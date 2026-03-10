# Changelog

All notable changes to modora-admin are documented here.

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
