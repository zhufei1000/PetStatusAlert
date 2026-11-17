-------------------------------------------------
-- Client-specific rules shared by runtime and settings
-------------------------------------------------

local _, PSA = ...
PSA = PSA or _G.PetStatusAlert

local interfaceVersion = type(GetBuildInfo) == "function" and tonumber((select(4, GetBuildInfo()))) or 0
local isForever = interfaceVersion >= 16000 and interfaceVersion < 17000

function PSA.IsForeverClient()
    return isForever
end

function PSA.IsAccessibleValue(value)
    return type(issecretvalue) ~= "function" or not issecretvalue(value)
end

if isForever and C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
    and C_UnitAuras.GetPlayerAuraBySpellID and C_Spell and C_Spell.GetSpellName then
    local WELL_FED = 19705
    -- Some foods also have older effects with a separate aura ID.
    local foodAuraByItem = {
        [13810] = 18125, -- Blessed Sunfruit
        [13813] = 18141, -- Blessed Sunfruit Juice
        [13928] = 18192, -- Grilled Squid
        [13931] = 18194, -- Nightfin Soup
        [18254] = 22730, -- Runn Tum Tuber Surprise
        [21023] = 25661, -- Dirge's Kickin' Chimaerok Chops
    }
    local namedFoodAuras = {}
    for _, auraID in pairs(foodAuraByItem) do namedFoodAuras[auraID] = true end
    local wellFedName
    local accessible = PSA.IsAccessibleValue

    local function ReadableTable(value)
        return accessible(value) and (type(value) ~= "table" or not canaccesstable or canaccesstable(value))
    end

    function PSA.HasKnownFoodAura(itemID)
        return foodAuraByItem[itemID] ~= nil
    end

    function PSA.CanReadFoodAuras()
        return not (C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret())
    end

    local function SpellAuraReadable(id)
        return not (C_Secrets and C_Secrets.ShouldSpellAuraBeSecret and C_Secrets.ShouldSpellAuraBeSecret(id))
    end

    local function InstanceID(aura)
        local id = aura.auraInstanceID
        if accessible(id) and type(id) == "number" then return id end
    end

    -- true = present, false = confirmed missing, nil = unreadable.
    function PSA.ReadFoodBuff()
        if not PSA.CanReadFoodAuras() then return end
        if not wellFedName then
            local name = C_Spell.GetSpellName(WELL_FED)
            if accessible(name) and type(name) == "string" and name ~= "" then wellFedName = name end
        end
        local unknown = not wellFedName or not SpellAuraReadable(WELL_FED)
        if not unknown then
            local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", wellFedName, "HELPFUL")
            if not ok or not ReadableTable(aura) then
                unknown = true
            elseif aura then
                return true, InstanceID(aura)
            end
        end

        local present
        for id in pairs(namedFoodAuras) do
            if SpellAuraReadable(id) then
                local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
                if not ok or not ReadableTable(aura) then
                    unknown = true
                elseif aura then
                    present = true
                    local instanceID = InstanceID(aura)
                    if instanceID then return true, instanceID end
                end
            else
                unknown = true
            end
        end
        if present then return true end
        if not unknown then return false end
    end

    function PSA.FoodAuraMayHaveChanged(update, present, instanceID)
        if not ReadableTable(update) then return false end
        if not update then return true end
        local full = update.isFullUpdate
        if accessible(full) and full then return true end

        if present then
            local removed = update.removedAuraInstanceIDs
            if ReadableTable(removed) and removed then
                for _, id in ipairs(removed) do
                    if accessible(id) and (not instanceID or id == instanceID) then return true end
                end
            end
            -- A duration update leaves the tracked instance in place.
            return false
        end

        local added = update.addedAuras
        if not ReadableTable(added) or not added then return false end
        for _, aura in ipairs(added) do
            if ReadableTable(aura) then
                local id, name, helpful = aura.spellId, aura.name, aura.isHelpful
                if accessible(helpful) and helpful
                    and ((accessible(id) and (id == WELL_FED or namedFoodAuras[id]))
                        or (wellFedName and accessible(name) and name == wellFedName)) then
                    return true
                end
            end
        end
        return false
    end
end

function PSA.IsBelowForeverLevelCap(level)
    if level == nil and UnitLevel then level = UnitLevel("player") end
    local cap = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion()
    if not PSA.IsAccessibleValue(cap) or type(cap) ~= "number" or cap <= 0 then cap = 60 end
    return PSA.IsAccessibleValue(level) and type(level) == "number" and level > 0 and level < cap
end

