-------------------------------------------------
-- PetStatusAlert localization and saved text settings
-------------------------------------------------

local ADDON_NAME, PSA = ...
PSA = PSA or _G.PetStatusAlert

local InitDB = PSA.InitDB
local Trim = PSA.Trim

local LOCALIZED_MESSAGES = {
    enUS = {
        ASSIST = "My pet is currently: Assist",
        PASSIVE = "My pet is currently: Passive",
        DEFENSIVE = "My pet is currently: Defensive",
        UNKNOWN = "My pet status could not be identified right now",
        NO_PET = "My pet is not summoned",
        PET_DEAD = "My pet is dead",
    },
    zhCN = {
        ASSIST = "我的宠物现在是：协助状态",
        PASSIVE = "我的宠物现在是：被动状态",
        DEFENSIVE = "我的宠物现在是：防御状态",
        UNKNOWN = "我的宠物状态暂时无法识别",
        NO_PET = "我的宠物不存在",
        PET_DEAD = "我的宠物已死亡",
    },
    zhTW = {
        ASSIST = "我的寵物現在是：協助狀態",
        PASSIVE = "我的寵物現在是：被動狀態",
        DEFENSIVE = "我的寵物現在是：防禦狀態",
        UNKNOWN = "我的寵物狀態暫時無法識別",
        NO_PET = "我的寵物不存在",
        PET_DEAD = "我的寵物已死亡",
    },
    ruRU = {
        ASSIST = "Режим питомца: Помощь",
        PASSIVE = "Режим питомца: Пассивный",
        DEFENSIVE = "Режим питомца: Защита",
        UNKNOWN = "Статус питомца сейчас невозможно определить",
        NO_PET = "Питомец не призван",
        PET_DEAD = "Питомец мертв",
    },
}

