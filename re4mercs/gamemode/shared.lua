-- RE4 Mercenaries Remake - Shared Code
-- Runs on both client and server

GM.Name    = "RE Mercenaries"
GM.Author  = "SLeNd3rMaN23"
GM.Email   = ""
GM.Website = ""
GM.Base    = "base"

-- mount wOS animations
wOS = wOS or {}
wOS.AnimExtension = wOS.AnimExtension or {}
wOS.AnimExtension.Mounted = wOS.AnimExtension.Mounted or {}

wOS.AnimExtension.Mounted["Blade Symphony"] = true
wOS.AnimExtension.Mounted[ "Resident Evil The Mercenaries" ] = true
wOS.AnimExtension.Mounted[ "Action Half-life" ] = true


-- ============================================
-- GAME STATES
-- ============================================
GAMESTATE_MENU     = 0   -- Players in menu, picking loadout
GAMESTATE_PREROUND = 1   -- Countdown before round
GAMESTATE_ACTIVE   = 2   -- Round in progress
GAMESTATE_POSTROUND = 3  -- Results screen
GAMESTATE_WAITING  = 4   -- Waiting for players

-- ============================================
-- NET MESSAGE STRINGS
-- ============================================
RE4MERCS_NET = {
    "RE4M_GameState",
    "RE4M_StartGame",
    "RE4M_SetLoadout",
    "RE4M_SetPlayermodel",
    "RE4M_SetPlayerHands",
    "RE4M_SetPlayerBodygroups",
    "RE4M_SetPlayerSkin",
    "RE4M_SetPlayerColor",
    "RE4M_ParryRequest",
    "RE4M_PlayParryAnim",
    "RE4M_CounterRequest",
    "RE4M_PlayCounterAnim",
    "RE4M_DoorKickRequest",
    "RE4M_PlayDoorKick",
    "RE4M_UsePickupRequest",
    "RE4M_SetTheme",
    "RE4M_SetCustomNPCs",
    "RE4M_WeaponList",
    "RE4M_ScoreUpdate",
    "RE4M_TimeUpdate",
    "RE4M_ComboPopup",
    "RE4M_KillFeed",
    "RE4M_PickupCollected",
    "RE4M_TimeExtend",
    "RE4M_PlayerReady",
    "RE4M_SyncMusic",
    "RE4M_ForceMenu",
    "RE4M_AdminPanel",
    "RE4M_NavmeshWarning",
    "RE4M_ThemeInfo",
    "RE4M_AllScores",
    "RE4M_DamageNumber",
    "RE4M_EnemyKilled",
    "RE4M_EliteSpawned",
    "RE4M_EchoTeamMessage",
    -- Local TFA-VOX pack assignment for the player model selector.
    "RE4M_AssignTFA_VOX",
    "lf_playermodel_voxlist",
    "RE4M_RequestProgression",
    "RE4M_LobbyProgression",
    "RE4M_BuySkill",
    "RE4M_ToggleSkill",
    "RE4M_SetEquippedSkills",
    "RE4M_SkillShopResult",
    "RE4M_RequestCustomNPCs",
    "RE4M_CustomNPCList",
    "RE4M_PerfectDodge",
    "RE4M_PlayerHit",
}

-- Mercenary perks inspired by RE6's skills list, adapted to systems this mode
-- actually has. Costs use Merc Points; each player can equip at most three.
RE4M_SKILLS = {
    { id = "eagle_eye", name = "Eagle Eye", cost = 8, description = "Sniper rifles deal 15% more damage.", effect = "sniper" },
    { id = "item_drop", name = "Item Drop Increase", cost = 15, description = "Increases enemy pickup drop chance by 50%.", effect = "drop" },
    { id = "go_for_broke", name = "Go For Broke!", cost = 18, description = "When 30 seconds or less remain, combo chains last 2 seconds longer.", effect = "combo_window" },
    { id = "blitz_play", name = "Blitz Play", cost = 8, description = "Deal 15% more damage after a teammate recently damaged the same enemy.", effect = "blitz" },
    { id = "quick_shot", name = "Quick Shot Damage Increase", cost = 12, description = "Deal 10% more firearm damage.", effect = "quick_shot" },
    { id = "power_counter", name = "Power Counter", cost = 10, description = "Deal 25% more melee damage to parryable enemies during their attacks.", effect = "counter" },
    { id = "second_wind", name = "Second Wind", cost = 8, description = "Deal 20% more damage below 30% health.", effect = "low_health" },
    { id = "martial_arts", name = "Martial Arts Master", cost = 15, description = "Deal 25% more melee damage and 10% less firearm damage.", effect = "melee_master" },
    { id = "target_master", name = "Target Master", cost = 15, description = "Deal 15% more firearm damage and 10% less melee damage.", effect = "firearm_master" },
    { id = "last_stand", name = "Last Stand", cost = 20, description = "Deal 20% more damage, but take 50% more damage.", effect = "last_stand" },
    { id = "preemptive_strike", name = "Preemptive Strike", cost = 10, description = "Deal 20% more damage when attacking an enemy from behind.", effect = "behind" },
    { id = "dying_breath", name = "Dying Breath", cost = 12, description = "Deal 25% more damage below 20% health.", effect = "dying" },
    { id = "pharmacist", name = "Pharmacist", cost = 12, description = "Health pickups restore 50% more health.", effect = "healing" },
    { id = "medic", name = "Medic", cost = 12, description = "Health pickups also heal nearby teammates for half their value.", effect = "medic" },
    { id = "first_responder", name = "First Responder", cost = 15, description = "Health pickups also restore 20 health to distant living teammates.", effect = "responder" },
    { id = "take_it_easy", name = "Take It Easy", cost = 15, description = "Natural healing is faster while standing still.", effect = "stationary_healing" },
    { id = "natural_healing", name = "Natural Healing", cost = 18, description = "Regenerate 1 health every 5 seconds while below maximum health.", effect = "regeneration" },
    { id = "time_bonus", name = "Time Bonus +", cost = 25, description = "Time pickups grant 50% more time.", effect = "time_pickup" },
    { id = "combo_bonus", name = "Combo Bonus +", cost = 20, description = "Combo milestone time bonuses are 25% larger.", effect = "combo_time" },
    { id = "limit_breaker", name = "Limit Breaker", cost = 20, description = "Earn 10% more kill score while your combo is above 50.", effect = "score" },
}
RE4M_SKILLS_BY_ID = {}
for _, skill in ipairs(RE4M_SKILLS) do RE4M_SKILLS_BY_ID[skill.id] = skill end

-- ============================================
-- CONFIG DEFAULTS + CONVARS
-- ============================================

RE4MERCS_CONFIG = RE4MERCS_CONFIG or {}

