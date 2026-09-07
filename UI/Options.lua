-------------------------------------------------
-- PetStatusAlert UI / Options
-- UI redesign: clearer grouping + scrollable pages
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
local GetAlertIconMode = PSA.GetAlertIconMode
local SetAlertIconMode = PSA.SetAlertIconMode
local GetAlertIconSize = PSA.GetAlertIconSize
local SetAlertIconSize = PSA.SetAlertIconSize
local GetAlertIconGap = PSA.GetAlertIconGap
local SetAlertIconGap = PSA.SetAlertIconGap

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

-------------------------------------------------
-- State / constants
-------------------------------------------------

local optionsFrame
local nativeSettingsPanel
local nativeSettingsCategory
local nativeSettingsRegistered = false
local ApplyLanguageSelection

local editBoxes = {}
local statusEnableCheckBoxes = {}
local statusLine
local moveToggleButton

local DEFAULT_ALERT_FONT_SIZE = PSA.DEFAULT_ALERT_FONT_SIZE or 28
local DEFAULT_ALERT_FLOAT_AMPLITUDE = PSA.DEFAULT_ALERT_FLOAT_AMPLITUDE or 8
local DEFAULT_ALERT_FLOAT_SPEED = PSA.DEFAULT_ALERT_FLOAT_SPEED or 1
local DEFAULT_ALERT_GLOW_ENABLED = PSA.DEFAULT_ALERT_GLOW_ENABLED == true
local DEFAULT_ALERT_GLOW_SPEED = PSA.DEFAULT_ALERT_GLOW_SPEED or 1
local DEFAULT_ALERT_ICON_MODE = PSA.DEFAULT_ALERT_ICON_MODE or "both"
local DEFAULT_ALERT_ICON_SIZE = PSA.DEFAULT_ALERT_ICON_SIZE or 48
local DEFAULT_ALERT_ICON_GAP = PSA.DEFAULT_ALERT_ICON_GAP or 10

local LAYOUT = {
    frameWidth = 900,
    frameHeight = 680,
    navWidth = 166,
    contentWidth = 650,
    pageTopGap = 0,
    cardGap = 10,
    buttonHeight = 28,
    sliderWidth = 306,
}

local STYLE = {
    frameBg = { 0.025, 0.025, 0.025, 0.95 },
    frameBorder = { 0.30, 0.24, 0.14, 0.96 },
    panelBg = { 0.055, 0.055, 0.055, 0.78 },
    panelBgSoft = { 0.045, 0.045, 0.045, 0.62 },
    divider = { 1.00, 0.82, 0.00, 0.22 },
    text = { 0.92, 0.90, 0.84, 1.00 },
    muted = { 0.64, 0.63, 0.58, 0.95 },
    white = { 1.00, 1.00, 1.00, 1.00 },
    gold = { 1.00, 0.82, 0.00, 1.00 },
    red = { 1.00, 0.30, 0.24, 1.00 },
    green = { 0.35, 0.90, 0.40, 1.00 },
}

local TEXT = {}

-------------------------------------------------
-- Generic helpers
-------------------------------------------------

local function ColorRGBA(color)
    return color[1], color[2], color[3], color[4]
end

local function LocaleText(enUS, zhCN, zhTW, ruRU)
    local locale = GetActiveLocale and GetActiveLocale() or "enUS"
    if locale == "zhCN" then
        return zhCN
    elseif locale == "zhTW" then
        return zhTW
    elseif locale == "ruRU" then
        return ruRU or enUS
    end
    return enUS
end

local function RefreshStaticText()
    TEXT.NAV_ALERTS = LocaleText("Alerts", "提醒设置", "提醒設定", "Предупреждения")
    TEXT.NAV_DISPLAY = LocaleText("Display", "显示样式", "顯示樣式", "Отображение")
    TEXT.NAV_VOICE = LocaleText("Voice", "语音提醒", "語音提醒", "Озвучивание")
    TEXT.NAV_GENERAL = LocaleText("General", "通用", "一般", "Общие")

    TEXT.ALERTS_TITLE = LocaleText("Alert rules and messages", "提醒规则与文字", "提醒規則與文字", "Правила и тексты предупреждений")
    TEXT.ALERTS_DESC = LocaleText(
        "Choose which pet states should warn you. Each state can use its own text and color.",
        "选择哪些宠物状态需要提醒；每种状态都可以单独设置文字和颜色。",
        "選擇哪些寵物狀態需要提醒；每種狀態都可以單獨設定文字與顏色。",
        "Выберите состояния питомца для предупреждений. Для каждого можно настроить текст и цвет."
    )
    TEXT.CUSTOM_TEXT = LocaleText("Custom text", "自定义文字", "自訂文字", "Свой текст")
    TEXT.USE_DEFAULT = LocaleText("Default", "默认文字", "預設文字", "По умолчанию")
    TEXT.COLOR_HINT = LocaleText("Color: left-click to choose, right-click to reset.", "颜色：左键选择，右键恢复默认。", "顏色：左鍵選擇，右鍵恢復預設。", "Цвет: ЛКМ — выбрать, ПКМ — сбросить.")

    TEXT.DISPLAY_TITLE = LocaleText("On-screen alert appearance", "屏幕提醒外观", "螢幕提醒外觀", "Внешний вид предупреждения")
    TEXT.DISPLAY_DESC = LocaleText(
        "Position, icon/text mode, size, movement and glow are grouped here.",
        "位置、图标/文字模式、大小、浮动和流光统一在这里设置。",
        "位置、圖示/文字模式、大小、浮動和流光統一在這裡設定。",
        "Здесь находятся позиция, режим значка/текста, размер, движение и свечение."
    )
    TEXT.SECTION_POSITION = LocaleText("Position & preview", "位置与预览", "位置與預覽", "Позиция и предпросмотр")
    TEXT.SECTION_PRESENTATION = LocaleText("Icon & text", "图标与文字", "圖示與文字", "Значок и текст")
    TEXT.SECTION_MOTION = LocaleText("Text & movement", "文字与动画", "文字與動畫", "Текст и движение")
    TEXT.SECTION_EFFECTS = LocaleText("Effects", "特效", "特效", "Эффекты")
    TEXT.ICON_GAP = LocaleText("Icon / text spacing", "图标与文字间距", "圖示與文字間距", "Расстояние между значком и текстом")
    TEXT.ICON_GAP_HINT = LocaleText(
        "Only affects Icon + Text mode. Default: 10.",
        "只影响“图标+文字”模式。默认：10。",
        "只影響「圖示+文字」模式。預設：10。",
        "Работает только в режиме «Значок + текст». По умолчанию: 10."
    )
    TEXT.ICON_GAP_VALUE = LocaleText("Spacing: %s", "间距：%s", "間距：%s", "Расстояние: %s")
    TEXT.UNLOCK = LocaleText("Unlock move", "解锁移动", "解鎖移動", "Разблокировать")
    TEXT.LOCK = LocaleText("Lock position", "锁定位置", "鎖定位置", "Закрепить")
    TEXT.RESET_POSITION = LocaleText("Reset position", "恢复默认位置", "恢復預設位置", "Сбросить позицию")
    TEXT.POSITION_RESET_DONE = LocaleText("Alert position reset", "提示位置已恢复默认", "提示位置已恢復預設", "Позиция предупреждения сброшена")

    TEXT.VOICE_TITLE = LocaleText("Combat voice reminder", "战斗语音提醒", "戰鬥語音提醒", "Голосовое напоминание в бою")
    TEXT.VOICE_DESC = LocaleText(
        "TTS is independent from the visual style. Keep it disabled if you only want on-screen alerts.",
        "TTS 与屏幕样式独立；如果只需要屏幕提醒，保持关闭即可。",
        "TTS 與螢幕樣式獨立；如果只需要螢幕提醒，保持關閉即可。",
        "TTS не зависит от визуального оформления. Оставьте выключенным, если нужен только экранный текст."
    )

    TEXT.GENERAL_TITLE = LocaleText("General settings", "通用设置", "一般設定", "Общие настройки")
    TEXT.GENERAL_DESC = LocaleText(
        "Language and addon information.",
        "语言与插件信息。",
        "語言與插件資訊。",
        "Язык и информация об аддоне."
    )
    TEXT.SECTION_LANGUAGE = LocaleText("Language", "界面语言", "介面語言", "Язык")
    TEXT.SECTION_ABOUT = LocaleText("About PetStatusAlert", "关于 PetStatusAlert", "關於 PetStatusAlert", "О PetStatusAlert")
    TEXT.OPEN_LARGE_PANEL = LocaleText("Open large panel", "打开独立大面板", "開啟獨立大面板", "Открыть настройки")
