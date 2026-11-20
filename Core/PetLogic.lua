-------------------------------------------------
-- PetStatusAlert pet detection logic
-------------------------------------------------

local _, PSA = ...
PSA = PSA or _G.PetStatusAlert

local InitDB = PSA.InitDB
local HideStatus = PSA.HideStatus
local ShowStatus = PSA.ShowStatus
local GetPlayerSpecId = PSA.GetPlayerSpecId

local SPEC_HUNTER_MARKSMANSHIP = 254
local SPEC_DEATHKNIGHT_UNHOLY = 252
local SPEC_MAGE_FROST = 64
local WRONG_PET = PSA.WRONG_PET_STATUS_KEY
local PET_MODE_TOKENS = {
    { "PET_MODE_ASSIST", "ASSIST" },
    { "PET_MODE_DEFENSIVE", "DEFENSIVE" },
    { "PET_MODE_DEFENSIVEASSIST", "DEFENSIVE" },
    { "PET_MODE_PASSIVE", "PASSIVE" },
    { "PET_MODE_AGGRESSIVE", "AGGRESSIVE" },
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

-- Learned spells only gain ranks during a session; a "true" answer can be cached
-- until the spellbook changes. "false" is never cached so a login-time spellbook
-- that is still loading cannot disable pet alerts until the next reload.
local knownSpellCache = {}
local petModeValid, petModeValue

local function ClearPetStatusCaches()
    grimoireOfSacrificeCache.specId = 0
    grimoireOfSacrificeCache.value = false
    grimoireOfSacrificeCache.valid = false

    supportsPetStatusCache.classFile = nil
    supportsPetStatusCache.specId = 0
    supportsPetStatusCache.value = false
    supportsPetStatusCache.valid = false

    knownSpellCache = {}
    petModeValid = false
end

-------------------------------------------------
-- Pet logic
-------------------------------------------------

local function IsKnownPlayerSpell(spellID)
    spellID = tonumber(spellID)
    if not spellID then
        return false
    end

    -- Hot path: RefreshPetCare and the aspect recommendation both query the
    -- same handful of spell IDs several times per second.
    if knownSpellCache[spellID] then
        return true
    end

    if C_SpellBook and type(C_SpellBook.IsSpellKnown) == "function" then
        local known = C_SpellBook.IsSpellKnown(spellID)
        if PSA.IsAccessibleValue(known) and known ~= nil then
            if known then knownSpellCache[spellID] = true end
            return known and true or false
        end
    end

    if type(IsPlayerSpell) == "function" then
        local known = IsPlayerSpell(spellID)
        if PSA.IsAccessibleValue(known) and known ~= nil then
            if known then knownSpellCache[spellID] = true end
            return known and true or false
        end
    end

    if type(IsSpellKnown) == "function" then
        local known = IsSpellKnown(spellID)
        if PSA.IsAccessibleValue(known) and known ~= nil then
            if known then knownSpellCache[spellID] = true end
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
                or TraitValueMatches(definitionInfo.spellID, matchIDs)
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

local function IsWarlockGrimoireOfSacrificeActive(specId)
    -- Retail trait definition IDs do not describe Forever's talent system.
    if PSA.IsForeverClient() or not PSA.GetClassOption("warlockIgnoreSacrifice") then
        return false
    end
    if PSA.GetPlayerClassFile() ~= "WARLOCK" then
        return false
    end

    specId = specId or GetPlayerSpecId()
    local talentID = PSA.GetWarlockSacrificeID(specId)
    if not talentID then
        return false
    end

    -- Talent data cannot change without spec/talent events. Cache until those events
    -- invalidate it instead of scanning all trait nodes on every pet/aura refresh.
    if grimoireOfSacrificeCache.valid and grimoireOfSacrificeCache.specId == specId then
        return grimoireOfSacrificeCache.value
    end

    local active = IsTalentActiveByAnyKnownID({ [talentID] = true }, specId)

    grimoireOfSacrificeCache.specId = specId
    grimoireOfSacrificeCache.value = active and true or false
    grimoireOfSacrificeCache.valid = true

    return grimoireOfSacrificeCache.value
end

local function HasWrongWarlockPet()
    if PSA.GetPlayerClassFile() ~= "WARLOCK" or not PSA.IsStatusEnabled(WRONG_PET, "WARLOCK") then
        return false
    end
    local specID = GetPlayerSpecId()
    local blocked = PSA.GetWarlockBlockedPets(specID)
    if not blocked or not next(blocked) then
        return false
    end
    local familyID = PSA.GetActiveWarlockPetFamily()
    return familyID and blocked[familyID] == true and not IsWarlockGrimoireOfSacrificeActive(specID)
end

local function SupportsPetStatusPrompt()
    local classFile = PSA.GetPlayerClassFile()
    local specId = GetPlayerSpecId()

    if supportsPetStatusCache.valid
        and supportsPetStatusCache.classFile == classFile
        and supportsPetStatusCache.specId == specId
    then
        return supportsPetStatusCache.value
    end

    local supports = false

    if PSA.IsForeverClient() then
        supports = PSA.SupportsForeverPetClass(classFile, IsKnownPlayerSpell)
    elseif classFile == "HUNTER" then
        supports = specId ~= SPEC_HUNTER_MARKSMANSHIP
    elseif classFile == "WARLOCK" then
        supports = true
    elseif classFile == "MAGE" then
        local summonID = PSA.GetClassOption("mageSummonID")
        supports = specId == SPEC_MAGE_FROST and (not PSA.GetClassOption("mageRequireSummon")
            or IsKnownPlayerSpell(summonID) or IsTalentActiveByAnyKnownID({ [summonID] = true }, specId))
    elseif classFile == "DEATHKNIGHT" then
        supports = specId == SPEC_DEATHKNIGHT_UNHOLY
    end

    supportsPetStatusCache.classFile = classFile
    supportsPetStatusCache.specId = specId
    supportsPetStatusCache.value = supports and true or false
    supportsPetStatusCache.valid = true

    return supportsPetStatusCache.value
end

-- Mount/vehicle state does not change between pet refreshes; several events per
-- second used to call four separate vehicle APIs each time. Cache it and let the
-- event layer invalidate the value when mount or vehicle state actually changes.
local mountStateValid = false
local mountedOrInVehicle = false

local function IsPlayerMountedOrInVehicle()
    if mountStateValid then
        return mountedOrInVehicle
    end

    local mounted = false
    if type(IsMounted) == "function" then
        local value = IsMounted()
        if PSA.IsAccessibleValue(value) and value then mounted = true end
    end
    if not mounted and type(UnitInVehicle) == "function" then
        local value = UnitInVehicle("player")
        if PSA.IsAccessibleValue(value) and value then mounted = true end
    end
    if not mounted and type(UnitHasVehicleUI) == "function" then
        local value = UnitHasVehicleUI("player")
        if PSA.IsAccessibleValue(value) and value then mounted = true end
    end
    if not mounted then
        local hasVehicleActionBar = _G["HasVehicleActionBar"]
        if type(hasVehicleActionBar) == "function" then
            local value = hasVehicleActionBar()
            if PSA.IsAccessibleValue(value) and value then mounted = true end
        end
    end

    mountStateValid, mountedOrInVehicle = true, mounted
    return mounted
end

function PSA.InvalidatePlayerMountState()
    mountStateValid = false
end

local DISMOUNT_GRACE_SECONDS = 2
local wasMounted, dismountRecheck

function PSA.UpdatePetDismountGrace(reset)
    if reset then wasMounted, dismountRecheck = nil, nil end
    if type(IsMounted) ~= "function" then return end
    local mounted = IsMounted()
    if not PSA.IsAccessibleValue(mounted) then return end
    local justDismounted = wasMounted and not mounted
    wasMounted = mounted
    if mounted then
        dismountRecheck = nil
    elseif justDismounted and not InCombatLockdown() then
        local function Recheck()
            if dismountRecheck ~= Recheck then return end
            dismountRecheck = nil
            PSA.RefreshPetStatusText()
        end
        dismountRecheck = Recheck
        C_Timer.After(DISMOUNT_GRACE_SECONDS, Recheck)
    end
end

-- Pet action names are fixed for the session. Build the token/localized-name to
-- mode lookup once instead of walking five token entries for every active slot.
-- Token names win over localized names so a pet ability that happens to share a
-- translated mode name cannot be mistaken for a stance.
local petModeTokenMap, petModeLocalizedNameMap

local function GetPetModeActionMaps()
    if petModeTokenMap then
        return petModeTokenMap, petModeLocalizedNameMap
    end
    petModeTokenMap, petModeLocalizedNameMap = {}, {}
    for _, entry in ipairs(PET_MODE_TOKENS) do
        local token, mode = entry[1], entry[2]
        petModeTokenMap[token] = mode
        local localized = _G[token]
        if type(localized) == "string" and localized ~= token then
            petModeLocalizedNameMap[localized] = mode
        end
    end
    return petModeTokenMap, petModeLocalizedNameMap
end

-- GetPetActionInfo returns name, texture, isToken, isActive, autoCastAllowed,
-- autoCastEnabled, spellID, checksRange, inRange on Retail (Blizzard's own
-- Blizzard_ActionBar/Shared/PetActionBar.lua reads exactly that order), while
-- the Classic-era clients return the same prefix shifted by a subtext name.
-- The client does not guarantee Lua booleans: Retail reports isToken/isActive
-- as 1/0, so a type check for "boolean" put the active flag nowhere and every
-- stance alert stayed silent. The texture string is the only reliable layout
-- marker: the Classic layout puts it third (after subtext), Retail second.
local function IsActiveFlag(value)
    return value == true or value == 1
end

local function ReadPetActionSlot(index)
    local name, second, third, fourth, fifth = GetPetActionInfo(index)
    local isToken, isActive
    if type(second) == "boolean" then
        -- Oldest: name, isToken, isActive
        isToken, isActive = second, third
    elseif type(third) == "string" then
        -- Classic: name, subtext, texture, isToken, isActive
        isToken, isActive = fourth, fifth
    else
        -- Retail: name, texture, isToken, isActive, autoCastAllowed, ...
        -- isToken is 1/false/nil here; the texture string is the layout marker.
        isToken, isActive = third, fourth
    end

    -- Secret values cannot be indexed or compared. Drop only the unreadable
    -- field; one secret must not turn the whole stance into "unknown".
    if not PSA.IsAccessibleValue(name) then name = nil end
    if not PSA.IsAccessibleValue(isToken) then isToken = nil end
    if not PSA.IsAccessibleValue(isActive) then isActive = nil end
    return name, isToken, isActive
end

local function PickPetMode()
    local tokenMap, localizedMap = GetPetModeActionMaps()
    local slotCount = tonumber(NUM_PET_ACTION_SLOTS) or 10
    local pendingMode, pendingCount

    for i = 1, slotCount do
        local name, _, isActive = ReadPetActionSlot(i)
        if name ~= nil then
            local mode = tokenMap[name]
            if mode == nil then
                mode = localizedMap[name]
            end
            if mode ~= nil then
                if IsActiveFlag(isActive) then
                    return mode
                end
                pendingCount = (pendingCount or 0) + 1
                if pendingMode == nil then
                    pendingMode = mode
                end
            end
        end
    end

    -- One stance button is the whole switch: its name already reports the
    -- current mode, so neither a missing nor an explicit false isActive may
    -- hide it. Several stance buttons are disambiguated by isActive above; when
    -- none of them is active the stance stays unknown instead of being guessed.
    if pendingMode ~= nil and pendingCount == 1 then
        return pendingMode
    end
end

local function GetPetMode()
    if petModeValid then
        return petModeValue
    end

    if not UnitExists("pet") then
        -- The caller already checked UnitExists; do not cache this nil. A pet
        -- that appears without its UNIT_PET event reaching us would otherwise
        -- stay invisible until the next cache invalidation.
        petModeValid, petModeValue = false, nil
        return nil
    end

    if type(GetPetActionInfo) ~= "function" then
        petModeValid, petModeValue = true, "UNKNOWN"
        return "UNKNOWN"
    end

    -- The pet action bar is refreshed from Blizzard code paths, but a client
    -- build without the expected returns must not abort the whole alert
    -- refresh, so a failed scan falls back to the unknown state.
    local ok, mode = pcall(PickPetMode)
    if ok and mode ~= nil then
        petModeValid, petModeValue = true, mode
        return mode
    end

    -- An unknown stance is not cached: right after a summon or a control change
    -- the pet action bar can still be populating, and a cached "UNKNOWN" keeps
    -- every stance alert silent until the next invalidating event.
    petModeValid, petModeValue = false, nil
    return "UNKNOWN"
end

-- Pet action buttons only change on pet bar/UI updates, pet swaps and control
-- changes. Invalidate on those events instead of walking ten action slots on
-- every status refresh triggered by bag or happiness events.
function PSA.InvalidatePetMode()
    petModeValid = false
end

local function GetPetModeStatusKey(mode)
    if mode == "PASSIVE" then
        return "PASSIVE"
    end
    if mode == "DEFENSIVE" then
        return "DEFENSIVE"
    end
    if mode == "AGGRESSIVE" then
        return "AGGRESSIVE"
    end
    return "UNKNOWN"
end

local function RefreshPetStatusText()
    InitDB()
    if PSA.RefreshForeverFormAlert then return PSA.RefreshForeverFormAlert() end

    if dismountRecheck and InCombatLockdown() then dismountRecheck = nil end
    if not SupportsPetStatusPrompt() or IsPlayerMountedOrInVehicle() then
        HideStatus()
        return
    end

    if type(UnitExists) ~= "function" then
        HideStatus()
        return
    end
    local petExists = UnitExists("pet")
    if not PSA.IsAccessibleValue(petExists) then
        HideStatus()
        return
    end

    if not petExists then
        -- Sacrifice can explain the missing pet. It leaves stance and death checks active.
        if dismountRecheck or IsWarlockGrimoireOfSacrificeActive() then
            HideStatus()
            return
        end

        ShowStatus("NO_PET")
        return
    end

    local petDead = type(UnitIsDeadOrGhost) == "function" and UnitIsDeadOrGhost("pet")
    if not PSA.IsAccessibleValue(petDead) then
        HideStatus()
        return
    end

    if petDead then
        ShowStatus("PET_DEAD")
        return
    end

    if HasWrongWarlockPet() then
        ShowStatus(WRONG_PET)
        return
    end

    local mode = GetPetMode()

    if PSA.IsNormalPetMode(mode) then
        HideStatus()
        return
    end

    if mode == "UNKNOWN" then
        -- Destruction/Affliction Warlocks with Grimoire of Sacrifice can intentionally
        -- play without a controllable demon. In that case, do not show the generic
        -- "status could not be identified" warning. Real pets are still checked above
        -- for dead/passive/defensive states when those states can be identified.
        if IsWarlockGrimoireOfSacrificeActive() then
            HideStatus()
            return
        end
    end

    ShowStatus(GetPetModeStatusKey(mode))
end

local queuedRefreshTimers = {}
-- QueueRefresh is called with four fixed delays. Reuse one callback per delay
-- bucket instead of allocating a closure for every pet event.
local queuedRefreshCallbacks = {}

local function QueueRefresh(delaySeconds)
    delaySeconds = tonumber(delaySeconds) or 0.05
    if delaySeconds < 0 then
        delaySeconds = 0
    end

    -- Numeric key instead of string.format: QueueRefresh runs on every pet event
    -- and the formatted string was pure garbage on the hot path.
    local key = math.floor(delaySeconds * 100 + 0.5)
    if queuedRefreshTimers[key] then
        return
    end
    queuedRefreshTimers[key] = true

    if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
        local callback = queuedRefreshCallbacks[key]
        if not callback then
            callback = function()
                queuedRefreshTimers[key] = nil
                RefreshPetStatusText()
            end
            queuedRefreshCallbacks[key] = callback
        end
        C_Timer.After(delaySeconds, callback)
    else
        queuedRefreshTimers[key] = nil
        RefreshPetStatusText()
    end
end


-------------------------------------------------
-- Public pet logic API
-------------------------------------------------

PSA.ClearPetStatusCaches = ClearPetStatusCaches
function PSA.GetCurrentPetAlertEligibility(classFile)
    if PSA.GetPlayerClassFile() ~= classFile then return end
    local ok, eligible = pcall(SupportsPetStatusPrompt)
    if ok then return eligible end
end

function PSA.RefreshClassPetSettings(classFile)
    if PSA.GetPlayerClassFile() == classFile then
        ClearPetStatusCaches()
        RefreshPetStatusText()
    end
end
-- IsKnownPlayerSpell 供 AlertFrame 在显示图标时动态查询术士召唤技能，需保留导出。
PSA.IsKnownPlayerSpell = IsKnownPlayerSpell
-- GetPlayerSpecId / IsPlayerMountedOrInVehicle 供 WarriorLogic 复用，需保留导出。
PSA.GetPlayerSpecId = GetPlayerSpecId
PSA.IsPlayerMountedOrInVehicle = IsPlayerMountedOrInVehicle
PSA.RefreshPetStatusText = RefreshPetStatusText
PSA.QueueRefresh = QueueRefresh
