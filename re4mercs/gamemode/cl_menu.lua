-- RE4 Mercenaries BETA - Main Menu (Client)

local MainMenuFrame = nil
local currentTab = "loadout"
local lobbySection = "players"

local function RequestLobbyProgression()
    if not IsValid(LocalPlayer()) then return end
    net.Start("RE4M_RequestProgression")
    net.SendToServer()
end

local function IsReadyPlayerLockedToLobby()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:RE4M_GetReady() then return false end

    local startAt = GetGlobalFloat("RE4M_LobbyStartAt", 0)
    if startAt <= 0 then return false end

    local readyCount = GetGlobalInt("RE4M_LobbyReadyCount", 0)
    local required = math.max(GetGlobalInt("RE4M_LobbyReadyRequired", 1), 1)
    return readyCount >= required
end

local function FitPreviewCamera(panel, ent, distanceScale)
    if not IsValid(panel) or not IsValid(ent) then return end

    local mins, maxs = ent:OBBMins(), ent:OBBMaxs()
    if not mins or not maxs then mins, maxs = ent:GetRenderBounds() end

    local center = (mins + maxs) * 0.5
    local size = (maxs - mins):Length()
    local radius = math.max(size * 0.5, 8)
    local fov = math.rad(panel:GetFOV())
    local distance = radius / math.max(math.tan(fov * 0.5), 0.1) * (distanceScale or 1.15)

    panel.PreviewLookAt = center
    panel.PreviewBaseDistance = distance
    panel.PreviewDistance = distance
    panel:SetLookAt(center)
    panel:SetCamPos(center + Vector(distance, 0, distance * 0.08))
end

local function EnablePreviewControls(panel)
    panel:SetMouseInputEnabled(true)
    panel.PreviewYaw = 0
    panel.PreviewPitch = 0
    panel.PreviewDragging = false

    panel.OnMousePressed = function(self, code)
        if code ~= MOUSE_LEFT then return end
        self.PreviewDragging = true
        self.PreviewLastX, self.PreviewLastY = gui.MousePos()
        self:MouseCapture(true)
    end

    panel.OnCursorMoved = function(self, x, y)
        if not self.PreviewDragging then return end
        local mouseX, mouseY = gui.MousePos()
        local dx = mouseX - (self.PreviewLastX or mouseX)
        local dy = mouseY - (self.PreviewLastY or mouseY)
        self.PreviewLastX, self.PreviewLastY = mouseX, mouseY
        self.PreviewYaw = (self.PreviewYaw or 0) + dx * 0.5
        self.PreviewPitch = math.Clamp((self.PreviewPitch or 0) - dy * 0.35, -45, 45)
    end

    panel.OnMouseReleased = function(self, code)
        if code ~= MOUSE_LEFT then return end
        self.PreviewDragging = false
        self:MouseCapture(false)
    end

    panel.OnMouseWheeled = function(self, delta)
        if not self.PreviewBaseDistance then return false end
        local factor = delta > 0 and 0.85 or 1.18
        self.PreviewDistance = math.Clamp(self.PreviewDistance * factor,
            self.PreviewBaseDistance * 0.35, self.PreviewBaseDistance * 3.5)
        local center = self.PreviewLookAt or vector_origin
        local distance = self.PreviewDistance
        self:SetCamPos(center + Vector(distance, 0, distance * 0.08))
        return true
    end

    panel.LayoutEntity = function(self, ent)
        if self.bAnimated then self:RunAnimation() end
        ent:SetAngles(Angle(self.PreviewPitch or 0, self.PreviewYaw or 0, 0))
    end
end

-- ============================================
-- MENU MANAGEMENT
-- ============================================

