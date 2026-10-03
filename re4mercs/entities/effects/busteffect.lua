-- RE4 Mercenaries adaptation of the smoke burst effect from mightyfootengaged
function EFFECT:Init(data)
	local pos = data:GetOrigin()
	local normal = data:GetNormal()
	local magnitude = data:GetMagnitude()
	local emitter = ParticleEmitter(pos)
	if not emitter then return end

	-- render.GetSurfaceColor returns a Vector (x/y/z in 0-1), not a Color.
	-- The old code read .r/.g/.b off that Vector, which are nil, so every door
	-- kick threw a Lua error and showed no smoke.
	local surfaceVector = render.GetSurfaceColor(pos - normal * 16, pos - normal * 16 - Vector(0, 0, 32))
	local surfaceColor
	if isvector(surfaceVector) then
		surfaceColor = Color(
			math.Clamp(surfaceVector.x * 255 + 100, 0, 255),
			math.Clamp(surfaceVector.y * 255 + 100, 0, 255),
			math.Clamp(surfaceVector.z * 255 + 100, 0, 255))
	else
		surfaceColor = Color(180, 180, 180)
	end

	for i = 1, 10 do
		local particle = emitter:Add("particle/particle_smokegrenade", pos - normal * 8 + Vector(
			math.Rand(-normal.y, normal.y),
			math.Rand(-normal.x, normal.x),
			normal.z
		) * 20)
		if not particle then continue end

		particle:SetVelocity(-normal * magnitude + VectorRand() * 10)
		particle:SetAirResistance(150)
		particle:SetGravity(Vector(0, 0, 0))
		particle:SetDieTime(math.Rand(1, 2))
		particle:SetStartAlpha(math.Rand(100, 150))
		particle:SetEndAlpha(0)
		particle:SetStartSize(math.Rand(10, 15))
		particle:SetEndSize(math.Rand(20, 30))
		particle:SetRoll(math.Rand(180, 480))
		particle:SetRollDelta(math.Rand(-1, 1))
		particle:SetColor(surfaceColor.r, surfaceColor.g, surfaceColor.b)
		particle:SetLighting(true)
		particle:SetCollide(true)
		particle:SetBounce(0.45)
	end

	emitter:Finish()
end

function EFFECT:Think()
	return false
end

function EFFECT:Render()
end