local UI_LOCALE = {
    enUS = {
        TITLE = "PetStatusAlert",
        SUBTITLE = "Custom pet warning text. Leave blank to use the default text for your client language.",
        CARD_TITLE = "Warning Text Overrides",
        CARD_DESC = "Custom text has priority. Empty input = use localized default text.",
        PASSIVE = "Passive Pet",
        DEFENSIVE = "Defensive Pet",
        NO_PET = "No Pet",
        PET_DEAD = "Pet Dead",
        UNKNOWN = "Unknown Status",
        ENABLE_ALERT = "Enable this alert",
        ALERT_ENABLED = "%s alert enabled",
        ALERT_DISABLED = "%s alert disabled",
        DEFAULT_PREFIX = "Default:",
        INPUT_LABEL = "Custom text",
        COLOR = "Color",
        RESET_COLOR = "Default color",
        COLOR_SAVED = "Color saved",
        COLOR_RESET = "Color reset",
        PREVIEW = "Preview",
        CLEAR = "Clear",
        RESET_ALL = "Reset All",
        CLOSE = "Close",
        FOOTER = "Options > AddOns > PetStatusAlert, or slash: /psa",
        SAVED = "Saved automatically",
        CLEARED = "Custom text cleared",
        RESET_DONE = "All custom text has been reset",
        SUPPORT = "Supported: Hunter, Warlock, Unholy Death Knight, Frost Mage with Summon Water Elemental talent",
        LOCK_ALERT_POSITION = "Lock alert position",
        UNLOCK_HINT = "Unchecked: preview text, then drag the alert text to move it.",
        LOCKED_STATUS = "Alert position locked",
        UNLOCKED_STATUS = "Alert position unlocked. Drag the alert text to move it.",
        COMBAT_TTS = "Combat TTS voice reminder",
        COMBAT_TTS_HINT = "When enabled, the visible alert text is spoken every 3 seconds during combat.",
        COMBAT_TTS_RATE = "TTS speech speed",
        COMBAT_TTS_RATE_HINT = "Drag to adjust the voice speed. Default: 3. 0 = WoW default speed.",
        COMBAT_TTS_RATE_VALUE = "Speed: %s",
        COMBAT_TTS_ON = "Combat TTS reminder enabled",
        COMBAT_TTS_OFF = "Combat TTS reminder disabled",
        ANIMATION_TITLE = "Animation Settings",
        ANIMATION_FONT_SIZE = "Alert font size",
        ANIMATION_FONT_SIZE_HINT = "Adjust the on-screen alert text size. Default: 28.",
        ANIMATION_FONT_SIZE_VALUE = "Font size: %s",
        ANIMATION_FONT_SIZE_CHANGED = "Alert font size set to: %s",
        ANIMATION_AMPLITUDE = "Up/down float amplitude",
        ANIMATION_AMPLITUDE_HINT = "Adjust the vertical floating range of the on-screen alert text. Default: 8.",
        ANIMATION_AMPLITUDE_VALUE = "Amplitude: %s",
        ANIMATION_AMPLITUDE_CHANGED = "Animation amplitude set to: %s",
        ANIMATION_SPEED = "Up/down float speed",
        ANIMATION_SPEED_HINT = "Adjust the vertical floating speed. 1.0x = old default speed.",
        ANIMATION_SPEED_VALUE = "Speed: %sx",
        ANIMATION_SPEED_CHANGED = "Animation speed set to: %sx",
        ANIMATION_GLOW_ENABLE = "Pixel glow",
        ANIMATION_GLOW_ENABLE_HINT = "Uses the embedded LibCustomGlow-1.0 Pixel Glow around the alert text.",
        ANIMATION_GLOW_ON = "Pixel glow enabled",
        ANIMATION_GLOW_OFF = "Pixel glow disabled",
        ANIMATION_GLOW_SPEED = "Pixel glow speed",
        ANIMATION_GLOW_SPEED_HINT = "Adjust the flowing speed of the pixel glow. 1.0x = default speed.",
        ANIMATION_GLOW_SPEED_VALUE = "Glow speed: %sx",
        ANIMATION_GLOW_SPEED_CHANGED = "Pixel glow speed set to: %sx",
        LANGUAGE = "Language",
        LANGUAGE_DESC = "Default follows your WoW client language. Manual selection immediately updates the interface and default alert text.",
        LANGUAGE_CURRENT = "Current language mode:",
        LANGUAGE_AUTO = "Follow Client",
        LANGUAGE_ENUS = "English",
        LANGUAGE_ZHCN = "Simplified Chinese",
        LANGUAGE_ZHTW = "Traditional Chinese",
        LANGUAGE_RURU = "Russian",
        LANGUAGE_CHANGED = "Language switched to: %s",
        AUTHOR = "Author: zhufei1000",
        TRANSLATION_RURU = "Russian translation: Hubbotu",
    },
    zhCN = {
        TITLE = "PetStatusAlert 宠物状态提醒",
        SUBTITLE = "自定义不同宠物状态下的屏幕提示文字。留空时，自动使用当前客户端语言的默认文字。",
        CARD_TITLE = "提示文字自定义",
        CARD_DESC = "自定义文字优先显示；输入框留空 = 使用本地化默认文字。",
        PASSIVE = "被动状态",
        DEFENSIVE = "防御状态",
        NO_PET = "未召唤宠物",
        PET_DEAD = "宠物死亡",
        UNKNOWN = "无法识别状态",
        ENABLE_ALERT = "显示此类型提醒",
        ALERT_ENABLED = "%s提醒已开启",
        ALERT_DISABLED = "%s提醒已关闭",
        DEFAULT_PREFIX = "默认：",
        INPUT_LABEL = "自定义文字",
        COLOR = "颜色",
        RESET_COLOR = "默认颜色",
        COLOR_SAVED = "颜色已保存",
        COLOR_RESET = "颜色已恢复默认",
        PREVIEW = "预览",
        CLEAR = "清空",
        RESET_ALL = "全部恢复默认",
        CLOSE = "关闭",
        FOOTER = "选项 > 插件 > PetStatusAlert，或命令：/psa 打开设置界面",
        SAVED = "已自动保存",
        CLEARED = "已清空，将使用默认文字",
        RESET_DONE = "全部自定义文字已恢复默认",
        SUPPORT = "支持：猎人、术士、邪恶死亡骑士、点出召唤水元素天赋的冰霜法师",
        LOCK_ALERT_POSITION = "锁定提示文字位置",
        UNLOCK_HINT = "取消勾选后：先点预览显示文字，再拖动屏幕提示文字调整位置。",
        LOCKED_STATUS = "提示文字位置已锁定",
        UNLOCKED_STATUS = "提示文字位置已解锁，可拖动屏幕提示文字移动位置。",
        COMBAT_TTS = "战斗中 TTS 语音提醒",
        COMBAT_TTS_HINT = "开启后，战斗中会每 3 秒朗读一次屏幕上正在显示的提示文字。",
        COMBAT_TTS_RATE = "TTS 语音语速",
        COMBAT_TTS_RATE_HINT = "拖动滑条调整朗读速度。默认：3。0 = 魔兽默认语速。",
        COMBAT_TTS_RATE_VALUE = "语速：%s",
        COMBAT_TTS_ON = "战斗中 TTS 语音提醒已开启",
        COMBAT_TTS_OFF = "战斗中 TTS 语音提醒已关闭",
        ANIMATION_TITLE = "动画设置",
        ANIMATION_FONT_SIZE = "提示文字字体大小",
        ANIMATION_FONT_SIZE_HINT = "调整屏幕提示文字的字体大小。默认：28。",
        ANIMATION_FONT_SIZE_VALUE = "字体大小：%s",
        ANIMATION_FONT_SIZE_CHANGED = "提示文字字体大小已设置为：%s",
        ANIMATION_AMPLITUDE = "上下浮动幅度",
        ANIMATION_AMPLITUDE_HINT = "调整屏幕提示文字的上下浮动范围。默认：8。",
        ANIMATION_AMPLITUDE_VALUE = "幅度：%s",
        ANIMATION_AMPLITUDE_CHANGED = "动画幅度已设置为：%s",
        ANIMATION_SPEED = "上下浮动速度",
        ANIMATION_SPEED_HINT = "调整提示文字上下浮动的速度。1.0x = 旧版本默认速度。",
        ANIMATION_SPEED_VALUE = "速度：%sx",
        ANIMATION_SPEED_CHANGED = "动画速度已设置为：%sx",
        ANIMATION_GLOW_ENABLE = "像素流光",
        ANIMATION_GLOW_ENABLE_HINT = "使用内置 LibCustomGlow-1.0，只保留像素流光效果。",
        ANIMATION_GLOW_ON = "像素流光已开启",
        ANIMATION_GLOW_OFF = "像素流光已关闭",
        ANIMATION_GLOW_SPEED = "像素流光速度",
        ANIMATION_GLOW_SPEED_HINT = "调整像素流光的流动速度。1.0x = 默认速度。",
        ANIMATION_GLOW_SPEED_VALUE = "流光速度：%sx",
        ANIMATION_GLOW_SPEED_CHANGED = "像素流光速度已设置为：%sx",
        LANGUAGE = "界面语言",
        LANGUAGE_DESC = "默认跟随魔兽客户端语言；手动选择后，会立即同步设置界面和默认提示文字。",
        LANGUAGE_CURRENT = "当前语言模式：",
        LANGUAGE_AUTO = "跟随客户端",
        LANGUAGE_ENUS = "English",
        LANGUAGE_ZHCN = "简体中文",
        LANGUAGE_ZHTW = "繁體中文",
        LANGUAGE_RURU = "俄语",
        LANGUAGE_CHANGED = "语言已切换为：%s",
        AUTHOR = "作者：zhufei1000",
        TRANSLATION_RURU = "俄语翻译：Hubbotu",
    },
    zhTW = {
        TITLE = "PetStatusAlert 寵物狀態提醒",
        SUBTITLE = "自訂不同寵物狀態下的螢幕提示文字。留空時，自動使用目前客戶端語言的預設文字。",
        CARD_TITLE = "提示文字自訂",
        CARD_DESC = "自訂文字優先顯示；輸入框留空 = 使用本地化預設文字。",
        PASSIVE = "被動狀態",
        DEFENSIVE = "防禦狀態",
        NO_PET = "未召喚寵物",
        PET_DEAD = "寵物死亡",
        UNKNOWN = "無法識別狀態",
        ENABLE_ALERT = "顯示此類型提醒",
        ALERT_ENABLED = "%s提醒已開啟",
        ALERT_DISABLED = "%s提醒已關閉",
        DEFAULT_PREFIX = "預設：",
        INPUT_LABEL = "自訂文字",
        COLOR = "顏色",
        RESET_COLOR = "預設顏色",
        COLOR_SAVED = "顏色已儲存",
        COLOR_RESET = "顏色已恢復預設",
        PREVIEW = "預覽",
        CLEAR = "清空",
        RESET_ALL = "全部恢復預設",
        CLOSE = "關閉",
        FOOTER = "選項 > 插件 > PetStatusAlert，或命令：/psa 開啟設定介面",
        SAVED = "已自動儲存",
        CLEARED = "已清空，將使用預設文字",
        RESET_DONE = "全部自訂文字已恢復預設",
        SUPPORT = "支援：獵人、術士、邪惡死亡騎士、點出召喚水元素天賦的冰霜法師",
        LOCK_ALERT_POSITION = "鎖定提示文字位置",
        UNLOCK_HINT = "取消勾選後：先點預覽顯示文字，再拖動螢幕提示文字調整位置。",
        LOCKED_STATUS = "提示文字位置已鎖定",
        UNLOCKED_STATUS = "提示文字位置已解鎖，可拖動螢幕提示文字移動位置。",
        COMBAT_TTS = "戰鬥中 TTS 語音提醒",
        COMBAT_TTS_HINT = "開啟後，戰鬥中會每 3 秒朗讀一次螢幕上正在顯示的提示文字。",
        COMBAT_TTS_RATE = "TTS 語音語速",
        COMBAT_TTS_RATE_HINT = "拖動滑條調整朗讀速度。預設：3。0 = 魔獸預設語速。",
        COMBAT_TTS_RATE_VALUE = "語速：%s",
        COMBAT_TTS_ON = "戰鬥中 TTS 語音提醒已開啟",
        COMBAT_TTS_OFF = "戰鬥中 TTS 語音提醒已關閉",
        ANIMATION_TITLE = "動畫設定",
        ANIMATION_FONT_SIZE = "提示文字字體大小",
        ANIMATION_FONT_SIZE_HINT = "調整螢幕提示文字的字體大小。預設：28。",
        ANIMATION_FONT_SIZE_VALUE = "字體大小：%s",
        ANIMATION_FONT_SIZE_CHANGED = "提示文字字體大小已設定為：%s",
        ANIMATION_AMPLITUDE = "上下浮動幅度",
        ANIMATION_AMPLITUDE_HINT = "調整螢幕提示文字的上下浮動範圍。預設：8。",
        ANIMATION_AMPLITUDE_VALUE = "幅度：%s",
        ANIMATION_AMPLITUDE_CHANGED = "動畫幅度已設定為：%s",
        ANIMATION_SPEED = "上下浮動速度",
        ANIMATION_SPEED_HINT = "調整提示文字上下浮動的速度。1.0x = 舊版本預設速度。",
        ANIMATION_SPEED_VALUE = "速度：%sx",
        ANIMATION_SPEED_CHANGED = "動畫速度已設定為：%sx",
        ANIMATION_GLOW_ENABLE = "像素流光",
        ANIMATION_GLOW_ENABLE_HINT = "使用內建 LibCustomGlow-1.0，只保留像素流光效果。",
        ANIMATION_GLOW_ON = "像素流光已開啟",
        ANIMATION_GLOW_OFF = "像素流光已關閉",
        ANIMATION_GLOW_SPEED = "像素流光速度",
        ANIMATION_GLOW_SPEED_HINT = "調整像素流光的流動速度。1.0x = 預設速度。",
        ANIMATION_GLOW_SPEED_VALUE = "流光速度：%sx",
        ANIMATION_GLOW_SPEED_CHANGED = "像素流光速度已設定為：%sx",
        LANGUAGE = "介面語言",
        LANGUAGE_DESC = "預設跟隨魔獸客戶端語言；手動選擇後，會立即同步設定介面和預設提示文字。",
        LANGUAGE_CURRENT = "目前語言模式：",
        LANGUAGE_AUTO = "跟隨客戶端",
        LANGUAGE_ENUS = "English",
        LANGUAGE_ZHCN = "简体中文",
        LANGUAGE_ZHTW = "繁體中文",
        LANGUAGE_RURU = "俄語",
        LANGUAGE_CHANGED = "語言已切換為：%s",
        AUTHOR = "作者：zhufei1000",
        TRANSLATION_RURU = "俄語翻譯：Hubbotu",
    },
    ruRU = {
        TITLE = "PetStatusAlert",
        SUBTITLE = "Собственный текст предупреждения. Оставьте поле пустым, чтобы использовать стандартный текст для языка вашего клиента.",
        CARD_TITLE = "Замена текста предупреждений",
        CARD_DESC = "Пользовательский текст имеет приоритет. Пустое поле = использовать локализованный текст по умолчанию.",
        PASSIVE = "Пассивный питомец",
        DEFENSIVE = "Защищающийся питомец",
        NO_PET = "Нет питомца",
        PET_DEAD = "Питомец мертв",
        UNKNOWN = "Неизвестный статус",
        ENABLE_ALERT = "Вкл. это предупреждение",
        ALERT_ENABLED = "Предупреждение %s включено",
        ALERT_DISABLED = "Предупреждение %s выключено",
        DEFAULT_PREFIX = "По умолчанию:",
        INPUT_LABEL = "Свой текст",
        COLOR = "Цвет",
        RESET_COLOR = "Цвет по умолчанию",
        COLOR_SAVED = "Цвет сохранен",
        COLOR_RESET = "Цвет сброшен",
        PREVIEW = "Предпросмотр",
        CLEAR = "Очистить",
        RESET_ALL = "Сбросить всё",
        CLOSE = "Закрыть",
        FOOTER = "Настройки > Модификации > PetStatusAlert, или команда: /psa",
        SAVED = "Сохранено автоматически",
        CLEARED = "Пользовательский текст очищен",
        RESET_DONE = "Весь пользовательский текст был сброшен",
        SUPPORT = "Поддерживается: Охотник, Чернокнижник, Рыцарь смерти «Нечестивости», Маг «Льда» с талантом «Призыв элементаля воды»",
        LOCK_ALERT_POSITION = "Закрепить позицию предупреждения",
        UNLOCK_HINT = "Флажок снят: отображается текст предпросмотра, перетащите его для перемещения.",
        LOCKED_STATUS = "Позиция предупреждения закреплена",
        UNLOCKED_STATUS = "Позиция предупреждения разблокирована. Перетащите текст для перемещения.",
        COMBAT_TTS = "Голосовое напоминание (TTS) в бою",
        COMBAT_TTS_HINT = "Если включено, видимый текст предупреждения будет озвучиваться каждые 3 секунды во время боя.",
        COMBAT_TTS_RATE = "Скорость речи TTS",
        COMBAT_TTS_RATE_HINT = "Перетащите ползунок для настройки скорости голоса. По умолчанию: 3. 0 = стандартная скорость WoW.",
        COMBAT_TTS_RATE_VALUE = "Скорость: %s",
        COMBAT_TTS_ON = "Голосовое напоминание (TTS) в бою включено",
        COMBAT_TTS_OFF = "Голосовое напоминание (TTS) в бою выключено",
        ANIMATION_TITLE = "Анимация",
        ANIMATION_FONT_SIZE = "Размер шрифта оповещений",
        ANIMATION_FONT_SIZE_HINT = "Регулировка размера текста оповещений на экране. По умолчанию: 28.",
        ANIMATION_FONT_SIZE_VALUE = "Размер шрифта: %s",
        ANIMATION_FONT_SIZE_CHANGED = "Размер шрифта оповещений изменен на: %s",
        ANIMATION_AMPLITUDE = "Амплитуда покачивания вверх/вниз",
        ANIMATION_AMPLITUDE_HINT = "Регулировка диапазона вертикального движения текста оповещений. По умолчанию: 8.",
        ANIMATION_AMPLITUDE_VALUE = "Амплитуда: %s",
        ANIMATION_AMPLITUDE_CHANGED = "Амплитуда анимации изменена на: %s",
        ANIMATION_SPEED = "Скорость покачивания вверх/вниз",
        ANIMATION_SPEED_HINT = "Регулировка скорости вертикального движения. 1.0x = прежняя скорость по умолчанию.",
        ANIMATION_SPEED_VALUE = "Скорость: %sx",
        ANIMATION_SPEED_CHANGED = "Скорость анимации изменена на: %sx",
        ANIMATION_GLOW_ENABLE = "Пиксельное свечение",
        ANIMATION_GLOW_ENABLE_HINT = "Использует встроенную библиотеку LibCustomGlow-1.0 для создания пиксельного свечения вокруг текста.",
        ANIMATION_GLOW_ON = "Пиксельное свечение включено",
        ANIMATION_GLOW_OFF = "Пиксельное свечение выключено",
        ANIMATION_GLOW_SPEED = "Скорость пиксельного свечения",
        ANIMATION_GLOW_SPEED_HINT = "Регулировка скорости движения пиксельного свечения. 1.0x = скорость по умолчанию.",
        ANIMATION_GLOW_SPEED_VALUE = "Скорость свечения: %sx",
        ANIMATION_GLOW_SPEED_CHANGED = "Скорость пиксельного свечения изменена на: %sx",
        LANGUAGE = "Язык",
        LANGUAGE_DESC = "По умолчанию соответствует языку вашего клиента WoW. Ручной выбор немедленно обновит интерфейс и стандартный текст предупреждений.",
        LANGUAGE_CURRENT = "Текущий языковой режим:",
        LANGUAGE_AUTO = "Язык клиента",
        LANGUAGE_ENUS = "Английский",
        LANGUAGE_ZHCN = "Китайский (упрощенный)",
        LANGUAGE_ZHTW = "Китайский (традиционный)",
        LANGUAGE_RURU = "Русский",
        LANGUAGE_CHANGED = "Язык переключен на: %s",
        AUTHOR = "Автор: zhufei1000",
        TRANSLATION_RURU = "Перевод на Русский: ZamestoTV",
    },
}

