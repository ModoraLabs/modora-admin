-- ============================================
-- Modora FiveM Control Center — Server Reports
-- ============================================
-- Depends on: server/api.lua (getEffectiveAPIConfig, buildAuthHeaders, performHttpRequestWithRetry)
-- Depends on: server/auth.lua (GetPlayerIdentifiersTable)

-- Fetches server config (categories, report form, etc.) from the API.
function getServerConfig(callback)
    local baseUrl, _, token = getEffectiveAPIConfig()
    if not baseUrl or baseUrl == '' then
        if callback then callback(false, 'API base URL not configured') end
        return
    end
    if not token or token == '' then
        if callback then callback(false, 'API token not configured') end
        return
    end
    if not baseUrl:match('^https?://') then
        if callback then callback(false, 'API base URL must start with http:// or https://') end
        return
    end
    local url = baseUrl .. '/config'
    local headers = buildAuthHeaders()
    if Config.Debug then
        print('[Modora] Fetching server config from: ' .. url)
        print('[Modora] API Token length: ' .. tostring(string.len(token or '')))
        print('[Modora] API Token preview: ' .. string.sub(token or '', 1, 10) .. '...')
    end

    performHttpRequestWithRetry(url, 'GET', '', headers, function(statusCode, response, responseHeaders, maxRetries, retryCount)
        local statusNum = tonumber(statusCode) or 0
        maxRetries = maxRetries or 3
        retryCount = retryCount or 0

        if Config.Debug then
            print('[Modora] Config request response: statusCode=' .. tostring(statusCode) .. ' (num=' .. tostring(statusNum) .. ')')
            print('[Modora] Retries attempted: ' .. tostring(retryCount) .. '/' .. tostring(maxRetries))
        end

        if statusNum == 0 then
            local errorMsg = 'Connection failed after retries.'
            if callback then callback(false, errorMsg) end
        elseif (statusNum == 200 or statusNum == 302) and response and response ~= '' then
            -- 302: API may return redirect with JSON body (e.g. reverse proxy); parse body as config
            local success, data = pcall(json.decode, response)
            if success and data and (data.serverId or data.reportFormConfig or data.categories) then
                if callback then callback(true, data) end
            elseif success and data then
                if callback then callback(true, data) end
            else
                if callback then callback(false, 'Failed to parse config response') end
            end
        elseif statusNum == 401 then
            if callback then callback(false, 'Authentication failed. Check your API token.') end
        else
            local errorMsg = 'HTTP ' .. tostring(statusCode)
            if response then errorMsg = errorMsg .. ': ' .. response end
            if callback then callback(false, errorMsg) end
        end
    end)
end

