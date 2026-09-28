-- RE4 Mercenaries Remake - Results Screen (Client)

local ResultsFrame = nil
local resultsData = {}
local resultsAnimState = 0
local resultsAnimStart = 0

function RE4M_ShowResults(data)
    resultsData = data or {}
    RE4M_CLIENT.ResultsOpen = true

    -- Play results music
    RE4M_PlayResultsMusic()

    -- Start animation
    resultsAnimState = 0
    resultsAnimStart = CurTime()

    -- Close any existing
    if IsValid(ResultsFrame) then
        ResultsFrame:Remove()
    end

    local sw, sh = ScrW(), ScrH()

    ResultsFrame = vgui.Create("DFrame")
    ResultsFrame:SetSize(sw, sh)
    ResultsFrame:SetPos(0, 0)
    ResultsFrame:SetTitle("")
    ResultsFrame:SetDraggable(false)
    ResultsFrame:ShowCloseButton(false)
    ResultsFrame:MakePopup()

    -- Find local player's results
    local localSteamID = LocalPlayer():SteamID()
    local localResult = nil
    local localPlace = 1

    for i, result in ipairs(resultsData) do
        if result.steamid == localSteamID then
            localResult = result
            localPlace = i
            break
        end
    end

    if not localResult then
        localResult = {
            name = LocalPlayer():Nick(),
            score = LocalPlayer():RE4M_GetScore(),
            kills = LocalPlayer():RE4M_GetKills(),
            maxCombo = LocalPlayer():RE4M_GetMaxCombo(),
            level = LocalPlayer():GetNWInt("RE4M_PlayerLevel", 1),
            xpGained = 0,
            mpGained = 0,
            rank = "C",
        }
    end

    local rankName, rankColor = RE4MERCS_GetRank(localResult.score)
    local lastScoreSoundStep = -1

    ResultsFrame.Paint = function(self, w, h)
        local elapsed = CurTime() - resultsAnimStart

        -- Background fade in
        local bgAlpha = math.Clamp(elapsed * 200, 0, 230)
        surface.SetDrawColor(10, 5, 5, bgAlpha)
        surface.DrawRect(0, 0, w, h)

        -- Vignette
        local vigAlpha = math.Clamp(elapsed * 150, 0, 200)
        for i = 0, 200 do
            local a = Lerp(i / 200, vigAlpha, 0)
            surface.SetDrawColor(0, 0, 0, a)
            surface.DrawRect(0, i, w, 1)
            surface.DrawRect(0, h - i, w, 1)
        end

        if elapsed < 0.5 then return end

        -- ============ TITLE ============
        local titleAlpha = math.Clamp((elapsed - 0.5) * 400, 0, 255)
        draw.SimpleText("MISSION COMPLETE", "RE4M_Title", w/2, 60,
            Color(255, 60, 60, titleAlpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        if elapsed < 1.0 then return end

        -- ============ RANK (big center reveal) ============
        local rankAlpha = math.Clamp((elapsed - 1.0) * 300, 0, 255)
        local rankScale = Lerp(math.Clamp((elapsed - 1.0) * 3, 0, 1), 3.0, 1.0)

        -- Rank background circle
        local rankCenterX = w / 2
        local rankCenterY = 200
        local circleRadius = 80

        surface.SetDrawColor(rankColor.r, rankColor.g, rankColor.b, rankAlpha * 0.3)
        draw.NoTexture()
        -- Draw circle approximation
        local segments = 32
        local poly = {}
        for s = 0, segments do
            local angle = (s / segments) * math.pi * 2
            table.insert(poly, {
                x = rankCenterX + math.cos(angle) * circleRadius,
                y = rankCenterY + math.sin(angle) * circleRadius,
            })
        end
        surface.DrawPoly(poly)

        -- Rank border
        surface.SetDrawColor(rankColor.r, rankColor.g, rankColor.b, rankAlpha * 0.8)
        for s = 0, segments - 1 do
            local a1 = (s / segments) * math.pi * 2
            local a2 = ((s + 1) / segments) * math.pi * 2
            surface.DrawLine(
                rankCenterX + math.cos(a1) * circleRadius,
                rankCenterY + math.sin(a1) * circleRadius,
                rankCenterX + math.cos(a2) * circleRadius,
                rankCenterY + math.sin(a2) * circleRadius
            )
        end

        -- Rank letter
        draw.SimpleText(rankName, "RE4M_Rank", rankCenterX, rankCenterY,
            Color(rankColor.r, rankColor.g, rankColor.b, rankAlpha),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Rank reveal sound (play once)
        if resultsAnimState < 1 and elapsed >= 1.0 then
            resultsAnimState = 1
            RE4M_PlayUISound("ui/ui_rank_result.wav", "ui/rank_reveal.ogg")
        end

        if elapsed < 2.0 then return end

        -- ============ STATS ============
        local statsAlpha = math.Clamp((elapsed - 2.0) * 400, 0, 255)
        local statsY = 310
        local statsSpacing = 45

        -- Score
        draw.SimpleText("FINAL SCORE", "RE4M_Medium", w/2, statsY,
            Color(200, 200, 200, statsAlpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Animated score counter
        local scoreProgress = math.Clamp((elapsed - 2.0) / 2.0, 0, 1)
        local displayScore = math.floor(Lerp(scoreProgress, 0, localResult.score))
        local scoreSoundSteps = math.min(math.max(math.floor(localResult.score), 1), 50)
        local scoreSoundStep = math.floor(scoreProgress * scoreSoundSteps)
        if localResult.score > 0 and scoreSoundStep > lastScoreSoundStep then
            lastScoreSoundStep = scoreSoundStep
            RE4M_PlayUISound("ui/ui_scorecount.wav")
        end

        draw.SimpleText(RE4MERCS_FormatScore(displayScore), "RE4M_Title", w/2, statsY + 50,
            Color(255, 255, 255, statsAlpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Stats grid
        local gridY = statsY + 120
        local col1X = w/2 - 200
        local col2X = w/2 + 50

        -- Kills
        draw.SimpleText("KILLS", "RE4M_Small", col1X, gridY,
            Color(200, 200, 200, statsAlpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(tostring(localResult.kills), "RE4M_Large", col1X + 130, gridY,
            Color(255, 255, 255, statsAlpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        -- Max Combo
        draw.SimpleText("MAX COMBO", "RE4M_Small", col2X, gridY,
            Color(200, 200, 200, statsAlpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(tostring(localResult.maxCombo), "RE4M_Large", col2X + 170, gridY,
            Color(255, 215, 0, statsAlpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        draw.SimpleText("PLAYER LEVEL  " .. tostring(localResult.level or 1) ..
            "     PLAYER XP  +" .. tostring(localResult.xpGained or 0),
            "RE4M_Small", w / 2, gridY + 48,
            Color(210, 175, 255, statsAlpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        draw.SimpleText("MERC POINTS  +" .. tostring(localResult.mpGained or 0),
            "RE4M_Small", w / 2, gridY + 72,
            Color(255, 220, 100, statsAlpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

        if elapsed < 3.0 then return end

        -- ============ LEADERBOARD (Multiplayer) ============
        if #resultsData > 1 then
            local lbAlpha = math.Clamp((elapsed - 3.0) * 400, 0, 255)
            local lbY = gridY + 105

            draw.SimpleText("LEADERBOARD", "RE4M_Medium", w/2, lbY,
                Color(255, 60, 60, lbAlpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            -- Separator
            surface.SetDrawColor(255, 60, 60, lbAlpha * 0.5)
            surface.DrawRect(w/2 - 250, lbY + 20, 500, 1)

            for i, result in ipairs(resultsData) do
                if i > 8 then break end -- Max 8 entries

                local entryY = lbY + 30 + (i - 1) * 35
                local isLocal = result.steamid == localSteamID
                local entryColor = isLocal and Color(255, 215, 0, lbAlpha) or Color(255, 255, 255, lbAlpha)

                -- Place
                draw.SimpleText("#" .. i, "RE4M_Medium", w/2 - 240, entryY,
                    entryColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                -- Name
                draw.SimpleText(result.name, "RE4M_Medium", w/2 - 180, entryY,
                    entryColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                draw.SimpleText("Lv." .. tostring(result.level or 1), "RE4M_Small",
                    w/2 - 5, entryY + 3, entryColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                -- Score
                draw.SimpleText(RE4MERCS_FormatScore(result.score), "RE4M_Medium", w/2 + 100, entryY,
                    entryColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                -- Rank
                local rName, rColor = RE4MERCS_GetRank(result.score)
                draw.SimpleText(rName, "RE4M_Medium", w/2 + 230, entryY,
                    Color(rColor.r, rColor.g, rColor.b, lbAlpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                -- Highlight local player row
                if isLocal then
                    surface.SetDrawColor(255, 215, 0, lbAlpha * 0.1)
                    surface.DrawRect(w/2 - 250, entryY - 2, 500, 30)
                end
            end
        end

        -- ============ FOOTER ============
        if elapsed > 4.0 then
            local footAlpha = math.Clamp((elapsed - 4.0) * 300, 0, 255)
            local pulse = (math.sin(CurTime() * 3) + 1) / 2

            draw.SimpleText("Returning to menu...", "RE4M_Small", w/2, h - 40,
                Color(200, 200, 200, footAlpha * (0.5 + pulse * 0.5)),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
end

function RE4M_CloseResults()
    if IsValid(ResultsFrame) then
        ResultsFrame:Remove()
        ResultsFrame = nil
    end

    RE4M_CLIENT.ResultsOpen = false
    RE4M_StopResultsMusic()

    resultsAnimState = 0
    resultsData = {}
end
