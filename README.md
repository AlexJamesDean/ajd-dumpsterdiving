# AJD Dumpster Dive

Enhanced dumpster diving gameplay built for QB-Core with configurable loot tiers, immersive feedback, integrated selling, and admin/anti-cheat tooling.

```4:54:client.lua
-- Features:
-- - Optimized dumpster detection with caching
-- - Fixed loot generation logic
-- - Improved error handling and validation
-- - Support for multiple target systems (qb-target, ox_target)
-- - Support for multiple progress bar systems
-- - Comprehensive anti-cheat protection
-- - Selling system integration
```

## Feature Highlights
- **Framework friendly:** toggle target, progress, inventory, and notification systems without rewriting the core loop (`Config.Framework` block).  
- **Secure loot economy:** weighted rarity tables plus item validation to guarantee only whitelisted items are given out.  
- **Immersive experience:** optional sound/particle effects, ped vendors, blips, and ajd-hud notifications for selling interactions.  
- **Built-in selling system:** configurable locations, payment methods, and price handling (fixed or percentage of item value).  
- **Defense in depth:** rate limiting, weight checks, suspicious-activity tracking, and optional Discord webhook logging.  
- **Admin + exports:** commands and exports for stats, cooldown management, and integration with jobs, quests, or UI.  

```24:75:config.lua
Config.Selling = {
    enabled = true,
    locations = {
        {
            coords = vector3(1138.23, -982.14, 46.42),
            blip = {...},
            ped = {...}
        }
    },
    usePercentage = true,
    defaultPercentage = 50,
    customPrices = {
        ['lead'] = 15,
        ...
    },
    paymentMethod = 'cash'
}
```

```24:136:client.lua
local LootTables = {
    common = { weight = 60, items = { ... } },
    uncommon = { weight = 25, items = { ... } },
    rare = { weight = 12, items = { ... } },
    legendary = { weight = 3, items = { ... } }
}
```

```570:621:server.lua
exports('GetPlayerDumpsterStats', function(source) ... end)
exports('CanPlayerSearch', function(source) ... end)
exports('GetServerStats', function() ... end)
exports('ResetPlayerCooldown', function(source) ... end)
```

## Requirements
- `qb-core` (hard dependency)
- Inventory with the items declared in `loot tables` and `Config.Selling.customPrices`

### Optional Resources
- Target: `qb-target` or `ox_target`
- Progress: `qb-progressbar`, `progressBars`, or `mythic_progbar`
- Notifications: `ox_lib`, `mythic_notify`, or AJD HUD
- UI feedback: `ox_lib` (context menus) and `ajd-hud`

```24:54:client.lua
local Config = {
    Framework = {
        progressbar = 'qb-progressbar',
        target = 'qb-target',
        inventory = 'qb-inventory',
        notification = 'qb-core'
    },
    ...
}
```

## Installation
1. Download or clone the repository into `resources/[ajd]/ajd-dumpsterdive`.
2. Add `ensure ajd-dumpsterdive` (or `ensure [ajd]`) to your `server.cfg` after `qb-core`.
3. Verify all referenced loot/selling items exist in `qb-core/shared/items.lua` with sensible prices if you rely on percentage-based selling.
4. Restart the server or run `refresh` + `start ajd-dumpsterdive` from the server console.

## Configuration Guide
- **Loot + balance:** edit rarity weights, item lists, and drop chances in `client.lua` → `LootTables`.
- **Framework switches:** change target/progress/inventory modules inside the `Config.Framework` section of `client.lua`.
- **Selling flow:** adjust `Config.Selling` inside `config.lua` for locations, blips, ped models, price mode, payment method, cooldown, and limits.
- **Anti-cheat:** tune `ServerConfig` in `server.lua` (per-minute caps, webhook logging, max weight, etc.).
- **Effects:** enable/disable sound and particle feedback via `Config.Effects` in `client.lua`.

## Gameplay Overview
1. Approach any whitelisted dumpster prop. Target zones are automatically created for `qb-target`/`ox_target`; fallback keybind listening can be added easily.
2. Start a search; progress bars, animations, sounds, and FX run for ~3 seconds with built-in cooldown handling.
3. Successfully searching rolls against the weighted loot tables and pushes items through the server-side validator/anti-cheat pipeline.
4. Bring loot to any configured selling location, use the target interaction (or `/sellitem item amount`), and get paid in cash or bank depending on config.

```400:529:server.lua
/dumpsterstats, /dumpsterreset, /dumpsterplayerstats, /dumpsterunblock, /dumpsterreload
```

```180:227:server_selling.lua
/dumpstersellprice, /sellitem
```

## Admin & Dev Commands
| Command | Permission | Description |
| --- | --- | --- |
| `/dumpsterstats` | admin | Print global search/item totals. |
| `/dumpsterreset confirm` | god | Wipe all dumpster stats and cooldowns. |
| `/dumpsterplayerstats [id]` | admin | View live stats for a specific player. |
| `/dumpsterunblock [id]` | admin | Clear a player's temporary block/suspicion. |
| `/dumpsterreload` | god | Hot reloads config (placeholder hook). |
| `/dumpstersellprice [item] [amount?]` | admin | Shows sell payout for the item/stack. |
| `/sellitem [item] [amount?]` | any | Manual CLI to sell from inventory (uses same validation). |

## Exports (Client)
- `exports['ajd-dumpsterdive']:IsSearching()`
- `exports['ajd-dumpsterdive']:GetPlayerDumpsterStats()`
- `exports['ajd-dumpsterdive']:CanSearch()`
- `exports['ajd-dumpsterdive']:GetNearbyDumpster()`

## Exports (Server)
- `exports['ajd-dumpsterdive']:GetPlayerDumpsterStats(source)`
- `exports['ajd-dumpsterdive']:CanPlayerSearch(source)`
- `exports['ajd-dumpsterdive']:GetServerStats()`
- `exports['ajd-dumpsterdive']:ResetPlayerCooldown(source)`

Use these to tie dumpster diving into quests, jobs, or seasonal events (e.g., only allow searching during specific weather, award XP, etc.).

## Roadmap / Ideas
`IMPROVEMENTS.md` already contains a prioritized backlog that covers exports, audio polish, XP systems, and more achievement/quest hooks. Keep that document in sync with GitHub issues to provide contributors a clear path forward.

## Credits & License
- Developed by **AJD Development**.  
- Built for **QB-Core** servers (Lua 5.4 / CfxLua).  
- MIT or custom license – update this section with the license terms you plan to release under.

Pull requests and issue reports are welcome!

I fix the bugs other devs gaslight you about.
A I tools, Five M systems, automation pipelines.
Build it, break it, resurrect it: 👉 https://AJThe.Dev
