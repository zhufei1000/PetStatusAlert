local _, PSA = ...
if PSA.IsForeverClient() or not (C_UnitAuras and C_UnitAuras.GetUnitAuras and C_SpecializationInfo) then return end

local IsAccessible = PSA.IsAccessibleValue
local WELL_FED_ICON = 136000
local ENHANCEMENT = 263
local MAX_LEAD_MINUTES = 60
local STRENGTH, AGILITY, INTELLECT = 1, 2, 4
local WHISPER_RECHECK = 60
local WHISPER_COOLDOWN = 15
local whisperStatus = Enum.ChatWhisperTargetStatus
local buffs = {
    { key = "BATTLE_SHOUT", id = 6673, class = "WARRIOR", stats = { [STRENGTH] = true, [AGILITY] = true } },
    { key = "ARCANE_INTELLECT", id = 1459, aura = 432778, class = "MAGE", stats = { [INTELLECT] = true } },
    { key = "SKYFURY", id = 462854, class = "SHAMAN" },
    { key = "MARK_OF_THE_WILD", id = 1126, aura = 432661, class = "DRUID" },
    { key = "FORTITUDE", id = 21562, class = "PRIEST" },
}
local weapons = {
    { key = "MAIN_HAND", slot = INVSLOT_MAINHAND or 16, imbue = { key = "WINDFURY", spell = 33757, enchant = 5401 } },
    { key = "OFF_HAND", slot = INVSLOT_OFFHAND or 17, imbue = { key = "FLAMETONGUE", spell = 318038, enchant = 5400 } },
}
local buffsByKey = {}
for _, buff in ipairs(buffs) do buffsByKey[buff.key] = buff end
PSA.RETAIL_BUFFS = buffs

local function GetSavedSetting(key)
    local settings = PSA.InitDB().retailSupply
    if type(settings) == "table" then return settings[key] end
end

function PSA.GetRetailSupplySetting(key)
    local value = GetSavedSetting(key)
    if buffsByKey[key] or key == "WINDFURY" or key == "FLAMETONGUE" then return value ~= false end
    return value == true
end

local function NormalizeLeadMinutes(value)
    local minutes = tonumber(value)
    if minutes and minutes == minutes then
        return math.floor(math.max(0, math.min(MAX_LEAD_MINUTES, minutes)))
    end
end

function PSA.GetRetailSupplyLeadMinutes(key)
    return NormalizeLeadMinutes(GetSavedSetting(key .. "_LEAD_MINUTES")) or 0
end

function PSA.GetRetailBuffName(buff)
    return C_Spell.GetSpellName(buff.id) or PSA.UI["RETAIL_" .. buff.key]
end

local function IsReadableTable(value)
    return IsAccessible(value) and type(value) == "table" and (not canaccesstable or canaccesstable(value))
end

local inEncounter = false
local function IsSuspended()
    return inEncounter or InCombatLockdown() or UnitIsDeadOrGhost("player")
end

local function CanReadAuras()
    return not IsSuspended() and not (C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret())
end

local function CanReadSpell(spellID)
    return not (C_Secrets and C_Secrets.ShouldSpellAuraBeSecret and C_Secrets.ShouldSpellAuraBeSecret(spellID))
end

local function CanWhisper()
    return C_ChatInfo and C_ChatInfo.RequestCanLocalWhisperTarget and C_ChatInfo.SendChatMessage
        and C_ChatInfo.InChatMessagingLockdown and not C_ChatInfo.InChatMessagingLockdown()
        and C_SocialRestrictions and C_SocialRestrictions.CanSendChat and C_SocialRestrictions.CanSendChat()
end

local function ReadMember(unit, expectedClass)
    if not UnitIsConnected(unit) then return end
    local guid, isSelf = UnitGUID(unit), UnitIsUnit(unit, "player")
    if not IsAccessible(guid) or not guid or not IsAccessible(isSelf) or isSelf then return end
    local _, class = UnitClass(unit)
    if not IsAccessible(class) or not class or (expectedClass and class ~= expectedClass) then return end
    local name, realm = UnitFullName(unit)
    if not IsAccessible(name) or not IsAccessible(realm) or not name or name == "" then return end
    return guid, realm and realm ~= "" and (name .. "-" .. realm) or name, class
