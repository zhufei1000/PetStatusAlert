-------------------------------------------------
-- PetStatusAlert alert frame
-------------------------------------------------

local ADDON_NAME, PSA = ...
PSA = PSA or _G.PetStatusAlert

local InitDB = PSA.InitDB
local GetStatusColor = PSA.GetStatusColor
local GetDisplayMessage = PSA.GetDisplayMessage
local IsStatusEnabled = PSA.IsStatusEnabled
local DEFAULT_ALERT_FLOAT_AMPLITUDE = PSA.DEFAULT_ALERT_FLOAT_AMPLITUDE or 8
local DEFAULT_ALERT_FLOAT_SPEED = PSA.DEFAULT_ALERT_FLOAT_SPEED or 1
local DEFAULT_ALERT_FONT_SIZE = PSA.DEFAULT_ALERT_FONT_SIZE or 28
local DEFAULT_ALERT_GLOW_ENABLED = PSA.DEFAULT_ALERT_GLOW_ENABLED ~= false
local DEFAULT_ALERT_GLOW_PADDING = PSA.DEFAULT_ALERT_GLOW_PADDING or 0
local DEFAULT_ALERT_GLOW_THICKNESS = PSA.DEFAULT_ALERT_GLOW_THICKNESS or 2
local DEFAULT_ALERT_GLOW_TYPE = "Pixel"
local DEFAULT_ALERT_GLOW_SPEED = PSA.DEFAULT_ALERT_GLOW_SPEED or 1
local DEFAULT_ALERT_GLOW_COLOR = {0.95, 0.95, 0.32, 1}
local ALERT_GLOW_KEY = "PetStatusAlert_Glow"

local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)

local addonFrame = CreateFrame("Frame", "PetStatusAlertFrame", UIParent)
addonFrame:SetSize(780, 86)
addonFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 220)
addonFrame:SetClampedToScreen(true)
addonFrame:SetMovable(true)
addonFrame:EnableMouse(false)
addonFrame:RegisterForDrag("LeftButton")
addonFrame:Hide()

-- 透明外层边框：文本本身仍然是 FontString，动态发光套在这个透明 Frame 上。
local glowFrame = CreateFrame("Frame", nil, addonFrame)
glowFrame:SetPoint("CENTER", addonFrame, "CENTER", 0, 0)
glowFrame:SetSize(240, 58)
if glowFrame.SetFrameLevel then
    glowFrame:SetFrameLevel((addonFrame:GetFrameLevel() or 1) + 1)
end
glowFrame:Hide()

-- 文本单独放在更高层，避免发光纹理盖住文字本体。
local textFrame = CreateFrame("Frame", nil, addonFrame)
textFrame:SetAllPoints(addonFrame)
textFrame:EnableMouse(false)
if textFrame.SetFrameLevel then
    textFrame:SetFrameLevel((glowFrame:GetFrameLevel() or 1) + 20)
end

-- 只显示文字，不创建任何透明底色框。
local text = textFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
text:SetPoint("CENTER", textFrame, "CENTER", 0, 0)
text:SetFont(STANDARD_TEXT_FONT, DEFAULT_ALERT_FONT_SIZE, "OUTLINE")
text:SetTextColor(1, 0.12, 0.08, 1)
text:SetShadowColor(0, 0, 0, 1)
text:SetShadowOffset(2, -2)
text:SetText("")

local function ClampNumber(value, fallback, minValue, maxValue, decimals)
    value = tonumber(value)
    if value == nil then
        value = fallback
    end
    if decimals and decimals > 0 then
        local multiplier = 10 ^ decimals
        value = math.floor(value * multiplier + 0.5) / multiplier
    else
        value = math.floor(value + 0.5)
    end
    if value < minValue then
        value = minValue
    elseif value > maxValue then
        value = maxValue
    end
    return value
end

local function NormalizeAlertFontSize(value)
    return ClampNumber(value, DEFAULT_ALERT_FONT_SIZE, 12, 72)
end

local function NormalizeFloatAmplitude(value)
    return ClampNumber(value, DEFAULT_ALERT_FLOAT_AMPLITUDE, 0, 24)
end

