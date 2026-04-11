-- ============================================
-- Modora FiveM Control Center — Client Moderation
-- ============================================

-- Warn from Discord: show message in chat
RegisterNetEvent('modora:receiveWarn')
AddEventHandler('modora:receiveWarn', function(reason, staffName)
    local msg = '[Modora] Warning'
    if staffName and staffName ~= '' then
        msg = msg .. ' (by ' .. tostring(staffName) .. ')'
    end
    msg = msg .. ': ' .. tostring(reason or 'No reason provided')
    TriggerEvent('chat:addMessage', {
        color = { 255, 165, 0 },
        multiline = true,
        args = { '[Modora]', msg }
    })
end)
