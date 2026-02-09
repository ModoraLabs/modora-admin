# Modora FiveM Admin

Version: 1.0.5  
Author: ModoraLabs

One resource: **Reports** (in-game report → Discord ticket) and **Moderation bridge** (bans, whitelist, command queue from Modora Dashboard).

## Install

1. Clone or download this repo. **Rename the folder to `modora-admin`** (the FiveM resource name is the folder name). If the repo is still named `modora-reports`, rename the repository to `modora-admin` on GitHub and clone again, or rename the local folder after cloning.
2. Place the `modora-admin` folder in your server `resources` directory.
3. Add to `server.cfg`:
   ```cfg
   ensure modora-admin
   ```
4. Configure `config.lua` with your API token (from Modora Dashboard → FiveM → your server).

## Features

- **Reports:** `/report` (or keybind) opens the report form; submissions create Discord tickets.
- **Moderation:** Dashboard staff can kick, ban, tempban, unban, warn, whitelist add/remove. Commands are polled by this resource; bans/whitelist are enforced on `playerConnecting`.

## Configuration

```lua
Config.ModoraAPIBase = 'http://api.modora.xyz'
Config.APIToken = 'your_api_token_here'
Config.ReportCommand = 'report'
Config.ReportKeybind = 'F7'
Config.NearbyRadius = 30.0
Config.MaxNearbyPlayers = 5
Config.Locale = 'en'
Config.Debug = false

-- Moderation (same API token)
Config.ModerationEnabled = true
Config.PollIntervalSeconds = 10
Config.WhitelistOnly = false   -- true = only whitelisted identifiers can join
Config.ConnectPolicy = 'fail_closed'
```

Optional convars in `server.cfg`:

```cfg
set modora_api_base "http://api.modora.xyz"
set modora_api_token "your_token"
set modora_moderation_poll_interval 10
set modora_moderation_whitelist_only 0
set modora_moderation_connect_policy "fail_closed"
```

If you use an IP for the API base, set the Host header:

```lua
Config.ModoraHostHeader = 'api.modora.xyz'
```

Restart after config changes:

```
restart modora-admin
```

**API base:** Gebruik alleen `https://api.modora.xyz` (of `http://api.modora.xyz`) of het IP van de server + `ModoraHostHeader = 'api.modora.xyz'`. Geen path-based URL. Bij 404: zet `Config.Debug = true`, herstart en controleer de gelogde URL.

## NUI (report form)

- **Lua → NUI:** `openReport` with optional `INIT` (serverName, cooldownRemaining, playerName, version); `reportSubmitted` (success, ticketNumber, ticketId, ticketUrl, error, cooldownSeconds).
- **NUI → Lua:** `closeReport`, `requestPlayerData`, `requestServerConfig`, `submitReport` (category, subject, description, priority, reporter, targets, attachments, evidenceUrls).

## TXAdmin sync (optional)

To merge bans/whitelist from TXAdmin with Modora, set in `config.lua`:

- `Config.TXAdminBaseUrl` – e.g. `'http://127.0.0.1:40120'` (your TXAdmin port).
- `Config.TXAdminToken` – leave empty unless your TXAdmin API requires it. Many versions do not use a token for local requests. If required, check txAdmin Web Panel → Settings/Advanced or the [txAdmin repo](https://github.com/tabarra/txAdmin) for API/auth docs.
- Adjust `TXAdminBansPath` / `TXAdminWhitelistPath` if your txAdmin version uses different API paths.

## Moderation exports (optional)

- `exports['modora-admin']:getBanCache()` – current ban list.
- `exports['modora-admin']:getWhitelistCache()` – current whitelist.

## Support

- Discord: https://discord.gg/modora
- Website: https://modora.xyz
- Docs: https://modora.xyz/docs
- GitHub: https://github.com/ModoraLabs/modora-admin
