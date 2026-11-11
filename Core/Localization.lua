-------------------------------------------------
-- PetStatusAlert localization and saved text settings
-------------------------------------------------

local _, PSA = ...
PSA = PSA or _G.PetStatusAlert

local InitDB = PSA.InitDB
local Trim = PSA.Trim

local LOCALIZED_MESSAGES = {
    enUS = {
        PASSIVE = "Pet: Passive",
        DEFENSIVE = "Pet: Defensive",
        AGGRESSIVE = "Pet: Aggressive",
        UNKNOWN = "Pet status unknown.",
        NO_PET = "No pet summoned!",
        PET_DEAD = "Pet is dead!",
        WARRIOR_DEFENSIVE_STANCE = "Defensive Stance active!",
        WARLOCK_WRONG_PET = "Wrong demon summoned!",
    },
    zhCN = {
        PASSIVE = "我的宠物现在是：被动状态",
        DEFENSIVE = "我的宠物现在是：防御状态",
        AGGRESSIVE = "我的宠物现在是：攻击状态",
        UNKNOWN = "我的宠物状态暂时无法识别",
        NO_PET = "我的宠物不存在",
        PET_DEAD = "我的宠物已死亡",
        WARRIOR_DEFENSIVE_STANCE = "当前处于：防御姿态",
        WARLOCK_WRONG_PET = "召唤错误",
    },
    zhTW = {
        PASSIVE = "我的寵物現在是：被動狀態",
        DEFENSIVE = "我的寵物現在是：防禦狀態",
        AGGRESSIVE = "我的寵物現在是：攻擊狀態",
        UNKNOWN = "我的寵物狀態暫時無法識別",
        NO_PET = "我的寵物不存在",
        PET_DEAD = "我的寵物已死亡",
        WARRIOR_DEFENSIVE_STANCE = "目前處於：防禦姿態",
        WARLOCK_WRONG_PET = "召喚錯誤",
    },
    ruRU = {
        PASSIVE = "Режим питомца: Пассивный",
        DEFENSIVE = "Режим питомца: Защита",
        AGGRESSIVE = "Режим питомца: Агрессивный",
        UNKNOWN = "Статус питомца сейчас невозможно определить",
        NO_PET = "Питомец не призван",
        PET_DEAD = "Питомец мертв",
        WARRIOR_DEFENSIVE_STANCE = "Сейчас включена защитная стойка",
        WARLOCK_WRONG_PET = "Призван неподходящий демон!",
    },
}

