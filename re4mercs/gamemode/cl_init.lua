-- RE4 Mercenaries Remake - Client Init

include("shared.lua")
include("cl_hud.lua")
include("cl_menu.lua")
include("cl_music.lua")
include("cl_results.lua")

-- ============================================
-- CLIENT STATE
-- ============================================

RE4M_CLIENT = {
    GameState        = GAMESTATE_WAITING,
    Score            = 0,
    Combo            = 0,
    MaxCombo         = 0,
    Kills            = 0,
    Multiplier       = 1.0,
    RoundTimeLeft    = 0,
    WeaponList       = {},
    SelectedLoadout  = {},
    SelectedModel    = "",
    CurrentTheme     = "default",
    MenuOpen         = false,
    ResultsOpen      = false,
    KillFeed         = {},
    Popups           = {},
    PickupNotifs     = {},
    TimeExtendNotifs = {},
    HasNavmesh       = true,
    MusicTrack       = 0,
    MusicPlaying     = false,
    DamageNumbers    = {},
    KillScoreFloats  = {},
    EliteAlerts      = {},
    EchoTeam = {
        msg1 = "",
        msg2 = "",
        msg3 = "",
        duration = 2.0,
        startTime = 0,
    },
}

-- ============================================
-- FONTS
-- ============================================

local function CreateFonts()
    surface.CreateFont("RE4M_Title", {
        font = "Arial Black",
        size = 64,
        weight = 900,
        antialias = true,
    })

    surface.CreateFont("RE4M_Subtitle", {
        font = "Arial Black",
        size = 36,
        weight = 800,
        antialias = true,
    })

    surface.CreateFont("RE4M_Large", {
        font = "EuroStyle",
        size = 48,
        weight = 700,
        antialias = true,
    })

    surface.CreateFont("RE4M_Medium", {
        font = "EuroStyle",
        size = 28,
        weight = 600,
        antialias = true,
    })

    surface.CreateFont("RE4M_Small", {
        font = "EuroStyle",
        size = 20,
        weight = 500,
        antialias = true,
    })

    surface.CreateFont("RE4M_Tiny", {
        font = "EuroStyle",
        size = 14,
        weight = 400,
        antialias = true,
    })

    surface.CreateFont("RE4M_HUDScore", {
        font = "Arial Black",
        size = 42,
        weight = 900,
        antialias = true,
    })

    surface.CreateFont("RE4M_HUDCombo", {
        font = "Arial Black",
        size = 56,
        weight = 900,
        antialias = true,
    })

    surface.CreateFont("RE4M_HUDTimer", {
        font = "DS-Digital",
        size = 52,
        weight = 900,
        antialias = true,
    })

    surface.CreateFont("RE4M_Rank", {
        font = "Arial Black",
        size = 120,
        weight = 900,
        antialias = true,
    })

    surface.CreateFont("RE4M_KillFeed", {
        font = "EuroStyle",
        size = 22,
        weight = 600,
        antialias = true,
    })

    surface.CreateFont("RE4M_Popup", {
        font = "Arial Black",
        size = 40,
        weight = 800,
        antialias = true,
    })

    surface.CreateFont("RE4M_MenuItem", {
        font = "EuroStyle",
        size = 24,
        weight = 600,
        antialias = true,
    })

    surface.CreateFont("RE4M_MenuButton", {
        font = "Arial Black",
        size = 30,
        weight = 800,
        antialias = true,
    })
    
    surface.CreateFont("RE4M_DamageNumber", {
        font = "Arial Black",
        size = 24,
        weight = 800,
        antialias = true,
        outline = true,
    })

    surface.CreateFont("RE4M_DamageNumberLarge", {
        font = "Arial Black",
        size = 34,
        weight = 900,
        antialias = true,
        outline = true,
    })

    surface.CreateFont("RE4M_KillScore", {
        font = "Arial Black",
        size = 28,
        weight = 800,
        antialias = true,
        outline = true,
    })

    surface.CreateFont("RE4M_HealthBar", {
        font = "Arial",
        size = 12,
        weight = 600,
        antialias = true,
    })

    surface.CreateFont("RE4M_EliteAlert", {
        font = "Arial Black",
        size = 44,
        weight = 900,
        antialias = true,
    })

    surface.CreateFont("RE4M_EliteAlertSub", {
        font = "Arial",
        size = 22,
        weight = 600,
        antialias = true,
    })
end

hook.Add("InitPostEntity", "RE4M_CreateFonts", CreateFonts)
CreateFonts()

-- ============================================
-- NET RECEIVERS
-- ============================================