local function NormalizeFloatSpeed(value)
    return ClampNumber(value, DEFAULT_ALERT_FLOAT_SPEED, 0.1, 3, 1)
end

local function NormalizeGlowPadding(value)
    return ClampNumber(value, DEFAULT_ALERT_GLOW_PADDING, 0, 60)
end

local function NormalizeGlowThickness(value)
    return ClampNumber(value, DEFAULT_ALERT_GLOW_THICKNESS, 1, 8)
end

local function NormalizeGlowSpeed(value)
    return ClampNumber(value, DEFAULT_ALERT_GLOW_SPEED, 0.2, 3, 1)
end

local function NormalizeGlowType(value)
    return DEFAULT_ALERT_GLOW_TYPE
end

local FLOAT_PERIOD = 1.5
local FLOAT_UPDATE_INTERVAL = 0.05
local floatElapsed = 0
local floatUpdateElapsed = 0
local lastFloatOffset
local floatingActive = false
local currentFloatAmplitude = DEFAULT_ALERT_FLOAT_AMPLITUDE
local currentFloatSpeed = DEFAULT_ALERT_FLOAT_SPEED
local currentAlertFontSize = DEFAULT_ALERT_FONT_SIZE
local currentGlowPadding = DEFAULT_ALERT_GLOW_PADDING
local currentGlowThickness = DEFAULT_ALERT_GLOW_THICKNESS
local currentGlowType = DEFAULT_ALERT_GLOW_TYPE
local currentGlowSpeed = DEFAULT_ALERT_GLOW_SPEED
local currentGlowEnabled = DEFAULT_ALERT_GLOW_ENABLED
local lastMessage = ""
local lastStatusKey = nil

local function ApplyAlertTextColor(statusKey)
    local r, g, b, a = GetStatusColor(statusKey or "UNKNOWN")
    text:SetTextColor(r, g, b, a)
end

local function RefreshAlertFontSize()
    InitDB()
    currentAlertFontSize = NormalizeAlertFontSize(PetStatusAlertDB.alertFontSize)
    PetStatusAlertDB.alertFontSize = currentAlertFontSize
    return currentAlertFontSize
end

local function RefreshAlertFloatAmplitude()
    InitDB()
    currentFloatAmplitude = NormalizeFloatAmplitude(PetStatusAlertDB.alertFloatAmplitude)
    PetStatusAlertDB.alertFloatAmplitude = currentFloatAmplitude
    return currentFloatAmplitude
end

local function RefreshAlertFloatSpeed()
    InitDB()
    currentFloatSpeed = NormalizeFloatSpeed(PetStatusAlertDB.alertFloatSpeed)
    PetStatusAlertDB.alertFloatSpeed = currentFloatSpeed
    return currentFloatSpeed
end

local function RefreshAlertGlowEnabled()
    InitDB()
    currentGlowEnabled = PetStatusAlertDB.alertGlowEnabled and true or false
    PetStatusAlertDB.alertGlowEnabled = currentGlowEnabled
    return currentGlowEnabled
end

local function RefreshAlertGlowPadding()
    InitDB()
    currentGlowPadding = NormalizeGlowPadding(PetStatusAlertDB.alertGlowPadding)
    PetStatusAlertDB.alertGlowPadding = currentGlowPadding
    return currentGlowPadding
end

local function RefreshAlertGlowThickness()
    InitDB()
    currentGlowThickness = NormalizeGlowThickness(PetStatusAlertDB.alertGlowThickness)
    PetStatusAlertDB.alertGlowThickness = currentGlowThickness
    return currentGlowThickness
end

local function RefreshAlertGlowSpeed()
    InitDB()
    currentGlowSpeed = NormalizeGlowSpeed(PetStatusAlertDB.alertGlowSpeed)
    PetStatusAlertDB.alertGlowSpeed = currentGlowSpeed
    return currentGlowSpeed
end

local function RefreshAlertGlowType()
    InitDB()
    currentGlowType = NormalizeGlowType(PetStatusAlertDB.alertGlowType)
    PetStatusAlertDB.alertGlowType = currentGlowType
    return currentGlowType
end