end

local function GroupUnits()
    if IsInRaid() then return "raid", GetNumGroupMembers() end
    return "party", GetNumSubgroupMembers()
end

local foodEnabled, weaponEnabled, classEnabled, watchAuras, watching = false, false, false, false, false
local tracked, eligible, roster, permissions, lastWhisper = {}, {}, {}, {}, {}
local instances, counts, foodExpirations = {}, {}, {}
local aurasKnown, weaponStates, expectedImbues = false, {}, {}
local foodLead, weaponLead = 0, 0
local wakeAt, wakeTimer
local wellFedName, foodHasOpaqueAura
local displayed = {}

local function ReadRoster()
    roster = {}
    local currentPermissions = {}
    local prefix, count = GroupUnits()
    for index = 1, count do
        local unit = prefix .. index
        local guid, name, class = ReadMember(unit)
        if guid then
            roster[class] = roster[class] or {}
            table.insert(roster[class], { unit = unit, guid = guid, name = name })
            currentPermissions[guid] = permissions[guid]
        end
    end
    permissions = currentPermissions
end

local function StillInGroup(member, class)
    local prefix, count = GroupUnits()
    local index = tonumber(member.unit:match("^" .. prefix .. "(%d+)$"))
    if not index or index > count then return false end
    local guid, name = ReadMember(member.unit, class)
    return guid == member.guid and name == member.name
end

local function RequestWhisper(member, retry)
    local info = permissions[member.guid]
    local now = GetTime()
    if not info or (retry and now - info.time >= WHISPER_RECHECK) then
        info = { time = now }
        permissions[member.guid] = info
        C_ChatInfo.RequestCanLocalWhisperTarget(member.guid)
    end
    return info.status
end

local function IsWhisperAllowed(status)
    return status ~= nil and (status == whisperStatus.CanWhisper or status == whisperStatus.CanWhisperGuild)
end

local function FindProvider(buff)
    for _, member in ipairs(roster[buff.class] or {}) do
        local status = RequestWhisper(member)
        if status == nil or IsWhisperAllowed(status) then return member, IsWhisperAllowed(status) end
    end
end

local function BuildAuraPlan()
    local previous = eligible
    tracked, eligible = {}, {}
    if not classEnabled then return next(previous) ~= nil end
    local specs = C_SpecializationInfo
    local index = specs.GetSpecialization()
    local stat = IsAccessible(index) and index and select(6, specs.GetSpecializationInfo(index))
    if not IsAccessible(stat) then stat = nil end
    local playerClass = PSA.GetPlayerClassFile()
    for _, buff in ipairs(buffs) do
        if PSA.GetRetailSupplySetting(buff.key) and (not buff.stats or buff.stats[stat] or playerClass == buff.class) then
            eligible[buff.key] = playerClass == buff.class and PSA.IsKnownPlayerSpell(buff.id) and "spell" or "whisper"
            tracked[buff.id] = buff.key
            if buff.aura then tracked[buff.aura] = buff.key end
        end
    end
    for _, buff in ipairs(buffs) do
        if eligible[buff.key] ~= previous[buff.key] then return true end
    end
    return false
end

local function ClassifyAura(aura)
    if not IsReadableTable(aura) then return nil, nil, foodEnabled end
    local id, spell, helpful = aura.auraInstanceID, aura.spellId, aura.isHelpful
    local readableHelpful = IsAccessible(helpful)
    if readableHelpful and not helpful then return end
    if not IsAccessible(id) or not id then return nil, nil, foodEnabled end
    local key = readableHelpful and IsAccessible(spell) and tracked[spell]
    if key then return id, key end
    if not foodEnabled then return end
    local icon, name = aura.icon, aura.name
    local readableIcon = IsAccessible(icon)
    local isFood = (readableIcon and icon == WELL_FED_ICON)
        or (wellFedName and IsAccessible(name) and name == wellFedName)
    if isFood and readableHelpful then return id, "FOOD" end
    if isFood or not readableIcon then return id, "UNKNOWN_FOOD" end
end

