-- Native bridge between the player model selector and TFA-VOX.
-- Store only target -> source model paths; TFA-VOX owns the actual voice data.

local DATA_DIRECTORY = "re4mercs"
local DATA_FILE = DATA_DIRECTORY .. "/tfa_vox_assignments.json"
local assignments = {}

local function FindRegisteredPack(modelPath)
    if not istable(TFAVOX_Models) or not isstring(modelPath) then return end

    if istable(TFAVOX_Models[modelPath]) then
        return modelPath, TFAVOX_Models[modelPath]
    end

    local normalized = string.lower(modelPath)
    for registeredPath, pack in pairs(TFAVOX_Models) do
        if isstring(registeredPath) and string.lower(registeredPath) == normalized and istable(pack) then
            return registeredPath, pack
        end
    end
end

local function SaveAssignments()
    if not file.Exists(DATA_DIRECTORY, "DATA") then
        file.CreateDir(DATA_DIRECTORY)
    end

    file.Write(DATA_FILE, util.TableToJSON(assignments, true) or "{}")
end

local function ApplyAssignment(targetModel, sourceModel)
    if not istable(TFAVOX_Models) then return false end
    if not isstring(targetModel) or not string.StartWith(string.lower(targetModel), "models/") then return false end
    if not util.IsValidModel(targetModel) then return false end

    local registeredPath, pack = FindRegisteredPack(sourceModel)
    if not registeredPath or not pack then return false end

    TFAVOX_Models[targetModel] = pack
    assignments[targetModel] = registeredPath
    return true
end

local function SendAssignment(targetModel, sourceModel, recipient)
    net.Start("RE4M_AssignTFA_VOX")
        net.WriteString(targetModel)
        net.WriteString(sourceModel)
    if IsValid(recipient) then
        net.Send(recipient)
    else
        net.Broadcast()
    end
end

local function LoadAssignments()
    if file.Exists(DATA_FILE, "DATA") then
        local decoded = util.JSONToTable(file.Read(DATA_FILE, "DATA") or "")
        if istable(decoded) then assignments = decoded end
    end

    if not istable(TFAVOX_Models) then return end
    for targetModel, sourceModel in pairs(assignments) do
        if ApplyAssignment(targetModel, sourceModel) then
            SendAssignment(targetModel, assignments[targetModel])
        end
    end
end

-- TFA-VOX loads its pack files during Initialize. Apply saved mappings after
-- those registrations exist, then mirror each mapping to connected clients.
hook.Add("InitPostEntity", "RE4M_TFA_VOX_LoadAssignments", function()
    timer.Simple(0, LoadAssignments)
end)

hook.Add("PlayerInitialSpawn", "RE4M_TFA_VOX_SyncAssignments", function(ply)
    timer.Simple(2, function()
        if not IsValid(ply) then return end
        for targetModel, sourceModel in pairs(assignments) do
            SendAssignment(targetModel, sourceModel, ply)
        end
    end)
end)

net.Receive("RE4M_AssignTFA_VOX", function(_, ply)
    if not IsValid(ply) or not ply.RE4M_IsAdmin or not ply:RE4M_IsAdmin() then return end

    local targetModel = net.ReadString()
    local sourceModel = net.ReadString()
    if #targetModel > 260 or #sourceModel > 260 then return end

    if not ApplyAssignment(targetModel, sourceModel) then
        if RE4MERCS_CONFIG and RE4MERCS_CONFIG.Debug then
            print("[RE4 Mercs] Rejected TFA-VOX assignment:", targetModel, sourceModel)
        end
        return
    end

    SaveAssignments()
    SendAssignment(targetModel, assignments[targetModel])
    print("[RE4 Mercs] Assigned TFA-VOX pack " .. assignments[targetModel] .. " to " .. targetModel)
end)
