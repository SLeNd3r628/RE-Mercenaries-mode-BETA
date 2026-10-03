-- RE4 Mercenaries Remake - Loot Drop Controller (Server)
-- Smart HP-based priority dropping with RE4-style pickups

-- ============================================
-- DROP CONFIGURATION
-- ============================================

local DROP_SETTINGS = {
    -- Overall chance for any drop on NPC kill (0-1)
    BaseDropChance = 0.20,

    -- Delay before spawning the pickup (prevents clipping into corpse)
    SpawnDelay = 2.5,

    -- Spawn height offset above death position
    SpawnHeightOffset = 25,

    -- Health thresholds for priority drops
    HealthCritical = 20,    -- At or below this = very high herb chance
    HealthLow = 60,         -- At or below this = moderate herb chance
    HealthMedium = 100,     -- Above this = mostly ammo

    -- Drop weights by health state
    -- Format: {health = weight, ammo = weight, time = weight}
    CriticalHealthWeights = {health = 70, ammo = 20, time = 10},
    LowHealthWeights      = {health = 45, ammo = 40, time = 15},
    NormalHealthWeights    = {health = 10, ammo = 65, time = 25},
    FullHealthWeights      = {health = 5,  ammo = 70, time = 25},

    -- Entity classes for each drop type
    DropEntities = {
        health = "re_greenherb",
        ammo   = "re_ammopickup",
        time   = "re_timepickup",
    },
}

-- ============================================
-- WEIGHTED RANDOM SELECTION
-- ============================================

--- Pick a random type from weighted table
local function WeightedRandom(weights)
    local totalWeight = 0
    for _, w in pairs(weights) do
        totalWeight = totalWeight + w
    end

    if totalWeight <= 0 then return "ammo" end

    local roll = math.random() * totalWeight
    local accumulated = 0

    for pickupType, weight in pairs(weights) do
        accumulated = accumulated + weight
        if roll <= accumulated then
            return pickupType
        end
    end

    return "ammo"  -- Fallback
end

-- ============================================
-- DETERMINE DROP TYPE BASED ON PLAYER STATE
-- ============================================

--- Decide what to drop based on the attacking player's current state
local function DetermineDropType(ply)
    if not IsValid(ply) then return "ammo" end

    local health = ply:Health()
    local maxHealth = ply:GetMaxHealth()
    local healthFrac = health / math.max(maxHealth, 1)

    -- Select weight table based on health
    local weights

    if health <= DROP_SETTINGS.HealthCritical then
        weights = DROP_SETTINGS.CriticalHealthWeights
    elseif health <= DROP_SETTINGS.HealthLow then
        weights = DROP_SETTINGS.LowHealthWeights
    elseif health < maxHealth then
        weights = DROP_SETTINGS.NormalHealthWeights
    else
        weights = DROP_SETTINGS.FullHealthWeights
    end

    -- Override from config if available
    local cfg = RE4MERCS_GetConfig and RE4MERCS_GetConfig()
    if cfg and cfg.PickupWeights then
        -- Use config weights as base but still factor in health priority
        if health <= DROP_SETTINGS.HealthCritical then
            -- Critical health always prioritizes herbs regardless of config
            weights = DROP_SETTINGS.CriticalHealthWeights
        elseif health <= DROP_SETTINGS.HealthLow then
            -- Low health uses a blend
            weights = {
                health = math.max(cfg.PickupWeights.health or 35, 40),
                ammo   = cfg.PickupWeights.ammo or 40,
                time   = cfg.PickupWeights.time or 25,
            }
        end
    end

    return WeightedRandom(weights)
end

-- ============================================
-- SPAWN PICKUP FUNCTION
-- ============================================

