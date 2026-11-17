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
local UNHAPPY, CONTENT = 1, 2
local LAST_BAG = NUM_TOTAL_EQUIPPED_BAG_SLOTS or 4
local feedButton
local characterGUID, sessionFoodID
local foodBags = {}

function PSA.InvalidatePetFood(bag)
    if bag == nil then
        foodBags = {}
    elseif type(bag) == "number" and bag >= 0 and bag <= LAST_BAG then
        foodBags[bag] = nil
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

local function ResolvePreferredFood()
    local itemID = GetPreferredFood()
    if not itemID then
        return
    end
    local count = C_Item.GetItemCount(itemID)
    -- Wait until bags are available before treating a zero count as depletion.
    if count == 0 and C_Container.GetContainerNumSlots(0) > 0 then
        SetPreferredFood(nil)
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

-- Reuse a per-bag summary when only the current happiness changed. Without it
-- every UNIT_HAPPINESS tick walked every bag slot even though no bag event had
-- invalidated the cached contents.
local function FindFood(preferredID, visitFood, useCache)
    local hasFood = false
    for bag = 0, LAST_BAG do
        local cachedBag = useCache and foodBags[bag] or nil
        if useCache and cachedBag and not visitFood then
            hasFood = hasFood or cachedBag.hasFood
            local entry
            if preferredID then
                entry = cachedBag.byID and cachedBag.byID[preferredID]
            else
                entry = cachedBag.first
            end
            if entry then return entry.item, bag, entry.slot, true end
        else
            local size = cachedBag and cachedBag.size or C_Container.GetContainerNumSlots(bag)
            if useCache and not cachedBag then
                cachedBag = { size = size, byID = {} }
                foodBags[bag] = cachedBag
            end

            for slot = 1, size do
                local item = cachedBag and cachedBag[slot]
                if item == nil then
                    item = C_Container.GetContainerItemInfo(bag, slot)
                    local edible = item and item.stackCount > 0 and C_PetInfo.CanPetEatItem(item.itemID)
                    if cachedBag then
                        cachedBag[slot] = edible and item or false
                    end
                    item = edible and item
                end
                if item then
                    hasFood = true
                    if cachedBag then
                        cachedBag.hasFood = true
                        if not item.isLocked then
                            local entry = { item = item, slot = slot }
                            cachedBag.byID = cachedBag.byID or {}
                            cachedBag.first = cachedBag.first or entry
                            cachedBag.byID[item.itemID] = cachedBag.byID[item.itemID] or entry
                        end
                    end
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
        or not PSA.GetClassOption("petFeedEnabled") or not GetHappiness() or not PSA.IsKnownPlayerSpell(FEED_PET) then
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
    local inCombat = feedingEnabled and InCombatLockdown()
    local preferredID, preferredCount
    if feedingEnabled then preferredID, preferredCount = ResolvePreferredFood() end
    local kind, texture, unavailable

    if happiness == UNHAPPY and unhappyEnabled and not feedingEnabled then
        kind = "unhappy"
    elseif happiness and ((happiness == UNHAPPY and unhappyEnabled) or (feedingEnabled and not inCombat)) then
        local food, _, _, hasFood = FindFood(preferredID, nil, true)
        if happiness == UNHAPPY and unhappyEnabled and not hasFood then
            kind = "unhappy"
        elseif feedingEnabled and not inCombat and (food or (preferredID and hasFood)) and PSA.IsKnownPlayerSpell(FEED_PET) then
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