-- Round
RE4MERCS_CONFIG.BaseRoundTime        = 120
RE4MERCS_CONFIG.MaxRoundTime         = 600
RE4MERCS_CONFIG.PreRoundTime         = 10
RE4MERCS_CONFIG.PostRoundTime        = 15
RE4MERCS_CONFIG.TimeExtendOnKill     = 5
RE4MERCS_CONFIG.TimeExtendOnCombo10  = 15
RE4MERCS_CONFIG.TimeExtendOnCombo25  = 20
RE4MERCS_CONFIG.TimeExtendOnCombo50  = 30
RE4MERCS_CONFIG.TimeExtendOnCombo100 = 60

-- Spawning
RE4MERCS_CONFIG.MinSpawnDistance     = 800
RE4MERCS_CONFIG.MaxSpawnDistance     = 4000
RE4MERCS_CONFIG.SpawnInterval        = 5
RE4MERCS_CONFIG.BaseMaxNPCs          = 18
RE4MERCS_CONFIG.MaxNPCsPerPlayer     = 5
RE4MERCS_CONFIG.AbsoluteMaxNPCs      = 40

-- Floating text / HUD toggles
RE4MERCS_CONFIG.ShowDamageNumbers    = true
RE4MERCS_CONFIG.ShowKillScores       = true
RE4MERCS_CONFIG.ShowEnemyHealthBars  = true
RE4MERCS_CONFIG.ShowEliteAlerts      = true
RE4MERCS_CONFIG.MaxDamageNumbers     = 30
RE4MERCS_CONFIG.MaxKillScoreFloats   = 15
RE4MERCS_CONFIG.DamageNumberLifetime = 1.0
RE4MERCS_CONFIG.HeadshotNumberLifetime = 1.5
RE4MERCS_CONFIG.HealthBarMaxDistance = 2000

-- Scoring
RE4MERCS_CONFIG.BaseKillScore        = 500
RE4MERCS_CONFIG.HeadshotBonus        = 250
RE4MERCS_CONFIG.MeleeKillBonus       = 300
RE4MERCS_CONFIG.EliteKillBonus       = 750
RE4MERCS_CONFIG.ComboTimeout         = 8
RE4MERCS_CONFIG.ComboResetOnDamage   = true

-- Ammo
RE4MERCS_CONFIG.StartingPrimaryAmmo   = 90
RE4MERCS_CONFIG.StartingSecondaryAmmo = 30
RE4MERCS_CONFIG.FallbackPistolAmmo    = 60
RE4MERCS_CONFIG.FallbackSMGAmmo       = 90

-- Weapons
RE4MERCS_CONFIG.MaxWeaponSlots       = 3

-- Pickups
RE4MERCS_CONFIG.PickupDropChance     = 0.15
RE4MERCS_CONFIG.HealthPickupAmount   = 25
RE4MERCS_CONFIG.AmmoPickupMultiplier = 0.25
RE4MERCS_CONFIG.TimePickupAmount     = 10
RE4MERCS_CONFIG.PickupLifetime       = 20

-- Player
RE4MERCS_CONFIG.PlayerHealth         = 150
RE4MERCS_CONFIG.PlayerArmor          = 50
RE4MERCS_CONFIG.PlayerRunSpeed       = 300
RE4MERCS_CONFIG.PlayerWalkSpeed      = 200
RE4MERCS_CONFIG.RespawnEnabled       = false
RE4MERCS_CONFIG.FriendlyFire         = false
RE4MERCS_CONFIG.RollEnabled          = true
RE4MERCS_CONFIG.RollCooldown         = 0.8
RE4MERCS_CONFIG.RollIFrame           = 0.2
RE4MERCS_CONFIG.RollForwardDistance  = 220
RE4MERCS_CONFIG.RollSideDistance     = 165
RE4MERCS_CONFIG.RollBackDistance     = 145

-- Parry / counter / door kick. These need typed defaults here: without them
-- RE4MERCS_GetConfig() turned the ConVar value "0" into the number 0, which is
-- truthy in Lua, so "re4m_parry_enabled 0" never actually disabled parrying.
RE4MERCS_CONFIG.ParryEnabled         = true
RE4MERCS_CONFIG.ParryRange           = 120
RE4MERCS_CONFIG.ParryCooldown        = 0.9
RE4MERCS_CONFIG.ParryDuration        = 0.95
RE4MERCS_CONFIG.CounterEnabled       = true
RE4MERCS_CONFIG.CounterRange         = 120
RE4MERCS_CONFIG.CounterDamage        = 750
RE4MERCS_CONFIG.CounterDuration      = 1.2
RE4MERCS_CONFIG.DoorKickRange        = 100
RE4MERCS_CONFIG.RespawnDelay         = 5
RE4MERCS_CONFIG.BlockHUDAddons       = true

-- Music volumes / paths (paths stay as defaults; volumes are ConVars)
RE4MERCS_CONFIG.MenuMusic            = "ui/menu.ogg"
RE4MERCS_CONFIG.MenuMusicVolume      = 0.4
RE4MERCS_CONFIG.RoundMusicVolume     = 0.6
RE4MERCS_CONFIG.ResultsMusic         = "ui/results.ogg"
RE4MERCS_CONFIG.ResultsMusicVolume   = 0.5

-- Echo team
RE4MERCS_CONFIG.EchoTeamMessage1     = "This is BSAA Echo Team!\nA chopper is en route to your\nposition now!"
RE4MERCS_CONFIG.EchoTeamMessage2     = "You will have to hold out against\nall remaining hostile forces until we arrive!"
RE4MERCS_CONFIG.EchoTeamMessage3     = "You will be rewarded for\ndefeating numerous hostiles\nin a row!"
RE4MERCS_CONFIG.EchoTeamMessageDuration = 2.0

-- Debug
RE4MERCS_CONFIG.Debug                = false
RE4MERCS_CONFIG.DebugSpawns          = false
RE4MERCS_CONFIG.AllPlayersAdmin      = false

-- Tables (not ConVars – edit in this file if needed)
RE4MERCS_CONFIG.ComboMultipliers = {
    {1,   1.0},
    {10,  1.1},
    {25,  1.2},
    {50,  1.3},
    {70,  1.4},
    {100, 1.5},
}

RE4MERCS_CONFIG.Ranks = {
    {0,       "C",   Color(150, 150, 150)},
    {50000,   "B",   Color(100, 180, 255)},
    {100000,  "A",   Color(50, 255, 50)},
    {200000,  "S",   Color(255, 215, 0)},
    {500000,  "S+",  Color(255, 140, 0)},
    {1000000, "S++", Color(255, 50, 50)},
}

RE4MERCS_CONFIG.PickupWeights = {
    health = 35,
    ammo   = 40,
    time   = 25,
}

RE4MERCS_CONFIG.EliteThresholds = {
    {kills = 25,  maxElites = 1},
    {kills = 50,  maxElites = 2},
    {kills = 90,  maxElites = 3},
    {kills = 130, maxElites = 3},
}

