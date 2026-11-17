local _, PSA = ...

-- Forever has the happiness and diet APIs used by the QFXUnitframes feeder.
if not PSA.IsForeverClient() or not C_PetInfo or not C_PetInfo.GetPetHappiness
    or not C_PetInfo.CanPetEatItem or not C_Container
    or not C_Container.GetContainerNumSlots or not C_Container.GetContainerItemInfo then
    return
end

local _, class = UnitClass("player")
local IsAccessible = PSA.IsAccessibleValue
if not IsAccessible(class) or class ~= "HUNTER" then
    return
end

local FEED_PET = 6991
local FEED_PET_EFFECT = 1539
local UNHAPPY, CONTENT = 1, 2
local LAST_BAG = NUM_TOTAL_EQUIPPED_BAG_SLOTS or 4
local feedButton
local characterGUID, sessionFoodID
-- bag -> { size, dirty, hasFood, first, entries, [slot] = entry|false }
local foodBags = {}
-- itemID -> edible. CanPetEatItem is purely item-based, so the same item must
-- not be re-queried for every bag slot after every pickup. The cache is bounded
-- so a long session with many distinct items cannot grow it without limit.
local canEatCache = {}
local canEatCacheSize = 0
local CAN_EAT_CACHE_LIMIT = 1024
local preferredCountCache

local function CanPetEatItem(itemID)
    if not itemID then return false end
    local edible = canEatCache[itemID]
    if edible == nil then
        local value = C_PetInfo.CanPetEatItem(itemID)
        if not IsAccessible(value) then return false end
        edible = value and true or false
        if canEatCacheSize < CAN_EAT_CACHE_LIMIT then
            canEatCache[itemID] = edible
            canEatCacheSize = canEatCacheSize + 1
        end
    end
    return edible
end

function PSA.InvalidatePetFood(bag)
    if bag == nil then
        preferredCountCache = nil
        for index = 0, LAST_BAG do
            local cache = foodBags[index]
            if cache then cache.dirty = true end
        end
        return
    end
    if type(bag) == "number" and bag >= 0 and bag <= LAST_BAG then
        preferredCountCache = nil
        local cache = foodBags[bag]
        if cache then cache.dirty = true end
        return true
    end
end

local function GetCharacterGUID()
    if not characterGUID then
        local guid = UnitGUID("player")
        if IsAccessible(guid) then
            characterGUID = guid
        end
    end
    return characterGUID
end

local function GetPreferredFood()
    local guid = GetCharacterGUID()
    if not guid then
        return sessionFoodID
    end
    local choices = PSA.InitDB().petFeedFoodByCharacter
    local itemID = type(choices) == "table" and choices[guid]
    if type(itemID) == "number" and itemID > 0 and itemID % 1 == 0 then
        return itemID
    end
end

local function SetPreferredFood(itemID)
    local guid = GetCharacterGUID()
    if not guid then
        sessionFoodID = itemID
        return
    end
    local db = PSA.InitDB()
    if type(db.petFeedFoodByCharacter) ~= "table" then
        if not itemID then
            return
        end
        db.petFeedFoodByCharacter = {}
    end
    db.petFeedFoodByCharacter[guid] = itemID
end

local function ResolvePreferredFood(useCache)
    local itemID = GetPreferredFood()
    if not itemID then
        preferredCountCache = nil
        return
    end
    local count
    if useCache and preferredCountCache and preferredCountCache.itemID == itemID then
        count = preferredCountCache.count
    else
        count = C_Item.GetItemCount(itemID)
        preferredCountCache = { itemID = itemID, count = count }
    end
    -- Wait until bags are available before treating a zero count as depletion.
    if count == 0 and C_Container.GetContainerNumSlots(0) > 0 then
        SetPreferredFood(nil)
        preferredCountCache = nil
        return
    end
    return itemID, count
end

local function HasLivingHunterPet()
    if not UnitExists("pet") or UnitIsDeadOrGhost("pet") then return false end
    local _, isHunterPet = HasPetUI()
    return IsAccessible(isHunterPet) and isHunterPet
end

local function GetHappiness()
    if PSA.IsPlayerMountedOrInVehicle() or UnitIsDeadOrGhost("player") or not HasLivingHunterPet() then
        return
    end
    local happiness = C_PetInfo.GetPetHappiness()
    if IsAccessible(happiness) and (happiness == UNHAPPY or happiness == CONTENT) then
        return happiness
    end
end

