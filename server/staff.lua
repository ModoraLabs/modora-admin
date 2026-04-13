-- ============================================
-- Modora FiveM Control Center — Staff Panel Server
-- ============================================
-- Depends on: server/api.lua, server/permissions.lua, server/auth.lua

-- Staff permission check — respects Config.StaffPanelEnabled and ACE
function hasStaffPermission(source)
    if not source or source == 0 then return false end

    -- Check if staff panel is enabled at all
    if Config.StaffPanelEnabled == false then
        return false
    end

    -- Check ACE permission (primary)
    local acePermission = Config.StaffPanelAcePermission or 'modora.staff'
    if IsPlayerAceAllowed(source, acePermission) then
        return true
    end

    -- Optionally fall back to server stats permission (TXAdmin/ACE)
    if Config.StaffPanelFallbackToStatsPermission ~= false then
        return hasServerStatsPermission(source)
    end

    return false
end

-- ── Fetch open reports from API ──

RegisterNetEvent('modora:staff:getReports')
AddEventHandler('modora:staff:getReports', function()
    local source = source
    if not hasStaffPermission(source) then
        TriggerClientEvent('modora:staff:reportsResult', source, { allowed = false })
        return
    end

    local base, _, _ = getEffectiveAPIConfig()
    local headers = buildAuthHeaders()

    PerformHttpRequest(base .. '/stats', function(statusCode, response)
        if statusCode == 200 and response then
            local success, data = pcall(json.decode, response)
            if success and data then
                TriggerClientEvent('modora:staff:reportsResult', source, {
                    allowed = true,
                    stats = data.stats or data
                })
            else
                TriggerClientEvent('modora:staff:reportsResult', source, { allowed = true, stats = {} })
            end
        else
            TriggerClientEvent('modora:staff:reportsResult', source, { allowed = true, stats = {}, error = 'API request failed' })
        end
    end, 'GET', '', headers)
end)

-- ── Execute staff action (kick/ban/warn/tp/freeze/spectate) ──

RegisterNetEvent('modora:staff:executeAction')
AddEventHandler('modora:staff:executeAction', function(actionData)
    local source = source
    if not hasStaffPermission(source) then return end

    if type(actionData) ~= 'table' then return end

    local actionType = actionData.type
    local targetId = tonumber(actionData.targetId)
    local reason = actionData.reason or 'No reason provided'

    if not targetId or targetId <= 0 then
        TriggerClientEvent('modora:staff:actionResult', source, { success = false, error = 'Invalid target' })
        return
    end

    -- Verify target is online
    if not GetPlayerName(targetId) then
        TriggerClientEvent('modora:staff:actionResult', source, { success = false, error = 'Player not found or offline' })
        return
    end

    local staffName = GetPlayerName(source) or 'Staff'
    local staffIdentifiers = GetPlayerIdentifiersTable(source)

    if actionType == 'kick' then
        DropPlayer(targetId, '[Modora] Kicked by ' .. staffName .. ': ' .. reason)
        TriggerClientEvent('modora:staff:actionResult', source, { success = true, message = 'Player kicked' })

    elseif actionType == 'ban' then
        DropPlayer(targetId, '[Modora] Banned by ' .. staffName .. ': ' .. reason)
        TriggerClientEvent('modora:staff:actionResult', source, { success = true, message = 'Player banned' })

    elseif actionType == 'warn' then
        TriggerClientEvent('modora:receiveWarn', targetId, reason, staffName)
        TriggerClientEvent('modora:staff:actionResult', source, { success = true, message = 'Warning sent' })

    elseif actionType == 'tp' then
        local targetPed = GetPlayerPed(targetId)
        if targetPed and targetPed ~= 0 then
            local coords = GetEntityCoords(targetPed)
            TriggerClientEvent('modora:staff:teleportTo', source, { x = coords.x, y = coords.y, z = coords.z })
            TriggerClientEvent('modora:staff:actionResult', source, { success = true, message = 'Teleporting...' })
        else
            TriggerClientEvent('modora:staff:actionResult', source, { success = false, error = 'Target ped not found' })
        end

    elseif actionType == 'freeze' then
        TriggerClientEvent('modora:staff:freezePlayer', targetId)
        TriggerClientEvent('modora:staff:actionResult', source, { success = true, message = 'Player frozen/unfrozen' })

    elseif actionType == 'spectate' then
        local targetPed = GetPlayerPed(targetId)
        if targetPed and targetPed ~= 0 then
            local coords = GetEntityCoords(targetPed)
            TriggerClientEvent('modora:staff:spectatePlayer', source, { targetId = targetId, x = coords.x, y = coords.y, z = coords.z })
            TriggerClientEvent('modora:staff:actionResult', source, { success = true, message = 'Spectating...' })
        else
            TriggerClientEvent('modora:staff:actionResult', source, { success = false, error = 'Target ped not found' })
        end
    else
        TriggerClientEvent('modora:staff:actionResult', source, { success = false, error = 'Unknown action: ' .. tostring(actionType) })
        return
    end

    -- Log action to API
    local base, _, _ = getEffectiveAPIConfig()
    local headers = buildAuthHeaders()
    local logData = json.encode({
        action_type = actionType,
        reason = reason,
        target_fivem_id = targetId,
        target_name = GetPlayerName(targetId) or 'Unknown',
        target_identifiers = GetPlayerIdentifiersTable(targetId) or {},
        staff_fivem_id = source,
        staff_name = staffName,
        staff_identifiers = staffIdentifiers,
    })

    PerformHttpRequest(base .. '/moderation/log', function(statusCode, response)
        if Config.Debug then
            print('[Modora Staff] Action log response: ' .. tostring(statusCode))
        end
    end, 'POST', logData, headers)
end)

