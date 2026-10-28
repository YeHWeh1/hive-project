<#
  rebuild_all.ps1  —  Hive 环境一键恢复（幂等：先清空再全量重建）

  用途：
    1) 电脑重启后 hive-server 容器因 pid 文件残留起不来
    2) 容器被误删 / 损坏，ODS、DWD 的表和数据全部消失
    3) 答辩前把环境恢复到确定状态

  用法：
    cd E:\hive-project
    .\scripts\rebuild_all.ps1
    .\scripts\rebuild_all.ps1 -Force      # 跳过 5 秒等待

  注意：会 drop 掉 ydsh_ods / ydsh_dwd 两个库后重新导入，约 2-3 分钟。
#>
param([switch]$Force)

# 关键：docker / beeline 会向 stderr 写日志（SLF4J 警告等），
# 若使用 Stop，PowerShell 会把它当成 NativeCommandError 并中断脚本。
$ErrorActionPreference = 'Continue'

$ProjectDir = Split-Path -Parent $PSScriptRoot
$Container  = 'hive-project-hive-server-1'
$DataDir    = 'E:\界面\模拟数据'
$Jdbc       = 'jdbc:hive2://localhost:10000/'

function Title($t) { Write-Host "`n===== $t =====" -ForegroundColor Cyan }
function Q([string]$sql) {
    (docker exec $Container beeline --silent=true -u $Jdbc -e $sql 2>&1 | Out-String)
}
function Run($f) {
    Write-Host "执行 $f"
    $out = docker exec $Container beeline --silent=true -u $Jdbc -f $f 2>&1 | Out-String
    ($out -split "`n") |
        Where-Object { $_ -match 'FAILED|Error while|rows affected|Loading data to table' } |
        ForEach-Object { Write-Host "    $($_.Trim())" }
    if ($out -match 'FAILED|Error while') { Write-Host '    !! 该脚本报错，请检查' -ForegroundColor Red }
}

Set-Location $ProjectDir

Title '0. 说明'
Write-Host '本脚本会先清空 ydsh_ods / ydsh_dwd，再重新建表、导入、清洗。'
if (-not $Force) {
    Write-Host '5 秒后开始，按 Ctrl+C 可取消 ...'
    Start-Sleep 5
}

Title '1. 检查 Docker'
docker info *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Docker Desktop 未运行，请先启动后重试。' -ForegroundColor Red
    exit 1
}
Write-Host 'Docker 正常'

Title '2. 检查 hive-server 容器'
$status = docker ps -a --filter "name=$Container" --format "{{.Status}}"
if ($status -notmatch '^Up') {
    Write-Host "当前状态: $status  -> 重建容器"
    docker rm -f $Container *> $null
    docker compose up -d hive-server
} else {
    Write-Host "当前状态: $status  -> 无需重建"
}

Title '3. 等待 HiveServer2 就绪（最多 120 秒）'
$ready = $false
for ($i = 1; $i -le 40; $i++) {
    Write-Host ("  第 {0} 次探测 ... " -f $i) -NoNewline
    docker exec $Container beeline --silent=true -u $Jdbc -e 'select 1;' *> $null
    if ($LASTEXITCODE -eq 0) { Write-Host '就绪'; $ready = $true; break }
    Write-Host '未就绪，等 3 秒'
    Start-Sleep 3
}
if (-not $ready) {
    Write-Host 'HiveServer2 未就绪，请执行: docker compose logs --tail 60 hive-server' -ForegroundColor Red
    exit 1
}

Title '4. 清空旧库（保证幂等，避免行数翻倍）'
Q 'drop database if exists ydsh_ods cascade; drop database if exists ydsh_dwd cascade;' | Out-Null
Write-Host '已清空 ydsh_ods / ydsh_dwd'

Title '5. 准备容器内目录并拷贝数据与脚本'
docker exec -u root $Container mkdir -p /sql /data
if (-not (Test-Path $DataDir)) {
    Write-Host "数据目录不存在: $DataDir" -ForegroundColor Red
    exit 1
}
docker cp "$DataDir\." "${Container}:/data/"      | Out-Null
docker cp "$ProjectDir\sql\." "${Container}:/sql/" | Out-Null
Write-Host '拷贝完成'

Title '6. 建表 -> 导入 -> 清洗'
Run '/sql/ods/create_ods.sql'
Run '/sql/ods/load_ods.sql'
Run '/sql/clean/01_clean_user.sql'
Run '/sql/clean/02_clean_product.sql'
Run '/sql/clean/03_dedup_order.sql'

Title '7. 行数与清洗结果校验'
docker exec $Container beeline --silent=true -u $Jdbc -f /sql/ods/91_count_check.sql
docker exec $Container beeline --silent=true -u $Jdbc -f /sql/clean/90_clean_check.sql

Title '完成'
Write-Host '期望结果: ODS 6 张表行数全 OK；DWD 三表 1000 / 600 / 15000。' -ForegroundColor Green