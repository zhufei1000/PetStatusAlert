-------------------------------------------------
-- Hunter pet autocast checks
-------------------------------------------------

local _, PSA = ...
if not PSA.IsForeverClient() then return end

local GROWL, COWER = 2649, 1742
local accessible = PSA.IsAccessibleValue
local spellBook = C_SpellBook
local petBank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet
if not (petBank and spellBook and spellBook.HasPetSpells and spellBook.GetSpellBookItemName
    and spellBook.GetSpellBookItemAutoCast and C_Spell and C_Spell.GetSpellName
    and IsInInstance and IsInRaid) then
    return
end

local names = {}
local function GetName(spellID)
    if names[spellID] then return names[spellID] end
    local name = C_Spell.GetSpellName(spellID)
    if accessible(name) and type(name) == "string" and name ~= "" then
        names[spellID] = name
        return name
    end
end

local function GetWantedGrowl()
    local raid = IsInRaid()
    if accessible(raid) and raid == true then return false end
    local inside, instanceType = IsInInstance()
    if not accessible(inside) or not accessible(instanceType) then return end
    if instanceType == "party" or instanceType == "raid" then return false end
    if accessible(raid) and raid == false and inside == false and instanceType == "none" then return true end
    -- Other instance types do not have a Growl rule.
end

local function GetMismatch()
    local exists = UnitExists("pet")
    if not accessible(exists) or not exists then return end
    local dead = UnitIsDeadOrGhost("pet")
    if not accessible(dead) or dead then return end
    local numSpells = spellBook.HasPetSpells()
    if not accessible(numSpells) or type(numSpells) ~= "number" or numSpells <= 0 then return end
    local growlName = GetName(GROWL)
    if not growlName then return end
    local cowerName = GetName(COWER)
    local growl, cower
    for index = 1, numSpells do
        -- Compare localized names so higher ranks on Forever are recognized.
        local name = spellBook.GetSpellBookItemName(index, petBank)
        if accessible(name) and (name == growlName or (cowerName and name == cowerName)) then
            local allowed, enabled = spellBook.GetSpellBookItemAutoCast(index, petBank)
            if accessible(allowed) and allowed and accessible(enabled) and type(enabled) == "boolean" then
                if name == growlName then growl = enabled else cower = enabled end
                if growl ~= nil and (not cowerName or cower ~= nil) then break end
            end
        end
    end
    if growl == nil then return end

    local wanted = GetWantedGrowl()
    if wanted ~= nil and growl ~= wanted then
        return GROWL, wanted, growlName
    end
    -- Only use the actual Growl state, after any earlier Growl mismatch is resolved.
    if cower ~= nil and cower == growl then
        return COWER, not growl, cowerName
    end
end

function PSA.RefreshPetAutocast()
    PSA.SetPetAutocastAlert(GetMismatch())
end
