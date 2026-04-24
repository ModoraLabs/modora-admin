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
local UPDATE_CHECK_MAX_ATTEMPTS = 4
local UPDATE_CHECK_BACKOFF_MS = { 15000, 30000, 60000 } -- waits between attempts 1→2, 2→3, 3→4

local function handleUpdateCheckResult(data)
    if not data[1] or not data[1].tag_name then
        print('^3[Modora] Update check: no releases found on GitLab^7')
        return
    end

    local latestVersion = string.gsub(data[1].tag_name, '^v', '')
    local currentVersion = RESOURCE_VERSION

    if latestVersion ~= currentVersion then
        print('^3[Modora] ⚠️ UPDATE AVAILABLE!^7')
        print('^3[Modora] Current version: ^7' .. currentVersion)
        print('^3[Modora] Latest version: ^7' .. latestVersion)
        print('^3[Modora] Download: ' .. GITLAB_RELEASES_URL .. '^7')
    else
        print('^2[Modora] ✅ Resource is up to date (v' .. currentVersion .. ')^7')
    end
end

local function attemptUpdateCheck(attempt, gitlabUrl)
    PerformHttpRequest(gitlabUrl, function(statusCode, response)
        local statusNum = tonumber(statusCode) or 0

        -- Success path
        if statusNum == 200 and response and response ~= '' then
            local ok, data = pcall(json.decode, response)
            if ok and type(data) == 'table' and #data > 0 then
                handleUpdateCheckResult(data)
                return
            end
            if Config.Debug then
                print('^3[Modora] Update check: could not parse GitLab response^7')
            end
        end

        -- Retryable: transient network errors (status 0) or 5xx
        local retryable = (statusNum == 0) or (statusNum >= 500 and statusNum < 600)
        if retryable and attempt < UPDATE_CHECK_MAX_ATTEMPTS then
            local nextWait = UPDATE_CHECK_BACKOFF_MS[attempt] or 60000
            if Config.Debug then
                local reason = (statusNum == 0) and 'network error' or ('HTTP ' .. tostring(statusCode))
                print('^3[Modora] Update check attempt ' .. attempt .. '/' .. UPDATE_CHECK_MAX_ATTEMPTS
                    .. ' failed (' .. reason .. '), retrying in ' .. math.floor(nextWait / 1000) .. 's^7')
            end
            Citizen.SetTimeout(nextWait, function()
                attemptUpdateCheck(attempt + 1, gitlabUrl)
            end)
            return
        end

        -- Give up — print a single concise line, not a scary warning.
        if statusNum == 0 then
            print('^3[Modora] Update check skipped: GitLab unreachable after '
                .. UPDATE_CHECK_MAX_ATTEMPTS .. ' attempts (running v' .. RESOURCE_VERSION .. ')^7')
        elseif statusNum ~= 200 then
            print('^3[Modora] Update check: GitLab returned HTTP ' .. tostring(statusCode)
                .. ' (running v' .. RESOURCE_VERSION .. ')^7')
        end
    end, 'GET', '', {
        ['User-Agent'] = 'Modora-FiveM-Resource',
        ['Accept'] = 'application/json'
    })
end

Citizen.CreateThread(function()
    -- Wait long enough for FiveM's HTTP stack + DNS to settle after boot.
    Citizen.Wait(30000)

    if Config.Debug then
        print('[Modora] Checking for updates from GitLab...')
    end

    local gitlabUrl = 'https://gitlab.modora.xyz/api/v4/projects/' .. GITLAB_PROJECT .. '/releases?per_page=1'
    if Config.Debug then
        print('[Modora] Update check URL: ' .. gitlabUrl)
    end

    attemptUpdateCheck(1, gitlabUrl)
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

    -- Collect metrics to send with heartbeat
    local playerCount = #GetPlayers()
    local resourceCount = 0
    for i = 0, GetNumResources() - 1 do
        local name = GetResourceByFindIndex(i)
        if name and GetResourceState(name) == 'started' then
            resourceCount = resourceCount + 1
        end
    end
    local memoryMb = nil
    if processStatsCache and processStatsCache.hostMemoryMb then
        memoryMb = math.floor(processStatsCache.hostMemoryMb)
    end
    local cpuPercent = nil
    if processStatsCache and processStatsCache.hostCpuPercent then
        cpuPercent = processStatsCache.hostCpuPercent
    end

    -- Build URL with query params
    local url = baseUrl .. '/stats?player_count=' .. tostring(playerCount)
        .. '&resource_count=' .. tostring(resourceCount)
    if memoryMb then
        url = url .. '&memory_mb=' .. tostring(memoryMb)
    end
    if cpuPercent then
        url = url .. '&cpu_percent=' .. tostring(cpuPercent)
    end

    local headers = buildAuthHeaders()
    PerformHttpRequest(url, function(statusCode, response)
        local statusNum = tonumber(statusCode) or 0
        if statusNum == 200 then
            if Config.Debug then
                print('[Modora] Heartbeat OK | players=' .. tostring(playerCount) .. ' resources=' .. tostring(resourceCount))
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