-- Weapon bases we accept.
-- The whole Base inheritance chain is walked, so listing a root base is
-- enough: a weapon whose Base is "arccw_gun" (which itself derives from
-- "arccw_base") is still matched.
RE4MERCS_CONFIG.AllowedBases = {
    -- ARC9
    "arc9_base",
    -- ARCCW
    "arccw_base", "arccw_gun", "arccw_base_melee",
    -- TacRP
    "tacrp_base", "tacrp_base_melee", "tacrp_base_giveitem", "tacrp_base_grenade",
    -- Modern Warfare Base (MWB)
    "mg_base", "mw_base", "mwb_base", "mg_base_melee", "mg_base_nade",
    -- ASTW2
    "astw2_base", "astw2_base_melee", "astw2_base_nade",
    -- TFA Base
    "tfa_gun_base", "tfa_bash_base", "tfa_melee_base", "tfa_base",
    -- Misc / legacy
    "weapon_base", "bobs_gun_base", "fas2_base", "m9k_base",
    "cw_base", "weapon_cs_base", "weapon_tttbase",
}

-- Class-name prefixes we accept. Matching is case-insensitive.
RE4MERCS_CONFIG.AllowedPrefixes = {
    "arc9_",                 -- ARC9
    "arccw_",                -- ARCCW
    "tacrp_",                -- TacRP
    "mg_", "mw_", "mwb_",    -- Modern Warfare Base
    "astw2_",                -- ASTW2
    "tfa_",                  -- TFA Base
    "cw_", "m9k_", "fas2_", "swep_", "weapon_",
}

-- Anything whose class STARTS WITH one of these is treated as a base SWEP
-- or internal template and hidden from the loadout menu. This is what stops
-- "ARCCW Base", "TacRP Base" etc. appearing as selectable guns.
RE4MERCS_CONFIG.BlacklistedPrefixes = {
    "arc9_base", "arccw_base", "tacrp_base", "astw2_base",
    "tfa_base", "mg_base", "mw_base", "mwb_base",
    "cw_base", "m9k_base", "fas2_base",
}

RE4MERCS_CONFIG.BlacklistedWeapons = {
    "weapon_physgun", "weapon_physcannon", "gmod_tool", "gmod_camera",
    "weapon_fists",
    "arc9_cod2019_base", "arc9_cod2019_base_nade",
    "arccw_gun", "tfa_gun_base", "weapon_base",
}

-- Most weapon bases flag themselves Spawnable = false while real weapons
-- are Spawnable = true. Leaving this on filters out base/template SWEPs
-- automatically. Turn it off if one of your packs deliberately hides its
-- weapons from the spawnmenu and you still want them selectable.
RE4MERCS_CONFIG.HideNonSpawnable = true

RE4MERCS_CONFIG.DefaultTheme = "default"
RE4MERCS_CONFIG.EnabledThemes = { "default", "halflife", "re5", "custom" }

RE4MERCS_CONFIG.ThemeNPCs = {
    default = {
        regular = { "npc_zombie", "npc_fastzombie", "npc_poisonzombie" },
        elite   = { "npc_fastzombie", "npc_poisonzombie" },
        re4_regular = { "drg_roach_re4_ganado", "drg_roach_re4_novistador", "drg_roach_re4_dog" },
        re4_elite   = { "drg_roach_re4_ganado_drs", "drg_roach_re4_garrador", "drg_roach_re4_brute", "drg_roach_re4_regenerador" },
    },
    halflife = {
        regular = { "npc_zombie", "npc_fastzombie", "npc_antlion", "npc_antlion_worker" },
        elite   = { "npc_antlionguard", "npc_fastzombie", "npc_zombine", "npc_antlionguardian" },
    },
    re5 = {
        regular = { "drg_roach_re5_amjn2", "drg_roach_re5_amjn0" },
        elite   = { "drg_roach_re5_executioner", "drg_roach_re5_csawmjn", "drg_roach_re5_mgmjn", "drg_roach_re5_amjn1" },
    },
    custom = {
        regular = { "npc_combine_s", "npc_metropolice", "ShotgunSoldier", "npc_manhack" },
        elite   = { "npc_hunter", "CombineElite" },
    },
}

RE4MERCS_CONFIG.RoundMusic = {
    "re4mercs/EvilEye.ogg",
    "re4mercs/HeatOnBeat.ogg",
    "re4mercs/RideonSea.ogg",
    "re4mercs/ThePressureIsOn.ogg",
    "re4mercs/bgm001.ogg",
}

RE4MERCS_CONFIG.HUDColors = {
    background   = Color(0, 0, 0, 180),
    primary      = Color(255, 60, 60),
    secondary    = Color(255, 200, 50),
    text         = Color(255, 255, 255),
    comboNormal  = Color(255, 255, 255),
    comboHigh    = Color(255, 215, 0),
    comboMax     = Color(255, 50, 50),
    timerNormal  = Color(255, 255, 255),
    timerLow     = Color(255, 50, 50),
    health       = Color(50, 255, 50),
    healthLow    = Color(255, 50, 50),
}