local function ReadFoodExpiration(aura)
    if not IsReadableTable(aura) then return end
    local expiration = aura.expirationTime
    if IsAccessible(expiration) and type(expiration) == "number" and expiration > 0 and expiration < math.huge then
        return expiration
    end
end

local function UpdateInstance(id, key, aura)
    local previous = instances[id]
    local expiration
    if key == "FOOD" and foodLead > 0 then expiration = ReadFoodExpiration(aura) end
    local changed = foodExpirations[id] ~= expiration
    foodExpirations[id] = expiration
    if key == previous then return changed end
    if previous then counts[previous] = counts[previous] - 1 end
    if key then counts[key] = (counts[key] or 0) + 1 end
    instances[id] = key
    return true
end

local function ReadAuras()
    instances, counts, foodExpirations = {}, {}, {}
    aurasKnown, foodHasOpaqueAura = false, false
    if not watchAuras then return end
    if foodEnabled and not wellFedName then wellFedName = C_Spell.GetSpellName(19705) end
    local ok, auras = pcall(C_UnitAuras.GetUnitAuras, "player", "HELPFUL")
    if not ok or not IsReadableTable(auras) then return end
    for _, aura in ipairs(auras) do
        local id, key, opaque = ClassifyAura(aura)
        if opaque then foodHasOpaqueAura = true end
        if key then UpdateInstance(id, key, aura) end
    end
    aurasKnown = true
end

local function UpdateExpectedImbues()
    local enhancement = weaponEnabled and PSA.GetPlayerClassFile() == "SHAMAN" and PSA.GetPlayerSpecId() == ENHANCEMENT
    local changed = false
    for _, hand in ipairs(weapons) do
        local imbue = enhancement and PSA.IsKnownPlayerSpell(hand.imbue.spell) and hand.imbue or nil
        if expectedImbues[hand.key] ~= imbue then
            expectedImbues[hand.key] = imbue
            changed = true
        end
    end
    return changed
end

local function ReadWeapons()
    weaponStates = {}
    if not weaponEnabled or IsSuspended() or not (C_Item and C_Item.GetItemInfoInstant
        and C_PaperDollInfo and C_PaperDollInfo.GetTemporaryEnchantmentInfo) then return end
    local now = weaponLead > 0 and GetTime()
    for _, hand in ipairs(weapons) do
        local imbue = expectedImbues[hand.key]
        local item = GetInventoryItemID("player", hand.slot)
        if IsAccessible(item) and item and (not imbue or PSA.GetRetailSupplySetting(imbue.key)) then
            local _, _, _, _, icon, class, subclass = C_Item.GetItemInfoInstant(item)
            if IsAccessible(class) and class == Enum.ItemClass.Weapon and IsAccessible(subclass)
                and subclass ~= Enum.ItemWeaponSubclass.Fishingpole then
                local enchant = C_PaperDollInfo.GetTemporaryEnchantmentInfo(hand.slot)
                local readable = IsReadableTable(enchant)
                local enchantID = imbue and readable and enchant.enchantID
                if IsAccessible(enchant) and (not enchant or (readable and IsAccessible(enchantID))) then
                    local missing = not enchant or (imbue and enchantID ~= imbue.enchant)
                    local expiration
                    if not missing and now and readable then
                        local timed, remaining = enchant.hasExpirationTime, enchant.remainingTimeMs
                        if IsAccessible(timed) and timed and IsAccessible(remaining) and type(remaining) == "number"
                            and remaining > 0 and remaining < math.huge then
                            expiration = now + remaining / 1000
                        end
                    end
                    if imbue then icon = C_Spell.GetSpellTexture(imbue.spell) end
                    weaponStates[hand.key] = {
                        icon = IsAccessible(icon) and icon or 134400,
                        missing = missing, expiration = expiration, imbue = imbue and imbue.key,
                    }
                end
            end
        end
    end
end

local function SetReminderWake(time, callback)
    if wakeAt == time then return end
    if wakeTimer then wakeTimer:Cancel(); wakeTimer = nil end
    wakeAt = time
    if not time then return end
    wakeTimer = C_Timer.NewTimer(math.max(0.01, time - GetTime()), function()
        wakeAt, wakeTimer = nil, nil
        callback()
    end)
end

