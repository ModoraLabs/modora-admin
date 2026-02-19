local RESOURCE_VERSION = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '0.0.0'
local GITHUB_REPO = 'ModoraLabs/modora-admin'

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    print('[Modora] Resource version (fxmanifest): ' .. RESOURCE_VERSION)
    print('[Modora] Config.Debug = ' .. tostring(Config.Debug))
end)


Citizen.CreateThread(function()
    Citizen.Wait(5000) 

    if Config.Debug then
        print('[Modora] Checking for updates from GitHub...')
    end

    PerformHttpRequest('https://api.github.com/repos/' .. GITHUB_REPO .. '/releases/latest', function(statusCode, response, headers)
        local statusNum = tonumber(statusCode) or 0
        if statusNum == 200 and response then
            local success, data = pcall(json.decode, response)
            if success and data and data.tag_name then
                local latestVersion = string.gsub(data.tag_name, '^v', '')
                local currentVersion = RESOURCE_VERSION

                if Config.Debug then
                    print('[Modora] Current version: ' .. currentVersion)
                    print('[Modora] Latest version: ' .. latestVersion)
                end

                if latestVersion ~= currentVersion then
                    print('^3[Modora] ⚠️ UPDATE AVAILABLE!^7')
                    print('^3[Modora] Current version: ^7' .. currentVersion)
                    print('^3[Modora] Latest version: ^7' .. latestVersion)
                    print('^3[Modora] Download: https://github.com/' .. GITHUB_REPO .. '/releases/latest^7')
                else
                    if Config.Debug then
                        print('[Modora] ✅ Resource is up to date!')
                    end
                end
            end
        end
    end, 'GET', '', {
        ['User-Agent'] = 'Modora-FiveM-Resource',
        ['Accept'] = 'application/vnd.github.v3+json'
    })
end)

-- ============================================
-- API AUTHENTICATION
-- ============================================

-- Returns API base URL, optional host header and bearer token from config.
local function getEffectiveAPIConfig()
    local base = (Config.ModoraAPIBase or ''):gsub('/+$', ''):match('^%s*(.-)%s*$')
    local host = (Config.ModoraHostHeader or ''):match('^%s*(.-)%s*$')
    local token = (Config.APIToken or ''):match('^%s*(.-)%s*$')
    return base, host, token
end

-- Build request headers with bearer token.
local function buildAuthHeaders()
    local _, hostHeader, token = getEffectiveAPIConfig()
    token = token or ''
    return {
        ['Content-Type'] = 'application/json',
        ['Authorization'] = 'Bearer ' .. token,
    }
end

-- Player identifiers (discord, steam, etc.) for the report payload.
function GetPlayerIdentifiersTable(source)
    local identifiers = {}
    for i = 0, GetNumPlayerIdentifiers(source) - 1 do
        local identifier = GetPlayerIdentifier(source, i)
        if identifier then
            local prefix, value = string.match(identifier, '^([^:]+):(.+)$')
            if prefix and value then
                identifiers[prefix] = value
            end
        end
    end
    return identifiers
end

RegisterNetEvent('modora:getPlayerIdentifiers')
AddEventHandler('modora:getPlayerIdentifiers', function()
    local source = source
    local identifiers = GetPlayerIdentifiersTable(source)
    TriggerClientEvent('modora:playerIdentifiers', source, identifiers)
end)

-- ============================================
-- SERVER STATS PANEL (TXAdmin permission + stats + last 5 errors)
-- ============================================

local serverStatsStartTime = os.time()
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        serverStatsStartTime = os.time()
    end
end)

local lastErrors = {}
local MAX_ERRORS = 5

-- Call from other resources or use TriggerEvent('modora:pushServerError', message) to record an error.
RegisterNetEvent('modora:pushServerError')
AddEventHandler('modora:pushServerError', function(message)
    if not message or type(message) ~= 'string' then return end
    table.insert(lastErrors, 1, os.date('%H:%M:%S') .. ' - ' .. message)
    while #lastErrors > MAX_ERRORS do
        table.remove(lastErrors)
    end
end)

