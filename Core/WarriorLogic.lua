-------------------------------------------------
-- PetStatusAlert Warrior stance support
-- Arms / Fury: warn while Defensive Stance is active
-------------------------------------------------

local ADDON_NAME, PSA = ...
PSA = PSA or _G.PetStatusAlert

local STATUS_KEY = "WARRIOR_DEFENSIVE_STANCE"
local SPEC_WARRIOR_ARMS = 71
local SPEC_WARRIOR_FURY = 72
local SPELL_DEFENSIVE_STANCE = 386208

local PET_STATUS_ORDER = {
    "NO_PET",
    "PET_DEAD",
    "PASSIVE",
    "DEFENSIVE",
    "UNKNOWN",
}

-------------------------------------------------
-- Localization extension
-------------------------------------------------

local function ExtendLocalization()
    local messages = PSA.LOCALIZED_MESSAGES
    local uiLocales = PSA.UI_LOCALE

    if type(messages) == "table" then
        if messages.enUS then
            messages.enUS[STATUS_KEY] = "I am currently in Defensive Stance"
        end
        if messages.zhCN then
            messages.zhCN[STATUS_KEY] = "当前处于：防御姿态"
        end
        if messages.zhTW then
            messages.zhTW[STATUS_KEY] = "目前處於：防禦姿態"
        end
        if messages.ruRU then
            messages.ruRU[STATUS_KEY] = "Сейчас включена защитная стойка"
        end
    end

    if type(uiLocales) == "table" then
        if uiLocales.enUS then
            uiLocales.enUS[STATUS_KEY] = "Warrior: Defensive Stance"
            uiLocales.enUS.SUBTITLE = "Customize warning text for supported pet states and class states. Leave blank to use the localized default."
            uiLocales.enUS.SUPPORT = "Supported: Hunter, Warlock, Unholy Death Knight, Frost Mage with Summon Water Elemental, Arms Warrior, Fury Warrior"
        end
        if uiLocales.zhCN then
            uiLocales.zhCN[STATUS_KEY] = "战士：防御姿态"
            uiLocales.zhCN.SUBTITLE = "自定义受支持的宠物状态和职业状态提醒文字。留空时自动使用当前语言的默认文字。"
            uiLocales.zhCN.SUPPORT = "支持：猎人、术士、邪恶死亡骑士、点出召唤水元素的冰霜法师、武器战士、狂暴战士"
        end
        if uiLocales.zhTW then
            uiLocales.zhTW[STATUS_KEY] = "戰士：防禦姿態"
            uiLocales.zhTW.SUBTITLE = "自訂受支援的寵物狀態與職業狀態提醒文字。留空時自動使用目前語言的預設文字。"
            uiLocales.zhTW.SUPPORT = "支援：獵人、術士、邪惡死亡騎士、點出召喚水元素的冰霜法師、武器戰士、狂怒戰士"
        end
        if uiLocales.ruRU then
            uiLocales.ruRU[STATUS_KEY] = "Воин: Защитная стойка"
            uiLocales.ruRU.SUBTITLE = "Настройте предупреждения для поддерживаемых состояний питомца и класса. Пустое поле использует локализованный текст по умолчанию."
            uiLocales.ruRU.SUPPORT = "Поддерживается: Охотник, Чернокнижник, Рыцарь смерти «Нечестивости», Маг «Льда» с элементалем воды, Воин «Оружие», Воин «Неистовство»"
        end
    end
end

local function GetPlayerSpecId()
    if type(PSA.GetPlayerSpecId) == "function" then
        return PSA.GetPlayerSpecId()
    end

    if type(GetSpecialization) ~= "function" or type(GetSpecializationInfo) ~= "function" then
        return 0
    end

    local specIndex = GetSpecialization()
    if not specIndex or specIndex <= 0 then
        return 0
    end

    return tonumber(select(1, GetSpecializationInfo(specIndex))) or 0
end

local function IsWarrior()
    if type(UnitClass) ~= "function" then
        return false
    end
    local _, classFile = UnitClass("player")
    return classFile == "WARRIOR"
end

local function SupportsWarriorStanceAlert()
    if not IsWarrior() then
        return false
    end

    local specId = GetPlayerSpecId()
    return specId == SPEC_WARRIOR_ARMS or specId == SPEC_WARRIOR_FURY
