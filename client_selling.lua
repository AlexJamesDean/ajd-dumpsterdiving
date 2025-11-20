-- ================================
-- Dumpster Diving - Selling System (Client)
-- QB-Core Framework
-- ================================

local QBCore = exports['qb-core']:GetCoreObject()
local sellingZones = {}
local sellingBlips = {}
local sellingPeds = {}
local isNearSellingZone = false
local currentSellingZone = nil

-- ================================
-- UTILITY FUNCTIONS
-- ================================

local function DebugPrint(message)
    if Config and Config.Debug then
        print('^3[DumpsterDiving-Selling]^7 ' .. tostring(message))
    end
end

local function ShowNotification(message, type)
    local notificationType = 'info'
    
    if type == 'error' then
        notificationType = 'error'
    elseif type == 'success' then
        notificationType = 'success'
    elseif type == 'primary' then
        notificationType = 'info'
    end
    
    -- Use the ajd-hud export for notifications
    if exports['ajd-hud'] and exports['ajd-hud'].showNotification then
        exports['ajd-hud']:showNotification(message, notificationType)
    elseif QBCore and QBCore.Functions and QBCore.Functions.Notify then
        QBCore.Functions.Notify(message, type or 'primary')
    end
end

local function GetDistance(coords1, coords2)
    return #(coords1 - coords2)
end

-- ================================
-- SELLING ZONE MANAGEMENT
-- ================================

local function CreateSellingBlip(location)
    if not location.blip or not location.blip.enabled then
        return nil
    end
    
    local blip = AddBlipForCoord(location.coords.x, location.coords.y, location.coords.z)
    SetBlipSprite(blip, location.blip.sprite or 500)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, location.blip.scale or 0.7)
    SetBlipColour(blip, location.blip.color or 2)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(location.blip.label or "Scrap Dealer")
    EndTextCommandSetBlipName(blip)
    
    return blip
end