local UI_LOCALE = {
    enUS = {
        TITLE = "PetStatusAlert",
        SUBTITLE = "Custom pet warning text. Leave blank to use the default text for your client language.",
        PASSIVE = "Pet: Passive",
        DEFENSIVE = "Pet: Defensive",
        AGGRESSIVE = "Pet: Aggressive",
        NO_PET = "No Pet Summoned",
        PET_DEAD = "Dead Pet",
        UNKNOWN = "Unknown Pet Status",
        ENABLE_ALERT = "Enable this alert",
        ALERT_ENABLED = "%s alert enabled",
        ALERT_DISABLED = "%s alert disabled",
        DEFAULT_PREFIX = "Default:",
        COLOR_SAVED = "Color saved",
        COLOR_RESET = "Color reset",
        PREVIEW = "Preview",
        CLOSE = "Close",
        FOOTER = "Options > AddOns > PetStatusAlert, or slash: /psa",
        SAVED = "Saved automatically",
        CLEARED = "Custom text cleared",
        RESET_DONE = "All custom text has been reset",
        SUPPORT = PSA.IsForeverClient() and "Supported: Hunter, Warlock, Mage with Summon Water Elemental. Requires a learned pet summon ability."
            or "Supported: Hunter, Warlock, Unholy Death Knight, Frost Mage with Summon Water Elemental talent",
        LOCKED_STATUS = "Alert position locked",
        UNLOCKED_STATUS = "Alert position unlocked. Drag the alert text to move it.",
        COMBAT_TTS = "Combat TTS voice reminder",
        COMBAT_TTS_HINT = "When enabled, the visible alert text is spoken every 3 seconds during combat.",
        COMBAT_TTS_RATE = "TTS speech speed",
        COMBAT_TTS_RATE_HINT = "Drag to adjust the voice speed. Default: 3. 0 = WoW default speed.",
        COMBAT_TTS_RATE_VALUE = "Speed: %s",
        COMBAT_TTS_ON = "Combat TTS reminder enabled",
        COMBAT_TTS_OFF = "Combat TTS reminder disabled",
        ANIMATION_FONT_SIZE = "Alert font size",
        ANIMATION_FONT_SIZE_HINT = "Adjust the on-screen alert text size. Default: 28.",
        ANIMATION_FONT_SIZE_VALUE = "Font size: %s",
        ANIMATION_AMPLITUDE = "Up/down float amplitude",
        ANIMATION_AMPLITUDE_HINT = "Adjust the vertical floating range of the on-screen alert text. Default: 8.",
        ANIMATION_AMPLITUDE_VALUE = "Amplitude: %s",
        ANIMATION_SPEED = "Up/down float speed",
        ANIMATION_SPEED_HINT = "Adjust the vertical floating speed. 1.0x = old default speed.",
        ANIMATION_SPEED_VALUE = "Speed: %sx",
        ANIMATION_GLOW_ENABLE = "Pixel glow",
        ANIMATION_GLOW_ENABLE_HINT = "Pixel glow outlines icons. It defaults to on for Passive, Defensive, Feed Pet and unhappy pet alerts.",
        FEED_CHOOSE_TITLE = "Choose Pet Food",
        FEED_CHOOSE_AUTO = "Choose Automatically",
        FEED_CHOOSE_HINT = "Right-click to choose food",
        FEED_FOOD_REMAINING = "%s (%d in bags)",
        FEED_FOOD_UNAVAILABLE = "Selected food unavailable",
        LOW_ARROWS = "Low arrows (%d left)",
        LOW_BULLETS = "Low bullets (%d left)",
        LOW_ARROWS_LABEL = "Low arrows",
        LOW_BULLETS_LABEL = "Low bullets",
        RETAIL_CLIENT = "Retail",
        FOREVER_CLIENT = "Forever",
        CLASS_SETTINGS = "Class Settings",
        OTHER_CLIENT_SETTINGS = "Read-only defaults. Open this game version to change its settings.",
        CLASS_UNSUPPORTED = "This class has no alerts in this game version.",
        WARLOCK_WRONG_PET = "Wrong summon alert",
        WARLOCK_PET_RULES = "Demon selection",
        WARLOCK_PET_RULES_HINT = "The alert triggers when a checked demon is your active pet.",
        WARLOCK_SPEC = "Specialization",
        WARLOCK_SPECS = { [265] = "Affliction", [266] = "Demonology", [267] = "Destruction" },
        WARLOCK_PETS = { [23] = "Imp", [16] = "Voidwalker", [15] = "Felhunter", [17] = "Succubus", [302] = "Incubus", [29] = "Felguard" },
        WARLOCK_SAYAAD = "Sayaad (Succubus or Incubus)",
        WARLOCK_IGNORE_SACRIFICE = "Suppress alerts with Grimoire of Sacrifice",
        WARLOCK_SACRIFICE_ID = "Grimoire talent ID",
        WARLOCK_SACRIFICE_HINT = "Uses the ID for the selected specialization. Clear the field to restore its default.",
        MAGE_SUMMON_SETTINGS = "Water Elemental requirement",
        MAGE_REQUIRE_SUMMON = "Require the summon talent or spell",
        MAGE_SUMMON_ID = "Talent or spell ID",
        MAGE_SUMMON_HINT = "Default: 31687. Clear the field to restore the default.",
        FEED_SETTINGS = "One-click pet feeding",
        FEED_ENABLED = "Show one-click feed button",
        FEED_SETTINGS_HINT = "Choose food automatically or prefer an item in your bags. The choice is saved per character.",
        FEED_REQUIRES_PET = "Summon a hunter pet to list suitable food.",
        FEED_REQUIRES_HUNTER = "Select food on your Forever hunter.",
        SETTING_OUT_OF_COMBAT = "Available out of combat.",
        ALERT_CLASSES = { HUNTER = "Hunter", WARLOCK = "Warlock", MAGE = "Mage", DEATHKNIGHT = "Death Knight", WARRIOR = "Warrior" },
        ALERT_CLASS_VARIANTS = { MAGE = "Frost Mage (Water Elemental)", FOREVER_MAGE = "Mage (Water Elemental)",
            DEATHKNIGHT = "Unholy Death Knight", WARRIOR = "Arms / Fury Warrior" },
        WARRIOR_DEFENSIVE_STANCE = "Warrior: Defensive Stance",
        AMMO_SETTINGS = "Low Ammo Alert",
        AMMO_THRESHOLD = "Ammo threshold",
        AMMO_THRESHOLD_HINT = "Warn out of combat below this amount. Default: 100. Range: 0–9999. Set 0 to turn off.",
        ANIMATION_GLOW_ON = "Pixel glow enabled",
        ANIMATION_GLOW_OFF = "Pixel glow disabled",
        ANIMATION_GLOW_SPEED = "Pixel glow speed",
        ANIMATION_GLOW_SPEED_HINT = "Adjust the flowing speed of the pixel glow. 1.0x = default speed.",
        ANIMATION_GLOW_SPEED_VALUE = "Glow speed: %sx",
        ANIMATION_ICON_MODE = "Icon mode",
        ANIMATION_ICON_MODE_HINT = "No-pet and dead-pet states show the matching spell icon. Passive/Defensive states show the pet stance icon (requires pet alive). Unknown state has no icon.",
        ANIMATION_ICON_MODE_TEXT = "Text only",
        ANIMATION_ICON_MODE_ICON = "Icon only",
        ANIMATION_ICON_MODE_BOTH = "Icon + Text",
        ANIMATION_ICON_MODE_CHANGED = "Icon mode set to: %s",
        ANIMATION_ICON_SIZE = "Icon size",
        ANIMATION_ICON_SIZE_HINT = "Adjust the skill icon edge length. Default: 48.",
        ANIMATION_ICON_SIZE_VALUE = "Icon size: %s",
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
        PASSIVE = "被动状态",
        DEFENSIVE = "防御状态",
        AGGRESSIVE = "攻击状态",
        NO_PET = "未召唤宠物",
        PET_DEAD = "宠物死亡",
        UNKNOWN = "无法识别状态",
        ENABLE_ALERT = "显示此类型提醒",
        ALERT_ENABLED = "%s提醒已开启",
        ALERT_DISABLED = "%s提醒已关闭",
        DEFAULT_PREFIX = "默认：",
        COLOR_SAVED = "颜色已保存",
        COLOR_RESET = "颜色已恢复默认",
        PREVIEW = "预览",
        CLOSE = "关闭",
        FOOTER = "选项 > 插件 > PetStatusAlert，或命令：/psa 打开设置界面",
        SAVED = "已自动保存",
        CLEARED = "已清空，将使用默认文字",
        RESET_DONE = "全部自定义文字已恢复默认",
        SUPPORT = PSA.IsForeverClient() and "支持：猎人、术士、学会召唤水元素的法师；学会宠物召唤技能后启用。"
            or "支持：猎人、术士、邪恶死亡骑士、点出召唤水元素天赋的冰霜法师",
        LOCKED_STATUS = "提示文字位置已锁定",
        UNLOCKED_STATUS = "提示文字位置已解锁，可拖动屏幕提示文字移动位置。",
        COMBAT_TTS = "战斗中 TTS 语音提醒",
        COMBAT_TTS_HINT = "开启后，战斗中会每 3 秒朗读一次屏幕上正在显示的提示文字。",
        COMBAT_TTS_RATE = "TTS 语音语速",
        COMBAT_TTS_RATE_HINT = "拖动滑条调整朗读速度。默认：3。0 = 魔兽默认语速。",
        COMBAT_TTS_RATE_VALUE = "语速：%s",
        COMBAT_TTS_ON = "战斗中 TTS 语音提醒已开启",
        COMBAT_TTS_OFF = "战斗中 TTS 语音提醒已关闭",
        ANIMATION_FONT_SIZE = "提示文字字体大小",
        ANIMATION_FONT_SIZE_HINT = "调整屏幕提示文字的字体大小。默认：28。",
        ANIMATION_FONT_SIZE_VALUE = "字体大小：%s",
        ANIMATION_AMPLITUDE = "上下浮动幅度",
        ANIMATION_AMPLITUDE_HINT = "调整屏幕提示文字的上下浮动范围。默认：8。",
        ANIMATION_AMPLITUDE_VALUE = "幅度：%s",
        ANIMATION_SPEED = "上下浮动速度",
        ANIMATION_SPEED_HINT = "调整提示文字上下浮动的速度。1.0x = 旧版本默认速度。",
        ANIMATION_SPEED_VALUE = "速度：%sx",
        ANIMATION_GLOW_ENABLE = "像素流光",
        ANIMATION_GLOW_ENABLE_HINT = "像素流光围绕图标显示。被动、防御、喂养宠物和红色心情提醒默认开启。",
        FEED_CHOOSE_TITLE = "选择宠物食物",
        FEED_CHOOSE_AUTO = "自动选择食物",
        FEED_CHOOSE_HINT = "右键选择食物",
        FEED_FOOD_REMAINING = "%s（背包剩余 %d）",
        FEED_FOOD_UNAVAILABLE = "所选食物不可用",
        LOW_ARROWS = "箭矢不足（剩余 %d）",
        LOW_BULLETS = "子弹不足（剩余 %d）",
        LOW_ARROWS_LABEL = "箭矢不足",
        LOW_BULLETS_LABEL = "子弹不足",
        RETAIL_CLIENT = "正式服",
        FOREVER_CLIENT = "无限服",
        CLASS_SETTINGS = "职业设置",
        OTHER_CLIENT_SETTINGS = "此处只读，展示该版本的默认设置。请在对应客户端修改。",
        CLASS_UNSUPPORTED = "该职业在此版本没有可用的提醒。",
        WARLOCK_WRONG_PET = "召唤错误提示",
        WARLOCK_PET_RULES = "宠物选择",
        WARLOCK_PET_RULES_HINT = "当前召唤的宠物在勾选列表中时，显示召唤错误。",
        WARLOCK_SPEC = "专精",
        WARLOCK_SPECS = { [265] = "痛苦", [266] = "恶魔学识", [267] = "毁灭" },
        WARLOCK_PETS = { [23] = "小鬼", [16] = "虚空行者", [15] = "地狱猎犬", [17] = "魅魔", [302] = "夜魔", [29] = "恶魔卫士" },
        WARLOCK_SAYAAD = "萨亚德（魅魔或夜魔）",
        WARLOCK_IGNORE_SACRIFICE = "点出牺牲魔典时忽略相关提醒",
        WARLOCK_SACRIFICE_ID = "牺牲魔典天赋 ID",
        WARLOCK_SACRIFICE_HINT = "对应当前选中的专精。清空输入框可恢复默认 ID。",
        MAGE_SUMMON_SETTINGS = "水元素天赋检测",
        MAGE_REQUIRE_SUMMON = "要求已学会召唤水元素",
        MAGE_SUMMON_ID = "天赋或技能 ID",
        MAGE_SUMMON_HINT = "默认 31687。清空输入框可恢复默认 ID。",
        FEED_SETTINGS = "一键喂养",
        FEED_ENABLED = "显示一键喂养按钮",
        FEED_SETTINGS_HINT = "可自动挑选，也可指定背包里的一种食物。食物选择按角色保存。",
        FEED_REQUIRES_PET = "召出猎人宠物后可查看适合它的食物。",
        FEED_REQUIRES_HUNTER = "请用无限服猎人选择食物。",
        SETTING_OUT_OF_COMBAT = "脱战后可选择。",
        ALERT_CLASSES = { HUNTER = "猎人", WARLOCK = "术士", MAGE = "法师", DEATHKNIGHT = "死亡骑士", WARRIOR = "战士" },
        ALERT_CLASS_VARIANTS = { MAGE = "冰霜法师（召唤水元素）", FOREVER_MAGE = "法师（召唤水元素）",
            DEATHKNIGHT = "邪恶死亡骑士", WARRIOR = "武器 / 狂暴战士" },
        WARRIOR_DEFENSIVE_STANCE = "战士：防御姿态",
        AMMO_SETTINGS = "弹药不足提醒",
        AMMO_THRESHOLD = "弹药低于此数量时提醒",
        AMMO_THRESHOLD_HINT = "脱战时检查剩余弹药。默认 100，可设为 0–9999，设为 0 关闭提醒。",
        ANIMATION_GLOW_ON = "像素流光已开启",
        ANIMATION_GLOW_OFF = "像素流光已关闭",
        ANIMATION_GLOW_SPEED = "像素流光速度",
        ANIMATION_GLOW_SPEED_HINT = "调整像素流光的流动速度。1.0x = 默认速度。",
        ANIMATION_GLOW_SPEED_VALUE = "流光速度：%sx",
        ANIMATION_ICON_MODE = "图标模式",
        ANIMATION_ICON_MODE_HINT = "未召唤/死亡状态显示对应技能图标。被动/防御状态显示宠物姿态图标（需宠物存在）。未知状态无合适图标。",
        ANIMATION_ICON_MODE_TEXT = "纯文字",
        ANIMATION_ICON_MODE_ICON = "纯图标",
        ANIMATION_ICON_MODE_BOTH = "图标+文字",
        ANIMATION_ICON_MODE_CHANGED = "图标模式已设置为：%s",
        ANIMATION_ICON_SIZE = "图标大小",
        ANIMATION_ICON_SIZE_HINT = "调整技能图标的边长。默认：48。",
        ANIMATION_ICON_SIZE_VALUE = "图标大小：%s",
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
        PASSIVE = "被動狀態",
        DEFENSIVE = "防禦狀態",
        AGGRESSIVE = "攻擊狀態",
        NO_PET = "未召喚寵物",
        PET_DEAD = "寵物死亡",
        UNKNOWN = "無法識別狀態",
        ENABLE_ALERT = "顯示此類型提醒",
        ALERT_ENABLED = "%s提醒已開啟",
        ALERT_DISABLED = "%s提醒已關閉",
        DEFAULT_PREFIX = "預設：",
        COLOR_SAVED = "顏色已儲存",
        COLOR_RESET = "顏色已恢復預設",
        PREVIEW = "預覽",
        CLOSE = "關閉",
        FOOTER = "選項 > 插件 > PetStatusAlert，或命令：/psa 開啟設定介面",
        SAVED = "已自動儲存",
        CLEARED = "已清空，將使用預設文字",
        RESET_DONE = "全部自訂文字已恢復預設",
        SUPPORT = PSA.IsForeverClient() and "支援：獵人、術士、學會召喚水元素的法師；學會寵物召喚技能後啟用。"
            or "支援：獵人、術士、邪惡死亡騎士、點出召喚水元素天賦的冰霜法師",
        LOCKED_STATUS = "提示文字位置已鎖定",
        UNLOCKED_STATUS = "提示文字位置已解鎖，可拖動螢幕提示文字移動位置。",
        COMBAT_TTS = "戰鬥中 TTS 語音提醒",
        COMBAT_TTS_HINT = "開啟後，戰鬥中會每 3 秒朗讀一次螢幕上正在顯示的提示文字。",
        COMBAT_TTS_RATE = "TTS 語音語速",
        COMBAT_TTS_RATE_HINT = "拖動滑條調整朗讀速度。預設：3。0 = 魔獸預設語速。",
        COMBAT_TTS_RATE_VALUE = "語速：%s",
        COMBAT_TTS_ON = "戰鬥中 TTS 語音提醒已開啟",
        COMBAT_TTS_OFF = "戰鬥中 TTS 語音提醒已關閉",
        ANIMATION_FONT_SIZE = "提示文字字體大小",
        ANIMATION_FONT_SIZE_HINT = "調整螢幕提示文字的字體大小。預設：28。",
        ANIMATION_FONT_SIZE_VALUE = "字體大小：%s",
        ANIMATION_AMPLITUDE = "上下浮動幅度",
        ANIMATION_AMPLITUDE_HINT = "調整螢幕提示文字的上下浮動範圍。預設：8。",
        ANIMATION_AMPLITUDE_VALUE = "幅度：%s",
        ANIMATION_SPEED = "上下浮動速度",
        ANIMATION_SPEED_HINT = "調整提示文字上下浮動的速度。1.0x = 舊版本預設速度。",
        ANIMATION_SPEED_VALUE = "速度：%sx",
        ANIMATION_GLOW_ENABLE = "像素流光",
        ANIMATION_GLOW_ENABLE_HINT = "像素流光圍繞圖示顯示。被動、防禦、餵養寵物和紅色心情提醒預設開啟。",
        FEED_CHOOSE_TITLE = "選擇寵物食物",
        FEED_CHOOSE_AUTO = "自動選擇食物",
        FEED_CHOOSE_HINT = "按右鍵選擇食物",
        FEED_FOOD_REMAINING = "%s（背包剩餘 %d）",
        FEED_FOOD_UNAVAILABLE = "所選食物無法使用",
        LOW_ARROWS = "箭矢不足（剩餘 %d）",
        LOW_BULLETS = "子彈不足（剩餘 %d）",
        LOW_ARROWS_LABEL = "箭矢不足",
        LOW_BULLETS_LABEL = "子彈不足",
        RETAIL_CLIENT = "正式服",
        FOREVER_CLIENT = "無限服",
        CLASS_SETTINGS = "職業設定",
        OTHER_CLIENT_SETTINGS = "此處唯讀，顯示該版本的預設設定。請在對應用戶端修改。",
        CLASS_UNSUPPORTED = "此職業在這個版本沒有可用的提醒。",
        WARLOCK_WRONG_PET = "召喚錯誤提醒",
        WARLOCK_PET_RULES = "寵物選擇",
        WARLOCK_PET_RULES_HINT = "目前召喚的寵物在勾選清單中時，顯示召喚錯誤。",
        WARLOCK_SPEC = "專精",
        WARLOCK_SPECS = { [265] = "痛苦", [266] = "惡魔學識", [267] = "毀滅" },
        WARLOCK_PETS = { [23] = "小鬼", [16] = "虛無行者", [15] = "惡魔獵犬", [17] = "魅魔", [302] = "夢魔", [29] = "惡魔守衛" },
        WARLOCK_SAYAAD = "薩亞德（魅魔或夢魔）",
        WARLOCK_IGNORE_SACRIFICE = "點出犧牲魔典時忽略相關提醒",
        WARLOCK_SACRIFICE_ID = "犧牲魔典天賦 ID",
        WARLOCK_SACRIFICE_HINT = "對應目前選取的專精。清空輸入欄可恢復預設 ID。",
        MAGE_SUMMON_SETTINGS = "水元素天賦偵測",
        MAGE_REQUIRE_SUMMON = "要求已學會召喚水元素",
        MAGE_SUMMON_ID = "天賦或技能 ID",
        MAGE_SUMMON_HINT = "預設 31687。清空輸入欄可恢復預設 ID。",
        FEED_SETTINGS = "一鍵餵食",
        FEED_ENABLED = "顯示一鍵餵食按鈕",
        FEED_SETTINGS_HINT = "可自動挑選，也可指定背包中的一種食物。食物選擇依角色儲存。",
        FEED_REQUIRES_PET = "召喚獵人寵物後可查看適合牠的食物。",
        FEED_REQUIRES_HUNTER = "請使用無限服獵人選擇食物。",
        SETTING_OUT_OF_COMBAT = "脫離戰鬥後可選擇。",
        ALERT_CLASSES = { HUNTER = "獵人", WARLOCK = "術士", MAGE = "法師", DEATHKNIGHT = "死亡騎士", WARRIOR = "戰士" },
        ALERT_CLASS_VARIANTS = { MAGE = "冰霜法師（召喚水元素）", FOREVER_MAGE = "法師（召喚水元素）",
            DEATHKNIGHT = "邪惡死亡騎士", WARRIOR = "武器 / 狂怒戰士" },
        WARRIOR_DEFENSIVE_STANCE = "戰士：防禦姿態",
        AMMO_SETTINGS = "彈藥不足提醒",
        AMMO_THRESHOLD = "彈藥低於此數量時提醒",
        AMMO_THRESHOLD_HINT = "脫戰時檢查剩餘彈藥。預設 100，可設為 0–9999，設為 0 關閉提醒。",
        ANIMATION_GLOW_ON = "像素流光已開啟",
        ANIMATION_GLOW_OFF = "像素流光已關閉",
        ANIMATION_GLOW_SPEED = "像素流光速度",
        ANIMATION_GLOW_SPEED_HINT = "調整像素流光的流動速度。1.0x = 預設速度。",
        ANIMATION_GLOW_SPEED_VALUE = "流光速度：%sx",
        ANIMATION_ICON_MODE = "圖示模式",
        ANIMATION_ICON_MODE_HINT = "未召喚/死亡狀態顯示對應技能圖示。被動/防禦狀態顯示寵物姿態圖示（需寵物存在）。未知狀態無合適圖示。",
        ANIMATION_ICON_MODE_TEXT = "純文字",
        ANIMATION_ICON_MODE_ICON = "純圖示",
        ANIMATION_ICON_MODE_BOTH = "圖示+文字",
        ANIMATION_ICON_MODE_CHANGED = "圖示模式已設定為：%s",
        ANIMATION_ICON_SIZE = "圖示大小",
        ANIMATION_ICON_SIZE_HINT = "調整技能圖示的邊長。預設：48。",
        ANIMATION_ICON_SIZE_VALUE = "圖示大小：%s",
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
        PASSIVE = "Пассивный питомец",
        DEFENSIVE = "Защищающийся питомец",
        AGGRESSIVE = "Агрессивный питомец",
        NO_PET = "Нет питомца",
        PET_DEAD = "Питомец мертв",
        UNKNOWN = "Неизвестный статус",
        ENABLE_ALERT = "Вкл. это предупреждение",
        ALERT_ENABLED = "Предупреждение %s включено",
        ALERT_DISABLED = "Предупреждение %s выключено",
        DEFAULT_PREFIX = "По умолчанию:",
        COLOR_SAVED = "Цвет сохранен",
        COLOR_RESET = "Цвет сброшен",
        PREVIEW = "Предпросмотр",
        CLOSE = "Закрыть",
        FOOTER = "Настройки > Модификации > PetStatusAlert, или команда: /psa",
        SAVED = "Сохранено автоматически",
        CLEARED = "Пользовательский текст очищен",
        RESET_DONE = "Весь пользовательский текст был сброшен",
        SUPPORT = PSA.IsForeverClient() and "Поддерживается: Охотник, Чернокнижник, Маг с призывом элементаля воды. Требуется изученное заклинание призыва питомца."
            or "Поддерживается: Охотник, Чернокнижник, Рыцарь смерти «Нечестивости», Маг «Льда» с талантом «Призыв элементаля воды»",
        LOCKED_STATUS = "Позиция предупреждения закреплена",
        UNLOCKED_STATUS = "Позиция предупреждения разблокирована. Перетащите текст для перемещения.",
        COMBAT_TTS = "Голосовое напоминание (TTS) в бою",
        COMBAT_TTS_HINT = "Если включено, видимый текст предупреждения будет озвучиваться каждые 3 секунды во время боя.",
        COMBAT_TTS_RATE = "Скорость речи TTS",
        COMBAT_TTS_RATE_HINT = "Перетащите ползунок для настройки скорости голоса. По умолчанию: 3. 0 = стандартная скорость WoW.",
        COMBAT_TTS_RATE_VALUE = "Скорость: %s",
        COMBAT_TTS_ON = "Голосовое напоминание (TTS) в бою включено",
        COMBAT_TTS_OFF = "Голосовое напоминание (TTS) в бою выключено",
        ANIMATION_FONT_SIZE = "Размер шрифта оповещений",
        ANIMATION_FONT_SIZE_HINT = "Регулировка размера текста оповещений на экране. По умолчанию: 28.",
        ANIMATION_FONT_SIZE_VALUE = "Размер шрифта: %s",
        ANIMATION_AMPLITUDE = "Амплитуда покачивания вверх/вниз",
        ANIMATION_AMPLITUDE_HINT = "Регулировка диапазона вертикального движения текста оповещений. По умолчанию: 8.",
        ANIMATION_AMPLITUDE_VALUE = "Амплитуда: %s",
        ANIMATION_SPEED = "Скорость покачивания вверх/вниз",
        ANIMATION_SPEED_HINT = "Регулировка скорости вертикального движения. 1.0x = прежняя скорость по умолчанию.",
        ANIMATION_SPEED_VALUE = "Скорость: %sx",
        ANIMATION_GLOW_ENABLE = "Пиксельное свечение",
        ANIMATION_GLOW_ENABLE_HINT = "По умолчанию подсвечиваются значки пассивного и защитного режима, кормления и недовольства питомца.",
        FEED_CHOOSE_TITLE = "Выбор корма",
        FEED_CHOOSE_AUTO = "Автоматический выбор",
        FEED_CHOOSE_HINT = "Щёлкните правой кнопкой, чтобы выбрать корм",
        FEED_FOOD_REMAINING = "%s (%d в сумках)",
        FEED_FOOD_UNAVAILABLE = "Выбранный корм недоступен",
        LOW_ARROWS = "Мало стрел (осталось %d)",
        LOW_BULLETS = "Мало пуль (осталось %d)",
        LOW_ARROWS_LABEL = "Мало стрел",
        LOW_BULLETS_LABEL = "Мало пуль",
        RETAIL_CLIENT = "Retail",
        FOREVER_CLIENT = "Forever",
        CLASS_SETTINGS = "Настройки классов",
        OTHER_CLIENT_SETTINGS = "Показаны настройки по умолчанию. Изменить их можно в соответствующем клиенте.",
        CLASS_UNSUPPORTED = "Для этого класса в данной версии нет предупреждений.",
        WARLOCK_WRONG_PET = "Предупреждение о неверном призыве",
        WARLOCK_PET_RULES = "Выбор демонов",
        WARLOCK_PET_RULES_HINT = "Предупреждение появляется, если активный демон отмечен в списке.",
        WARLOCK_SPEC = "Специализация",
        WARLOCK_SPECS = { [265] = "Колдовство", [266] = "Демонология", [267] = "Разрушение" },
        WARLOCK_PETS = { [23] = "Бес", [16] = "Демон Бездны", [15] = "Охотник Скверны", [17] = "Суккуб", [302] = "Инкуб", [29] = "Страж Скверны" },
        WARLOCK_SAYAAD = "Саяад (суккуб или инкуб)",
        WARLOCK_IGNORE_SACRIFICE = "Игнорировать при «Гримуаре жертвоприношения»",
        WARLOCK_SACRIFICE_ID = "ID таланта «Гримуар жертвоприношения»",
        WARLOCK_SACRIFICE_HINT = "ID для выбранной специализации. Очистите поле для восстановления значения по умолчанию.",
        MAGE_SUMMON_SETTINGS = "Проверка элементаля воды",
        MAGE_REQUIRE_SUMMON = "Требовать изученный призыв элементаля",
        MAGE_SUMMON_ID = "ID таланта или заклинания",
        MAGE_SUMMON_HINT = "По умолчанию: 31687. Очистите поле, чтобы вернуть это значение.",
        FEED_SETTINGS = "Кормление в один клик",
        FEED_ENABLED = "Показывать кнопку кормления",
        FEED_SETTINGS_HINT = "Выберите корм из сумок или оставьте автоматический выбор. Настройка сохраняется для персонажа.",
        FEED_REQUIRES_PET = "Призовите питомца охотника, чтобы увидеть подходящий корм.",
        FEED_REQUIRES_HUNTER = "Выберите корм на охотнике в Forever.",
        SETTING_OUT_OF_COMBAT = "Доступно вне боя.",
        ALERT_CLASSES = { HUNTER = "Охотник", WARLOCK = "Чернокнижник", MAGE = "Маг", DEATHKNIGHT = "Рыцарь смерти", WARRIOR = "Воин" },
        ALERT_CLASS_VARIANTS = { MAGE = "Маг льда (элементаль воды)", FOREVER_MAGE = "Маг (элементаль воды)",
            DEATHKNIGHT = "Рыцарь смерти (Нечестивость)", WARRIOR = "Воин (Оружие / Неистовство)" },
        WARRIOR_DEFENSIVE_STANCE = "Воин: Защитная стойка",
        AMMO_SETTINGS = "Нехватка боеприпасов",
        AMMO_THRESHOLD = "Порог боеприпасов",
        AMMO_THRESHOLD_HINT = "Проверка вне боя. По умолчанию 100. Диапазон 0–9999. Значение 0 отключает предупреждение.",
        ANIMATION_GLOW_ON = "Пиксельное свечение включено",
        ANIMATION_GLOW_OFF = "Пиксельное свечение выключено",
        ANIMATION_GLOW_SPEED = "Скорость пиксельного свечения",
        ANIMATION_GLOW_SPEED_HINT = "Регулировка скорости движения пиксельного свечения. 1.0x = скорость по умолчанию.",
        ANIMATION_GLOW_SPEED_VALUE = "Скорость свечения: %sx",
        ANIMATION_ICON_MODE = "Режим значков",
        ANIMATION_ICON_MODE_HINT = "Состояния «нет питомца» и «питомец мёртв» — значок нужного заклинания призыва. Пассивный/Защита — значок стойки питомца (требуется живой питомец). Неизвестный статус — без значка.",
        ANIMATION_ICON_MODE_TEXT = "Только текст",
        ANIMATION_ICON_MODE_ICON = "Только значок",
        ANIMATION_ICON_MODE_BOTH = "Значок + текст",
        ANIMATION_ICON_MODE_CHANGED = "Режим значков: %s",
        ANIMATION_ICON_SIZE = "Размер значка",
        ANIMATION_ICON_SIZE_HINT = "Регулировка размера стороны значка. По умолчанию: 48.",
        ANIMATION_ICON_SIZE_VALUE = "Размер значка: %s",
        LANGUAGE_DESC = "По умолчанию соответствует языку вашего клиента WoW. Ручной выбор немедленно обновит интерфейс и стандартный текст предупреждений.",
        LANGUAGE_CURRENT = "Текущий языковой режим:",
        LANGUAGE_AUTO = "Язык клиента",
        LANGUAGE_ENUS = "Английский",
        LANGUAGE_ZHCN = "Китайский (упрощенный)",
        LANGUAGE_ZHTW = "Китайский (традиционный)",
        LANGUAGE_RURU = "Русский",
        LANGUAGE_CHANGED = "Язык переключен на: %s",
        AUTHOR = "Автор: zhufei1000",
        TRANSLATION_RURU = "Русский перевод: Hubbotu",
    },
}