end

local function RefreshAllLocaleState()
    if RefreshLocaleTables then
        RefreshLocaleTables()
    end
    RefreshStaticText()
end

RefreshStaticText()

local function GetPlayerClassColor()
    local _, classToken = UnitClass("player")
    local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
    local color = colors and colors[classToken]
    if color then
        return color.r or 1, color.g or 0.82, color.b or 0
    end
    return 1, 0.82, 0
end

local function ApplyBackdrop(frame, bg, border)
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
    frame:SetBackdropColor(ColorRGBA(bg or STYLE.panelBg))
    frame:SetBackdropBorderColor(ColorRGBA(border or STYLE.frameBorder))
end

local function ApplyFontString(fontString, size, color, shadow)
    if not fontString then
        return
    end
    local font, _, flags = fontString:GetFont()
    fontString:SetFont(font or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size or 14, flags or "")
    fontString:SetTextColor(ColorRGBA(color or STYLE.text))
    if shadow ~= false then
        fontString:SetShadowOffset(1, -1)
        fontString:SetShadowColor(0, 0, 0, 0.85)
    end
end

local function CreateText(parent, fontObject, textValue, size, color, justify)
    local fs = parent:CreateFontString(nil, "ARTWORK", fontObject or "GameFontNormal")
    fs:SetText(textValue or "")
    fs:SetJustifyH(justify or "LEFT")
    ApplyFontString(fs, size, color)
    return fs
end

local function AutoFitButton(button, minWidth, padding)
    if not button then
        return
    end
    local width = minWidth or 92
    local fs = button:GetFontString()
    if fs and fs.GetStringWidth then
        width = math.max(width, math.ceil(fs:GetStringWidth() + (padding or 26)))
    end
    button:SetWidth(width)
end

local function CreateButton(parent, label, width, height)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 100, height or LAYOUT.buttonHeight)
    button:SetText(label or "")
    ApplyFontString(button:GetFontString(), 13, STYLE.white)
    AutoFitButton(button, width or 100)
    return button
end

local function CreateSection(parent, titleText, descText, yOffset, height)
    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    box:SetSize(LAYOUT.contentWidth, height)
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
    ApplyBackdrop(box, STYLE.panelBg, STYLE.frameBorder)

    local r, g, b = GetPlayerClassColor()
    local accent = box:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -1)
    accent:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 0, 1)
    accent:SetWidth(3)
    accent:SetColorTexture(r, g, b, 0.72)

    local title = CreateText(box, "GameFontNormal", titleText, 16, STYLE.white)
    title:SetPoint("TOPLEFT", box, "TOPLEFT", 16, -13)
    title:SetWidth(LAYOUT.contentWidth - 32)

    local desc
    if descText and descText ~= "" then
        desc = CreateText(box, "GameFontDisableSmall", descText, 12, STYLE.muted)
        desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
        desc:SetWidth(LAYOUT.contentWidth - 32)
        if desc.SetWordWrap then
            desc:SetWordWrap(true)
        end
    end

    box.sectionTitle = title
    box.sectionDesc = desc
    return box
end

local function CreatePageHeader(parent, titleText, descText)
    local title = CreateText(parent, "GameFontNormal", titleText, 18, STYLE.white)
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    title:SetWidth(LAYOUT.contentWidth)

    local desc = CreateText(parent, "GameFontDisableSmall", descText, 12, STYLE.muted)
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    desc:SetWidth(LAYOUT.contentWidth - 10)
    if desc.SetWordWrap then
        desc:SetWordWrap(true)
    end

    return title, desc
end