local function CreateSellingPed(location)
    if not location.ped or not location.ped.enabled then
        return nil
    end
    
    local model = GetHashKey(location.ped.model or "a_m_m_eastsa_02")
    RequestModel(model)
    
    local timeout = 0
    while not HasModelLoaded(model) and timeout < 5000 do
        Wait(100)
        timeout = timeout + 100
    end
    
    if not HasModelLoaded(model) then
        DebugPrint('Failed to load ped model: ' .. tostring(location.ped.model))
        return nil
    end
    
    local ped = CreatePed(4, model, location.coords.x, location.coords.y, location.coords.z - 1.0, location.ped.heading or 0.0, false, true)
    
    if ped and ped ~= 0 then
        SetEntityAsMissionEntity(ped, true, true)
        SetPedFleeAttributes(ped, 0, false)
        SetPedCombatAttributes(ped, 46, true)
        SetPedCanRagdollFromPlayerImpact(ped, false)
        SetEntityInvincible(ped, true)
        FreezeEntityPosition(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        
        DebugPrint('Created selling ped at ' .. tostring(location.coords))
        return ped
    end
    
    return nil
end

local function InitializeSellingZones()
    if not Config or not Config.Selling or not Config.Selling.enabled then
        DebugPrint('Selling system is disabled')
        return
    end
    
    if not Config.Selling.locations or #Config.Selling.locations == 0 then
        DebugPrint('No selling locations configured')
        return
    end
    
    for i, location in ipairs(Config.Selling.locations) do
        if location.coords then
            -- Create blip
            if location.blip and location.blip.enabled then
                sellingBlips[i] = CreateSellingBlip(location)
            end
            
            -- Create ped
            if location.ped and location.ped.enabled then
                sellingPeds[i] = CreateSellingPed(location)
            end
            
            -- Store zone data
            sellingZones[i] = {
                coords = location.coords,
                index = i
            }
            
            DebugPrint('Initialized selling zone ' .. i .. ' at ' .. tostring(location.coords))
        end
    end
end

local function GetClosestSellingZone()
    local ped = PlayerPedId()
    if not ped or ped == 0 then
        return nil, 999
    end
    
    local coords = GetEntityCoords(ped)
    if not coords then
        return nil, 999
    end
    
    local closestZone = nil
    local closestDistance = 5.0 -- Interaction distance
    
    for i, zone in pairs(sellingZones) do
        if zone and zone.coords then
            local distance = GetDistance(coords, zone.coords)
            if distance < closestDistance then
                closestDistance = distance
                closestZone = zone
            end
        end
    end
    
    return closestZone, closestDistance
end

-- ================================
-- TARGET SYSTEM INTEGRATION
-- ================================

local function SetupSellingTargets()
    if not Config or not Config.Selling or not Config.Selling.enabled then
        return
    end
    
    if GetResourceState('qb-target') == 'started' then
        for i, location in ipairs(Config.Selling.locations) do
            if location.coords then
                exports['qb-target']:AddBoxZone("dumpster_selling_" .. i, location.coords, 2.0, 2.0, {
                    name = "dumpster_selling_" .. i,
                    heading = 0.0,
                    debugPoly = false,
                    minZ = location.coords.z - 1.0,
                    maxZ = location.coords.z + 2.0,
                }, {
                    options = {
                        {
                            type = "client",
                            event = "dumpster:client:openSellingMenu",
                            icon = "fas fa-dollar-sign",
                            label = "Sell Items",
                        }
                    },
                    distance = 2.5
                })
            end
        end
        DebugPrint('QB-Target integration enabled for selling')
    elseif GetResourceState('ox_target') == 'started' then
        for i, location in ipairs(Config.Selling.locations) do
            if location.coords then
                exports.ox_target:addBoxZone({
                    coords = location.coords,
                    size = vector3(2.0, 2.0, 3.0),
                    rotation = 0.0,
                    name = "dumpster_selling_" .. i,
                    options = {
                        {
                            name = 'sell_items',
                            event = 'dumpster:client:openSellingMenu',
                            icon = 'fas fa-dollar-sign',
                            label = 'Sell Items',
                            distance = 2.5
                        }
                    }
                })
            end
        end
        DebugPrint('OX-Target integration enabled for selling')
    end
end

-- ================================
-- SELLING MENU
-- ================================

local function GetSellableItems()
    local PlayerData = QBCore.Functions.GetPlayerData()
    if not PlayerData or not PlayerData.items then
        return {}
    end
    
    local sellableItems = {}
    
    for _, item in pairs(PlayerData.items) do
        if item and item.name and Config.Selling.customPrices[item.name] then
            local price = Config.Selling.customPrices[item.name]
            table.insert(sellableItems, {
                name = item.name,
                label = item.label or item.name,
                amount = item.amount or 0,
                price = price,
                totalValue = price * (item.amount or 0)
            })
        end
    end
    
    return sellableItems
end

local function OpenSellingMenu()
    local zone, distance = GetClosestSellingZone()
    if not zone then
        ShowNotification('No selling location nearby', 'error')
        return
    end
    
    local sellableItems = GetSellableItems()
    if #sellableItems == 0 then
        ShowNotification('You have no items to sell', 'error')
        return
    end
    
    -- Use ox_lib menu if available
    if exports.ox_lib and exports.ox_lib.openMenu then
        local menuOptions = {}
        for _, item in ipairs(sellableItems) do
            table.insert(menuOptions, {
                title = item.label .. ' (' .. item.amount .. 'x)',
                description = 'Sell for $' .. item.price .. ' each (Total: $' .. item.totalValue .. ')',
                icon = 'dollar-sign',
                onSelect = function()
                    TriggerServerEvent('dumpster:server:sellItem', item.name, item.amount, item.price)
                end
            })
        end
        
        exports.ox_lib:registerContext({
            id = 'dumpster_selling',
            title = 'Sell Items',
            options = menuOptions
        })
        exports.ox_lib:showContext('dumpster_selling')
    elseif exports['qb-menu'] and exports['qb-menu'].openMenu then
        -- QB-Menu fallback
        local menuOptions = {}
        for _, item in ipairs(sellableItems) do
            table.insert(menuOptions, {
                header = item.label .. ' (' .. item.amount .. 'x)',
                txt = 'Sell for $' .. item.price .. ' each (Total: $' .. item.totalValue .. ')',
                icon = 'fas fa-dollar-sign',
                params = {
                    event = 'dumpster:server:sellItem',
                    args = {
                        itemName = item.name,
                        quantity = item.amount,
                        price = item.price
                    }
                }
            })
        end
        
        exports['qb-menu']:openMenu(menuOptions)
    else
        -- Simple notification with item list
        local message = 'Sellable items: '
        for i, item in ipairs(sellableItems) do
            if i > 1 then message = message .. ', ' end
            message = message .. item.label .. ' ($' .. item.price .. '/ea)'
        end
        ShowNotification(message, 'primary')
        ShowNotification('Use /sellitem [item] [amount] to sell items', 'info')
    end
end

-- ================================
-- EVENT HANDLERS
-- ================================

RegisterNetEvent('dumpster:client:openSellingMenu', function()
    OpenSellingMenu()
end)

RegisterNetEvent('dumpster:client:sellItemResult', function(success, message, amount)
    if success then
        ShowNotification('Sold items for $' .. amount, 'success')
    else
        ShowNotification(message or 'Failed to sell items', 'error')
    end
end)

-- ================================
-- CLEANUP
-- ================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        -- Remove blips
        for _, blip in pairs(sellingBlips) do
            if blip then
                RemoveBlip(blip)
            end
        end
        
        -- Remove peds
        for _, ped in pairs(sellingPeds) do
            if ped and DoesEntityExist(ped) then
                DeleteEntity(ped)
            end
        end
        
        -- Remove target zones
        if GetResourceState('qb-target') == 'started' then
            for i, _ in pairs(sellingZones) do
                exports['qb-target']:RemoveZone("dumpster_selling_" .. i)
            end
        elseif GetResourceState('ox_target') == 'started' then
            for i, _ in pairs(sellingZones) do
                exports.ox_target:removeZone("dumpster_selling_" .. i)
            end
        end
    end
end)

-- ================================
-- INITIALIZATION
-- ================================

CreateThread(function()
    -- Wait for QB-Core and config to be ready
    while not QBCore do
        Wait(100)
    end
    
    Wait(2000) -- Wait for config to load
    
    if Config and Config.Selling and Config.Selling.enabled then
        InitializeSellingZones()
        SetupSellingTargets()
        DebugPrint('Selling system initialized')
    end
end)

