-- Server-authoritative combat roll action.

util.AddNetworkString("RE4M_RollRequest")
util.AddNetworkString("RE4M_PlayRoll")

local ROLL_COOLDOWN_UNTIL = setmetatable({}, {__mode = "k"})
local ROLL_SOUND_COUNT = 4

local function RollConfig()
	return RE4MERCS_GetConfig and RE4MERCS_GetConfig() or {}
end

local function WeaponForwardRoll(weapon)
	if not IsValid(weapon) then return "roll_ar" end
	local holdType = isfunction(weapon.GetHoldType) and string.lower(weapon:GetHoldType() or "") or ""
	local class = string.lower(weapon:GetClass() or "")

	if holdType == "grenade" or string.find(class, "grenade", 1, true) or string.find(class, "frag", 1, true) then
		return "roll_gren_frag"
	end
	if holdType == "crossbow" or holdType == "rpg" or string.find(class, "sniper", 1, true) or
	   string.find(class, "scout", 1, true) or string.find(class, "awp", 1, true) then
		return "roll_sniper"
	end
	if holdType == "duel" or string.find(class, "akimbo", 1, true) or string.find(class, "dual", 1, true) then
		return "roll_akimbo"
	end
	if holdType == "shotgun" then
		if string.find(class, "sawed", 1, true) or string.find(class, "shorty", 1, true) then return "roll_sawed" end
		return "roll_shotgun"
	end
	if holdType == "revolver" then
		if string.find(class, "50ae", 1, true) or string.find(class, "deagle", 1, true) or
		   string.find(class, "magnum", 1, true) then return "roll_50ae" end
		return "roll_saa"
	end
	if string.find(class, "saa", 1, true) or string.find(class, "singleaction", 1, true) then return "roll_saa" end
	if holdType == "pistol" then return "roll_50ae" end
	if holdType == "smg" or holdType == "smg1" then return "roll_smg" end
	if string.find(class, "ak", 1, true) then return "roll_aksaa" end
	if holdType == "ar2" or holdType == "rifle" or holdType == "passive" then return "roll_ar" end
	return "roll_ar"
end

local function SequenceForRoll(ply, direction, weapon)
	local candidates
	if direction == 1 then
		candidates = {WeaponForwardRoll(weapon), "wos_bs_shared_roll_forward", "wos_re4m_roll", "wos_re4m_roll_rm", "roll_ar"}
	elseif direction == 2 then
		candidates = {"wos_bs_shared_roll_back", "roll_back", "wos_re4m_roll", "wos_re4m_roll_rm", WeaponForwardRoll(weapon)}
	elseif direction == 3 then
		candidates = {"wos_bs_shared_roll_right", "roll_right", "wos_re4m_roll", "wos_re4m_roll_rm", WeaponForwardRoll(weapon)}
	else
		candidates = {"wos_bs_shared_roll_left", "roll_left", "wos_re4m_roll", "wos_re4m_roll_rm", WeaponForwardRoll(weapon)}
	end

	for _, sequence in ipairs(candidates) do
		local sequenceID = ply:LookupSequence(sequence)
		if sequenceID and sequenceID >= 0 then return sequence, sequenceID, 0 end
		local activityID = 0
		if string.StartWith(sequence, "roll_") and util.GetActivityIDByName then
			activityID = util.GetActivityIDByName("ACT_AHL_" .. string.upper(string.sub(sequence, 6))) or 0
		end
		if activityID > 0 then
			local sequenceID = ply:SelectWeightedSequence(activityID)
			if sequenceID and sequenceID >= 0 then return sequence, sequenceID, activityID end
		end
	end
	return nil
end

local function ResetRoll(ply)
	if not IsValid(ply) then return end
	ply.RE4M_RollToken = nil
	ply.RE4M_RollDistance = nil
	ply:SetNW2Float("RE4M_RollDistance", 0)
	ply:SetNW2Float("RE4M_RollStartTime", 0)
	ply:SetNW2Float("RE4M_RollEndTime", 0)
	ply:SetNW2Float("RE4M_RollIFrameEnd", 0)
	ply:SetNW2Vector("RE4M_RollDirection", vector_origin)
	ply:SetNW2String("RE4M_RollSequence", "")
	ply:SetNW2Int("RE4M_RollType", 0)
	ply:SetNW2Int("RE4M_RollActivity", 0)
	ply:SetCycle(0)
end

hook.Add("StartCommand", "RE4M_DisableJumpInput", function(_, cmd)
	cmd:RemoveKey(IN_JUMP)
end)

