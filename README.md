# RE4 Mercenaries Remake for Garry's Mod

RE4 Mercenaries Remake is a cooperative survival score attack gamemode inspired by Resident Evil 4 and Resident Evil 5 Mercenaries. You and the other players have a limited amount of time to survive, kill as many enemies as possible, keep your combo alive, and finish with the highest score you can.

This is a proper gamemode, not just a collection of NPCs. It supplies the lobby, round rules, enemy spawning, scoring, HUD, loadouts, progression, skills, pickups, special actions, music, and results screen. The separate `RE4MercenariesContent` addon supplies the RE4 enemy entities, models, materials, animations, sounds, pickups, and other assets used by the included RE4 themes.

## What you need

- Garry's Mod
- This gamemode installed as `garrysmod/gamemodes/re4mercs`
- The `RE4MercenariesContent` addon installed as `garrysmod/addons/RE4MercenariesContent`
- A map with the `merc_` prefix, such as a map made for Mercenaries
- A navmesh on the map so enemies can find valid spawn and pathing areas
- The enemy or weapon addons you want to use, if you enable themes or loadout weapons that come from other addons

The content addon is required for the included RE4 and RE5 enemies. The gamemode can also use built-in Half-Life NPCs and custom server NPC lists, but those still need to exist on the server.

## Installation

### Playing locally

1. Copy the `re4mercs` folder into:

   `GarrysMod/garrysmod/gamemodes/`

2. Copy the complete `RE4MercenariesContent` folder into:

   `GarrysMod/garrysmod/addons/`

3. Start Garry's Mod and create a listen server on a `merc_` map.
4. Select **The Mercenaries** from the gamemode list if it is not selected automatically.

### Dedicated server

Install the gamemode and content addon on the server. The server must have the NPC and weapon dependencies installed too. Clients need the content addon and any clientside asset addons so that models, sounds, materials, and animations show correctly.

If a map has no navmesh, generate one with `nav_generate`, then save it with `nav_save`. Change maps or restart the server after generating it. The HUD displays a warning when no navmesh is available. The gamemode has a fallback spawn method, but proper navmesh support is strongly recommended.

## Starting a match

When players join, they are placed in the lobby. Open the gamemode menu with the on-screen prompt or use `!menu` in chat. The lobby lets you:

- Pick up to three weapons for your loadout
- Change your playermodel, skin, bodygroups, and player colour
- Buy and equip progression skills
- View player and weapon levels
- Choose the NPC theme, if you are an admin
- Ready up

Click **READY** when you are prepared. The match can start once the required players are ready. An admin can also start it manually with `!start` or `re4m_start`.

The match has three stages:

1. A short pre-round briefing and countdown
2. The active timed survival round
3. A results screen showing player scores, kills, combos, rank, and progression rewards

The default active round starts at 120 seconds. Killing enemies adds time, combo milestones add larger time bonuses, and time pickups can be collected during the round. The round cannot extend beyond the configured maximum round time unless the server owner changes that limit.

## How to play

The basic loop is simple: move around the map, kill enemies quickly, collect useful drops, and avoid taking damage so your combo does not expire.

Every kill gives score and extends the clock. The combo counter rises when kills happen before the combo timer runs out. Higher combos increase the score multiplier and award additional time at milestones.

Default combo milestones are:

- 10 combo: +15 seconds
- 25 combo: +20 seconds
- 50 combo: +30 seconds
- 100 combo: +60 seconds

The default combo multipliers are 1.0x at combo 1, 1.1x at 10, 1.2x at 25, 1.3x at 50, 1.4x at 70, and 1.5x at 100.

Taking damage resets the combo by default. Missing the combo timeout also resets it. A good run is about controlling enemies and keeping kills flowing, not just firing as fast as possible.

## Combat actions

The gamemode adds a few RE-style defensive and movement actions. The exact key shown on the HUD follows your current Garry's Mod binding.

- **Combat roll:** press the jump key while the round is active. Direction comes from your movement input. With no movement input, it performs a quick backward step. The roll has a short invulnerability window.
- **Parry:** press the use key when a parryable DrG enemy is attacking nearby. A successful parry protects you and creates an opening.
- **Counter:** press the use key when a nearby enemy is stunned and the counter prompt appears.
- **Door kick:** press the use key while looking at a suitable map door. This is available for map doors that the gamemode can safely open.
- **Pickups:** press the use key when the pickup prompt appears. The gamemode handles health, ammo, and time drops itself.

