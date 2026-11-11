-------------------------------------------------
-- PetStatusAlert UI / Options
-- UI redesign: clearer grouping + scrollable pages
-------------------------------------------------

local ADDON_NAME, PSA = ...
PSA = PSA or _G.PetStatusAlert

local InitDB = PSA.InitDB
local isForever = PSA.IsForeverClient()
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

local statusLine
local moveToggleButton
local classResetDialog

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
    buttonHeight = 28,
    sliderWidth = 306,
    statusCardHeight = 60,
    statusCardGap = 6,
    statusActionHeight = 22,
}

local STYLE = {
    frameBg = { 0.025, 0.025, 0.025, 0.95 },
    frameBorder = { 0.30, 0.24, 0.14, 0.96 },
    panelBg = { 0.055, 0.055, 0.055, 0.78 },
    divider = { 1.00, 0.82, 0.00, 0.22 },
    text = { 0.92, 0.90, 0.84, 1.00 },
    muted = { 0.64, 0.63, 0.58, 0.95 },
    white = { 1.00, 1.00, 1.00, 1.00 },
    gold = { 1.00, 0.82, 0.00, 1.00 },
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

local function GetAddonVersion()
    local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
    return (getMeta and getMeta(ADDON_NAME, "Version")) or "?"
end

local function GetNativeProxyDescription()
    return LocaleText(
        "Open the full PetStatusAlert panel for alert rules, appearance, voice and language settings.",
        "打开完整的 PetStatusAlert 面板，可设置提醒规则、显示样式、语音和语言。",
        "開啟完整的 PetStatusAlert 面板，可設定提醒規則、顯示樣式、語音和語言。",
        "Откройте полную панель PetStatusAlert для настройки предупреждений, внешнего вида, озвучивания и языка."
    )
end

local function RefreshStaticText()
    TEXT.NAV_DISPLAY = LocaleText("Display", "显示样式", "顯示樣式", "Отображение")
    TEXT.NAV_VOICE = LocaleText("Voice", "语音提醒", "語音提醒", "Озвучивание")
    TEXT.NAV_GENERAL = LocaleText("General", "通用", "一般", "Общие")

    TEXT.CUSTOM_TEXT = LocaleText("Custom text", "自定义文字", "自訂文字", "Свой текст")
    TEXT.USE_DEFAULT = LocaleText("Default", "默认文字", "預設文字", "По умолчанию")
    TEXT.COLOR_HINT = LocaleText("Color: left-click to choose, right-click to reset.", "颜色：左键选择，右键恢复默认。", "顏色：左鍵選擇，右鍵恢復預設。", "Цвет: ЛКМ — выбрать, ПКМ — сбросить.")

    TEXT.DISPLAY_TITLE = LocaleText("On-screen alert appearance", "屏幕提醒外观", "螢幕提醒外觀", "Внешний вид предупреждения")
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

local function GetPlayerClassColor(classToken)
    classToken = classToken or PSA.GetPlayerClassFile()
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

local function CreateScrollablePage(parent, topInset)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(topInset or 0))
    scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -24, 0)
    scroll:EnableMouseWheel(true)
    parent.psaScroll = scroll

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

local function AddTooltip(frame, message)
    if not message or message == "" then return end
    frame:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(message, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

local function CreateSliderRow(parent, labelText, hintText, yOffset, minValue, maxValue, stepValue, value, valueText, onChanged)
    local label = CreateText(parent, "GameFontNormal", labelText, 14, STYLE.gold)
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", 18, yOffset)
    label:SetWidth(270)

    if hintText and hintText ~= "" then
        local hitArea = CreateFrame("Frame", nil, parent)
        hitArea:SetAllPoints(label)
        hitArea:EnableMouse(true)
        AddTooltip(hitArea, hintText)
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
    AddTooltip(slider, hintText)

    local minText = CreateText(parent, "GameFontDisableSmall", tostring(minValue), 10, STYLE.muted)
    minText:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -3)

    local currentText = CreateText(parent, "GameFontDisableSmall", valueText or tostring(value), 11, STYLE.gold, "CENTER")
    currentText:SetPoint("TOP", slider, "BOTTOM", 0, -3)
    currentText:SetWidth(170)

    local maxText = CreateText(parent, "GameFontDisableSmall", tostring(maxValue), 10, STYLE.muted, "RIGHT")
    maxText:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -3)

    -- 拖动过程中只重置防抖计时器；松手或停止 0.12s 后才真正应用，
    -- 避免每个 step 都重建告警布局并重启 LibCustomGlow 流光。
    local pendingCommit

    local function ApplyValue()
        if not onChanged or not slider:IsVisible() then
            return
        end
        local display = onChanged(slider:GetValue())
        if display ~= nil then
            currentText:SetText(display)
        end
    end

    local function CancelPendingCommit()
        if pendingCommit then
            pendingCommit:Cancel()
            pendingCommit = nil
        end
    end

    local function ScheduleCommit()
        CancelPendingCommit()
        if type(C_Timer) == "table" and type(C_Timer.NewTimer) == "function" then
            pendingCommit = C_Timer.NewTimer(0.12, function()
                pendingCommit = nil
                ApplyValue()
            end)
        else
            ApplyValue()
        end
    end

    slider:SetScript("OnValueChanged", function()
        ScheduleCommit()
    end)

    slider:SetScript("OnMouseUp", function()
        CancelPendingCommit()
        ApplyValue()
    end)
    slider:SetScript("OnHide", CancelPendingCommit)

    return slider, currentText
end

-------------------------------------------------
-- Color picker
-------------------------------------------------

local function RefreshConfiguredAlert(statusKey, classFile)
    if PSA.currentStatusForce then
        if PSA.currentStatusKey == statusKey and PSA.currentStatusClass == classFile then
            PreviewStatus(statusKey, classFile)
        end
    elseif PSA.GetPlayerClassFile() == classFile then
        RefreshPetStatusText()
    end
end

local function StopSettingsPreview()
    if PSA.currentStatusForce then
        PSA.HideStatus(true)
        RefreshPetStatusText()
    end
end