net.Receive("RE4M_GameState", function()
    local state = net.ReadUInt(4)
    RE4M_CLIENT.GameState = state

    if state == GAMESTATE_MENU or state == GAMESTATE_WAITING then
        RE4M_CloseResults()
        RE4M_OpenMainMenu()
        RE4M_StopRoundMusic()
        RE4M_PlayMenuMusic()

    elseif state == GAMESTATE_PREROUND then
        RE4M_CloseResults()
        RE4M_CloseMainMenu()
        RE4M_StopMenuMusic()

    elseif state == GAMESTATE_ACTIVE then
        RE4M_CloseMainMenu()
        RE4M_CloseResults()
        RE4M_CLIENT.Score            = 0
        RE4M_CLIENT.Combo            = 0
        RE4M_CLIENT.Kills            = 0
        RE4M_CLIENT.KillFeed         = {}
        RE4M_CLIENT.Popups           = {}
        RE4M_CLIENT.DamageNumbers    = {}
        RE4M_CLIENT.KillScoreFloats  = {}
        RE4M_CLIENT.EliteAlerts      = {}

    elseif state == GAMESTATE_POSTROUND then
        RE4M_StopRoundMusic()
    end
end)

net.Receive("RE4M_ForceMenu", function()
    RE4M_OpenMainMenu()
end)

net.Receive("RE4M_WeaponList", function()
    local len  = net.ReadUInt(32)
    local data = net.ReadData(len)
    local decompressed = util.Decompress(data)
    if not decompressed then
        ErrorNoHalt("[RE4 Mercs] RE4M_WeaponList: Failed to decompress weapon data!\n")
        return
    end

    local json = util.JSONToTable(decompressed)
    if json then
        RE4M_CLIENT.WeaponList = json
    else
        ErrorNoHalt("[RE4 Mercs] RE4M_WeaponList: Failed to parse weapon JSON!\n")
    end
end)

net.Receive("RE4M_ScoreUpdate", function()
    RE4M_CLIENT.Score      = net.ReadUInt(32)
    RE4M_CLIENT.Combo      = net.ReadUInt(16)
    RE4M_CLIENT.Multiplier = net.ReadFloat()
end)

net.Receive("RE4M_TimeUpdate", function()
    RE4M_CLIENT.RoundTimeLeft = net.ReadFloat()
end)

net.Receive("RE4M_KillFeed", function()
    local score      = net.ReadUInt(24)
    local combo      = net.ReadUInt(16)
    local multiplier = net.ReadFloat()
    local hasBonus   = net.ReadBool()

    table.insert(RE4M_CLIENT.KillFeed, 1, {
        score      = score,
        combo      = combo,
        multiplier = multiplier,
        hasBonus   = hasBonus,
        time       = CurTime(),
        alpha      = 255,
    })
    while #RE4M_CLIENT.KillFeed > 6 do
        table.remove(RE4M_CLIENT.KillFeed)
    end
end)

net.Receive("RE4M_ComboPopup", function()
    local combo     = net.ReadUInt(16)
    local timeAdded = net.ReadFloat()

    if combo > 0 then
        table.insert(RE4M_CLIENT.Popups, {
            text  = combo .. " COMBO!",
            sub   = "+" .. string.format("%.1f", timeAdded) .. "s",
            time  = CurTime(),
            alpha = 255,
            scale = 2.0,
        })
    end
end)

net.Receive("RE4M_PickupCollected", function()
    local pickupType = net.ReadString()

    local names = {
        health       = "HEALTH RECOVERED",
        ammo         = "AMMO AQUIRED",
        time         = "TIME EXTENDED",
        rare_rpg     = "★ RARE DROP: RPG ROUND ★",
        rare_grenade = "★ RARE DROP: GRENADE ★",
    }

    local typeColors = {
        health       = "health",
        ammo         = "ammo",
        time         = "time",
        rare_rpg     = "rare",
        rare_grenade = "rare",
    }

    table.insert(RE4M_CLIENT.PickupNotifs, {
        text  = names[pickupType] or "PICKUP",
        type  = typeColors[pickupType] or "ammo",
        time  = CurTime(),
        alpha = 255,
    })
end)

net.Receive("RE4M_TimeExtend", function()
    local seconds = net.ReadFloat()

    table.insert(RE4M_CLIENT.TimeExtendNotifs, {
        seconds = seconds,
        time    = CurTime(),
        alpha   = 255,
    })
end)

net.Receive("RE4M_SyncMusic", function()
    local track      = net.ReadUInt(4)
    local shouldPlay = net.ReadBool()

    RE4M_CLIENT.MusicTrack = track

    if shouldPlay then
        RE4M_StopMenuMusic()
        RE4M_PlayRoundMusic(track)
    else
        RE4M_StopRoundMusic()
    end
end)

net.Receive("RE4M_ThemeInfo", function()
    RE4M_CLIENT.CurrentTheme = net.ReadString()
end)

net.Receive("RE4M_NavmeshWarning", function()
    RE4M_CLIENT.HasNavmesh = false
    chat.AddText(
        Color(255, 50, 50),  "[RE4 Mercs] ",
        Color(255, 200, 50), "WARNING: ",
        Color(255, 255, 255), "No navmesh found! Use 'nav_generate' to fix."
    )
end)

