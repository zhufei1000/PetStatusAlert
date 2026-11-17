local _, PSA = ...

if not (PSA.ReadFoodBuff and C_Container and C_Container.GetContainerNumSlots
    and C_Container.GetContainerItemInfo and C_Item and C_Item.GetItemSpell and C_Item.IsUsableItem) then
    return
end

local NUTRITIOUS_FOOD = 1248377
local LAST_BAG = NUM_TOTAL_EQUIPPED_BAG_SLOTS or 4
local CONSUMABLE = Enum and Enum.ItemClass and Enum.ItemClass.Consumable or 0
local button, owner, menu
local characterGUID, sessionItem
local requestedItems, waitingItems = {}, {}
local requestedSpell, waitingSpell, menuRefreshQueued
local foodUseFrame, pendingFoodUse
local itemTransferFrames = { "MerchantFrame", "BankFrame", "GuildBankFrame", "MailFrame", "TradeFrame" }

local function CharacterGUID()
    if not characterGUID then
        local guid = UnitGUID("player")
        if PSA.IsAccessibleValue(guid) then characterGUID = guid end
    end
    return characterGUID
end

local function PreferredItem()
    local guid = CharacterGUID()
    local choices = PSA.InitDB().playerFoodByCharacter
    local id = guid and type(choices) == "table" and choices[guid] or sessionItem
    if type(id) == "number" and id > 0 and id % 1 == 0 then return id end
end

local function RememberItem(id)
    local guid = CharacterGUID()
    if not guid then
        sessionItem = id
        return
    end
    local db = PSA.InitDB()
    if type(db.playerFoodByCharacter) ~= "table" then db.playerFoodByCharacter = {} end
    db.playerFoodByCharacter[guid] = id
    sessionItem = nil
end

local function ReadBagCount(id)
    local count = C_Item.GetItemCount(id)
    if PSA.IsAccessibleValue(count) and type(count) == "number" then return count end
end

local function BagCount(id)
    return ReadBagCount(id) or 0
end

local function CanInteract()
    return owner and button:IsVisible() and not InCombatLockdown()
end

local function UpdateBagWatch()
    if owner and (menu or PreferredItem()) then
        button:RegisterEvent("BAG_UPDATE_DELAYED")
    else
        button:UnregisterEvent("BAG_UPDATE_DELAYED")
    end
end

local function UpdateIcon()
    local id = PreferredItem()
    local count = id and BagCount(id) or 0
    local texture = count > 0 and C_Item.GetItemIconByID(id)
    button.foodTexture:SetShown(not not texture)
    if texture then button.foodTexture:SetTexture(texture) end
    button.foodCount:SetText(count > 0 and tostring(count) or "")
end

local function StopLoading()
    wipe(requestedItems)
    wipe(waitingItems)
    requestedSpell, waitingSpell = nil, nil
    button:UnregisterEvent("ITEM_DATA_LOAD_RESULT")
    button:UnregisterEvent("SPELL_DATA_LOAD_RESULT")
end

local function CloseMenu()
    local current = menu
    menu = nil
    StopLoading()
    UpdateBagWatch()
    if current then current:Close() end
end

local function IsBuffFood(id, nutritiousName)
    if PSA.HasKnownFoodAura(id) then return true end
    local name, spellID = C_Item.GetItemSpell(id)
    return (PSA.IsAccessibleValue(spellID) and spellID == NUTRITIOUS_FOOD)
        or (PSA.IsAccessibleValue(nutritiousName) and nutritiousName
            and PSA.IsAccessibleValue(name) and name == nutritiousName)
end

local function CanRememberBagFood()
    return not InCombatLockdown() and PSA.GetBuffAlertsEnabled()
        and PSA.GetFoodBuffAlertEnabled() and PSA.GetFoodPickerEnabled()
end

local function ClearPendingFoodUse()
    pendingFoodUse = nil
    if foodUseFrame then foodUseFrame:UnregisterEvent("BAG_UPDATE_DELAYED") end
end

local function ConfirmBagFood()
    local attempt = pendingFoodUse
    if not attempt then return end
    if not CanRememberBagFood() then
        ClearPendingFoodUse()
        return
    end
    local count = ReadBagCount(attempt.id)
    if count and count < attempt.count then
        ClearPendingFoodUse()
        RememberItem(attempt.id)
        if CanInteract() then
            UpdateIcon()
            UpdateBagWatch()
        end
    end