function RE4M_OpenMainMenu()
    if IsValid(MainMenuFrame) then
        MainMenuFrame:Remove()
    end

    RE4M_CLIENT.MenuOpen = true
    RE4M_PlayMenuMusic()

    local sw, sh = ScrW(), ScrH()
    local contentPanel

    MainMenuFrame = vgui.Create("DFrame")
    MainMenuFrame:SetSize(sw, sh)
    MainMenuFrame:SetPos(0, 0)
    MainMenuFrame:SetTitle("")
    MainMenuFrame:SetDraggable(false)
    MainMenuFrame:ShowCloseButton(false)
    MainMenuFrame:MakePopup()
    MainMenuFrame.Think = function()
        if IsReadyPlayerLockedToLobby() and currentTab ~= "lobby" then
            currentTab = "lobby"
            RE4M_RefreshMenuContent(contentPanel)
            RequestLobbyProgression()
        end
    end

        -- Background paint
    local bgMat = Material("vgui/re4mercs/background.png", "smooth")
    local vignetteMat = Material("vgui/re4mercs/vignette.png", "smooth")

    MainMenuFrame.Paint = function(self, w, h)
        -- Dark background fallback
        surface.SetDrawColor(20, 10, 10, 255)
        surface.DrawRect(0, 0, w, h)

        -- Background image
        if not bgMat:IsError() then
            surface.SetDrawColor(255, 255, 255, 255)
            surface.SetMaterial(bgMat)
            surface.DrawTexturedRect(0, 0, w, h)
        else
            -- Fallback: dark red gradient
            for i = 0, h, 2 do
                local frac = i / h
                local r = Lerp(frac, 40, 10)
                local g = Lerp(frac, 5, 0)
                local b = Lerp(frac, 5, 0)
                surface.SetDrawColor(r, g, b, 255)
                surface.DrawRect(0, i, w, 2)
            end
        end

        -- Vignette overlay
        if not vignetteMat:IsError() then
            surface.SetDrawColor(255, 255, 255, 200)
            surface.SetMaterial(vignetteMat)
            surface.DrawTexturedRect(0, 0, w, h)
        else
            -- Fallback vignette with manual gradient
            local vignetteSize = 300
            for i = 0, vignetteSize do
                local alpha = Lerp(i / vignetteSize, 180, 0)
                surface.SetDrawColor(0, 0, 0, alpha)
                surface.DrawRect(0, i, w, 1)
                surface.DrawRect(0, h - i, w, 1)
                surface.DrawRect(i, 0, 1, h)
                surface.DrawRect(w - i, 0, 1, h)
            end
        end

        draw.SimpleText(
            "RE MERCENARIES", "RE4M_Title",
            w / 2, 50,
            Color(255, 60, 60, 255),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP
        )
        draw.SimpleText(
            "BETA", "RE4M_Subtitle",
            w / 2, 115,
            Color(255, 200, 50, 220),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP
        )

        surface.SetDrawColor(255, 60, 60, 150)
        surface.DrawRect(w / 2 - 200, 155, 400, 2)
    end

    contentPanel = vgui.Create("DPanel", MainMenuFrame)
    contentPanel:SetPos(sw * 0.05, 180)
    contentPanel:SetSize(sw * 0.9, sh - 280)
    contentPanel.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(0, 0, 0, 160))
    end

    local tabBar = vgui.Create("DPanel", MainMenuFrame)
    tabBar:SetPos(sw * 0.05, 165)
    tabBar:SetSize(sw * 0.9, 30)
    tabBar.Paint = function() end

    local tabs = {
        { id = "lobby",       label = "LOBBY" },
        { id = "loadout",     label = "LOADOUT" },
        { id = "playermodel", label = "PLAYER MODEL" },
        { id = "theme",       label = "MAP THEME" },
    }

    for i, tab in ipairs(tabs) do
        local tabData = tab
        local tabBtn = vgui.Create("DButton", tabBar)
        tabBtn:SetPos((i - 1) * 205, 0)
        tabBtn:SetSize(200, 28)
        tabBtn:SetText(tabData.label)
        tabBtn:SetFont("RE4M_Small")
        tabBtn:SetTextColor(Color(255, 255, 255))

        tabBtn.Paint = function(self, w, h)
            local bg = currentTab == tabData.id
                and Color(180, 40, 40, 220)
                or  Color(60, 30, 30, 180)

            if self:IsHovered() and currentTab ~= tabData.id then
                bg = Color(120, 40, 40, 200)
            end
            draw.RoundedBoxEx(6, 0, 0, w, h, bg, true, true, false, false)
        end

        tabBtn.Think = function(self)
            self:SetEnabled(not (tabData.id ~= "lobby" and IsReadyPlayerLockedToLobby()))
        end

        tabBtn.DoClick = function()
            if tabData.id ~= "lobby" and IsReadyPlayerLockedToLobby() then
                currentTab = "lobby"
                RE4M_RefreshMenuContent(contentPanel)
                RequestLobbyProgression()
                return
            end
            if tabData.id == "theme" and not LocalPlayer():RE4M_IsAdmin() then return end
            currentTab = tabData.id
            if tabData.id == "lobby" then RequestLobbyProgression() end
            RE4M_RefreshMenuContent(contentPanel)
        end
    end

    local bottomPanel = vgui.Create("DPanel", MainMenuFrame)
    bottomPanel:SetPos(sw * 0.05, sh - 85)
    bottomPanel:SetSize(sw * 0.9, 70)
    bottomPanel.Paint = function() end

    local readyBtn = vgui.Create("DButton", bottomPanel)
    readyBtn:SetSize(200, 50)
    readyBtn:SetPos(0, 10)
    readyBtn:SetFont("RE4M_MenuButton")
    readyBtn:SetTextColor(Color(255, 255, 255))
    readyBtn:SetText("READY")

    readyBtn.Paint = function(self, w, h)
        local isReady = IsValid(LocalPlayer()) and LocalPlayer():RE4M_GetReady()
        local bg = isReady
            and Color(50, 180, 50, 220)
            or  Color(100, 100, 100, 200)

        if self:IsHovered() then
            bg = isReady
                and Color(70, 200, 70, 240)
                or  Color(140, 140, 140, 220)
        end

        draw.RoundedBox(8, 0, 0, w, h, bg)
        surface.SetDrawColor(255, 255, 255, 60)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
        draw.SimpleText(self:GetText(), self:GetFont(), w / 2, h / 2,
            Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    readyBtn.DoClick = function()
        local newReady = not LocalPlayer():RE4M_GetReady()
        net.Start("RE4M_PlayerReady")
            net.WriteBool(newReady)
        net.SendToServer()
        if newReady then RE4M_PlayUISound("ui/ui_ready.wav", "ui/btn_click.wav") end
    end

    readyBtn.Think = function(self)
        if IsValid(LocalPlayer()) and LocalPlayer():RE4M_GetReady() then
            self:SetText("✓ READY")
        else
            self:SetText("READY")
        end
    end

    local startBtn = vgui.Create("DButton", bottomPanel)
    startBtn:SetSize(280, 50)
    startBtn:SetPos(sw * 0.9 - 280, 10)
    startBtn:SetFont("RE4M_MenuButton")
    startBtn:SetTextColor(Color(255, 255, 255))
    startBtn:SetEnabled(false)

    startBtn.Paint = function(self, w, h)
        local ready = self:IsEnabled()
        local bg = ready and (self:IsHovered()
            and Color(220, 60, 60, 240)
            or Color(180, 40, 40, 220)) or Color(75, 55, 55, 200)
        draw.RoundedBox(8, 0, 0, w, h, bg)
        surface.SetDrawColor(255, 100, 100, ready and 100 or 35)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
        draw.SimpleText(self:GetText(), self:GetFont(), w / 2, h / 2,
            ready and Color(255, 255, 255) or Color(190, 175, 175),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    startBtn.Think = function(self)
        local readyCount = GetGlobalInt("RE4M_LobbyReadyCount", 0)
        local required = math.max(GetGlobalInt("RE4M_LobbyReadyRequired", 1), 1)
        if readyCount < required then
            self:SetEnabled(false)
            self:SetText("READY UP (" .. readyCount .. "/" .. required .. ")")
        else
            local remaining = math.ceil(GetGlobalFloat("RE4M_LobbyStartAt", 0) - CurTime())
            if remaining > 0 then
                self:SetEnabled(false)
                self:SetText("STARTING IN " .. remaining)
            else
                self:SetEnabled(false)
                self:SetText("STARTING MATCH...")
            end
        end
    end

    startBtn.DoClick = function()
        if not startBtn:IsEnabled() then return end
        net.Start("RE4M_StartGame")
        net.SendToServer()
    end

    local playerListPanel = vgui.Create("DPanel", bottomPanel)
    playerListPanel:SetPos(220, 5)
    playerListPanel:SetSize(sw * 0.9 - 520, 60)
    playerListPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(0, 0, 0, 100))

        local x = 10
        for _, ply in ipairs(player.GetAll()) do
            if not IsValid(ply) then continue end

            local ready = ply:RE4M_GetReady()
            local col   = ready and Color(50, 255, 50) or Color(200, 200, 200)
            local icon  = ready and "✓ " or "○ "
            local text  = icon .. ply:Nick() .. "  Lv." .. ply:GetNWInt("RE4M_PlayerLevel", 1)

            draw.SimpleText(text, "RE4M_Small", x, h / 2, col,
                TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            surface.SetFont("RE4M_Small")
            local tw, _ = surface.GetTextSize(text)
            x = x + tw + 20
            if x > w - 20 then break end
        end
    end

    RE4M_RefreshMenuContent(contentPanel)
    RequestLobbyProgression()
end

function RE4M_CloseMainMenu()
    if IsValid(MainMenuFrame) then
        MainMenuFrame:Remove()
        MainMenuFrame = nil
    end
    RE4M_CLIENT.MenuOpen = false
    RE4M_StopMenuMusic()
end

function RE4M_RefreshMenuContent(parent)
    if not IsValid(parent) then return end
    parent:Clear()

    if currentTab == "loadout" then
        RE4M_CreateLoadoutPanel(parent)
    elseif currentTab == "playermodel" then
        RE4M_CreatePlayermodelPanel(parent)
    elseif currentTab == "lobby" then
        RE4M_CreateLobbyPanel(parent)
    elseif currentTab == "theme" then
        RE4M_CreateThemePanel(parent)
    end
end

-- ============================================
-- LOBBY MODEL VIEW
-- ============================================

function RE4M_CreateLobbyPanel(parent)
    local pw, ph = parent:GetSize()
    local players = player.GetAll()
    parent.ProgressionRevision = RE4M_CLIENT.ProgressionRevision or 0
    parent.Think = function(self)
        local revision = RE4M_CLIENT.ProgressionRevision or 0
        if currentTab == "lobby" and self.ProgressionRevision ~= revision then
            RE4M_RefreshMenuContent(self)
        end
    end

    local header = vgui.Create("DPanel", parent)
    header:SetPos(10, 8)
    header:SetSize(pw - 20, 28)
    header.Paint = function(self, w, h)
        local title = lobbySection == "shop" and "MERC POINTS  •  SKILL SHOP"
            or (lobbySection == "equipped" and "EQUIPPED PERKS" or "LOBBY")
        draw.SimpleText(title, "RE4M_Medium", w / 2, 0,
            Color(255, 90, 90), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end

    local sectionButton = vgui.Create("DButton", header)
    sectionButton:SetPos(0, 0)
    sectionButton:SetSize(105, 25)
    sectionButton:SetText("PLAYERS")
    sectionButton:SetFont("RE4M_Tiny")
    sectionButton:SetTextColor(Color(255, 255, 255))
    sectionButton.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and Color(150, 45, 45) or Color(70, 30, 30))
    end
    sectionButton.DoClick = function()
        lobbySection = "players"
        RE4M_RefreshMenuContent(parent)
    end

    local function AddLobbySectionButton(label, id, x, width)
        local button = vgui.Create("DButton", header)
        button:SetPos(x, 0)
        button:SetSize(width, 25)
        button:SetText(label)
        button:SetFont("RE4M_Tiny")
        button:SetTextColor(Color(255, 255, 255))
        button.Paint = function(self, w, h)
            local active = lobbySection == id
            draw.RoundedBox(4, 0, 0, w, h,
                active and Color(150, 45, 45) or (self:IsHovered() and Color(115, 40, 40) or Color(70, 30, 30)))
        end
        button.DoClick = function()
            lobbySection = id
            RE4M_RefreshMenuContent(parent)
        end
        return button
    end
    AddLobbySectionButton("SKILL SHOP", "shop", 112, 112)
    AddLobbySectionButton("EQUIPPED SKILLS", "equipped", 231, 145)

    local localPlayer = LocalPlayer()
    local localKey = IsValid(localPlayer) and localPlayer:SteamID64() or ""
    if localKey == "0" and IsValid(localPlayer) then localKey = localPlayer:SteamID() end
    local localProfile = (RE4M_CLIENT.ProgressionProfiles or {})[localKey] or {}
    -- The replicated player field is authoritative for the local player's
    -- ownership, including when a broadcast snapshot refreshed the lobby cache.
    if IsValid(localPlayer) then
        local ownedJson = localPlayer:GetNWString("RE4M_OwnedSkills", "[]")
        local ownedSkills = util.JSONToTable(ownedJson) or {}
        if istable(ownedSkills) then
            localProfile = table.Copy(localProfile)
            localProfile.ownedSkills = ownedSkills
        end
        local equippedSkills = {}
        for slot = 1, 3 do
            local skillID = localPlayer:GetNWString("RE4M_EquippedSkill" .. slot, "")
            if skillID ~= "" then equippedSkills[#equippedSkills + 1] = skillID end
        end
        if #equippedSkills > 0 or istable(localProfile.equippedSkills) then
            localProfile = table.Copy(localProfile)
            localProfile.equippedSkills = equippedSkills
        end
    end
    local balance = vgui.Create("DLabel", header)
    balance:SetPos(pw - 255, 2)
    balance:SetSize(245, 22)
    balance:SetText("MP: " .. tostring(localProfile.mercPoints or (IsValid(localPlayer) and localPlayer:GetNWInt("RE4M_MercPoints", 0)) or 0) ..
        "   Equipped: " .. #(localProfile.equippedSkills or {}) .. "/3")
    balance:SetFont("RE4M_Small")
    balance:SetTextColor(Color(255, 220, 100))
    balance:SetContentAlignment(6)

    if lobbySection == "shop" or lobbySection == "equipped" then
        local scroll = vgui.Create("DScrollPanel", parent)
        scroll:SetPos(10, 40)
        scroll:SetSize(pw - 20, ph - 50)
        local layout = vgui.Create("DIconLayout", scroll)
        layout:SetPos(0, 0)
        layout:SetSize(scroll:GetWide() - 10, ph)
        layout:SetSpaceX(8)
        layout:SetSpaceY(8)
        local skills = RE4M_SKILLS or {}
        local cardWidth = math.max(220, math.floor((pw - 55) / 3))
        local ownedCount = 0
        for _, skill in ipairs(skills) do
            local skillData = skill
            local owned = table.HasValue(localProfile.ownedSkills or {}, skillData.id)
            local equipped = table.HasValue(localProfile.equippedSkills or {}, skillData.id)
            if lobbySection == "equipped" and not owned then continue end
            ownedCount = ownedCount + 1
            local card = layout:Add("DPanel")
            card:SetSize(cardWidth, 125)
            card.Paint = function(self, w, h)
                draw.RoundedBox(5, 0, 0, w, h, Color(25, 14, 16, 245))
                surface.SetDrawColor(equipped and Color(150, 85, 225, 180) or Color(150, 45, 45, 100))
                surface.DrawOutlinedRect(0, 0, w, h, 1)
                draw.SimpleText(skillData.name, "RE4M_Small", 9, 8, Color(255, 220, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                draw.SimpleText(owned and (equipped and "EQUIPPED" or "OWNED") or (skillData.cost .. " MP"), "RE4M_Tiny", 9, h - 28,
                    equipped and Color(210, 160, 255) or Color(255, 220, 100), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end
            local description = vgui.Create("DLabel", card)
            description:SetPos(9, 31)
            description:SetSize(cardWidth - 18, 53)
            description:SetFont("RE4M_Tiny")
            description:SetText(skillData.description)
            description:SetTextColor(Color(220, 210, 210))
            description:SetWrap(true)
            description:SetAutoStretchVertical(false)
            description:SetContentAlignment(7)
            local action = vgui.Create("DButton", card)
            action:SetPos(cardWidth - 105, 91)
            action:SetSize(96, 26)
            action:SetText(lobbySection == "equipped" and (equipped and "UNEQUIP" or "EQUIP")
                or (owned and (equipped and "UNEQUIP" or "EQUIP") or "BUY"))
            action:SetFont("RE4M_Tiny")
            action:SetTextColor(Color(255, 255, 255))
            -- Leave Buy clickable even if our cached balance is stale; the
            -- server validates the purchase and returns the current result.
            local atEquipLimit = #(localProfile.equippedSkills or {}) >= 3
            action:SetEnabled(not owned or equipped or not atEquipLimit)
            action.Paint = function(self, w, h)
                draw.RoundedBox(3, 0, 0, w, h, self:IsEnabled() and (self:IsHovered() and Color(170, 55, 55) or Color(110, 38, 38)) or Color(55, 45, 45))
            end
            action.DoClick = function()
                if not owned then
                    net.Start("RE4M_BuySkill")
                    net.WriteString(skillData.id)
                    net.SendToServer()
                    return
                end

                local selected = {}
                local seen = {}
                for slot = 1, 3 do
                    local activeID = IsValid(localPlayer) and localPlayer:GetNWString("RE4M_EquippedSkill" .. slot, "") or ""
                    if activeID == "" then activeID = (localProfile.equippedSkills or {})[slot] or "" end
                    if activeID ~= "" and activeID ~= skillData.id and not seen[activeID] then
                        selected[#selected + 1] = activeID
                        seen[activeID] = true
                    end
                end
                if not equipped then
                    if #selected >= 3 then
                        notification.AddLegacy("Unequip a skill before selecting another.", NOTIFY_ERROR, 4)
                        return
                    end
                    selected[#selected + 1] = skillData.id
                end

                net.Start("RE4M_SetEquippedSkills")
                    net.WriteUInt(#selected, 2)
                    for _, selectedID in ipairs(selected) do net.WriteString(selectedID) end
                net.SendToServer()
            end
        end
        if lobbySection == "equipped" and ownedCount == 0 then
            local empty = vgui.Create("DLabel", parent)
            empty:SetPos(20, 58)
            empty:SetSize(pw - 40, 32)
            empty:SetFont("RE4M_Small")
            empty:SetText("No skills purchased yet. Open Skill Shop to buy and equip perks.")
            empty:SetTextColor(Color(220, 205, 220))
            empty:SetContentAlignment(5)
        end
        return
    end

    if #players == 0 then
        local empty = vgui.Create("DLabel", parent)
        empty:SetPos(20, 50)
        empty:SetSize(pw - 40, 30)
        empty:SetFont("RE4M_Small")
        empty:SetText("Waiting for players...")
        empty:SetTextColor(Color(220, 220, 220))
        empty:SetContentAlignment(5)
        return
    end

    -- A single shared room backdrop sits behind every player preview so the
    -- characters read as one lobby lineup instead of separate model cards.
    local room = vgui.Create("DPanel", parent)
    room:SetPos(10, 40)
    room:SetSize(pw - 20, ph - 50)
    local roomMaterial = Material("vgui/re4mercs/background_lobby.png", "smooth")
    room.Paint = function(self, w, h)
        if roomMaterial and not roomMaterial:IsError() then
            surface.SetDrawColor(255, 255, 255, 255)
            surface.SetMaterial(roomMaterial)
            surface.DrawTexturedRect(0, 0, w, h)
        else
            draw.RoundedBox(5, 0, 0, w, h, Color(18, 20, 22, 255))
        end

        surface.SetDrawColor(0, 0, 0, 55)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(0, 0, 0, 105)
        surface.DrawOutlinedRect(0, 0, w, h, 3)
    end

    local scroll = vgui.Create("DScrollPanel", parent)
    scroll:SetPos(10, 40)
    scroll:SetSize(pw - 20, ph - 50)
    scroll.Paint = function() end

    local gap = 10
    local columns = math.min(#players, math.max(1, math.floor((pw - 20 + gap) / (280 + gap))))
    local cardWidth = math.floor((pw - 20 - (columns - 1) * gap) / columns)
    local cardHeight = math.max(340, ph - 65)
    local modelHeight = cardHeight - 130
    local layout = vgui.Create("DIconLayout", scroll)
    layout:SetPos(0, 0)
    layout:SetSize(scroll:GetWide() - 10,
        math.ceil(#players / columns) * (cardHeight + gap))
    layout:SetSpaceX(gap)
    layout:SetSpaceY(gap)

    local profiles = RE4M_CLIENT.ProgressionProfiles or {}
    local function GetPlayerKey(ply)
        local key = ply:SteamID64()
        if not key or key == "0" then key = ply:SteamID() end
        return key
    end

    for _, ply in ipairs(players) do
        if not IsValid(ply) then continue end
        local lobbyPlayer = ply

        local card = layout:Add("DPanel")
        card:SetSize(cardWidth, cardHeight)
        card.Paint = function(self, w, h)
            draw.RoundedBoxEx(5, 0, modelHeight + 5, w, h - modelHeight - 5,
                Color(17, 10, 11, 220), false, false, true, true)
            surface.SetDrawColor(155, 45, 45, 135)
            surface.DrawOutlinedRect(0, modelHeight + 5, w, h - modelHeight - 5, 1)
        end

        local playerModelPath = lobbyPlayer:GetModel()
        if not isstring(playerModelPath) or playerModelPath == "" then
            playerModelPath = "models/player/kleiner.mdl"
        end

        local modelPanel = vgui.Create("DModelPanel", card)
        modelPanel:SetPos(0, 0)
        modelPanel:SetSize(cardWidth, modelHeight)
        modelPanel:SetFOV(36)
        modelPanel:SetAnimated(true)
        modelPanel:SetModel(playerModelPath)
        modelPanel:SetMouseInputEnabled(false)
        modelPanel.LayoutEntity = function(self, ent)
            if self.bAnimated then self:RunAnimation() end
            ent:SetAngles(Angle(0, 12 + math.sin(CurTime() * 0.45) * 3, 0))
        end

        timer.Simple(0, function()
            if not IsValid(modelPanel) or not IsValid(modelPanel.Entity) then return end
            local ent = modelPanel.Entity
            local idleSequence = ent:LookupSequence("menu_idle")
            if not idleSequence or idleSequence < 0 then
                idleSequence = ent:LookupSequence("idle_all_01")
            end
            if idleSequence and idleSequence >= 0 then
                ent:ResetSequence(idleSequence)
                ent:SetCycle(0)
                ent:SetPlaybackRate(1)
            end
            ent:SetSkin(IsValid(lobbyPlayer) and lobbyPlayer:GetSkin() or 0)
            if IsValid(lobbyPlayer) then
                pcall(function()
                    for group = 0, lobbyPlayer:GetNumBodyGroups() - 1 do
                        ent:SetBodygroup(group, lobbyPlayer:GetBodygroup(group))
                    end
                end)
            end
            FitPreviewCamera(modelPanel, ent, 2.2)
            local mins, maxs = ent:OBBMins(), ent:OBBMaxs()
            if mins and maxs then
                local waistLookAt = Vector(0, 0, Lerp(0.52, mins.z, maxs.z))
                local distance = modelPanel.PreviewDistance or 0
                local cameraOffset = Vector(distance, 0, distance * 0.08)
                modelPanel.PreviewLookAt = waistLookAt
                modelPanel:SetLookAt(waistLookAt)
                modelPanel:SetCamPos(waistLookAt + cameraOffset)
            end
        end)
        local key = GetPlayerKey(lobbyPlayer)
        local profile = profiles[key] or {}
        local weaponRows = {}
        local loadout = istable(profile.loadout) and profile.loadout or {}
        for _, weaponClass in ipairs(loadout) do
            local weaponData = profile.weapons and profile.weapons[weaponClass] or nil
            local weapon = weapons.GetStored(weaponClass)
            local weaponName = weapon and weapon.PrintName or weaponClass
            if isstring(weaponName) and string.StartWith(weaponName, "#") then
                weaponName = language.GetPhrase(string.sub(weaponName, 2))
            end
            weaponRows[#weaponRows + 1] = string.format("%s  Lv.%d",
                weaponName, tonumber(weaponData and weaponData.level) or 1)
        end

        local info = vgui.Create("DPanel", card)
        info:SetPos(9, modelHeight + 10)
        info:SetSize(cardWidth - 18, cardHeight - modelHeight - 15)
        info.Paint = function(self, w, h)
            if not IsValid(lobbyPlayer) then return end
            local ready = lobbyPlayer:RE4M_GetReady()
            local playerLevel = lobbyPlayer:GetNWInt("RE4M_PlayerLevel", tonumber(profile.level) or 1)
            draw.SimpleText(lobbyPlayer:Nick(), "RE4M_Small", 3, 2,
                Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText("PLAYER  Lv." .. playerLevel .. (ready and "  •  READY" or ""),
                "RE4M_Tiny", 3, 23,
                ready and Color(125, 255, 125) or Color(255, 205, 120),
                TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

            local equipped = istable(profile.equippedSkills) and profile.equippedSkills or {}
            if #equipped > 0 then
                local labels = {}
                for _, id in ipairs(equipped) do
                    local data = RE4M_SKILLS_BY_ID and RE4M_SKILLS_BY_ID[id]
                    labels[#labels + 1] = data and data.name or id
                end
                draw.SimpleText("SKILLS: " .. table.concat(labels, ", "), "RE4M_Tiny", 3, 42,
                    Color(215, 175, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            else
                draw.SimpleText("SKILLS: none equipped", "RE4M_Tiny", 3, 42,
                    Color(175, 165, 175), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end

            if #weaponRows == 0 then
                draw.SimpleText("No weapons selected", "RE4M_Tiny", 3, 61,
                    Color(190, 180, 180), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            else
                for i = 1, math.min(#weaponRows, 3) do
                    draw.SimpleText(weaponRows[i], "RE4M_Tiny", 3, 61 + ((i - 1) * 13),
                        Color(220, 200, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                end
            end
        end
    end
end

net.Receive("RE4M_SkillShopResult", function()
    local success = net.ReadBool()
    local message = net.ReadString()
    if notification and notification.AddLegacy then
        notification.AddLegacy(message, success and NOTIFY_GENERIC or NOTIFY_ERROR, 4)
        surface.PlaySound(success and "buttons/button15.wav" or "buttons/button10.wav")
    else
        chat.AddText(success and Color(120, 255, 120) or Color(255, 120, 120), "[Merc Shop] " .. message)
    end
end)

-- ============================================
-- LOADOUT TAB
-- ============================================

function RE4M_CreateLoadoutPanel(parent)
    local pw, ph = parent:GetSize()
    local cfg      = RE4MERCS_GetConfig()
    local maxSlots = cfg and cfg.MaxWeaponSlots or 3

    local browserPanel = vgui.Create("DPanel", parent)
    browserPanel:SetPos(10, 10)
    browserPanel:SetSize(pw * 0.6 - 20, ph - 20)
    browserPanel.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(30, 15, 15, 220))
        draw.SimpleText("AVAILABLE WEAPONS", "RE4M_Small",
            w / 2, 5, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end

    local searchBar = vgui.Create("DTextEntry", browserPanel)
    searchBar:SetPos(10, 28)
    searchBar:SetSize(browserPanel:GetWide() - 20, 28)
    searchBar:SetPlaceholderText("Search weapons...")
    searchBar:SetFont("RE4M_Small")
    searchBar:SetTextColor(Color(255, 255, 255))
    searchBar.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(50, 30, 30, 240))
        surface.SetDrawColor(180, 60, 60, 100)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        self:DrawTextEntryText(
            Color(255, 255, 255),
            Color(255, 100, 100),
            Color(255, 255, 255)
        )
    end

    local categoryFilter = vgui.Create("DComboBox", browserPanel)
    categoryFilter:SetPos(10, 60)
    categoryFilter:SetSize(browserPanel:GetWide() - 20, 25)
    categoryFilter:SetValue("All Categories")
    categoryFilter:AddChoice("All Categories")

    for _, cat in ipairs(RE4MERCS_WEAPON_CATEGORIES) do
        categoryFilter:AddChoice(cat)
    end

    categoryFilter:SetFont("RE4M_Small")
    categoryFilter:SetTextColor(Color(255, 255, 255))

    local weaponList = vgui.Create("DListView", browserPanel)
    weaponList:SetPos(10, 90)
    weaponList:SetSize(browserPanel:GetWide() - 20, browserPanel:GetTall() - 100)
    weaponList:SetMultiSelect(false)
    weaponList:AddColumn("Name"):SetWidth(200)
    weaponList:AddColumn("Category"):SetWidth(120)
    weaponList:AddColumn("Class"):SetWidth(150)
    weaponList:AddColumn("Level"):SetWidth(70)

    weaponList.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(20, 10, 10, 220))
    end

    -- Patch AddLine to colour text white
    local origAddLine = weaponList.AddLine
    weaponList.AddLine = function(self, ...)
        local line = origAddLine(self, ...)
        if line and line.Columns then
            for _, col in ipairs(line.Columns) do
                if IsValid(col) then
                    col:SetTextColor(Color(255, 255, 255))
                end
            end
        end
        return line
    end

    local function PopulateWeapons()
        weaponList:Clear()
        local search = string.lower(searchBar:GetValue() or "")
        local category = categoryFilter:GetSelected()
        category = category or "All Categories"
        local localPlayer = LocalPlayer()
        local profileKey = IsValid(localPlayer) and localPlayer:SteamID64() or nil
        if not profileKey or profileKey == "0" then
            profileKey = IsValid(localPlayer) and localPlayer:SteamID() or ""
        end
        local localProfile = (RE4M_CLIENT.ProgressionProfiles or {})[profileKey]
        local weaponLevels = localProfile and localProfile.weapons or {}

        for _, wep in ipairs(RE4M_CLIENT.WeaponList) do
            local matchSearch = search == ""
                or string.find(string.lower(wep.name  or ""), search, 1, true)
                or string.find(string.lower(wep.class or ""), search, 1, true)

            local matchCategory = category == "All Categories"
                or wep.category == category

            if matchSearch and matchCategory then
                local weaponProgress = weaponLevels[wep.class]
                local weaponLevel = tonumber(weaponProgress and weaponProgress.level) or 1
                local line = weaponList:AddLine(wep.name, wep.category, wep.class, "Lv." .. weaponLevel)
                line.WeaponData = wep
            end
        end
    end

    PopulateWeapons()
    weaponList.LastProgressionRevision = RE4M_CLIENT.ProgressionRevision or 0
    weaponList.Think = function(self)
        local revision = RE4M_CLIENT.ProgressionRevision or 0
        if revision == self.LastProgressionRevision then return end
        self.LastProgressionRevision = revision
        timer.Simple(0, function()
            if IsValid(self) then PopulateWeapons() end
        end)
    end
    searchBar.OnChange       = function() PopulateWeapons() end
    categoryFilter.OnSelect  = function() timer.Simple(0, function() PopulateWeapons() end) end

    local loadoutPanel = vgui.Create("DPanel", parent)
    loadoutPanel:SetPos(pw * 0.6, 10)
    loadoutPanel:SetSize(pw * 0.4 - 10, ph - 20)
    loadoutPanel.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(30, 15, 15, 220))
        draw.SimpleText("SELECTED LOADOUT", "RE4M_Medium",
            w / 2, 10, Color(255, 60, 60), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end

    local slotHeight = 70
    local slotNames  = { "PRIMARY", "SECONDARY", "MELEE / SPECIAL" }

    for i = 1, maxSlots do
        local slot = vgui.Create("DPanel", loadoutPanel)
        slot:SetPos(10, 45 + (i - 1) * (slotHeight + 10))
        slot:SetSize(loadoutPanel:GetWide() - 20, slotHeight)
        slot.SlotIndex = i

        slot.Paint = function(self, w, h)
            local idx      = self.SlotIndex
            local hasWeapon = RE4M_CLIENT.SelectedLoadout[idx] ~= nil
            local bg = hasWeapon
                and Color(60, 30, 30, 220)
                or  Color(40, 20, 20, 180)

            draw.RoundedBox(6, 0, 0, w, h, bg)
            surface.SetDrawColor(255, 60, 60, 120)
            surface.DrawOutlinedRect(0, 0, w, h, 1)

            draw.SimpleText(
                slotNames[idx] or ("SLOT " .. idx),
                "RE4M_Tiny", 10, 5,
                Color(255, 200, 200, 200),
                TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP
            )

            if hasWeapon then
                local wep = RE4M_CLIENT.SelectedLoadout[idx]
                draw.SimpleText(
                    wep.name or wep.class, "RE4M_Medium",
                    10, h / 2 + 5,
                    Color(255, 255, 255),
                    TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
                )
                draw.SimpleText(
                    wep.class, "RE4M_Tiny",
                    10, h - 8,
                    Color(200, 200, 200, 150),
                    TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM
                )
            else
                draw.SimpleText(
                    "[ Click weapon to equip ]", "RE4M_Small",
                    w / 2, h / 2 + 5,
                    Color(200, 200, 200, 120),
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
                )
            end
        end

        local clearBtn = vgui.Create("DButton", slot)
        clearBtn:SetPos(slot:GetWide() - 30, 5)
        clearBtn:SetSize(25, 25)
        clearBtn:SetText("X")
        clearBtn:SetFont("RE4M_Small")
        clearBtn:SetTextColor(Color(255, 150, 150))
        clearBtn.SlotIndex = i

        clearBtn.Paint = function(self, w, h)
            if self:IsHovered() then
                draw.RoundedBox(4, 0, 0, w, h, Color(180, 30, 30, 220))
            end
        end

        clearBtn.DoClick = function(self)
            RE4M_CLIENT.SelectedLoadout[self.SlotIndex] = nil
            RE4M_SendLoadout()
            surface.PlaySound("ui/btn_click.wav")
        end
    end

    local previewY      = 45 + maxSlots * (slotHeight + 10) + 10
    local previewHeight = loadoutPanel:GetTall() - previewY - 10
    local wepPreview    = nil

    if previewHeight > 80 then
        local weaponPreviewBackground = vgui.Create("DPanel", loadoutPanel)
        weaponPreviewBackground:SetPos(10, previewY + 16)
        weaponPreviewBackground:SetSize(loadoutPanel:GetWide() - 20, previewHeight - 20)
        weaponPreviewBackground.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, Color(20, 10, 10, 220))
        end

        wepPreview = vgui.Create("DModelPanel", loadoutPanel)
        wepPreview:SetPos(10, previewY + 16)
        wepPreview:SetSize(loadoutPanel:GetWide() - 20, previewHeight - 20)
        wepPreview:SetFOV(48)
        EnablePreviewControls(wepPreview)

        local weaponPreviewHint = vgui.Create("DLabel", loadoutPanel)
        weaponPreviewHint:SetPos(10, previewY + 18)
        weaponPreviewHint:SetSize(loadoutPanel:GetWide() - 20, 16)
        weaponPreviewHint:SetFont("RE4M_Tiny")
        weaponPreviewHint:SetTextColor(Color(210, 210, 210, 170))
        weaponPreviewHint:SetText("DRAG TO ROTATE  •  WHEEL TO ZOOM")
        weaponPreviewHint:SetContentAlignment(8)
    end

    weaponList.OnRowSelected = function(panel, rowIndex, row)
        if not row or not row.WeaponData then return end

        local slotIdx
        for j = 1, maxSlots do
            if RE4M_CLIENT.SelectedLoadout[j] == nil then
                slotIdx = j
                break
            end
        end
        if not slotIdx then slotIdx = maxSlots end

        RE4M_CLIENT.SelectedLoadout[slotIdx] = row.WeaponData
        RE4M_SendLoadout()

        if IsValid(wepPreview)
            and row.WeaponData.model
            and row.WeaponData.model ~= ""
        then
            wepPreview:SetModel(row.WeaponData.model)
            local ent = wepPreview.Entity
            if IsValid(ent) then
                FitPreviewCamera(wepPreview, ent, 1.35)
            end

            timer.Simple(0, function()
                if not IsValid(wepPreview) then return end
                FitPreviewCamera(wepPreview, wepPreview.Entity, 1.35)
            end)
        end

        surface.PlaySound("ui/btn_click.wav")
    end
end

function RE4M_SendLoadout()
    local cfg      = RE4MERCS_GetConfig and RE4MERCS_GetConfig()
    local maxSlots = (cfg and cfg.MaxWeaponSlots) or 3

    local classes = {}
    for i = 1, maxSlots do
        if RE4M_CLIENT.SelectedLoadout[i] then
            table.insert(classes, RE4M_CLIENT.SelectedLoadout[i].class)
        end
    end

    net.Start("RE4M_SetLoadout")
        net.WriteUInt(#classes, 4)
        for _, class in ipairs(classes) do
            net.WriteString(class)
        end
    net.SendToServer()
end

-- ============================================
-- PLAYERMODEL TAB
-- ============================================

function RE4M_CreatePlayermodelPanel(parent)
    local pw, ph = parent:GetSize()

    -- ========================================
    -- STATE (loaded from convars every open)
    -- ========================================
    local state = {
        modelPath   = GetConVar("re4m_playermodel"):GetString() or "",
        modelName   = "",
        voxPackPath = "",
        skin        = GetConVar("re4m_playerskin"):GetInt() or 0,
        bodygroups  = RE4M_ParseBodygroups(GetConVar("re4m_playerbodygroups"):GetString() or ""),
        playerColor = Vector(
            GetConVar("re4m_playercolor_r"):GetFloat(),
            GetConVar("re4m_playercolor_g"):GetFloat(),
            GetConVar("re4m_playercolor_b"):GetFloat()
        ),
    }

    if state.modelPath == "" and IsValid(LocalPlayer()) then
        state.modelPath = LocalPlayer():GetModel()
    end

    -- ========================================
    -- Build the model list
    -- ========================================
    local allModels = player_manager.AllValidModels() or {}

    -- Keep the saved/current model selectable even when another add-on
    -- changed it without registering it in player_manager.AllValidModels().
    local currentModel = IsValid(LocalPlayer()) and LocalPlayer():GetModel() or ""
    local function HasModelPath(path)
        path = string.lower(path or "")
        for _, registeredPath in pairs(allModels) do
            if isstring(registeredPath) and string.lower(registeredPath) == path then
                return true
            end
        end
        return false
    end

    if state.modelPath ~= "" and not HasModelPath(state.modelPath) then
        if util.IsValidModel(state.modelPath) then
            allModels["Current Selection"] = state.modelPath
        else
            state.modelPath = currentModel
        end
    end

    if currentModel ~= "" and not HasModelPath(currentModel) then
        allModels["Current Model"] = currentModel
    end

    if state.modelPath == "" then
        for _, modelPath in pairs(allModels) do
            if isstring(modelPath) and modelPath ~= "" then
                state.modelPath = modelPath
                break
            end
        end
    end

    -- If player_manager returned nothing, add at least the HL2 defaults
    if table.Count(allModels) == 0 then
        allModels = {
            ["Kleiner"]   = "models/player/kleiner.mdl",
            ["Alyx"]      = "models/player/alyx.mdl",
            ["Barney"]    = "models/player/barney.mdl",
            ["Breen"]     = "models/player/breen.mdl",
            ["Eli"]       = "models/player/eli.mdl",
            ["Gman"]      = "models/player/gman_high.mdl",
            ["Mossman"]   = "models/player/mossman.mdl",
            ["Monk"]      = "models/player/monk.mdl",
            ["Odessa"]    = "models/player/odessa.mdl",
            ["Police"]    = "models/player/police.mdl",
            ["Combine"]   = "models/player/combine_soldier.mdl",
            ["Combine Prison Guard"] = "models/player/combine_soldier_prisonguard.mdl",
            ["Combine Elite"] = "models/player/combine_super_soldier.mdl",
        }
    end

    if state.modelPath == "" then
        for _, modelPath in pairs(allModels) do
            if isstring(modelPath) and modelPath ~= "" then
                state.modelPath = modelPath
                break
            end
        end
    end

    -- ========================================
    -- LAYOUT DIMENSIONS
    -- ========================================
    local browserWidth  = math.floor(pw * 0.35)
    local previewWidth  = math.floor(pw * 0.30)
    local controlsWidth = pw - browserWidth - previewWidth - 30

    -- ========================================
    -- LEFT: Model Browser
    -- ========================================
    local browserPanel = vgui.Create("DPanel", parent)
    browserPanel:SetPos(10, 10)
    browserPanel:SetSize(browserWidth - 5, ph - 20)
    browserPanel.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(30, 15, 15, 220))
        draw.SimpleText("PLAYER MODELS (" .. table.Count(allModels) .. ")", "RE4M_Small",
            w / 2, 5, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end

    local searchBar = vgui.Create("DTextEntry", browserPanel)
    searchBar:SetPos(10, 28)
    searchBar:SetSize(browserPanel:GetWide() - 20, 26)
    searchBar:SetPlaceholderText("Search models...")
    searchBar:SetFont("RE4M_Small")
    searchBar:SetTextColor(Color(255, 255, 255))
    searchBar.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(50, 30, 30, 240))
        surface.SetDrawColor(180, 60, 60, 100)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        self:DrawTextEntryText(Color(255, 255, 255), Color(255, 100, 100), Color(255, 255, 255))
    end

    local scrollPanel = vgui.Create("DScrollPanel", browserPanel)
    scrollPanel:SetPos(10, 60)
    scrollPanel:SetSize(browserPanel:GetWide() - 20, browserPanel:GetTall() - 70)

    do
        local sbar = scrollPanel:GetVBar()
        sbar:SetWide(8)
        sbar.Paint         = function(s, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(30, 15, 15, 200)) end
        sbar.btnGrip.Paint = function(s, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(180, 60, 60, 200)) end
        sbar.btnUp.Paint   = function() end
        sbar.btnDown.Paint = function() end
    end

    local iconLayout = vgui.Create("DIconLayout", scrollPanel)
    iconLayout:SetSize(scrollPanel:GetWide() - 10, 0)
    iconLayout:SetSpaceX(4)
    iconLayout:SetSpaceY(4)

    -- ========================================
    -- CENTER: 3D Preview
    -- ========================================
    local previewPanel = vgui.Create("DPanel", parent)
    previewPanel:SetPos(browserWidth + 5, 10)
    previewPanel:SetSize(previewWidth, ph - 20)
    previewPanel.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(30, 15, 15, 220))
        draw.SimpleText("PREVIEW", "RE4M_Small",
            w / 2, 5, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end

    local modelPreviewBackground = vgui.Create("DPanel", previewPanel)
    modelPreviewBackground:SetPos(5, 25)
    modelPreviewBackground:SetSize(previewPanel:GetWide() - 10, previewPanel:GetTall() - 100)
    modelPreviewBackground.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(15, 8, 8, 240))
    end

    local mdlPanel = vgui.Create("DModelPanel", previewPanel)
    mdlPanel:SetPos(5, 25)
    mdlPanel:SetSize(previewPanel:GetWide() - 10, previewPanel:GetTall() - 100)
    mdlPanel:SetFOV(42)
    mdlPanel:SetAnimated(true)
    EnablePreviewControls(mdlPanel)
    mdlPanel:SetDirectionalLight(BOX_TOP,   Color(255, 255, 255))
    mdlPanel:SetDirectionalLight(BOX_FRONT, Color(220, 220, 220))
    mdlPanel:SetAmbientLight(Color(90, 90, 90))

    local modelPreviewHint = vgui.Create("DLabel", previewPanel)
    modelPreviewHint:SetPos(5, 27)
    modelPreviewHint:SetSize(previewPanel:GetWide() - 10, 16)
    modelPreviewHint:SetFont("RE4M_Tiny")
    modelPreviewHint:SetTextColor(Color(210, 210, 210, 170))
    modelPreviewHint:SetText("DRAG TO ROTATE  •  WHEEL TO ZOOM")
    modelPreviewHint:SetContentAlignment(8)

    -- Info labels
    local nameLabel = vgui.Create("DLabel", previewPanel)
    nameLabel:SetPos(5, previewPanel:GetTall() - 72)
    nameLabel:SetSize(previewPanel:GetWide() - 10, 20)
    nameLabel:SetFont("RE4M_Small")
    nameLabel:SetTextColor(Color(255, 255, 255))
    nameLabel:SetText("")
    nameLabel:SetContentAlignment(5)

    local pathLabel = vgui.Create("DLabel", previewPanel)
    pathLabel:SetPos(5, previewPanel:GetTall() - 54)
    pathLabel:SetSize(previewPanel:GetWide() - 10, 14)
    pathLabel:SetFont("RE4M_Tiny")
    pathLabel:SetTextColor(Color(200, 200, 200, 150))
    pathLabel:SetText("")
    pathLabel:SetContentAlignment(5)

    local handsLabel = vgui.Create("DLabel", previewPanel)
    handsLabel:SetPos(5, previewPanel:GetTall() - 40)
    handsLabel:SetSize(previewPanel:GetWide() - 10, 14)
    handsLabel:SetFont("RE4M_Tiny")
    handsLabel:SetTextColor(Color(180, 180, 255, 180))
    handsLabel:SetText("")
    handsLabel:SetContentAlignment(5)

    local statusLabel = vgui.Create("DLabel", previewPanel)
    statusLabel:SetPos(5, previewPanel:GetTall() - 24)
    statusLabel:SetSize(previewPanel:GetWide() - 10, 20)
    statusLabel:SetFont("RE4M_Tiny")
    statusLabel:SetTextColor(Color(200, 200, 200, 100))
    statusLabel:SetText("")
    statusLabel:SetContentAlignment(5)

    -- ========================================
    -- COLOR HELPERS
    -- ========================================

    local function ApplyPlayerColorToPreview()
        local ent = mdlPanel.Entity
        if not IsValid(ent) then return end

        local pc = state.playerColor

        ent.GetPlayerColor = function() return pc end

        local r = math.Clamp(math.floor(pc.x * 255), 0, 255)
        local g = math.Clamp(math.floor(pc.y * 255), 0, 255)
        local b = math.Clamp(math.floor(pc.z * 255), 0, 255)

        if pc.x < 0.95 or pc.y < 0.95 or pc.z < 0.95 then
            ent:SetColor(Color(r, g, b, 255))
        else
            ent:SetColor(Color(255, 255, 255, 255))
        end
    end

    local function ApplyCustomizationToPreview()
        local ent = mdlPanel.Entity
        if not IsValid(ent) then return end

        ent:SetSkin(state.skin or 0)

        for i, val in ipairs(state.bodygroups) do
            ent:SetBodygroup(i - 1, val or 0)
        end

        ApplyPlayerColorToPreview()
    end

    -- ========================================
    -- RIGHT: Customization Controls
    -- ========================================
    local controlsPanel = vgui.Create("DPanel", parent)
    controlsPanel:SetPos(browserWidth + previewWidth + 15, 10)
    controlsPanel:SetSize(controlsWidth, ph - 20)
    controlsPanel.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(30, 15, 15, 220))
        draw.SimpleText("CUSTOMIZE", "RE4M_Small",
            w / 2, 5, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end

    local controlsScroll = vgui.Create("DScrollPanel", controlsPanel)
    controlsScroll:SetPos(5, 25)
    controlsScroll:SetSize(controlsPanel:GetWide() - 10, controlsPanel:GetTall() - 85)

    do
        local csbar = controlsScroll:GetVBar()
        csbar:SetWide(6)
        csbar.Paint         = function(s, w, h) draw.RoundedBox(3, 0, 0, w, h, Color(30, 15, 15, 200)) end
        csbar.btnGrip.Paint = function(s, w, h) draw.RoundedBox(3, 0, 0, w, h, Color(180, 60, 60, 200)) end
        csbar.btnUp.Paint   = function() end
        csbar.btnDown.Paint = function() end
    end

    -- ========================================
    -- REBUILD CONTROLS for the current model
    -- ========================================
    local rebuildRetries = 0

    local function RebuildControls()
        controlsScroll:Clear()

        local ent = mdlPanel.Entity
        if not IsValid(ent) then
            rebuildRetries = rebuildRetries + 1
            if rebuildRetries < 10 then
                timer.Simple(0.1, RebuildControls)
            end
            return
        end
        rebuildRetries = 0

        local ctrlWidth = controlsScroll:GetWide() - 12

        local function MakeSectionHeader(parentPanel, labelText, height)
            local panel = vgui.Create("DPanel", parentPanel)
            panel:SetSize(ctrlWidth, height or 50)
            panel:Dock(TOP)
            panel:DockMargin(0, 5, 0, 0)
            panel.Paint = function(self, w, h)
                draw.SimpleText(labelText, "RE4M_Tiny", 5, 2,
                    Color(255, 200, 200, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end
            return panel
        end

        -- ===== SKIN SELECTOR =====
        local numSkins = ent:SkinCount() or 1
        if numSkins > 1 then
            local skinPanel = MakeSectionHeader(controlsScroll,
                "SKIN  ( " .. numSkins .. " available )")

            local skinSlider = vgui.Create("DNumSlider", skinPanel)
            skinSlider:SetPos(0, 16)
            skinSlider:SetSize(ctrlWidth, 30)
            skinSlider:SetText("")
            skinSlider:SetMin(0)
            skinSlider:SetMax(numSkins - 1)
            skinSlider:SetDecimals(0)
            skinSlider:SetValue(state.skin or 0)
            skinSlider:SetDark(false)
            if IsValid(skinSlider.Label)    then skinSlider.Label:SetTextColor(Color(255, 255, 255)) end
            if IsValid(skinSlider.TextArea) then skinSlider.TextArea:SetTextColor(Color(255, 255, 255)) end

            skinSlider.OnValueChanged = function(self, val)
                state.skin = math.floor(val)
                if IsValid(ent) then ent:SetSkin(state.skin) end
            end
        end

        -- ===== BODYGROUP SELECTORS =====
        local numBG = ent:GetNumBodyGroups() or 0

        for bg = 0, numBG - 1 do
            local bgName  = ent:GetBodygroupName(bg) or ("Group " .. bg)
            local bgCount = ent:GetBodygroupCount(bg) or 1
            if bgCount <= 1 then continue end

            local capturedBG = bg

            local bgPanel = MakeSectionHeader(controlsScroll,
                string.upper(bgName) .. "  ( " .. bgCount .. " options )")

            local bgSlider = vgui.Create("DNumSlider", bgPanel)
            bgSlider:SetPos(0, 16)
            bgSlider:SetSize(ctrlWidth, 30)
            bgSlider:SetText("")
            bgSlider:SetMin(0)
            bgSlider:SetMax(bgCount - 1)
            bgSlider:SetDecimals(0)
            bgSlider:SetValue(state.bodygroups[capturedBG + 1] or 0)
            bgSlider:SetDark(false)
            if IsValid(bgSlider.Label)    then bgSlider.Label:SetTextColor(Color(255, 255, 255)) end
            if IsValid(bgSlider.TextArea) then bgSlider.TextArea:SetTextColor(Color(255, 255, 255)) end

            bgSlider.OnValueChanged = function(self, val)
                local v = math.floor(val)
                state.bodygroups[capturedBG + 1] = v
                if IsValid(ent) then ent:SetBodygroup(capturedBG, v) end
            end
        end

        -- ===== PLAYER COLOR =====
        local colorPanel = MakeSectionHeader(controlsScroll, "PLAYER COLOR", 190)
        colorPanel:SetSize(ctrlWidth, 190)

        local colorMixer = vgui.Create("DColorMixer", colorPanel)
        colorMixer:SetPos(5, 18)
        colorMixer:SetSize(ctrlWidth - 10, 165)
        colorMixer:SetPalette(true)
        colorMixer:SetAlphaBar(false)
        colorMixer:SetWangs(true)
        colorMixer:SetColor(Color(
            math.Clamp(state.playerColor.x * 255, 0, 255),
            math.Clamp(state.playerColor.y * 255, 0, 255),
            math.Clamp(state.playerColor.z * 255, 0, 255)
        ))

        colorMixer.ValueChanged = function(self, col)
            state.playerColor = Vector(col.r / 255, col.g / 255, col.b / 255)
            ApplyPlayerColorToPreview()
        end

        -- ===== TFA-VOX MODEL/PACK ASSIGNMENT =====
        -- TFA-VOX registers packs by full model path. The gamemode bridge
        -- assigns a registered pack table to the selected model on the server.
        if istable(TFAVOX_Models) then
            local voxHeader = vgui.Create("DPanel", controlsScroll)
            voxHeader:SetSize(ctrlWidth, 20)
            voxHeader:Dock(TOP)
            voxHeader:DockMargin(0, 10, 0, 0)
            voxHeader.Paint = function(self, w, h)
                draw.SimpleText("TFA-VOX PACK FOR THIS MODEL", "RE4M_Tiny", 5, 2,
                    Color(255, 200, 200, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end

            local packChoices = {}
            for packModel in pairs(TFAVOX_Models) do
                if isstring(packModel) and string.StartWith(string.lower(packModel), "models/") then
                    packChoices[#packChoices + 1] = packModel
                end
            end
            table.sort(packChoices)

            local voxPicker = vgui.Create("DComboBox", controlsScroll)
            voxPicker:SetSize(ctrlWidth, 28)
            voxPicker:Dock(TOP)
            voxPicker:DockMargin(0, 2, 0, 0)
            voxPicker:SetValue("Select an installed TFA-VOX pack")
            voxPicker.OnSelect = function(_, _, _, packModel)
                state.voxPackPath = packModel
            end

            for _, packModel in ipairs(packChoices) do
                local label = string.StripExtension(string.GetFileFromFilename(packModel))
                voxPicker:AddChoice(label, packModel)
            end

            local assignVox = vgui.Create("DButton", controlsScroll)
            assignVox:SetSize(ctrlWidth, 28)
            assignVox:Dock(TOP)
            assignVox:DockMargin(0, 3, 0, 0)
            assignVox:SetText("Assign pack to selected model")
            assignVox:SetEnabled(LocalPlayer():RE4M_IsAdmin() and #packChoices > 0)
            assignVox.DoClick = function()
                local packModel = state.voxPackPath
                if not packModel or state.modelPath == "" then return end

                net.Start("RE4M_AssignTFA_VOX")
                    net.WriteString(state.modelPath)
                    net.WriteString(packModel)
                net.SendToServer()
                state.voxPackPath = packModel
                surface.PlaySound("ui/btn_click.wav")
            end

            if #packChoices == 0 then
                local noPacks = vgui.Create("DLabel", controlsScroll)
                noPacks:SetSize(ctrlWidth, 20)
                noPacks:Dock(TOP)
                noPacks:SetText("No TFA-VOX packs are registered.")
                noPacks:SetTextColor(Color(200, 200, 200, 160))
            elseif not LocalPlayer():RE4M_IsAdmin() then
                local adminNote = vgui.Create("DLabel", controlsScroll)
                adminNote:SetSize(ctrlWidth, 20)
                adminNote:Dock(TOP)
                adminNote:SetText("An admin can assign a voice pack to this model.")
                adminNote:SetTextColor(Color(200, 200, 200, 160))
            end
        end

        -- ===== HANDS INFO (read-only) =====
        local handsInfo    = RE4M_GetHandsForModel(state.modelPath)
        local handsIsValid = util.IsValidModel(handsInfo.model)

        local handsInfoPanel = vgui.Create("DPanel", controlsScroll)
        handsInfoPanel:SetSize(ctrlWidth, 55)
        handsInfoPanel:Dock(TOP)
        handsInfoPanel:DockMargin(0, 10, 0, 0)

        handsInfoPanel.Paint = function(self, w, h)
            draw.SimpleText("VIEWMODEL HANDS", "RE4M_Tiny", 5, 2,
                Color(180, 180, 255, 180), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

            draw.SimpleText(string.GetFileFromFilename(handsInfo.model), "RE4M_Tiny", 5, 16,
                Color(200, 200, 255, 150), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

            local status    = handsIsValid and "✓ Valid" or "✗ Fallback will be used"
            local statusCol = handsIsValid and Color(50, 255, 50, 180) or Color(255, 180, 50, 180)
            draw.SimpleText(status, "RE4M_Tiny", 5, 32, statusCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

        controlsScroll:InvalidateLayout(true)
    end

    -- ========================================
    -- SET PREVIEW MODEL
    -- ========================================
    local function SetPreviewModel(modelPath, modelName)
        if not modelPath or modelPath == "" then return end

        -- Update state FIRST, before any validation that might bail out.
        -- This ensures clicking an icon always updates what Apply will send.
        local isSameModel = (state.modelPath == modelPath)

        state.modelPath = modelPath
        state.modelName = modelName or ""

        if not isSameModel then
            state.skin       = 0
            state.bodygroups = {}
        end

        -- Update labels immediately even if model panel takes a frame
        if IsValid(nameLabel) then
            nameLabel:SetText(modelName or string.GetFileFromFilename(modelPath))
        end
        if IsValid(pathLabel) then
            pathLabel:SetText(modelPath)
        end
        if IsValid(handsLabel) then
            local hi = RE4M_GetHandsForModel(modelPath)
            handsLabel:SetText("Hands: " .. string.GetFileFromFilename(hi.model))
        end

        -- Set the model on the panel (this works even if util.IsValidModel
        -- returns false on client — DModelPanel handles it internally)
        mdlPanel:SetModel(modelPath)

        timer.Simple(0, function()
            if not IsValid(mdlPanel) then return end

            local ent = mdlPanel.Entity
            if not IsValid(ent) then return end

            FitPreviewCamera(mdlPanel, ent, 1.25)

            local menuIdle = ent:LookupSequence("menu_idle")
            if menuIdle and menuIdle >= 0 then
                ent:ResetSequence(menuIdle)
                ent:SetCycle(0)
                ent:SetPlaybackRate(1)
            else
                for _, sequenceName in ipairs({ "idle_all_01", "idle01", "idle_subtle", "idle" }) do
                    local sequence = ent:LookupSequence(sequenceName)
                    if sequence and sequence >= 0 then
                        ent:ResetSequence(sequence)
                        break
                    end
                end
            end

            ApplyCustomizationToPreview()

            rebuildRetries = 0
            RebuildControls()
        end)
    end

    -- ========================================
    -- APPLY & RESET BUTTONS
    -- ========================================
    local mainApplyBtn = vgui.Create("DButton", controlsPanel)
    mainApplyBtn:SetPos(5, controlsPanel:GetTall() - 55)
    mainApplyBtn:SetSize(controlsPanel:GetWide() - 10, 26)
    mainApplyBtn:SetText("APPLY MODEL & SETTINGS")
    mainApplyBtn:SetFont("RE4M_Small")
    mainApplyBtn:SetTextColor(Color(255, 255, 255))
    mainApplyBtn.Paint = function(self, w, h)
        local bg = self:IsHovered() and Color(220, 60, 60, 240) or Color(160, 40, 40, 220)
        draw.RoundedBox(4, 0, 0, w, h, bg)
        surface.SetDrawColor(255, 100, 100, 80)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
    end

    mainApplyBtn.DoClick = function()
        if not state.modelPath or state.modelPath == "" then return end

        RunConsoleCommand("re4m_playermodel",      state.modelPath)
        RunConsoleCommand("re4m_playerskin",        tostring(state.skin or 0))
        RunConsoleCommand("re4m_playerbodygroups",  RE4M_BodygroupsToString(state.bodygroups))
        RunConsoleCommand("re4m_playercolor_r",     tostring(state.playerColor.x))
        RunConsoleCommand("re4m_playercolor_g",     tostring(state.playerColor.y))
        RunConsoleCommand("re4m_playercolor_b",     tostring(state.playerColor.z))

        net.Start("RE4M_SetPlayermodel")
            net.WriteString(state.modelPath)
        net.SendToServer()

        local hi = RE4M_GetHandsForModel(state.modelPath)
        net.Start("RE4M_SetPlayerHands")
            net.WriteString(hi.model)
            net.WriteUInt(hi.skin or 0, 8)
            net.WriteString(hi.body or "0000000")
        net.SendToServer()

        net.Start("RE4M_SetPlayerSkin")
            net.WriteUInt(state.skin or 0, 8)
        net.SendToServer()

        net.Start("RE4M_SetPlayerBodygroups")
            net.WriteString(RE4M_BodygroupsToString(state.bodygroups))
        net.SendToServer()

        net.Start("RE4M_SetPlayerColor")
            net.WriteFloat(state.playerColor.x)
            net.WriteFloat(state.playerColor.y)
            net.WriteFloat(state.playerColor.z)
        net.SendToServer()

        RE4M_CLIENT.SelectedModel = state.modelPath
        surface.PlaySound("ui/btn_click.wav")

        statusLabel:SetText("✓ Applied: " .. (state.modelName ~= "" and state.modelName or string.GetFileFromFilename(state.modelPath)))
        statusLabel:SetTextColor(Color(50, 255, 50))
        timer.Simple(2.5, function()
            if IsValid(statusLabel) then
                statusLabel:SetText("")
                statusLabel:SetTextColor(Color(200, 200, 200, 100))
            end
        end)
    end

    local resetBtn = vgui.Create("DButton", controlsPanel)
    resetBtn:SetPos(5, controlsPanel:GetTall() - 26)
    resetBtn:SetSize(controlsPanel:GetWide() - 10, 22)
    resetBtn:SetText("Reset Customization")
    resetBtn:SetFont("RE4M_Tiny")
    resetBtn:SetTextColor(Color(200, 200, 200))
    resetBtn.Paint = function(self, w, h)
        if self:IsHovered() then draw.RoundedBox(3, 0, 0, w, h, Color(80, 40, 40, 180)) end
    end

    resetBtn.DoClick = function()
        state.skin        = 0
        state.bodygroups  = {}
        state.playerColor = Vector(0.3, 1.0, 0.8)

        local ent = mdlPanel.Entity
        if IsValid(ent) then
            ent:SetSkin(0)
            local numBG = ent:GetNumBodyGroups() or 0
            for bg = 0, numBG - 1 do
                ent:SetBodygroup(bg, 0)
            end
            ent:SetColor(Color(255, 255, 255, 255))
            ent.GetPlayerColor = function() return state.playerColor end
        end

        rebuildRetries = 0
        RebuildControls()
        surface.PlaySound("ui/btn_click.wav")
    end

    -- ========================================
    -- POPULATE MODEL GRID
    -- ========================================
    local function PopulateModels()
        iconLayout:Clear()
        local search = string.lower(searchBar:GetValue() or "")

        for name, path in SortedPairs(allModels) do
            local matchSearch = search == "" or
                string.find(string.lower(name), search, 1, true) or
                string.find(string.lower(path), search, 1, true)

            if matchSearch then
                local icon = iconLayout:Add("SpawnIcon")
                icon:SetSize(64, 64)
                icon:SetModel(path)
                icon:SetTooltip(name .. "\n" .. path)

                icon.DoClick = function()
                    SetPreviewModel(path, name)
                    surface.PlaySound("ui/btn_click.wav")
                end

                icon.DoDoubleClick = function()
                    SetPreviewModel(path, name)
                    -- Small delay so state.modelPath is set before apply reads it
                    timer.Simple(0.05, function()
                        if not IsValid(mainApplyBtn) then return end
                        mainApplyBtn:DoClick()
                    end)
                end
            end
        end
    end

    PopulateModels()

    searchBar.OnChange = function()
        PopulateModels()
    end

    -- ========================================
    -- INITIAL LOAD
    -- ========================================
    local initialName = "Current Model"
    for name, path in pairs(allModels) do
        if string.lower(path) == string.lower(state.modelPath) then
            initialName = name
            break
        end
    end

    SetPreviewModel(state.modelPath, initialName)
end
-- ============================================
-- THEME TAB (Admin Only)
-- ============================================

function RE4M_CreateThemePanel(parent)
    local pw, ph = parent:GetSize()
    local isAdmin = LocalPlayer():RE4M_IsAdmin()

    if not isAdmin then
        local label = vgui.Create("DLabel", parent)
        label:SetPos(0, 0)
        label:SetSize(pw, ph)
        label:SetText("Admin access required to change themes.")
        label:SetFont("RE4M_Medium")
        label:SetTextColor(Color(200, 200, 200))
        label:SetContentAlignment(5)
        return
    end

    -- Theme selection
    local themePanel = vgui.Create("DPanel", parent)
    themePanel:SetPos(10, 10)
    themePanel:SetSize(pw - 20, ph - 20)
    themePanel.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(30, 15, 15, 200))
        draw.SimpleText("MAP THEME & ENEMIES", "RE4M_Medium", w/2, 10,
            Color(255, 60, 60), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end

    local themes = {
        {
            id = "default",
            name = "RESIDENT EVIL 4 ENEMIES",
            desc = "Ganados galore!. \n The classic RE4 experience",
            color = Color(180, 40, 40),
        },
        {
            id = "re5",
            name = "RESIDENT EVIL 5 ENEMIES",
            desc = "Manji have arrived!, The classic RE5 experience.\nNo additional addons required.",
            color = Color(255, 20, 50),
        },
        {
            id = "halflife",
            name = "HALF-LIFE 2 ENEMIES",
            desc = "Zombies, Antlions, Headcrabs, and more.\nAll enemies are on the same team and won't fight each other.\nNo additional addons required.",
            color = Color(255, 150, 50),
        },
        {
            id = "custom",
            name = "CUSTOM ENEMIES",
            desc = "Choose your own NextBots and NPCs from the Steam Workshop.\n NOT IMPLEMENTED YET, COMING SOON....",
            color = Color(50, 150, 255),
        },
    }

    for i, theme in ipairs(themes) do
        local btn = vgui.Create("DButton", themePanel)
        btn:SetPos(20, 50 + (i-1) * 100)
        btn:SetSize(pw - 60, 85)
        btn:SetText("")

        btn.Paint = function(self, w, h)
            local selected = RE4M_CLIENT.CurrentTheme == theme.id
            local bg = selected and ColorAlpha(theme.color, 150) or Color(50, 25, 25, 180)
            if self:IsHovered() and not selected then
                bg = ColorAlpha(theme.color, 80)
            end
            draw.RoundedBox(8, 0, 0, w, h, bg)

            if selected then
                surface.SetDrawColor(theme.color)
                surface.DrawOutlinedRect(0, 0, w, h, 3)
                draw.SimpleText("✓", "RE4M_Large", w - 40, h/2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end

            draw.SimpleText(theme.name, "RE4M_Medium", 15, 10,
                Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

            -- Draw description lines
            local lines = string.Explode("\n", theme.desc)
            for j, line in ipairs(lines) do
                draw.SimpleText(line, "RE4M_Tiny", 15, 35 + (j-1) * 16,
                    Color(200, 200, 200, 180), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end
        end

        btn.DoClick = function()
            RE4M_CLIENT.CurrentTheme = theme.id
            net.Start("RE4M_SetTheme")
                net.WriteString(theme.id)
            net.SendToServer()
            surface.PlaySound("ui/btn_click.wav")
        end
    end

    -- Custom NPC list (only visible when custom theme is selected)
    local customPanel = vgui.Create("DPanel", themePanel)
    customPanel:SetPos(20, 360)
    customPanel:SetSize(pw - 60, ph - 380)

    customPanel.Paint = function(self, w, h)
        if RE4M_CLIENT.CurrentTheme ~= "custom" then
            self:SetVisible(false)
            return
        end
        self:SetVisible(true)
        draw.RoundedBox(6, 0, 0, w, h, Color(20, 10, 10, 200))
        draw.SimpleText("Custom NPC Classes", "RE4M_Small", w/2, 5,
            Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end

    -- Text entry for adding NPC classes
    local npcEntry = vgui.Create("DTextEntry", customPanel)
    npcEntry:SetPos(10, 25)
    npcEntry:SetSize(customPanel:GetWide() - 120, 25)
    npcEntry:SetPlaceholderText("Enter NPC class name (e.g., npc_zombie)")
    npcEntry:SetFont("RE4M_Small")
    npcEntry.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(50, 30, 30, 220))
        self:DrawTextEntryText(Color(255, 255, 255), Color(255, 100, 100), Color(255, 255, 255))
    end

    local addBtn = vgui.Create("DButton", customPanel)
    addBtn:SetPos(customPanel:GetWide() - 100, 25)
    addBtn:SetSize(90, 25)
    addBtn:SetText("Add NPC")
    addBtn:SetFont("RE4M_Small")
    addBtn:SetTextColor(Color(255, 255, 255))
    addBtn.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and Color(50, 150, 50, 220) or Color(40, 100, 40, 200))
    end

    -- Simple list of added NPCs
    local npcList = vgui.Create("DListView", customPanel)
    npcList:SetPos(10, 55)
    npcList:SetSize(customPanel:GetWide() - 20, customPanel:GetTall() - 65)
    npcList:AddColumn("Class Name"):SetWidth(300)
    npcList:AddColumn("Type"):SetWidth(100)
    npcList.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(20, 10, 10, 200))
    end

    local customRegular = {}
    local customElite = {}

    addBtn.DoClick = function()
        local class = npcEntry:GetValue()
        if class and class ~= "" then
            table.insert(customRegular, class)
            npcList:AddLine(class, "Regular")
            npcEntry:SetValue("")

            -- Send to server
            net.Start("RE4M_SetCustomNPCs")
                net.WriteUInt(#customRegular, 8)
                for _, c in ipairs(customRegular) do
                    net.WriteString(c)
                end
                net.WriteUInt(#customElite, 8)
                for _, c in ipairs(customElite) do
                    net.WriteString(c)
                end
            net.SendToServer()
        end
    end
end
