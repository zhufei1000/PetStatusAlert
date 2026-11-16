local _, PSA = ...
if PSA.IsForeverClient() or not (C_UnitAuras and C_UnitAuras.GetUnitAuras and C_SpecializationInfo) then return end

local IsAccessible = PSA.IsAccessibleValue
local WELL_FED_ICON = 136000
local ELEMENTAL, ENHANCEMENT, RESTORATION = 262, 263, 264
local ELEMENTAL_ORBIT = 383010
local EARTH_SHIELD_SPELL = 974
local EARTH_SHIELD_SELF_AURA = 383648
local WATER_SHIELD_SPELL = 52127
local LIGHTNING_SHIELD_SPELL = 192106
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
local hands = {
    { key = "MAIN_HAND", slot = INVSLOT_MAINHAND or 16 },
    { key = "OFF_HAND", slot = INVSLOT_OFFHAND or 17 },
}
-- Spell/enchant IDs match EUI's shaman imbue table. Shield imbues require an equipped shield.
local imbues = {
    { key = "WINDFURY", spell = 33757, enchant = 5401 },
    { key = "FLAMETONGUE", spell = 318038, enchant = 5400 },
    { key = "EARTHLIVING", spell = 382021, enchant = 6498 },
    { key = "TIDECALLER", spell = 457481, enchant = 7528, shield = true },
    { key = "TSTRIKE", spell = 462757, enchant = 7587, shield = true },
}
local imbuesByKey = {}
for _, imbue in ipairs(imbues) do imbuesByKey[imbue.key] = imbue end
-- Self shields. Earth Shield uses 383648 for the Elemental Orbit self aura and
-- 974 for the normal Earth Shield buff; Water/Lightning share their spell IDs.
local shields = {
    { key = "EARTH_SHIELD", cast = EARTH_SHIELD_SPELL, buffs = { EARTH_SHIELD_SPELL, EARTH_SHIELD_SELF_AURA } },
    { key = "WATER_SHIELD", cast = WATER_SHIELD_SPELL, buffs = { WATER_SHIELD_SPELL } },
    { key = "LIGHTNING_SHIELD", cast = LIGHTNING_SHIELD_SPELL, buffs = { LIGHTNING_SHIELD_SPELL } },
}
local shieldsByKey = {}
for _, shield in ipairs(shields) do shieldsByKey[shield.key] = shield end
local specImbues = {
    [ENHANCEMENT] = { MAIN_HAND = "WINDFURY", OFF_HAND = "FLAMETONGUE" },
    [ELEMENTAL] = { MAIN_HAND = "FLAMETONGUE", OFF_HAND = "TSTRIKE" },
    [RESTORATION] = { MAIN_HAND = "EARTHLIVING", OFF_HAND = "TIDECALLER" },
}
local buffsByKey = {}
for _, buff in ipairs(buffs) do buffsByKey[buff.key] = buff end
PSA.RETAIL_BUFFS = buffs
PSA.RETAIL_IMBUES = imbues
PSA.RETAIL_SHIELDS = shields

-- Spell names and icons are fixed for an expansion. RefreshDisplay runs after
-- every relevant event, so query them once instead of once per refresh.
local spellNames, spellTextures = {}, {}
local function SpellName(spellID)
    local name = spellNames[spellID]
    if name == nil then
        name = C_Spell.GetSpellName(spellID)
        if name then spellNames[spellID] = name end
    end
    return name
end

local function SpellTexture(spellID)
    local texture = spellTextures[spellID]
    if texture == nil then
        texture = C_Spell.GetSpellTexture(spellID)
        if texture then spellTextures[spellID] = texture end
    end
    return texture or 134400
end

local function GetSavedSetting(key)
    local settings = PSA.InitDB().retailSupply
    if type(settings) == "table" then return settings[key] end
end

function PSA.GetRetailSupplySetting(key)
    local value = GetSavedSetting(key)
    if key == "CLASS" or key == "FOOD" or key == "WEAPON" or key == "SHIELD"
        or buffsByKey[key] or imbuesByKey[key] or shieldsByKey[key] then
        return value ~= false
    end
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
    return SpellName(buff.id) or PSA.UI["RETAIL_" .. buff.key]
end

function PSA.GetRetailImbueName(key)
    local imbue = imbuesByKey[key]
    if not imbue then return key end
    return SpellName(imbue.spell) or PSA.UI["RETAIL_" .. key]
