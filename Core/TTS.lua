-------------------------------------------------
-- PetStatusAlert combat TTS reminder
-------------------------------------------------

local _, PSA = ...
PSA = PSA or _G.PetStatusAlert

local InitDB = PSA.InitDB
local Trim = PSA.Trim
local addonFrame = PSA.addonFrame
local text = PSA.alertText
local DEFAULT_COMBAT_TTS_RATE = PSA.DEFAULT_COMBAT_TTS_RATE or 3
local DEFAULT_COMBAT_TTS_INTERVAL = 3
local combatTTSTicker, spokenKey, spokenClass, spokenText

local UI = setmetatable({}, {
    __index = function(_, key)
        return PSA.UI and PSA.UI[key]
    end,
})

-------------------------------------------------
-- Combat TTS voice reminder
-------------------------------------------------

local function IsCombatTTSEnabled()
    InitDB()
    return PetStatusAlertDB.combatTTSEnabled == true
end

local function GetCombatTTSRate()
    InitDB()
    local rate = tonumber(PetStatusAlertDB.combatTTSRate) or DEFAULT_COMBAT_TTS_RATE
    if rate < -10 then
        rate = -10
    elseif rate > 10 then
        rate = 10
    end
    return rate
end

local function SetCombatTTSRate(value)
    InitDB()
    local rate = math.floor((tonumber(value) or 0) + 0.5)
    if rate < -10 then
        rate = -10
    elseif rate > 10 then
        rate = 10
    end
    PetStatusAlertDB.combatTTSRate = rate
    return rate
end

local function GetCombatTTSRateDisplayText()
    return string.format(UI.COMBAT_TTS_RATE_VALUE or "Speed: %s", tostring(GetCombatTTSRate()))
end

local function NormalizeRepeatInterval(value)
    value = tonumber(value)
    if not value or value ~= value then return DEFAULT_COMBAT_TTS_INTERVAL end
    return math.max(2, math.min(15, math.floor(value + 0.5)))
end

local function GetCombatTTSInterval()
    local value = tonumber(InitDB().combatTTSInterval)
    return value == 0 and 0 or NormalizeRepeatInterval(value)
end

local function GetCombatTTSRepeatInterval()
    local interval = GetCombatTTSInterval()
    return interval > 0 and interval or NormalizeRepeatInterval(InitDB().combatTTSLastRepeatInterval)
end

local function IsPlayerInCombatForTTS()
    return type(InCombatLockdown) == "function" and InCombatLockdown() == true
end

-- 去掉颜色/链接/纹理转义，避免 TTS 把 |cff00ff00 之类的代码念出来。
local function StripChatMarkup(value)
    value = tostring(value or "")
    value = value:gsub("|c%x%x%x%x%x%x%x%x", "")
    value = value:gsub("|r", "")
    value = value:gsub("|T.-|t", "")
    value = value:gsub("|A.-|a", "")
    value = value:gsub("|H.-|h", "")
    value = value:gsub("|h", "")
    value = value:gsub("[\r\n]+", " ")
    return value
end

local function GetCurrentAlertSpeechText()
    if not addonFrame:IsShown() or PSA.currentStatusKey == nil then
        return nil
    end
    if PSA.currentStatusForce then
        return nil
    end

    -- 纯图标模式下文字是隐藏的，设置页文案也说明只朗读“可见”的提示文字。
    if text.IsShown and not text:IsShown() then
        return nil
    end

    local value = Trim(StripChatMarkup(text:GetText()))
    if value == "" then
        return nil
    end

    return value
end

local function CancelTicker()
    if combatTTSTicker then
        combatTTSTicker:Cancel()
        combatTTSTicker = nil
    end
end

local function StopCombatTTSReminder()
    CancelTicker()
    spokenKey, spokenClass, spokenText = nil, nil, nil
end

local function SpeakLocalTTS(spokenText)
    if type(C_VoiceChat) ~= "table" or type(C_VoiceChat.SpeakText) ~= "function" then
        return false
    end

    local rate = GetCombatTTSRate()
    return pcall(C_VoiceChat.SpeakText, 0, spokenText, rate, 100, false)
end

local function SpeakCurrentAlertText()
    if not IsCombatTTSEnabled() or not IsPlayerInCombatForTTS() then
        return
    end

    local message = GetCurrentAlertSpeechText()
    if not message then
        return
    end

    if SpeakLocalTTS(message) then
        spokenKey, spokenClass, spokenText = PSA.currentStatusKey, PSA.currentStatusClass, message
    end
end

local function RefreshCombatTTSReminder(playImmediately)
    local message = GetCurrentAlertSpeechText()
    if not IsCombatTTSEnabled() or not IsPlayerInCombatForTTS() or not message then
        StopCombatTTSReminder()
        return
    end

    local interval = GetCombatTTSInterval()
    if interval == 0 then
        CancelTicker()
        if spokenKey ~= PSA.currentStatusKey or spokenClass ~= PSA.currentStatusClass or spokenText ~= message then
            SpeakCurrentAlertText()
        end
        return
    end

    if combatTTSTicker then
        return
    end

    if playImmediately then
        SpeakCurrentAlertText()
    end

    if type(C_Timer) == "table" and type(C_Timer.NewTicker) == "function" then
        combatTTSTicker = C_Timer.NewTicker(interval, function()
            if not IsCombatTTSEnabled() or not IsPlayerInCombatForTTS() or not GetCurrentAlertSpeechText() then
                StopCombatTTSReminder()
                return
            end
            SpeakCurrentAlertText()
        end)
    end
end

local function SetCombatTTSInterval(value)
    value = tonumber(value)
    if not value or value ~= value then return GetCombatTTSInterval() end
    value = value == 0 and 0 or NormalizeRepeatInterval(value)
    local previous = GetCombatTTSInterval()
    if value ~= previous then
        local db = InitDB()
        if value == 0 then db.combatTTSLastRepeatInterval = previous end
        db.combatTTSInterval = value
        CancelTicker()
        RefreshCombatTTSReminder(false)
    end
    return value
end


-------------------------------------------------
-- Public TTS API
-------------------------------------------------

PSA.GetCombatTTSRate = GetCombatTTSRate
PSA.SetCombatTTSRate = SetCombatTTSRate
PSA.GetCombatTTSRateDisplayText = GetCombatTTSRateDisplayText
PSA.GetCombatTTSInterval = GetCombatTTSInterval
PSA.GetCombatTTSRepeatInterval = GetCombatTTSRepeatInterval
PSA.SetCombatTTSInterval = SetCombatTTSInterval
PSA.PlayCombatTTSSample = function() return SpeakLocalTTS(UI.PREVIEW_SAMPLE) end
PSA.StopCombatTTSReminder = StopCombatTTSReminder
PSA.RefreshCombatTTSReminder = RefreshCombatTTSReminder
