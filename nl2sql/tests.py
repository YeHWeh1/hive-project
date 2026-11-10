# -*- coding: utf-8 -*-
"""NL2SQL 测试套件：跑一组典型问题，统计生成正确率与耗时。

用法：
    python -m nl2sql.tests
结果输出到 nl2sql/test_results.csv
"""
import csv
import os
import re
import time

from . import engine, main as cli, prompts, schema_loader

QUESTIONS = [
    ("2024 年 6 月的 GMV 是多少", ["fact_order", "pay_amount"]),
    ("销量最高的前 5 个品类", ["fact_order_item", "dim_product", "quantity"]),
    ("各渠道的客单价对比", ["dim_channel", "pay_amount"]),
    ("哪个门店的 GMV 最高", ["dim_store", "pay_amount"]),
    ("各会员等级的客单价是多少", ["dim_member_level", "pay_amount"]),
    ("2024 年 3 月的订单状态分布", ["dim_order_status", "2024-03"]),
    ("广东省 2024 年的销售额是多少", ["dim_store", "广东省"]),
    ("各支付方式的订单量占比", ["dim_pay_type"]),
    ("用户价值分层各层级有多少人", ["ads_user_value"]),
    ("哪个省份的买家最多", ["dim_user", "province"]),
]

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "test_results.csv")


def main():
    sp = cli.build_system_prompt()
    rows = []
    ok_cnt = 0
    for i, (q, must) in enumerate(QUESTIONS, 1):
        t0 = time.time()
        try:
            text, usage = engine.llm_call(sp, prompts.USER_TEMPLATE.format(question=q))
            sql, reason = engine.extract_sql(text)
            passed, why = engine.guard(sql) if sql else (False, "未生成 SQL")
            rows_n = 0
            err = ""
            exec_ok = False
            if passed:
                header, body, raw = engine.execute(sql)
                err = engine.check_error(raw) or ""
                rows_n = len(body)
                exec_ok = not err and bool(header)
            # 关键词检查：SQL 里是否用到了必要的表/字段
            kw_ok = all(k.lower() in (sql or "").lower() for k in must) if sql else False
            success = passed and exec_ok and kw_ok
            if success:
                ok_cnt += 1
        except Exception as e:  # noqa
            sql, reason, success, rows_n, err, why = "", "", False, 0, str(e), "异常"
            kw_ok = False
        cost = time.time() - t0
        rows.append({
            "序号": i, "问题": q, "是否通过": "是" if success else "否",
            "生成SQL": (sql or "")[:400], "返回行数": rows_n,
            "关键词命中": "是" if kw_ok else "否", "错误": err[:200], "耗时(s)": round(cost, 2),
        })
        print(f"[{i}/{len(QUESTIONS)}] {'PASS' if success else 'FAIL'}  {q}　({cost:.1f}s, {rows_n} 行)")

    with open(OUT, "w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)

    total = len(QUESTIONS)
    print(f"\n通过 {ok_cnt}/{total}　准确率 {ok_cnt/total*100:.1f}%")
    print(f"平均耗时 {sum(r['耗时(s)'] for r in rows)/total:.2f}s")
    print(f"结果已写入 {OUT}")


if __name__ == "__main__":
    main()
