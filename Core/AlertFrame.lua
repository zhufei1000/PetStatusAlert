-------------------------------------------------
-- PetStatusAlert alert frame
-------------------------------------------------

local _, PSA = ...
PSA = PSA or _G.PetStatusAlert

local InitDB = PSA.InitDB
local GetStatusColor = PSA.GetStatusColor
local GetDisplayMessage = PSA.GetDisplayMessage
local IsStatusEnabled = PSA.IsStatusEnabled
local GetPlayerClassFile = PSA.GetPlayerClassFile
local isForever = PSA.IsForeverClient()
local DEFAULT_ALERT_FLOAT_AMPLITUDE = PSA.DEFAULT_ALERT_FLOAT_AMPLITUDE or 8
local DEFAULT_ALERT_FLOAT_SPEED = PSA.DEFAULT_ALERT_FLOAT_SPEED or 1
local DEFAULT_ALERT_FONT_SIZE = PSA.DEFAULT_ALERT_FONT_SIZE or 28
local DEFAULT_ALERT_GLOW_SPEED = PSA.DEFAULT_ALERT_GLOW_SPEED or 1
local DEFAULT_ALERT_GLOW_COLOR = {0.95, 0.95, 0.32, 1}
local DEFAULT_ALERT_ICON_MODE = PSA.DEFAULT_ALERT_ICON_MODE or "both"
local DEFAULT_ALERT_ICON_SIZE = PSA.DEFAULT_ALERT_ICON_SIZE or 48
local DEFAULT_ALERT_ICON_GAP = PSA.DEFAULT_ALERT_ICON_GAP or 10
local VALID_ALERT_ICON_MODES = PSA.VALID_ALERT_ICON_MODES or { text = true, icon = true, both = true }
local ALERT_GLOW_KEY = "PetStatusAlert_Glow"
local ALERT_ROW_GAP = 8
local ALERT_ROW_EDGE_PADDING = 3
local SUPPLY_BADGE_GAP = 3
local SUPPLY_BADGE_HEIGHT = 16
local SUPPLY_NUMERIC_WIDTH = 40
local DISPLAY_SAMPLE = "DISPLAY_SAMPLE"
local displayPreview

local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)

-------------------------------------------------
-- 状态图标标识
-- 正数 = spellID，通过 C_Spell.GetSpellTexture 获取图标。
-- 负数 = 宠物姿态：-1=被动，-2=防御，-3=攻击，使用硬编码姿态纹理。
-- 字符串 "WARLOCK_SUMMON" = 术士动态检测已学召唤技能。
-- nil = 该状态无图标可用 → 始终只显示文字。
-------------------------------------------------
local STATUS_ICON_SPELLS = {
    HUNTER = {
        NO_PET = 883,       -- Call Pet（哨子）
        PET_DEAD = 982,     -- Revive Pet（复活宠物）
        PASSIVE = -1,       -- PET_MODE_PASSIVE（宠物被动姿态图标）
        DEFENSIVE = -2,     -- PET_MODE_DEFENSIVE（宠物防御姿态图标）
    },
    DEATHKNIGHT = {
        NO_PET = 46584,     -- Raise Dead（亡者复生，Retail 统一 spellID）
        PET_DEAD = 46584,
        PASSIVE = -1,
        DEFENSIVE = -2,
    },
    MAGE = {
        NO_PET = 31687,     -- Summon Water Elemental（召唤水元素）
        PET_DEAD = 31687,
        PASSIVE = -1,
        DEFENSIVE = -2,
    },
    -- 术士有多种宠物，按已学技能优先级动态选择。
    WARLOCK = {
        NO_PET = "WARLOCK_SUMMON",
        PET_DEAD = "WARLOCK_SUMMON",
        PASSIVE = -1,
        DEFENSIVE = -2,
    },
}

local PET_MODE_TOKEN = {
    [-1] = "PET_MODE_PASSIVE",
    [-2] = "PET_MODE_DEFENSIVE",
    [-3] = "PET_MODE_AGGRESSIVE",
}

-- 宠物姿态图标的固定纹理路径（WoW 内置常量，跨版本不变）。
-- 不依赖宠物是否存在、不依赖 PetActionButton UI 对象、不依赖 GetPetActionInfo 返回值。
-- 这样 RL/重登后即使宠物栏未渲染也能立即显示正确图标。
local PET_MODE_ICON_TEXTURE = {
    PET_MODE_PASSIVE = "Interface\\Icons\\Ability_Seal",
    PET_MODE_DEFENSIVE = "Interface\\Icons\\Ability_Defend",
    PET_MODE_AGGRESSIVE = "Interface\\Icons\\Ability_Racial_BloodRage",
}

-- 直接返回硬编码纹理路径。不依赖任何运行时状态。
local function GetPetModeIconTexture(targetToken)
    return PET_MODE_ICON_TEXTURE[targetToken] or nil
end

-- 术士召唤技能优先级（恶魔专精优先 Felguard，其余按常用顺序）。
local WARLOCK_SUMMON_SPELL_PRIORITY = {
    30146,  -- Summon Felguard（恶魔专精）
    691,    -- Summon Felhunter
    712,    -- Summon Succubus
    697,    -- Summon Voidwalker
    688,    -- Summon Imp（兜底）
}

-- spellID → 纹理路径 缓存。spellID 固定、图标不变，只查询一次即可。
local SPELL_TEXTURE_CACHE = {}

local function GetSpellTextureByID(spellID)
    spellID = tonumber(spellID)
    if not spellID then
        return nil
    end

    local cached = SPELL_TEXTURE_CACHE[spellID]
    if cached ~= nil then
        return cached
    end

    local tex
    if C_Spell and type(C_Spell.GetSpellTexture) == "function" then
        local ok, result = pcall(C_Spell.GetSpellTexture, spellID)
        if ok and result and result ~= 0 then
            tex = result
        end
    end

    if not tex and type(GetSpellTexture) == "function" then
        local ok, result = pcall(GetSpellTexture, spellID)
        if ok and result and result ~= 0 then
            tex = result
        end
    end

    -- 登录初期法术数据可能尚未就绪；失败结果不缓存，后续显示会重试，
    -- 避免一次失败造成图标永久空白直到 /reload。
    if tex then
        SPELL_TEXTURE_CACHE[spellID] = tex
    end
    return tex
end

