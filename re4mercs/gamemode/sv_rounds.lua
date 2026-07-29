-- RE4 Mercenaries Remake - Round Management (Server)

--- Start the pre-round countdown
function RE4M_StartPreRound()
    RE4M_SetGameState(GAMESTATE_PREROUND)
    local cfg = RE4MERCS_GetConfig()
    net.Start("RE4M_EchoTeamMessage")
        net.WriteString(cfg.EchoTeamMessage1 or "")
        net.WriteString(cfg.EchoTeamMessage2 or "")
        net.WriteString(cfg.EchoTeamMessage3 or "")
        net.WriteFloat(cfg.EchoTeamMessageDuration or 2.0)
    net.Broadcast()
    RE4M_STATE.RoundNumber = RE4M_STATE.RoundNumber + 1

    -- Reset all player stats
    for _, ply in ipairs(player.GetAll()) do
        ply:SetNWInt("RE4M_Score", 0)
        ply:SetNWInt("RE4M_Combo", 0)
        ply:SetNWInt("RE4M_MaxCombo", 0)
        ply:SetNWInt("RE4M_Kills", 0)
        ply.RE4M_ComboTimer = 0
        ply.RE4M_LastKillTime = 0

        -- Spawn/respawn player
        if not ply:Alive() then
            ply:Spawn()
        end

        ply:Freeze(true)
        ply:SetHealth(cfg.PlayerHealth or 150)
        ply:SetArmor(cfg.PlayerArmor or 50)
    end

    -- Clean up any existing NPCs and pickups
    RE4M_CleanupNPCs()
    RE4M_CleanupPickups()

    -- Select random music track
    local tracks = cfg.RoundMusic or {}
    if #tracks > 0 then
        RE4M_STATE.MusicTrack = math.random(1, #tracks)
    end

    -- Pre-round countdown
    local preTime = cfg.PreRoundTime or 10

    -- Broadcast countdown start
    SetGlobalFloat("RE4M_PreRoundEnd", CurTime() + preTime)

    -- Play countdown sound
    for _, ply in ipairs(player.GetAll()) do
        ply:EmitSound("ui/countdown.ogg", 75, 100, 0.5)
    end

    timer.Create("RE4M_PreRound", preTime, 1, function()
        RE4M_StartRound()
    end)
end

--- Start the active round
function RE4M_StartRound()
    local cfg = RE4MERCS_GetConfig()
    local baseTime = cfg.BaseRoundTime or 120

    RE4M_SetGameState(GAMESTATE_ACTIVE)
    RE4M_STATE.RoundTime = baseTime
    RE4M_STATE.RoundEndTime = CurTime() + baseTime

    -- Set networked timer
    SetGlobalFloat("RE4M_RoundEndTime", RE4M_STATE.RoundEndTime)
    SetGlobalFloat("RE4M_RoundStartTime", CurTime())

    -- Unfreeze players and give loadouts
    for _, ply in ipairs(player.GetAll()) do
        ply:Freeze(false)
        RE4M_GiveLoadout(ply)
        ply:EmitSound("ui/round_start.ogg", 75, 100, 0.8)
    end

    -- Sync music track to all clients
    net.Start("RE4M_SyncMusic")
        net.WriteUInt(RE4M_STATE.MusicTrack, 4)
        net.WriteBool(true)  -- start playing
    net.Broadcast()

    -- Start the spawn system
    RE4M_StartSpawning()

    -- Main round timer tick (runs every 0.5 seconds for time display accuracy)
    timer.Create("RE4M_RoundTick", 0.5, 0, function()
        if RE4M_STATE.GameState ~= GAMESTATE_ACTIVE then
            timer.Remove("RE4M_RoundTick")
            return
        end

        local remaining = RE4M_STATE.RoundEndTime - CurTime()

        if remaining <= 0 then
            RE4M_EndRound()
            return
        end

        -- Broadcast time update periodically
        net.Start("RE4M_TimeUpdate")
            net.WriteFloat(remaining)
        net.Broadcast()
    end)

    -- Combo decay check (runs every second)
    timer.Create("RE4M_ComboDecay", 1, 0, function()
        if RE4M_STATE.GameState ~= GAMESTATE_ACTIVE then
            timer.Remove("RE4M_ComboDecay")
            return
        end

        local comboTimeout = cfg.ComboTimeout or 8

        for _, ply in ipairs(player.GetAll()) do
            if ply:Alive() and ply:RE4M_GetCombo() > 0 then
                local timeSinceKill = CurTime() - (ply.RE4M_LastKillTime or 0)
                if timeSinceKill >= comboTimeout then
                    RE4M_ResetCombo(ply, "timeout")
                end
            end
        end
    end)

    if RE4MERCS_CONFIG.Debug then
        print("[RE4 Mercs] Round started! Duration: " .. baseTime .. "s")
    end
end

--- Extend the round timer
function RE4M_ExtendTime(seconds, ply)
    local cfg = RE4MERCS_GetConfig()
    local maxTime = cfg.MaxRoundTime or 600

    local currentRemaining = RE4M_STATE.RoundEndTime - CurTime()
    local newRemaining = math.min(currentRemaining + seconds, maxTime)

    RE4M_STATE.RoundEndTime = CurTime() + newRemaining
    SetGlobalFloat("RE4M_RoundEndTime", RE4M_STATE.RoundEndTime)

    -- Notify the player who earned the extension
    if IsValid(ply) then
        net.Start("RE4M_TimeExtend")
            net.WriteFloat(seconds)
        net.Send(ply)

        ply:EmitSound("ui/time_extend.ogg", 60, 100, 0.6)
    end
end

--- End the round
function RE4M_EndRound()
    if RE4M_STATE.GameState ~= GAMESTATE_ACTIVE and RE4M_STATE.GameState ~= GAMESTATE_PREROUND then
        return
    end

    RE4M_SetGameState(GAMESTATE_POSTROUND)

    -- Stop spawning
    RE4M_StopSpawning()

    -- Stop timers
    timer.Remove("RE4M_RoundTick")
    timer.Remove("RE4M_ComboDecay")
    timer.Remove("RE4M_PreRound")

    -- Stop music
    net.Start("RE4M_SyncMusic")
        net.WriteUInt(0, 4)
        net.WriteBool(false)  -- stop playing
    net.Broadcast()

    -- Freeze all players
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            ply:Freeze(true)
        end
    end

    -- Play end sound
    for _, ply in ipairs(player.GetAll()) do
        ply:EmitSound("ui/round_end.wav", 75, 100, 0.8)
    end

    -- Clean up NPCs (with slight delay for dramatic effect)
    timer.Simple(2, function()
        RE4M_CleanupNPCs()
        RE4M_CleanupPickups()
    end)

    -- Build and send results
    timer.Simple(3, function()
        RE4M_SendResults()
    end)

    -- Return to menu after post-round time
    local cfg = RE4MERCS_GetConfig()
    local postTime = cfg.PostRoundTime or 15

    timer.Simple(postTime, function()
        RE4M_ReturnToMenu()
    end)
end

--- Send round results to all players
function RE4M_SendResults()
    local results = {}

    for _, ply in ipairs(player.GetAll()) do
        local score = ply:RE4M_GetScore()
        local rankName, rankColor = RE4MERCS_GetRank(score)

        table.insert(results, {
            name     = ply:Nick(),
            steamid  = ply:SteamID(),
            score    = score,
            kills    = ply:RE4M_GetKills(),
            maxCombo = ply:RE4M_GetMaxCombo(),
            rank     = rankName,
        })
    end

    -- Sort by score descending
    table.sort(results, function(a, b) return a.score > b.score end)

    -- Send to all clients
    local data = util.TableToJSON(results)
    local compressed = util.Compress(data)
    local len = #compressed

    net.Start("RE4M_AllScores")
        net.WriteUInt(len, 32)
        net.WriteData(compressed, len)
    net.Broadcast()
end

--- Return to the menu state
function RE4M_ReturnToMenu()
    RE4M_SetGameState(GAMESTATE_MENU)

    -- Respawn and freeze all players
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            ply:Spawn()
            ply:Freeze(true)
            ply:StripWeapons()

            -- Force menu open
            net.Start("RE4M_ForceMenu")
            net.Send(ply)
        end
    end
end

-- NOTE: RE4M_CleanupNPCs() and RE4M_CleanupPickups() used to be redefined
-- here, silently overwriting the more thorough versions in sv_spawning.lua
-- (which also purge leftover ragdolls). They are now defined ONLY in
-- sv_spawning.lua - this file just calls them.