end

local function ReplaceStatusOrder(values)
    local order = PSA.STATUS_ORDER
    if type(order) ~= "table" then
        return
    end

    for index = #order, 1, -1 do
        order[index] = nil
    end

    for index, statusKey in ipairs(values) do
        order[index] = statusKey
    end
end

local function RefreshStatusOrderForPlayer()
    if not IsWarrior() then
        ReplaceStatusOrder(PET_STATUS_ORDER)
        return
    end

    if SupportsWarriorStanceAlert() then
        ReplaceStatusOrder({ STATUS_KEY })
    else
        -- Protection Warrior is intentionally unsupported for this warning.
        ReplaceStatusOrder({})
    end
end

ExtendLocalization()

-- RefreshLocaleTables replaces PSA.STATUS_LABEL with a new table each time.
-- Wrap it so the Warrior status label is restored after language changes.
local OriginalRefreshLocaleTables = PSA.RefreshLocaleTables
if type(OriginalRefreshLocaleTables) == "function" then
    PSA.RefreshLocaleTables = function(...)
        OriginalRefreshLocaleTables(...)
        local ui = PSA.UI
        if type(PSA.STATUS_LABEL) == "table" and type(ui) == "table" then
            PSA.STATUS_LABEL[STATUS_KEY] = ui[STATUS_KEY] or STATUS_KEY
        end
        RefreshStatusOrderForPlayer()
    end
end

if type(PSA.RefreshLocaleTables) == "function" then
    PSA.RefreshLocaleTables()
else
    RefreshStatusOrderForPlayer()
end

-- The redesigned Display page uses pet statuses as generic preview samples.
-- On Warrior, transparently redirect those samples to the Warrior stance alert
-- so the preview and status line never show unrelated pet text.
local OriginalGetDisplayMessage = PSA.GetDisplayMessage
if type(OriginalGetDisplayMessage) == "function" then
    PSA.GetDisplayMessage = function(statusKey, ...)
        if IsWarrior() and statusKey ~= STATUS_KEY then
            statusKey = STATUS_KEY
        end
        return OriginalGetDisplayMessage(statusKey, ...)
    end
end

local OriginalPreviewStatus = PSA.PreviewStatus
if type(OriginalPreviewStatus) == "function" then
    PSA.PreviewStatus = function(statusKey, ...)
        if IsWarrior() then
            statusKey = STATUS_KEY
        end
        return OriginalPreviewStatus(statusKey, ...)
    end
end

-------------------------------------------------
-- Defensive Stance aura detection
-------------------------------------------------

local function IsAuraSpellActive(spellID)
    spellID = tonumber(spellID)
    if not spellID then
        return false
    end

    if C_UnitAuras and type(C_UnitAuras.GetPlayerAuraBySpellID) == "function" then
        local ok, auraData = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
        if ok and auraData then
            return true
        end
    end

    if AuraUtil and type(AuraUtil.FindAuraBySpellID) == "function" then
        local ok, auraData = pcall(AuraUtil.FindAuraBySpellID, spellID, "player", "HELPFUL")
        if ok and auraData then
            return true
        end
    end

    -- Last-resort modern API scan. Only Warrior registers UNIT_AURA below,
    -- so this does not add aura-scan cost to pet classes.
    if C_UnitAuras and type(C_UnitAuras.GetAuraDataByIndex) == "function" then
        for index = 1, 40 do
            local ok, auraData = pcall(C_UnitAuras.GetAuraDataByIndex, "player", index, "HELPFUL")
            if not ok or not auraData then
                break
            end
            if tonumber(auraData.spellId or auraData.spellID) == spellID then
                return true
            end
        end
    end

    return false
end

local function IsDefensiveStanceActive()
    return IsAuraSpellActive(SPELL_DEFENSIVE_STANCE)
end

