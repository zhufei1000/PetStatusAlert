local _, PSA = ...

if not PSA.IsForeverClient() then return end

local CHEETAH, PACK = 5118, 13159
local FALCON = 469145
local hawkRanks = {27044, 25296, 14322, 14321, 14320, 14319, 14318, 13165}
local aspects = {
    [CHEETAH] = true, [PACK] = true, [FALCON] = true,
    [13163] = true, [13161] = true, [1299445] = true, [1299446] = true, [1299447] = true,
    [20043] = true, [20190] = true, [34074] = true, [415423] = true,
}
for _, id in ipairs(hawkRanks) do aspects[id] = true end

local IsAccessible = PSA.IsAccessibleValue
local function ReadableTable(value)
    return IsAccessible(value) and type(value) == "table" and (not canaccesstable or canaccesstable(value))
end

local function IsTravelAspect(spell)
    return spell == CHEETAH or spell == PACK
end

-- nil = unreadable, false = unrelated, spell ID = our own travel aspect.
local function ReadAura(aura)
    if not ReadableTable(aura) then return end
    local spell = aura.spellId
    if not IsAccessible(spell) then return end
    if not IsTravelAspect(spell) then return false end
    local source, helpful, instance = aura.sourceUnit, aura.isHelpful, aura.auraInstanceID
    if not IsAccessible(source) or not IsAccessible(helpful) then return end
    if source ~= "player" or helpful == false then return false end
    if not IsAccessible(instance) or type(instance) ~= "number" then instance = nil end
    return spell, instance
end

local frame, combat, dead, active, instance, recommendation, pending
local enabled = false
local function Render()
    PSA.SetCombatAspectAlert(combat and not dead and active and (recommendation or active) or nil)
end

local function RefreshRecommendation()
    recommendation = nil
    if PSA.IsKnownPlayerSpell(FALCON) then
        recommendation = FALCON
        return
    end
    for _, spell in ipairs(hawkRanks) do
        if PSA.IsKnownPlayerSpell(spell) then
            recommendation = spell
            return
        end
    end
end

-- Seed the cache on login and reconcile after combat. Combat never reads a
-- full aura snapshot; it uses successful casts and readable aura deltas.
local function RunSnapshot()
    pending = false
    if not enabled or combat or dead or InCombatLockdown()
        or (C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret()) then return end
    local auras = C_UnitAuras
    if not auras then return end
    local spell, id
    local readable = true
    if auras.GetUnitAuras then
        local list = auras.GetUnitAuras("player", "HELPFUL")
        if not ReadableTable(list) then return end
        for _, aura in ipairs(list) do
            spell, id = ReadAura(aura)
            if spell then break end
            if spell == nil then readable = false end
        end
    elseif auras.GetAuraDataByIndex then
        for index = 1, 255 do
            local aura = auras.GetAuraDataByIndex("player", index, "HELPFUL")
            if not IsAccessible(aura) then return end
            if not aura then break end
            spell, id = ReadAura(aura)
            if spell then break end
            if spell == nil then readable = false end
        end
    else
        return
    end
    if spell or readable then active, instance = spell or nil, id end
end

local function QueueSnapshot()
    if pending or combat or not C_UnitAuras
        or not (C_UnitAuras.GetUnitAuras or C_UnitAuras.GetAuraDataByIndex) then return end
    pending = true
    C_Timer.After(0, RunSnapshot)
end

local function HandleAuraUpdate(update)
    if not ReadableTable(update) then QueueSnapshot(); return end
    local full = update.isFullUpdate
    if not IsAccessible(full) or full then QueueSnapshot(); return end
    local removed, added = update.removedAuraInstanceIDs, update.addedAuras
    local previous = active
    if instance and ReadableTable(removed) then
        for _, id in ipairs(removed) do
            if IsAccessible(id) and id == instance then active, instance = nil, nil; break end
        end
    end
    if ReadableTable(added) then
        for _, aura in ipairs(added) do
            local spell, id = ReadAura(aura)
            if spell then active, instance = spell, id; break end
        end
    end
    if active ~= previous then Render() end
end

local events = {
    "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "SPELLS_CHANGED",
    "LEARNED_SPELL_IN_SKILL_LINE", "PLAYER_TALENT_UPDATE", "ADDON_RESTRICTION_STATE_CHANGED",
}

local function RefreshWorldState()
    combat = InCombatLockdown()
    local isDead = UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")
    dead = IsAccessible(isDead) and isDead or false
    active, instance = nil, nil
    RefreshRecommendation()
    Render()
    QueueSnapshot()
end

local function OnEvent(_, event, unit, update, spell)
    if event == "UNIT_AURA" or event == "UNIT_SPELLCAST_SUCCEEDED" then
        if dead or not IsAccessible(unit) or unit ~= "player" then return end
        if event == "UNIT_AURA" then
            HandleAuraUpdate(update)
        elseif IsAccessible(spell) and type(spell) == "number" and aspects[spell] then
            local travel = IsTravelAspect(spell) and spell or nil
            if travel ~= active then
                active, instance = travel, nil
                Render()
            end
        end
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        combat = event == "PLAYER_REGEN_DISABLED"
        Render()
        if not combat then QueueSnapshot() end
    elseif event == "PLAYER_ENTERING_WORLD" then
        RefreshWorldState()
    elseif event == "PLAYER_DEAD" then
        dead, active, instance = true, nil, nil
        Render()
    elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
        dead = false
        QueueSnapshot()
    elseif event == "ADDON_RESTRICTION_STATE_CHANGED" then
        QueueSnapshot()
    else
        RefreshRecommendation()
        Render()
    end
end

function PSA.GetCombatAspectAlertEnabled()
    local saved = PSA.InitDB().foreverClassBuffs
    return type(saved) ~= "table" or saved.ASPECT ~= false
end

function PSA.RefreshCombatAspectAlert()
    local want = PSA.GetPlayerClassFile() == "HUNTER"
        and PSA.GetCombatAspectAlertEnabled()
    if want == enabled then return end
    enabled = want
    if not want then
        for _, event in ipairs(events) do frame:UnregisterEvent(event) end
        frame:UnregisterEvent("UNIT_AURA")
        frame:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        active, instance = nil, nil
        Render()
        return
    end
    if not frame then
        frame = CreateFrame("Frame")
        frame:SetScript("OnEvent", OnEvent)
    end
    for _, event in ipairs(events) do
        -- The restriction notification is not available on every build.
        if event == "ADDON_RESTRICTION_STATE_CHANGED" then
            pcall(frame.RegisterEvent, frame, event)
        else
            frame:RegisterEvent(event)
        end
    end
    for _, event in ipairs({"UNIT_AURA", "UNIT_SPELLCAST_SUCCEEDED"}) do
        local ok, registered = pcall(frame.RegisterUnitEvent, frame, event, "player")
        if not ok or registered == false then frame:RegisterEvent(event) end
    end
    RefreshWorldState()
end

function PSA.SetCombatAspectAlertEnabled(on)
    local db = PSA.InitDB()
    if type(db.foreverClassBuffs) ~= "table" then db.foreverClassBuffs = {} end
    db.foreverClassBuffs.ASPECT = on == true
    PSA.RefreshCombatAspectAlert()
end