local function CreateScrollablePage(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -24, 0)
    scroll:EnableMouseWheel(true)

    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(LAYOUT.contentWidth, 1)
    scroll:SetScrollChild(child)

    scroll:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll() or 0
        local maxScroll = self:GetVerticalScrollRange() or 0
        local nextValue = current - (delta * 48)
        if nextValue < 0 then
            nextValue = 0
        elseif nextValue > maxScroll then
            nextValue = maxScroll
        end
        self:SetVerticalScroll(nextValue)
    end)

    local function Finish(height)
        child:SetHeight(math.max(height or 1, 1))
    end

    return child, Finish, scroll
end

local function SkinEditBox(editBox)
    editBox:SetAutoFocus(false)
    editBox:SetMultiLine(false)
    editBox:SetMaxLetters(180)
    editBox:SetFontObject("GameFontHighlightSmall")
    editBox:SetTextColor(0.95, 0.95, 0.95, 1)
    editBox:SetTextInsets(8, 8, 0, 0)
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

local function FormatOneDecimal(value)
    return string.format("%.1f", tonumber(value) or 0)
end

local function CreateSliderRow(parent, labelText, hintText, yOffset, minValue, maxValue, stepValue, value, valueText, onChanged)
    local label = CreateText(parent, "GameFontNormal", labelText, 14, STYLE.gold)
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", 18, yOffset)
    label:SetWidth(270)

    local hint = CreateText(parent, "GameFontDisableSmall", hintText or "", 11, STYLE.muted)
    hint:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
    hint:SetWidth(270)
    if hint.SetWordWrap then
        hint:SetWordWrap(true)
    end

    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetSize(LAYOUT.sliderWidth, 16)
    slider:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -24, yOffset - 8)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(stepValue)
    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(true)
    end
    slider:SetValue(value)
    HideSliderTemplateLabels(slider)

    local minText = CreateText(parent, "GameFontDisableSmall", tostring(minValue), 10, STYLE.muted)
    minText:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -3)

    local currentText = CreateText(parent, "GameFontDisableSmall", valueText or tostring(value), 11, STYLE.gold, "CENTER")
    currentText:SetPoint("TOP", slider, "BOTTOM", 0, -3)
    currentText:SetWidth(170)

    local maxText = CreateText(parent, "GameFontDisableSmall", tostring(maxValue), 10, STYLE.muted, "RIGHT")
    maxText:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -3)

    slider:SetScript("OnValueChanged", function(_, newValue)
        if onChanged then
            local display = onChanged(newValue)
            if display ~= nil then
                currentText:SetText(display)
            end
        end
    end)

    return slider, currentText
end

-------------------------------------------------
-- Color picker
-------------------------------------------------

local function UpdateColorSwatch(swatch, statusKey)
    if not swatch then
        return
    end
    local r, g, b, a = GetStatusColor(statusKey)
    swatch:SetColorTexture(r, g, b, a or 1)
end

local function CreateColorButton(parent, statusKey)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(28, 26)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    ApplyBackdrop(button, { 0.03, 0.03, 0.03, 0.95 }, STYLE.frameBorder)

    local swatch = button:CreateTexture(nil, "ARTWORK")
    swatch:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -4)
    swatch:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 4)
    UpdateColorSwatch(swatch, statusKey)
    button.swatch = swatch

    local hover = button:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints(swatch)
    hover:SetColorTexture(1, 1, 1, 0.18)

    return button
end

local function OpenStatusColorPicker(statusKey, swatch)
    if not ColorPickerFrame then
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
            statusLine:SetText(UI.COLOR_SAVED or "Color saved")
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

-------------------------------------------------
-- Alerts page
-------------------------------------------------

local function CreateStatusCard(parent, statusKey, yOffset)
    InitDB()

    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetSize(LAYOUT.contentWidth, 112)
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
    ApplyBackdrop(card, STYLE.panelBg, STYLE.frameBorder)

    local r, g, b = GetPlayerClassColor()
    local accent = card:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", card, "TOPLEFT", 0, -1)
    accent:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 0, 1)
    accent:SetWidth(3)
    accent:SetColorTexture(r, g, b, 0.72)

    local check = CreateFrame("CheckButton", nil, card, "UICheckButtonTemplate")
    check:SetSize(22, 22)
    check:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -10)
    check:SetChecked(IsStatusEnabled(statusKey))
    statusEnableCheckBoxes[statusKey] = check

    local title = CreateText(card, "GameFontNormal", STATUS_LABEL[statusKey] or statusKey, 15, STYLE.white)
    title:SetPoint("LEFT", check, "RIGHT", 3, 0)
    title:SetWidth(190)

    local keyText = CreateText(card, "GameFontDisableSmall", statusKey, 10, STYLE.muted)
    keyText:SetPoint("LEFT", title, "RIGHT", 6, 0)
    keyText:SetWidth(90)

    local enabledText = CreateText(card, "GameFontDisableSmall", UI.ENABLE_ALERT or "Enable this alert", 11, STYLE.muted)
    enabledText:SetPoint("TOPRIGHT", card, "TOPRIGHT", -14, -13)
    enabledText:SetWidth(190)
    enabledText:SetJustifyH("RIGHT")

    check:SetScript("OnClick", function(self)
        local enabled = self:GetChecked() and true or false
        SetStatusEnabled(statusKey, enabled)
        RefreshPetStatusText()
        if statusLine then
            local formatText = enabled and UI.ALERT_ENABLED or UI.ALERT_DISABLED
            statusLine:SetText(string.format(formatText or "%s", STATUS_LABEL[statusKey] or statusKey))
        end
    end)

    local defaultText = CreateText(card, "GameFontDisableSmall", (UI.DEFAULT_PREFIX or "Default:") .. " " .. GetDefaultMessage(statusKey), 11, STYLE.muted)
    defaultText:SetPoint("TOPLEFT", card, "TOPLEFT", 16, -39)
    defaultText:SetWidth(LAYOUT.contentWidth - 32)

    local customLabel = CreateText(card, "GameFontDisableSmall", TEXT.CUSTOM_TEXT, 11, STYLE.gold)
    customLabel:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 16, 17)
    customLabel:SetWidth(80)

    local editBox = CreateFrame("EditBox", nil, card, "InputBoxTemplate")
    editBox:SetSize(296, 28)
    editBox:SetPoint("LEFT", customLabel, "RIGHT", 2, 0)
    SkinEditBox(editBox)
    editBox:SetText(PetStatusAlertDB.customMessages[statusKey] or "")
    editBoxes[statusKey] = editBox

    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    editBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        RefreshPetStatusText()
    end)
    editBox:SetScript("OnEditFocusGained", function(self)
        if self.HighlightText then
            self:HighlightText()
        end
    end)
    editBox:SetScript("OnEditFocusLost", function()
        RefreshPetStatusText()
    end)
    editBox:SetScript("OnTextChanged", function(self, userInput)
        if not userInput then
            return
        end
        InitDB()
        PetStatusAlertDB.customMessages[statusKey] = self:GetText() or ""
        if statusLine then
            statusLine:SetText(UI.SAVED or "Saved automatically")
        end
        if PSA.currentStatusKey == statusKey then
            PreviewStatus(statusKey)
        end
    end)

    local colorButton = CreateColorButton(card, statusKey)
    colorButton:SetPoint("LEFT", editBox, "RIGHT", 8, 0)
    colorButton:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" then
            ResetStatusColor(statusKey)
            UpdateColorSwatch(self.swatch, statusKey)
            PreviewStatus(statusKey)
            if statusLine then
                statusLine:SetText(UI.COLOR_RESET or "Color reset")
            end
        else
            OpenStatusColorPicker(statusKey, self.swatch)
        end
    end)

    local previewButton = CreateButton(card, UI.PREVIEW or "Preview", 70, 26)
    previewButton:SetPoint("LEFT", colorButton, "RIGHT", 7, 0)
    previewButton:SetScript("OnClick", function()
        PreviewStatus(statusKey)
        if statusLine then
            statusLine:SetText((STATUS_LABEL[statusKey] or statusKey) .. " - " .. GetDisplayMessage(statusKey))
        end
    end)

    local defaultButton = CreateButton(card, TEXT.USE_DEFAULT, 108, 26)
    defaultButton:SetPoint("LEFT", previewButton, "RIGHT", 7, 0)
    defaultButton:SetScript("OnClick", function()
        InitDB()
        PetStatusAlertDB.customMessages[statusKey] = ""
        editBox:SetText("")
        if PSA.currentStatusKey == statusKey then
            PreviewStatus(statusKey)
        end
        if statusLine then
            statusLine:SetText(UI.CLEARED or "Custom text cleared")
        end
    end)

    return card
