Config = {}

-- ============================================
-- API CONFIGURATION (REQUIRED)
-- ============================================
-- API token from the Modora dashboard (FiveM → your server → API Credentials).
Config.APIToken = ''

-- ============================================
-- REPORT COMMAND & KEYBIND
-- ============================================
Config.ReportCommand = 'report'
Config.ReportKeybind = 'false' -- Or F7 as example

-- ============================================
-- NEARBY PLAYERS SETTINGS
-- ============================================
Config.NearbyRadius = 30.0 -- Radius in meters for nearby players detection
Config.MaxNearbyPlayers = 5 -- Maximum number of nearby players to show

-- ============================================
-- SERVER STATS PANEL (/serverstats)
-- ============================================
-- Command to open the server stats panel (memory, last 5 errors). Restricted by TXAdmin permission.
Config.ServerStatsCommand = 'serverstats'
-- TXAdmin permission required to open the panel (e.g. 'console.view', 'all_permissions'). Set in TXAdmin Admin Manager.
Config.ServerStatsTxAdminPermission = 'console.view'
-- Path to txAdmin admins.json. Use forward slashes only.
-- If FXServer can't read this path (e.g. G: not available to the process), copy admins.json into the modora-admin resource folder and we'll use that.
Config.ServerStatsTxAdminAdminsPath = ''
-- If TXAdmin is not running, allow server stats for nobody (false) or everyone (true). Default: false.
Config.ServerStatsAllowWithoutTxAdmin = true
-- Optional: grant via ACE in server.cfg e.g. add_ace group.admin modora.serverstats allow (checked first).
Config.ServerStatsAcePermission = 'modora.serverstats'
-- Server Stats panel gets process RAM and CPU from the OS (Linux: /proc/self, Windows: tasklist).
-- Optionally also run the helper scripts in scripts/ to write stats_host.txt (for external panels/txAdmin widgets).
-- How often to run the helper script in the background (seconds). Set to 0 to disable periodic runs.
Config.HostStatsUpdateIntervalSeconds = 2
-- Also run the helper script immediately when /serverstats is used (true/false).
Config.HostStatsRunOnServerStatsCommand = true

-- ============================================
-- HEARTBEAT (Dashboard "online" status)
-- ============================================
-- Send heartbeat to Modora every N seconds (GET /stats). Set to 0 to disable.
Config.HeartbeatIntervalSeconds = 120

-- ============================================
-- MODERATION (Discord → Game: poll pending kick/ban/warn)
-- ============================================
-- Poll for pending actions every N seconds. Set to 0 to disable.
Config.ModerationPollIntervalSeconds = 30

-- ============================================
-- STAFF PANEL (/mstaff or F6)
-- ============================================
-- Enable/disable the in-game staff panel entirely. Set to false to hide it from all players.
Config.StaffPanelEnabled = true
-- Command to open the staff panel. Set to false to disable the command (keybind still works if set).
Config.StaffPanelCommand = 'mstaff'
-- Keybind to open the staff panel. Set to 'false' to disable. Examples: 'F6', 'F8', 'HOME'.
Config.StaffPanelKeybind = 'F6'
-- ACE permission required to open the staff panel.
-- Grant in server.cfg: add_ace group.admin modora.staff allow
-- Or per player: add_ace identifier.discord:123456 modora.staff allow
Config.StaffPanelAcePermission = 'modora.staff'
-- If true, also allow players who have ServerStats permission (TXAdmin/ACE) to use the staff panel.
-- If false, ONLY the StaffPanelAcePermission ACE is checked (strictest).
Config.StaffPanelFallbackToStatsPermission = true
-- Enable in-game notifications for staff (e.g. new high-severity reports). Requires staff permission.
Config.StaffNotificationsEnabled = true
-- How often to check for new reports to notify staff (seconds). Set to 0 to disable.
Config.StaffNotificationIntervalSeconds = 60

-- ============================================
-- LOCALE & LOGGING
-- ============================================
Config.Debug = true
Config.Locale = 'en'  -- 'nl' or 'en'

-- Locale messages are loaded from shared/locales/*.lua into the global Locales table.
-- Config.Messages is kept as a fallback for users who added custom keys in config.lua.
Config.Messages = Config.Messages or {}

Locales = Locales or {}

function GetMessage(key)
    local locale = Config.Locale or 'en'
    -- Check shared/locales first, then Config.Messages fallback
    if Locales[locale] and Locales[locale][key] then
        return Locales[locale][key]
    end
    if Locales['en'] and Locales['en'][key] then
        return Locales['en'][key]
    end
    if Config.Messages[locale] and Config.Messages[locale][key] then
        return Config.Messages[locale][key]
    end
    if Config.Messages['en'] and Config.Messages['en'][key] then
        return Config.Messages['en'][key]
    end
    return key
end