local SETTINGS_STRINGS = {
    READ_ONLY_TAB = { "Preview only", "仅预览", "僅預覽", "Только просмотр" },
    PREVIEW_SAMPLE = { "Sample alert", "提醒预览", "提醒預覽", "Пример предупреждения" },
    MOVE_HINT = { "Unlock, then drag the sample alert to move it.", "解锁后，拖动屏幕上的预览提醒即可调整位置。", "解鎖後，拖曳畫面上的預覽提醒即可調整位置。", "Разблокируйте и перетащите пример предупреждения." },
    STOP_PREVIEW = { "Stop preview", "停止预览", "停止預覽", "Остановить предпросмотр" },
    ADVANCED = { "Advanced", "高级", "進階", "Дополнительно" },
    WRONG_PET_OFF = { "Alert off. Your pet choices are kept.", "提醒已关闭，所选宠物仍会保留。", "提醒已關閉，所選寵物仍會保留。", "Предупреждение выключено. Выбор питомцев сохраняется." },
    WRONG_PET_NONE = { "Select at least one demon to trigger the alert.", "至少勾选一种宠物才会触发提醒。", "至少勾選一種寵物才會觸發提醒。", "Выберите хотя бы одного демона для предупреждения." },
    WARLOCK_BLOCKED_PETS = { "Demons that trigger the alert", "会触发提醒的宠物", "會觸發提醒的寵物", "Демоны, вызывающие предупреждение" },
    TTS_BEHAVIOR_HINT = { "Speaks visible alert text in combat. Icon-only alerts without text are silent.", "在战斗中朗读屏幕上的提醒。只显示图标、没有文字时不会播报。", "在戰鬥中朗讀畫面上的提醒。只顯示圖示、沒有文字時不會播報。", "Озвучивает видимый текст в бою. Значки без текста не озвучиваются." },
    TTS_SAMPLE = { "Listen", "试听", "試聽", "Прослушать" },
    TTS_UNAVAILABLE = { "Voice preview is unavailable.", "当前无法播放语音试听。", "目前無法播放語音試聽。", "Прослушивание недоступно." },
    TTS_ONCE = { "Speak once", "仅播一次", "僅播一次", "Один раз" },
    TTS_REPEAT = { "Repeat", "重复播报", "重複播報", "Повторять" },
    TTS_INTERVAL = { "Repeat interval (seconds)", "重复间隔（秒）", "重複間隔（秒）", "Интервал повтора (сек.)" },
    TTS_INTERVAL_VALUE = { "%d sec", "%d 秒", "%d 秒", "%d сек." },
    PET_UNHAPPY_ENABLED = { "Warn when the pet is unhappy", "宠物不高兴时提醒", "寵物不高興時提醒", "Предупреждать о недовольстве питомца" },
    AMMO_WEAPON_HINT = { "Any class with a bow, crossbow, or gun that requires ammo.", "适用于装备需要弹药的弓、弩或枪的职业。", "適用於裝備需要彈藥的弓、弩或槍的職業。", "Для любого класса с луком, арбалетом или ружьём, требующим боеприпасы." },
    CLASS_RESET = { "Reset this class", "恢复本职业默认", "恢復本職業預設", "Сбросить настройки класса" },
    CLASS_RESET_TITLE = { "Reset %s settings?", "恢复%s的默认设置？", "恢復%s的預設設定？", "Сбросить настройки: %s?" },
    CLASS_RESET_BODY = { "Restores this class’s alert switches, custom text, colors, and rules on this client.", "恢复当前版本此职业的提醒开关、自定义文字、颜色和职业规则。", "恢復目前版本此職業的提醒開關、自訂文字、顏色和職業規則。", "Восстанавливает переключатели, тексты, цвета и правила этого класса в текущей версии." },
    CLASS_RESET_KEEP_FOOD = { "Saved food choices are kept.", "角色选定的食物会保留。", "角色選定的食物會保留。", "Выбор еды сохраняется." },
    RESET_ACTION = { "Reset", "恢复默认", "恢復預設", "Сбросить" },
    CLASS_RESET_DONE = { "Class settings restored.", "已恢复本职业的默认设置。", "已恢復本職業的預設設定。", "Настройки класса восстановлены." },
    CANCEL = { "Cancel", "取消", "取消", "Отмена" },
    ELIGIBILITY_MET = { "Current character: eligible.", "当前角色：满足生效条件。", "目前角色：符合生效條件。", "Текущий персонаж: условия выполнены." },
    ELIGIBILITY_UNMET = { "Current character: requirements not met.", "当前角色：尚未满足生效条件。", "目前角色：尚未符合生效條件。", "Текущий персонаж: условия не выполнены." },
    SUPPORT_HUNTER = { "Beast Mastery and Survival only.", "仅野兽控制和生存专精。", "僅獸王和生存專精。", "Только «Повелитель зверей» и «Выживание»." },
    SUPPORT_WARLOCK = { "Available for all Warlock specializations.", "术士所有专精均支持。", "術士所有專精均支援。", "Доступно всем специализациям чернокнижника." },
    SUPPORT_MAGE = { "Frost only. Requires the configured Water Elemental ability by default.", "仅冰霜专精。默认要求已学会设定的水元素召唤技能或天赋。", "僅冰霜專精。預設需學會設定的水元素召喚技能或天賦。", "Только «Лёд». По умолчанию нужна указанная способность призыва элементаля воды." },
    SUPPORT_DEATHKNIGHT = { "Unholy only.", "仅邪恶专精。", "僅穢邪專精。", "Только «Нечестивость»." },
    SUPPORT_WARRIOR = { "Arms and Fury only.", "仅武器和狂怒专精。", "僅武器和狂怒專精。", "Только «Оружие» и «Неистовство»." },
    SUPPORT_FOREVER = { "Learn a pet summon ability to enable pet alerts.", "学会宠物召唤技能后生效。", "學會寵物召喚技能後生效。", "Для предупреждений нужна изученная способность призыва питомца." },
    SUPPORT_FOREVER_MAGE = { "Requires the configured Water Elemental ability by default.", "默认要求学会设定的水元素召唤技能。", "預設需學會設定的水元素召喚技能。", "По умолчанию нужна указанная способность призыва элементаля воды." },
}

