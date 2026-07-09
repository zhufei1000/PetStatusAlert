-------------------------------------------------
-- PetStatusAlert
-- Hunter / Warlock / Unholy DK / Frost Mage pet status prompt
-- Version: 1.3.23
-------------------------------------------------

local ADDON_NAME, PSA = ...
ADDON_NAME = ADDON_NAME or "PetStatusAlert"
PSA = PSA or _G.PetStatusAlert or {}
_G.PetStatusAlert = PSA
PSA.ADDON_NAME = ADDON_NAME

local DEFAULT_COMBAT_TTS_RATE = 3
local DEFAULT_ALERT_FLOAT_AMPLITUDE = 8
local DEFAULT_ALERT_FLOAT_SPEED = 1
local DEFAULT_ALERT_FONT_SIZE = 28
local DEFAULT_ALERT_GLOW_ENABLED = false
local DEFAULT_ALERT_GLOW_PADDING = 0
local DEFAULT_ALERT_GLOW_THICKNESS = 2
local OLD_ALERT_GLOW_PADDING_DEFAULT = 18
local TIGHT_ALERT_GLOW_PADDING_DEFAULT = 4
local DEFAULT_ALERT_GLOW_TYPE = "Pixel"
local DEFAULT_ALERT_GLOW_SPEED = 1

-------------------------------------------------
-- SavedVariables
-------------------------------------------------

PetStatusAlertDB = type(PetStatusAlertDB) == "table" and PetStatusAlertDB or {}

local function Trim(value)
    value = tostring(value or "")
    value = value:gsub("^%s+", "")
    value = value:gsub("%s+$", "")
    return value
end

