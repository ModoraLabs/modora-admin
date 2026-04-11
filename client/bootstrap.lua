-- ============================================
-- Modora FiveM Control Center — Client Bootstrap
-- ============================================
-- State variables and command registration.

isMenuOpen = false
isServerStatsOpen = false
serverConfig = nil

print('[Modora] Client loaded. Config.Debug = ' .. tostring(Config.Debug))

-- Report command and keybind open the NUI report form.
RegisterCommand(Config.ReportCommand, function()
    if not Config.APIToken or Config.APIToken == '' then
        TriggerEvent('chat:addMessage', {
            color = {255, 165, 0},
            multiline = true,
            args = {'[Modora]', GetMessage('config_failed')}
        })
        return
    end

    if isMenuOpen then
        SetNuiFocus(false, false)
        isMenuOpen = false
        return
    end

    isMenuOpen = true
    SetNuiFocus(true, true)

    -- INIT: serverName (convar) and optional NUI branding
    local serverName = GetConvar('sv_projectName', '') or GetConvar('sv_hostname', '') or ''
    if serverName == '' then serverName = 'Server' end
    SendNUIMessage({
        action = 'openReport',
        type = 'INIT',
        serverName = serverName,
        cooldownRemaining = 0,
        playerName = GetPlayerName(PlayerId()),
        version = '2.0.0'
    })

    TriggerEvent('chat:addMessage', {
        color = {0, 255, 0},
        multiline = true,
        args = {'[Modora]', GetMessage('report_opened')}
    })
end, false)

if Config.ReportKeybind and Config.ReportKeybind ~= false then
    RegisterKeyMapping(Config.ReportCommand, 'Open Report Menu', 'keyboard', Config.ReportKeybind)
end

-- Server stats command
RegisterCommand(Config.ServerStatsCommand or 'serverstats', function()
    print('[Modora] /serverstats command run (Config.Debug=' .. tostring(Config.Debug) .. ')')
    if isServerStatsOpen then
        SetNuiFocus(false, false)
        isServerStatsOpen = false
        SendNUIMessage({ action = 'closeServerStats' })
        return
    end
    TriggerServerEvent('modora:requestServerStats')
end, false)
