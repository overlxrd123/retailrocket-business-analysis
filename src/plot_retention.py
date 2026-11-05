from pathlib import Path

import matplotlib
matplotlib.use("Agg")

import matplotlib.pyplot as plt
import numpy as np
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
        exact = pd.read_sql_query(
            text("SELECT * FROM retention_metrics ORDER BY day_n"),
            conn,
        )

        weekly = pd.read_sql_query(
            text("""
                SELECT *
                FROM cohort_weekly_retention
                ORDER BY cohort_week, week_index
            """),
            conn,
        )
finally:
    engine.dispose()

assert exact["day_n"].tolist() == [1, 7, 30]
assert (exact["returned_visitors"] <= exact["eligible_visitors"]).all()

exact.to_csv(
    RESULTS / "retention_metrics_mysql.csv",
    index=False, encoding="utf-8-sig",
)
weekly.to_csv(
    RESULTS / "weekly_retention_mysql.csv",
    index=False, encoding="utf-8-sig",
)

weekly["cohort_week"] = pd.to_datetime(weekly["cohort_week"])
weekly["retention_rate_pct"] = pd.to_numeric(
    weekly["retention_rate_pct"], errors="raise"
)

# 去掉第0周；它包含首次行为，因此天然为100%
matrix = weekly.pivot(
    index="cohort_week",
    columns="week_index",
    values="retention_rate_pct",
).reindex(columns=range(1, 8))

# 最早的04-27分群只有05-03一天入群，先不参与跨周比较
matrix = matrix.loc[matrix.index >= pd.Timestamp("2015-05-04")]

# 尚没有任何完整后续周的分群不画，原始CSV仍保留
matrix = matrix.dropna(how="all")
assert not matrix.empty

plt.rcParams["font.sans-serif"] = ["Microsoft YaHei", "SimHei"]
plt.rcParams["axes.unicode_minus"] = False

fig, axes = plt.subplots(
    2, 1, figsize=(12, 12),
    gridspec_kw={"height_ratios": [1, 3]},
)

# 1. 精确第N日回访率
rates = exact["retention_rate_pct"].astype(float).to_numpy()
bars = axes[0].bar(
    [f"D{int(n)}" for n in exact["day_n"]],
    rates,
    color=["#2878AD", "#208978", "#9654A2"],
)

axes[0].bar_label(
    bars,
    labels=[f"{value:.3f}%" for value in rates],
    padding=5,
)
axes[0].set_ylim(0, rates.max() * 1.25)
axes[0].set_title("首次观察后精确第N日回访率")
axes[0].set_ylabel("回访率（%）")
axes[0].grid(axis="y", alpha=0.2)
axes[0].set_axisbelow(True)

# 2. 周留存热力图，灰色为观察窗口不足
values = matrix.to_numpy(dtype=float)
vmax = float(np.nanmax(values))

cmap = plt.get_cmap("Blues").copy()
cmap.set_bad("#EEEEEE")

image = axes[1].imshow(
    np.ma.masked_invalid(values),
    aspect="auto",
    cmap=cmap,
    vmin=0,
    vmax=vmax,
)

axes[1].set_xticks(
    range(7), [f"第{n}周" for n in range(1, 8)]
)
axes[1].set_yticks(
    range(len(matrix)),
    matrix.index.strftime("%m-%d"),
)
axes[1].set_ylabel("首次观察周起始日（UTC）")
axes[1].set_title("周回访率（%）：灰色表示观察窗口不足")

for row in range(values.shape[0]):
    for col in range(values.shape[1]):
        value = values[row, col]
        if np.isfinite(value):
            axes[1].text(
                col, row, f"{value:.2f}",
                ha="center", va="center",
                fontsize=9,
                color="white" if value > vmax * 0.6 else "black",
            )

fig.colorbar(image, ax=axes[1], label="回访率（%）")
fig.suptitle("访客回访：精确日指标与周分群")
fig.text(
    0.5, 0.015,
    "首次观察不等于注册；D7是精确第7日，周回访按7天龄段计算，二者口径不同。",
    ha="center", fontsize=10,
)
fig.tight_layout(rect=(0, 0.05, 1, 0.96))

output = FIGURES / "05_retention.png"
fig.savefig(output, dpi=160)
plt.close(fig)

print(f"图片已保存：{output}")
print(exact.to_string(index=False))