local function GetFoodExpiration()
    local latest, timed = nil, 0
    for _, expiration in pairs(foodExpirations) do
        latest = math.max(latest or expiration, expiration)
        timed = timed + 1
    end
    -- An untimed or unreadable Well Fed effect can outlast the readable ones.
    if timed == counts.FOOD then return latest end
end

local function RefreshDisplay()
    displayed = {}
    local nextWake
    if not IsSuspended() then
        local canRead = CanReadAuras()
        local now = GetTime()
        local function AddReminder(key, icon, missing, expiration, lead, imbue)
            if missing then
                displayed[key] = { icon = icon, imbue = imbue }
            elseif canRead and expiration and expiration > now and lead > 0 then
                local threshold = expiration - lead
                if now >= threshold then
                    displayed[key] = { icon = icon, expiration = expiration, lead = lead, imbue = imbue }
                elseif not nextWake or threshold < nextWake then
                    nextWake = threshold
                end
            end
        end
        if weaponEnabled then
            for key, state in pairs(weaponStates) do
                AddReminder(key, state.icon, state.missing, state.expiration, weaponLead, state.imbue)
            end
        end
        if aurasKnown and canRead then
            if foodEnabled and not foodHasOpaqueAura and (counts.UNKNOWN_FOOD or 0) == 0 then
                AddReminder("FOOD", WELL_FED_ICON, (counts.FOOD or 0) == 0, GetFoodExpiration(), foodLead)
            end
            for _, buff in ipairs(buffs) do
                local action = eligible[buff.key]
                if action and (counts[buff.key] or 0) == 0 and CanReadSpell(buff.id)
                    and (not buff.aura or CanReadSpell(buff.aura)) then
                    local hasProvider = roster[buff.class] and #roster[buff.class] > 0
                    if action == "spell" or hasProvider then
                        local member, ready
                        if action == "whisper" and CanWhisper() then member, ready = FindProvider(buff) end
                        displayed[buff.key] = {
                            icon = C_Spell.GetSpellTexture(buff.id) or 134400, action = action,
                            member = member, ready = ready,
                        }
                    end
                end
            end
        end
    end
    SetReminderWake(nextWake, RefreshDisplay)
    PSA.RenderRetailSupplyAlerts(displayed, foodEnabled or weaponEnabled or classEnabled)
end

local pending, dirtyPlan, dirtyRoster, dirtyAuras, dirtyWeapons
local function QueueRefresh(plan, group, auras, gear)
    dirtyPlan, dirtyRoster = dirtyPlan or plan, dirtyRoster or group
    dirtyAuras, dirtyWeapons = dirtyAuras or auras, dirtyWeapons or gear
    if auras then aurasKnown = false end
    if pending then return end
    pending = true
    C_Timer.After(0, function()
        pending = false
        if dirtyPlan then
            if BuildAuraPlan() then dirtyAuras = true end
            if UpdateExpectedImbues() then dirtyWeapons = true end
        end
        if dirtyRoster and classEnabled and CanReadAuras() then ReadRoster() end
        local watch = (foodEnabled or next(tracked) ~= nil) and CanReadAuras()
        if watch ~= watchAuras then
            watchAuras = watch
            PSA.SetRetailSupplyAuraWatch(watch)
            dirtyAuras = true
        end
        if dirtyAuras then ReadAuras() end
        if dirtyWeapons then ReadWeapons() end
        dirtyPlan, dirtyRoster, dirtyAuras, dirtyWeapons = nil, nil, nil, nil
        RefreshDisplay()
    end)
end

