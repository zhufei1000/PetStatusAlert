-------------------------------------------------
-- PetStatusAlert UI / Options
-------------------------------------------------

local ADDON_NAME, PSA = ...
PSA = PSA or _G.PetStatusAlert

local InitDB = PSA.InitDB
local GetActiveLocale = PSA.GetActiveLocale
local GetSavedLanguageMode = PSA.GetSavedLanguageMode
local RefreshLocaleTables = PSA.RefreshLocaleTables
local GetDefaultMessage = PSA.GetDefaultMessage
local GetDisplayMessage = PSA.GetDisplayMessage
local IsStatusEnabled = PSA.IsStatusEnabled
local SetStatusEnabled = PSA.SetStatusEnabled
local GetStatusColor = PSA.GetStatusColor
local SetStatusColor = PSA.SetStatusColor
local ResetStatusColor = PSA.ResetStatusColor
local ApplyAlertTextColor = PSA.ApplyAlertTextColor
local ApplyAlertPosition = PSA.ApplyAlertPosition
local SetAlertPositionLocked = PSA.SetAlertPositionLocked
local PreviewStatus = PSA.PreviewStatus
local ShowStatus = PSA.ShowStatus
local GetCombatTTSRate = PSA.GetCombatTTSRate
local SetCombatTTSRate = PSA.SetCombatTTSRate
local GetCombatTTSRateDisplayText = PSA.GetCombatTTSRateDisplayText
local RefreshPetStatusText = PSA.RefreshPetStatusText
local RefreshCombatTTSReminder = PSA.RefreshCombatTTSReminder
local StopCombatTTSReminder = PSA.StopCombatTTSReminder
local GetAlertFontSize = PSA.GetAlertFontSize
local SetAlertFontSize = PSA.SetAlertFontSize
local GetAlertFloatAmplitude = PSA.GetAlertFloatAmplitude
local SetAlertFloatAmplitude = PSA.SetAlertFloatAmplitude
local GetAlertFloatSpeed = PSA.GetAlertFloatSpeed
local SetAlertFloatSpeed = PSA.SetAlertFloatSpeed
local GetAlertGlowEnabled = PSA.GetAlertGlowEnabled
local SetAlertGlowEnabled = PSA.SetAlertGlowEnabled
local GetAlertGlowSpeed = PSA.GetAlertGlowSpeed
local SetAlertGlowSpeed = PSA.SetAlertGlowSpeed
local DEFAULT_ALERT_FONT_SIZE = PSA.DEFAULT_ALERT_FONT_SIZE or 28
local DEFAULT_ALERT_FLOAT_AMPLITUDE = PSA.DEFAULT_ALERT_FLOAT_AMPLITUDE or 8
local DEFAULT_ALERT_FLOAT_SPEED = PSA.DEFAULT_ALERT_FLOAT_SPEED or 1
local DEFAULT_ALERT_GLOW_ENABLED = PSA.DEFAULT_ALERT_GLOW_ENABLED ~= false
local DEFAULT_ALERT_GLOW_SPEED = PSA.DEFAULT_ALERT_GLOW_SPEED or 1
local STATUS_ORDER = PSA.STATUS_ORDER
local SUPPORTED_LOCALES = PSA.SUPPORTED_LOCALES

local UI = setmetatable({}, {
    __index = function(_, key)
        return PSA.UI and PSA.UI[key]
    end,
})

local STATUS_LABEL = setmetatable({}, {
    __index = function(_, key)
        return PSA.STATUS_LABEL and PSA.STATUS_LABEL[key]
    end,
})

local lockCheckBox
local combatTTSCheckBox
local ttsRateSlider
local ttsRateValueText
local animationFontSizeSlider
local animationFontSizeValueText
local animationAmplitudeSlider
local animationAmplitudeValueText
local animationSpeedSlider
local animationSpeedValueText
local animationGlowCheckBox
local animationGlowSpeedSlider
local animationGlowSpeedValueText

-------------------------------------------------
-- UI helpers
-- QFX WoW Addon UI Skill: Blizzard-native first, compact multilingual layout,
-- unified spacing, native controls, and bottom min/current/max slider labels.
-- UI-only refactor: pet detection, alert text logic, SavedVariables, and drag logic stay unchanged.
-------------------------------------------------

local optionsFrame
local editBoxes = {}
local statusEnableCheckBoxes = {}
local statusLine
local moveToggleButton
local ApplyLanguageSelection
local nativeSettingsPanel
local nativeSettingsCategory
local nativeSettingsRegistered = false

local LAYOUT = {
    frameWidth = 970,
    frameHeight = 700,
    navWidth = 165,
    contentWidth = 740,
    rowHeight = 68,
    rowGap = 8,
    buttonHeight = 28,
    sliderWidth = 360,
    dropdownWidth = 250,
}

local ANIMATION_LAYOUT = {
    labelX = 18,
    sliderX = 342,
    labelWidth = 300,
    hintWidth = 300,
    sliderWidth = 360,
    rowStep = 88,
}

local PSA_STYLE = {
    frameBg = { 0.03, 0.03, 0.03, 0.92 },
    frameBorder = { 0.28, 0.22, 0.14, 0.95 },
    panelBg = { 0.04, 0.04, 0.04, 0.68 },
    divider = { 1.00, 0.82, 0.00, 0.24 },
    controlBg = { 0.18, 0.18, 0.18, 0.95 },
    controlHover = { 0.28, 0.24, 0.18, 0.95 },
    controlDown = { 0.12, 0.10, 0.08, 0.95 },
    editBg = { 0.08, 0.08, 0.08, 0.95 },
    text = { 0.90, 0.88, 0.82, 0.95 },
    muted = { 0.68, 0.66, 0.60, 0.90 },
    white = { 1.00, 1.00, 1.00, 1.00 },
    gold = { 1.00, 0.82, 0.00, 1.00 },
    red = { 1.00, 0.30, 0.24, 1.00 },
}

local function ColorRGBA(color)
    return color[1], color[2], color[3], color[4]
end

local function LocaleText(enUS, zhCN, zhTW, ruRU)
    local locale = GetActiveLocale()
    if locale == "zhCN" then
        return zhCN
    end
    if locale == "zhTW" then
        return zhTW
    end
    if locale == "ruRU" then
        return ruRU or enUS
    end
    return enUS
end

local NAV_TEXT
local NAV_ANIMATION
local NAV_ABOUT
local MOVE_UNLOCK_TEXT
local MOVE_LOCK_TEXT
local POSITION_TITLE
local ANIMATION_TITLE
local PREVIEW_ALERT_TEXT
local RESET_POSITION_TEXT
local POSITION_RESET_DONE
local COLOR_USAGE_TEXT
local SETTINGS_STANDALONE_TEXT

