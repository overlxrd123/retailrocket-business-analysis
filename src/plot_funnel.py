from pathlib import Path

import matplotlib
matplotlib.use("Agg")

import matplotlib.pyplot as plt
import pandas as pd
from sqlalchemy import text

from db_connect import get_engine


PROJECT = Path(__file__).resolve().parents[1]
FIGURES = PROJECT / "figures"
RESULTS = PROJECT / "results"
FIGURES.mkdir(exist_ok=True)
RESULTS.mkdir(exist_ok=True)

engine = get_engine()

try:
    with engine.connect() as conn:
        funnel = pd.read_sql_query(
            text("""
                SELECT *
                FROM funnel_metrics
                ORDER BY stage_order
            """),
            conn,
        )

        windows = pd.read_sql_query(
            text("""
                SELECT *
                FROM funnel_window_comparison
                ORDER BY window_hours
            """),
            conn,
        )
finally:
    engine.dispose()

assert funnel["stage_order"].tolist() == [1, 2, 3]
assert funnel["pair_count"].is_monotonic_decreasing
assert windows["window_hours"].tolist() == [24, 72, 168]
assert windows["viewing_pairs"].nunique() == 1
assert windows["purchase_pairs"].is_monotonic_increasing

windows["view_to_purchase_pct"] = (
    100 * windows["purchase_pairs"] / windows["viewing_pairs"]
)

funnel.to_csv(
    RESULTS / "funnel_metrics_mysql.csv",
    index=False, encoding="utf-8-sig",
)
windows.to_csv(
    RESULTS / "funnel_windows_mysql.csv",
    index=False, encoding="utf-8-sig",
)

plt.rcParams["font.sans-serif"] = ["Microsoft YaHei", "SimHei"]
plt.rcParams["axes.unicode_minus"] = False

fig, axes = plt.subplots(1, 2, figsize=(13, 5))

# 左图：24小时有序漏斗
counts = funnel["pair_count"].to_numpy()
labels = ["首次浏览", "随后加购", "随后购买"]
percentages = 100 * counts / counts[0]

bars = axes[0].barh(
    labels, counts,
    color=["#2878AD", "#D98D45", "#208978"],
)
axes[0].invert_yaxis()
axes[0].bar_label(
    bars,
    labels=[
        f"{count:,}（{pct:.2f}%）"
        for count, pct in zip(counts, percentages)
    ],
    padding=5,
)
axes[0].set_xlim(0, counts[0] * 1.45)
axes[0].ticklabel_format(axis="x", style="plain")
axes[0].set_title("首次浏览后24小时：有序漏斗")
axes[0].set_xlabel("访客—商品对数量")

# 右图：使用同一批具备7天观察期的起点
x = range(len(windows))
rates = windows["view_to_purchase_pct"].to_numpy()

axes[1].plot(x, rates, marker="o", color="#9654A2")
axes[1].set_xticks(list(x), ["24小时", "72小时", "7天"])
axes[1].set_ylim(0, max(rates) * 1.2)
axes[1].set_ylabel("浏览起点到有序购买的比例（%）")
axes[1].set_title("同一观察样本：延长窗口的变化")

for position, rate, count in zip(
    x, rates, windows["purchase_pairs"]
):
    axes[1].annotate(
        f"{rate:.4f}%\n{int(count):,}对",
        (position, rate),
        xytext=(0, 10),
        textcoords="offset points",
        ha="center",
    )

axes[1].grid(axis="y", alpha=0.2)

fig.suptitle("同访客、同商品：浏览 → 加购 → 购买")
fig.text(
    0.5, 0.02,
    "两图观察样本不同：左图要求至少24小时观察期，右图统一要求至少7天。",
    ha="center", fontsize=10,
)
fig.tight_layout(rect=(0, 0.08, 1, 0.94))

output = FIGURES / "04_funnel_comparison.png"
fig.savefig(output, dpi=160)
plt.close(fig)

print(f"图片已保存：{output}")
print(windows.to_string(index=False))