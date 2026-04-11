-- ============================================
-- Modora FiveM Control Center — Staff Panel Client
-- ============================================
-- Depends on: client/bootstrap.lua (isMenuOpen, isServerStatsOpen)

isStaffPanelOpen = false

-- ── Open staff panel with /mstaff or keybind ──

RegisterCommand('mstaff', function()
    if isMenuOpen or isServerStatsOpen then return end
    if isStaffPanelOpen then
        SetNuiFocus(false, false)
        isStaffPanelOpen = false
        SendNUIMessage({ action = 'CLOSE_STAFF' })
        return
    end

    isStaffPanelOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'OPEN_STAFF' })

    -- Request data
    TriggerServerEvent('modora:staff:getReports')
    TriggerServerEvent('modora:staff:getPlayers')
end, false)

-- Register keybind (F6 default for staff)
RegisterKeyMapping('mstaff', 'Open Modora Staff Panel', 'keyboard', 'F6')

-- ── NUI callbacks ──

RegisterNUICallback('closeStaff', function(data, cb)
    SetNuiFocus(false, false)
    isStaffPanelOpen = false
    cb('ok')
end)

RegisterNUICallback('staffAction', function(data, cb)
    TriggerServerEvent('modora:staff:executeAction', data)
    cb('ok')
end)

RegisterNUICallback('staffRefreshPlayers', function(data, cb)
    TriggerServerEvent('modora:staff:getPlayers')
    cb('ok')
end)

RegisterNUICallback('staffRefreshReports', function(data, cb)
    TriggerServerEvent('modora:staff:getReports')
    cb('ok')
end)

RegisterNUICallback('staffBulkAction', function(data, cb)
    TriggerServerEvent('modora:staff:bulkAction', data)
    cb('ok')
end)

-- ── Server event handlers ──

RegisterNetEvent('modora:staff:reportsResult')
AddEventHandler('modora:staff:reportsResult', function(data)
    if not data.allowed then
        TriggerEvent('chat:addMessage', {
            color = {255, 100, 100},
            args = {'[Modora]', 'You do not have permission to access the staff panel.'}
        })
        SetNuiFocus(false, false)
        isStaffPanelOpen = false
        SendNUIMessage({ action = 'CLOSE_STAFF' })
        return
    end
    SendNUIMessage({ action = 'STAFF_REPORTS_UPDATE', data = data })
end)

RegisterNetEvent('modora:staff:playersResult')
AddEventHandler('modora:staff:playersResult', function(players)
    SendNUIMessage({ action = 'STAFF_PLAYERS_UPDATE', players = players })
end)

RegisterNetEvent('modora:staff:actionResult')
AddEventHandler('modora:staff:actionResult', function(result)
    SendNUIMessage({ action = 'STAFF_ACTION_RESULT', result = result })
    -- Also refresh player list after actions
    TriggerServerEvent('modora:staff:getPlayers')
end)

RegisterNetEvent('modora:staff:teleportTo')
AddEventHandler('modora:staff:teleportTo', function(coords)
    local ped = PlayerPedId()
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
end)

RegisterNetEvent('modora:staff:freezePlayer')
AddEventHandler('modora:staff:freezePlayer', function()
    local ped = PlayerPedId()
    local isFrozen = IsEntityPositionFrozen(ped)
    FreezeEntityPosition(ped, not isFrozen)
end)

RegisterNetEvent('modora:staff:spectatePlayer')
AddEventHandler('modora:staff:spectatePlayer', function(data)
    if not data then return end
    local ped = PlayerPedId()
    SetEntityCoords(ped, data.x, data.y, data.z + 10.0, false, false, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    SetEntityAlpha(ped, 0, false)
    SetEntityCollision(ped, false, false)

    TriggerEvent('chat:addMessage', {
        color = {177, 137, 251},
        args = {'[Modora]', 'Spectating player. Use /mstaff to stop.'}
    })
end)

-- ── Staff notifications ──

RegisterNetEvent('modora:staff:notification')
AddEventHandler('modora:staff:notification', function(notification)
    if not notification then return end
    -- Show as NUI toast if staff panel is open, otherwise show chat message
    if isStaffPanelOpen then
        SendNUIMessage({ action = 'STAFF_NOTIFICATION', notification = notification })
    else
        TriggerEvent('chat:addMessage', {
            color = {177, 137, 251},
            args = {'[Modora]', notification.message or 'New notification'}
        })
    end

    -- Play notification sound
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', false)
end)

-- ── Warn received handler (for target player) ──

RegisterNetEvent('modora:receiveWarn')
AddEventHandler('modora:receiveWarn', function(reason, staffName)
    TriggerEvent('chat:addMessage', {
        color = {255, 200, 0},
        args = {'[Modora Warning]', 'You have been warned by ' .. (staffName or 'Staff') .. ': ' .. (reason or 'No reason provided')}
    })
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', false)
end)
