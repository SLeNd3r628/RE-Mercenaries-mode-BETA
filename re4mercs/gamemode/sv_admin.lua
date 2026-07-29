-- RE4 Mercenaries Remake - Admin Controls (Server)

-- Handle admin panel commands
net.Receive("RE4M_AdminPanel", function(len, ply)
    if not IsValid(ply) then return end
    if not ply:RE4M_IsAdmin() then return end

    local command = net.ReadString()

    if command == "start" then
        if RE4M_STATE.GameState == GAMESTATE_MENU or RE4M_STATE.GameState == GAMESTATE_WAITING then
            RE4M_StartPreRound()
        end

    elseif command == "stop" then
        RE4M_EndRound()

    elseif command == "restart" then
        RE4M_EndRound()
        timer.Simple(2, function()
            RE4M_StartPreRound()
        end)

    elseif command == "cleanup" then
        RE4M_CleanupNPCs()
        RE4M_CleanupPickups()

    elseif command == "add_time" then
        local seconds = net.ReadFloat()
        if RE4M_STATE.GameState == GAMESTATE_ACTIVE then
            RE4M_ExtendTime(seconds)
        end

    elseif command == "set_max_npcs" then
        local max = net.ReadUInt(16)
        RE4MERCS_CONFIG.BaseMaxNPCs = max

    elseif command == "rebuild_weapons" then
        RE4M_BuildWeaponList()
        for _, p in ipairs(player.GetAll()) do
            RE4M_SendWeaponList(p)
        end
    end
end)

-- Chat commands
hook.Add("PlayerSay", "RE4M_ChatCommands", function(ply, text, teamChat)
    text = string.lower(string.Trim(text))

    if text == "!start" or text == "/start" then
        if ply:RE4M_IsAdmin() then
            if RE4M_STATE.GameState == GAMESTATE_MENU or RE4M_STATE.GameState == GAMESTATE_WAITING then
                RE4M_StartPreRound()
                return ""
            end
        end

    elseif text == "!stop" or text == "/stop" then
        if ply:RE4M_IsAdmin() then
            RE4M_EndRound()
            return ""
        end

    elseif text == "!menu" or text == "/menu" then
        if RE4M_STATE.GameState == GAMESTATE_MENU or RE4M_STATE.GameState == GAMESTATE_WAITING then
            net.Start("RE4M_ForceMenu")
            net.Send(ply)
            return ""
        end

    elseif text == "!ready" or text == "/ready" then
        ply.RE4M_Ready = not ply.RE4M_Ready
        ply:SetNWBool("RE4M_Ready", ply.RE4M_Ready)
        ply:ChatPrint("[RE4 Mercs] You are " .. (ply.RE4M_Ready and "READY" or "NOT READY"))
        return ""

    elseif string.StartWith(text, "!theme ") or string.StartWith(text, "/theme ") then
        if ply:RE4M_IsAdmin() then
            local theme = string.sub(text, 8)
            RE4M_STATE.CurrentTheme = string.Trim(theme)
            net.Start("RE4M_ThemeInfo")
                net.WriteString(RE4M_STATE.CurrentTheme)
            net.Broadcast()
            ply:ChatPrint("[RE4 Mercs] Theme set to: " .. RE4M_STATE.CurrentTheme)
            return ""
        end
    end
end)