-- Submits report payload to the API and returns result via callback.
local function submitReport(reportData, callback)
    local baseUrl, _, token = getEffectiveAPIConfig()
    if not baseUrl or baseUrl == '' then
        if callback then callback(false, nil, 'API base URL not configured') end
        return
    end
    if not token or token == '' then
        if callback then callback(false, nil, 'API token not configured') end
        return
    end
    baseUrl = baseUrl:gsub('/+$', ''):match('^%s*(.-)%s*$')

    if not baseUrl:match('^https?://') then
        if callback then callback(false, nil, 'API base URL must start with http:// or https://') end
        return
    end

    local url = baseUrl .. '/reports'
    local body = json.encode(reportData)
    local headers = buildAuthHeaders()

    if Config.Debug then
        print('[Modora] Submitting report to: ' .. url)
        print('[Modora] API Token length: ' .. tostring(string.len(Config.APIToken or '')))
        print('[Modora] API Token preview: ' .. string.sub(Config.APIToken or '', 1, 10) .. '...')
        print('[Modora] Report data: ' .. body)
    end

    performHttpRequestWithRetry(url, 'POST', body, headers, function(statusCode, response, responseHeaders, maxRetries, retryCount)
        local statusNum = tonumber(statusCode) or 0
        maxRetries = maxRetries or 3
        retryCount = retryCount or 0

        if Config.Debug then
            print('[Modora] Report submission response: statusCode=' .. tostring(statusCode) .. ' (num=' .. tostring(statusNum) .. ')')
            print('[Modora] Retries attempted: ' .. tostring(retryCount) .. '/' .. tostring(maxRetries))
        end

        if statusNum == 0 then
            local errorMsg = 'Connection failed after ' .. tostring(retryCount) .. ' retry attempts.'
            if callback then callback(false, nil, errorMsg, nil) end
        elseif statusNum == 201 or statusNum == 200 then
            local success, data = pcall(json.decode, response)
            if success and data then
                if callback then callback(true, data, nil, nil) end
            else
                if callback then callback(false, nil, 'Failed to parse response', nil) end
            end
        elseif statusNum == 401 then
            if callback then callback(false, nil, 'Authentication failed. Check your API token.', nil) end
        elseif statusNum == 429 then
            local success, data = pcall(json.decode, response)
            local cooldownSec = (success and data and data.remaining_seconds) and tonumber(data.remaining_seconds) or (success and data and data.cooldown_seconds) and tonumber(data.cooldown_seconds) or nil
            if success and data and data.remaining_seconds then
                if callback then callback(false, nil, 'Cooldown active. Please wait ' .. data.remaining_seconds .. ' seconds.', cooldownSec) end
            else
                if callback then callback(false, nil, 'Rate limit exceeded. Please wait before submitting another report.', cooldownSec) end
            end
        else
            local errorMsg = 'HTTP ' .. tostring(statusCode)
            if response and response ~= '' then
                local success, data = pcall(json.decode, response)
                if success and data then
                    if data.message and data.message ~= '' then
                        errorMsg = data.message
                    elseif data.error and data.error ~= '' then
                        errorMsg = data.error .. (data.message and (': ' .. data.message) or '')
                    end
                else
                    errorMsg = errorMsg .. ': ' .. string.sub(response, 1, 200)
                end
            end
            if callback then callback(false, nil, errorMsg, nil) end
        end
    end)
end

-- ============================================
-- SERVER CONFIG (for NUI report form)
-- ============================================

RegisterNetEvent('modora:getServerConfig')
AddEventHandler('modora:getServerConfig', function()
    local source = source
    getServerConfig(function(success, data)
        if success and data then
            TriggerClientEvent('modora:serverConfig', source, data)
        else
            TriggerClientEvent('modora:serverConfig', source, nil)
        end
    end)
end)

-- ============================================
-- REPORT SUBMISSION
-- ============================================

RegisterNetEvent('modora:submitReport')
AddEventHandler('modora:submitReport', function(reportData)
    local source = source

    if not reportData.category or not reportData.subject or not reportData.description then
        TriggerClientEvent('modora:reportSubmitted', source, {
            success = false,
            error = 'Missing required fields',
            cooldownSeconds = nil
        })
        return
    end

    local identifiers = GetPlayerIdentifiersTable(source)
    reportData.reporter = reportData.reporter or {}
    reportData.reporter.identifiers = identifiers
    reportData.reporter.fivemId = source
    reportData.reporter.name = GetPlayerName(source)

    reportData.meta = reportData.meta or {}
    if reportData.evidenceUrls and type(reportData.evidenceUrls) == 'table' then
        reportData.meta.evidence_urls = reportData.evidenceUrls
    end

    submitReport(reportData, function(success, data, err, cooldownSeconds)
        if success and data then
            TriggerClientEvent('modora:reportSubmitted', source, {
                success = true,
                ticketNumber = data.ticketNumber,
                ticketId = data.ticketId,
                ticketUrl = data.ticketUrl,
                error = nil,
                cooldownSeconds = nil
            })
        else
            TriggerClientEvent('modora:reportSubmitted', source, {
                success = false,
                ticketNumber = nil,
                ticketId = nil,
                ticketUrl = nil,
                error = err or 'Unknown error',
                cooldownSeconds = cooldownSeconds
            })
        end
    end)
end)
