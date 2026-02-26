#!/bin/sh
# Write FXServer process memory to stats_host.txt for Modora Server Stats panel.
# Run on a schedule: */10 * * * * /path/to/write_host_stats.sh
# Place in: server/resources/modora-admin/scripts/
# Writes to: server/resources/modora-admin/stats_host.txt

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="${SCRIPT_DIR}/../stats_host.txt"

# Find FXServer process (FXServer or FXServer.exe)
PID=""
for name in FXServer FXServer.exe; do
  PID=$(pgrep -x "$name" 2>/dev/null | head -1)
  [ -n "$PID" ] && break
done

if [ -z "$PID" ]; then
  exit 0
fi

# VmRSS is in KB (from /proc/PID/status)
if [ -r "/proc/${PID}/status" ]; then
  RSS=$(grep -E '^VmRSS:' "/proc/${PID}/status" | awk '{print $2}')
  if [ -n "$RSS" ] && [ "$RSS" -ge 0 ] 2>/dev/null; then
    MB=$(echo "scale=1; $RSS / 1024" | bc 2>/dev/null || echo "$((RSS / 1024))")
    echo "memory_mb=$MB" > "$OUT"
  fi
fi
