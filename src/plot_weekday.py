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

# 1. 直接读取 MySQL 的星期汇总表
engine = get_engine()

try:
    with engine.connect() as conn:
        data = pd.read_sql_query(
            text("""
                SELECT *
                FROM weekday_metrics
                ORDER BY weekday_number
            """),
            conn,
        )
finally:
    engine.dispose()

# 2. 核对范围
assert data["weekday_number"].tolist() == list(range(1, 8))
assert int(data["date_count"].sum()) == 137

data.to_csv(
    RESULTS / "weekday_metrics_mysql.csv",
    index=False,
    encoding="utf-8-sig",
)

# 3. 绘图：周末用橙色标识
plt.rcParams["font.sans-serif"] = ["Microsoft YaHei", "SimHei"]
plt.rcParams["axes.unicode_minus"] = False

labels = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
colors = ["#2878AD"] * 5 + ["#D98D45"] * 2

fig, axes = plt.subplots(1, 2, figsize=(12, 5))

settings = [
    ("avg_daily_active_visitors", "日均活跃访客", "{:,.0f}"),
    ("buyer_rate_pct", "购买访客占比（%）", "{:.2f}%"),
]

for ax, (column, title, number_format) in zip(axes, settings):
    values = data[column].astype(float).to_numpy()
    bars = ax.bar(labels, values, color=colors)

    ax.bar_label(
        bars,
        labels=[number_format.format(value) for value in values],
        padding=4,
        fontsize=10,
    )

    ax.set_title(title)
    ax.set_ylim(0, values.max() * 1.18)
    ax.grid(axis="y", alpha=0.2)
    ax.set_axisbelow(True)

fig.suptitle("UTC 星期规律：排除首尾不完整日")
fig.text(
    0.5, 0.02,
    "购买占比 = 购买访客日之和 ÷ 活跃访客日之和；仅反映关联，不代表因果。",
    ha="center", fontsize=10,
)

fig.tight_layout(rect=(0, 0.07, 1, 0.94))

output = FIGURES / "02_weekday_pattern.png"
fig.savefig(output, dpi=160)
plt.close(fig)

print("核对通过：7个星期分组，共137天。")
print(f"图片已保存：{output}")