local function RefreshLocalizedStaticText()
    NAV_TEXT = LocaleText("Alert Text", "提示文字", "提示文字", "Предупреждения")
    NAV_ANIMATION = UI.ANIMATION_TITLE or LocaleText("Animation Settings", "动画设置", "動畫設定", "Анимация")
    NAV_ABOUT = LocaleText("About", "关于", "關於", "О аддоне")
    MOVE_UNLOCK_TEXT = LocaleText("Unlock Move", "解锁移动", "解鎖移動", "Разблокировать")
    MOVE_LOCK_TEXT = LocaleText("Lock Position", "锁定位置", "鎖定位置", "Закрепить")
    POSITION_TITLE = LocaleText("Alert Text Position", "提示文字位置", "提示文字位置", "Позиция текста предупреждения")
    ANIMATION_TITLE = UI.ANIMATION_TITLE or LocaleText("Animation Settings", "动画设置", "動畫設定", "Анимация")
    PREVIEW_ALERT_TEXT = UI.PREVIEW or LocaleText("Preview", "预览", "預覽", "Предпросмотр")
    RESET_POSITION_TEXT = LocaleText("Reset Default", "恢复默认", "恢復預設", "Сбросить")
    POSITION_RESET_DONE = LocaleText("Alert position has been reset", "提示文字位置已恢复默认", "提示文字位置已恢復預設", "Позиция предупреждения сброшена")
    COLOR_USAGE_TEXT = LocaleText("Color swatch: left-click to choose, right-click to reset.", "颜色方块：左键选择颜色，右键恢复默认颜色。", "顏色方塊：左鍵選擇顏色，右鍵恢復預設顏色。", "Цветовой квадрат: ЛКМ — выбрать, ПКМ — сбросить.")

    SETTINGS_STANDALONE_TEXT = LocaleText("Open large panel", "打开独立大面板", "開啟獨立大面板", "Открыть настройки")
end

local function RefreshAllLocaleState()
    RefreshLocaleTables()
    RefreshLocalizedStaticText()
end

RefreshLocalizedStaticText()

local function GetMoveButtonText()
    InitDB()
    if PetStatusAlertDB.alertLocked then
        return MOVE_UNLOCK_TEXT
    end
    return MOVE_LOCK_TEXT
end

local function GetPlayerClassColor()
    local _, classToken = UnitClass("player")
    local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
    local color = colors and colors[classToken]
    if color then
        return color.r or 1, color.g or 0.82, color.b or 0
    end
    return 1, 0.82, 0
end

local function ApplyBackdrop(frame, bgR, bgG, bgB, bgA, borderR, borderG, borderB, borderA)
    if not frame then
        return
    end

    if not frame.SetBackdrop and type(Mixin) == "function" and BackdropTemplateMixin then
        Mixin(frame, BackdropTemplateMixin)
    end
    if not frame.SetBackdrop then
        return
    end

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(bgR or 0, bgG or 0, bgB or 0, bgA or 0.8)
    frame:SetBackdropBorderColor(borderR or 0, borderG or 0, borderB or 0, borderA or 1)
end

local function StripTextures(frame)
    if not frame or not frame.GetRegions then
        return
    end

    for _, region in ipairs({ frame:GetRegions() }) do
        if region and region.IsObjectType and region:IsObjectType("Texture") then
            if region.SetTexture then
                region:SetTexture(nil)
            end
            if region.SetAlpha then
                region:SetAlpha(0)
            end
        end
    end
end

local function ApplyFontString(fontString, size, color, shadow)
    if not fontString then
        return
    end

    local font, _, flags = fontString:GetFont()
    fontString:SetFont(font or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size or 15, flags or "")
    if color then
        fontString:SetTextColor(ColorRGBA(color))
    end
    if shadow ~= false then
        fontString:SetShadowOffset(1, -1)
        fontString:SetShadowColor(0, 0, 0, 0.85)
    end
end

local function CreateText(parent, fontObject, textValue, justify, fontSize, color)
    local fs = parent:CreateFontString(nil, "ARTWORK", fontObject or "GameFontNormal")
    fs:SetText(textValue or "")
    fs:SetJustifyH(justify or "LEFT")
    ApplyFontString(fs, fontSize, color or PSA_STYLE.text)
    return fs
end

local function AutoFitButton(button, minWidth, padding)
    if not button then
        return
    end

    local fontString = button:GetFontString()
    local width = tonumber(minWidth) or 96
    if fontString and fontString.GetStringWidth then
        width = math.max(width, math.ceil(fontString:GetStringWidth() + (padding or 28)))
    end
    button:SetWidth(width)
end

local function SkinButton(btn, minWidth)
    if not btn then
        return
    end

    -- Keep UIPanelButtonTemplate native textures and states.
    -- This only normalizes text and width so localized labels do not clip.
    ApplyFontString(btn:GetFontString(), 14, PSA_STYLE.white)
    AutoFitButton(btn, minWidth)
end

local function CreateStyledButton(parent, label, width, height)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width or 110, height or LAYOUT.buttonHeight)
    btn:SetText(label or "")
    SkinButton(btn, width)
    return btn
end

local function SkinHorizontalSlider(slider)
    if not slider then
        return
    end

    -- Keep OptionsSliderTemplate native track/thumb.
    if slider.SetOrientation then
        slider:SetOrientation("HORIZONTAL")
    end
    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(true)
    end
    if slider.SetHitRectInsets then
        slider:SetHitRectInsets(0, 0, -8, -14)
    end
end


local function HideSliderTemplateLabels(slider)
    if not slider then
        return
    end

    local function HideLabel(label)
        if label then
            if label.SetText then
                label:SetText("")
            end
            if label.Hide then
                label:Hide()
            end
        end
    end

    -- 新版模板若带 Key，则直接关闭；旧模板或匿名模板则兜底隐藏自带 FontString。
    HideLabel(slider.Text)
    HideLabel(slider.Low)
    HideLabel(slider.High)

    if slider.GetRegions then
        for _, region in ipairs({ slider:GetRegions() }) do
            if region and region.GetObjectType and region:GetObjectType() == "FontString" then
                HideLabel(region)
            end
        end
    end
end

local function UpdateTTSRateControls()
    local rate = GetCombatTTSRate()
    if ttsRateSlider then
        ttsRateSlider:SetValue(rate)
    end
    if ttsRateValueText then
        ttsRateValueText:SetText(GetCombatTTSRateDisplayText())
    end
end



local function FormatOneDecimal(value)
    value = tonumber(value) or 0
    return string.format("%.1f", value)
end

local function GetAlertFontSizeDisplayText()
    local size = GetAlertFontSize and GetAlertFontSize() or DEFAULT_ALERT_FONT_SIZE
    return string.format(UI.ANIMATION_FONT_SIZE_VALUE or "Font size: %s", tostring(size))
end

local function GetAnimationAmplitudeDisplayText()
    local amplitude = GetAlertFloatAmplitude and GetAlertFloatAmplitude() or DEFAULT_ALERT_FLOAT_AMPLITUDE
    return string.format(UI.ANIMATION_AMPLITUDE_VALUE or "Amplitude: %s", tostring(amplitude))
end

local function GetAnimationSpeedDisplayText()
    local speed = GetAlertFloatSpeed and GetAlertFloatSpeed() or DEFAULT_ALERT_FLOAT_SPEED
    return string.format(UI.ANIMATION_SPEED_VALUE or "Speed: %sx", FormatOneDecimal(speed))
end

local function GetGlowSpeedDisplayText()
    local speed = GetAlertGlowSpeed and GetAlertGlowSpeed() or DEFAULT_ALERT_GLOW_SPEED
    return string.format(UI.ANIMATION_GLOW_SPEED_VALUE or "Glow speed: %sx", FormatOneDecimal(speed))
end

