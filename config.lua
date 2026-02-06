Config = {}

-- ============================================
-- API CONFIGURATION (REQUIRED)
-- ============================================
-- API Base URL - Uses HTTP/1.1 for FiveM compatibility
-- IMPORTANT: Must start with http:// or https:// and NOT have a trailing slash
-- 
-- OPTION 1: Use direct domain (no Cloudflare) - RECOMMENDED
--   Config.ModoraAPIBase = 'http://api.ditiskevin.nl'
--   Note: Direct IP connection, no Cloudflare redirects. Works immediately.
--   Make sure api.ditiskevin.nl points to your dashboard IP (alpha or production)
--
-- OPTION 2: Use alpha environment API
--   Config.ModoraAPIBase = 'http://api.alpha.modora.xyz'
--   Note: For alpha/testing environment. Direct connection, no Cloudflare.
--
-- OPTION 3: Use HTTPS (if Cloudflare redirects HTTP to HTTPS)
--   Config.ModoraAPIBase = 'https://api.modora.xyz'
--   Note: Requires working SSL/TLS on FiveM server. If you get HTTP 0 errors, try Option 1.
--
-- OPTION 4: Use HTTP with Cloudflare (requires Cloudflare configuration)
--   Config.ModoraAPIBase = 'http://api.modora.xyz'
--   Note: You MUST configure Cloudflare to allow HTTP (see README.md)
--   Without Cloudflare config, HTTP will be redirected to HTTPS (307 error)
--
Config.ModoraAPIBase = 'http://api.alpha.modora.xyz'  -- Using HTTP for alpha environment

-- API Token - Get this from your Modora Dashboard:
-- Dashboard > Guild > FiveM Integration > [Your Server] > API Token
-- Copy the full token including the 'fivem_' prefix if present
Config.APIToken = 'fivem_6oOHs4aQKvvHjfc3Bimk6xBEJDdyPwBwuZy5TWhdvY1PP99B' -- Your API token here

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
-- DEBUG & LOCALE
-- ============================================
Config.Debug = true -- Set to true for detailed logging
Config.Locale = 'nl' -- 'nl' or 'en'

Config.Messages = {
    ['nl'] = {
        ['report_opened'] = 'Report menu geopend. Gebruik ESC om te sluiten.',
        ['report_sent'] = 'Je report is verzonden! Ticket ID: %s',
        ['report_failed'] = 'Je report kon niet worden verzonden. Probeer het later opnieuw.',
        ['cooldown_active'] = 'Je moet %d seconden wachten voordat je een nieuw report kunt maken.',
        ['no_nearby_players'] = 'Geen spelers in de buurt gevonden.',
        ['upload_failed'] = 'Upload van bijlage mislukt.',
        ['config_failed'] = 'API token niet geconfigureerd. Controleer config.lua.',
        ['auth_failed'] = 'Authenticatie mislukt. Controleer je API token.',
    },
    ['en'] = {
        ['report_opened'] = 'Report menu opened. Press ESC to close.',
        ['report_sent'] = 'Your report has been sent! Ticket ID: %s',
        ['report_failed'] = 'Your report could not be sent. Please try again later.',
        ['cooldown_active'] = 'You must wait %d seconds before creating a new report.',
        ['no_nearby_players'] = 'No nearby players found.',
        ['upload_failed'] = 'Failed to upload attachment.',
        ['config_failed'] = 'API token not configured. Check config.lua.',
        ['auth_failed'] = 'Authentication failed. Check your API token.',
    }
}

function GetMessage(key)
    return Config.Messages[Config.Locale][key] or Config.Messages['en'][key] or key
end
