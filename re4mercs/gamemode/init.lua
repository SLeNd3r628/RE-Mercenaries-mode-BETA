-- RE4 Mercenaries Remake - Server Init
-- All server-side logic

AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("cl_hud.lua")
AddCSLuaFile("cl_menu.lua")
AddCSLuaFile("cl_music.lua")
AddCSLuaFile("cl_results.lua")

include("shared.lua")
include("sv_scoring.lua")
include("sv_spawning.lua")
include("sv_rounds.lua")
include("sv_pickups.lua")
include("sv_admin.lua")

-- ============================================
-- REGISTER NET MESSAGES
-- ============================================

if RE4MERCS_NET and type(RE4MERCS_NET) == "table" then
    for _, msg in ipairs(RE4MERCS_NET) do
        util.AddNetworkString(msg)
    end
else
    ErrorNoHalt("[RE4 Mercs] WARNING: RE4MERCS_NET is not defined in shared.lua!\n")
end

-- ============================================
-- RESOURCE SETUP
-- ============================================

local soundFiles = {
    "sound/re4mercs/EvilEye.ogg",
    "sound/re4mercs/HeatOnBeat.ogg",
    "sound/re4mercs/RideonSea.ogg",
    "sound/re4mercs/ThePressureIsOn.ogg",
    "sound/ui/results.ogg",
    "sound/ui/menu.ogg",
    "sound/ui/combo_milestone.ogg",
    "sound/ui/time_extend.ogg",
    "sound/ui/pickup_health.ogg",
    "sound/ui/pickup_ammo.ogg",
    "sound/ui/pickup_time.ogg",
    "sound/ui/round_start.ogg",
    "sound/ui/round_end.ogg",
    "sound/ui/countdown.ogg",
    "sound/ui/rank_reveal.ogg",
}

for _, f in ipairs(soundFiles) do
    -- file.Exists needs the full path including "sound/"
    if file.Exists(f, "GAME") then
        resource.AddFile(f)
    else
        -- Only warn in debug; missing sounds are non-fatal
        if RE4MERCS_CONFIG and RE4MERCS_CONFIG.Debug then
            print("[RE4 Mercs] Missing sound file (will not be sent): " .. f)
        end
    end
end

local materialFiles = {
    "materials/vgui/re4mercs/background.png",
    "materials/vgui/re4mercs/vignette.png",
    "materials/vgui/re4mercs/logo.png",
    "materials/vgui/re4mercs/slot_bg.png",
    "materials/vgui/re4mercs/rank_bg.png",
    "materials/vgui/re4mercs/combo_fire.png",
    "materials/vgui/re4mercs/pickup_health.png",
    "materials/vgui/re4mercs/pickup_ammo.png",
    "materials/vgui/re4mercs/pickup_time.png",
}

for _, f in ipairs(materialFiles) do
    if file.Exists(f, "GAME") then
        resource.AddFile(f)
    else
        if RE4MERCS_CONFIG and RE4MERCS_CONFIG.Debug then
            print("[RE4 Mercs] Missing material file (will not be sent): " .. f)
        end
    end
end

-- ============================================
-- GAME STATE MANAGEMENT
-- ============================================

RE4M_STATE = {
    GameState    = GAMESTATE_WAITING,
    RoundTime    = 0,
    RoundEndTime = 0,
    CurrentTheme = "default",
    MusicTrack   = 1,
    ActiveNPCs   = {},
    Pickups      = {},
    RoundNumber  = 0,
    HasNavmesh   = false,
}

--- Set the global game state and notify all clients.
function RE4M_SetGameState(state)
    -- FIX #3: Validate that state is a number before writing it to a net
    -- message or SetGlobalInt. An invalid state would silently corrupt globals.
    if type(state) ~= "number" then
        ErrorNoHalt("[RE4 Mercs] RE4M_SetGameState called with non-number state: " .. tostring(state) .. "\n")
        return
    end

    RE4M_STATE.GameState = state
    SetGlobalInt("RE4M_GameState", state)

    net.Start("RE4M_GameState")
        net.WriteUInt(state, 4)
    net.Broadcast()

    if RE4MERCS_CONFIG and RE4MERCS_CONFIG.Debug then
        local stateNames = {
            [GAMESTATE_MENU]      = "MENU",
            [GAMESTATE_PREROUND]  = "PREROUND",
            [GAMESTATE_ACTIVE]    = "ACTIVE",
            [GAMESTATE_POSTROUND] = "POSTROUND",
            [GAMESTATE_WAITING]   = "WAITING",
        }
        print("[RE4 Mercs] Game state -> " .. (stateNames[state] or "UNKNOWN"))
    end