local function UpdateAnimationControls()
    local size = GetAlertFontSize and GetAlertFontSize() or DEFAULT_ALERT_FONT_SIZE
    local amplitude = GetAlertFloatAmplitude and GetAlertFloatAmplitude() or DEFAULT_ALERT_FLOAT_AMPLITUDE
    local speed = GetAlertFloatSpeed and GetAlertFloatSpeed() or DEFAULT_ALERT_FLOAT_SPEED
    local glowEnabled = GetAlertGlowEnabled and GetAlertGlowEnabled()
    if glowEnabled == nil then
        glowEnabled = DEFAULT_ALERT_GLOW_ENABLED
    end
    local glowSpeed = GetAlertGlowSpeed and GetAlertGlowSpeed() or DEFAULT_ALERT_GLOW_SPEED

    if animationFontSizeSlider then
        animationFontSizeSlider:SetValue(size)
    end
    if animationFontSizeValueText then
        animationFontSizeValueText:SetText(GetAlertFontSizeDisplayText())
    end
    if animationAmplitudeSlider then
        animationAmplitudeSlider:SetValue(amplitude)
    end
    if animationAmplitudeValueText then
        animationAmplitudeValueText:SetText(GetAnimationAmplitudeDisplayText())
    end
    if animationSpeedSlider then
        animationSpeedSlider:SetValue(speed)
    end
    if animationSpeedValueText then
        animationSpeedValueText:SetText(GetAnimationSpeedDisplayText())
    end
    if animationGlowCheckBox then
        animationGlowCheckBox:SetChecked(glowEnabled)
    end
    if animationGlowSpeedSlider then
        animationGlowSpeedSlider:SetValue(glowSpeed)
    end
    if animationGlowSpeedValueText then
        animationGlowSpeedValueText:SetText(GetGlowSpeedDisplayText())
    end
end

local function UpdateAnimationAmplitudeControls()
    UpdateAnimationControls()
end

local function CreateSliderScaleLabels(parent, slider, minValue, currentValue, maxValue)
    local minText = CreateText(parent, "GameFontDisableSmall", tostring(minValue), "LEFT", 11, PSA_STYLE.muted)
    minText:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -4)

    local currentText = CreateText(parent, "GameFontDisableSmall", tostring(currentValue), "CENTER", 11, PSA_STYLE.gold)
    currentText:SetPoint("TOP", slider, "BOTTOM", 0, -4)
    currentText:SetWidth(180)

    local maxText = CreateText(parent, "GameFontDisableSmall", tostring(maxValue), "RIGHT", 11, PSA_STYLE.muted)
    maxText:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -4)

    return minText, currentText, maxText
end


local function CreateCombatTTSControls(parent, yOffset)
    InitDB()

    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    box:SetSize(LAYOUT.contentWidth, 112)
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
    ApplyBackdrop(box,
        PSA_STYLE.panelBg[1], PSA_STYLE.panelBg[2], PSA_STYLE.panelBg[3], PSA_STYLE.panelBg[4],
        PSA_STYLE.frameBorder[1], PSA_STYLE.frameBorder[2], PSA_STYLE.frameBorder[3], PSA_STYLE.frameBorder[4]
    )

    local accentR, accentG, accentB = GetPlayerClassColor()
    local accent = box:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -1)
    accent:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 0, 1)
    accent:SetWidth(3)
    accent:SetColorTexture(accentR, accentG, accentB, 0.70)

    combatTTSCheckBox = CreateFrame("CheckButton", nil, box, "UICheckButtonTemplate")
    combatTTSCheckBox:SetSize(22, 22)
    combatTTSCheckBox:SetPoint("TOPLEFT", box, "TOPLEFT", 16, -12)
    combatTTSCheckBox:SetChecked(PetStatusAlertDB.combatTTSEnabled == true)

    local ttsLabel = CreateText(box, "GameFontNormal", UI.COMBAT_TTS, "LEFT", 15, PSA_STYLE.gold)
    ttsLabel:SetPoint("LEFT", combatTTSCheckBox, "RIGHT", 4, 0)

    local ttsHint = CreateText(box, "GameFontDisableSmall", UI.COMBAT_TTS_HINT, "LEFT", 12, PSA_STYLE.muted)
    ttsHint:SetPoint("TOPLEFT", combatTTSCheckBox, "BOTTOMLEFT", 30, -2)
    ttsHint:SetWidth(580)

    combatTTSCheckBox:SetScript("OnClick", function(self)
        InitDB()
        PetStatusAlertDB.combatTTSEnabled = self:GetChecked() and true or false
        if PetStatusAlertDB.combatTTSEnabled then
            if RefreshCombatTTSReminder then
                RefreshCombatTTSReminder(true)
            end
        else
            if StopCombatTTSReminder then
                StopCombatTTSReminder()
            end
        end
        if statusLine then
            statusLine:SetText(PetStatusAlertDB.combatTTSEnabled and UI.COMBAT_TTS_ON or UI.COMBAT_TTS_OFF)
        end
    end)

    local ttsRateLabel = CreateText(box, "GameFontNormal", UI.COMBAT_TTS_RATE, "LEFT", 15, PSA_STYLE.gold)
    ttsRateLabel:SetPoint("TOPLEFT", box, "TOPLEFT", 18, -70)
    ttsRateLabel:SetWidth(170)

    ttsRateSlider = CreateFrame("Slider", nil, box, "OptionsSliderTemplate")
    ttsRateSlider:SetSize(LAYOUT.sliderWidth, 16)
    ttsRateSlider:SetPoint("LEFT", ttsRateLabel, "RIGHT", 18, 0)
    ttsRateSlider:SetMinMaxValues(-10, 10)
    ttsRateSlider:SetValueStep(1)
    ttsRateSlider:SetValue(GetCombatTTSRate())
    SkinHorizontalSlider(ttsRateSlider)
    HideSliderTemplateLabels(ttsRateSlider)
    local _, currentLabel = CreateSliderScaleLabels(box, ttsRateSlider, "-10", GetCombatTTSRateDisplayText(), "+10")
    ttsRateValueText = currentLabel
    ttsRateSlider:SetScript("OnValueChanged", function(_, value)
        SetCombatTTSRate(value)
        if ttsRateValueText then
            ttsRateValueText:SetText(GetCombatTTSRateDisplayText())
        end
        if statusLine then
            statusLine:SetText(GetCombatTTSRateDisplayText())
        end
    end)

    return box
end


local function UpdateColorSwatch(swatch, statusKey)
    if not swatch then
        return
    end
    local r, g, b, a = GetStatusColor(statusKey)
    swatch:SetColorTexture(r, g, b, a or 1)
end


local function CreateColorSwatchButton(parent, statusKey)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(28, 24)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    ApplyBackdrop(button,
        0.03, 0.03, 0.03, 0.95,
        PSA_STYLE.frameBorder[1], PSA_STYLE.frameBorder[2], PSA_STYLE.frameBorder[3], 0.95
    )

    local swatch = button:CreateTexture(nil, "ARTWORK")
    swatch:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -4)
    swatch:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 4)
    UpdateColorSwatch(swatch, statusKey)
    button.swatch = swatch

    local hover = button:CreateTexture(nil, "HIGHLIGHT")
    hover:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
    hover:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    hover:SetColorTexture(1, 1, 1, 0.16)
    button.hover = hover

    button:SetScript("OnMouseDown", function(self)
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(1, 0.82, 0, 1)
        end
    end)
    button:SetScript("OnMouseUp", function(self)
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(PSA_STYLE.frameBorder[1], PSA_STYLE.frameBorder[2], PSA_STYLE.frameBorder[3], 0.95)
        end
    end)
    button:SetScript("OnLeave", function(self)
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(PSA_STYLE.frameBorder[1], PSA_STYLE.frameBorder[2], PSA_STYLE.frameBorder[3], 0.95)
        end
    end)

    return button
end

