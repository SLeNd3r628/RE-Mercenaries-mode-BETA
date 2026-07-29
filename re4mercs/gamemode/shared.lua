-- RE4 Mercenaries Remake - Shared Code
-- Runs on both client and server

GM.Name    = "RE4 Mercenaries"
GM.Author  = "SLeNd3rMaN23"
GM.Email   = ""
GM.Website = ""
GM.Base    = "base"

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
    "RE4M_EchoTeamMessage"
}

-- ============================================
-- CONFIG DEFAULTS + CONVARS
-- All scalar/bool/string settings from the old
-- re4mercs_config.lua are now ConVars (re4m_*).
-- Tables stay hardcoded (editable only by code).
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

RE4MERCS_CONFIG.AllowedBases = {
    "arc9_base", "tfa_gun_base", "weapon_base", "bobs_gun_base",
    "fas2_base", "m9k_base", "cw_base",
}

RE4MERCS_CONFIG.AllowedPrefixes = {
    "arc9_", "tfa_", "weapon_", "m9k_", "cw_", "fas2_", "swep_",
}

RE4MERCS_CONFIG.BlacklistedWeapons = {
    "weapon_physgun", "weapon_physcannon", "gmod_tool", "gmod_camera",
    "weapon_fists", "arc9_cod2019_base", "arc9_cod2019_base_nade",
}

RE4MERCS_CONFIG.DefaultTheme = "default"
RE4MERCS_CONFIG.EnabledThemes = { "default", "halflife", "custom" }

RE4MERCS_CONFIG.ThemeNPCs = {
    default = {
        regular = { "npc_zombie", "npc_fastzombie", "npc_poisonzombie" },
        elite   = { "npc_fastzombie", "npc_poisonzombie" },
        re4_regular = { "drg_roach_re4_ganado", "drg_roach_re4_dog" },
        re4_elite   = { "drg_roach_re4_ganado_drs", "drg_roach_re4_garrador", "drg_roach_re4_brute" },
    },
    halflife = {
        regular = { "npc_zombie", "npc_fastzombie", "npc_antlion", "npc_antlion_worker" },
        elite   = { "npc_antlionguard", "npc_fastzombie", "npc_zombine", "npc_antlionguardian" },
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
}

if SERVER then
    for _, data in ipairs(RE4M_CVAR_MAP) do
        CreateConVar(data[1], data[3], {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY}, data[4])
    end
end

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

    if string.find(lower, "ct_") or string.find(lower, "t_") then
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
    ["Assault Rifles"]  = {"assault", "rifle", "ar15", "ar-15", "carbine", "ak", "m4", "m16", "scar"},
    ["Submachine Guns"] = {"smg", "submachine", "mp5", "mp7", "p90", "ump", "mac10", "uzi"},
    ["Shotguns"]        = {"shotgun", "pump", "auto_shotgun", "benelli", "mossberg", "remington", "spas"},
    ["Sniper Rifles"]   = {"sniper", "awp", "scout", "marksman", "dmr", "svd", "bolt"},
    ["Pistols"]         = {"pistol", "handgun", "revolver", "deagle", "glock", "beretta", "1911", "usp"},
    ["Machine Guns"]    = {"lmg", "machine_gun", "m249", "m60", "minigun", "mg"},
    ["Melee"]           = {"melee", "knife", "sword", "bat", "crowbar", "axe", "machete", "fists"},
    ["Explosives"]      = {"grenade", "rpg", "launcher", "explosive", "c4", "mine"},
}

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
            -- Try number first, then bool
            local num = tonumber(val)
            if num ~= nil then
                cfg[key] = num
            elseif val == "1" or val == "true" then
                cfg[key] = true
            elseif val == "0" or val == "false" then
                cfg[key] = false
            else
                cfg[key] = val
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

function RE4MERCS_CategorizeWeapon(className, printName)
    local searchStr = string.lower(className .. " " .. (printName or ""))

    for category, keywords in pairs(RE4MERCS_CATEGORY_KEYWORDS) do
        for _, keyword in ipairs(keywords) do
            if string.find(searchStr, keyword, 1, true) then
                return category
            end
        end
    end

    return "Other"
end

function RE4MERCS_IsWeaponAllowed(className, base)
    local cfg = RE4MERCS_GetConfig()
    base = base or ""

    local allowed = false

    if cfg.AllowedPrefixes then
        for _, prefix in ipairs(cfg.AllowedPrefixes) do
            if string.StartWith(className, prefix) then
                allowed = true
                break
            end
        end
    end

    if not allowed and cfg.AllowedBases then
        for _, allowedBase in ipairs(cfg.AllowedBases) do
            if base == allowedBase then
                allowed = true
                break
            end
        end
    end

    if allowed and cfg.BlacklistedWeapons then
        for _, blocked in ipairs(cfg.BlacklistedWeapons) do
            if className == blocked then
                allowed = false
                break
            end
        end
    end

    return allowed
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
    local cfg = RE4MERCS_GetConfig()
    if not cfg.FriendlyFire and IsValid(attacker) and attacker:IsPlayer() and attacker ~= ply then
        return false
    end
    return true
end