-- The feeding effect is only used out of combat and when its aura is public.
local function IsPetEating()
    local auras, secrets = C_UnitAuras, C_Secrets
    if not auras or not auras.GetUnitAuraBySpellID or not secrets or not secrets.ShouldAurasBeSecret then
        return false
    end
    local aurasSecret = secrets.ShouldAurasBeSecret()
    if not IsAccessible(aurasSecret) or aurasSecret then return false end
    if secrets.ShouldSpellAuraBeSecret then
        local spellSecret = secrets.ShouldSpellAuraBeSecret(FEED_PET_EFFECT)
        if not IsAccessible(spellSecret) or spellSecret then return false end
    end
    local ok, aura = pcall(auras.GetUnitAuraBySpellID, "pet", FEED_PET_EFFECT)
    if not ok then return false end
    return IsAccessible(aura) and aura ~= nil
end

local function FillFoodEntry(entry, item, slot)
    entry.itemID = item.itemID
    entry.stackCount = item.stackCount
    entry.iconFileID = item.iconFileID
    entry.itemName = item.itemName
    entry.isLocked = item.isLocked and true or false
    entry.slot = slot
    return entry
end

-- Mark one bag stale without discarding its per-slot entry tables. The next
-- FindFood pass re-probes lazily and reuses the entry table for each slot, so a
-- pickup burst does not allocate a table per bag slot.
local function PrepareBagCache(bag, cache)
    if not cache then
        cache = { size = -1, dirty = true, entries = {} }
        foodBags[bag] = cache
    end
    local size = C_Container.GetContainerNumSlots(bag)
    if cache.dirty or cache.size ~= size then
        local previousSize = cache.size
        if previousSize and previousSize > 0 then
            for slot = 1, previousSize do
                local entry = cache[slot]
                if type(entry) == "table" then
                    cache.entries[slot] = entry
                end
                cache[slot] = nil
            end
            if previousSize > size then
                for slot = size + 1, previousSize do
                    cache.entries[slot] = nil
                end
            end
        end
        cache.size = size
        cache.dirty = false
        cache.hasFood = false
        cache.first = nil
    end
    return cache, size
end

local function ProbeSlot(bag, cache, slot)
    local item = C_Container.GetContainerItemInfo(bag, slot)
    local entry
    if item and item.stackCount > 0 and CanPetEatItem(item.itemID) then
        entry = cache.entries[slot]
        if entry then
            FillFoodEntry(entry, item, slot)
        else
            entry = FillFoodEntry({}, item, slot)
            cache.entries[slot] = entry
        end
    end
    cache[slot] = entry or false
    return entry
end

-- Reuse a per-bag summary when only the current happiness changed. Without it
-- every UNIT_HAPPINESS tick walked every bag slot even though no bag event had
-- invalidated the cached contents. The scan stays lazy: a preferred food found
-- early stops the pass instead of re-reading the rest of the bag.
local function FindFood(preferredID, visitFood, useCache)
    local hasFood = false
    for bag = 0, LAST_BAG do
        if useCache then
            local cache, size = PrepareBagCache(bag, foodBags[bag])
            for slot = 1, size do
                local entry = cache[slot]
                if entry == nil then
                    entry = ProbeSlot(bag, cache, slot)
                end
                if entry then
                    cache.hasFood = true
                    if not entry.isLocked then
                        cache.first = cache.first or entry
                        if visitFood then
                            visitFood(entry)
                        elseif not preferredID or entry.itemID == preferredID then
                            return entry, bag, slot, true
                        end
                    end
                end
            end
            hasFood = hasFood or cache.hasFood
        else
            -- One-shot path used by clicks and item selection: always read live
            -- bag data so a stale lock flag can never feed the wrong slot.
            local size = C_Container.GetContainerNumSlots(bag)
            for slot = 1, size do
                local item = C_Container.GetContainerItemInfo(bag, slot)
                if item and item.stackCount > 0 and CanPetEatItem(item.itemID) then
                    hasFood = true
                    if not item.isLocked then
                        if visitFood then
                            visitFood(item)
                        elseif not preferredID or item.itemID == preferredID then
                            return item, bag, slot, true
                        end
                    end
                end
            end
        end
    end
    return nil, nil, nil, hasFood
end

local function ClearAction(button)
    button:SetAttribute("type1", nil)
    button:SetAttribute("target-bag1", nil)
    button:SetAttribute("target-slot1", nil)
end