-- Create ConVars (server creates, FCVAR_REPLICATED so clients see them)
local RE4M_CVAR_MAP = {
    -- Round
    {"re4m_baseroundtime",        "BaseRoundTime",        "120", "Base round duration (seconds)"},
    {"re4m_maxroundtime",         "MaxRoundTime",         "600", "Max round time with extensions"},
    {"re4m_preroundtime",         "PreRoundTime",         "10",  "Pre-round countdown"},
    {"re4m_postroundtime",        "PostRoundTime",        "15",  "Results screen duration"},
    {"re4m_timeextendonkill",     "TimeExtendOnKill",     "5",   "Seconds added per kill"},
    {"re4m_timeextendoncombo10",  "TimeExtendOnCombo10",  "15",  "Bonus at 10 combo"},
    {"re4m_timeextendoncombo25",  "TimeExtendOnCombo25",  "20",  "Bonus at 25 combo"},
    {"re4m_timeextendoncombo50",  "TimeExtendOnCombo50",  "30",  "Bonus at 50 combo"},
    {"re4m_timeextendoncombo100", "TimeExtendOnCombo100", "60",  "Bonus at 100 combo"},

    -- Spawning
    {"re4m_minspawndistance",     "MinSpawnDistance",     "800", "Min distance from players to spawn"},
    {"re4m_maxspawndistance",     "MaxSpawnDistance",     "4000","Max spawn distance"},
    {"re4m_spawninterval",        "SpawnInterval",        "5",   "Seconds between NPC spawns"},
    {"re4m_basemaxnpcs",          "BaseMaxNPCs",          "18",  "Base max NPCs (1 player)"},
    {"re4m_maxnpcsperplayer",     "MaxNPCsPerPlayer",     "5",   "Extra max NPCs per extra player"},
    {"re4m_absolutemaxnpcs",      "AbsoluteMaxNPCs",      "40",  "Hard NPC cap"},

    -- Floating text
    {"re4m_showdamagenumbers",    "ShowDamageNumbers",    "1",   "Show floating damage numbers"},
    {"re4m_showkillscores",       "ShowKillScores",       "1",   "Show floating kill scores"},
    {"re4m_showenemyhealthbars",  "ShowEnemyHealthBars",  "1",   "Show enemy health bars"},
    {"re4m_showelitealerts",      "ShowEliteAlerts",      "1",   "Show elite spawn alerts"},
    {"re4m_maxdamagenumbers",     "MaxDamageNumbers",     "30",  "Max floating damage numbers"},
    {"re4m_maxkillscorefloats",   "MaxKillScoreFloats",   "15",  "Max kill score floats"},
    {"re4m_damagenumberlifetime", "DamageNumberLifetime", "1.0", "Damage number lifetime"},
    {"re4m_headshotnumberlifetime","HeadshotNumberLifetime","1.5","Headshot number lifetime"},
    {"re4m_healthbarmaxdistance", "HealthBarMaxDistance", "2000","Health bar max draw distance"},

    -- Scoring
    {"re4m_basekillscore",        "BaseKillScore",        "500", "Base points per kill"},
    {"re4m_headshotbonus",        "HeadshotBonus",        "250", "Headshot bonus points"},
    {"re4m_meleekillbonus",       "MeleeKillBonus",       "300", "Melee kill bonus"},
    {"re4m_elitekillbonus",       "EliteKillBonus",       "750", "Elite kill bonus"},
    {"re4m_combotimeout",         "ComboTimeout",         "8",   "Combo reset timeout (seconds)"},
    {"re4m_comboresetondamage",   "ComboResetOnDamage",   "1",   "Reset combo on damage taken"},

    -- Ammo
    {"re4m_startingprimaryammo",  "StartingPrimaryAmmo",  "90",  "Starting primary ammo"},
    {"re4m_startingsecondaryammo","StartingSecondaryAmmo","30",  "Starting secondary ammo"},
    {"re4m_fallbackpistolammo",   "FallbackPistolAmmo",   "60",  "Fallback pistol ammo"},
    {"re4m_fallbacksmgammo",      "FallbackSMGAmmo",      "90",  "Fallback SMG ammo"},

    -- Weapons
    {"re4m_maxweaponslots",       "MaxWeaponSlots",       "3",   "Max weapons in loadout"},

    -- Pickups
    {"re4m_pickupdropchance",     "PickupDropChance",     "0.15","Chance of pickup on kill"},
    {"re4m_healthpickupamount",   "HealthPickupAmount",   "25",  "Health restored by herb"},
    {"re4m_ammopickupmultiplier", "AmmoPickupMultiplier", "0.25","Fraction of max ammo given"},
    {"re4m_timepickupamount",     "TimePickupAmount",     "10",  "Seconds from time pickup"},
    {"re4m_pickuplifetime",       "PickupLifetime",       "20",  "Seconds before pickup despawns"},

    -- Player
    {"re4m_playerhealth",         "PlayerHealth",         "150", "Starting health"},
    {"re4m_playerarmor",          "PlayerArmor",          "50",  "Starting armor"},
    {"re4m_playerrunspeed",       "PlayerRunSpeed",       "300", "Run speed"},
    {"re4m_playerwalkspeed",      "PlayerWalkSpeed",      "200", "Walk speed"},
    {"re4m_respawnenabled",       "RespawnEnabled",       "0",   "Allow respawns during round"},
    {"re4m_friendlyfire",         "FriendlyFire",         "0",   "Enable friendly fire"},
    {"re4m_respawndelay",         "RespawnDelay",         "5",   "Seconds before a dead player may respawn (when respawns are enabled)"},

    -- Other addons
    {"re4m_blockhudaddons",       "BlockHUDAddons",       "1",   "Disable other addons' HUDs while playing this gamemode"},

    -- Music volumes
    {"re4m_menumusicvolume",      "MenuMusicVolume",      "0.4", "Menu music volume"},
    {"re4m_roundmusicvolume",     "RoundMusicVolume",     "0.6", "Round music volume"},
    {"re4m_resultsmusicvolume",   "ResultsMusicVolume",   "0.5", "Results music volume"},

    -- Echo
    {"re4m_echoteammessageduration","EchoTeamMessageDuration","2.0","Seconds each echo message shows"},

    -- Debug
    {"re4m_debug",                "Debug",                "0",   "Enable debug prints"},
    {"re4m_debugspawns",          "DebugSpawns",          "0",   "Show spawn debug"},
    {"re4m_allplayersadmin",      "AllPlayersAdmin",      "0",   "Everyone is admin (testing)"},

    -- Parry
    {"re4m_parry_enabled",  "ParryEnabled",  "1",   "Enable USE-key parry against attacking DrG nextbots"},
    {"re4m_parry_range",    "ParryRange",    "120", "Max distance to parry"},
    {"re4m_parry_cooldown", "ParryCooldown", "0.9", "Cooldown between parries"},
    {"re4m_parry_duration", "ParryDuration", "0.95","How long the riposte animation locks"},
    {"re4m_counter_enabled", "CounterEnabled", "1", "Enable counter attacks against stunned enemies"},
    {"re4m_counter_range", "CounterRange", "120", "Max distance to counter a stunned enemy"},
    {"re4m_counter_damage", "CounterDamage", "750", "Damage dealt by a counter attack"},
    {"re4m_counter_duration", "CounterDuration", "1.2", "How long the counter animation locks"},
    {"re4m_door_kick_range", "DoorKickRange", "100", "Max distance to kick open a map door"},

    -- Combat roll / evade
    {"re4m_roll_enabled", "RollEnabled", "1", "Enable the jump-key combat roll"},
    {"re4m_roll_cooldown", "RollCooldown", "0.8", "Delay between combat rolls"},
    {"re4m_roll_iframe", "RollIFrame", "0.2", "Roll invulnerability window in seconds"},
    {"re4m_roll_forward_distance", "RollForwardDistance", "220", "Forward roll travel distance"},
    {"re4m_roll_side_distance", "RollSideDistance", "165", "Side roll travel distance"},
    {"re4m_roll_back_distance", "RollBackDistance", "145", "Backstep travel distance"},
}

-- Replicated ConVars must be created in BOTH realms. When only the server
-- created them, GetConVar() returned nil on clients, so every client-side
-- RE4MERCS_GetConfig() call silently fell back to the defaults above and
-- server settings (HUD toggles, parry/counter ranges, slot count...) never
-- reached the client.
do
    local sharedCVarFlags = SERVER and bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY)
        or FCVAR_REPLICATED
    for _, data in ipairs(RE4M_CVAR_MAP) do
        if not ConVarExists(data[1]) then
            CreateConVar(data[1], data[3], sharedCVarFlags, data[4])
        end
    end
end

-- Much of the code checks RE4MERCS_CONFIG.Debug / DebugSpawns directly, so
-- keep those fields mirrored from their ConVars.
local function RE4M_SyncDebugFlags()
    local debugCVar = GetConVar("re4m_debug")
    local spawnCVar = GetConVar("re4m_debugspawns")
    RE4MERCS_CONFIG.Debug = debugCVar and debugCVar:GetBool() or false
    RE4MERCS_CONFIG.DebugSpawns = spawnCVar and spawnCVar:GetBool() or false
