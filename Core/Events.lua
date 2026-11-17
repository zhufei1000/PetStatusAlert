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
local HandleForeverFormAlertCast = PSA.HandleForeverFormAlertCast
local ResetForeverFormAlertState = PSA.ResetForeverFormAlertState
local isForever = PSA.IsForeverClient()
local canWatchPetFeedingAura = isForever and C_UnitAuras and C_UnitAuras.GetUnitAuraBySpellID

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

local registeredEvents, registeredUnitEvents = {}, {}

local function SetEventRegistered(event, active)
    if active then
        if registeredEvents[event] then return end
        registeredEvents[event] = true
        RegisterEventSafe(event)
    elseif registeredEvents[event] then
        registeredEvents[event] = nil
        UnregisterEventSafe(event)
    end
end

local function SetUnitEventRegistered(event, unit, active)
    local key = event .. ":" .. (unit or "")
    if active then
        if registeredUnitEvents[key] then return end
        registeredUnitEvents[key] = true
        RegisterUnitEventSafe(event, unit)
    elseif registeredUnitEvents[key] then
        registeredUnitEvents[key] = nil
        UnregisterEventSafe(event)
    end
end

local watchingWarriorAuras = false
function PSA.RefreshWarriorAuraWatch()
    local watch = not isForever and PSA.WantsWarriorAuraWatch and PSA.WantsWarriorAuraWatch() or false
    if watch == watchingWarriorAuras then return end
    watchingWarriorAuras = watch
    SetUnitEventRegistered("UNIT_AURA", "player", watch)
end

PSA.RefreshWarriorAuraWatch()

local trackAmmo = isForever and PSA.GetForeverAmmo and PSA.SetAmmoAlert
local ammoThreshold = 0
local function GetActiveAmmoThreshold()
    return PSA.GetAmmoAlertEnabled() and PSA.GetAmmoThreshold() or 0
end

local petCareWatch, feedingWatch = false, false
local petAutocastWatch, petAutocastRefreshPending = false, false

local function RunPetAutocastRefresh()
    petAutocastRefreshPending = false
    if petAutocastWatch then PSA.RefreshPetAutocast() end
end

local function QueuePetAutocastRefresh()
    if not petAutocastWatch or petAutocastRefreshPending then return end
    petAutocastRefreshPending = true
    -- Zone, roster and pet bar events can arrive together on world entry.
    C_Timer.After(0.15, RunPetAutocastRefresh)
end

if PSA.RefreshPetAutocast then
    function PSA.ApplyPetAutocastSettings()
        local watch = playerClass == "HUNTER" and PSA.GetClassOption("petAutocastAlertEnabled")
        petAutocastWatch = watch
        SetEventRegistered("GROUP_ROSTER_UPDATE", watch)
        SetEventRegistered("ZONE_CHANGED_NEW_AREA", watch)
        if watch then QueuePetAutocastRefresh() else PSA.SetPetAutocastAlert() end
    end
end

local PET_AUTOCAST_STATE_EVENTS = {
    PLAYER_ENTERING_WORLD = true,
    GROUP_ROSTER_UPDATE = true,
    ZONE_CHANGED_NEW_AREA = true,
    UNIT_PET = true,
    UNIT_FLAGS = true,
    PET_BAR_UPDATE = true,
    PET_UI_UPDATE = true,
    SPELLS_CHANGED = true,
    LEARNED_SPELL_IN_SKILL_LINE = true,
    PLAYER_REGEN_ENABLED = true,
}

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
    local pet = hasClassAlerts
    local usesFormBar = isForever and PSA.GetForeverFormAlertStatuses(playerClass)
    local watchForms = pet and usesFormBar
    local hasPet = pet and playerClass ~= "WARRIOR" and not usesFormBar
    local ammo = ammoThreshold > 0
    local deathEvents = petCareWatch or watchForms
    for _, event in ipairs(centralPetEvents) do SetEventRegistered(event, pet) end
    for _, event in ipairs(centralWorldEvents) do SetEventRegistered(event, pet or ammo) end
    for _, event in ipairs(centralDeathEvents) do
        SetEventRegistered(event, deathEvents)
    end
    for _, event in ipairs(centralPetCareEvents) do SetEventRegistered(event, feedingWatch) end
    SetEventRegistered("BAG_UPDATE_DELAYED", feedingWatch or ammo)
    SetEventRegistered("PLAYER_EQUIPMENT_CHANGED", ammo)
    SetUnitEventRegistered("UNIT_INVENTORY_CHANGED", "player", ammo)
    SetUnitEventRegistered("UNIT_HAPPINESS", "pet", petCareWatch)
    if canWatchPetFeedingAura then SetUnitEventRegistered("UNIT_AURA", "pet", feedingWatch) end
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

local function RunAmmoRefresh()
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
end

local function QueueAmmoRefresh()
    if ammoThreshold == 0 or ammoRefreshPending or InCombatLockdown() then
        return
    end
    ammoRefreshPending = true
    C_Timer.After(0, RunAmmoRefresh)