--- Spawn a pickup at a position after a delay
function RE4M_SpawnPickupDelayed(pos, pickupType, delay)
    delay = delay or DROP_SETTINGS.SpawnDelay

    -- Validate pickup type
    local entityClass = DROP_SETTINGS.DropEntities[pickupType]
    if not entityClass then
        entityClass = DROP_SETTINGS.DropEntities.ammo
        pickupType = "ammo"
    end

    -- Adjust position upward
    local spawnPos = pos + Vector(0, 0, DROP_SETTINGS.SpawnHeightOffset)

    timer.Simple(delay, function()
        -- Make sure the round is still active
        if RE4M_STATE and RE4M_STATE.GameState ~= GAMESTATE_ACTIVE then return end

        local ent = ents.Create(entityClass)
        if not IsValid(ent) then
            -- Fallback: try creating the entity anyway
            if RE4MERCS_CONFIG and RE4MERCS_CONFIG.Debug then
                print("[RE4 Mercs Drops] Failed to create " .. entityClass .. ", class may not exist")
            end
            return
        end

        ent:SetPos(spawnPos)
        ent:SetAngles(Angle(0, math.random(0, 360), 0))

        local ok, err = pcall(function()
            ent:Spawn()
            ent:Activate()
        end)

        if not ok then
            print("[RE4 Mercs Drops] Spawn failed: " .. tostring(err))
            if IsValid(ent) then
                pcall(ent.Remove, ent)
            end
            return
        end

        -- Apply a small upward force so it pops up
        local phys = ent:GetPhysicsObject()
        if IsValid(phys) and ent:GetClass() == "re_ammopickup" then
            phys:ApplyForceCenter(Vector(0, 0, 150))
        end

        -- Track in pickup list
        if RE4M_STATE then
            table.insert(RE4M_STATE.Pickups, ent)
        end
        ent.RE4M_Pickup = true
        ent.RE4M_TouchReadyAt = CurTime() + 0.75 -- let it land before touch pickup

        -- re4m_pickuplifetime was never applied; the entities only removed
        -- themselves after their own hard-coded 25 seconds.
        local cfg = RE4MERCS_GetConfig and RE4MERCS_GetConfig()
        local lifetime = cfg and tonumber(cfg.PickupLifetime) or 20
        if lifetime > 0 then
            timer.Simple(lifetime, function()
                if IsValid(ent) and not ent.Used then ent:Remove() end
            end)
        end

        if RE4MERCS_CONFIG and RE4MERCS_CONFIG.Debug then
            print("[RE4 Mercs Drops] Spawned " .. pickupType .. " (" .. entityClass .. ") at " .. tostring(spawnPos))
        end
    end)
end

--- Spawn a pickup immediately (no delay)
function RE4M_SpawnPickupImmediate(pos, pickupType)
    RE4M_SpawnPickupDelayed(pos, pickupType, 0)
end

-- ============================================
-- TRY SPAWN PICKUP ON KILL
-- Called from sv_scoring.lua when an NPC dies
-- ============================================

function RE4M_TrySpawnPickup(victim)
    if not IsValid(victim) then return end
    if RE4M_STATE and RE4M_STATE.GameState ~= GAMESTATE_ACTIVE then return end

    -- Get overall drop chance
    local dropChance = DROP_SETTINGS.BaseDropChance
    local cfg = RE4MERCS_GetConfig and RE4MERCS_GetConfig()
    if cfg and cfg.PickupDropChance then
        dropChance = cfg.PickupDropChance
    end

    -- Elite enemies have higher drop chance
    if victim.RE4M_IsElite then
        dropChance = math.min(dropChance * 2.5, 0.8)  -- Up to 80% for elites
    end
    local dropOwner = victim.RE4M_LastDamageAttacker
    if IsValid(dropOwner) and dropOwner:IsPlayer() and RE4M_PlayerHasSkill and RE4M_PlayerHasSkill(dropOwner, "item_drop") then
        dropChance = math.min(dropChance * 1.5, 0.95)
    end

    -- Roll for drop
    if math.random() > dropChance then return end

    -- Get death position safely
    local ok, deathPos = pcall(victim.GetPos, victim)
    if not ok or not deathPos then return end

    -- Prefer the player who last damaged this NPC so skill-based drop
    -- bonuses and the drop type belong to the correct player.
    local attacker = victim.RE4M_LastDamageAttacker
    if not IsValid(attacker) or not attacker:IsPlayer() then attacker = nil end

    -- If no player damage source was recorded, use the nearest living player.
    if not attacker then
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:IsPlayer() and ply:Alive() then
                if not attacker then
                    attacker = ply
                elseif ply:GetPos():DistToSqr(deathPos) < attacker:GetPos():DistToSqr(deathPos) then
                    attacker = ply
                end
            end
        end
    end

    -- Determine what to drop
    local dropType = DetermineDropType(attacker)

    -- Spawn it with delay
    RE4M_SpawnPickupDelayed(deathPos, dropType)