net.Receive("RE4M_RollRequest", function(_, ply)
	if not IsValid(ply) or not ply:Alive() or RE4M_STATE.GameState ~= GAMESTATE_ACTIVE then return end
	local cfg = RollConfig()
	if cfg.RollEnabled == false then return end
	if ply:InVehicle() or ply:IsFrozen() or not ply:OnGround() or ply:GetMoveType() ~= MOVETYPE_WALK then return end
	if ply:GetNW2Float("RE4M_RollEndTime", 0) > CurTime() or
	   ply:GetNW2Float("RE4M_ParryTime", 0) > CurTime() or
	   ply:GetNW2Float("RE4M_CounterTime", 0) > CurTime() or
	   ply:GetNW2Float("RE4M_DoorKickTime", 0) > CurTime() then return end
	if (ROLL_COOLDOWN_UNTIL[ply] or 0) > CurTime() then return end

	local directionType = net.ReadUInt(3)
	local direction = net.ReadVector()
	if directionType < 1 or directionType > 4 or not isvector(direction) then return end
	direction.z = 0
	if direction:LengthSqr() < 0.5 then return end
	direction:Normalize()

	local weapon = ply:GetActiveWeapon()
	local sequence, sequenceID, activityID = SequenceForRoll(ply, directionType, weapon)
	if not sequence then return end
	if not sequenceID or sequenceID < 0 then return end
	local sequenceDuration = ply:SequenceDuration(sequenceID)
	if not isnumber(sequenceDuration) or sequenceDuration <= 0 then sequenceDuration = 0.6 end
	local duration = math.Clamp(sequenceDuration, 0.4, 2.5)
	local now = CurTime()
	local iframeDuration = math.Clamp(tonumber(cfg.RollIFrame) or 0.2, 0.05, 0.4)
	local distance
	if directionType == 1 then
		distance = tonumber(cfg.RollForwardDistance) or 220
	elseif directionType == 3 or directionType == 4 then
		distance = tonumber(cfg.RollSideDistance) or 165
	else
		distance = tonumber(cfg.RollBackDistance) or 145
	end

	local endsAt = now + duration
	ply.RE4M_RollToken = endsAt
	ply:SetNW2Float("RE4M_RollStartTime", now)
	ply:SetNW2Float("RE4M_RollEndTime", endsAt)
	ply:SetNW2Float("RE4M_RollIFrameEnd", now + iframeDuration)
	ply:SetNW2Vector("RE4M_RollDirection", direction)
	ply:SetNW2String("RE4M_RollSequence", sequence)
	ply:SetNW2Int("RE4M_RollType", directionType)
	ply:SetNW2Int("RE4M_RollActivity", activityID or 0)
	ply:SetNW2Float("RE4M_RollDistance", distance)
	ply.RE4M_RollDistance = distance
	ply:SetCycle(0)
	ROLL_COOLDOWN_UNTIL[ply] = endsAt + math.max(0, tonumber(cfg.RollCooldown) or 0.8)
	ply:AnimRestartMainSequence()
	ply:EmitSound("re4mercs/Body_Roll_0" .. math.random(1, ROLL_SOUND_COUNT) .. ".wav", 75, math.random(97, 103), 0.9)

	net.Start("RE4M_PlayRoll")
		net.WriteEntity(ply)
	net.Broadcast()

	timer.Simple(duration, function()
		if not IsValid(ply) or ply.RE4M_RollToken ~= endsAt then return end
		ResetRoll(ply)
	end)
end)

--- A roll's invulnerability window made an enemy attack miss: flash the
--- perfect-dodge vignette for that player, once per roll. Also called by the
--- RE4 content addon when a grab/chainsaw instant kill is dodged.
function RE4M_TriggerPerfectDodge(ply)
	if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end
	if RE4M_STATE.GameState ~= GAMESTATE_ACTIVE then return end
	if ply:GetNW2Float("RE4M_RollIFrameEnd", 0) <= CurTime() then return end
	local rollToken = ply.RE4M_RollToken or ply:GetNW2Float("RE4M_RollStartTime", 0)
	if ply.RE4M_PerfectDodgeToken == rollToken then return end
	ply.RE4M_PerfectDodgeToken = rollToken

	net.Start("RE4M_PerfectDodge")
	net.Send(ply)
end

hook.Add("EntityTakeDamage", "RE4M_CombatRollIFrames", function(target, dmgInfo)
	if not IsValid(target) or not target:IsPlayer() or RE4M_STATE.GameState ~= GAMESTATE_ACTIVE then return end
	if target:GetNW2Float("RE4M_RollIFrameEnd", 0) > CurTime() then
		-- Only real attacks count as a dodge (not falls or self damage).
		local attacker = dmgInfo:GetAttacker()
		if dmgInfo:GetDamage() > 0 and IsValid(attacker) and attacker ~= target then
			RE4M_TriggerPerfectDodge(target)
		end
		return true
	end
end)

-- Roll movement (SetupMove/Move) lives in shared.lua so clients predict it.

local function ResetPlayerRoll(ply)
	ResetRoll(ply)
	ROLL_COOLDOWN_UNTIL[ply] = nil
end

hook.Add("PlayerSpawn", "RE4M_ResetCombatRoll", ResetPlayerRoll)
hook.Add("PlayerDeath", "RE4M_ResetCombatRoll", ResetPlayerRoll)
hook.Add("PlayerDisconnected", "RE4M_ResetCombatRollCooldown", function(ply)
	ROLL_COOLDOWN_UNTIL[ply] = nil
end)
hook.Add("RE4M_GameStateChanged", "RE4M_ResetCombatRolls", function(_, newState)
	if newState == GAMESTATE_ACTIVE then return end
	for _, ply in ipairs(player.GetAll()) do ResetPlayerRoll(ply) end
end)
