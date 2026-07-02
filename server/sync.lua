-- ============================================
-- Modora FiveM Control Center — Server Report Status Sync (v2)
-- ============================================
-- Depends on: server/api.lua (getEffectiveAPIConfig, buildAuthHeaders)

-- Poll for report status updates
local reportStatusCache = {}

function PollReportStatuses(source)
    -- Reports are keyed by the reporter's FiveM id (the server session id used when the
    -- report was submitted). This matches within the same play session; across reconnects
    -- the session id changes, so older reports won't resolve here.
    local fivemId = source
    local base, _, token = getEffectiveAPIConfig()
    local headers = buildAuthHeaders()

    if not base or base == '' then return end
    if not token or token == '' then return end

    local url = base:gsub('/+$', '') .. '/reports/mine?reporter_id=' .. tostring(fivemId)

    -- Use the resilient request path (retries on connection failure) and accept both 200 and
    -- 302: a reverse proxy in front of the API can return a redirect that still carries the
    -- JSON body (same handling as getServerConfig). The old code only accepted 200 and silently
    -- dropped 302 responses, so /reportstatus showed nothing.
    performHttpRequestWithRetry(url, 'GET', '', headers, function(statusCode, response)
        local statusNum = tonumber(statusCode) or 0

        if Config.Debug then
            print('[Modora] Report status response: statusCode=' .. tostring(statusCode) .. ' (num=' .. tostring(statusNum) .. ')')
            if response and #response > 0 then
                print('[Modora] Report status preview: ' .. string.sub(response, 1, 200))
            end
        end

        if (statusNum == 200 or statusNum == 302) and response and response ~= '' then
            local success, data = pcall(json.decode, response)
            if success and data then
                -- API returns { success = true, reports = [...] }; tolerate a bare array too.
                local reports = data.reports
                if reports == nil and type(data) == 'table' and data[1] ~= nil then
                    reports = data
                end
                TriggerClientEvent('modora:reportStatusUpdate', source, reports or {})
            end
        end
    end)
end

RegisterNetEvent('modora:requestReportStatuses')
AddEventHandler('modora:requestReportStatuses', function()
    local source = source
    PollReportStatuses(source)
end)
