-- ================================
-- Enhanced Dumpster Diving Script
-- QB-Core Framework
-- Version: 2.1.0
-- 
-- Features:
-- - Optimized dumpster detection with caching
-- - Fixed loot generation logic
-- - Improved error handling and validation
-- - Support for multiple target systems (qb-target, ox_target)
-- - Support for multiple progress bar systems
-- - Comprehensive anti-cheat protection
-- - Selling system integration
-- ================================

local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = {}
local isLoggedIn = false
local isSearching = false
local nearbyDumpster = nil
local searchThread = nil

-- Configuration
local Config = {
    Framework = {
        progressbar = 'qb-progressbar', -- qb-progressbar, progressBars, mythic_progbar
        target = 'qb-target', -- qb-target, ox_target, false
        inventory = 'qb-inventory', -- qb-inventory, ox_inventory, qs-inventory
        notification = 'qb-core' -- qb-core, ox_lib, mythic_notify
    },
    
    Search = {
        time = 3000, -- Reduced from 8000 to 3000ms (3 seconds)
        distance = 2.0, -- Distance to interact with dumpster
        cooldownTime = 2000, -- Reduced from 5000 to 2000ms (2 seconds)
        dumpsterResetTime = 900000, -- Reduced from 1800000 to 900000ms (15 minutes)
        maxItemsPerSearch = 2,
        minItemsPerSearch = 1,
        emptyChance = 30, -- Chance (%) that dumpster is empty
        failChance = 15, -- Chance to fail and get nothing even if not empty
    },
    
    Items = {
        requiredSpace = 5, -- Required inventory space to search
        maxWeight = 50000, -- Maximum weight player can carry (50kg)
    },
    
    Effects = {
        enableSounds = true, -- Enable sound effects
        enableParticles = true, -- Enable particle effects
    },
    
    Debug = false -- Set to true for debug messages
}

-- Secure dumpster models (only legitimate dumpster props)
local DumpsterModels = {
    -- Standard dumpsters
    [`prop_dumpster_01a`] = true,
    [`prop_dumpster_02a`] = true,
    [`prop_dumpster_02b`] = true,
    [`prop_dumpster_3a`] = true,
    [`prop_dumpster_4a`] = true,
    [`prop_dumpster_4b`] = true,
    [`prop_cs_dumpster_01a`] = true,
    [`prop_cs_dumpster_02a`] = true,
    -- Bins
    [`prop_cs_bin_01`] = true,
    [`prop_cs_bin_02`] = true,
    [`prop_bin_01a`] = true,
    [`prop_bin_02a`] = true,
    [`prop_bin_03a`] = true,
    [`prop_bin_04a`] = true,
    [`prop_bin_05a`] = true,
    [`prop_bin_06a`] = true,
    [`prop_bin_07a`] = true,
    [`prop_bin_07b`] = true,
    [`prop_bin_07c`] = true,
    [`prop_bin_07d`] = true,
    [`prop_bin_08a`] = true,
    [`prop_bin_08open`] = true,
    [`prop_bin_09a`] = true,
    [`prop_bin_10a`] = true,
    [`prop_bin_10b`] = true,
    [`prop_bin_11a`] = true,
    [`prop_bin_12a`] = true,
    [`prop_bin_14a`] = true,
    [`prop_bin_14b`] = true
}

