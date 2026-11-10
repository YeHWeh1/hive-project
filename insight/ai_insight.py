# -*- coding: utf-8 -*-
"""第 3 周 · 子任务 5：AI 智能洞察与自动报告

流程：
  1. 从 Hive 取 KPI 事实（月度、渠道、状态、会员、品类、日粒度异常）
  2. 用程序做异常检测（z-score），不依赖模型判断「哪里异常」
  3. 把「事实清单」交给大模型，只让它做归因与摘要，禁止引入外部信息
  4. 汇总输出 Markdown 报告 + 事实底稿 JSON

用法：
    python -m insight.ai_insight
"""
import csv
import io
import json
import os
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from nl2sql import engine  # 复用大模型调用

CONTAINER = "hive-project-hive-server-1"
JDBC = "jdbc:hive2://localhost:10000/"
OUT_MD = r"E:\hive-project\docs\第3周_AI经营分析摘要.md"
OUT_JSON = r"E:\dssgz\kpi\insight_facts.json"


def q(sql):
    cmd = ["docker", "exec", CONTAINER, "beeline", "--silent=true", "--outputformat=csv2",
           "-u", JDBC, "-e", sql]
    p = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="ignore")
    rows = list(csv.reader(io.StringIO(p.stdout or "")))
    rows = [r for r in rows if any(c.strip() for c in r)]
    if not rows:
        return [], []
    return rows[0], rows[1:]


def collect():
    facts = {}

    h, r = q("""select round(sum(pay_amount),2) gmv, count(distinct order_id) orders,
                       count(distinct user_id) buyers, round(sum(pay_amount)/count(distinct order_id),2) aov
                from ydsh_dwd.fact_order where amount_invalid=0""")
    facts["overall"] = dict(zip(h, r[0]))

    h, r = q("""select order_month, count(distinct order_id) orders, round(sum(pay_amount),2) gmv
                from ydsh_dwd.fact_order where amount_invalid=0 group by order_month order by order_month""")
    facts["monthly"] = [dict(zip(h, x)) for x in r]

    h, r = q("""select stat_date, round(gmv,2) gmv, order_cnt
                from ydsh_dws.dws_sales_day order by stat_date""")
    facts["daily"] = [dict(zip(h, x)) for x in r]

    h, r = q("""select c.channel_name, count(distinct f.order_id) orders, round(sum(f.pay_amount),2) gmv
                from ydsh_dwd.fact_order f join ydsh_dwd.dim_channel c on f.channel_code=c.channel_code
                where f.amount_invalid=0 group by c.channel_name order by gmv desc""")
    facts["channel"] = [dict(zip(h, x)) for x in r]

    h, r = q("""select s.status_name, count(*) orders, round(100.0*count(*)/sum(count(*)) over (),2) pct
                from ydsh_dwd.fact_order f join ydsh_dwd.dim_order_status s on f.status_code=s.status_code
                where f.amount_invalid=0 group by s.status_name order by orders desc""")
    facts["status"] = [dict(zip(h, x)) for x in r]

    h, r = q("""select l.level_name, count(distinct f.user_id) users,
                       round(sum(f.pay_amount)/count(distinct f.order_id),2) aov
                from ydsh_dwd.fact_order f
                join ydsh_dwd.dim_user u on f.user_id=u.user_id
                join ydsh_dwd.dim_member_level l on u.member_level_code=l.level_code
                where f.amount_invalid=0 group by l.level_name, l.sort_no order by l.sort_no""")
    facts["member_level"] = [dict(zip(h, x)) for x in r]

    h, r = q("""select rk, category, round(sales,2) sales, round(cast(sales_ratio as double)*100,2) pct
                from ydsh_ads.ads_category_topn order by rk limit 5""")
    facts["category_top5"] = [dict(zip(h, x)) for x in r]

    h, r = q("""select value_level, count(*) users, round(sum(total_amount),2) gmv
                from ydsh_ads.ads_user_value group by value_level order by value_level""")
    facts["user_value"] = [dict(zip(h, x)) for x in r]

    return facts


