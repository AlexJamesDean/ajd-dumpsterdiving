-- ================================
-- Dumpster Diving - Selling System (Server)
-- QB-Core Framework
-- ================================

local QBCore = exports['qb-core']:GetCoreObject()

-- ================================
-- UTILITY FUNCTIONS
-- ================================

local function Log(message, level)
    level = level or 'info'
    local prefix = '^3[DumpsterDiving-Selling]^7'
    
    if level == 'error' then
        prefix = '^1[DumpsterDiving-Selling ERROR]^7'
    elseif level == 'warn' then
        prefix = '^3[DumpsterDiving-Selling WARN]^7'
    elseif level == 'success' then
        prefix = '^2[DumpsterDiving-Selling]^7'
    end
    
    print(prefix .. ' ' .. tostring(message))
end

local function GetItemPrice(itemName, quantity)
    if not Config or not Config.Selling then
        return 0
    end
    
    -- Check for custom price
    if Config.Selling.customPrices and Config.Selling.customPrices[itemName] then
        return Config.Selling.customPrices[itemName] * quantity
    end
    
    -- Use percentage of item value if enabled
    if Config.Selling.usePercentage then
        local itemData = QBCore.Shared.Items[itemName]
        if itemData and itemData.price then
            local percentage = Config.Selling.defaultPercentage or 50
            return math.floor((itemData.price * quantity) * (percentage / 100))
        end
    end
    
    return 0
end

local function ValidateSellRequest(source, itemName, quantity)
    if not source or source == 0 then
        return false, 'Invalid source'
    end
    
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return false, 'Player not found'
    end
    
    if not itemName or type(itemName) ~= 'string' then
        return false, 'Invalid item name'
    end
    
    if not quantity or type(quantity) ~= 'number' or quantity <= 0 then
        return false, 'Invalid quantity'
    end
    
    -- Check if item exists in shared items
    if not QBCore.Shared.Items[itemName] then
        return false, 'Item does not exist'
    end
    
    -- Check if player has the item
    local hasItem = Player.Functions.GetItemByName(itemName)
    if not hasItem or (hasItem.amount or 0) < quantity then
        return false, 'You do not have enough of this item'
    end
    
    -- Check if item is sellable (has a price configured)
    local price = GetItemPrice(itemName, quantity)
    if price <= 0 then
        return false, 'This item cannot be sold here'
    end
    
    -- Check selling restrictions
    if Config.Selling.minSellAmount and quantity < Config.Selling.minSellAmount then
        return false, 'Minimum sell amount is ' .. Config.Selling.minSellAmount
    end
    
    if Config.Selling.maxSellAmount and quantity > Config.Selling.maxSellAmount then
        return false, 'Maximum sell amount is ' .. Config.Selling.maxSellAmount
    end
    
    return true, nil
end

-- ================================
-- SELLING FUNCTION
-- ================================

local function SellItem(source, itemName, quantity, pricePerItem)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return false, 'Player not found', 0
    end
    
    -- Validate request
    local isValid, errorMsg = ValidateSellRequest(source, itemName, quantity)
    if not isValid then
        return false, errorMsg, 0
    end
    
    -- Calculate total price
    local totalPrice = GetItemPrice(itemName, quantity)
    if totalPrice <= 0 then
        return false, 'Invalid price for this item', 0
    end
    
    -- Remove item from player
    local removed = Player.Functions.RemoveItem(itemName, quantity)
    if not removed then
        return false, 'Failed to remove item from inventory', 0
    end
    
    -- Give money to player
    local paymentMethod = Config.Selling.paymentMethod or 'cash'
    if paymentMethod == 'cash' then
        Player.Functions.AddMoney('cash', totalPrice, 'dumpster-selling')
    elseif paymentMethod == 'bank' then
        Player.Functions.AddMoney('bank', totalPrice, 'dumpster-selling')
    else
        -- Default to cash
        Player.Functions.AddMoney('cash', totalPrice, 'dumpster-selling')
    end
    
    -- Trigger client event for item box
    TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[itemName], 'remove', quantity)
    
    Log('Player ' .. Player.PlayerData.citizenid .. ' sold ' .. quantity .. 'x ' .. itemName .. ' for $' .. totalPrice, 'success')
    
    return true, 'Items sold successfully', totalPrice
end

-- ================================
-- EVENT HANDLERS
-- ================================

RegisterNetEvent('dumpster:server:sellItem', function(itemName, quantity, pricePerItem)
    local source = source
    
    if not source or source == 0 then
        Log('Invalid source in sellItem event', 'error')
        return
    end
    
    -- Additional validation
    if type(itemName) ~= 'string' or type(quantity) ~= 'number' or quantity <= 0 then
        Log('Invalid parameters in sellItem event from source: ' .. source, 'warn')
        TriggerClientEvent('dumpster:client:sellItemResult', source, false, 'Invalid request parameters')
        return
    end
    
    -- Check cooldown if configured
    if Config.Selling.sellCooldown and Config.Selling.sellCooldown > 0 then
        -- Cooldown logic could be added here if needed
    end
    
    -- Process sale
    local success, message, amount = SellItem(source, itemName, quantity, pricePerItem)
    TriggerClientEvent('dumpster:client:sellItemResult', source, success, message, amount)
end)

-- ================================
-- ADMIN COMMANDS
-- ================================

-- ================================
-- COMMANDS
-- ================================

RegisterCommand('dumpstersellprice', function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    
    if not Player or not QBCore.Functions.HasPermission(source, 'admin') then
        TriggerClientEvent('QBCore:Notify', source, 'No permission', 'error')
        return
    end
    
    if not args[1] then
        TriggerClientEvent('QBCore:Notify', source, 'Usage: /dumpstersellprice [item_name]', 'error')
        return
    end
    
    local itemName = args[1]
    local quantity = tonumber(args[2]) or 1
    
    local price = GetItemPrice(itemName, quantity)
    local itemData = QBCore.Shared.Items[itemName]
    
    if not itemData then
        TriggerClientEvent('QBCore:Notify', source, 'Item not found', 'error')
        return
    end
    
    local message = 'Item: ' .. itemData.label .. '\n'
    message = message .. 'Price per item: $' .. GetItemPrice(itemName, 1) .. '\n'
    message = message .. 'Price for ' .. quantity .. 'x: $' .. price
    
    TriggerClientEvent('chat:addMessage', source, {
        color = {255, 255, 0},
        multiline = true,
        args = {'Selling Price', message}
    })
end, false)

RegisterCommand('sellitem', function(source, args)
    if not args[1] then
        TriggerClientEvent('QBCore:Notify', source, 'Usage: /sellitem [item_name] [amount]', 'error')
        return
    end
    
    local itemName = args[1]
    local quantity = tonumber(args[2]) or 1
    
    -- Validate and process sale
    local success, message, amount = SellItem(source, itemName, quantity, nil)
    TriggerClientEvent('dumpster:client:sellItemResult', source, success, message, amount)
end, false)

-- ================================
-- STARTUP
-- ================================

CreateThread(function()
    Wait(1000) -- Wait for QB-Core to initialize
    
    if Config and Config.Selling and Config.Selling.enabled then
        Log('Selling system initialized', 'success')
        Log('Payment method: ' .. (Config.Selling.paymentMethod or 'cash'), 'info')
        Log('Selling locations: ' .. (#Config.Selling.locations or 0), 'info')
    else
        Log('Selling system is disabled', 'info')
    end
end)