end

function PSA.GetRetailShieldName(spellID)
    if spellID == EARTH_SHIELD_SPELL then return PSA.UI.RETAIL_EARTH_SHIELD end
    if spellID == WATER_SHIELD_SPELL then return PSA.UI.RETAIL_WATER_SHIELD end
    if spellID == LIGHTNING_SHIELD_SPELL then return PSA.UI.RETAIL_LIGHTNING_SHIELD end
    return SpellName(spellID) or PSA.UI.RETAIL_SHIELD
end

local function SpecShield()
    if PSA.GetPlayerSpecId() == RESTORATION then
        return "WATER_SHIELD", WATER_SHIELD_SPELL
    end
    return "LIGHTNING_SHIELD", LIGHTNING_SHIELD_SPELL
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

local foodEnabled, weaponEnabled, classEnabled, shieldEnabled, watchAuras, watching = false, false, false, false, false, false
local tracked, eligible, roster, permissions, lastWhisper = {}, {}, {}, {}, {}
local instances, counts, foodExpirations = {}, {}, {}
local aurasKnown, weaponStates, expectedImbues = false, {}, {}
local shieldPlan = {}
local masterEnabled = false
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
    local nextImbues = {}
    if weaponEnabled and PSA.GetPlayerClassFile() == "SHAMAN" then
        local plan = specImbues[PSA.GetPlayerSpecId()]
        if plan then
            for hand, key in pairs(plan) do
                local imbue = imbuesByKey[key]
                if imbue and PSA.IsKnownPlayerSpell(imbue.spell) then
                    nextImbues[hand] = key
                end
            end
        end
    end
    local changed = false
    for _, hand in ipairs(hands) do
        if expectedImbues[hand.key] ~= nextImbues[hand.key] then
            expectedImbues[hand.key] = nextImbues[hand.key]
            changed = true
        end
    end
    return changed
end

local function UpdateShieldPlan()
    local nextPlan = {}
    if shieldEnabled then
        local orbit = PSA.IsKnownPlayerSpell(ELEMENTAL_ORBIT)
        local specKey, specID = SpecShield()
        if orbit then
            if PSA.GetRetailSupplySetting("EARTH_SHIELD") and PSA.IsKnownPlayerSpell(EARTH_SHIELD_SPELL) then
                nextPlan.earth = true
                tracked[EARTH_SHIELD_SPELL] = "EARTH_SHIELD"
                tracked[EARTH_SHIELD_SELF_AURA] = "EARTH_SHIELD"
            end
            if PSA.GetRetailSupplySetting(specKey) and PSA.IsKnownPlayerSpell(specID) then
                nextPlan.spec = specKey
                nextPlan.specID = specID
                tracked[specID] = specKey
            end
        else
            local first
            for _, shield in ipairs(shields) do
                if PSA.GetRetailSupplySetting(shield.key) and PSA.IsKnownPlayerSpell(shield.cast) then
                    first = first or shield
                    for _, id in ipairs(shield.buffs) do tracked[id] = shield.key end
                end
            end
            if first then
                nextPlan.combined = true
                if PSA.GetRetailSupplySetting(specKey) and PSA.IsKnownPlayerSpell(specID) then
                    nextPlan.castID = specID
                else
                    nextPlan.castID = first.cast
                end
            end
        end
    end
    local changed = shieldPlan.earth ~= nextPlan.earth or shieldPlan.spec ~= nextPlan.spec
        or shieldPlan.specID ~= nextPlan.specID or shieldPlan.combined ~= nextPlan.combined
        or shieldPlan.castID ~= nextPlan.castID
    shieldPlan = nextPlan
    return changed
end

