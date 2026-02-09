Config = {}

-- ============================================
-- API CONFIGURATION (REQUIRED)
-- ============================================
-- FiveM API gebruikt alleen de api.modora.xyz- of IP-route (geen path-based URL).
-- Geen trailing slash. Voorbeelden:
--   https://api.modora.xyz   of   http://api.modora.xyz
--   Of direct IP (bijv. als HTTP geblokkeerd wordt):  http://JOUW_IP  en zet ModoraHostHeader hieronder.
Config.ModoraAPIBase = 'http://api.modora.xyz'

-- Verplicht wanneer je een IP als base gebruikt (zodat de server de juiste host ziet).
Config.ModoraHostHeader = 'api.modora.xyz'

-- API Token from Modora Dashboard.
Config.APIToken = 'your_api_key'

-- ============================================
-- REPORT COMMAND & KEYBIND
-- ============================================
Config.ReportCommand = 'report'
Config.ReportKeybind = 'F7' -- Or false to disable

-- ============================================
-- NEARBY PLAYERS SETTINGS
-- ============================================
Config.NearbyRadius = 30.0 -- Radius in meters for nearby players detection
Config.MaxNearbyPlayers = 5 -- Maximum number of nearby players to show

-- ============================================
-- MODERATION BRIDGE (optional)
-- ============================================
-- Same API token as reports. Enable moderation (command queue, bans, whitelist) when set.
Config.ModerationEnabled = true -- Set to false to disable moderation bridge
Config.PollIntervalSeconds = tonumber((GetConvar and GetConvar('modora_moderation_poll_interval', '10')) or '10') or 10
Config.WhitelistOnly = (type(GetConvarInt) == 'function' and GetConvarInt('modora_moderation_whitelist_only', 0) == 1) or false
Config.ConnectPolicy = (GetConvar and GetConvar('modora_moderation_connect_policy', 'fail_closed')) or 'fail_closed'

-- TXAdmin sync (optional): merge bans/whitelist from TXAdmin with Modora data.
-- Set to your TXAdmin base URL (e.g. same as your server + TXAdmin port, often 40120).
-- Leave empty to use only Modora dashboard data.
Config.TXAdminBaseUrl = '' -- e.g. 'http://127.0.0.1:40120'
Config.TXAdminToken = ''   -- Optional. Many TXAdmin versions do not use an API token for local requests.
                           -- If your TXAdmin API requires auth: check txAdmin Web Panel → Settings → Advanced
                           -- or the txAdmin documentation (https://github.com/tabarra/txAdmin) for "API" / "Token".
Config.TXAdminBansPath = '/api/bans'       -- Path for bans list (adjust if your TXAdmin version uses another path)
Config.TXAdminWhitelistPath = '/api/whitelist' -- Path for whitelist (optional)

-- ============================================
-- DEBUG & LOCALE
-- ============================================
Config.Debug = false -- Set to true for detailed logging
Config.Locale = 'en' -- 'nl' or 'en'

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
    }
}

function GetMessage(key)
    return Config.Messages[Config.Locale][key] or Config.Messages['en'][key] or key
end
