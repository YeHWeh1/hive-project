# -*- coding: utf-8 -*-
"""NL2SQL 命令行入口。

用法：
    python -m nl2sql.main "2024 年 6 月的 GMV 是多少"
    python -m nl2sql.main --interactive        # 交互模式
    python -m nl2sql.main --sql-only "..."     # 只生成 SQL 不执行
"""
import argparse
import sys
import time

from . import engine, prompts, schema_loader


def build_system_prompt():
    schema = schema_loader.load()
    return prompts.SYSTEM.replace("{schema}", schema_loader.as_prompt_text(schema))


def render(header, rows, max_rows=30):
    if not header:
        return "（无结果）"
    widths = [len(str(h)) for h in header]
    shown = rows[:max_rows]
    for r in shown:
        for i, c in enumerate(r):
            if i < len(widths):
                widths[i] = max(widths[i], len(str(c)))
    sep = "+" + "+".join("-" * (w + 2) for w in widths) + "+"
    lines = [sep, "| " + " | ".join(str(h).ljust(widths[i]) for i, h in enumerate(header)) + " |", sep]
    for r in shown:
        cells = []
        for i in range(len(header)):
            v = str(r[i]) if i < len(r) else ""
            cells.append(v.ljust(widths[i]))
        lines.append("| " + " | ".join(cells) + " |")
    lines.append(sep)
    if len(rows) > max_rows:
        lines.append(f"... 共 {len(rows)} 行，仅显示前 {max_rows} 行")
    return "\n".join(lines)


def ask(question, system_prompt, run_sql=True, verbose=False):
    t0 = time.time()
    text, usage = engine.llm_call(system_prompt, prompts.USER_TEMPLATE.format(question=question))
    t_llm = time.time() - t0

    sql, reason = engine.extract_sql(text)
    if not sql:
        print("\n[失败] 模型未返回可解析的 SQL：")
        print(text[:500])
        return None

    ok, why = engine.guard(sql)
    print("\n" + "=" * 70)
    print("问题：", question)
    if reason:
        print("思路：", reason)
    print("-" * 70)
    print("SQL：")
    print(sql)
    print("-" * 70)

    if not ok:
        print(f"[拦截] {why}")
        return {"question": question, "sql": sql, "ok": False, "error": why}

    if not run_sql:
        return {"question": question, "sql": sql, "ok": True, "skipped": True}

    header, rows, out = engine.execute(sql)
    err = engine.check_error(out)
    if err:
        # 失败重试一次：把报错回喂给模型
        print(f"[执行失败] {err}\n[重试] 将错误信息回传给模型修正 ...")
        fix_prompt = (f"上一版 SQL 执行报错：{err}\n原 SQL：{sql}\n"
                      f"请修正后重新输出 JSON（只输出 JSON）。")
        text2, _ = engine.llm_call(system_prompt, prompts.USER_TEMPLATE.format(question=question) + "\n" + fix_prompt)
        sql2, reason2 = engine.extract_sql(text2)
        if sql2:
            ok2, why2 = engine.guard(sql2)
            print(f"\n修正后 SQL：\n{sql2}")
            if ok2:
                header, rows, out = engine.execute(sql2)
                err = engine.check_error(out)
                sql = sql2
            else:
                print(f"[拦截] {why2}")
        if err:
            print(f"[仍失败] {err}")
            return {"question": question, "sql": sql, "ok": False, "error": err}

    t_all = time.time() - t0
    print(render(header, rows))
    print(f"[耗时] 模型 {t_llm:.1f}s / 总 {t_all:.1f}s　[token] {usage.get('total_tokens', '-')}")
    return {"question": question, "sql": sql, "ok": True, "rows": len(rows),
            "header": header, "elapsed": round(t_all, 2)}


def main():
    ap = argparse.ArgumentParser(description="NL2SQL 自然语言查询 Hive")
    ap.add_argument("question", nargs="*", help="自然语言问题")
    ap.add_argument("--interactive", action="store_true", help="交互模式")
    ap.add_argument("--sql-only", action="store_true", help="只生成 SQL 不执行")
    args = ap.parse_args()

    sp = build_system_prompt()

    if args.interactive:
        print("NL2SQL 交互模式，输入问题回车执行，输入 exit 退出。")
        while True:
            try:
                q = input("\n问题> ").strip()
            except (EOFError, KeyboardInterrupt):
                break
            if q.lower() in ("exit", "quit", ""):
                break
            ask(q, sp, run_sql=not args.sql_only)
        return

    q = " ".join(args.question).strip()
    if not q:
        ap.print_help()
        sys.exit(1)
    ask(q, sp, run_sql=not args.sql_only)


if __name__ == "__main__":
    main()
