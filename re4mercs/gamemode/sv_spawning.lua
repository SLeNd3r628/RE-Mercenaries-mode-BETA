-- RE4 Mercenaries Remake - Dynamic NPC Spawning (Server)

local spawnTimerName    = "RE4M_SpawnLoop"
local cleanupTimerName  = "RE4M_CleanupLoop"
local retargetTimerName = "RE4M_RetargetNPCs"
local ragdollTimerName  = "RE4M_RagdollCleanup"
local teleportTimerName = "RE4M_TeleportStray"

-- ============================================
-- CONSTANTS
-- ============================================

-- How far (squared) an NPC must be before we consider teleporting it
local STRAY_DIST_SQR       = 2500 * 2500   -- 2500 units
-- How close to a player an NPC must be to NOT get teleported
local NEAR_PLAYER_DIST_SQR = 1200 * 1200
-- Minimum time an NPC must have been alive before we teleport it
local MIN_ALIVE_BEFORE_TELEPORT = 8         -- seconds
-- How many teleport candidates we process per timer tick (perf budget)
local TELEPORT_BATCH_SIZE   = 4
-- How often the teleport timer fires (seconds)
local TELEPORT_TIMER_RATE   = 10
-- How often retarget fires (seconds)
local RETARGET_TIMER_RATE   = 12
-- Max attempts finding a navmesh spawn position
local NAV_SPAWN_ATTEMPTS    = 8

-- ============================================
-- NAVMESH CACHE
-- ============================================

RE4M_CachedNavAreas = nil

