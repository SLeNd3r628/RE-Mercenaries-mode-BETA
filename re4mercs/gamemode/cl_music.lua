-- RE4 Mercenaries Remake - Music System (Client)

local menuSoundStation = nil
local roundSoundStation = nil
local resultsSoundStation = nil
local musicGeneration = {menu = 0, round = 0, results = 0}

local function BeginMusicRequest(kind)
    musicGeneration[kind] = musicGeneration[kind] + 1
    return musicGeneration[kind]
end

local function StopLateStation(station)
    if IsValid(station) then station:Stop() end
end

-- ============================================
-- MENU MUSIC
-- ============================================

function RE4M_PlayMenuMusic()
    RE4M_StopMenuMusic()
    local requestGeneration = musicGeneration.menu

    local cfg = RE4MERCS_GetConfig()
    local musicPath = cfg.MenuMusic or "ui/menu.ogg"
    local volume = cfg.MenuMusicVolume or 0.4

    -- Fallback if file doesn't exist
    if not file.Exists("sound/" .. musicPath, "GAME") then
        local alternatives = {
            "ambient/levels/citadel/strange_talk" .. math.random(1, 11) .. ".wav",
            "music/hl2_song3.mp3",
        }
        for _, alt in ipairs(alternatives) do
            if file.Exists("sound/" .. alt, "GAME") then
                musicPath = alt
                break
            end
        end
    end

    sound.PlayFile("sound/" .. musicPath, "noplay", function(station, errCode, errStr)
        if requestGeneration ~= musicGeneration.menu then
            StopLateStation(station)
            return
        end
        if IsValid(station) then
            menuSoundStation = station
            station:SetVolume(volume)
            station:EnableLooping(true)
            station:Play()
        else
            print("[RE4M] Menu music error: " .. tostring(errStr))
        end
    end)
end

function RE4M_StopMenuMusic()
    BeginMusicRequest("menu")
    if IsValid(menuSoundStation) then
        menuSoundStation:Stop()
        menuSoundStation = nil
    end
end

-- ============================================
-- ROUND MUSIC
-- ============================================

function RE4M_PlayRoundMusic(trackIndex)
    RE4M_StopRoundMusic()
    local requestGeneration = musicGeneration.round

    local cfg = RE4MERCS_GetConfig()
    local tracks = cfg.RoundMusic or {}
    local volume = cfg.RoundMusicVolume or 0.6

    if #tracks == 0 then 
        RE4M_CLIENT.MusicPlaying = false
        return 
    end

    trackIndex = trackIndex or math.random(1, #tracks)
    local musicPath = tracks[math.Clamp(trackIndex, 1, #tracks)]

    -- Fallback if file doesn't exist
    if not file.Exists("sound/" .. musicPath, "GAME") then
        local fallbacks = {
            "music/hl2_song20_submix0.mp3",
            "music/hl2_song31.mp3",
            "music/hl2_song14.mp3",
        }
        for _, fb in ipairs(fallbacks) do
            if file.Exists("sound/" .. fb, "GAME") then
                musicPath = fb
                break
            end
        end
    end

    sound.PlayFile("sound/" .. musicPath, "noplay", function(station, errCode, errStr)
        if requestGeneration ~= musicGeneration.round then
            StopLateStation(station)
            return
        end
        if IsValid(station) then
            roundSoundStation = station
            station:SetVolume(volume)
            station:EnableLooping(true)
            station:Play()
        else
            print("[RE4M] Round music error: " .. tostring(errStr))
        end
    end)

    RE4M_CLIENT.MusicPlaying = true
end

function RE4M_StopRoundMusic()
    BeginMusicRequest("round")
    if IsValid(roundSoundStation) then
        roundSoundStation:Stop()
        roundSoundStation = nil
    end
    RE4M_CLIENT.MusicPlaying = false
end

-- ============================================
-- RESULTS MUSIC
-- ============================================

function RE4M_PlayResultsMusic()
    RE4M_StopResultsMusic()
    local requestGeneration = musicGeneration.results

    local cfg = RE4MERCS_GetConfig()
    local musicPath = cfg.ResultsMusic or "ui/results.ogg"
    local volume = cfg.ResultsMusicVolume or 0.5

    if not file.Exists("sound/" .. musicPath, "GAME") then
        musicPath = "music/hl2_song3.mp3"
    end

    sound.PlayFile("sound/" .. musicPath, "noplay", function(station, errCode, errStr)
        if requestGeneration ~= musicGeneration.results then
            StopLateStation(station)
            return
        end
        if IsValid(station) then
            resultsSoundStation = station
            station:SetVolume(volume)
            station:EnableLooping(true)
            station:Play()
        else
            print("[RE4M] Results music error: " .. tostring(errStr))
        end
    end)
end

function RE4M_StopResultsMusic()
    BeginMusicRequest("results")
    if IsValid(resultsSoundStation) then
        resultsSoundStation:Stop()
        resultsSoundStation = nil
    end
end

-- ============================================
-- CLEANUP ON DISCONNECT / SHUTDOWN
-- ============================================

hook.Add("ShutDown", "RE4M_MusicCleanup", function()
    RE4M_StopMenuMusic()
    RE4M_StopRoundMusic()
    RE4M_StopResultsMusic()
end)

-- Optional: Also stop music when the client disconnects from the server
hook.Add("OnClientDisconnect", "RE4M_MusicCleanupDisconnect", function()
    RE4M_StopMenuMusic()
    RE4M_StopRoundMusic()
    RE4M_StopResultsMusic()
end)