local function ConfirmClassReset(classFile, onReset)
    local title = UI.CLASS_RESET_TITLE:format(PSA.GetAlertClassLabel(classFile))
    local body = UI.CLASS_RESET_BODY
    if isForever and classFile == "HUNTER" then body = body .. "\n" .. UI.CLASS_RESET_KEEP_FOOD end
    local function Reset()
        StopSettingsPreview()
        if PSA.ResetClassSettings(classFile) then
            PSA.RefreshClassPetSettings(classFile)
            if PSA.GetPlayerClassFile() == classFile then
                RefreshPetStatusText()
                if PSA.RefreshPetCare then PSA.RefreshPetCare() end
            end
            if onReset then onReset() end
        end
    end
    local widgets = rawget(_G, "QFXWidgets")
    if widgets and type(widgets.Confirm) == "function" then
        classResetDialog = widgets:Confirm({ reuse = classResetDialog, title = title, text = body,
            acceptText = UI.RESET_ACTION, cancelText = UI.CANCEL, danger = true, onAccept = Reset })
        return classResetDialog
    end
    if StaticPopupDialogs and StaticPopup_Show then
        local key = "PETSTATUSALERT_RESET_CLASS"
        StaticPopupDialogs[key] = {
            text = "%s\n\n%s", button1 = UI.RESET_ACTION, button2 = UI.CANCEL,
            OnAccept = function(_, callback) callback() end, timeout = 0, hideOnEscape = true,
        }
        return StaticPopup_Show(key, title, body, Reset)
    end
end

PSA.ConfirmClassReset = ConfirmClassReset

local function UpdateColorSwatch(swatch, statusKey, classFile)
    if not swatch then
        return
    end
    local r, g, b, a = GetStatusColor(statusKey, classFile)
    swatch:SetColorTexture(r, g, b, a or 1)
end

local function CreateColorButton(parent)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(LAYOUT.statusActionHeight, LAYOUT.statusActionHeight)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    ApplyBackdrop(button, { 0.03, 0.03, 0.03, 0.95 }, STYLE.frameBorder)

    local swatch = button:CreateTexture(nil, "ARTWORK")
    swatch:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
    swatch:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
    button.swatch = swatch

    local hover = button:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints(swatch)
    hover:SetColorTexture(1, 1, 1, 0.18)

    return button
end

local function OpenStatusColorPicker(statusKey, classFile, swatch)
    if not ColorPickerFrame then
        return
    end

    local oldR, oldG, oldB, oldA = GetStatusColor(statusKey, classFile)

    local function ApplyPickedColor()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        SetStatusColor(statusKey, r, g, b, oldA or 1, classFile)
        UpdateColorSwatch(swatch, statusKey, classFile)
        RefreshConfiguredAlert(statusKey, classFile)
        if statusLine then
            statusLine:SetText(UI.COLOR_SAVED or "Color saved")
        end
    end

    local function CancelPickedColor()
        SetStatusColor(statusKey, oldR, oldG, oldB, oldA, classFile)
        UpdateColorSwatch(swatch, statusKey, classFile)
        RefreshConfiguredAlert(statusKey, classFile)
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

local function CreateStatusCard(parent, statusKey, classFile, yOffset, readOnly, embedded, onToggle)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetSize(LAYOUT.contentWidth, LAYOUT.statusCardHeight)
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
    if not embedded then ApplyBackdrop(card, STYLE.panelBg, STYLE.frameBorder) end

    local r, g, b = GetPlayerClassColor(classFile)
    if readOnly then
        r, g, b = ColorRGBA(STYLE.muted)
    end
    if not embedded then
        local accent = card:CreateTexture(nil, "ARTWORK")
        accent:SetPoint("TOPLEFT", card, "TOPLEFT", 0, -1)
        accent:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 0, 1)
        accent:SetWidth(3)
        accent:SetColorTexture(r, g, b, 0.72)
    end

    local check = CreateFrame("CheckButton", nil, card, "UICheckButtonTemplate")
    check:SetSize(20, 20)
    check:SetPoint("LEFT", card, "TOPLEFT", 12, -16)

    local title = CreateText(card, "GameFontNormal", STATUS_LABEL[statusKey] or statusKey, 14, STYLE.white)
    title:SetPoint("LEFT", check, "RIGHT", 4, 0)
    title:SetWidth(230)
    title:SetWordWrap(false)

    local defaultText = CreateText(card, "GameFontDisableSmall", (UI.DEFAULT_PREFIX or "Default:") .. " " .. GetDefaultMessage(statusKey), 11, STYLE.muted, "RIGHT")
    defaultText:SetPoint("RIGHT", card, "TOPRIGHT", -14, -16)
    defaultText:SetWidth(LAYOUT.contentWidth - 294)
    defaultText:SetWordWrap(false)

    local customLabel = CreateText(card, "GameFontDisableSmall", TEXT.CUSTOM_TEXT, 12, readOnly and STYLE.muted or STYLE.gold)
    customLabel:SetWidth(92)

    local editBox = CreateFrame("EditBox", nil, card, "InputBoxTemplate")
    editBox:SetHeight(24)
    editBox:SetPoint("LEFT", customLabel, "RIGHT", 4, 0)
    SkinEditBox(editBox)

    local colorButton = CreateColorButton(card)
    editBox:SetPoint("RIGHT", colorButton, "LEFT", -8, 0)

    local previewButton = CreateButton(card, UI.PREVIEW or "Preview", 70, LAYOUT.statusActionHeight)
    local defaultButton = CreateButton(card, TEXT.USE_DEFAULT, 92, LAYOUT.statusActionHeight)
    defaultButton:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -14, 6)
    previewButton:SetPoint("RIGHT", defaultButton, "LEFT", -7, 0)
    colorButton:SetPoint("RIGHT", previewButton, "LEFT", -7, 0)
    customLabel:SetPoint("LEFT", card, "BOTTOMLEFT", 16, 6 + LAYOUT.statusActionHeight / 2)

    if readOnly then
        check:SetChecked(PSA.GetDefaultStatusEnabled(statusKey))
        colorButton.swatch:SetColorTexture(PSA.GetDefaultStatusColor())
        for _, control in ipairs({ check, editBox, colorButton, previewButton, defaultButton }) do
            control:Disable()
            control:SetAlpha(0.5)
        end
        return
    end

    check:SetScript("OnClick", function(self)
        local enabled = self:GetChecked() and true or false
        SetStatusEnabled(statusKey, enabled, classFile)
        RefreshConfiguredAlert(statusKey, classFile)
        if onToggle then onToggle() end
        if statusLine then
            local formatText = enabled and UI.ALERT_ENABLED or UI.ALERT_DISABLED
            statusLine:SetText(string.format(formatText or "%s", STATUS_LABEL[statusKey] or statusKey))
        end
    end)

    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    editBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    editBox:SetScript("OnEditFocusGained", function(self)
        if self.HighlightText then
            self:HighlightText()
        end
    end)
    editBox:SetScript("OnEditFocusLost", function()
        RefreshConfiguredAlert(statusKey, classFile)
    end)
    editBox:SetScript("OnTextChanged", function(self, userInput)
        if not userInput then
            return
        end
        PSA.SetCustomMessage(statusKey, self:GetText(), classFile)
        if statusLine then
            statusLine:SetText(UI.SAVED or "Saved automatically")
        end
        if PSA.currentStatusKey == statusKey and PSA.currentStatusClass == classFile then
            RefreshConfiguredAlert(statusKey, classFile)
        end
    end)

    colorButton:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" then
            ResetStatusColor(statusKey, classFile)
            UpdateColorSwatch(self.swatch, statusKey, classFile)
            PreviewStatus(statusKey, classFile)
            if statusLine then
                statusLine:SetText(UI.COLOR_RESET or "Color reset")
            end
        else
            OpenStatusColorPicker(statusKey, classFile, self.swatch)
        end
    end)

    previewButton:SetScript("OnClick", function()
        PreviewStatus(statusKey, classFile)
        if statusLine then
            statusLine:SetText((STATUS_LABEL[statusKey] or statusKey) .. " - " .. GetDisplayMessage(statusKey, classFile))
        end
    end)

    defaultButton:SetScript("OnClick", function()
        PSA.SetCustomMessage(statusKey, "", classFile)
        editBox:SetText("")
        RefreshConfiguredAlert(statusKey, classFile)
        if statusLine then
            statusLine:SetText(UI.CLEARED or "Custom text cleared")
        end
    end)

    return function()
        check:SetChecked(IsStatusEnabled(statusKey, classFile))
        editBox:SetText(PSA.GetCustomMessage(statusKey, classFile))
        UpdateColorSwatch(colorButton.swatch, statusKey, classFile)
    end
