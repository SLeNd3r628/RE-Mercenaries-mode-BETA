-- RE4 Mercenaries Remake - Scoring System (Server)
-- Updated to track last kill score and time for floating text

--- Called when a player kills an NPC/NextBot
function RE4M_OnKill(ply, victim, dmgInfo)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if RE4M_STATE.GameState ~= GAMESTATE_ACTIVE then return end

    -- Guard against double-crediting the same kill. OnNPCKilled (and the
    -- NextBot OnKilled override) can sometimes fire more than once for the
    -- same entity - e.g. from splash/simultaneous damage - which was
    -- causing combo/score/kills to increment by 2 instead of 1.
    if IsValid(victim) then
        if victim.RE4M_KillCredited then return end
        victim.RE4M_KillCredited = true

        local weaponClass
        if victim.RE4M_LastDamageAttacker == ply then
            weaponClass = victim.RE4M_LastWeaponClass
        end

        if not weaponClass and dmgInfo and dmgInfo.GetInflictor then
            local inflictor = dmgInfo:GetInflictor()
            if IsValid(inflictor) and inflictor:IsWeapon() then
                weaponClass = inflictor:GetClass()
            end
        end

        if not weaponClass then
            local activeWeapon = ply:GetActiveWeapon()
            if IsValid(activeWeapon) then weaponClass = activeWeapon:GetClass() end
        end
        if weaponClass then RE4M_RecordWeaponKill(ply, weaponClass) end
    end

    local cfg = RE4MERCS_GetConfig()

    -- Increment kills
    local kills = ply:RE4M_GetKills() + 1
    ply:SetNWInt("RE4M_Kills", kills)

    -- Increment combo
    local combo = ply:RE4M_GetCombo() + 1
    ply:SetNWInt("RE4M_Combo", combo)

    -- Track max combo
    if combo > ply:RE4M_GetMaxCombo() then
        ply:SetNWInt("RE4M_MaxCombo", combo)
    end

    -- Reset combo timer
    ply.RE4M_LastKillTime = CurTime()

    -- Calculate score
    local baseScore = cfg.BaseKillScore or 500
    local multiplier = RE4MERCS_GetComboMultiplier(combo)
    local bonus = 0

    -- Headshot bonus. Uses the hit group of the killing blow on THIS victim;
    -- it used to read the attacker's last hit on any NPC, so headshotting one
    -- enemy and then blowing up another still paid a headshot bonus.
    local hitGroup = IsValid(victim) and victim.RE4M_LastHitGroup or HITGROUP_GENERIC
    if hitGroup == HITGROUP_HEAD then
        bonus = bonus + (cfg.HeadshotBonus or 250)
    end

    -- Elite kill bonus
    if IsValid(victim) and victim.RE4M_IsElite then
        bonus = bonus + (cfg.EliteKillBonus or 750)
    end

    -- Melee kill bonus. OnNPCKilled provides no DamageInfo, so NPC melee kills
    -- never got this bonus; fall back to the damage type recorded on the victim.
    local damageType = dmgInfo and dmgInfo:GetDamageType() or (IsValid(victim) and victim.RE4M_LastDamageType) or 0
    if bit.band(damageType, bit.bor(DMG_CLUB, DMG_SLASH)) ~= 0 then
        bonus = bonus + (cfg.MeleeKillBonus or 300)
    end

    local totalScore = math.floor((baseScore + bonus) * multiplier)
    if combo > 50 and RE4M_PlayerHasSkill and RE4M_PlayerHasSkill(ply, "limit_breaker") then
        totalScore = math.floor(totalScore * 1.10)
    end
    local currentScore = ply:RE4M_GetScore()
    ply:SetNWInt("RE4M_Score", currentScore + totalScore)

    -- Time extension on kill
    local timeExtend = cfg.TimeExtendOnKill or 2
    RE4M_ExtendTime(timeExtend, ply)

    -- Store for floating text system
    ply.RE4M_LastKillScore = totalScore
    ply.RE4M_LastTimeAdded = timeExtend

    -- Combo milestone bonuses
    local comboTimeExtends = {
        [10]  = cfg.TimeExtendOnCombo10 or 5,
        [25]  = cfg.TimeExtendOnCombo25 or 10,
        [50]  = cfg.TimeExtendOnCombo50 or 15,
        [100] = cfg.TimeExtendOnCombo100 or 30,
    }

    if comboTimeExtends[combo] then
        local bonusTime = comboTimeExtends[combo]
        if RE4M_PlayerHasSkill and RE4M_PlayerHasSkill(ply, "combo_bonus") then
            bonusTime = math.floor(bonusTime * 1.25)
        end
        RE4M_ExtendTime(bonusTime, ply)
        ply.RE4M_LastTimeAdded = timeExtend + bonusTime

        -- Send combo milestone popup
        net.Start("RE4M_ComboPopup")
            net.WriteUInt(combo, 16)
            net.WriteFloat(bonusTime)
        net.Send(ply)

        -- Play sound with increasing pitch. The old code emitted a sound path
        -- that is not shipped, then ALSO played the fallback.
        local milestoneSound = file.Exists("sound/ui/combo_milestone.ogg", "GAME")
            and "ui/combo_milestone.ogg" or "buttons/button15.wav"
        ply:EmitSound(milestoneSound, 60, 100 + math.min(combo, 50), 0.7)
    end

    -- Send kill feed notification
    net.Start("RE4M_KillFeed")
        net.WriteUInt(totalScore, 24)
        net.WriteUInt(combo, 16)
        net.WriteFloat(multiplier)
        net.WriteBool(bonus > 0)
    net.Send(ply)

    -- Send score update
    net.Start("RE4M_ScoreUpdate")
        net.WriteUInt(ply:RE4M_GetScore(), 32)
        net.WriteUInt(combo, 16)
        net.WriteFloat(multiplier)
    net.Send(ply)

    -- Floating kill score for everyone. This was only sent from the
    -- OnNPCKilled hook, so NextBot kills credited through their OnKilled
    -- override showed no score float unless the bot also ran that hook.
    local deathPos = Vector(0, 0, 0)
    if IsValid(victim) then
        local ok, pos = pcall(victim.GetPos, victim)
        if ok and pos then deathPos = pos end
    end
    net.Start("RE4M_EnemyKilled")
        net.WriteVector(deathPos)
        net.WriteUInt(math.min(totalScore, 16777215), 24)
        net.WriteFloat(ply.RE4M_LastTimeAdded or 0)
        net.WriteBool(IsValid(victim) and victim.RE4M_IsElite or false)
        net.WriteEntity(ply)
    net.Broadcast()

    -- Try to spawn a pickup
    RE4M_TrySpawnPickup(victim)