local function OpenStatusColorPicker(statusKey, swatch)
    if not ColorPickerFrame then
        if statusLine then
            statusLine:SetText("ColorPickerFrame not available")
        end
        return
    end

    local oldR, oldG, oldB, oldA = GetStatusColor(statusKey)

    local function ApplyPickedColor()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        SetStatusColor(statusKey, r, g, b, oldA or 1)
        UpdateColorSwatch(swatch, statusKey)
        if PSA.currentStatusKey == statusKey then
            ApplyAlertTextColor(statusKey)
        end
        if statusLine then
            statusLine:SetText(UI.COLOR_SAVED)
        end
    end

    local function CancelPickedColor()
        SetStatusColor(statusKey, oldR, oldG, oldB, oldA)
        UpdateColorSwatch(swatch, statusKey)
        if PSA.currentStatusKey == statusKey then
            ApplyAlertTextColor(statusKey)
        end
    end

    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = oldR,
            g = oldG,
            b = oldB,
            hasOpacity = false,
            swatchFunc = ApplyPickedColor,
            cancelFunc = CancelPickedColor,
        })
    else
        ColorPickerFrame.func = ApplyPickedColor
        ColorPickerFrame.cancelFunc = CancelPickedColor
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame:SetColorRGB(oldR, oldG, oldB)
        ColorPickerFrame:Show()
    end
end

local function SkinEditBox(eb)
    if not eb then
        return
    end

    -- Keep InputBoxTemplate native textures; normalize behavior only.
    eb:SetAutoFocus(false)
    eb:SetMultiLine(false)
    eb:SetMaxLetters(180)
    eb:SetFontObject("GameFontHighlightSmall")
    eb:SetTextColor(0.95, 0.95, 0.95, 1)
    eb:SetTextInsets(8, 8, 0, 0)
end


local function SetNavButtonActive(btn, isActive)
    if not btn then
        return
    end
    btn.isActive = isActive and true or false
    if btn.selected then
        btn.selected:SetShown(btn.isActive)
    end
    if btn.text then
        btn.text:SetTextColor(ColorRGBA(btn.isActive and PSA_STYLE.white or PSA_STYLE.gold))
    end
end

local function CreateNavButton(parent, textValue, yOffset)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(LAYOUT.navWidth - 8, 26)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", btn, "LEFT", 18, 1)
    label:SetText(textValue or "")
    ApplyFontString(label, 15, PSA_STYLE.gold)
    btn.text = label

    local r, g, b = GetPlayerClassColor()
    local selected = btn:CreateTexture(nil, "BACKGROUND")
    selected:SetPoint("TOPLEFT", btn, "TOPLEFT", 8, 0)
    selected:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    selected:SetColorTexture(r, g, b, 0.22)
    selected:Hide()
    btn.selected = selected

    local hover = btn:CreateTexture(nil, "BACKGROUND")
    hover:SetPoint("TOPLEFT", btn, "TOPLEFT", 8, 0)
    hover:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    hover:SetColorTexture(r, g, b, 0.34)
    hover:Hide()
    btn.hover = hover

    btn:SetScript("OnEnter", function(self)
        if not self.isActive then
            self.hover:Show()
            self.text:SetTextColor(ColorRGBA(PSA_STYLE.white))
        end
    end)
    btn:SetScript("OnLeave", function(self)
        self.hover:Hide()
        if not self.isActive then
            self.text:SetTextColor(ColorRGBA(PSA_STYLE.gold))
        end
    end)

    return btn
end

local function UpdateMoveControls()
    InitDB()
    if lockCheckBox then
        lockCheckBox:SetChecked(PetStatusAlertDB.alertLocked == true)
    end
    if combatTTSCheckBox then
        combatTTSCheckBox:SetChecked(PetStatusAlertDB.combatTTSEnabled == true)
    end
    if moveToggleButton then
        moveToggleButton:SetText(GetMoveButtonText())
        local fontString = moveToggleButton:GetFontString()
        if fontString then
            fontString:SetTextColor(ColorRGBA(PSA_STYLE.red))
        end
    end
    UpdateTTSRateControls()
end

local function UpdateStatusEnableControls()
    for statusKey, checkBox in pairs(statusEnableCheckBoxes) do
        if checkBox then
            checkBox:SetChecked(IsStatusEnabled(statusKey))
        end
    end
end

local function CreateStatusRow(parent, statusKey, yOffset)
    InitDB()

    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetSize(LAYOUT.contentWidth, LAYOUT.rowHeight)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
    ApplyBackdrop(row,
        PSA_STYLE.panelBg[1], PSA_STYLE.panelBg[2], PSA_STYLE.panelBg[3], PSA_STYLE.panelBg[4],
        PSA_STYLE.frameBorder[1], PSA_STYLE.frameBorder[2], PSA_STYLE.frameBorder[3], PSA_STYLE.frameBorder[4]
    )

    local accentR, accentG, accentB = GetPlayerClassColor()
    local accent = row:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1)
    accent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 1)
    accent:SetWidth(3)
    accent:SetColorTexture(accentR, accentG, accentB, 0.70)

    local title = CreateText(row, "GameFontNormal", STATUS_LABEL[statusKey] or statusKey, "LEFT", 15, PSA_STYLE.gold)
    title:SetPoint("TOPLEFT", row, "TOPLEFT", 14, -8)
    title:SetWidth(230)

    local keyText = CreateText(row, "GameFontDisableSmall", statusKey, "LEFT", 12, PSA_STYLE.muted)
    keyText:SetPoint("LEFT", title, "RIGHT", 8, 0)
    keyText:SetWidth(100)

    local enableLabel = CreateText(row, "GameFontNormal", UI.ENABLE_ALERT, "LEFT", 13, PSA_STYLE.gold)
    enableLabel:SetPoint("TOPRIGHT", row, "TOPRIGHT", -14, -10)
    enableLabel:SetWidth(178)

    local enableCheckBox = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    enableCheckBox:SetSize(22, 22)
    enableCheckBox:SetPoint("RIGHT", enableLabel, "LEFT", -4, 0)
    enableCheckBox:SetChecked(IsStatusEnabled(statusKey))
    statusEnableCheckBoxes[statusKey] = enableCheckBox

    enableCheckBox:SetScript("OnClick", function(self)
        local enabled = self:GetChecked() and true or false
        SetStatusEnabled(statusKey, enabled)
        RefreshPetStatusText()
        if statusLine then
            statusLine:SetText(string.format(enabled and UI.ALERT_ENABLED or UI.ALERT_DISABLED, STATUS_LABEL[statusKey] or statusKey))
        end
    end)

    local defaultText = CreateText(row, "GameFontDisableSmall", UI.DEFAULT_PREFIX .. " " .. GetDefaultMessage(statusKey), "LEFT", 12, PSA_STYLE.muted)
    defaultText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    defaultText:SetWidth(245)

    local eb = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    eb:SetSize(188, 28)
    eb:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 270, 10)
    SkinEditBox(eb)
    eb:SetText(PetStatusAlertDB.customMessages[statusKey] or "")

    eb:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    eb:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        RefreshPetStatusText()
    end)
    eb:SetScript("OnEditFocusGained", function(self)
        if self.HighlightText then
            self:HighlightText()
        end
    end)
    eb:SetScript("OnEditFocusLost", function(self)
        RefreshPetStatusText()
    end)
    eb:SetScript("OnTextChanged", function(self, userInput)
        if not userInput then
            return
        end
        InitDB()
        PetStatusAlertDB.customMessages[statusKey] = self:GetText() or ""
        if statusLine then
            statusLine:SetText(UI.SAVED)
        end
        if PSA.currentStatusKey == statusKey then
            PreviewStatus(statusKey)
        end
    end)

    editBoxes[statusKey] = eb

    local colorButton = CreateColorSwatchButton(row, statusKey)
    colorButton:SetPoint("LEFT", eb, "RIGHT", 8, 0)

    colorButton:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            ResetStatusColor(statusKey)
            UpdateColorSwatch(self.swatch, statusKey)
            PreviewStatus(statusKey)
            if statusLine then
                statusLine:SetText(UI.COLOR_RESET)
            end
            return
        end
        OpenStatusColorPicker(statusKey, self.swatch)
        PreviewStatus(statusKey)
    end)

    local preview = CreateStyledButton(row, UI.PREVIEW, 54, 26)
    preview:SetPoint("LEFT", colorButton, "RIGHT", 6, 0)
    preview:SetScript("OnClick", function()
        PreviewStatus(statusKey)
        if statusLine then
            statusLine:SetText((STATUS_LABEL[statusKey] or statusKey) .. " - " .. GetDisplayMessage(statusKey))
        end
    end)

    local clear = CreateStyledButton(row, UI.CLEAR, 48, 26)
    clear:SetPoint("LEFT", preview, "RIGHT", 6, 0)
    clear:SetScript("OnClick", function()
        InitDB()
        PetStatusAlertDB.customMessages[statusKey] = ""
        eb:SetText("")
        if statusLine then
            statusLine:SetText(UI.CLEARED)
        end
        if PSA.currentStatusKey == statusKey then
            PreviewStatus(statusKey)
        end
    end)

    return row
