-------------------------------------------------
-- PetStatusAlert events
-------------------------------------------------

local ADDON_NAME, PSA = ...
ADDON_NAME = ADDON_NAME or (PSA and PSA.ADDON_NAME) or "PetStatusAlert"
PSA = PSA or _G.PetStatusAlert

local addonFrame = PSA.addonFrame
local InitDB = PSA.InitDB
local RegisterNativeOptionsCategory = PSA.RegisterNativeOptionsCategory
local StopCombatTTSReminder = PSA.StopCombatTTSReminder
local QueueRefresh = PSA.QueueRefresh
local RefreshPetStatusText = PSA.RefreshPetStatusText
local RefreshPetCare = PSA.RefreshPetCare
local InvalidatePetFood = PSA.InvalidatePetFood
local RefreshCombatTTSReminder = PSA.RefreshCombatTTSReminder
local ClearPetStatusCaches = PSA.ClearPetStatusCaches
local HandleFoodBuffEvent = PSA.HandleFoodBuffEvent
local HandleForeverFormAlertCast = PSA.HandleForeverFormAlertCast
local ResetForeverFormAlertState = PSA.ResetForeverFormAlertState
local isForever = PSA.IsForeverClient()

local function RegisterEventSafe(event)
    if addonFrame and event then
        pcall(addonFrame.RegisterEvent, addonFrame, event)
    end
end

local function RegisterUnitEventSafe(event, unit)
    if addonFrame and event and unit then
        local ok, registered = pcall(addonFrame.RegisterUnitEvent, addonFrame, event, unit)
        if not ok or registered == false then RegisterEventSafe(event) end
    end
end

local petActive, buffActive = true, false
local mastersInitialized = false
local playerClass, hasClassAlerts
local function UpdatePlayerClass()
    playerClass = PSA.GetPlayerClassFile()
    hasClassAlerts = playerClass == nil or PSA.GetClassAlertStatuses(playerClass, isForever) ~= nil
    if isForever and PSA.GetForeverFormAlertStatuses(playerClass) then
        hasClassAlerts = PSA.HasEnabledForeverFormAlerts and PSA.HasEnabledForeverFormAlerts()
    end
end
UpdatePlayerClass()

local function UnregisterEventSafe(event)
    if addonFrame and addonFrame.UnregisterEvent then
        pcall(addonFrame.UnregisterEvent, addonFrame, event)
    end
end

local function SetEventRegistered(event, active)
    if active then RegisterEventSafe(event) else UnregisterEventSafe(event) end
end

local function SetUnitEventRegistered(event, unit, active)
    if active then RegisterUnitEventSafe(event, unit) else UnregisterEventSafe(event) end
end

do
    local watchingPlayerAuras = false
    local supplyAuraWatch, foodAuraWatch = false, false
    local function UpdateAuraWatch()
        -- Forever reads the form bar; only Retail Warrior stance tracking uses auras.
        local watch = supplyAuraWatch or foodAuraWatch
            or (not isForever and petActive and PSA.WantsWarriorAuraWatch ~= nil and PSA.WantsWarriorAuraWatch())
        if watch == watchingPlayerAuras then return end
        watchingPlayerAuras = watch
        if watch then
            if addonFrame.RegisterUnitEvent then
                RegisterUnitEventSafe("UNIT_AURA", "player")
            else
                RegisterEventSafe("UNIT_AURA")
            end
        else
            UnregisterEventSafe("UNIT_AURA")
        end
    end
    local function SetSupplyAuraWatch(enabled)
        supplyAuraWatch = enabled and true or false
        UpdateAuraWatch()
    end
    if isForever then
        PSA.SetForeverClassAuraWatch = SetSupplyAuraWatch
        function PSA.SetForeverFoodAuraWatch(enabled)
            foodAuraWatch = enabled and true or false
            UpdateAuraWatch()
        end
    else
        PSA.SetRetailSupplyAuraWatch = SetSupplyAuraWatch
    end
    function PSA.RefreshRetailSupplyAuraWatch()
        UpdateAuraWatch()
    end
    UpdateAuraWatch()
end

local trackAmmo = isForever and PSA.GetForeverAmmo and PSA.SetAmmoAlert
local ammoThreshold = 0
local petCareWatch, feedingWatch = false, false

