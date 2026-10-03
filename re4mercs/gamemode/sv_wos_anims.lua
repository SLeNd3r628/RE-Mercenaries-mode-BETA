-- RE4 Mercenaries – wOS Animations and Gaemplay Systems

util.AddNetworkString("RE4M_ParryRequest")
util.AddNetworkString("RE4M_PlayParryAnim")
util.AddNetworkString("RE4M_ParryHit") -- for metal flash + parry sound
util.AddNetworkString("RE4M_CounterRequest")
util.AddNetworkString("RE4M_PlayCounterAnim")
util.AddNetworkString("RE4M_DoorKickRequest")
util.AddNetworkString("RE4M_PlayDoorKick")
util.AddNetworkString("RE4M_UsePickupRequest")

local PARRY_COOLDOWN = {}
local COUNTER_COOLDOWN = {}
local DOOR_KICK_COOLDOWN = {}
local OPENED_DOORS = {}
local PICKUP_USE_COOLDOWN = setmetatable({}, {__mode = "k"})
local RE4M_USE_PICKUPS = {
    re_ammopickup = true,
    re_greenherb = true,
    re_timepickup = true,
}

hook.Add("EntityTakeDamage", "RE4M_ActionInvulnerability", function(target)
    if not IsValid(target) or not target:IsPlayer() or RE4M_STATE.GameState ~= GAMESTATE_ACTIVE then return end
    local now = CurTime()
    if target:GetNW2Float("RE4M_ParryTime", 0) > now or
       target:GetNW2Float("RE4M_CounterTime", 0) > now or
       target:GetNW2Float("RE4M_DoorKickTime", 0) > now then
        return true
    end
end)

local function IsRE4MPickup(ent)
    return IsValid(ent) and RE4M_USE_PICKUPS[ent:GetClass()] == true
end

local function RE4M_PlayCounterJumpVOX(ply)
    if not IsValid(ply) or not istable(TFAVOX_Models) or
       not isfunction(TFAVOX_PlayVoicePriority) then return end

    local model = string.lower(ply:GetModel() or "")
    local pack = TFAVOX_Models[ply:GetModel()]
    if not istable(pack) then
        for registeredModel, registeredPack in pairs(TFAVOX_Models) do
            if isstring(registeredModel) and string.lower(registeredModel) == model and istable(registeredPack) then
                pack = registeredPack
                break
            end
        end
    end

    local jumpSound = istable(pack) and istable(pack.main) and pack.main.jump or nil
    if not istable(jumpSound) and istable(ply.TFAVOX_Sounds) and istable(ply.TFAVOX_Sounds.main) then
        jumpSound = ply.TFAVOX_Sounds.main.jump
    end
    if not istable(jumpSound) or not jumpSound.sound then return end

    -- Priority 10 with command=true makes the counter's voice line play even
    -- if another low-priority TFA-VOX callout is currently active.
    TFAVOX_PlayVoicePriority(ply, jumpSound, 10, true)
end

local function RE4M_GetCounterAnimationDuration(ply, animation)
    if not IsValid(ply) or not animation then return 1.2 end

    -- Use the animation's authored frame rate rather than SequenceDuration,
    -- which can disagree with the merged wOS/DynaBase sequence metadata.
    local frames = animation.frames or 36
    local fps = animation.fps or 120
    return math.max(frames / fps, 0.1)
end

local function IsMapDoor(ent)
    if not IsValid(ent) then return false end
    local class = ent:GetClass()
    if class ~= "prop_door_rotating" and class ~= "func_door" and class ~= "func_door_rotating" then return false end
    return ent:MapCreationID() ~= -1
end

local function FindDoorForPlayer(ply, maxRange)
    local eyePos = ply:EyePos()
    local aim = ply:GetAimVector()
    local trace = util.TraceLine({
        start = eyePos,
        endpos = eyePos + aim * maxRange,
        filter = ply,
        mask = MASK_SOLID,
    })

    if IsMapDoor(trace.Entity) and eyePos:DistToSqr(trace.Entity:WorldSpaceCenter()) <= maxRange * maxRange then
        return trace.Entity
    end

    local nearest, nearestDistance
    for _, ent in ipairs(ents.FindInSphere(ply:GetPos(), maxRange)) do
        if not IsMapDoor(ent) then continue end
        local toDoor = ent:WorldSpaceCenter() - eyePos
        local distance = toDoor:LengthSqr()
        if distance > maxRange * maxRange or aim:Dot(toDoor:GetNormalized()) < 0.35 then continue end
        local visibility = util.TraceLine({start = eyePos, endpos = ent:WorldSpaceCenter(), filter = ply, mask = MASK_SOLID})
        if visibility.Entity ~= ent then continue end
        if not nearestDistance or distance < nearestDistance then
            nearest = ent
            nearestDistance = distance
        end
    end
    return nearest
