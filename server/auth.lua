-- ============================================
-- Modora FiveM Control Center — Server Auth / Identifiers
-- ============================================
-- Global functions: GetPlayerIdentifiersTable

-- Player identifiers (discord, steam, etc.) for the report payload.
function GetPlayerIdentifiersTable(source)
    local identifiers = {}
    for i = 0, GetNumPlayerIdentifiers(source) - 1 do
        local identifier = GetPlayerIdentifier(source, i)
        if identifier then
            local prefix, value = string.match(identifier, '^([^:]+):(.+)$')
            if prefix and value then
                identifiers[prefix] = value
            end
        end
    end
    return identifiers
end

RegisterNetEvent('modora:getPlayerIdentifiers')
AddEventHandler('modora:getPlayerIdentifiers', function()
    local source = source
    local identifiers = GetPlayerIdentifiersTable(source)
    TriggerClientEvent('modora:playerIdentifiers', source, identifiers)
end)
