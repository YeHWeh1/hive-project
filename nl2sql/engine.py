# -*- coding: utf-8 -*-
"""大模型调用与 SQL 执行。

- llm_call: 读 .env 里的 DEEPSEEK_API_KEY，调用 DeepSeek Chat API
- execute: 通过 docker exec beeline 执行 SQL，返回表头 + 行数据
- guard: SQL 白名单校验，拦截非 SELECT 与未知表
"""
import csv
import io
import json
import os
import re
import subprocess
import time
import urllib.error
import urllib.request

CONTAINER = "hive-project-hive-server-1"
JDBC = "jdbc:hive2://localhost:10000/"
ENV_FILE = r"E:\hive-project\.env"

ALLOWED_PREFIXES = ("ydsh_dwd.", "ydsh_dws.", "ydsh_ads.")
FORBIDDEN = re.compile(
    r"\b(insert|update|delete|drop|alter|create|truncate|grant|revoke|load|msck)\b", re.I)


def load_env(path=ENV_FILE):
    key = model = base = None
    if os.path.exists(path):
        for line in open(path, encoding="utf-8-sig"):
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            k, v = k.strip(), v.strip().strip('"').strip("'")
            if k == "DEEPSEEK_API_KEY":
                key = v
            elif k == "LLM_MODEL":
                model = v
            elif k == "LLM_BASE_URL":
                base = v
    key = key or os.environ.get("DEEPSEEK_API_KEY")
    return key, model or "deepseek-chat", base or "https://api.deepseek.com"


def llm_call(system_prompt: str, user_prompt: str, temperature: float = 0.0, timeout: int = 60, max_tokens: int = 800):
    key, model, base = load_env()
    if not key:
        raise RuntimeError("未找到 DEEPSEEK_API_KEY，请检查 E:\\hive-project\\.env")

    payload = json.dumps({
        "model": model,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        "temperature": temperature,
        "max_tokens": max_tokens,
    }).encode("utf-8")

    req = urllib.request.Request(base.rstrip("/") + "/chat/completions", data=payload, method="POST")
    req.add_header("Content-Type", "application/json")
    req.add_header("Authorization", f"Bearer {key}")

    with urllib.request.urlopen(req, timeout=timeout) as resp:
        body = json.loads(resp.read().decode("utf-8"))
    return body["choices"][0]["message"]["content"], body.get("usage", {})


def extract_sql(text: str):
    """从模型返回中解析出 sql 与 reason，容错处理 JSON / 代码块 / 裸 SQL。"""
    t = text.strip()
    # 去掉 ```json ... ``` 包裹
    t = re.sub(r"^```(?:json)?\s*", "", t)
    t = re.sub(r"\s*```$", "", t).strip()

    m = re.search(r"\{.*\}", t, re.S)
    if m:
        try:
            obj = json.loads(m.group(0))
            sql = obj.get("sql", "").strip()
            reason = obj.get("reason", "").strip()
            if sql:
                return sql, reason
        except json.JSONDecodeError:
            pass

    # 兜底：直接找 SELECT ... 到语句结尾
    m = re.search(r"(select\b.*?)(?:;|$)", t, re.S | re.I)
    if m:
        return m.group(1).strip(), ""
    return "", ""


def guard(sql: str):
    """返回 (是否通过, 原因)。"""
    s = sql.strip().rstrip(";")
    if not s:
        return False, "SQL 为空"
    if not re.match(r"^select\b", s, re.I):
        return False, "不是 SELECT 语句"
    if FORBIDDEN.search(s):
        return False, "包含被禁止的写操作关键字"
    tables = re.findall(r"\b(?:from|join)\s+([a-zA-Z0-9_]+\.[a-zA-Z0-9_]+)", s, re.I)
    if not tables:
        return False, "未识别的库表名（必须带库名前缀）"
    for t in tables:
        if not any(t.lower().startswith(p) for p in ALLOWED_PREFIXES):
            return False, f"表 {t} 不在允许范围内"
    return True, "OK"


def execute(sql: str, timeout: int = 120):
    """执行 SQL，返回 (表头, 行列表, 原始输出)。"""
    cmd = ["docker", "exec", CONTAINER, "beeline", "--silent=true", "--outputformat=csv2",
           "-u", JDBC, "-e", sql.rstrip(";")]
    t0 = time.time()
    p = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="ignore", timeout=timeout)
    stdout = p.stdout or ""
    stderr = p.stderr or ""
    # 解析只用 stdout；stderr 仅用于识别报错（beeline 的 SLF4J 噪音都在 stderr）
    rows = list(csv.reader(io.StringIO(stdout)))
    rows = [r for r in rows if any(c.strip() for c in r)]
    header = rows[0] if rows else []
    body = rows[1:] if rows else []
    return header, body, stdout + "\n" + stderr


def check_error(out: str):
    """从 beeline 输出里识别错误信息。"""
    for line in out.splitlines():
        if line.startswith("Error:") or "FAILED:" in line:
            return line.strip()[:300]
    return None
