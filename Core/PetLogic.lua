-------------------------------------------------
-- PetStatusAlert pet detection logic
-------------------------------------------------

local ADDON_NAME, PSA = ...
PSA = PSA or _G.PetStatusAlert

local InitDB = PSA.InitDB
local HideStatus = PSA.HideStatus
local ShowStatus = PSA.ShowStatus

local SPEC_HUNTER_MARKSMANSHIP = 254
local SPEC_DEATHKNIGHT_UNHOLY = 252
local SPEC_MAGE_FROST = 64
local SPEC_WARLOCK_AFFLICTION = 265
local SPEC_WARLOCK_DESTRUCTION = 267
local SPELL_SUMMON_WATER_ELEMENTAL = 31687

-- Retail talent-definition IDs supplied by the user.
-- Do not use spellID fallback here: spell queries can be unsafe or unstable in combat.
local WARLOCK_GRIMOIRE_OF_SACRIFICE_TALENTS = {
    [SPEC_WARLOCK_AFFLICTION] = {
        [124691] = true,
    },
    [SPEC_WARLOCK_DESTRUCTION] = {
        [125618] = true,
    },
}

local grimoireOfSacrificeCache = {
    specId = 0,
    value = false,
    valid = false,
}

local supportsPetStatusCache = {
    classFile = nil,
    specId = 0,
    value = false,
    valid = false,
}

local function ClearPetStatusCaches()
    grimoireOfSacrificeCache.specId = 0
    grimoireOfSacrificeCache.value = false
    grimoireOfSacrificeCache.valid = false

    supportsPetStatusCache.classFile = nil
    supportsPetStatusCache.specId = 0
    supportsPetStatusCache.value = false
    supportsPetStatusCache.valid = false
end

-------------------------------------------------
-- Pet logic
-------------------------------------------------

local function GetPlayerSpecId()
    if type(GetSpecialization) ~= "function" or type(GetSpecializationInfo) ~= "function" then
        return 0
    end

    local specIndex = GetSpecialization()
    if not specIndex or specIndex <= 0 then
        return 0
    end

    local specId = select(1, GetSpecializationInfo(specIndex))
    return tonumber(specId) or 0
end

local function IsKnownPlayerSpell(spellID)
    spellID = tonumber(spellID)
    if not spellID then
        return false
    end

    if C_SpellBook and type(C_SpellBook.IsSpellKnown) == "function" then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, spellID)
        if ok and known ~= nil then
            return known and true or false
        end
    end

    if type(IsPlayerSpell) == "function" then
        local ok, known = pcall(IsPlayerSpell, spellID)
        if ok and known ~= nil then
            return known and true or false
        end
    end

    if type(IsSpellKnown) == "function" then
        local ok, known = pcall(IsSpellKnown, spellID)
        if ok and known ~= nil then
            return known and true or false
        end
    end

    return false
end

local function TraitValueMatches(value, matchIDs)
    value = tonumber(value)
    return value ~= nil and matchIDs[value] == true
end

local function TraitRecordMatches(record, matchIDs)
    if type(record) == "number" then
        return TraitValueMatches(record, matchIDs)
    end

    if type(record) ~= "table" then
        return false
    end

    if TraitValueMatches(record.ID, matchIDs)
        or TraitValueMatches(record.id, matchIDs)
        or TraitValueMatches(record.nodeID, matchIDs)
        or TraitValueMatches(record.entryID, matchIDs)
        or TraitValueMatches(record.definitionID, matchIDs)
    then
        return true
    end

    local definitionID = tonumber(record.definitionID)
    if definitionID and C_Traits and type(C_Traits.GetDefinitionInfo) == "function" then
        local okDefinition, definitionInfo = pcall(C_Traits.GetDefinitionInfo, definitionID)
        if okDefinition and type(definitionInfo) == "table" then
            if TraitValueMatches(definitionInfo.ID, matchIDs)
                or TraitValueMatches(definitionInfo.id, matchIDs)
                or TraitValueMatches(definitionInfo.definitionID, matchIDs)
            then
                return true
            end
        end
    end

    return false
end