-- Export so other resources can push errors: exports['modora-admin']:PushServerError('message')
exports('PushServerError', function(message)
    TriggerEvent('modora:pushServerError', message)
end)

local function normalizeId(s)
    if type(s) ~= 'string' then return nil end
    s = s:match('^%s*(.-)%s*$') or s
    return s ~= '' and string.lower(s) or nil
end

-- Build set of player identifiers (lowercase, trimmed) for matching txAdmin admins.json
local function getPlayerIdentifierSet(source)
    local set = {}
    for i = 0, GetNumPlayerIdentifiers(source) - 1 do
        local id = normalizeId(GetPlayerIdentifier(source, i))
        if id then set[id] = true end
    end
    return set
end

-- Load and check txAdmin admins.json (txAdmin does not expose HasPermission to other resources)
local function hasTxAdminPermissionFromFile(source, requiredPerm)
    local path = (Config.ServerStatsTxAdminAdminsPath or ''):gsub('^%s*(.-)%s*$', '%1')
    path = path:gsub('^["\']+', ''):gsub('["\']+$', '')  -- strip surrounding quotes
    if path == '' then
        path = (GetConvar('txDataPath', '') or ''):gsub('^%s*(.-)%s*$', '%1')
        if path ~= '' then
            path = path:gsub('[/\\]+$', '') .. '/admins.json'
        end
    end
    path = path:gsub('\\', '/')
    local content = nil
    if path ~= '' then
        local ok, data = pcall(function()
            local f = io.open(path, 'r')
            if not f then return nil end
            local out = f:read('*a')
            f:close()
            return out
        end)
        if ok and data and data ~= '' then content = data end
    end
    -- Fallback: read from resource folder (copy G:\txData\admins.json to modora-admin/admins.json)
    if not content or content == '' then
        content = LoadResourceFile(GetCurrentResourceName(), 'admins.json')
    end
    if not content or content == '' then
        if Config.Debug then
            print('[Modora ServerStats] admins.json not found. Copy G:\\txData\\admins.json into the modora-admin resource folder as admins.json')
        end
        return false
    end

    local ok
    ok, content = pcall(json.decode, content)
    if not ok or type(content) ~= 'table' then
        if Config.Debug then
            print('[Modora ServerStats] admins.json parse failed')
        end
        return false
    end

    local playerIds = getPlayerIdentifierSet(source)
    if not next(playerIds) then
        if Config.Debug then
            print('[Modora ServerStats] player #' .. tostring(source) .. ' has no identifiers')
        end
        return false
    end

    if Config.Debug then
        local list = {}
        for id, _ in pairs(playerIds) do list[#list + 1] = id end
        print('[Modora ServerStats] player #' .. tostring(source) .. ' identifiers: ' .. table.concat(list, ', '))
    end

    for _, admin in ipairs(content) do
        if type(admin) ~= 'table' then goto continue end
        local adminIds = {}
        if type(admin.providers) == 'table' then
            for _, prov in pairs(admin.providers) do
                if type(prov) == 'table' then
                    local id = normalizeId(prov.identifier)
                    if id then adminIds[id] = true end
                end
            end
        end
        local match = false
        for id, _ in pairs(playerIds) do
            if adminIds[id] then match = true break end
        end
        if not match then goto continue end

        if admin.master == true then
            if Config.Debug then
                print('[Modora ServerStats] matched master admin: ' .. tostring(admin.name))
            end
            return true
        end
        local perms = admin.permissions
        if type(perms) ~= 'table' then goto continue end
        for _, p in ipairs(perms) do
            if p == 'all_permissions' or p == requiredPerm then
                if Config.Debug then
                    print('[Modora ServerStats] matched admin with perm: ' .. tostring(admin.name))
                end
                return true
            end
        end
        if Config.Debug then
            print('[Modora ServerStats] matched admin but missing perm: ' .. tostring(admin.name) .. ' (need ' .. tostring(requiredPerm) .. ')')
        end
        ::continue::
    end
    if Config.Debug then
        print('[Modora ServerStats] no admin match for player #' .. tostring(source))
    end
    return false
end

local function hasServerStatsPermission(source)
    if not source or source == 0 then return false end
    local acePerm = Config.ServerStatsAcePermission or 'modora.serverstats'
    if acePerm and acePerm ~= '' and IsPlayerAceAllowed(source, acePerm) then
        if Config.Debug then print('[Modora ServerStats] Permission: ACE allowed (' .. tostring(acePerm) .. ')') end
        return true
    end
    local perm = Config.ServerStatsTxAdminPermission or 'console.view'
    if hasTxAdminPermissionFromFile(source, perm) then
        if Config.Debug then print('[Modora ServerStats] Permission: txAdmin admins.json') end
        return true
    end
    local state = GetResourceState('monitor')
    if state == 'started' then
        local ok, has = pcall(function()
            return exports.monitor:HasPermission(source, perm)
        end)
        if ok and has then
            if Config.Debug then print('[Modora ServerStats] Permission: monitor export') end
            return true
        end
    end
    state = GetResourceState('txAdmin')
    if state == 'started' then
        local ok, has = pcall(function()
            return exports.txAdmin:HasPermission(source, perm)
        end)
        if ok and has then
            if Config.Debug then print('[Modora ServerStats] Permission: txAdmin export') end
            return true
        end
    end
    if Config.ServerStatsAllowWithoutTxAdmin then
        if Config.Debug then print('[Modora ServerStats] Permission: ServerStatsAllowWithoutTxAdmin=true') end
        return true
    end
    if Config.Debug then print('[Modora ServerStats] Permission: denied (no match)') end
    return false
end

-- Process RAM and CPU. FiveM sandbox blocks io.popen (except ls/dir) and io.open outside resources,
-- so we try: (1) optional stats file written by external script, (2) OS reads if sandbox allows.
local processStatsCache = { hostMemoryMb = nil, hostCpuPercent = nil }

local function getProcessMemoryMb()
    -- (1) Optional stats file written by external script (works with FiveM sandbox)
    local name = Config.ServerStatsHostStatsFile or 'stats_host.txt'
    if name and name ~= '' then
        local content = LoadResourceFile(GetCurrentResourceName(), name)
        if content and content ~= '' then
            local mem = content:match('memory_mb=%s*([%d%.]+)')
            local cpu = content:match('cpu_percent=%s*([%d%.]+)')
            if cpu then
                local pct = tonumber(cpu)
                if pct and pct >= 0 then processStatsCache.hostCpuPercent = math.floor(math.min(100, pct) * 10) / 10 end
            end
            if mem then
                local mb = tonumber(mem)
                if mb and mb >= 0 then return math.floor(mb * 10) / 10 end
            end
        end
    end
    -- (2) Linux: /proc/self/status has VmRSS in KB (fails if sandbox blocks io.open)
    local f = io.open('/proc/self/status', 'r')
    if f then
        local content = f:read('*a')
        f:close()
        if content then
            local rss = content:match('VmRSS:%s+(%d+)')
            if rss then
                local kb = tonumber(rss)
                if kb and kb >= 0 then return math.floor((kb / 1024) * 10) / 10 end
            end
        end
    end
    -- Windows: try tasklist then wmic (use cmd /c so shell runs the command)
    local function readPipe(cmd)
        local ok, h = pcall(io.popen, cmd, 'r')
        if not ok or not h then return nil end
        local out = h:read('*a')
        pcall(function() if h and h.close then h:close() end end)
        return out
    end
    local function parseMemFromTasklist(out)
        if not out then return nil end
        local line = out:match('FXServer[^\r\n]*')
        if not line then line = out:match('([^\r\n]+)') end
        if not line then return nil end
        -- CSV: "12,345 K" or "12 345 K" in last field
        local memStr = line:match('"([%d,%s]+)%s*K?"%s*$') or line:match(',%s*"([%d,%s]+)%s*K?"')
        if memStr then
            local num = tonumber((memStr:gsub('[%s,]', '')))
            if num and num > 0 then return math.floor((num / 1024) * 10) / 10 end
        end
        -- Table format: number followed by " K" at end
        local num = line:match('(%d[%d,]*)%s*K%s*$')
        if num then
            num = tonumber((num:gsub(',', '')))
            if num and num > 0 then return math.floor((num / 1024) * 10) / 10 end
        end
        return nil
    end
    local out
    for _, cmd in ipairs({
        'tasklist /fi "imagename eq FXServer.exe" /fo csv /nh',
        'cmd /c tasklist /fi "imagename eq FXServer.exe" /fo csv /nh',
        'tasklist /fi "imagename eq FXServer.exe"',
        'cmd /c tasklist /fi "imagename eq FXServer.exe"',
    }) do
        out = readPipe(cmd)
        if out and #out > 0 then
            local mb = parseMemFromTasklist(out)
            if mb then return mb end
        end
    end
    for _, cmd in ipairs({
        'wmic process where name="FXServer.exe" get WorkingSetSize /value',
        'cmd /c wmic process where name="FXServer.exe" get WorkingSetSize /value',
    }) do
        out = readPipe(cmd)
        if out then
            local bytes = out:match('WorkingSetSize=%s*(%d+)')
            if bytes then
                local b = tonumber(bytes)
                if b and b > 0 then return math.floor((b / (1024 * 1024)) * 10) / 10 end
            end
        end
    end
    out = readPipe('powershell -NoProfile -Command "(Get-Process -Name FXServer -ErrorAction SilentlyContinue).WorkingSet64"')
    if out then
        local bytes = out:match('(%d+)')
        if bytes then
            local b = tonumber(bytes)
            if b and b > 0 then return math.floor((b / (1024 * 1024)) * 10) / 10 end
        end
    end
    return nil
end

-- CPU % on Linux: sample /proc/self/stat (utime + stime) twice, compute delta.
local function updateProcessCpuPercent()
    local f = io.open('/proc/self/stat', 'r')
    if not f then return end
    local line = f:read('*l')
    f:close()
    if not line then return end
    -- Format: pid (comm) state ppid ... ; after ") " we have state,ppid,..., utime=12th, stime=13th
    local afterParen = line:match('%)%s+(.+)$')
    if not afterParen then return end
    local fields = {}
    for v in afterParen:gmatch('%S+') do fields[#fields + 1] = v end
    if #fields < 14 then return end
    local utime, stime = fields[12], fields[13]
    if not utime or not stime then return end
    local u, s = tonumber(utime), tonumber(stime)
    if not u or not s then return end
    local totalTicks = u + s
    local prev = processStatsCache._lastCpuTicks
    local prevTs = processStatsCache._lastCpuTs
    local now = os.time()
    processStatsCache._lastCpuTicks = totalTicks
    processStatsCache._lastCpuTs = now
    if prev and prevTs and (now - prevTs) >= 1 then
        local tickHz = 100
        local deltaTicks = totalTicks - prev
        local deltaSec = now - prevTs
        if deltaSec > 0 then
            local pct = (deltaTicks / tickHz) / deltaSec
            processStatsCache.hostCpuPercent = math.floor(math.min(100, pct) * 10) / 10
        end
    end
end

CreateThread(function()
    Wait(2000)
    while true do
        local ok, mb = pcall(getProcessMemoryMb)
        if ok and mb ~= nil then processStatsCache.hostMemoryMb = mb end
        Wait(5000)
    end
end)

CreateThread(function()
    Wait(3000)
    while true do
        pcall(updateProcessCpuPercent)
        Wait(2000)
    end
end)

local function getServerStats()
    local numResources = 0
    for i = 0, GetNumResources() - 1 do
        local name = GetResourceByFindIndex(i)
        if name and GetResourceState(name) == 'started' then
            numResources = numResources + 1
        end
    end
    local players = #GetPlayers()
    local uptimeSec = os.time() - (serverStatsStartTime or os.time())
    local memoryKb = math.floor(collectgarbage('count'))
    local stats = {
        uptimeSeconds = uptimeSec,
        playerCount = players,
        resourceCount = numResources,
        memoryKb = memoryKb,
        serverVersion = GetConvar('version', '') or '',
        serverName = GetConvar('sv_hostname', '') or GetConvar('sv_projectName', '') or 'Server',
        lastErrors = lastErrors
    }
    if processStatsCache.hostMemoryMb ~= nil then
        stats.hostMemoryMb = processStatsCache.hostMemoryMb
    else
        -- Fallback when OS process RAM unavailable (e.g. io.popen disabled): show Lua heap
        stats.hostMemoryMb = math.floor((memoryKb / 1024) * 10) / 10
        stats.hostMemoryLuaFallback = true
    end
    if processStatsCache.hostCpuPercent ~= nil then stats.hostCpuPercent = processStatsCache.hostCpuPercent end
    return stats
end

RegisterNetEvent('modora:requestServerStats')
AddEventHandler('modora:requestServerStats', function()
    local source = source
    print('[Modora ServerStats] Request from player #' .. tostring(source) .. ' | Config.Debug=' .. tostring(Config.Debug))
    local function sendResult(allowed, stats)
        TriggerClientEvent('modora:serverStatsResult', source, {
            allowed = allowed,
            stats = stats or {}
        })
    end
    local ok, err = pcall(function()
        if not source or source == 0 then
            if Config.Debug then print('[Modora ServerStats] Invalid source') end
            sendResult(false, nil)
            return
        end
        if not hasServerStatsPermission(source) then
            local ids = getPlayerIdentifierSet(source)
            local list = {}
            for id, _ in pairs(ids) do list[#list + 1] = id end
            print('[Modora ServerStats] Denied #' .. tostring(source) .. ' | identifiers: ' .. (table.concat(list, ', ') or 'none'))
            sendResult(false, nil)
            return
        end
        local stats
        local statsOk, statsErr = pcall(function()
            stats = getServerStats()
        end)
        if not statsOk then
            print('[Modora ServerStats] getServerStats error: ' .. tostring(statsErr))
            local memKb = math.floor(collectgarbage('count'))
            stats = {
                uptimeSeconds = os.time() - (serverStatsStartTime or os.time()),
                playerCount = #GetPlayers(),
                resourceCount = 0,
                memoryKb = memKb,
                hostMemoryMb = math.floor((memKb / 1024) * 10) / 10,
                hostMemoryLuaFallback = true,
                serverVersion = GetConvar('version', '') or '',
                serverName = GetConvar('sv_hostname', '') or GetConvar('sv_projectName', '') or 'Server',
                lastErrors = lastErrors
            }
        end
        if Config.Debug and stats then
            print('[Modora ServerStats] Sending stats: players=' .. tostring(stats.playerCount) .. ' resources=' .. tostring(stats.resourceCount) .. ' memoryKb=' .. tostring(stats.memoryKb))
        end
        sendResult(true, stats)
    end)
    if not ok then
        print('[Modora ServerStats] Handler error: ' .. tostring(err))
        sendResult(false, nil)
    end
end)

-- API: config fetch and report submit with retries.

-- HTTP request with optional retries.
local function performHttpRequestWithRetry(url, method, body, headers, callback, maxRetries)
    maxRetries = tonumber(maxRetries) or 3
    local retryCount = 0

    local function attemptRequest()
        if Config.Debug then
            if retryCount > 0 then
                print('[Modora] Retry attempt ' .. tostring(retryCount) .. '/' .. tostring(maxRetries))
            else
                print('[Modora] Making HTTP request to: ' .. url)
            end
        end

        PerformHttpRequest(url, function(statusCode, response, responseHeaders)
            local statusNum = tonumber(statusCode) or 0

            if Config.Debug then
                print('[Modora] HTTP response: statusCode=' .. tostring(statusCode) .. ' (num=' .. tostring(statusNum) .. ')')
                if response and string.len(response) > 0 then
                    print('[Modora] Response preview: ' .. string.sub(response, 1, 200))
                end
            end

            if statusNum == 0 and retryCount < maxRetries then
                retryCount = retryCount + 1
                if Config.Debug then
                    print('[Modora] Connection failed, waiting ' .. tostring(1000 * retryCount) .. 'ms before retry...')
                end
                Citizen.Wait(1000 * retryCount) -- Exponential backoff
                attemptRequest()
            else
                if callback then
                    callback(statusCode, response, responseHeaders, maxRetries, retryCount)
                end
            end
        end, method, body or '', headers)
    end

    attemptRequest()
end

-- Fetches server config (categories, report form, etc.) from the API.
local function getServerConfig(callback)
    local baseUrl, _, token = getEffectiveAPIConfig()
    if not baseUrl or baseUrl == '' then
        if callback then callback(false, 'API base URL not configured') end
        return
    end
    if not token or token == '' then
        if callback then callback(false, 'API token not configured') end
        return
    end
    if not baseUrl:match('^https?://') then
        if callback then callback(false, 'API base URL must start with http:// or https://') end
        return
    end
    local url = baseUrl .. '/config'
    local headers = buildAuthHeaders()
    if Config.Debug then
        print('[Modora] Fetching server config from: ' .. url)
        print('[Modora] API Token length: ' .. tostring(string.len(token or '')))
        print('[Modora] API Token preview: ' .. string.sub(token or '', 1, 10) .. '...')
    end

    performHttpRequestWithRetry(url, 'GET', '', headers, function(statusCode, response, responseHeaders, maxRetries, retryCount)
        local statusNum = tonumber(statusCode) or 0
        maxRetries = maxRetries or 3
        retryCount = retryCount or 0

        if Config.Debug then
            print('[Modora] Config request response: statusCode=' .. tostring(statusCode) .. ' (num=' .. tostring(statusNum) .. ')')
            print('[Modora] Retries attempted: ' .. tostring(retryCount) .. '/' .. tostring(maxRetries))
        end

        if statusNum == 0 then
            local errorMsg = 'Connection failed after retries.'
            if callback then callback(false, errorMsg) end
        elseif (statusNum == 200 or statusNum == 302) and response and response ~= '' then
            -- 302: API may return redirect with JSON body (e.g. reverse proxy); parse body as config
            local success, data = pcall(json.decode, response)
            if success and data and (data.serverId or data.reportFormConfig or data.categories) then
                if callback then callback(true, data) end
            elseif success and data then
                if callback then callback(true, data) end
            else
                if callback then callback(false, 'Failed to parse config response') end
            end
        elseif statusNum == 401 then
            if callback then callback(false, 'Authentication failed. Check your API token.') end
        else
            local errorMsg = 'HTTP ' .. tostring(statusCode)
            if response then errorMsg = errorMsg .. ': ' .. response end
            if callback then callback(false, errorMsg) end
        end
    end)
end

-- Submits report payload to the API and returns result via callback.
local function submitReport(reportData, callback)
    local baseUrl, _, token = getEffectiveAPIConfig()
    if not baseUrl or baseUrl == '' then
        if callback then callback(false, nil, 'API base URL not configured') end
        return
    end
    if not token or token == '' then
        if callback then callback(false, nil, 'API token not configured') end
        return
    end
    baseUrl = baseUrl:gsub('/+$', ''):match('^%s*(.-)%s*$')

    if not baseUrl:match('^https?://') then
        if callback then callback(false, nil, 'API base URL must start with http:// or https://') end
        return
    end

    local url = baseUrl .. '/reports'
    local body = json.encode(reportData)
    local headers = buildAuthHeaders()

    if Config.Debug then
        print('[Modora] Submitting report to: ' .. url)
        print('[Modora] API Token length: ' .. tostring(string.len(Config.APIToken or '')))
        print('[Modora] API Token preview: ' .. string.sub(Config.APIToken or '', 1, 10) .. '...')
        print('[Modora] Report data: ' .. body)
    end

    performHttpRequestWithRetry(url, 'POST', body, headers, function(statusCode, response, responseHeaders, maxRetries, retryCount)
        local statusNum = tonumber(statusCode) or 0
        maxRetries = maxRetries or 3
        retryCount = retryCount or 0

        if Config.Debug then
            print('[Modora] Report submission response: statusCode=' .. tostring(statusCode) .. ' (num=' .. tostring(statusNum) .. ')')
            print('[Modora] Retries attempted: ' .. tostring(retryCount) .. '/' .. tostring(maxRetries))
        end

        if statusNum == 0 then
            local errorMsg = 'Connection failed after ' .. tostring(retryCount) .. ' retry attempts.'
            if callback then callback(false, nil, errorMsg, nil) end
        elseif statusNum == 201 or statusNum == 200 then
            local success, data = pcall(json.decode, response)
            if success and data then
                if callback then callback(true, data, nil, nil) end
            else
                if callback then callback(false, nil, 'Failed to parse response', nil) end
            end
        elseif statusNum == 401 then
            if callback then callback(false, nil, 'Authentication failed. Check your API token.', nil) end
        elseif statusNum == 429 then
            local success, data = pcall(json.decode, response)
            local cooldownSec = (success and data and data.remaining_seconds) and tonumber(data.remaining_seconds) or (success and data and data.cooldown_seconds) and tonumber(data.cooldown_seconds) or nil
            if success and data and data.remaining_seconds then
                if callback then callback(false, nil, 'Cooldown active. Please wait ' .. data.remaining_seconds .. ' seconds.', cooldownSec) end
            else
                if callback then callback(false, nil, 'Rate limit exceeded. Please wait before submitting another report.', cooldownSec) end
            end
        else
            local errorMsg = 'HTTP ' .. tostring(statusCode)
            if response and response ~= '' then
                local success, data = pcall(json.decode, response)
                if success and data then
                    if data.message and data.message ~= '' then
                        errorMsg = data.message
                    elseif data.error and data.error ~= '' then
                        errorMsg = data.error .. (data.message and (': ' .. data.message) or '')
                    end
                else
                    errorMsg = errorMsg .. ': ' .. string.sub(response, 1, 200)
                end
            end
            if callback then callback(false, nil, errorMsg, nil) end
        end
    end)
end

-- ============================================
-- SERVER CONFIG (for NUI report form – categories + reportFormConfig from dashboard)
-- ============================================

RegisterNetEvent('modora:getServerConfig')
AddEventHandler('modora:getServerConfig', function()
    local source = source
    getServerConfig(function(success, data)
        if success and data then
            TriggerClientEvent('modora:serverConfig', source, data)
        else
            TriggerClientEvent('modora:serverConfig', source, nil)
        end
    end)
end)

-- ============================================
-- REPORT SUBMISSION
-- ============================================

RegisterNetEvent('modora:submitReport')
AddEventHandler('modora:submitReport', function(reportData)
    local source = source

    if not reportData.category or not reportData.subject or not reportData.description then
        TriggerClientEvent('modora:reportSubmitted', source, {
            success = false,
            error = 'Missing required fields',
            cooldownSeconds = nil
        })
        return
    end

    local identifiers = GetPlayerIdentifiersTable(source)
    reportData.reporter = reportData.reporter or {}
    reportData.reporter.identifiers = identifiers
    reportData.reporter.fivemId = source
    reportData.reporter.name = GetPlayerName(source)

    reportData.meta = reportData.meta or {}
    if reportData.evidenceUrls and type(reportData.evidenceUrls) == 'table' then
        reportData.meta.evidence_urls = reportData.evidenceUrls
    end

    submitReport(reportData, function(success, data, err, cooldownSeconds)
        if success and data then
            TriggerClientEvent('modora:reportSubmitted', source, {
                success = true,
                ticketNumber = data.ticketNumber,
                ticketId = data.ticketId,
                ticketUrl = data.ticketUrl,
                error = nil,
                cooldownSeconds = nil
            })
        else
            TriggerClientEvent('modora:reportSubmitted', source, {
                success = false,
                ticketNumber = nil,
                ticketId = nil,
                ticketUrl = nil,
                error = err or 'Unknown error',
                cooldownSeconds = cooldownSeconds
            })
        end
    end)
end)

-- ============================================
-- SCREENSHOT UPLOAD
-- ============================================

RegisterNetEvent('modora:getScreenshotUploadUrl')
AddEventHandler('modora:getScreenshotUploadUrl', function()
    local source = source
    local baseUrl, _, token = getEffectiveAPIConfig()
    baseUrl = (baseUrl or ''):gsub('/+$', ''):match('^%s*(.-)%s*$')
    if baseUrl == '' or (token or '') == '' then
        TriggerClientEvent('modora:screenshotUploadUrl', source, '')
        return
    end
    local url = baseUrl .. '/upload-token'
    local headers = buildAuthHeaders()
    performHttpRequestWithRetry(url, 'POST', '{}', headers, function(statusCode, response)
        local uploadUrl = ''
        local statusNum = tonumber(statusCode) or 0
        if statusNum == 200 and response and response ~= '' then
            local ok, data = pcall(json.decode, response)
            if ok and data and data.upload_url then
                uploadUrl = tostring(data.upload_url)
            end
        end
        Citizen.CreateThread(function()
            TriggerClientEvent('modora:screenshotUploadUrl', source, uploadUrl)
        end)
    end, 2)
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
    -- Don't manually set Host header 
    -- if hostHeader and hostHeader ~= '' then
    --     testHeaders['Host'] = hostHeader
    -- end

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

    testHttpEndpoint('http://example.com', 'example-http')
    testHttpEndpoint('http://api.modoralabs.com/test', 'modora-http-test')
    testHttpEndpoint('https://api.modoralabs.com/test', 'modora-https-test')

    local ip = '157.180.103.21'
    local function testIpEndpoint(url, label, hostHeader)
        local headers = {
            ['Accept'] = '*/*',
        }
        -- Don't manually set Host header
        -- if hostHeader and hostHeader ~= '' then
        --     headers['Host'] = hostHeader
        -- end

        print('[Modora] HTTP debug: ' .. label .. ' -> ' .. url .. (hostHeader and (' (Host=' .. hostHeader .. ')') or ''))

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

    testIpEndpoint('http://' .. ip .. '/test', 'modora-ip-http-test', 'api.modoralabs.com')
    testIpEndpoint('https://' .. ip .. '/test', 'modora-ip-https-test', 'api.modoralabs.com')
end, false)

-- ============================================
-- CONFIGURATION VALIDATION
-- ============================================

Citizen.CreateThread(function()
    Citizen.Wait(2000)

    local baseUrl, _, token = getEffectiveAPIConfig()
    local configValid = (baseUrl and baseUrl ~= '' and token and token ~= '')

    if not configValid then
        print('^1[Modora] Set Config.ModoraAPIBase and Config.APIToken in config.lua (from Dashboard → FiveM → your server).^7')
    else
        print('^2[Modora] Configuration OK^7')
        Citizen.Wait(1000)
        testAPIConnection()
    end
end)