end

local function IsDoorOpenedForever(door)
    return IsValid(door) and door.RE4M_KickedOpen == true
end

local function ForceDoorOpen(door, activator)
    if not IsValid(door) then return end
    door.RE4M_KickedOpen = true
    door:SetNW2Bool("RE4M_KickedOpen", true)

    local class = door:GetClass()
    door:Fire("Unlock", "", 0, activator)
    door:Fire("SetSpeed", "500", 0, activator)

    if class == "prop_door_rotating" and IsValid(activator) then
        -- OpenAwayFrom needs a target name to determine which side to swing
        -- away from. Give the kicker a temporary unique name for this input.
        local oldName = activator:GetName()
        local kickerName = "RE4M_DoorKicker_" .. activator:EntIndex()
        activator:SetName(kickerName)

        -- Match Door Bust's fast, player-relative swing while retaining this
        -- gamemode's unlock/kick flow and close prevention.
        door:SetKeyValue("opendir", "0")
        door:Fire("OpenAwayFrom", kickerName, 0, activator)
        timer.Simple(0, function()
            if IsValid(activator) and activator:GetName() == kickerName then
                activator:SetName(oldName or "")
            end
        end)
    else
        -- func_door and func_door_rotating use Open. Record the kicker as the
        -- activator, following the addon behavior for func doors.
        if IsValid(activator) then
            door:SetSaveValue("m_hactivator", activator)
        end
        door:Fire("Open", "", 0, activator)
    end

    door:Fire("Lock", "", 0.5, activator)
end

hook.Add("PlayerUse", "RE4M_BlockDefaultUse", function(ply, ent)
    if RE4M_STATE.GameState ~= GAMESTATE_ACTIVE then return end
    if IsRE4MPickup(ent) then
        -- Collect through the gamemode instead of letting the entity's own
        -- Use() run, which ignored the pickup ConVars and skills.
        if isfunction(RE4M_CollectPickup) then
            RE4M_CollectPickup(ply, ent)
            return false
        end
        return
    end
    return false
end)