local function PrepareClick(button, mouseButton)
    if InCombatLockdown() then
        return
    end
    ClearAction(button)
    if mouseButton ~= "LeftButton" or not PSA.InitDB().alertLocked or not button:IsVisible() or SpellIsTargeting() or GetCursorInfo()
        or not PSA.GetClassOption("petFeedEnabled") or not GetHappiness() or not PSA.IsKnownPlayerSpell(FEED_PET)
        or IsPetEating() then
        return
    end

    -- Recheck the slot after bag sorting, trading, or consuming food.
    local preferredID = ResolvePreferredFood()
    local food, bag, slot = FindFood(preferredID)
    if food then
        button:SetAttribute("target-bag1", bag)
        button:SetAttribute("target-slot1", slot)
        button:SetAttribute("type1", "spell")
    end
end

local function GetFoodName(itemID, name)
    name = name or C_Item.GetItemNameByID(itemID)
    return name and name ~= "" and name or "#" .. itemID
end

local function RefreshTooltip(button)
    local tooltip = GameTooltip
    if not tooltip or tooltip:IsForbidden() or not tooltip:IsOwned(button) then
        return
    end
    tooltip:SetSpellByID(FEED_PET)
    if button.foodName then
        tooltip:AddLine(PSA.UI.FEED_FOOD_REMAINING:format(button.foodName, button.foodCount), 1, 1, 1, true)
        if not button.foodAvailable then
            tooltip:AddLine(PSA.UI.FEED_FOOD_UNAVAILABLE, 1, 0.5, 0.4)
        end
    end
    tooltip:AddLine(PSA.UI.FEED_CHOOSE_HINT, 0.8, 0.8, 0.8)
    tooltip:Show()
end

local function HideTooltip(button)
    if GameTooltip and not GameTooltip:IsForbidden() and GameTooltip:IsOwned(button) then
        GameTooltip:Hide()
    end
end

function PSA.GetPetFeedFoodChoice()
    return GetPreferredFood() or 0
end

function PSA.SetPetFeedFoodChoice(itemID)
    if InCombatLockdown() then return false end
    if itemID ~= 0 and (not HasLivingHunterPet() or not FindFood(itemID)) then
        return false
    end
    SetPreferredFood(itemID ~= 0 and itemID or nil)
    PSA.RefreshPetCare()
    return true
end

local function ForEachFoodChoice(addChoice, showHint, useCache)
    addChoice(0, PSA.UI.FEED_CHOOSE_AUTO)
    if not HasLivingHunterPet() then
        showHint(PSA.UI.FEED_REQUIRES_PET)
        return false
    end
    local seen = {}
    FindFood(nil, function(food)
        local itemID = food.itemID
        if not seen[itemID] then
            seen[itemID] = true
            local label = ("%s ×%d"):format(GetFoodName(itemID, food.itemName), C_Item.GetItemCount(itemID))
            addChoice(itemID, label)
        end
    end, useCache)
    if next(seen) then return true end
    showHint(PSA.UI.FEED_FOOD_UNAVAILABLE)
    return false
end