function PSA.HandleRetailSupplyAuraUpdate(update)
    if not watchAuras or not CanReadAuras() then return end
    if not IsReadableTable(update) or not IsAccessible(update.isFullUpdate) or update.isFullUpdate then
        QueueRefresh(false, false, true)
        return
    end
    if not aurasKnown then return end
    if not IsAccessible(update.removedAuraInstanceIDs) or not IsAccessible(update.addedAuras) then
        QueueRefresh(false, false, true)
        return
    end
    local changed
    if IsReadableTable(update.removedAuraInstanceIDs) then
        for _, id in ipairs(update.removedAuraInstanceIDs) do
            if IsAccessible(id) and instances[id] then changed = UpdateInstance(id) or changed end
        end
    end
    if IsReadableTable(update.addedAuras) then
        for _, aura in ipairs(update.addedAuras) do
            local id, key, opaque = ClassifyAura(aura)
            if opaque and not foodHasOpaqueAura then
                QueueRefresh(false, false, true)
                return
            end
            if key then changed = UpdateInstance(id, key, aura) or changed end
        end
    end
    if foodLead > 0 and C_UnitAuras.GetAuraDataByAuraInstanceID and IsReadableTable(update.updatedAuraInstanceIDs) then
        for _, id in ipairs(update.updatedAuraInstanceIDs) do
            if IsAccessible(id) and instances[id] == "FOOD" then
                local ok, aura = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, "player", id)
                changed = UpdateInstance(id, "FOOD", ok and aura) or changed
            end
        end
    end
    if changed then QueueRefresh() end
end

local function ShowClickFeedback(key)
    if UIErrorsFrame then UIErrorsFrame:AddMessage(PSA.UI[key], 1, 0.82, 0) end
end

function PSA.GetRetailSupplyTooltip(key)
    local alert, buff = displayed[key], buffsByKey[key]
    if not alert then return end
    if not buff then
        local label = "RETAIL_" .. (alert.imbue or key)
        if alert.expiration then return PSA.UI[label .. "_EXPIRING"] end
        return PSA.UI[label .. "_MISSING"]
    end
    local label = PSA.UI.RETAIL_BUFF_MISSING:format(PSA.GetRetailBuffName(buff))
    if alert.action == "spell" then return label, PSA.UI.RETAIL_BUFF_CAST end
    if not alert.member or not CanWhisper() then return label, PSA.UI.RETAIL_WHISPER_BLOCKED end
    if not alert.ready then return label, PSA.UI.RETAIL_WHISPER_PENDING end
    return label, PSA.UI.RETAIL_WHISPER_CLICK:format(alert.member.name)
end

function PSA.ActivateRetailSupplyAlert(key)
    local alert, buff = displayed[key], buffsByKey[key]
    if not alert or not buff or not classEnabled or not PSA.GetRetailSupplySetting(key) or dirtyPlan or dirtyRoster
        or not aurasKnown or not CanReadAuras() or (counts[key] or 0) > 0
        or not CanReadSpell(buff.id) or (buff.aura and not CanReadSpell(buff.aura)) then return end
    if alert.action == "spell" then
        if PSA.IsKnownPlayerSpell(buff.id) then return buff.id end
        return
    end
    if not CanWhisper() then return ShowClickFeedback("RETAIL_WHISPER_BLOCKED") end
    local member = alert.member
    if not member or not StillInGroup(member, buff.class) then
        QueueRefresh(false, true)
        return ShowClickFeedback("RETAIL_WHISPER_BLOCKED")
    end
    local status = RequestWhisper(member, true)
    if status == nil then
        QueueRefresh()
        return ShowClickFeedback("RETAIL_WHISPER_PENDING")
    end
    if not IsWhisperAllowed(status) then return ShowClickFeedback("RETAIL_WHISPER_BLOCKED") end
    local now = GetTime()
    if lastWhisper[key] and now - lastWhisper[key] < WHISPER_COOLDOWN then
        return ShowClickFeedback("RETAIL_WHISPER_COOLDOWN")
    end
    lastWhisper[key] = now
    C_ChatInfo.SendChatMessage(PSA.UI.RETAIL_WHISPER_MESSAGE:format(PSA.GetRetailBuffName(buff)), "WHISPER", nil, member.name)
end

local eventFrame = CreateFrame("Frame")
local commonEvents = { "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_DEAD",
    "PLAYER_ALIVE", "PLAYER_UNGHOST", "ENCOUNTER_START", "ENCOUNTER_END" }
local classEvents = { "GROUP_ROSTER_UPDATE", "UNIT_CONNECTION", "CAN_LOCAL_WHISPER_TARGET_RESPONSE" }
local talentEvents = { "PLAYER_SPECIALIZATION_CHANGED", "SPELLS_CHANGED" }
local weaponEvents = { "PLAYER_EQUIPMENT_CHANGED", "WEAPON_ENCHANT_CHANGED" }