end
RE4M_SyncDebugFlags()
cvars.AddChangeCallback("re4m_debug", RE4M_SyncDebugFlags, "RE4M_SyncDebug")
cvars.AddChangeCallback("re4m_debugspawns", RE4M_SyncDebugFlags, "RE4M_SyncDebugSpawns")

-- ============================================
-- PLAYERMODEL PERSISTENCE CONVARS (Client)
-- ============================================

if CLIENT then
    CreateClientConVar("re4m_playermodel", "", true, true, "Selected playermodel path")
    CreateClientConVar("re4m_playerskin", "0", true, true, "Selected skin index")
    CreateClientConVar("re4m_playerbodygroups", "", true, true, "Selected bodygroups as comma-separated values")
    CreateClientConVar("re4m_playercolor_r", "0.3", true, true, "Player color red")
    CreateClientConVar("re4m_playercolor_g", "1.0", true, true, "Player color green")
    CreateClientConVar("re4m_playercolor_b", "0.8", true, true, "Player color blue")
    CreateClientConVar("re4m_loadout", "", true, false, "Saved loadout weapon classes, comma-separated")
end

-- ============================================
-- PLAYERMODEL UTILITY FUNCTIONS
-- ============================================

function RE4M_GetHandsForModel(modelPath)
    if not modelPath or modelPath == "" then
        return {
            model = "models/weapons/c_arms_citizen.mdl",
            skin  = 0,
            body  = "0000000",
        }
    end

    local simpleModel = player_manager.TranslateToPlayerModelName(modelPath)

    if simpleModel and simpleModel ~= "" then
        local info = player_manager.TranslatePlayerHands(simpleModel)
        if info and info.model and info.model ~= "" then
            return {
                model = info.model,
                skin  = info.skin or 0,
                body  = info.body or "0000000",
            }
        end
    end

    local knownHands = {
        ["models/player/alyx.mdl"]               = {model = "models/weapons/c_arms_citizen.mdl", skin = 0, body = "0000000"},
        ["models/player/barney.mdl"]              = {model = "models/weapons/c_arms_citizen.mdl", skin = 0, body = "0000000"},
        ["models/player/breen.mdl"]               = {model = "models/weapons/c_arms_citizen.mdl", skin = 0, body = "0000000"},
        ["models/player/eli.mdl"]                 = {model = "models/weapons/c_arms_citizen.mdl", skin = 0, body = "0000000"},
        ["models/player/gman_high.mdl"]           = {model = "models/weapons/c_arms_citizen.mdl", skin = 0, body = "0000000"},
        ["models/player/kleiner.mdl"]             = {model = "models/weapons/c_arms_citizen.mdl", skin = 0, body = "0000000"},
        ["models/player/monk.mdl"]                = {model = "models/weapons/c_arms_citizen.mdl", skin = 0, body = "0000000"},
        ["models/player/mossman.mdl"]             = {model = "models/weapons/c_arms_citizen.mdl", skin = 0, body = "0000000"},
        ["models/player/police.mdl"]              = {model = "models/weapons/c_arms_combine_soldier.mdl", skin = 0, body = "0000000"},
        ["models/player/combine_soldier.mdl"]     = {model = "models/weapons/c_arms_combine_soldier.mdl", skin = 0, body = "0000000"},
        ["models/player/combine_soldier_prisonguard.mdl"] = {model = "models/weapons/c_arms_combine_soldier.mdl", skin = 0, body = "0000000"},
        ["models/player/combine_super_soldier.mdl"] = {model = "models/weapons/c_arms_combine_soldier.mdl", skin = 0, body = "0000000"},
    }

    local lower = string.lower(modelPath)
    if knownHands[lower] then
        return knownHands[lower]
    end

    local dir = string.GetPathFromFilename(lower)
    local name = string.StripExtension(string.GetFileFromFilename(lower))

    local searchPaths = {
        dir .. name .. "_arms.mdl",
        dir .. "c_arms_" .. name .. ".mdl",
        dir .. "c_hands.mdl",
        dir .. "arms.mdl",
        dir .. "v_arms.mdl",
        string.Replace(lower, "/player/", "/weapons/c_arms_") ,
    }

    for _, sp in ipairs(searchPaths) do
        if util.IsValidModel(sp) then
            return {
                model = sp,
                skin  = 0,
                body  = "0000000",
            }
        end
    end

    -- Counter-Strike player models are named ct_*.mdl / t_*.mdl. The old
    -- substring test for "t_" matched almost any path ("urban_t_", "art_"...).
    if string.StartWith(name, "ct_") or string.StartWith(name, "t_") then
        return {
            model = "models/weapons/c_arms_cstrike.mdl",
            skin  = 0,
            body  = "0000000",
        }
    end

    return {
        model = "models/weapons/c_arms_citizen.mdl",
        skin  = 0,
        body  = "0000000",
    }
end

function RE4M_ParseBodygroups(str)
    if not str or str == "" then return {} end
    local result = {}
    for v in string.gmatch(str, "([^,]+)") do
        table.insert(result, tonumber(v) or 0)
    end
    return result
end

function RE4M_BodygroupsToString(tbl)
    if not tbl or #tbl == 0 then return "" end
    local strs = {}
    for _, v in ipairs(tbl) do
        table.insert(strs, tostring(v))
    end
    return table.concat(strs, ",")
end

-- ============================================
-- SHARED TABLES
-- ============================================

RE4MERCS_WEAPON_CATEGORIES = {
    "Assault Rifles",
    "Submachine Guns",
    "Shotguns",
    "Sniper Rifles",
    "Pistols",
    "Machine Guns",
    "Melee",
    "Explosives",
    "Other",
}