end

local function CreateRuleCheck(parent, label, x, y, width, setValue)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(20, 20)
    check:SetPoint("LEFT", parent, "TOPLEFT", x, y)
    local text = CreateText(parent, "GameFontNormal", label, 12, setValue and STYLE.text or STYLE.muted)
    text:SetPoint("LEFT", check, "RIGHT", 5, 0)
    text:SetWidth(width)
    if setValue then
        if check.SetHitRectInsets then check:SetHitRectInsets(0, -width - 5, 0, 0) end
        check:SetScript("OnClick", function(self) setValue(not not self:GetChecked()) end)
    else
        check:Disable()
        check:SetAlpha(0.5)
    end
    return check
end

local function CreateRuleID(parent, label, y, getValue, setValue)
    local text = CreateText(parent, "GameFontNormal", label, 12, setValue and STYLE.text or STYLE.muted)
    text:SetPoint("LEFT", parent, "TOPLEFT", 16, y)
    text:SetWidth(LAYOUT.contentWidth - 136)
    local input = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    input:SetSize(96, 24)
    input:SetPoint("RIGHT", parent, "TOPRIGHT", -16, y)
    SkinEditBox(input)
    input:SetNumeric(true)
    input:SetMaxLetters(10)
    input:SetJustifyH("RIGHT")
    local function Refresh()
        input:SetText(tostring(getValue() or ""))
    end
    if setValue then
        input:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        input:SetScript("OnEditFocusLost", function(self)
            setValue(self:GetText())
            Refresh()
        end)
        input:SetScript("OnEscapePressed", function(self)
            Refresh()
            self:ClearFocus()
        end)
    else
        input:Disable()
        input:SetAlpha(0.5)
    end
    return input, Refresh
end