-- Validated loot tables with proper item checking
local LootTables = {
    common = {
        weight = 60,
        items = {
            {item = 'lead', min = 1, max = 2, chance = 70},
            {item = 'gunpowder', min = 1, max = 3, chance = 80}
        }
    },
    uncommon = {
        weight = 25,
        items = {
            {item = 'pistol_barrel', min = 1, max = 1, chance = 25},
            {item = 'weapon_spring', min = 1, max = 2, chance = 40},
            {item = 'pistol_frame', min = 1, max = 1, chance = 20},
            {item = 'weapon_parts', min = 1, max = 2, chance = 50},
            {item = 'simple_trigger', min = 1, max = 1, chance = 30},
            {item = 'combatpistol_barrel', min = 1, max = 1, chance = 15},
            {item = 'revolver_barrel', min = 1, max = 1, chance = 15}
        }
    },
    rare = {
        weight = 12,
        items = {
            {item = 'burst_trigger', min = 1, max = 1, chance = 20},
            {item = 'advanced_trigger', min = 1, max = 1, chance = 25},
            {item = 'smg_barrel', min = 1, max = 1, chance = 15},
            {item = 'smg_frame', min = 1, max = 1, chance = 10},
            {item = 'advanced_parts', min = 1, max = 1, chance = 30},
            {item = 'vintage_parts', min = 1, max = 1, chance = 25}
        }
    },
    legendary = {
        weight = 3,
        items = {
            {item = 'shotgun_barrel', min = 1, max = 1, chance = 15},
            {item = 'shotgun_frame', min = 1, max = 1, chance = 10},
            {item = 'rifle_barrel', min = 1, max = 1, chance = 8},
            {item = 'rifle_frame', min = 1, max = 1, chance = 6},
            {item = 'sniper_barrel', min = 1, max = 1, chance = 3},
            {item = 'sniper_frame', min = 1, max = 1, chance = 2},
            {item = 'precision_trigger', min = 1, max = 1, chance = 12},
            {item = 'rifle_scope', min = 1, max = 1, chance = 8}
        }
    }
}

-- State management
local State = {
    playerCooldowns = {},
    searchedDumpsters = {},
    validItems = {},
    isNearDumpster = false,
    currentDumpster = nil
}

-- ================================
-- UTILITY FUNCTIONS
-- ================================

local function DebugPrint(message)
    if Config.Debug then
        print('^3[DumpsterDiving]^7 ' .. tostring(message))
    end
end

local function ValidateItem(itemName)
    if not itemName or type(itemName) ~= 'string' then
        return false
    end
    
    if not QBCore.Shared.Items[itemName] then
        DebugPrint('Invalid item: ' .. itemName)
        return false
    end
    
    return true
end

local function InitializeValidItems()
    State.validItems = {}
    local validCount = 0
    
    for rarity, data in pairs(LootTables) do
        if data and data.items then
            -- Create a new items table to avoid modifying during iteration
            local validItems = {}
            for _, itemData in pairs(data.items) do
                if itemData and itemData.item and ValidateItem(itemData.item) then
                    table.insert(validItems, itemData)
                    State.validItems[itemData.item] = true
                    validCount = validCount + 1
                else
                    DebugPrint('Removing invalid item from loot table: ' .. tostring(itemData and itemData.item or 'nil'))
                end
            end
            -- Replace the items table with the filtered one
            data.items = validItems
        end
    end
    
    DebugPrint('Initialized ' .. validCount .. ' valid items')
end

local function SecureRandom(min, max)
    if not min or not max or min > max then
        return 0
    end
    return math.random(min, max)
end

local function GetDumpsterHash(entity)
    if not DoesEntityExist(entity) then
        return nil
    end
    
    local coords = GetEntityCoords(entity)
    if not coords then
        return nil
    end
    
    return string.format("%.2f_%.2f_%.2f", coords.x, coords.y, coords.z)
end

