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
local RefreshCombatTTSReminder = PSA.RefreshCombatTTSReminder
local ClearPetStatusCaches = PSA.ClearPetStatusCaches

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
RegisterEventSafe("PLAYER_SPECIALIZATION_CHANGED")
RegisterEventSafe("PLAYER_TALENT_UPDATE")
RegisterEventSafe("TRAIT_CONFIG_UPDATED")
RegisterEventSafe("TRAIT_CONFIG_LIST_UPDATED")
RegisterEventSafe("PLAYER_CONTROL_LOST")
RegisterEventSafe("PLAYER_CONTROL_GAINED")
RegisterEventSafe("PLAYER_MOUNT_DISPLAY_CHANGED")
RegisterEventSafe("PLAYER_REGEN_DISABLED")
RegisterEventSafe("PLAYER_REGEN_ENABLED")
RegisterUnitEventSafe("UNIT_ENTERED_VEHICLE", "player")
RegisterUnitEventSafe("UNIT_EXITED_VEHICLE", "player")
RegisterUnitEventSafe("UNIT_FLAGS", "pet")

local CACHE_INVALIDATE_EVENTS = {
    PLAYER_ENTERING_WORLD = true,
    PLAYER_SPECIALIZATION_CHANGED = true,
    PLAYER_TALENT_UPDATE = true,
    TRAIT_CONFIG_UPDATED = true,
    TRAIT_CONFIG_LIST_UPDATED = true,
}

local PET_READY_EVENTS = {
    PLAYER_ENTERING_WORLD = true,
    UNIT_PET = true,
    PET_BAR_UPDATE = true,
    PLAYER_SPECIALIZATION_CHANGED = true,
    PLAYER_TALENT_UPDATE = true,
    TRAIT_CONFIG_UPDATED = true,
    TRAIT_CONFIG_LIST_UPDATED = true,
}

addonFrame:SetScript("OnEvent", function(_, event, unit)
    if event == "ADDON_LOADED" then
        if unit == ADDON_NAME or unit == "PetStatusAlert" then
            InitDB()
            RegisterNativeOptionsCategory()
        end
        return
    end

    if (event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE") and unit ~= "player" then
        return
    end

    if event == "UNIT_FLAGS" and unit ~= "pet" then
        return
    end

    if CACHE_INVALIDATE_EVENTS[event] and ClearPetStatusCaches then
        ClearPetStatusCaches()
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
        QueueRefresh(0.35)
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