end

local function DrawAlertsPage(parent)
    editBoxes = {}
    statusEnableCheckBoxes = {}

    local page, finish = CreateScrollablePage(parent)
    local _, desc = CreatePageHeader(page, TEXT.ALERTS_TITLE, TEXT.ALERTS_DESC)

    local colorHint = CreateText(page, "GameFontDisableSmall", TEXT.COLOR_HINT, 11, STYLE.gold)
    colorHint:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -8)
    colorHint:SetWidth(LAYOUT.contentWidth)

    local startY = -76
    local step = 122
    for index, statusKey in ipairs(STATUS_ORDER) do
        CreateStatusCard(page, statusKey, startY - ((index - 1) * step))
    end

    finish(76 + (#STATUS_ORDER * step) + 12)
end

-------------------------------------------------
-- Display page
-------------------------------------------------

local ICON_MODE_LABEL_KEYS = {
    text = "ANIMATION_ICON_MODE_TEXT",
    icon = "ANIMATION_ICON_MODE_ICON",
    both = "ANIMATION_ICON_MODE_BOTH",
}

local function GetIconModeLabel(mode)
    local key = ICON_MODE_LABEL_KEYS[mode] or ICON_MODE_LABEL_KEYS[DEFAULT_ALERT_ICON_MODE]
    return UI[key] or mode
end

local function GetMoveButtonText()
    InitDB()
    return PetStatusAlertDB.alertLocked and TEXT.UNLOCK or TEXT.LOCK
end

local function SetIconModeButtonState(button, active)
    if not button then
        return
    end
    button:SetAlpha(active and 1.0 or 0.58)
    local fs = button:GetFontString()
    if fs then
        fs:SetTextColor(ColorRGBA(active and STYLE.white or STYLE.gold))
    end
end

local function DrawDisplayPage(parent)
    local page, finish = CreateScrollablePage(parent)
    local _, desc = CreatePageHeader(page, TEXT.DISPLAY_TITLE, TEXT.DISPLAY_DESC)

    local y = -72

    -------------------------------------------------
    -- Position
    -------------------------------------------------
    local positionBox = CreateSection(page, TEXT.SECTION_POSITION, LocaleText(
        "Preview the alert, unlock it to drag, or restore the default screen position.",
        "先预览提醒；需要移动时解锁后直接拖动屏幕提醒，也可恢复默认位置。",
        "先預覽提醒；需要移動時解鎖後直接拖動螢幕提醒，也可恢復預設位置。",
        "Покажите предупреждение, разблокируйте его для перетаскивания или верните позицию по умолчанию."
    ), y, 104)

    local previewButton = CreateButton(positionBox, UI.PREVIEW or "Preview", 96, 28)
    previewButton:SetPoint("BOTTOMLEFT", positionBox, "BOTTOMLEFT", 18, 15)
    previewButton:SetScript("OnClick", function()
        PreviewStatus("PASSIVE")
        if statusLine then
            statusLine:SetText(GetDisplayMessage("PASSIVE"))
        end
    end)

    moveToggleButton = CreateButton(positionBox, GetMoveButtonText(), 112, 28)
    moveToggleButton:SetPoint("LEFT", previewButton, "RIGHT", 10, 0)
    moveToggleButton:SetScript("OnClick", function()
        InitDB()
        local locked = not PetStatusAlertDB.alertLocked
        SetAlertPositionLocked(locked)
        moveToggleButton:SetText(GetMoveButtonText())
        AutoFitButton(moveToggleButton, 112)
        if not locked then
            PreviewStatus("PASSIVE")
        end
        if statusLine then
            statusLine:SetText(locked and (UI.LOCKED_STATUS or TEXT.LOCK) or (UI.UNLOCKED_STATUS or TEXT.UNLOCK))
        end
    end)

    local resetButton = CreateButton(positionBox, TEXT.RESET_POSITION, 130, 28)
    resetButton:SetPoint("LEFT", moveToggleButton, "RIGHT", 10, 0)
    resetButton:SetScript("OnClick", function()
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
            statusLine:SetText(TEXT.POSITION_RESET_DONE)
        end
    end)

    y = y - 114

    -------------------------------------------------
    -- Icon + text presentation
    -------------------------------------------------
    local presentationBox = CreateSection(page, TEXT.SECTION_PRESENTATION, UI.ANIMATION_ICON_MODE_HINT or "", y, 258)

    local modeLabel = CreateText(presentationBox, "GameFontNormal", UI.ANIMATION_ICON_MODE or "Icon mode", 14, STYLE.gold)
    modeLabel:SetPoint("TOPLEFT", presentationBox, "TOPLEFT", 18, -70)

    local modeButtons = {}
    local previous
    for _, mode in ipairs({ "text", "icon", "both" }) do
        local button = CreateButton(presentationBox, GetIconModeLabel(mode), 112, 28)
        if previous then
            button:SetPoint("LEFT", previous, "RIGHT", 8, 0)
        else
            button:SetPoint("LEFT", modeLabel, "RIGHT", 18, 0)
        end
        button:SetScript("OnClick", function()
            local newMode = SetAlertIconMode(mode)
            for key, modeButton in pairs(modeButtons) do
                SetIconModeButtonState(modeButton, key == newMode)
            end
            PreviewStatus("NO_PET")
            if statusLine then
                statusLine:SetText(string.format(UI.ANIMATION_ICON_MODE_CHANGED or "Icon mode set to: %s", GetIconModeLabel(newMode)))
            end
        end)
        modeButtons[mode] = button
        previous = button
    end

    local currentMode = GetAlertIconMode and GetAlertIconMode() or DEFAULT_ALERT_ICON_MODE
    for key, button in pairs(modeButtons) do
        SetIconModeButtonState(button, key == currentMode)
    end

    CreateSliderRow(
        presentationBox,
        UI.ANIMATION_ICON_SIZE or "Icon size",
        UI.ANIMATION_ICON_SIZE_HINT or "Default: 48.",
        -120,
        24,
        96,
        1,
        GetAlertIconSize and GetAlertIconSize() or DEFAULT_ALERT_ICON_SIZE,
        string.format(UI.ANIMATION_ICON_SIZE_VALUE or "Icon size: %s", tostring(GetAlertIconSize and GetAlertIconSize() or DEFAULT_ALERT_ICON_SIZE)),
        function(value)
            local newValue = SetAlertIconSize(value)
            PreviewStatus("NO_PET")
            return string.format(UI.ANIMATION_ICON_SIZE_VALUE or "Icon size: %s", tostring(newValue))
        end
    )

    CreateSliderRow(
        presentationBox,
        TEXT.ICON_GAP,
        TEXT.ICON_GAP_HINT,
        -188,
        0,
        40,
        1,
        GetAlertIconGap and GetAlertIconGap() or DEFAULT_ALERT_ICON_GAP,
        string.format(TEXT.ICON_GAP_VALUE, tostring(GetAlertIconGap and GetAlertIconGap() or DEFAULT_ALERT_ICON_GAP)),
        function(value)
            local newValue = SetAlertIconGap and SetAlertIconGap(value) or DEFAULT_ALERT_ICON_GAP
            PreviewStatus("NO_PET")
            return string.format(TEXT.ICON_GAP_VALUE, tostring(newValue))
        end
    )

    y = y - 268

    -------------------------------------------------
    -- Text and movement
    -------------------------------------------------
    local motionBox = CreateSection(page, TEXT.SECTION_MOTION, LocaleText(
        "Adjust the text size and vertical floating animation.",
        "调整提示文字大小以及上下浮动的幅度和速度。",
        "調整提示文字大小以及上下浮動的幅度和速度。",
        "Настройте размер текста и вертикальную анимацию."
    ), y, 278)

    CreateSliderRow(
        motionBox,
        UI.ANIMATION_FONT_SIZE or "Alert font size",
        UI.ANIMATION_FONT_SIZE_HINT or "Default: 28.",
        -72,
        12,
        72,
        1,
        GetAlertFontSize and GetAlertFontSize() or DEFAULT_ALERT_FONT_SIZE,
        string.format(UI.ANIMATION_FONT_SIZE_VALUE or "Font size: %s", tostring(GetAlertFontSize and GetAlertFontSize() or DEFAULT_ALERT_FONT_SIZE)),
        function(value)
            local newValue = SetAlertFontSize(value)
            PreviewStatus("PASSIVE")
            return string.format(UI.ANIMATION_FONT_SIZE_VALUE or "Font size: %s", tostring(newValue))
        end
    )

    CreateSliderRow(
        motionBox,
        UI.ANIMATION_AMPLITUDE or "Up/down float amplitude",
        UI.ANIMATION_AMPLITUDE_HINT or "Default: 8.",
        -140,
        0,
        24,
        1,
        GetAlertFloatAmplitude and GetAlertFloatAmplitude() or DEFAULT_ALERT_FLOAT_AMPLITUDE,
        string.format(UI.ANIMATION_AMPLITUDE_VALUE or "Amplitude: %s", tostring(GetAlertFloatAmplitude and GetAlertFloatAmplitude() or DEFAULT_ALERT_FLOAT_AMPLITUDE)),
        function(value)
            local newValue = SetAlertFloatAmplitude(value)
            PreviewStatus("PASSIVE")
            return string.format(UI.ANIMATION_AMPLITUDE_VALUE or "Amplitude: %s", tostring(newValue))
        end
    )

    CreateSliderRow(
        motionBox,
        UI.ANIMATION_SPEED or "Up/down float speed",
        UI.ANIMATION_SPEED_HINT or "1.0x = default.",
        -208,
        0.1,
        3,
        0.1,
        GetAlertFloatSpeed and GetAlertFloatSpeed() or DEFAULT_ALERT_FLOAT_SPEED,
        string.format(UI.ANIMATION_SPEED_VALUE or "Speed: %sx", FormatOneDecimal(GetAlertFloatSpeed and GetAlertFloatSpeed() or DEFAULT_ALERT_FLOAT_SPEED)),
        function(value)
            local newValue = SetAlertFloatSpeed(value)
            PreviewStatus("PASSIVE")
            return string.format(UI.ANIMATION_SPEED_VALUE or "Speed: %sx", FormatOneDecimal(newValue))
        end
    )

    y = y - 288

    -------------------------------------------------
    -- Effects
    -------------------------------------------------
    local effectsBox = CreateSection(page, TEXT.SECTION_EFFECTS, UI.ANIMATION_GLOW_ENABLE_HINT or "", y, 176)

    local glowCheck = CreateFrame("CheckButton", nil, effectsBox, "UICheckButtonTemplate")
    glowCheck:SetSize(22, 22)
    glowCheck:SetPoint("TOPLEFT", effectsBox, "TOPLEFT", 14, -68)
    local glowEnabled = GetAlertGlowEnabled and GetAlertGlowEnabled()
    if glowEnabled == nil then
        glowEnabled = DEFAULT_ALERT_GLOW_ENABLED
    end
    glowCheck:SetChecked(glowEnabled)

    local glowLabel = CreateText(effectsBox, "GameFontNormal", UI.ANIMATION_GLOW_ENABLE or "Pixel glow", 14, STYLE.gold)
    glowLabel:SetPoint("LEFT", glowCheck, "RIGHT", 3, 0)

    glowCheck:SetScript("OnClick", function(self)
        local enabled = SetAlertGlowEnabled(self:GetChecked() and true or false)
        self:SetChecked(enabled)
        PreviewStatus("NO_PET")
        if statusLine then
            statusLine:SetText(enabled and (UI.ANIMATION_GLOW_ON or "Pixel glow enabled") or (UI.ANIMATION_GLOW_OFF or "Pixel glow disabled"))
        end
    end)

    CreateSliderRow(
        effectsBox,
        UI.ANIMATION_GLOW_SPEED or "Pixel glow speed",
        UI.ANIMATION_GLOW_SPEED_HINT or "1.0x = default.",
        -112,
        0.2,
        3,
        0.1,
        GetAlertGlowSpeed and GetAlertGlowSpeed() or DEFAULT_ALERT_GLOW_SPEED,
        string.format(UI.ANIMATION_GLOW_SPEED_VALUE or "Glow speed: %sx", FormatOneDecimal(GetAlertGlowSpeed and GetAlertGlowSpeed() or DEFAULT_ALERT_GLOW_SPEED)),
        function(value)
            local newValue = SetAlertGlowSpeed(value)
            PreviewStatus("NO_PET")
            return string.format(UI.ANIMATION_GLOW_SPEED_VALUE or "Glow speed: %sx", FormatOneDecimal(newValue))
        end
    )

    finish(math.abs(y) + 188)
end

-------------------------------------------------
-- Voice page
-------------------------------------------------

local function DrawVoicePage(parent)
    local page, finish = CreateScrollablePage(parent)
    local _, desc = CreatePageHeader(page, TEXT.VOICE_TITLE, TEXT.VOICE_DESC)

    local voiceBox = CreateSection(page, UI.COMBAT_TTS or TEXT.VOICE_TITLE, UI.COMBAT_TTS_HINT or "", -78, 220)

    local check = CreateFrame("CheckButton", nil, voiceBox, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check:SetPoint("TOPLEFT", voiceBox, "TOPLEFT", 14, -74)
    check:SetChecked(PetStatusAlertDB.combatTTSEnabled == true)

    local label = CreateText(voiceBox, "GameFontNormal", UI.COMBAT_TTS or TEXT.VOICE_TITLE, 14, STYLE.gold)
    label:SetPoint("LEFT", check, "RIGHT", 3, 0)

    local stateText = CreateText(voiceBox, "GameFontDisableSmall", "", 11, STYLE.muted)
    stateText:SetPoint("LEFT", label, "RIGHT", 10, 0)

    local function RefreshVoiceStateText()
        stateText:SetText(PetStatusAlertDB.combatTTSEnabled and (UI.COMBAT_TTS_ON or "Enabled") or (UI.COMBAT_TTS_OFF or "Disabled"))
        stateText:SetTextColor(ColorRGBA(PetStatusAlertDB.combatTTSEnabled and STYLE.green or STYLE.muted))
    end
    RefreshVoiceStateText()

    check:SetScript("OnClick", function(self)
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
        RefreshVoiceStateText()
        if statusLine then
            statusLine:SetText(PetStatusAlertDB.combatTTSEnabled and (UI.COMBAT_TTS_ON or "Enabled") or (UI.COMBAT_TTS_OFF or "Disabled"))
        end
    end)

    CreateSliderRow(
        voiceBox,
        UI.COMBAT_TTS_RATE or "TTS speech speed",
        UI.COMBAT_TTS_RATE_HINT or "0 = WoW default speed.",
        -132,
        -10,
        10,
        1,
        GetCombatTTSRate(),
        GetCombatTTSRateDisplayText(),
        function(value)
            SetCombatTTSRate(value)
            return GetCombatTTSRateDisplayText()
        end
    )

    finish(320)
end

-------------------------------------------------
-- General page
-------------------------------------------------

local function GetLanguageModeLabel(languageMode)
    languageMode = tostring(languageMode or "auto")
    if languageMode == "enUS" then
        return UI.LANGUAGE_ENUS
    elseif languageMode == "zhCN" then
        return UI.LANGUAGE_ZHCN
    elseif languageMode == "zhTW" then
        return UI.LANGUAGE_ZHTW
    elseif languageMode == "ruRU" then
        return UI.LANGUAGE_RURU
    end
    return UI.LANGUAGE_AUTO
end

local function GetCurrentLanguageModeText()
    return (UI.LANGUAGE_CURRENT or "Current language mode:") .. " " .. GetLanguageModeLabel(GetSavedLanguageMode())
end

local function DrawGeneralPage(parent)
    local page, finish = CreateScrollablePage(parent)
    CreatePageHeader(page, TEXT.GENERAL_TITLE, TEXT.GENERAL_DESC)

    local languageBox = CreateSection(page, TEXT.SECTION_LANGUAGE, UI.LANGUAGE_DESC or "", -72, 188)

    local current = CreateText(languageBox, "GameFontNormal", GetCurrentLanguageModeText(), 13, STYLE.text)
    current:SetPoint("TOPLEFT", languageBox, "TOPLEFT", 18, -72)
    current:SetWidth(LAYOUT.contentWidth - 36)

    local buttons = {
        { "auto", UI.LANGUAGE_AUTO, 112 },
        { "enUS", UI.LANGUAGE_ENUS, 96 },
        { "zhCN", UI.LANGUAGE_ZHCN, 118 },
        { "zhTW", UI.LANGUAGE_ZHTW, 118 },
        { "ruRU", UI.LANGUAGE_RURU, 106 },
    }

    local previous
    for index, info in ipairs(buttons) do
        local button = CreateButton(languageBox, info[2], info[3], 28)
        if index == 1 then
            button:SetPoint("TOPLEFT", current, "BOTTOMLEFT", 0, -12)
        elseif index == 5 then
            button:SetPoint("TOPLEFT", buttons[1].button, "BOTTOMLEFT", 0, -8)
        else
            button:SetPoint("LEFT", previous, "RIGHT", 8, 0)
        end
        info.button = button
        previous = button
        button:SetScript("OnClick", function()
            if ApplyLanguageSelection then
                ApplyLanguageSelection(info[1])
            end
        end)
    end

    local aboutBox = CreateSection(page, TEXT.SECTION_ABOUT, UI.SUPPORT or "", -270, 220)

    local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
    local version = (getMeta and getMeta(ADDON_NAME, "Version")) or "?"

    local infoLines = {
        LocaleText("Version: ", "版本：", "版本：", "Версия: ") .. tostring(version),
        UI.AUTHOR or "Author: zhufei1000",
        UI.TRANSLATION_RURU or "",
        UI.FOOTER or "/psa",
    }

    for index, lineText in ipairs(infoLines) do
        if lineText and lineText ~= "" then
            local line = CreateText(aboutBox, "GameFontNormal", lineText, 13, index == 2 and STYLE.gold or STYLE.text)
            line:SetPoint("TOPLEFT", aboutBox, "TOPLEFT", 18, -78 - ((index - 1) * 30))
            line:SetWidth(LAYOUT.contentWidth - 36)
        end
    end

    finish(510)
end

-------------------------------------------------
-- Navigation + main frame
-------------------------------------------------

local function SetNavButtonActive(button, active)
    if not button then
        return
    end
    button.isActive = active and true or false
    if button.selected then
        button.selected:SetShown(button.isActive)
    end
    if button.text then
        button.text:SetTextColor(ColorRGBA(button.isActive and STYLE.white or STYLE.gold))
    end
end

local function CreateNavButton(parent, labelText, yOffset)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(LAYOUT.navWidth - 8, 34)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)

    local r, g, b = GetPlayerClassColor()

    local selected = button:CreateTexture(nil, "BACKGROUND")
    selected:SetPoint("TOPLEFT", button, "TOPLEFT", 8, 0)
    selected:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    selected:SetColorTexture(r, g, b, 0.22)
    selected:Hide()
    button.selected = selected

    local hover = button:CreateTexture(nil, "BACKGROUND")
    hover:SetPoint("TOPLEFT", button, "TOPLEFT", 8, 0)
    hover:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    hover:SetColorTexture(r, g, b, 0.34)
    hover:Hide()
    button.hover = hover

    local text = CreateText(button, "GameFontNormal", labelText, 14, STYLE.gold)
    text:SetPoint("LEFT", button, "LEFT", 18, 0)
    text:SetWidth(LAYOUT.navWidth - 26)
    button.text = text

    button:SetScript("OnEnter", function(self)
        if not self.isActive then
            self.hover:Show()
            self.text:SetTextColor(ColorRGBA(STYLE.white))
        end
    end)
    button:SetScript("OnLeave", function(self)
        self.hover:Hide()
        if not self.isActive then
            self.text:SetTextColor(ColorRGBA(STYLE.gold))
        end
    end)

    return button
end

local function CreateOptionsFrame()
    if optionsFrame then
        return optionsFrame
    end

    InitDB()

    local frame = CreateFrame("Frame", "PetStatusAlertOptionsFrame", UIParent, "BackdropTemplate")
    optionsFrame = frame
    frame:SetSize(LAYOUT.frameWidth, LAYOUT.frameHeight)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    ApplyBackdrop(frame, STYLE.frameBg, STYLE.frameBorder)

    local title = CreateText(frame, "GameFontNormalLarge", UI.TITLE, 21, STYLE.gold, "CENTER")
    title:SetPoint("TOP", frame, "TOP", 0, -17)
    title:SetWidth(520)
    frame.psaTitle = title

    local subtitle = CreateText(frame, "GameFontDisableSmall", UI.SUBTITLE or "", 11, STYLE.muted, "CENTER")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -5)
    subtitle:SetWidth(610)
    frame.psaSubtitle = subtitle

    local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
    local version = (getMeta and getMeta(ADDON_NAME, "Version")) or "?"
    local versionText = CreateText(frame, "GameFontDisableSmall", "v" .. tostring(version), 11, STYLE.muted)
    versionText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -22, -22)

    local leftPanel = CreateFrame("Frame", nil, frame)
    leftPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -76)
    leftPanel:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 54)
    leftPanel:SetWidth(LAYOUT.navWidth)

    local navDivider = leftPanel:CreateTexture(nil, "ARTWORK")
    navDivider:SetColorTexture(ColorRGBA(STYLE.divider))
    navDivider:SetWidth(1)
    navDivider:SetPoint("TOPRIGHT", leftPanel, "TOPRIGHT", 0, 0)
    navDivider:SetPoint("BOTTOMRIGHT", leftPanel, "BOTTOMRIGHT", 0, 0)

    local navHeader = CreateText(leftPanel, "GameFontDisableSmall", LocaleText("SETTINGS", "设置", "設定", "НАСТРОЙКИ"), 10, STYLE.muted)
    navHeader:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 18, -2)

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 14, -2)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 56)

    frame.activePage = "alerts"
    frame.navButtons = {}
    frame.currentPage = nil

    local function RefreshNavButtons()
        for key, button in pairs(frame.navButtons) do
            SetNavButtonActive(button, key == frame.activePage)
        end
    end

    local function DrawPage()
        if frame.currentPage then
            frame.currentPage:Hide()
            frame.currentPage:SetParent(nil)
            frame.currentPage = nil
        end

        local pageHolder = CreateFrame("Frame", nil, content)
        pageHolder:SetAllPoints(content)
        frame.currentPage = pageHolder

        if frame.activePage == "display" then
            DrawDisplayPage(pageHolder)
        elseif frame.activePage == "voice" then
            DrawVoicePage(pageHolder)
        elseif frame.activePage == "general" then
            DrawGeneralPage(pageHolder)
        else
            DrawAlertsPage(pageHolder)
        end

        RefreshNavButtons()
    end

    local function AddNav(key, label, yOffset)
        local button = CreateNavButton(leftPanel, label, yOffset)
        frame.navButtons[key] = button
        button:SetScript("OnClick", function()
            frame.activePage = key
            DrawPage()
        end)
    end

    AddNav("alerts", TEXT.NAV_ALERTS, -28)
    AddNav("display", TEXT.NAV_DISPLAY, -66)
    AddNav("voice", TEXT.NAV_VOICE, -104)
    AddNav("general", TEXT.NAV_GENERAL, -142)

    local support = CreateText(leftPanel, "GameFontDisableSmall", LocaleText(
        "Hunter\nWarlock\nUnholy DK\nFrost Mage",
        "猎人\n术士\n邪恶死亡骑士\n冰霜法师",
        "獵人\n術士\n邪惡死亡騎士\n冰霜法師",
        "Охотник\nЧернокнижник\nНечестивый Рыцарь смерти\nМаг льда"
    ), 10, STYLE.muted)
    support:SetPoint("BOTTOMLEFT", leftPanel, "BOTTOMLEFT", 18, 12)
    support:SetWidth(LAYOUT.navWidth - 28)
    support:SetSpacing(3)

    statusLine = CreateText(frame, "GameFontHighlightSmall", UI.FOOTER or "/psa", 12, STYLE.text)
    statusLine:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 18)
    statusLine:SetWidth(650)
    frame.psaStatusLine = statusLine

    local close = CreateButton(frame, UI.CLOSE or "Close", 96, 28)
    close:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 13)
    close:SetScript("OnClick", function()
        frame:Hide()
    end)
    frame.psaCloseButton = close

    frame.DrawPage = DrawPage
    DrawPage()

    return frame
