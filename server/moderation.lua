-- Moderation bridge: command queue, bans, whitelist (part of modora-admin)
-- Bans/whitelist are merged from Modora API + optional TXAdmin sync
local banCache = {}
local whitelistCache = {}

local function log(msg)
    print('^2[Modora]^7 ' .. tostring(msg))
end

local function logDebug(msg)
    if Config.Debug then
        print('^3[Modora]^7 ' .. tostring(msg))
    end
end

local function buildAuthHeaders()
    local token = (Config.APIToken or ''):gsub('^%s*(.-)%s*$', '%1')
    return {
        ['Content-Type'] = 'application/json',
        ['Authorization'] = 'Bearer ' .. token,
        ['User-Agent'] = 'Modora-FiveM-Admin/1.0',
        ['Accept'] = 'application/json',
    }
end

local function apiBase()
    return (Config.ModoraAPIBase or ''):gsub('/+$', ''):match('^%s*(.-)%s*$')
end

-- Normalize a ban entry from TXAdmin-style response to { identifier_type, identifier_value, reason }
local function normalizeTxAdminBan(entry)
    if not entry or type(entry) ~= 'table' then return nil end
    local identifiers = entry.identifiers or entry
    local reason = entry.reason or entry.reasonMessage or entry.message or 'Banned'
    if type(identifiers) == 'table' then
        for idType, value in pairs(identifiers) do
            if value and value ~= '' and (idType == 'license' or idType == 'discord' or idType == 'steam' or idType == 'license2') then
                return { identifier_type = idType, identifier_value = tostring(value), reason = reason }
            end
        end
    end
    if entry.license and entry.license ~= '' then
        return { identifier_type = 'license', identifier_value = tostring(entry.license), reason = reason }
    end
    if entry.discord and entry.discord ~= '' then
        return { identifier_type = 'discord', identifier_value = tostring(entry.discord), reason = reason }
    end
    return nil
end

local function normalizeTxAdminWhitelist(entry)
    if not entry or type(entry) ~= 'table' then return nil end
    local identifiers = entry.identifiers or entry
    if type(identifiers) == 'table' then
        for idType, value in pairs(identifiers) do
            if value and value ~= '' and (idType == 'license' or idType == 'discord' or idType == 'steam') then
                return { identifier_type = idType, identifier_value = tostring(value) }
            end
        end
    end
    if entry.license and entry.license ~= '' then
        return { identifier_type = 'license', identifier_value = tostring(entry.license) }
    end
    return nil
end

local function fetchTxAdminBans(cb)
    local base = (Config.TXAdminBaseUrl or ''):gsub('/+$', '')
    if base == '' then if cb then cb({}) end return end
    local path = (Config.TXAdminBansPath or '/api/bans'):gsub('^/+', '')
    local url = base .. '/' .. path
    local headers = { ['Content-Type'] = 'application/json', ['Accept'] = 'application/json' }
    if Config.TXAdminToken and Config.TXAdminToken ~= '' then
        headers['Authorization'] = 'Bearer ' .. (Config.TXAdminToken or '')
    end
    PerformHttpRequest(url, function(statusCode, response, hdrs)
        if tonumber(statusCode) ~= 200 or not response then if cb then cb({}) end return end
        local ok, data = pcall(json.decode, response)
        if not ok or not data then if cb then cb({}) end return end
        local list = type(data) == 'table' and (data.bans or data.data or data) or {}
        if type(list) ~= 'table' then list = {} end
        local out = {}
        for _, entry in ipairs(list) do
            local b = normalizeTxAdminBan(entry)
            if b then table.insert(out, b) end
        end
        if cb then cb(out) end
    end, 'GET', '', headers)
end

local function fetchTxAdminWhitelist(cb)
    local base = (Config.TXAdminBaseUrl or ''):gsub('/+$', '')
    if base == '' then if cb then cb({}) end return end
    local path = (Config.TXAdminWhitelistPath or '/api/whitelist'):gsub('^/+', '')
    local url = base .. '/' .. path
    local headers = { ['Content-Type'] = 'application/json', ['Accept'] = 'application/json' }
    if Config.TXAdminToken and Config.TXAdminToken ~= '' then
        headers['Authorization'] = 'Bearer ' .. (Config.TXAdminToken or '')
    end
    PerformHttpRequest(url, function(statusCode, response, hdrs)
        if tonumber(statusCode) ~= 200 or not response then if cb then cb({}) end return end
        local ok, data = pcall(json.decode, response)
        if not ok or not data then if cb then cb({}) end return end
        local list = type(data) == 'table' and (data.whitelist or data.data or data) or {}
        if type(list) ~= 'table' then list = {} end
        local out = {}
        for _, entry in ipairs(list) do
            local w = normalizeTxAdminWhitelist(entry)
            if w then table.insert(out, w) end
        end
        if cb then cb(out) end
    end, 'GET', '', headers)
