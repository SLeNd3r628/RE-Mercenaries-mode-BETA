-- RE4 Mercenaries Remake - HUD (Client)

local hudColors = {}

local function GetHUDColors()
    local cfg = RE4MERCS_GetConfig and RE4MERCS_GetConfig()
    if cfg and cfg.HUDColors then
        hudColors = cfg.HUDColors
    else
        hudColors = {
            background  = Color(0, 0, 0, 180),
            primary     = Color(255, 60, 60),
            secondary   = Color(255, 200, 50),
            text        = Color(255, 255, 255),
            comboNormal = Color(255, 255, 255),
            comboHigh   = Color(255, 215, 0),
            comboMax    = Color(255, 50, 50),
            timerNormal = Color(255, 255, 255),
            timerLow    = Color(255, 50, 50),
            health      = Color(50, 255, 50),
            healthLow   = Color(255, 50, 50),
        }
    end
end

hook.Add("InitPostEntity", "RE4M_GetHUDColors", GetHUDColors)
GetHUDColors()

-- ============================================
-- SAFETY: Ensure RE4M_CLIENT exists with defaults
-- ============================================

RE4M_CLIENT = RE4M_CLIENT or {}
RE4M_CLIENT.GameState       = RE4M_CLIENT.GameState       or 0
RE4M_CLIENT.RoundTimeLeft   = RE4M_CLIENT.RoundTimeLeft   or 0
RE4M_CLIENT.Score           = RE4M_CLIENT.Score           or 0
RE4M_CLIENT.Combo           = RE4M_CLIENT.Combo           or 0
RE4M_CLIENT.Multiplier      = RE4M_CLIENT.Multiplier      or 1.0
RE4M_CLIENT.Kills           = RE4M_CLIENT.Kills           or 0
RE4M_CLIENT.KillFeed        = RE4M_CLIENT.KillFeed        or {}
RE4M_CLIENT.Popups          = RE4M_CLIENT.Popups          or {}
RE4M_CLIENT.PickupNotifs    = RE4M_CLIENT.PickupNotifs    or {}
RE4M_CLIENT.TimeExtendNotifs= RE4M_CLIENT.TimeExtendNotifs or {}
RE4M_CLIENT.DamageNumbers   = RE4M_CLIENT.DamageNumbers   or {}
RE4M_CLIENT.KillScoreFloats = RE4M_CLIENT.KillScoreFloats or {}
RE4M_CLIENT.EliteAlerts     = RE4M_CLIENT.EliteAlerts     or {}
RE4M_CLIENT.HasNavmesh      = RE4M_CLIENT.HasNavmesh      ~= false -- default true
RE4M_CLIENT.CurrentTheme    = RE4M_CLIENT.CurrentTheme    or "default"

-- ============================================
-- DRAWING UTILITIES
-- ============================================

local function DrawPanelBox(x, y, w, h, bgColor, borderColor)
    draw.RoundedBox(6, x, y, w, h, bgColor)
    if borderColor then
        surface.SetDrawColor(borderColor)
        surface.DrawOutlinedRect(x, y, w, h, 2)
    end
end

local function DrawProgressBar(x, y, w, h, fraction, bgColor, fillColor)
    draw.RoundedBox(4, x, y, w, h, bgColor)
    if fraction > 0 then
        draw.RoundedBox(4, x + 2, y + 2,
            math.max(0, (w - 4) * math.Clamp(fraction, 0, 1)),
            h - 4, fillColor)
    end
end

local function PulseValue(speed, min, max)
    return Lerp((math.sin(CurTime() * speed) + 1) / 2, min, max)
end

-- ============================================
-- MAIN HUD PAINT
-- ============================================

hook.Add("HUDPaint", "RE4M_HUD", function()
    local state = RE4M_CLIENT.GameState

    if state == GAMESTATE_ACTIVE then
        RE4M_DrawActiveHUD()
    elseif state == GAMESTATE_PREROUND then
        RE4M_DrawPreRoundHUD()
    end

    -- Always draw these overlays
    RE4M_DrawKillFeed()
    RE4M_DrawPopups()
    RE4M_DrawPickupNotifs()
    RE4M_DrawTimeExtendNotifs()
    RE4M_DrawFloatingDamageNumbers()
    RE4M_DrawFloatingKillScores()
    RE4M_DrawEliteAlerts()
end)

