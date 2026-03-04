# Modora FiveM Admin

Version: 1.0.9  
Author: ModoraLabs

FiveM resource: **Reports + Server Stats** — in‑game report form → Discord ticket, plus `/serverstats` panel for RAM/CPU + last errors.

## Install

1. Clone or download this repo. **Rename the folder to `modora-admin`** (the FiveM resource name is the folder name).
2. Place the `modora-admin` folder in your server `resources` directory.
3. Add to `server.cfg`:
   ```cfg
   ensure modora-admin
   ```
4. Configure `config.lua` with your API token (from Modora Dashboard → FiveM → your server).

## Features

- **Reports:** `/report` (or keybind) opens the report form; submissions create Discord tickets.
- **Server stats panel:** `/serverstats` (configurable) shows:
  - FXServer uptime, player count, started resources
  - Lua process memory
  - Optional **host RAM + CPU** (from OS / helper script)
  - Last 5 server errors pushed via `exports['modora-admin']:PushServerError('message')`

## Basic configuration

```lua
-- API
Config.ModoraAPIBase = 'http://api.modoralabs.com'
Config.APIToken      = 'your_api_token_here'

-- Report command / keybind
Config.ReportCommand = 'report'
Config.ReportKeybind = 'F7'     -- or 'false' to disable keybind

-- Nearby players selector
Config.NearbyRadius      = 30.0
Config.MaxNearbyPlayers  = 5

-- Locale + debug
Config.Locale = 'en'      -- 'en' or 'nl'
Config.Debug  = false     -- set true when troubleshooting
```

## Server stats panel (`/serverstats`)

### Command + permissions

```lua
-- Chat command that opens the panel
Config.ServerStatsCommand = 'serverstats'

-- Permission checks (in this order):
Config.ServerStatsAcePermission        = 'modora.serverstats' -- ACE (server.cfg) e.g. add_ace group.admin modora.serverstats allow
Config.ServerStatsTxAdminPermission    = 'console.view'       -- txAdmin permission name
Config.ServerStatsAllowWithoutTxAdmin  = false                -- if true, allow even when txAdmin/monitor are not present
```

If a player fails all checks, they see a “no permission” message and the panel does not open.

### txAdmin `admins.json` lookup

The resource needs read access to txAdmin’s `admins.json` to resolve permissions when txAdmin exports are not available:

```lua
-- Preferred: let txAdmin tell us where txData is.
Config.ServerStatsTxAdminAdminsPath = ''
```

With this empty value the script will:

- Read the `txDataPath` convar (set by txAdmin) and use `<txDataPath>/admins.json`, **or**
- Fall back to a local `admins.json` in the resource root (recommended for Windows dev installs):
  - Copy `G:\txData\admins.json` (or your server’s `txData/admins.json`) into the `modora-admin` folder as:
    - `resources/modora-admin/admins.json`

If `admins.json` cannot be read or parsed and `Config.Debug = true`, the server console will log a detailed error.

### Host RAM / CPU sources

The `/serverstats` panel shows three kinds of memory/CPU:

- **Lua process memory** (always): from `collectgarbage('count')`.
- **Host RAM / CPU (internal)**:
  - Linux: `/proc/self/status` and `/proc/self/stat`
  - Windows: `tasklist` / `wmic` / PowerShell via the built‑in logic in `server/main.lua`
- **Host RAM / CPU (external helper)**:
  - If a `stats_host.txt` file exists in the resource root, its values override the internal host stats:
    - `memory_mb=<number>`
    - `cpu_percent=<number>`

The panel labels host memory as `NNN MB` and shows CPU as `NN%`. When `stats_host.txt` was produced by the internal Lua fallback instead of an external script, it will mark host memory as `(Lua)` in the NUI for clarity.

### Auto‑updating host stats

```lua
-- How often to refresh host stats from inside the resource (seconds). Set to 0 to disable.
Config.HostStatsUpdateIntervalSeconds = 60

-- Also refresh host stats immediately when `/serverstats` is used.
Config.HostStatsRunOnServerStatsCommand = true
```

When `HostStatsUpdateIntervalSeconds > 0`, a server thread will periodically recompute host stats and/or read `stats_host.txt` and push the values into the panel.

If you prefer to drive host stats **only** from an external script (e.g. Windows Task Scheduler or cron), set:

```lua
Config.HostStatsUpdateIntervalSeconds   = 0
Config.HostStatsRunOnServerStatsCommand = false
```

In that mode the resource never tries to compute host stats, it only reads `stats_host.txt` if present.

### Helper scripts for `stats_host.txt`

The `scripts/` folder contains optional helpers you can schedule outside of FXServer:

- `scripts/write_host_stats.sh` (Linux)
- `scripts/write_host_stats.bat` (Windows)

Both write into `stats_host.txt` in the resource root with the format:

```text
memory_mb=290
cpu_percent=15
```

Example scheduling:

- **Linux cron** (every 10 seconds):

  ```cron
  */1 * * * * /path/to/server/resources/modora-admin/scripts/write_host_stats.sh
  ```

- **Windows Task Scheduler**:
  - **Action → Start a program**
    - **Program/script**: `G:\txData\Qbox_8D623E.base\resources\modora-admin-1.08\scripts\write_host_stats.bat`
    - **Start in (optional)**: `G:\txData\Qbox_8D623E.base\resources\modora-admin-1.08\scripts`
    - **Arguments**: *(leave empty)*
  - **Trigger**: repeat task every 10–60 seconds, as desired.

With either method running, the `/serverstats` panel will display live host RAM/CPU using the values written into `stats_host.txt`.

## NUI (report form)

- **Lua → NUI:** `openReport` with optional `INIT` (serverName, cooldownRemaining, playerName, version); `reportSubmitted` (success, ticketNumber, ticketId, ticketUrl, error, cooldownSeconds).
- **NUI → Lua:** `closeReport`, `requestPlayerData`, `requestServerConfig`, `submitReport` (category, subject, description, priority, reporter, targets, attachments, evidenceUrls).

## Support

- Discord: https://discord.gg/modora
- Website: https://modora.xyz
- Docs: https://modora.xyz/docs
- GitHub: https://github.com/ModoraLabs/modora-admin