function PSA.GetPlayerClassFile()
    if type(UnitClass) == "function" then
        local _, classFile = UnitClass("player")
        if PSA.IsAccessibleValue(classFile) then
            return classFile
        end
    end
end

local rangedSlot, ammoSlot, emptyAmmoTexture
local PROJECTILE_ARROW, PROJECTILE_BULLET = 2, 3
local ammoItemInfo = {}

local function ResolveAmmoSlots()
    if not rangedSlot or not ammoSlot then
        rangedSlot = C_PaperDollInfo.GetInventorySlotInfo("RangedSlot")
        ammoSlot, emptyAmmoTexture = C_PaperDollInfo.GetInventorySlotInfo("AmmoSlot")
    end
    return rangedSlot and ammoSlot
end

local function GetAmmoItemInfo(itemID)
    local info = ammoItemInfo[itemID]
    if not info then
        local _, _, _, _, icon, class, subclass = C_Item.GetItemInfoInstant(itemID)
        if not class then
            return
        end
        info = { class = class, subclass = subclass, icon = icon }
        ammoItemInfo[itemID] = info
    end
    return info
end

local function GetForeverAmmo()
    if not UnitUsesAmmo("player") or not C_PaperDollInfo.AmmoNeeded() then
        return
    end

    if not ResolveAmmoSlots() then
        return
    end

    local weaponID = GetInventoryItemID("player", rangedSlot)
    if not PSA.IsAccessibleValue(weaponID) or not weaponID then
        return
    end
    local weapon = GetAmmoItemInfo(weaponID)
    local subclasses = Enum.ItemWeaponSubclass
    if not weapon or weapon.class ~= Enum.ItemClass.Weapon then
        return
    end

    local kind, projectileType
    local weaponType = weapon.subclass
    if weaponType == subclasses.Bows or weaponType == subclasses.Crossbow then
        kind, projectileType = "LOW_ARROWS", PROJECTILE_ARROW
    elseif weaponType == subclasses.Guns then
        kind, projectileType = "LOW_BULLETS", PROJECTILE_BULLET
    else
        return
    end

    local ammoID = GetInventoryItemID("player", ammoSlot)
    if not PSA.IsAccessibleValue(ammoID) then
        return kind
    end
    if ammoID then
        local ammo = GetAmmoItemInfo(ammoID)
        if not ammo then
            return kind
        end
        if ammo.class == Enum.ItemClass.Projectile and ammo.subclass == projectileType then
            -- Match the character sheet's ammo count. The empty slot has no count.
            local count = GetInventoryItemCount("player", ammoSlot)
            if PSA.IsAccessibleValue(count) and type(count) == "number" then
                return kind, count, ammo.icon or GetInventoryItemTexture("player", ammoSlot) or emptyAmmoTexture
            end
            return kind
        end
    end
    return kind, 0, emptyAmmoTexture
end

if isForever and UnitUsesAmmo and C_PaperDollInfo and C_PaperDollInfo.AmmoNeeded and C_PaperDollInfo.GetInventorySlotInfo
    and GetInventoryItemID and GetInventoryItemCount and GetInventoryItemTexture and C_Item and C_Item.GetItemInfoInstant
    and Enum and Enum.ItemClass and Enum.ItemWeaponSubclass then
    PSA.GetForeverAmmo = GetForeverAmmo
    function PSA.IsForeverAmmoEquipmentSlot(slot)
        -- Unknown slot data must not suppress an equipment refresh.
        return not PSA.IsAccessibleValue(slot) or type(slot) ~= "number"
            or not ResolveAmmoSlots() or slot == rangedSlot or slot == ammoSlot
    end
end

function PSA.GetPlayerSpecId()
    -- Forever has no specializations, even if the shared client exposes these APIs.
    if isForever then
        return 0
    end
    local getSpec = GetSpecialization or (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization)
    local getInfo = GetSpecializationInfo or (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo)
    if type(getSpec) ~= "function" or type(getInfo) ~= "function" then
        return 0
    end
    local index = getSpec()
    if not index or index <= 0 then
        return 0
    end
    return tonumber((getInfo(index))) or 0
end

local foreverPetSpells = {
    HUNTER = { 883 }, -- Call Pet: do not warn before the player can summon a pet.
    WARLOCK = { 688, 697, 712, 713, 691, 30146 },
}

function PSA.SupportsForeverPetClass(classFile, isKnownSpell)
    if classFile == "MAGE" then
        return not PSA.GetClassOption("mageRequireSummon") or isKnownSpell(PSA.GetClassOption("mageSummonID"))
    end
    for _, spellID in ipairs(foreverPetSpells[classFile] or {}) do
        if isKnownSpell(spellID) then
            return true
        end
    end
    return false
