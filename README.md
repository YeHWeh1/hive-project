# 云购生活新零售企业 —— 企业级数据仓库与经营分析可视化系统

> 课程：企业项目实战实训　阶段：第 1 周（项目启动 · 环境搭建 · Git 基础 · 数据导入 · 数据清洗一）

## 一、团队信息

| 项目 | 内容 |
|---|---|
| 队名 | 【待填：队名】 |
| 成员 | 【待填：成员姓名】 |
| 口号 | 【待填：口号】 |

## 二、角色分工

| 角色 | 姓名 | 主要职责 |
|---|---|---|
| 项目经理 | 【待填】 | 进度把控、任务拆分、文档汇总、答辩组织 |
| 数据工程师 | 【待填】 | Docker/Hive/MySQL 环境搭建、ODS 建表与数据导入 |
| 数据分析师 | 【待填】 | 数据质量五维度评估、缺失值与重复值清洗、指标口径定义 |
| 可视化工程师 | 【待填】 | 数据探索、图表与看板设计（第 4 周开展） |

> 说明：如成员少于 4 人，可按「一人多岗」填写，清单允许该形式。

## 三、项目目标

基于「云购生活」新零售业务数据，构建 **ODS → DWD → DWS → ADS** 四层数据仓库，并在其上完成经营分析可视化系统，形成「接数据 → 查质量 → 做清洗 → 出指标 → 上可视化」的完整闭环。

## 四、阶段计划

| 周次 | 主题 | 关键产出 |
|---|---|---|
| 第 1 周 | 环境搭建 / 数据导入 / 清洗（一） | Docker+Hive 环境、ODS 6 表、质量预评估表、缺失值与去重脚本 |
| 第 2 周 | 清洗进阶 / 数仓建模 / 探索分析 | DWD 明细层建模、DWS 汇总层、探索性分析 |
| 第 3 周 | 分析 / 预测 / AI 协同 | 经营指标分析、简单预测模型、AI 协同记录 |
| 第 4 周 | 可视化 / 部署 | 看板与图表、系统部署 |
| 第 5 周 | 整合 / 文档 / 答辩 | 项目文档、答辩材料 |

## 五、技术栈

| 层次 | 技术 |
|---|---|
| 容器与编排 | Docker Desktop（WSL2 backend）、Docker Compose v2 |
| 数据存储 | Hive 4.0.0（Metastore + HiveServer2）、MySQL 8.0 |
| 查询引擎 | Hive SQL（Tez 执行引擎） |
| 数据处理 | Hive SQL：建表 / LOAD DATA / 窗口函数 / CTAS |
| 版本管理 | Git + GitHub（SSH over 443） |
| 文档与交付 | Markdown、Excel（openpyxl） |

## 六、数据说明

`模拟数据/` 下共 6 个 CSV（UTF-8，逗号分隔，含表头），已通过 `.gitignore` 排除，不纳入版本库：

| 表名 | 业务含义 | 行数 |
|---|---|---|
| ods_user | 用户维度 | 1000 |
| ods_product | 商品维度 | 600 |
| ods_store | 门店维度 | 60 |
| ods_order | 订单事实 | 15600 |
| ods_order_item | 订单明细 | 37549 |
| ods_user_behavior | 用户行为 | 60000 |

## 七、目录结构

```
hive-project/
├── docker-compose.yml          # Hive + MySQL 编排
├── README.md
├── .gitignore                  # 排除数据、密钥、日志
├── sql/
│   ├── ods/
│   │   ├── create_ods.sql      # 建库 + 6 张表
│   │   ├── load_ods.sql        # 6 个 CSV 导入
│   │   ├── 01~06_create_*.sql  # 分表建表脚本
│   │   ├── 91_count_check.sql  # 行数校验
│   │   ├── 92_quality_check.sql# 五维度扫描
│   │   └── 93_spot_check.sql   # 关键指标抽查
│   └── clean/
│       ├── 01_clean_user.sql   # age 均值填充 + email 缺失标记
│       ├── 02_clean_product.sql# 上架日期补全
│       ├── 03_dedup_order.sql  # ROW_NUMBER 去重
│       └── 90_clean_check.sql  # 清洗结果校验
├── scripts/
│   └── rebuild_all.ps1         # 环境一键恢复
├── docs/
│   ├── 环境搭建笔记.md
│   ├── 数据质量预评估表.xlsx
│   └── screenshots/
└── 模拟数据/                    # 6 个 CSV（不入库）
```

## 八、环境启动与验证

```powershell
# 1. 启动三容器
docker compose up -d
docker compose ps                     # 期望 mysql / metastore / hive-server 均 Up

# 2. 导入 ODS 层
docker exec -u root hive-project-hive-server-1 mkdir -p /sql /data
docker cp "模拟数据\." hive-project-hive-server-1:/data/
docker cp ".\sql\."  hive-project-hive-server-1:/sql/
docker exec hive-project-hive-server-1 beeline -u "jdbc:hive2://localhost:10000/" -f /sql/ods/create_ods.sql
docker exec hive-project-hive-server-1 beeline -u "jdbc:hive2://localhost:10000/" -f /sql/ods/load_ods.sql

# 3. 行数校验（6 行全 OK 即通过）
docker exec hive-project-hive-server-1 beeline -u "jdbc:hive2://localhost:10000/" -f /sql/ods/91_count_check.sql

# 4. 清洗
docker exec hive-project-hive-server-1 beeline -u "jdbc:hive2://localhost:10000/" -f /sql/clean/01_clean_user.sql
docker exec hive-project-hive-server-1 beeline -u "jdbc:hive2://localhost:10000/" -f /sql/clean/02_clean_product.sql
docker exec hive-project-hive-server-1 beeline -u "jdbc:hive2://localhost:10000/" -f /sql/clean/03_dedup_order.sql

# 5. 清洗结果校验
docker exec hive-project-hive-server-1 beeline -u "jdbc:hive2://localhost:10000/" -f /sql/clean/90_clean_check.sql
```

## 九、当前进度（第 1 周）

| 交付物 | 状态 |
|---|---|
| Docker / Hive / MySQL 环境可运行 | ✅ 三容器 Up，beeline 可连 |
| ODS 层 6 张表 + 数据导入 | ✅ 行数校验全 OK |
| 数据质量五维度预评估 | ✅ `docs/数据质量预评估表.xlsx` |
| 缺失值处理 | ✅ `age` 均值填充、`email` 与 `launch_date` 标记/补全 |
| 重复值去重 | ✅ `ods_order` 15600 → `dwd_order` 15000 |
| Git 仓库与规范提交 | ✅ 提交信息遵循 `feat:` / `fix:` / `docs:` / `chore:` |