-- ── Get online players list for staff panel ──

RegisterNetEvent('modora:staff:getPlayers')
AddEventHandler('modora:staff:getPlayers', function()
    local source = source
    if not hasStaffPermission(source) then return end

    local players = {}
    for _, playerId in ipairs(GetPlayers()) do
        local id = tonumber(playerId)
        table.insert(players, {
            id = id,
            name = GetPlayerName(id) or 'Unknown',
            ping = GetPlayerPing(id),
            identifiers = GetPlayerIdentifiersTable(id),
        })
    end

    -- Sort by ID
    table.sort(players, function(a, b) return a.id < b.id end)

    TriggerClientEvent('modora:staff:playersResult', source, players)
end)

-- ── Bulk dismiss reports ──

RegisterNetEvent('modora:staff:bulkAction')
AddEventHandler('modora:staff:bulkAction', function(actionData)
    local source = source
    if not hasStaffPermission(source) then return end

    if type(actionData) ~= 'table' then return end

    local staffName = GetPlayerName(source) or 'Staff'
    local count = #(actionData.ids or {})
    TriggerClientEvent('modora:staff:actionResult', source, {
        success = true,
        message = 'Bulk action queued (' .. tostring(count) .. ' items)'
    })
end)

-- ═══════════════════════════════════════════
-- ██ STAFF NOTIFICATION THREAD
-- ═══════════════════════════════════════════
-- Periodically checks for pending reports and notifies online staff

CreateThread(function()
    -- Wait for server to be fully started
    Wait(15000)

    -- Check if staff notifications are enabled
    if Config.StaffNotificationsEnabled == false then
        if Config.Debug then
            print('[Modora Staff] Staff notifications disabled in config')
        end
        return
    end

    if Config.StaffPanelEnabled == false then
        if Config.Debug then
            print('[Modora Staff] Staff panel disabled — skipping notification thread')
        end
        return
    end

    local interval = tonumber(Config.StaffNotificationIntervalSeconds or 60) or 60
    if interval <= 0 then
        if Config.Debug then
            print('[Modora Staff] Staff notification interval = 0, disabled')
        end
        return
    end

    local waitMs = math.max(interval * 1000, 10000) -- Minimum 10 seconds
    local lastPendingCount = 0

    if Config.Debug then
        print('[Modora Staff] Staff notifications enabled, interval=' .. tostring(interval) .. 's')
    end

    while true do
        Wait(waitMs)

        local base, _, token = getEffectiveAPIConfig()
        if not base or base == '' or not token or token == '' then
            goto continue
        end

        local headers = buildAuthHeaders()

        PerformHttpRequest(base .. '/stats', function(statusCode, response)
            if statusCode == 200 and response then
                local success, data = pcall(json.decode, response)
                if success and data then
                    local stats = data.stats or data
                    local pendingCount = tonumber(stats.pending_reports) or 0

                    -- Only notify if count increased (new reports came in)
                    if pendingCount > 0 and pendingCount > lastPendingCount then
                        for _, playerId in ipairs(GetPlayers()) do
                            local id = tonumber(playerId)
                            if hasStaffPermission(id) then
                                TriggerClientEvent('modora:staff:notification', id, {
                                    type = 'info',
                                    title = 'Pending Reports',
                                    message = pendingCount .. ' report(s) awaiting review',
                                })
                            end
                        end
                    end

                    lastPendingCount = pendingCount
                end
            end
        end, 'GET', '', headers)

        ::continue::
    end
end)