end

function PSA.IsNormalPetMode(mode)
    return mode == "ASSIST"
end

local retailPetStatuses = { "NO_PET", "PET_DEAD", "PASSIVE", "DEFENSIVE", "UNKNOWN" }
local foreverPetStatuses = { "NO_PET", "PET_DEAD", "PASSIVE", "DEFENSIVE", "AGGRESSIVE", "UNKNOWN" }
PSA.PET_STATUS_ORDER = isForever and foreverPetStatuses or retailPetStatuses

local retailClasses = { "HUNTER", "WARLOCK", "MAGE", "DEATHKNIGHT", "WARRIOR" }
local foreverClasses = { "HUNTER", "WARLOCK", "MAGE", "WARRIOR" }
local settingsClasses = { "HUNTER", "WARLOCK", "MAGE", "DEATHKNIGHT", "WARRIOR" }
PSA.WARRIOR_STATUS_KEY = "WARRIOR_DEFENSIVE_STANCE"
PSA.WRONG_PET_STATUS_KEY = "WARLOCK_WRONG_PET"
PSA.WARLOCK_SPECS = { 265, 266, 267 }
local warriorStatuses = { PSA.WARRIOR_STATUS_KEY }
-- Paladin wrong-aura alerts are intentionally disabled for now. Keep the aura
-- rank table because the Class Buffs tab still uses it for the missing-aura
-- reminder, and ForeverBuffs reads the active aura through the form API.
local paladinAuraEntries = {
    { "FOREVER_PALADIN_DEVOTION", {465, 10290, 643, 10291, 1032, 10292, 10293} },
    { "FOREVER_PALADIN_RETRIBUTION", {7294, 10298, 10299, 10300, 10301} },
    { "FOREVER_PALADIN_CONCENTRATION", {19746} },
    { "FOREVER_PALADIN_SHADOW_RESISTANCE", {19876, 19895, 19896} },
    { "FOREVER_PALADIN_FROST_RESISTANCE", {19888, 19897, 19898} },
    { "FOREVER_PALADIN_FIRE_RESISTANCE", {19891, 19899, 19900} },
}
local foreverFormAlerts = {
    WARRIOR = {
        { "FOREVER_WARRIOR_BATTLE", {2457} },
        { "FOREVER_WARRIOR_DEFENSIVE", {71} },
        { "FOREVER_WARRIOR_BERSERKER", {2458} },
    },
}
local formStatuses, formKeysBySpell, formIconSpells = {}, {}, {}
for classFile, entries in pairs(foreverFormAlerts) do
    local statuses, spellKeys = {}, {}
    for index, entry in ipairs(entries) do
        local key, ranks = entry[1], entry[2]
        statuses[index] = key
        formIconSpells[key] = ranks[1]
        for _, id in ipairs(ranks) do spellKeys[id] = key end
    end
    formStatuses[classFile], formKeysBySpell[classFile] = statuses, spellKeys
end
PSA.FOREVER_FORM_ALERT_SPELLS = formIconSpells

function PSA.GetForeverFormAlertStatuses(classFile)
    return formStatuses[classFile]
end

function PSA.GetForeverFormAlertBySpell(classFile, spellID)
    local spellKeys = formKeysBySpell[classFile]
    if spellKeys then return spellKeys[spellID] end
end