local RAW_CLIENT_LOCALE = type(GetLocale) == "function" and GetLocale() or "enUS"
local SUPPORTED_LOCALES = {
    enUS = true,
    zhCN = true,
    zhTW = true,
    ruRU = true,
}

local function NormalizeLocale(locale)
    locale = tostring(locale or "")
    if SUPPORTED_LOCALES[locale] then
        return locale
    end
    return "enUS"
end

local CLIENT_LOCALE = NormalizeLocale(RAW_CLIENT_LOCALE)

local function GetSavedLanguageMode()
    InitDB()
    local language = tostring(PetStatusAlertDB.language or "auto")
    if language == "auto" or SUPPORTED_LOCALES[language] then
        return language
    end
    return "auto"
end

local function GetActiveLocale()
    local language = GetSavedLanguageMode()
    if language == "auto" then
        return CLIENT_LOCALE
    end
    return NormalizeLocale(language)
end

local L = LOCALIZED_MESSAGES.enUS
local UI = UI_LOCALE.enUS

local STATUS_ORDER = {
    "NO_PET",
    "PET_DEAD",
    "PASSIVE",
    "DEFENSIVE",
    "UNKNOWN",
}

local STATUS_LABEL = {}

local function RefreshLocaleTables()
    local locale = GetActiveLocale()
    L = LOCALIZED_MESSAGES[locale] or LOCALIZED_MESSAGES.enUS
    UI = UI_LOCALE[locale] or UI_LOCALE.enUS
    STATUS_LABEL = {
        NO_PET = UI.NO_PET,
        PET_DEAD = UI.PET_DEAD,
        PASSIVE = UI.PASSIVE,
        DEFENSIVE = UI.DEFENSIVE,
        UNKNOWN = UI.UNKNOWN,
    }
    PSA.L = L
    PSA.UI = UI
    PSA.STATUS_LABEL = STATUS_LABEL
