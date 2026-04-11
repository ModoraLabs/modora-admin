-- ============================================
-- Modora FiveM Control Center — Server Stats
-- ============================================
-- Depends on: server/permissions.lua (hasServerStatsPermission, GetPlayerIdentifierSet)
-- Depends on: server/api.lua (getEffectiveAPIConfig, buildAuthHeaders)

serverStatsStartTime = os.time()
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        serverStatsStartTime = os.time()
    end
end)

local lastErrors = {}
local MAX_ERRORS = 5

-- Call from other resources or use TriggerEvent('modora:pushServerError', message) to record an error.
RegisterNetEvent('modora:pushServerError')
AddEventHandler('modora:pushServerError', function(message)
    if not message or type(message) ~= 'string' then return end
    table.insert(lastErrors, 1, os.date('%H:%M:%S') .. ' - ' .. message)
    while #lastErrors > MAX_ERRORS do
        table.remove(lastErrors)
    end
end)

-- Export so other resources can push errors: exports['modora-admin']:PushServerError('message')
exports('PushServerError', function(message)
    TriggerEvent('modora:pushServerError', message)
end)

-- Process RAM and CPU: read from OS (Linux /proc/self, Windows tasklist).
processStatsCache = { hostMemoryMb = nil, hostCpuPercent = nil }

function getProcessMemoryMb()
    -- Linux: /proc/self/status has VmRSS in KB (self = FXServer process)
    local f = io.open('/proc/self/status', 'r')
    if f then
        local content = f:read('*a')
        f:close()
        if content then
            local rss = content:match('VmRSS:%s+(%d+)')
            if rss then
                local kb = tonumber(rss)
                if kb and kb >= 0 then return math.floor((kb / 1024) * 10) / 10 end
            end
        end
    end
    -- Windows: try tasklist then wmic
    local function readPipe(cmd)
        local ok, h = pcall(io.popen, cmd)
        if not ok or not h then return nil end
        local out = h:read('*a')
        pcall(function() if h and h.close then h:close() end end)
        return out
    end
    -- tasklist CSV: last column "12,345 K" or "12 345 K" (locale)
    local out = readPipe('tasklist /fi "imagename eq FXServer.exe" /fo csv /nh 2>nul')
    if out then
        local line = out:match('([^\r\n]+)')
        if line then
            -- Last quoted field or last number followed by optional space and K
            local memStr = line:match('"([%d,%s]+)%s*K?"%s*$') or line:match(',%s*"([%d,%s]+)%s*K?"')
            if memStr then
                local num = tonumber((memStr:gsub('[%s,]', '')))
                if num and num > 0 then return math.floor((num / 1024) * 10) / 10 end
            end
            -- Non-CSV: number before " K" at end of line
            local num = line:match('(%d[%d,]*)%s*K%s*$')
            if num then
                num = tonumber((num:gsub(',', '')))
                if num and num > 0 then return math.floor((num / 1024) * 10) / 10 end
            end
        end
    end
    -- wmic: WorkingSetSize in bytes (try different quote styles for Windows)
    for _, cmd in ipairs({
        'wmic process where name="FXServer.exe" get WorkingSetSize /value 2>nul',
        "wmic process where name='FXServer.exe' get WorkingSetSize /value 2>nul",
    }) do
        out = readPipe(cmd)
        if out then
            local bytes = out:match('WorkingSetSize=%s*(%d+)')
            if bytes then
                local b = tonumber(bytes)
                if b and b > 0 then return math.floor((b / (1024 * 1024)) * 10) / 10 end
            end
        end
    end
    -- PowerShell fallback
    out = readPipe('powershell -NoProfile -Command "(Get-Process -Name FXServer -ErrorAction SilentlyContinue).WorkingSet64" 2>nul')
    if out then
        local bytes = out:match('(%d+)')
        if bytes then
            local b = tonumber(bytes)
            if b and b > 0 then return math.floor((b / (1024 * 1024)) * 10) / 10 end
        end
    end
    return nil
end

