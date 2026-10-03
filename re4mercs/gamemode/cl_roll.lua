-- Client input and animation selection for the server-authoritative roll.

if SERVER then return end

local function HorizontalCameraBasis(ply)
	local _, direction
	if RE4M_GetCameraAimRay then _, direction = RE4M_GetCameraAimRay() end
	local yaw = isvector(direction) and direction:Angle().y or ply:EyeAngles().y
	local forward = Angle(0, yaw, 0):Forward()
	local right = Angle(0, yaw, 0):Right()
	return forward, right
end

local function GetRollIntent(ply)
	local forward, right = HorizontalCameraBasis(ply)
	local forwardInput = (ply:KeyDown(IN_FORWARD) and 1 or 0) - (ply:KeyDown(IN_BACK) and 1 or 0)
	local sideInput = (ply:KeyDown(IN_MOVERIGHT) and 1 or 0) - (ply:KeyDown(IN_MOVELEFT) and 1 or 0)
	local directionType
	if forwardInput == 0 and sideInput == 0 then
		directionType = 2 -- Neutral input defaults to a quick backward step.
		forwardInput = -1
	elseif math.abs(forwardInput) >= math.abs(sideInput) then
		directionType = forwardInput >= 0 and 1 or 2
	else
		directionType = sideInput >= 0 and 3 or 4
	end

	local direction = forward * forwardInput + right * sideInput
	direction.z = 0
	if direction:LengthSqr() <= 0 then direction = -forward end
	direction:Normalize()
	return directionType, direction
end

hook.Add("PlayerBindPress", "RE4M_CombatRollJumpBind", function(ply, bind, pressed)
	if not IsValid(ply) or ply ~= LocalPlayer() or not string.find(string.lower(bind or ""), "+jump", 1, true) then return end
	if pressed and RE4M_CLIENT and RE4M_CLIENT.GameState == GAMESTATE_ACTIVE and ply:Alive() then
		local directionType, direction = GetRollIntent(ply)
		net.Start("RE4M_RollRequest")
			net.WriteUInt(directionType, 3)
			net.WriteVector(direction)
		net.SendToServer()
	end
	return true -- Jump is replaced by the roll action, including outside a live round.
end)

hook.Add("CreateMove", "RE4M_CombatRollBlockJump", function(cmd)
	cmd:RemoveKey(IN_JUMP)
end)

net.Receive("RE4M_PlayRoll", function()
	local ply = net.ReadEntity()
	if IsValid(ply) then
		ply:SetCycle(0)
		ply:AnimRestartMainSequence()
	end
end)