local function DrawWarlockRules(page, y, forever, readOnly)
    local key = PSA.WRONG_PET_STATUS_KEY
    local box = CreateFrame("Frame", nil, page, "BackdropTemplate")
    box:SetWidth(LAYOUT.contentWidth)
    box:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y)
    ApplyBackdrop(box, STYLE.panelBg, STYLE.frameBorder)
    local hint = CreateText(box, "GameFontDisableSmall", UI.WARLOCK_PET_RULES_HINT, 12, STYLE.muted)
    hint:SetPoint("TOPLEFT", box, "TOPLEFT", 16, -62)
    hint:SetWidth(LAYOUT.contentWidth - 32)
    hint:SetWordWrap(true)
    local spec = forever and 0 or PSA.WARLOCK_SPECS[1]
    local function RefreshHint()
        if readOnly then
            hint:SetText(UI.WARLOCK_PET_RULES_HINT)
        elseif not IsStatusEnabled(key, "WARLOCK") then
            hint:SetText(UI.WRONG_PET_OFF)
        else
            local blocked = PSA.GetWarlockBlockedPets(spec)
            hint:SetText(blocked and next(blocked) and UI.WARLOCK_PET_RULES_HINT or UI.WRONG_PET_NONE)
        end
    end
    if not forever and not readOnly and PSA.GetPlayerClassFile() == "WARLOCK" then
        local current = PSA.GetPlayerSpecId()
        if UI.WARLOCK_SPECS[current] then spec = current end
    end
    local petChecks, specButtons = {}, {}
    local refreshCard
    local sacrifice, idInput, refreshID
    local function Refresh()
        if refreshCard then refreshCard() end
        local blocked = not readOnly and PSA.GetWarlockBlockedPets(spec)
        for familyID, check in pairs(petChecks) do
            check:SetChecked(blocked and blocked[familyID] == true or false)
        end
        for specID, button in pairs(specButtons) do
            local selected = specID == spec
            button:SetButtonState(selected and "PUSHED" or "NORMAL", selected)
            button:SetAlpha(selected and 1 or 0.72)
        end
        if sacrifice then
            sacrifice:SetChecked(PSA.GetClassOption("warlockIgnoreSacrifice", readOnly))
            refreshID()
        end
        RefreshHint()
    end
    refreshCard = CreateStatusCard(box, key, "WARLOCK", 0, readOnly, true, RefreshHint)
    local specY = -62 - math.max(26, hint:GetStringHeight()) - 13
    local gridY = specY
    if not forever then
        local label = CreateText(box, "GameFontNormal", UI.WARLOCK_SPEC, 12, STYLE.text)
        label:SetPoint("LEFT", box, "TOPLEFT", 16, specY)
        local previous
        for _, specID in ipairs(PSA.WARLOCK_SPECS) do
            local button = CreateButton(box, UI.WARLOCK_SPECS[specID], 112, 22)
            if previous then
                button:SetPoint("LEFT", previous, "RIGHT", 6, 0)
            else
                button:SetPoint("LEFT", box, "TOPLEFT", 170, specY)
            end
            specButtons[specID], previous = button, button
            button:SetScript("OnClick", function()
                if idInput and idInput:HasFocus() then idInput:ClearFocus() end
                spec = specID
                Refresh()
            end)
        end
        gridY = specY - 26
    end

    local gridLabel = CreateText(box, "GameFontNormal", UI.WARLOCK_BLOCKED_PETS, 12, readOnly and STYLE.muted or STYLE.white)
    gridLabel:SetPoint("LEFT", box, "TOPLEFT", 16, gridY)
    local familyIDs = PSA.GetWarlockPetFamilies(forever)
    for index, familyID in ipairs(familyIDs) do
        local column, row = (index - 1) % 2, math.floor((index - 1) / 2)
        petChecks[familyID] = CreateRuleCheck(box, PSA.GetWarlockPetLabel(familyID), 16 + column * 308, gridY - 23 - row * 23, 274,
            not readOnly and function(blocked)
                PSA.SetWarlockBlockedPet(spec, familyID, blocked)
                PSA.RefreshClassPetSettings("WARLOCK")
                RefreshHint()
            end)
    end

    local endY = gridY - 23 * math.ceil(#familyIDs / 2) - 23
    if not forever then
        sacrifice = CreateRuleCheck(box, UI.WARLOCK_IGNORE_SACRIFICE, 16, endY, LAYOUT.contentWidth - 56,
            not readOnly and function(on)
                PSA.SetClassOption("warlockIgnoreSacrifice", on)
                PSA.RefreshClassPetSettings("WARLOCK")
            end)
        local advanced = CreateFrame("Frame", nil, box)
        advanced:SetSize(LAYOUT.contentWidth, 60)
        advanced:SetPoint("TOPLEFT", box, "TOPLEFT", 0, endY - 48)
        advanced:Hide()
        idInput, refreshID = CreateRuleID(advanced, UI.WARLOCK_SACRIFICE_ID, -13, function()
            return PSA.GetWarlockSacrificeID(spec, readOnly)
        end, not readOnly and function(value)
            PSA.SetWarlockSacrificeID(spec, value)
            PSA.RefreshClassPetSettings("WARLOCK")
        end)
        local idHint = CreateText(advanced, "GameFontDisableSmall", UI.WARLOCK_SACRIFICE_HINT, 11, STYLE.muted)
        idHint:SetPoint("TOPLEFT", advanced, "TOPLEFT", 16, -30)
        idHint:SetWidth(LAYOUT.contentWidth - 32)
        local button = CreateButton(box, "+ " .. UI.ADVANCED, 112, 22)
        button:SetPoint("LEFT", box, "TOPLEFT", 16, endY - 28)
        local collapsedHeight = -endY + 48
        box:SetHeight(collapsedHeight)
        button:SetScript("OnClick", function(self)
            local expanded = not advanced:IsShown()
            if not expanded and idInput:HasFocus() then idInput:ClearFocus() end
            advanced:SetShown(expanded)
            self:SetText((expanded and "- " or "+ ") .. UI.ADVANCED)
            box:SetHeight(collapsedHeight + (expanded and 60 or 0))
            if box.OnLayout then box.OnLayout() end
        end)
    else
        box:SetHeight(-endY)
    end
    return box, Refresh
end

local function DrawMageRules(page, y, readOnly)
    local height = 122
    local box = CreateSection(page, UI.MAGE_SUMMON_SETTINGS, UI.MAGE_SUMMON_HINT, y, height)
    local check = CreateRuleCheck(box, UI.MAGE_REQUIRE_SUMMON, 16, -66, LAYOUT.contentWidth - 56,
        not readOnly and function(on)
            PSA.SetClassOption("mageRequireSummon", on)
            PSA.RefreshClassPetSettings("MAGE")
            if PSA.RefreshOpenClassEligibility then PSA.RefreshOpenClassEligibility() end
        end)
    local _, refreshID = CreateRuleID(box, UI.MAGE_SUMMON_ID, -96, function()
        return PSA.GetClassOption("mageSummonID", readOnly)
    end, not readOnly and function(value)
        PSA.SetClassOption("mageSummonID", value)
        PSA.RefreshClassPetSettings("MAGE")
        if PSA.RefreshOpenClassEligibility then PSA.RefreshOpenClassEligibility() end
    end)
    return height, function()
        check:SetChecked(PSA.GetClassOption("mageRequireSummon", readOnly))
        refreshID()
    end
end

local function DrawFeedingRules(page, y, readOnly)
    local height = 154
    local hint = UI.FEED_SETTINGS_HINT
    local openMenu = not readOnly and PSA.OpenPetFoodSettingsMenu
    if not readOnly and not openMenu then hint = UI.FEED_REQUIRES_HUNTER end
    local box = CreateSection(page, UI.FEED_SETTINGS, hint, y, height)
    local check = CreateRuleCheck(box, UI.FEED_ENABLED, 16, -72, LAYOUT.contentWidth - 56,
        not readOnly and function(on)
            PSA.SetClassOption("petFeedEnabled", on)
            if PSA.RefreshPetCare then PSA.RefreshPetCare() end
        end)
    local unhappy = CreateRuleCheck(box, UI.PET_UNHAPPY_ENABLED, 16, -96, LAYOUT.contentWidth - 56,
        not readOnly and function(on)
            PSA.SetClassOption("petUnhappyAlertEnabled", on)
            if PSA.RefreshPetCare then PSA.RefreshPetCare() end
        end)
    local label = CreateText(box, "GameFontNormal", UI.FEED_CHOOSE_TITLE, 12, openMenu and STYLE.text or STYLE.muted)
    label:SetPoint("LEFT", box, "TOPLEFT", 16, -125)
    label:SetWidth(LAYOUT.contentWidth - 302)
    local button = CreateButton(box, UI.FEED_CHOOSE_AUTO, 260, 22)
    button:SetPoint("RIGHT", box, "TOPRIGHT", -16, -125)
    local function Refresh()
        check:SetChecked(PSA.GetClassOption("petFeedEnabled", readOnly))
        unhappy:SetChecked(PSA.GetClassOption("petUnhappyAlertEnabled", readOnly))
        button:SetText(openMenu and PSA.GetPetFeedFoodLabel() or UI.FEED_CHOOSE_AUTO)
    end
    if openMenu then
        local menu
        button:SetScript("OnClick", function(self)
            if InCombatLockdown() then
                statusLine:SetText(UI.SETTING_OUT_OF_COMBAT)
            else
                menu = openMenu(self, Refresh)
            end
        end)
        button:SetScript("OnHide", function()
            if menu then menu:Close(); menu = nil end
        end)
    else
        button:Disable()
        button:SetAlpha(0.5)
    end
    return height, Refresh
end

local function DrawAlertsPage(parent, classFile, forever)
    local page, finish = CreateScrollablePage(parent)
    local readOnly = forever ~= isForever
    local statuses = PSA.GetClassAlertStatuses(classFile, forever)
    local description = PSA.GetClassSupportNote(classFile, forever)
    if statuses then
        description = description .. "\n" .. (readOnly and UI.OTHER_CLIENT_SETTINGS or TEXT.COLOR_HINT)
    end
    local title = statuses and PSA.GetAlertClassLabel(classFile, forever) or PSA.GetAlertClassLabel(classFile)
    local _, desc = CreatePageHeader(page, title, description)
    local startY = 36 + desc:GetStringHeight()
    local updateEligibility
    if statuses and not readOnly and (forever or classFile == "MAGE") and PSA.GetPlayerClassFile() == classFile then
        local eligibility = CreateText(page, "GameFontDisableSmall", "", 12, STYLE.text)
        eligibility:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -4)
        eligibility:SetWidth(LAYOUT.contentWidth - 10)
        updateEligibility = function()
            local eligible = PSA.GetCurrentPetAlertEligibility(classFile)
            eligibility:SetText(eligible == nil and "" or (eligible and UI.ELIGIBILITY_MET or UI.ELIGIBILITY_UNMET))
        end
        startY = startY + 20
    end

    local refreshes = {}
    local step = LAYOUT.statusCardHeight + LAYOUT.statusCardGap
    local height = startY
    for _, statusKey in ipairs(statuses or {}) do
        if statusKey ~= PSA.WRONG_PET_STATUS_KEY then
            local refresh = CreateStatusCard(page, statusKey, classFile, -height, readOnly)
            if refresh then refreshes[#refreshes + 1] = refresh end
            height = height + step
        end
    end

    local rulesHeight, refreshRules, rulesBox
    if classFile == "WARLOCK" then
        rulesBox, refreshRules = DrawWarlockRules(page, -height, forever, readOnly)
    elseif classFile == "MAGE" then
        rulesHeight, refreshRules = DrawMageRules(page, -height, readOnly)
    elseif forever and classFile == "HUNTER" then
        rulesHeight, refreshRules = DrawFeedingRules(page, -height, readOnly)
    end
    local function Refresh()
        for _, refresh in ipairs(refreshes) do
            refresh()
        end
        if refreshRules then refreshRules() end
        if updateEligibility then updateEligibility() end
    end
    local resetButton
    if statuses and not readOnly then
        resetButton = CreateButton(page, UI.CLASS_RESET, 160, 24)
        resetButton:SetScript("OnClick", function()
            ConfirmClassReset(classFile, function()
                Refresh()
                if statusLine then statusLine:SetText(UI.CLASS_RESET_DONE) end
            end)
        end)
    end
    local function LayoutPage()
        local bottom = height + (rulesBox and rulesBox:GetHeight() or rulesHeight or 0)
        if resetButton then
            resetButton:ClearAllPoints()
            resetButton:SetPoint("TOPRIGHT", page, "TOPRIGHT", -2, -bottom - 10)
            bottom = bottom + 34
        end
        finish(bottom + 12)
    end
    if rulesBox then rulesBox.OnLayout = LayoutPage end
    LayoutPage()
    return Refresh, updateEligibility
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
    local page, finish = CreateScrollablePage(parent, 63)
    local title = CreateText(parent, "GameFontNormal", TEXT.DISPLAY_TITLE, 18, STYLE.white)
    title:SetPoint("TOPLEFT")

    local previewButton = CreateButton(parent, UI.STOP_PREVIEW, 96, 26)
    previewButton:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -28)
    local function RefreshPreviewButton()
        previewButton:SetText(PSA.IsDisplayPreviewActive() and UI.STOP_PREVIEW or UI.PREVIEW)
    end
    RefreshPreviewButton()
    previewButton:SetScript("OnClick", function()
        if PSA.IsDisplayPreviewActive() then StopSettingsPreview() else PSA.PreviewDisplay() end
        RefreshPreviewButton()
        if statusLine then
            statusLine:SetText(PSA.IsDisplayPreviewActive() and UI.PREVIEW_SAMPLE or UI.FOOTER)
        end
    end)

    moveToggleButton = CreateButton(parent, GetMoveButtonText(), 112, 26)
    moveToggleButton:SetPoint("LEFT", previewButton, "RIGHT", 10, 0)
    AddTooltip(moveToggleButton, UI.MOVE_HINT)
    moveToggleButton:SetScript("OnClick", function()
        InitDB()
        local locked = not PetStatusAlertDB.alertLocked
        SetAlertPositionLocked(locked)
        moveToggleButton:SetText(GetMoveButtonText())
        AutoFitButton(moveToggleButton, 112)
        if not locked then
            PSA.PreviewDisplay()
            RefreshPreviewButton()
        end
        if statusLine then
            statusLine:SetText(locked and (UI.LOCKED_STATUS or TEXT.LOCK) or (UI.UNLOCKED_STATUS or TEXT.UNLOCK))
        end
    end)

    local resetButton = CreateButton(parent, TEXT.RESET_POSITION, 130, 26)
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
        PSA.PreviewDisplay()
        RefreshPreviewButton()
        if statusLine then
            statusLine:SetText(TEXT.POSITION_RESET_DONE)
        end
    end)

    local y = 0

    -------------------------------------------------
    -- Icon + text presentation
    -------------------------------------------------
    local presentationBox = CreateSection(page, TEXT.SECTION_PRESENTATION, nil, y, 183)

    local modeLabel = CreateText(presentationBox, "GameFontNormal", UI.ANIMATION_ICON_MODE or "Icon mode", 14, STYLE.gold)
    modeLabel:SetPoint("TOPLEFT", presentationBox, "TOPLEFT", 18, -47)

    local modeButtons = {}
    local previous
    for _, mode in ipairs({ "text", "icon", "both" }) do
        local button = CreateButton(presentationBox, GetIconModeLabel(mode), 112, 28)
        AddTooltip(button, UI.ANIMATION_ICON_MODE_HINT)
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
        -88,
        24,
        96,
        1,
        GetAlertIconSize and GetAlertIconSize() or DEFAULT_ALERT_ICON_SIZE,
        string.format(UI.ANIMATION_ICON_SIZE_VALUE or "Icon size: %s", tostring(GetAlertIconSize and GetAlertIconSize() or DEFAULT_ALERT_ICON_SIZE)),
        function(value)
            local newValue = SetAlertIconSize(value)
            return string.format(UI.ANIMATION_ICON_SIZE_VALUE or "Icon size: %s", tostring(newValue))
        end
    )

    CreateSliderRow(
        presentationBox,
        TEXT.ICON_GAP,
        TEXT.ICON_GAP_HINT,
        -134,
        0,
        40,
        1,
        GetAlertIconGap and GetAlertIconGap() or DEFAULT_ALERT_ICON_GAP,
        string.format(TEXT.ICON_GAP_VALUE, tostring(GetAlertIconGap and GetAlertIconGap() or DEFAULT_ALERT_ICON_GAP)),
        function(value)
            local newValue = SetAlertIconGap and SetAlertIconGap(value) or DEFAULT_ALERT_ICON_GAP
            return string.format(TEXT.ICON_GAP_VALUE, tostring(newValue))
        end
    )

    y = y - 193

    -------------------------------------------------
    -- Text and movement
    -------------------------------------------------
    local motionBox = CreateSection(page, TEXT.SECTION_MOTION, nil, y, 190)

    CreateSliderRow(
        motionBox,
        UI.ANIMATION_FONT_SIZE or "Alert font size",
        UI.ANIMATION_FONT_SIZE_HINT or "Default: 28.",
        -45,
        12,
        72,
        1,
        GetAlertFontSize and GetAlertFontSize() or DEFAULT_ALERT_FONT_SIZE,
        string.format(UI.ANIMATION_FONT_SIZE_VALUE or "Font size: %s", tostring(GetAlertFontSize and GetAlertFontSize() or DEFAULT_ALERT_FONT_SIZE)),
        function(value)
            local newValue = SetAlertFontSize(value)
            return string.format(UI.ANIMATION_FONT_SIZE_VALUE or "Font size: %s", tostring(newValue))
        end
    )

    CreateSliderRow(
        motionBox,
        UI.ANIMATION_AMPLITUDE or "Up/down float amplitude",
        UI.ANIMATION_AMPLITUDE_HINT or "Default: 8.",
        -91,
        0,
        24,
        1,
        GetAlertFloatAmplitude and GetAlertFloatAmplitude() or DEFAULT_ALERT_FLOAT_AMPLITUDE,
        string.format(UI.ANIMATION_AMPLITUDE_VALUE or "Amplitude: %s", tostring(GetAlertFloatAmplitude and GetAlertFloatAmplitude() or DEFAULT_ALERT_FLOAT_AMPLITUDE)),
        function(value)
            local newValue = SetAlertFloatAmplitude(value)
            return string.format(UI.ANIMATION_AMPLITUDE_VALUE or "Amplitude: %s", tostring(newValue))
        end
    )

    CreateSliderRow(
        motionBox,
        UI.ANIMATION_SPEED or "Up/down float speed",
        UI.ANIMATION_SPEED_HINT or "1.0x = default.",
        -137,
        0.1,
        3,
        0.1,
        GetAlertFloatSpeed and GetAlertFloatSpeed() or DEFAULT_ALERT_FLOAT_SPEED,
        string.format(UI.ANIMATION_SPEED_VALUE or "Speed: %sx", FormatOneDecimal(GetAlertFloatSpeed and GetAlertFloatSpeed() or DEFAULT_ALERT_FLOAT_SPEED)),
        function(value)
            local newValue = SetAlertFloatSpeed(value)
            return string.format(UI.ANIMATION_SPEED_VALUE or "Speed: %sx", FormatOneDecimal(newValue))
        end
    )

    y = y - 200

    -------------------------------------------------
    -- Effects
    -------------------------------------------------
    local effectsBox = CreateSection(page, TEXT.SECTION_EFFECTS, nil, y, 134)

    local glowCheck = CreateFrame("CheckButton", nil, effectsBox, "UICheckButtonTemplate")
    glowCheck:SetSize(22, 22)
    glowCheck:SetPoint("TOPLEFT", effectsBox, "TOPLEFT", 14, -41)
    AddTooltip(glowCheck, UI.ANIMATION_GLOW_ENABLE_HINT)
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
        if statusLine then
            statusLine:SetText(enabled and (UI.ANIMATION_GLOW_ON or "Pixel glow enabled") or (UI.ANIMATION_GLOW_OFF or "Pixel glow disabled"))
        end
    end)

    CreateSliderRow(
        effectsBox,
        UI.ANIMATION_GLOW_SPEED or "Pixel glow speed",
        UI.ANIMATION_GLOW_SPEED_HINT or "1.0x = default.",
        -81,
        0.2,
        3,
        0.1,
        GetAlertGlowSpeed and GetAlertGlowSpeed() or DEFAULT_ALERT_GLOW_SPEED,
        string.format(UI.ANIMATION_GLOW_SPEED_VALUE or "Glow speed: %sx", FormatOneDecimal(GetAlertGlowSpeed and GetAlertGlowSpeed() or DEFAULT_ALERT_GLOW_SPEED)),
        function(value)
            local newValue = SetAlertGlowSpeed(value)
            return string.format(UI.ANIMATION_GLOW_SPEED_VALUE or "Glow speed: %sx", FormatOneDecimal(newValue))
        end
    )

    finish(math.abs(y) + 146)