end

RefreshLocaleTables()

local function GetDefaultMessage(statusKey)
    return L[statusKey] or LOCALIZED_MESSAGES.enUS[statusKey] or ""
end

local function GetCustomMessage(statusKey)
    InitDB()
    local value = PetStatusAlertDB.customMessages[statusKey]
    value = Trim(value)
    if value ~= "" then
        return value
    end
    return nil
end

local function GetDisplayMessage(statusKey)
    return GetCustomMessage(statusKey) or GetDefaultMessage(statusKey)
end

local function IsStatusEnabled(statusKey)
    InitDB()
    if PetStatusAlertDB.statusEnabled[statusKey] == nil then
        PetStatusAlertDB.statusEnabled[statusKey] = true
    end
    return PetStatusAlertDB.statusEnabled[statusKey] ~= false
end

local function SetStatusEnabled(statusKey, enabled)
    InitDB()
    PetStatusAlertDB.statusEnabled[statusKey] = enabled and true or false
end

local DEFAULT_TEXT_COLOR = {
    r = 1,
    g = 0.12,
    b = 0.08,
    a = 1,
}

local function ClampColor(value, fallback)
    value = tonumber(value)
    if value == nil then
        return fallback
    end
    if value < 0 then
        return 0
    end
    if value > 1 then
        return 1
    end
    return value