end

local function OpenOptionsFrame()
    local frame = CreateOptionsFrame()
    InitDB()
    if frame.DrawPage then
        frame:DrawPage()
    end
    if frame.psaStatusLine then
        statusLine = frame.psaStatusLine
        statusLine:SetText(UI.FOOTER or "/psa")
    end
    frame:Show()
    frame:Raise()
end

local function RefreshOptionsFrameLocale()
    if not optionsFrame then
        return
    end

    local frame = optionsFrame
    if frame.psaTitle then
        frame.psaTitle:SetText(UI.TITLE)
    end
    if frame.psaSubtitle then
        frame.psaSubtitle:SetText(UI.SUBTITLE or "")
    end
    if frame.navButtons then
        if frame.navButtons.alerts and frame.navButtons.alerts.text then
            frame.navButtons.alerts.text:SetText(TEXT.NAV_ALERTS)
        end
        if frame.navButtons.display and frame.navButtons.display.text then
            frame.navButtons.display.text:SetText(TEXT.NAV_DISPLAY)
        end
        if frame.navButtons.voice and frame.navButtons.voice.text then
            frame.navButtons.voice.text:SetText(TEXT.NAV_VOICE)
        end
        if frame.navButtons.general and frame.navButtons.general.text then
            frame.navButtons.general.text:SetText(TEXT.NAV_GENERAL)
        end
    end
    if frame.psaCloseButton then
        frame.psaCloseButton:SetText(UI.CLOSE or "Close")
        AutoFitButton(frame.psaCloseButton, 96)
    end
    if frame.psaStatusLine then
        frame.psaStatusLine:SetText(UI.FOOTER or "/psa")
    end
    if frame.DrawPage then
        frame:DrawPage()
    end
