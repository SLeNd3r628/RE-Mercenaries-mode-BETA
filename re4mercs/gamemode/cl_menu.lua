-- RE4 Mercenaries BETA - Main Menu (Client)

local MainMenuFrame = nil
local currentTab = "loadout"

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

    MainMenuFrame = vgui.Create("DFrame")
    MainMenuFrame:SetSize(sw, sh)
    MainMenuFrame:SetPos(0, 0)
    MainMenuFrame:SetTitle("")
    MainMenuFrame:SetDraggable(false)
    MainMenuFrame:ShowCloseButton(false)
    MainMenuFrame:MakePopup()

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

    local contentPanel = vgui.Create("DPanel", MainMenuFrame)
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
        { id = "loadout",     label = "LOADOUT" },
        { id = "playermodel", label = "PLAYER MODEL" },
        { id = "theme",       label = "MAP THEME" },
    }

    for i, tab in ipairs(tabs) do
        local tabBtn = vgui.Create("DButton", tabBar)
        tabBtn:SetPos((i - 1) * 205, 0)
        tabBtn:SetSize(200, 28)
        tabBtn:SetText(tab.label)
        tabBtn:SetFont("RE4M_Small")
        tabBtn:SetTextColor(Color(255, 255, 255))

        tabBtn.Paint = function(self, w, h)
            local bg = currentTab == tab.id
                and Color(180, 40, 40, 220)
                or  Color(60, 30, 30, 180)

            if self:IsHovered() and currentTab ~= tab.id then
                bg = Color(120, 40, 40, 200)
            end
            draw.RoundedBoxEx(6, 0, 0, w, h, bg, true, true, false, false)
        end

        tabBtn.DoClick = function()
            if tab.id == "theme" and not LocalPlayer():RE4M_IsAdmin() then return end
            currentTab = tab.id
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
    end

    readyBtn.DoClick = function()
        local newReady = not LocalPlayer():RE4M_GetReady()
        net.Start("RE4M_PlayerReady")
            net.WriteBool(newReady)
        net.SendToServer()
    end

    readyBtn.Think = function(self)
        if IsValid(LocalPlayer()) and LocalPlayer():RE4M_GetReady() then
            self:SetText("✓ READY")
        else
            self:SetText("READY")
        end
    end

    if LocalPlayer():RE4M_IsAdmin() then
        local startBtn = vgui.Create("DButton", bottomPanel)
        startBtn:SetSize(280, 50)
        startBtn:SetPos(sw * 0.9 - 280, 10)
        startBtn:SetText("START GAME")
        startBtn:SetFont("RE4M_MenuButton")
        startBtn:SetTextColor(Color(255, 255, 255))

        startBtn.Paint = function(self, w, h)
            local bg = self:IsHovered()
                and Color(220, 60, 60, 240)
                or  Color(180, 40, 40, 220)
            draw.RoundedBox(8, 0, 0, w, h, bg)
            surface.SetDrawColor(255, 100, 100, 100)
            surface.DrawOutlinedRect(0, 0, w, h, 2)
        end

        startBtn.DoClick = function()
            net.Start("RE4M_StartGame")
            net.SendToServer()
        end
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
            local text  = icon .. ply:Nick()

            draw.SimpleText(text, "RE4M_Small", x, h / 2, col,
                TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            surface.SetFont("RE4M_Small")
            local tw, _ = surface.GetTextSize(text)
            x = x + tw + 20
            if x > w - 20 then break end
        end
    end

    RE4M_RefreshMenuContent(contentPanel)
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
    elseif currentTab == "theme" then
        RE4M_CreateThemePanel(parent)
    end
end

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

        for _, wep in ipairs(RE4M_CLIENT.WeaponList) do
            local matchSearch = search == ""
                or string.find(string.lower(wep.name  or ""), search, 1, true)
                or string.find(string.lower(wep.class or ""), search, 1, true)

            local matchCategory = category == "All Categories"
                or wep.category == category

            if matchSearch and matchCategory then
                local line = weaponList:AddLine(wep.name, wep.category, wep.class)
                line.WeaponData = wep
            end
        end
    end

    PopulateWeapons()
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
        wepPreview = vgui.Create("DModelPanel", loadoutPanel)
        wepPreview:SetPos(10, previewY + 16)
        wepPreview:SetSize(loadoutPanel:GetWide() - 20, previewHeight - 20)
        wepPreview:SetFOV(60)
        wepPreview.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, Color(20, 10, 10, 220))
        end
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
                local mn, mx = ent:GetRenderBounds()
                local center = (mn + mx) / 2
                local size   = (mx - mn):Length()
                wepPreview:SetCamPos(Vector(size * 0.5, size * 0.3, size * 0.2))
                wepPreview:SetLookAt(center)
            end
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

    local mdlPanel = vgui.Create("DModelPanel", previewPanel)
    mdlPanel:SetPos(5, 25)
    mdlPanel:SetSize(previewPanel:GetWide() - 10, previewPanel:GetTall() - 100)
    mdlPanel:SetFOV(36)
    mdlPanel:SetAnimated(true)
    mdlPanel:SetDirectionalLight(BOX_TOP,   Color(255, 255, 255))
    mdlPanel:SetDirectionalLight(BOX_FRONT, Color(220, 220, 220))
    mdlPanel:SetAmbientLight(Color(90, 90, 90))

    mdlPanel.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(15, 8, 8, 240))
    end

    -- Drag-to-rotate + auto-rotate
    local lastDragTime = 0

    mdlPanel.DragMousePress = function(self)
        self.PressX  = gui.MousePos()
        self.Pressed = true
        lastDragTime = CurTime()
    end

    mdlPanel.DragMouseRelease = function(self)
        self.Pressed = false
        lastDragTime = CurTime()
    end

    mdlPanel.LayoutEntity = function(self, ent)
        if self.bAnimated then self:RunAnimation() end

        if self.Pressed then
            local mx = gui.MousePos()
            local diffX = mx - (self.PressX or mx)
            self.PressX = mx
            ent:SetAngles(Angle(0, ent:GetAngles().y + diffX * 0.5, 0))
            lastDragTime = CurTime()
        elseif CurTime() - lastDragTime > 2 then
            ent:SetAngles(Angle(0, ent:GetAngles().y + FrameTime() * 15, 0))
        end
    end

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

        -- ===== TFA-VOX VOICE PACK (clickable list) =====
        local voiceSets = nil
        if TFA_VOX and TFA_VOX.VoiceSets then
            voiceSets = TFA_VOX.VoiceSets
        elseif istable(TFA) and TFA.VOX and TFA.VOX.VoiceSets then
            voiceSets = TFA.VOX.VoiceSets
        end

        if voiceSets then
            local voxHeaderPanel = vgui.Create("DPanel", controlsScroll)
            voxHeaderPanel:SetSize(ctrlWidth, 20)
            voxHeaderPanel:Dock(TOP)
            voxHeaderPanel:DockMargin(0, 10, 0, 0)
            voxHeaderPanel.Paint = function(self, w, h)
                draw.SimpleText("TFA-VOX VOICE PACK", "RE4M_Tiny", 5, 2,
                    Color(255, 200, 200, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end

            -- Build sorted list of voice set names
            local voxNames = {"Default"}
            for name, _ in SortedPairs(voiceSets) do
                table.insert(voxNames, name)
            end

            -- Determine current selection
            local currentVox = GetConVar("tfa_vox_voice") and GetConVar("tfa_vox_voice"):GetString() or "Default"
            local selectedVox = currentVox

            -- Calculate height: each row is 28px, cap at 6 visible rows
            local visibleRows = math.min(#voxNames, 6)
            local listHeight = visibleRows * 28

            local voxScrollPanel = vgui.Create("DScrollPanel", controlsScroll)
            voxScrollPanel:SetSize(ctrlWidth, listHeight)
            voxScrollPanel:Dock(TOP)
            voxScrollPanel:DockMargin(0, 2, 0, 0)

            do
                local vsbar = voxScrollPanel:GetVBar()
                vsbar:SetWide(6)
                vsbar.Paint         = function(s, w, h) draw.RoundedBox(3, 0, 0, w, h, Color(30, 15, 15, 200)) end
                vsbar.btnGrip.Paint = function(s, w, h) draw.RoundedBox(3, 0, 0, w, h, Color(180, 60, 60, 200)) end
                vsbar.btnUp.Paint   = function() end
                vsbar.btnDown.Paint = function() end
            end

            local voxButtons = {}

            for _, voxName in ipairs(voxNames) do
                local voxBtn = vgui.Create("DButton", voxScrollPanel)
                voxBtn:SetSize(ctrlWidth - 8, 26)
                voxBtn:Dock(TOP)
                voxBtn:DockMargin(2, 1, 2, 1)
                voxBtn:SetText(voxName)
                voxBtn:SetFont("RE4M_Tiny")
                voxBtn:SetTextColor(Color(255, 255, 255))

                voxBtn.VoxName = voxName
                table.insert(voxButtons, voxBtn)

                voxBtn.Paint = function(self, w, h)
                    local isSelected = (selectedVox == self.VoxName)
                        or (self.VoxName == "Default" and (selectedVox == "" or selectedVox == "default"))
                    local bg

                    if isSelected then
                        bg = Color(180, 40, 40, 220)
                    elseif self:IsHovered() then
                        bg = Color(100, 40, 40, 180)
                    else
                        bg = Color(40, 20, 20, 160)
                    end

                    draw.RoundedBox(4, 0, 0, w, h, bg)

                    if isSelected then
                        surface.SetDrawColor(255, 60, 60, 120)
                        surface.DrawOutlinedRect(0, 0, w, h, 1)
                    end
                end

                voxBtn.DoClick = function(self)
                    selectedVox = self.VoxName
                    if self.VoxName == "Default" then
                        RunConsoleCommand("tfa_vox_voice", "")
                    else
                        RunConsoleCommand("tfa_vox_voice", self.VoxName)
                    end
                    surface.PlaySound("ui/btn_click.wav")
                end
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

            local mn, mx = ent:GetRenderBounds()
            if mn and mx then
                local center = (mn + mx) * 0.5
                local height = math.max(mx.z - mn.z, 10)
                local dist   = height * 0.85
                mdlPanel:SetCamPos(Vector(dist, 0, center.z))
                mdlPanel:SetLookAt(Vector(0, 0, center.z))
            end

            local idleSeqs = {
                "idle_all_01", "idle01", "idle_subtle",
                "idle_relaxed", "idle_angry", "menu_gman",
                "idle", "reference",
            }
            for _, seqName in ipairs(idleSeqs) do
                local seq = ent:LookupSequence(seqName)
                if seq and seq > 0 then
                    ent:ResetSequence(seq)
                    break
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