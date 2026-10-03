-- RE4 Mercenaries Remake - Client Init

include("shared.lua")
include("cl_hud.lua")
include("cl_menu.lua")
include("cl_music.lua")
include("cl_results.lua")
include("cl_camera_movement.lua")
include("cl_roll.lua")
include("cl_hudblock.lua")

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
    ProgressionProfiles = {},
    EchoTeam         = {
        msg1 = "",
        msg2 = "",
        msg3 = "",
        duration = 2.0,
        startTime = 0,
    },
}

function RE4M_PlayUISound(path, fallback)
    if file.Exists("sound/" .. path, "GAME") then
        surface.PlaySound(path)
    elseif fallback and file.Exists("sound/" .. fallback, "GAME") then
        surface.PlaySound(fallback)
    end
end

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

    surface.CreateFont("RE4M_EnemyLevel", {
        font = "Arial Black",
        size = 20,
        weight = 900,
        antialias = true,
        outline = true,
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
        RE4M_PlayUISound("ui/ui_startmatch.wav")

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
        RE4M_RestoreSavedLoadout()
    else
        ErrorNoHalt("[RE4 Mercs] RE4M_WeaponList: Failed to parse weapon JSON!\n")
    end
end)

--- Re-select the loadout saved in re4m_loadout. The loadout used to be
--- forgotten on every reconnect/map change, silently falling back to the
--- default HL2 pistol/SMG/crowbar kit.
function RE4M_RestoreSavedLoadout()
    local cvar = GetConVar("re4m_loadout")
    if not cvar then return end
    local saved = cvar:GetString()
    if saved == "" then return end

    local byClass = {}
    for _, wep in ipairs(RE4M_CLIENT.WeaponList or {}) do
        byClass[wep.class] = wep
    end

    local cfg = RE4MERCS_GetConfig()
    local maxSlots = cfg and cfg.MaxWeaponSlots or 3
    local restored = {}
    for class in string.gmatch(saved, "([^,]+)") do
        if byClass[class] and #restored < maxSlots then
            restored[#restored + 1] = byClass[class]
        end
    end
    if #restored == 0 then return end

    RE4M_CLIENT.SelectedLoadout = restored
    if RE4M_SendLoadout then RE4M_SendLoadout() end
end

RE4M_CLIENT.CustomNPCs = { regular = {}, elite = {} }

net.Receive("RE4M_CustomNPCList", function()
    local function ReadList()
        local list = {}
        for i = 1, net.ReadUInt(8) do list[#list + 1] = net.ReadString() end
        return list
    end
    RE4M_CLIENT.CustomNPCs = { regular = ReadList(), elite = ReadList() }
    RE4M_CLIENT.CustomNPCRevision = (RE4M_CLIENT.CustomNPCRevision or 0) + 1
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
    local ammoLabel = pickupType == "ammo" and net.BytesLeft() > 0 and net.ReadString() or nil
    if pickupType == "health" and RE4M_FlashVignette then RE4M_FlashVignette("herb") end

    local names = {
        health       = "HEALTH RECOVERED",
        ammo         = "AMMO ACQUIRED",
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
        text  = pickupType == "ammo" and
            ((ammoLabel and ammoLabel ~= "" and ammoLabel or "AMMO") .. " ACQUIRED") or
            (names[pickupType] or "PICKUP"),
        type  = typeColors[pickupType] or "ammo",
        time  = CurTime(),
        alpha = 255,
    })
end)

-- RE4-style pickup markers: camera-facing textured quads using the addon beam
-- material, with width/alpha tuned by distance like the reference drop system.
local re4mPickupBeamMaterial = Material("re4beam/beam")
local re4mPickupBeamClasses = {"re_ammopickup", "re_greenherb", "re_timepickup"}

hook.Add("PreDrawHalos", "RE4M_PickupHalos", function()
    local healthPickups, ammoPickups = {}, {}
    for _, className in ipairs(re4mPickupBeamClasses) do
        for _, ent in ipairs(ents.FindByClass(className)) do
            if not IsValid(ent) then continue end
            local category = ent:GetNW2String("RE_LootCategory", "")
            if category == "ammo" then
                ammoPickups[#ammoPickups + 1] = ent
            elseif category == "health" or category == "time" then
                healthPickups[#healthPickups + 1] = ent
            end
        end
    end

    if #healthPickups > 0 then halo.Add(healthPickups, Color(150, 255, 150), 2, 2, 1, true, true) end
    if #ammoPickups > 0 then halo.Add(ammoPickups, Color(255, 160, 160), 2, 2, 1, true, true) end
end)

hook.Add("PostDrawTranslucentRenderables", "RE4M_PickupBeams", function(depth, skybox)
    if depth or skybox then return end
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local up = Vector(0, 0, 1)
    for _, className in ipairs(re4mPickupBeamClasses) do
        for _, ent in ipairs(ents.FindByClass(className)) do
            if not IsValid(ent) then continue end
            local category = ent:GetNW2String("RE_LootCategory", "")
            if category == "" then continue end

            local entityPos = ent:GetPos()
            local dist = ply:GetPos():Distance(entityPos)
            local width = math.Clamp(math.Remap(dist, 500, 1500, 3, 12), 3, 12)
            local alpha = math.Clamp(math.Remap(dist, 130, 170, 0, 255), 0, 255)
            local color = category == "ammo"
                and Color(255, 145, 145, alpha)
                or Color(175, 255, 175, alpha)

            local pos = entityPos + Vector(0, 0, 20)
            local toPlayer = ply:GetPos() - pos
            toPlayer.z = 0
            if toPlayer:LengthSqr() < 0.001 then toPlayer = Vector(1, 0, 0) end
            local right = toPlayer:GetNormalized():Cross(up):GetNormalized()
            local height = 40

            render.SetMaterial(re4mPickupBeamMaterial)
            render.DrawQuad(
                pos + up * height + right * width,
                pos + up * height - right * width,
                pos - up * height - right * width,
                pos - up * height + right * width,
                color
            )
        end
    end
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
    RE4M_CLIENT.EchoTeam = RE4M_CLIENT.EchoTeam or {}
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

    -- The re4m_showdamagenumbers / maxdamagenumbers / *lifetime ConVars
    -- existed but the values here were hard-coded.
    local cfg = RE4MERCS_GetConfig()
    if not cfg.ShowDamageNumbers then return end
    local maxNumbers = math.max(1, tonumber(cfg.MaxDamageNumbers) or 30)

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
        lifetime   = isHeadshot and (tonumber(cfg.HeadshotNumberLifetime) or 1.5)
                                 or (tonumber(cfg.DamageNumberLifetime) or 1.0),
    })

    while #RE4M_CLIENT.DamageNumbers > maxNumbers do
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

    local cfg = RE4MERCS_GetConfig()
    if not cfg.ShowKillScores then return end
    local maxFloats = math.max(1, tonumber(cfg.MaxKillScoreFloats) or 15)

    table.insert(RE4M_CLIENT.KillScoreFloats, {
        pos       = deathPos + Vector(0, 0, 60),
        score     = score,
        timeAdded = timeAdded,
        isElite   = isElite,
        spawnTime = CurTime(),
        alpha     = 255,
        attacker  = IsValid(attacker) and attacker or nil,
    })

    while #RE4M_CLIENT.KillScoreFloats > maxFloats do
        table.remove(RE4M_CLIENT.KillScoreFloats, 1)
    end
end)

-- ============================================
-- ELITE SPAWN ALERT RECEIVER
-- ============================================

net.Receive("RE4M_EliteSpawned", function()
    local className = net.ReadString()
    local spawnPos  = net.ReadVector()

    local cfg = RE4MERCS_GetConfig()
    if not cfg.ShowEliteAlerts then return end

    -- Show the enemy's display name ("Garrador") rather than its raw class
    -- ("DRG_ROACH_RE4_GARRADOR") when the entity or NPC list provides one.
    local displayName = className
    local stored = scripted_ents.GetStored(className)
    if stored and stored.t and isstring(stored.t.PrintName) and stored.t.PrintName ~= "" then
        displayName = stored.t.PrintName
    elseif list.Get("NPC")[className] and list.Get("NPC")[className].Name then
        displayName = list.Get("NPC")[className].Name
    end
    if isstring(displayName) and string.StartWith(displayName, "#") then
        displayName = language.GetPhrase(string.sub(displayName, 2))
    end

    table.insert(RE4M_CLIENT.EliteAlerts, {
        text     = "⚠ ELITE ENEMY DETECTED ⚠",
        subtext  = string.upper(displayName or "UNKNOWN"),
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


-- =============================================
-- Parry System
-- =============================================

local nextDoorKickAttempt = 0
local KNIFE_MODEL = "models/weapons/w_knife_t.mdl"
local originalTPIK = nil          -- stores original arc9_tpik value

local function RE4M_DisableTPIKForAction()
    local tpikCvar = GetConVar("arc9_tpik")
    if not tpikCvar then return end

    if originalTPIK == nil then originalTPIK = tpikCvar:GetInt() end
    RunConsoleCommand("arc9_tpik", "0")

    hook.Add("Think", "RE4M_RestoreActionTPIK", function()
        local ply = LocalPlayer()
        local parryActive = IsValid(ply) and ply:GetNW2Float("RE4M_ParryTime", 0) > CurTime()
        local counterActive = IsValid(ply) and ply:GetNW2Float("RE4M_CounterTime", 0) > CurTime()
        if parryActive or counterActive then return end

        hook.Remove("Think", "RE4M_RestoreActionTPIK")
        if originalTPIK ~= nil then
            RunConsoleCommand("arc9_tpik", tostring(originalTPIK))
            originalTPIK = nil
        end
    end)
end

-- Remove legacy standalone binds; parry and counter now share the USE key.
concommand.Remove("re4m_parry")
concommand.Remove("re4m_counter")

net.Receive("RE4M_ParryHit", function()
    local pos = net.ReadVector()

    local effectdata = EffectData()
    effectdata:SetOrigin(pos)
    effectdata:SetNormal(Vector(0, 0, 1))
    effectdata:SetMagnitude(2)
    effectdata:SetScale(1.5)
    effectdata:SetRadius(3)
    util.Effect("Sparks", effectdata)

    local flash = EffectData()
    flash:SetOrigin(pos)
    flash:SetScale(1.2)
    util.Effect("cball_explode", flash)
end)

-- One temporary knife per parrying player. The server now broadcasts the
-- parry with the player entity, so teammates see the knife too (previously
-- only the parrying player got the message).
local parryKnives = {}

local function RE4M_RemoveParryKnife(ply)
    local knife = parryKnives[ply]
    if IsValid(knife) then knife:Remove() end
    parryKnives[ply] = nil
    if IsValid(ply) then
        local wep = ply:GetActiveWeapon()
        if IsValid(wep) then wep:SetNoDraw(false) end
    end
end

net.Receive("RE4M_PlayParryAnim", function()
    local ply = net.ReadEntity()
    if not IsValid(ply) then return end

    ply:AnimRestartMainSequence()

    -- Force ARC9 third-person IK off so arms don't bug
    if ply == LocalPlayer() then RE4M_DisableTPIKForAction() end

    RE4M_RemoveParryKnife(ply)
    local knife = ClientsideModel(KNIFE_MODEL)
    if not IsValid(knife) then return end
    knife:SetNoDraw(false)
    parryKnives[ply] = knife
end)

-- Keep each knife in its player's hand and hide the real gun while parrying.
hook.Add("Think", "RE4M_ParryKnifeThink", function()
    for ply, knife in pairs(parryKnives) do
        if not IsValid(ply) or not IsValid(knife) or ply:GetNW2Float("RE4M_ParryTime", 0) <= CurTime() then
            RE4M_RemoveParryKnife(ply)
            continue
        end

        local wep = ply:GetActiveWeapon()
        if IsValid(wep) then wep:SetNoDraw(true) end

        local bone = ply:LookupBone("ValveBiped.Bip01_R_Hand")
        local matrix = bone and ply:GetBoneMatrix(bone)
        if matrix then
            local pos = matrix:GetTranslation()
            local ang = matrix:GetAngles()

            -- Adjust these if the knife sits wrong
            pos = pos + ang:Forward() * 3 + ang:Right() * 1.5 + ang:Up() * -1
            ang:RotateAroundAxis(ang:Right(), 90)
            ang:RotateAroundAxis(ang:Up(), 180)

            knife:SetPos(pos)
            knife:SetAngles(ang)
        end
    end
end)

net.Receive("RE4M_PlayCounterAnim", function()
    local ply = net.ReadEntity()
    if IsValid(ply) then
        ply:SetCycle(0)
        ply:AnimRestartMainSequence()
    end

    -- ARC9's third-person IK can interfere with the counter animation pose.
    if IsValid(ply) and ply == LocalPlayer() then RE4M_DisableTPIKForAction() end
end)

net.Receive("RE4M_PlayDoorKick", function()
    local ply = net.ReadEntity()
    if IsValid(ply) then
        ply:SetCycle(0)
        ply:AnimRestartMainSequence()
    end
end)

local function RE4M_ClientFindKickDoor(maxRange)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local eyePos = ply:EyePos()
    local trace = util.TraceLine({
        start = eyePos,
        endpos = eyePos + ply:GetAimVector() * maxRange,
        filter = ply,
        mask = MASK_SOLID,
    })
    local door = trace.Entity
    if not IsValid(door) then return end
    local class = door:GetClass()
    if class ~= "prop_door_rotating" and class ~= "func_door" and class ~= "func_door_rotating" then return end
    if door:MapCreationID() == -1 or door:GetNW2Bool("RE4M_KickedOpen", false) then return end
    if eyePos:DistToSqr(door:WorldSpaceCenter()) > maxRange * maxRange then return end
    return door
end

local RE4M_CLIENT_USE_PICKUPS = {
    re_ammopickup = true,
    re_greenherb = true,
    re_timepickup = true,
}

local function RE4M_ClientFindUsePickup()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local viewOrigin, direction
    if RE4M_GetCameraAimRay then
        viewOrigin, direction = RE4M_GetCameraAimRay()
    end
    viewOrigin = isvector(viewOrigin) and viewOrigin or ply:EyePos()
    direction = isvector(direction) and direction:GetNormalized() or ply:GetAimVector()
    local maxPickupRange = 220
    local viewRange = maxPickupRange + math.min(viewOrigin:Distance(ply:GetPos()), 160)
    local traceFilter = {ply}
    local activeWeapon = ply:GetActiveWeapon()
    if IsValid(activeWeapon) then traceFilter[#traceFilter + 1] = activeWeapon end
    local directTrace = util.TraceLine({
        start = viewOrigin,
        endpos = viewOrigin + direction * viewRange,
        filter = traceFilter,
        mask = MASK_SOLID,
    })
    local direct = directTrace.Entity
    if IsValid(direct) and RE4M_CLIENT_USE_PICKUPS[direct:GetClass()] and
       ply:GetPos():DistToSqr(direct:WorldSpaceCenter()) <= maxPickupRange * maxPickupRange then
        return direct
    end

    -- Give the three small RE4 pickups a generous aim-assist volume so the
    -- third-person camera does not require pixel-perfect USE targeting.
    local best, bestDistance
    for _, ent in ipairs(ents.FindInSphere(ply:GetPos(), maxPickupRange)) do
        if not IsValid(ent) or not RE4M_CLIENT_USE_PICKUPS[ent:GetClass()] then continue end
        local offset = ent:WorldSpaceCenter() - viewOrigin
        local alongRay = offset:Dot(direction)
        if alongRay < 0 or alongRay > viewRange then continue end

        local perpendicular = offset - direction * alongRay
        local distanceSqr = perpendicular:LengthSqr()
        local aimRadius = ent:GetClass() == "re_greenherb" and 96 or 80
        if distanceSqr > aimRadius * aimRadius then continue end
        if bestDistance and distanceSqr >= bestDistance then continue end

        local visibilityFilter = {ply, ent}
        if IsValid(activeWeapon) then visibilityFilter[#visibilityFilter + 1] = activeWeapon end
        local visibility = util.TraceLine({
            start = viewOrigin,
            endpos = ent:WorldSpaceCenter(),
            filter = visibilityFilter,
            mask = MASK_SOLID,
        })
        if visibility.Hit then continue end

        best = ent
        bestDistance = distanceSqr
    end
    return best
end

local nextUsePromptScan = 0
local cachedUsePromptPickup

local function RE4M_UpdateUsePromptTargets()
    if nextUsePromptScan > CurTime() then
        return cachedUsePromptPickup
    end

    nextUsePromptScan = CurTime() + 0.12
    cachedUsePromptPickup = RE4M_ClientFindUsePickup()
    return cachedUsePromptPickup
end

local function RE4M_ClientCanParry()
    local ply = LocalPlayer()
    if not IsValid(ply) then return false end
    local cfg = RE4MERCS_GetConfig and RE4MERCS_GetConfig()
    if not cfg or cfg.ParryEnabled == false then return false end
    local range = cfg.ParryRange or 120
    for _, ent in ipairs(ents.FindInSphere(ply:GetPos(), range)) do
        local isVJ = IsValid(ent) and ent.IsVJBaseSNPC == true
        if not IsValid(ent) or not (isVJ or ent.IsDrGNextbot or (ent.IsNextBot and ent:IsNextBot())) then continue end
        if not isVJ and not ent.Parryable then continue end
        local attacking = ent.IsAttacking and isfunction(ent.IsAttacking) and ent:IsAttacking()
        if not attacking then
            local sequence = string.lower(ent:GetSequenceName(ent:GetSequence()) or "")
            attacking = (string.find(sequence, "att", 1, true) ~= nil or string.find(sequence, "melee", 1, true) ~= nil) and
                not string.find(sequence, "grab", 1, true) and not string.find(sequence, "idle", 1, true)
        end
        if attacking then return true end
    end
    return false
end

local function RE4M_ClientFindCounterTarget()
    local ply = LocalPlayer()
    if not IsValid(ply) or not RE4M_IsCounterStunned then return end
    local cfg = RE4MERCS_GetConfig and RE4MERCS_GetConfig()
    if not cfg or cfg.CounterEnabled == false then return end
    local range = cfg.CounterRange or cfg.ParryRange or 120
    local best, bestDistance
    for _, ent in ipairs(ents.FindInSphere(ply:GetPos(), range)) do
        local isNextBot = IsValid(ent) and (ent.IsDrGNextbot or ent.IsVJBaseSNPC or (ent.IsNextBot and ent:IsNextBot()))
        if not isNextBot or not RE4M_IsCounterStunned(ent) or ent:GetNW2Float("RE4M_CounteredUntil", 0) > CurTime() then continue end
        local distance = ply:GetPos():DistToSqr(ent:GetPos())
        if not bestDistance or distance < bestDistance then best, bestDistance = ent, distance end
    end
    return best
end

hook.Add("PlayerBindPress", "RE4M_DoorKickUseBind", function(ply, bind, pressed)
    if not IsValid(ply) or ply ~= LocalPlayer() or RE4M_CLIENT.GameState ~= GAMESTATE_ACTIVE then return end
    if not string.find(string.lower(bind or ""), "+use", 1, true) then return end
    if ply:GetNW2Float("RE4M_ParryTime", 0) > CurTime() or
       ply:GetNW2Float("RE4M_CounterTime", 0) > CurTime() or
       ply:GetNW2Float("RE4M_DoorKickTime", 0) > CurTime() or
       ply:GetNW2Float("RE4M_RollEndTime", 0) > CurTime() then return true end

    local pickup = RE4M_ClientFindUsePickup()
    if pickup then
        if pressed and nextDoorKickAttempt <= CurTime() then
            nextDoorKickAttempt = CurTime() + 0.25
            local viewOrigin = ply:EyePos()
            if RE4M_GetCameraAimRay then
                local cameraOrigin = select(1, RE4M_GetCameraAimRay())
                if isvector(cameraOrigin) then viewOrigin = cameraOrigin end
            end
            net.Start("RE4M_UsePickupRequest")
                net.WriteEntity(pickup)
                net.WriteVector(viewOrigin)
            net.SendToServer()
        end
        return true
    end

    if pressed and RE4M_ClientFindCounterTarget() then
        net.Start("RE4M_CounterRequest")
        net.SendToServer()
        return true
    end

    if pressed and RE4M_ClientCanParry() then
        net.Start("RE4M_ParryRequest")
        net.SendToServer()
        return true
    end

    if pressed and nextDoorKickAttempt <= CurTime() then
        nextDoorKickAttempt = CurTime() + 0.25
        net.Start("RE4M_DoorKickRequest")
        net.SendToServer()
    end
    return true
end)

-- ============================================
-- Movement lock
-- ============================================
hook.Add("SetupMove", "RE4M_ParryLockMovement", function(ply, mv, cmd)
    local parryEnd = ply:GetNW2Float("RE4M_ParryTime", 0)
    local counterEnd = ply:GetNW2Float("RE4M_CounterTime", 0)
    local doorKickEnd = ply:GetNW2Float("RE4M_DoorKickTime", 0)
    if parryEnd > CurTime() or counterEnd > CurTime() or doorKickEnd > CurTime() then
        mv:SetForwardSpeed(0)
        mv:SetSideSpeed(0)
        mv:SetUpSpeed(0)
        mv:SetMaxClientSpeed(0)
    end
end)

-- Hide first-person viewmodel
hook.Add("PreDrawViewModel", "RE4M_ParryHideViewmodel", function(vm, ply, wep)
    local parryEnd = ply:GetNW2Float("RE4M_ParryTime", 0)
    local counterEnd = ply:GetNW2Float("RE4M_CounterTime", 0)
    local doorKickEnd = ply:GetNW2Float("RE4M_DoorKickTime", 0)
    local rollEnd = ply:GetNW2Float("RE4M_RollEndTime", 0)
    if parryEnd > CurTime() or counterEnd > CurTime() or doorKickEnd > CurTime() or rollEnd > CurTime() then
        return true
    end
end)

-- Draw the local player model in third person
hook.Add("ShouldDrawLocalPlayer", "RE4M_ParryShowThirdPersonModel", function(ply)
    local actionEnd = math.max(ply:GetNW2Float("RE4M_ParryTime", 0), ply:GetNW2Float("RE4M_CounterTime", 0), ply:GetNW2Float("RE4M_DoorKickTime", 0), ply:GetNW2Float("RE4M_RollEndTime", 0))
    return actionEnd > CurTime()
end)

-- ============================================
-- Simple QTE prompt
-- ============================================
hook.Add("HUDPaint", "RE4M_ParryQTE", function()
    if RE4M_CLIENT.GameState ~= GAMESTATE_ACTIVE then return end

    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    -- Don't show the prompt while already parrying
    if ply:GetNW2Float("RE4M_ParryTime", 0) > CurTime() then return end

    local cfg = RE4MERCS_GetConfig and RE4MERCS_GetConfig()
    if not cfg or cfg.ParryEnabled == false then return end

    local promptPickup = RE4M_UpdateUsePromptTargets()
    if promptPickup or RE4M_ClientFindCounterTarget() or not RE4M_ClientCanParry() then return end

    local sw, sh = ScrW(), ScrH()
    local alpha = 180 + math.sin(CurTime() * 8) * 75   -- gentle pulse

    -- Background bar
    surface.SetDrawColor(0, 0, 0, alpha * 0.6)
    surface.DrawRect(sw / 2 - 140, sh * 0.72, 280, 42)

    -- Text
    local binding = input.LookupBinding("+use") or "E"
    draw.SimpleText("PARRY  [ " .. string.upper(binding) .. " ]", "RE4M_Medium",
        sw / 2, sh * 0.72 + 21,
        Color(255, 220, 80, alpha),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

hook.Add("HUDPaint", "RE4M_CounterPrompt", function()
    if RE4M_CLIENT.GameState ~= GAMESTATE_ACTIVE then return end
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end
    local promptPickup = RE4M_UpdateUsePromptTargets()
    if promptPickup then return end
    if ply:GetNW2Float("RE4M_ParryTime", 0) > CurTime() or
       ply:GetNW2Float("RE4M_CounterTime", 0) > CurTime() then return end

    local cfg = RE4MERCS_GetConfig and RE4MERCS_GetConfig()
    if not cfg or cfg.CounterEnabled == false then return end

    if not RE4M_ClientFindCounterTarget() then return end

    local binding = input.LookupBinding("+use") or "E"
    local label = "COUNTER  [ " .. string.upper(binding) .. " ]"
    local sw, sh = ScrW(), ScrH()
    local alpha = 180 + math.sin(CurTime() * 8) * 75
    surface.SetDrawColor(0, 0, 0, alpha * 0.6)
    surface.DrawRect(sw / 2 - 160, sh * 0.66, 320, 42)
    draw.SimpleText(label, "RE4M_Medium", sw / 2, sh * 0.66 + 21,
        Color(255, 170, 80, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

hook.Add("HUDPaint", "RE4M_DoorKickPrompt", function()
    if RE4M_CLIENT.GameState ~= GAMESTATE_ACTIVE then return end
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end
    if ply:GetNW2Float("RE4M_ParryTime", 0) > CurTime() or
       ply:GetNW2Float("RE4M_CounterTime", 0) > CurTime() or
       ply:GetNW2Float("RE4M_DoorKickTime", 0) > CurTime() then return end
    local promptPickup = RE4M_UpdateUsePromptTargets()
    if promptPickup then return end

    local cfg = RE4MERCS_GetConfig and RE4MERCS_GetConfig()
    local door = RE4M_ClientFindKickDoor((cfg and cfg.DoorKickRange) or 100)
    if not IsValid(door) then return end

    local binding = input.LookupBinding("+use") or "E"
    local label = "OPEN  [ " .. string.upper(binding) .. " ]"
    local sw, sh = ScrW(), ScrH()
    local alpha = 180 + math.sin(CurTime() * 8) * 75
    surface.SetDrawColor(0, 0, 0, alpha * 0.6)
    surface.DrawRect(sw / 2 - 150, sh * 0.72, 300, 42)
    draw.SimpleText(label, "RE4M_Medium", sw / 2, sh * 0.72 + 21,
        Color(255, 220, 80, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

hook.Add("HUDPaint", "RE4M_PickupUsePrompt", function()
    if RE4M_CLIENT.GameState ~= GAMESTATE_ACTIVE then return end
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end
    if ply:GetNW2Float("RE4M_ParryTime", 0) > CurTime() or
       ply:GetNW2Float("RE4M_CounterTime", 0) > CurTime() or
       ply:GetNW2Float("RE4M_DoorKickTime", 0) > CurTime() then return end
    local pickup = RE4M_UpdateUsePromptTargets()
    if not pickup then return end

    local binding = input.LookupBinding("+use") or "E"
    local sw, sh = ScrW(), ScrH()
    local alpha = 180 + math.sin(CurTime() * 8) * 75
    surface.SetDrawColor(0, 0, 0, alpha * 0.6)
    surface.DrawRect(sw / 2 - 145, sh * 0.72, 290, 42)
    draw.SimpleText("TAKE  [ " .. string.upper(binding) .. " ]", "RE4M_Medium",
        sw / 2, sh * 0.72 + 21, Color(255, 220, 80, alpha),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

net.Receive("RE4M_LobbyProgression", function()
    local len = net.ReadUInt(32)
    if len == 0 or len > 65536 then return end

    local compressed = net.ReadData(len)
    if not compressed then return end
    local json = util.Decompress(compressed)
    if not json then return end

    -- The server sends a list of { steamID = "...", ... }. Rebuild the map
    -- keyed by the SteamID STRING the menus look up. ignoreConversions keeps
    -- numeric-looking weapon class keys as strings too.
    local decoded = util.JSONToTable(json, false, true)
    local profiles
    if istable(decoded) then
        profiles = {}
        for _, entry in ipairs(decoded) do
            if istable(entry) and entry.steamID then
                profiles[tostring(entry.steamID)] = entry
            end
        end
    end
    if istable(profiles) then
        local current = RE4M_CLIENT.ProgressionProfiles or {}
        for steamID, newProfile in pairs(profiles) do
            local oldProfile = current[steamID]
            if istable(oldProfile) and istable(oldProfile.weapons) and
               istable(newProfile) and istable(newProfile.weapons) then
                for class, weaponData in pairs(oldProfile.weapons) do
                    if newProfile.weapons[class] == nil then
                        newProfile.weapons[class] = weaponData
                    end
                end
            end
        end
        table.Empty(current)
        table.Merge(current, profiles)
        RE4M_CLIENT.ProgressionProfiles = current
        RE4M_CLIENT.ProgressionRevision = (RE4M_CLIENT.ProgressionRevision or 0) + 1
    end
end)

net.Receive("RE4M_AssignTFA_VOX", function()
    local targetModel = net.ReadString()
    local sourceModel = net.ReadString()
    if not istable(TFAVOX_Models) or not isstring(targetModel) or not isstring(sourceModel) then return end

    local pack = TFAVOX_Models[sourceModel]
    if not istable(pack) then
        local sourceLower = string.lower(sourceModel)
        for registeredPath, registeredPack in pairs(TFAVOX_Models) do
            if isstring(registeredPath) and string.lower(registeredPath) == sourceLower and istable(registeredPack) then
                pack = registeredPack
                break
            end
        end
    end

    if istable(pack) then
        TFAVOX_Models[targetModel] = pack
    end
end)