local settingsLocales = { "enUS", "zhCN", "zhTW", "ruRU" }
for key, translations in pairs(SETTINGS_STRINGS) do
    for i, locale in ipairs(settingsLocales) do
        UI_LOCALE[locale][key] = translations[i]
    end
end

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

local STATUS_ORDER = {}
for index, key in ipairs(PSA.PET_STATUS_ORDER) do
    STATUS_ORDER[index] = key
end

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
        AGGRESSIVE = UI.AGGRESSIVE,
        UNKNOWN = UI.UNKNOWN,
        WARRIOR_DEFENSIVE_STANCE = UI.WARRIOR_DEFENSIVE_STANCE,
        WARLOCK_WRONG_PET = UI.WARLOCK_WRONG_PET,
    }
    PSA.UI = UI
    PSA.STATUS_LABEL = STATUS_LABEL
    if PSA.RefreshAmmoAlertText then
        PSA.RefreshAmmoAlertText()
    end
end

RefreshLocaleTables()

local function GetDefaultMessage(statusKey)
    return L[statusKey] or LOCALIZED_MESSAGES.enUS[statusKey] or ""
end

function PSA.GetAlertClassLabel(classFile, forever)
    if forever ~= nil then
        local key = forever and classFile == "MAGE" and "FOREVER_MAGE" or classFile
        return UI.ALERT_CLASS_VARIANTS[key] or UI.ALERT_CLASSES[classFile]
    end
    return UI.ALERT_CLASSES[classFile]
