-- RE4 Mercenaries Remake - Round Management (Server)

-- Retained between same-map round resets so consecutive matches do not
-- restart with the same BGM track.
local previousRoundMusicPath

local function RE4M_AdminCleanupThen(callback)
    local hookID = "RE4M_AdminCleanupBeforeMenuRespawn"
    local timeoutID = "RE4M_AdminCleanupTimeout"
    local done = false

    local function finish()
        if done then return end
        done = true
        hook.Remove("PostCleanupMap", hookID)
        timer.Remove(timeoutID)
        if callback then callback() end
    end

    hook.Remove("PostCleanupMap", hookID)
    hook.Add("PostCleanupMap", hookID, finish)

    -- gmod_admin_cleanup comes from Sandbox's cleanup module. This gamemode
    -- derives from "base", where that command may not exist. Previously the
    -- function just bailed out in that case, so players were never respawned
    -- and the lobby never reopened. Fall back to game.CleanUpMap directly.
    if concommand.GetTable().gmod_admin_cleanup then
        game.ConsoleCommand("gmod_admin_cleanup\n")
        -- Safety net in case the command is blocked and never cleans up.
        timer.Create(timeoutID, 2, 1, function()
            if done then return end
            game.CleanUpMap()
            finish()
        end)
    else
        game.CleanUpMap()
        finish()
    end
end

local function RE4M_RespawnForMenu(ply)
    if not IsValid(ply) then return end

    -- Spawn alone can leave a dead player's previous observer/death camera
    -- attached when the mode is restarted on the same map.
    ply:Freeze(false)
    ply:UnSpectate()
    ply:SetObserverMode(OBS_MODE_NONE)
    ply:Spawn()
    ply:SetViewEntity(ply)
    ply:Freeze(true)
    ply:StripWeapons()
end

