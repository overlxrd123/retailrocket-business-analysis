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
        weekends = pd.read_sql_query(
            text("""
                SELECT *
                FROM daily_metrics
                WHERE event_date_utc >= '2015-07-01'
                  AND event_date_utc < '2015-08-01'
                  AND weekday_number IN (6, 7)
                  AND is_boundary_date = 0
                ORDER BY event_date_utc
            """),
            conn,
        )

        hourly = pd.read_sql_query(
            text("""
                SELECT *
                FROM hourly_metrics
                WHERE event_date_utc IN (
                    '2015-07-18', '2015-07-19',
                    '2015-07-25', '2015-07-26'
                )
                ORDER BY event_date_utc, hour_utc
            """),
            conn,
        )
finally:
    engine.dispose()

weekends["event_date_utc"] = pd.to_datetime(weekends["event_date_utc"])
hourly["event_date_utc"] = pd.to_datetime(hourly["event_date_utc"])

assert len(weekends) == 8
assert hourly["event_date_utc"].nunique() == 4

# 用7月其余周末建立同星期基准：
# 周六对比其他周六，周日对比其他周日
target = weekends["event_date_utc"].isin(
    pd.to_datetime(["2015-07-25", "2015-07-26"])
)

baseline = (
    weekends.loc[~target]
    .groupby("weekday_number")[
        ["buying_visitors", "active_visitors"]
    ]
    .sum()
)

baseline["buyer_rate_pct"] = (
    100 * baseline["buying_visitors"] / baseline["active_visitors"]
)

weekends["same_weekday_baseline_pct"] = (
    weekends["weekday_number"].map(baseline["buyer_rate_pct"])
)

weekends.to_csv(
    RESULTS / "july_weekend_comparison_mysql.csv",
    index=False, encoding="utf-8-sig",
)
hourly.to_csv(
    RESULTS / "july_hourly_mysql.csv",
    index=False, encoding="utf-8-sig",
)

plt.rcParams["font.sans-serif"] = ["Microsoft YaHei", "SimHei"]
plt.rcParams["axes.unicode_minus"] = False

labels = weekends["event_date_utc"].dt.strftime("%m-%d")
colors = ["#D98D45" if value else "#2878AD" for value in target]

fig, axes = plt.subplots(3, 1, figsize=(12, 12))

# 1. 各周末日期访问量
bars = axes[0].bar(
    labels, weekends["active_visitors"], color=colors
)
axes[0].bar_label(bars, fmt="%.0f", padding=3)
axes[0].set_title("7月各周末日期：活跃访客")
axes[0].margins(y=0.15)

# 2. 购买占比与同星期基准
axes[1].bar(
    labels,
    weekends["daily_buyer_rate_pct"].astype(float),
    color=colors,
    label="当日购买占比",
)
axes[1].scatter(
    labels,
    weekends["same_weekday_baseline_pct"],
    color="black", marker="_", s=250,
    label="7月其余同星期日期的加权购买占比",
    zorder=3,
)
axes[1].set_title("购买访客占比对比（%）")
axes[1].legend()

# 3. 相邻两个周末的小时分布
for date, group in hourly.groupby("event_date_utc"):
    axes[2].plot(
        group["hour_utc"],
        group["active_visitors"],
        label=date.strftime("%m-%d"),
    )

axes[2].set_title("相邻两个周末：小时活跃访客")
axes[2].set_xlabel("小时（UTC）")
axes[2].set_ylabel("小时去重访客数")
axes[2].set_xticks(range(0, 24, 2))
axes[2].legend()

for ax in axes:
    ax.grid(axis="y", alpha=0.2)
    ax.set_axisbelow(True)

fig.suptitle("7月25—26日：访问增长是否伴随购买增长？")
fig.tight_layout(rect=(0, 0, 1, 0.96))

output = FIGURES / "03_july_comparison.png"
fig.savefig(output, dpi=160)
plt.close(fig)

print(f"图片已保存：{output}")
print(
    weekends[
        [
            "event_date_utc",
            "active_visitors",
            "buying_visitors",
            "daily_buyer_rate_pct",
            "same_weekday_baseline_pct",
        ]
    ].to_string(index=False)
)