end

local function EnsureStatusColor(statusKey)
    InitDB()
    PetStatusAlertDB.textColors[statusKey] = type(PetStatusAlertDB.textColors[statusKey]) == "table" and PetStatusAlertDB.textColors[statusKey] or {}
    local color = PetStatusAlertDB.textColors[statusKey]
    color.r = ClampColor(color.r, DEFAULT_TEXT_COLOR.r)
    color.g = ClampColor(color.g, DEFAULT_TEXT_COLOR.g)
    color.b = ClampColor(color.b, DEFAULT_TEXT_COLOR.b)
    color.a = ClampColor(color.a, DEFAULT_TEXT_COLOR.a)
    return color
end

local function GetStatusColor(statusKey)
    local color = EnsureStatusColor(statusKey or "UNKNOWN")
    return color.r, color.g, color.b, color.a
end

local function SetStatusColor(statusKey, r, g, b, a)
    InitDB()
    local color = EnsureStatusColor(statusKey)
    color.r = ClampColor(r, DEFAULT_TEXT_COLOR.r)
    color.g = ClampColor(g, DEFAULT_TEXT_COLOR.g)
    color.b = ClampColor(b, DEFAULT_TEXT_COLOR.b)
    color.a = ClampColor(a, DEFAULT_TEXT_COLOR.a)