local function ReadWeapons()
    weaponStates = {}
    if not weaponEnabled or IsSuspended() or not (C_Item and C_Item.GetItemInfoInstant
        and C_PaperDollInfo and C_PaperDollInfo.GetTemporaryEnchantmentInfo) then return end
    local isShaman = PSA.GetPlayerClassFile() == "SHAMAN"
    local now = weaponLead > 0 and GetTime()
    for _, hand in ipairs(hands) do
        local imbueKey = expectedImbues[hand.key]
        local imbue = imbueKey and imbuesByKey[imbueKey]
        -- Non-shamans use the generic temporary-enchantment reminder; shamans get
        -- only their current specialization's known imbues (and only for the
        -- matching weapon or shield slot).
        if not isShaman or imbue then
            local item = GetInventoryItemID("player", hand.slot)
            if IsAccessible(item) and item then
                local _, _, _, _, icon, class, subclass = C_Item.GetItemInfoInstant(item)
                local isWeapon = IsAccessible(class) and class == Enum.ItemClass.Weapon
                    and IsAccessible(subclass) and subclass ~= Enum.ItemWeaponSubclass.Fishingpole
                local isShield = IsAccessible(class) and class == Enum.ItemClass.Armor
                    and IsAccessible(subclass) and subclass == Enum.ItemArmorSubclass.Shield
                local eligible = imbue and (imbue.shield and isShield or (not imbue.shield and isWeapon))
                    or (not imbue and isWeapon)
                if eligible and (not imbue or PSA.GetRetailSupplySetting(imbue.key)) then
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
                        if imbue then icon = SpellTexture(imbue.spell) end
                        weaponStates[hand.key] = {
                            icon = IsAccessible(icon) and icon or 134400,
                            missing = missing, expiration = expiration, imbue = imbue and imbue.key,
                        }
                    end
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
                            icon = SpellTexture(buff.id), action = action,
                            member = member, ready = ready,
                        }
                    end
                end
            end
            if shieldEnabled and shieldPlan then
                local earthReadable = CanReadSpell(EARTH_SHIELD_SPELL) and CanReadSpell(EARTH_SHIELD_SELF_AURA)
                local waterReadable = CanReadSpell(WATER_SHIELD_SPELL)
                local lightningReadable = CanReadSpell(LIGHTNING_SHIELD_SPELL)
                if shieldPlan.earth and earthReadable and (counts.EARTH_SHIELD or 0) == 0 then
                    displayed.EARTH_SHIELD = {
                        icon = SpellTexture(EARTH_SHIELD_SPELL),
                        action = "shield", spellID = EARTH_SHIELD_SPELL,
                    }
                end
                if shieldPlan.spec and (counts[shieldPlan.spec] or 0) == 0 then
                    local readable = (shieldPlan.spec == "WATER_SHIELD" and waterReadable)
                        or (shieldPlan.spec == "LIGHTNING_SHIELD" and lightningReadable)
                    if readable then
                        displayed[shieldPlan.spec] = {
                            icon = SpellTexture(shieldPlan.specID),
                            action = "shield", spellID = shieldPlan.specID,
                        }
                    end
                end
                if shieldPlan.combined and earthReadable and waterReadable and lightningReadable
                    and (counts.EARTH_SHIELD or 0) + (counts.WATER_SHIELD or 0) + (counts.LIGHTNING_SHIELD or 0) == 0 then
                    displayed.SHIELD = {
                        icon = SpellTexture(shieldPlan.castID),
                        action = "shield", spellID = shieldPlan.castID,
                    }
                end
            end
        end
    end
    SetReminderWake(nextWake, RefreshDisplay)
    PSA.RenderRetailSupplyAlerts(displayed, foodEnabled or weaponEnabled or classEnabled or shieldEnabled)
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
        if not masterEnabled then return end
        if dirtyPlan then
            if BuildAuraPlan() then dirtyAuras = true end
            if UpdateShieldPlan() then dirtyAuras = true end
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
    if alert.action == "shield" then
        return PSA.UI.RETAIL_SHIELD_MISSING:format(PSA.GetRetailShieldName(alert.spellID)), PSA.UI.RETAIL_BUFF_CAST
    end
    if not buff then
        if alert.imbue then
            local imbue = imbuesByKey[alert.imbue]
            if not imbue then return end
            local slot = imbue.shield and "SHIELD" or (key == "MAIN_HAND" and "MAIN" or "OFF")
            local formatString = PSA.UI["RETAIL_IMBUE_" .. slot .. (alert.expiration and "_EXPIRING" or "_MISSING")]
            if formatString then return formatString:format(PSA.GetRetailImbueName(alert.imbue)) end
            return
        end
        local label = "RETAIL_" .. key
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
    if not alert then return end
    if alert.action == "shield" then
        if not shieldEnabled or not aurasKnown or not CanReadAuras()
            or not PSA.IsKnownPlayerSpell(alert.spellID) or not CanReadSpell(alert.spellID) then return end
        if key == "SHIELD" then
            if (counts.EARTH_SHIELD or 0) + (counts.WATER_SHIELD or 0) + (counts.LIGHTNING_SHIELD or 0) > 0 then return end
        elseif (counts[key] or 0) > 0 then
            return
        end
        return alert.spellID
    end
    if not buff or not classEnabled or not PSA.GetRetailSupplySetting(key) or dirtyPlan or dirtyRoster
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
local talentEvents = { "PLAYER_SPECIALIZATION_CHANGED", "SPELLS_CHANGED", "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED" }
local weaponEvents = { "PLAYER_EQUIPMENT_CHANGED", "WEAPON_ENCHANT_CHANGED" }

