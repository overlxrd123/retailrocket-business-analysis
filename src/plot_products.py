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
        categories = pd.read_sql_query(
            text("SELECT * FROM category_metrics"), conn
        )
        availability = pd.read_sql_query(
            text("SELECT * FROM availability_metrics"), conn
        )
finally:
    engine.dispose()

for frame in [categories, availability]:
    assert int(frame["total_events"].sum()) == 2756101
    assert int(frame["purchase_events"].sum()) == 22457

categories.to_csv(
    RESULTS / "category_metrics_mysql.csv",
    index=False, encoding="utf-8-sig",
)
availability.to_csv(
    RESULTS / "availability_metrics_mysql.csv",
    index=False, encoding="utf-8-sig",
)

plt.rcParams["font.sans-serif"] = ["Microsoft YaHei", "SimHei"]
plt.rcParams["axes.unicode_minus"] = False

# ---------- 图6：类别分布 ----------
# 仅对已匹配类别排名；未知类别另行展示
known = categories.loc[
    categories["category_match_status"].eq("matched")
].copy()

top = (
    known.sort_values("purchase_events", ascending=False)
    .head(12)
    .sort_values("purchase_events")
)

coverage = (
    categories.groupby("category_match_status")["total_events"]
    .sum()
)

fig, axes = plt.subplots(1, 2, figsize=(13, 6))

bars = axes[0].barh(
    top["category_id"].map(lambda value: str(int(value))),
    top["purchase_events"],
    color="#208978",
)
axes[0].bar_label(
    bars,
    labels=[f"{int(value):,}" for value in top["purchase_events"]],
    padding=4,
)
axes[0].margins(x=0.2)
axes[0].set_title("已知类别：购买事件数前12名")
axes[0].set_xlabel("购买事件数，不是订单数")
axes[0].set_ylabel("匿名类别编号")

status_labels = {
    "matched": "已匹配",
    "no_history": "无历史类别",
    "not_in_tree": "类别树未匹配",
}

percentages = 100 * coverage / coverage.sum()
bars = axes[1].bar(
    [status_labels.get(value, value) for value in coverage.index],
    percentages,
    color="#2878AD",
)
axes[1].bar_label(
    bars,
    labels=[f"{value:.2f}%" for value in percentages],
    padding=5,
)
axes[1].set_ylim(0, 110)
axes[1].set_title("全部行为事件的类别匹配覆盖率")
axes[1].set_ylabel("事件占比（%）")

fig.suptitle("商品类别：购买事件分布与历史属性覆盖")
fig.tight_layout(rect=(0, 0, 1, 0.94))
fig.savefig(FIGURES / "06_product_categories.png", dpi=160)
plt.close(fig)

# ---------- 图7：各类事件的可售状态构成 ----------
availability["status"] = availability["available"].map(
    lambda value: (
        "未知" if pd.isna(value)
        else {0: "不可售", 1: "可售"}.get(int(value), "其他")
    )
)

assert set(availability["status"]) <= {"未知", "不可售", "可售"}

event_columns = ["view_events", "cart_events", "purchase_events"]
event_labels = ["浏览事件", "加购事件", "购买事件"]

counts = (
    availability.groupby("status")[event_columns]
    .sum()
    .reindex(["可售", "不可售", "未知"], fill_value=0)
)

shares = counts.div(counts.sum(axis=0), axis=1) * 100

fig, ax = plt.subplots(figsize=(10, 6))
bottom = np.zeros(3)

for status, color in [
    ("可售", "#208978"),
    ("不可售", "#D98D45"),
    ("未知", "#AAAAAA"),
]:
    values = shares.loc[status].to_numpy(dtype=float)
    ax.bar(
        event_labels, values, bottom=bottom,
        label=status, color=color,
    )

    for position, value in enumerate(values):
        if value >= 2:
            ax.text(
                position,
                bottom[position] + value / 2,
                f"{value:.1f}%",
                ha="center", va="center",
            )

    bottom += values

ax.set_ylim(0, 110)
ax.set_ylabel("该类事件中的状态占比（%）")
ax.set_title("行为发生时的商品可售状态构成")
ax.legend(loc="upper right")

fig.text(
    0.5, 0.02,
    "每根柱分别以该类事件总数为分母；这不是可售状态对购买的转化率或因果效果。",
    ha="center", fontsize=10,
)

fig.tight_layout(rect=(0, 0.07, 1, 1))
fig.savefig(FIGURES / "07_availability.png", dpi=160)
plt.close(fig)

print("已生成：06_product_categories.png")
print("已生成：07_availability.png")
print("\n各可售状态的事件数：")
print(counts.to_string())