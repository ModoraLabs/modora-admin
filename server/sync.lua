-- ============================================
-- Modora FiveM Control Center — Server Report Status Sync (v2)
-- ============================================
-- Depends on: server/api.lua (getEffectiveAPIConfig, buildAuthHeaders)

-- Poll for report status updates
local reportStatusCache = {}

function PollReportStatuses(source)
    -- Get player's FiveM ID
    local fivemId = source
    local base, _, _ = getEffectiveAPIConfig()
    local headers = buildAuthHeaders()

    if not base or base == '' then return end

    PerformHttpRequest(base .. '/reports/mine?reporter_id=' .. tostring(fivemId), function(statusCode, response)
        if statusCode == 200 and response then
            local success, data = pcall(json.decode, response)
            if success and data and data.reports then
                -- Send to client NUI
                TriggerClientEvent('modora:reportStatusUpdate', source, data.reports)
            end
        end
    end, 'GET', '', headers)
end

RegisterNetEvent('modora:requestReportStatuses')
AddEventHandler('modora:requestReportStatuses', function()
    local source = source
    PollReportStatuses(source)
end)
