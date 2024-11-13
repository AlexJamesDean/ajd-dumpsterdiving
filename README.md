# AJD Dumpster Diving Script for QB-Core

A comprehensive dumpster diving system for FiveM QB-Core servers that adds an immersive way for players to search through dumpsters, find valuable items, and progress their scavenging skills.

## Features

- **Skill-Based Progression System**
  - Players earn experience while successfully searching dumpsters
  - Higher skill levels unlock access to better dumpsters
  - Skill level influences loot quality and success rates

- **Dynamic Loot System**
  - Different dumpster types yield different categories of loot
  - Loot quality scales with player skill level
  - Configurable loot tables for each dumpster type

- **Interactive Searching**
  - Realistic searching animations
  - Integration with QB-Core's minigame system
  - Progress bar system for search duration

- **Risk vs. Reward**
  - Chance of injury while searching
  - Different search techniques with varying difficulty levels
  - Cooldown system prevents excessive farming

- **QB-Target Integration**
  - Seamless interaction with dumpsters
  - Visual indicators for searchable objects
  - Easy-to-use targeting system

## Dependencies

- QB-Core Framework
- QB-Target
- QB-Minigames

## Installation

1. Ensure you have all dependencies installed and updated
2. Drop the `ajd-dumpsterdiving` folder into your server's `resources` directory
3. Add `ensure ajd-dumpsterdiving` to your `server.cfg`
4. Configure the script settings in `config.lua` to your preferences
5. Restart your server

## Configuration

The script is highly configurable through the `config.lua` file, allowing you to adjust:

- Dumpster types and their requirements
- Loot tables and item probabilities
- Search durations and cooldowns
- Skill progression rates
- Injury chances and effects
- Search technique difficulties

## Usage

Players can:
1. Approach any configured dumpster
2. Use QB-Target to interact with the dumpster
3. Complete the search minigame
4. Receive items based on success and skill level
5. Progress their dumpster diving skill

## Support

For support, bug reports, or feature requests, please:
1. Create an issue in the repository
2. Join our Discord server [Discord Link]
3. Contact us through our support channels

## License

This script is protected by copyright and is not to be redistributed without permission.

## Credits

- Created by [Your Name/Organization]
- Special thanks to the QB-Core community

## Version History

- 1.0.0
  - Initial release
  - Basic functionality implemented
  - Skill system integration