end


local function DrawTextPage(page)
    editBoxes = {}
    statusEnableCheckBoxes = {}

    local sectionTitle = CreateText(page, "GameFontNormal", UI.CARD_TITLE, "LEFT", 17, PSA_STYLE.white)
    sectionTitle:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)

    local colorTip = CreateText(page, "GameFontDisableSmall", COLOR_USAGE_TEXT, "LEFT", 12, PSA_STYLE.muted)
    colorTip:SetPoint("TOPLEFT", sectionTitle, "BOTTOMLEFT", 0, -8)
    colorTip:SetWidth(LAYOUT.contentWidth - 30)

    local startY = -52
    local rowStep = LAYOUT.rowHeight + LAYOUT.rowGap
    for i, statusKey in ipairs(STATUS_ORDER) do
        CreateStatusRow(page, statusKey, startY - ((i - 1) * rowStep))
    end

    local ttsY = startY - (#STATUS_ORDER * rowStep) - 6
    CreateCombatTTSControls(page, ttsY)
end

local function CreateAnimationSlider(parent, labelText, hintText, yOffset, minValue, maxValue, stepValue, currentValue, currentText, onChanged)
    local label = CreateText(parent, "GameFontNormal", labelText, "LEFT", 15, PSA_STYLE.gold)
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", ANIMATION_LAYOUT.labelX, yOffset)
    label:SetWidth(ANIMATION_LAYOUT.labelWidth)
    if label.SetWordWrap then
        label:SetWordWrap(false)
    end

    local hint = CreateText(parent, "GameFontDisableSmall", hintText, "LEFT", 12, PSA_STYLE.muted)
    hint:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -5)
    hint:SetWidth(ANIMATION_LAYOUT.hintWidth)
    if hint.SetWordWrap then
        hint:SetWordWrap(true)
    end
    if hint.SetNonSpaceWrap then
        hint:SetNonSpaceWrap(true)
    end

    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetSize(ANIMATION_LAYOUT.sliderWidth, 16)
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", ANIMATION_LAYOUT.sliderX, yOffset - 7)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(stepValue)
    slider:SetValue(currentValue)
    SkinHorizontalSlider(slider)
    HideSliderTemplateLabels(slider)
    local _, valueText = CreateSliderScaleLabels(parent, slider, tostring(minValue), currentText, tostring(maxValue))

    slider:SetScript("OnValueChanged", function(_, value)
        if onChanged then
            onChanged(value, slider, valueText)
        end
    end)

    return slider, valueText
end

