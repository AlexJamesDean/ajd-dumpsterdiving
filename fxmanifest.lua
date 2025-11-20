fx_version 'cerulean'
game 'gta5'

author 'AJD Development'
description 'Enhanced Dumpster Diving System for QB-Core with selling system, sound effects, and particle effects'
version '2.2.0'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'config.lua'
}

client_scripts {
    'client.lua',
    'client_selling.lua'
}

server_scripts {
    'server.lua',
    'server_selling.lua'
}

dependencies {
    'qb-core'
}

-- Optional dependencies (will work without these)
optional_dependencies {
    'qb-target',
    'ox_target',
    'qb-progressbar',
    'progressBars',
    'mythic_progbar',
    'ox_lib'
}

lua54 'yes'