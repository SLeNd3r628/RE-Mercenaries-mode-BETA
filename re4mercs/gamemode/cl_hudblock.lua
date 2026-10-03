-- RE4 Mercenaries Remake - HUD addon blocker (Client)
-- The gamemode draws its own HUD and menus. Sandbox HUD addons (health/ammo
-- HUDs, damage overlays, weapon selectors, scoreboards...) draw on top of it
-- and fight it for input, so while re4m_blockhudaddons is on, every client
-- hook from a file that draws HUD is unhooked. It is restored when the
-- ConVar is turned off.

if SERVER then return end

-- A file that hooks any of these is treated as a HUD/UI file.
local HUD_EVENTS = {
    "HUDPaint", "HUDPaintBackground", "HUDShouldDraw", "PreDrawHUD", "PostDrawHUD",
    "HUDDrawTargetID", "HUDDrawPickupHistory", "HUDItemPickedUp", "HUDWeaponPickedUp",
    "HUDAmmoPickedUp", "DrawDeathNotice", "HUDDrawScoreBoard", "ScoreboardShow", "ScoreboardHide",
}

-- Never touched: this gamemode, Garry's Mod itself, and gameplay systems
-- whose HUD pieces are part of playing (weapon bases, DrGBase possession,
-- wOS animations, this gamemode's content addon). Matched against the
-- lowercase source path of the hook function.
local ALLOWED_PATH_PREFIXES = {
    "gamemodes/re4mercs/", "gamemodes/base/",
    "lua/includes/", "lua/vgui/", "lua/derma/", "lua/skins/", "lua/postprocess/",
    "lua/matproxy/", "lua/menu/", "[c]", "=[c]",
}
local ALLOWED_PATH_KEYWORDS = {
    "/lua/weapons/", "/lua/entities/", "/lua/effects/", "lua/weapons/", "lua/entities/", "lua/effects/",
    "arc9", "arccw", "tacrp", "tfa", "mwb", "mw_base", "mg_base", "cw_2", "cw2", "/cw/", "m9k", "fas2",
    "drgbase", "wos", "dynabase", "re4mercenariescontent", "re4mercs",
    -- Not HUDs: lighting (Real CSM) and weapon laser sights.
    "realcsm", "laserdot",
    -- Code run through RunString has no file, so its owner is unknown.
    "runstring",
}

local blocked = {}        -- blocked[source] = { {event, id, fn}, ... }
local blockedCount = 0

local function HookSource(fn)
    if not isfunction(fn) then return nil end
    local info = debug.getinfo(fn, "S")
    return info and string.lower(string.gsub(info.short_src or info.source or "", "\\", "/")) or nil
end

local function IsAllowed(source)
    if not source or source == "" then return true end
    for _, prefix in ipairs(ALLOWED_PATH_PREFIXES) do
        if string.StartWith(source, prefix) then return true end
    end
    for _, keyword in ipairs(ALLOWED_PATH_KEYWORDS) do
        if string.find(source, keyword, 1, true) then return true end
    end
    return false
end

local function IsBlockingEnabled()
    local cvar = GetConVar("re4m_blockhudaddons")
    return not cvar or cvar:GetBool()
end

function RE4M_ScanHUDAddons()
    if not IsBlockingEnabled() then return end
    local hooks = hook.GetTable()

    -- 1) Which files draw HUD?
    local hudSources = {}
    for _, event in ipairs(HUD_EVENTS) do
        for _, fn in pairs(hooks[event] or {}) do
            local source = HookSource(fn)
            if source and not IsAllowed(source) then hudSources[source] = true end
        end
    end
    if next(hudSources) == nil then return end

    -- 2) Unhook everything those files registered, on every event, so their
    --    input grabs (weapon selectors), movement tweaks etc. go too.
    for event, list in pairs(hooks) do
        for id, fn in pairs(list) do
            local source = HookSource(fn)
            if source and hudSources[source] then
                blocked[source] = blocked[source] or {}
                table.insert(blocked[source], {event = event, id = id, fn = fn})
                hook.Remove(event, id)
                blockedCount = blockedCount + 1
            end
        end
    end

    for source in pairs(hudSources) do
        MsgC(Color(255, 90, 90), "[RE4 Mercs] ", color_white, "Disabled HUD addon file: " .. source .. "\n")
    end
end

local function RestoreHUDAddons()
    for _, entries in pairs(blocked) do
        for _, entry in ipairs(entries) do
            -- Entity/table hook IDs that no longer exist must not be re-added.
            if isstring(entry.id) or IsValid(entry.id) then
                hook.Add(entry.event, entry.id, entry.fn)
            end
        end
    end
    blocked, blockedCount = {}, 0
    MsgC(Color(255, 90, 90), "[RE4 Mercs] ", color_white, "HUD addons restored.\n")
end

-- Addons finish registering hooks at different times; scan after load and
-- keep checking for late additions (cheap: a walk over the hook table).
hook.Add("InitPostEntity", "RE4M_ScanHUDAddons", function()
    RE4M_ScanHUDAddons()
    timer.Simple(2, RE4M_ScanHUDAddons)
end)
timer.Create("RE4M_ScanHUDAddons", 5, 0, function()
    -- Also covers the ConVar being turned off without the change callback
    -- firing on this client.
    if IsBlockingEnabled() then RE4M_ScanHUDAddons()
    elseif blockedCount > 0 then RestoreHUDAddons() end
end)
timer.Simple(0, RE4M_ScanHUDAddons)

cvars.AddChangeCallback("re4m_blockhudaddons", function(_, _, new)
    if tobool(new) then RE4M_ScanHUDAddons() else RestoreHUDAddons() end
end, "RE4M_HUDBlockToggle")

concommand.Add("re4m_hudblock_list", function()
    if blockedCount == 0 then
        print("[RE4 Mercs] No HUD addons are currently disabled.")
        return
    end
    print("[RE4 Mercs] Disabled HUD addon files (" .. blockedCount .. " hooks):")
    for source, entries in SortedPairs(blocked) do
        print("  " .. source .. "  (" .. #entries .. " hooks)")
    end
end, nil, "List the HUD addon files the gamemode has disabled")