end

local function fetchCommandQueue(cb)
    local base = apiBase()
    if base == '' or (Config.APIToken or '') == '' then
        if cb then cb(false, nil, 'Not configured') end
        return
    end
    local url = base .. '/moderation/command-queue'
    PerformHttpRequest(url, function(statusCode, response, headers)
        local statusNum = tonumber(statusCode) or 0
        if statusNum ~= 200 or not response then
            local err = 'HTTP ' .. tostring(statusCode)
            if statusNum == 404 then
                err = err .. ' (URL: ' .. url .. ' — use api.modora.xyz or IP as ModoraAPIBase in config.lua, e.g. https://api.modora.xyz or http://JOUW_IP with ModoraHostHeader)'
            end
            if cb then cb(false, nil, err) end
            return
        end
        local ok, data = pcall(json.decode, response)
        if not ok or not data then
            if cb then cb(false, nil, 'Invalid JSON') end
            return
        end
        if cb then cb(true, data, nil) end
    end, 'GET', '', buildAuthHeaders())
end

local function sendCommandAck(commandId, success, result)
    local base = apiBase()
    if base == '' or (Config.APIToken or '') == '' then return end
    local url = base .. '/moderation/command-ack'
    local body = json.encode({
        command_id = commandId,
        success = success and true or false,
        result = result or {}
    })
    PerformHttpRequest(url, function(statusCode, response, headers)
        logDebug('Ack command ' .. tostring(commandId) .. ' status=' .. tostring(statusCode))
    end, 'POST', body, buildAuthHeaders())
end

local function getPlayerIdentifiers(source)
    local t = {}
    for i = 0, GetNumPlayerIdentifiers(source) - 1 do
        local id = GetPlayerIdentifier(source, i)
        if id then
            local prefix, value = id:match('^([^:]+):(.+)$')
            if prefix and value then
                t[prefix] = value
            end
        end
    end
    return t
end

local function findPlayerByIdentifiers(targetIds)
    if not targetIds or type(targetIds) ~= 'table' then return nil end
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        if src then
            local ids = getPlayerIdentifiers(src)
            for typ, val in pairs(targetIds) do
                if ids[typ] == val then
                    return src
                end
            end
        end
    end
    return nil
end

local function executeCommand(cmd)
    local cmdType = cmd.command_type
    local payload = cmd.payload or {}
    local targetIds = payload.target_identifiers or {}
    local source = findPlayerByIdentifiers(targetIds)

    if Config.Debug then
        logDebug('Moderation: Executing ' .. tostring(cmdType) .. ' target=' .. tostring(source))
    end

    local ok, err = true, nil
    if cmdType == 'kick' then
        if not source then
            ok, err = false, 'Player not online'
        else
            DropPlayer(source, payload.reason or 'Kicked by staff')
        end
    elseif cmdType == 'ban' or cmdType == 'tempban' then
        if source then
            DropPlayer(source, payload.reason or 'Banned')
        end
        ok = true
    elseif cmdType == 'unban' then
        ok = true
    elseif cmdType == 'warn' then
        if source then
            TriggerClientEvent('modora:moderation:warn', source, payload.reason or 'You have been warned.')
        end
        ok = true
    elseif cmdType == 'whitelist_add' or cmdType == 'whitelist_remove' then
        ok = true
    else
        ok, err = false, 'Unknown command type'
    end

    sendCommandAck(cmd.id, ok, err and { error = err } or {})
end

