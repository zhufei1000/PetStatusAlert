-------------------------------------------------
-- PetStatusAlert combat TTS reminder
-------------------------------------------------

local ADDON_NAME, PSA = ...
PSA = PSA or _G.PetStatusAlert

local InitDB = PSA.InitDB
local Trim = PSA.Trim
local addonFrame = PSA.addonFrame
local text = PSA.alertText
local DEFAULT_COMBAT_TTS_RATE = PSA.DEFAULT_COMBAT_TTS_RATE or 3
local COMBAT_TTS_INTERVAL = 3
local combatTTSTicker

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

local function IsPlayerInCombatForTTS()
    return type(InCombatLockdown) == "function" and InCombatLockdown() == true
end

local function GetCurrentAlertSpeechText()
    if not addonFrame:IsShown() or PSA.currentStatusKey == nil then
        return nil
    end

    local value = text:GetText()
    value = Trim(value)
    if value == "" then
        return nil
    end

    return value
end

local function StopCombatTTSReminder()
    if combatTTSTicker then
        combatTTSTicker:Cancel()
        combatTTSTicker = nil
    end
end

local function GetTTSDestination()
    if type(Enum) == "table" and type(Enum.VoiceTtsDestination) == "table" then
        return Enum.VoiceTtsDestination.QueuedLocalPlayback
            or Enum.VoiceTtsDestination.LocalPlayback
            or 0
    end
    return 0
end

local function SpeakLocalTTS(spokenText)
    if type(C_VoiceChat) ~= "table" or type(C_VoiceChat.SpeakText) ~= "function" then
        return false
    end

    local rate = GetCombatTTSRate()
    local volume = 100

    -- Current WoW API: SpeakText(voiceID, text, rate, volume [, overlap]).
    -- Call this first. Passing the old destination argument here makes the saved
    -- speech rate become the volume, so the default rate 3 sounds like 3% volume.
    local ok = pcall(C_VoiceChat.SpeakText, 0, spokenText, rate, volume, false)
    if ok then
        return true
    end

    -- Compatibility fallback for old clients that still require a TTS destination.
    ok = pcall(C_VoiceChat.SpeakText, 0, spokenText, GetTTSDestination(), rate, volume)
    return ok and true or false
end

local function SpeakCurrentAlertText()
    if not IsCombatTTSEnabled() or not IsPlayerInCombatForTTS() then
        return
    end

    local spokenText = GetCurrentAlertSpeechText()
    if not spokenText then
        return
    end

    SpeakLocalTTS(spokenText)
end

local function RefreshCombatTTSReminder(playImmediately)
    if not IsCombatTTSEnabled() or not IsPlayerInCombatForTTS() or not GetCurrentAlertSpeechText() then
        StopCombatTTSReminder()
        return
    end

    if combatTTSTicker then
        return
    end

    if playImmediately then
        SpeakCurrentAlertText()
    end

    if type(C_Timer) == "table" and type(C_Timer.NewTicker) == "function" then
        combatTTSTicker = C_Timer.NewTicker(COMBAT_TTS_INTERVAL, function()
            if not IsCombatTTSEnabled() or not IsPlayerInCombatForTTS() or not GetCurrentAlertSpeechText() then
                StopCombatTTSReminder()
                return
            end
            SpeakCurrentAlertText()
        end)
    end
end


-------------------------------------------------
-- Public TTS API
-------------------------------------------------

PSA.IsCombatTTSEnabled = IsCombatTTSEnabled
PSA.GetCombatTTSRate = GetCombatTTSRate
PSA.SetCombatTTSRate = SetCombatTTSRate
PSA.GetCombatTTSRateDisplayText = GetCombatTTSRateDisplayText
PSA.StopCombatTTSReminder = StopCombatTTSReminder
PSA.RefreshCombatTTSReminder = RefreshCombatTTSReminder