end

-- ============================================
-- WEAPON LIST BUILDING
-- ============================================

local RE4M_WeaponCache = {}

function RE4M_BuildWeaponList()
    RE4M_WeaponCache = {}

    -- FIX #4: RE4MERCS_GetConfig() may return nil if shared.lua is broken.
    -- Guard here so we get a useful error instead of a cryptic index-nil crash.
    local cfg = RE4MERCS_GetConfig()
    if not cfg then
        ErrorNoHalt("[RE4 Mercs] RE4M_BuildWeaponList: RE4MERCS_GetConfig() returned nil!\n")
        return
    end

    local allWeapons = weapons.GetList()

    for _, wep in ipairs(allWeapons) do
        local className   = wep.ClassName  or ""
        local printName   = wep.PrintName  or className
        local base        = wep.Base       or ""
        local worldModel  = wep.WorldModel or ""

        local allowed = RE4MERCS_IsWeaponAllowed(className, base)

        -- FIX #5: Original skipped weapons where printName == "". That is
        -- fine, but className == "" should also be rejected because Give("")
        -- would later cause an error.
        if allowed and className ~= "" and printName ~= "" then
            local category = RE4MERCS_CategorizeWeapon(className, printName)
            table.insert(RE4M_WeaponCache, {
                class    = className,
                name     = printName,
                category = category,
                model    = worldModel,
                base     = base,
            })
        end
    end

    table.sort(RE4M_WeaponCache, function(a, b)
        if a.category == b.category then
            return a.name < b.name
        end
        return a.category < b.category
    end)

    if RE4MERCS_CONFIG and RE4MERCS_CONFIG.Debug then
        print("[RE4 Mercs] Built weapon list: " .. #RE4M_WeaponCache .. " weapons")
    end
end

function RE4M_SendWeaponList(ply)
    -- FIX #6: Always validate the player before sending a net message.
    -- The original had no guard; if called from a timer the ply may have left.
    if not IsValid(ply) then return end

    local data       = util.TableToJSON(RE4M_WeaponCache)
    local compressed = util.Compress(data)
    local len        = #compressed

    net.Start("RE4M_WeaponList")
        net.WriteUInt(len, 32)
        net.WriteData(compressed, len)
    net.Send(ply)
end

-- ============================================
-- NAVMESH CHECK
-- ============================================

local function RE4M_CheckNavmesh()
    local areas = navmesh.GetAllNavAreas()
    if areas and #areas > 0 then
        RE4M_STATE.HasNavmesh = true
        print("[RE4 Mercs] Navmesh detected: " .. #areas .. " nav areas found.")
        return true
    else
        RE4M_STATE.HasNavmesh = false
        print("[RE4 Mercs] WARNING: No navmesh detected on this map!")
        print("[RE4 Mercs] NPCs will not be able to spawn.")
        print("[RE4 Mercs] Use 'nav_generate' in console to create one.")
        return false
    end
end

-- ============================================
-- CORE GAMEMODE HOOKS
-- ============================================

function GM:Initialize()
    print("[RE4 Mercs] ==============================")
    print("[RE4 Mercs] RE4 Mercenaries Remake loaded!")
    print("[RE4 Mercs] ==============================")

    RE4M_SetGameState(GAMESTATE_WAITING)
end

function GM:InitPostEntity()
    print("[RE4 Mercs] InitPostEntity - checking navmesh and building weapon list...")

    RE4M_CheckNavmesh()

    timer.Simple(1, function()
        RE4M_BuildWeaponList()

        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) then
                RE4M_SendWeaponList(ply)
            end
        end
    end)

    timer.Simple(3, function()
        if not RE4M_STATE.HasNavmesh then
            RE4M_CheckNavmesh()
        end

        local areas = navmesh.GetAllNavAreas()
        local count = areas and #areas or 0
        print("[RE4 Mercs] Final navmesh status: " .. count .. " areas | HasNavmesh = " .. tostring(RE4M_STATE.HasNavmesh))
    end)
end

function GM:PlayerInitialSpawn(ply)
    ply.RE4M_Loadout      = {}
    ply.RE4M_Playermodel  = ""
    ply.RE4M_Skin         = 0
    ply.RE4M_Bodygroups   = ""
    ply.RE4M_HandsModel   = ""
    ply.RE4M_HandsSkin    = 0
    ply.RE4M_HandsBody    = "0000000"
    ply.RE4M_PlayerColor  = Vector(0.3, 1.0, 0.8)
    ply.RE4M_Ready        = false

    ply:SetNWInt("RE4M_Score",    0)
    ply:SetNWInt("RE4M_Combo",    0)
    ply:SetNWInt("RE4M_MaxCombo", 0)
    ply:SetNWInt("RE4M_Kills",    0)
    ply:SetNWBool("RE4M_Ready",   false)

    timer.Simple(3, function()
        if not IsValid(ply) then return end

        RE4M_SendWeaponList(ply)

        if not RE4M_STATE.HasNavmesh then
            -- FIX #7: This net message must be registered. Make sure
            -- "RE4M_NavmeshWarning" is present in your RE4MERCS_NET table
            -- in shared.lua, otherwise this Start() call will silently fail.
            net.Start("RE4M_NavmeshWarning")
            net.Send(ply)
        end

        net.Start("RE4M_ThemeInfo")
            net.WriteString(RE4M_STATE.CurrentTheme)
        net.Send(ply)

        if RE4M_STATE.GameState == GAMESTATE_MENU or
           RE4M_STATE.GameState == GAMESTATE_WAITING then
            net.Start("RE4M_ForceMenu")
            net.Send(ply)
        end
    end)

    -- FIX #8: This block was AFTER the timer in the original, meaning it ran
    -- instantly. Moving the state transition outside the timer is correct, but
    -- be aware this fires before the 3-second timer above completes. That is
    -- intentional: we want the state to change immediately.
    if RE4M_STATE.GameState == GAMESTATE_WAITING then
        RE4M_SetGameState(GAMESTATE_MENU)
    end
end

function GM:PlayerSpawn(ply)
    local cfg = RE4MERCS_GetConfig()
    if not cfg then return end  -- FIX #9: Guard against nil config

    ply:SetHealth(cfg.PlayerHealth   or 150)
    ply:SetArmor(cfg.PlayerArmor     or 50)
    ply:SetRunSpeed(cfg.PlayerRunSpeed  or 300)
    ply:SetWalkSpeed(cfg.PlayerWalkSpeed or 200)
    ply:SetJumpPower(200)

    if ply.RE4M_Playermodel and ply.RE4M_Playermodel ~= "" then
        ply:SetModel(ply.RE4M_Playermodel)
    end

    if ply.RE4M_Skin then
        ply:SetSkin(ply.RE4M_Skin)
    end

    if ply.RE4M_Bodygroups and ply.RE4M_Bodygroups ~= "" then
        local bodygroups = RE4M_ParseBodygroups(ply.RE4M_Bodygroups)
        for i, val in ipairs(bodygroups) do
            ply:SetBodygroup(i - 1, val)
        end
    end

    if ply.RE4M_PlayerColor then
        ply:SetPlayerColor(ply.RE4M_PlayerColor)
    end

    timer.Simple(0.1, function()
        if IsValid(ply) then
            ply:SetupHands()
        end
    end)

    if RE4M_STATE.GameState ~= GAMESTATE_ACTIVE then
        timer.Simple(0.1, function()
            if IsValid(ply) then
                ply:Freeze(true)
                ply:StripWeapons()
            end
        end)
    else
        RE4M_GiveLoadout(ply)
    end
end

function GM:PlayerSetModel(ply)
    if ply.RE4M_Playermodel and ply.RE4M_Playermodel ~= "" then
        ply:SetModel(ply.RE4M_Playermodel)
    end

    if ply.RE4M_Skin then
        ply:SetSkin(ply.RE4M_Skin)
    end

    if ply.RE4M_Bodygroups and ply.RE4M_Bodygroups ~= "" then
        local bodygroups = RE4M_ParseBodygroups(ply.RE4M_Bodygroups)
        for i, val in ipairs(bodygroups) do
            ply:SetBodygroup(i - 1, val)
        end
    end

    if ply.RE4M_PlayerColor then
        ply:SetPlayerColor(ply.RE4M_PlayerColor)
    end
end

function RE4M_GiveLoadout(ply)
    if not IsValid(ply) then return end

    ply:StripWeapons()
    ply:RemoveAllAmmo()

    local cfg = RE4MERCS_GetConfig()
    local loadout = ply.RE4M_Loadout or {}

    if #loadout == 0 then
        ply:Give("weapon_pistol")
        ply:Give("weapon_smg1")
        ply:Give("weapon_crowbar")
        ply:GiveAmmo(cfg.FallbackPistolAmmo or 60, "Pistol")
        ply:GiveAmmo(cfg.FallbackSMGAmmo or 90, "SMG1")
        return
    end

    for _, weaponClass in ipairs(loadout) do
        if weaponClass and weaponClass ~= "" then
            local wep = ply:Give(weaponClass)

            if IsValid(wep) then
                local primaryAmmo   = wep:GetPrimaryAmmoType()
                local secondaryAmmo = wep:GetSecondaryAmmoType()

                -- -1 means "no ammo", 0+ is a valid ammo type index.
                if primaryAmmo and primaryAmmo >= 0 then
                    ply:GiveAmmo(cfg.StartingPrimaryAmmo or 90, primaryAmmo)
                end
                if secondaryAmmo and secondaryAmmo >= 0 then
                    ply:GiveAmmo(cfg.StartingSecondaryAmmo or 30, secondaryAmmo)
                end
            end
        end
    end
end

-- FIX #11: GM:PlayerLoadout returning true tells the engine to skip the
-- default loadout assignment. This is correct, but the function receives
-- the player as an argument. Add the parameter for clarity and correctness.
function GM:PlayerLoadout(ply)
    return true
end

function GM:PlayerDeathThink(ply)
    if RE4M_STATE.GameState == GAMESTATE_ACTIVE then
        local cfg = RE4MERCS_GetConfig()
        -- FIX #12: Guard cfg before indexing it.
        if cfg and not cfg.RespawnEnabled then
            return false
        end
    end

    if ply:KeyDown(IN_ATTACK) or ply:KeyDown(IN_JUMP) then
        --// ply:Spawn()
    end

    return false
end

function GM:PlayerDeath(ply, inflictor, attacker)
    if RE4M_STATE.GameState == GAMESTATE_ACTIVE then
        local anyAlive = false
        for _, p in ipairs(player.GetAll()) do
            -- FIX #14: We must also check p != ply here because ply is already
            -- dead at this point but Alive() may still return true for one
            -- tick. The original did have this check - confirmed correct.
            if p:Alive() and p ~= ply then
                anyAlive = true
                break
            end
        end

        if not anyAlive then
            timer.Simple(2, function()
                RE4M_EndRound()
            end)
        end
    end
end

function GM:CanPlayerSuicide(ply)
    return false
end

function GM:PlayerDisconnected(ply)
    if RE4M_STATE.GameState == GAMESTATE_ACTIVE then
        timer.Simple(1, function()
            local players = player.GetAll()

            if #players == 0 then
                RE4M_EndRound()
                return
            end

            local anyAlive = false
            for _, p in ipairs(players) do
                if IsValid(p) and p:Alive() then  -- FIX #15: Validate p inside the loop
                    anyAlive = true
                    break
                end
            end

            if not anyAlive then
                RE4M_EndRound()
            end
        end)
    end
end

-- ============================================
-- NET MESSAGE HANDLERS
-- ============================================

net.Receive("RE4M_SetLoadout", function(len, ply)
    -- FIX #16: Validate ply at the top of every net.Receive callback.
    -- A malformed or spoofed packet could arrive with an invalid player.
    if not IsValid(ply) then return end

    local count   = net.ReadUInt(4)
    local loadout = {}

    -- FIX #17: count comes from the client. Cap it to the bit-width maximum
    -- (4 bits = 15) so a malicious client cannot cause a huge loop.
    count = math.Clamp(count, 0, 15)

    for i = 1, count do
        local class = net.ReadString()
        if class and class ~= "" then
            table.insert(loadout, class)
        end
    end

    local cfg      = RE4MERCS_GetConfig()
    local maxSlots = cfg and cfg.MaxWeaponSlots or 3

    while #loadout > maxSlots do
        table.remove(loadout)
    end

    ply.RE4M_Loadout = loadout

    if RE4MERCS_CONFIG and RE4MERCS_CONFIG.Debug then
        print("[RE4 Mercs] " .. ply:Nick() .. " set loadout: " .. table.concat(loadout, ", "))
    end
end)

net.Receive("RE4M_SetPlayermodel", function(len, ply)
    if not IsValid(ply) then return end  -- FIX #18: Validate ply

    local model = net.ReadString()
    if not model or model == "" or not util.IsValidModel(model) then return end

    ply.RE4M_Playermodel = model

    if IsValid(ply) and ply:Alive() then
        ply:SetModel(model)
        timer.Simple(0.05, function()
            if IsValid(ply) then
                ply:SetupHands()
            end
        end)
    end

    local handsInfo         = RE4M_GetHandsForModel(model)
    ply.RE4M_HandsModel     = handsInfo.model
    ply.RE4M_HandsSkin      = handsInfo.skin
    ply.RE4M_HandsBody      = handsInfo.body

    if RE4MERCS_CONFIG and RE4MERCS_CONFIG.Debug then
        print("[RE4 Mercs] " .. ply:Nick() .. " set model: " .. model)
        print("[RE4 Mercs]   → Hands: " .. handsInfo.model)
    end
end)

net.Receive("RE4M_PlayerReady", function(len, ply)
    if not IsValid(ply) then return end  -- FIX #19: Validate ply

    ply.RE4M_Ready = net.ReadBool()
    ply:SetNWBool("RE4M_Ready", ply.RE4M_Ready)
end)

net.Receive("RE4M_StartGame", function(len, ply)
    if not IsValid(ply) then return end  -- FIX #20: Validate ply

    if not ply:RE4M_IsAdmin() then return end

    if RE4M_STATE.GameState == GAMESTATE_MENU or
       RE4M_STATE.GameState == GAMESTATE_WAITING then
        RE4M_StartPreRound()
    end
end)

net.Receive("RE4M_SetTheme", function(len, ply)
    if not IsValid(ply) then return end  -- FIX #21: Validate ply

    if not ply:RE4M_IsAdmin() then return end

    local theme = net.ReadString()
    local cfg   = RE4MERCS_GetConfig()

    -- FIX #22: Guard cfg and EnabledThemes before iterating.
    if not cfg then return end

    local valid = false
    for _, t in ipairs(cfg.EnabledThemes or {}) do
        if t == theme then
            valid = true
            break
        end
    end

    if valid then
        RE4M_STATE.CurrentTheme = theme

        net.Start("RE4M_ThemeInfo")
            net.WriteString(theme)
        net.Broadcast()

        if RE4MERCS_CONFIG and RE4MERCS_CONFIG.Debug then
            print("[RE4 Mercs] Theme set to: " .. theme)
        end
    end
end)

net.Receive("RE4M_SetCustomNPCs", function(len, ply)
    if not IsValid(ply) then return end  -- FIX #23: Validate ply

    if not ply:RE4M_IsAdmin() then return end

    local regularCount = net.ReadUInt(8)
    -- FIX #24: Cap counts from clients to prevent oversized loops.
    regularCount = math.Clamp(regularCount, 0, 255)

    local regular = {}
    for i = 1, regularCount do
        table.insert(regular, net.ReadString())
    end

    local eliteCount = net.ReadUInt(8)
    eliteCount = math.Clamp(eliteCount, 0, 255)

    local elite = {}
    for i = 1, eliteCount do
        table.insert(elite, net.ReadString())
    end

    local cfg = RE4MERCS_GetConfig()
    if not cfg then return end  -- FIX #25: Guard cfg

    cfg.ThemeNPCs         = cfg.ThemeNPCs or {}
    cfg.ThemeNPCs.custom  = {
        regular = regular,
        elite   = elite,
    }

    if RE4MERCS_CONFIG and RE4MERCS_CONFIG.Debug then
        print("[RE4 Mercs] Custom NPCs set: " .. #regular .. " regular, " .. #elite .. " elite")
    end
end)



-- ============================================
-- PLAYER CUSTOMIZATION NET RECEIVERS
-- ============================================

net.Receive("RE4M_SetPlayerHands", function(len, ply)
    if not IsValid(ply) then return end  -- FIX #26: Validate ply

    local handsModel = net.ReadString()
    local handsSkin  = net.ReadUInt(8)
    local handsBody  = net.ReadString()

    if handsModel and handsModel ~= "" and util.IsValidModel(handsModel) then
        ply.RE4M_HandsModel = handsModel
        ply.RE4M_HandsSkin  = handsSkin or 0
        ply.RE4M_HandsBody  = handsBody or "0000000"

        if IsValid(ply) and ply:Alive() then
            timer.Simple(0.05, function()
                if IsValid(ply) then ply:SetupHands() end
            end)
        end
    end
end)

net.Receive("RE4M_SetPlayerBodygroups", function(len, ply)
    if not IsValid(ply) then return end  -- FIX #27: Validate ply

    local bgString = net.ReadString()

    ply.RE4M_Bodygroups = bgString

    if IsValid(ply) and ply:Alive() then
        local bodygroups = RE4M_ParseBodygroups(bgString)
        for i, val in ipairs(bodygroups) do
            ply:SetBodygroup(i - 1, val)
        end
    end

    if RE4MERCS_CONFIG and RE4MERCS_CONFIG.Debug then
        print("[RE4 Mercs] " .. ply:Nick() .. " set bodygroups: " .. bgString)
    end
end)

net.Receive("RE4M_SetPlayerSkin", function(len, ply)
    if not IsValid(ply) then return end  -- FIX #28: Validate ply

    local skin = net.ReadUInt(8)

    ply.RE4M_Skin = skin

    if IsValid(ply) and ply:Alive() then
        ply:SetSkin(skin)
    end

    if RE4MERCS_CONFIG and RE4MERCS_CONFIG.Debug then
        print("[RE4 Mercs] " .. ply:Nick() .. " set skin: " .. skin)
    end
end)

net.Receive("RE4M_SetPlayerColor", function(len, ply)
    if not IsValid(ply) then return end  -- FIX #29: Validate ply

    local r = net.ReadFloat()
    local g = net.ReadFloat()
    local b = net.ReadFloat()

    -- FIX #30: Clamp color components so a client cannot send NaN or huge
    -- values that could corrupt SetPlayerColor.
    r = math.Clamp(r, 0, 1)
    g = math.Clamp(g, 0, 1)
    b = math.Clamp(b, 0, 1)

    ply.RE4M_PlayerColor = Vector(r, g, b)

    if IsValid(ply) and ply:Alive() then
        ply:SetPlayerColor(Vector(r, g, b))
    end
end)

-- ============================================
-- HANDS HOOK
-- ============================================

function GM:PlayerSetHandsModel(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then return end

    -- Priority 1: Explicitly stored hands from the menu
    if ply.RE4M_HandsModel and ply.RE4M_HandsModel ~= "" then
        ent:SetModel(ply.RE4M_HandsModel)
        ent:SetSkin(ply.RE4M_HandsSkin or 0)
        ent:SetBodyGroups(ply.RE4M_HandsBody or "0000000")
        return
    end

    -- Priority 2: Resolve from current playermodel
    local currentModel = ply:GetModel()
    if currentModel and currentModel ~= "" then
        local info = RE4M_GetHandsForModel(currentModel)
        ent:SetModel(info.model)
        ent:SetSkin(info.skin)
        ent:SetBodyGroups(info.body)
        return
    end

    -- Priority 3: player_manager system
    local simplemodel = player_manager.TranslateToPlayerModelName(ply:GetModel())
    local info        = player_manager.TranslatePlayerHands(simplemodel)

    if info then
        ent:SetModel(info.model)
        ent:SetSkin(info.skin)
        ent:SetBodyGroups(info.body)
        return
    end

    -- Fallback
    ent:SetModel("models/weapons/c_arms_citizen.mdl")
end

-- ============================================
-- DISABLE DEFAULT BEHAVIORS
-- ============================================

function GM:PlayerNoClip(ply)
    return ply:RE4M_IsAdmin()
end

-- FIX #31: PlayerSpawnProp, PlayerSpawnSENT etc. must return a BOOLEAN.
-- Returning "RE4M_STATE.GameState ~= GAMESTATE_ACTIVE" already produces a
-- boolean in Lua, so those were correct. But for consistency and clarity,
-- all the "return false" hooks are confirmed correct as-is.
function GM:PlayerSpawnProp(ply)
    return RE4M_STATE.GameState ~= GAMESTATE_ACTIVE
end

function GM:PlayerSpawnSENT(ply)
    return false
end

function GM:PlayerSpawnSWEP(ply)
    return false
end

function GM:PlayerGiveSWEP(ply)
    return false
end

function GM:PlayerSpawnNPC(ply)
    return false
end

function GM:PlayerSpawnVehicle(ply)
    return false
end

function GM:PlayerSpawnRagdoll(ply)
    return false
end

function GM:PlayerSpawnEffect(ply)
    return false
end

-- ============================================
-- CONSOLE COMMANDS
-- ============================================

concommand.Add("re4m_start", function(ply, cmd, args)
    -- FIX #32: IsValid(ply) is false for the server console (ply == NULL entity).
    -- Use the pattern: if IsValid(ply) check admin, else always allow (server console).
    if IsValid(ply) and not ply:RE4M_IsAdmin() then
        ply:ChatPrint("[RE4 Mercs] Admin only command.")
        return
    end

    if RE4M_STATE.GameState == GAMESTATE_MENU or
       RE4M_STATE.GameState == GAMESTATE_WAITING then
        RE4M_StartPreRound()
    else
        if IsValid(ply) then
            ply:ChatPrint("[RE4 Mercs] Round already in progress or ending.")
        else
            print("[RE4 Mercs] Round already in progress or ending.")
        end
    end
end)

concommand.Add("re4m_stop", function(ply, cmd, args)
    if IsValid(ply) and not ply:RE4M_IsAdmin() then
        ply:ChatPrint("[RE4 Mercs] Admin only command.")
        return
    end

    RE4M_EndRound()
end)

concommand.Add("re4m_theme", function(ply, cmd, args)
    if IsValid(ply) and not ply:RE4M_IsAdmin() then return end

    if args[1] then
        RE4M_STATE.CurrentTheme = args[1]

        net.Start("RE4M_ThemeInfo")
            net.WriteString(args[1])
        net.Broadcast()

        local msg = "[RE4 Mercs] Theme set to: " .. args[1]
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
    end
end)

concommand.Add("re4m_rebuild_weapons", function(ply, cmd, args)
    if IsValid(ply) and not ply:RE4M_IsAdmin() then return end

    RE4M_BuildWeaponList()

    for _, p in ipairs(player.GetAll()) do
        RE4M_SendWeaponList(p)
    end

    local msg = "[RE4 Mercs] Weapon list rebuilt: " .. #RE4M_WeaponCache .. " weapons"
    if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
end)

concommand.Add("re4m_debug", function(ply, cmd, args)
    if IsValid(ply) and not ply:RE4M_IsAdmin() then return end

    -- FIX #33: RE4MERCS_CONFIG could be nil if shared.lua never ran.
    if not RE4MERCS_CONFIG then
        local msg = "[RE4 Mercs] RE4MERCS_CONFIG is nil - shared.lua may not have loaded."
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
        return
    end

    RE4MERCS_CONFIG.Debug = not RE4MERCS_CONFIG.Debug
    local msg = "[RE4 Mercs] Debug mode: " .. tostring(RE4MERCS_CONFIG.Debug)
    if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
end)

concommand.Add("re4m_check_navmesh", function(ply, cmd, args)
    if IsValid(ply) and not ply:RE4M_IsAdmin() then return end

    local result = RE4M_CheckNavmesh()
    local areas  = navmesh.GetAllNavAreas()
    local count  = areas and #areas or 0

    local msg = "[RE4 Mercs] Navmesh check: " .. count .. " areas | Valid = " .. tostring(result)
    if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
end)