local function DrawAnimationPage(page)
    animationFontSizeSlider = nil
    animationFontSizeValueText = nil
    animationAmplitudeSlider = nil
    animationAmplitudeValueText = nil
    animationSpeedSlider = nil
    animationSpeedValueText = nil
    animationGlowCheckBox = nil
    animationGlowSpeedSlider = nil
    animationGlowSpeedValueText = nil

    local title = CreateText(page, "GameFontNormal", ANIMATION_TITLE, "LEFT", 17, PSA_STYLE.white)
    title:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)

    local box = CreateFrame("Frame", nil, page, "BackdropTemplate")
    box:SetSize(LAYOUT.contentWidth, 500)
    box:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -38)
    ApplyBackdrop(box,
        PSA_STYLE.panelBg[1], PSA_STYLE.panelBg[2], PSA_STYLE.panelBg[3], PSA_STYLE.panelBg[4],
        PSA_STYLE.frameBorder[1], PSA_STYLE.frameBorder[2], PSA_STYLE.frameBorder[3], PSA_STYLE.frameBorder[4]
    )

    local accentR, accentG, accentB = GetPlayerClassColor()
    local accent = box:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -1)
    accent:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 0, 1)
    accent:SetWidth(3)
    accent:SetColorTexture(accentR, accentG, accentB, 0.70)

    animationFontSizeSlider, animationFontSizeValueText = CreateAnimationSlider(
        box,
        UI.ANIMATION_FONT_SIZE or "Alert font size",
        UI.ANIMATION_FONT_SIZE_HINT or "Adjust the on-screen alert text size. Default: 28.",
        -22,
        12,
        72,
        1,
        GetAlertFontSize and GetAlertFontSize() or DEFAULT_ALERT_FONT_SIZE,
        GetAlertFontSizeDisplayText(),
        function(value, slider, valueText)
            local size = SetAlertFontSize and SetAlertFontSize(value) or DEFAULT_ALERT_FONT_SIZE
            if slider then
                slider:SetValue(size)
            end
            if valueText then
                valueText:SetText(GetAlertFontSizeDisplayText())
            end
            PreviewStatus("PASSIVE")
            if statusLine then
                statusLine:SetText(string.format(UI.ANIMATION_FONT_SIZE_CHANGED or "Alert font size set to: %s", tostring(size)))
            end
        end
    )

    animationAmplitudeSlider, animationAmplitudeValueText = CreateAnimationSlider(
        box,
        UI.ANIMATION_AMPLITUDE,
        UI.ANIMATION_AMPLITUDE_HINT,
        -110,
        0,
        24,
        1,
        GetAlertFloatAmplitude and GetAlertFloatAmplitude() or DEFAULT_ALERT_FLOAT_AMPLITUDE,
        GetAnimationAmplitudeDisplayText(),
        function(value, slider, valueText)
            local amplitude = SetAlertFloatAmplitude and SetAlertFloatAmplitude(value) or DEFAULT_ALERT_FLOAT_AMPLITUDE
            if slider then
                slider:SetValue(amplitude)
            end
            if valueText then
                valueText:SetText(GetAnimationAmplitudeDisplayText())
            end
            PreviewStatus("PASSIVE")
            if statusLine then
                statusLine:SetText(string.format(UI.ANIMATION_AMPLITUDE_CHANGED or "Animation amplitude set to: %s", tostring(amplitude)))
            end
        end
    )

    animationSpeedSlider, animationSpeedValueText = CreateAnimationSlider(
        box,
        UI.ANIMATION_SPEED or "Up/down float speed",
        UI.ANIMATION_SPEED_HINT or "Adjust the vertical floating speed. 1.0x = old default speed.",
        -198,
        0.1,
        3,
        0.1,
        GetAlertFloatSpeed and GetAlertFloatSpeed() or DEFAULT_ALERT_FLOAT_SPEED,
        GetAnimationSpeedDisplayText(),
        function(value, slider, valueText)
            local speed = SetAlertFloatSpeed and SetAlertFloatSpeed(value) or DEFAULT_ALERT_FLOAT_SPEED
            if slider then
                slider:SetValue(speed)
            end
            if valueText then
                valueText:SetText(GetAnimationSpeedDisplayText())
            end
            PreviewStatus("PASSIVE")
            if statusLine then
                statusLine:SetText(string.format(UI.ANIMATION_SPEED_CHANGED or "Animation speed set to: %sx", FormatOneDecimal(speed)))
            end
        end
    )

    animationGlowCheckBox = CreateFrame("CheckButton", nil, box, "UICheckButtonTemplate")
    animationGlowCheckBox:SetSize(24, 24)
    animationGlowCheckBox:SetPoint("TOPLEFT", box, "TOPLEFT", 14, -286)
    do
        local glowEnabled = GetAlertGlowEnabled and GetAlertGlowEnabled()
        if glowEnabled == nil then
            glowEnabled = DEFAULT_ALERT_GLOW_ENABLED
        end
        animationGlowCheckBox:SetChecked(glowEnabled)
    end

    local glowLabel = CreateText(box, "GameFontNormal", UI.ANIMATION_GLOW_ENABLE or "Pixel glow", "LEFT", 15, PSA_STYLE.gold)
    glowLabel:SetPoint("LEFT", animationGlowCheckBox, "RIGHT", 4, 0)

    local glowHint = CreateText(box, "GameFontDisableSmall", UI.ANIMATION_GLOW_ENABLE_HINT or "Uses the embedded LibCustomGlow-1.0 Pixel Glow around the alert text.", "LEFT", 12, PSA_STYLE.muted)
    glowHint:SetPoint("TOPLEFT", glowLabel, "BOTTOMLEFT", 0, -6)
    glowHint:SetWidth(LAYOUT.contentWidth - 64)

    animationGlowCheckBox:SetScript("OnClick", function(self)
        local enabled = self:GetChecked() and true or false
        if SetAlertGlowEnabled then
            enabled = SetAlertGlowEnabled(enabled)
        end
        self:SetChecked(enabled)
        PreviewStatus("PASSIVE")
        if statusLine then
            statusLine:SetText(enabled and (UI.ANIMATION_GLOW_ON or "Pixel glow enabled") or (UI.ANIMATION_GLOW_OFF or "Pixel glow disabled"))
        end
    end)

    animationGlowSpeedSlider, animationGlowSpeedValueText = CreateAnimationSlider(
        box,
        UI.ANIMATION_GLOW_SPEED or "Pixel glow speed",
        UI.ANIMATION_GLOW_SPEED_HINT or "Adjust the flowing speed of the pixel glow. 1.0x = default speed.",
        -364,
        0.2,
        3,
        0.1,
        GetAlertGlowSpeed and GetAlertGlowSpeed() or DEFAULT_ALERT_GLOW_SPEED,
        GetGlowSpeedDisplayText(),
        function(value, slider, valueText)
            local speed = SetAlertGlowSpeed and SetAlertGlowSpeed(value) or DEFAULT_ALERT_GLOW_SPEED
            if slider then
                slider:SetValue(speed)
            end
            if valueText then
                valueText:SetText(GetGlowSpeedDisplayText())
            end
            PreviewStatus("PASSIVE")
            if statusLine then
                statusLine:SetText(string.format(UI.ANIMATION_GLOW_SPEED_CHANGED or "Pixel glow speed set to: %sx", FormatOneDecimal(speed)))
            end
        end
    )

    UpdateAnimationControls()
end

local function GetLanguageModeLabel(languageMode)
    languageMode = tostring(languageMode or "auto")
    if languageMode == "enUS" then
        return UI.LANGUAGE_ENUS
    end
    if languageMode == "zhCN" then
        return UI.LANGUAGE_ZHCN
    end
    if languageMode == "zhTW" then
        return UI.LANGUAGE_ZHTW
    end
    if languageMode == "ruRU" then
        return UI.LANGUAGE_RURU
    end
    return UI.LANGUAGE_AUTO
end

local function GetCurrentLanguageModeText()
    return UI.LANGUAGE_CURRENT .. " " .. GetLanguageModeLabel(GetSavedLanguageMode())
end

local function DrawAboutPage(page)
    local title = CreateText(page, "GameFontNormal", NAV_ABOUT, "LEFT", 17, PSA_STYLE.white)
    title:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)

    local box = CreateFrame("Frame", nil, page, "BackdropTemplate")
    box:SetSize(LAYOUT.contentWidth, 315)
    box:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -38)
    ApplyBackdrop(box,
        PSA_STYLE.panelBg[1], PSA_STYLE.panelBg[2], PSA_STYLE.panelBg[3], PSA_STYLE.panelBg[4],
        PSA_STYLE.frameBorder[1], PSA_STYLE.frameBorder[2], PSA_STYLE.frameBorder[3], PSA_STYLE.frameBorder[4]
    )

    local languageTitle = CreateText(box, "GameFontNormal", UI.LANGUAGE, "LEFT", 15, PSA_STYLE.gold)
    languageTitle:SetPoint("TOPLEFT", box, "TOPLEFT", 18, -18)

    local languageDesc = CreateText(box, "GameFontDisableSmall", UI.LANGUAGE_DESC, "LEFT", 12, PSA_STYLE.muted)
    languageDesc:SetPoint("TOPLEFT", languageTitle, "BOTTOMLEFT", 0, -7)
    languageDesc:SetWidth(LAYOUT.contentWidth - 40)

    local currentLanguage = CreateText(box, "GameFontNormal", GetCurrentLanguageModeText(), "LEFT", 13, PSA_STYLE.text)
    currentLanguage:SetPoint("TOPLEFT", languageDesc, "BOTTOMLEFT", 0, -10)
    currentLanguage:SetWidth(LAYOUT.contentWidth - 40)

    local autoButton = CreateStyledButton(box, UI.LANGUAGE_AUTO, 118, 28)
    autoButton:SetPoint("TOPLEFT", currentLanguage, "BOTTOMLEFT", 0, -12)
    autoButton:SetScript("OnClick", function()
        if ApplyLanguageSelection then
            ApplyLanguageSelection("auto")
        end
    end)

    local enButton = CreateStyledButton(box, UI.LANGUAGE_ENUS, 104, 28)
    enButton:SetPoint("LEFT", autoButton, "RIGHT", 10, 0)
    enButton:SetScript("OnClick", function()
        if ApplyLanguageSelection then
            ApplyLanguageSelection("enUS")
        end
    end)

    local zhCNButton = CreateStyledButton(box, UI.LANGUAGE_ZHCN, 126, 28)
    zhCNButton:SetPoint("LEFT", enButton, "RIGHT", 10, 0)
    zhCNButton:SetScript("OnClick", function()
        if ApplyLanguageSelection then
            ApplyLanguageSelection("zhCN")
        end
    end)

    local zhTWButton = CreateStyledButton(box, UI.LANGUAGE_ZHTW, 126, 28)
    zhTWButton:SetPoint("LEFT", zhCNButton, "RIGHT", 10, 0)
    zhTWButton:SetScript("OnClick", function()
        if ApplyLanguageSelection then
            ApplyLanguageSelection("zhTW")
        end
    end)

    local ruRUButton = CreateStyledButton(box, UI.LANGUAGE_RURU, 126, 28)
    ruRUButton:SetPoint("TOPLEFT", autoButton, "BOTTOMLEFT", 0, -10)
    ruRUButton:SetScript("OnClick", function()
        if ApplyLanguageSelection then
            ApplyLanguageSelection("ruRU")
        end
    end)

    local divider = box:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(ColorRGBA(PSA_STYLE.divider))
    divider:SetPoint("TOPLEFT", ruRUButton, "BOTTOMLEFT", 0, -18)
    divider:SetPoint("TOPRIGHT", box, "TOPRIGHT", -18, 0)
    divider:SetHeight(1)

    local lines = {
        UI.SUPPORT,
        UI.FOOTER,
        UI.AUTHOR,
        UI.TRANSLATION_RURU,
    }

    for i, value in ipairs(lines) do
        local color = (i >= 3) and PSA_STYLE.gold or PSA_STYLE.text
        local line = CreateText(box, "GameFontNormal", value, "LEFT", 14, color)
        line:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -18 - ((i - 1) * 32))
        line:SetWidth(LAYOUT.contentWidth - 40)
    end
