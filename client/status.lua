-- ============================================
-- Modora FiveM Control Center — Client Report Status View (v2)
-- ============================================
-- Depends on: client/bootstrap.lua (isMenuOpen)

local isStatusOpen = false

RegisterCommand('reportstatus', function()
    if isMenuOpen or isStatusOpen then return end
    isStatusOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'OPEN_STATUS' })
    TriggerServerEvent('modora:requestReportStatuses')
end, false)

RegisterNUICallback('closeStatus', function(data, cb)
    SetNuiFocus(false, false)
    isStatusOpen = false
    cb('ok')
end)

RegisterNUICallback('refreshStatuses', function(data, cb)
    TriggerServerEvent('modora:requestReportStatuses')
    cb('ok')
end)

RegisterNetEvent('modora:reportStatusUpdate')
AddEventHandler('modora:reportStatusUpdate', function(reports)
    SendNUIMessage({ action = 'STATUS_UPDATE', reports = reports })
end)
