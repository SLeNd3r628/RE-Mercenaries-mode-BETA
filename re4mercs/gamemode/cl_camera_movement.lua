if SERVER then return end

local cvCamera = CreateClientConVar("re4m_thirdperson_enabled", "0", true, false,
    "Enable the RE-style over-the-shoulder camera")
local cvMovement = CreateClientConVar("re4m_movement_enabled", "0", true, false,
    "Enable camera-relative movement and movement-facing")
local cvDebug = CreateClientConVar("re4m_camera_debug", "0", true, false,
    "Show camera and movement debug information")
local CAMERA = {
    -- Tight over-the-shoulder framing keeps the waist at the lower edge of
    -- view during normal movement; sprint pulls back to retain situational view.
    walk = { distance = 45, side = 25, height = 3, fov = 72, lookDown = 4 },
    -- Shoulder framing similar to the reference image. Aim view is a fixed
    -- preset; there is no mouse-wheel or distance-convar zoom.
    aim = { distance = 35, side = 15, height = 3, fov = 72, lookDown = 4 },
    sprint = { distance = 52, side = 12, height = -16, fov = 81, lookDown = 8 },
    -- Dedicated action framing copied from sprint, so door kicks and counters
    -- use the wider, pulled-back sprint view even while standing still.
    action = { distance = 52, side = 12, height = -16, fov = 81, lookDown = 8 },
    crouch = { distance = 55, side = 12, height = 15, fov = 75, lookDown = 12 },
}

local shoulderSign = 1
local cameraAngles
local bodyYaw
local smoothedOrigin
local smoothedFOV = CAMERA.walk.fov
local wasMovementEnabled = false
local lastTrace = nil
local lastPivot = nil
local lastWishOrigin = nil
local cameraState = "walk"
local counterCameraState
local lastCounterCameraVariant
local rollCameraState
local lastRollCameraVariant

local COUNTER_CAMERA_VARIANTS = {
	{side = 56, back = 42, height = 30, fov = 76, sign = 1},
	{side = 64, back = 50, height = 42, fov = 73, sign = -1},
	{side = 46, back = 62, height = 24, fov = 79, sign = 1},
	{side = 72, back = 48, height = 34, fov = 74, sign = -1},
}

local ROLL_CAMERA_VARIANTS = {
	{side = 34, back = 66, height = 24, fov = 77, sign = 1},
	{side = 46, back = 74, height = 32, fov = 74, sign = -1},
	{side = 28, back = 82, height = 20, fov = 80, sign = 1},
	{side = 52, back = 70, height = 38, fov = 75, sign = -1},
}

local function ResetRig()
    cameraAngles = nil
    bodyYaw = nil
    smoothedOrigin = nil
    lastTrace = nil
    lastPivot = nil
    lastWishOrigin = nil
    wasMovementEnabled = false
    counterCameraState = nil
    rollCameraState = nil
end

local function SaveCameraAimRay(view)
	RE4M_CAMERA_AIM_ORIGIN = view.origin
	RE4M_CAMERA_AIM_DIRECTION = view.angles:Forward()
	return view
end

function RE4M_GetCameraAimRay()
	local ply = LocalPlayer()
	if not IsValid(ply) then return end
	if isvector(RE4M_CAMERA_AIM_ORIGIN) and isvector(RE4M_CAMERA_AIM_DIRECTION) then
		return RE4M_CAMERA_AIM_ORIGIN, RE4M_CAMERA_AIM_DIRECTION
	end
	return ply:EyePos(), ply:GetAimVector()
end

local function IsUsablePlayer(ply)
    return IsValid(ply) and ply == LocalPlayer() and ply:Alive()
        and ply:GetMoveType() ~= MOVETYPE_NOCLIP and ply:GetMoveType() ~= MOVETYPE_OBSERVER
        and not ply:InVehicle() and not ply:IsTyping()
end

local function HorizontalBasis(yaw)
    local angle = Angle(0, yaw, 0)
    return angle:Forward(), angle:Right()
end

local function GetCameraPivot(ply)
    local mins, maxs = ply:GetHull()
    local height = maxs and maxs.z or 72
    if ply:Crouching() then
        local crouchMins, crouchMaxs = ply:GetHullDuck()
        height = crouchMaxs and crouchMaxs.z or 36
    end

    -- Keep the pivot around the upper chest for different player hull heights.
    return ply:GetPos() + Vector(0, 0, math.Clamp(height * 0.78, 28, 58))