end

-------------------------------------------------
-- Native WoW Settings proxy
-------------------------------------------------

local function CreateNativeProxyPanel()
    if nativeSettingsPanel then
        return nativeSettingsPanel
    end

    local panel = CreateFrame("Frame", "PetStatusAlertNativeSettingsPanel", UIParent)
    nativeSettingsPanel = panel
    panel.name = "PetStatusAlert"

    local title = CreateText(panel, "GameFontNormalLarge", UI.TITLE, 21, STYLE.gold)
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -8)
    panel.psaProxyTitle = title

    local desc = CreateText(panel, "GameFontHighlightSmall", LocaleText(
        "Open the full PetStatusAlert panel for alert rules, appearance, voice and language settings.",
        "打开完整的 PetStatusAlert 面板，可设置提醒规则、显示样式、语音和语言。",
        "開啟完整的 PetStatusAlert 面板，可設定提醒規則、顯示樣式、語音和語言。",
        "Откройте полную панель PetStatusAlert для настройки предупреждений, внешнего вида, озвучивания и языка."
    ), 13, STYLE.text)
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    desc:SetWidth(640)
    panel.psaProxyDesc = desc

    local openButton = CreateButton(panel, TEXT.OPEN_LARGE_PANEL, 150, 28)
    openButton:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -16)
    openButton:SetScript("OnClick", function()
        OpenOptionsFrame()
    end)
    panel.psaProxyOpenButton = openButton

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
            "Open the full PetStatusAlert panel for alert rules, appearance, voice and language settings.",
            "打开完整的 PetStatusAlert 面板，可设置提醒规则、显示样式、语音和语言。",
            "開啟完整的 PetStatusAlert 面板，可設定提醒規則、顯示樣式、語音和語言。",
            "Откройте полную панель PetStatusAlert для настройки предупреждений, внешнего вида, озвучивания и языка."
        ))
    end
    if panel.psaProxyOpenButton then
        panel.psaProxyOpenButton:SetText(TEXT.OPEN_LARGE_PANEL)
        AutoFitButton(panel.psaProxyOpenButton, 150)
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
        statusLine:SetText(string.format(UI.LANGUAGE_CHANGED or "Language switched to: %s", GetLanguageModeLabel(languageMode)))
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