local function RefreshWarriorStatusText()
    if type(PSA.InitDB) == "function" then
        PSA.InitDB()
    end

    if not SupportsWarriorStanceAlert() then
        if type(PSA.HideStatus) == "function" then
            PSA.HideStatus()
        end
        return
    end

    if type(PSA.IsPlayerMountedOrInVehicle) == "function" then
        local okMounted, mounted = pcall(PSA.IsPlayerMountedOrInVehicle)
        if not okMounted or mounted then
            if type(PSA.HideStatus) == "function" then
                PSA.HideStatus()
            end
            return
        end
    end

    if IsDefensiveStanceActive() then
        if type(PSA.ShowStatus) == "function" then
            PSA.ShowStatus(STATUS_KEY)
        end
    elseif type(PSA.HideStatus) == "function" then
        PSA.HideStatus()
    end
end

-------------------------------------------------
-- Integrate with the existing refresh pipeline
-------------------------------------------------

local OriginalRefreshPetStatusText = PSA.RefreshPetStatusText
if type(OriginalRefreshPetStatusText) == "function" then
    PSA.RefreshPetStatusText = function(...)
        if IsWarrior() then
            return RefreshWarriorStatusText()
        end
        return OriginalRefreshPetStatusText(...)
    end
end

-- PetLogic.QueueRefresh closes over its original pet-only refresh function.
-- Replace the public queue for Warriors so Events.lua captures the Warrior-aware path.
local OriginalQueueRefresh = PSA.QueueRefresh
local warriorQueuedRefreshTimers = {}

PSA.QueueRefresh = function(delaySeconds)
    if not IsWarrior() then
        if type(OriginalQueueRefresh) == "function" then
            return OriginalQueueRefresh(delaySeconds)
        end
        return
    end

    delaySeconds = tonumber(delaySeconds) or 0.05
    if delaySeconds < 0 then
        delaySeconds = 0
    end

    local key = string.format("%.2f", delaySeconds)
    if warriorQueuedRefreshTimers[key] then
        return
    end
    warriorQueuedRefreshTimers[key] = true

    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(delaySeconds, function()
            warriorQueuedRefreshTimers[key] = nil
            RefreshWarriorStatusText()
        end)
    else
        warriorQueuedRefreshTimers[key] = nil
        RefreshWarriorStatusText()
    end
end

local OriginalClearPetStatusCaches = PSA.ClearPetStatusCaches
PSA.ClearPetStatusCaches = function(...)
    if type(OriginalClearPetStatusCaches) == "function" then
        OriginalClearPetStatusCaches(...)
    end
    RefreshStatusOrderForPlayer()
end

-------------------------------------------------
-- Warrior-only events
-------------------------------------------------

if IsWarrior() then
    local warriorEventFrame = CreateFrame("Frame")

    if warriorEventFrame.RegisterUnitEvent then
        pcall(warriorEventFrame.RegisterUnitEvent, warriorEventFrame, "UNIT_AURA", "player")
    else
        pcall(warriorEventFrame.RegisterEvent, warriorEventFrame, "UNIT_AURA")
    end
    pcall(warriorEventFrame.RegisterEvent, warriorEventFrame, "PLAYER_SPECIALIZATION_CHANGED")
    pcall(warriorEventFrame.RegisterEvent, warriorEventFrame, "PLAYER_ENTERING_WORLD")

    warriorEventFrame:SetScript("OnEvent", function(_, event, unit)
        if event == "UNIT_AURA" then
            if unit and unit ~= "player" then
                return
            end
            PSA.QueueRefresh(0.02)
            return
        end

        if event == "PLAYER_SPECIALIZATION_CHANGED" and unit and unit ~= "player" then
            return
        end

        RefreshStatusOrderForPlayer()
        PSA.QueueRefresh(0.08)

        if type(PSA.RefreshOptionsFrameLocale) == "function" then
            PSA.RefreshOptionsFrameLocale()
        end
    end)
end

-------------------------------------------------
-- Public Warrior API
-------------------------------------------------

PSA.WARRIOR_DEFENSIVE_STANCE_STATUS_KEY = STATUS_KEY
PSA.WARRIOR_DEFENSIVE_STANCE_SPELL_ID = SPELL_DEFENSIVE_STANCE
PSA.SupportsWarriorStanceAlert = SupportsWarriorStanceAlert
PSA.IsWarriorDefensiveStanceActive = IsDefensiveStanceActive
PSA.RefreshWarriorStatusText = RefreshWarriorStatusText
PSA.RefreshStatusOrderForPlayer = RefreshStatusOrderForPlayer
