-- Persistent player and weapon progression.

local DATA_DIRECTORY = "re4mercs"
local DATA_FILE = DATA_DIRECTORY .. "/player_progression.json"
local SAVE_TIMER = "RE4M_SaveProgression"
-- Results XP is intentionally modest; at this curve leveling takes sustained play.
local PLAYER_XP_PER_LEVEL = 10000
local WEAPON_XP_PER_KILL = 100
local WEAPON_XP_PER_LEVEL = 1000
local WEAPON_DAMAGE_PER_LEVEL = 0.01
local MAX_WEAPON_DAMAGE_BONUS = 0.5

RE4M_Progression = { players = {} }

local function NewPlayerProfile()
    return { level = 1, xp = 0, totalXP = 0, mercPoints = 0, ownedSkills = {}, equippedSkills = {}, weapons = {} }
end

function RE4M_GetMPRewardForLevel(level)
    level = math.floor(tonumber(level) or 1)
    if level == 100 then return 18 end
    if level > 100 then return 10 end
    if level == 90 then return 14 end
    if level >= 91 and level <= 99 then return 9 end
    if level == 80 then return 12 end
    if level >= 81 and level <= 89 then return 7 end
    if level >= 71 and level <= 79 then return 6 end
    if level >= 10 and level <= 70 and level % 10 == 0 then return 10 end
    if level >= 2 and level <= 69 then return 5 end
    return 0
end

