# -*- coding: utf-8 -*-
"""从 Hive 自动抽取表结构，生成供大模型理解的 Schema 描述。

做法：对每张表执行 `describe <table>`，解析出字段名、类型、注释，
缓存到 schema.json，避免每次都连 Hive（一次抽取约 20 秒）。
"""
import csv
import io
import json
import os
import subprocess
import sys

CONTAINER = "hive-project-hive-server-1"
JDBC = "jdbc:hive2://localhost:10000/"

# 只抽取与大模型问答相关的表（全量 25 张会让 prompt 过长）
TABLES = [
    ("ydsh_dwd", "fact_order", "订单事实表（一单一行，含金额、状态、渠道、时间）"),
    ("ydsh_dwd", "fact_order_item", "订单明细事实表（一商品一行，含数量、单价、明细金额）"),
    ("ydsh_dwd", "dim_user", "用户维度表（含性别、年龄、省市、会员等级编码）"),
    ("ydsh_dwd", "dim_product", "商品维度表（含品类、品牌、价格、状态）"),
    ("ydsh_dwd", "dim_store", "门店维度表（含省市、区县、面积、店长）"),
    ("ydsh_dwd", "dim_date", "日期维度表（2023-2025 每天，含星期、季度、是否周末）"),
    ("ydsh_dwd", "dim_member_level", "会员等级维表（level_code, level_name）"),
    ("ydsh_dwd", "dim_order_status", "订单状态维表（status_code, status_name）"),
    ("ydsh_dwd", "dim_pay_type", "支付方式维表（pay_code, pay_name）"),
    ("ydsh_dwd", "dim_channel", "下单渠道维表（channel_code, channel_name）"),
    ("ydsh_dws", "dws_sales_day", "日粒度销售汇总（日期、订单量、GMV、客单价）"),
    ("ydsh_dws", "dws_sales_month", "月粒度销售汇总（含取消率、退款率）"),
    ("ydsh_ads", "ads_kpi_overview", "核心 KPI 总览（指标名、值、单位、口径）"),
    ("ydsh_ads", "ads_category_topn", "品类销售排行（含占比）"),
    ("ydsh_ads", "ads_store_topn", "门店销售排行"),
    ("ydsh_ads", "ads_user_value", "用户价值分层（累计消费、订单数、最近下单、层级）"),
]

SCHEMA_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "schema.json")


def run_beeline(sql: str) -> str:
    """用 beeline 执行查询，返回 stdout（CSV 格式）。"""
    cmd = [
        "docker", "exec", CONTAINER, "beeline",
        "--silent=true", "--outputformat=csv2",
        "-u", JDBC, "-e", sql,
    ]
    p = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="ignore")
    return p.stdout


def describe(db: str, table: str):
    out = run_beeline(f"describe {db}.{table}")
    rows = list(csv.reader(io.StringIO(out)))
    cols = []
    for r in rows:
        if len(r) < 2:
            continue
        name, dtype = r[0].strip(), r[1].strip()
        if not name or name.startswith("#") or name in ("col_name",):
            continue
        if dtype in ("", "data_type"):
            continue
        comment = r[2].strip() if len(r) > 2 else ""
        cols.append({"name": name, "type": dtype, "comment": comment})
        if len(cols) >= 40:
            break
    return cols


def build():
    schema = []
    for db, table, cn in TABLES:
        cols = describe(db, table)
        if not cols:
            print(f"  [跳过] {db}.{table} 无字段")
            continue
        schema.append({"db": db, "table": table, "cn": cn, "columns": cols})
        print(f"  [OK] {db}.{table}  {len(cols)} 个字段")
    with open(SCHEMA_FILE, "w", encoding="utf-8") as f:
        json.dump(schema, f, ensure_ascii=False, indent=2)
    print(f"\n已写入 {SCHEMA_FILE}，共 {len(schema)} 张表")
    return schema


def load():
    """优先读缓存；没有则现场抽取。"""
    if os.path.exists(SCHEMA_FILE):
        return json.load(open(SCHEMA_FILE, encoding="utf-8"))
    return build()


def as_prompt_text(schema) -> str:
    """把 schema 转成给模型看的文字描述。"""
    lines = []
    for s in schema:
        lines.append(f"表 {s['db']}.{s['table']}　-- {s['cn']}")
        cols = [f"{c['name']} {c['type']}" + (f"（{c['comment']}）" if c["comment"] else "")
                for c in s["columns"]]
        lines.append("  字段：" + ", ".join(cols))
    return "\n".join(lines)


if __name__ == "__main__":
    build()
