-- RE4 Mercenaries – wOS Animations and Gaemplay Systems

util.AddNetworkString("RE4M_ParryRequest")
util.AddNetworkString("RE4M_PlayParryAnim")
util.AddNetworkString("RE4M_ParryHit") -- for metal flash + parry sound

local PARRY_COOLDOWN = {}

-- ============================================
-- Movement lock while the wOS parry anim plays
-- ============================================
hook.Add("SetupMove", "RE4M_ParryLockMovement", function(ply, mv, cmd)
    local parryEnd = ply:GetNW2Float("RE4M_ParryTime", 0)
    if parryEnd > CurTime() then
        mv:SetForwardSpeed(0)
        mv:SetSideSpeed(0)
        mv:SetUpSpeed(0)
        mv:SetMaxClientSpeed(0)
    end
end)

local function RE4M_ForceParryAnim(ply)
    if not IsValid(ply) then return end

    local cfg = RE4MERCS_GetConfig()
    local duration = (cfg and cfg.ParryDuration) or 0.95

    ply:SetNW2Float("RE4M_ParryTime", CurTime() + duration)
    ply:AnimRestartMainSequence()

    net.Start("RE4M_PlayParryAnim")
    net.Send(ply)

    -- Play draw + whoosh on start
    ply:EmitSound("re4mercs/knife_draw.wav", 75, 100, 0.9)
    timer.Simple(0.08, function()
        if IsValid(ply) then
            ply:EmitSound("re4mercs/knife_whoosh.wav", 70, math.random(95, 105), 0.7)
        end
    end)
end

net.Receive("RE4M_ParryRequest", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if RE4M_STATE.GameState ~= GAMESTATE_ACTIVE then return end

    local cfg = RE4MERCS_GetConfig()
    if not cfg or not cfg.ParryEnabled then return end

    local sid = ply:SteamID64()
    if PARRY_COOLDOWN[sid] and PARRY_COOLDOWN[sid] > CurTime() then return end

    -- Always play the animation + sounds + knife model
    PARRY_COOLDOWN[sid] = CurTime() + (cfg.ParryCooldown or 0.9)
    RE4M_ForceParryAnim(ply)

    -- Check for successful parry
    local range = cfg.ParryRange or 120
    local hitPos = nil

    for _, ent in ipairs(ents.FindInSphere(ply:GetPos(), range)) do
        if not IsValid(ent) then continue end
        if not (ent.IsDrGNextbot or ent:IsNextBot()) then continue end
        if not ent.Parryable then continue end

        local attacking = false
        if ent.IsAttacking and isfunction(ent.IsAttacking) and ent:IsAttacking() then
            attacking = true
        else
            local seqName = string.lower(ent:GetSequenceName(ent:GetSequence()) or "")
            if string.find(seqName, "att") and not string.find(seqName, "grab") and not string.find(seqName, "idle") then
                attacking = true
            end
        end

        if not attacking then continue end

        -- Successful parry – force flinch
        if ent.ParriedAnimation and ent.ParriedAnimation ~= "" then
            if isfunction(ent.CICO) then
                ent:CICO(function(self)
                    self:PlaySequenceAndMove(self.ParriedAnimation, 1.15)
                end)
            else
                ent:PlaySequenceAndMove(ent.ParriedAnimation, 1.15)
            end
        end

        -- Punish damage
        local dmg = DamageInfo()
        dmg:SetAttacker(ply)
        dmg:SetInflictor(ply)
        dmg:SetDamage(5)
        dmg:SetDamageType(DMG_CLUB)
        ent:TakeDamageInfo(dmg)

        hitPos = ent:WorldSpaceCenter()
        break
    end

    -- If we hit something, play the parry sound + tell clients to spawn the flash
    if hitPos then
        -- Play the heavy metal clash sound at the impact point
        sound.Play("re4mercs/knife_parry.wav", hitPos, 80, math.random(95, 105), 1)

        net.Start("RE4M_ParryHit")
            net.WriteVector(hitPos)
        net.Broadcast()
    end
end)

-- Keep the force command for testing
concommand.Add("re4m_forceparry", function(ply)
    if not IsValid(ply) then return end
    RE4M_ForceParryAnim(ply)
end)