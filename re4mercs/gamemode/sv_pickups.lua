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
        if IsValid(phys) then
            phys:ApplyForceCenter(Vector(0, 0, 150))
        end

        -- Track in pickup list
        if RE4M_STATE then
            table.insert(RE4M_STATE.Pickups, ent)
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

    -- Roll for drop
    if math.random() > dropChance then return end

    -- Get death position safely
    local ok, deathPos = pcall(victim.GetPos, victim)
    if not ok or not deathPos then return end

    -- Find the attacker to determine drop type
    -- We look for the player who last damaged this NPC
    local attacker = nil

    -- Check all players and find the one closest / who killed it
    -- The scoring system tracks this, but as a fallback just find nearest
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Alive() then
            if not attacker then
                attacker = ply
            elseif ply:GetPos():DistToSqr(deathPos) < attacker:GetPos():DistToSqr(deathPos) then
                attacker = ply
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

hook.Add("PlayerTouch", "RE4M_PickupTouch", function(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then return end
    if not ply:Alive() then return end
    if RE4M_STATE.GameState ~= GAMESTATE_ACTIVE then return end

    local pickupType = RE4M_ClassToPickupType(ent:GetClass())
    if not pickupType then return end -- not one of ours

    local cfg = RE4MERCS_GetConfig and RE4MERCS_GetConfig() or {}

    if pickupType == "health" then
        local amount = cfg.HealthPickupAmount or 25
        ply:SetHealth(math.min(ply:Health() + amount, ply:GetMaxHealth()))

    elseif pickupType == "ammo" then
        local wep = ply:GetActiveWeapon()
        if IsValid(wep) then
            local ammoType = wep:GetPrimaryAmmoType()
            if ammoType and ammoType >= 0 then
                local maxAmmo = game.GetAmmoMax(ammoType) or 100
                local giveAmt = math.max(1, math.floor(maxAmmo * (cfg.AmmoPickupMultiplier or 0.25)))
                ply:GiveAmmo(giveAmt, ammoType)
            end
        end

    elseif pickupType == "time" then
        local seconds = cfg.TimePickupAmount or 10
        RE4M_ExtendTime(seconds, ply) -- this already nets RE4M_TimeExtend to ply
    end

    -- Tell the client what was picked up (drives the on-screen notification)
    net.Start("RE4M_PickupCollected")
        net.WriteString(pickupType)
    net.Send(ply)

    if file.Exists("sound/ui/pickup_" .. pickupType .. ".ogg", "GAME") then
        ply:EmitSound("ui/pickup_" .. pickupType .. ".ogg", 60, 100, 0.6)
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
end)

-- NOTE: "rare_rpg" / "rare_grenade" pickup types are referenced client-side
-- (cl_init.lua RE4M_PickupCollected receiver) but there are no matching
-- entity classes or drop weights defined anywhere server-side. If you want
-- these, add them to DROP_SETTINGS.DropEntities above and give them a
-- weight in the health/low/normal/full weight tables, e.g.:
--   DropEntities.rare_rpg = "re_rpgammo_pickup"
--   CriticalHealthWeights.rare_rpg = 2  (and to the other weight tables)
-- Until then they will simply never be rolled by WeightedRandom().

-- ============================================
-- CLEANUP
-- ============================================

-- NOTE: RE4M_CleanupPickups() and RE4M_MonitorPickups() used to be
-- redefined here too, duplicating sv_spawning.lua's versions with no
-- functional difference. They are now defined ONLY in sv_spawning.lua.