-- ============================================
-- PRE-ROUND COUNTDOWN
-- ============================================

function RE4M_DrawPreRoundHUD()
    local endTime   = GetGlobalFloat("RE4M_PreRoundEnd", 0)
    local remaining = math.max(0, endTime - CurTime())
    local countDown = math.ceil(remaining)

    local sw, sh = ScrW(), ScrH()

    surface.SetDrawColor(0, 0, 0, 150)
    surface.DrawRect(0, 0, sw, sh)

    draw.SimpleText("GET READY", "RE4M_Title",
        sw / 2, sh / 2 - 80,
        Color(255, 60, 60, 255),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    if countDown > 0 then
        local alpha = 200 + math.sin(CurTime() * 8) * 55
        draw.SimpleText(tostring(countDown), "RE4M_Rank",
            sw / 2, sh / 2 + 40,
            Color(255, 255, 255, alpha),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local themeNames = {
        default  = "RESIDENT EVIL 4 ENEMIES",
        halflife = "HALF-LIFE 2 ENEMIES",
        custom   = "CUSTOM ENEMIES",
    }
    local themeName = themeNames[RE4M_CLIENT.CurrentTheme] or RE4M_CLIENT.CurrentTheme

    draw.SimpleText("Theme: " .. themeName, "RE4M_Medium",
        sw / 2, sh / 2 + 160,
        Color(200, 200, 200, 200),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- BSSA Echo Team briefing (on top of everything)
    RE4M_DrawEchoTeamMessage()
end

-- ============================================
-- ECHO TEAM PRE-ROUND BRIEFING
-- ============================================

-- ============================================
-- ECHO TEAM PRE-ROUND BRIEFING (3 messages)
-- ============================================

function RE4M_DrawEchoTeamMessage()
    local echo = RE4M_CLIENT.EchoTeam
    if not echo or echo.startTime == 0 then return end

    local elapsed = CurTime() - echo.startTime
    local phase   = echo.duration or 2.0
    local totalDuration = phase * 3 + 1.0

    -- Cleanup after everything finishes
    if elapsed > totalDuration then
        RE4M_CLIENT.EchoTeam.startTime = 0
        return
    end

    local text = ""
    local alpha = 255

    if elapsed < phase then
        -- Message 1
        text = echo.msg1
        alpha = 255

    elseif elapsed < phase * 2 then
        -- Crossfade Message 1 → Message 2
        local prog = (elapsed - phase) / 0.6
        text = echo.msg2
        alpha = 255 * prog

    elseif elapsed < phase * 3 then
        -- Crossfade Message 2 → Message 3
        local prog = (elapsed - phase * 2) / 0.6
        text = echo.msg3
        alpha = 255 * prog

    else
        -- Final fade-out of Message 3
        local prog = (elapsed - phase * 3) / 0.8
        text = echo.msg3
        alpha = 255 * math.max(0, 1 - prog)
    end

    if text == "" or alpha <= 10 then return end

    local sw, sh = ScrW(), ScrH()
    local baseY = sh * 0.73   -- middle-center bottom

    local lines = string.Explode("\n", text)

    for i, line in ipairs(lines) do
        local y = baseY + (i - 1) * 32

        -- Shadow
        draw.SimpleText(line, "RE4M_Medium", sw/2 + 2, y + 2,
            Color(0, 0, 0, alpha * 0.7), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Main gold text
        draw.SimpleText(line, "RE4M_Medium", sw/2, y,
            Color(255, 215, 100, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

-- ============================================
-- ACTIVE ROUND HUD
-- ============================================

function RE4M_DrawActiveHUD()
    local sw, sh = ScrW(), ScrH()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    -- ============ TIMER (Top Center) ============
    local timeLeft  = RE4M_CLIENT.RoundTimeLeft
    local timeStr   = RE4MERCS_FormatTime and RE4MERCS_FormatTime(timeLeft) or tostring(timeLeft)
    local timerColor = hudColors.timerNormal or Color(255, 255, 255)

    if timeLeft <= 15 then
        local flash = PulseValue(6, 0.3, 1.0)
        timerColor = Color(255, 50 * flash, 50 * flash)
    elseif timeLeft <= 30 then
        timerColor = Color(255, 200, 50)
    end

    DrawPanelBox(sw / 2 - 100, 10, 200, 60, Color(0, 0, 0, 200), hudColors.primary)
    draw.SimpleText("TIME", "RE4M_Tiny",
        sw / 2, 12,
        Color(200, 200, 200, 180),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    draw.SimpleText(timeStr, "RE4M_HUDTimer",
        sw / 2, 40,
        timerColor,
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- ============ SCORE (Top Right) ============
    local score    = RE4M_CLIENT.Score
    local scoreStr = RE4MERCS_FormatScore and RE4MERCS_FormatScore(score) or tostring(score)
    local rankName, rankColor = "---", Color(255, 255, 255)

    if RE4MERCS_GetRank then
        rankName, rankColor = RE4MERCS_GetRank(score)
    end

    DrawPanelBox(sw - 320, 10, 310, 70, Color(0, 0, 0, 200), hudColors.primary)
    draw.SimpleText("SCORE", "RE4M_Tiny",
        sw - 310, 14,
        Color(200, 200, 200, 180),
        TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText(scoreStr, "RE4M_HUDScore",
        sw - 15, 50,
        hudColors.text,
        TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    draw.SimpleText(rankName, "RE4M_Subtitle",
        sw - 310, 50,
        rankColor,
        TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    -- ============ COMBO (Right Side) ============
    local combo      = RE4M_CLIENT.Combo
    local multiplier = RE4M_CLIENT.Multiplier

    if combo > 0 then
        local comboColor = hudColors.comboNormal or Color(255, 255, 255)

        if combo >= 100 then
            local pulse = PulseValue(4, 0.8, 1.0)
            comboColor = Color(255 * pulse, 50 * pulse, 50 * pulse)
        elseif combo >= 50 then
            comboColor = hudColors.comboMax or Color(255, 50, 50)
        elseif combo >= 25 then
            comboColor = Color(255, 150, 50)
        elseif combo >= 10 then
            comboColor = hudColors.comboHigh or Color(255, 215, 0)
        end

        local comboX = sw - 170
        local comboY = sh / 2 - 60

        DrawPanelBox(comboX - 10, comboY - 10, 170, 120, Color(0, 0, 0, 160), comboColor)

        draw.SimpleText("COMBO", "RE4M_Small",
            comboX + 75, comboY,
            Color(200, 200, 200, 200),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        draw.SimpleText(tostring(combo), "RE4M_HUDCombo",
            comboX + 75, comboY + 50,
            comboColor,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("x" .. string.format("%.1f", multiplier), "RE4M_Medium",
            comboX + 75, comboY + 85,
            hudColors.secondary or Color(255, 200, 50),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

        -- Combo timeout bar
        local cfg     = RE4MERCS_GetConfig and RE4MERCS_GetConfig()
        local timeout = (cfg and cfg.ComboTimeout) or 8
        local comboFraction = 1.0

        if RE4M_CLIENT._lastComboTime then
            local elapsed = CurTime() - RE4M_CLIENT._lastComboTime
            comboFraction = math.Clamp(1 - (elapsed / timeout), 0, 1)
        end

        DrawProgressBar(comboX, comboY + 105, 150, 8,
            comboFraction, Color(40, 40, 40, 200), comboColor)
    end

    -- ============ HEALTH & ARMOR (Bottom Left) ============
    local health    = ply:Health()
    local maxHealth = math.max(ply:GetMaxHealth(), 1)
    local armor     = ply:Armor()
    local healthFrac = health / maxHealth
    local healthColor

    if healthFrac <= 0.3 then
        local pulse = PulseValue(4, 0.5, 1.0)
        healthColor = Color(255, 50 * pulse, 50 * pulse)
    else
        healthColor = hudColors.health or Color(50, 255, 50)
    end

    DrawPanelBox(10, sh - 90, 280, 80, Color(0, 0, 0, 200), hudColors.primary)

    draw.SimpleText("HEALTH", "RE4M_Tiny",
        20, sh - 85,
        Color(200, 200, 200, 180),
        TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    DrawProgressBar(20, sh - 65, 200, 16,
        healthFrac, Color(40, 40, 40, 200), healthColor)
    draw.SimpleText(tostring(health), "RE4M_Medium",
        230, sh - 60,
        healthColor,
        TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    if armor > 0 then
        draw.SimpleText("ARMOR", "RE4M_Tiny",
            20, sh - 43,
            Color(200, 200, 200, 180),
            TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        DrawProgressBar(20, sh - 25, 200, 12,
            armor / 100, Color(40, 40, 40, 200), Color(50, 150, 255))
        draw.SimpleText(tostring(armor), "RE4M_Small",
            230, sh - 22,
            Color(50, 150, 255),
            TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    -- ============ AMMO (Bottom Right) ============
    local wep = ply:GetActiveWeapon()
    if IsValid(wep) then
        local clip    = wep:Clip1()
        local reserve = ply:GetAmmoCount(wep:GetPrimaryAmmoType())

        DrawPanelBox(sw - 250, sh - 70, 240, 60, Color(0, 0, 0, 200), hudColors.primary)

        local wepName = wep:GetPrintName() or wep:GetClass()
        draw.SimpleText(string.upper(wepName), "RE4M_Tiny",
            sw - 240, sh - 66,
            Color(200, 200, 200, 180),
            TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        if clip >= 0 then
            draw.SimpleText(tostring(clip), "RE4M_HUDScore",
                sw - 120, sh - 42,
                hudColors.text,
                TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            draw.SimpleText("/ " .. tostring(reserve), "RE4M_Medium",
                sw - 115, sh - 42,
                Color(180, 180, 180),
                TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        else
            -- clip == -1 means weapon has no clip (melee, etc.)
            draw.SimpleText("∞", "RE4M_HUDScore",
                sw - 130, sh - 42,
                hudColors.secondary or Color(255, 200, 50),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    -- ============ KILLS (Top Left) ============
    DrawPanelBox(10, 10, 160, 45, Color(0, 0, 0, 200), hudColors.primary)
    draw.SimpleText("KILLS", "RE4M_Tiny",
        20, 14,
        Color(200, 200, 200, 180),
        TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText(tostring(RE4M_CLIENT.Kills), "RE4M_Medium",
        90, 40,
        hudColors.text,
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

-- Track combo timing clientside
hook.Add("Think", "RE4M_TrackComboTime", function()
    local currentCombo = RE4M_CLIENT.Combo or 0

    if currentCombo > 0 then
        if not RE4M_CLIENT._lastCombo or currentCombo ~= RE4M_CLIENT._lastCombo then
            RE4M_CLIENT._lastComboTime = CurTime()
        end
    else
        RE4M_CLIENT._lastComboTime = nil
    end

    RE4M_CLIENT._lastCombo = currentCombo
end)

-- ============================================
-- KILL FEED OVERLAY (Right side)
-- ============================================

function RE4M_DrawKillFeed()
    if not RE4M_CLIENT.KillFeed then return end

    local sw, sh = ScrW(), ScrH()
    local feedX   = sw - 300
    local feedY   = sh / 2 + 80

    for i = #RE4M_CLIENT.KillFeed, 1, -1 do
        local entry = RE4M_CLIENT.KillFeed[i]
        if not entry then continue end

        local age = CurTime() - entry.time

        if age > 3 then
            entry.alpha = math.max(0, entry.alpha - FrameTime() * 200)
        end

        if entry.alpha <= 0 then
            table.remove(RE4M_CLIENT.KillFeed, i)
            continue
        end

        local y     = feedY + (i - 1) * 30
        local alpha = entry.alpha

        local scoreStr = RE4MERCS_FormatScore and RE4MERCS_FormatScore(entry.score)
            or tostring(entry.score)
        local scoreColor = entry.hasBonus
            and Color(255, 215, 0, alpha)
            or  Color(255, 255, 255, alpha)

        draw.SimpleText("+" .. scoreStr, "RE4M_KillFeed",
            feedX + 145, y,
            scoreColor,
            TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

        if entry.multiplier and entry.multiplier > 1.0 then
            draw.SimpleText(" x" .. string.format("%.1f", entry.multiplier), "RE4M_Tiny",
                feedX + 150, y + 2,
                Color(255, 200, 50, alpha),
                TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
    end
end

-- ============================================
-- COMBO MILESTONE POPUPS (Center)
-- ============================================

function RE4M_DrawPopups()
    if not RE4M_CLIENT.Popups then return end

    local sw, sh = ScrW(), ScrH()

    for i = #RE4M_CLIENT.Popups, 1, -1 do
        local popup = RE4M_CLIENT.Popups[i]
        if not popup then continue end

        local age = CurTime() - popup.time

        if age > 3 then
            popup.alpha = math.max(0, popup.alpha - FrameTime() * 300)
        end

        if popup.alpha <= 0 then
            table.remove(RE4M_CLIENT.Popups, i)
            continue
        end

        local y     = sh / 2 - 20 - (i - 1) * 60
        local alpha = popup.alpha

        draw.SimpleText(popup.text, "RE4M_Popup",
            sw / 2, y,
            Color(255, 215, 0, alpha),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        if popup.sub then
            draw.SimpleText(popup.sub, "RE4M_Medium",
                sw / 2, y + 35,
                Color(50, 255, 50, alpha * 0.8),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
end

-- ============================================
-- PICKUP NOTIFICATIONS (Center-Left)
-- ============================================

function RE4M_DrawPickupNotifs()
    if not RE4M_CLIENT.PickupNotifs then return end

    local sw, sh = ScrW(), ScrH()

    for i = #RE4M_CLIENT.PickupNotifs, 1, -1 do
        local notif = RE4M_CLIENT.PickupNotifs[i]
        if not notif then continue end

        local age = CurTime() - notif.time

        if age > 2.5 then
            notif.alpha = math.max(0, notif.alpha - FrameTime() * 300)
        end

        if notif.alpha <= 0 then
            table.remove(RE4M_CLIENT.PickupNotifs, i)
            continue
        end

        local y     = sh / 2 + 120 + (i - 1) * 30
        local alpha = notif.alpha

        local typeColors = {
            health = Color(50, 255, 50,   alpha),
            ammo   = Color(255, 200, 50,  alpha),
            time   = Color(50, 150, 255,  alpha),
            rare   = Color(255, 50, 255,  alpha),
        }

        local col = typeColors[notif.type] or Color(255, 255, 255, alpha)

        -- Drop shadow
        draw.SimpleText(notif.text, "RE4M_Medium",
            sw / 2 + 1, y + 1,
            Color(0, 0, 0, alpha * 0.5),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        draw.SimpleText(notif.text, "RE4M_Medium",
            sw / 2, y,
            col,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

-- ============================================
-- TIME EXTEND NOTIFICATIONS (Near Timer)
-- ============================================

function RE4M_DrawTimeExtendNotifs()
    if not RE4M_CLIENT.TimeExtendNotifs then return end

    local sw = ScrW()

    for i = #RE4M_CLIENT.TimeExtendNotifs, 1, -1 do
        local notif = RE4M_CLIENT.TimeExtendNotifs[i]
        if not notif then continue end

        local age = CurTime() - notif.time

        if age > 1.5 then
            notif.alpha = math.max(0, notif.alpha - FrameTime() * 300)
        end

        if notif.alpha <= 0 then
            table.remove(RE4M_CLIENT.TimeExtendNotifs, i)
            continue
        end

        -- Floats upward as it ages
        local y     = 80 + (i - 1) * 25 - age * 20
        local alpha = notif.alpha

        draw.SimpleText("+" .. tostring(notif.seconds) .. "s", "RE4M_Medium",
            sw / 2, y,
            Color(50, 255, 50, alpha),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

-- ============================================
-- FLOATING HEALTH BARS ABOVE ENEMIES
-- ============================================

hook.Add("HUDPaint", "RE4M_EnemyHealthBars", function()
    if RE4M_CLIENT.GameState ~= GAMESTATE_ACTIVE then return end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local eyePos     = ply:EyePos()
    local maxDrawDist = 1500

    for _, ent in ipairs(ents.GetAll()) do
        if not (ent:IsNPC() or ent:IsNextBot()) then continue end
        if not ent.RE4M_Spawned then continue end
        local healthFrac = ent:GetNWFloat("RE4M_HealthFrac", -1)
        if healthFrac < 0 or healthFrac <= 0 then continue end
        if healthFrac <= 0 then continue end -- dead

        local entPos = ent:GetPos()
        local dist   = eyePos:Distance(entPos)
        if dist > maxDrawDist then continue end

        -- Position bar above the model bounding box
        local obbMaxZ = ent:OBBMaxs().z
        local headPos = entPos + Vector(0, 0, obbMaxZ + 15)

        local screenPos = headPos:ToScreen()
        if not screenPos.visible then continue end

        local sx = screenPos.x
        local sy = screenPos.y

        -- Scale with distance
        local scaleFactor = math.Clamp(1 - (dist / maxDrawDist), 0.3, 1.0)
        local barWidth    = 60 * scaleFactor
        local barHeight   = 6  * scaleFactor

        -- Fade with distance
        local distAlpha = math.Clamp(255 * (1 - (dist / maxDrawDist) * 0.5), 80, 255)

        local isElite = ent:GetNWBool("RE4M_IsElite", false)

        -- Background outline
        draw.RoundedBox(2,
            sx - barWidth / 2 - 1, sy - 1,
            barWidth + 2, barHeight + 2,
            Color(0, 0, 0, distAlpha * 0.8))

        -- Health fill color
        local fillColor
        if isElite then
            local pulse = PulseValue(3, 0.7, 1.0)
            fillColor = Color(255 * pulse, 100 * pulse, 0, distAlpha)
        else
            if healthFrac > 0.6 then
                fillColor = Color(50, 220, 50, distAlpha)
            elseif healthFrac > 0.3 then
                fillColor = Color(255, 200, 0, distAlpha)
            else
                fillColor = Color(255, 50, 50, distAlpha)
            end
        end

        local fillWidth = math.max(0, barWidth * healthFrac)
        draw.RoundedBox(2, sx - barWidth / 2, sy, fillWidth, barHeight, fillColor)

        -- Elite label
        if isElite then
            draw.SimpleText("ELITE", "RE4M_HealthBar",
                sx, sy - 12,
                Color(255, 80, 80, distAlpha),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        -- Percentage for nearby enemies
        if dist < 800 then
            local pctText = math.floor(healthFrac * 100) .. "%"
            draw.SimpleText(pctText, "RE4M_HealthBar",
                sx, sy + barHeight + 4,
                Color(255, 255, 255, distAlpha * 0.7),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        end
    end
end)

-- ============================================
-- FLOATING DAMAGE NUMBERS
-- ============================================

function RE4M_DrawFloatingDamageNumbers()
    if RE4M_CLIENT.GameState ~= GAMESTATE_ACTIVE then return end
    if not RE4M_CLIENT.DamageNumbers then return end

    local ft = FrameTime()

    for i = #RE4M_CLIENT.DamageNumbers, 1, -1 do
        local dmg = RE4M_CLIENT.DamageNumbers[i]
        if not dmg then continue end

        local age = CurTime() - dmg.time

        if age > dmg.lifetime then
            dmg.alpha = math.max(0, dmg.alpha - ft * 500)
        end

        if dmg.alpha <= 0 then
            table.remove(RE4M_CLIENT.DamageNumbers, i)
            continue
        end

        -- Move upward; apply slight gravity
        dmg.pos      = dmg.pos + dmg.velocity * ft
        dmg.velocity = dmg.velocity + Vector(0, 0, -30 * ft)

        local screenPos = dmg.pos:ToScreen()
        if not screenPos.visible then continue end

        local alpha = dmg.alpha
        local font  = dmg.isHeadshot and "RE4M_DamageNumberLarge" or "RE4M_DamageNumber"

        local color
        if dmg.isHeadshot then
            color = Color(255, 50, 50, alpha)
        elseif dmg.willKill then
            color = Color(255, 215, 0, alpha)
        else
            color = Color(255, 255, 255, alpha)
        end

        -- Drop shadow
        draw.SimpleText(tostring(dmg.damage), font,
            screenPos.x + 1, screenPos.y + 1,
            Color(0, 0, 0, alpha * 0.5),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Main text
        draw.SimpleText(tostring(dmg.damage), font,
            screenPos.x, screenPos.y,
            color,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        if dmg.isHeadshot then
            draw.SimpleText("HEADSHOT", "RE4M_HealthBar",
                screenPos.x, screenPos.y - 18,
                Color(255, 100, 100, alpha * 0.8),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
end

-- ============================================
-- FLOATING KILL SCORES (at death position)
-- ============================================

function RE4M_DrawFloatingKillScores()
    if RE4M_CLIENT.GameState ~= GAMESTATE_ACTIVE then return end
    if not RE4M_CLIENT.KillScoreFloats then return end

    for i = #RE4M_CLIENT.KillScoreFloats, 1, -1 do
        local ks = RE4M_CLIENT.KillScoreFloats[i]
        if not ks then continue end

        local age = CurTime() - ks.spawnTime

        -- Float upward over time
        local floatPos = ks.pos + Vector(0, 0, age * 30)

        -- Fade after 2.5 seconds
        if age > 2.5 then
            ks.alpha = math.max(0, ks.alpha - FrameTime() * 300)
        end

        if ks.alpha <= 0 or age > 4 then
            table.remove(RE4M_CLIENT.KillScoreFloats, i)
            continue
        end

        local screenPos = floatPos:ToScreen()
        if not screenPos.visible then continue end

        local alpha      = ks.alpha
        local sx, sy     = screenPos.x, screenPos.y
        local scoreColor = ks.isElite
            and Color(255, 100, 50, alpha)
            or  Color(255, 215, 0,  alpha)

        local scoreStr = RE4MERCS_FormatScore and RE4MERCS_FormatScore(ks.score)
            or tostring(ks.score)

        -- Drop shadow
        draw.SimpleText("+" .. scoreStr, "RE4M_KillScore",
            sx + 1, sy + 1,
            Color(0, 0, 0, alpha * 0.6),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Main score
        draw.SimpleText("+" .. scoreStr, "RE4M_KillScore",
            sx, sy,
            scoreColor,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Time bonus
        if ks.timeAdded and ks.timeAdded > 0 then
            draw.SimpleText("+" .. string.format("%.0f", ks.timeAdded) .. "s", "RE4M_Small",
                sx, sy + 25,
                Color(50, 255, 50, alpha * 0.9),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        -- Elite badge
        if ks.isElite then
            draw.SimpleText("★ ELITE KILL ★", "RE4M_HealthBar",
                sx, sy - 20,
                Color(255, 100, 50, alpha),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
end

-- ============================================
-- ELITE SPAWN ALERT (Center Screen)
-- ============================================

function RE4M_DrawEliteAlerts()
    if not RE4M_CLIENT.EliteAlerts then return end

    local sw, sh = ScrW(), ScrH()

    for i = #RE4M_CLIENT.EliteAlerts, 1, -1 do
        local alert = RE4M_CLIENT.EliteAlerts[i]
        if not alert then continue end

        local age = CurTime() - alert.time

        if age > alert.duration then
            alert.alpha = math.max(0, alert.alpha - FrameTime() * 200)
        end

        if alert.alpha <= 0 then
            table.remove(RE4M_CLIENT.EliteAlerts, i)
            continue
        end

        local alpha = alert.alpha

        -- Slide in from top
        local slideProgress = math.Clamp(age / 0.3, 0, 1)
        local yOffset       = Lerp(slideProgress, -60, 0)
        local baseY         = sh * 0.2 + yOffset

        -- Flashing red background bar
        -- Keep alpha consistent: flashAlpha 0–60, scaled by overall alpha
        local flashAlpha = (math.sin(CurTime() * 8) * 0.5 + 0.5) * 60 * (alpha / 255)
        surface.SetDrawColor(180, 30, 30, flashAlpha)
        surface.DrawRect(0, baseY - 35, sw, 80)

        -- Border lines
        surface.SetDrawColor(255, 50, 50, alpha * 0.8)
        surface.DrawRect(0, baseY - 35, sw, 2)
        surface.DrawRect(0, baseY + 43, sw, 2)

        -- Main text
        draw.SimpleText(alert.text, "RE4M_EliteAlert",
            sw / 2, baseY,
            Color(255, 50, 50, alpha),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Sub text
        draw.SimpleText(alert.subtext, "RE4M_EliteAlertSub",
            sw / 2, baseY + 30,
            Color(255, 200, 200, alpha * 0.8),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

-- ============================================
-- NAVMESH WARNING
-- ============================================

hook.Add("HUDPaint", "RE4M_NavmeshWarning", function()
    if RE4M_CLIENT.HasNavmesh then return end

    local sw, sh  = ScrW(), ScrH()
    local pulse   = PulseValue(2, 0.5, 1.0)

    draw.SimpleText("⚠ NO NAVMESH - NPCs CANNOT SPAWN", "RE4M_Medium",
        sw / 2, sh - 30,
        Color(255, 50, 50, 255 * pulse),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    draw.SimpleText("Run 'nav_generate' in console to fix", "RE4M_Small",
        sw / 2, sh - 8,
        Color(200, 200, 200, 200),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)