end

if isForever and trackAmmo then
    function PSA.ApplyAmmoAlertSettings()
        local wasWatching = ammoThreshold > 0
        ammoThreshold = GetActiveAmmoThreshold()
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

local petCareRefreshPending = false
local foodMenuRefreshPending = false
local foodBagUpdateSeen, foodBagChanged = false, false

local function UpdatePetCareWatch()
    local canWatch = hasClassAlerts and RefreshPetCare ~= nil
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

local function RunPetCareRefresh()
    petCareRefreshPending = false
    local refreshMenu = foodMenuRefreshPending
    foodMenuRefreshPending = false
    if petCareWatch then RefreshPetCare(refreshMenu) end
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
    C_Timer.After(0.15, RunPetCareRefresh)
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
    -- Mount and vehicle state changed; drop the cached value before any status
    -- check so the next refresh reads the real state once.
    if event == "PLAYER_MOUNT_DISPLAY_CHANGED" or event == "PLAYER_CONTROL_LOST"
        or event == "PLAYER_CONTROL_GAINED" or event == "PLAYER_ENTERING_WORLD"
        or event == "UNIT_PET"
        or ((event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE") and unit == "player") then
        if PSA.InvalidatePlayerMountState then PSA.InvalidatePlayerMountState() end
    end

    -- Pet action buttons only change on these events; everything else can reuse
    -- the cached stance instead of walking the ten pet action slots again.
    if event == "UNIT_PET" or event == "PET_BAR_UPDATE" or event == "PET_UI_UPDATE"
        or (event == "UNIT_FLAGS" and unit == "pet")
        or event == "PLAYER_CONTROL_LOST" or event == "PLAYER_CONTROL_GAINED"
        or event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        if PSA.InvalidatePetMode then PSA.InvalidatePetMode() end
    end

    if event == "ADDON_LOADED" then
        if unit == ADDON_NAME or unit == "PetStatusAlert" then
            UnregisterEventSafe("ADDON_LOADED")
            InitDB(true)
            UpdatePlayerClass()
            if PSA.InvalidatePlayerMountState then PSA.InvalidatePlayerMountState() end
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
            UpdatePetCareWatch()
            if PSA.ApplyPetAutocastSettings then PSA.ApplyPetAutocastSettings() end
            if trackAmmo then
                ammoThreshold = GetActiveAmmoThreshold()
                QueueAmmoRefresh()
            end
            UpdateCentralEvents()
            PSA.RefreshWarriorAuraWatch()
            if PSA.RefreshCombatAspectAlert then PSA.RefreshCombatAspectAlert() end
            RegisterNativeOptionsCategory()
        end
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if hasClassAlerts and HandleForeverFormAlertCast then
            HandleForeverFormAlertCast(unit, spellID)
        end
        return
    end

    if not playerClass and event == "PLAYER_ENTERING_WORLD" then
        UpdatePlayerClass()
        if playerClass then
            UpdatePetCareWatch()
            if PSA.ApplyPetAutocastSettings then PSA.ApplyPetAutocastSettings() end
            UpdateCentralEvents()
            if PSA.RefreshCombatAspectAlert then PSA.RefreshCombatAspectAlert() end
        end
    end

    if event == "UNIT_AURA" then
        if not PSA.IsAccessibleValue(unit) then return end
        if unit == "pet" and canWatchPetFeedingAura and feedingWatch and not InCombatLockdown() then
            QueuePetCareRefresh(false)
        elseif unit == "player" and PSA.HandleWarriorAuraChanged then
            PSA.HandleWarriorAuraChanged(slot)
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

    if petAutocastWatch and PET_AUTOCAST_STATE_EVENTS[event] then QueuePetAutocastRefresh() end
    if event == "GROUP_ROSTER_UPDATE" or event == "ZONE_CHANGED_NEW_AREA" then return end

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
    if hasClassAlerts and ResetForeverFormAlertState then
        if event == "PLAYER_ENTERING_WORLD" then
            ResetForeverFormAlertState()
        elseif event == "PLAYER_DEAD" then
            ResetForeverFormAlertState()
            PSA.HideStatus()
        elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
            QueueRefresh(0.08)
        end
    end
    if PET_CARE_ONLY_EVENTS[event] then
        return
    end
    if not hasClassAlerts then return end

    if playerClass ~= "WARRIOR" and (event == "PLAYER_MOUNT_DISPLAY_CHANGED" or event == "PLAYER_ENTERING_WORLD") then
        PSA.UpdatePetDismountGrace(event == "PLAYER_ENTERING_WORLD")
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

    -- Only world entry and pet swaps can outlast the normal event batch.
    QueueRefresh(0.08)
    if event == "PLAYER_ENTERING_WORLD" or event == "UNIT_PET" then
        QueueRefresh(0.35)
        if event == "PLAYER_ENTERING_WORLD" then QueueRefresh(1.00) end
    end
end)
