-- ============================================
-- Modora FiveM Control Center — Server API Helpers
-- ============================================
-- Global functions: getEffectiveAPIConfig, buildAuthHeaders, performHttpRequestWithRetry

-- Hardcoded API base URL — all traffic goes to modora.gg
local MODORA_API_BASE = 'https://modora.gg/api/fivem'

-- Returns API base URL and bearer token from config.
-- The base URL is hardcoded; only the token comes from config.lua.
function getEffectiveAPIConfig()
    local token = (Config.APIToken or ''):match('^%s*(.-)%s*$')
    return MODORA_API_BASE, '', token
end

-- Build request headers with bearer token.
function buildAuthHeaders()
    local _, _, token = getEffectiveAPIConfig()
    token = token or ''
    return {
        ['Content-Type'] = 'application/json',
        ['Authorization'] = 'Bearer ' .. token,
    }
end

-- HTTP request with optional retries and exponential backoff.
function performHttpRequestWithRetry(url, method, body, headers, callback, maxRetries)
    maxRetries = tonumber(maxRetries) or 3
    local retryCount = 0

    local function attemptRequest()
        if Config.Debug then
            if retryCount > 0 then
                print('[Modora] Retry attempt ' .. tostring(retryCount) .. '/' .. tostring(maxRetries))
            else
                print('[Modora] Making HTTP request to: ' .. url)
            end
        end

        PerformHttpRequest(url, function(statusCode, response, responseHeaders)
            local statusNum = tonumber(statusCode) or 0

            if Config.Debug then
                print('[Modora] HTTP response: statusCode=' .. tostring(statusCode) .. ' (num=' .. tostring(statusNum) .. ')')
                if response and string.len(response) > 0 then
                    print('[Modora] Response preview: ' .. string.sub(response, 1, 200))
                end
            end

            if statusNum == 0 and retryCount < maxRetries then
                retryCount = retryCount + 1
                if Config.Debug then
                    print('[Modora] Connection failed, waiting ' .. tostring(1000 * retryCount) .. 'ms before retry...')
                end
                Citizen.Wait(1000 * retryCount) -- Exponential backoff
                attemptRequest()
            else
                if callback then
                    callback(statusCode, response, responseHeaders, maxRetries, retryCount)
                end
            end
        end, method, body or '', headers)
    end

    attemptRequest()
end