net.Receive("RE4M_UsePickupRequest", function(_, ply)
    if not IsValid(ply) or not ply:Alive() or RE4M_STATE.GameState ~= GAMESTATE_ACTIVE then return end
    if (PICKUP_USE_COOLDOWN[ply] or 0) > CurTime() then return end

    local pickup = net.ReadEntity()
    local viewOrigin = net.ReadVector()
    if not IsRE4MPickup(pickup) or pickup.Used then return end
    if ply:GetPos():DistToSqr(pickup:WorldSpaceCenter()) > 220 * 220 then return end

    -- The view origin comes from the rendered third-person camera. Bound its
    -- offset so a client cannot claim an arbitrary remote line of sight.
    if ply:EyePos():DistToSqr(viewOrigin) > 240 * 240 then return end

    local traceFilter = {ply, pickup}
    local activeWeapon = ply:GetActiveWeapon()
    if IsValid(activeWeapon) then traceFilter[#traceFilter + 1] = activeWeapon end

    local sight = util.TraceLine({
        start = viewOrigin,
        endpos = pickup:WorldSpaceCenter(),
        filter = traceFilter,
        mask = MASK_SOLID,
    })
    if sight.Hit then return end

    PICKUP_USE_COOLDOWN[ply] = CurTime() + 0.25
    -- Route all mode pickups through the same collector used by touch drops.
    -- Calling entity-specific Use directly made the time pickup bypass the
    -- gamemode's bonus, notification, and tracking logic.
    if isfunction(RE4M_CollectPickup) then
        RE4M_CollectPickup(ply, pickup)
    else
        pickup:Use(ply, ply, USE_ON, 1)
    end
end)

hook.Add("PlayerCanPickupItem", "RE4M_BlockDefaultItems", function(ply, ent)
    if RE4M_STATE.GameState == GAMESTATE_ACTIVE then return false end
end)

hook.Add("PlayerCanPickupWeapon", "RE4M_BlockDefaultWeapons", function(ply, ent)
    -- Only reject map placed weapon pickups. Player:Give and scripted loadout
    -- grants use runtime-created weapon entities and must remain functional.
    if RE4M_STATE.GameState == GAMESTATE_ACTIVE and IsValid(ent) and ent:MapCreationID() ~= -1 then
        return false
    end
end)

hook.Add("AllowPlayerPickup", "RE4M_BlockPhysgunPickup", function(ply, ent)
    if RE4M_STATE.GameState == GAMESTATE_ACTIVE then return false end
end)

hook.Add("GravGunPickupAllowed", "RE4M_BlockGravityGunPickup", function(ply, ent)
    if RE4M_STATE.GameState == GAMESTATE_ACTIVE then return false end
end)

hook.Add("PhysgunPickup", "RE4M_BlockPhysicsGunPickup", function(ply, ent)
    if RE4M_STATE.GameState == GAMESTATE_ACTIVE then return false end
end)

hook.Add("AcceptInput", "RE4M_KeepKickedDoorsOpen", function(ent, inputName)
    if not IsValid(ent) or not ent.RE4M_KickedOpen then return end
    local input = string.lower(inputName or "")
    if input == "close" or input == "toggle" then return true end
end)

hook.Add("EntityRemoved", "RE4M_ClearOpenedDoor", function(ent)
    OPENED_DOORS[ent] = nil
end)

hook.Add("Think", "RE4M_KeepKickedDoorsOpen", function()
    for door, checkAt in pairs(OPENED_DOORS) do
        if not IsValid(door) then
            OPENED_DOORS[door] = nil
        elseif CurTime() >= checkAt then
            OPENED_DOORS[door] = CurTime() + 0.5
            local class = door:GetClass()
            local isOpen
            if class == "prop_door_rotating" then
                isOpen = (door:GetInternalVariable("m_eDoorState") or 0) ~= 0
            else
                isOpen = door:GetInternalVariable("m_toggle_state") == 0
            end
            if not isOpen then
                door:Fire("Unlock")
                door:Fire("Open")
                door:Fire("Lock", "", 0.5)
            end
        end
    end
end)

hook.Add("RE4M_GameStateChanged", "RE4M_ResetKickedDoors", function(_, newState)
    if newState ~= GAMESTATE_MENU and newState ~= GAMESTATE_WAITING then return end
    for door in pairs(OPENED_DOORS) do
        if IsValid(door) then
            door.RE4M_KickedOpen = nil
            door:SetNW2Bool("RE4M_KickedOpen", false)
            door:Fire("Unlock")
        end
    end
    OPENED_DOORS = {}
end)

local function IsCounterableEnemy(ent)
    if not IsValid(ent) then return false end
    local isNextBot = ent.IsDrGNextbot or (isfunction(ent.IsNextBot) and ent:IsNextBot())
    if not isNextBot and not ent.IsVJBaseSNPC then return false end
    -- VJ NPCs: flinching, or staggered by a parry, opens the counter window.
    if ent.IsVJBaseSNPC and (ent.Flinching or (ent.RE4M_ParryStunUntil or 0) > CurTime()) then return true end
    if not RE4M_IsCounterStunned(ent) then return false end
    -- Use the active stun sequence as the source of truth. Several supplied
    -- NPC scripts play their bullet/headshot flinch sequences while Flinching
    -- is unset, even though the character is visibly staggered.
    return true
end

-- ============================================
-- Movement lock while the wOS parry anim plays
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

local function ResetActionState(ply)
    if not IsValid(ply) then return end
    ply:SetNW2Float("RE4M_ParryTime", 0)
    ply:SetNW2Float("RE4M_CounterTime", 0)
    ply:SetNW2Float("RE4M_DoorKickTime", 0)
    ply:SetNW2Int("RE4M_CounterActivity", 0)
    ply:SetNW2String("RE4M_CounterSequence", "")
    ply:SetNW2Float("RE4M_CounterAnimDuration", 0)
    ply:SetNW2Entity("RE4M_CounterTarget", NULL)
    ply:SetNW2Entity("RE4M_DoorKickTarget", NULL)
end

hook.Add("PlayerSpawn", "RE4M_ResetActionState", ResetActionState)
hook.Add("PlayerDeath", "RE4M_ResetActionState", ResetActionState)
hook.Add("RE4M_GameStateChanged", "RE4M_ResetActionState", function(_, newState)
    if newState == GAMESTATE_ACTIVE then return end
    for _, ply in ipairs(player.GetAll()) do ResetActionState(ply) end
end)
hook.Add("PlayerDisconnected", "RE4M_ClearActionCooldowns", function(ply)
    local sid = ply:SteamID64()
    PARRY_COOLDOWN[sid] = nil
    COUNTER_COOLDOWN[sid] = nil
    DOOR_KICK_COOLDOWN[sid] = nil
end)

net.Receive("RE4M_DoorKickRequest", function(_, ply)
    if not IsValid(ply) or not ply:Alive() or RE4M_STATE.GameState ~= GAMESTATE_ACTIVE then return end
    if ply:GetNW2Float("RE4M_ParryTime", 0) > CurTime() or
       ply:GetNW2Float("RE4M_CounterTime", 0) > CurTime() or
       ply:GetNW2Float("RE4M_DoorKickTime", 0) > CurTime() or
       ply:GetNW2Float("RE4M_RollEndTime", 0) > CurTime() then return end

    local sid = ply:SteamID64()
    if DOOR_KICK_COOLDOWN[sid] and DOOR_KICK_COOLDOWN[sid] > CurTime() then return end
    local cfg = RE4MERCS_GetConfig()
    if not cfg then return end
    local door = FindDoorForPlayer(ply, cfg.DoorKickRange or 100)
    if not IsValid(door) or IsDoorOpenedForever(door) then return end

    DOOR_KICK_COOLDOWN[sid] = CurTime() + 0.6
    OPENED_DOORS[door] = CurTime() + 0.48
    door.RE4M_KickedOpen = true
    door:SetNW2Bool("RE4M_KickedOpen", true)
    local doorAnimation = RE4M_COUNTER_ANIMATIONS[2]
    local duration = RE4M_GetCounterAnimationDuration(ply, doorAnimation)
    ply:SetNW2String("RE4M_CounterSequence", "wos_re4m_counter_02")
    ply:SetNW2Int("RE4M_CounterActivity", 2046)
    ply:SetNW2Float("RE4M_CounterAnimDuration", duration)
    ply:SetNW2Float("RE4M_DoorKickTime", CurTime() + duration)
    ply:SetNW2Entity("RE4M_DoorKickTarget", door)
    local faceDoor = door:WorldSpaceCenter() - ply:GetPos()
    ply:SetEyeAngles(Angle(0, faceDoor:Angle().y, 0))
    ply:SetCycle(0)
    ply:AnimRestartMainSequence()
    RE4M_PlayCounterJumpVOX(ply)
    ply:EmitSound("re4mercs/foot_whoosh.wav", 75, 100, 0.9)

    net.Start("RE4M_PlayDoorKick")
        net.WriteEntity(ply)
    net.Broadcast()

    -- Time the door impulse to the kick portion of sequence 02.
    timer.Simple(0.48, function()
        if not IsValid(door) or not IsValid(ply) or
           RE4M_STATE.GameState ~= GAMESTATE_ACTIVE or not door.RE4M_KickedOpen then return end
        ForceDoorOpen(door, ply)
        OPENED_DOORS[door] = CurTime() + 0.6
        door:EmitSound("re4mercs/foot_kickwall.wav", 85, math.random(97, 103), 1)
        door:EmitSound("re4mercs/kickopendoor.wav", 90, 100, 1)
        util.ScreenShake(door:WorldSpaceCenter(), 8, 8, 0.7, 120)

		local effectData = EffectData()
		effectData:SetOrigin(door:WorldSpaceCenter())
		-- The effect launches smoke opposite its normal, back from the door.
		local burstNormal = door:WorldSpaceCenter() - ply:WorldSpaceCenter()
		if burstNormal:LengthSqr() > 0 then
			effectData:SetNormal(burstNormal:GetNormalized())
		else
			effectData:SetNormal(ply:GetForward())
		end
		effectData:SetMagnitude(150)
		util.Effect("busteffect", effectData, true, true)
    end)
end)

local function RE4M_ForceCounterAnim(ply)
    if not IsValid(ply) then return end
    local animation = RE4M_COUNTER_ANIMATIONS[math.random(#RE4M_COUNTER_ANIMATIONS)]
    local duration = RE4M_GetCounterAnimationDuration(ply, animation)

    ply:SetNW2String("RE4M_CounterSequence", animation.sequence)
    ply:SetNW2Int("RE4M_CounterActivity", animation.activityID or 0)
    ply:SetNW2Float("RE4M_CounterAnimDuration", duration)
    ply:SetNW2Float("RE4M_CounterTime", CurTime() + duration)
    ply:SetCycle(0)
    ply:AnimRestartMainSequence()
    RE4M_PlayCounterJumpVOX(ply)
    ply:EmitSound("re4mercs/foot_whoosh.wav", 75, 100, 0.9)

    net.Start("RE4M_PlayCounterAnim")
        net.WriteEntity(ply)
    net.Broadcast()
end

net.Receive("RE4M_CounterRequest", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if RE4M_STATE.GameState ~= GAMESTATE_ACTIVE then return end

    local cfg = RE4MERCS_GetConfig()
    if not cfg or not cfg.CounterEnabled then return end

    local sid = ply:SteamID64()
    if COUNTER_COOLDOWN[sid] and COUNTER_COOLDOWN[sid] > CurTime() then return end
    if ply:GetNW2Float("RE4M_ParryTime", 0) > CurTime() or
       ply:GetNW2Float("RE4M_CounterTime", 0) > CurTime() or
       ply:GetNW2Float("RE4M_DoorKickTime", 0) > CurTime() or
       ply:GetNW2Float("RE4M_RollEndTime", 0) > CurTime() then return end

    local range = cfg.CounterRange or cfg.ParryRange or 120
    local target
    local nearestDistance = range
    for _, ent in ipairs(ents.FindInSphere(ply:GetPos(), range)) do
        if not IsCounterableEnemy(ent) then continue end
        local distance = ply:GetPos():DistToSqr(ent:GetPos())
        if distance <= nearestDistance * nearestDistance then
            target = ent
            nearestDistance = math.sqrt(distance)
        end
    end
    if not IsValid(target) then return end
    if (target.RE4M_CounteredUntil or 0) > CurTime() then return end

    COUNTER_COOLDOWN[sid] = CurTime() + 0.35
    target.RE4M_CounteredUntil = CurTime() + 1.5
    target:SetNW2Float("RE4M_CounteredUntil", target.RE4M_CounteredUntil)
    target.RE4M_ParriedUntil = nil
    ply:SetNW2Entity("RE4M_CounterTarget", target)
    RE4M_ForceCounterAnim(ply)

    local direction = (target:WorldSpaceCenter() - ply:WorldSpaceCenter()):GetNormalized()
    local damage = DamageInfo()
    damage:SetAttacker(ply)
    damage:SetInflictor(ply)
    damage:SetDamage(cfg.CounterDamage or 750)
    damage:SetDamageType(DMG_BLAST)
    damage:SetDamagePosition(target:WorldSpaceCenter())
    damage:SetDamageForce(direction * 50000 + Vector(0, 0, 25000))
    -- Counterable stagger sequences often leave DrG's Flinching flag set.
    -- Clear it so the NPC's existing DMG_BLAST reaction can replace that
    -- stagger with its grenade-style knockdown response.
    target.RE4M_CounterImpact = true
    target.Flinching = false
    target:TakeDamageInfo(damage)
    target.RE4M_CounterImpact = nil

    if IsValid(target) then
        if target:Health() > 0 and (not isfunction(target.IsDead) or not target:IsDead()) then
            target:SetVelocity(direction * 420 + Vector(0, 0, 180))
        end
        target:EmitSound("re4mercs/foot_kickbody.wav", 80, math.random(97, 103), 1)
        sound.Play("re4mercs/knife_parry.wav", target:WorldSpaceCenter(), 80, math.random(90, 100), 1)
    end
end)

local function RE4M_ForceParryAnim(ply)
    if not IsValid(ply) then return end

    local cfg = RE4MERCS_GetConfig()
    local duration = (cfg and cfg.ParryDuration) or 0.95

    ply:SetNW2Float("RE4M_ParryTime", CurTime() + duration)
    ply:AnimRestartMainSequence()

    -- Broadcast with the entity so every client shows the parry knife, not
    -- only the player who parried.
    net.Start("RE4M_PlayParryAnim")
        net.WriteEntity(ply)
    net.Broadcast()

    -- Play draw + whoosh on start
    ply:EmitSound("re4mercs/knife_draw.wav", 75, 100, 0.9)
    timer.Simple(0.08, function()
        if IsValid(ply) then
            ply:EmitSound("re4mercs/knife_slash.wav", 70, math.random(95, 105), 0.7)
        end
    end)
end

net.Receive("RE4M_ParryRequest", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if RE4M_STATE.GameState ~= GAMESTATE_ACTIVE then return end

    local cfg = RE4MERCS_GetConfig()
    if not cfg or not cfg.ParryEnabled then return end
    if ply:GetNW2Float("RE4M_ParryTime", 0) > CurTime() or
       ply:GetNW2Float("RE4M_CounterTime", 0) > CurTime() or
       ply:GetNW2Float("RE4M_DoorKickTime", 0) > CurTime() or
       ply:GetNW2Float("RE4M_RollEndTime", 0) > CurTime() then return end

    local range = cfg.ParryRange or 120
    local hitPos = nil
    local target, nearestDistance

    for _, ent in ipairs(ents.FindInSphere(ply:GetPos(), range)) do
        if not IsValid(ent) then continue end
        local isVJ = ent.IsVJBaseSNPC == true
        if not isVJ and not (ent.IsDrGNextbot or ent:IsNextBot()) then continue end
        if not isVJ and not ent.Parryable then continue end

        local attacking = false
        if isVJ then
            -- Parry VJ melee attacks during their wind-up, before the hit lands.
            attacking = VJ ~= nil and ent.AttackType == VJ.ATTACK_TYPE_MELEE and
                ent.AttackState == VJ.ATTACK_STATE_STARTED
        elseif ent.IsAttacking and isfunction(ent.IsAttacking) and ent:IsAttacking() then
            attacking = true
        else
            local seqName = string.lower(ent:GetSequenceName(ent:GetSequence()) or "")
            if string.find(seqName, "att") and not string.find(seqName, "grab") and not string.find(seqName, "idle") then
                attacking = true
            end
        end

        if not attacking then continue end
        local distance = ply:GetPos():DistToSqr(ent:GetPos())
        if not nearestDistance or distance < nearestDistance then
            target = ent
            nearestDistance = distance
        end
    end

    -- A parry only starts inside a real enemy attack window. This prevents
    -- empty USE presses from consuming cooldown or replaying the animation.
    if not IsValid(target) then return end
    local sid = ply:SteamID64()
    if PARRY_COOLDOWN[sid] and PARRY_COOLDOWN[sid] > CurTime() then return end
    PARRY_COOLDOWN[sid] = CurTime() + (cfg.ParryCooldown or 0.9)
    RE4M_ForceParryAnim(ply)

    if target.IsVJBaseSNPC then
        -- Cancel the VJ attack and stagger it; this also opens the counter
        -- window (see IsCounterableEnemy).
        if isfunction(target.StopAttacks) then pcall(target.StopAttacks, target, true) end
        if isfunction(target.PlayAnim) then
            pcall(target.PlayAnim, target, {ACT_BIG_FLINCH, ACT_FLINCH_PHYSICS, ACT_FLINCH_CHEST}, true, 1.2, false)
        end
        target.RE4M_ParryStunUntil = CurTime() + 1.4
    elseif isfunction(target.RE4M_OnParried) then
        -- NextBots can define their own parry reaction (e.g. a knockdown
        -- chain) instead of a single ParriedAnimation.
        target:RE4M_OnParried(ply)
    elseif target.ParriedAnimation and target.ParriedAnimation ~= "" then
        if isfunction(target.CICO) then
            target:CICO(function(self)
                self:PlaySequenceAndMove(self.ParriedAnimation, 1.15)
            end)
        elseif isfunction(target.ReactInCoroutine) then
            -- PlaySequenceAndMove yields, so it must run inside the bot's
            -- behaviour coroutine; calling it from this net handler errored.
            target:ReactInCoroutine(target.PlaySequenceAndMove, target.ParriedAnimation, 1.15)
        end
    end
    target.RE4M_ParriedUntil = CurTime() + 1.5
    local dmg = DamageInfo()
    dmg:SetAttacker(ply)
    dmg:SetInflictor(ply)
    dmg:SetDamage(5)
    dmg:SetDamageType(DMG_CLUB)
    target:TakeDamageInfo(dmg)
    if IsValid(target) then hitPos = target:WorldSpaceCenter() end

    -- If we hit something, play the parry sound + tell clients to spawn the flash
    if hitPos then
        -- Play the heavy metal clash sound at the impact point
        sound.Play("re4mercs/knife_parry.wav", hitPos, 80, math.random(95, 105), 1)

        net.Start("RE4M_ParryHit")
            net.WriteVector(hitPos)
        net.Broadcast()
    end
end)

-- Keep the force command for testing. Admin-only: a parry grants damage
-- immunity, so anyone could spam this command to become invulnerable.
concommand.Add("re4m_forceparry", function(ply)
    if not IsValid(ply) or not ply:RE4M_IsAdmin() then return end
    RE4M_ForceParryAnim(ply)
end)
