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

RegisterEventSafe("ADDON_LOADED")
RegisterEventSafe("PLAYER_ENTERING_WORLD")
RegisterEventSafe("UNIT_PET")
RegisterEventSafe("PET_BAR_UPDATE")
RegisterEventSafe("PET_UI_UPDATE")
RegisterEventSafe("SPELLS_CHANGED")
RegisterEventSafe("LEARNED_SPELL_IN_SKILL_LINE")
RegisterEventSafe("PLAYER_TALENT_UPDATE")
if not isForever then
    RegisterEventSafe("PLAYER_SPECIALIZATION_CHANGED")
    RegisterEventSafe("TRAIT_CONFIG_UPDATED")
    RegisterEventSafe("TRAIT_CONFIG_LIST_UPDATED")
end
RegisterEventSafe("PLAYER_CONTROL_LOST")
RegisterEventSafe("PLAYER_CONTROL_GAINED")
RegisterEventSafe("PLAYER_MOUNT_DISPLAY_CHANGED")
RegisterEventSafe("PLAYER_REGEN_DISABLED")
RegisterEventSafe("PLAYER_REGEN_ENABLED")
RegisterUnitEventSafe("UNIT_ENTERED_VEHICLE", "player")
RegisterUnitEventSafe("UNIT_EXITED_VEHICLE", "player")
RegisterUnitEventSafe("UNIT_FLAGS", "pet")

local trackAmmo = PSA.GetForeverAmmo and PSA.SetAmmoAlert
if trackAmmo then
    RegisterEventSafe("BAG_UPDATE_DELAYED")
    RegisterEventSafe("PLAYER_EQUIPMENT_CHANGED")
    RegisterEventSafe("UNIT_INVENTORY_CHANGED")
end

local ammoRefreshPending = false
local function QueueAmmoRefresh()
    if ammoRefreshPending or InCombatLockdown() then
        return
    end
    ammoRefreshPending = true
    C_Timer.After(0, function()
        ammoRefreshPending = false
        if InCombatLockdown() then
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

if RefreshPetCare then
    for event in pairs(PET_CARE_ONLY_EVENTS) do
        if event ~= "BAG_UPDATE_DELAYED" or not trackAmmo then
            RegisterEventSafe(event)
        end
    end
end

local petCareRefreshPending = false
local foodMenuRefreshPending = false
local foodBagUpdateSeen = false
local function QueuePetCareRefresh(refreshFoodMenu)
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
            RegisterNativeOptionsCategory()
        end
        return
    end

    if (event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE") and unit ~= "player" then
        return
    end

    if (event == "UNIT_FLAGS" and unit ~= "pet") or (event == "UNIT_PET" and unit ~= "player") then
        return
    end

    if trackAmmo then
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

    if RefreshPetCare then
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
    if PET_CARE_ONLY_EVENTS[event] then
        return
    end

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
    -- coalesced refresh. UNIT_AURA(player) is intentionally not registered because
    -- it causes frequent unrelated refreshes and is not required for pet status.
    QueueRefresh(0.08)
end)