local function NormalizeProfile(profile)
    if not istable(profile) then return NewPlayerProfile() end

    profile.level = math.max(1, math.floor(tonumber(profile.level) or 1))
    profile.xp = math.max(0, math.floor(tonumber(profile.xp) or 0))
    profile.totalXP = math.max(0, math.floor(tonumber(profile.totalXP) or profile.xp))
    profile.mercPoints = math.max(0, math.floor(tonumber(profile.mercPoints) or 0))
    if not istable(profile.weapons) then profile.weapons = {} end

    local owned, equipped = {}, {}
    for _, skillID in ipairs(istable(profile.ownedSkills) and profile.ownedSkills or {}) do
        if RE4M_SKILLS_BY_ID and RE4M_SKILLS_BY_ID[skillID] then owned[skillID] = true end
    end
    for _, skillID in ipairs(istable(profile.equippedSkills) and profile.equippedSkills or {}) do
        if #equipped >= 3 then break end
        if owned[skillID] and not table.HasValue(equipped, skillID) then equipped[#equipped + 1] = skillID end
    end
    profile.ownedSkills = {}
    for skillID in pairs(owned) do profile.ownedSkills[#profile.ownedSkills + 1] = skillID end
    table.sort(profile.ownedSkills)
    profile.equippedSkills = equipped

    local normalizedWeapons = {}
    for class, weapon in pairs(profile.weapons) do
        if isstring(class) and #class <= 128 and istable(weapon) then
            normalizedWeapons[class] = {
                level = math.max(1, math.floor(tonumber(weapon.level) or 1)),
                xp = math.max(0, math.floor(tonumber(weapon.xp) or 0)),
                kills = math.max(0, math.floor(tonumber(weapon.kills) or 0)),
            }
        end
    end
    profile.weapons = normalizedWeapons
    return profile
end

function RE4M_LoadProgression()
    file.CreateDir(DATA_DIRECTORY)
    if not file.Exists(DATA_FILE, "DATA") then return end

    local contents = file.Read(DATA_FILE, "DATA")
    local decoded = contents and util.JSONToTable(contents)
    if not istable(decoded) or not istable(decoded.players) then
        ErrorNoHalt("[RE4 Mercs] Progression JSON is invalid; starting with empty profiles.\n")
        return
    end

    for steamID, profile in pairs(decoded.players) do
        if isstring(steamID) and #steamID <= 32 then
            RE4M_Progression.players[steamID] = NormalizeProfile(profile)
        end
    end
end

function RE4M_SaveProgression()
    if not RE4M_Progression then return end
    file.CreateDir(DATA_DIRECTORY)
    local encoded = util.TableToJSON(RE4M_Progression, true)
    if not encoded then
        ErrorNoHalt("[RE4 Mercs] Failed to encode progression profiles.\n")
        return
    end
    file.Write(DATA_FILE, encoded)
end

local function ScheduleSave()
    if timer.Exists(SAVE_TIMER) then return end
    timer.Create(SAVE_TIMER, 2, 1, RE4M_SaveProgression)
end

function RE4M_GetPlayerProfile(ply)
    if not IsValid(ply) then return nil end
    local steamID = ply:SteamID64()
    if not steamID or steamID == "0" then steamID = ply:SteamID() end
    if not steamID or steamID == "" then return nil end

    local players = RE4M_Progression.players
    players[steamID] = players[steamID] or NewPlayerProfile()
    return players[steamID], steamID
end

local function ApplyPlayerProfile(ply, profile)
    if not IsValid(ply) or not profile then return end
    ply:SetNWInt("RE4M_PlayerLevel", profile.level)
    ply:SetNWInt("RE4M_PlayerXP", profile.xp)
    ply:SetNWInt("RE4M_MercPoints", profile.mercPoints or 0)
    ply:SetNWString("RE4M_OwnedSkills", util.TableToJSON(profile.ownedSkills or {}) or "[]")
    for slot = 1, 3 do
        ply:SetNWString("RE4M_EquippedSkill" .. slot, profile.equippedSkills and profile.equippedSkills[slot] or "")
    end
    local activeWeapon = ply:GetActiveWeapon()
    local activeProfile = IsValid(activeWeapon) and profile.weapons[activeWeapon:GetClass()] or nil
    ply:SetNWInt("RE4M_ActiveWeaponLevel", activeProfile and activeProfile.level or 1)
end

function RE4M_ApplyPlayerProgression(ply)
    local profile = RE4M_GetPlayerProfile(ply)
    ApplyPlayerProfile(ply, profile)
end

function RE4M_GetWeaponProfile(ply, weaponClass)
    if not IsValid(ply) or not isstring(weaponClass) or weaponClass == "" then return nil end
    local profile = RE4M_GetPlayerProfile(ply)
    if not profile then return nil end
    profile.weapons[weaponClass] = profile.weapons[weaponClass] or { level = 1, xp = 0, kills = 0 }
    return profile.weapons[weaponClass]
end

function RE4M_GetWeaponLevel(ply, weaponClass)
    local weapon = RE4M_GetWeaponProfile(ply, weaponClass)
    return weapon and weapon.level or 1
end

function RE4M_AwardPlayerXP(ply, amount)
    local profile = RE4M_GetPlayerProfile(ply)
    if not profile then return 0 end

    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if amount <= 0 then
        ApplyPlayerProfile(ply, profile)
        return 0, 0
    end

    local startingMP = profile.mercPoints or 0
    profile.xp = profile.xp + amount
    profile.totalXP = profile.totalXP + amount
    while profile.xp >= profile.level * PLAYER_XP_PER_LEVEL do
        profile.xp = profile.xp - profile.level * PLAYER_XP_PER_LEVEL
        profile.level = profile.level + 1
        profile.mercPoints = (profile.mercPoints or 0) + RE4M_GetMPRewardForLevel(profile.level)
    end
    ApplyPlayerProfile(ply, profile)
    ScheduleSave()
    return amount, (profile.mercPoints or 0) - startingMP
end

function RE4M_SetPlayerLevel(ply, level)
    local profile = RE4M_GetPlayerProfile(ply)
    if not profile then return false end
    profile.level = math.Clamp(math.floor(tonumber(level) or 1), 1, 1000000)
    profile.xp = 0
    profile.totalXP = (profile.level - 1) * profile.level / 2 * PLAYER_XP_PER_LEVEL
    ApplyPlayerProfile(ply, profile)
    ScheduleSave()
    RE4M_SendLobbyProgression()
    RE4M_SendLobbyProgression(ply, true)
    return true
end

function RE4M_RemovePlayerXP(ply, amount)
    local profile = RE4M_GetPlayerProfile(ply)
    if not profile then return 0 end
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    local oldTotal = profile.totalXP
    profile.totalXP = math.max(0, profile.totalXP - amount)
    local remaining = profile.totalXP
    profile.level = 1
    profile.xp = remaining
    while profile.level < 1000000 and profile.xp >= profile.level * PLAYER_XP_PER_LEVEL do
        profile.xp = profile.xp - profile.level * PLAYER_XP_PER_LEVEL
        profile.level = profile.level + 1
    end
    ApplyPlayerProfile(ply, profile)
    ScheduleSave()
    RE4M_SendLobbyProgression()
    RE4M_SendLobbyProgression(ply, true)
    return oldTotal - profile.totalXP
end

local function FindProgressionTarget(query)
    query = string.Trim(string.lower(tostring(query or "")))
    if query == "" then return nil end
    for _, target in ipairs(player.GetAll()) do
        if IsValid(target) and (string.lower(target:Nick()) == query or
            string.lower(target:SteamID()) == query or string.lower(target:SteamID64()) == query) then
            return target
        end
    end
    for _, target in ipairs(player.GetAll()) do
        if IsValid(target) and string.find(string.lower(target:Nick()), query, 1, true) then return target end
    end
end

local function AdminProgressionCommand(ply, cmd, args)
    if IsValid(ply) and (not ply.RE4M_IsAdmin or not ply:RE4M_IsAdmin()) then
        ply:ChatPrint("[RE4 Mercs] Admin access required.")
        return false
    end
    return true
end

local function AddPlayerTargetCommand(name, callback, optionalAmount)
    concommand.Add(name, function(ply, cmd, args)
        if not AdminProgressionCommand(ply, cmd, args) then return end
        if #args < (optionalAmount and 1 or 2) then
            local usage = "Usage: " .. name .. " <player>" .. (optionalAmount and " [amount]" or " <amount>")
            if IsValid(ply) then ply:ChatPrint(usage) else print(usage) end
            return
        end
        local amount = tonumber(args[#args])
        local queryEnd = amount and (#args - 1) or #args
        local query = table.concat(args, " ", 1, queryEnd)
        if queryEnd == 0 then query = args[1] end
        local target = FindProgressionTarget(query)
        if not IsValid(target) then
            local message = "[RE4 Mercs] Player not found: " .. query
            if IsValid(ply) then ply:ChatPrint(message) else print(message) end
            return
        end
        if amount == nil and optionalAmount then amount = 1 end
        if amount == nil then return end
        callback(target, math.max(0, math.floor(amount)))
        local message = "[RE4 Mercs] Updated progression for " .. target:Nick() .. "."
        if IsValid(ply) then ply:ChatPrint(message) else print(message) end
    end, nil, "Admin progression control")
end

AddPlayerTargetCommand("re4m_setlevel", function(target, amount) RE4M_SetPlayerLevel(target, amount) end)
AddPlayerTargetCommand("re4m_givexp", function(target, amount) RE4M_AwardPlayerXP(target, amount) end)
AddPlayerTargetCommand("re4m_removexp", function(target, amount) RE4M_RemovePlayerXP(target, amount) end)
AddPlayerTargetCommand("re4m_delevel", function(target, amount)
    local profile = RE4M_GetPlayerProfile(target)
    RE4M_SetPlayerLevel(target, math.max(1, (profile and profile.level or 1) - amount))
end, true)
AddPlayerTargetCommand("re4m_givemp", function(target, amount)
    local profile = RE4M_GetPlayerProfile(target)
    if not profile then return end
    profile.mercPoints = profile.mercPoints + amount
    ApplyPlayerProfile(target, profile)
    ScheduleSave()
    RE4M_SendLobbyProgression()
    RE4M_SendLobbyProgression(target, true)
end)
AddPlayerTargetCommand("re4m_setmp", function(target, amount)
    local profile = RE4M_GetPlayerProfile(target)
    if not profile then return end
    profile.mercPoints = amount
    ApplyPlayerProfile(target, profile)
    ScheduleSave()
    RE4M_SendLobbyProgression()
    RE4M_SendLobbyProgression(target, true)
end)
AddPlayerTargetCommand("re4m_removemp", function(target, amount)
    local profile = RE4M_GetPlayerProfile(target)
    if not profile then return end
    profile.mercPoints = math.max(0, profile.mercPoints - amount)
    ApplyPlayerProfile(target, profile)
    ScheduleSave()
    RE4M_SendLobbyProgression()
    RE4M_SendLobbyProgression(target, true)
end)

function RE4M_RecordWeaponKill(ply, weaponClass)
    if not IsValid(ply) or not isstring(weaponClass) or weaponClass == "" then return end
    local weapon = RE4M_GetWeaponProfile(ply, weaponClass)
    if not weapon then return end

    weapon.kills = weapon.kills + 1
    weapon.xp = weapon.xp + WEAPON_XP_PER_KILL
    local previousLevel = weapon.level
    while weapon.xp >= weapon.level * WEAPON_XP_PER_LEVEL do
        weapon.xp = weapon.xp - weapon.level * WEAPON_XP_PER_LEVEL
        weapon.level = weapon.level + 1
    end
    local activeWeapon = ply:GetActiveWeapon()
    if IsValid(activeWeapon) and activeWeapon:GetClass() == weaponClass then
        ply:SetNWInt("RE4M_ActiveWeaponLevel", weapon.level)
    end
    ScheduleSave()
    if weapon.level ~= previousLevel and RE4M_SendLobbyProgression then
        RE4M_SendLobbyProgression()
        RE4M_SendLobbyProgression(ply, true)
    end
end

local function UpdateActiveWeaponLevel(ply)
    if not IsValid(ply) then return end
    local activeWeapon = ply:GetActiveWeapon()
    local weapon = IsValid(activeWeapon) and RE4M_GetWeaponProfile(ply, activeWeapon:GetClass()) or nil
    ply:SetNWInt("RE4M_ActiveWeaponLevel", weapon and weapon.level or 1)
end

hook.Add("PlayerSwitchWeapon", "RE4M_SyncActiveWeaponLevel", function(ply)
    timer.Simple(0, function()
        if IsValid(ply) then UpdateActiveWeaponLevel(ply) end
    end)
end)

hook.Add("PlayerSpawn", "RE4M_SyncSpawnedWeaponLevel", function(ply)
    timer.Simple(0.1, function()
        if IsValid(ply) then UpdateActiveWeaponLevel(ply) end
    end)
end)

function RE4M_PlayerHasSkill(ply, skillID)
    if not IsValid(ply) then return false end
    local profile = RE4M_GetPlayerProfile(ply)
    if not profile then return false end
    for _, equipped in ipairs(profile.equippedSkills or {}) do
        if equipped == skillID then return true end
    end
    return false
end

local function BroadcastSkillChange(ply)
    local profile = RE4M_GetPlayerProfile(ply)
    if profile then ApplyPlayerProfile(ply, profile) end
    -- Skill purchases/equip changes should survive a restart immediately.
    RE4M_SaveProgression()
    RE4M_SendLobbyProgression()
    RE4M_SendLobbyProgression(ply, true)
end

local function SendSkillShopResult(ply, success, message)
    if not IsValid(ply) then return end
    net.Start("RE4M_SkillShopResult")
        net.WriteBool(success)
        net.WriteString(message)
    net.Send(ply)
end

net.Receive("RE4M_BuySkill", function(_, ply)
    local skillID = net.ReadString()
    local skill = RE4M_SKILLS_BY_ID and RE4M_SKILLS_BY_ID[skillID]
    local profile = RE4M_GetPlayerProfile(ply)
    if not skill or not profile or profile.ownedSkills == nil then
        SendSkillShopResult(ply, false, "That skill could not be found.")
        return
    end
    if table.HasValue(profile.ownedSkills, skillID) then
        SendSkillShopResult(ply, false, "You already own this skill.")
        return
    end
    if profile.mercPoints < skill.cost then
        SendSkillShopResult(ply, false, "Not enough MP. You have " .. profile.mercPoints .. "; this skill costs " .. skill.cost .. ".")
        RE4M_SendLobbyProgression(ply, true)
        return
    end
    profile.mercPoints = profile.mercPoints - skill.cost
    profile.ownedSkills[#profile.ownedSkills + 1] = skillID
    ApplyPlayerProfile(ply, profile)
    BroadcastSkillChange(ply)
    SendSkillShopResult(ply, true, skill.name .. " purchased. Open Equipped Skills to equip it.")
end)

net.Receive("RE4M_ToggleSkill", function(_, ply)
    local skillID = net.ReadString()
    local profile = RE4M_GetPlayerProfile(ply)
    local skill = RE4M_SKILLS_BY_ID and RE4M_SKILLS_BY_ID[skillID]
    if not profile or not skill or not table.HasValue(profile.ownedSkills or {}, skillID) then
        SendSkillShopResult(ply, false, "You need to buy that skill first.")
        return
    end
    local found
    for i, equipped in ipairs(profile.equippedSkills) do
        if equipped == skillID then table.remove(profile.equippedSkills, i); found = true; break end
    end
    if not found then
        if #profile.equippedSkills >= 3 then
            SendSkillShopResult(ply, false, "You can equip only three skills. Unequip one first.")
            return
        end
        profile.equippedSkills[#profile.equippedSkills + 1] = skillID
    end
    BroadcastSkillChange(ply)
    SendSkillShopResult(ply, true, found and (skill.name .. " unequipped.") or (skill.name .. " equipped."))
end)

net.Receive("RE4M_SetEquippedSkills", function(_, ply)
    local count = net.ReadUInt(2)
    if count > 3 then
        SendSkillShopResult(ply, false, "You can equip only three skills.")
        return
    end

    local requested, seen = {}, {}
    for _ = 1, count do
        local skillID = net.ReadString()
        local skill = RE4M_SKILLS_BY_ID and RE4M_SKILLS_BY_ID[skillID]
        if not skill or seen[skillID] then
            SendSkillShopResult(ply, false, "Invalid or duplicate skill selection.")
            return
        end
        seen[skillID] = true
        requested[#requested + 1] = skillID
    end

    local profile = RE4M_GetPlayerProfile(ply)
    if not profile then
        SendSkillShopResult(ply, false, "Your progression profile is unavailable.")
        return
    end
    for _, skillID in ipairs(requested) do
        if not table.HasValue(profile.ownedSkills or {}, skillID) then
            SendSkillShopResult(ply, false, "You need to buy every selected skill first.")
            return
        end
    end

    profile.equippedSkills = requested
    BroadcastSkillChange(ply)
    SendSkillShopResult(ply, true, "Equipped skills saved.")
end)

local function ResolveWeaponClass(attacker, inflictor)
    if IsValid(inflictor) and inflictor:IsWeapon() then
        return inflictor:GetClass()
    end
    if IsValid(attacker) and attacker:IsPlayer() then
        local activeWeapon = attacker:GetActiveWeapon()
        if IsValid(activeWeapon) then return activeWeapon:GetClass() end
    end
    return nil
end

hook.Add("EntityTakeDamage", "RE4M_WeaponProgressionDamage", function(target, dmgInfo)
    local attacker = dmgInfo:GetAttacker()
    if IsValid(target) and target:IsPlayer() then
        if RE4M_PlayerHasSkill(target, "last_stand") then dmgInfo:ScaleDamage(1.5) end
        return
    end
    if not IsValid(target) or not target.RE4M_Spawned then return end
    if not IsValid(attacker) or not attacker:IsPlayer() then return end

    local weaponClass = ResolveWeaponClass(attacker, dmgInfo:GetInflictor())
    if not weaponClass then return end

    local level = RE4M_GetWeaponLevel(attacker, weaponClass)
    local bonus = math.min((level - 1) * WEAPON_DAMAGE_PER_LEVEL, MAX_WEAPON_DAMAGE_BONUS)
    local multiplier = 1 + bonus
    local melee = dmgInfo:IsDamageType(DMG_CLUB) or dmgInfo:IsDamageType(DMG_SLASH)
    local lowerClass = string.lower(weaponClass)
    if string.find(lowerClass, "sniper", 1, true) and RE4M_PlayerHasSkill(attacker, "eagle_eye") then
        multiplier = multiplier * 1.15
    end
    if not melee and RE4M_PlayerHasSkill(attacker, "quick_shot") then multiplier = multiplier * 1.10 end
    if melee and RE4M_PlayerHasSkill(attacker, "martial_arts") then multiplier = multiplier * 1.25 end
    if not melee and RE4M_PlayerHasSkill(attacker, "martial_arts") then multiplier = multiplier * 0.9 end
    if melee and RE4M_PlayerHasSkill(attacker, "target_master") then multiplier = multiplier * 0.9 end
    if not melee and RE4M_PlayerHasSkill(attacker, "target_master") then multiplier = multiplier * 1.15 end
    if attacker:Health() <= attacker:GetMaxHealth() * 0.3 and RE4M_PlayerHasSkill(attacker, "second_wind") then multiplier = multiplier * 1.2 end
    if attacker:Health() <= attacker:GetMaxHealth() * 0.2 and RE4M_PlayerHasSkill(attacker, "dying_breath") then multiplier = multiplier * 1.25 end
    if RE4M_PlayerHasSkill(attacker, "last_stand") then multiplier = multiplier * 1.2 end
    if IsValid(target) and target.GetForward then
        local toAttacker = (attacker:GetPos() - target:GetPos()):GetNormalized()
        if target:GetForward():Dot(toAttacker) < -0.25 and RE4M_PlayerHasSkill(attacker, "preemptive_strike") then
            multiplier = multiplier * 1.2
        end
    end
    if target.RE4M_LastDamageAttacker and target.RE4M_LastDamageAttacker ~= attacker and
       target.RE4M_LastDamageAt and CurTime() - target.RE4M_LastDamageAt <= 4 and
       RE4M_PlayerHasSkill(attacker, "blitz_play") then multiplier = multiplier * 1.15 end
    local isAttacking = false
    if isfunction(target.IsAttacking) then
        local ok, result = pcall(target.IsAttacking, target)
        isAttacking = ok and result == true
    end
    if melee and isAttacking and RE4M_PlayerHasSkill(attacker, "power_counter") then
        multiplier = multiplier * 1.25
    end
    if multiplier > 0 then dmgInfo:ScaleDamage(multiplier) end
    target.RE4M_LastDamageAttacker = attacker
    target.RE4M_LastDamageAt = CurTime()
end)

function RE4M_SendLobbyProgression(requester, force)
    if IsValid(requester) and not force and (requester.RE4M_LastProgressionRequest or 0) > CurTime() then return end
    if IsValid(requester) then requester.RE4M_LastProgressionRequest = CurTime() + 1 end

    local summary = {}
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end
        local profile, steamID = RE4M_GetPlayerProfile(ply)
        if not profile then continue end

        local weapons = {}
        local loadout = istable(ply.RE4M_Loadout) and ply.RE4M_Loadout or {}
        if IsValid(requester) and requester == ply then
            for class, weapon in pairs(profile.weapons) do
                weapons[class] = { level = weapon.level, kills = weapon.kills }
            end
        else
            for _, class in ipairs(loadout) do
                local weapon = profile.weapons[class]
                weapons[class] = { level = weapon and weapon.level or 1, kills = weapon and weapon.kills or 0 }
            end
        end

        summary[steamID] = {
            name = ply:Nick(),
            level = profile.level,
            xp = profile.xp,
            mercPoints = profile.mercPoints or 0,
            weapons = weapons,
            loadout = loadout,
            ownedSkills = profile.ownedSkills or {},
            equippedSkills = profile.equippedSkills or {},
        }
    end

    local json = util.TableToJSON(summary)
    local compressed = json and util.Compress(json)
    if not compressed then return end

    net.Start("RE4M_LobbyProgression")
        net.WriteUInt(#compressed, 32)
        net.WriteData(compressed, #compressed)
    if IsValid(requester) then
        net.Send(requester)
    else
        net.Broadcast()
    end
end

net.Receive("RE4M_RequestProgression", function(_, ply)
    RE4M_SendLobbyProgression(ply)
end)

hook.Add("ShutDown", "RE4M_SaveProgressionOnShutdown", RE4M_SaveProgression)
timer.Create("RE4M_NaturalHealing", 1, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or not ply:Alive() or ply:Health() >= ply:GetMaxHealth() then continue end
        local natural = RE4M_PlayerHasSkill(ply, "natural_healing")
        local stationary = RE4M_PlayerHasSkill(ply, "take_it_easy") and ply:GetVelocity():Length2DSqr() < 25
        if not natural and not stationary then ply.RE4M_HealingSeconds = 0; continue end
        ply.RE4M_HealingSeconds = (ply.RE4M_HealingSeconds or 0) + 1
        local interval = stationary and 3 or 5
        if ply.RE4M_HealingSeconds >= interval then
            ply.RE4M_HealingSeconds = 0
            ply:SetHealth(math.min(ply:Health() + 1, ply:GetMaxHealth()))
        end
    end
end)
hook.Add("PlayerAuthed", "RE4M_ApplyProgressionAfterAuth", function(ply)
    timer.Simple(0, function()
        if not IsValid(ply) then return end
        RE4M_ApplyPlayerProgression(ply)
        RE4M_SendLobbyProgression()
    end)
end)

-- Read once for this map session. The same JSON file is written as profiles
-- change and loaded again when the next map session starts.
RE4M_LoadProgression()
