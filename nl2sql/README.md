# NL2SQL 自然语言查询接口

把「用中文提问」转换成「可执行的 Hive SQL 并返回结果」的最小可用实现。

## 快速使用

```powershell
cd E:\hive-project
.\.venv\Scripts\python.exe -m nl2sql.main "2024 年 6 月的 GMV 是多少"
.\.venv\Scripts\python.exe -m nl2sql.main --interactive     # 交互模式
.\.venv\Scripts\python.exe -m nl2sql.main --sql-only "..."  # 只生成 SQL
.\.venv\Scripts\python.exe -m nl2sql.tests                  # 跑 10 题测试集
```

示例输出：

```
问题： 各会员等级的客单价是多少
思路： 按会员等级分组，用有效订单汇总 GMV 与订单量并计算客单价
SQL：
SELECT ml.level_name, ROUND(SUM(f.pay_amount), 2) AS gmv, ...
FROM ydsh_dwd.fact_order f
JOIN ydsh_dwd.dim_user u ON f.user_id = u.user_id
JOIN ydsh_dwd.dim_member_level ml ON u.member_level_code = ml.level_code
WHERE f.amount_invalid = 0
GROUP BY ml.level_name ORDER BY aov DESC
+---------------+------------+--------+---------+
| ml.level_name | gmv        | orders | aov     |
+---------------+------------+--------+---------+
| 普通会员       | 8943794.11 | 3546   | 2522.22 |
...
```

## 架构

```
用户提问
   ↓
prompts.SYSTEM（含 Schema 描述 + 口径说明 + few-shot 示例）
   ↓
engine.llm_call → DeepSeek Chat API（temperature=0，输出 JSON）
   ↓
engine.extract_sql（兼容 JSON / ```sql 代码块 / 裸 SQL）
   ↓
engine.guard（白名单校验：只允许 SELECT、表名必须带 ydsh_ 前缀、禁写操作）
   ↓
engine.execute（docker exec beeline --outputformat=csv2）
   ↓
结果表 + 耗时 + token 用量
```

失败自动重试一次：把 beeline 的报错信息回传给模型，让它修正 SQL。

## 模块说明

| 文件 | 职责 |
|---|---|
| `schema_loader.py` | 对 16 张表执行 `describe`，解析字段名/类型/注释，缓存到 `schema.json` |
| `prompts.py` | 系统提示词：Schema + 业务口径 + 3 个 few-shot 示例 |
| `engine.py` | 大模型调用、SQL 提取、白名单校验、beeline 执行、错误识别 |
| `main.py` | 命令行入口（单次提问 / 交互模式 / 只出 SQL） |
| `tests.py` | 10 题测试集，统计通过率与耗时，输出 `test_results.csv` |

## Prompt 设计的 5 条约束

1. **只允许 SELECT**，禁止 INSERT/UPDATE/DELETE/DROP 等（提示词 + 代码双重校验）
2. **表名必须带库前缀**（`ydsh_dwd.` / `ydsh_dws.` / `ydsh_ads.`），防止编造
3. **输出 JSON**（`{"sql": ..., "reason": ...}`），便于程序解析
4. **注入业务口径**：有效订单 `amount_invalid = 0`、品类销售额必须走明细表 `item_amount`
5. **注入维表字段名**：`dim_member_level(level_code, level_name)` 等，避免模型猜字段

## 关键坑（已解决）

| 问题 | 后果 | 解决 |
|---|---|---|
| Schema 只含 6 张主表，没放枚举维表 | 模型猜字段名（`member_level_name`），SQL 编译失败却被当成"无结果" | 把 4 张枚举维表加入 schema，并在 prompt 里列出固定字段名 |
| beeline 编译错误打在 stderr，代码只读 stdout | 失败被静默吞掉，误判为"查询无结果" | 合并 stderr 做错误识别，但**只用 stdout 解析结果** |
| 提示词未限制相对时间 | 模型生成 `current_date()` 导致查空 | 明确「数据仅 2024 年，禁用 current_date，上个月一律换算成具体月份」 |

## 测试结果

10 个典型问题，**通过 10/10（100%）**，平均耗时 5.95 秒（含模型 1~2 秒 + Hive 执行 3~4 秒）。
明细见 `test_results.csv`。