end

-- ============================================
-- APPLY PICKUP EFFECT ON TOUCH
-- This was previously missing entirely: pickups would spawn
-- but touching them did nothing and never notified the client.
-- ============================================

--- Map an entity class back to its pickup type ("health"/"ammo"/"time")
local function RE4M_ClassToPickupType(className)
    for pickupType, entClass in pairs(DROP_SETTINGS.DropEntities) do
        if entClass == className then return pickupType end
    end
    return nil
end

function RE4M_CollectPickup(ply, ent)
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() or not IsValid(ent) then return false end
    if RE4M_STATE.GameState ~= GAMESTATE_ACTIVE or ent.Used then return false end

    local pickupType = RE4M_ClassToPickupType(ent:GetClass())
    if not pickupType then return false end -- not one of ours

    -- Shared by touch and the custom third-person USE request. Mark it before
    -- awarding anything so simultaneous touch/use inputs cannot double-collect.
    ent.Used = true

    local cfg = RE4MERCS_GetConfig and RE4MERCS_GetConfig() or {}
    local ammoDisplayLabel

    if pickupType == "health" then
        local amount = cfg.HealthPickupAmount or 25
        if RE4M_PlayerHasSkill and RE4M_PlayerHasSkill(ply, "pharmacist") then amount = math.floor(amount * 1.5) end
        ply:SetHealth(math.min(ply:Health() + amount, ply:GetMaxHealth()))
        if RE4M_PlayerHasSkill and RE4M_PlayerHasSkill(ply, "medic") then
            for _, teammate in ipairs(player.GetAll()) do
                if teammate ~= ply and IsValid(teammate) and teammate:Alive() and
                    teammate:GetPos():DistToSqr(ply:GetPos()) <= 700 * 700 then
                    teammate:SetHealth(math.min(teammate:Health() + math.floor(amount * 0.5), teammate:GetMaxHealth()))
                end
            end
        end
        if RE4M_PlayerHasSkill and RE4M_PlayerHasSkill(ply, "first_responder") then
            for _, teammate in ipairs(player.GetAll()) do
                if teammate ~= ply and IsValid(teammate) and teammate:Alive() and
                    teammate:GetPos():DistToSqr(ply:GetPos()) > 700 * 700 and teammate:GetPos():DistToSqr(ply:GetPos()) <= 2500 * 2500 then
                    teammate:SetHealth(math.min(teammate:Health() + 20, teammate:GetMaxHealth()))
                end
            end
        end

    elseif pickupType == "ammo" and math.random(1, 1000) <= 25 then
        -- Rare explosive roll (2.5%), matching the ammo entity's own Use().
        -- The client already had notifications for these, but routing pickups
        -- through this collector had made them impossible to get.
        if math.random(1, 25) <= 5 then
            pickupType = "rare_rpg"
            ply:GiveAmmo(1, "RPG_Round")
        else
            pickupType = "rare_grenade"
            ply:GiveAmmo(1, "Grenade")
            ply:GiveAmmo(1, "SMG1_Grenade")
        end

    elseif pickupType == "ammo" then
        local wep = ply:GetActiveWeapon()
        local category = ent:GetNW2String("RE4M_AmmoCategory", "")
        if category ~= "" then
            local matchTokens = {
                pistol = {"pistol", "9mm", "sidearm"},
                smg = {"smg", "ar2", "rifle", "assault"},
                shotgun = {"buckshot", "shotgun", "shell"},
                sniper = {"sniper", "rifle", "338", "762"},
                magnum = {"357", "magnum", "revolver"},
                mine = {"mine", "slam", "grenade"},
            }
            local tokens = matchTokens[category]
            if tokens then
                for _, candidate in ipairs(ply:GetWeapons()) do
                    if not IsValid(candidate) then continue end
                    local candidateAmmo = candidate:GetPrimaryAmmoType()
                    local candidateName = candidateAmmo and candidateAmmo >= 0 and game.GetAmmoName(candidateAmmo) or ""
                    local lowerName = string.lower(tostring(candidateName or ""))
                    local matched = false
                    for _, token in ipairs(tokens) do
                        if string.find(lowerName, token, 1, true) then
                            wep = candidate
                            matched = true
                            break
                        end
                    end
                    if matched then break end
                end
            end
        end
        if IsValid(wep) then
            local ammoType = wep:GetPrimaryAmmoType()
            if ammoType and ammoType >= 0 then
                local ammoName = game.GetAmmoName(ammoType)
                ammoDisplayLabel = RE4M_AmmoDisplayLabel and RE4M_AmmoDisplayLabel(ammoName) or ammoName
                local maxAmmo = game.GetAmmoMax(ammoType) or 100
                local giveAmt = math.max(1, math.floor(maxAmmo * (cfg.AmmoPickupMultiplier or 0.25)))
                if RE4M_GiveAmmo then
                    RE4M_GiveAmmo(ply, giveAmt, ammoType)
                else
                    ply:GiveAmmo(giveAmt, ammoType)
                end
            end
        end

    elseif pickupType == "time" then
        local seconds = cfg.TimePickupAmount or 10
        if RE4M_PlayerHasSkill and RE4M_PlayerHasSkill(ply, "time_bonus") then seconds = math.floor(seconds * 1.5) end
        RE4M_ExtendTime(seconds, ply) -- this already nets RE4M_TimeExtend to ply
    end

    -- Tell the client what was picked up (drives the on-screen notification)
    net.Start("RE4M_PickupCollected")
        net.WriteString(pickupType)
        if pickupType == "ammo" then net.WriteString(ammoDisplayLabel or "AMMO") end
    net.Send(ply)

    local soundType = string.StartWith(pickupType, "rare_") and "ammo" or pickupType
    local fallbackSounds = {
        health = "items/smallmedkit1.wav",
        ammo   = "items/ammo_pickup.wav",
        time   = "buttons/button9.wav",
    }
    if file.Exists("sound/ui/pickup_" .. soundType .. ".ogg", "GAME") then
        ply:EmitSound("ui/pickup_" .. soundType .. ".ogg", 60, 100, 0.6)
    elseif fallbackSounds[soundType] then
        ply:EmitSound(fallbackSounds[soundType], 60, 100, 0.6)
    end

    -- Untrack and remove the world entity
    for i, tracked in ipairs(RE4M_STATE.Pickups or {}) do
        if tracked == ent then
            table.remove(RE4M_STATE.Pickups, i)
            break
        end
    end

    if IsValid(ent) then
        pcall(ent.Remove, ent)
    end
    return true
