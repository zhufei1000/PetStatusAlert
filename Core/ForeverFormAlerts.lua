local _, PSA = ...

if not PSA.IsForeverClient() then return end

local iconSpells = PSA.FOREVER_FORM_ALERT_SPELLS
for _, classFile in ipairs(PSA.GetAlertClasses(true)) do
    for _, key in ipairs(PSA.GetForeverFormAlertStatuses(classFile) or {}) do
        PSA.RegisterStatusIcon(classFile, key, iconSpells[key])
    end
end

local playerClass = PSA.GetPlayerClassFile()
local statuses = PSA.GetForeverFormAlertStatuses(playerClass)
if not statuses then return end

for index = #PSA.STATUS_ORDER, 1, -1 do PSA.STATUS_ORDER[index] = nil end
for index, key in ipairs(statuses) do PSA.STATUS_ORDER[index] = key end

local PreviewStatus, GetDisplayMessage = PSA.PreviewStatus, PSA.GetDisplayMessage
PSA.PreviewStatus = function(statusKey, classFile)
    if classFile or iconSpells[statusKey] then return PreviewStatus(statusKey, classFile or playerClass) end
    PSA.HideStatus()
end
PSA.GetDisplayMessage = function(statusKey, classFile)
    if classFile or iconSpells[statusKey] then return GetDisplayMessage(statusKey, classFile) end
    return ""
end

local function IsAlertEnabled(key)
    return PSA.IsStatusEnabled(key, playerClass)
end

local activeKey

function PSA.HasEnabledForeverFormAlerts()
    if not PSA.ReadForeverFormAlert then return false end
    for _, key in ipairs(statuses) do
        if IsAlertEnabled(key) then return true end
    end
    return false
end

function PSA.ResetForeverFormAlertState()
    activeKey = nil
end

local function Render()
    if activeKey and not PSA.IsPlayerMountedOrInVehicle() then
        PSA.ShowStatus(activeKey)
    else
        PSA.HideStatus()
    end
end

function PSA.RefreshForeverFormAlert()
    local dead = UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")
    if not PSA.HasEnabledForeverFormAlerts() or (PSA.IsAccessibleValue(dead) and dead) then
        PSA.ResetForeverFormAlertState()
    elseif not InCombatLockdown() then
        activeKey = PSA.ReadForeverFormAlert(playerClass)
    end
    Render()
end

function PSA.HandleForeverFormAlertCast(unit, spellID)
    if not PSA.IsAccessibleValue(unit) or unit ~= "player"
        or not PSA.IsAccessibleValue(spellID) or type(spellID) ~= "number" then return end
    local key = PSA.GetForeverFormAlertBySpell(playerClass, spellID)
    if not key then return end

    activeKey = key
    if InCombatLockdown() then Render() else PSA.QueueRefresh(0.08) end
end

local menuTitle = "FOREVER_" .. playerClass .. "_FORM_MENU"
local function ToggleAlert(key)
    PSA.SetStatusEnabled(key, not IsAlertEnabled(key), playerClass)
end

function PSA.OpenForeverFormAlertMenu()
    -- Keep the menu open when a selection hides the alert.
    MenuUtil.CreateContextMenu(nil, function(_, root)
        root:CreateTitle(PSA.UI[menuTitle])
        for _, key in ipairs(statuses) do
            root:CreateCheckbox(PSA.STATUS_LABEL[key], IsAlertEnabled, ToggleAlert, key)
        end
    end)
end
