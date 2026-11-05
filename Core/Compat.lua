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
