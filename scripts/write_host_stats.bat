@echo off
REM Write FXServer process memory and CPU usage to stats_host.txt for Modora Server Stats panel.
REM Run on a schedule (Task Scheduler, every 10 sec) or from txAdmin.
REM Place in: server/resources/modora-admin/scripts/
REM Writes to: server/resources/modora-admin/stats_host.txt

setlocal enabledelayedexpansion

cd /d "%~dp0.."

set "OUT=stats_host.txt"
set "MEM_BYTES="
set "MEM_MB="
set "CPU_PCT="

REM Read WorkingSetSize (bytes) for FXServer.exe
for /f "tokens=2 delims==" %%A in ('
  wmic process where "name='FXServer.exe'" get WorkingSetSize /value 2^>nul ^| find "="
') do (
  set "MEM_BYTES=%%A"
)

if defined MEM_BYTES (
  set /a MEM_KB=MEM_BYTES/1024
  set /a MEM_MB=MEM_KB/1024
)

REM Read PercentProcessorTime for FXServer process (may aggregate multiple instances)
for /f "tokens=2 delims==" %%A in ('
  wmic path Win32_PerfFormattedData_PerfProc_Process where "Name like 'FXServer%%'" get PercentProcessorTime /value 2^>nul ^| find "="
') do (
  set "CPU_PCT=%%A"
)

> "%OUT%" (
  if defined MEM_MB echo memory_mb=!MEM_MB!
  if defined CPU_PCT echo cpu_percent=!CPU_PCT!
)

endlocal