end

local function ResetStatusColor(statusKey)
    InitDB()
    PetStatusAlertDB.textColors[statusKey] = {
        r = DEFAULT_TEXT_COLOR.r,
        g = DEFAULT_TEXT_COLOR.g,
        b = DEFAULT_TEXT_COLOR.b,
        a = DEFAULT_TEXT_COLOR.a,
    }
end


-------------------------------------------------
-- Public localization API
-------------------------------------------------

PSA.LOCALIZED_MESSAGES = LOCALIZED_MESSAGES
PSA.UI_LOCALE = UI_LOCALE
PSA.SUPPORTED_LOCALES = SUPPORTED_LOCALES
PSA.CLIENT_LOCALE = CLIENT_LOCALE
PSA.STATUS_ORDER = STATUS_ORDER
PSA.DEFAULT_TEXT_COLOR = DEFAULT_TEXT_COLOR

PSA.NormalizeLocale = NormalizeLocale
PSA.GetSavedLanguageMode = GetSavedLanguageMode
PSA.GetActiveLocale = GetActiveLocale
PSA.RefreshLocaleTables = RefreshLocaleTables
PSA.GetDefaultMessage = GetDefaultMessage
PSA.GetCustomMessage = GetCustomMessage
PSA.GetDisplayMessage = GetDisplayMessage
PSA.IsStatusEnabled = IsStatusEnabled
PSA.SetStatusEnabled = SetStatusEnabled
PSA.GetStatusColor = GetStatusColor
PSA.SetStatusColor = SetStatusColor
PSA.ResetStatusColor = ResetStatusColor