local function InitDB()
    PetStatusAlertDB = type(PetStatusAlertDB) == "table" and PetStatusAlertDB or {}
    PetStatusAlertDB.customMessages = type(PetStatusAlertDB.customMessages) == "table" and PetStatusAlertDB.customMessages or {}
    PetStatusAlertDB.textColors = type(PetStatusAlertDB.textColors) == "table" and PetStatusAlertDB.textColors or {}
    PetStatusAlertDB.statusEnabled = type(PetStatusAlertDB.statusEnabled) == "table" and PetStatusAlertDB.statusEnabled or {}

    -- 默认锁定提示文字位置；旧版本用户升级后也会保持默认锁定。
    if PetStatusAlertDB.alertLocked == nil then
        PetStatusAlertDB.alertLocked = true
    end

    -- 默认开启：战斗中 TTS 语音提醒。
    if PetStatusAlertDB.combatTTSEnabled == nil then
        PetStatusAlertDB.combatTTSEnabled = true
    end

    -- TTS 语速：C_VoiceChat.SpeakText 的 rate 参数；新用户默认 3，0 = 游戏默认语速。
    if PetStatusAlertDB.combatTTSRate == nil then
        PetStatusAlertDB.combatTTSRate = DEFAULT_COMBAT_TTS_RATE
    end
    PetStatusAlertDB.combatTTSRate = tonumber(PetStatusAlertDB.combatTTSRate) or DEFAULT_COMBAT_TTS_RATE
    if PetStatusAlertDB.combatTTSRate < -10 then
        PetStatusAlertDB.combatTTSRate = -10
    elseif PetStatusAlertDB.combatTTSRate > 10 then
        PetStatusAlertDB.combatTTSRate = 10
    end

    -- 屏幕提示字体大小。
    if PetStatusAlertDB.alertFontSize == nil then
        PetStatusAlertDB.alertFontSize = DEFAULT_ALERT_FONT_SIZE
    end
    PetStatusAlertDB.alertFontSize = tonumber(PetStatusAlertDB.alertFontSize) or DEFAULT_ALERT_FONT_SIZE
    if PetStatusAlertDB.alertFontSize < 12 then
        PetStatusAlertDB.alertFontSize = 12
    elseif PetStatusAlertDB.alertFontSize > 72 then
        PetStatusAlertDB.alertFontSize = 72
    end

    -- 提示文字上下浮动动画幅度：默认沿用旧版本固定数值 8。
    if PetStatusAlertDB.alertFloatAmplitude == nil then
        PetStatusAlertDB.alertFloatAmplitude = DEFAULT_ALERT_FLOAT_AMPLITUDE
    end
    PetStatusAlertDB.alertFloatAmplitude = tonumber(PetStatusAlertDB.alertFloatAmplitude) or DEFAULT_ALERT_FLOAT_AMPLITUDE
    if PetStatusAlertDB.alertFloatAmplitude < 0 then
        PetStatusAlertDB.alertFloatAmplitude = 0
    elseif PetStatusAlertDB.alertFloatAmplitude > 24 then
        PetStatusAlertDB.alertFloatAmplitude = 24
    end

    -- 提示文字上下浮动速度倍率：1 = 旧版本速度。
    if PetStatusAlertDB.alertFloatSpeed == nil then
        PetStatusAlertDB.alertFloatSpeed = DEFAULT_ALERT_FLOAT_SPEED
    end
    PetStatusAlertDB.alertFloatSpeed = tonumber(PetStatusAlertDB.alertFloatSpeed) or DEFAULT_ALERT_FLOAT_SPEED
    if PetStatusAlertDB.alertFloatSpeed < 0.1 then
        PetStatusAlertDB.alertFloatSpeed = 0.1
    elseif PetStatusAlertDB.alertFloatSpeed > 3 then
        PetStatusAlertDB.alertFloatSpeed = 3
    end

    -- 动态发光边框设置：边框是围绕文字外层透明 Frame 的动画，不是每个字的笔画动画。
    -- 1.3.14：像素流光默认关闭；旧版本默认开启的配置升级后也关闭一次，避免玩家更新后自动显示流光。
    if PetStatusAlertDB.alertGlowDefaultOffMigrated ~= true then
        if PetStatusAlertDB.alertGlowEnabled == nil or PetStatusAlertDB.alertGlowEnabled == true then
            PetStatusAlertDB.alertGlowEnabled = DEFAULT_ALERT_GLOW_ENABLED
        end
        PetStatusAlertDB.alertGlowDefaultOffMigrated = true
    elseif PetStatusAlertDB.alertGlowEnabled == nil then
        PetStatusAlertDB.alertGlowEnabled = DEFAULT_ALERT_GLOW_ENABLED
    end
    PetStatusAlertDB.alertGlowEnabled = PetStatusAlertDB.alertGlowEnabled and true or false

    -- 1.3.13：像素流光只保留速度可调；距离和粗细固定为默认值，避免旧隐藏设置影响观感。
    PetStatusAlertDB.alertGlowPadding = DEFAULT_ALERT_GLOW_PADDING
    PetStatusAlertDB.alertGlowThickness = DEFAULT_ALERT_GLOW_THICKNESS

    -- 像素流光速度：1 = 默认速度。只保留 Pixel Glow，旧发光类型统一迁移。
    if PetStatusAlertDB.alertGlowSpeed == nil then
        PetStatusAlertDB.alertGlowSpeed = DEFAULT_ALERT_GLOW_SPEED
    end
    PetStatusAlertDB.alertGlowSpeed = tonumber(PetStatusAlertDB.alertGlowSpeed) or DEFAULT_ALERT_GLOW_SPEED
    if PetStatusAlertDB.alertGlowSpeed < 0.2 then
        PetStatusAlertDB.alertGlowSpeed = 0.2
    elseif PetStatusAlertDB.alertGlowSpeed > 3 then
        PetStatusAlertDB.alertGlowSpeed = 3
    end

    -- 1.3.13：只保留像素流光，不再暴露多发光类型选择。
    PetStatusAlertDB.alertGlowType = DEFAULT_ALERT_GLOW_TYPE

    -- 语言设置：默认跟随客户端；也可手动强制切换。
    local language = tostring(PetStatusAlertDB.language or "auto")
    if language ~= "auto" and language ~= "enUS" and language ~= "zhCN" and language ~= "zhTW" and language ~= "ruRU" then
        language = "auto"
    end
    PetStatusAlertDB.language = language

    -- 默认位置保持之前版本的位置：屏幕中央上方 220。
    if type(PetStatusAlertDB.alertPosition) ~= "table" then
        PetStatusAlertDB.alertPosition = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = 220,
        }
    end

    PetStatusAlertDB.alertPosition.point = PetStatusAlertDB.alertPosition.point or "CENTER"
    PetStatusAlertDB.alertPosition.relativePoint = PetStatusAlertDB.alertPosition.relativePoint or "CENTER"
    PetStatusAlertDB.alertPosition.x = tonumber(PetStatusAlertDB.alertPosition.x) or 0
    PetStatusAlertDB.alertPosition.y = tonumber(PetStatusAlertDB.alertPosition.y) or 220
end


-------------------------------------------------
-- Public database API
-------------------------------------------------

PSA.DEFAULT_COMBAT_TTS_RATE = DEFAULT_COMBAT_TTS_RATE
PSA.DEFAULT_ALERT_FLOAT_AMPLITUDE = DEFAULT_ALERT_FLOAT_AMPLITUDE
PSA.DEFAULT_ALERT_FLOAT_SPEED = DEFAULT_ALERT_FLOAT_SPEED
PSA.DEFAULT_ALERT_FONT_SIZE = DEFAULT_ALERT_FONT_SIZE
PSA.DEFAULT_ALERT_GLOW_ENABLED = DEFAULT_ALERT_GLOW_ENABLED
PSA.DEFAULT_ALERT_GLOW_PADDING = DEFAULT_ALERT_GLOW_PADDING
PSA.DEFAULT_ALERT_GLOW_THICKNESS = DEFAULT_ALERT_GLOW_THICKNESS
PSA.DEFAULT_ALERT_GLOW_TYPE = DEFAULT_ALERT_GLOW_TYPE
PSA.DEFAULT_ALERT_GLOW_SPEED = DEFAULT_ALERT_GLOW_SPEED
PSA.Trim = Trim
PSA.InitDB = InitDB