local function IsValidDumpster(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return false
    end
    
    local model = GetEntityModel(entity)
    return DumpsterModels[model] == true
end

-- Cache for dumpster entities to reduce GetGamePool calls
local dumpsterCache = {}
local cacheUpdateTime = 0
local CACHE_DURATION = 5000 -- Update cache every 5 seconds

local function UpdateDumpsterCache()
    local currentTime = GetGameTimer()
    if currentTime - cacheUpdateTime < CACHE_DURATION then
        return -- Cache still valid
    end
    
    dumpsterCache = {}
    local objects = GetGamePool('CObject')
    
    for _, obj in pairs(objects) do
        if IsValidDumpster(obj) then
            local objCoords = GetEntityCoords(obj)
            if objCoords then
                table.insert(dumpsterCache, {
                    entity = obj,
                    coords = objCoords
                })
            end
        end
    end
    
    cacheUpdateTime = currentTime
    DebugPrint('Updated dumpster cache: ' .. #dumpsterCache .. ' dumpsters found')
end

local function GetClosestDumpster()
    local ped = PlayerPedId()
    if not ped or ped == 0 then
        return nil, 999
    end
    
    local coords = GetEntityCoords(ped)
    if not coords then
        return nil, 999
    end
    
    -- Update cache if needed
    UpdateDumpsterCache()
    
    local closestDumpster = nil
    local closestDistance = Config.Search.distance
    
    -- Search through cached dumpsters
    for _, dumpsterData in pairs(dumpsterCache) do
        if DoesEntityExist(dumpsterData.entity) then
            local distance = #(coords - dumpsterData.coords)
            if distance < closestDistance then
                closestDistance = distance
                closestDumpster = dumpsterData.entity
            end
        end
    end
    
    return closestDumpster, closestDistance
end

local function CanPlayerSearch()
    if not isLoggedIn or not PlayerData then
        return false, 'You are not logged in'
    end
    
    if isSearching then
        return false, 'You are already searching'
    end
    
    local playerId = GetPlayerServerId(PlayerId())
    local currentTime = GetGameTimer()
    
    -- More lenient cooldown check
    if State.playerCooldowns[playerId] and currentTime < State.playerCooldowns[playerId] then
        local remaining = math.ceil((State.playerCooldowns[playerId] - currentTime) / 1000)
        if remaining > 0 then
            return false, 'You must wait ' .. remaining .. ' seconds before searching again'
        end
    end
    
    return true, nil
end

local function CanSearchDumpster(dumpster)
    if not IsValidDumpster(dumpster) then
        return false, 'Invalid dumpster'
    end
    
    local hash = GetDumpsterHash(dumpster)
    if not hash then
        return false, 'Cannot identify dumpster'
    end
    
    local currentTime = GetGameTimer()
    -- More lenient dumpster reset check
    if State.searchedDumpsters[hash] and currentTime < State.searchedDumpsters[hash] then
        local remaining = math.ceil((State.searchedDumpsters[hash] - currentTime) / 1000)
        if remaining > 0 then
            return false, 'This dumpster was recently searched'
        end
    end
    
    return true, nil
end

-- ================================
-- NOTIFICATION SYSTEM
-- ================================

local function ShowNotification(message, type, duration)
    -- Map the notification types to match ajd-hud types
    local notificationType = 'info' -- default type
    
    if type == 'error' then
        notificationType = 'error'
    elseif type == 'success' then
        notificationType = 'success'
    elseif type == 'primary' then
        notificationType = 'info'
    end
    
    -- Use the ajd-hud export for notifications
    exports['ajd-hud']:showNotification(message, notificationType)
end

-- ================================
-- INVENTORY MANAGEMENT
-- ================================

local function CheckInventorySpace()
    -- Remove client-side inventory check - let server handle all validation
    -- Server already has comprehensive inventory checking with CanPlayerCarryItem function
    return true, nil
end

local function GiveItemToPlayer(itemName, quantity)
    if not ValidateItem(itemName) or not quantity or quantity <= 0 then
        DebugPrint('Invalid item data: ' .. tostring(itemName) .. ' x' .. tostring(quantity))
        return false
    end
    
    -- Server-side validation through event
    TriggerServerEvent('dumpster:server:giveItem', itemName, quantity)
    return true
end

-- ================================
-- LOOT GENERATION
-- ================================

local function GetRandomLoot()
    local foundItems = {}
    
    -- Check if search fails (separate roll for failure)
    local failRoll = SecureRandom(1, 100)
    if failRoll <= Config.Search.failChance then
        DebugPrint('Search failed due to fail chance')
        return foundItems
    end
    
    -- Check if dumpster is empty (separate roll for empty)
    local emptyRoll = SecureRandom(1, 100)
    if emptyRoll <= Config.Search.emptyChance then
        DebugPrint('Dumpster is empty')
        return foundItems
    end
    
    -- Determine rarity tier
    local rarityRoll = SecureRandom(1, 100)
    local selectedTable = nil
    
    if rarityRoll <= LootTables.legendary.weight then
        selectedTable = LootTables.legendary
        DebugPrint('Legendary loot selected')
    elseif rarityRoll <= LootTables.legendary.weight + LootTables.rare.weight then
        selectedTable = LootTables.rare
        DebugPrint('Rare loot selected')
    elseif rarityRoll <= LootTables.legendary.weight + LootTables.rare.weight + LootTables.uncommon.weight then
        selectedTable = LootTables.uncommon
        DebugPrint('Uncommon loot selected')
    else
        selectedTable = LootTables.common
        DebugPrint('Common loot selected')
    end
    
    if not selectedTable or not selectedTable.items or #selectedTable.items == 0 then
        DebugPrint('No valid items in selected table')
        return foundItems
    end
    
    -- Generate items
    local numItems = SecureRandom(Config.Search.minItemsPerSearch, Config.Search.maxItemsPerSearch)
    local attempts = 0
    local maxAttempts = numItems * 5 -- More attempts for better item generation
    local usedItems = {} -- Track items to avoid duplicates in same search
    
    while #foundItems < numItems and attempts < maxAttempts do
        attempts = attempts + 1
        
        if #selectedTable.items == 0 then
            break -- No valid items available
        end
        
        local randomIndex = SecureRandom(1, #selectedTable.items)
        local randomItem = selectedTable.items[randomIndex]
        
        if randomItem and randomItem.item and ValidateItem(randomItem.item) then
            -- Check if we already have this item in this search (optional - remove if duplicates are allowed)
            local alreadyFound = false
            for _, found in pairs(foundItems) do
                if found.item == randomItem.item then
                    alreadyFound = true
                    break
                end
            end
            
            if not alreadyFound then
                local itemRoll = SecureRandom(1, 100)
                if itemRoll <= randomItem.chance then
                    local quantity = SecureRandom(randomItem.min, randomItem.max)
                    
                    table.insert(foundItems, {
                        item = randomItem.item,
                        quantity = quantity
                    })
                    
                    DebugPrint('Added item: ' .. randomItem.item .. ' x' .. quantity)
                end
            end
        end
    end
    
    return foundItems
end

-- ================================
-- ANIMATION SYSTEM
-- ================================

local function LoadAnimDict(dict)
    if not HasAnimDictLoaded(dict) then
        RequestAnimDict(dict)
        local timeout = 0
        while not HasAnimDictLoaded(dict) and timeout < 5000 do
            Wait(100)
            timeout = timeout + 100
        end
    end
    return HasAnimDictLoaded(dict)
end

local function PlaySearchAnimation()
    local ped = PlayerPedId()
    if not ped or ped == 0 then
        return false
    end
    
    local animDict = "amb@prop_human_bum_bin@idle_b"
    local animName = "idle_d"
    
    if LoadAnimDict(animDict) then
        TaskPlayAnim(ped, animDict, animName, 8.0, 8.0, -1, 1, 0, false, false, false)
        return true
    end
    
    return false
end

local function StopAnimation()
    local ped = PlayerPedId()
    if ped and ped ~= 0 then
        ClearPedTasks(ped)
    end
end

-- ================================
-- SOUND EFFECTS
-- ================================

local function PlaySound(soundName, soundSet)
    soundSet = soundSet or "HUD_FRONTEND_DEFAULT_SOUNDSET"
    PlaySoundFrontend(-1, soundName, soundSet, true)
end

local function PlaySearchSound()
    -- Play a subtle search sound
    PlaySound("CHECKPOINT_PERFECT", "HUD_MINI_GAME_SOUNDSET")
end

local function PlayItemFoundSound(rarity)
    -- Different sounds for different rarities
    if rarity == 'legendary' then
        PlaySound("PURCHASE", "HUD_LIQUOR_STORE_SOUNDSET")
    elseif rarity == 'rare' then
        PlaySound("CHECKPOINT_NORMAL", "HUD_MINI_GAME_SOUNDSET")
    else
        PlaySound("CHECKPOINT_UNDER_THE_BRIDGE", "HUD_MINI_GAME_SOUNDSET")
    end
end

local function PlayEmptySound()
    PlaySound("ERROR", "HUD_FRONTEND_DEFAULT_SOUNDSET")
end

-- ================================
-- PARTICLE EFFECTS
-- ================================

local function CreateSearchParticles(coords)
    -- Create dust particles when searching
    RequestNamedPtfxAsset("core")
    while not HasNamedPtfxAssetLoaded("core") do
        Wait(10)
    end
    
    UseParticleFxAssetNextCall("core")
    StartParticleFxNonLoopedAtCoord("ent_dst_elec_fire_sp", coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.5, false, false, false)
end

local function CreateItemFoundParticles(coords, rarity)
    RequestNamedPtfxAsset("scr_paletoscore")
    while not HasNamedPtfxAssetLoaded("scr_paletoscore") do
        Wait(10)
    end
    
    UseParticleFxAssetNextCall("scr_paletoscore")
    if rarity == 'legendary' then
        StartParticleFxNonLoopedAtCoord("scr_paleto_banknotes", coords.x, coords.y, coords.z + 0.5, 0.0, 0.0, 0.0, 1.0, false, false, false)
    else
        StartParticleFxNonLoopedAtCoord("scr_paleto_roof_impact", coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.3, false, false, false)
    end
end

-- ================================
-- PROGRESS BAR SYSTEM
-- ================================

local function ShowProgressBar(onFinish, onCancel)
    if Config.Framework.progressbar == 'qb-progressbar' then
        if QBCore and QBCore.Functions and QBCore.Functions.Progressbar then
            QBCore.Functions.Progressbar("dumpster_search", "Searching through trash...", Config.Search.time, false, true, {
                disableMovement = true,
                disableCarMovement = true,
                disableMouse = false,
                disableCombat = true,
            }, {}, {}, {}, onFinish, onCancel)
        else
            -- Fallback if qb-progressbar not available
            Wait(Config.Search.time)
            onFinish()
        end
    elseif Config.Framework.progressbar == 'ox_lib' then
        if lib and lib.progressBar then
            lib.progressBar({
                duration = Config.Search.time,
                label = 'Searching through trash...',
                useWhileDead = false,
                canCancel = true,
                disable = {
                    car = true,
                    move = true,
                    combat = true,
                },
            })
            onFinish()
        else
            -- Fallback if ox_lib not available
            Wait(Config.Search.time)
            onFinish()
        end
    else
        -- Fallback with simple wait
        Wait(Config.Search.time)
        onFinish()
    end
end

-- ================================
-- MAIN SEARCH FUNCTION
-- ================================

local function SearchDumpster()
    -- Validation checks
    local canSearch, searchError = CanPlayerSearch()
    if not canSearch then
        ShowNotification(searchError, 'error')
        return
    end
    
    local dumpster, distance = GetClosestDumpster()
    if not dumpster then
        ShowNotification('No dumpster nearby', 'error')
        return
    end
    
    local canSearchDumpster, dumpsterError = CanSearchDumpster(dumpster)
    if not canSearchDumpster then
        ShowNotification(dumpsterError, 'error')
        return
    end
    
    local canCarry, inventoryError = CheckInventorySpace()
    if not canCarry then
        ShowNotification(inventoryError, 'error')
        return
    end
    
    -- Start search process
    isSearching = true
    local playerId = GetPlayerServerId(PlayerId())
    local dumpsterHash = GetDumpsterHash(dumpster)
    
    -- Play animation
    if not PlaySearchAnimation() then
        ShowNotification('Failed to start search animation', 'error')
        isSearching = false
        return
    end
    
    -- Play sound and particles
    if Config.Effects.enableSounds then
        PlaySearchSound()
    end
    local dumpsterCoords = GetEntityCoords(dumpster)
    if Config.Effects.enableParticles and dumpsterCoords then
        CreateSearchParticles(dumpsterCoords)
    end
    
    ShowNotification('Searching through the dumpster...', 'primary')
    
    ShowProgressBar(
        function() -- On finish
            StopAnimation()
            isSearching = false
            
            -- Record search on server for statistics
            TriggerServerEvent('dumpster:server:recordSearch')
            
            -- Generate loot
            local loot = GetRandomLoot()
            local dumpsterCoords = GetEntityCoords(dumpster)
            
            if #loot == 0 then
                if Config.Effects.enableSounds then
                    PlayEmptySound()
                end
                if Config.Effects.enableParticles and dumpsterCoords then
                    CreateSearchParticles(dumpsterCoords)
                end
                ShowNotification('You found nothing useful...', 'error')
            else
                -- Determine highest rarity for sound/particles
                local highestRarity = 'common'
                for _, item in ipairs(loot) do
                    for rarity, data in pairs(LootTables) do
                        if data.items then
                            for _, lootItem in pairs(data.items) do
                                if lootItem.item == item.item then
                                    if rarity == 'legendary' then
                                        highestRarity = 'legendary'
                                    elseif rarity == 'rare' and highestRarity ~= 'legendary' then
                                        highestRarity = 'rare'
                                    elseif rarity == 'uncommon' and highestRarity == 'common' then
                                        highestRarity = 'uncommon'
                                    end
                                end
                            end
                        end
                    end
                end
                
                if Config.Effects.enableSounds then
                    PlayItemFoundSound(highestRarity)
                end
                if Config.Effects.enableParticles and dumpsterCoords then
                    CreateItemFoundParticles(dumpsterCoords, highestRarity)
                end
                -- Create a detailed message about what was found
                local message = 'You found: '
                local itemCount = 0
                for i, item in ipairs(loot) do
                    local itemData = QBCore.Shared.Items[item.item]
                    if itemData then
                        if itemCount > 0 then
                            message = message .. ', '
                        end
                        message = message .. item.quantity .. 'x ' .. itemData.label
                        itemCount = itemCount + 1
                    end
                end
                
                if itemCount > 0 then
                    ShowNotification(message, 'success')
                end
                
                -- Give items to player
                for _, item in ipairs(loot) do
                    if item and item.item and item.quantity then
                        if GiveItemToPlayer(item.item, item.quantity) then
                            DebugPrint('Gave player: ' .. item.item .. ' x' .. item.quantity)
                        else
                            DebugPrint('Failed to give item: ' .. item.item .. ' x' .. item.quantity)
                        end
                    end
                end
            end
            
            -- Set cooldowns
            State.playerCooldowns[playerId] = GetGameTimer() + Config.Search.cooldownTime
            if dumpsterHash then
                State.searchedDumpsters[dumpsterHash] = GetGameTimer() + Config.Search.dumpsterResetTime
            end
            
        end,
        function() -- On cancel
            StopAnimation()
            isSearching = false
            ShowNotification('Search cancelled', 'error')
        end
    )
end

-- ================================
-- TARGET SYSTEM INTEGRATION
-- ================================

local function SetupTargetSystem()
    if Config.Framework.target == 'qb-target' and GetResourceState('qb-target') == 'started' then
        local models = {}
        for model, _ in pairs(DumpsterModels) do
            table.insert(models, model)
        end
        
        exports['qb-target']:AddTargetModel(models, {
            options = {
                {
                    type = "client",
                    event = "dumpster:client:search",
                    icon = "fas fa-search",
                    label = "Search Dumpster",
                    canInteract = function()
                        return not isSearching and isLoggedIn
                    end
                }
            },
            distance = Config.Search.distance
        })
        
        DebugPrint('QB-Target integration enabled')
    elseif Config.Framework.target == 'ox_target' and GetResourceState('ox_target') == 'started' then
        local models = {}
        for model, _ in pairs(DumpsterModels) do
            table.insert(models, model)
        end
        
        exports.ox_target:addModel(models, {
            {
                name = 'search_dumpster',
                event = 'dumpster:client:search',
                icon = 'fas fa-search',
                label = 'Search Dumpster',
                distance = Config.Search.distance,
                canInteract = function()
                    return not isSearching and isLoggedIn
                end
            }
        })
        
        DebugPrint('OX-Target integration enabled')
    end
end

-- ================================
-- EVENT HANDLERS
-- ================================

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    isLoggedIn = true
    InitializeValidItems()
    SetupTargetSystem()
    
    -- Reset state on player load
    State.playerCooldowns = {}
    State.searchedDumpsters = {}
    dumpsterCache = {}
    cacheUpdateTime = 0
    
    DebugPrint('Player loaded, dumpster diving initialized')
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    isLoggedIn = false
    PlayerData = {}
    
    -- Clean up active searches
    if isSearching then
        StopAnimation()
        isSearching = false
    end
    
    -- Clear state
    State.playerCooldowns = {}
    State.searchedDumpsters = {}
    dumpsterCache = {}
    cacheUpdateTime = 0
    
    DebugPrint('Player unloaded, state cleared')
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    PlayerData = val
end)

RegisterNetEvent('dumpster:client:search', function()
    SearchDumpster()
end)

RegisterNetEvent('dumpster:client:itemReceived', function(itemName, quantity, itemData)
    if ValidateItem(itemName) and quantity > 0 then
        TriggerEvent('inventory:client:ItemBox', itemData, 'add', quantity)
    end
end)

-- ================================
-- CLEANUP SYSTEM
-- ================================

CreateThread(function()
    while true do
        Wait(300000) -- 5 minutes
        
        local currentTime = GetGameTimer()
        local cleanedCooldowns = 0
        local cleanedDumpsters = 0
        
        -- Clean expired player cooldowns
        for playerId, expiry in pairs(State.playerCooldowns) do
            if currentTime > expiry then
                State.playerCooldowns[playerId] = nil
                cleanedCooldowns = cleanedCooldowns + 1
            end
        end
        
        -- Clean expired dumpster searches
        for hash, expiry in pairs(State.searchedDumpsters) do
            if currentTime > expiry then
                State.searchedDumpsters[hash] = nil
                cleanedDumpsters = cleanedDumpsters + 1
            end
        end
        
        -- Clean dumpster cache if it's too old
        if currentTime - cacheUpdateTime > CACHE_DURATION * 2 then
            dumpsterCache = {}
            cacheUpdateTime = 0
            DebugPrint('Cleared dumpster cache due to age')
        end
        
        if cleanedCooldowns > 0 or cleanedDumpsters > 0 then
            DebugPrint('Cleaned ' .. cleanedCooldowns .. ' cooldowns and ' .. cleanedDumpsters .. ' dumpster entries')
        end
    end
end)

-- ================================
-- EXPORTS (For Integration with Other Resources)
-- ================================

exports('IsSearching', function()
    return isSearching
end)

exports('GetPlayerDumpsterStats', function()
    local playerId = GetPlayerServerId(PlayerId())
    return {
        isSearching = isSearching,
        isOnCooldown = State.playerCooldowns[playerId] ~= nil,
        cooldownRemaining = State.playerCooldowns[playerId] and math.max(0, State.playerCooldowns[playerId] - GetGameTimer()) or 0,
        nearbyDumpster = nearbyDumpster ~= nil
    }
end)

exports('CanSearch', function()
    local canSearch, error = CanPlayerSearch()
    return canSearch, error
end)

exports('GetNearbyDumpster', function()
    local dumpster, distance = GetClosestDumpster()
    return dumpster, distance
end)

-- ================================
-- INITIALIZATION
-- ================================

CreateThread(function()
    -- Wait for QB-Core to be ready
    while not QBCore do
        Wait(100)
    end
    
    -- Check if player is already loaded
    if QBCore.Functions.GetPlayerData() and QBCore.Functions.GetPlayerData().citizenid then
        PlayerData = QBCore.Functions.GetPlayerData()
        isLoggedIn = true
        InitializeValidItems()
        SetupTargetSystem()
        DebugPrint('Dumpster diving initialized on script start')
    end
end)