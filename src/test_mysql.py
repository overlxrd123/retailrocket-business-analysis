from getpass import getpass

import pandas as pd
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL

password = getpass("请输入 MySQL 密码：")

url = URL.create(
    drivername="mysql+pymysql",
    username="root",
    password=password,
    host="127.0.0.1",
    port=3306,
    database="retailrocket",
    query={"charset": "utf8mb4"},
)

engine = create_engine(
    url,
    connect_args={"connect_timeout": 10},
)

try:
    with engine.connect() as conn:
        conn.execute(text("SET time_zone = '+00:00'"))

        daily = pd.read_sql_query(
            text("""
                SELECT *
                FROM daily_metrics
                ORDER BY event_date_utc
            """),
            conn,
        )

    print("\n连接成功！数据来自 MySQL。")
    print(f"读取日期数：{len(daily)}")
    print(f"事件总数：{int(daily['total_events'].sum()):,}")
    print("\n前 5 行：")
    print(daily.head().to_string(index=False))

finally:
    engine.dispose()