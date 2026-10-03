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

    if state == GAMESTATE_ACTIVE then
        RE4M_DrawProgressionHUD()
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

local lastPreRoundCount

function RE4M_DrawPreRoundHUD()
    local endTime   = GetGlobalFloat("RE4M_PreRoundEnd", 0)
    local remaining = math.max(0, endTime - CurTime())
    local countDown = math.ceil(remaining)

    if countDown > 0 and countDown ~= lastPreRoundCount then
        lastPreRoundCount = countDown
        RE4M_PlayUISound("ui/countdown.ogg")
    elseif countDown <= 0 then
        lastPreRoundCount = nil
    end

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
        re5  = "RESIDENT EVIL 5 ENEMIES",
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

    -- The fade-in math above overshoots 255 once the 0.6s fade completes.
    alpha = math.Clamp(alpha, 0, 255)
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
        -- Mirror the server's Go For Broke! bonus so the bar matches reality.
        if timeLeft <= 30 then
            for slot = 1, 3 do
                if ply:GetNWString("RE4M_EquippedSkill" .. slot, "") == "go_for_broke" then
                    timeout = timeout + 2
                    break
                end
            end
        end
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

    -- ============ RESPAWN PROMPT ============
    local respawnCfg = RE4MERCS_GetConfig and RE4MERCS_GetConfig()
    if not ply:Alive() and respawnCfg and respawnCfg.RespawnEnabled then
        local wait = math.ceil(ply:GetNW2Float("RE4M_RespawnAt", 0) - CurTime())
        local text = wait > 0 and ("RESPAWN IN " .. wait)
            or ("PRESS [ " .. string.upper(input.LookupBinding("+attack") or "MOUSE1") .. " ] TO RESPAWN")
        draw.SimpleText(text, "RE4M_Popup", sw / 2, sh * 0.6,
            Color(255, 220, 80, 200 + math.sin(CurTime() * 6) * 55),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
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

-- Read the authoritative replicated player fields directly so the HUD does
-- not depend on whether the lobby profile snapshot has finished syncing.
function RE4M_DrawProgressionHUD()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local playerLevel = ply:GetNWInt("RE4M_PlayerLevel", 1)
    local weaponLevel = ply:GetNWInt("RE4M_ActiveWeaponLevel", 1)
    local mercPoints = ply:GetNWInt("RE4M_MercPoints", 0)
    DrawPanelBox(10, 65, 300, 86, Color(0, 0, 0, 200), Color(150, 70, 190, 200))
    draw.SimpleText("PLAYER Lv." .. playerLevel .. "   WEAPON Lv." .. weaponLevel .. "   MP " .. mercPoints,
        "RE4M_Tiny", 20, 73, Color(245, 225, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    local visible = 0
    for slot = 1, 3 do
        local skillID = ply:GetNWString("RE4M_EquippedSkill" .. slot, "")
        if skillID == "" then continue end
        visible = visible + 1
        local skill = RE4M_SKILLS_BY_ID and RE4M_SKILLS_BY_ID[skillID]
        draw.SimpleText(visible .. ". " .. (skill and skill.name or skillID), "RE4M_Tiny",
            20, 95 + (visible - 1) * 15, Color(215, 175, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end
    if visible == 0 then
        draw.SimpleText("SKILLS: none equipped", "RE4M_Tiny", 20, 99,
            Color(190, 180, 195), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end
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

        draw.SimpleText("+" .. string.format("%g", math.Round(notif.seconds or 0, 1)) .. "s", "RE4M_Medium",
            sw / 2, y,
            Color(50, 255, 50, alpha),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

-- ============================================
-- FLOATING HEALTH BARS ABOVE ENEMIES
-- ============================================

local healthBarEntities = {}
local healthBarEnabledCVar = GetConVar("re4m_showenemyhealthbars")
local healthBarDistanceCVar = GetConVar("re4m_healthbarmaxdistance")

local function TrackHealthBarEntity(ent)
    if not IsValid(ent) then return end
    if not (ent:IsNPC() or ent:IsNextBot()) then return end

    local attempts = 0
    local function tryTrack()
        if not IsValid(ent) then return end
        if ent:GetNWBool("RE4M_Spawned", false) then
            healthBarEntities[ent] = true
            return
        end

        -- Give the initial networked marker a short window to arrive. This
        -- runs only for NPCs/NextBots, never for ordinary map entities.
        attempts = attempts + 1
        if attempts < 6 then timer.Simple(0.2, tryTrack) end
    end
    timer.Simple(0.2, tryTrack)
end

-- NetworkEntityCreated fires only for entities replicated to this client.
-- Cache spawned NPCs as they enter PVS instead of walking every entity every
-- HUD frame; a one-time seed covers entities already present at load.
hook.Add("NetworkEntityCreated", "RE4M_TrackHealthBarEntities", TrackHealthBarEntity)
hook.Add("EntityRemoved", "RE4M_UntrackHealthBarEntities", function(ent)
    healthBarEntities[ent] = nil
end)
timer.Simple(0, function()
    for _, ent in ipairs(ents.GetAll()) do
        TrackHealthBarEntity(ent)
    end
end)

hook.Add("HUDPaint", "RE4M_EnemyHealthBars", function()
    if RE4M_CLIENT.GameState ~= GAMESTATE_ACTIVE then return end
    healthBarEnabledCVar = healthBarEnabledCVar or GetConVar("re4m_showenemyhealthbars")
    if healthBarEnabledCVar and not healthBarEnabledCVar:GetBool() then return end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local eyePos     = ply:EyePos()
    healthBarDistanceCVar = healthBarDistanceCVar or GetConVar("re4m_healthbarmaxdistance")
    local maxDrawDist = healthBarDistanceCVar and math.max(healthBarDistanceCVar:GetFloat(), 1) or 2000
    local maxDrawDistSqr = maxDrawDist * maxDrawDist

    for ent in pairs(healthBarEntities) do
        if not IsValid(ent) then
            healthBarEntities[ent] = nil
            continue
        end
        if not (ent:IsNPC() or ent:IsNextBot()) then continue end
        if not ent:GetNWBool("RE4M_Spawned", false) then
            healthBarEntities[ent] = nil
            continue
        end
        local healthFrac = ent:GetNWFloat("RE4M_HealthFrac", -1)
        if healthFrac < 0 or healthFrac <= 0 then continue end

        local entPos = ent:GetPos()
        local distSqr = eyePos:DistToSqr(entPos)
        if distSqr > maxDrawDistSqr then continue end
        local dist = math.sqrt(distSqr)

        -- Position bar above the model bounding box
        local obbMaxZ = ent:OBBMaxs().z
        local headPos = entPos + Vector(0, 0, obbMaxZ + 15)

        local screenPos = headPos:ToScreen()
        if not screenPos.visible then continue end

        local sx = screenPos.x
        local sy = screenPos.y

        -- Scale with distance
        local scaleFactor = math.Clamp(1 - (dist / maxDrawDist), 0.3, 1.0)
        local barWidth    = 220 * scaleFactor
        local barHeight   = 9   * scaleFactor

        -- Fade with distance
        local distAlpha = math.Clamp(255 * (1 - (dist / maxDrawDist) * 0.5), 80, 255)

        local isElite = ent:GetNWBool("RE4M_IsElite", false)

        local barLeft = sx - barWidth / 2
        local barTop = sy
        local border = math.max(1, math.floor(scaleFactor * 1.5))
        local fillWidth = math.max(0, (barWidth - border * 2) * healthFrac)

        -- Thin neon-violet bar with a hot-pink outline, like the reference.
        surface.SetDrawColor(255, 75, 245, distAlpha)
        surface.DrawRect(barLeft, barTop, barWidth, barHeight)
        surface.SetDrawColor(34, 10, 45, distAlpha)
        surface.DrawRect(barLeft + border, barTop + border,
            math.max(0, barWidth - border * 2), math.max(0, barHeight - border * 2))
        surface.SetDrawColor(193, 42, 255, distAlpha)
        surface.DrawRect(barLeft + border, barTop + border, fillWidth,
            math.max(0, barHeight - border * 2))
        if fillWidth > 0 then
            surface.SetDrawColor(255, 166, 255, distAlpha * 0.85)
            surface.DrawRect(barLeft + border, barTop + border,
                fillWidth, math.max(1, math.floor(border * 0.65)))
        end

        local enemyLevel = ent:GetNWInt("RE4M_EnemyLevel", isElite and 2 or 1)
        local enemyMaxHealth = math.max(ent:GetNWInt("RE4M_EnemyMaxHealth", ent:GetMaxHealth()), 1)
        -- ent:Health() is not networked for most NPCs and read 0 here.
        local enemyHealth = ent:GetNWInt("RE4M_EnemyHealth", -1)
        if enemyHealth < 0 then enemyHealth = math.floor(enemyMaxHealth * healthFrac) end
        draw.SimpleText("Lv. " .. enemyLevel .. "  •  HP " .. enemyHealth .. " / " .. enemyMaxHealth, "RE4M_EnemyLevel",
            barLeft, barTop + barHeight + 1,
            Color(255, 198, 95, distAlpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
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

-- ============================================
-- SCREEN VIGNETTES (herb used / perfect dodge)
-- ============================================

local VIGNETTES = {
    -- Green edge glow when a herb heals you.
    herb  = { material = Material("vgui/re4mercs/herb_used_vignette.png", "smooth"),  fadeIn = 0.08, hold = 0.35, fadeOut = 0.9, alpha = 255 },
    -- White flash when a roll's invulnerability makes an attack miss.
    dodge = { material = Material("vgui/re4mercs/perfect_dodge_vingette.png", "smooth"), fadeIn = 0.04, hold = 0.15, fadeOut = 0.6, alpha = 255 },
}
local activeVignettes = {}

--- Show a full-screen vignette ("herb" or "dodge"); re-triggering restarts it.
function RE4M_FlashVignette(kind)
    local data = VIGNETTES[kind]
    if not data or data.material:IsError() then return end
    activeVignettes[kind] = CurTime()
end

net.Receive("RE4M_PerfectDodge", function()
    RE4M_FlashVignette("dodge")
end)

-- HUDPaintBackground draws beneath the regular HUD, so the vignettes tint the
-- screen edges without covering the timer, score or health panels.
hook.Add("HUDPaintBackground", "RE4M_ScreenVignettes", function()
    if next(activeVignettes) == nil then return end
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then
        activeVignettes = {}
        return
    end

    local sw, sh = ScrW(), ScrH()
    local now = CurTime()
    for kind, startTime in pairs(activeVignettes) do
        local data = VIGNETTES[kind]
        local t = now - startTime
        local total = data.fadeIn + data.hold + data.fadeOut
        if t >= total then
            activeVignettes[kind] = nil
        else
            local frac
            if t < data.fadeIn then
                frac = t / data.fadeIn
            elseif t < data.fadeIn + data.hold then
                frac = 1
            else
                frac = 1 - (t - data.fadeIn - data.hold) / data.fadeOut
            end
            surface.SetDrawColor(255, 255, 255, data.alpha * math.Clamp(frac, 0, 1))
            surface.SetMaterial(data.material)
            surface.DrawTexturedRect(0, 0, sw, sh)
        end
    end
end)

-- ============================================
-- GET-HIT SCREEN EFFECT
-- ============================================
-- Recreates the otherworldHUD_v2 damage feedback with this mode's gethit
-- images: a random blood overlay held ~1.5s then stretched and faded over
-- 0.6s, a light screen blur, the half of the screen facing the attacker
-- darkened, a small shake/view punch and a brief movement slow. The server
-- sends RE4M_PlayerHit with the attacker's position (sv_scoring.lua), so
-- the side darkening knows where the hit came from.

-- Material() returns two values (material, load time); wrapping each call in
-- parentheses keeps only the material. Unwrapped, the last entry expanded
-- into a stray number and every hit threw "attempt to index local 'mat'".
local GETHIT_MATS = {
    (Material("vgui/re4mercs/gethit_1.png", "smooth mips")),
    (Material("vgui/re4mercs/gethit_2.png", "smooth mips")),
    (Material("vgui/re4mercs/gethit_3.png", "smooth mips")),
}
local GETHIT_HOLD, GETHIT_FADE = 1.5, 0.6   -- overlay: full strength, then stretch-fade
local GETHIT_SIDE_TIME = 0.8                -- attacker-side darkening
local GETHIT_SLOW_TIME = 0.35               -- movement slow after a hit
local gethitMat, gethitStart, gethitUntil = nil, 0, 0
local gethitSide, gethitSideUntil = 0, 0
local gethitSlowUntil, gethitLastTrigger = 0, 0
local gethitBlur = Material("pp/blurscreen")

local function RE4M_StartHitFeedback(sourcePosition)
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end
    local now = CurTime()

    -- Shotgun pellets / multi-hits arrive together: restart the overlay at
    -- most every 0.08s, but always update which side the hit came from.
    if now - gethitLastTrigger >= 0.08 then
        gethitLastTrigger = now
        local choices = {}
        for _, mat in ipairs(GETHIT_MATS) do
            if not mat:IsError() then choices[#choices + 1] = mat end
        end
        gethitMat = #choices > 0 and choices[math.random(#choices)] or nil
        gethitStart, gethitUntil = now, now + GETHIT_HOLD + GETHIT_FADE
        gethitSlowUntil = now + GETHIT_SLOW_TIME
        util.ScreenShake(ply:GetPos(), 2, 5, 0.25, 350)
        ply:ViewPunch(Angle(-0.35, math.Rand(-0.3, 0.3), 0))
    end

    if isvector(sourcePosition) then
        local incoming = sourcePosition - ply:EyePos()
        incoming.z = 0
        if incoming:LengthSqr() > 0.001 then
            incoming:Normalize()
            local right = ply:EyeAngles():Right()
            right.z = 0
            right:Normalize()
            local side = incoming:Dot(right)
            if math.abs(side) > 0.05 then
                -- Darken the half of the screen opposite the attacker.
                gethitSide = side > 0 and -1 or 1
                gethitSideUntil = now + GETHIT_SIDE_TIME
            end
        end
    end
end

net.Receive("RE4M_PlayerHit", function()
    local hasSource = net.ReadBool()
    RE4M_StartHitFeedback(hasSource and net.ReadVector() or nil)
end)

-- Brief movement slow, easing back from 62% to full speed.
hook.Add("CreateMove", "RE4M_HitSlow", function(cmd)
    local remaining = gethitSlowUntil - CurTime()
    if remaining <= 0 then return end
    local scale = Lerp(math.Clamp(remaining / GETHIT_SLOW_TIME, 0, 1), 1, 0.62)
    cmd:SetForwardMove(cmd:GetForwardMove() * scale)
    cmd:SetSideMove(cmd:GetSideMove() * scale)
end)

hook.Add("RenderScreenspaceEffects", "RE4M_HitBlur", function()
    local now = CurTime()
    if gethitUntil <= now then return end
    local elapsed = now - gethitStart
    local strength = elapsed < GETHIT_HOLD and 0.12
        or 0.12 * (1 - math.Clamp((elapsed - GETHIT_HOLD) / GETHIT_FADE, 0, 1))
    if strength <= 0 then return end
    gethitBlur:SetFloat("$blur", strength * 4)
    gethitBlur:Recompute()
    render.UpdateScreenEffectTexture()
    render.SetMaterial(gethitBlur)
    render.DrawScreenQuad()
end)

hook.Add("HUDPaintBackground", "RE4M_HitOverlay", function()
    local ply = LocalPlayer()
    local now = CurTime()
    if not IsValid(ply) or not ply:Alive() then
        gethitUntil, gethitSideUntil, gethitSlowUntil = 0, 0, 0
        return
    end
    local w, h = ScrW(), ScrH()

    if gethitMat and gethitUntil > now then
        local elapsed = now - gethitStart
        local stretch = math.Clamp((elapsed - GETHIT_HOLD) / GETHIT_FADE, 0, 1)
        local alpha = elapsed <= GETHIT_HOLD and 150 or 150 * (1 - stretch)
        -- Blood "runs": the overlay stretches downward and slightly wider as it fades.
        surface.SetDrawColor(255, 255, 255, alpha)
        surface.SetMaterial(gethitMat)
        surface.DrawTexturedRect(-w * stretch * 0.015, 0, w * (1 + stretch * 0.03), h * (1 + stretch * 0.45))
    end

    if gethitSide ~= 0 and gethitSideUntil > now then
        local fade = math.Clamp((gethitSideUntil - now) / GETHIT_SIDE_TIME, 0, 1)
        surface.SetDrawColor(0, 0, 0, 115 * fade)
        surface.DrawRect(gethitSide < 0 and 0 or w / 2, 0, w / 2, h)
    end
end)
