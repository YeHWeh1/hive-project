<#
  rebuild_all.ps1  —  Hive 环境一键恢复
  用途：电脑重启、容器损坏后，重建 hive-server 容器并重新导入 ODS / DWD 全部数据
  用法：cd E:\hive-project
        powershell -ExecutionPolicy Bypass -File .\scripts\rebuild_all.ps1
#>

$ErrorActionPreference = 'Stop'
$ProjectDir = Split-Path -Parent $PSScriptRoot
$Container  = 'hive-project-hive-server-1'
$DataDir    = 'E:\界面\模拟数据'
$Jdbc       = 'jdbc:hive2://localhost:10000/'

function Title($t) { Write-Host "`n===== $t =====" -ForegroundColor Cyan }
function Run($f) {
    Write-Host "执行 $f"
    docker exec $Container beeline -u $Jdbc -f $f 2>&1 |
        Select-String -Pattern 'FAILED|Error while|rows affected|errors' |
        ForEach-Object { Write-Host "    $($_.Line.Trim())" }
}

Set-Location $ProjectDir

Title '1. 检查 Docker'
docker info *> $null
if ($LASTEXITCODE -ne 0) { throw 'Docker Desktop 未运行，请先启动 Docker Desktop。' }

Title '2. 检查 hive-server 容器'
$status = docker ps -a --filter "name=$Container" --format "{{.Status}}"
if ($status -notmatch '^Up') {
    Write-Host "当前状态: $status  -> 重建容器"
    docker rm -f $Container *> $null
    docker compose up -d hive-server
} else {
    Write-Host "当前状态: $status  -> 无需重建"
}

Title '3. 等待 HiveServer2 就绪（最多 90 秒）'
$ready = $false
for ($i = 1; $i -le 30; $i++) {
    $out = docker exec $Container beeline -u $Jdbc -e 'select 1;' 2>&1
    if ($out -match '1 row selected') { $ready = $true; Write-Host "已就绪（第 $i 次探测）"; break }
    Start-Sleep 3
}
if (-not $ready) { throw 'HiveServer2 未就绪，请执行: docker compose logs --tail 60 hive-server' }

Title '4. 准备容器内目录'
docker exec -u root $Container mkdir -p /sql /data

Title '5. 拷贝数据与脚本'
if (-not (Test-Path $DataDir)) { throw "数据目录不存在: $DataDir" }
docker cp "$DataDir\." "${Container}:/data/"
docker cp "$ProjectDir\sql\." "${Container}:/sql/"

Title '6. 建表 -> 导入 -> 清洗'
Run '/sql/ods/create_ods.sql'
Run '/sql/ods/load_ods.sql'
Run '/sql/clean/01_clean_user.sql'
Run '/sql/clean/02_clean_product.sql'
Run '/sql/clean/03_dedup_order.sql'

Title '7. 行数与清洗结果校验'
docker exec $Container beeline -u $Jdbc -f /sql/ods/91_count_check.sql
docker exec $Container beeline -u $Jdbc -f /sql/clean/90_clean_check.sql

Title '完成'
Write-Host '期望结果: ODS 6 张表行数全 OK；DWD 三表 1000 / 600 / 15000。' -ForegroundColor Green