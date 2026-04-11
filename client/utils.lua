-- ============================================
-- Modora FiveM Control Center — Client Utilities
-- ============================================

-- Nearby players within radius for the report form (optional targets).
function GetNearbyPlayers(coords, radius, maxPlayers)
    local players = {}
    local playerPed = PlayerPedId()
    local playerCoords = coords or GetEntityCoords(playerPed)

    for _, playerId in ipairs(GetActivePlayers()) do
        if playerId ~= PlayerId() then
            local targetPed = GetPlayerPed(playerId)
            if targetPed and targetPed ~= 0 then
                local targetCoords = GetEntityCoords(targetPed)
                local distance = #(playerCoords - targetCoords)

                if distance <= radius then
                    local serverId = GetPlayerServerId(playerId)
                    local playerName = GetPlayerName(playerId)

                    table.insert(players, {
                        fivemId = serverId,
                        name = playerName,
                        distance = math.floor(distance)
                    })

                    if #players >= maxPlayers then
                        break
                    end
                end
            end
        end
    end

    return players
end
