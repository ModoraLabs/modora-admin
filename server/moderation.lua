-- ============================================
-- Modora FiveM Control Center — Server Moderation (Discord -> Game)
-- ============================================
-- Depends on: server/api.lua (getEffectiveAPIConfig, buildAuthHeaders)

local function reportModerationExecuted(actionId, success, errMsg)
    local baseUrl, _, token = getEffectiveAPIConfig()
    if not baseUrl or baseUrl == '' or not token or token == '' then return end
    baseUrl = baseUrl:gsub('/+$', '')
    local url = baseUrl .. '/moderation/executed'
    local headers = buildAuthHeaders()
    local body = json.encode({
        id = actionId,
        status = success and 'executed' or 'failed',
        error_message = errMsg or nil
    })
    PerformHttpRequest(url, function(statusCode, response)
        if Config.Debug then
            print('[Modora] Moderation executed report: HTTP ' .. tostring(statusCode) .. ' for action ' .. tostring(actionId))
        end
    end, 'POST', body, headers)
end

local function getPlayerIdByIdentifier(identifier)
    -- identifier can be "license:xxx", "discord:xxx", or we have target_fivem_id
    if not identifier or identifier == '' then return nil end
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        if not src then goto continue end
        for i = 0, GetNumPlayerIdentifiers(src) - 1 do
            local id = GetPlayerIdentifier(src, i)
            if id and string.lower(tostring(id)) == string.lower(tostring(identifier)) then
                return src
            end
        end
        ::continue::
    end
    return nil
end

function executeModerationAction(action)
    local actionId = action.id
    local actionType = action.action_type
    local targetFivemId = action.target_fivem_id
    local targetIdentifier = action.target_identifier
    local targetName = action.target_name or 'Unknown'
    local reason = action.reason or 'No reason provided'

    local targetSource = nil
    if targetFivemId and tonumber(targetFivemId) then
        targetSource = tonumber(targetFivemId)
        if not GetPlayerName(targetSource) then
            targetSource = nil
        end
    end
    if not targetSource and targetIdentifier and targetIdentifier ~= '' then
        targetSource = getPlayerIdByIdentifier(targetIdentifier)
    end
    if not targetSource then
        reportModerationExecuted(actionId, false, 'Player not online or identifier not found')
        return
    end

    if actionType == 'kick' then
        DropPlayer(targetSource, '[Modora] Kicked: ' .. tostring(reason))
        reportModerationExecuted(actionId, true, nil)
    elseif actionType == 'ban' then
        -- Drop and optionally persist ban via export if another resource provides it
        DropPlayer(targetSource, '[Modora] Banned: ' .. tostring(reason))
        reportModerationExecuted(actionId, true, nil)
    elseif actionType == 'warn' then
        TriggerClientEvent('modora:receiveWarn', targetSource, reason, action.actor_username)
        reportModerationExecuted(actionId, true, nil)
    else
        reportModerationExecuted(actionId, false, 'Unknown action_type: ' .. tostring(actionType))
    end
end

-- Moderation poll thread: fetch pending kick/ban/warn from API, execute them
CreateThread(function()
    local interval = tonumber(Config.ModerationPollIntervalSeconds or 0) or 0
    if interval <= 0 then
        if Config.Debug then
            print('[Modora] Moderation poll disabled (ModerationPollIntervalSeconds = 0)')
        end
        return
    end
    local waitMs = math.floor(interval * 1000)
    if Config.Debug then
        print('[Modora] Moderation poll enabled, interval=' .. tostring(interval) .. 's')
    end
    Wait(15000)
    while true do
        local baseUrl, _, token = getEffectiveAPIConfig()
        if baseUrl and baseUrl ~= '' and token and token ~= '' then
            baseUrl = baseUrl:gsub('/+$', '')
            local url = baseUrl .. '/moderation/pending'
            local headers = buildAuthHeaders()
            PerformHttpRequest(url, function(statusCode, response)
                local statusNum = tonumber(statusCode) or 0
                if statusNum == 200 and response and response ~= '' then
                    local ok, data = pcall(json.decode, response)
                    if ok and data and data.actions and type(data.actions) == 'table' then
                        for _, action in ipairs(data.actions) do
                            executeModerationAction(action)
                        end
                    end
                end
            end, 'GET', '', headers)
        end
        Wait(waitMs)
    end
end)