def detect_anomalies(daily):
    """z-score 检测日 GMV 异常（|z| >= 2）。"""
    gmv = np.array([float(d["gmv"]) for d in daily])
    mu, sd = gmv.mean(), gmv.std()
    out = []
    for d, v in zip(daily, gmv):
        z = (v - mu) / sd if sd else 0
        if abs(z) >= 2:
            out.append({"date": d["stat_date"], "gmv": round(v, 2), "z": round(float(z), 2),
                        "type": "异常高" if z > 0 else "异常低"})
    out.sort(key=lambda x: abs(x["z"]), reverse=True)
    return {"mean": round(float(mu), 2), "std": round(float(sd), 2), "anomalies": out[:8]}


def build_prompt(facts, anom):
    fact_text = json.dumps({**facts, "anomaly": anom}, ensure_ascii=False, indent=1)
    system = """你是新零售企业的数据分析师。我会给你一份已经算好的经营数据事实清单（JSON）。
请基于这些事实撰写经营分析，严格遵守：
1. 只能使用清单中出现的数据，禁止引入任何外部信息（如行业均值、竞品、天气、政策）。
2. 每个结论必须能对应到具体数字；没有数字支撑的推断必须标注为「推测」。
3. 如果数据显示某种异常无法从清单解释，直接说「现有数据不足以判断原因」，不要编造因果。
4. 输出 Markdown，包含四部分：一、整体经营概况；二、异常与波动归因；三、结构性发现；四、经营建议（不超过4条）。
5. 语言简洁，面向管理层，控制在 600 字以内。"""
    user = f"以下是经营数据事实清单：\n\n{fact_text}\n\n请按要求撰写分析。"
    return system, user


def main():
    print("采集 KPI 事实 ...")
    facts = collect()
    for k, v in facts.items():
        if isinstance(v, list):
            print(f"  {k}: {len(v)} 行")
        else:
            print(f"  {k}: {v}")

    anom = detect_anomalies(facts["daily"])
    print(f"异常日检测：{len(anom['anomalies'])} 天（|z|>=2）")

    with open(OUT_JSON, "w", encoding="utf-8") as f:
        json.dump({**facts, "anomaly": anom}, f, ensure_ascii=False, indent=2)

    print("调用大模型生成分析 ...")
    system, user = build_prompt(facts, anom)
    text, usage = engine.llm_call(system, user, temperature=0.3, max_tokens=1800)
    print(f"  完成，token={usage.get('total_tokens')}")

    header = f"""# 第 3 周 · AI 经营分析摘要

> 团队：云仓五号　生成日期：2026-11-10
> 说明：数据事实由 Hive 查询产出，异常检测由 z-score 程序完成，大模型仅负责归因与文字组织。
> 事实底稿：`insight_facts.json`（含 366 天明细）

---

## 零、数据事实摘要（程序产出，未经模型改写）

| 指标 | 数值 |
|---|---|
| GMV | {float(facts['overall']['gmv']):,.2f} 元 |
| 有效订单 | {int(float(facts['overall']['orders'])):,} 笔 |
| 买家数 | {int(float(facts['overall']['buyers'])):,} 人 |
| 客单价 | {float(facts['overall']['aov']):,.2f} 元 |

**异常日（z-score ≥ 2，共 {len(anom['anomalies'])} 天）**：日均 GMV {anom['mean']:,.2f} 元，标准差 {anom['std']:,.2f} 元。

| 日期 | GMV | z 值 | 类型 |
|---|---|---|---|
"""
    for a in anom["anomalies"]:
        header += f"| {a['date']} | {a['gmv']:,.2f} | {a['z']} | {a['type']} |\n"

    header += "\n---\n\n## 一、AI 生成的分析（基于上述事实）\n\n"

    footer = """

---

## 附录：AI 输出的验证记录

| 检查项 | 做法 | 结果 |
|---|---|---|
| 数字是否与事实一致 | 人工核对 AI 引用的 GMV、订单量、客单价 | 待填 |
| 是否引入外部信息 | 检索文中是否出现行业均值、竞品、政策等 | 待填 |
| 因果结论是否有数据支撑 | 逐条检查「因为…所以…」是否有对应字段 | 待填 |
| 是否有过度承诺 | 检查是否出现「必然」「一定」等绝对化表述 | 待填 |
"""

    os.makedirs(os.path.dirname(OUT_MD), exist_ok=True)
    with open(OUT_MD, "w", encoding="utf-8") as f:
        f.write(header + text.strip() + footer)
    print("已生成", OUT_MD)


if __name__ == "__main__":
    main()
