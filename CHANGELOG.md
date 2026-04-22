# Changelog

All notable changes to modora-admin are documented here.

## [2.0.2] - 2026-04-22

### Fixed

- **Report keybind:** `Config.ReportKeybind` set to `false` (or string `'false'`, `nil`, empty string) no longer registers a broken key mapping in FiveM's keybind settings. Previously the string `'false'` was passed through to `RegisterKeyMapping`, causing a dead entry to persist in `citizen/settings.xml`.

### Changed

- Default `Config.ReportKeybind` is now the boolean `false` instead of the string `'false'`. Both remain accepted as "disabled"; valid key names (e.g. `'F7'`) continue to work.

---

## [1.1.0] - 2026-03-10

### Added

- **Heartbeat:** Periodic `GET /stats` to the Modora API so the dashboard shows the server as online. Configure `Config.HeartbeatIntervalSeconds` (default 120). Set to 0 to disable.
- **Moderation Bridge (Discord → Game):** Polls `GET /moderation/pending` for kick/ban/warn actions created from Discord (`/fivem kick`, `/fivem ban`, `/fivem warn`). Executes them in-game and reports back via `POST /moderation/executed`. Configure `Config.ModerationPollIntervalSeconds` (default 30). Set to 0 to disable.
- **In-game warn:** When staff use `/fivem warn` in Discord, the target player receives an orange chat message with the reason.

### Changed

- Description updated to "Modora FiveM Bridge - Reports, heartbeat, moderation sync (kick/ban/warn from Discord)".

---

## [1.09] - (previous)

- Reports, server stats panel, screenshot upload, TXAdmin/ACE permissions.
