-- ============================================
-- Modora FiveM Control Center — Server Permissions (TXAdmin / ACE)
-- ============================================
-- Global functions: hasServerStatsPermission

local function normalizeId(s)
    if type(s) ~= 'string' then return nil end
    s = s:match('^%s*(.-)%s*$') or s
    return s ~= '' and string.lower(s) or nil
end

-- Build set of player identifiers (lowercase, trimmed) for matching txAdmin admins.json
local function getPlayerIdentifierSet(source)
    local set = {}
    for i = 0, GetNumPlayerIdentifiers(source) - 1 do
        local id = normalizeId(GetPlayerIdentifier(source, i))
        if id then set[id] = true end
    end
    return set
end

-- Expose getPlayerIdentifierSet globally (used by stats.lua for denied logging)
function GetPlayerIdentifierSet(source)
    return getPlayerIdentifierSet(source)
end

-- Load and check txAdmin admins.json (txAdmin does not expose HasPermission to other resources)
local function hasTxAdminPermissionFromFile(source, requiredPerm)
    local path = (Config.ServerStatsTxAdminAdminsPath or ''):gsub('^%s*(.-)%s*$', '%1')
    path = path:gsub('^["\']+', ''):gsub('["\']+$', '')  -- strip surrounding quotes
    if path == '' then
        path = (GetConvar('txDataPath', '') or ''):gsub('^%s*(.-)%s*$', '%1')
        if path ~= '' then
            path = path:gsub('[/\\]+$', '') .. '/admins.json'
        end
    end
    path = path:gsub('\\', '/')
    local content = nil
    if path ~= '' then
        local ok, data = pcall(function()
            local f = io.open(path, 'r')
            if not f then return nil end
            local out = f:read('*a')
            f:close()
            return out
        end)
        if ok and data and data ~= '' then content = data end
    end
    -- Fallback: read from resource folder (copy G:\txData\admins.json to modora-admin/admins.json)
    if not content or content == '' then
        content = LoadResourceFile(GetCurrentResourceName(), 'admins.json')
    end
    if not content or content == '' then
        if Config.Debug then
            print('[Modora ServerStats] admins.json not found. Copy G:\\txData\\admins.json into the modora-admin resource folder as admins.json')
        end
        return false
    end

    local ok
    ok, content = pcall(json.decode, content)
    if not ok or type(content) ~= 'table' then
        if Config.Debug then
            print('[Modora ServerStats] admins.json parse failed')
        end
        return false
    end

    local playerIds = getPlayerIdentifierSet(source)
    if not next(playerIds) then
        if Config.Debug then
            print('[Modora ServerStats] player #' .. tostring(source) .. ' has no identifiers')
        end
        return false
    end

    if Config.Debug then
        local list = {}
        for id, _ in pairs(playerIds) do list[#list + 1] = id end
        print('[Modora ServerStats] player #' .. tostring(source) .. ' identifiers: ' .. table.concat(list, ', '))
    end

    for _, admin in ipairs(content) do
        if type(admin) ~= 'table' then goto continue end
        local adminIds = {}
        if type(admin.providers) == 'table' then
            for _, prov in pairs(admin.providers) do
                if type(prov) == 'table' then
                    local id = normalizeId(prov.identifier)
                    if id then adminIds[id] = true end
                end
            end
        end
        local match = false
        for id, _ in pairs(playerIds) do
            if adminIds[id] then match = true break end
        end
        if not match then goto continue end

        if admin.master == true then
            if Config.Debug then
                print('[Modora ServerStats] matched master admin: ' .. tostring(admin.name))
            end
            return true
        end
        local perms = admin.permissions
        if type(perms) ~= 'table' then goto continue end
        for _, p in ipairs(perms) do
            if p == 'all_permissions' or p == requiredPerm then
                if Config.Debug then
                    print('[Modora ServerStats] matched admin with perm: ' .. tostring(admin.name))
                end
                return true
            end
        end
        if Config.Debug then
            print('[Modora ServerStats] matched admin but missing perm: ' .. tostring(admin.name) .. ' (need ' .. tostring(requiredPerm) .. ')')
        end
        ::continue::
    end
    if Config.Debug then
        print('[Modora ServerStats] no admin match for player #' .. tostring(source))
    end
    return false
end

function hasServerStatsPermission(source)
    if not source or source == 0 then return false end
    local acePerm = Config.ServerStatsAcePermission or 'modora.serverstats'
    if acePerm and acePerm ~= '' and IsPlayerAceAllowed(source, acePerm) then
        if Config.Debug then print('[Modora ServerStats] Permission: ACE allowed (' .. tostring(acePerm) .. ')') end
        return true
    end
    local perm = Config.ServerStatsTxAdminPermission or 'console.view'
    if hasTxAdminPermissionFromFile(source, perm) then
        if Config.Debug then print('[Modora ServerStats] Permission: txAdmin admins.json') end
        return true
    end
    local state = GetResourceState('monitor')
    if state == 'started' then
        local ok, has = pcall(function()
            return exports.monitor:HasPermission(source, perm)
        end)
        if ok and has then
            if Config.Debug then print('[Modora ServerStats] Permission: monitor export') end
            return true
        end
    end
    state = GetResourceState('txAdmin')
    if state == 'started' then
        local ok, has = pcall(function()
            return exports.txAdmin:HasPermission(source, perm)
        end)
        if ok and has then
            if Config.Debug then print('[Modora ServerStats] Permission: txAdmin export') end
            return true
        end
    end
    if Config.ServerStatsAllowWithoutTxAdmin then
        if Config.Debug then print('[Modora ServerStats] Permission: ServerStatsAllowWithoutTxAdmin=true') end
        return true
    end
    if Config.Debug then print('[Modora ServerStats] Permission: denied (no match)') end
    return false
end