function RE4M_CacheNavAreas()
    local areas = navmesh.GetAllNavAreas()
    if areas and #areas > 0 then
        RE4M_CachedNavAreas = areas
        RE4M_STATE.HasNavmesh = true
        print("[RE4 Mercs Spawner] Cached " .. #areas .. " nav areas.")
    else
        RE4M_CachedNavAreas = nil
        RE4M_STATE.HasNavmesh = false
        print("[RE4 Mercs Spawner] WARNING: No nav areas found – fallback spawning active.")
    end
end

-- ============================================
-- ELITE SPAWN RULES
-- 25 kills  = 1 elite max
-- 50 kills  = 2 elites max
-- 90 kills  = 3 elites max
-- 130+ kills = 3 elites max (cap)
-- ============================================

local ELITE_THRESHOLDS = {
    { kills = 25,  maxElites = 1 },
    { kills = 50,  maxElites = 2 },
    { kills = 90,  maxElites = 3 },
    { kills = 130, maxElites = 3 },
}

-- Full elite group size: when this many elites are alive simultaneously,
-- normal spawning is PAUSED until all of them are dead.
local ELITE_PAUSE_COUNT = 3   -- matches the cap above; adjust if thresholds change

function RE4M_GetTotalKills()
    local total = 0
    for _, ply in ipairs(player.GetAll()) do
        total = total + (ply:GetNWInt("RE4M_Kills", 0))
    end
    return total
end

function RE4M_GetMaxElites()
    local totalKills = RE4M_GetTotalKills()
    local maxElites  = 0
    for _, threshold in ipairs(ELITE_THRESHOLDS) do
        if totalKills >= threshold.kills then
            maxElites = threshold.maxElites
        end
    end
    return maxElites
end

function RE4M_GetActiveEliteCount()
    local count = 0
    for _, ent in ipairs(RE4M_STATE.ActiveNPCs) do
        if IsValid(ent) and ent.RE4M_IsElite then
            count = count + 1
        end
    end
    return count
end

-- Enemy levels follow the most progressed player in the current lobby,
-- including connected players who are currently dead or spectating.
function RE4M_GetHighestLobbyPlayerLevel()
    local highest = 1
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            highest = math.max(highest, ply:GetNWInt("RE4M_PlayerLevel", 1))
        end
    end
    return highest
end

function RE4M_GetEnemyLevelRange(playerLevel)
    playerLevel = math.max(1, math.floor(tonumber(playerLevel) or 1))
    local minimum = math.max(1, math.floor(playerLevel * 0.8))
    local maximum = math.max(minimum, math.ceil(playerLevel * 1.16))
    return minimum, maximum
end

function RE4M_ShouldSpawnElite()
    local maxElites = RE4M_GetMaxElites()
    if maxElites <= 0 then return false end
    return RE4M_GetActiveEliteCount() < maxElites
end

-- ============================================
-- ELITE GROUP PAUSE LOGIC
-- Returns true when normal spawning should be blocked
-- because a full elite group (ELITE_PAUSE_COUNT) is active.
-- ============================================

function RE4M_EliteGroupActive()
    local eliveCount = RE4M_GetActiveEliteCount()
    -- Only pause when we actually hit the group threshold AND kills
    -- have unlocked at least that many elites.
    return (eliveCount >= ELITE_PAUSE_COUNT) and (RE4M_GetMaxElites() >= ELITE_PAUSE_COUNT)
end

-- ============================================
-- SPAWN POSITION FINDING
-- Fixed: ground-trace, player-distance check,
--        navmesh-less map support, safer fallback.
-- ============================================

function RE4M_GetSpawnPosition()
    local cfg = RE4MERCS_GetConfig()
    if not cfg then
        ErrorNoHalt("[RE4 Mercs Spawner] RE4M_GetSpawnPosition: config is nil!\n")
        return nil
    end

    local minDistSqr = (cfg.MinSpawnDistance or 800) ^ 2
    local players    = player.GetAll()

    -- ---- Nav-mesh path ----
    local navAreas = RE4M_CachedNavAreas
    if navAreas and #navAreas > 0 then
        for i = 1, NAV_SPAWN_ATTEMPTS do
            local area = navAreas[math.random(#navAreas)]
            if not area then continue end

            local pos = area:GetRandomPoint()

            -- Snap to ground and reject positions inside solid geometry.
            local tr = util.TraceLine({
                start  = pos + Vector(0, 0, 100),
                endpos = pos - Vector(0, 0, 500),
                mask   = MASK_SOLID_BRUSHONLY,
            })

            if not tr.Hit then continue end  -- floating / skybox point
            pos = tr.HitPos + Vector(0, 0, 32)

            -- Reject if inside a solid (started inside brush).
            if tr.StartSolid then continue end

            -- Sanity hull-check: make sure an NPC-sized box fits here.
            local hullTr = util.TraceHull({
                start  = pos + Vector(0, 0, 36),
                endpos = pos + Vector(0, 0, 36),
                mins   = Vector(-16, -16, 0),
                maxs   = Vector(16, 16, 72),
                mask   = MASK_NPCSOLID,
            })
            if hullTr.StartSolid then continue end

            -- Reject if too close to any alive player.
            local tooClose = false
            for _, ply in ipairs(players) do
                if IsValid(ply) and ply:Alive() then
                    if ply:GetPos():DistToSqr(pos) < minDistSqr then
                        tooClose = true
                        break
                    end
                end
            end
            if not tooClose then return pos end
        end
        -- Fell through all attempts – fall through to fallback below.
    end

    -- ---- Fallback: offset from a random living player ----
    -- Used on navmesh-less maps or when nav attempts all failed.
    local alivePlayers = {}
    for _, ply in ipairs(players) do
        if IsValid(ply) and ply:Alive() then
            table.insert(alivePlayers, ply)
        end
    end
    if #alivePlayers == 0 then return nil end

    -- Try several random offsets so we don't always spawn in the same spot.
    for attempt = 1, 8 do
        local ply    = alivePlayers[math.random(#alivePlayers)]
        local angle  = math.random(360)
        local dist   = math.random(700, 1100)
        local offset = Vector(math.cos(math.rad(angle)) * dist,
                              math.sin(math.rad(angle)) * dist,
                              0)
        local candidate = ply:GetPos() + offset

        -- Drop to ground.
        local tr = util.TraceLine({
            start  = candidate + Vector(0, 0, 200),
            endpos = candidate - Vector(0, 0, 600),
            mask   = MASK_SOLID_BRUSHONLY,
        })
        if not tr.Hit or tr.StartSolid then continue end
        local pos = tr.HitPos + Vector(0, 0, 32)

        -- Hull clearance check.
        local hullTr = util.TraceHull({
            start  = pos + Vector(0, 0, 36),
            endpos = pos + Vector(0, 0, 36),
            mins   = Vector(-16, -16, 0),
            maxs   = Vector(16, 16, 72),
            mask   = MASK_NPCSOLID,
        })
        if hullTr.StartSolid then continue end

        -- Not on top of a player.
        local onPlayer = false
        for _, p in ipairs(players) do
            if IsValid(p) and p:GetPos():DistToSqr(pos) < (80 ^ 2) then
                onPlayer = true
                break
            end
        end
        if not onPlayer then return pos end
    end

    return nil  -- genuinely couldn't find anything safe
end

-- ============================================
-- NPC CLASS SELECTION
-- ============================================

function RE4M_GetThemeNPCs()
    local cfg = RE4MERCS_GetConfig()
    if not cfg then
        return { "npc_zombie", "npc_fastzombie" }, { "npc_poisonzombie" }
    end

    local theme     = RE4M_STATE.CurrentTheme or "default"
    local themeData = cfg.ThemeNPCs and cfg.ThemeNPCs[theme]

    if not themeData then
        return { "npc_zombie", "npc_fastzombie" }, { "npc_poisonzombie" }
    end

    local regular = themeData.regular or {}
    local elite   = themeData.elite   or {}

    if theme == "default" and themeData.re4_regular then
        local testClass = themeData.re4_regular[1]
        if testClass and scripted_ents.GetStored(testClass) then
            regular = themeData.re4_regular
            elite   = themeData.re4_elite or elite
        end
    end

    if #regular == 0 then regular = { "npc_zombie", "npc_fastzombie", "npc_headcrab_fast" } end
    if #elite   == 0 then elite   = { "npc_poisonzombie", "npc_antlionguard" }             end

    return regular, elite
end

-- ============================================
-- TELEPORT HELPERS
-- ============================================

-- Find a safe position near a player suitable for a teleporting NPC.
local function RE4M_FindTeleportPos(targetPlayer)
    if not IsValid(targetPlayer) then return nil end

    local players = player.GetAll()
    local navAreas = RE4M_CachedNavAreas

    -- Prefer a nearby nav area that is out of the player's direct line of sight.
    if navAreas and #navAreas > 0 then
        local pPos = targetPlayer:GetPos()

        -- Collect candidates within a radius band.
        local candidates = {}
        for _, area in ipairs(navAreas) do
            local aPos = area:GetCenter()
            local dSqr = pPos:DistToSqr(aPos)
            if dSqr > 600 * 600 and dSqr < 1400 * 1400 then
                table.insert(candidates, area)
            end
        end

        -- Shuffle a subset so we don't always try the same areas.
        for attempt = 1, math.min(12, #candidates) do
            local area = candidates[math.random(#candidates)]
            local pos  = area:GetRandomPoint()

            local tr = util.TraceLine({
                start  = pos + Vector(0, 0, 100),
                endpos = pos - Vector(0, 0, 500),
                mask   = MASK_SOLID_BRUSHONLY,
            })
            if not tr.Hit or tr.StartSolid then continue end
            pos = tr.HitPos + Vector(0, 0, 32)

            local hullTr = util.TraceHull({
                start  = pos + Vector(0, 0, 36),
                endpos = pos + Vector(0, 0, 36),
                mins   = Vector(-16, -16, 0),
                maxs   = Vector(16, 16, 72),
                mask   = MASK_NPCSOLID,
            })
            if hullTr.StartSolid then continue end

            -- Make sure we're not teleporting onto a player.
            local blocked = false
            for _, p in ipairs(players) do
                if IsValid(p) and p:GetPos():DistToSqr(pos) < (80 ^ 2) then
                    blocked = true
                    break
                end
            end
            if not blocked then return pos end
        end
    end

    -- Fallback: ring offset from the player.
    for attempt = 1, 8 do
        local angle = math.random(360)
        local dist  = math.random(700, 1200)
        local pos   = targetPlayer:GetPos() +
                      Vector(math.cos(math.rad(angle)) * dist,
                             math.sin(math.rad(angle)) * dist,
                             0)

        local tr = util.TraceLine({
            start  = pos + Vector(0, 0, 200),
            endpos = pos - Vector(0, 0, 600),
            mask   = MASK_SOLID_BRUSHONLY,
        })
        if not tr.Hit or tr.StartSolid then continue end
        pos = tr.HitPos + Vector(0, 0, 32)

        local hullTr = util.TraceHull({
            start  = pos + Vector(0, 0, 36),
            endpos = pos + Vector(0, 0, 36),
            mins   = Vector(-16, -16, 0),
            maxs   = Vector(16, 16, 72),
            mask   = MASK_NPCSOLID,
        })
        if not hullTr.StartSolid then return pos end
    end

    return nil
end

-- Find the closest alive player to a given world position.
local function RE4M_ClosestPlayer(pos)
    local nearest, nearestDist = nil, math.huge
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Alive() then
            local d = ply:GetPos():DistToSqr(pos)
            if d < nearestDist then
                nearestDist = d
                nearest     = ply
            end
        end
    end
    return nearest, nearestDist
end

-- ============================================
-- SINGLE NPC SPAWN (with pcall safety)
-- ============================================

function RE4M_SpawnEnemy(pos, forceElite)
    if not pos then return nil end

    local regularNPCs, eliteNPCs = RE4M_GetThemeNPCs()

    local isElite   = forceElite or false
    local classList = isElite and eliteNPCs or regularNPCs

    if #classList == 0 then
        classList = regularNPCs
        isElite   = false
    end
    if #classList == 0 then
        ErrorNoHalt("[RE4 Mercs Spawner] RE4M_SpawnEnemy: no NPC classes available!\n")
        return nil
    end

    local enemyClass = classList[math.random(#classList)]

    local enemy = ents.Create(enemyClass)
    if not IsValid(enemy) then
        if RE4MERCS_CONFIG and RE4MERCS_CONFIG.Debug then
            print("[RE4 Mercs Spawner] Failed to create: " .. tostring(enemyClass))
        end
        return nil
    end

    enemy:SetPos(pos)
    enemy:SetAngles(Angle(0, math.random(0, 360), 0))

    local spawnOk, spawnErr = pcall(function()
        enemy:Spawn()
        enemy:Activate()
    end)

    if not spawnOk then
        print("[RE4 Mercs Spawner] Spawn/Activate crashed: " .. tostring(spawnErr))
        if IsValid(enemy) then pcall(enemy.Remove, enemy) end
        return nil
    end

    enemy.RE4M_Spawned   = true
    enemy.RE4M_IsElite   = isElite
    enemy.RE4M_SpawnTime = CurTime()
    enemy:SetNWBool("RE4M_Spawned", true)
    enemy:SetNWBool("RE4M_IsElite", isElite)
    local playerLevel = RE4M_GetHighestLobbyPlayerLevel()
    local minEnemyLevel, maxEnemyLevel = RE4M_GetEnemyLevelRange(playerLevel)
    local enemyLevel = math.random(minEnemyLevel, maxEnemyLevel)
    enemy.RE4M_Level = enemyLevel
    enemy:SetNWInt("RE4M_EnemyLevel", enemyLevel)

    -- Scale from the entity's initialized health so custom NPC/NextBot base
    -- values remain intact. Elite health keeps its existing 1.5x multiplier.
    local healthScale = 1 + math.max(0, enemyLevel - 1) * 0.05
    if isElite then healthScale = healthScale * 1.5 end
    pcall(function()
        local originalHealth = math.max(tonumber(enemy:Health()) or 0, 1)
        local originalMaxHealth = math.max(tonumber(enemy:GetMaxHealth()) or 0, originalHealth)
        local scaledMaxHealth = math.max(1, math.floor(originalMaxHealth * healthScale))
        local healthFraction = math.Clamp(originalHealth / originalMaxHealth, 0, 1)
        enemy:SetMaxHealth(scaledMaxHealth)
        enemy:SetHealth(math.max(1, math.floor(scaledMaxHealth * healthFraction)))
        enemy:SetNWInt("RE4M_EnemyMaxHealth", scaledMaxHealth)
    end)

    if isElite then
        pcall(function()
            enemy:SetModelScale(1.2, 0)
        end)

        timer.Simple(0.1, function()
            if IsValid(enemy) then
                pcall(function() enemy:SetColor(Color(255, 100, 100)) end)
            end
        end)
    end

    local maxHealth = math.max(enemy:GetNWInt("RE4M_EnemyMaxHealth", enemy:GetMaxHealth()), 1)
    enemy:SetNWFloat("RE4M_HealthFrac", math.Clamp(enemy:Health() / maxHealth, 0, 1))

    -- Deferred AI setup (runs next tick, avoids calling NPC functions before
    -- the engine has fully initialised the entity).
    timer.Simple(0, function()
        if not IsValid(enemy) then return end

        pcall(function()
            if enemy:IsNPC() then
                enemy:SetKeyValue("spawnflags", "256")

                local allPlayers = player.GetAll()
                for _, ply in ipairs(allPlayers) do
                    if IsValid(ply) then
                        enemy:AddEntityRelationship(ply, D_HT, 99)
                    end
                end

                -- Target the nearest player immediately.
                local nearest, nearestDist = RE4M_ClosestPlayer(enemy:GetPos())
                if nearest then
                    enemy:SetEnemy(nearest)
                    enemy:UpdateEnemyMemory(nearest, nearest:GetPos())
                    enemy:SetSchedule(SCHED_CHASE_ENEMY)
                end

            elseif enemy:IsNextBot() then
                local oldOnKilled = enemy.OnKilled
                enemy.OnKilled = function(self, dmgInfo)
                    local attacker = dmgInfo:GetAttacker()
                    if IsValid(attacker) and attacker:IsPlayer() then
                        RE4M_OnKill(attacker, self, dmgInfo)
                    end
                    for i, tracked in ipairs(RE4M_STATE.ActiveNPCs) do
                        if tracked == self then
                            table.remove(RE4M_STATE.ActiveNPCs, i)
                            break
                        end
                    end
                    if oldOnKilled then return oldOnKilled(self, dmgInfo) end
                end
            end
        end)
    end)

    if RE4MERCS_CONFIG and RE4MERCS_CONFIG.DebugSpawns then
        local tag = isElite and "[ELITE] " or ""
        print("[RE4 Mercs Spawner] Spawned " .. tag .. enemyClass ..
              " (total: " .. (#RE4M_STATE.ActiveNPCs + 1) .. ")")
    end

    return enemy
end

-- ============================================
-- CLEANUP FUNCTIONS
-- ============================================

function RE4M_CleanupDead()
    local i = #RE4M_STATE.ActiveNPCs
    while i > 0 do
        local npc    = RE4M_STATE.ActiveNPCs[i]
        local remove = true

        if IsValid(npc) then
            local ok, h = pcall(npc.Health, npc)
            if ok and h and h > 0 then remove = false end
        end

        if remove then table.remove(RE4M_STATE.ActiveNPCs, i) end
        i = i - 1
    end
end

function RE4M_CleanupRagdolls()
    local now = CurTime()
    for _, ent in ipairs(ents.FindByClass("prop_ragdoll")) do
        if IsValid(ent) and ent.RE4M_Ragdoll then
            if (now - ent:GetCreationTime()) > 5 then
                pcall(ent.Remove, ent)
            end
        end
    end

    -- Also purge dead NPCs that slipped through the death hook.
    local i = #RE4M_STATE.ActiveNPCs
    while i > 0 do
        local ent = RE4M_STATE.ActiveNPCs[i]
        if IsValid(ent) and ent.RE4M_Spawned then
            local ok, h = pcall(ent.Health, ent)
            if ok and h and h <= 0 then
                pcall(ent.Remove, ent)
                table.remove(RE4M_STATE.ActiveNPCs, i)
            end
        end
        i = i - 1
    end
end

function RE4M_CleanupNPCs()
    for _, npc in ipairs(RE4M_STATE.ActiveNPCs) do
        if IsValid(npc) then pcall(npc.Remove, npc) end
    end
    RE4M_STATE.ActiveNPCs = {}

    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) and (ent:IsNPC() or ent:IsNextBot()) and ent.RE4M_Spawned then
            pcall(ent.Remove, ent)
        end
    end

    RE4M_CleanupRagdolls()
end

function RE4M_CleanupPickups()
    for _, ent in ipairs(RE4M_STATE.Pickups) do
        if IsValid(ent) then pcall(ent.Remove, ent) end
    end
    RE4M_STATE.Pickups = {}
end

function RE4M_MonitorPickups()
    local i = #RE4M_STATE.Pickups
    while i > 0 do
        if not IsValid(RE4M_STATE.Pickups[i]) then
            table.remove(RE4M_STATE.Pickups, i)
        end
        i = i - 1
    end
end

-- ============================================
-- NPC COUNT HELPERS
-- ============================================

function RE4M_GetActiveNPCCount()
    return #RE4M_STATE.ActiveNPCs  -- trust the death hooks to keep this accurate
end

function RE4M_GetMaxNPCs()
    local cfg = RE4MERCS_GetConfig()
    if not cfg then return 25 end

    local playerCount = #player.GetAll()
    local base        = cfg.BaseMaxNPCs      or 25
    local perPlayer   = cfg.MaxNPCsPerPlayer or 8
    local absolute    = cfg.AbsoluteMaxNPCs  or 50

    return math.min(base + (math.max(0, playerCount - 1) * perPlayer), absolute)
end

-- ============================================
-- MAIN SPAWN LOOP
-- ============================================

function RE4M_StartSpawning()
    RE4M_STATE.ActiveNPCs = {}
    RE4M_STATE.Pickups    = {}

    RE4M_CacheNavAreas()

    local cfg = RE4MERCS_GetConfig()
    if not cfg then
        ErrorNoHalt("[RE4 Mercs Spawner] RE4M_StartSpawning: config is nil!\n")
        return
    end

    local spawnRate = math.max(cfg.SpawnInterval or 3, 0.5)

    print("[RE4 Mercs Spawner] Starting spawner (interval: " .. spawnRate ..
          "s, max NPCs: " .. RE4M_GetMaxNPCs() .. ")")

    -- ---- MAIN SPAWN LOOP ----
    -- Spawns ONE NPC per tick to prevent batch-spawn crashes.
    timer.Create(spawnTimerName, spawnRate, 0, function()
        if RE4M_STATE.GameState ~= GAMESTATE_ACTIVE then return end

        local activeCount = RE4M_GetActiveNPCCount()
        local maxNPCs     = RE4M_GetMaxNPCs()
        if activeCount >= maxNPCs then return end

        local shouldElite    = RE4M_ShouldSpawnElite()
        local eliteGroupLive = RE4M_EliteGroupActive()

        -- If a full elite group is active, only allow elite spawns (which will
        -- also return false from ShouldSpawnElite once the cap is met, so
        -- nothing at all spawns until regular enemies thin the elite count).
        if eliteGroupLive and not shouldElite then
            if RE4MERCS_CONFIG and RE4MERCS_CONFIG.DebugSpawns then
                print("[RE4 Mercs Spawner] Normal spawn PAUSED – elite group active.")
            end
            return
        end

        local spawnPos = RE4M_GetSpawnPosition()
        if not spawnPos then return end

        if shouldElite then
            local elite = RE4M_SpawnEnemy(spawnPos, true)
            if IsValid(elite) then
                table.insert(RE4M_STATE.ActiveNPCs, elite)

                net.Start("RE4M_EliteSpawned")
                    net.WriteString(elite:GetClass())
                    net.WriteVector(elite:GetPos())
                net.Broadcast()

                if RE4MERCS_CONFIG and RE4MERCS_CONFIG.Debug then
                    print("[RE4 Mercs Spawner] ELITE spawned! (" ..
                          RE4M_GetActiveEliteCount() .. "/" ..
                          RE4M_GetMaxElites() .. " elites)" ..
                          (RE4M_EliteGroupActive() and " [GROUP ACTIVE – normal pause]" or ""))
                end
            end
        else
            local enemy = RE4M_SpawnEnemy(spawnPos, false)
            if IsValid(enemy) then
                table.insert(RE4M_STATE.ActiveNPCs, enemy)
            end
        end
    end)

    -- ---- CLEANUP LOOP ----
    timer.Create(cleanupTimerName, 6, 0, function()
        if RE4M_STATE.GameState ~= GAMESTATE_ACTIVE then return end
        RE4M_CleanupDead()
        RE4M_CleanupRagdolls()
        RE4M_MonitorPickups()
    end)

    -- ---- RETARGET LOOP ----
    -- Makes all NPCs hunt the nearest (or a random) alive player.
    timer.Create(retargetTimerName, RETARGET_TIMER_RATE, 0, function()
        if RE4M_STATE.GameState ~= GAMESTATE_ACTIVE then return end

        local alivePlayers = {}
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:Alive() then
                table.insert(alivePlayers, ply)
            end
        end
        if #alivePlayers == 0 then return end

        local aliveCount = #alivePlayers

        for _, npc in ipairs(RE4M_STATE.ActiveNPCs) do
            if IsValid(npc) and npc:IsNPC() then
                pcall(function()
                    local target
                    if math.random() < 0.7 then
                        -- 70 %: nearest player.
                        local nearestDist = math.huge
                        for _, ply in ipairs(alivePlayers) do
                            local d = npc:GetPos():DistToSqr(ply:GetPos())
                            if d < nearestDist then
                                nearestDist = d
                                target      = ply
                            end
                        end
                    else
                        -- 30 %: random player (keeps things unpredictable).
                        target = alivePlayers[math.random(aliveCount)]
                    end

                    if target then
                        npc:SetEnemy(target)
                        npc:UpdateEnemyMemory(target, target:GetPos())
                        npc:SetSchedule(SCHED_CHASE_ENEMY)
                    end
                end)
            end
        end
    end)

    -- ---- STRAY-NPC TELEPORT LOOP ----
    -- Any NPC that is too far from ALL players gets teleported to a safe
    -- position near the closest player.  We process only TELEPORT_BATCH_SIZE
    -- candidates per tick to cap the per-frame trace budget.
    local teleportIndex = 1   -- rolling cursor through ActiveNPCs

    timer.Create(teleportTimerName, TELEPORT_TIMER_RATE, 0, function()
        if RE4M_STATE.GameState ~= GAMESTATE_ACTIVE then return end

        local alivePlayers = {}
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:Alive() then
                table.insert(alivePlayers, ply)
            end
        end
        if #alivePlayers == 0 then return end

        local total     = #RE4M_STATE.ActiveNPCs
        if total == 0 then teleportIndex = 1 return end

        -- Clamp the cursor in case the list shrank since last tick.
        if teleportIndex > total then teleportIndex = 1 end

        local processed = 0
        local startIdx  = teleportIndex

        repeat
            local npc = RE4M_STATE.ActiveNPCs[teleportIndex]

            -- Advance cursor (wrap around).
            teleportIndex = teleportIndex + 1
            if teleportIndex > total then teleportIndex = 1 end

            if IsValid(npc) and npc.RE4M_Spawned then
                -- Don't teleport NPCs that just spawned.
                local age = CurTime() - (npc.RE4M_SpawnTime or 0)
                if age >= MIN_ALIVE_BEFORE_TELEPORT then
                    local npcPos              = npc:GetPos()
                    local closestPly, distSqr = RE4M_ClosestPlayer(npcPos)

                    if closestPly and distSqr > STRAY_DIST_SQR then
                        -- NPC is too far – find a safe spot near that player.
                        local telePos = RE4M_FindTeleportPos(closestPly)
                        if telePos then
                            pcall(function()
                                npc:SetPos(telePos)
                                -- Refresh targeting immediately after the warp.
                                if npc:IsNPC() then
                                    npc:SetEnemy(closestPly)
                                    npc:UpdateEnemyMemory(closestPly, closestPly:GetPos())
                                    npc:SetSchedule(SCHED_CHASE_ENEMY)
                                end
                            end)

                            if RE4MERCS_CONFIG and RE4MERCS_CONFIG.DebugSpawns then
                                print(string.format(
                                    "[RE4 Mercs Spawner] Teleported stray %s to %s (was %.0f units away)",
                                    npc:GetClass(), tostring(telePos),
                                    math.sqrt(distSqr)))
                            end
                        end
                    end
                end
            end

            processed = processed + 1
        until processed >= TELEPORT_BATCH_SIZE or teleportIndex == startIdx
    end)
end

function RE4M_StopSpawning()
    timer.Remove(spawnTimerName)
    timer.Remove(cleanupTimerName)
    timer.Remove(retargetTimerName)
    timer.Remove(ragdollTimerName)
    timer.Remove(teleportTimerName)
    print("[RE4 Mercs Spawner] Spawner stopped.")
end

-- ============================================
-- NPC DEATH HOOKS
-- ============================================

hook.Add("OnNPCKilled", "RE4M_NPCKilled", function(npc, attacker, inflictor)
    if not npc.RE4M_Spawned then return end
    if RE4M_STATE.GameState ~= GAMESTATE_ACTIVE then return end

    if IsValid(attacker) and attacker:IsPlayer() then
        local ok, deathPos = pcall(npc.GetPos, npc)
        local npcPos = ok and deathPos or Vector(0, 0, 0)

        RE4M_OnKill(attacker, npc, nil)

        local lastScore = attacker.RE4M_LastKillScore or 500
        local timeAdded = attacker.RE4M_LastTimeAdded  or 2

        net.Start("RE4M_EnemyKilled")
            net.WriteVector(npcPos)
            net.WriteUInt(lastScore, 24)
            net.WriteFloat(timeAdded)
            net.WriteBool(npc.RE4M_IsElite or false)
            net.WriteEntity(attacker)
        net.Broadcast()

    end

    for i, tracked in ipairs(RE4M_STATE.ActiveNPCs) do
        if tracked == npc then
            table.remove(RE4M_STATE.ActiveNPCs, i)
            break
        end
    end
end)

hook.Add("ScaleNPCDamage", "RE4M_TrackHitGroup", function(npc, hitGroup, dmgInfo)
    if not npc.RE4M_Spawned then return end
    local attacker = dmgInfo:GetAttacker()
    if IsValid(attacker) and attacker:IsPlayer() then
        attacker.RE4M_LastHitGroup = hitGroup
    end
end)

hook.Add("EntityRemoved", "RE4M_TrackNPCRemovals", function(ent)
    if not ent.RE4M_Spawned then return end
    for i, tracked in ipairs(RE4M_STATE.ActiveNPCs) do
        if tracked == ent then
            table.remove(RE4M_STATE.ActiveNPCs, i)
            break
        end
    end
end)

-- ============================================
-- FLOATING DAMAGE NUMBERS / HEALTH SYNC
-- ============================================

hook.Add("EntityTakeDamage", "RE4M_DamageEvents", function(target, dmgInfo)
    if RE4M_STATE.GameState ~= GAMESTATE_ACTIVE then return end
    if not IsValid(target) then return end
    if not target.RE4M_Spawned then return end

    local attacker = dmgInfo:GetAttacker()

    if IsValid(attacker) and attacker:IsPlayer() then
        local damage = dmgInfo:GetDamage()
        local hitPos = dmgInfo:GetDamagePosition()
        if hitPos:LengthSqr() < 1 then
            hitPos = target:WorldSpaceCenter() or (target:GetPos() + Vector(0, 0, 36))
        end

        local hitGroup   = attacker.RE4M_LastHitGroup or HITGROUP_GENERIC
        local isHeadshot = (hitGroup == HITGROUP_HEAD)

        local ok, h   = pcall(target.Health, target)
        local willKill = ok and h and (h - damage <= 0)

        net.Start("RE4M_DamageNumber")
            net.WriteVector(hitPos)
            net.WriteUInt(math.max(1, math.floor(damage)), 16)
            net.WriteBool(isHeadshot)
            net.WriteBool(willKill or false)
            net.WriteEntity(target)
        net.Send(attacker)  -- only the shooter needs to see their own damage numbers
    end

    -- Coalesce same-tick damage events, but never drop the final health update.
    if target.RE4M_HealthSyncPending then return end
    target.RE4M_HealthSyncPending = true
    timer.Simple(0, function()
        if not IsValid(target) then return end
        target.RE4M_HealthSyncPending = nil
        local ok, h   = pcall(target.Health, target)
        local ok2, mh = pcall(target.GetMaxHealth, target)
        if ok and ok2 and h and mh and mh > 0 then
            target:SetNWFloat("RE4M_HealthFrac", math.Clamp(h / mh, 0, 1))
            target:SetNWBool("RE4M_IsElite", target.RE4M_IsElite or false)
        end
    end)
end)

-- Tag only ragdolls produced by this mode's enemies. The previous kill hook
-- searched every ragdoll after every kill, and missed matches accumulated.
hook.Add("CreateEntityRagdoll", "RE4M_TagEnemyRagdolls", function(source, ragdoll)
    if not IsValid(source) or not source.RE4M_Spawned or not IsValid(ragdoll) then return end
    ragdoll.RE4M_Ragdoll = true
end)

-- ============================================
-- DEBUG COMMANDS
-- ============================================

concommand.Add("re4m_debug_spawns", function(ply, cmd, args)
    if IsValid(ply) and not ply:RE4M_IsAdmin() then return end
    if not RE4MERCS_CONFIG then
        local msg = "[RE4 Mercs] Config not loaded."
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
        return
    end
    RE4MERCS_CONFIG.DebugSpawns = not (RE4MERCS_CONFIG.DebugSpawns or false)
    local msg = "[RE4 Mercs] Debug spawns: " .. tostring(RE4MERCS_CONFIG.DebugSpawns)
    if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
end)

concommand.Add("re4m_test_spawn", function(ply, cmd, args)
    if IsValid(ply) and not ply:RE4M_IsAdmin() then return end
    if not RE4M_CachedNavAreas or #RE4M_CachedNavAreas == 0 then
        RE4M_CacheNavAreas()
    end
    print("[RE4 Mercs] Cached nav areas: " .. (RE4M_CachedNavAreas and #RE4M_CachedNavAreas or 0))
    local pos = RE4M_GetSpawnPosition()
    if pos then
        print("[RE4 Mercs] Found spawn pos: " .. tostring(pos))
        local npc = RE4M_SpawnEnemy(pos, false)
        if IsValid(npc) then
            table.insert(RE4M_STATE.ActiveNPCs, npc)
            local msg = "[RE4 Mercs] Test NPC spawned!"
            if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
        else
            local msg = "[RE4 Mercs] Failed to spawn test NPC."
            if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
        end
    else
        local msg = "[RE4 Mercs] No spawn position found."
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
    end
end)

concommand.Add("re4m_test_elite", function(ply, cmd, args)
    if IsValid(ply) and not ply:RE4M_IsAdmin() then return end
    local pos = RE4M_GetSpawnPosition()
    if pos then
        local npc = RE4M_SpawnEnemy(pos, true)
        if IsValid(npc) then
            table.insert(RE4M_STATE.ActiveNPCs, npc)
            local msg = "[RE4 Mercs] Test ELITE spawned!"
            if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
        else
            local msg = "[RE4 Mercs] Failed to spawn test ELITE."
            if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
        end
    else
        local msg = "[RE4 Mercs] No spawn position found."
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
    end
end)

concommand.Add("re4m_npc_count", function(ply, cmd, args)
    if IsValid(ply) and not ply:RE4M_IsAdmin() then return end
    local count      = RE4M_GetActiveNPCCount()
    local max        = RE4M_GetMaxNPCs()
    local elites     = RE4M_GetActiveEliteCount()
    local maxElites  = RE4M_GetMaxElites()
    local totalKills = RE4M_GetTotalKills()
    local paused     = RE4M_EliteGroupActive() and " [NORMAL SPAWN PAUSED]" or ""

    local msg = string.format(
        "[RE4 Mercs] NPCs: %d/%d | Elites: %d/%d | Kills: %d%s",
        count, max, elites, maxElites, totalKills, paused)
    if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
end)
