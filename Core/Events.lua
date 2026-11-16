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
local isForever = PSA.IsForeverClient()

local function RegisterEventSafe(event)
    if addonFrame and event then
        pcall(addonFrame.RegisterEvent, addonFrame, event)
    end
end

local function RegisterUnitEventSafe(event, unit)
    if addonFrame and event and unit then
        pcall(addonFrame.RegisterUnitEvent, addonFrame, event, unit)
    end
end

local petActive, buffActive = true, false
local mastersInitialized = false

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

if not isForever then
    local watchingPlayerAuras = false
    local retailAuraWatch = false
    local function UpdateAuraWatch()
        local watch = retailAuraWatch or (petActive and PSA.HandleWarriorAuraChanged ~= nil)
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
    function PSA.SetRetailSupplyAuraWatch(enabled)
        retailAuraWatch = enabled and true or false
        UpdateAuraWatch()
    end
    function PSA.RefreshRetailSupplyAuraWatch()
        UpdateAuraWatch()
    end
    UpdateAuraWatch()
end

local trackAmmo = PSA.GetForeverAmmo and PSA.SetAmmoAlert

local centralPetEvents = {
    "UNIT_PET", "PET_BAR_UPDATE", "PET_UI_UPDATE", "SPELLS_CHANGED",
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
local centralPetCareEvents = { "UNIT_HAPPINESS", "BAG_UPDATE", "ITEM_LOCK_CHANGED" }
local centralAmmoEvents = { "PLAYER_EQUIPMENT_CHANGED", "UNIT_INVENTORY_CHANGED" }

local function UpdateCentralEvents()
    local pet = petActive
    local buff = buffActive
    local petCare = pet and RefreshPetCare ~= nil
    local ammo = buff and trackAmmo ~= nil
    local buffWorld = buff and (trackAmmo ~= nil or HandleFoodBuffEvent ~= nil)
    local deathEvents = petCare or (buff and HandleFoodBuffEvent ~= nil)
    for _, event in ipairs(centralPetEvents) do SetEventRegistered(event, pet) end
    for _, event in ipairs(centralWorldEvents) do SetEventRegistered(event, pet or buffWorld) end
    for _, event in ipairs(centralDeathEvents) do
        SetEventRegistered(event, deathEvents)
    end
    for _, event in ipairs(centralPetCareEvents) do SetEventRegistered(event, petCare) end
    SetEventRegistered("BAG_UPDATE_DELAYED", petCare or ammo)
    for _, event in ipairs(centralAmmoEvents) do SetEventRegistered(event, ammo) end
    SetUnitEventRegistered("UNIT_ENTERED_VEHICLE", "player", pet)
    SetUnitEventRegistered("UNIT_EXITED_VEHICLE", "player", pet)
    SetUnitEventRegistered("UNIT_FLAGS", "pet", pet)
end

RegisterEventSafe("ADDON_LOADED")
UpdateCentralEvents()

local ammoRefreshPending = false
local function QueueAmmoRefresh()
    if not buffActive or ammoRefreshPending or InCombatLockdown() then
        return
    end
    ammoRefreshPending = true
    C_Timer.After(0, function()
        ammoRefreshPending = false
        if not buffActive or InCombatLockdown() then
            return
        end

        local threshold = PSA.GetAmmoThreshold()
        if threshold == 0 then
            PSA.SetAmmoAlert()
            return
        end
        local kind, count, texture = PSA.GetForeverAmmo()
        if not kind or (count and count >= threshold) then
            PSA.SetAmmoAlert()
        elseif count then
            PSA.SetAmmoAlert(kind, count, texture)
        end
    end)
end

if trackAmmo then
    PSA.QueueAmmoRefresh = QueueAmmoRefresh
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

local PET_FOOD_SOURCE_EVENTS = {
    PLAYER_ENTERING_WORLD = true,
    UNIT_PET = true,
    PET_UI_UPDATE = true,
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
    UNIT_AURA = true,
    ADDON_RESTRICTION_STATE_CHANGED = true,
    PLAYER_UPDATE_RESTING = true,
    PLAYER_LEVEL_UP = true,
    ENCOUNTER_START = true,
    ENCOUNTER_END = true,
}

local petCareRefreshPending = false
local foodMenuRefreshPending = false
local foodBagUpdateSeen = false
local function QueuePetCareRefresh(refreshFoodMenu)
    if not petActive or not RefreshPetCare then return end
    foodMenuRefreshPending = foodMenuRefreshPending or refreshFoodMenu
    if petCareRefreshPending then
        return
    end
    petCareRefreshPending = true
    C_Timer.After(0.05, function()
        petCareRefreshPending = false
        local refreshMenu = foodMenuRefreshPending
        foodMenuRefreshPending = false
        RefreshPetCare(refreshMenu)
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

local PET_READY_EVENTS = {
    PET_UI_UPDATE = true,
    SPELLS_CHANGED = true,
    LEARNED_SPELL_IN_SKILL_LINE = true,
    PLAYER_ENTERING_WORLD = true,
    UNIT_PET = true,
    PET_BAR_UPDATE = true,
    PLAYER_SPECIALIZATION_CHANGED = true,
    PLAYER_TALENT_UPDATE = true,
    TRAIT_CONFIG_UPDATED = true,
    TRAIT_CONFIG_LIST_UPDATED = true,
}

addonFrame:SetScript("OnEvent", function(_, event, unit, slot)
    if event == "ADDON_LOADED" then
        if unit == ADDON_NAME or unit == "PetStatusAlert" then
            InitDB(true)
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

    if not isForever and event == "UNIT_AURA" then
        if PSA.IsAccessibleValue(unit) and unit == "player" then
            if petActive and PSA.HandleWarriorAuraChanged then PSA.HandleWarriorAuraChanged() end
            if buffActive and PSA.HandleRetailSupplyAuraUpdate then PSA.HandleRetailSupplyAuraUpdate(slot) end
        end
        return
    end

    if (event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE") and unit ~= "player" then
        return
    end

    if (event == "UNIT_FLAGS" and unit ~= "pet") or (event == "UNIT_PET" and unit ~= "player") then
        return
    end

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

    if buffActive and trackAmmo then
        if event == "PLAYER_REGEN_DISABLED" then
            PSA.SetAmmoAlert()
        elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" or event == "BAG_UPDATE_DELAYED" then
            QueueAmmoRefresh()
        elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "UNIT_INVENTORY_CHANGED" then
            if event == "PLAYER_EQUIPMENT_CHANGED" or unit == "player" then
                QueueAmmoRefresh()
            end
            return
        end
    end

    if petActive and RefreshPetCare then
        if event == "PLAYER_REGEN_DISABLED" then
            RefreshPetCare()
        elseif event == "BAG_UPDATE" then
            InvalidatePetFood(unit)
            foodBagUpdateSeen = true
        elseif event == "BAG_UPDATE_DELAYED" then
            -- A delayed event without a bag ID still has to refresh all food data.
            if not foodBagUpdateSeen then
                InvalidatePetFood()
            end
            foodBagUpdateSeen = false
            QueuePetCareRefresh(true)
        elseif event == "ITEM_LOCK_CHANGED" then
            if slot and InvalidatePetFood(unit) and not InCombatLockdown() then
                QueuePetCareRefresh(true)
            end
        elseif PET_FOOD_SOURCE_EVENTS[event] then
            InvalidatePetFood()
            QueuePetCareRefresh(true)
        elseif PET_CARE_STATE_EVENTS[event] or (event == "UNIT_HAPPINESS" and unit == "pet") then
            QueuePetCareRefresh(false)
        end
    end
    if petActive and PET_CARE_ONLY_EVENTS[event] then
        return
    end
    if not petActive then return end

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

    if PET_READY_EVENTS[event] then
        QueueRefresh(0.08)
        if event ~= "PET_BAR_UPDATE" or not isForever then
            QueueRefresh(0.35)
        end
        if event == "PLAYER_ENTERING_WORLD" then
            QueueRefresh(1.00)
        end
        return
    end

    -- Pet flags and mount/control/vehicle state changes only need a single
    -- coalesced refresh. Food-only UNIT_AURA events return before the pet path.
    QueueRefresh(0.08)
end)

function PSA.ApplyAlertMasterSwitches()
    local nextPet = PSA.GetPetAlertsEnabled()
    local nextBuff = PSA.GetBuffAlertsEnabled()
    local petChanged = nextPet ~= petActive
    local buffChanged = nextBuff ~= buffActive
    local firstApply = not mastersInitialized
    petActive, buffActive = nextPet, nextBuff
    mastersInitialized = true
    UpdateCentralEvents()
    if PSA.RefreshRetailSupplyAuraWatch then PSA.RefreshRetailSupplyAuraWatch() end
    if PSA.SetWarriorAlertActivity then PSA.SetWarriorAlertActivity(petActive) end

    if petActive then
        if petChanged then
            if RefreshPetCare then RefreshPetCare() end
            if PSA.QueueRefresh then PSA.QueueRefresh(0.05) end
        end
    else
        if PSA.SetPetCareAlert then PSA.SetPetCareAlert(nil) end
        if PSA.StopCombatTTSReminder then PSA.StopCombatTTSReminder() end
        if PSA.HideStatus then PSA.HideStatus(true) end
    end

    if PSA.RefreshRetailBuffAlerts then PSA.RefreshRetailBuffAlerts() end
    if PSA.RefreshFoodBuffAlert then PSA.RefreshFoodBuffAlert(firstApply) end
    if not buffActive and PSA.SetAmmoAlert then PSA.SetAmmoAlert() end
    if buffActive and buffChanged and trackAmmo then QueueAmmoRefresh() end
    if PSA.RefreshFoodPicker then PSA.RefreshFoodPicker() end
end
