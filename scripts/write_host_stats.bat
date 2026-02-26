@echo off
REM Write FXServer process memory to stats_host.txt for Modora Server Stats panel.
REM Run on a schedule (Task Scheduler, every 10 sec) or from txAdmin.
REM Place in: server/resources/modora-admin/scripts/
REM Writes to: server/resources/modora-admin/stats_host.txt

cd /d "%~dp0.."
powershell -NoProfile -Command "& { $out = (Get-Location).Path + '\stats_host.txt'; $p = Get-Process -Name FXServer -ErrorAction SilentlyContinue; if ($p) { $mb = [math]::Round($p.WorkingSet64 / 1MB, 1); Set-Content -LiteralPath $out -Value ('memory_mb=' + $mb) -Encoding ASCII } }"