--- Start the pre-round countdown
function RE4M_StartPreRound()
    timer.Remove("RE4M_LastPlayerDeathEnd")
    timer.Remove("RE4M_PreRound")
    timer.Remove("RE4M_RoundTick")
    timer.Remove("RE4M_ComboDecay")
    timer.Remove("RE4M_PostRoundCleanup")
    timer.Remove("RE4M_PostRoundResults")
    timer.Remove("RE4M_ReturnToMenu")

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
            ply:UnSpectate()
            ply:SetObserverMode(OBS_MODE_NONE)
            ply:Spawn()
            ply:SetViewEntity(ply)
        end

        ply:Freeze(true)
        ply:SetMaxHealth(cfg.PlayerHealth or 150)
        ply:SetHealth(cfg.PlayerHealth or 150)
        ply:SetArmor(cfg.PlayerArmor or 50)
    end

    -- Clean up any existing NPCs and pickups
    RE4M_CleanupNPCs()
    RE4M_CleanupPickups()

    -- Select a random track, excluding the track used in the previous match
    -- whenever at least one alternative exists.
    local tracks = cfg.RoundMusic or {}
    if #tracks > 0 then
        local candidates = {}
        for index, path in ipairs(tracks) do
            if #tracks == 1 or path ~= previousRoundMusicPath then
                candidates[#candidates + 1] = {index = index, path = path}
            end
        end
        if #candidates == 0 then
            for index, path in ipairs(tracks) do
                candidates[#candidates + 1] = {index = index, path = path}
            end
        end

        local choice = candidates[math.random(1, #candidates)]
        RE4M_STATE.MusicTrack = choice.index
        previousRoundMusicPath = choice.path
    end

    -- Pre-round countdown
    local preTime = cfg.PreRoundTime or 10

    -- Broadcast countdown start
    SetGlobalFloat("RE4M_PreRoundEnd", CurTime() + preTime)

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

        for _, ply in ipairs(player.GetAll()) do
            if ply:Alive() and ply:RE4M_GetCombo() > 0 then
                local comboTimeout = cfg.ComboTimeout or 8
                local roundRemaining = (RE4M_STATE.RoundEndTime or CurTime()) - CurTime()
                if roundRemaining <= 30 and RE4M_PlayerHasSkill and RE4M_PlayerHasSkill(ply, "go_for_broke") then
                    comboTimeout = comboTimeout + 2
                end
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
    if RE4M_STATE.GameState ~= GAMESTATE_ACTIVE then return end
    seconds = tonumber(seconds) or 0
    if seconds ~= seconds or seconds <= 0 then return end -- reject NaN / non-positive

    local cfg = RE4MERCS_GetConfig()
    local maxTime = cfg.MaxRoundTime or 600

    local currentRemaining = RE4M_STATE.RoundEndTime - CurTime()
    local newRemaining = math.min(currentRemaining + seconds, maxTime)
    local added = newRemaining - currentRemaining

    RE4M_STATE.RoundEndTime = CurTime() + newRemaining
    SetGlobalFloat("RE4M_RoundEndTime", RE4M_STATE.RoundEndTime)

    -- Notify the player who earned the extension. Report what was actually
    -- added, which is less than requested when the MaxRoundTime cap is hit.
    if IsValid(ply) and added > 0.05 then
        net.Start("RE4M_TimeExtend")
            net.WriteFloat(math.Round(added, 1))
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
    timer.Create("RE4M_PostRoundCleanup", 2, 1, function()
        if RE4M_STATE.GameState ~= GAMESTATE_POSTROUND then return end
        RE4M_CleanupNPCs()
        RE4M_CleanupPickups()
    end)

    -- Build and send results
    timer.Create("RE4M_PostRoundResults", 3, 1, function()
        if RE4M_STATE.GameState ~= GAMESTATE_POSTROUND then return end
        RE4M_SendResults()
    end)

    -- Return to menu after post-round time
    local cfg = RE4MERCS_GetConfig()
    local postTime = cfg.PostRoundTime or 15

    timer.Create("RE4M_ReturnToMenu", math.max(0, postTime), 1, function()
        if RE4M_STATE.GameState ~= GAMESTATE_POSTROUND then return end
        RE4M_ReturnToMenu()
    end)
end

--- Send round results to all players
function RE4M_SendResults()
    local results = {}

    for _, ply in ipairs(player.GetAll()) do
        local score = ply:RE4M_GetScore()
        local rankName, rankColor = RE4MERCS_GetRank(score)
        local xpGained = 0
        local mpGained = 0

        -- Each player's final score is converted to persistent player XP once
        -- per round. This XP is shared across the player's full profile.
        if ply.RE4M_ProgressionAwardedRound ~= RE4M_STATE.RoundNumber then
            -- Award a small fraction of final score so persistent levels take
            -- a long time to earn: 1 XP for each 100 score points.
            xpGained, mpGained = RE4M_AwardPlayerXP(ply, math.floor(score / 100))
            ply.RE4M_ProgressionAwardedRound = RE4M_STATE.RoundNumber
        end

        table.insert(results, {
            name     = ply:Nick(),
            steamid  = ply:SteamID(),
            score    = score,
            xpGained = xpGained,
            mpGained = mpGained,
            level    = ply:GetNWInt("RE4M_PlayerLevel", 1),
            xp       = ply:GetNWInt("RE4M_PlayerXP", 0),
            kills    = ply:RE4M_GetKills(),
            maxCombo = ply:RE4M_GetMaxCombo(),
            rank     = rankName,
        })
    end

    RE4M_SaveProgression()
    RE4M_SendLobbyProgression()

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
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            ply.RE4M_Ready = false
            ply:SetNWBool("RE4M_Ready", false)
        end
    end

    RE4M_SetGameState(GAMESTATE_MENU)

    -- Run the actual Garry's Mod Admin Cleanup before resetting players. Its
    -- PostCleanupMap hook marks completion, so respawns happen after entities
    -- and the previous round's ragdolls/camera state have been cleared.
    RE4M_AdminCleanupThen(function()
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) then
                RE4M_RespawnForMenu(ply)

                -- Force menu open
                net.Start("RE4M_ForceMenu")
                net.Send(ply)
            end
        end
    end)
end
