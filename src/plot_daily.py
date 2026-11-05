from pathlib import Path

import matplotlib
matplotlib.use("Agg")  # 直接保存图片，不依赖弹窗

import matplotlib.pyplot as plt
import matplotlib.dates as mdates
import pandas as pd
from sqlalchemy import text

from db_connect import get_engine


# 根据脚本位置定位项目，不依赖终端当前目录
PROJECT = Path(__file__).resolve().parents[1]
FIGURES = PROJECT / "figures"
RESULTS = PROJECT / "results"

FIGURES.mkdir(exist_ok=True)
RESULTS.mkdir(exist_ok=True)

# 1. 从 MySQL 读取已经汇总好的每日指标
engine = get_engine()

try:
    with engine.connect() as conn:
        daily = pd.read_sql_query(
            text("""
                SELECT *
                FROM daily_metrics
                ORDER BY event_date_utc
            """),
            conn,
        )
finally:
    engine.dispose()

daily["event_date_utc"] = pd.to_datetime(daily["event_date_utc"])

# 保存本次数据库查询结果，便于核对
daily.to_csv(
    RESULTS / "daily_metrics_mysql.csv",
    index=False,
    encoding="utf-8-sig",
)

# 2. 排除首尾不完整日
data = daily.loc[daily["is_boundary_date"].eq(0)].copy()

# 3. 计算滚动指标
data["active_7d"] = data["active_visitors"].rolling(7).mean()
data["buyers_7d"] = data["buying_visitors"].rolling(7).mean()

# 占比使用分子之和÷分母之和，不直接平均每日百分比
data["buyer_rate_7d"] = (
    100
    * data["buying_visitors"].rolling(7).sum()
    / data["active_visitors"].rolling(7).sum()
)

# 4. 绘图
plt.rcParams["font.sans-serif"] = ["Microsoft YaHei", "SimHei"]
plt.rcParams["axes.unicode_minus"] = False

fig, axes = plt.subplots(3, 1, figsize=(12, 9), sharex=True)

settings = [
    ("active_visitors", "active_7d", "每日活跃访客", "#2878AD"),
    ("buying_visitors", "buyers_7d", "每日购买访客", "#208978"),
    (
        "daily_buyer_rate_pct",
        "buyer_rate_7d",
        "当日购买访客占比（%）",
        "#9654A2",
    ),
]

for ax, (raw, rolling, title, color) in zip(axes, settings):
    ax.plot(
        data["event_date_utc"], data[raw],
        color=color, alpha=0.3, label="每日值",
    )
    ax.plot(
        data["event_date_utc"], data[rolling],
        color=color, linewidth=2, label="7日滚动值",
    )
    ax.set_title(title, loc="left")
    ax.grid(axis="y", alpha=0.2)
    ax.legend(loc="upper right")

axes[-1].xaxis.set_major_formatter(mdates.DateFormatter("%m-%d"))
axes[-1].set_xlabel("日期（UTC）")

fig.suptitle("Retailrocket：访问与购买趋势")
fig.tight_layout(rect=(0, 0, 1, 0.96))

output = FIGURES / "01_daily_trends.png"
fig.savefig(output, dpi=160)
plt.close(fig)

print(f"参与绘图：{len(data)} 个完整日")
print(f"图片已保存：{output}")