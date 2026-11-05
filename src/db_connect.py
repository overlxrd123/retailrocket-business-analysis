from getpass import getpass

from sqlalchemy import create_engine
from sqlalchemy.engine import URL


def get_engine():
    """创建数据库连接，密码仅在运行时输入。"""
    url = URL.create(
        drivername="mysql+pymysql",
        username="root",
        password=getpass("请输入 MySQL 密码："),
        host="127.0.0.1",
        port=3306,
        database="retailrocket",
        query={"charset": "utf8mb4"},
    )

    return create_engine(
        url,
        connect_args={"connect_timeout": 10},
        pool_pre_ping=True,
    )