The use key chooses the relevant action based on what is in front of you. It does not require separate parry, counter, or pickup binds.

## Enemies and themes

The spawner creates one enemy at a time at a safe distance from players, keeps the active NPC count within the configured limit, and retargets enemies as players move around.

The included themes are:

- **default:** Half-Life zombies plus RE4 regular enemies and elite enemies
- **halflife:** Half-Life zombies, antlions, and related elite NPCs
- **re5:** RE5 Majini and elite enemies from the content addon
- **custom:** Combine and other server NPC classes configured in the gamemode

Default RE4 regular enemies include Ganados, Novistadors, and dogs. Default elite enemies include Dr. Salvador style enemies, Garradors, Brutes, and Regeneradors. RE5 includes Majini variants, Executioners, chainsaw enemies, and other supplied entities.

Elite enemies begin appearing as the lobby's total kill count grows. The default thresholds allow one elite at 25 kills, two at 50 kills, and up to three at 90 kills. Elite groups temporarily change the pressure of the round, so save strong weapons and skills for them.

The theme can be changed by an admin with `!theme re5` or `re4m_theme re5`. Valid defaults are `default`, `halflife`, `re5`, and `custom`.

## Weapons and loadouts

The loadout menu scans installed scripted weapons and lists weapons from common bases such as ARC9, ARCCW, TacRP, Modern Warfare Base, ASTW2, TFA, M9K, FAS2, CW, and standard weapon bases. Base weapons, tools, physics weapons, and other blacklisted templates are filtered out.

The default loadout limit is three weapons. The gamemode gives starting ammunition to the selected weapons and provides fallback pistol or SMG ammo when a weapon does not expose normal ammo settings. The selected loadout is saved clientside in `re4m_loadout` so it can be restored after reconnecting.

Weapon progression is separate for each weapon class. Using a weapon to kill enemies gives it weapon XP. Weapon levels increase its damage gradually, up to the built-in maximum weapon damage bonus of 50 percent.

If a newly installed weapon pack is not showing, an admin can rebuild the list with `re4m_rebuild_weapons`.

## Pickups

Enemy kills have a default 15 percent chance to drop a pickup. The default weighted drop table is:

- Health herb: 35 weight, restores 25 health
- Ammo: 40 weight, gives a fraction of the active weapon's maximum ammo
- Time: 25 weight, adds 10 seconds

Pickups normally disappear after 20 seconds. The HUD marks them with clear pickup effects and notifications. The `Item Drop Increase` skill increases the chance of seeing one.

## Progression and skills

Progression is stored server-side in `data/re4mercs/player_progression.json`. Player levels, XP, Merc Points, owned skills, equipped skills, and weapon progression persist across maps and sessions on that server.

Players gain XP from match results and can earn Merc Points at level milestones. Merc Points are spent in the lobby skill shop. You can own many skills but equip only three at a time.

Available skills include:

- Eagle Eye: sniper rifles deal 15 percent more damage
- Item Drop Increase: 50 percent more pickup drop chance
- Go For Broke!: combo chains last two seconds longer when 30 seconds or less remain
- Blitz Play: 15 percent more damage after a teammate recently damaged the same enemy
- Quick Shot Damage Increase: 10 percent more firearm damage
- Power Counter: 25 percent more melee damage during a counter opportunity
- Second Wind: 20 percent more damage below 30 percent health
- Martial Arts Master: 25 percent more melee damage and 10 percent less firearm damage
- Target Master: 15 percent more firearm damage and 10 percent less melee damage
- Last Stand: 20 percent more damage, but take 50 percent more damage
- Preemptive Strike: 20 percent more damage from behind
- Dying Breath: 25 percent more damage below 20 percent health
- Pharmacist: health pickups restore 50 percent more health
- Medic: health pickups also heal nearby teammates for half their value
- First Responder: health pickups also restore 20 health to distant living teammates
- Take It Easy: natural healing is faster while standing still
- Natural Healing: regenerate one health every five seconds below maximum health
- Time Bonus +: time pickups grant 50 percent more time
- Combo Bonus +: combo milestone time bonuses are 25 percent larger
- Limit Breaker: earn 10 percent more kill score above a 50 combo

## Ranks and scoring

The default score values are 500 for a normal kill, +250 for a headshot, +300 for a melee kill, and +750 for an elite kill. Combo multipliers are applied on top of the score.

The default result ranks are:

- C: 0
- B: 50,000
- A: 100,000
- S: 200,000
- S+: 500,000
- S++: 1,000,000