local function GetTraitEntryInfo(configID, entryID)
    if not C_Traits or type(C_Traits.GetEntryInfo) ~= "function" then
        return nil
    end

    local okEntry, entryInfo = pcall(C_Traits.GetEntryInfo, configID, entryID)
    if okEntry and entryInfo then
        return entryInfo
    end

    okEntry, entryInfo = pcall(C_Traits.GetEntryInfo, entryID)
    if okEntry and entryInfo then
        return entryInfo
    end

    return nil
end

local function ActiveTraitEntryMatches(configID, entry, matchIDs)
    if TraitRecordMatches(entry, matchIDs) then
        return true
    end

    local entryID
    if type(entry) == "number" then
        entryID = entry
    elseif type(entry) == "table" then
        entryID = entry.entryID or entry.ID or entry.id
    end

    if not entryID then
        return false
    end

    if TraitValueMatches(entryID, matchIDs) then
        return true
    end

    return TraitRecordMatches(GetTraitEntryInfo(configID, entryID), matchIDs)
end

local function ActiveTalentNodeMatches(configID, nodeInfo, matchIDs)
    if type(nodeInfo) ~= "table" then
        return false
    end

    local currentRank = tonumber(nodeInfo.currentRank or nodeInfo.ranksPurchased or nodeInfo.activeRank) or 0
    if currentRank <= 0 then
        return false
    end

    if TraitRecordMatches(nodeInfo, matchIDs) then
        return true
    end

    if nodeInfo.activeEntry ~= nil and ActiveTraitEntryMatches(configID, nodeInfo.activeEntry, matchIDs) then
        return true
    end

    if nodeInfo.activeEntryID ~= nil and ActiveTraitEntryMatches(configID, nodeInfo.activeEntryID, matchIDs) then
        return true
    end

    if type(nodeInfo.entryIDsWithCommittedRanks) == "table" then
        for _, entryID in pairs(nodeInfo.entryIDsWithCommittedRanks) do
            if ActiveTraitEntryMatches(configID, entryID, matchIDs) then
                return true
            end
        end
    end

    -- Some clients only expose entryIDs for a ranked node. Only use this fallback
    -- when there is a single entry, so choice nodes do not false-positive.
    if type(nodeInfo.entryIDs) == "table" and #nodeInfo.entryIDs == 1 then
        return ActiveTraitEntryMatches(configID, nodeInfo.entryIDs[1], matchIDs)
    end

    return false
end

local function GetActiveTalentConfigID(specId)
    if not C_ClassTalents then
        return nil
    end

    if type(C_ClassTalents.GetActiveConfigID) == "function" then
        local okConfigID, configID = pcall(C_ClassTalents.GetActiveConfigID)
        if okConfigID and configID then
            return configID
        end
    end

    -- Fallback for clients/login timing where active config is not ready yet.
    if specId and type(C_ClassTalents.GetLastSelectedSavedConfigID) == "function" then
        local okSavedConfigID, savedConfigID = pcall(C_ClassTalents.GetLastSelectedSavedConfigID, specId)
        if okSavedConfigID and savedConfigID then
            return savedConfigID
        end
    end

    return nil
end

