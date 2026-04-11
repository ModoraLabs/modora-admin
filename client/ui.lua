-- ============================================
-- Modora FiveM Control Center — Client UI (NUI bridge, ESC handling)
-- ============================================
-- Depends on: client/bootstrap.lua (isMenuOpen, isServerStatsOpen)

-- Close report NUI callback
RegisterNUICallback('closeReport', function(data, cb)
    SetNuiFocus(false, false)
    isMenuOpen = false
    cb('ok')
end)

-- Close server stats NUI callback
RegisterNUICallback('closeServerStats', function(data, cb)
    SetNuiFocus(false, false)
    isServerStatsOpen = false
    cb('ok')
end)

-- Show message in chat and as on-screen notification (works even if chat resource is missing).
function serverStatsNotify(msg, isError)
    TriggerEvent('chat:addMessage', {
        color = isError and {255, 100, 100} or {100, 255, 100},
        multiline = true,
        args = {'[Modora]', msg}
    })
    pcall(function()
        BeginTextCommandThefeedPost("STRING")
        AddTextComponentSubstringPlayerName(msg)
        EndTextCommandThefeedPostTicker(false, false)
    end)
end

-- Server stats result handler
RegisterNetEvent('modora:serverStatsResult')
AddEventHandler('modora:serverStatsResult', function(payload)
    print('[Modora] ServerStats result received (allowed=' .. tostring(payload and payload.allowed) .. ')')
    if Config.Debug and payload and payload.stats then
        local s = payload.stats
        print('[Modora Debug] Stats: players=' .. tostring(s.playerCount) .. ' resources=' .. tostring(s.resourceCount) .. ' memoryKb=' .. tostring(s.memoryKb) .. ' hostMemoryMb=' .. tostring(s.hostMemoryMb) .. ' hostCpuPercent=' .. tostring(s.hostCpuPercent))
    end
    if not payload then
        serverStatsNotify(GetMessage('serverstats_denied'), true)
        return
    end
    if not payload.allowed then
        local msg = GetMessage('serverstats_denied')
        serverStatsNotify(msg, true)
        return
    end
    isServerStatsOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openServerStats',
        stats = payload.stats or {}
    })
    serverStatsNotify(GetMessage('serverstats_opened'), false)
end)

-- Server config received from server
RegisterNetEvent('modora:serverConfig')
AddEventHandler('modora:serverConfig', function(config)
    serverConfig = config
    SendNUIMessage({
        action = 'serverConfig',
        config = config
    })
end)

-- ESC closes the report or server stats NUI when open.
Citizen.CreateThread(function()
    while true do
        Wait(0)
        if isMenuOpen then
            DisableControlAction(0, 322, true) -- ESC
            DisableControlAction(0, 245, true) -- T
            DisableControlAction(0, 246, true) -- Y
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisablePlayerFiring(PlayerId(), true)

            if IsDisabledControlJustPressed(0, 322) then
                SetNuiFocus(false, false)
                isMenuOpen = false
                SendNUIMessage({
                    action = 'closeReport'
                })
            end
        elseif isServerStatsOpen then
            DisableControlAction(0, 322, true) -- ESC
            if IsDisabledControlJustPressed(0, 322) then
                SetNuiFocus(false, false)
                isServerStatsOpen = false
                SendNUIMessage({ action = 'closeServerStats' })
            end
        end
    end
end)