local function StopAlertGlow()
    if LCG and LCG.PixelGlow_Stop then
        LCG.PixelGlow_Stop(glowFrame, ALERT_GLOW_KEY)
        LCG.PixelGlow_Stop(glowFrame)
    end
    glowFrame:Hide()
end

local function RefreshAlertBoxSize()
    RefreshAlertFontSize()
    RefreshAlertGlowPadding()
    RefreshAlertGlowThickness()

    text:SetFont(STANDARD_TEXT_FONT, currentAlertFontSize, "OUTLINE")

    local textWidth = text:GetStringWidth() or 0
    local textHeight = text:GetStringHeight() or currentAlertFontSize
    local boxWidth = math.max(math.ceil(textWidth + currentGlowPadding * 2), 40)
    local boxHeight = math.max(math.ceil(textHeight + currentGlowPadding * 2), currentAlertFontSize + 6)

    addonFrame:SetSize(math.max(boxWidth, 80), math.max(boxHeight, 32))
    glowFrame:SetSize(boxWidth, boxHeight)
end

local function ApplyFloatOffset(y)
    y = tonumber(y) or 0
    if lastFloatOffset ~= nil and math.abs(y - lastFloatOffset) < 0.05 then
        return
    end
    lastFloatOffset = y

    text:ClearAllPoints()
    text:SetPoint("CENTER", textFrame, "CENTER", 0, y)

    if currentGlowEnabled and glowFrame:IsShown() then
        glowFrame:ClearAllPoints()
        glowFrame:SetPoint("CENTER", addonFrame, "CENTER", 0, y)
    end
end

local function OnAlertUpdate(_, elapsed)
    elapsed = tonumber(elapsed) or 0
    floatElapsed = floatElapsed + elapsed
    floatUpdateElapsed = floatUpdateElapsed + elapsed
    if floatUpdateElapsed < FLOAT_UPDATE_INTERVAL then
        return
    end
    floatUpdateElapsed = 0

    local phase = ((floatElapsed * currentFloatSpeed) / FLOAT_PERIOD) * (math.pi * 2)
    ApplyFloatOffset(math.sin(phase) * currentFloatAmplitude)
end

local function UpdateFloatingScript()
    local shouldFloat = addonFrame:IsShown() and currentFloatAmplitude > 0 and currentFloatSpeed > 0
    if shouldFloat and not floatingActive then
        floatingActive = true
        floatUpdateElapsed = 0
        lastFloatOffset = nil
        addonFrame:SetScript("OnUpdate", OnAlertUpdate)
        return
    end

    if not shouldFloat and floatingActive then
        floatingActive = false
        addonFrame:SetScript("OnUpdate", nil)
        floatElapsed = 0
        floatUpdateElapsed = 0
        lastFloatOffset = nil
        ApplyFloatOffset(0)
        return
    end

    if not shouldFloat then
        ApplyFloatOffset(0)
    end
end

local function StartAlertGlow()
    RefreshAlertGlowEnabled()
    if not currentGlowEnabled then
        if glowFrame:IsShown() then
            StopAlertGlow()
        end
        return
    end

    RefreshAlertGlowType()
    RefreshAlertGlowSpeed()
    RefreshAlertBoxSize()

    if not addonFrame:IsShown() or text:GetText() == "" then
        StopAlertGlow()
        return
    end

    if not LCG or not LCG.PixelGlow_Start then
        StopAlertGlow()
        return
    end

    local color = DEFAULT_ALERT_GLOW_COLOR
    local length = math.max(8, math.floor(currentAlertFontSize * 0.38 + 0.5))
    local frameLevel = 8
    local frequency = 0.2 * currentGlowSpeed

    StopAlertGlow()
    glowFrame:Show()
    LCG.PixelGlow_Start(
        glowFrame,
        color,
        8,
        frequency,
        length,
        currentGlowThickness,
        0,
        0,
        false,
        ALERT_GLOW_KEY,
        frameLevel
    )
end

local function RefreshAlertVisuals()
    RefreshAlertFloatAmplitude()
    RefreshAlertFloatSpeed()
    RefreshAlertBoxSize()
    UpdateFloatingScript()
    if addonFrame:IsShown() then
        StartAlertGlow()
    end
end