net.Receive("RE4M_AllScores", function()
    local len  = net.ReadUInt(32)
    local data = net.ReadData(len)

    -- FIX #8: Same decompress guard as FIX #5.
    local decompressed = util.Decompress(data)
    if not decompressed then
        ErrorNoHalt("[RE4 Mercs] RE4M_AllScores: Failed to decompress results data!\n")
        return
    end

    local results = util.JSONToTable(decompressed)
    if results then
        RE4M_ShowResults(results)
    else
        ErrorNoHalt("[RE4 Mercs] RE4M_AllScores: Failed to parse results JSON!\n")
    end
end)

net.Receive("RE4M_EchoTeamMessage", function()
    RE4M_CLIENT.EchoTeam.msg1     = net.ReadString()
    RE4M_CLIENT.EchoTeam.msg2     = net.ReadString()
    RE4M_CLIENT.EchoTeam.msg3     = net.ReadString()
    RE4M_CLIENT.EchoTeam.duration = net.ReadFloat()
    RE4M_CLIENT.EchoTeam.startTime = CurTime()
end)

-- ============================================
-- FLOATING DAMAGE NUMBER RECEIVER
-- ============================================

net.Receive("RE4M_DamageNumber", function()
    local hitPos    = net.ReadVector()
    local damage    = net.ReadUInt(16)
    local isHeadshot = net.ReadBool()
    local willKill  = net.ReadBool()
    local targetEnt = net.ReadEntity()

    local randomOffset = Vector(
        math.Rand(-30, 30),
        math.Rand(-30, 30),
        math.Rand(10, 40)
    )

    table.insert(RE4M_CLIENT.DamageNumbers, {
        pos        = hitPos + randomOffset,
        damage     = damage,
        isHeadshot = isHeadshot,
        willKill   = willKill,
        targetEnt  = IsValid(targetEnt) and targetEnt or nil,
        time       = CurTime(),
        alpha      = 255,
        velocity   = Vector(
                         math.Rand(-20, 20),
                         math.Rand(-20, 20),
                         math.Rand(40, 80)
                     ),
        lifetime   = (isHeadshot and 1.5 or 1.0),
    })

    while #RE4M_CLIENT.DamageNumbers > 30 do
        table.remove(RE4M_CLIENT.DamageNumbers, 1)
    end
end)

-- ============================================
-- KILL SCORE FLOAT RECEIVER
-- ============================================

net.Receive("RE4M_EnemyKilled", function()
    local deathPos  = net.ReadVector()
    local score     = net.ReadUInt(24)
    local timeAdded = net.ReadFloat()
    local isElite   = net.ReadBool()
    local attacker  = net.ReadEntity()

    table.insert(RE4M_CLIENT.KillScoreFloats, {
        pos       = deathPos + Vector(0, 0, 60),
        score     = score,
        timeAdded = timeAdded,
        isElite   = isElite,
        spawnTime = CurTime(),
        alpha     = 255,
        attacker  = IsValid(attacker) and attacker or nil,
    })

    while #RE4M_CLIENT.KillScoreFloats > 15 do
        table.remove(RE4M_CLIENT.KillScoreFloats, 1)
    end
end)

-- ============================================
-- ELITE SPAWN ALERT RECEIVER
-- ============================================

net.Receive("RE4M_EliteSpawned", function()
    local className = net.ReadString()
    local spawnPos  = net.ReadVector()

    table.insert(RE4M_CLIENT.EliteAlerts, {
        text     = "⚠ ELITE ENEMY DETECTED ⚠",
        subtext  = string.upper(className or "UNKNOWN"),
        time     = CurTime(),
        alpha    = 255,
        duration = 4,
        spawnPos = spawnPos,  -- FIX #15 continued: store the position
    })

    if file.Exists("sound/re4mercs/elite_warning.ogg", "GAME") then
        surface.PlaySound("re4mercs/elite_warning.ogg")
    else
        surface.PlaySound("npc/attack_helicopter/aheli_damaged_alarm1.wav")
    end
end)

-- ============================================
-- DISABLE DEFAULT HUD
-- ============================================

local hideHUD = {
    ["CHudHealth"]          = true,
    ["CHudBattery"]         = true,
    ["CHudAmmo"]            = true,
    ["CHudSecondaryAmmo"]   = true,
    ["CHudDamageIndicator"] = true,
    ["CHudCrosshair"]       = false,  -- false = allow crosshair to draw
}

hook.Add("HUDShouldDraw", "RE4M_HideDefaultHUD", function(name)
    if hideHUD[name] == true then return false end
end)

-- ============================================
-- CLIENT THINK
-- ============================================

hook.Add("Think", "RE4M_ClientThink", function()
    if RE4M_CLIENT.GameState == GAMESTATE_ACTIVE then
        local endTime = GetGlobalFloat("RE4M_RoundEndTime", 0)
        if endTime > 0 then
            RE4M_CLIENT.RoundTimeLeft = math.max(0, endTime - CurTime())
        end
    end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    if ply.RE4M_GetScore then
        RE4M_CLIENT.Score = ply:RE4M_GetScore()
    end
    if ply.RE4M_GetCombo then
        RE4M_CLIENT.Combo = ply:RE4M_GetCombo()
    end
    if ply.RE4M_GetKills then
        RE4M_CLIENT.Kills = ply:RE4M_GetKills()
    end
end)