local centralPetEvents = {
    "SPELLS_CHANGED",
    "LEARNED_SPELL_IN_SKILL_LINE", "PLAYER_TALENT_UPDATE",
    "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED", "PLAYER_MOUNT_DISPLAY_CHANGED",
}
if not isForever then
    for _, event in ipairs({ "PLAYER_SPECIALIZATION_CHANGED", "TRAIT_CONFIG_UPDATED", "TRAIT_CONFIG_LIST_UPDATED" }) do
        centralPetEvents[#centralPetEvents + 1] = event
    end
end
local centralWorldEvents = { "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }
local centralDeathEvents = { "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST" }
local centralPetCareEvents = { "BAG_UPDATE", "ITEM_LOCK_CHANGED" }

local function UpdateCentralEvents()
    local pet = petActive and hasClassAlerts
    local usesFormBar = isForever and PSA.GetForeverFormAlertStatuses(playerClass)
    local watchForms = pet and usesFormBar
    local hasPet = pet and playerClass ~= "WARRIOR" and not usesFormBar
    local buff = buffActive
    local ammo = ammoThreshold > 0
    local buffWorld = ammo or (buff and HandleFoodBuffEvent ~= nil)
    local deathEvents = petCareWatch or watchForms or (buff and HandleFoodBuffEvent ~= nil)
    for _, event in ipairs(centralPetEvents) do SetEventRegistered(event, pet) end
    for _, event in ipairs(centralWorldEvents) do SetEventRegistered(event, pet or buffWorld) end
    for _, event in ipairs(centralDeathEvents) do
        SetEventRegistered(event, deathEvents)
    end
    for _, event in ipairs(centralPetCareEvents) do SetEventRegistered(event, feedingWatch) end
    SetEventRegistered("BAG_UPDATE_DELAYED", feedingWatch or ammo)
    SetEventRegistered("PLAYER_EQUIPMENT_CHANGED", ammo)
    SetUnitEventRegistered("UNIT_INVENTORY_CHANGED", "player", ammo)
    SetUnitEventRegistered("UNIT_HAPPINESS", "pet", petCareWatch)
    SetUnitEventRegistered("UNIT_ENTERED_VEHICLE", "player", pet)
    SetUnitEventRegistered("UNIT_EXITED_VEHICLE", "player", pet)
    SetUnitEventRegistered("UNIT_FLAGS", "pet", hasPet)
    SetUnitEventRegistered("UNIT_PET", "player", hasPet)
    SetEventRegistered("PET_BAR_UPDATE", hasPet)
    SetEventRegistered("PET_UI_UPDATE", hasPet)
    if usesFormBar then
        SetEventRegistered("UPDATE_SHAPESHIFT_FORM", watchForms)
        SetEventRegistered("UPDATE_SHAPESHIFT_FORMS", watchForms)
        SetUnitEventRegistered("UNIT_SPELLCAST_SUCCEEDED", "player", watchForms)
    end
end

if PSA.HasEnabledForeverFormAlerts then
    function PSA.ApplyForeverFormAlertSettings()
        UpdatePlayerClass()
        UpdateCentralEvents()
        if not hasClassAlerts then ResetForeverFormAlertState() end
        if not PSA.currentStatusForce then RefreshPetStatusText() end
    end
end

RegisterEventSafe("ADDON_LOADED")
UpdateCentralEvents()

local ammoRefreshPending = false
local function QueueAmmoRefresh()
    if ammoThreshold == 0 or ammoRefreshPending or InCombatLockdown() then
        return
    end
    ammoRefreshPending = true
    C_Timer.After(0, function()
        ammoRefreshPending = false
        if ammoThreshold == 0 or InCombatLockdown() then
            return
        end

        local kind, count, texture = PSA.GetForeverAmmo()
        if not kind or (count and count >= ammoThreshold) then
            PSA.SetAmmoAlert()
        elseif count then
            PSA.SetAmmoAlert(kind, count, texture)
        end
    end)
end

if isForever and trackAmmo then
    function PSA.ApplyAmmoAlertSettings()
        local wasWatching = ammoThreshold > 0
        ammoThreshold = buffActive and PSA.GetAmmoThreshold() or 0
        if wasWatching ~= (ammoThreshold > 0) then UpdateCentralEvents() end
        if ammoThreshold > 0 then QueueAmmoRefresh() else PSA.SetAmmoAlert() end
    end
end

local PET_CARE_ONLY_EVENTS = {
    UNIT_HAPPINESS = true,
    BAG_UPDATE = true,
    BAG_UPDATE_DELAYED = true,
    ITEM_LOCK_CHANGED = true,
    PLAYER_DEAD = true,
    PLAYER_ALIVE = true,
    PLAYER_UNGHOST = true,
}

-- PET_UI_UPDATE can fire while the pet fights. It refreshes the pet status,
-- but the bag contents did not change, so it must not throw away the cached
-- food slots and rescan every bag.
local PET_FOOD_SOURCE_EVENTS = {
    PLAYER_ENTERING_WORLD = true,
    UNIT_PET = true,
}

local PET_CARE_STATE_EVENTS = {
    SPELLS_CHANGED = true,
    LEARNED_SPELL_IN_SKILL_LINE = true,
    PLAYER_TALENT_UPDATE = true,
    PLAYER_REGEN_ENABLED = true,
    PLAYER_CONTROL_LOST = true,
    PLAYER_CONTROL_GAINED = true,
    PLAYER_MOUNT_DISPLAY_CHANGED = true,
    UNIT_ENTERED_VEHICLE = true,
    UNIT_EXITED_VEHICLE = true,
    UNIT_FLAGS = true,
    PLAYER_DEAD = true,
    PLAYER_ALIVE = true,
    PLAYER_UNGHOST = true,
}

local FOOD_ONLY_EVENTS = {
    ADDON_RESTRICTION_STATE_CHANGED = true,
    PLAYER_UPDATE_RESTING = true,
    PLAYER_LEVEL_UP = true,
    ENCOUNTER_START = true,
    ENCOUNTER_END = true,
}

local petCareRefreshPending = false
local foodMenuRefreshPending = false
local foodBagUpdateSeen, foodBagChanged = false, false

local function UpdatePetCareWatch()
    local canWatch = petActive and hasClassAlerts and RefreshPetCare ~= nil
    local feeding = canWatch and PSA.GetClassOption("petFeedEnabled")
    local care = feeding or (canWatch and PSA.GetClassOption("petUnhappyAlertEnabled"))
    local changed = feeding ~= feedingWatch or care ~= petCareWatch
    if feeding ~= feedingWatch then
        InvalidatePetFood()
        foodBagUpdateSeen, foodBagChanged = false, false
    end
    feedingWatch, petCareWatch = feeding, care
    return changed
end

if RefreshPetCare then
    function PSA.ApplyPetCareSettings()
        if UpdatePetCareWatch() then UpdateCentralEvents() end
        RefreshPetCare()
    end
end

local function QueuePetCareRefresh(refreshFoodMenu)
    if not petCareWatch then return end
    foodMenuRefreshPending = foodMenuRefreshPending or refreshFoodMenu
    if petCareRefreshPending then
        return
    end
    petCareRefreshPending = true
    -- Bag and happiness events arrive in bursts. Food does not need 20 Hz
    -- feedback, so coalesce them into one refresh per 150 ms.
    C_Timer.After(0.15, function()
        petCareRefreshPending = false
        local refreshMenu = foodMenuRefreshPending
        foodMenuRefreshPending = false
        if petCareWatch then RefreshPetCare(refreshMenu) end
    end)
end

local CACHE_INVALIDATE_EVENTS = {
    SPELLS_CHANGED = true,
    LEARNED_SPELL_IN_SKILL_LINE = true,
    PLAYER_ENTERING_WORLD = true,
    PLAYER_SPECIALIZATION_CHANGED = true,
    PLAYER_TALENT_UPDATE = true,
    TRAIT_CONFIG_UPDATED = true,
    TRAIT_CONFIG_LIST_UPDATED = true,
}

addonFrame:SetScript("OnEvent", function(_, event, unit, slot, spellID)
    if event == "ADDON_LOADED" then
        if unit == ADDON_NAME or unit == "PetStatusAlert" then
            UnregisterEventSafe("ADDON_LOADED")
            InitDB(true)
            UpdatePlayerClass()
            -- 存档在脚本执行后载入，按保存的语言重新初始化文案和默认提醒。
            if PSA.RefreshLocaleState then
                PSA.RefreshLocaleState()
            end
            if PSA.RefreshOptionsFrameLocale then
                PSA.RefreshOptionsFrameLocale()
            end
            if PSA.ApplyAlertPosition then
                PSA.ApplyAlertPosition()
            end
            if PSA.SetAlertPositionLocked then
                PSA.SetAlertPositionLocked(PetStatusAlertDB.alertLocked)
            end
            -- RL/重登后强制刷新视觉，确保 currentIconMode 等状态从 DB 同步
            if PSA.RefreshAlertVisuals then
                PSA.RefreshAlertVisuals()
            end
            if PSA.ApplyAlertMasterSwitches then PSA.ApplyAlertMasterSwitches() end
            RegisterNativeOptionsCategory()
        end
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if petActive and hasClassAlerts and HandleForeverFormAlertCast then
            HandleForeverFormAlertCast(unit, spellID)
        end
        return
    end

    if not playerClass and event == "PLAYER_ENTERING_WORLD" then
        UpdatePlayerClass()
        if playerClass then
            UpdatePetCareWatch()
            UpdateCentralEvents()
        end
    end

    if event == "UNIT_AURA" then
        if PSA.IsAccessibleValue(unit) and unit == "player" then
            if isForever then
                if buffActive and HandleFoodBuffEvent then HandleFoodBuffEvent(event, unit, slot) end
                if buffActive and PSA.HandleForeverClassAuraUpdate then PSA.HandleForeverClassAuraUpdate(slot) end
            else
                if petActive and PSA.HandleWarriorAuraChanged then PSA.HandleWarriorAuraChanged(slot) end
                if buffActive and PSA.HandleRetailSupplyAuraUpdate then PSA.HandleRetailSupplyAuraUpdate(slot) end
            end
        end
        return
    end

    if (event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE") and unit ~= "player" then
        return
    end

    if (event == "UNIT_FLAGS" and unit ~= "pet") or (event == "UNIT_PET" and unit ~= "player") then
        return
    end
    if event == "PLAYER_SPECIALIZATION_CHANGED" and unit and unit ~= "player" then return end

    if buffActive and HandleFoodBuffEvent then
        if FOOD_ONLY_EVENTS[event] then
            HandleFoodBuffEvent(event, unit, slot)
            return
        end
        if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED"
            or event == "PLAYER_DEAD" or event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
            HandleFoodBuffEvent(event, unit, slot)
        end
    end

    if ammoThreshold > 0 then
        if event == "PLAYER_REGEN_DISABLED" then
            PSA.SetAmmoAlert()
        elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" or event == "BAG_UPDATE_DELAYED" then
            QueueAmmoRefresh()
        elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "UNIT_INVENTORY_CHANGED" then
            if (event == "PLAYER_EQUIPMENT_CHANGED" and PSA.IsForeverAmmoEquipmentSlot(unit))
                or (event == "UNIT_INVENTORY_CHANGED" and unit == "player") then
                QueueAmmoRefresh()
            end
        end
    end
    if event == "PLAYER_EQUIPMENT_CHANGED" or event == "UNIT_INVENTORY_CHANGED" then return end

    if petCareWatch then
        if event == "PLAYER_REGEN_DISABLED" then
            RefreshPetCare()
        elseif event == "BAG_UPDATE" and feedingWatch then
            if PSA.IsAccessibleValue(unit) and type(unit) == "number" then
                foodBagUpdateSeen = true
                foodBagChanged = InvalidatePetFood(unit) or foodBagChanged
            else
                InvalidatePetFood()
                foodBagChanged = true
            end
        elseif event == "BAG_UPDATE_DELAYED" and feedingWatch then
            -- A delayed event without a bag ID still has to refresh all food data.
            if not foodBagUpdateSeen then
                InvalidatePetFood()
            end
            local refresh = not foodBagUpdateSeen or foodBagChanged
            foodBagUpdateSeen, foodBagChanged = false, false
            if refresh then QueuePetCareRefresh(true) end
        elseif event == "ITEM_LOCK_CHANGED" and feedingWatch then
            if slot and InvalidatePetFood(unit) and not InCombatLockdown() then
                QueuePetCareRefresh(true)
            end
        elseif PET_FOOD_SOURCE_EVENTS[event] then
            -- Only a world transition can replace the bag contents behind our
            -- back; pet swaps merely change which pet needs feeding.
            if feedingWatch and event == "PLAYER_ENTERING_WORLD" then InvalidatePetFood() end
            QueuePetCareRefresh(feedingWatch)
        elseif PET_CARE_STATE_EVENTS[event] or (event == "UNIT_HAPPINESS" and unit == "pet") then
            QueuePetCareRefresh(false)
        end
    end
    if petActive and hasClassAlerts and ResetForeverFormAlertState then
        if event == "PLAYER_ENTERING_WORLD" then
            ResetForeverFormAlertState()
        elseif event == "PLAYER_DEAD" then
            ResetForeverFormAlertState()
            PSA.HideStatus()
        elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
            QueueRefresh(0.08)
        end
    end
    if petActive and PET_CARE_ONLY_EVENTS[event] then
        return
    end
    if not petActive or not hasClassAlerts then return end

    if CACHE_INVALIDATE_EVENTS[event] and ClearPetStatusCaches then
        ClearPetStatusCaches()
        if PSA.RefreshOpenClassEligibility then PSA.RefreshOpenClassEligibility() end
    end

    if event == "PLAYER_REGEN_ENABLED" then
        StopCombatTTSReminder()
        QueueRefresh(0.08)
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        -- Combat-start needs the current status before starting TTS, but avoid the old
        -- multi-refresh path used by generic events.
        RefreshPetStatusText()
        RefreshCombatTTSReminder(true)
        QueueRefresh(0.20)
        return
    end

    -- Only world entry and pet swaps can outlast the normal event batch.
    QueueRefresh(0.08)
    if event == "PLAYER_ENTERING_WORLD" or event == "UNIT_PET" then
        QueueRefresh(0.35)
        if event == "PLAYER_ENTERING_WORLD" then QueueRefresh(1.00) end
    end
end)

function PSA.ApplyAlertMasterSwitches()
    local nextPet = PSA.GetPetAlertsEnabled()
    local nextBuff = PSA.GetBuffAlertsEnabled()
    local petChanged = nextPet ~= petActive
    local buffChanged = nextBuff ~= buffActive
    local firstApply = not mastersInitialized
    petActive, buffActive = nextPet, nextBuff
    mastersInitialized = true
    UpdatePetCareWatch()
    if isForever and PSA.ApplyAmmoAlertSettings and (firstApply or buffChanged) then
        PSA.ApplyAmmoAlertSettings()
    end
    UpdateCentralEvents()
    -- Generic refresh for whichever aura watch the current client uses.
    if PSA.RefreshRetailSupplyAuraWatch then PSA.RefreshRetailSupplyAuraWatch() end
    if not isForever and PSA.SetWarriorAlertActivity then PSA.SetWarriorAlertActivity(petActive) end

    if petActive then
        if petChanged then
            if ClearPetStatusCaches then ClearPetStatusCaches() end
            if isForever and petCareWatch then RefreshPetCare() end
            if PSA.RefreshOpenClassEligibility then PSA.RefreshOpenClassEligibility() end
            if PSA.QueueRefresh then PSA.QueueRefresh(0.05) end
        end
    else
        if isForever and RefreshPetCare then RefreshPetCare() end
        if ResetForeverFormAlertState then ResetForeverFormAlertState() end
        if PSA.StopCombatTTSReminder then PSA.StopCombatTTSReminder() end
        if PSA.HideStatus then PSA.HideStatus(true) end
    end

    if firstApply or buffChanged then
        if not isForever and PSA.RefreshRetailBuffAlerts then PSA.RefreshRetailBuffAlerts() end
        if isForever and PSA.RefreshForeverClassBuffs then PSA.RefreshForeverClassBuffs() end
        if isForever and PSA.RefreshFoodBuffAlert then PSA.RefreshFoodBuffAlert(firstApply) end
        if isForever and PSA.RefreshFoodPicker then PSA.RefreshFoodPicker() end
    end
end