end

local function ObserveBagFoodUse(bag, slot, target)
    if not CanRememberBagFood() or not PSA.IsAccessibleValue(bag) or not PSA.IsAccessibleValue(slot)
        or not PSA.IsAccessibleValue(target) or (target and target ~= "player")
        or type(bag) ~= "number" or bag < 0 or bag > LAST_BAG or type(slot) ~= "number"
        or SpellIsTargeting() or GetCursorInfo() then return end
    for _, name in ipairs(itemTransferFrames) do
        local frame = _G[name]
        if frame and frame:IsShown() then return end
    end
    if C_Bank and C_Bank.AreAnyBankTypesViewable and C_Bank.AreAnyBankTypesViewable() then return end

    local item = C_Container.GetContainerItemInfo(bag, slot)
    if not PSA.IsAccessibleValue(item) or not item or (canaccesstable and not canaccesstable(item)) then return end
    local id = item.itemID
    if not PSA.IsAccessibleValue(id) or type(id) ~= "number"
        or select(6, C_Item.GetItemInfoInstant(id)) ~= CONSUMABLE
        or not IsBuffFood(id, C_Spell.GetSpellName(NUTRITIOUS_FOOD)) then return end
    ConfirmBagFood()
    local count = ReadBagCount(id)
    if not count or count == 0 then return end

    -- The food buff may hide the reminder before the bag update arrives.
    if not foodUseFrame then
        foodUseFrame = CreateFrame("Frame")
        foodUseFrame:SetScript("OnEvent", ConfirmBagFood)
    end
    local attempt = { id = id, count = count }
    pendingFoodUse = attempt
    foodUseFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    C_Timer.After(2, function()
        if pendingFoodUse == attempt then ClearPendingFoodUse() end
    end)
end

local function RequestItem(id)
    if not requestedItems[id] then
        requestedItems[id], waitingItems[id] = true, true
        button:RegisterEvent("ITEM_DATA_LOAD_RESULT")
        C_Item.RequestLoadItemDataByID(id)
    end
end

local function CountBagStacks()
    local totals = {}
    for bag = 0, LAST_BAG do
        local slots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, slots do
            local item = C_Container.GetContainerItemInfo(bag, slot)
            if PSA.IsAccessibleValue(item) and item then
                local id, count = item.itemID, item.stackCount
                if PSA.IsAccessibleValue(id) and id and PSA.IsAccessibleValue(count) and count and count > 0 then
                    totals[id] = (totals[id] or 0) + count
                end
            end
        end
    end
    return totals
end