end

local function CreateOptionsFrame()
    if optionsFrame then
        return optionsFrame
    end

    InitDB()

    local f = CreateFrame("Frame", "PetStatusAlertOptionsFrame", UIParent, "BackdropTemplate")
    optionsFrame = f
    f:SetSize(LAYOUT.frameWidth, LAYOUT.frameHeight)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()
    ApplyBackdrop(f,
        PSA_STYLE.frameBg[1], PSA_STYLE.frameBg[2], PSA_STYLE.frameBg[3], PSA_STYLE.frameBg[4],
        PSA_STYLE.frameBorder[1], PSA_STYLE.frameBorder[2], PSA_STYLE.frameBorder[3], PSA_STYLE.frameBorder[4]
    )

    local title = CreateText(f, "GameFontNormalLarge", UI.TITLE, "CENTER", 21, PSA_STYLE.gold)
    title:SetPoint("TOP", f, "TOP", 0, -18)
    f.psaTitle = title

    local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
    local version = (getMeta and getMeta(ADDON_NAME, "Version")) or "1.3.9"
    local versionText = CreateText(f, "GameFontNormal", "v" .. tostring(version), "CENTER", 17, PSA_STYLE.text)
    versionText:SetPoint("TOP", title, "BOTTOM", 0, -8)

    local leftPanel = CreateFrame("Frame", nil, f)
    leftPanel:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -76)
    leftPanel:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 10)
    leftPanel:SetWidth(LAYOUT.navWidth)

    local divider = leftPanel:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(ColorRGBA(PSA_STYLE.divider))
    divider:SetWidth(1)
    divider:SetPoint("TOPRIGHT", leftPanel, "TOPRIGHT", 0, 0)
    divider:SetPoint("BOTTOMRIGHT", leftPanel, "BOTTOMRIGHT", 0, 0)

    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 12, -2)
    content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 65)

    f.activePage = "text"
    f.navButtons = {}
    f.currentPage = nil

    local function RefreshNavButtons()
        for key, btn in pairs(f.navButtons) do
            SetNavButtonActive(btn, key == f.activePage)
        end
    end

    local function DrawPage()
        if f.currentPage then
            f.currentPage:Hide()
            f.currentPage:SetParent(nil)
            f.currentPage = nil
        end

        local page = CreateFrame("Frame", nil, content)
        page:SetAllPoints(content)
        f.currentPage = page

        if f.activePage == "animation" then
            DrawAnimationPage(page)
        elseif f.activePage == "about" then
            DrawAboutPage(page)
        else
            DrawTextPage(page)
        end

        RefreshNavButtons()
    end

    local function AddNav(pageKey, label, yOffset)
        local btn = CreateNavButton(leftPanel, label, yOffset)
        f.navButtons[pageKey] = btn
        btn:SetScript("OnClick", function()
            f.activePage = pageKey
            DrawPage()
        end)
    end

    AddNav("text", NAV_TEXT, -6)
    AddNav("animation", NAV_ANIMATION, -34)
    AddNav("about", NAV_ABOUT, -62)

    local function SetLeftActionButtonTextColor(button)
        local fontString = button and button:GetFontString()
        if fontString then
            fontString:SetTextColor(ColorRGBA(PSA_STYLE.red))
        end
    end

    local resetPositionButton = CreateStyledButton(leftPanel, RESET_POSITION_TEXT, 110, 28)
    resetPositionButton:SetPoint("BOTTOM", leftPanel, "BOTTOM", 0, 114)
    SetLeftActionButtonTextColor(resetPositionButton)
    resetPositionButton:SetScript("OnClick", function()
        InitDB()
        PetStatusAlertDB.alertPosition = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = 220,
        }
        ApplyAlertPosition()
        PreviewStatus("PASSIVE")
        if statusLine then
            statusLine:SetText(POSITION_RESET_DONE)
        end
    end)

    local previewAlertButton = CreateStyledButton(leftPanel, PREVIEW_ALERT_TEXT, 110, 28)
    previewAlertButton:SetPoint("BOTTOM", leftPanel, "BOTTOM", 0, 80)
    SetLeftActionButtonTextColor(previewAlertButton)
    previewAlertButton:SetScript("OnClick", function()
        PreviewStatus("PASSIVE")
        if statusLine then
            statusLine:SetText(GetDisplayMessage("PASSIVE"))
        end
    end)

    moveToggleButton = CreateStyledButton(leftPanel, GetMoveButtonText(), 110, 28)
    moveToggleButton:SetPoint("BOTTOM", leftPanel, "BOTTOM", 0, 46)
    SetLeftActionButtonTextColor(moveToggleButton)
    moveToggleButton:SetScript("OnClick", function()
        InitDB()
        local locked = not PetStatusAlertDB.alertLocked
        SetAlertPositionLocked(locked)
        UpdateMoveControls()
        if statusLine then
            statusLine:SetText(locked and UI.LOCKED_STATUS or UI.UNLOCKED_STATUS)
        end
        if not locked then
            PreviewStatus("PASSIVE")
        end
    end)

    f.psaResetPositionButton = resetPositionButton
    f.psaPreviewAlertButton = previewAlertButton


    local close = CreateStyledButton(f, UI.CLOSE, 110, 30)
    close:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 22)
    f.psaCloseButton = close
    close:SetScript("OnClick", function()
        f:Hide()
    end)

    statusLine = CreateText(f, "GameFontHighlightSmall", UI.FOOTER, "LEFT", 13, PSA_STYLE.text)
    statusLine:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 200, 8)
    statusLine:SetWidth(560)
    f.psaStatusLine = statusLine
    f.psaMoveToggleButton = moveToggleButton

    local author = CreateText(f, "GameFontDisableSmall", UI.AUTHOR, "LEFT", 12, PSA_STYLE.gold)
    author:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 20, 12)
    f.psaAuthorText = author

    f.DrawPage = DrawPage
    DrawPage()

    return f
end