The HUD can show damage numbers, floating kill scores, enemy health bars, elite alerts, time extensions, combo popups, and kill feed entries. These can be disabled or tuned with convars.

## Server convars

Run these from the server console or place them in `server.cfg`. Values shown are the defaults.

### Round and time

| ConVar | Default | Purpose |
| --- | ---: | --- |
| `re4m_baseroundtime` | 120 | Starting round time in seconds |
| `re4m_maxroundtime` | 600 | Maximum round time after extensions |
| `re4m_preroundtime` | 10 | Pre-round countdown |
| `re4m_postroundtime` | 15 | Results screen duration |
| `re4m_timeextendonkill` | 5 | Time added for each kill |
| `re4m_timeextendoncombo10` | 15 | Bonus at combo 10 |
| `re4m_timeextendoncombo25` | 20 | Bonus at combo 25 |
| `re4m_timeextendoncombo50` | 30 | Bonus at combo 50 |
| `re4m_timeextendoncombo100` | 60 | Bonus at combo 100 |

### Spawning

| ConVar | Default | Purpose |
| --- | ---: | --- |
| `re4m_minspawndistance` | 800 | Minimum spawn distance from players |
| `re4m_maxspawndistance` | 4000 | Maximum spawn distance |
| `re4m_spawninterval` | 5 | Seconds between spawn attempts |
| `re4m_basemaxnpcs` | 18 | NPC cap with one player |
| `re4m_maxnpcsperplayer` | 5 | Extra NPC cap per additional player |
| `re4m_absolutemaxnpcs` | 40 | Hard NPC cap |

### HUD and feedback

| ConVar | Default | Purpose |
| --- | ---: | --- |
| `re4m_showdamagenumbers` | 1 | Show floating damage numbers |
| `re4m_showkillscores` | 1 | Show floating kill scores |
| `re4m_showenemyhealthbars` | 1 | Show enemy health bars |
| `re4m_showelitealerts` | 1 | Show elite spawn alerts |
| `re4m_maxdamagenumbers` | 30 | Maximum damage numbers on screen |
| `re4m_maxkillscorefloats` | 15 | Maximum floating kill scores |
| `re4m_damagenumberlifetime` | 1.0 | Normal damage number lifetime |
| `re4m_headshotnumberlifetime` | 1.5 | Headshot number lifetime |
| `re4m_healthbarmaxdistance` | 2000 | Maximum enemy health bar distance |

### Scoring, ammo, weapons, and pickups

| ConVar | Default | Purpose |
| --- | ---: | --- |
| `re4m_basekillscore` | 500 | Base kill score |
| `re4m_headshotbonus` | 250 | Headshot score bonus |
| `re4m_meleekillbonus` | 300 | Melee kill score bonus |
| `re4m_elitekillbonus` | 750 | Elite kill score bonus |
| `re4m_combotimeout` | 8 | Seconds before a combo expires |
| `re4m_comboresetondamage` | 1 | Reset combo when damaged |
| `re4m_startingprimaryammo` | 90 | Starting primary ammo |
| `re4m_startingsecondaryammo` | 30 | Starting secondary ammo |
| `re4m_fallbackpistolammo` | 60 | Fallback pistol ammo |
| `re4m_fallbacksmgammo` | 90 | Fallback SMG ammo |
| `re4m_maxweaponslots` | 3 | Maximum loadout weapons |
| `re4m_pickupdropchance` | 0.15 | Chance of a pickup on kill |
| `re4m_healthpickupamount` | 25 | Health restored by a herb |
| `re4m_ammopickupmultiplier` | 0.25 | Fraction of maximum ammo given |
| `re4m_timepickupamount` | 10 | Seconds given by a time pickup |
| `re4m_pickuplifetime` | 20 | Pickup lifetime |

### Player and combat actions

