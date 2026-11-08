-------------------------------------------------
-- PetStatusAlert
-- Hunter / Warlock / Unholy DK / Frost Mage pet status prompt + Warrior stance alerts
-- Version: 1.6.0
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
local DEFAULT_ALERT_GLOW_ENABLED = true
local DEFAULT_ALERT_GLOW_SPEED = 1
-- 1.4.0：图标提醒模式。both=图标+文字（默认）；text=纯文字；icon=纯图标。
local DEFAULT_ALERT_ICON_MODE = "both"
-- 图标边长（像素），默认 48，与默认字号 28 协调。
local DEFAULT_ALERT_ICON_SIZE = 48
-- 图标与文字之间的间距（像素）。
local DEFAULT_ALERT_ICON_GAP = 10
local DEFAULT_AMMO_THRESHOLD = 100
local MAX_AMMO_THRESHOLD = 9999
local VALID_ALERT_ICON_MODES = { text = true, icon = true, both = true }

-------------------------------------------------
-- SavedVariables
-------------------------------------------------

local function Trim(value)
    value = tostring(value or "")
    value = value:gsub("^%s+", "")
    value = value:gsub("%s+$", "")
    return value
end

local function InitDB(force)
    -- 初始化/迁移一次即可。ShowStatus 链上会多次调用 InitDB，重复执行
    -- 只会带来无意义的 tonumber/范围钳制和 SavedVariables 写回。
    if PSA.dbInitialized and type(PetStatusAlertDB) == "table" and not force then
        return PetStatusAlertDB
    end

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
    PetStatusAlertDB.combatTTSRate = tonumber(PetStatusAlertDB.combatTTSRate) or DEFAULT_COMBAT_TTS_RATE
    if PetStatusAlertDB.combatTTSRate < -10 then
        PetStatusAlertDB.combatTTSRate = -10
    elseif PetStatusAlertDB.combatTTSRate > 10 then
        PetStatusAlertDB.combatTTSRate = 10
    end

    -- 屏幕提示字体大小。
    PetStatusAlertDB.alertFontSize = tonumber(PetStatusAlertDB.alertFontSize) or DEFAULT_ALERT_FONT_SIZE
    if PetStatusAlertDB.alertFontSize < 12 then
        PetStatusAlertDB.alertFontSize = 12
    elseif PetStatusAlertDB.alertFontSize > 72 then
        PetStatusAlertDB.alertFontSize = 72
    end

    -- 提示文字上下浮动动画幅度：默认沿用旧版本固定数值 8。
    PetStatusAlertDB.alertFloatAmplitude = tonumber(PetStatusAlertDB.alertFloatAmplitude) or DEFAULT_ALERT_FLOAT_AMPLITUDE
    if PetStatusAlertDB.alertFloatAmplitude < 0 then
        PetStatusAlertDB.alertFloatAmplitude = 0
    elseif PetStatusAlertDB.alertFloatAmplitude > 24 then
        PetStatusAlertDB.alertFloatAmplitude = 24
    end

    -- 提示文字上下浮动速度倍率：1 = 旧版本速度。
    PetStatusAlertDB.alertFloatSpeed = tonumber(PetStatusAlertDB.alertFloatSpeed) or DEFAULT_ALERT_FLOAT_SPEED
    if PetStatusAlertDB.alertFloatSpeed < 0.1 then
        PetStatusAlertDB.alertFloatSpeed = 0.1
    elseif PetStatusAlertDB.alertFloatSpeed > 3 then
        PetStatusAlertDB.alertFloatSpeed = 3
    end

    -- The old default and a manual opt-out were both saved as false.
    -- Migrate that value once to the new per-alert defaults; keep explicit opt-ins.
    if PetStatusAlertDB.alertGlowDefaultsMigrated ~= true then
        if PetStatusAlertDB.alertGlowEnabled ~= true then
            PetStatusAlertDB.alertGlowEnabled = nil
        end
        PetStatusAlertDB.alertGlowDefaultsMigrated = true
    end

    -- 像素流光速度：1 = 默认速度。
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

    -- 图标边长（像素）。范围 24~96，默认 48。
    PetStatusAlertDB.alertIconSize = tonumber(PetStatusAlertDB.alertIconSize) or DEFAULT_ALERT_ICON_SIZE
    if PetStatusAlertDB.alertIconSize < 24 then
        PetStatusAlertDB.alertIconSize = 24
    elseif PetStatusAlertDB.alertIconSize > 96 then
        PetStatusAlertDB.alertIconSize = 96
    end

    -- 图标与文字间距（像素）。范围 0~40，默认 10。纯图标模式不使用此值。
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

    PSA.dbInitialized = true
    return PetStatusAlertDB
end

local function NormalizeAmmoThreshold(value)
    value = tonumber(value)
    if value and value == value then
        return math.floor(math.max(0, math.min(value, MAX_AMMO_THRESHOLD)))
    end
end

function PSA.GetAmmoThreshold()
    return NormalizeAmmoThreshold(InitDB().ammoThreshold) or DEFAULT_AMMO_THRESHOLD
end

function PSA.SetAmmoThreshold(value)
    local db = InitDB()
    local current = PSA.GetAmmoThreshold()
    local threshold = NormalizeAmmoThreshold(value) or current
    if threshold ~= current then
        db.ammoThreshold = threshold
        if PSA.QueueAmmoRefresh then
            PSA.QueueAmmoRefresh()
        end
    end
    return threshold
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
