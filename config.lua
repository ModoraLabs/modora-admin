Config = {}

-- ============================================
-- API CONFIGURATION (REQUIRED)
-- ============================================
-- API base URL (no trailing slash). Use hostname or IP; when using IP, set ModoraHostHeader.
Config.ModoraAPIBase = 'http://api.modoralabs.com'

-- Host header when using an IP as base URL. Leave empty when using hostname.
Config.ModoraHostHeader = ''

-- API token from the Modora dashboard (FiveM → your server → API).
Config.APIToken = 'fivem_XjtuPzTWLVMhZMkMKSY4Yre8DXLEInPyw4ahC7p50NC8mYRy'

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
Config.ServerStatsTxAdminAdminsPath = 'G:/txData/admins.json'
-- If TXAdmin is not running, allow server stats for nobody (false) or everyone (true). Default: false.
Config.ServerStatsAllowWithoutTxAdmin = true
-- Optional: grant via ACE in server.cfg e.g. add_ace group.admin modora.serverstats allow (checked first).
Config.ServerStatsAcePermission = 'modora.serverstats'
-- Optional: file name (inside this resource folder) from which to read actual host RAM/CPU.
-- FiveM server sandbox blocks io.popen and io.open outside resources, so process memory must be written by an external script.
-- Use scripts/write_host_stats.bat (Windows) or write_host_stats.sh (Linux); run every 10 sec (Task Scheduler / cron).
-- Leave empty ('') to show Lua memory only.
Config.ServerStatsHostStatsFile = 'stats_host.txt'

-- ============================================
-- LOCALE & LOGGING
-- ============================================
Config.Debug = true
Config.Locale = 'en'  -- 'nl' or 'en'

Config.Messages = {
    ['nl'] = {
        ['report_opened'] = 'Report menu geopend. Gebruik ESC om te sluiten.',
        ['report_sent'] = 'Je report is verzonden! Ticket ID: %s',
        ['report_failed'] = 'Je report kon niet worden verzonden. Probeer het later opnieuw.',
        ['cooldown_active'] = 'Je moet %d seconden wachten voordat je een nieuw report kunt maken.',
        ['no_nearby_players'] = 'Geen spelers in de buurt gevonden.',
        ['upload_failed'] = 'Upload van bijlage mislukt.',
        ['config_failed'] = 'Modora API-token niet geconfigureerd. Controleer config.lua.',
        ['auth_failed'] = 'Authenticatie mislukt. Controleer het Modora API-token in het dashboard (FiveM → jouw server → API Credentials).',
        ['serverstats_denied'] = 'Je hebt geen rechten om serverstatistieken te bekijken.',
        ['serverstats_opened'] = 'Serverstatistieken geopend.',
    },
    ['en'] = {
        ['report_opened'] = 'Report menu opened. Press ESC to close.',
        ['report_sent'] = 'Your report has been sent! Ticket ID: %s',
        ['report_failed'] = 'Your report could not be sent. Please try again later.',
        ['cooldown_active'] = 'You must wait %d seconds before creating a new report.',
        ['no_nearby_players'] = 'No nearby players found.',
        ['upload_failed'] = 'Failed to upload attachment.',
        ['config_failed'] = 'Modora API token not configured. Check config.lua.',
        ['auth_failed'] = 'Authentication failed. Check the Modora API token in the dashboard (FiveM → your server → API Credentials).',
        ['serverstats_denied'] = 'You do not have permission to view server statistics.',
        ['serverstats_opened'] = 'Server statistics opened.',
    }
}

function GetMessage(key)
    return Config.Messages[Config.Locale][key] or Config.Messages['en'][key] or key
end