function PSA.GetPetFeedFoodChoices()
    local choices = {}
    ForEachFoodChoice(function(itemID, label)
        choices[#choices + 1] = {key = itemID, label = label}
    end, function(label)
        choices[#choices + 1] = {label = label, disabled = true}
    end)
    return choices
end

local function AddFoodChoices(root, canChoose, onChange, useCache)
    local function IsSelected(itemID) return PSA.GetPetFeedFoodChoice() == itemID end
    local function SelectFood(itemID)
        if canChoose() and PSA.SetPetFeedFoodChoice(itemID) and onChange then onChange() end
    end
    root:CreateTitle(PSA.UI.FEED_CHOOSE_TITLE)
    local hasFood = ForEachFoodChoice(function(itemID, label)
        root:CreateRadio(label, IsSelected, SelectFood, itemID)
    end, function(label)
        root:CreateTitle(label)
    end, useCache)
    if hasFood then root:SetScrollMode(240) end
end

local function BuildFoodMenu(button, root)
    root:AddMenuReleasedCallback(function(menu)
        if button.foodMenu == menu then
            button.foodMenu = nil
        end
    end)
    AddFoodChoices(root, function() return button:IsVisible() and GetHappiness() end, nil, true)
end

function PSA.GetPetFeedFoodLabel()
    local itemID = ResolvePreferredFood()
    return itemID and GetFoodName(itemID) or PSA.UI.FEED_CHOOSE_AUTO
end

function PSA.OpenPetFoodSettingsMenu(owner, onChange)
    if InCombatLockdown() or not MenuUtil or not owner:IsVisible() then return end
    return MenuUtil.CreateContextMenu(owner, function(_, root)
        AddFoodChoices(root, function() return owner:IsVisible() end, onChange)
    end)
end

local function RefreshFoodMenu(button)
    local menu = button.foodMenu
    if menu then
        local root = MenuUtil.CreateRootMenuDescription(MenuVariants.GetDefaultContextMenuMixin())
        Menu.PopulateDescription(BuildFoodMenu, button, root)
        menu:SetMenuDescription(root)
    end
end

local function CreateFeedButton()
    -- This template handles the player's click and blocks actions in combat.
    -- It does not inherit SecureFrameTemplate, so the alert can still move in combat.
    local parent = PSA.GetPetCareFrame()
    local button = CreateFrame("Button", nil, parent, "InsecureActionButtonTemplate")
    button:SetAllPoints(parent)
    button:EnableMouse(PSA.InitDB().alertLocked)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetAttribute("useOnKeyDown", false)
    button:SetAttribute("spell1", FEED_PET)
    local count = button:CreateFontString(nil, "OVERLAY")
    count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    count:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    count:SetJustifyH("RIGHT")
    button.count = count

    button:SetScript("PreClick", PrepareClick)
    button:SetScript("PostClick", function(self, mouseButton)
        if InCombatLockdown() then
            return
        end
        ClearAction(self)
        if mouseButton == "RightButton" and PSA.InitDB().alertLocked and self:IsVisible() and GetHappiness() and MenuUtil then
            HideTooltip(self)
            self.foodMenu = MenuUtil.CreateContextMenu(self, BuildFoodMenu)
        end
    end)
    button:SetScript("OnEnter", function(self)
        if GameTooltip and not GameTooltip:IsForbidden() then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            RefreshTooltip(self)
        end
    end)
    button:SetScript("OnLeave", HideTooltip)
    button:SetScript("OnHide", function(self)
        HideTooltip(self)
        if self.foodMenu then
            self.foodMenu:Close()
        end
    end)
    return button
end

function PSA.SetPetFeedMouseEnabled(enabled)
    if not feedButton then return end
    feedButton:EnableMouse(enabled)
    if not enabled then
        HideTooltip(feedButton)
        if feedButton.foodMenu then feedButton.foodMenu:Close() end
    end
end

function PSA.RefreshPetCare(refreshFoodMenu)
    local feedingEnabled = PSA.GetClassOption("petFeedEnabled")
    local unhappyEnabled = PSA.GetClassOption("petUnhappyAlertEnabled")
    if not feedingEnabled and not unhappyEnabled then
        if feedButton then feedButton:Hide() end
        PSA.SetPetCareAlert(nil)
        return
    end
    local happiness = GetHappiness()
    local inCombat = InCombatLockdown()
    local warnUnhappy = happiness == UNHAPPY and unhappyEnabled
    local canFeed = feedingEnabled and happiness and PSA.IsKnownPlayerSpell(FEED_PET)
    local kind, texture, unavailable

    if not canFeed then
        if warnUnhappy then kind = "unhappy" end
    elseif (inCombat and warnUnhappy) or (not inCombat and not IsPetEating()) then
        local preferredID, preferredCount = ResolvePreferredFood(true)
        local food, _, _, hasFood = FindFood(preferredID, nil, true)
        if not hasFood then
            -- A zero-size backpack on login does not mean the player ran out.
            if not inCombat and C_Container.GetContainerNumSlots(0) > 0 then
                kind = "no_food"
            elseif warnUnhappy then
                kind = "unhappy"
            end
        elseif not inCombat and (food or preferredID) then
            kind = "feed"
            local itemID = food and food.itemID or preferredID
            texture = (food and food.iconFileID) or C_Item.GetItemIconByID(itemID) or "Interface\\Icons\\INV_Misc_QuestionMark"
            unavailable = not food
            feedButton = feedButton or CreateFeedButton()
            feedButton.foodName = GetFoodName(itemID, food and food.itemName)
            local foodCount = preferredCount or C_Item.GetItemCount(itemID)
            if feedButton.foodCount ~= foodCount then
                feedButton.count:SetText(tostring(foodCount))
                feedButton.foodCount = foodCount
            end
            feedButton.foodAvailable = not unavailable
            feedButton:Show()
            RefreshTooltip(feedButton)
            if refreshFoodMenu then
                RefreshFoodMenu(feedButton)
            end
        end
    end

    if kind ~= "feed" and feedButton then
        feedButton:Hide()
    end
    PSA.SetPetCareAlert(kind, texture, unavailable)
end