RE4MERCS_CATEGORY_KEYWORDS = {
    -- Recognize weapon designations commonly used as class names / print
    -- names by CoD, EFT, ARC9, TFA, and similar realistic weapon packs.
    ["Assault Rifles"]  = {
        "assault rifle", "assault_rifle", "ar15", "ar-15", "ar-10", "carbine", "battle rifle",
        "ak47", "ak-47", "ak74", "ak-74", "akm", "ak12", "ak-12", "aks74", "aks-74",
        "m4a1", "m4a4", "m16", "mk18", "hk416", "hk417", "scar", "fn fal", "f2000",
        "aug", "famas", "galil", "g36", "qbz", "sig 55", "sig mcx", "acr", "kilo 141",
        "ram-7", "cr-56", "as val", "groza", "an-94", "m13", "m13b", "kastov", "taq-56",
        "m762", "beryl", "ace 32", "g36c", "l85", "sa80", "g3a3", "hk g3", "vhs-2",
    },
    ["Submachine Guns"] = {
        "smg", "submachine", "mp5", "mp7", "mp9", "mp40", "mp5k", "p90", "ump", "ump45",
        "mac10", "mac-10", "mac11", "uzi", "vector", "kriss", "thompson", "pp19", "pp-19",
        "ppsh", "pp-19", "bizon", "m3 grease", "sten", "sterling", "scorpion evo", "akimbo smg",
        "fennec", "lachmann sub", "iso 45", "hrm-9", "striker 9", "rival-9", "vel 46",
        "mx9", "lc10", "milano", "bullfrog", "ots 9", "ksp 45", "tec-9", "p10 roni",
    },
    ["Shotguns"]        = {
        "shotgun", "pump action", "pump_shotgun", "auto_shotgun", "benelli", "mossberg", "remington",
        "spas", "striker", "saiga", "nova", "sawn", "m1014", "m590", "m870", "870 breacher",
        "aa-12", "aa12", "ks-23", "ks23", "db shotgun", "double barrel", "super 90", "vepr-12",
        "r9-0", "725", "lockwood 300", "expedite 12", "kv broadside", "haymaker", "reclaimer 18",
    },
    ["Sniper Rifles"]   = {
        "sniper", "awp", "scout", "marksman", "dmr", "svd", "bolt action", "barrett", "intervention",
        "kar98", "kar-98", "mosin", "m24", "m40a", "remington 700", "r700", "sv-98", "sv98",
        "dragunov", "vss vintorez", "vpo-215", "m700", "m82", "m107", "ax-50", "hdr", "lynx",
        "mcpr-300", "victus xmr", "fJx imperium", "signal 50", "la-b 330", "sp-x 80", "tundra",
        "pelington", "lw3", "swiss k31", "zrg 20mm", "dmr rifle", "marksman rifle", "sr-25", "m110",
    },
    ["Pistols"]         = {
        "pistol", "handgun", "revolver", "deagle", "desert eagle", "glock", "beretta", "1911", "usp",
        "p226", "magnum", "fiveseven", "five-seven", "five seven", "m9a3", "m9 beretta", "m17", "m18",
        "p320", "p250", "fnx-45", "fn 57", "five-seven", "walther", "makarov", "pm pistol", "tt-33",
        "tokarev", "cz75", "cz-75", "cz p-", "glock 17", "glock 18", "glock 19", "glock 21", "glock 26",
        "usp-s", "p2000", "p30", "mk23", "soc om", "r8 revolver", "python", "judge", "shorty",
    },
    ["Machine Guns"]    = {
        "lmg", "machine gun", "machine_gun", "machinegun", "m249", "m240", "m60", "minigun", "rpd",
        "pkm", "pkp", "mg42", "mg3", "mg34", "m1919", "m27 iar", "m250", "pkm", "rpk", "rpk-16",
        "sa-58 lmg", "bruen mk9", "holger 26", "dg-58 lsw", "taq eradicator", "pulemyot", "kastov lsw",
    },
    ["Melee"]           = {
        "melee", "knife", "sword", "bat", "crowbar", "axe", "machete", "fists", "katana", "hatchet",
        "bayonet", "combat knife", "karambit", "kukri", "tomahawk", "tactical knife", "combat axe",
    },
    ["Explosives"]      = {
        "grenade", "rpg", "launcher", "explosive", "c4", "mine", "rocket", "bazooka", "panzerfaust",
        "m79", "m203", "gp-25", "gl40", "underbarrel grenade", "javelin", "stinger", "at4", "rpg-7",
        "rpg7", "rpg-26", "rpg26", "rpg-18", "rpg18", "m32 grenade", "crossbow", "grenade launcher",
    },
}