end

--- Reset a player's combo
function RE4M_ResetCombo(ply, reason)
    if not IsValid(ply) then return end

    local oldCombo = ply:RE4M_GetCombo()
    if oldCombo <= 0 then return end

    ply:SetNWInt("RE4M_Combo", 0)
    ply.RE4M_LastKillTime = 0

    net.Start("RE4M_ScoreUpdate")
        net.WriteUInt(ply:RE4M_GetScore(), 32)
        net.WriteUInt(0, 16)
        net.WriteFloat(1.0)
    net.Send(ply)

    if RE4MERCS_CONFIG and RE4MERCS_CONFIG.Debug then
        print("[RE4 Mercs] " .. ply:Nick() .. " combo reset (" .. reason .. "): was " .. oldCombo)
    end
end

--- Reset combo when player takes damage.
--- PostEntityTakeDamage only runs after every EntityTakeDamage hook and
--- PlayerShouldTakeDamage, and reports whether damage was actually applied.
--- On EntityTakeDamage, the combo was also reset by hits that roll/parry
--- i-frames or friendly-fire protection blocked.
--- Tell a player they were hit, and from where, for the gethit screen
--- effect (cl_hud.lua). Only damage that was actually applied counts, so
--- hits blocked by roll/parry i-frames or friendly-fire rules show nothing.
hook.Add("PostEntityTakeDamage", "RE4M_PlayerHitFeedback", function(target, dmgInfo, took)
    if not took or not IsValid(target) or not target:IsPlayer() or dmgInfo:GetDamage() <= 0 then return end

    local source
    local attacker = dmgInfo:GetAttacker()
    if IsValid(attacker) and attacker ~= target then
        source = attacker:WorldSpaceCenter()
    else
        local hitPos = dmgInfo:GetDamagePosition()
        if isvector(hitPos) and hitPos ~= vector_origin then source = hitPos end
    end

    net.Start("RE4M_PlayerHit")
        net.WriteBool(source ~= nil)
        if source then net.WriteVector(source) end
    net.Send(target)
end)

hook.Remove("EntityTakeDamage", "RE4M_PlayerDamageComboReset")
hook.Add("PostEntityTakeDamage", "RE4M_PlayerDamageComboReset", function(target, dmgInfo, took)
    if not took or RE4M_STATE.GameState ~= GAMESTATE_ACTIVE then return end
    if not IsValid(target) or not target:IsPlayer() then return end
    if dmgInfo:GetDamage() <= 0 then return end

    local cfg = RE4MERCS_GetConfig()
    if not cfg.ComboResetOnDamage then return end

    if dmgInfo:GetAttacker() == target then return end
    RE4M_ResetCombo(target, "damage taken")
end)
