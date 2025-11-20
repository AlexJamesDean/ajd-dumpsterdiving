-- ================================
-- Dumpster Diving Configuration
-- ================================

Config = Config or {}

-- Selling System Configuration
Config.Selling = {
    enabled = true,
    
    -- Selling locations (coordinates where players can sell items)
    locations = {
        {
            coords = vector3(1138.23, -982.14, 46.42), -- Legion Square Pawn Shop
            blip = {
                enabled = true,
                sprite = 500,
                color = 2,
                scale = 0.7,
                label = "Scrap Dealer"
            },
            ped = {
                enabled = true,
                model = "a_m_m_eastsa_02",
                heading = 90.0
            }
        },
        -- Add more locations as needed
        -- {
        --     coords = vector3(x, y, z),
        --     blip = { enabled = true, sprite = 500, color = 2, scale = 0.7, label = "Scrap Dealer" },
        --     ped = { enabled = true, model = "a_m_m_eastsa_02", heading = 90.0 }
        -- }
    },
    
    -- Item prices (percentage of item value or fixed price)
    -- If usePercentage = true, price is % of item's worth in qb-core/shared/items.lua
    -- If usePercentage = false, price is fixed amount
    usePercentage = true,
    defaultPercentage = 50, -- 50% of item value
    
    -- Custom prices for specific items (overrides percentage)
    customPrices = {
        -- Common items
        ['lead'] = 15,
        ['gunpowder'] = 10,
        
        -- Uncommon items
        ['pistol_barrel'] = 75,
        ['weapon_spring'] = 40,
        ['pistol_frame'] = 100,
        ['weapon_parts'] = 50,
        ['simple_trigger'] = 60,
        ['combatpistol_barrel'] = 90,
        ['revolver_barrel'] = 90,
        
        -- Rare items
        ['burst_trigger'] = 150,
        ['advanced_trigger'] = 140,
        ['smg_barrel'] = 200,
        ['smg_frame'] = 250,
        ['advanced_parts'] = 180,
        ['vintage_parts'] = 160,
        
        -- Legendary items
        ['shotgun_barrel'] = 400,
        ['shotgun_frame'] = 450,
        ['rifle_barrel'] = 500,
        ['rifle_frame'] = 550,
        ['sniper_barrel'] = 700,
        ['sniper_frame'] = 750,
        ['precision_trigger'] = 300,
        ['rifle_scope'] = 350,
    },
    
    -- Payment method
    paymentMethod = 'cash', -- 'cash' or 'bank'
    
    -- Selling restrictions
    minSellAmount = 1,
    maxSellAmount = 50, -- Max items per transaction
    sellCooldown = 0, -- Cooldown in ms (0 = no cooldown)
}
