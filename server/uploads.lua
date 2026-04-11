-- ============================================
-- Modora FiveM Control Center — Server Uploads
-- ============================================
-- Depends on: server/api.lua (getEffectiveAPIConfig, buildAuthHeaders, performHttpRequestWithRetry)

RegisterNetEvent('modora:getScreenshotUploadUrl')
AddEventHandler('modora:getScreenshotUploadUrl', function()
    local source = source
    local baseUrl, _, token = getEffectiveAPIConfig()
    baseUrl = (baseUrl or ''):gsub('/+$', ''):match('^%s*(.-)%s*$')
    if baseUrl == '' or (token or '') == '' then
        TriggerClientEvent('modora:screenshotUploadUrl', source, '')
        return
    end
    local url = baseUrl .. '/upload-token'
    local headers = buildAuthHeaders()
    performHttpRequestWithRetry(url, 'POST', '{}', headers, function(statusCode, response)
        local uploadUrl = ''
        local statusNum = tonumber(statusCode) or 0
        if statusNum == 200 and response and response ~= '' then
            local ok, data = pcall(json.decode, response)
            if ok and data and data.upload_url then
                uploadUrl = tostring(data.upload_url)
            end
        end
        Citizen.CreateThread(function()
            TriggerClientEvent('modora:screenshotUploadUrl', source, uploadUrl)
        end)
    end, 2)
end)