-- Categories are tested in THIS order. pairs() has no guaranteed order, which
-- previously made a weapon land in a different category run to run. Specific
-- categories are checked before broad ones ("Shotguns" before "Assault
-- Rifles", so "auto shotgun rifle" isn't mislabelled).
RE4MERCS_CATEGORY_ORDER = {
    "Melee",
    "Explosives",
    "Shotguns",
    "Sniper Rifles",
    "Machine Guns",
    "Submachine Guns",
    "Pistols",
    "Assault Rifles",
}

-- Keep the user-facing weapon browser and the lobby animation mapping on
-- these same canonical names.
RE4MERCS_CATEGORY_ALIASES = {
    ["Assault Rifles"] = {"Assault Rifles", "AssaultRifle", "Rifle"},
    ["Submachine Guns"] = {"Submachine Guns", "SubmachineGun", "SMG"},
    ["Shotguns"] = {"Shotguns", "Shotgun"},
    ["Sniper Rifles"] = {"Sniper Rifles", "Sniper"},
    ["Machine Guns"] = {"Machine Guns", "MachineGun", "LMG"},
    ["Pistols"] = {"Pistols", "Pistol", "Sidearm"},
    ["Melee"] = {"Melee", "Knife"},
    ["Explosives"] = {"Explosives", "Grenade"},
}

-- ============================================
-- PARRY ANIMATION SYSTEM (wOS)
-- ============================================

local PLAYER = FindMetaTable("Player")

function PLAYER:RE4M_IsParrying()
    return self:GetNW2Float("RE4M_ParryTime", 0) >= CurTime()
end

function PLAYER:RE4M_GetParryTime()
    return self:GetNW2Float("RE4M_ParryTime", 0)
end

RE4M_COUNTER_ANIMATIONS = {
    { sequence = "wos_re4m_counter_01", activity = "ACT_RE4M_COUNTER_ATTACK_01", activityID = 2045, frames = 106, fps = 120 },
    { sequence = "wos_re4m_counter_02", activity = "ACT_RE4M_COUNTER_ATTACK_02", activityID = 2046, frames = 98, fps = 120 },
    { sequence = "wos_re4m_counter_03", activity = "ACT_RE4M_COUNTER_ATTACK_03", activityID = 2047, frames = 92, fps = 120 },
}

function RE4M_AmmoDisplayLabel(ammoName)
    local normalized = string.lower(tostring(ammoName or ""))
    local labels = {
        pistol = "9MM ROUNDS",
        pistol_ammo = "9MM ROUNDS",
        smg1 = "SMG ROUNDS",
        smg = "SMG ROUNDS",
        buckshot = "12 GAUGE SHELLS",
        shotgun = "12 GAUGE SHELLS",
        ar2 = "5.56MM ROUNDS",
        sniperround = "SNIPER ROUNDS",
        sniperpenetratedround = "SNIPER ROUNDS",
        revolver = ".357 ROUNDS",
        ["357"] = ".357 ROUNDS",
        rpg_round = "RPG ROCKETS",
        grenade = "GRENADES",
    }
    if labels[normalized] then return labels[normalized] end
    normalized = string.Trim(string.gsub(normalized, "_", " "))
    return normalized == "" and "AMMO" or string.upper(normalized) .. " ROUNDS"
end

local COUNTER_STUN_SEQUENCES = {
    -- NPCs use flinch1-flinch9 for bullet reactions, including headshot
    -- staggers. The active flinch sequence itself defines the counter window.
    "flinch",
    "flinch3",
    "flinch_stagger",
    "flinch_blast",
    "flinch5",
    "flinch_block",
    "flinch_stagger2",
    "physflinch",
}

function RE4M_IsCounterStunned(ent)
    if not IsValid(ent) or not ent.GetSequenceName then return false end
    local sequenceName = string.lower(ent:GetSequenceName(ent:GetSequence()) or "")
    for _, baseName in ipairs(COUNTER_STUN_SEQUENCES) do
        if sequenceName == baseName or
           string.StartWith(sequenceName, baseName .. "_") or
           string.match(sequenceName, "^" .. baseName .. "%d+$") then
            return true
        end
    end
    return false
end

function PLAYER:RE4M_IsCountering()
    return self:GetNW2Float("RE4M_CounterTime", 0) >= CurTime()
end

function PLAYER:RE4M_IsKickingDoor()
    return self:GetNW2Float("RE4M_DoorKickTime", 0) >= CurTime()
end

local function RE4M_GetActionSequence(ply)
    if not IsValid(ply) then return end
    if ply:GetNW2Float("RE4M_RollEndTime", 0) > CurTime() then
        return ply:GetNW2String("RE4M_RollSequence", "")
    end
    if ply:RE4M_IsCountering() then return ply:GetNW2String("RE4M_CounterSequence", "") end
    if ply:RE4M_IsKickingDoor() then return "wos_re4m_counter_02" end
    if ply:RE4M_IsParrying() then return "b_block_forward_riposte" end
end

-- Clear callbacks left behind by the earlier global gamemode override, and
-- old per-action hook IDs when Lua auto-refreshes this file.
GM.CalcMainActivity = nil
GM.UpdateAnimation = nil
hook.Remove("CalcMainActivity", "RE4M_CounterAnimation")
hook.Remove("CalcMainActivity", "RE4M_DoorKickAnimation")
hook.Remove("CalcMainActivity", "RE4M_ParryAnimation")
hook.Remove("UpdateAnimation", "RE4M_CounterPlayback")
hook.Remove("UpdateAnimation", "RE4M_DoorKickPlayback")
hook.Remove("UpdateAnimation", "RE4M_ParryPlayback")

-- One action hook avoids conflicting sequence returns; idle animation is
-- left to the base gamemode and other animation addons.
hook.Add("CalcMainActivity", "RE4M_ActionAnimation", function(ply)
    local sequenceName = RE4M_GetActionSequence(ply)
    if not sequenceName or sequenceName == "" then return end
    local sequenceID = ply:LookupSequence(sequenceName)
    if not sequenceID or sequenceID < 0 then return end
    return -1, sequenceID
end)

hook.Add("UpdateAnimation", "RE4M_ActionAnimationPlayback", function(ply)
    if not IsValid(ply) then return end
    if ply:GetNW2Float("RE4M_RollEndTime", 0) > CurTime() then
        ply:SetPlaybackRate(1)
        return true
    end
    if ply:RE4M_IsCountering() or ply:RE4M_IsKickingDoor() then
        local sequenceDuration = ply:SequenceDuration(ply:GetSequence())
        local requestedDuration = ply:GetNW2Float("RE4M_CounterAnimDuration", 0)
        local rate = sequenceDuration > 0 and requestedDuration > 0 and
            math.Clamp(sequenceDuration / requestedDuration, 0.05, 8) or 1
        ply:SetPlaybackRate(rate)
        return true
    end
    if ply:RE4M_IsParrying() then
        ply:SetPlaybackRate(1)
        return true
    end
end)

-- ============================================
-- COMBAT ROLL MOVEMENT (shared so it is predicted)
-- ============================================
-- This used to run only on the server, so the client predicted a standing
-- player while the server moved them, which rubber-banded every roll.

hook.Add("SetupMove", "RE4M_CombatRollLockMovement", function(ply, mv)
    if ply:GetNW2Float("RE4M_RollEndTime", 0) <= CurTime() then return end
    mv:SetForwardSpeed(0)
    mv:SetSideSpeed(0)
    mv:SetUpSpeed(0)
    mv:SetMaxClientSpeed(0)
end)

hook.Add("Move", "RE4M_CombatRollMovement", function(ply, mv)
    local startTime = ply:GetNW2Float("RE4M_RollStartTime", 0)
    local endTime = ply:GetNW2Float("RE4M_RollEndTime", 0)
    if endTime <= CurTime() or endTime <= startTime then return end
    local direction = ply:GetNW2Vector("RE4M_RollDirection", vector_origin)
    if direction:LengthSqr() < 0.5 then return end
    direction = Vector(direction.x, direction.y, 0)
    direction:Normalize()
    local duration = endTime - startTime
    local distance = ply:GetNW2Float("RE4M_RollDistance", 220)
    local velocity = mv:GetVelocity()
    mv:SetVelocity(Vector(direction.x * distance / duration, direction.y * distance / duration, velocity.z))
end)

-- Players pass through each other (see GM:ShouldCollide). ShouldCollide is
-- only consulted for entities flagged with SetCustomCollisionCheck.
hook.Add(SERVER and "PlayerSpawn" or "NetworkEntityCreated", "RE4M_PlayerCustomCollision", function(ent)
    if IsValid(ent) and ent:IsPlayer() then
        ent:SetCustomCollisionCheck(true)
        ent:CollisionRulesChanged()
    end
end)

-- ============================================
-- SHARED UTILITY FUNCTIONS
-- ============================================

--- Returns live config (defaults + current ConVar values)
function RE4MERCS_GetConfig()
    local cfg = {}
    for k, v in pairs(RE4MERCS_CONFIG) do
        cfg[k] = v
    end

    -- Override with live ConVar values
    for _, data in ipairs(RE4M_CVAR_MAP) do
        local cvar = GetConVar(data[1])
        if cvar then
            local key = data[2]
            local val = cvar:GetString()
            -- Preserve the default type: boolean ConVars must not become
            -- numeric 0/1, because zero is truthy in Lua.
            if type(RE4MERCS_CONFIG[key]) == "boolean" then
                cfg[key] = val == "1" or val == "true"
            else
                local num = tonumber(val)
                cfg[key] = num ~= nil and num or val
            end
        end
    end

    return cfg
end

function RE4MERCS_GetComboMultiplier(combo)
    local cfg = RE4MERCS_GetConfig()
    local multipliers = cfg.ComboMultipliers or {{1, 1.0}}
    local mult = 1.0

    for _, data in ipairs(multipliers) do
        if combo >= data[1] then
            mult = data[2]
        end
    end

    return mult
end

function RE4MERCS_GetRank(score)
    local cfg = RE4MERCS_GetConfig()
    local ranks = cfg.Ranks or {{0, "C", Color(150,150,150)}}
    local rank = ranks[1]

    for _, data in ipairs(ranks) do
        if score >= data[1] then
            rank = data
        end
    end

    return rank[2], rank[3], rank[1]
end

function RE4MERCS_CategorizeWeapon(className, printName, swepTable)
    local searchStr = string.lower((className or "") .. " " .. (printName or ""))

    -- Some bases publish a useful spawnmenu category, e.g. "ARC9 - Shotguns".
    -- Fold it into the search string so it can help the match.
    if swepTable and isstring(swepTable.Category) then
        searchStr = searchStr .. " " .. string.lower(swepTable.Category)
    end

    -- Use explicit slot metadata where packs expose it. Numeric slot values
    -- are base-specific, so only interpret recognizable string labels.
    if swepTable then
        local slot = swepTable.Slot or swepTable.SlotName or swepTable.WeaponType
        if isstring(slot) then
            local slotName = string.lower(slot)
            if string.find(slotName, "shotgun", 1, true) then return "Shotguns" end
            if string.find(slotName, "sniper", 1, true) or string.find(slotName, "marksman", 1, true) then return "Sniper Rifles" end
            if string.find(slotName, "machine", 1, true) or string.find(slotName, "lmg", 1, true) then return "Machine Guns" end
            if string.find(slotName, "smg", 1, true) or string.find(slotName, "submachine", 1, true) then return "Submachine Guns" end
            if string.find(slotName, "pistol", 1, true) or string.find(slotName, "sidearm", 1, true) then return "Pistols" end
            if string.find(slotName, "melee", 1, true) then return "Melee" end
            if string.find(slotName, "launcher", 1, true) or string.find(slotName, "explosive", 1, true) then return "Explosives" end
            if string.find(slotName, "rifle", 1, true) or string.find(slotName, "assault", 1, true) then return "Assault Rifles" end
        end
    end

    -- Normalize punctuation to word boundaries so "m4_a1", "M4-A1", and
    -- "M4 A1" match consistently, without letting short names like "aug" or
    -- "scar" match inside unrelated words.
    local normalized = string.lower(searchStr)
    normalized = string.gsub(normalized, "[%p_]+", " ")
    normalized = string.gsub(normalized, "%s+", " ")
    normalized = " " .. normalized .. " "

    local order = RE4MERCS_CATEGORY_ORDER or {}

    for _, category in ipairs(order) do
        local keywords = RE4MERCS_CATEGORY_KEYWORDS[category]
        if keywords then
            for _, keyword in ipairs(keywords) do
                local normalizedKeyword = string.lower(keyword)
                normalizedKeyword = string.gsub(normalizedKeyword, "[%p_]+", " ")
                normalizedKeyword = string.gsub(normalizedKeyword, "%s+", " ")
                if string.find(normalized, " " .. normalizedKeyword .. " ", 1, true) then
                    return category
                end
            end
        end
    end

    return "Other"
end

--- Walk a weapon's Base chain and return a lookup table of every base in it.
--- Guards against loops and missing entries.
local function RE4MERCS_GetBaseChain(base)
    local chain, seen = {}, {}
    local current = base

    for _ = 1, 16 do
        if not current or current == "" or seen[current] then break end
        seen[current]  = true
        chain[current] = true

        local stored = weapons.GetStored(current)
        current = stored and stored.Base or nil
    end

    return chain
end

--- swepTable is optional but recommended: it lets us use Spawnable to
--- filter out base SWEPs, and it is what RE4M_BuildWeaponList passes in.
function RE4MERCS_IsWeaponAllowed(className, base, swepTable)
    local cfg = RE4MERCS_GetConfig()
    if not cfg then return false end
    if not className or className == "" then return false end

    base = base or ""
    local lowerClass = string.lower(className)

    -- 1) Exact-class blacklist
    for _, blocked in ipairs(cfg.BlacklistedWeapons or {}) do
        if lowerClass == string.lower(blocked) then return false end
    end

    -- 2) Blacklisted prefixes (base SWEPs / internal templates)
    for _, blocked in ipairs(cfg.BlacklistedPrefixes or {}) do
        blocked = string.lower(blocked)
        if string.sub(lowerClass, 1, #blocked) == blocked then return false end
    end

    -- 3) Base SWEPs are nearly always flagged Spawnable = false
    if cfg.HideNonSpawnable and swepTable and swepTable.Spawnable == false then
        return false
    end

    -- 4) Class-name prefix whitelist
    for _, prefix in ipairs(cfg.AllowedPrefixes or {}) do
        prefix = string.lower(prefix)
        if string.sub(lowerClass, 1, #prefix) == prefix then return true end
    end

    -- 5) Base whitelist, walking the FULL inheritance chain.
    --    The old code only compared the immediate Base, so any pack whose
    --    weapons derive from an intermediate base (very common in ARCCW,
    --    TacRP and MW Base) was silently dropped.
    local chain = RE4MERCS_GetBaseChain(base)
    for _, allowedBase in ipairs(cfg.AllowedBases or {}) do
        if chain[allowedBase] then return true end
    end

    return false
