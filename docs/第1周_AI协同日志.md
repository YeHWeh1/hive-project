# 第 1 周 AI 协同日志

- 团队：【待填：队名】　成员：【待填：成员姓名】　填写日期：2026-10-28

---

## 一、使用的 AI 工具 / 模型

- 工具名称：DeepSeek（DeepSeek Harness 桌面客户端）　模型版本：deepseek-flash
- 辅助：GitHub Copilot（少量代码补全）、Windows PowerShell 5.1 + Docker Desktop

---

## 二、AI 协同记录表

| 序号 | 提问 / 任务描述 | AI 产出摘要 | 人工修改与验证 | 是否采纳 |
|------|----------------|-------------|----------------|----------|
| 1 | Docker 拉取 `mysql:8.0` 卡在 Pulling 约 17 分钟，是否卡死？ | 说明 compose TTY 进度会折叠每层下载，给出判据：另开窗口 `docker pull` 看分层进度、`docker system df` 比对体积 | 实测另开窗口可见分层下载，最终 1103 秒完成，确认是网络慢而非卡死 | 是 |
| 2 | `docker compose up -d` 报 `ports are not available: 0.0.0.0:3306` | 给出 `netstat -ano` 查 PID、`Get-Process` 认进程的排查路径 | 执行后发现同一 PID 同时监听 3306 与 33060，据 33060 判定为本机 MySQL 8；停服务并改手动启动后容器正常启动 | 是 |
| 3 | GitHub SSH 报 `connect to host github.com port 22: Connection refused` | 判定 22 端口被网络封锁，给出改走 `ssh.github.com:443` 的 `~/.ssh/config` 方案 | TCP 连通性测试证实 22 不通、443 通；配置后 `ssh -T` 返回 `Hi liuwu-123!` | 是 |
| 4 | `git push` 报 `Could not create directory '/c/Users/\301\365\265t...'` 与 `Permission denied (publickey)` | 判断中文用户名被按 GBK 拆解导致 MSYS 版 ssh 找不到 `.ssh`，建议 `core.sshCommand` 指向 Windows 自带 OpenSSH | 按建议调用 `ssh -T` 先验证通过，再执行 `git push` 成功 | 是 |
| 5 | `docker cp` 输出 Successfully 但容器内 `/sql` 不存在 | 指认 docker cp 在目标多级父目录不存在时"假成功"，要求先 `mkdir -p` 再拷并 `ls` 复查 | 复现确认，改为先建目录后逐文件拷贝，`ls` 看到 10 个 sql 文件 | 是 |
| 6 | 重启电脑后 hive-server 报 `Exited (1)`，日志 `HiveServer2 running as process 7` | 解释容器内 pid 文件残留导致误判，结论是"容器只能新建不能重启"，给 `docker rm -f` + `up -d` 方案 | 实测重建后恢复；进一步把「重建 → 建表 → 导入 → 清洗」脚本化为 `rebuild_all.ps1` | 是 |
| 7 | 15 条统计放进一个 `union all` 报 `Too many counters: 121 max=120` | 说明 Tez 计数器按 union 分支累加，建议 `set tez.counters.max=2000` 并拆成每组 ≤6 个 union | 拆为 3 组后 15 项指标全部返回，数值与质检表逐一对上 | 是 |
| 8 | 按 6 个 CSV 的实际表头生成 ODS 建表与导入脚本 | 给出 6 张表 DDL（金额用 `decimal(12,2)`、日期用 `string` 贴源保留）、`load data local inpath` 与行数校验 | 人工核对表头列序与类型后执行，6 张表行数与数据字典完全一致 | 是 |
| 9 | 把恢复流程写成 `rebuild_all.ps1` | 产出 PowerShell 脚本，含容器检查、就绪等待、清空重建、校验 | 首次运行被 `NativeCommandError` 中断，改为 `Continue` 修复；随后 AI 建议加 `--silent=true` 抑制噪音，实测导致就绪探测匹配不到 `1 row selected`，于是**未采纳该建议**，改回按退出码判断 | 部分采纳 |

---

## 三、AI 产出成果清单

- **由 AI 生成**：6 张 ODS 表的 DDL 与导入脚本、行数校验与五维度扫描 SQL、缺失值/去重 SQL、`rebuild_all.ps1` 初版、README 与本文档初稿、数据质量预评估表生成脚本。
- **由人工编写**：`docker-compose.yml`（依据课程手册）、项目目录结构与命名、端口与进程排查命令、最终运行验证步骤。
- **人机协作完成**：环境排障（AI 给方向、人工执行验证）、脚本命名与清单对齐、质量预评估表口径确认、截图与文档整理。

---

## 四、问题与解决

- **遇到的问题**：环境层面遇到 6 类问题——镜像拉取慢、端口冲突、22 端口封锁、中文路径导致密钥失效、`docker cp` 假成功、容器重启失败；数据处理层面遇到 1 类——Tez 计数器上限。
- **AI 是否有效解决**：6/7 直接有效。第 9 条中 AI 给出的 `--silent=true` 建议反而破坏了就绪探测，属"有帮助但需验证"。
- **最终如何解决**：每个方案都先做最小验证（`ssh -T`、`docker pull`、`ls`、`show databases`）再落地；把可复现的修复步骤脚本化，避免下次重蹈。

---

## 五、反思与总结

- **AI 协同带来的价值**：把"看报错猜原因"变成"按现象定位机制"。例如 `\301\365\265t` 这类乱码，人工很难快速联想到 GBK 拆解与 MSYS 路径解析；AI 直接指出根因，省去大量试错。
- **AI 的局限与风险**：① 会给出"看起来合理但实测有副作用"的建议（`--silent=true` 就是例子）；② 对本机环境的隐含假设可能不成立（如默认 `powershell` 在 PATH 中，实际不在）；③ 生成的 SQL 需人工核对字段类型与业务口径。
- **本次协作中我的能力提升**：学会用 TCP 连通性与端口归属做二分定位；理解了 Hive 4 中 `union all` 与 Tez 计数器的关系；掌握了"容器重建 + 脚本化恢复"的运维思路。
- **对 AI 协同的改进建议**：让 AI 每给一步方案就附带"如何验证"的命令，形成「建议 → 验证 → 采纳/否决」的闭环；对涉及破坏性操作（drop、rm -f）的方案必须人工复核后再执行。