if Config.ModerationEnabled then
    CreateThread(function()
        if apiBase() == '' or (Config.APIToken or '') == '' then
            log('Moderation: API not configured. Set Config.APIToken and Config.ModoraAPIBase (or convars).')
            return
        end
        log('Moderation bridge started. Poll interval: ' .. tostring(Config.PollIntervalSeconds) .. 's')
        while true do
            Wait((Config.PollIntervalSeconds or 10) * 1000)
            fetchCommandQueue(function(success, data, err)
                if not success or not data then
                    logDebug('Moderation poll failed: ' .. tostring(err))
                    return
                end
                local modoraBans = (data.bans and type(data.bans) == 'table') and data.bans or {}
                local modoraWhitelist = (data.whitelist and type(data.whitelist) == 'table') and data.whitelist or {}
                fetchTxAdminBans(function(txBans)
                    -- Merge Modora + TXAdmin bans (both apply)
                    local seen = {}
                    banCache = {}
                    for _, b in ipairs(modoraBans) do
                        local k = (b.identifier_type or '') .. ':' .. (b.identifier_value or '')
                        if not seen[k] then seen[k] = true; table.insert(banCache, b) end
                    end
                    for _, b in ipairs(txBans or {}) do
                        local k = (b.identifier_type or '') .. ':' .. (b.identifier_value or '')
                        if not seen[k] then seen[k] = true; table.insert(banCache, b) end
                    end
                    fetchTxAdminWhitelist(function(txWhitelist)
                        local wSeen = {}
                        whitelistCache = {}
                        for _, w in ipairs(modoraWhitelist) do
                            local k = (w.identifier_type or '') .. ':' .. (w.identifier_value or '')
                            if not wSeen[k] then wSeen[k] = true; table.insert(whitelistCache, w) end
                        end
                        for _, w in ipairs(txWhitelist or {}) do
                            local k = (w.identifier_type or '') .. ':' .. (w.identifier_value or '')
                            if not wSeen[k] then wSeen[k] = true; table.insert(whitelistCache, w) end
                        end
                        if data.commands and type(data.commands) == 'table' then
                            for _, cmd in ipairs(data.commands) do
                                executeCommand(cmd)
                            end
                        end
                    end)
                end)
            end)
        end
    end)

    CreateThread(function()
        Wait(2000)
        if apiBase() == '' or (Config.APIToken or '') == '' then return end
        fetchCommandQueue(function(success, data, err)
            if success and data then
                local modoraBans = (data.bans and type(data.bans) == 'table') and data.bans or {}
                local modoraWhitelist = (data.whitelist and type(data.whitelist) == 'table') and data.whitelist or {}
                fetchTxAdminBans(function(txBans)
                    local seen = {}
                    banCache = {}
                    for _, b in ipairs(modoraBans) do
                        local k = (b.identifier_type or '') .. ':' .. (b.identifier_value or '')
                        if not seen[k] then seen[k] = true; table.insert(banCache, b) end
                    end
                    for _, b in ipairs(txBans or {}) do
                        local k = (b.identifier_type or '') .. ':' .. (b.identifier_value or '')
                        if not seen[k] then seen[k] = true; table.insert(banCache, b) end
                    end
                    fetchTxAdminWhitelist(function(txWhitelist)
                        local wSeen = {}
                        whitelistCache = {}
                        for _, w in ipairs(modoraWhitelist) do
                            local k = (w.identifier_type or '') .. ':' .. (w.identifier_value or '')
                            if not wSeen[k] then wSeen[k] = true; table.insert(whitelistCache, w) end
                        end
                        for _, w in ipairs(txWhitelist or {}) do
                            local k = (w.identifier_type or '') .. ':' .. (w.identifier_value or '')
                            if not wSeen[k] then wSeen[k] = true; table.insert(whitelistCache, w) end
                        end
                        log('Moderation initial sync: ' .. #(banCache or {}) .. ' bans, ' .. #(whitelistCache or {}) .. ' whitelist (incl. TXAdmin)')
                    end)
                end)
            end
        end)
    end)

    AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
        local source = source
        deferrals.defer()
        Wait(0)
        deferrals.update('Checking Modora moderation...')

        local ids = getPlayerIdentifiers(source)
        if not ids or not ids.license then
            deferrals.done('Could not get identifiers.')
            return
        end

        local function isBanned()
            for _, b in ipairs(banCache or {}) do
                local v = ids[b.identifier_type]
                if v and v == b.identifier_value then
                    return true, b.reason or 'Banned'
                end
            end
            return false
        end

        local function isWhitelisted()
            for _, w in ipairs(whitelistCache or {}) do
                local v = ids[w.identifier_type]
                if v and v == w.identifier_value then
                    return true
                end
            end
            return false
        end

        local banned, reason = isBanned()
        if banned then
            deferrals.done(reason or 'You are banned from this server.')
            return
        end

        if Config.WhitelistOnly then
            if not isWhitelisted() then
                deferrals.done('You are not on the whitelist.')
                return
            end
        end

        deferrals.done()
    end)

    exports('getBanCache', function() return banCache end)
    exports('getWhitelistCache', function() return whitelistCache end)
end