local function FindFood()
    local name = C_Spell.GetSpellName(NUTRITIOUS_FOOD)
    if not name and not requestedSpell then
        requestedSpell, waitingSpell = true, true
        button:RegisterEvent("SPELL_DATA_LOAD_RESULT")
        C_Spell.RequestLoadSpellData(NUTRITIOUS_FOOD)
    end

    local result = {}
    for id, count in pairs(CountBagStacks()) do
        if select(6, C_Item.GetItemInfoInstant(id)) == CONSUMABLE then
            if not C_Item.IsItemDataCachedByID(id) then
                RequestItem(id)
            elseif IsBuffFood(id, name) and C_Item.IsUsableItem(id) then
                result[#result + 1] = { id = id, name = C_Item.GetItemNameByID(id) or tostring(id), count = count }
            end
        end
    end
    table.sort(result, function(a, b)
        if a.name == b.name then return a.id < b.id end
        return a.name < b.name
    end)
    return result
end

local function BuildMenu(_, root)
    root:AddMenuReleasedCallback(function(released)
        if released == menu then
            menu = nil
            StopLoading()
            UpdateBagWatch()
        end
    end)
    root:CreateTitle(PSA.UI.FOOD_PICKER_TITLE)
    local choices = FindFood()
    local function IsSelected(id) return PreferredItem() == id end
    local function SelectItem(id)
        if not CanInteract() or BagCount(id) == 0 or not C_Item.IsUsableItem(id) then return end
        ClearPendingFoodUse()
        RememberItem(id)
        UpdateIcon()
        UpdateBagWatch()
    end
    for _, food in ipairs(choices) do
        local itemID = food.id
        local entry = root:CreateRadio(("%s ×%d"):format(food.name, food.count), IsSelected, SelectItem, itemID)
        entry:SetTooltip(function(tooltip)
            tooltip:SetItemByID(itemID)
        end)
    end
    if waitingSpell or next(waitingItems) then
        root:CreateTitle(PSA.UI.FOOD_PICKER_LOADING)
    elseif #choices == 0 then
        root:CreateTitle(PSA.UI.FOOD_PICKER_EMPTY)
    end
    if #choices > 0 then root:SetScrollMode(240) end
end

local function QueueMenuRefresh()
    if menuRefreshQueued then return end
    menuRefreshQueued = true
    C_Timer.After(0, function()
        menuRefreshQueued = false
        if not menu or not CanInteract() then return end
        local root = MenuUtil.CreateRootMenuDescription(MenuVariants.GetDefaultContextMenuMixin())
        Menu.PopulateDescription(BuildMenu, button, root)
        menu:SetMenuDescription(root)
    end)
end

local function ClearAction(self)
    self:SetAttribute("type1", nil)
    self:SetAttribute("item1", nil)
end

local function PrepareClick(self, mouseButton)
    ClearAction(self)
    if mouseButton ~= "LeftButton" or not CanInteract() or SpellIsTargeting() or GetCursorInfo() then return end
    local id = PreferredItem()
    if id and BagCount(id) > 0 and C_Item.IsUsableItem(id) then
        self:SetAttribute("item1", "item:" .. id)
        self:SetAttribute("type1", "item")
    end
end

local function HideTooltip(self)
    if GameTooltip and not GameTooltip:IsForbidden() and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
end

local function CreateButton(parent)
    -- This Blizzard template performs item actions from a player click, outside combat only.
    local picker = CreateFrame("Button", nil, parent, "InsecureActionButtonTemplate")
    picker:SetAllPoints(parent)
    picker:EnableMouse(true)
    picker:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    picker:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    picker:SetAttribute("useOnKeyDown", false)
    picker.foodTexture = picker:CreateTexture(nil, "ARTWORK")
    picker.foodTexture:SetAllPoints(picker)
    picker.foodCount = picker:CreateFontString(nil, "OVERLAY")
    picker.foodCount:SetPoint("BOTTOMRIGHT", picker, "BOTTOMRIGHT", -2, 2)
    picker.foodCount:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    picker:SetScript("PreClick", PrepareClick)
    picker:SetScript("PostClick", function(self, mouseButton)
        ClearAction(self)
        if mouseButton ~= "RightButton" or not CanInteract() or not MenuUtil then return end
        HideTooltip(self)
        CloseMenu()
        menu = MenuUtil.CreateContextMenu(self, BuildMenu)
        if not menu then StopLoading() end
        UpdateBagWatch()
    end)
    picker:SetScript("OnEnter", function(self)
        if not GameTooltip or GameTooltip:IsForbidden() then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local id = PreferredItem()
        if id and BagCount(id) > 0 then
            GameTooltip:SetItemByID(id)
        else
            GameTooltip:SetText(PSA.UI.FOOD_BUFF_MISSING)
        end
        GameTooltip:AddLine(PSA.UI.FOOD_PICKER_HINT, 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    picker:SetScript("OnLeave", HideTooltip)
    picker:SetScript("OnHide", HideTooltip)
    picker:SetScript("OnEvent", function(self, event, id)
        if event == "BAG_UPDATE_DELAYED" then
            if CanInteract() then
                UpdateIcon()
                if menu then QueueMenuRefresh() end
            end
        elseif event == "ITEM_DATA_LOAD_RESULT" and waitingItems[id] then
            waitingItems[id] = nil
            if not next(waitingItems) then self:UnregisterEvent(event) end
            QueueMenuRefresh()
        elseif event == "SPELL_DATA_LOAD_RESULT" and id == NUTRITIOUS_FOOD then
            waitingSpell = nil
            self:UnregisterEvent(event)
            QueueMenuRefresh()
        end
    end)
    return picker
end

function PSA.SetFoodPickerOwner(parent)
    if not PSA.GetFoodPickerEnabled() then parent = nil end
    if owner == parent then return end
    owner = parent
    if not parent then
        CloseMenu()
        button:Hide()
        return
    end
    button = button or CreateButton(parent)
    UpdateIcon()
    UpdateBagWatch()
    button:Show()
end

if hooksecurefunc and C_Container.UseContainerItem then
    hooksecurefunc(C_Container, "UseContainerItem", ObserveBagFoodUse)
end
