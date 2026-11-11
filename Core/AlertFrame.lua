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

-- 内容层：textFrame 作为层级容器（始终覆盖 addonFrame）。
-- contentFrame 是浮动层，承载 icon 和 text，跟随浮动动画整体上下移动。
-- 这样布局（icon/text 相对位置）与浮动（整体 Y 偏移）完全解耦。
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
local floatElapsed = 0
local floatUpdateElapsed = 0
local lastFloatOffset, lastContentOffsetX
local contentOffsetX = 0
local floatingFrame
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
local RefreshAlertVisuals
local petCareFrame, petCareIcon, petCareKind, petCareTexture
local petCareDesaturated = false
local ammoFrame, ammoIcon, ammoText, ammoLabel
local ammoKind, ammoCount, ammoTexture
local ammoLabelWidth = 0

-- Reserve space for the active accessory icons when wrapping the stance text.
local function GetMaxAlertContentWidth()
    local width = UIParent:GetWidth()
    local accessoryCount = (petCareKind and 1 or 0) + (ammoKind and 1 or 0)
    local reserved = accessoryCount * (currentIconSize + ALERT_ROW_GAP) + 2 * ALERT_ROW_EDGE_PADDING
    if ammoKind then
        reserved = reserved + ammoLabelWidth + currentIconGap
    end
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

local function StopAlertGlow()
    if LCG and LCG.PixelGlow_Stop then
        LCG.PixelGlow_Stop(glowFrame, ALERT_GLOW_KEY)
    end
    glowFrame:Hide()
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
    local stanceWidth = lastStatusKey and contentFrame:GetWidth() or 0
    local centeredIcon = isForever and lastStatusKey and currentLayoutShowsIcon
    -- In Forever the stance icon shares the saved center with standalone accessory icons.
    local stanceLeft = centeredIcon and currentIconSize / 2 or stanceWidth / 2
    contentOffsetX = stanceWidth / 2 - stanceLeft
    ApplyFloatOffset(lastFloatOffset or 0)

    if not petCareKind and not ammoKind and not centeredIcon then
        addonFrame:SetClampRectInsets(0, 0, 0, 0)
        addonFrame:SetShown(lastStatusKey ~= nil)
        return
    end

    local anchor = lastStatusKey and contentFrame or nil
    local leftReach = anchor and stanceLeft or currentIconSize / 2
    local rightReach = anchor and stanceWidth - stanceLeft or currentIconSize / 2
    if petCareKind then
        petCareFrame:SetSize(currentIconSize, currentIconSize)
        petCareFrame:ClearAllPoints()
        if anchor then
            petCareFrame:SetPoint("RIGHT", currentLayoutShowsIcon and icon or anchor, "LEFT", -ALERT_ROW_GAP, 0)
            leftReach = leftReach + ALERT_ROW_GAP + currentIconSize
        else
            petCareFrame:SetPoint("CENTER", contentFrame, "CENTER", 0, 0)
        end
        anchor = petCareFrame
    end
    if ammoKind then
        ammoFrame:SetSize(currentIconSize, currentIconSize)
        ammoFrame:ClearAllPoints()
        if anchor then
            ammoFrame:SetPoint("RIGHT", anchor, "LEFT", -ALERT_ROW_GAP, 0)
            leftReach = leftReach + ALERT_ROW_GAP + currentIconSize
        else
            ammoFrame:SetPoint("CENTER", contentFrame, "CENTER", 0, 0)
        end
        ammoLabel:ClearAllPoints()
        ammoLabel:SetPoint("RIGHT", ammoFrame, "LEFT", -currentIconGap, 0)
        leftReach = leftReach + ammoLabelWidth + currentIconGap
    end

    local halfWidth = addonFrame:GetWidth() / 2
    local left = leftReach + ALERT_ROW_EDGE_PADDING - halfWidth
    local right = rightReach + ALERT_ROW_EDGE_PADDING - halfWidth
    local amplitude = (lastStatusKey or petCareKind == "unhappy") and currentFloatAmplitude or 0
    local rowHeight = math.max(currentIconSize, lastStatusKey and contentFrame:GetHeight() or 0,
        ammoKind and ammoLabel:GetStringHeight() or 0)
    local vertical = math.max(0, rowHeight / 2 + amplitude + ALERT_ROW_EDGE_PADDING - addonFrame:GetHeight() / 2)
    addonFrame:SetClampRectInsets(-left, right, vertical, -vertical)
    addonFrame:Show()
end