local function ResolveWarlockSummonSpellID()
    -- 运行时读取：PetLogic.lua 在本文件之后加载，加载时 PSA.IsKnownPlayerSpell 尚未赋值，
    -- 因此不能在文件顶部缓存。这里在实际调用（显示图标）时读取，此时该函数已存在。
    local knownFn = PSA.IsKnownPlayerSpell
    if type(knownFn) ~= "function" then
        return WARLOCK_SUMMON_SPELL_PRIORITY[#WARLOCK_SUMMON_SPELL_PRIORITY]
    end
    for _, spellID in ipairs(WARLOCK_SUMMON_SPELL_PRIORITY) do
        if knownFn(spellID) then
            return spellID
        end
    end
    return WARLOCK_SUMMON_SPELL_PRIORITY[#WARLOCK_SUMMON_SPELL_PRIORITY]
end

-- 返回当前状态对应的技能图标 spellID；没有合适图标时返回 nil。
local function GetStatusIconSpellID(statusKey)
    if statusKey == DISPLAY_SAMPLE then return -1 end
    if not statusKey then
        return nil
    end

    local classFile = PSA.currentStatusClass
    if not classFile then
        return nil
    end

    local classSpells = STATUS_ICON_SPELLS[classFile]
    if not classSpells then
        return nil
    end

    local value = classSpells[statusKey]
    if statusKey == "AGGRESSIVE" then
        return -3
    end
    if value == nil then
        return nil
    end

    if value == "WARLOCK_SUMMON" then
        if PSA.currentStatusForce and classFile ~= GetPlayerClassFile() then
            return WARLOCK_SUMMON_SPELL_PRIORITY[#WARLOCK_SUMMON_SPELL_PRIORITY]
        end
        return ResolveWarlockSummonSpellID()
    end

    return tonumber(value)
end

-- 供外部模块（如 WarriorLogic）注册"职业-状态 → 图标 spellID"映射。
-- 与 STATUS_ICON_SPELLS 使用同一张表，正数 = spellID，负数 = 宠物姿态标记。
local function RegisterStatusIcon(classFile, statusKey, value)
    if type(classFile) ~= "string" or type(statusKey) ~= "string" or value == nil then
        return false
    end
    if not STATUS_ICON_SPELLS[classFile] then
        STATUS_ICON_SPELLS[classFile] = {}
    end
    STATUS_ICON_SPELLS[classFile][statusKey] = value
    return true
end

local addonFrame = CreateFrame("Frame", "PetStatusAlertFrame", UIParent)
-- Dragging can save an edge point; keep the anchor's center stable as the row changes size.
addonFrame:SetSize(80, 32)
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

-- 内容层：textFrame 作为层级容器（始终覆盖 addonFrame）。
-- contentFrame 是整行提醒的浮动基点，宠物、增益和补给跟随同一个 Y 偏移。
local contentFrame = CreateFrame("Frame", nil, textFrame)
contentFrame:SetPoint("CENTER", textFrame, "CENTER", 0, 0)
contentFrame:SetSize(240, 58)
contentFrame:EnableMouse(false)

-- 告警默认走 MEDIUM；预览时提升到 DIALOG，避免被 900x680 的设置面板
-- （HIGH）遮住。设置面板或管理器关闭后会由 HideStatus 恢复。
local ALERT_STRATA_DEFAULT = "MEDIUM"
local ALERT_STRATA_PREVIEW = "DIALOG"
local currentAlertStrata

local function SetAlertStrata(strata)
    strata = strata or ALERT_STRATA_DEFAULT
    if PetStatusAlertDB and not PetStatusAlertDB.alertLocked then
        strata = ALERT_STRATA_PREVIEW
    end
    if strata == currentAlertStrata then
        return
    end
    currentAlertStrata = strata
    if addonFrame and addonFrame.SetFrameStrata then
        addonFrame:SetFrameStrata(strata)
    end
    if glowFrame and glowFrame.SetFrameStrata then
        glowFrame:SetFrameStrata(strata)
    end
    if textFrame and textFrame.SetFrameStrata then
        textFrame:SetFrameStrata(strata)
    end
    if contentFrame and contentFrame.SetFrameStrata then
        contentFrame:SetFrameStrata(strata)
    end
end

-- 技能图标纹理。默认隐藏，仅在有对应技能图标且模式非纯文字时显示。
local icon = contentFrame:CreateTexture(nil, "ARTWORK")
icon:SetSize(DEFAULT_ALERT_ICON_SIZE, DEFAULT_ALERT_ICON_SIZE)
icon:SetPoint("CENTER", contentFrame, "CENTER", 0, 0)
icon:Hide()

-- 提示文字。锚点由 ApplyContentLayout 按图标模式动态设置。
local text = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
text:SetFont(STANDARD_TEXT_FONT, DEFAULT_ALERT_FONT_SIZE, "OUTLINE")
text:SetTextColor(1, 0.12, 0.08, 1)
text:SetShadowColor(0, 0, 0, 1)
text:SetShadowOffset(2, -2)
text:SetPoint("CENTER", contentFrame, "CENTER", 0, 0)
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

local function NormalizeGlowSpeed(value)
    return ClampNumber(value, DEFAULT_ALERT_GLOW_SPEED, 0.2, 3, 1)
end

local function NormalizeIconMode(value)
    if type(value) ~= "string" or not VALID_ALERT_ICON_MODES[value] then
        return DEFAULT_ALERT_ICON_MODE
    end
    return value
end

local function NormalizeIconSize(value)
    return ClampNumber(value, DEFAULT_ALERT_ICON_SIZE, 24, 96)
end

local function NormalizeIconGap(value)
    return ClampNumber(value, DEFAULT_ALERT_ICON_GAP, 0, 40)
end

local FLOAT_PERIOD = 1.5
local FLOAT_UPDATE_INTERVAL = 0.05
-- 所有像素流光共用同一个 20 FPS 调度器。LibCustomGlow 默认会给每个图标挂一个
-- 每帧 OnUpdate；提醒图标一多（补给、职业增益、宠物护理）时，每帧的 SetPoint
-- 调用会成倍增长。集中调度后每帧只跑一次循环，20 FPS 对流光观感几乎没有影响。
local CLASS_GLOW_INTERVAL = 1 / 20
local PIXEL_GLOW_FRAME_KEY = "_PixelGlow" .. ALERT_GLOW_KEY
local classGlowUpdates = {}
local classGlowTime, classGlowElapsed = 0, 0
local animationActive = false
local floatElapsed = 0
local floatUpdateElapsed = 0
local lastFloatOffset, lastContentOffsetX
local contentOffsetX = 0
local floatActive = false
local currentFloatAmplitude = DEFAULT_ALERT_FLOAT_AMPLITUDE
local currentFloatSpeed = DEFAULT_ALERT_FLOAT_SPEED
local currentAlertFontSize = DEFAULT_ALERT_FONT_SIZE
local currentGlowSpeed = DEFAULT_ALERT_GLOW_SPEED
local currentIconMode = DEFAULT_ALERT_ICON_MODE
local currentIconSize = DEFAULT_ALERT_ICON_SIZE
local currentIconGap = DEFAULT_ALERT_ICON_GAP
-- 缓存当前是否处于"显示图标"的布局，供流光判断使用。
local currentLayoutShowsIcon = false
local iconTexturePending = false
local lastMessage = ""
local lastStatusKey = nil
local RefreshAlertVisuals, UpdateFloatingScript, UpdateAlertAnimation
local petCareFrame, petCareIcon, petCareKind, petCareTexture
local petCareDesaturated = false
local supplyFrame, positionLabel
local supplyWidth, supplyIconSize, supplyBadgeHeight = 0, 0, 0
local supplyFirstIconOffset = 0
local ammoFrame, ammoIcon, ammoText
local ammoKind, ammoCount, ammoTexture
local foodFrame, foodLabel
local foodMissing, foodXP
local retailSupplyIcons = {}
local retailSupplyOrder = { "FOOD", "MAIN_HAND", "OFF_HAND", "EARTH_SHIELD", "WATER_SHIELD", "LIGHTNING_SHIELD", "SHIELD", "BATTLE_SHOUT", "ARCANE_INTELLECT", "SKYFURY", "MARK_OF_THE_WILD", "FORTITUDE" }
local foreverSupplyIcons, foreverSupplyItems = {}, {}

do
    supplyFrame = CreateFrame("Frame", "PetStatusAlertSupplyFrame", textFrame)
    supplyFrame:EnableMouse(false)
    supplyFrame:Hide()
    positionLabel = textFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    positionLabel:SetPoint("CENTER")
    positionLabel:Hide()
end

-- Reserve room for the adjacent icons when wrapping the stance text.
local function GetMaxAlertContentWidth()
    local width = UIParent:GetWidth()
    local reserved = (petCareKind and currentIconSize + ALERT_ROW_GAP or 0) + 2 * ALERT_ROW_EDGE_PADDING
    if supplyWidth > 0 then reserved = reserved + supplyWidth + ALERT_ROW_GAP end
    return math.max(160, math.min(width * 0.9, width - reserved))
end

local function ApplyAlertTextColor(statusKey)
    -- 无参调用时同步当前显示中的状态；管理器里改其他状态的颜色时，
    -- 不会把当前告警误染成 UNKNOWN 的颜色。
    statusKey = statusKey or PSA.currentStatusKey
    if statusKey == DISPLAY_SAMPLE then
        text:SetTextColor(PSA.GetDefaultStatusColor())
        return
    end
    local r, g, b, a = GetStatusColor(statusKey or "UNKNOWN", PSA.currentStatusClass)
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

local function GetAlertGlowEnabled()
    return InitDB().alertGlowEnabled ~= false
end

local function RefreshAlertGlowSpeed()
    InitDB()
    currentGlowSpeed = NormalizeGlowSpeed(PetStatusAlertDB.alertGlowSpeed)
    PetStatusAlertDB.alertGlowSpeed = currentGlowSpeed
    return currentGlowSpeed
end

local function RefreshAlertIconMode()
    InitDB()
    currentIconMode = NormalizeIconMode(PetStatusAlertDB.alertIconMode)
    PetStatusAlertDB.alertIconMode = currentIconMode
    return currentIconMode
end

local function RefreshAlertIconSize()
    InitDB()
    currentIconSize = NormalizeIconSize(PetStatusAlertDB.alertIconSize)
    PetStatusAlertDB.alertIconSize = currentIconSize
    icon:SetSize(currentIconSize, currentIconSize)
    return currentIconSize
end

local function RefreshAlertIconGap()
    InitDB()
    currentIconGap = NormalizeIconGap(PetStatusAlertDB.alertIconGap)
    PetStatusAlertDB.alertIconGap = currentIconGap
    return currentIconGap
end

local function SetAlertIconGap(value)
    InitDB()
    currentIconGap = NormalizeIconGap(value)
    PetStatusAlertDB.alertIconGap = currentIconGap
    RefreshAlertVisuals()
    return currentIconGap
end

local function GetAlertIconGap()
    return RefreshAlertIconGap()
end

-- 计算当前状态应使用的布局：返回 showIcon, showText, iconValue
-- 规则：
--   UNKNOWN 状态 / 无图标标识的状态 → 始终只显示文字
--   纯文字模式 → 只显示文字
--   纯图标模式 + 有图标 → 只显示图标
--   图标+文字模式 + 有图标 → 两者都显示
local function ResolveContentLayout(statusKey)
    local iconValue = GetStatusIconSpellID(statusKey)
    local hasIcon = iconValue ~= nil

    if not hasIcon or currentIconMode == "text" then
        return false, true, nil
    end
    if currentIconMode == "icon" then
        return true, false, iconValue
    end
    return true, true, iconValue
end

-- 根据 statusKey 设置 icon/text 锚点和 contentFrame 尺寸。
-- 返回 contentWidth, contentHeight（内容净尺寸，不含 glow padding）。
local function ApplyContentLayout(statusKey)
    -- 防御：从 DB 同步 currentIconMode，修复 RL/重登后图标模式丢失。
    -- 不调用 InitDB（上层 RefreshAlertVisuals/RefreshAlertBoxSize 已初始化 DB），仅做轻量同步。
    if PetStatusAlertDB.alertIconMode then
        currentIconMode = NormalizeIconMode(PetStatusAlertDB.alertIconMode)
    end

    local showIcon, showText, iconValue = ResolveContentLayout(statusKey)
    currentLayoutShowsIcon = showIcon
    iconTexturePending = false

    local maxTextWidth = math.max(80, GetMaxAlertContentWidth() - (showIcon and (currentIconSize + currentIconGap) or 0))

    icon:ClearAllPoints()
    text:ClearAllPoints()

    -- 获取图标纹理。iconValue 由 GetStatusIconSpellID 保证为数字：负数 = 宠物姿态标记，正数 = spellID。
    -- 纯图标模式下若纹理获取失败，回退为纯文字。
    local iconTexture = nil
    if showIcon and iconValue then
        if iconValue < 0 then
            -- 负数 = 宠物姿态，直接使用硬编码纹理路径
            local token = PET_MODE_TOKEN[iconValue]
            if token then
                iconTexture = GetPetModeIconTexture(token)
            end
        else
            iconTexture = GetSpellTextureByID(iconValue)
        end
        if not iconTexture then
            showIcon = false
            showText = true
            currentLayoutShowsIcon = false
            iconTexturePending = true
            -- 图标纹理不可用时回退为纯文字，文字可以使用整行宽度。
            maxTextWidth = math.max(80, GetMaxAlertContentWidth())
        end
    end

    if not showIcon then
        icon:Hide()
        icon:SetTexture(nil)
        text:Show()
        text:SetPoint("CENTER", contentFrame, "CENTER", 0, 0)
        text:SetWidth(maxTextWidth)
        text:SetJustifyH("CENTER")
        if text.SetWordWrap then
            text:SetWordWrap(true)
        end
        local tw = text:GetStringWidth() or 0
        if tw > maxTextWidth then
            tw = maxTextWidth
        end
        local th = text:GetStringHeight() or currentAlertFontSize
        return tw, th
    end

    icon:SetTexture(iconTexture)
    icon:SetSize(currentIconSize, currentIconSize)

    if not showText then
        -- 纯图标：图标居中，流光也居中
        icon:Show()
        text:Hide()
        icon:SetPoint("CENTER", contentFrame, "CENTER", 0, 0)
        return currentIconSize, currentIconSize
    end

    -- 图标在左、文字在右
    icon:Show()
    text:Show()
    icon:SetPoint("LEFT", contentFrame, "LEFT", 0, 0)
    text:SetPoint("LEFT", icon, "RIGHT", currentIconGap, 0)
    text:SetWidth(maxTextWidth)
    -- 设置宽度后必须显式左对齐，否则 FontString 默认居中会把文字推到
    -- 宽框中间，视觉上表现为图标与文字之间出现巨大空白。
    text:SetJustifyH("LEFT")
    if text.SetWordWrap then
        text:SetWordWrap(true)
    end

    local tw = text:GetStringWidth() or 0
    if tw > maxTextWidth then
        tw = maxTextWidth
    end
    local th = text:GetStringHeight() or currentAlertFontSize
    local totalW = currentIconSize + currentIconGap + tw
    local totalH = math.max(currentIconSize, th)
    return totalW, totalH
end

local function ForgetGlowUpdate(frame)
    local glow = frame and frame[PIXEL_GLOW_FRAME_KEY]
    if glow then
        classGlowUpdates[glow] = nil
    end
end

-- 把库自带的每帧 OnUpdate 摘下来，交给统一的 30 FPS 循环。
local function ShareGlowUpdate(frame)
    local glow = frame and frame[PIXEL_GLOW_FRAME_KEY]
    local update = glow and glow.GetScript and glow:GetScript("OnUpdate")
    if not update then return end
    glow:SetScript("OnUpdate", nil)
    classGlowUpdates[glow] = update
end

local function StopAlertGlow()
    ForgetGlowUpdate(glowFrame)
    if LCG and LCG.PixelGlow_Stop then
        LCG.PixelGlow_Stop(glowFrame, ALERT_GLOW_KEY)
    end
    glowFrame:Hide()
    UpdateAlertAnimation()
end

local function ApplyFloatOffset(y)
    if lastContentOffsetX == contentOffsetX and lastFloatOffset and math.abs(y - lastFloatOffset) < 0.05 then
        return
    end
    lastContentOffsetX, lastFloatOffset = contentOffsetX, y
    contentFrame:ClearAllPoints()
    contentFrame:SetPoint("CENTER", textFrame, "CENTER", contentOffsetX, y)
end

local function LayoutAlertRow()
    local hasStance = lastStatusKey ~= nil
    local hasSupply = supplyWidth > 0
    local hasAlert = hasStance or petCareKind ~= nil or hasSupply
    local stanceWidth = hasStance and contentFrame:GetWidth() or 0
    -- Keep the status icon itself at the saved anchor, even with text beside it.
    local stanceLeft = hasStance and currentLayoutShowsIcon and currentIconSize / 2 or stanceWidth / 2
    contentOffsetX = stanceWidth / 2 - stanceLeft
    ApplyFloatOffset(lastFloatOffset or 0)
    UpdateFloatingScript(hasAlert)

    local showPosition = not PetStatusAlertDB.alertLocked and not hasAlert
    positionLabel:SetShown(showPosition)
    if not hasAlert then
        local extra = showPosition and math.max(0, (positionLabel:GetUnboundedStringWidth() + 16 - addonFrame:GetWidth()) / 2) or 0
        addonFrame:SetClampRectInsets(-extra, extra, 0, 0)
        if addonFrame.SetHitRectInsets then
            addonFrame:SetHitRectInsets(-extra, -extra, 0, 0)
        end
        addonFrame:SetShown(showPosition)
        return
    end

    local leftmostPet = hasStance and (currentLayoutShowsIcon and icon or contentFrame) or nil
    local leftReach, rightReach = stanceLeft, stanceWidth - stanceLeft
    if petCareKind then
        petCareFrame:SetSize(currentIconSize, currentIconSize)
        petCareFrame:ClearAllPoints()
        if leftmostPet then
            petCareFrame:SetPoint("RIGHT", leftmostPet, "LEFT", -ALERT_ROW_GAP, 0)
            leftReach = leftReach + ALERT_ROW_GAP + currentIconSize
        else
            petCareFrame:SetPoint("CENTER", contentFrame, "CENTER", 0, 0)
            leftReach, rightReach = currentIconSize / 2, currentIconSize / 2
        end
        leftmostPet = petCareFrame
    end
    if hasSupply then
        supplyFrame:ClearAllPoints()
        if leftmostPet then
            supplyFrame:SetPoint("RIGHT", leftmostPet, "LEFT", -ALERT_ROW_GAP, -supplyBadgeHeight / 2)
            leftReach = leftReach + ALERT_ROW_GAP + supplyWidth
        else
            -- With no pet alert, the first visible icon takes the saved anchor.
            supplyFrame:SetPoint("LEFT", contentFrame, "CENTER", -supplyFirstIconOffset, -supplyBadgeHeight / 2)
            leftReach, rightReach = supplyFirstIconOffset, supplyWidth - supplyFirstIconOffset
        end
    end

    local halfWidth = addonFrame:GetWidth() / 2
    local left = leftReach + ALERT_ROW_EDGE_PADDING - halfWidth
    local right = rightReach + ALERT_ROW_EDGE_PADDING - halfWidth
    local amplitude = floatActive and currentFloatAmplitude or 0
    local halfHeight = math.max(petCareKind and currentIconSize or 0, supplyIconSize,
        hasStance and contentFrame:GetHeight() or 0) / 2
    local bottomReach = math.max(halfHeight, supplyIconSize / 2 + supplyBadgeHeight)
    local space = amplitude + ALERT_ROW_EDGE_PADDING - addonFrame:GetHeight() / 2
    local top, bottom = math.max(0, halfHeight + space), math.max(0, bottomReach + space)
    addonFrame:SetClampRectInsets(-left, right, top, -bottom)
    if addonFrame.SetHitRectInsets then
        addonFrame:SetHitRectInsets(-math.max(0, left), -math.max(0, right), -top, -bottom)
    end
    addonFrame:Show()
end

local function RefreshAlertBoxSize()
    RefreshAlertFontSize()
    RefreshAlertIconSize()

    text:SetFont(STANDARD_TEXT_FONT, currentAlertFontSize, "OUTLINE")
    -- 默认恢复 text 可见；ApplyContentLayout 会按纯图标模式再隐藏。
    text:Show()

    -- 用当前状态键重新计算 icon/text 锚点与内容尺寸。
    local contentWidth, contentHeight = ApplyContentLayout(lastStatusKey)
    contentWidth = tonumber(contentWidth) or 0
    contentHeight = tonumber(contentHeight) or currentAlertFontSize

    local boxWidth = math.min(math.max(math.ceil(contentWidth), 40), GetMaxAlertContentWidth())
    local boxHeight = math.max(math.ceil(contentHeight), currentAlertFontSize + 6)

    contentFrame:SetSize(math.max(contentWidth, 1), math.max(contentHeight, 1))

    -- 流光目标：有图标时只围绕图标，纯文字时围绕文字
    if currentLayoutShowsIcon then
        local glowSize = math.max(math.ceil(currentIconSize), 32)
        glowFrame:SetSize(glowSize, glowSize)
    else
        glowFrame:SetSize(boxWidth, boxHeight)
    end
    LayoutAlertRow()
end

local function OnAlertUpdate(_, elapsed)
    elapsed = tonumber(elapsed) or 0
    if next(classGlowUpdates) then
        classGlowTime = classGlowTime + elapsed
        classGlowElapsed = classGlowElapsed + elapsed
        if classGlowTime >= CLASS_GLOW_INTERVAL then
            classGlowTime = classGlowTime % CLASS_GLOW_INTERVAL
            for glow, update in pairs(classGlowUpdates) do
                update(glow, classGlowElapsed)
            end
            classGlowElapsed = 0
        end
    end
    if not floatActive then return end

    floatElapsed = floatElapsed + elapsed
    floatUpdateElapsed = floatUpdateElapsed + elapsed
    if floatUpdateElapsed < FLOAT_UPDATE_INTERVAL then
        return
    end
    floatUpdateElapsed = 0

    local phase = ((floatElapsed * currentFloatSpeed) / FLOAT_PERIOD) * (math.pi * 2)
    ApplyFloatOffset(math.sin(phase) * currentFloatAmplitude)
end

UpdateAlertAnimation = function()
    local hasClassGlows = next(classGlowUpdates) ~= nil
    if not hasClassGlows then classGlowTime, classGlowElapsed = 0, 0 end
    local active = floatActive or hasClassGlows
    if active == animationActive then return end
    animationActive = active
    addonFrame:SetScript("OnUpdate", active and OnAlertUpdate or nil)
end

UpdateFloatingScript = function(hasAlert)
    local active = hasAlert and currentFloatAmplitude > 0 and currentFloatSpeed > 0
    if active == floatActive then return end

    floatActive = active
    floatUpdateElapsed = 0
    UpdateAlertAnimation()
    if not active then
        floatElapsed = 0
        if lastFloatOffset ~= 0 then
            lastFloatOffset = nil
            ApplyFloatOffset(0)
        end
    end
end

local function StartIconGlow(frame, frameLevel)
    local length = math.max(8, math.floor(currentAlertFontSize * 0.38 + 0.5))
    local frequency = 0.2 * RefreshAlertGlowSpeed()
    LCG.PixelGlow_Start(frame, DEFAULT_ALERT_GLOW_COLOR, 8, frequency, length, 2, 0, 0, false, ALERT_GLOW_KEY, frameLevel)
end

local function StartAlertGlow()
    local setting = InitDB().alertGlowEnabled
    local enabled = setting == true or (setting == nil and (lastStatusKey == "PASSIVE" or lastStatusKey == "DEFENSIVE" or lastStatusKey == DISPLAY_SAMPLE))

    StopAlertGlow()
    if not enabled or not lastStatusKey or text:GetText() == "" or not currentLayoutShowsIcon
        or not LCG or not LCG.PixelGlow_Start then
        return
    end

    -- frameLevel 必须超过 icon 所在 contentFrame 的层级（textFrame = glowFrame+20），
    -- 否则流光渲染在图标背面。glowFrame level=2，icon 层≈22，故用 25。
    glowFrame:Show()
    -- 直接锚定到 icon 纹理上，尺寸跟随图标，位置自动对齐（浮动动画自动跟随）
    glowFrame:ClearAllPoints()
    glowFrame:SetPoint("CENTER", icon, "CENTER", 0, 0)
    StartIconGlow(glowFrame, 25)
    ShareGlowUpdate(glowFrame)
    UpdateAlertAnimation()
end

local function RefreshAccessoryGlow(frame, active)
    if not frame or not LCG or not LCG.PixelGlow_Start then
        return
    end
    ForgetGlowUpdate(frame)
    LCG.PixelGlow_Stop(frame, ALERT_GLOW_KEY)
    if active and GetAlertGlowEnabled() then
        StartIconGlow(frame)
        -- The bundled glow library attaches its frame under this key. If a
        -- different installed version doesn't expose it, the library keeps its
        -- own OnUpdate and the glow still animates.
        ShareGlowUpdate(frame)
    end
    UpdateAlertAnimation()
end

local function CreateSupplyBadge(frame)
    local label = frame:CreateFontString(nil, "OVERLAY")
    label:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    label:SetHeight(SUPPLY_BADGE_HEIGHT)
    label:SetJustifyH("CENTER")
    label:SetWordWrap(false)
    label:SetPoint("TOP", frame, "BOTTOM", 0, -SUPPLY_BADGE_GAP)
    frame.supplyLabel = label
    return label
end

local function LayoutSupplyRow(updateBoxes)
    local moving = not PetStatusAlertDB.alertLocked
    local items = {}
    if isForever then
        if ammoKind then items[#items + 1] = ammoFrame end
        if foodMissing then items[#items + 1] = foodFrame end
        for _, button in ipairs(foreverSupplyItems) do items[#items + 1] = button end
    else
        for _, key in ipairs(retailSupplyOrder) do
            local button = retailSupplyIcons[key]
            if button and button.active then items[#items + 1] = button end
        end
    end
    local count = #items
    local previousWidth = supplyWidth
    supplyWidth, supplyIconSize, supplyBadgeHeight = 0, 0, 0
    if count > 0 then
        -- Leave room for the pet status and care icon even if they appear later.
        local screen = UIParent:GetWidth()
        local reserve = math.min(screen * 0.50, math.max(220, currentIconSize + currentIconGap + 80)
            + (isForever and currentIconSize + ALERT_ROW_GAP or 0))
        local width = screen - reserve - 4 * ALERT_ROW_EDGE_PADDING - count * ALERT_ROW_GAP
        local maxCellWidth = math.max(1, width / count)
        local size = math.min(currentIconSize, maxCellWidth)
        local x, badgeHeight = ALERT_ROW_EDGE_PADDING, 0
        for index, item in ipairs(items) do
            local cellWidth = size
            local label = item.supplyLabel
            if label and label:IsShown() then
                local labelWidth = item == foodFrame and math.ceil(label:GetUnboundedStringWidth()) + 2 or SUPPLY_NUMERIC_WIDTH
                cellWidth = math.min(maxCellWidth, math.max(size, labelWidth))
                label:SetWidth(cellWidth)
                badgeHeight = SUPPLY_BADGE_GAP + SUPPLY_BADGE_HEIGHT
            end
            item:SetSize(size, size)
            item:ClearAllPoints()
            local center = x + cellWidth / 2
            if index == 1 then supplyFirstIconOffset = center end
            item:SetPoint("TOP", supplyFrame, "TOPLEFT", center, -ALERT_ROW_EDGE_PADDING)
            if item.alertKey then item:EnableMouse(not moving) end
            x = x + cellWidth + ALERT_ROW_GAP
        end
        supplyWidth = x - ALERT_ROW_GAP + ALERT_ROW_EDGE_PADDING
        supplyIconSize, supplyBadgeHeight = size, badgeHeight
        supplyFrame:SetSize(supplyWidth, size + badgeHeight + 2 * ALERT_ROW_EDGE_PADDING)
    end
    supplyFrame:SetShown(count > 0)
    if updateBoxes or (lastStatusKey and supplyWidth ~= previousWidth) then
        RefreshAlertBoxSize()
    else
        LayoutAlertRow()
    end
end

local function RefreshAmmoTooltip(frame)
    local tooltip = GameTooltip
    if ammoKind and tooltip and not tooltip:IsForbidden() and tooltip:IsOwned(frame) then
        tooltip:SetText(PSA.UI[ammoKind]:format(ammoCount))
        tooltip:Show()
    end
end

local function HideAmmoTooltip(frame)
    if GameTooltip and not GameTooltip:IsForbidden() and GameTooltip:IsOwned(frame) then
        GameTooltip:Hide()
    end
end

local function ShowRetailSupplyTooltip(button)
    if not GameTooltip or GameTooltip:IsForbidden() then return end
    local label, hint = PSA.GetRetailSupplyTooltip(button.alertKey)
    if not label then return end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(label)
    if hint then GameTooltip:AddLine(hint, 0.8, 0.8, 0.8, true) end
    GameTooltip:Show()
end

local function CreateRetailSupplyIcon(key)
    local button = CreateFrame("Button", nil, supplyFrame, "InsecureActionButtonTemplate")
    button.alertKey = key
    button.isRetailClassBuff = key ~= "FOOD" and key ~= "MAIN_HAND" and key ~= "OFF_HAND"
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints(button)
    button:RegisterForClicks("LeftButtonUp")
    button:SetAttribute("useOnKeyDown", false)
    button:SetAttribute("unit1", "player")
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:SetScript("PreClick", function(self)
        if InCombatLockdown() or not InitDB().alertLocked then return end
        local spell = PSA.ActivateRetailSupplyAlert(self.alertKey)
        if spell then
            self:SetAttribute("spell1", spell)
            self:SetAttribute("type1", "spell")
        end
    end)
    button:SetScript("PostClick", function(self)
        self:SetAttribute("type1", nil)
        self:SetAttribute("spell1", nil)
    end)
    button:SetScript("OnEnter", ShowRetailSupplyTooltip)
    button:SetScript("OnLeave", HideAmmoTooltip)
    button:SetScript("OnHide", HideAmmoTooltip)
    retailSupplyIcons[key] = button
    return button
end

local supplyTimeFormatter
local function ApplyRetailSupplyCountdown(button, expiration, lead)
    if expiration == button.expiration and lead == button.lead then return end
    button.expiration, button.lead = expiration, lead
    local binding = button.timeBinding
    if not expiration then
        if binding then
            binding:SetEnabled(false)
            button.timeText:Hide()
        end
        return
    end
    if not binding then
        if not (C_DurationUtil and C_DurationUtil.CreateDuration and C_DurationUtil.CreateDurationTextBinding) then return end
        local text = CreateSupplyBadge(button)
        button.timeText = text
        button.duration = C_DurationUtil.CreateDuration()
        binding = C_DurationUtil.CreateDurationTextBinding()
        binding:SetFontString(text)
        binding:SetDuration(button.duration)
        if not supplyTimeFormatter and C_StringUtil and C_StringUtil.CreateSecondsFormatter then
            supplyTimeFormatter = C_StringUtil.CreateSecondsFormatter()
            supplyTimeFormatter:SetDefaultAbbreviation(Enum.SecondsFormatterAbbreviation.OneLetter)
            supplyTimeFormatter:SetDesiredUnitCount(1)
        end
        if supplyTimeFormatter then binding:SetFormatter(supplyTimeFormatter) end
        button.timeBinding = binding
    end
    button.duration:SetTimeFromEnd(expiration, lead)
    binding:SetEnabled(true)
    button.timeText:Show()
end

function PSA.RenderRetailSupplyAlerts(alerts)
    if isForever then return end
    if not PSA.GetBuffAlertsEnabled() then
        alerts = {}
    end
    local layoutChanged
    local newlyActive
    for _, key in ipairs(retailSupplyOrder) do
        local alert, button = alerts[key], retailSupplyIcons[key]
        if alert then
            button = button or CreateRetailSupplyIcon(key)
            if button.texture ~= alert.icon then
                button.texture = alert.icon
                button.icon:SetTexture(alert.icon)
            end
            if not button.active then
                button.active = true
                button:Show()
                layoutChanged = true
                newlyActive = newlyActive or {}
                newlyActive[#newlyActive + 1] = button
            end
            local hadCountdown = button.timeText and button.timeText:IsShown()
            ApplyRetailSupplyCountdown(button, alert.expiration, alert.lead)
            if hadCountdown ~= (button.timeText and button.timeText:IsShown()) then layoutChanged = true end
            if GameTooltip and not GameTooltip:IsForbidden() and GameTooltip:IsOwned(button) then
                ShowRetailSupplyTooltip(button)
            end
        elseif button and button.active then
            button.active = false
            ApplyRetailSupplyCountdown(button)
            RefreshAccessoryGlow(button, false)
            button:Hide()
            layoutChanged = true
        end
    end
    if layoutChanged then LayoutSupplyRow() end
    if newlyActive then
        for _, button in ipairs(newlyActive) do RefreshAccessoryGlow(button, true) end
    end
end

-- Personal Forever class alerts are indicators only; food and ammo retain their own behavior.
function PSA.RenderForeverClassBuffAlerts(alerts)
    if not isForever then return end
    if #foreverSupplyItems == 0 and #alerts == 0 then return end
    if not PSA.GetBuffAlertsEnabled() then alerts = {} end
    for _, button in ipairs(foreverSupplyItems) do button.pending = false end
    local layoutChanged
    for index, alert in ipairs(alerts) do
        local button = foreverSupplyIcons[alert.key]
        if not button then
            button = CreateFrame("Frame", nil, supplyFrame)
            button:Hide()
            button.classBuffKey = alert.key
            button.icon = button:CreateTexture(nil, "ARTWORK")
            button.icon:SetAllPoints(button)
            foreverSupplyIcons[alert.key] = button
        end
        button.pending = true
        if foreverSupplyItems[index] ~= button then layoutChanged = true end
        local texture = GetSpellTextureByID(alert.spell) or 134400
        if texture ~= button.texture then
            button.texture = texture
            button.icon:SetTexture(texture)
        end
    end
    for _, button in ipairs(foreverSupplyItems) do
        if not button.pending then
            RefreshAccessoryGlow(button, false)
            button:Hide()
            layoutChanged = true
        end
    end
    if not layoutChanged then return end
    for index = #foreverSupplyItems, 1, -1 do foreverSupplyItems[index] = nil end
    for index, alert in ipairs(alerts) do
        local button = foreverSupplyIcons[alert.key]
        foreverSupplyItems[index] = button
        if not button:IsShown() then
            button.needsGlow = true
            button:Show()
        end
    end
    LayoutSupplyRow()
    for _, button in ipairs(foreverSupplyItems) do
        if button.needsGlow then
            button.needsGlow = nil
            RefreshAccessoryGlow(button, true)
        end
    end
end

local function UpdateAmmoText()
    ammoText:SetText(tostring(ammoCount))
    RefreshAmmoTooltip(ammoFrame)
end

function PSA.SetAmmoAlert(kind, count, texture)
    if not isForever then return end
    if not PSA.GetBuffAlertsEnabled() then
        kind, count, texture = nil, nil, nil
    end
    if not supplyFrame or (kind == ammoKind and count == ammoCount and texture == ammoTexture) then
        return
    end
    local textureChanged = texture ~= ammoTexture
    ammoKind, ammoCount, ammoTexture = kind, count, texture
    if not kind then
        RefreshAccessoryGlow(ammoFrame, false)
        ammoFrame:Hide()
        LayoutSupplyRow()
        return
    end
    if not ammoFrame then
        ammoFrame = CreateFrame("Frame", nil, supplyFrame)
        ammoFrame:Hide()
        ammoFrame:SetMouseMotionEnabled(PetStatusAlertDB.alertLocked)
        ammoIcon = ammoFrame:CreateTexture(nil, "ARTWORK")
        ammoIcon:SetAllPoints(ammoFrame)
        ammoText = CreateSupplyBadge(ammoFrame)
        ammoText:SetTextColor(1, 0.72, 0.2)
        ammoFrame:SetScript("OnEnter", function(self)
            if GameTooltip and not GameTooltip:IsForbidden() then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                RefreshAmmoTooltip(self)
            end
        end)
        ammoFrame:SetScript("OnLeave", HideAmmoTooltip)
        ammoFrame:SetScript("OnHide", HideAmmoTooltip)
    end
    local wasShown = ammoFrame:IsShown()
    if textureChanged or not wasShown then
        ammoIcon:SetTexture(texture)
    end
    UpdateAmmoText()
    if not wasShown then
        ammoFrame:Show()
        LayoutSupplyRow()
        RefreshAccessoryGlow(ammoFrame, true)
    end
end

local function UpdateFoodLabel()
    foodLabel:SetText(foodXP and PSA.UI.FOOD_BUFF_XP or PSA.UI.FOOD_BUFF_MISSING)
end

function PSA.RefreshFoodPicker()
    if PSA.SetFoodPickerOwner then
        PSA.SetFoodPickerOwner(foodMissing and PSA.GetBuffAlertsEnabled()
            and PetStatusAlertDB.alertLocked and foodFrame or nil)
    end
end

function PSA.SetFoodBuffAlert(missing, showXP)
    if not isForever then return end
    if not PSA.GetBuffAlertsEnabled() then
        missing, showXP = nil, nil
    end
    if not supplyFrame or (foodMissing == missing and foodXP == showXP) then return end
    local visibilityChanged = (not not foodMissing) ~= (not not missing)
    foodMissing, foodXP = missing, showXP
    if missing then
        if not foodFrame then
            foodFrame = CreateFrame("Frame", nil, supplyFrame)
            local texture = foodFrame:CreateTexture(nil, "ARTWORK")
            texture:SetAllPoints(foodFrame)
            texture:SetTexture(136000)
            foodLabel = CreateSupplyBadge(foodFrame)
        end
        UpdateFoodLabel()
        foodFrame:Show()
    elseif foodFrame then
        foodFrame:Hide()
    end
    LayoutSupplyRow()
    if visibilityChanged then RefreshAccessoryGlow(foodFrame, foodMissing) end
    PSA.RefreshFoodPicker()
end

function PSA.RefreshSupplyAlertLabels()
    positionLabel:SetText(PSA.UI.PET_ALERTS_POSITION)
    if ammoKind then UpdateAmmoText() end
    if foodMissing then UpdateFoodLabel() end
    LayoutSupplyRow()
end

function PSA.GetPetCareFrame()
    if not petCareFrame then
        petCareFrame = CreateFrame("Frame", nil, textFrame)
        petCareFrame:SetFrameStrata(ALERT_STRATA_DEFAULT)
        petCareFrame:Hide()
        petCareIcon = petCareFrame:CreateTexture(nil, "ARTWORK")
        petCareIcon:SetAllPoints(petCareFrame)
    end
    return petCareFrame
end

function PSA.SetPetCareAlert(kind, texture, desaturated)
    if not isForever then return end
    if not PSA.GetPetAlertsEnabled() then
        kind, texture, desaturated = nil, nil, false
    end
    if kind == nil and not petCareFrame then return end
    desaturated = not not desaturated
    if kind == petCareKind and texture == petCareTexture and desaturated == petCareDesaturated then
        return
    end
    local kindChanged = kind ~= petCareKind
    local visibilityChanged = (kind == nil) ~= (petCareKind == nil)
    petCareKind, petCareTexture, petCareDesaturated = kind, texture, desaturated
    if kind == "unhappy" then
        PSA.GetPetCareFrame()
        petCareIcon:SetAtlas("UI-PetMad")
        petCareIcon:SetDesaturated(false)
        petCareFrame:Show()
    elseif kind == "feed" then
        PSA.GetPetCareFrame()
        petCareIcon:SetTexture(texture)
        petCareIcon:SetTexCoord(0, 1, 0, 1)
        petCareIcon:SetDesaturated(desaturated)
        petCareFrame:Show()
    else
        petCareFrame:Hide()
    end
    if kindChanged then
        if visibilityChanged then
            RefreshAlertBoxSize()
        else
            LayoutAlertRow()
        end
        RefreshAccessoryGlow(petCareFrame, petCareKind)
    end
end

RefreshAlertVisuals = function()
    RefreshAlertFloatAmplitude()
    RefreshAlertFloatSpeed()
    RefreshAlertIconMode()
    RefreshAlertIconGap()
    RefreshAlertFontSize()
    RefreshAlertIconSize()
    LayoutSupplyRow(true)
    if lastStatusKey then
        StartAlertGlow()
    end
    RefreshAccessoryGlow(petCareFrame, petCareKind)
    RefreshAccessoryGlow(ammoFrame, ammoKind)
    RefreshAccessoryGlow(foodFrame, foodMissing)
    for _, button in pairs(retailSupplyIcons) do
        if button.active then RefreshAccessoryGlow(button, true) end
    end
    for _, button in ipairs(foreverSupplyItems) do RefreshAccessoryGlow(button, true) end
    if PSA.RefreshCombatTTSReminder then
        PSA.RefreshCombatTTSReminder(true)
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
    PetStatusAlertDB.alertGlowEnabled = not not enabled
    RefreshAlertVisuals()
    return PetStatusAlertDB.alertGlowEnabled
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

local function SetAlertIconMode(value)
    InitDB()
    currentIconMode = NormalizeIconMode(value)
    PetStatusAlertDB.alertIconMode = currentIconMode
    -- RefreshAlertVisuals → RefreshAlertBoxSize → ApplyContentLayout(lastStatusKey)
    -- 会用新模式重新计算 icon/text 锚点与纹理，无需再单独调用 ShowStatus。
    RefreshAlertVisuals()
    return currentIconMode
end

local function GetAlertIconMode()
    return RefreshAlertIconMode()
end

local function SetAlertIconSize(value)
    InitDB()
    currentIconSize = NormalizeIconSize(value)
    PetStatusAlertDB.alertIconSize = currentIconSize
    RefreshAlertVisuals()
    return currentIconSize
end

local function GetAlertIconSize()
    return RefreshAlertIconSize()
end

RefreshAlertVisuals()
PSA.currentStatusKey = nil
PSA.currentStatusForce = false

local function PlaceAlert(frame, pos, defaultY)
    frame:ClearAllPoints()
    frame:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", tonumber(pos.x) or 0, tonumber(pos.y) or defaultY)
end

local function ApplyAlertPosition()
    local db = InitDB()
    PlaceAlert(addonFrame, db.alertPosition, 220)
end

function PSA.ResetAlertPositions()
    local db = InitDB()
    db.alertPosition = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 220 }
    ApplyAlertPosition()
end

local function SetAlertPositionLocked(locked)
    local db = InitDB()
    db.alertLocked = not not locked
    addonFrame:EnableMouse(not db.alertLocked)
    if ammoFrame then ammoFrame:SetMouseMotionEnabled(db.alertLocked) end
    if PSA.SetPetFeedMouseEnabled then PSA.SetPetFeedMouseEnabled(db.alertLocked) end
    SetAlertStrata(PSA.currentStatusForce and ALERT_STRATA_PREVIEW or ALERT_STRATA_DEFAULT)
    PSA.RefreshSupplyAlertLabels()
    PSA.RefreshFoodPicker()
end

local function SetDragHandlers(frame, positionKey, defaultY)
    frame:SetScript("OnDragStart", function(self)
        if not InitDB().alertLocked then self:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint(1)
        InitDB()[positionKey] = {
            point = point or "CENTER",
            relativePoint = relativePoint or "CENTER",
            x = tonumber(x) or 0,
            y = tonumber(y) or defaultY,
        }
    end)
end

SetDragHandlers(addonFrame, "alertPosition", 220)

ApplyAlertPosition()
SetAlertPositionLocked(PetStatusAlertDB.alertLocked)

local function SetMessage(message, statusKey, classFile)
    message = tostring(message or "")
    local changed = message ~= lastMessage or statusKey ~= lastStatusKey or classFile ~= PSA.currentStatusClass
    PSA.currentStatusKey = statusKey
    PSA.currentStatusClass = classFile
    ApplyAlertTextColor(statusKey)

    -- 图标尚未就绪时，同一状态也需要重新布局；加载成功后恢复快速路径。
    local retryIconTexture = iconTexturePending
    if changed or retryIconTexture then
        lastMessage = message
        lastStatusKey = statusKey
        text:SetText(message)
        RefreshAlertBoxSize()
    end
    return changed or (retryIconTexture and not iconTexturePending)
end

local HideStatus

local function ShowStatus(statusKey, force, classFile)
    if not PSA.GetPetAlertsEnabled() then
        HideStatus(true)
        return
    end
    if displayPreview and not force then return end
    displayPreview = nil
    classFile = (force and classFile) or GetPlayerClassFile()
    if not force and not IsStatusEnabled(statusKey, classFile) then
        HideStatus()
        return
    end

    -- 预览（设置面板/管理器）时提升到面板之上；真实状态恢复默认层级。
    SetAlertStrata(force and ALERT_STRATA_PREVIEW or ALERT_STRATA_DEFAULT)

    PSA.currentStatusForce = force and true or false
    local changed = SetMessage(GetDisplayMessage(statusKey, classFile), statusKey, classFile)

    if changed then
        StartAlertGlow()
    end

    if PSA.RefreshCombatTTSReminder then
        PSA.RefreshCombatTTSReminder(changed)
    end
end

local function PreviewStatus(statusKey, classFile)
    if classFile then
        for _, key in ipairs(PSA.GetClassAlertStatuses(classFile) or {}) do
            if key == statusKey then
                ShowStatus(statusKey, true, classFile)
                return
            end
        end
    else
        ShowStatus(statusKey, true)
    end
end

HideStatus = function(force)
    if displayPreview and not force then return end
    displayPreview = nil
    SetAlertStrata(ALERT_STRATA_DEFAULT)

    if not lastStatusKey and lastMessage == "" then
        if PSA.StopCombatTTSReminder then
            PSA.StopCombatTTSReminder()
        end
        return
    end

    PSA.currentStatusKey = nil
    PSA.currentStatusForce = false
    SetMessage("", nil)
    icon:Hide()
    StopAlertGlow()
    if PSA.StopCombatTTSReminder then
        PSA.StopCombatTTSReminder()
    end
end

function PSA.PreviewDisplay()
    if not PSA.GetPetAlertsEnabled() then return end
    displayPreview = true
    PSA.currentStatusForce = true
    SetAlertStrata(ALERT_STRATA_PREVIEW)
    SetMessage(PSA.UI.PREVIEW_SAMPLE, DISPLAY_SAMPLE)
    StartAlertGlow()
    if PSA.StopCombatTTSReminder then PSA.StopCombatTTSReminder() end
end

function PSA.IsDisplayPreviewActive()
    return displayPreview == true
end


-------------------------------------------------
-- Public alert frame API
-------------------------------------------------

PSA.addonFrame = addonFrame
PSA.alertText = text
PSA.ApplyAlertTextColor = ApplyAlertTextColor
PSA.ApplyAlertPosition = ApplyAlertPosition
PSA.SetAlertPositionLocked = SetAlertPositionLocked
PSA.GetAlertFontSize = GetAlertFontSize
PSA.SetAlertFontSize = SetAlertFontSize
PSA.GetAlertFloatAmplitude = GetAlertFloatAmplitude
PSA.SetAlertFloatAmplitude = SetAlertFloatAmplitude
PSA.GetAlertFloatSpeed = GetAlertFloatSpeed
PSA.SetAlertFloatSpeed = SetAlertFloatSpeed
PSA.GetAlertGlowEnabled = GetAlertGlowEnabled
PSA.SetAlertGlowEnabled = SetAlertGlowEnabled
PSA.GetAlertGlowSpeed = GetAlertGlowSpeed
PSA.SetAlertGlowSpeed = SetAlertGlowSpeed
PSA.GetAlertIconMode = GetAlertIconMode
PSA.SetAlertIconMode = SetAlertIconMode
PSA.GetAlertIconSize = GetAlertIconSize
PSA.SetAlertIconSize = SetAlertIconSize
-- Get/SetAlertIconGap 供新版 Options 的图标间距滑条调用。
PSA.GetAlertIconGap = GetAlertIconGap
PSA.SetAlertIconGap = SetAlertIconGap
PSA.RefreshAlertVisuals = RefreshAlertVisuals
-- RegisterStatusIcon 供 WarriorLogic 等扩展模块注册状态图标映射。
PSA.RegisterStatusIcon = RegisterStatusIcon
PSA.ShowStatus = ShowStatus
PSA.PreviewStatus = PreviewStatus
PSA.HideStatus = HideStatus
