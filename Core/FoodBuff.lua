local _, PSA = ...

if not PSA.ReadFoodBuff then return end

local frame = PSA.addonFrame
local enabled, watching, queued = false, false, false
local inEncounter, showXP = false, false
local present, foodInstanceID

local function WatchAura(watch)
    if watching == watch then return end
    watching = watch
    if watch then
        frame:RegisterUnitEvent("UNIT_AURA", "player")
    else
        frame:UnregisterEvent("UNIT_AURA")
    end
end

local function SetFoodState(newPresent, instanceID)
    present, foodInstanceID = newPresent, instanceID
    local missing = present == false
    PSA.SetFoodBuffAlert(missing, missing and showXP)
end

local function Eligible()
    return enabled and not inEncounter and not InCombatLockdown()
        and not IsResting() and not UnitIsDeadOrGhost("player")
end

local function StandDown()
    WatchAura(false)
    SetFoodState(nil)
end

local function Refresh()
    if not Eligible() or not PSA.CanReadFoodAuras() then
        StandDown()
        return
    end
    WatchAura(true)
    SetFoodState(PSA.ReadFoodBuff())
end

local function QueueRefresh()
    if queued then return end
    queued = true
    C_Timer.After(0, function()
        queued = false
        Refresh()
    end)
end

function PSA.RefreshFoodBuffAlert()
    local wanted = PSA.GetFoodBuffAlertEnabled()
    if enabled ~= wanted then
        enabled = wanted
        for _, event in ipairs({
            "PLAYER_UPDATE_RESTING", "PLAYER_LEVEL_UP", "ENCOUNTER_START", "ENCOUNTER_END",
            "ADDON_RESTRICTION_STATE_CHANGED",
        }) do
            if enabled then frame:RegisterEvent(event) else frame:UnregisterEvent(event) end
        end
        if enabled then inEncounter = IsEncounterInProgress and IsEncounterInProgress() or false end
    end
    if enabled then
        showXP = PSA.IsBelowForeverLevelCap()
        QueueRefresh()
    else
        StandDown()
    end
end

function PSA.HandleFoodBuffEvent(event, arg1, arg2)
    if event == "PLAYER_ENTERING_WORLD" then
        inEncounter = IsEncounterInProgress and IsEncounterInProgress() or false
        PSA.RefreshFoodBuffAlert()
        return
    end
    if not enabled then return end

    if event == "PLAYER_LEVEL_UP" then
        showXP = PSA.IsBelowForeverLevelCap(arg1)
        if present == false then PSA.SetFoodBuffAlert(true, showXP) end
    elseif event == "ENCOUNTER_START" then
        inEncounter = true
        StandDown()
    elseif event == "ENCOUNTER_END" then
        inEncounter = false
        QueueRefresh()
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_DEAD"
        or (event == "PLAYER_UPDATE_RESTING" and IsResting()) then
        StandDown()
    elseif event == "UNIT_AURA" then
        -- Only the player's readable events reach this filter.
        if InCombatLockdown() or not PSA.CanReadFoodAuras() then
            StandDown()
        elseif PSA.FoodAuraMayHaveChanged(arg2, present, foodInstanceID) then
            QueueRefresh()
        end
    else
        -- Restriction events can arrive before the new state is applied.
        QueueRefresh()
    end
end