local function RefreshAlertBoxSize()
    RefreshAlertFontSize()
    RefreshAlertIconSize()

    text:SetFont(STANDARD_TEXT_FONT, currentAlertFontSize, "OUTLINE")
    if ammoKind then
        ammoLabel:SetFont(STANDARD_TEXT_FONT, currentAlertFontSize, "OUTLINE")
        ammoLabelWidth = math.max(1, math.min(math.ceil(ammoLabel:GetUnboundedStringWidth()), UIParent:GetWidth() / 3))
        ammoLabel:SetWidth(ammoLabelWidth)
    end
    -- 默认恢复 text 可见；ApplyContentLayout 会按纯图标模式再隐藏。
    text:Show()

    -- 用当前状态键重新计算 icon/text 锚点与内容尺寸。
    local contentWidth, contentHeight = ApplyContentLayout(lastStatusKey)
    contentWidth = tonumber(contentWidth) or 0
    contentHeight = tonumber(contentHeight) or currentAlertFontSize

    local boxWidth = math.min(math.max(math.ceil(contentWidth), 40), GetMaxAlertContentWidth())
    local boxHeight = math.max(math.ceil(contentHeight), currentAlertFontSize + 6)

    addonFrame:SetSize(math.max(boxWidth, 80), math.max(boxHeight, 32))
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
    local nextFrame
    if currentFloatAmplitude > 0 and currentFloatSpeed > 0 then
        if lastStatusKey then
            nextFrame = addonFrame
        elseif petCareKind == "unhappy" then
            nextFrame = petCareFrame
        end
    end

    if nextFrame ~= floatingFrame then
        if floatingFrame then
            floatingFrame:SetScript("OnUpdate", nil)
        end
        floatingFrame = nextFrame
        floatUpdateElapsed = 0
        if nextFrame then
            nextFrame:SetScript("OnUpdate", OnAlertUpdate)
        end
    end

    if not nextFrame then
        floatElapsed = 0
        ApplyFloatOffset(0)
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
end

local function RefreshAccessoryGlow(frame, active)
    if not frame or not LCG or not LCG.PixelGlow_Start then
        return
    end
    LCG.PixelGlow_Stop(frame, ALERT_GLOW_KEY)
    if active and GetAlertGlowEnabled() then
        StartIconGlow(frame)
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

local function UpdateAmmoText()
    local label = PSA.UI[ammoKind .. "_LABEL"]
    local labelChanged = ammoLabel:GetText() ~= label
    if labelChanged then
        ammoLabel:SetText(label)
    end
    ammoText:SetText(tostring(ammoCount))
    RefreshAmmoTooltip(ammoFrame)
    return labelChanged
end

function PSA.RefreshAmmoAlertText()
    if ammoKind and UpdateAmmoText() then
        RefreshAlertBoxSize()
    end
end

function PSA.SetAmmoAlert(kind, count, texture)
    if kind == ammoKind and count == ammoCount and texture == ammoTexture then
        return
    end
    local textureChanged = texture ~= ammoTexture
    ammoKind, ammoCount, ammoTexture = kind, count, texture
    if not kind then
        RefreshAccessoryGlow(ammoFrame, false)
        ammoFrame:Hide()
        RefreshAlertBoxSize()
        return
    end
    if not ammoFrame then
        ammoFrame = CreateFrame("Frame", nil, textFrame)
        ammoFrame:Hide()
        ammoFrame:SetFrameStrata(ALERT_STRATA_DEFAULT)
        ammoFrame:SetMouseMotionEnabled(true)
        ammoIcon = ammoFrame:CreateTexture(nil, "ARTWORK")
        ammoIcon:SetAllPoints(ammoFrame)
        ammoText = ammoFrame:CreateFontString(nil, "OVERLAY")
        ammoText:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
        ammoText:SetTextColor(1, 0.72, 0.2)
        ammoText:SetPoint("BOTTOMRIGHT", ammoFrame, "BOTTOMRIGHT", -2, 2)
        ammoLabel = ammoFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        ammoLabel:SetTextColor(1, 0.72, 0.2)
        ammoLabel:SetJustifyH("RIGHT")
        ammoLabel:SetWordWrap(true)
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
    local labelChanged = UpdateAmmoText()
    if not wasShown or labelChanged then
        RefreshAlertBoxSize()
    end
    if not wasShown then
        ammoFrame:Show()
        RefreshAccessoryGlow(ammoFrame, true)
    end
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
        UpdateFloatingScript()
    end
end

RefreshAlertVisuals = function()
    RefreshAlertFloatAmplitude()
    RefreshAlertFloatSpeed()
    RefreshAlertIconMode()
    RefreshAlertIconGap()
    RefreshAlertBoxSize()
    UpdateFloatingScript()
    if lastStatusKey then
        StartAlertGlow()
    end
    RefreshAccessoryGlow(petCareFrame, petCareKind)
    RefreshAccessoryGlow(ammoFrame, ammoKind)
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

    UpdateFloatingScript()
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
    UpdateFloatingScript()
    if PSA.StopCombatTTSReminder then
        PSA.StopCombatTTSReminder()
    end
end

function PSA.PreviewDisplay()
    displayPreview = true
    PSA.currentStatusForce = true
    SetAlertStrata(ALERT_STRATA_PREVIEW)
    SetMessage(PSA.UI.PREVIEW_SAMPLE, DISPLAY_SAMPLE)
    UpdateFloatingScript()
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
