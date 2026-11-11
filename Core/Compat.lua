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

    if not ammoSlot then
        rangedSlot = C_PaperDollInfo.GetInventorySlotInfo("RangedSlot")
        ammoSlot, emptyAmmoTexture = C_PaperDollInfo.GetInventorySlotInfo("AmmoSlot")
    end
    if not rangedSlot or not ammoSlot then
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
local foreverClasses = { "HUNTER", "WARLOCK", "MAGE" }
PSA.WARRIOR_STATUS_KEY = "WARRIOR_DEFENSIVE_STANCE"
PSA.WRONG_PET_STATUS_KEY = "WARLOCK_WRONG_PET"
PSA.WARLOCK_SPECS = { 265, 266, 267 }
local warriorStatuses = { PSA.WARRIOR_STATUS_KEY }
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

function PSA.GetClassAlertStatuses(classFile, forever)
    if forever == nil then
        forever = isForever
    end
    for _, supported in ipairs(PSA.GetAlertClasses(forever)) do
        if supported == classFile then
            if classFile == "WARRIOR" then
                return warriorStatuses
            end
            if classFile == "WARLOCK" then
                return forever and foreverWarlockStatuses or retailWarlockStatuses
            end
            return forever and foreverPetStatuses or retailPetStatuses
        end
    end
end