end

function PSA.GetClassSupportNote(classFile, forever)
    if not PSA.GetClassAlertStatuses(classFile, forever) then return UI.CLASS_UNSUPPORTED end
    if forever then return classFile == "MAGE" and UI.SUPPORT_FOREVER_MAGE or UI.SUPPORT_FOREVER end
    return UI["SUPPORT_" .. classFile]
end

function PSA.GetWarlockPetLabel(familyID, useClientLocale)
    if not useClientLocale and familyID == 17 then
        return UI.WARLOCK_SAYAAD
    end
    local locale = useClientLocale and UI_LOCALE[CLIENT_LOCALE] or UI
    return locale.WARLOCK_PETS[familyID]
end

function PSA.GetAlertClientName(forever)
    return forever and UI.FOREVER_CLIENT or UI.RETAIL_CLIENT
end

local function GetCustomMessage(statusKey, classFile)
    return PSA.GetStatusSetting("customMessages", statusKey, classFile) or ""
end

local function SetCustomMessage(statusKey, value, classFile)
    PSA.SetStatusSetting("customMessages", statusKey, value or "", classFile)
end

local function GetDisplayMessage(statusKey, classFile)
    local value = Trim(GetCustomMessage(statusKey, classFile))
    if value ~= "" then
        return value
    end
    return GetDefaultMessage(statusKey)
