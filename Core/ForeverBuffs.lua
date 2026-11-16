local _, PSA = ...

if not PSA.IsForeverClient() or not (C_UnitAuras
    and (C_UnitAuras.GetUnitAuras or C_UnitAuras.GetAuraDataByIndex)) then return end

local CHEETAH = 5118
local PACK = 13159
local hawkRanks = {13165, 14318, 14319, 14320, 14321, 14322, 25296, 27044}
-- Forever has no Aspect of the Dragonhawk (the WotLK ranks 61846/61847 are not
-- in its spellbook). Its level-60 combat aspect is Aspect of the Falcon, which
-- gives the highest known Hawk rank's melee and ranged attack power.
local falconRanks = {469145}
local SPELLCAST_SUCCEEDED = "UNIT_SPELLCAST_SUCCEEDED"
local hunterAspects = {PACK, CHEETAH, 13163, 13161, 1299445, 1299446, 1299447, 20043, 20190}
for _, group in ipairs({ hawkRanks, {34074, 415423}, falconRanks }) do
    for _, id in ipairs(group) do hunterAspects[#hunterAspects + 1] = id end
end

-- Cheetah and Pack both daze on damage. Pack shares that risk with the whole
-- party, so it needs the same out-of-combat reminder as Cheetah.
local function IsTravelAspect(spell)
    return spell == CHEETAH or spell == PACK
end

-- Trainable ranks are ordered within each family. Coverage also includes group
-- versions; one active choice satisfies a family such as armors or aspects.
local families = {
    DRUID = {
        { key = "MARK", label = "RETAIL_MARK_OF_THE_WILD", spells = {1126, 5232, 6756, 5234, 8907, 9884, 9885, 21849, 21850} },
        { key = "THORNS", spells = {467, 782, 1075, 8914, 9756, 9910}, optional = true },
    },
    HUNTER = {
        { key = "ASPECT", spells = hunterAspects, own = true },
        { key = "TRUESHOT", spells = {1299346, 1299348, 19506, 20905, 20906} },
    },
    MAGE = {
        { key = "MAGE_ARMOR", spells = {168, 7300, 7301, 7302, 7320, 10219, 10220, 6117, 22782, 22783} },
        { key = "INTELLECT", label = "RETAIL_ARCANE_INTELLECT", spells = {1459, 1460, 1461, 10156, 10157, 23028} },
    },
    PALADIN = {
        { key = "BLESSING", spells = {19742, 19850, 19852, 19853, 19854, 25290, 20217, 19740, 19834,
            19835, 19836, 19837, 19838, 25291, 25894, 25918, 25898, 25782, 25916}, other = {1213408} },
        { key = "PALADIN_AURA", spells = {19891, 19899, 19900, 19888, 19897, 19898, 19876, 19895, 19896,
            19746, 7294, 10298, 10299, 10300, 10301, 465, 10290, 643, 10291, 1032, 10292, 10293}, own = true },
        { key = "RIGHTEOUS_FURY", spells = {25780}, optional = true },
    },
    PRIEST = {
        { key = "FORTITUDE", label = "RETAIL_FORTITUDE", spells = {1243, 1244, 1245, 2791, 10937, 10938, 21562, 21564} },
        { key = "SPIRIT", spells = {14752, 14818, 14819, 27841, 27681} },
        { key = "INNER_FIRE", spells = {588, 7128, 602, 1006, 10951, 10952} },
        { key = "SHADOWFORM", spells = {15473}, optional = true },
    },
    SHAMAN = {
        { key = "SHIELD", spells = {324, 325, 905, 945, 8134, 10431, 10432, 408510} },
    },
    WARLOCK = {
        { key = "DEMON_ARMOR", spells = {687, 696, 706, 1086, 11733, 11734, 11735} },
    },
    WARRIOR = {
        { key = "BATTLE_SHOUT", label = "RETAIL_BATTLE_SHOUT", spells = {6673, 5242, 6192, 11549, 11550, 11551, 25289} },
    },
}

local definitions = {}
for _, list in pairs(families) do
    for index, def in ipairs(list) do
        def.coverageBit = 2 ^ (index - 1)
        definitions[def.key] = def
    end
end

local IsAccessible = PSA.IsAccessibleValue
local function ReadableTable(value)
    return IsAccessible(value) and type(value) == "table" and (not canaccesstable or canaccesstable(value))
end

local function GetFamilies()
    return families[PSA.GetPlayerClassFile()]
end

local function HighestKnownSpell(spells)
    for i = #spells, 1, -1 do
        local id = spells[i]
        if PSA.IsKnownPlayerSpell(id) then return id end
    end
end

-- IsKnownPlayerSpell hits the spellbook for every rank. The answer only changes
-- when spells/talents change, so cache the highest known rank per family.
local knownSpellCache = {}
local function InvalidateKnownSpellCache()
    knownSpellCache = {}
end

local function KnownSpell(def)
    local cached = knownSpellCache[def.key]
    if cached ~= nil then return cached or nil end
    local spell = HighestKnownSpell(def.spells)
    knownSpellCache[def.key] = spell or false
    return spell
end

function PSA.GetForeverClassBuffEnabled(key)
    local def = definitions[key]
    if not def then return false end
    local saved = PSA.InitDB().foreverClassBuffs
    local choice
    if type(saved) == "table" then choice = saved[key] end
    if type(choice) == "boolean" then return choice end
    return not def.optional
end

function PSA.SetForeverClassBuffEnabled(key, enabled)
    if not definitions[key] or PSA.GetForeverClassBuffEnabled(key) == (enabled == true) then return end
    local db = PSA.InitDB()
    if type(db.foreverClassBuffs) ~= "table" then db.foreverClassBuffs = {} end
    db.foreverClassBuffs[key] = enabled == true
    PSA.RefreshForeverClassBuffs()
end

function PSA.GetForeverClassBuffOptions()
    local options = {}
    for _, def in ipairs(GetFamilies() or {}) do
        if KnownSpell(def) then
            options[#options + 1] = { key = def.key, label = PSA.UI[def.label or "FOREVER_BUFF_" .. def.key] }
        end
    end
    return options
end

local active, bySpell, instances, counts = {}, {}, {}, {}
local coverage = 0
local enabled, watching, snapshotOK, inEncounter, inCombat = false, false, false, false, false
local pending, planDirty, auraDirty
local eventFrame
local watchingAspectCasts = false
local lastAspect, aspectInstance, combatAspect

local function SetWatch(want)
    if want == watching then return end
    watching = want
    PSA.SetForeverClassAuraWatch(want)
end

local function EncounterInProgress()
    return C_InstanceEncounter and C_InstanceEncounter.IsEncounterInProgress
        and C_InstanceEncounter.IsEncounterInProgress() or false
end

local function CombatActive()
    return inCombat or inEncounter or InCombatLockdown()
end

local function RestingOrDead()
    return (IsResting and IsResting()) or (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player"))
end

local function Eligible()
    return not CombatActive() and not RestingOrDead()
        and not (C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret())
end

local function SetAspectCastWatch(want)
    if want == watchingAspectCasts then return end
    watchingAspectCasts = want
    if want then
        if not eventFrame.RegisterUnitEvent
            or not pcall(eventFrame.RegisterUnitEvent, eventFrame, SPELLCAST_SUCCEEDED, "player") then
            eventFrame:RegisterEvent(SPELLCAST_SUCCEEDED)
        end
    elseif eventFrame then
        eventFrame:UnregisterEvent(SPELLCAST_SUCCEEDED)
        lastAspect, aspectInstance, combatAspect = nil, nil, nil
    end
end

local function RenderCombatAspect()
    local show = combatAspect and IsTravelAspect(lastAspect) and CombatActive() and not RestingOrDead()
    PSA.RenderForeverClassBuffAlerts(show and {{ key = "ASPECT", spell = combatAspect }} or {})
end

local function StandDown()
    SetWatch(false)
    instances, counts, coverage, snapshotOK, aspectInstance = {}, {}, 0, false, nil
    RenderCombatAspect()
end

local function BuildPlan()
    local nextActive, nextBySpell = {}, {}
    for _, def in ipairs(GetFamilies() or {}) do
        local spell = PSA.GetForeverClassBuffEnabled(def.key) and KnownSpell(def)
        if spell then
            nextActive[#nextActive + 1] = { def = def, spell = spell }
            for _, id in ipairs(def.spells) do nextBySpell[id] = def end
            if def.other then
                for _, id in ipairs(def.other) do nextBySpell[id] = def end
            end
        end
    end
    local changed = #nextActive ~= #active
    if not changed then
        for index, entry in ipairs(nextActive) do
            if entry.def ~= active[index].def or entry.spell ~= active[index].spell then changed = true; break end
        end
    end
    active, bySpell = nextActive, nextBySpell
    SetAspectCastWatch(bySpell[CHEETAH] ~= nil or bySpell[PACK] ~= nil)
    if watchingAspectCasts then
        combatAspect = HighestKnownSpell(falconRanks) or HighestKnownSpell(hawkRanks)
    end
    return changed
end

-- A nil key is irrelevant, a false key means the event cannot prove absence.
local function Classify(aura)
    if not ReadableTable(aura) then return false end
    local spell = aura.spellId
    if not IsAccessible(spell) or type(spell) ~= "number" then return false end
    local def = bySpell[spell]
    if not def then return end
    local helpful = aura.isHelpful
    if not IsAccessible(helpful) then return false end
    if helpful == false then return end
    if def.own then
        local owner = aura.sourceUnit
        if not IsAccessible(owner) or not owner then return false end
        if owner ~= "player" then return end
    end
    local id = aura.auraInstanceID
    if not IsAccessible(id) or type(id) ~= "number" then return false end
    return def.key, id, spell
end

local function UpdateInstance(id, key)
    local before = instances[id]
    if before == key then return end
    if before then
        counts[before] = counts[before] - 1
        if counts[before] == 0 then coverage = coverage - definitions[before].coverageBit end
    end
    if key then
        local count = counts[key] or 0
        if count == 0 then coverage = coverage + definitions[key].coverageBit end
        counts[key] = count + 1
    end
    instances[id] = key
end

local function ReadSnapshot()
    instances, counts, coverage = {}, {}, 0
    local foundAspect, foundInstance
    local function Record(aura)
        local key, id, spell = Classify(aura)
        if key == false then return false end
        if key then UpdateInstance(id, key) end
        if key == "ASPECT" then foundAspect, foundInstance = spell, id end
        return true
    end
    if C_UnitAuras.GetUnitAuras then
        local ok, auras = pcall(C_UnitAuras.GetUnitAuras, "player", "HELPFUL")
        if not ok or not ReadableTable(auras) then return false end
        for _, aura in ipairs(auras) do if not Record(aura) then return false end end
    else
        for index = 1, 255 do
            local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", index, "HELPFUL")
            if not ok or not IsAccessible(aura) then return false end
            if not aura then break end
            if not Record(aura) then return false end
        end
    end
    lastAspect, aspectInstance = foundAspect, foundInstance
    return true
end

local function Render()
    local missing = {}
    if snapshotOK then
        for _, entry in ipairs(active) do
            local key = entry.def.key
            if (counts[key] or 0) == 0 then
                missing[#missing + 1] = { key = key, spell = entry.spell }
            end
        end
    end
    PSA.RenderForeverClassBuffAlerts(missing)
end

local function QueueRefresh(plan, auras)
    planDirty, auraDirty = planDirty or plan, auraDirty or auras
    if pending then return end
    pending = true
    C_Timer.After(0, function()
        pending = false
        local rebuild, rescan = planDirty, auraDirty
        planDirty, auraDirty = nil, nil
        if not enabled then return end
        if rebuild and BuildPlan() then rescan = true end
        if #active == 0 or not Eligible() then StandDown(); return end
        if rescan or not watching then snapshotOK = ReadSnapshot() end
        SetWatch(true)
        Render()
    end)
end

function PSA.HandleForeverClassAuraUpdate(update)
    if not watching or auraDirty then return end
    local rescan = not snapshotOK or not ReadableTable(update)
    local added, removed
    if not rescan then
        local full = update.isFullUpdate
        added, removed = update.addedAuras, update.removedAuraInstanceIDs
        rescan = not IsAccessible(full) or full or not IsAccessible(added) or not IsAccessible(removed)
            or (added and not ReadableTable(added)) or (removed and not ReadableTable(removed))
        if not rescan and (not added or #added == 0) and (not removed or #removed == 0) then return end
    end
    if not Eligible() then StandDown(); return end
    if rescan then QueueRefresh(false, true); return end

    -- Compare coverage after the whole batch, so swapping ranks or removing
    -- one of several effects covering a group doesn't schedule a redraw.
    local previousCoverage = coverage
    if removed then
        for _, id in ipairs(removed) do
            if not IsAccessible(id) then QueueRefresh(false, true); return end
            if type(id) == "number" then
                if id == aspectInstance then lastAspect, aspectInstance = nil, nil end
                UpdateInstance(id)
            end
        end
    end
    if added then
        for _, aura in ipairs(added) do
            local key, id, spell = Classify(aura)
            if key == false then QueueRefresh(false, true); return end
            if key == "ASPECT" then lastAspect, aspectInstance = spell, id end
            if key then UpdateInstance(id, key) end
        end
    end
    if coverage ~= previousCoverage then QueueRefresh() end
end

local events = {
    "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE", "PLAYER_TALENT_UPDATE",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST",
    "PLAYER_UPDATE_RESTING", "ADDON_RESTRICTION_STATE_CHANGED", "ENCOUNTER_START", "ENCOUNTER_END",
}
local function OnEvent(_, event, unit, _, spell)
    if not enabled then return end
    if event == SPELLCAST_SUCCEEDED then
        if not watchingAspectCasts or not IsAccessible(unit) or unit ~= "player"
            or not IsAccessible(spell) or type(spell) ~= "number" then return end
        if bySpell[spell] ~= definitions.ASPECT then return end
        if lastAspect ~= spell then
            local wasTravel = IsTravelAspect(lastAspect)
            lastAspect, aspectInstance = spell, nil
            if wasTravel ~= IsTravelAspect(spell) and CombatActive() then RenderCombatAspect() end
        end
        return
    end
    if event == "ENCOUNTER_START" then inEncounter = true end
    if event == "ENCOUNTER_END" then inEncounter = false end
    if event == "PLAYER_REGEN_DISABLED" then inCombat = true end
    if event == "PLAYER_REGEN_ENABLED" then inCombat = false end
    if event == "PLAYER_ENTERING_WORLD" then
        inEncounter = EncounterInProgress()
        inCombat = InCombatLockdown() and true or false
        lastAspect, aspectInstance = nil, nil
        InvalidateKnownSpellCache()
        StandDown()
        PSA.RefreshForeverClassBuffs()
    elseif event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_SKILL_LINE" or event == "PLAYER_TALENT_UPDATE" then
        InvalidateKnownSpellCache()
        QueueRefresh(true)
    elseif event == "PLAYER_DEAD" then
        lastAspect = nil
        StandDown()
    elseif event == "PLAYER_REGEN_DISABLED" or event == "ENCOUNTER_START" then
        StandDown()
    else
        if event == "PLAYER_REGEN_ENABLED" and not inEncounter then PSA.RenderForeverClassBuffAlerts({}) end
        -- Restrictions may take effect after dispatch; refresh on the next frame.
        QueueRefresh(false, true)
    end
end

function PSA.RefreshForeverClassBuffs()
    local want = false
    local class
    if PSA.GetBuffAlertsEnabled() then
        class = PSA.GetPlayerClassFile()
        if not class then want = true end
        for _, def in ipairs(families[class] or {}) do
            if PSA.GetForeverClassBuffEnabled(def.key) then want = true; break end
        end
    end
    if watchingAspectCasts and (class ~= "HUNTER" or not PSA.GetForeverClassBuffEnabled("ASPECT")) then
        SetAspectCastWatch(false)
        if CombatActive() then RenderCombatAspect() end
    end
    if want ~= enabled then
        enabled = want
        if want then
            -- Spell/talent events were not subscribed while the module was
            -- disabled, so refresh the cached ranks before building the plan.
            InvalidateKnownSpellCache()
            if not eventFrame then
                eventFrame = CreateFrame("Frame")
                eventFrame:SetScript("OnEvent", OnEvent)
            end
            for _, event in ipairs(events) do eventFrame:RegisterEvent(event) end
            inEncounter = EncounterInProgress()
            inCombat = InCombatLockdown() and true or false
        else
            for _, event in ipairs(events) do eventFrame:UnregisterEvent(event) end
            StandDown()
        end
    end
    if enabled then QueueRefresh(true, true) end
end