end

-------------------------------------------------
-- Voice page
-------------------------------------------------

local function DrawVoicePage(parent)
    local page, finish = CreateScrollablePage(parent)
    CreatePageHeader(page, TEXT.VOICE_TITLE, UI.TTS_BEHAVIOR_HINT)

    local voiceBox = CreateSection(page, UI.COMBAT_TTS or TEXT.VOICE_TITLE, nil, -70, 222)

    local check = CreateFrame("CheckButton", nil, voiceBox, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check:SetPoint("TOPLEFT", voiceBox, "TOPLEFT", 14, -49)
    check:SetChecked(PetStatusAlertDB.combatTTSEnabled == true)

    local label = CreateText(voiceBox, "GameFontNormal", UI.COMBAT_TTS or TEXT.VOICE_TITLE, 14, STYLE.gold)
    label:SetPoint("LEFT", check, "RIGHT", 3, 0)

    local listen = CreateButton(voiceBox, UI.TTS_SAMPLE, 104, 24)
    listen:SetPoint("RIGHT", voiceBox, "TOPRIGHT", -20, -61)
    listen:SetScript("OnClick", function()
        if not PSA.PlayCombatTTSSample() and statusLine then statusLine:SetText(UI.TTS_UNAVAILABLE) end
    end)

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
        if statusLine then
            statusLine:SetText(PetStatusAlertDB.combatTTSEnabled and (UI.COMBAT_TTS_ON or "Enabled") or (UI.COMBAT_TTS_OFF or "Disabled"))
        end
    end)

    CreateSliderRow(
        voiceBox,
        UI.COMBAT_TTS_RATE or "TTS speech speed",
        UI.COMBAT_TTS_RATE_HINT or "0 = WoW default speed.",
        -94,
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

    local repeatButton = CreateButton(voiceBox, UI.TTS_REPEAT, 118, 24)
    repeatButton:SetPoint("TOPRIGHT", voiceBox, "TOPRIGHT", -24, -140)
    local onceButton = CreateButton(voiceBox, UI.TTS_ONCE, 118, 24)
    onceButton:SetPoint("RIGHT", repeatButton, "LEFT", -8, 0)
    local intervalRow = CreateFrame("Frame", nil, voiceBox)
    intervalRow:SetSize(LAYOUT.contentWidth, 42)
    intervalRow:SetPoint("TOPLEFT", voiceBox, "TOPLEFT", 0, -181)
    local function FormatInterval(value) return UI.TTS_INTERVAL_VALUE:format(value) end
    local interval = PSA.GetCombatTTSRepeatInterval()
    CreateSliderRow(intervalRow, UI.TTS_INTERVAL, nil, -2, 2, 15, 1, interval,
        FormatInterval(interval), function(value) return FormatInterval(PSA.SetCombatTTSInterval(value)) end)
    local function RefreshMode()
        local repeatOn = PSA.GetCombatTTSInterval() > 0
        SetIconModeButtonState(onceButton, not repeatOn)
        SetIconModeButtonState(repeatButton, repeatOn)
        intervalRow:SetShown(repeatOn)
        voiceBox:SetHeight(repeatOn and 232 or 178)
        finish(82 + voiceBox:GetHeight())
    end
    onceButton:SetScript("OnClick", function()
        PSA.SetCombatTTSInterval(0)
        RefreshMode()
    end)
    repeatButton:SetScript("OnClick", function()
        PSA.SetCombatTTSInterval(PSA.GetCombatTTSRepeatInterval())
        RefreshMode()
    end)
    RefreshMode()
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

    local version = GetAddonVersion()

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

local function DrawForeverPage(parent)
    local page, finish = CreateScrollablePage(parent)
    CreatePageHeader(page, UI.FOREVER_CLIENT, "")
    local hint = UI.AMMO_WEAPON_HINT .. "\n" .. UI.AMMO_THRESHOLD_HINT
    if not isForever then
        hint = UI.OTHER_CLIENT_SETTINGS .. "\n" .. hint
    end
    local section = CreateSection(page, UI.AMMO_SETTINGS, hint, -52, 124)
    section:SetHeight(math.max(124, 90 + section.sectionDesc:GetStringHeight()))

    local label = CreateText(section, "GameFontNormal", UI.AMMO_THRESHOLD, 14, STYLE.gold)
    label:SetPoint("BOTTOMLEFT", section, "BOTTOMLEFT", 18, 24)
    label:SetWidth(LAYOUT.contentWidth - 130)

    local input = CreateFrame("EditBox", nil, section, "InputBoxTemplate")
    input:SetSize(84, 26)
    input:SetPoint("BOTTOMRIGHT", section, "BOTTOMRIGHT", -24, 17)
    SkinEditBox(input)
    input:SetNumeric(true)
    input:SetJustifyH("RIGHT")
    input:SetText(tostring(isForever and PSA.GetAmmoThreshold() or PSA.DEFAULT_AMMO_THRESHOLD))
    finish(66 + section:GetHeight())
    if not isForever then
        input:Disable()
        input:SetAlpha(0.5)
        return
    end
    input:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    input:SetScript("OnEditFocusLost", function(self)
        self:SetText(tostring(PSA.SetAmmoThreshold(self:GetText())))
    end)
    input:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(PSA.GetAmmoThreshold()))
        self:ClearFocus()
    end)
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