end

function RE4MERCS_FormatTime(seconds)
    seconds = math.max(0, math.floor(seconds))
    local mins = math.floor(seconds / 60)
    local secs = seconds % 60
    return string.format("%d:%02d", mins, secs)
end

function RE4MERCS_FormatScore(score)
    local formatted = tostring(math.floor(score))
    local k

    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end

    return formatted
end

-- ============================================
-- PLAYER META EXTENSIONS
-- ============================================
local PLAYER = FindMetaTable("Player")

function PLAYER:RE4M_GetScore()
    return self:GetNWInt("RE4M_Score", 0)
end

function PLAYER:RE4M_GetCombo()
    return self:GetNWInt("RE4M_Combo", 0)
end

function PLAYER:RE4M_GetMaxCombo()
    return self:GetNWInt("RE4M_MaxCombo", 0)
end

function PLAYER:RE4M_GetKills()
    return self:GetNWInt("RE4M_Kills", 0)
end

function PLAYER:RE4M_GetReady()
    return self:GetNWBool("RE4M_Ready", false)
end

function PLAYER:RE4M_IsAdmin()
    local cfg = RE4MERCS_GetConfig()
    if cfg.AllPlayersAdmin then return true end
    return self:IsAdmin() or self:IsSuperAdmin() or self:IsListenServerHost()
end

-- ============================================
-- SHARED HOOKS
-- ============================================

function GM:ShouldCollide(ent1, ent2)
    if IsValid(ent1) and IsValid(ent2) then
        if ent1:IsPlayer() and ent2:IsPlayer() then
            return false
        end
    end
    return true
end

function GM:PlayerShouldTakeDamage(ply, attacker)
    if RE4M_STATE and RE4M_STATE.GameState == GAMESTATE_ACTIVE then
        local now = CurTime()
        if ply:GetNW2Float("RE4M_ParryTime", 0) > now or
           ply:GetNW2Float("RE4M_CounterTime", 0) > now or
           ply:GetNW2Float("RE4M_DoorKickTime", 0) > now then
            return false
        end
    end

    local cfg = RE4MERCS_GetConfig()
    if not cfg.FriendlyFire and IsValid(attacker) and attacker:IsPlayer() and attacker ~= ply then
        return false
    end
    return true
end