local function SetAlertFontSize(value)
    InitDB()
    currentAlertFontSize = NormalizeAlertFontSize(value)
    PetStatusAlertDB.alertFontSize = currentAlertFontSize
    RefreshAlertVisuals()
    return currentAlertFontSize
end

local function GetAlertFontSize()
    return RefreshAlertFontSize()
end

local function SetAlertFloatAmplitude(value)
    InitDB()
    currentFloatAmplitude = NormalizeFloatAmplitude(value)
    PetStatusAlertDB.alertFloatAmplitude = currentFloatAmplitude
    RefreshAlertVisuals()
    return currentFloatAmplitude
end

local function GetAlertFloatAmplitude()
    return RefreshAlertFloatAmplitude()
end

local function SetAlertFloatSpeed(value)
    InitDB()
    currentFloatSpeed = NormalizeFloatSpeed(value)
    PetStatusAlertDB.alertFloatSpeed = currentFloatSpeed
    RefreshAlertVisuals()
    return currentFloatSpeed
end

local function GetAlertFloatSpeed()
    return RefreshAlertFloatSpeed()
end

local function SetAlertGlowEnabled(enabled)
    InitDB()
    currentGlowEnabled = enabled and true or false
    PetStatusAlertDB.alertGlowEnabled = currentGlowEnabled
    RefreshAlertVisuals()
    return currentGlowEnabled
end

local function GetAlertGlowEnabled()
    return RefreshAlertGlowEnabled()
end

local function SetAlertGlowPadding(value)
    InitDB()
    currentGlowPadding = NormalizeGlowPadding(value)
    PetStatusAlertDB.alertGlowPadding = currentGlowPadding
    RefreshAlertVisuals()
    return currentGlowPadding
end

local function GetAlertGlowPadding()
    return RefreshAlertGlowPadding()
end

local function SetAlertGlowThickness(value)
    InitDB()
    currentGlowThickness = NormalizeGlowThickness(value)
    PetStatusAlertDB.alertGlowThickness = currentGlowThickness
    RefreshAlertVisuals()
    return currentGlowThickness
end

local function GetAlertGlowThickness()
    return RefreshAlertGlowThickness()
end

local function SetAlertGlowSpeed(value)
    InitDB()
    currentGlowSpeed = NormalizeGlowSpeed(value)
    PetStatusAlertDB.alertGlowSpeed = currentGlowSpeed
    RefreshAlertVisuals()
    return currentGlowSpeed
end

local function GetAlertGlowSpeed()
    return RefreshAlertGlowSpeed()
end

local function SetAlertGlowType(value)
    InitDB()
    currentGlowType = NormalizeGlowType(value)
    PetStatusAlertDB.alertGlowType = currentGlowType
    RefreshAlertVisuals()
    return currentGlowType
end

local function GetAlertGlowType()
    return RefreshAlertGlowType()
end

RefreshAlertVisuals()
PSA.currentStatusKey = nil
PSA.currentStatusForce = false

local function ApplyAlertPosition()
    InitDB()
    local pos = PetStatusAlertDB.alertPosition
    addonFrame:ClearAllPoints()
    addonFrame:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", tonumber(pos.x) or 0, tonumber(pos.y) or 220)
end

local function SaveAlertPosition()
    InitDB()
    local point, _, relativePoint, x, y = addonFrame:GetPoint(1)
    PetStatusAlertDB.alertPosition = {
        point = point or "CENTER",
        relativePoint = relativePoint or "CENTER",
        x = tonumber(x) or 0,
        y = tonumber(y) or 220,
    }
end

local function SetAlertPositionLocked(locked)
    InitDB()
    PetStatusAlertDB.alertLocked = locked and true or false
    addonFrame:EnableMouse(not PetStatusAlertDB.alertLocked)
end

addonFrame:SetScript("OnDragStart", function(self)
    InitDB()
    if PetStatusAlertDB.alertLocked then
        return
    end
    self:StartMoving()
end)

addonFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SaveAlertPosition()
end)

ApplyAlertPosition()
SetAlertPositionLocked(PetStatusAlertDB.alertLocked)