| ConVar | Default | Purpose |
| --- | ---: | --- |
| `re4m_playerhealth` | 150 | Starting health |
| `re4m_playerarmor` | 50 | Starting armor |
| `re4m_playerrunspeed` | 300 | Run speed |
| `re4m_playerwalkspeed` | 200 | Walk speed |
| `re4m_respawnenabled` | 0 | Allow respawns during a round |
| `re4m_friendlyfire` | 0 | Enable friendly fire |
| `re4m_respawndelay` | 5 | Respawn delay when enabled |
| `re4m_roll_enabled` | 1 | Enable jump-key combat rolls |
| `re4m_roll_cooldown` | 0.8 | Roll cooldown |
| `re4m_roll_iframe` | 0.2 | Roll invulnerability window |
| `re4m_roll_forward_distance` | 220 | Forward roll distance |
| `re4m_roll_side_distance` | 165 | Side roll distance |
| `re4m_roll_back_distance` | 145 | Backstep distance |
| `re4m_parry_enabled` | 1 | Enable use-key parries |
| `re4m_parry_range` | 120 | Parry range |
| `re4m_parry_cooldown` | 0.9 | Parry cooldown |
| `re4m_parry_duration` | 0.95 | Parry animation duration |
| `re4m_counter_enabled` | 1 | Enable counters |
| `re4m_counter_range` | 120 | Counter range |
| `re4m_counter_damage` | 750 | Counter damage |
| `re4m_counter_duration` | 1.2 | Counter animation duration |
| `re4m_door_kick_range` | 100 | Door kick range |

### Other settings

| ConVar | Default | Purpose |
| --- | ---: | --- |
| `re4m_blockhudaddons` | 1 | Block conflicting addon HUDs while playing |
| `re4m_menumusicvolume` | 0.4 | Menu music volume |
| `re4m_roundmusicvolume` | 0.6 | Round music volume |
| `re4m_resultsmusicvolume` | 0.5 | Results music volume |
| `re4m_echoteammessageduration` | 2.0 | Seconds per briefing message |
| `re4m_debug` | 0 | Enable debug prints |
| `re4m_debugspawns` | 0 | Show spawn debugging |
| `re4m_allplayersadmin` | 0 | Treat everyone as an admin for testing |

The first three debug and admin settings should normally stay at 0 on a public server.

## Client settings and commands

These can be entered in the client console:

- `re4m_thirdperson 1`: enable the over-the-shoulder camera
- `re4m_movement 1`: enable camera-relative movement and movement-facing
- `re4m_camera_shoulder`: swap the camera shoulder
- `re4m_hudblock_list`: print detected addon HUD hooks that can be blocked
- `re4m_adminpanel`: open the admin panel if you have permission

Client convars also store playermodel selection, skin, bodygroups, player colour, and the saved loadout.

## Admin commands

These require admin permission unless run from the server console:

- `re4m_start` or `!start`: start a match
- `re4m_stop` or `!stop`: end the current match
- `!admin`: open the admin panel
- `re4m_theme <theme>` or `!theme <theme>`: choose the NPC theme
- `re4m_rebuild_weapons`: rebuild the available weapon list
- `re4m_check_navmesh`: check whether the current map has a usable navmesh
- `re4m_toggle_debug`: toggle debug printing
- `re4m_debug_spawns`: toggle spawn debugging
- `re4m_test_spawn`: spawn a test regular enemy
- `re4m_test_elite`: spawn a test elite enemy
- `re4m_npc_count`: print the active NPC count
- `re4m_setlevel <player> <level>`: set a player's level
- `re4m_givexp <player> <amount>`: give XP
- `re4m_removexp <player> <amount>`: remove XP
- `re4m_delevel <player> <amount>`: lower a player's level
- `re4m_givemp <player> <amount>`: give Merc Points
- `re4m_setmp <player> <amount>`: set Merc Points
- `re4m_removemp <player> <amount>`: remove Merc Points

Player-targeting commands use the server's normal Garry's Mod player target syntax where supported.

## Troubleshooting

**The gamemode does not appear:** check that the folder is exactly `gamemodes/re4mercs` and that `re4mercs.txt` is directly inside it.

**RE4 enemies are missing:** check that `RE4MercenariesContent` is directly inside the `addons` folder and that the required DrGBase or enemy dependencies are installed.

**Enemies do not spawn:** run `re4m_check_navmesh`. If the map has no navmesh, run `nav_generate` and `nav_save` as described above. Also check that the selected theme contains entity classes that are installed.

**Weapons do not appear:** install the weapon pack on the server, make sure it is a real spawnable weapon rather than a base weapon, then run `re4m_rebuild_weapons`.

**HUD elements overlap or disappear:** try `re4m_blockhudaddons 1`. This gamemode intentionally hides many external HUD hooks so its timer, score, health, combo, and prompts remain readable.

**Progression reset:** progression is saved by the server, not by the client. Check that the server can write to `garrysmod/data/re4mercs/player_progression.json` and that the server is not deleting its data folder between restarts.

## Credits and content note

This project is a fan-made Garry's Mod gamemode inspired by the Resident Evil Mercenaries format. Resident Evil names, characters, sounds, models, and other original assets belong to their respective owners. Check the included addon and dependency licenses before redistributing content.