end

function PSA.GetDefaultStatusEnabled(statusKey)
    return statusKey ~= "UNKNOWN" and statusKey ~= "AGGRESSIVE" and statusKey ~= PSA.WRONG_PET_STATUS_KEY
end

local function IsStatusEnabled(statusKey, classFile)
    local enabled = PSA.GetStatusSetting("statusEnabled", statusKey, classFile)
    if enabled == nil then
        return PSA.GetDefaultStatusEnabled(statusKey)
    end
    return enabled ~= false
end

local function SetStatusEnabled(statusKey, enabled, classFile)
    PSA.SetStatusSetting("statusEnabled", statusKey, not not enabled, classFile)
end

local DEFAULT_TEXT_COLOR = {
    r = 1,
    g = 0.12,
    b = 0.08,
    a = 1,
}

function PSA.GetDefaultStatusColor()
    return DEFAULT_TEXT_COLOR.r, DEFAULT_TEXT_COLOR.g, DEFAULT_TEXT_COLOR.b, DEFAULT_TEXT_COLOR.a
end

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

local function GetStatusColor(statusKey, classFile)
    local color = PSA.GetStatusSetting("textColors", statusKey or "UNKNOWN", classFile)
    if type(color) ~= "table" then
        return PSA.GetDefaultStatusColor()
    end
    return ClampColor(color.r, DEFAULT_TEXT_COLOR.r), ClampColor(color.g, DEFAULT_TEXT_COLOR.g),
        ClampColor(color.b, DEFAULT_TEXT_COLOR.b), ClampColor(color.a, DEFAULT_TEXT_COLOR.a)
