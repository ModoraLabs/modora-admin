-- ============================================
-- Modora FiveM Control Center — Server Bootstrap
-- ============================================
-- This file runs LAST in the server_scripts list.
-- It handles: version check, config validation, API test, heartbeat thread start.
-- Depends on: server/api.lua, server/stats.lua, server/reports.lua

local RESOURCE_VERSION = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '0.0.0'
-- GitLab project path (URL-encoded for API: modoralabs%2Fmodora-admin)
local GITLAB_PROJECT = 'modoralabs%2Fmodora-admin'
local GITLAB_RELEASES_URL = 'https://gitlab.modora.xyz/modoralabs/modora-admin/-/releases'

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    print('[Modora] Resource version (fxmanifest): ' .. RESOURCE_VERSION)
    print('[Modora] Config.Debug = ' .. tostring(Config.Debug))
end)

-- Version check thread
Citizen.CreateThread(function()
    Citizen.Wait(5000)

    if Config.Debug then
        print('[Modora] Checking for updates from GitLab...')
    end

    -- GitLab API: list releases (sorted by released_at desc), first = latest
    PerformHttpRequest('https://gitlab.modora.xyz/api/v4/projects/' .. GITLAB_PROJECT .. '/releases?per_page=1', function(statusCode, response, headers)
        local statusNum = tonumber(statusCode) or 0
        if statusNum == 200 and response then
            local success, data = pcall(json.decode, response)
            if success and data and type(data) == 'table' and #data > 0 and data[1].tag_name then
                local latestVersion = string.gsub(data[1].tag_name, '^v', '')
                local currentVersion = RESOURCE_VERSION

                if Config.Debug then
                    print('[Modora] Current version: ' .. currentVersion)
                    print('[Modora] Latest version: ' .. latestVersion)
                end

                if latestVersion ~= currentVersion then
                    print('^3[Modora] ⚠️ UPDATE AVAILABLE!^7')
                    print('^3[Modora] Current version: ^7' .. currentVersion)
                    print('^3[Modora] Latest version: ^7' .. latestVersion)
                    print('^3[Modora] Download: ' .. GITLAB_RELEASES_URL .. '^7')
                else
                    if Config.Debug then
                        print('[Modora] ✅ Resource is up to date!')
                    end
                end
            end
        end
    end, 'GET', '', {
        ['User-Agent'] = 'Modora-FiveM-Resource',
        ['Accept'] = 'application/json'
    })
end)

-- ============================================
-- API CONNECTION CHECK
-- ============================================

local function testAPIConnection()
    local baseUrl, hostHeader = getEffectiveAPIConfig()
    if not baseUrl or baseUrl == '' then
        return
    end
    baseUrl = baseUrl:gsub('/+$', ''):match('^%s*(.-)%s*$')
    if not baseUrl:match('^https?://') then
        return
    end

    local testUrl = baseUrl .. '/test'

    print('[Modora] Testing API connection to: ' .. testUrl)

    local protocol = testUrl:match('^(https?)://')

    if Config.Debug then
        print('[Modora] Testing API connection...')
        print('[Modora] URL: ' .. testUrl)
        print('[Modora] Protocol: ' .. (protocol or 'unknown'))
    end

    local testHeaders = {
        ['Accept'] = 'application/json',
    }

    PerformHttpRequest(testUrl, function(statusCode, response, responseHeaders)
        local statusNum = tonumber(statusCode) or 0

        if statusNum == 0 then
            print('^1[Modora] API connection check: could not reach ' .. testUrl .. '^7')
        elseif statusNum == 200 then
            print('^2[Modora] ✅ API connection test successful!^7')
            if Config.Debug and response then
                local success, data = pcall(json.decode, response)
                if success and data then
                    print('[Modora] API Response: ' .. (data.message or 'OK'))
                    if data.protocol then
                        print('[Modora] Server protocol: ' .. data.protocol)
                    end
                end
            end
        else
            print('^3[Modora] API connection check: HTTP ' .. tostring(statusCode) .. '^7')
        end
    end, 'GET', '', testHeaders)
end

-- ============================================
-- HTTP CONNECTIVITY TEST (console command)
-- ============================================

local function testHttpEndpoint(url, label)
    local headers = {
        ['Accept'] = '*/*',
    }

    print('[Modora] HTTP debug: ' .. label .. ' -> ' .. url)

    PerformHttpRequest(url, function(statusCode, response, responseHeaders)
        local statusNum = tonumber(statusCode) or 0
        print('[Modora] HTTP debug result (' .. label .. '): statusCode=' .. tostring(statusCode) .. ' (num=' .. tostring(statusNum) .. ')')

        if response and response ~= '' then
            print('[Modora] HTTP debug response preview (' .. label .. '): ' .. string.sub(response, 1, 200))
        end

        if responseHeaders and type(responseHeaders) == 'table' then
            local location = responseHeaders['Location'] or responseHeaders['location']
            if location and location ~= '' then
                print('[Modora] HTTP debug redirect (' .. label .. '): Location=' .. location)
            end
        end
    end, 'GET', '', headers)
end

RegisterCommand('modora_debug_http', function(source)
    if source ~= 0 then
        print('[Modora] HTTP debug can only be run from server console.')
        return
    end

    local baseUrl = getEffectiveAPIConfig()
    testHttpEndpoint('http://example.com', 'example-http')
    testHttpEndpoint(baseUrl .. '/test', 'modora-api-test')
end, false)

-- ============================================
-- HEARTBEAT (periodic GET /stats -> dashboard last_heartbeat)
-- ============================================

local function sendHeartbeat()
    local baseUrl, _, token = getEffectiveAPIConfig()
    if not baseUrl or baseUrl == '' or not token or token == '' then
        return
    end
    baseUrl = baseUrl:gsub('/+$', '')
    if not baseUrl:match('^https?://') then
        return
    end
    local url = baseUrl .. '/stats'
    local headers = buildAuthHeaders()
    PerformHttpRequest(url, function(statusCode, response)
        local statusNum = tonumber(statusCode) or 0
        if statusNum == 200 then
            if Config.Debug then
                print('[Modora] Heartbeat OK')
            end
        else
            if Config.Debug then
                print('[Modora] Heartbeat failed: HTTP ' .. tostring(statusCode))
            end
        end
    end, 'GET', '', headers)
end

CreateThread(function()
    local interval = tonumber(Config.HeartbeatIntervalSeconds or 0) or 0
    if interval <= 0 then
        if Config.Debug then
            print('[Modora] Heartbeat disabled (HeartbeatIntervalSeconds = 0)')
        end
        return
    end
    local waitMs = math.floor(interval * 1000)
    if Config.Debug then
        print('[Modora] Heartbeat enabled, interval=' .. tostring(interval) .. 's')
    end
    -- First heartbeat after 30s so config/test have run
    Wait(30000)
    while true do
        sendHeartbeat()
        Wait(waitMs)
    end
end)

-- ============================================
-- CONFIGURATION VALIDATION
-- ============================================

Citizen.CreateThread(function()
    Citizen.Wait(2000)

    local _, _, token = getEffectiveAPIConfig()
    local configValid = (token and token ~= '')

    if not configValid then
        print('^1[Modora] Set Config.APIToken in config.lua (from Dashboard → FiveM → your server → API Credentials).^7')
    else
        print('^2[Modora] Configuration OK^7')
        Citizen.Wait(1000)
        testAPIConnection()
    end
end)
