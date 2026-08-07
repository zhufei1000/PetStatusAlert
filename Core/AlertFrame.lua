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
local DEFAULT_ALERT_ICON_MODE = PSA.DEFAULT_ALERT_ICON_MODE or "text"
local DEFAULT_ALERT_ICON_SIZE = PSA.DEFAULT_ALERT_ICON_SIZE or 48
local DEFAULT_ALERT_ICON_GAP = PSA.DEFAULT_ALERT_ICON_GAP or 10
local VALID_ALERT_ICON_MODES = PSA.VALID_ALERT_ICON_MODES or { text = true, icon = true, both = true }
local ALERT_GLOW_KEY = "PetStatusAlert_Glow"

local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)

-------------------------------------------------
-- 状态图标标识
-- 正数 = spellID，通过 C_Spell.GetSpellTexture 获取图标。
-- 负数 = 宠物姿态：-1=PET_MODE_PASSIVE, -2=PET_MODE_DEFENSIVE，从宠物动作栏动态获取图标。
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
}

-- 宠物姿态图标的固定纹理路径（WoW 内置常量，跨版本不变）。
-- 不依赖宠物是否存在、不依赖 PetActionButton UI 对象、不依赖 GetPetActionInfo 返回值。
-- 这样 RL/重登后即使宠物栏未渲染也能立即显示正确图标。
local PET_MODE_ICON_TEXTURE = {
    PET_MODE_PASSIVE = "Interface\\Icons\\Ability_Seal",
    PET_MODE_DEFENSIVE = "Interface\\Icons\\Ability_Defend",
    PET_MODE_ASSIST = "Interface\\Icons\\Ability_Hunter_Pet_Assist",
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

local function GetPlayerClassFile()
    if type(UnitClass) ~= "function" then
        return nil
    end
    local _, classFile = UnitClass("player")
    return classFile
end

local function GetSpellTextureByID(spellID)
    spellID = tonumber(spellID)
    if not spellID then
        return nil
    end

    if C_Spell and type(C_Spell.GetSpellTexture) == "function" then
        local ok, tex = pcall(C_Spell.GetSpellTexture, spellID)
        if ok and tex then
            return tex
        end
    end

    if type(GetSpellTexture) == "function" then
        local ok, tex = pcall(GetSpellTexture, spellID)
        if ok and tex then
            return tex
        end
    end

    return nil
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
    if not statusKey then
        return nil
    end

    local classFile = GetPlayerClassFile()
    if not classFile then
        return nil
    end

    local classSpells = STATUS_ICON_SPELLS[classFile]
    if not classSpells then
        return nil
    end

    local value = classSpells[statusKey]
    if value == nil then
        return nil
    end

    if value == "WARLOCK_SUMMON" then
        return ResolveWarlockSummonSpellID()
    end

    return tonumber(value)
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
local currentIconMode = DEFAULT_ALERT_ICON_MODE
local currentIconSize = DEFAULT_ALERT_ICON_SIZE
local currentIconGap = DEFAULT_ALERT_ICON_GAP
-- 缓存当前是否处于"显示图标"的布局，供浮动函数复用锚点，避免每帧重算。
local currentLayoutShowsIcon = false
local currentLayoutShowsText = true
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
    -- 防御：每次布局前从 DB 同步 currentIconMode，修复 RL/重登后图标模式丢失
    InitDB()
    if PetStatusAlertDB.alertIconMode then
        currentIconMode = NormalizeIconMode(PetStatusAlertDB.alertIconMode)
    end

    local showIcon, showText, iconValue = ResolveContentLayout(statusKey)
    currentLayoutShowsIcon = showIcon
    currentLayoutShowsText = showText

    icon:ClearAllPoints()
    text:ClearAllPoints()

    -- 获取图标纹理。iconValue 可能是数字 spellID 或负数（宠物姿态标记）。
    -- 纯图标模式下若纹理获取失败，回退为纯文字。
    local iconTexture = nil
    if showIcon and iconValue then
        if type(iconValue) == "number" and iconValue < 0 then
            -- 负数 = 宠物姿态，从宠物动作栏动态获取图标纹理
            local token = PET_MODE_TOKEN[iconValue]
            if token then
                iconTexture = GetPetModeIconTexture(token)
            end
        elseif type(iconValue) == "number" then
            iconTexture = GetSpellTextureByID(iconValue)
        else
            -- 字符串（如 "WARLOCK_SUMMON"）：兜底，理论不应走到这里（已在 GetStatusIconSpellID 解析）
            iconTexture = GetSpellTextureByID(tonumber(iconValue))
        end
        if not iconTexture then
            showIcon = false
            showText = true
            currentLayoutShowsIcon = false
            currentLayoutShowsText = true
        end
    end

    if not showIcon then
        icon:Hide()
        icon:SetTexture(nil)
        text:Show()
        text:SetPoint("CENTER", contentFrame, "CENTER", 0, 0)
        local tw = text:GetStringWidth() or 0
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

    local tw = text:GetStringWidth() or 0
    local th = text:GetStringHeight() or currentAlertFontSize
    local totalW = currentIconSize + currentIconGap + tw
    local totalH = math.max(currentIconSize, th)
    return totalW, totalH
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
    RefreshAlertIconSize()

    text:SetFont(STANDARD_TEXT_FONT, currentAlertFontSize, "OUTLINE")
    -- 默认恢复 text 可见；ApplyContentLayout 会按纯图标模式再隐藏。
    text:Show()

    -- 用当前状态键重新计算 icon/text 锚点与内容尺寸。
    local contentWidth, contentHeight = ApplyContentLayout(lastStatusKey)
    contentWidth = tonumber(contentWidth) or 0
    contentHeight = tonumber(contentHeight) or currentAlertFontSize

    local boxWidth = math.max(math.ceil(contentWidth + currentGlowPadding * 2), 40)
    local boxHeight = math.max(math.ceil(contentHeight + currentGlowPadding * 2), currentAlertFontSize + 6)

    addonFrame:SetSize(math.max(boxWidth, 80), math.max(boxHeight, 32))
    contentFrame:SetSize(math.max(contentWidth, 1), math.max(contentHeight, 1))

    -- 流光目标：有图标时只围绕图标，纯文字时围绕文字
    if currentLayoutShowsIcon then
        local glowSize = math.max(math.ceil(currentIconSize + currentGlowPadding * 2), 32)
        glowFrame:SetSize(glowSize, glowSize)
    else
        glowFrame:SetSize(boxWidth, boxHeight)
    end
end

local function ApplyFloatOffset(y)
    y = tonumber(y) or 0
    if lastFloatOffset ~= nil and math.abs(y - lastFloatOffset) < 0.05 then
        return
    end
    lastFloatOffset = y

    -- 浮动作用于 contentFrame（承载 icon + text），整体上下移动。
    -- glowFrame 已直接锚定到 icon，自动跟随，无需手动同步。
    contentFrame:ClearAllPoints()
    contentFrame:SetPoint("CENTER", textFrame, "CENTER", 0, y)
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

    -- 纯文字模式不显示流光（效果不佳）；只在有图标时启动
    if not addonFrame:IsShown() or text:GetText() == "" or not currentLayoutShowsIcon then
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
    -- 直接锚定到 icon 纹理上，尺寸跟随图标，位置自动对齐（浮动动画自动跟随）
    glowFrame:ClearAllPoints()
    glowFrame:SetPoint("CENTER", icon, "CENTER", 0, 0)
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
    RefreshAlertIconMode()
    RefreshAlertIconGap()
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

-- 供 Options 预览时查询：当前职业在指定状态下是否有可用图标。
local function HasStatusIcon(statusKey)
    return GetStatusIconSpellID(statusKey) ~= nil
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
    icon:Hide()
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
PSA.alertIcon = icon
PSA.alertContentFrame = contentFrame
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
PSA.GetAlertIconMode = GetAlertIconMode
PSA.SetAlertIconMode = SetAlertIconMode
PSA.RefreshAlertIconMode = RefreshAlertIconMode
PSA.GetAlertIconSize = GetAlertIconSize
PSA.SetAlertIconSize = SetAlertIconSize
PSA.RefreshAlertIconSize = RefreshAlertIconSize
PSA.GetAlertIconGap = GetAlertIconGap
PSA.SetAlertIconGap = SetAlertIconGap
PSA.RefreshAlertIconGap = RefreshAlertIconGap
PSA.HasStatusIcon = HasStatusIcon
PSA.GetStatusIconSpellID = GetStatusIconSpellID
PSA.RefreshAlertVisuals = RefreshAlertVisuals
PSA.StartAlertGlow = StartAlertGlow
PSA.StopAlertGlow = StopAlertGlow
PSA.SetMessage = SetMessage
PSA.ShowStatus = ShowStatus
PSA.PreviewStatus = PreviewStatus
PSA.HideStatus = HideStatus