local function OpenOptionsFrame()
    local f = CreateOptionsFrame()
    InitDB()
    if f.psaStatusLine then
        statusLine = f.psaStatusLine
    end
    if f.psaMoveToggleButton then
        moveToggleButton = f.psaMoveToggleButton
    end
    if f.DrawPage then
        f:DrawPage()
    end
    for _, statusKey in ipairs(STATUS_ORDER) do
        if editBoxes[statusKey] then
            editBoxes[statusKey]:SetText(PetStatusAlertDB.customMessages[statusKey] or "")
        end
    end
    UpdateMoveControls()
    UpdateStatusEnableControls()
    if statusLine then
        statusLine:SetText(UI.FOOTER)
    end
    f:Show()
end

local function RefreshOptionsFrameLocale()
    if not optionsFrame then
        return
    end

    local f = optionsFrame

    if f.psaTitle then
        f.psaTitle:SetText(UI.TITLE)
    end
    if f.navButtons then
        if f.navButtons.text and f.navButtons.text.text then
            f.navButtons.text.text:SetText(NAV_TEXT)
        end
        if f.navButtons.animation and f.navButtons.animation.text then
            f.navButtons.animation.text:SetText(NAV_ANIMATION)
        end
        if f.navButtons.about and f.navButtons.about.text then
            f.navButtons.about.text:SetText(NAV_ABOUT)
        end
    end
    if f.psaMoveToggleButton then
        f.psaMoveToggleButton:SetText(GetMoveButtonText())
        AutoFitButton(f.psaMoveToggleButton, 110)
    end
    if f.psaResetPositionButton then
        f.psaResetPositionButton:SetText(RESET_POSITION_TEXT)
        AutoFitButton(f.psaResetPositionButton, 110)
    end
    if f.psaPreviewAlertButton then
        f.psaPreviewAlertButton:SetText(PREVIEW_ALERT_TEXT)
        AutoFitButton(f.psaPreviewAlertButton, 110)
    end
    if f.psaCloseButton then
        f.psaCloseButton:SetText(UI.CLOSE)
        AutoFitButton(f.psaCloseButton, 110)
    end
    if f.psaAuthorText then
        f.psaAuthorText:SetText(UI.AUTHOR)
    end
    if f.psaStatusLine then
        f.psaStatusLine:SetText(UI.FOOTER)
    end

    if f.DrawPage then
        f:DrawPage()
    end
    UpdateMoveControls()
    UpdateStatusEnableControls()
end


-------------------------------------------------
-- Native WoW Options > AddOns settings panel
-------------------------------------------------


local function CreateNativeProxyPanel()
    if nativeSettingsPanel then
        return nativeSettingsPanel
    end

    local panel = CreateFrame("Frame", "PetStatusAlertNativeSettingsPanel", UIParent)
    nativeSettingsPanel = panel
    panel.name = "PetStatusAlert"

    local title = CreateText(panel, "GameFontNormalLarge", UI.TITLE, "LEFT", 21, PSA_STYLE.gold)
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -8)
    panel.psaProxyTitle = title

    local desc = CreateText(panel, "GameFontHighlightSmall", LocaleText(
        "Click the button below to open the same PetStatusAlert settings panel as /psa. It will not auto-open when this category is refreshed.",
        "点击下面的按钮，会打开和 /psa 完全相同的 PetStatusAlert 设置面板。此分类刷新时不会再自动弹出设置界面。",
        "點擊下面的按鈕，會開啟和 /psa 完全相同的 PetStatusAlert 設定面板。此分類重新整理時不會再自動彈出設定介面。",
        "Нажмите кнопку ниже, чтобы открыть ту же панель настроек PetStatusAlert, что и через /psa. Она не будет открываться автоматически при обновлении этой категории."
    ), "LEFT", 13, PSA_STYLE.text)
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    desc:SetWidth(640)
    panel.psaProxyDesc = desc

    local openButton = CreateStyledButton(panel, SETTINGS_STANDALONE_TEXT, 145, 28)
    openButton:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -16)
    panel.psaProxyOpenButton = openButton
    openButton:SetScript("OnClick", function()
        OpenOptionsFrame()
    end)

    panel:SetScript("OnShow", function()
        -- Do not call OpenOptionsFrame() here.
        -- WoW can re-show the last AddOns settings category after AFK, control regain, or Settings refresh.
        -- Auto-opening the large frame from OnShow would make the settings UI pop up unexpectedly.
    end)

    return panel
end


local function RefreshNativeProxyPanelLocale(panel)
    panel = panel or nativeSettingsPanel
    if not panel then
        return
    end

    if panel.psaProxyTitle then
        panel.psaProxyTitle:SetText(UI.TITLE)
    end
    if panel.psaProxyDesc then
        panel.psaProxyDesc:SetText(LocaleText(
            "Click the button below to open the same PetStatusAlert settings panel as /psa. It will not auto-open when this category is refreshed.",
            "点击下面的按钮，会打开和 /psa 完全相同的 PetStatusAlert 设置面板。此分类刷新时不会再自动弹出设置界面。",
            "點擊下面的按鈕，會開啟和 /psa 完全相同的 PetStatusAlert 設定面板。此分類重新整理時不會再自動彈出設定介面。",
            "Нажмите кнопку ниже, чтобы открыть ту же панель настроек PetStatusAlert, что и через /psa. Она не будет открываться автоматически при обновлении этой категории."
        ))
    end
    if panel.psaProxyOpenButton then
        panel.psaProxyOpenButton:SetText(SETTINGS_STANDALONE_TEXT)
        AutoFitButton(panel.psaProxyOpenButton, 145)
    end
end

ApplyLanguageSelection = function(languageMode)
    InitDB()

    languageMode = tostring(languageMode or "auto")
    if languageMode ~= "auto" and not SUPPORTED_LOCALES[languageMode] then
        languageMode = "auto"
    end

    PetStatusAlertDB.language = languageMode
    RefreshAllLocaleState()
    RefreshOptionsFrameLocale()
    RefreshNativeProxyPanelLocale()

    if PSA.currentStatusKey then
        ShowStatus(PSA.currentStatusKey, PSA.currentStatusForce)
    else
        RefreshPetStatusText()
    end

    if statusLine then
        statusLine:SetText(string.format(UI.LANGUAGE_CHANGED, GetLanguageModeLabel(languageMode)))
    end
end


local function RegisterNativeOptionsCategory()
    if nativeSettingsRegistered then
        return
    end
    if type(Settings) ~= "table"
        or type(Settings.RegisterCanvasLayoutCategory) ~= "function"
        or type(Settings.RegisterAddOnCategory) ~= "function"
    then
        return
    end

    local panel = CreateNativeProxyPanel()
    nativeSettingsCategory = Settings.RegisterCanvasLayoutCategory(panel, "PetStatusAlert")
    Settings.RegisterAddOnCategory(nativeSettingsCategory)
    nativeSettingsRegistered = true
end

local function OpenNativeOptionsFrame()
    RegisterNativeOptionsCategory()
    OpenOptionsFrame()
    return true
end


-------------------------------------------------
-- Public UI API
-------------------------------------------------

PSA.OpenOptionsFrame = OpenOptionsFrame
PSA.RefreshOptionsFrameLocale = RefreshOptionsFrameLocale
PSA.RegisterNativeOptionsCategory = RegisterNativeOptionsCategory
PSA.OpenNativeOptionsFrame = OpenNativeOptionsFrame
PSA.ApplyLanguageSelection = ApplyLanguageSelection
