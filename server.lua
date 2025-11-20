-- ================================
-- Dumpster Diving Server Script
-- QB-Core Framework - SERVER SIDE
-- Version: 2.1.0
--
-- Features:
-- - Comprehensive anti-cheat system
-- - Rate limiting per player
-- - Item validation and whitelist
-- - Weight checking
-- - Suspicious activity detection
-- - Discord webhook logging (optional)
-- - Admin commands for statistics
-- ================================

local QBCore = exports['qb-core']:GetCoreObject()

-- Server Configuration
local ServerConfig = {
    -- Anti-cheat settings
    maxItemsPerMinute = 50, -- Maximum items a player can receive per minute
    maxSearchesPerMinute = 10, -- Maximum searches per minute per player
    logSuspiciousActivity = true,
    
    -- Webhook settings (optional)
    webhook = {
        enabled = false,
        url = '', -- Your Discord webhook URL
        color = 3447003, -- Blue color
    },
    
    -- Item validation
    validateItems = true,
    checkInventorySpace = true,
    maxWeight = 50000, -- Maximum weight in grams
}

-- Server state tracking
local ServerState = {
    playerStats = {}, -- Track player activity
    suspiciousPlayers = {}, -- Track suspicious activity
    totalSearches = 0,
    totalItemsGiven = 0,
}

-- Valid items that can be given (server-side validation)
local ValidItems = {
    -- Common items
    ['lead'] = {weight = 200, maxStack = 50},
    ['gunpowder'] = {weight = 100, maxStack = 100},
    
    -- Uncommon items
    ['pistol_barrel'] = {weight = 300, maxStack = 10},
    ['weapon_spring'] = {weight = 100, maxStack = 20},
    ['pistol_frame'] = {weight = 400, maxStack = 10},
    ['weapon_parts'] = {weight = 200, maxStack = 15},
    ['simple_trigger'] = {weight = 150, maxStack = 10},
    ['combatpistol_barrel'] = {weight = 350, maxStack = 10},
    ['revolver_barrel'] = {weight = 350, maxStack = 10},
    
    -- Rare items
    ['burst_trigger'] = {weight = 200, maxStack = 5},
    ['advanced_trigger'] = {weight = 180, maxStack = 5},
    ['smg_barrel'] = {weight = 400, maxStack = 5},
    ['smg_frame'] = {weight = 500, maxStack = 5},
    ['advanced_parts'] = {weight = 300, maxStack = 8},
    ['vintage_parts'] = {weight = 250, maxStack = 8},
    
    -- Legendary items
    ['shotgun_barrel'] = {weight = 600, maxStack = 3},
    ['shotgun_frame'] = {weight = 700, maxStack = 3},
    ['wood_parts'] = {weight = 400, maxStack = 5},
    ['short_shotgun_barrel'] = {weight = 450, maxStack = 3},
    ['rifle_barrel'] = {weight = 700, maxStack = 2},
    ['rifle_frame'] = {weight = 800, maxStack = 2},
    ['sniper_barrel'] = {weight = 900, maxStack = 1},
    ['sniper_frame'] = {weight = 1000, maxStack = 1},
    ['precision_trigger'] = {weight = 150, maxStack = 3},
    ['rifle_scope'] = {weight = 400, maxStack = 3},
}

-- ================================
-- UTILITY FUNCTIONS
-- ================================

local function Log(message, level)
    level = level or 'info'
    local prefix = '^3[DumpsterDiving-Server]^7'
    
    if level == 'error' then
        prefix = '^1[DumpsterDiving-Server ERROR]^7'
    elseif level == 'warn' then
        prefix = '^3[DumpsterDiving-Server WARN]^7'
    elseif level == 'success' then
        prefix = '^2[DumpsterDiving-Server]^7'
    end
    
    print(prefix .. ' ' .. tostring(message))
end