local function SetEvents(events, active)
    for _, event in ipairs(events) do
        if active then eventFrame:RegisterEvent(event) else eventFrame:UnregisterEvent(event) end
    end
end

eventFrame:SetScript("OnEvent", function(_, event, value, status)
    if event == "CAN_LOCAL_WHISPER_TARGET_RESPONSE" then
        local info = IsAccessible(value) and permissions[value]
        if info and IsAccessible(status) then
            info.status = status
            QueueRefresh()
        end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        if value == weapons[1].slot or value == weapons[2].slot then QueueRefresh(false, false, false, true) end
    elseif event == "WEAPON_ENCHANT_CHANGED" then
        QueueRefresh(false, false, false, true)
    elseif event == "GROUP_ROSTER_UPDATE" or event == "UNIT_CONNECTION" then
        if event == "GROUP_ROSTER_UPDATE" or (IsAccessible(value) and value
            and (value:match("^party%d+$") or value:match("^raid%d+$"))) then
            QueueRefresh(false, true)
        end
    elseif event == "SPELLS_CHANGED" or event == "PLAYER_SPECIALIZATION_CHANGED" then
        if event == "SPELLS_CHANGED" or value == "player" then QueueRefresh(true) end
    elseif event == "ADDON_RESTRICTION_STATE_CHANGED" then
        -- Activation events are sent before the restricted state takes effect.
        QueueRefresh(false, true, true)
    else
        if event == "PLAYER_REGEN_DISABLED" or event == "ENCOUNTER_START" or event == "PLAYER_DEAD" then
            SetReminderWake(nil)
        end
        if event == "ENCOUNTER_START" then inEncounter = true end
        if event == "ENCOUNTER_END" then inEncounter = false end
        if event == "PLAYER_ENTERING_WORLD" then
            inEncounter = C_InstanceEncounter and C_InstanceEncounter.IsEncounterInProgress() or false
        end
        QueueRefresh(event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED", true, true, true)
    end
end)

function PSA.RefreshRetailBuffAlerts()
    foodEnabled = PSA.GetRetailSupplySetting("FOOD")
    weaponEnabled = PSA.GetRetailSupplySetting("WEAPON")
    classEnabled = PSA.GetRetailSupplySetting("CLASS")
    foodLead = foodEnabled and PSA.GetRetailSupplyLeadMinutes("FOOD") * 60 or 0
    weaponLead = weaponEnabled and PSA.GetRetailSupplyLeadMinutes("WEAPON") * 60 or 0
    local active = foodEnabled or weaponEnabled or classEnabled
    if active ~= watching then
        watching = active
        inEncounter = active and C_InstanceEncounter and C_InstanceEncounter.IsEncounterInProgress() or false
        SetEvents(commonEvents, active)
    end
    if foodEnabled or classEnabled or weaponLead > 0 then eventFrame:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
    else eventFrame:UnregisterEvent("ADDON_RESTRICTION_STATE_CHANGED") end
    SetEvents(classEvents, classEnabled)
    SetEvents(talentEvents, classEnabled or (weaponEnabled and PSA.GetPlayerClassFile() == "SHAMAN"))
    SetEvents(weaponEvents, weaponEnabled)
    if not classEnabled then roster, permissions = {}, {} end
    if active or next(displayed) or watchAuras then
        QueueRefresh(true, true, true, true)
    else
        SetReminderWake(nil)
        PSA.RenderRetailSupplyAlerts(displayed, false)
    end
end

local function SaveSetting(key, value)
    local db = PSA.InitDB()
    if type(db.retailSupply) ~= "table" then db.retailSupply = {} end
    db.retailSupply[key] = value
    PSA.RefreshRetailBuffAlerts()
end

function PSA.SetRetailSupplySetting(key, enabled)
    SaveSetting(key, enabled == true)
end

function PSA.SetRetailSupplyLeadMinutes(key, value)
    local minutes = NormalizeLeadMinutes(value)
    if minutes and minutes ~= PSA.GetRetailSupplyLeadMinutes(key) then
        SaveSetting(key .. "_LEAD_MINUTES", minutes)
    end
end