-- CPU % on Linux: sample /proc/self/stat (utime + stime) twice, compute delta.
function updateProcessCpuPercent()
    local f = io.open('/proc/self/stat', 'r')
    if not f then return end
    local line = f:read('*l')
    f:close()
    if not line then return end
    -- Format: pid (comm) state ppid ... ; after ") " we have state,ppid,..., utime=12th, stime=13th
    local afterParen = line:match('%)%s+(.+)$')
    if not afterParen then return end
    local fields = {}
    for v in afterParen:gmatch('%S+') do fields[#fields + 1] = v end
    if #fields < 14 then return end
    local utime, stime = fields[12], fields[13]
    if not utime or not stime then return end
    local u, s = tonumber(utime), tonumber(stime)
    if not u or not s then return end
    local totalTicks = u + s
    local prev = processStatsCache._lastCpuTicks
    local prevTs = processStatsCache._lastCpuTs
    local now = os.time()
    processStatsCache._lastCpuTicks = totalTicks
    processStatsCache._lastCpuTs = now
    if prev and prevTs and (now - prevTs) >= 1 then
        local tickHz = 100
        local deltaTicks = totalTicks - prev
        local deltaSec = now - prevTs
        if deltaSec > 0 then
            local pct = (deltaTicks / tickHz) / deltaSec
            processStatsCache.hostCpuPercent = math.floor(math.min(100, pct) * 10) / 10
        end
    end
end

-- Optional: compute host stats and write stats_host.txt ourselves (no external process).
function runHostStatsScript()
    local resPath = GetResourcePath(GetCurrentResourceName())
    if not resPath or resPath == '' then
        return
    end

    local isWindows = resPath:match('^%a:[/\\]') ~= nil

    -- Normalize base path for building stats_host.txt target.
    if isWindows then
        resPath = resPath:gsub('/', '\\')
        resPath = resPath:gsub('\\+', '\\'):gsub('\\+$', '')
    else
        resPath = resPath:gsub('\\', '/')
        resPath = resPath:gsub('/+', '/'):gsub('/+$', '')
    end

    local hostStatsPath
    if isWindows then
        hostStatsPath = resPath .. '\\stats_host.txt'
    else
        hostStatsPath = resPath .. '/stats_host.txt'
    end

    local memMb = nil
    local cpuPct = nil

    -- Reuse the same logic used for in-game stats:
    -- getProcessMemoryMb already handles Linux (/proc/self/status) and Windows (tasklist/wmic/PowerShell).
    local okMem, m = pcall(getProcessMemoryMb)
    if okMem and m ~= nil then
        memMb = math.floor(m)
    end

    -- CPU percent is only available on Linux via updateProcessCpuPercent (/proc/self/stat).
    if processStatsCache and processStatsCache.hostCpuPercent ~= nil then
        cpuPct = math.floor(processStatsCache.hostCpuPercent)
    end

    if not memMb and not cpuPct then
        -- Only log once to avoid spamming the console
        if not processStatsCache._hostStatsWarned then
            processStatsCache._hostStatsWarned = true
            if Config.Debug then
                print('[Modora ServerStats] Host stats unavailable (normal on dev/Windows without FXServer process)')
            end
        end
        return
    end

    local f, err = io.open(hostStatsPath, 'w')
    if not f then
        if Config.Debug then
            print('[Modora ServerStats] Failed to open stats_host.txt for write: ' .. tostring(err))
        end
        return
    end
    if memMb then
        f:write('memory_mb=' .. tostring(memMb), '\n')
    end
    if cpuPct then
        f:write('cpu_percent=' .. tostring(cpuPct), '\n')
    end
    f:close()

    if Config.Debug then
        print('[Modora ServerStats] Wrote stats_host.txt at ' .. tostring(hostStatsPath) ..
            ' | memory_mb=' .. tostring(memMb) .. ' cpu_percent=' .. tostring(cpuPct))
    end
end

-- Optional: read stats_host.txt (written by helper scripts) and apply to stats table.
local function applyHostStatsFromFile(stats)
    if not stats then return end
    local resPath = GetResourcePath(GetCurrentResourceName())
    if not resPath or resPath == '' then return end
    resPath = resPath:gsub('\\', '/')
    local path = resPath .. '/stats_host.txt'
    local f = io.open(path, 'r')
    if not f then return end
    local content = f:read('*a')
    f:close()
    if not content or content == '' then return end

    local memStr = content:match('memory_mb%s*=%s*([%d%.]+)')
    if memStr then
        local m = tonumber(memStr)
        if m and m >= 0 then
            stats.hostMemoryMb = m
            stats.hostMemoryLuaFallback = false
        end
    end

    local cpuStr = content:match('cpu_percent%s*=%s*([%d%.]+)')
    if cpuStr then
        local c = tonumber(cpuStr)
        if c and c >= 0 then
            stats.hostCpuPercent = c
        end
    end
end

function getServerStats()
    local numResources = 0
    for i = 0, GetNumResources() - 1 do
        local name = GetResourceByFindIndex(i)
        if name and GetResourceState(name) == 'started' then
            numResources = numResources + 1
        end
    end
    local players = #GetPlayers()
    local uptimeSec = os.time() - (serverStatsStartTime or os.time())
    local memoryKb = math.floor(collectgarbage('count'))
    local stats = {
        uptimeSeconds = uptimeSec,
        playerCount = players,
        resourceCount = numResources,
        memoryKb = memoryKb,
        serverVersion = GetConvar('version', '') or '',
        serverName = GetConvar('sv_hostname', '') or GetConvar('sv_projectName', '') or 'Server',
        lastErrors = lastErrors
    }
    if processStatsCache.hostMemoryMb ~= nil then
        stats.hostMemoryMb = processStatsCache.hostMemoryMb
        stats.hostMemoryLuaFallback = true
    end
    if processStatsCache.hostCpuPercent ~= nil then
        stats.hostCpuPercent = processStatsCache.hostCpuPercent
    end
    -- Override with helper script values if available (e.g. Windows wmic via write_host_stats.bat)
    applyHostStatsFromFile(stats)
    return stats
end

-- Background threads for process stats collection
CreateThread(function()
    Wait(2000)
    while true do
        local ok, mb = pcall(getProcessMemoryMb)
        if ok and mb ~= nil then processStatsCache.hostMemoryMb = mb end
        Wait(5000)
    end
end)

CreateThread(function()
    Wait(3000)
    while true do
        pcall(updateProcessCpuPercent)
        Wait(2000)
    end
end)

-- Periodically run helper script to refresh stats_host.txt (for external panels), if enabled.
CreateThread(function()
    local interval = tonumber(Config.HostStatsUpdateIntervalSeconds or 0) or 0
    if interval <= 0 then
        return
    end
    -- Minimum of 1 second between runs to avoid crazy spam.
    if interval < 1 then
        interval = 1
    end
    local waitMs = math.floor(interval * 1000)
    if Config.Debug then
        print('[Modora ServerStats] Host stats auto-run enabled | interval=' .. tostring(interval) .. 's')
    end
    while true do
        Wait(waitMs)
        runHostStatsScript()
    end
end)

-- Handle server stats request from client
RegisterNetEvent('modora:requestServerStats')
AddEventHandler('modora:requestServerStats', function()
    local source = source
    print('[Modora ServerStats] Request from player #' .. tostring(source) .. ' | Config.Debug=' .. tostring(Config.Debug))
    local function sendResult(allowed, stats)
        TriggerClientEvent('modora:serverStatsResult', source, {
            allowed = allowed,
            stats = stats or {}
        })
    end
    local ok, err = pcall(function()
        if not source or source == 0 then
            if Config.Debug then print('[Modora ServerStats] Invalid source') end
            sendResult(false, nil)
            return
        end
        if not hasServerStatsPermission(source) then
            local ids = GetPlayerIdentifierSet(source)
            local list = {}
            for id, _ in pairs(ids) do list[#list + 1] = id end
            print('[Modora ServerStats] Denied #' .. tostring(source) .. ' | identifiers: ' .. (table.concat(list, ', ') or 'none'))
            sendResult(false, nil)
            return
        end
        -- Optionally refresh stats_host.txt immediately when /serverstats is used.
        if Config.HostStatsRunOnServerStatsCommand ~= false then
            if Config.Debug then
                print('[Modora ServerStats] Triggering host stats helper from /' .. tostring(Config.ServerStatsCommand or 'serverstats'))
            end
            runHostStatsScript()
        end
        local stats
        local statsOk, statsErr = pcall(function()
            stats = getServerStats()
        end)
        if not statsOk then
            print('[Modora ServerStats] getServerStats error: ' .. tostring(statsErr))
            stats = {
                uptimeSeconds = os.time() - (serverStatsStartTime or os.time()),
                playerCount = #GetPlayers(),
                resourceCount = 0,
                memoryKb = math.floor(collectgarbage('count')),
                serverVersion = GetConvar('version', '') or '',
                serverName = GetConvar('sv_hostname', '') or GetConvar('sv_projectName', '') or 'Server',
                lastErrors = lastErrors
            }
        end
        if Config.Debug and stats then
            print('[Modora ServerStats] Sending stats: players=' .. tostring(stats.playerCount) .. ' resources=' .. tostring(stats.resourceCount) .. ' memoryKb=' .. tostring(stats.memoryKb))
        end
        sendResult(true, stats)
    end)
    if not ok then
        print('[Modora ServerStats] Handler error: ' .. tostring(err))
        sendResult(false, nil)
    end
end)