local function SetMessage(message, statusKey)
    message = tostring(message or "")
    PSA.currentStatusKey = statusKey
    ApplyAlertTextColor(statusKey or "UNKNOWN")

    local changed = message ~= lastMessage or statusKey ~= lastStatusKey
    if changed then
        lastMessage = message
        lastStatusKey = statusKey
        text:SetText(message)
        RefreshAlertBoxSize()
    end
    return changed
end

local HideStatus

local function ShowStatus(statusKey, force)
    if not force and not IsStatusEnabled(statusKey) then
        HideStatus()
        return
    end

    local wasShown = addonFrame:IsShown()
    PSA.currentStatusForce = force and true or false
    local changed = SetMessage(GetDisplayMessage(statusKey), statusKey)

    if not wasShown then
        addonFrame:Show()
        changed = true
    end

    UpdateFloatingScript()
    if changed then
        StartAlertGlow()
    end

    if PSA.RefreshCombatTTSReminder then
        PSA.RefreshCombatTTSReminder(changed)
    end
end

local function PreviewStatus(statusKey)
    ShowStatus(statusKey, true)
end

HideStatus = function()
    local wasShown = addonFrame:IsShown()
    if not wasShown and PSA.currentStatusKey == nil and lastMessage == "" then
        if PSA.StopCombatTTSReminder then
            PSA.StopCombatTTSReminder()
        end
        return
    end

    PSA.currentStatusKey = nil
    PSA.currentStatusForce = false
    SetMessage("", nil)
    StopAlertGlow()
    if wasShown then
        addonFrame:Hide()
    end
    UpdateFloatingScript()
    if PSA.StopCombatTTSReminder then
        PSA.StopCombatTTSReminder()
    end
end


-------------------------------------------------
-- Public alert frame API
-------------------------------------------------

PSA.addonFrame = addonFrame
PSA.alertText = text
PSA.alertGlowFrame = glowFrame
PSA.alertTextFrame = textFrame
PSA.ApplyAlertTextColor = ApplyAlertTextColor
PSA.ApplyAlertPosition = ApplyAlertPosition
PSA.SaveAlertPosition = SaveAlertPosition
PSA.SetAlertPositionLocked = SetAlertPositionLocked
PSA.GetAlertFontSize = GetAlertFontSize
PSA.SetAlertFontSize = SetAlertFontSize
PSA.RefreshAlertFontSize = RefreshAlertFontSize
PSA.GetAlertFloatAmplitude = GetAlertFloatAmplitude
PSA.SetAlertFloatAmplitude = SetAlertFloatAmplitude
PSA.RefreshAlertFloatAmplitude = RefreshAlertFloatAmplitude
PSA.GetAlertFloatSpeed = GetAlertFloatSpeed
PSA.SetAlertFloatSpeed = SetAlertFloatSpeed
PSA.RefreshAlertFloatSpeed = RefreshAlertFloatSpeed
PSA.GetAlertGlowEnabled = GetAlertGlowEnabled
PSA.SetAlertGlowEnabled = SetAlertGlowEnabled
PSA.RefreshAlertGlowEnabled = RefreshAlertGlowEnabled
PSA.GetAlertGlowPadding = GetAlertGlowPadding
PSA.SetAlertGlowPadding = SetAlertGlowPadding
PSA.RefreshAlertGlowPadding = RefreshAlertGlowPadding
PSA.GetAlertGlowThickness = GetAlertGlowThickness
PSA.SetAlertGlowThickness = SetAlertGlowThickness
PSA.RefreshAlertGlowThickness = RefreshAlertGlowThickness
PSA.GetAlertGlowSpeed = GetAlertGlowSpeed
PSA.SetAlertGlowSpeed = SetAlertGlowSpeed
PSA.RefreshAlertGlowSpeed = RefreshAlertGlowSpeed
PSA.GetAlertGlowType = GetAlertGlowType
PSA.SetAlertGlowType = SetAlertGlowType
PSA.RefreshAlertGlowType = RefreshAlertGlowType
PSA.RefreshAlertVisuals = RefreshAlertVisuals
PSA.StartAlertGlow = StartAlertGlow
PSA.StopAlertGlow = StopAlertGlow
PSA.SetMessage = SetMessage
PSA.ShowStatus = ShowStatus
PSA.PreviewStatus = PreviewStatus
PSA.HideStatus = HideStatus