end

local function SetStatusColor(statusKey, r, g, b, a, classFile)
    PSA.SetStatusSetting("textColors", statusKey, {
        r = ClampColor(r, DEFAULT_TEXT_COLOR.r),
        g = ClampColor(g, DEFAULT_TEXT_COLOR.g),
        b = ClampColor(b, DEFAULT_TEXT_COLOR.b),
        a = ClampColor(a, DEFAULT_TEXT_COLOR.a),
    }, classFile)
end

local function ResetStatusColor(statusKey, classFile)
    SetStatusColor(statusKey, nil, nil, nil, nil, classFile)
end


-------------------------------------------------
-- Public localization API
-------------------------------------------------

PSA.LOCALIZED_MESSAGES = LOCALIZED_MESSAGES
PSA.UI_LOCALE = UI_LOCALE
PSA.SUPPORTED_LOCALES = SUPPORTED_LOCALES
PSA.STATUS_ORDER = STATUS_ORDER

PSA.GetSavedLanguageMode = GetSavedLanguageMode
PSA.GetActiveLocale = GetActiveLocale
PSA.RefreshLocaleTables = RefreshLocaleTables
PSA.GetDefaultMessage = GetDefaultMessage
PSA.GetCustomMessage = GetCustomMessage
PSA.SetCustomMessage = SetCustomMessage
PSA.GetDisplayMessage = GetDisplayMessage
PSA.IsStatusEnabled = IsStatusEnabled
PSA.SetStatusEnabled = SetStatusEnabled
PSA.GetStatusColor = GetStatusColor
PSA.SetStatusColor = SetStatusColor
PSA.ResetStatusColor = ResetStatusColor