local function AddTreeID(treeIDs, seen, treeID)
    treeID = tonumber(treeID)
    if treeID and not seen[treeID] then
        seen[treeID] = true
        treeIDs[#treeIDs + 1] = treeID
    end
end

local function GetConfigTreeIDs(configID)
    local treeIDs = {}
    local seen = {}

    local okConfigInfo, configInfo = pcall(C_Traits.GetConfigInfo, configID)
    if not okConfigInfo or type(configInfo) ~= "table" then
        return treeIDs
    end

    -- Retail returns treeIDs (array). Older/test clients may expose treeID.
    if type(configInfo.treeIDs) == "table" then
        for _, treeID in pairs(configInfo.treeIDs) do
            AddTreeID(treeIDs, seen, treeID)
        end
    end

    AddTreeID(treeIDs, seen, configInfo.treeID)

    return treeIDs
end

local function IsTalentActiveByAnyKnownID(matchIDs, specId)
    if not C_ClassTalents then
        return false
    end
    if not C_Traits or type(C_Traits.GetConfigInfo) ~= "function" or type(C_Traits.GetTreeNodes) ~= "function" or type(C_Traits.GetNodeInfo) ~= "function" then
        return false
    end

    local configID = GetActiveTalentConfigID(specId)
    if not configID then
        return false
    end

    local treeIDs = GetConfigTreeIDs(configID)
    if #treeIDs <= 0 then
        return false
    end

    for _, treeID in pairs(treeIDs) do
        local okNodes, nodeIDs = pcall(C_Traits.GetTreeNodes, treeID)
        if okNodes and type(nodeIDs) == "table" then
            for _, nodeID in pairs(nodeIDs) do
                local okNode, nodeInfo = pcall(C_Traits.GetNodeInfo, configID, nodeID)
                if okNode and ActiveTalentNodeMatches(configID, nodeInfo, matchIDs) then
                    return true
                end
            end
        end
    end

    return false
end

local function IsWarlockGrimoireOfSacrificeActive()
    local _, classFile = UnitClass("player")
    if classFile ~= "WARLOCK" then
        return false
    end

    local specId = GetPlayerSpecId()
    local matchIDs = WARLOCK_GRIMOIRE_OF_SACRIFICE_TALENTS[specId]
    if not matchIDs then
        return false
    end

    -- Talent data cannot change without spec/talent events. Cache until those events
    -- invalidate it instead of scanning all trait nodes on every pet/aura refresh.
    if grimoireOfSacrificeCache.valid and grimoireOfSacrificeCache.specId == specId then
        return grimoireOfSacrificeCache.value
    end

    local active = IsTalentActiveByAnyKnownID(matchIDs, specId)

    grimoireOfSacrificeCache.specId = specId
    grimoireOfSacrificeCache.value = active and true or false
    grimoireOfSacrificeCache.valid = true

    return grimoireOfSacrificeCache.value
end

local function SupportsPetStatusPrompt()
    local _, classFile = UnitClass("player")
    local specId = GetPlayerSpecId()

    if supportsPetStatusCache.valid
        and supportsPetStatusCache.classFile == classFile
        and supportsPetStatusCache.specId == specId
    then
        return supportsPetStatusCache.value
    end

    local supports = false

    if classFile == "HUNTER" then
        supports = specId ~= SPEC_HUNTER_MARKSMANSHIP
    elseif classFile == "WARLOCK" then
        supports = true
    elseif classFile == "MAGE" then
        supports = specId == SPEC_MAGE_FROST and IsKnownPlayerSpell(SPELL_SUMMON_WATER_ELEMENTAL)
    elseif classFile == "DEATHKNIGHT" then
        supports = specId == SPEC_DEATHKNIGHT_UNHOLY
    end

    supportsPetStatusCache.classFile = classFile
    supportsPetStatusCache.specId = specId
    supportsPetStatusCache.value = supports and true or false
    supportsPetStatusCache.valid = true

    return supportsPetStatusCache.value
end

local function IsPlayerMountedOrInVehicle()
    if type(IsMounted) == "function" and IsMounted() then
        return true
    end
    if type(UnitInVehicle) == "function" and UnitInVehicle("player") then
        return true
    end
    if type(UnitHasVehicleUI) == "function" and UnitHasVehicleUI("player") then
        return true
    end
    local hasVehicleActionBar = _G["HasVehicleActionBar"]
    if type(hasVehicleActionBar) == "function" and hasVehicleActionBar() then
        return true
    end

    return false
end

local function GetPetMode()
    if not UnitExists("pet") then
        return nil
    end

    if type(GetPetActionInfo) ~= "function" then
        return "UNKNOWN"
    end

    local hasPetControl = false
    if type(PetHasActionBar) == "function" and PetHasActionBar() then
        hasPetControl = true
    end
    if type(HasPetUI) == "function" and HasPetUI() then
        hasPetControl = true
    end
    local hasPetSpells = _G["HasPetSpells"]
    if type(hasPetSpells) == "function" and hasPetSpells() then
        hasPetControl = true
    end

    local sawAnyPetModeButton = false
    local slotCount = tonumber(NUM_PET_ACTION_SLOTS) or 10

    for i = 1, slotCount do
        local okAction, name, _, isToken, isActive = pcall(GetPetActionInfo, i)
        if not okAction then
            name = nil
            isToken = nil
            isActive = nil
        end
        if name then
            sawAnyPetModeButton = true
        end

        if name and isActive then
            local tokenName = isToken and name or nil
            local readable = isToken and (_G[name] or name) or name

            if tokenName == "PET_MODE_ASSIST" or readable == PET_MODE_ASSIST then
                return "ASSIST"
            end

            if tokenName == "PET_MODE_PASSIVE" or readable == PET_MODE_PASSIVE then
                return "PASSIVE"
            end
        end
    end

    if sawAnyPetModeButton or hasPetControl then
        return "DEFENSIVE"
    end

    return "UNKNOWN"
end

local function GetPetModeStatusKey(mode)
    if mode == "PASSIVE" then
        return "PASSIVE"
    end
    if mode == "DEFENSIVE" then
        return "DEFENSIVE"
    end
    return "UNKNOWN"
end

local function RefreshPetStatusText()
    InitDB()

    local okSupports, supports = pcall(SupportsPetStatusPrompt)
    if not okSupports or not supports then
        HideStatus()
        return
    end

    local okMounted, mounted = pcall(IsPlayerMountedOrInVehicle)
    if not okMounted or mounted then
        HideStatus()
        return
    end

    local okPetExists, petExists = pcall(UnitExists, "pet")
    if not okPetExists then
        HideStatus()
        return
    end

    if not petExists then
        -- Grimoire of Sacrifice only suppresses the missing-pet warning.
        -- If a real pet exists, Warlocks must still be checked for Passive/Defensive/Dead states.
        local okSacrifice, hasSacrificeTalent = pcall(IsWarlockGrimoireOfSacrificeActive)
        if okSacrifice and hasSacrificeTalent then
            HideStatus()
            return
        end

        ShowStatus("NO_PET")
        return
    end

    local okPetDead, petDead = pcall(UnitIsDeadOrGhost, "pet")
    if not okPetDead then
        HideStatus()
        return
    end

    if petDead then
        ShowStatus("PET_DEAD")
        return
    end

    local okMode, mode = pcall(GetPetMode)
    if not okMode then
        HideStatus()
        return
    end

    if mode == "ASSIST" then
        HideStatus()
        return
    end

    if mode == "UNKNOWN" then
        -- Destruction/Affliction Warlocks with Grimoire of Sacrifice can intentionally
        -- play without a controllable demon. In that case, do not show the generic
        -- "status could not be identified" warning. Real pets are still checked above
        -- for dead/passive/defensive states when those states can be identified.
        local okSacrifice, hasSacrificeTalent = pcall(IsWarlockGrimoireOfSacrificeActive)
        if okSacrifice and hasSacrificeTalent then
            HideStatus()
            return
        end
    end

    ShowStatus(GetPetModeStatusKey(mode))
end

local queuedRefreshTimers = {}

local function QueueRefresh(delaySeconds)
    delaySeconds = tonumber(delaySeconds) or 0.05
    if delaySeconds < 0 then
        delaySeconds = 0
    end

    local key = string.format("%.2f", delaySeconds)
    if queuedRefreshTimers[key] then
        return
    end
    queuedRefreshTimers[key] = true

    if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
        C_Timer.After(delaySeconds, function()
            queuedRefreshTimers[key] = nil
            RefreshPetStatusText()
        end)
    else
        queuedRefreshTimers[key] = nil
        RefreshPetStatusText()
    end
end


-------------------------------------------------
-- Public pet logic API
-------------------------------------------------

PSA.ClearPetStatusCaches = ClearPetStatusCaches
PSA.GetPlayerSpecId = GetPlayerSpecId
PSA.IsKnownPlayerSpell = IsKnownPlayerSpell
PSA.IsWarlockGrimoireOfSacrificeActive = IsWarlockGrimoireOfSacrificeActive
PSA.SupportsPetStatusPrompt = SupportsPetStatusPrompt
PSA.IsPlayerMountedOrInVehicle = IsPlayerMountedOrInVehicle
PSA.GetPetMode = GetPetMode
PSA.RefreshPetStatusText = RefreshPetStatusText
PSA.QueueRefresh = QueueRefresh