end

local function GetCounterBonePosition(ent, boneNames, fallback)
	if not IsValid(ent) then return fallback end
	for _, boneName in ipairs(boneNames) do
		local bone = ent:LookupBone(boneName)
		if bone then
			local position = ent:GetBonePosition(bone)
			if isvector(position) and position:LengthSqr() > 0 then return position end
		end
	end
	return fallback
end

local function BuildCounterCamera(ply, origin, angles, fov, counterEnd)
	local focus = GetCounterBonePosition(ply, {
		"ValveBiped.Bip01_Spine2",
		"ValveBiped.Bip01_Spine1",
		"ValveBiped.Bip01_Head1",
	}, ply:WorldSpaceCenter())
	local approach = ply:GetForward()
	approach.z = 0
	if approach:LengthSqr() < 0.001 then approach = ply:GetForward() end
	approach:Normalize()
	local right = Angle(0, approach:Angle().y, 0):Right()

	if not counterCameraState or counterCameraState.endsAt ~= counterEnd then
		local variantIndex = math.random(#COUNTER_CAMERA_VARIANTS)
		if #COUNTER_CAMERA_VARIANTS > 1 and variantIndex == lastCounterCameraVariant then
			variantIndex = variantIndex % #COUNTER_CAMERA_VARIANTS + 1
		end
		lastCounterCameraVariant = variantIndex
		counterCameraState = {
			endsAt = counterEnd,
			variant = COUNTER_CAMERA_VARIANTS[variantIndex],
			position = origin,
			angles = angles,
			fov = fov,
		}
	end

	local variant = counterCameraState.variant
	local desiredOrigin = focus - approach * variant.back + right * variant.side * variant.sign + Vector(0, 0, variant.height)
	local trace = util.TraceHull({
		start = focus,
		endpos = desiredOrigin,
		mins = Vector(-4, -4, -4),
		maxs = Vector(4, 4, 4),
		mask = MASK_SOLID,
		filter = ply,
	})
	if trace.Hit then desiredOrigin = trace.HitPos + trace.HitNormal * 3 end

	local desiredAngles = (focus - desiredOrigin):Angle()
	desiredAngles.r = 0
	local blend = math.min(FrameTime() * 9, 1)
	counterCameraState.position = LerpVector(blend, counterCameraState.position, desiredOrigin)
	counterCameraState.angles = LerpAngle(blend, counterCameraState.angles, desiredAngles)
	counterCameraState.fov = Lerp(blend, counterCameraState.fov, variant.fov)
	cameraState = "counter"

	return {
		origin = counterCameraState.position,
		angles = counterCameraState.angles,
		fov = counterCameraState.fov,
		drawviewer = true,
	}
end

local function BuildRollCamera(ply, origin, angles, fov, rollEnd)
	local focus = GetCounterBonePosition(ply, {
		"ValveBiped.Bip01_Spine2",
		"ValveBiped.Bip01_Spine1",
		"ValveBiped.Bip01_Pelvis",
	}, ply:WorldSpaceCenter())
	local forward = ply:GetForward()
	forward.z = 0
	if forward:LengthSqr() < 0.001 then forward = Angle(0, angles.y, 0):Forward() end
	forward:Normalize()
	local right = Angle(0, forward:Angle().y, 0):Right()

	if not rollCameraState or rollCameraState.endsAt ~= rollEnd then
		local variantIndex = math.random(#ROLL_CAMERA_VARIANTS)
		if #ROLL_CAMERA_VARIANTS > 1 and variantIndex == lastRollCameraVariant then
			variantIndex = variantIndex % #ROLL_CAMERA_VARIANTS + 1
		end
		lastRollCameraVariant = variantIndex
		rollCameraState = {
			endsAt = rollEnd,
			variant = ROLL_CAMERA_VARIANTS[variantIndex],
			position = origin,
			angles = angles,
			fov = fov,
		}
	end

	local variant = rollCameraState.variant
	local desiredOrigin = focus - forward * variant.back + right * variant.side * variant.sign + Vector(0, 0, variant.height)
	local trace = util.TraceHull({
		start = focus,
		endpos = desiredOrigin,
		mins = Vector(-4, -4, -4),
		maxs = Vector(4, 4, 4),
		mask = MASK_SOLID,
		filter = ply,
	})
	if trace.Hit then desiredOrigin = trace.HitPos + trace.HitNormal * 3 end

	local desiredAngles = (focus - desiredOrigin):Angle()
	desiredAngles.r = 0
	local blend = math.min(FrameTime() * 14, 1)
	rollCameraState.position = LerpVector(blend, rollCameraState.position, desiredOrigin)
	rollCameraState.angles = LerpAngle(blend, rollCameraState.angles, desiredAngles)
	rollCameraState.fov = Lerp(blend, rollCameraState.fov, variant.fov)
	cameraState = "roll"

	return {
		origin = rollCameraState.position,
		angles = rollCameraState.angles,
		fov = rollCameraState.fov,
		drawviewer = true,
	}
end

local function IsAiming(ply, cmd)
    if cmd:KeyDown(IN_ATTACK2) then return true end

    local weapon = ply:GetActiveWeapon()
    if not IsValid(weapon) then return false end
    if weapon.GetAimDelta then
        local ok, amount = pcall(weapon.GetAimDelta, weapon)
        if ok and isnumber(amount) and amount > 0.1 then return true end
    end
    return weapon.BO3_ADSState == 1 or weapon.BO3_ADSState == 2
end

local function ApproachYaw(current, target, speed)
    return math.ApproachAngle(current, target, speed * FrameTime())
end

local function CreateMove(cmd)
    local ply = LocalPlayer()
    if not IsUsablePlayer(ply) then
        ResetRig()
        return
    end

    local movementOn = cvMovement:GetBool()
    if not movementOn then
        wasMovementEnabled = false
        cameraAngles = nil
        bodyYaw = nil
        return
    end

    local cmdAngles = cmd:GetViewAngles()
    if not wasMovementEnabled or not cameraAngles or not bodyYaw then
        cameraAngles = Angle(cmdAngles.p, cmdAngles.y, 0)
        bodyYaw = ply:EyeAngles().y
        wasMovementEnabled = true
    end

    -- Camera rotation is independent from character rotation while idle.
    cameraAngles.p = math.Clamp(cameraAngles.p + cmd:GetMouseY() * 0.022, -75, 75)
    cameraAngles.y = math.NormalizeAngle(cameraAngles.y - cmd:GetMouseX() * 0.022)
    cameraAngles.r = 0

    local originalForward = cmd:GetForwardMove()
    local originalSide = cmd:GetSideMove()
    local moving = math.abs(originalForward) > 1 or math.abs(originalSide) > 1
    local firing = cmd:KeyDown(IN_ATTACK) or cmd:KeyDown(IN_ATTACK2)
    local aiming = IsAiming(ply, cmd)

    if cvCamera:GetBool() then
        if aiming then
            -- Keep the character locked to the aim direction with no yaw catch-up.
            bodyYaw = cameraAngles.y
        elseif moving or firing then
            -- Keep the camera and character facing aligned while active. The
            -- idle free-look can orbit, but movement/aim never spins around a
            -- body that is facing a different direction.
            bodyYaw = ApproachYaw(bodyYaw, cameraAngles.y, 900)
        end
    else
        -- With the camera disabled, retain the normal first-person view yaw.
        cameraAngles.p = cmdAngles.p
        cameraAngles.y = cmdAngles.y
        if moving then
            local camForward, camRight = HorizontalBasis(cameraAngles.y)
            local wish = camForward * originalForward + camRight * originalSide
            wish.z = 0
            if wish:LengthSqr() > 1 then bodyYaw = ApproachYaw(bodyYaw, wish:Angle().y, 540) end
        elseif aiming or firing then
            bodyYaw = ApproachYaw(bodyYaw, cameraAngles.y, 900)
        end
    end

    -- Translate the desired camera-relative world movement into the body-local
    -- movement values Source expects, preserving the player's movement speed.
    if moving then
        local camForward, camRight = HorizontalBasis(cameraAngles.y)
        local desiredWorld = camForward * originalForward + camRight * originalSide
        desiredWorld.z = 0
        local magnitude = math.min(desiredWorld:Length(), 10000)
        if magnitude > 0 then desiredWorld:Normalize() end

        local bodyForward, bodyRight = HorizontalBasis(bodyYaw)
        cmd:SetForwardMove(desiredWorld:Dot(bodyForward) * magnitude)
        cmd:SetSideMove(desiredWorld:Dot(bodyRight) * magnitude)
    end

    local pitch = (aiming or firing) and cameraAngles.p or cmdAngles.p
    cmd:SetViewAngles(Angle(pitch, bodyYaw, 0))
end

local function CalcView(ply, origin, angles, fov)
	local counterEnd = IsValid(ply) and ply:GetNW2Float("RE4M_CounterTime", 0) or 0
	if counterEnd > CurTime() and IsUsablePlayer(ply) then
		return SaveCameraAimRay(BuildCounterCamera(ply, origin, angles, fov, counterEnd))
	end
	counterCameraState = nil
	local rollEnd = IsValid(ply) and ply:GetNW2Float("RE4M_RollEndTime", 0) or 0
	if rollEnd > CurTime() and IsUsablePlayer(ply) then
		return SaveCameraAimRay(BuildRollCamera(ply, origin, angles, fov, rollEnd))
	end
	rollCameraState = nil
	local parryAction = IsValid(ply) and ply:GetNW2Float("RE4M_ParryTime", 0) > CurTime()
	local rollAction = IsValid(ply) and ply:GetNW2Float("RE4M_RollEndTime", 0) > CurTime()
	local actionCamera = IsValid(ply) and (ply:GetNW2Float("RE4M_DoorKickTime", 0) > CurTime() or parryAction or rollAction)
    if (not cvCamera:GetBool() and not actionCamera) or not IsUsablePlayer(ply) then
		if IsValid(ply) and ply == LocalPlayer() then
			RE4M_CAMERA_AIM_ORIGIN = nil
			RE4M_CAMERA_AIM_DIRECTION = nil
		end
		return
	end

    local viewAngles = cameraAngles or ply:EyeAngles()
    local aiming = ply:KeyDown(IN_ATTACK2)
    local sprinting = ply:KeyDown(IN_SPEED) and ply:GetVelocity():Length2D() > 20
    local crouching = ply:Crouching()

    local preset
    if actionCamera then
        preset, cameraState = CAMERA.action, "action"
    elseif aiming then
        preset, cameraState = CAMERA.aim, "aim"
    elseif crouching then
        preset, cameraState = CAMERA.crouch, "crouch"
    elseif sprinting then
        preset, cameraState = CAMERA.sprint, "sprint"
    else
        preset, cameraState = CAMERA.walk, "walk"
    end

    local pivot = GetCameraPivot(ply)
    local forward = Angle(0, viewAngles.y, 0):Forward()
    local right = Angle(0, viewAngles.y, 0):Right()
    local distance = preset.distance

    local shoulder = preset.side * shoulderSign
    local wishOrigin = pivot - forward * distance + right * shoulder + Vector(0, 0, preset.height)

    -- Start the collision probe on the shoulder arm, not at the hull center.
    local traceStart = pivot + right * (shoulder * 0.55)
    local tr = util.TraceHull({
        start = traceStart,
        endpos = wishOrigin,
        mins = Vector(-4, -4, -4),
        maxs = Vector(4, 4, 4),
        mask = MASK_SOLID,
        filter = function(ent)
            if ent == ply then return false end
            local moveType = ent:GetMoveType()
            if moveType == MOVETYPE_FLY or moveType == MOVETYPE_FLYGRAVITY then return false end
            local group = ent:GetCollisionGroup()
            return group ~= COLLISION_GROUP_DEBRIS and group ~= COLLISION_GROUP_PROJECTILE
        end,
    })
    lastTrace = tr
    lastPivot = traceStart
    lastWishOrigin = wishOrigin

    local safeOrigin = tr.Hit and (tr.HitPos + tr.HitNormal * 3) or wishOrigin
    if not smoothedOrigin then smoothedOrigin = safeOrigin end
    if aiming and not actionCamera then
        -- Collision still constrains the camera, but aiming does not trail the
        -- shoulder position or reticle behind the player's current aim.
        smoothedOrigin = safeOrigin
    else
        local followRate = (sprinting or actionCamera) and 7 or 11
        smoothedOrigin = LerpVector(math.min(FrameTime() * followRate, 1), smoothedOrigin, safeOrigin)
    end

    local targetFOV = preset.fov
    if aiming and not actionCamera then
        smoothedFOV = targetFOV
    else
        smoothedFOV = math.Approach(smoothedFOV, targetFOV, 130 * FrameTime())
    end

    local cameraViewAngles = Angle(viewAngles.p + preset.lookDown, viewAngles.y, 0)
    cameraViewAngles.p = math.Clamp(cameraViewAngles.p, -80, 80)

    return SaveCameraAimRay({
        origin = smoothedOrigin,
        angles = cameraViewAngles,
        fov = smoothedFOV,
        drawviewer = true,
    })
end

hook.Add("CreateMove", "RE4M_CameraMovement_CreateMove", CreateMove)
hook.Add("CalcView", "RE4M_CameraMovement_CalcView", CalcView)
hook.Add("ShouldDrawLocalPlayer", "RE4M_CameraMovement_DrawPlayer", function(ply)
    if IsUsablePlayer(ply) and (cvCamera:GetBool() or ply:GetNW2Float("RE4M_RollEndTime", 0) > CurTime()) then return true end
end)
hook.Add("PreDrawViewModel", "RE4M_CameraMovement_HideViewModel", function(_, ply)
    if IsUsablePlayer(ply) and (cvCamera:GetBool() or ply:GetNW2Float("RE4M_RollEndTime", 0) > CurTime()) then return true end
end)
hook.Add("AdjustMouseSensitivity", "RE4M_CameraMovement_Sensitivity", function()
    if cvCamera:GetBool() and IsUsablePlayer(LocalPlayer()) then return 1 end
end)

concommand.Add("re4m_thirdperson", function(_, _, args)
    local enabled = args[1] == nil and not cvCamera:GetBool() or tobool(args[1])
    RunConsoleCommand("re4m_thirdperson_enabled", enabled and "1" or "0")
    if not enabled then smoothedOrigin = nil end
    print("[RE4 Mercs] Third-person camera " .. (enabled and "enabled" or "disabled"))
end, nil, "Toggle the RE4 Mercenaries over-the-shoulder camera (0 or 1)")

concommand.Add("re4m_movement", function(_, _, args)
    local enabled = args[1] == nil and not cvMovement:GetBool() or tobool(args[1])
    RunConsoleCommand("re4m_movement_enabled", enabled and "1" or "0")
    ResetRig()
    print("[RE4 Mercs] Camera-relative movement " .. (enabled and "enabled" or "disabled"))
end, nil, "Toggle RE4 Mercenaries camera-relative movement (0 or 1)")

concommand.Add("re4m_camera_shoulder", function()
    shoulderSign = -shoulderSign
end, nil, "Swap the over-the-shoulder camera side")

hook.Add("PostDrawTranslucentRenderables", "RE4M_CameraMovement_DebugWorld", function()
    if not cvDebug:GetBool() or not cvCamera:GetBool() or not lastPivot then return end
    local actual = smoothedOrigin
    if not actual then return end

    render.DrawLine(lastPivot, lastWishOrigin or actual, Color(255, 190, 40), true)
    render.DrawLine(lastPivot, actual, Color(60, 255, 100), true)
    render.DrawWireframeSphere(lastPivot, 3, 8, 8, Color(80, 180, 255), true)
    render.DrawWireframeSphere(actual, 3, 8, 8, Color(60, 255, 100), true)
end)

hook.Add("HUDPaint", "RE4M_CameraMovement_DebugHUD", function()
    if not cvDebug:GetBool() or not cvCamera:GetBool() then return end
    local y = ScrH() * 0.78
    draw.SimpleText("RE4M CAMERA  |  " .. cameraState, "DermaDefaultBold", 18, y,
        Color(255, 220, 120), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText("Pivot: " .. tostring(lastPivot) .. "  Camera: " .. tostring(smoothedOrigin),
        "DermaDefault", 18, y + 18, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    if lastTrace then
        draw.SimpleText("Collision: " .. (lastTrace.Hit and "blocked" or "clear"),
            "DermaDefault", 18, y + 34,
            lastTrace.Hit and Color(255, 100, 100) or Color(100, 255, 130),
            TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end
end)

hook.Add("OnReloaded", "RE4M_CameraMovement_Reset", ResetRig)
hook.Add("PlayerBindPress", "RE4M_CameraMovement_ResetAfterFocus", function(_, bind, pressed)
    if not pressed then return end
    if string.find(bind, "messagemode", 1, true) or string.find(bind, "cancelselect", 1, true) then
        ResetRig()
    end
end)