local function GetPlayerIdentifier(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player then
        return Player.PlayerData.citizenid
    end
    return nil
end

local function InitializePlayerStats(identifier)
    if not ServerState.playerStats[identifier] then
        ServerState.playerStats[identifier] = {
            totalSearches = 0,
            totalItemsReceived = 0,
            lastSearchTime = 0,
            searchesThisMinute = 0,
            itemsThisMinute = 0,
            lastMinuteReset = GetGameTimer(),
            suspiciousActivity = 0
        }
    end
end

local function ResetMinuteCounters(identifier)
    local currentTime = GetGameTimer()
    local stats = ServerState.playerStats[identifier]
    
    if currentTime - stats.lastMinuteReset >= 60000 then -- 1 minute
        stats.searchesThisMinute = 0
        stats.itemsThisMinute = 0
        stats.lastMinuteReset = currentTime
    end
end

local function IsValidItem(itemName, quantity)
    if not itemName or type(itemName) ~= 'string' then
        return false, 'Invalid item name'
    end
    
    if not quantity or type(quantity) ~= 'number' or quantity <= 0 or quantity > 100 then
        return false, 'Invalid quantity'
    end
    
    if not ValidItems[itemName] then
        return false, 'Item not in whitelist'
    end
    
    if not QBCore.Shared.Items[itemName] then
        return false, 'Item does not exist in shared items'
    end
    
    if quantity > ValidItems[itemName].maxStack then
        return false, 'Quantity exceeds maximum stack size'
    end
    
    return true, nil
end

local function CheckAntiCheat(source, identifier, itemName, quantity)
    local stats = ServerState.playerStats[identifier]
    if not stats then
        Log('Player stats not initialized for ' .. identifier, 'error')
        return false, 'Player stats not initialized'
    end
    
    ResetMinuteCounters(identifier)
    
    -- Check search rate limiting
    if stats.searchesThisMinute >= ServerConfig.maxSearchesPerMinute then
        Log('Player ' .. identifier .. ' exceeded search rate limit (' .. stats.searchesThisMinute .. '/' .. ServerConfig.maxSearchesPerMinute .. ')', 'warn')
        return false, 'Search rate limit exceeded'
    end
    
    -- Check item rate limiting
    if stats.itemsThisMinute + quantity > ServerConfig.maxItemsPerMinute then
        Log('Player ' .. identifier .. ' exceeded item rate limit (' .. (stats.itemsThisMinute + quantity) .. '/' .. ServerConfig.maxItemsPerMinute .. ')', 'warn')
        return false, 'Item rate limit exceeded'
    end
    
    -- Check for suspicious timing patterns
    local currentTime = GetGameTimer()
    if stats.lastSearchTime > 0 and currentTime - stats.lastSearchTime < 5000 then -- Less than 5 seconds between searches
        stats.suspiciousActivity = stats.suspiciousActivity + 1
        if stats.suspiciousActivity >= 3 then
            Log('Suspicious activity detected for player ' .. identifier .. ' (Activity count: ' .. stats.suspiciousActivity .. ')', 'warn')
            ServerState.suspiciousPlayers[identifier] = currentTime
            return false, 'Suspicious activity detected'
        end
    else
        -- Reset suspicious activity if enough time has passed
        if stats.suspiciousActivity > 0 and currentTime - stats.lastSearchTime > 30000 then
            stats.suspiciousActivity = 0
        end
    end
    
    return true, nil
end

local function CanPlayerCarryItem(source, itemName, quantity)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return false, 'Player not found'
    end
    
    -- Check if player can carry the item (primary check)
    if Player.Functions.CanCarryItem then
        local canCarry, reason = Player.Functions.CanCarryItem(itemName, quantity)
        if not canCarry then
            return false, reason or 'Cannot carry item - inventory full or too heavy'
        end
    end
    
    -- Additional weight check as fallback
    local itemData = QBCore.Shared.Items[itemName]
    if itemData then
        local itemWeight = itemData.weight or 0
        local totalWeight = itemWeight * quantity
        
        -- Get current inventory weight
        local currentWeight = 0
        if Player.PlayerData.metadata and Player.PlayerData.metadata.weight then
            currentWeight = Player.PlayerData.metadata.weight
        elseif Player.PlayerData.items then
            -- Calculate weight from items if metadata not available
            for _, item in pairs(Player.PlayerData.items) do
                if item and item.weight then
                    currentWeight = currentWeight + (item.weight * (item.amount or 1))
                end
            end
        end
        
        if currentWeight + totalWeight > ServerConfig.maxWeight then
            return false, 'Would exceed weight limit (' .. math.floor(currentWeight + totalWeight) .. '/' .. ServerConfig.maxWeight .. 'g)'
        end
    end
    
    return true, nil
end

local function SendWebhookLog(title, description, color)
    if not ServerConfig.webhook.enabled or not ServerConfig.webhook.url then
        return
    end
    
    local webhook = {
        username = 'Dumpster Diving System',
        embeds = {
            {
                title = title,
                description = description,
                color = color or ServerConfig.webhook.color,
                timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
                footer = {
                    text = 'Dumpster Diving Logs'
                }
            }
        }
    }
    
    PerformHttpRequest(ServerConfig.webhook.url, function(err, text, headers) end, 'POST', json.encode(webhook), {['Content-Type'] = 'application/json'})
end

-- ================================
-- MAIN ITEM GIVING FUNCTION
-- ================================

local function GiveItemToPlayer(source, itemName, quantity)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then
        Log('Failed to get player identifier for source: ' .. source, 'error')
        return false
    end
    
    InitializePlayerStats(identifier)
    
    -- Validate item
    local isValid, validationError = IsValidItem(itemName, quantity)
    if not isValid then
        Log('Invalid item request from ' .. identifier .. ': ' .. validationError, 'warn')
        TriggerClientEvent('QBCore:Notify', source, 'Invalid item request', 'error')
        return false
    end
    
    -- Anti-cheat checks
    local passedAntiCheat, antiCheatError = CheckAntiCheat(source, identifier, itemName, quantity)
    if not passedAntiCheat then
        Log('Anti-cheat failed for ' .. identifier .. ': ' .. antiCheatError, 'warn')
        TriggerClientEvent('QBCore:Notify', source, 'Action blocked by security system', 'error')
        
        -- Log to webhook if enabled
        SendWebhookLog(
            'Security Alert',
            'Player: ' .. identifier .. '\nAction: Item Request Blocked\nReason: ' .. antiCheatError .. '\nItem: ' .. itemName .. ' x' .. quantity,
            16711680 -- Red color
        )
        return false
    end
    
    -- Check inventory space
    local canCarry, carryError = CanPlayerCarryItem(source, itemName, quantity)
    if not canCarry then
        Log('Player ' .. identifier .. ' cannot carry item: ' .. carryError, 'info')
        TriggerClientEvent('QBCore:Notify', source, carryError, 'error')
        return false
    end
    
    -- Get player and give item
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        Log('Player object not found for source: ' .. source, 'error')
        return false
    end
    
    -- Add item to player
    local success = Player.Functions.AddItem(itemName, quantity)
    if success then
        -- Update statistics
        local stats = ServerState.playerStats[identifier]
        stats.totalItemsReceived = stats.totalItemsReceived + quantity
        stats.itemsThisMinute = stats.itemsThisMinute + quantity
        stats.lastSearchTime = GetGameTimer()
        
        ServerState.totalItemsGiven = ServerState.totalItemsGiven + quantity
        
        -- Trigger client event for item box notification
        TriggerClientEvent('dumpster:client:itemReceived', source, itemName, quantity, QBCore.Shared.Items[itemName])
        
        Log('Gave ' .. quantity .. 'x ' .. itemName .. ' to player ' .. identifier, 'success')
        
        -- Log to webhook for rare items
        if ValidItems[itemName].maxStack <= 3 then -- Legendary items
            SendWebhookLog(
                'Rare Item Found',
                'Player: ' .. identifier .. '\nItem: ' .. itemName .. ' x' .. quantity .. '\nRarity: Legendary',
                16766720 -- Gold color
            )
        end
        
        return true
    else
        Log('Failed to add item to player ' .. identifier .. ': ' .. itemName .. ' x' .. quantity, 'error')
        TriggerClientEvent('QBCore:Notify', source, 'Failed to receive item', 'error')
        return false
    end
end

-- ================================
-- EVENT HANDLERS
-- ================================

RegisterNetEvent('dumpster:server:giveItem', function(itemName, quantity)
    local source = source
    
    if not source or source == 0 then
        Log('Invalid source in giveItem event', 'error')
        return
    end
    
    -- Additional server-side validation
    if type(itemName) ~= 'string' or type(quantity) ~= 'number' then
        Log('Invalid parameters in giveItem event from source: ' .. source, 'warn')
        return
    end
    
    -- Rate limiting check
    local identifier = GetPlayerIdentifier(source)
    if identifier and ServerState.suspiciousPlayers[identifier] then
        local suspiciousTime = ServerState.suspiciousPlayers[identifier]
        if GetGameTimer() - suspiciousTime < 300000 then -- 5 minute cooldown
            TriggerClientEvent('QBCore:Notify', source, 'You are temporarily blocked from searching', 'error')
            return
        else
            ServerState.suspiciousPlayers[identifier] = nil
        end
    end
    
    GiveItemToPlayer(source, itemName, quantity)
end)

RegisterNetEvent('dumpster:server:recordSearch', function()
    local source = source
    local identifier = GetPlayerIdentifier(source)
    
    if identifier then
        InitializePlayerStats(identifier)
        local stats = ServerState.playerStats[identifier]
        ResetMinuteCounters(identifier)
        
        stats.totalSearches = stats.totalSearches + 1
        stats.searchesThisMinute = stats.searchesThisMinute + 1
        ServerState.totalSearches = ServerState.totalSearches + 1
        
        Log('Player ' .. identifier .. ' performed a search (Total: ' .. stats.totalSearches .. ')', 'info')
    end
end)

-- ================================
-- ADMIN COMMANDS
-- ================================

RegisterCommand('dumpsterstats', function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    
    if not Player or not QBCore.Functions.HasPermission(source, 'admin') then
        TriggerClientEvent('QBCore:Notify', source, 'No permission', 'error')
        return
    end
    
    local message = 'Dumpster Diving Statistics:\n'
    message = message .. 'Total Searches: ' .. ServerState.totalSearches .. '\n'
    message = message .. 'Total Items Given: ' .. ServerState.totalItemsGiven .. '\n'
    message = message .. 'Active Players: ' .. #ServerState.playerStats .. '\n'
    message = message .. 'Suspicious Players: ' .. #ServerState.suspiciousPlayers
    
    TriggerClientEvent('chat:addMessage', source, {
        color = {255, 255, 0},
        multiline = true,
        args = {'Dumpster System', message}
    })
end, false)

RegisterCommand('dumpsterreset', function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    
    if not Player or not QBCore.Functions.HasPermission(source, 'god') then
        TriggerClientEvent('QBCore:Notify', source, 'No permission', 'error')
        return
    end
    
    if args[1] and args[1] == 'confirm' then
        ServerState.playerStats = {}
        ServerState.suspiciousPlayers = {}
        ServerState.totalSearches = 0
        ServerState.totalItemsGiven = 0
        
        TriggerClientEvent('QBCore:Notify', source, 'Dumpster diving data reset', 'success')
        Log('Admin ' .. GetPlayerIdentifier(source) .. ' reset all dumpster diving data', 'warn')
    else
        TriggerClientEvent('QBCore:Notify', source, 'Use: /dumpsterreset confirm', 'error')
    end
end, false)

RegisterCommand('dumpsterplayerstats', function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    
    if not Player or not QBCore.Functions.HasPermission(source, 'admin') then
        TriggerClientEvent('QBCore:Notify', source, 'No permission', 'error')
        return
    end
    
    if not args[1] then
        TriggerClientEvent('QBCore:Notify', source, 'Usage: /dumpsterplayerstats [player_id]', 'error')
        return
    end
    
    local targetId = tonumber(args[1])
    local targetPlayer = QBCore.Functions.GetPlayer(targetId)
    
    if not targetPlayer then
        TriggerClientEvent('QBCore:Notify', source, 'Player not found', 'error')
        return
    end
    
    local identifier = targetPlayer.PlayerData.citizenid
    local stats = ServerState.playerStats[identifier]
    
    if not stats then
        TriggerClientEvent('QBCore:Notify', source, 'No stats found for this player', 'error')
        return
    end
    
    local message = 'Stats for ' .. targetPlayer.PlayerData.charinfo.firstname .. ' ' .. targetPlayer.PlayerData.charinfo.lastname .. ':\n'
    message = message .. 'Total Searches: ' .. stats.totalSearches .. '\n'
    message = message .. 'Total Items: ' .. stats.totalItemsReceived .. '\n'
    message = message .. 'Searches This Minute: ' .. stats.searchesThisMinute .. '\n'
    message = message .. 'Items This Minute: ' .. stats.itemsThisMinute .. '\n'
    message = message .. 'Suspicious Activity: ' .. stats.suspiciousActivity
    
    TriggerClientEvent('chat:addMessage', source, {
        color = {255, 255, 0},
        multiline = true,
        args = {'Player Stats', message}
    })
end, false)

RegisterCommand('dumpsterunblock', function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    
    if not Player or not QBCore.Functions.HasPermission(source, 'admin') then
        TriggerClientEvent('QBCore:Notify', source, 'No permission', 'error')
        return
    end
    
    if not args[1] then
        TriggerClientEvent('QBCore:Notify', source, 'Usage: /dumpsterunblock [player_id]', 'error')
        return
    end
    
    local targetId = tonumber(args[1])
    local targetPlayer = QBCore.Functions.GetPlayer(targetId)
    
    if not targetPlayer then
        TriggerClientEvent('QBCore:Notify', source, 'Player not found', 'error')
        return
    end
    
    local identifier = targetPlayer.PlayerData.citizenid
    
    if ServerState.suspiciousPlayers[identifier] then
        ServerState.suspiciousPlayers[identifier] = nil
        TriggerClientEvent('QBCore:Notify', source, 'Player unblocked from dumpster diving', 'success')
        TriggerClientEvent('QBCore:Notify', targetId, 'You have been unblocked from dumpster diving', 'success')
        Log('Admin ' .. GetPlayerIdentifier(source) .. ' unblocked player ' .. identifier, 'warn')
    else
        TriggerClientEvent('QBCore:Notify', source, 'Player is not blocked', 'error')
    end
end, false)

RegisterCommand('dumpsterreload', function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    
    if not Player or not QBCore.Functions.HasPermission(source, 'god') then
        TriggerClientEvent('QBCore:Notify', source, 'No permission', 'error')
        return
    end
    
    -- Reload configuration (if using external config)
    TriggerClientEvent('QBCore:Notify', source, 'Dumpster diving config reloaded', 'success')
    Log('Admin ' .. GetPlayerIdentifier(source) .. ' reloaded dumpster diving config', 'info')
end, false)

-- ================================
-- CLEANUP AND MAINTENANCE
-- ================================

-- Cleanup old data every 30 minutes
CreateThread(function()
    while true do
        Wait(1800000) -- 30 minutes
        
        local currentTime = GetGameTimer()
        local cleanedStats = 0
        local cleanedSuspicious = 0
        
        -- Clean old player stats (inactive for 24 hours)
        for identifier, stats in pairs(ServerState.playerStats) do
            if currentTime - stats.lastSearchTime > 86400000 then -- 24 hours
                ServerState.playerStats[identifier] = nil
                cleanedStats = cleanedStats + 1
            end
        end
        
        -- Clean old suspicious player entries (older than 1 hour)
        for identifier, timestamp in pairs(ServerState.suspiciousPlayers) do
            if currentTime - timestamp > 3600000 then -- 1 hour
                ServerState.suspiciousPlayers[identifier] = nil
                cleanedSuspicious = cleanedSuspicious + 1
            end
        end
        
        if cleanedStats > 0 or cleanedSuspicious > 0 then
            Log('Cleaned ' .. cleanedStats .. ' old player stats and ' .. cleanedSuspicious .. ' suspicious entries', 'info')
        end
    end
end)

-- ================================
-- EXPORTS (For Integration with Other Resources)
-- ================================

exports('GetPlayerDumpsterStats', function(source)
    local identifier = GetPlayerIdentifier(source)
    if identifier and ServerState.playerStats[identifier] then
        return ServerState.playerStats[identifier]
    end
    return nil
end)

exports('CanPlayerSearch', function(source)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then
        return false, 'Player not found'
    end
    
    InitializePlayerStats(identifier)
    local stats = ServerState.playerStats[identifier]
    ResetMinuteCounters(identifier)
    
    -- Check if player is blocked
    if ServerState.suspiciousPlayers[identifier] then
        local suspiciousTime = ServerState.suspiciousPlayers[identifier]
        if GetGameTimer() - suspiciousTime < 300000 then
            return false, 'Player is temporarily blocked'
        end
    end
    
    -- Check rate limits
    if stats.searchesThisMinute >= ServerConfig.maxSearchesPerMinute then
        return false, 'Search rate limit exceeded'
    end
    
    return true, nil
end)

exports('GetServerStats', function()
    return {
        totalSearches = ServerState.totalSearches,
        totalItemsGiven = ServerState.totalItemsGiven,
        activePlayers = #ServerState.playerStats,
        suspiciousPlayers = #ServerState.suspiciousPlayers
    }
end)

exports('ResetPlayerCooldown', function(source)
    local identifier = GetPlayerIdentifier(source)
    if identifier and ServerState.suspiciousPlayers[identifier] then
        ServerState.suspiciousPlayers[identifier] = nil
        return true
    end
    return false
end)

-- ================================
-- STARTUP
-- ================================

CreateThread(function()
    Wait(1000) -- Wait for QB-Core to initialize
    Log('Dumpster Diving server script initialized', 'success')
    Log('Anti-cheat enabled: Max ' .. ServerConfig.maxSearchesPerMinute .. ' searches and ' .. ServerConfig.maxItemsPerMinute .. ' items per minute', 'info')
    
    if ServerConfig.webhook.enabled then
        Log('Discord webhook logging enabled', 'info')
        SendWebhookLog(
            'Server Started',
            'Dumpster Diving system has been initialized with anti-cheat protection.',
            65280 -- Green color
        )
    end
end)