-- The missing-aura reminder prefers the highest known rank of Devotion Aura.
-- Keep the Paladin spell mapping even though the wrong-aura status page is off.
local paladinAuraSpells = {}
local paladinSpellKeys = formKeysBySpell.PALADIN or {}
for index = #paladinAuraEntries, 1, -1 do
    local key, ranks = paladinAuraEntries[index][1], paladinAuraEntries[index][2]
    for _, id in ipairs(ranks) do
        paladinSpellKeys[id] = key
        paladinAuraSpells[#paladinAuraSpells + 1] = id
    end
end
formKeysBySpell.PALADIN = paladinSpellKeys
PSA.FOREVER_PALADIN_AURA_SPELLS = paladinAuraSpells

-- Modern clients return icon, active, castable, spellID. Some Classic-era
-- interfaces still return icon, name, active, castable, spellID. Normalize both
-- so Forever/Wrath-era API differences cannot silently disable stance alerts.
local function ReadShapeshiftForm(index)
    local _, second, third, fourth, fifth = GetShapeshiftFormInfo(index)
    if type(second) == "string" then
        return third, fifth
    end
    return second, fourth
end

if isForever and type(GetNumShapeshiftForms) == "function" and type(GetShapeshiftFormInfo) == "function" then
    function PSA.ReadForeverFormAlert(classFile)
        local spellKeys = formKeysBySpell[classFile]
        if not spellKeys then return end
        local count = GetNumShapeshiftForms()
        if not PSA.IsAccessibleValue(count) or type(count) ~= "number" then return end
        for index = 1, count do
            local active, spellID = ReadShapeshiftForm(index)
            if PSA.IsAccessibleValue(active) and active and PSA.IsAccessibleValue(spellID) then
                return spellKeys[spellID]
            end
        end
    end

    -- Any active aura on the Paladin bar satisfies the generic "Paladin auras"
    -- reminder, including a rank this build does not know about. Do not require
    -- the form spell ID to be in our rank table here: a missing rank would
    -- otherwise trigger a false "no aura" warning while an aura is active.
    function PSA.HasActiveForeverForm(classFile)
        local spellKeys = formKeysBySpell[classFile]
        if not spellKeys then return end
        local count = GetNumShapeshiftForms()
        if not PSA.IsAccessibleValue(count) or type(count) ~= "number" then return end
        for index = 1, count do
            local active, spellID = ReadShapeshiftForm(index)
            if PSA.IsAccessibleValue(active) and active then
                if classFile == "PALADIN" then return true end
                if PSA.IsAccessibleValue(spellID) and spellKeys[spellID] then return true end
            end
        end
        return false
    end
end

local function WarlockStatuses(petStatuses)
    local statuses = {}
    for index, statusKey in ipairs(petStatuses) do
        statuses[index] = statusKey
    end
    statuses[#statuses + 1] = PSA.WRONG_PET_STATUS_KEY
    return statuses
end
local retailWarlockStatuses = WarlockStatuses(retailPetStatuses)
local foreverWarlockStatuses = WarlockStatuses(foreverPetStatuses)

local retailDemonFamilies = { 23, 16, 15, 17, 29 }
local foreverDemonFamilies = { 23, 16, 15, 17 }
-- Incubus (302) and Succubus (17) share the Sayaad rule on both clients.
-- The other aliases are alternate appearances in the Retail CreatureFamily table.
local demonFamilyAliases = { [100] = 23, [101] = 16, [102] = 17, [103] = 15, [104] = 29, [302] = 17 }
local demonFamilyNames

function PSA.GetWarlockPetFamilies(forever)
    return forever and foreverDemonFamilies or retailDemonFamilies
end

function PSA.GetActiveWarlockPetFamily()
    if type(UnitCreatureFamily) ~= "function" then return end
    local name, familyID = UnitCreatureFamily("pet")
    if not PSA.IsAccessibleValue(familyID) then return end
    if type(familyID) == "number" and familyID > 0 then
        return demonFamilyAliases[familyID] or familyID
    end
    if not PSA.IsAccessibleValue(name) or type(name) ~= "string" then return end
    if not demonFamilyNames then
        demonFamilyNames = { [PSA.GetWarlockPetLabel(302, true)] = demonFamilyAliases[302] }
        local getInfo = C_CreatureInfo and C_CreatureInfo.GetCreatureFamilyInfo
        for _, id in ipairs(PSA.GetWarlockPetFamilies(isForever)) do
            demonFamilyNames[PSA.GetWarlockPetLabel(id, true)] = id
            local info = getInfo and getInfo(id)
            if info and info.name then demonFamilyNames[info.name] = id end
        end
        if getInfo then
            for alias, id in pairs(demonFamilyAliases) do
                if not isForever or alias == 302 then
                    local info = getInfo(alias)
                    if info and info.name then demonFamilyNames[info.name] = id end
                end
            end
        end
    end
    return demonFamilyNames[name]
end

function PSA.GetAlertClasses(forever)
    return forever and foreverClasses or retailClasses
end

function PSA.GetAlertSettingsClasses()
    -- Paladin is a Forever-only class; do not add a dead Paladin page to the
    -- Retail settings. Forever keeps all classes so the read-only Retail pages
    -- remain available there.
    if isForever then return settingsClasses end
    return retailClasses
end

function PSA.GetClassAlertStatuses(classFile, forever)
    if forever == nil then
        forever = isForever
    end
    for _, supported in ipairs(PSA.GetAlertClasses(forever)) do
        if supported == classFile then
            if forever and formStatuses[classFile] then return formStatuses[classFile] end
            if classFile == "WARRIOR" then return warriorStatuses end
            if classFile == "WARLOCK" then
                return forever and foreverWarlockStatuses or retailWarlockStatuses
            end
            return forever and foreverPetStatuses or retailPetStatuses
        end
    end
end