local function CreateNavButton(parent, labelText, indent)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(LAYOUT.navWidth - 8, 34)
    indent = indent or 0

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
    text:SetPoint("LEFT", button, "LEFT", 18 + indent, 0)
    text:SetWidth(LAYOUT.navWidth - 26 - indent)
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
    frame:SetScript("OnHide", StopSettingsPreview)
    ApplyBackdrop(frame, STYLE.frameBg, STYLE.frameBorder)

    local title = CreateText(frame, "GameFontNormalLarge", UI.TITLE, 21, STYLE.gold, "CENTER")
    title:SetPoint("TOP", frame, "TOP", 0, -17)
    title:SetWidth(520)
    frame.psaTitle = title

    local subtitle = CreateText(frame, "GameFontDisableSmall", UI.SUBTITLE or "", 11, STYLE.muted, "CENTER")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -5)
    subtitle:SetWidth(610)
    frame.psaSubtitle = subtitle

    local version = GetAddonVersion()
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

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 14, -2)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 56)

    frame.activePage = "general"
    frame.viewForever = isForever
    local classes = PSA.GetAlertClasses(false)
    local classesExpanded = false
    frame.navButtons = {}
    local alertPages = {}
    local scrollOffsets = {}
    local navLabels = {}
    local navOrder = {}

    local clientTabs = CreateFrame("Frame", nil, content)
    clientTabs:SetPoint("TOPLEFT")
    clientTabs:SetPoint("TOPRIGHT")
    clientTabs:SetHeight(36)
    local function GetClientTabLabel(forever)
        local label = PSA.GetAlertClientName(forever)
        return forever == isForever and label or (label .. " · " .. UI.READ_ONLY_TAB)
    end
    frame.clientButtons = {
        retail = CreateButton(clientTabs, GetClientTabLabel(false), 96),
        forever = CreateButton(clientTabs, GetClientTabLabel(true), 96),
    }
    frame.clientButtons.retail:SetPoint("TOPLEFT")
    frame.clientButtons.forever:SetPoint("LEFT", frame.clientButtons.retail, "RIGHT", 8, 0)

    local function RefreshClientTabs(classPage)
        clientTabs:SetShown(classPage)
        for key, button in pairs(frame.clientButtons) do
            local forever = key == "forever"
            local selected = forever == frame.viewForever
            SetIconModeButtonState(button, selected)
            button:SetButtonState(selected and "PUSHED" or "NORMAL", selected)
            if forever ~= isForever then
                button:GetFontString():SetTextColor(ColorRGBA(STYLE.muted))
            end
        end
    end

    local function RefreshNavButtons()
        local navY = -2
        for _, key in ipairs(navOrder) do
            local button = frame.navButtons[key]
            local shown = classesExpanded or not button.isClass
            button:SetShown(shown)
            if shown then
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 0, navY)
                navY = navY - button:GetHeight()
            end
            local active = key == frame.activePage
            if key == "classes" and not classesExpanded then
                active = frame.navButtons[frame.activePage].isClass
            end
            SetNavButtonActive(button, active)
        end
    end

    local function DrawPage()
        local key = frame.activePage
        local classPage = frame.navButtons[key].isClass == true
        local cacheKey = classPage and (GetActiveLocale() .. ":" .. key .. ":" .. tostring(frame.viewForever))
        local pageHolder = cacheKey and alertPages[cacheKey]
        if frame.currentPage and frame.currentPage ~= pageHolder then
            local oldScroll = frame.currentPage.psaScroll
            if oldScroll and oldScroll.GetVerticalScroll then
                scrollOffsets[frame.currentPage.psaPageKey] = oldScroll:GetVerticalScroll()
            end
            frame.currentPage:Hide()
            if not frame.currentPage.refreshAlerts then
                frame.currentPage:SetParent(nil)
            end
        end

        if not pageHolder then
            pageHolder = CreateFrame("Frame", nil, content)
            pageHolder.psaPageKey = cacheKey or key
            pageHolder:SetPoint("TOPLEFT", content, "TOPLEFT", 0, classPage and -36 or 0)
            pageHolder:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT")
            if key == "display" then
                DrawDisplayPage(pageHolder)
            elseif key == "voice" then
                DrawVoicePage(pageHolder)
            elseif key == "general" then
                DrawGeneralPage(pageHolder)
            elseif key == "forever" then
                DrawForeverPage(pageHolder)
            else
                pageHolder.refreshAlerts, pageHolder.refreshEligibility = DrawAlertsPage(pageHolder, key, frame.viewForever)
                alertPages[cacheKey] = pageHolder
            end
        end
        if pageHolder.refreshAlerts then
            pageHolder.refreshAlerts()
        end
        frame.currentPage = pageHolder
        pageHolder:Show()
        local scroll = pageHolder.psaScroll
        local offset = scrollOffsets[pageHolder.psaPageKey]
        if offset and scroll and scroll.GetVerticalScrollRange then
            scroll:SetVerticalScroll(math.min(offset, scroll:GetVerticalScrollRange() or 0))
        end
        RefreshClientTabs(classPage)
        RefreshNavButtons()
    end

    for key, button in pairs(frame.clientButtons) do
        local forever = key == "forever"
        button:SetScript("OnClick", function()
            if frame.viewForever ~= forever then
                StopSettingsPreview()
                frame.viewForever = forever
                statusLine:SetText(UI.FOOTER or "/psa")
                DrawPage()
            end
        end)
    end

    local function AddNav(key, getLabel, classPage)
        local button = CreateNavButton(leftPanel, getLabel(), classPage and 14)
        button.isClass = classPage
        navOrder[#navOrder + 1] = key
        frame.navButtons[key] = button
        navLabels[button.text] = getLabel
        button:SetScript("OnClick", function()
            if frame.activePage ~= key then
                StopSettingsPreview()
                frame.activePage = key
                frame.viewForever = isForever
                statusLine:SetText(UI.FOOTER or "/psa")
                DrawPage()
            end
        end)
        return button
    end

    local function ClassGroupLabel()
        return (classesExpanded and "- " or "+ ") .. UI.CLASS_SETTINGS
    end
    local classGroup = AddNav("classes", ClassGroupLabel)
    classGroup:SetScript("OnClick", function()
        classesExpanded = not classesExpanded
        classGroup.text:SetText(ClassGroupLabel())
        RefreshNavButtons()
    end)
    for _, classFile in ipairs(classes) do
        AddNav(classFile, function() return PSA.GetAlertClassLabel(classFile) end, true)
    end
    local ammoButton = AddNav("forever", function() return UI.AMMO_SETTINGS end)
    ammoButton:SetAlpha(isForever and 1 or 0.6)
    AddNav("display", function() return TEXT.NAV_DISPLAY end)
    AddNav("voice", function() return TEXT.NAV_VOICE end)
    AddNav("general", function() return TEXT.NAV_GENERAL end)

    frame.RefreshNavLabels = function()
        for label, getLabel in pairs(navLabels) do
            label:SetText(getLabel())
        end
        for key, button in pairs(frame.clientButtons) do
            button:SetText(GetClientTabLabel(key == "forever"))
            AutoFitButton(button, 96)
        end
    end

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

    return frame
end

function PSA.RefreshOpenClassEligibility()
    local page = optionsFrame and optionsFrame:IsShown() and optionsFrame.currentPage
    if page and page.refreshEligibility then page.refreshEligibility() end
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
    if frame.RefreshNavLabels then
        frame.RefreshNavLabels()
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

    local desc = CreateText(panel, "GameFontHighlightSmall", GetNativeProxyDescription(), 13, STYLE.text)
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    desc:SetWidth(640)
    panel.psaProxyDesc = desc

    local openButton = CreateButton(panel, TEXT.OPEN_LARGE_PANEL, 150, 28)
    openButton:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -16)
    openButton:SetScript("OnClick", function()
        OpenOptionsFrame()
    end)
    panel.psaProxyOpenButton = openButton
    panel:Hide()

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
        panel.psaProxyDesc:SetText(GetNativeProxyDescription())
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

    if PSA.IsDisplayPreviewActive() then
        PSA.PreviewDisplay()
    elseif PSA.currentStatusKey then
        ShowStatus(PSA.currentStatusKey, PSA.currentStatusForce, PSA.currentStatusClass)
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
PSA.RefreshConfiguredAlert = RefreshConfiguredAlert
PSA.StopSettingsPreview = StopSettingsPreview
PSA.RefreshLocaleState = RefreshAllLocaleState
PSA.RefreshOptionsFrameLocale = RefreshOptionsFrameLocale
PSA.RegisterNativeOptionsCategory = RegisterNativeOptionsCategory
PSA.OpenNativeOptionsFrame = OpenNativeOptionsFrame
PSA.ApplyManagerLanguage = function(value) ApplyLanguageSelection(value) end
PSA.HideStandaloneConfig = function() if optionsFrame then optionsFrame:Hide() end end
