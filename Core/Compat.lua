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
    WARLOCK = { 688, 697, 712, 691, 30146 },
    MAGE = { 31687 }, -- Enable only if this client actually grants Water Elemental.
}

function PSA.SupportsForeverPetClass(classFile, isKnownSpell)
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

PSA.PET_STATUS_ORDER = { "NO_PET", "PET_DEAD", "PASSIVE", "DEFENSIVE" }
if isForever then
    PSA.PET_STATUS_ORDER[#PSA.PET_STATUS_ORDER + 1] = "AGGRESSIVE"
end
PSA.PET_STATUS_ORDER[#PSA.PET_STATUS_ORDER + 1] = "UNKNOWN"