local function SetEvents(events, active)
    for _, event in ipairs(events) do
        if active then eventFrame:RegisterEvent(event) else eventFrame:UnregisterEvent(event) end
    end
end

eventFrame:SetScript("OnEvent", function(_, event, value, status)
    if not masterEnabled then return end
    if event == "CAN_LOCAL_WHISPER_TARGET_RESPONSE" then
        local info = IsAccessible(value) and permissions[value]
        if info and IsAccessible(status) then
            info.status = status
            QueueRefresh()
        end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        if value == hands[1].slot or value == hands[2].slot then QueueRefresh(false, false, false, true) end
    elseif event == "WEAPON_ENCHANT_CHANGED" then
        QueueRefresh(false, false, false, true)
    elseif event == "GROUP_ROSTER_UPDATE" or event == "UNIT_CONNECTION" then
        if event == "GROUP_ROSTER_UPDATE" or (IsAccessible(value) and value
            and (value:match("^party%d+$") or value:match("^raid%d+$"))) then
            QueueRefresh(false, true)
        end
    elseif event == "SPELLS_CHANGED" or event == "PLAYER_SPECIALIZATION_CHANGED"
        or event == "PLAYER_TALENT_UPDATE" or event == "TRAIT_CONFIG_UPDATED" then
        if event ~= "PLAYER_SPECIALIZATION_CHANGED" or value == "player" then QueueRefresh(true) end
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
    masterEnabled = PSA.GetBuffAlertsEnabled()
    if not masterEnabled then
        foodEnabled, weaponEnabled, classEnabled, shieldEnabled = false, false, false, false
        foodLead, weaponLead = 0, 0
        watching, watchAuras = false, false
        SetEvents(commonEvents, false)
        SetEvents(classEvents, false)
        SetEvents(talentEvents, false)
        SetEvents(weaponEvents, false)
        eventFrame:UnregisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
        PSA.SetRetailSupplyAuraWatch(false)
        SetReminderWake(nil)
        displayed = {}
        instances, counts, foodExpirations = {}, {}, {}
        tracked, eligible, expectedImbues, shieldPlan = {}, {}, {}, {}
        weaponStates = {}
        roster, permissions = {}, {}
        aurasKnown = false
        PSA.RenderRetailSupplyAlerts(displayed, false)
        return
    end
    foodEnabled = PSA.GetRetailSupplySetting("FOOD")
    weaponEnabled = PSA.GetRetailSupplySetting("WEAPON")
    classEnabled = PSA.GetRetailSupplySetting("CLASS")
    local playerClass = PSA.GetPlayerClassFile()
    local isShaman = playerClass == "SHAMAN"
    shieldEnabled = (not playerClass or isShaman) and PSA.GetRetailSupplySetting("SHIELD")
    foodLead = foodEnabled and PSA.GetRetailSupplyLeadMinutes("FOOD") * 60 or 0
    weaponLead = weaponEnabled and PSA.GetRetailSupplyLeadMinutes("WEAPON") * 60 or 0
    local active = foodEnabled or weaponEnabled or classEnabled or shieldEnabled
    if active ~= watching then
        watching = active
        inEncounter = active and C_InstanceEncounter and C_InstanceEncounter.IsEncounterInProgress() or false
        SetEvents(commonEvents, active)
    end
    if foodEnabled or classEnabled or shieldEnabled or weaponLead > 0 then eventFrame:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
    else eventFrame:UnregisterEvent("ADDON_RESTRICTION_STATE_CHANGED") end
    SetEvents(classEvents, classEnabled)
    SetEvents(talentEvents, classEnabled or shieldEnabled or (weaponEnabled and isShaman))
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
