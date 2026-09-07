-------------------------------------------------
-- PetStatusAlert
-- Hunter / Warlock / Unholy DK / Frost Mage pet status prompt
-- Version: 1.4.1
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
local DEFAULT_ALERT_GLOW_SPEED = 1
-- 1.4.0：图标提醒模式。both=图标+文字（默认）；text=纯文字；icon=纯图标。
local DEFAULT_ALERT_ICON_MODE = "both"
-- 图标边长（像素），默认 48，与默认字号 28 协调。
local DEFAULT_ALERT_ICON_SIZE = 48
-- 图标与文字之间的间距（像素）。
local DEFAULT_ALERT_ICON_GAP = 10
local VALID_ALERT_ICON_MODES = { text = true, icon = true, both = true }

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

    -- 默认关闭：战斗中 TTS 语音提醒。
    if PetStatusAlertDB.combatTTSEnabled == nil then
        PetStatusAlertDB.combatTTSEnabled = false
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

    -- 1.4.0：图标提醒模式。默认图文模式。
    if type(PetStatusAlertDB.alertIconMode) ~= "string" or not VALID_ALERT_ICON_MODES[PetStatusAlertDB.alertIconMode] then
        PetStatusAlertDB.alertIconMode = DEFAULT_ALERT_ICON_MODE
    end

    -- 1.4.0 默认值迁移：仅强制切换为图文模式。
    -- TTS / UNKNOWN 只影响新用户默认值；老用户已配置的按个人习惯保留。
    if PetStatusAlertDB.v140DefaultsMigrated ~= true then
        PetStatusAlertDB.alertIconMode = "both"
        PetStatusAlertDB.v140DefaultsMigrated = true
    end

    -- 图标边长（像素）。范围 24~96，默认 48。
    if PetStatusAlertDB.alertIconSize == nil then
        PetStatusAlertDB.alertIconSize = DEFAULT_ALERT_ICON_SIZE
    end
    PetStatusAlertDB.alertIconSize = tonumber(PetStatusAlertDB.alertIconSize) or DEFAULT_ALERT_ICON_SIZE
    if PetStatusAlertDB.alertIconSize < 24 then
        PetStatusAlertDB.alertIconSize = 24
    elseif PetStatusAlertDB.alertIconSize > 96 then
        PetStatusAlertDB.alertIconSize = 96
    end

    -- 图标与文字间距（像素）。范围 0~40，默认 10。纯图标模式不使用此值。
    if PetStatusAlertDB.alertIconGap == nil then
        PetStatusAlertDB.alertIconGap = DEFAULT_ALERT_ICON_GAP
    end
    PetStatusAlertDB.alertIconGap = tonumber(PetStatusAlertDB.alertIconGap) or DEFAULT_ALERT_ICON_GAP
    if PetStatusAlertDB.alertIconGap < 0 then
        PetStatusAlertDB.alertIconGap = 0
    elseif PetStatusAlertDB.alertIconGap > 40 then
        PetStatusAlertDB.alertIconGap = 40
    end

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
PSA.DEFAULT_ALERT_GLOW_SPEED = DEFAULT_ALERT_GLOW_SPEED
PSA.DEFAULT_ALERT_ICON_MODE = DEFAULT_ALERT_ICON_MODE
PSA.DEFAULT_ALERT_ICON_SIZE = DEFAULT_ALERT_ICON_SIZE
PSA.DEFAULT_ALERT_ICON_GAP = DEFAULT_ALERT_ICON_GAP
PSA.VALID_ALERT_ICON_MODES = VALID_ALERT_ICON_MODES
PSA.Trim = Trim
PSA.InitDB = InitDB