end

-- Walk-over pickup. There is no "PlayerTouch" gamemode hook, so the old hook
-- never ran and touching a drop did nothing. Poll the few tracked drops
-- instead. Herbs are left for the USE key while at full health so they are
-- not wasted by walking over them.
local TOUCH_RADIUS_SQR = 60 * 60
timer.Create("RE4M_PickupTouch", 0.1, 0, function()
    if not RE4M_STATE or RE4M_STATE.GameState ~= GAMESTATE_ACTIVE then return end
    local pickups = RE4M_STATE.Pickups
    if not pickups or #pickups == 0 then return end

    local now = CurTime()
    local players = player.GetAll()
    for i = #pickups, 1, -1 do
        local ent = pickups[i]
        if not IsValid(ent) then
            table.remove(pickups, i)
        elseif not ent.Used and (ent.RE4M_TouchReadyAt or 0) <= now then
            local entPos = ent:GetPos()
            for _, ply in ipairs(players) do
                if IsValid(ply) and ply:Alive() and ply:GetPos():DistToSqr(entPos) <= TOUCH_RADIUS_SQR then
                    local isHerb = ent:GetClass() == DROP_SETTINGS.DropEntities.health
                    if not isHerb or ply:Health() < ply:GetMaxHealth() then
                        if RE4M_CollectPickup(ply, ent) then break end
                    end
                end
            end
        end
    end
end)

-- The pickup entities' own ENT:Use() heals a random 25-50, ignores
-- re4m_healthpickupamount and every pickup skill (Pharmacist, Medic, Time
-- Bonus...). Route default USE on them through the gamemode collector.
function RE4M_IsModePickup(ent)
    return IsValid(ent) and RE4M_ClassToPickupType(ent:GetClass()) ~= nil
end

-- ============================================
-- CLEANUP
-- ============================================

-- NOTE: RE4M_CleanupPickups() and RE4M_MonitorPickups() used to be
-- redefined here too, duplicating sv_spawning.lua's versions with no
-- functional difference. They are now defined ONLY in sv_spawning.lua.
