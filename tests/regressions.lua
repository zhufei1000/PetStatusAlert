-- Run from the addon source directory: lua tests/regressions.lua
local function noop() end
local Methods = {}
local function Object(parent)
    local value = setmetatable({parent = parent, children = {}, shown = true,
        scripts = {}, value = 0, width = 1920, height = 28, text = ""}, {__index = Methods})
    if parent then parent.children[#parent.children + 1] = value end
    return value
end
for _, name in ipairs({"SetPoint", "ClearAllPoints", "SetAllPoints", "SetClampedToScreen",
    "SetMovable", "EnableMouse", "RegisterForDrag", "SetFrameLevel", "SetFrameStrata",
    "SetFont", "SetTextColor", "SetShadowColor", "SetShadowOffset", "SetWordWrap",
    "SetJustifyH", "SetOrientation", "SetMinMaxValues", "SetValueStep", "SetObeyStepOnDrag",
    "SetHighlightTexture", "SetTexCoord", "SetMouseMotionEnabled", "EnableMouseWheel", "SetScrollChild",
    "SetColorTexture", "SetAutoFocus", "SetMultiLine", "SetMaxLetters", "SetFontObject", "SetTextInsets",
    "SetNumeric"}) do
    Methods[name] = noop
end
function Methods:SetScript(key, callback) self.scripts[key] = callback end
function Methods:RegisterEvent(event)
    self.events = self.events or {}
    self.events[event] = true
end
function Methods:IsShown() return self.shown end
function Methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function Methods:Show() self.shown = true end
local function Hidden(value)
    if value.scripts.OnHide then value.scripts.OnHide(value) end
    for _, child in ipairs(value.children) do
        if child.shown then Hidden(child) end
    end
end
function Methods:Hide()
    local wasVisible = self:IsVisible()
    self.shown = false
    if wasVisible then Hidden(self) end
end
function Methods:SetShown(show)
    if show then self:Show() else self:Hide() end
end
function Methods:GetFrameLevel() return 1 end
function Methods:SetPoint(...) self.point = {...} end
function Methods:EnableMouse(value) self.mouseEnabled = value end
function Methods:SetFont() self.fontUpdates = (self.fontUpdates or 0) + 1 end
function Methods:GetFont() return STANDARD_TEXT_FONT end
function Methods:SetText(value) self.text = value end
function Methods:GetText() return self.text end
function Methods:SetWidth(value) self.width = value end
function Methods:SetHeight(value) self.height = value end
function Methods:GetWidth() return self.width end
function Methods:GetHeight() return self.height end
function Methods:SetSize(width, height) self.width, self.height = width, height end
function Methods:SetClampRectInsets(...) self.clampInsets = {...} end
function Methods:GetStringWidth() return #self.text * 12 end
Methods.GetUnboundedStringWidth = Methods.GetStringWidth
function Methods:GetStringHeight() return 28 end
function Methods:SetTexture(value) self.texture = value end
function Methods:SetAtlas(value) self.texture = value end
function Methods:SetDesaturated(value) self.desaturated = value end
function Methods:RegisterForClicks(...) self.clicks = {...} end
function Methods:SetAttribute(key, value)
    self.attributes = self.attributes or {}
    self.attributes[key] = value
end
function Methods:CreateTexture() self.icon = Object(self); return self.icon end
function Methods:CreateFontString() return Object(self) end
function Methods:SetValue(value)
    self.value = value
    if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, value) end
end
function Methods:GetValue() return self.value end

CreateFrame = function(_, _, parent, template)
    local frame = Object(parent)
    frame.template = template
    return frame
end
UIParent = Object()
STANDARD_TEXT_FONT = "font"
GetLocale = function() return "enUS" end
UnitClass = function() return "Hunter", "HUNTER" end
local texture, textureCalls = nil, 0
C_Spell = {GetSpellTexture = function() textureCalls = textureCalls + 1; return texture end}
local psa = {}
for _, file in ipairs({"Core/Database.lua", "Core/Compat.lua", "Core/Localization.lua", "Core/AlertFrame.lua"}) do
    assert(loadfile(file))("PetStatusAlert", psa)
end
local tickers, timers, spoken = {}, {}, {}
local function Timer(callback)
    return {callback = callback, Cancel = function(self) self.cancelled = true end}
end
C_Timer = {
    NewTicker = function(_, callback)
        local timer = Timer(callback); tickers[#tickers + 1] = timer; return timer
    end,
    NewTimer = function(_, callback)
        local timer = Timer(callback); timers[#timers + 1] = timer; return timer
    end,
}
local inCombat = false
InCombatLockdown = function() return inCombat end
C_VoiceChat = {SpeakText = function(_, text) spoken[#spoken + 1] = text end}
assert(loadfile("Core/TTS.lua"))("PetStatusAlert", psa)
local function ActiveTickers()
    local count = 0
    for _, timer in ipairs(tickers) do if not timer.cancelled then count = count + 1 end end
    return count
end

local passed, failed = 0, 0
local function Test(name, callback)
    local ok, err = pcall(callback)
    if ok then passed = passed + 1; print("PASS " .. name)
    else failed = failed + 1; print("FAIL " .. name .. ": " .. tostring(err)) end
end
Test("icon gap setter applies without a global function", function()
    psa.ShowStatus("PASSIVE")
    assert(psa.SetAlertIconGap(17) == 17)
    assert(PetStatusAlertDB.alertIconGap == 17)
end)
Test("unchanged status retries a missing spell icon and stops retrying after success", function()
    psa.HideStatus(); texture = nil
    psa.ShowStatus("NO_PET")
    local before = textureCalls
    assert(psa.alertText:IsShown() and not psa.alertText.parent.icon:IsShown())
    psa.ShowStatus("NO_PET")
    assert(textureCalls > before, "same status must retry a missing icon")
    texture = 123
    psa.ShowStatus("NO_PET")
    assert(psa.alertText.parent.icon.texture == 123 and psa.alertText.parent.icon:IsShown())
    before = textureCalls
    psa.ShowStatus("NO_PET")
    assert(textureCalls == before, "resolved icons must retain the fast refresh path")
end)
Test("icon-only mode restores the icon without reading hidden text", function()
    psa.HideStatus(); texture = nil
    psa.SetAlertIconMode("icon"); psa.ShowStatus("PET_DEAD")
    assert(psa.alertText:IsShown(), "missing texture falls back to text")
    texture = 456; psa.ShowStatus("PET_DEAD")
    assert(not psa.alertText:IsShown() and psa.alertText.parent.icon.texture == 456)
end)
Test("text and hidden alerts do not retry missing spell icons", function()
    psa.HideStatus(); texture = nil
    psa.RegisterStatusIcon("HUNTER", "NO_PET", 999001)
    psa.SetAlertIconMode("both"); psa.ShowStatus("NO_PET")
    psa.SetAlertIconMode("text")
    local before = textureCalls
    psa.ShowStatus("NO_PET"); psa.ShowStatus("NO_PET")
    assert(textureCalls == before)
    psa.HideStatus(); psa.RefreshAlertVisuals()
    assert(textureCalls == before and not psa.addonFrame:IsShown())
    psa.RegisterStatusIcon("HUNTER", "NO_PET", 883)
end)
Test("display mode stops and restarts combat TTS without another game event", function()
    inCombat = true; PetStatusAlertDB.combatTTSEnabled = true
    psa.SetAlertIconMode("both"); psa.ShowStatus("PASSIVE")
    assert(ActiveTickers() == 1)
    psa.SetAlertIconMode("icon")
    assert(ActiveTickers() == 0, "icon mode must immediately stop TTS")
    psa.SetAlertIconMode("both")
    assert(ActiveTickers() == 1, "visible text must restart TTS")
    local before = #spoken
    psa.SetAlertFontSize(32); psa.SetAlertIconGap(18)
    assert(ActiveTickers() == 1 and #spoken == before, "visual refresh must not duplicate TTS")
    psa.HideStatus(); assert(ActiveTickers() == 0)
    inCombat = false
end)

-- Run the real local slider factory, supplying only its UI dependencies.
local file = assert(io.open("UI/Options.lua", "rb"))
local source = file:read("*a"); file:close()
local first = assert(source:find("local function CreateSliderRow", 1, true))
local last = assert(source:find("-- Color picker", first, true))
local environment = setmetatable({STYLE = {}, LAYOUT = {sliderWidth = 300},
    CreateText = function() return Object() end, HideSliderTemplateLabels = noop}, {__index = _G})
local createSlider = assert(load(source:sub(first, last - 1) .. "\nreturn CreateSliderRow",
    "@UI/Options.lua", "t", environment))()
local function FlushTimers()
    local pending = timers; timers = {}
    for _, timer in ipairs(pending) do if not timer.cancelled then timer.callback() end end
end
Test("closing a panel cancels slider work and prevents preview resurrection", function()
    local panel = Object(UIParent)
    panel:SetScript("OnHide", function() if psa.currentStatusForce then psa.HideStatus() end end)
    local commits = 0
    local slider = createSlider(panel, "test", "", 0, 0, 40, 1, 10, "10", function(value)
        commits = commits + 1; psa.PreviewStatus("PASSIVE"); return value
    end)
    psa.PreviewStatus("PASSIVE"); slider:SetValue(20); panel:Hide(); FlushTimers()
    assert(commits == 0 and not psa.addonFrame:IsShown(), "hidden slider reopened preview")
    slider.scripts.OnMouseUp(slider)
    assert(commits == 0, "late mouse release must not apply a hidden slider")
    panel:Show(); FlushTimers()
    assert(commits == 0, "reopening must not replay a cancelled change")
end)
Test("visible sliders debounce and commit the final value on release", function()
    local values = {}
    local slider = createSlider(Object(UIParent), "test", "", 0, 0, 40, 1, 10, "10", function(value)
        values[#values + 1] = value; return value
    end)
    slider:SetValue(11); slider:SetValue(12); FlushTimers()
    assert(#values == 1 and values[1] == 12)
    slider:SetValue(13); slider.scripts.OnMouseUp(slider); FlushTimers()
    assert(#values == 2 and values[2] == 13, "release must cancel duplicate timer work")
end)
-- SavedVariables are restored after addon scripts execute, before ADDON_LOADED.
GetLocale = function() return "zhCN" end
local function LoadLanguageSession(saved)
    PetStatusAlertDB = nil
    local session = {}
    for _, path in ipairs({"Core/Database.lua", "Core/Compat.lua", "Core/Localization.lua", "Core/AlertFrame.lua",
        "Core/TTS.lua", "Core/PetLogic.lua", "Core/PetFeed.lua", "Core/WarriorLogic.lua", "UI/Options.lua",
        "UI/ManagerSettings.lua", "Core/Events.lua"}) do
        assert(loadfile(path))("PetStatusAlert", session)
    end
    if saved then
        PetStatusAlertDB = saved
        session.addonFrame.scripts.OnEvent(session.addonFrame, "ADDON_LOADED", "PetStatusAlert")
    end
    return session
end
local function Upvalue(callback, key)
    for index = 1, 100 do
        local name, value = debug.getupvalue(callback, index)
        if not name then break end
        if name == key then return value end
    end
    error("Missing upvalue: " .. key)
end
local alertTabTitles = {enUS = "Alerts", zhCN = "提醒设置", zhTW = "提醒設定", ruRU = "Предупреждения"}
for _, mode in ipairs({"enUS", "zhCN", "zhTW", "ruRU", "auto"}) do
    Test("saved language survives reload: " .. mode, function()
        local first = LoadLanguageSession()
        first.ApplyManagerLanguage(mode)
        PetStatusAlertDB.customMessages.DEFENSIVE = "Custom text"
        PetStatusAlertDB.alertFontSize = 41
        local saved = PetStatusAlertDB
        local reloaded = LoadLanguageSession(saved)
        local locale = mode == "auto" and "zhCN" or mode
        assert(reloaded.GetSavedLanguageMode() == mode, "saved selection was changed")
        assert(reloaded.UI == reloaded.UI_LOCALE[locale], "UI kept the client language after loading the saved selection")
        assert(Upvalue(reloaded.RefreshOptionsFrameLocale, "TEXT").NAV_ALERTS == alertTabTitles[locale],
            "standalone navigation kept the client language")
        for _, key in ipairs({"PASSIVE", "DEFENSIVE", "NO_PET", "PET_DEAD", "UNKNOWN", "WARRIOR_DEFENSIVE_STANCE"}) do
            assert(reloaded.GetDefaultMessage(key) == reloaded.LOCALIZED_MESSAGES[locale][key], key .. " used the wrong language")
        end
        assert(reloaded.STATUS_LABEL.WARRIOR_DEFENSIVE_STANCE == reloaded.UI["WARRIOR_DEFENSIVE_STANCE"],
            "Warrior label was lost while restoring language")
        reloaded.ShowStatus("NO_PET")
        assert(reloaded.alertText:GetText() == reloaded.LOCALIZED_MESSAGES[locale].NO_PET,
            "runtime alert did not use the restored language")
        local managerTitle = locale == "ruRU" and "Alerts" or alertTabTitles[locale]
        assert(reloaded.GetSettingsDefinition({}).tabs[1].title == managerTitle,
            "manager tabs did not use the restored language")
        assert(reloaded.GetDisplayMessage("DEFENSIVE") == "Custom text" and PetStatusAlertDB.alertFontSize == 41,
            "restoring language changed other preferences")
    end)
end
Test("glow uses the layout already calculated for the alert", function()
    local session = LoadLanguageSession({language = "enUS", alertGlowEnabled = true, alertGlowDefaultOffMigrated = true})
    local before = session.alertText.fontUpdates
    session.ShowStatus("PASSIVE")
    assert(session.alertText.fontUpdates == before + 1, "glow recalculated the same layout")
    before = session.alertText.fontUpdates
    session.SetAlertFontSize(35)
    assert(session.alertText.fontUpdates == before + 1, "visual settings recalculated the same layout")
end)
Test("fixed spell icon cache survives entering another zone", function()
    local session = LoadLanguageSession({language = "enUS"})
    texture = 9876
    session.ShowStatus("NO_PET")
    local before = textureCalls
    session.addonFrame.scripts.OnEvent(session.addonFrame, "PLAYER_ENTERING_WORLD")
    session.ShowStatus("NO_PET")
    assert(textureCalls == before, "zone entry unnecessarily discarded a fixed spell icon")
end)
Test("saved position and unlocked state are applied after SavedVariables load", function()
    local session = LoadLanguageSession({language = "enUS", alertLocked = false,
        alertPosition = {point = "CENTER", relativePoint = "CENTER", x = 137, y = -91}})
    assert(session.addonFrame.point[4] == 137 and session.addonFrame.point[5] == -91,
        "alert retained the pre-save default position")
    assert(session.addonFrame.mouseEnabled == true, "alert retained the pre-save locked state")
end)
Test("/psa opens standalone settings with the manager installed", function()
    local session = LoadLanguageSession({language = "enUS"})
    local frame = Object(UIParent)
    frame:Hide()
    frame.Raise = noop
    for index = 1, 30 do
        if debug.getupvalue(session.OpenOptionsFrame, index) == "CreateOptionsFrame" then
            debug.setupvalue(session.OpenOptionsFrame, index, function() return frame end)
            break
        end
    end
    QFXAddonManagerAPI = {OpenAddonSettings = function() error("settings recursed into the manager") end}
    SlashCmdList = {}
    assert(loadfile("Core/Slash.lua"))("PetStatusAlert", session)
    SlashCmdList.PETSTATUSALERT("")
    assert(frame:IsShown())
    frame:Hide()
    SlashCmdList.PETSTATUSALERT("options")
    assert(frame:IsShown())
    QFXAddonManagerAPI = nil
end)
Test("ordinary options refresh does not recreate localization tables", function()
    local session = LoadLanguageSession({language = "enUS"})
    local labels = session.STATUS_LABEL
    session.RefreshOptionsFrameLocale()
    assert(session.STATUS_LABEL == labels, "ordinary UI refresh rebuilt the locale state")
end)
Test("manager definition is cached until language or supported statuses change", function()
    local session = LoadLanguageSession({language = "zhCN"})
    local original = session.GetSettingsDefinition({})
    assert(session.GetSettingsDefinition({}) == original)
    session.ApplyManagerLanguage("enUS")
    local translated = session.GetSettingsDefinition({})
    assert(translated ~= original and translated.tabs[1].title == "Alerts", "manager reused old-language tabs")
    assert(session.GetSettingsDefinition({}) == translated)
    for index = #session.STATUS_ORDER, 1, -1 do session.STATUS_ORDER[index] = nil end
    session.STATUS_ORDER[1] = "WARRIOR_DEFENSIVE_STANCE"
    assert(session.GetSettingsDefinition({}) ~= translated, "manager reused pages for an old status list")
end)
Test("Forever Aggressive uses its own icon, text, and settings entry", function()
    GetBuildInfo = function() return "1.60.1", "70790", "Nov 5 2026", 16001 end
    local session = LoadLanguageSession({language = "enUS"})
    session.SetAlertIconMode("both")
    session.ShowStatus("AGGRESSIVE")
    assert(session.alertText:GetText() == "Pet: Aggressive")
    assert(session.alertText.parent.icon.texture == "Interface\\Icons\\Ability_Racial_BloodRage")
    session.SetAlertIconMode("icon")
    assert(session.alertText.parent.icon:IsShown() and not session.alertText:IsShown())
    assert(session.STATUS_ORDER[4] == "DEFENSIVE" and session.STATUS_ORDER[5] == "AGGRESSIVE")
    local text = Upvalue(session.RefreshOptionsFrameLocale, "TEXT")
    assert(text.SUPPORT_CLASSES == "Hunter\nWarlock\nMage (Water Elemental)")
    session.HideStatus()
    GetBuildInfo = nil
end)
Test("Forever Warrior UI previews stay hidden after language refresh", function()
    GetBuildInfo = function() return "1.60.1", "70790", "Nov 5 2026", 16001 end
    local originalClass = UnitClass
    UnitClass = function() return "Warrior", "WARRIOR" end
    local session = LoadLanguageSession({language = "enUS"})
    for _, language in ipairs({"enUS", "zhCN", "zhTW", "ruRU"}) do
        session.ApplyManagerLanguage(language)
        session.PreviewStatus("PASSIVE")
        assert(not session.addonFrame:IsShown() and #session.STATUS_ORDER == 0)
        session.PreviewStatus("WARRIOR_DEFENSIVE_STANCE")
        assert(not session.addonFrame:IsShown())
    end
    GetBuildInfo, UnitClass = nil, originalClass
end)

local activeGlows = {}
LibStub = function()
    return {
        PixelGlow_Start = function(frame) activeGlows[frame] = true end,
        PixelGlow_Stop = function(frame) activeGlows[frame] = nil end,
    }
end

Test("stance glow defaults on and an updated opt-out survives reload", function()
    local session = LoadLanguageSession({alertGlowEnabled = false, alertGlowDefaultOffMigrated = true})
    session.ShowStatus("PASSIVE")
    local glowFrame = next(activeGlows)
    assert(glowFrame and session.GetAlertGlowEnabled())
    session.ShowStatus("DEFENSIVE")
    assert(activeGlows[glowFrame])
    session.ShowStatus("NO_PET")
    assert(not activeGlows[glowFrame], "other alerts must retain their previous default")
    session.ShowStatus("PASSIVE")
    session.SetAlertIconMode("text")
    assert(not activeGlows[glowFrame])
    session.SetAlertIconMode("both")
    session.SetAlertGlowEnabled(false)
    assert(not activeGlows[glowFrame])
    local reloaded = LoadLanguageSession(PetStatusAlertDB)
    reloaded.ShowStatus("DEFENSIVE")
    assert(not reloaded.GetAlertGlowEnabled() and not next(activeGlows))
end)

Test("Forever threshold settings share the saved numeric value", function()
    GetBuildInfo = function() return "1.60.1", "70862", "", 16001 end
    local session = LoadLanguageSession({language = "zhCN"})
    assert(session.GetAmmoThreshold() == 100)
    local tabs = session.GetSettingsDefinition({}).tabs
    local tab = tabs[#tabs]
    assert(tab.key == "forever" and tab.title == "无限专用")
    local section = {EditBox = function(_, _, get, set, _, _, opts)
        assert(opts.numeric and get() == 100)
        assert(set("160") == 160 and get() == 160)
    end}
    tab.build({NewSection = function() return section end, AddSection = noop})

    local createOptions = Upvalue(session.OpenOptionsFrame, "CreateOptionsFrame")
    local drawForever = Upvalue(createOptions, "DrawForeverPage")
    local root = Object(UIParent)
    drawForever(root)
    local page = root.children[1].children[1]
    local standaloneSection = page.children[#page.children]
    local input = standaloneSection.children[#standaloneSection.children]
    assert(input.template == "InputBoxTemplate" and input:GetText() == "160")
    function input:ClearFocus() self.scripts.OnEditFocusLost(self) end
    input:SetText("250")
    input.scripts.OnEnterPressed(input)
    assert(session.GetAmmoThreshold() == 250)
    input:SetText("300")
    input.scripts.OnEscapePressed(input)
    assert(session.GetAmmoThreshold() == 250 and input:GetText() == "250")
    assert(session.SetAmmoThreshold("bad") == 250 and session.SetAmmoThreshold(10000) == 9999)
    session.SetAmmoThreshold(250)
    local reloaded = LoadLanguageSession(PetStatusAlertDB)
    assert(reloaded.GetAmmoThreshold() == 250)
    GetBuildInfo = nil
    for _, entry in ipairs(LoadLanguageSession().GetSettingsDefinition({}).tabs) do
        assert(entry.key ~= "forever")
    end
end)

Test("Forever ammo warns below 100 after every combat and only updates outside combat", function()
    local weapon, ammo, count = 101, 201, 100
    local reads, pending = 0, {}
    local itemInfoReads = 0
    local after = C_Timer.After
    C_Timer.After = function(_, callback) pending[#pending + 1] = callback end
    GetBuildInfo = function() return "1.60.1", "70862", "", 16001 end
    UnitUsesAmmo = function() return true end
    C_PaperDollInfo = {
        AmmoNeeded = function() return true end,
        GetInventorySlotInfo = function(slot)
            if slot == "AmmoSlot" then return 0, 12345 end
            assert(slot == "RangedSlot")
            return 18
        end,
    }
    Enum = {ItemClass = {Weapon = 2, Projectile = 6}, ItemWeaponSubclass = {Bows = 2, Guns = 3, Crossbow = 18}}
    local itemTypes = {[101] = {2, 2}, [102] = {2, 3}, [103] = {2, 18}, [104] = {2, 16},
        [201] = {6, 2}, [202] = {6, 3}}
    C_Item = {GetItemInfoInstant = function(id)
        itemInfoReads = itemInfoReads + 1
        return id, nil, nil, nil, nil, table.unpack(itemTypes[id])
    end}
    GetInventoryItemID = function(_, slot) if slot == 0 then return ammo end; return weapon end
    GetInventoryItemCount = function(_, slot) assert(slot == 0); reads = reads + 1; return count end
    GetInventoryItemTexture = function(_, slot) assert(slot == 0); return 45678 end

    local session = LoadLanguageSession({language = "enUS"})
    local events = session.addonFrame.events
    assert(events.BAG_UPDATE_DELAYED and events.UNIT_INVENTORY_CHANGED and events.PLAYER_EQUIPMENT_CHANGED)
    local function Event(event, ...)
        session.addonFrame.scripts.OnEvent(session.addonFrame, event, ...)
    end
    local function FlushEvents()
        local callbacks = pending
        pending = {}
        for _, callback in ipairs(callbacks) do callback() end
    end

    Event("PLAYER_ENTERING_WORLD")
    FlushEvents()
    local content = session.alertText.parent
    local row = content.parent
    local frameCount, timerCount = #row.children, #timers
    assert(reads == 1 and not next(activeGlows), "100 must not warn")

    count = 99
    Event("UNIT_INVENTORY_CHANGED", "pet")
    assert(#pending == 0)
    Event("UNIT_INVENTORY_CHANGED", "player")
    Event("BAG_UPDATE_DELAYED")
    assert(#pending == 1, "ammo checks must coalesce")
    FlushEvents()
    assert(reads == 2 and #row.children == frameCount + 1 and #timers == timerCount)
    local alert = row.children[#row.children]
    local _, badge, label = table.unpack(alert.children)
    assert(alert:IsVisible() and activeGlows[alert] and alert.icon.texture == 45678)
    assert(badge:GetText() == "99" and session.currentStatusKey == nil)
    assert(alert.point[1] == "CENTER" and alert.point[2] == content and alert.point[3] == "CENTER")
    assert(label:GetText() == "Low arrows" and label.point[1] == "RIGHT" and label.point[2] == alert
        and label.point[3] == "LEFT")

    local tooltip = Object()
    function tooltip:IsForbidden() return false end
    function tooltip:IsOwned(owner) return self.owner == owner end
    function tooltip:SetOwner(owner) self.owner = owner end
    GameTooltip = tooltip
    alert.scripts.OnEnter(alert)
    assert(tooltip:GetText() == "Low arrows (99 left)")

    local layouts = label.fontUpdates
    count = 98
    Event("BAG_UPDATE_DELAYED")
    FlushEvents()
    assert(badge:GetText() == "98" and tooltip:GetText() == "Low arrows (98 left)" and #timers == timerCount)
    assert(itemInfoReads == 2, "inventory events must reuse weapon and ammo metadata")
    assert(label.fontUpdates == layouts, "changing the count should not rebuild the row")
    FlushTimers()
    assert(alert:IsVisible() and activeGlows[alert], "out-of-combat warning must stay visible")
    session.ApplyManagerLanguage("zhCN")
    assert(label:GetText() == "箭矢不足" and tooltip:GetText() == "箭矢不足（剩余 98）")
    session.ApplyManagerLanguage("enUS")

    local beforeCombat = reads
    Event("BAG_UPDATE_DELAYED")
    inCombat = true
    Event("PLAYER_REGEN_DISABLED")
    assert(not alert:IsVisible() and not activeGlows[alert] and not tooltip:IsShown())
    FlushEvents()
    assert(reads == beforeCombat, "queued ammo checks must not run in combat")
    count = 97
    Event("BAG_UPDATE_DELAYED")
    Event("UNIT_INVENTORY_CHANGED", "player")
    assert(#pending == 0 and reads == beforeCombat, "combat inventory changes must not queue ammo checks")
    inCombat = false
    Event("PLAYER_REGEN_ENABLED")
    FlushEvents()
    assert(alert:IsVisible() and activeGlows[alert] and badge:GetText() == "97")

    inCombat = true
    Event("PLAYER_REGEN_DISABLED")
    assert(not alert:IsShown())
    inCombat = false
    Event("PLAYER_REGEN_ENABLED")
    FlushEvents()
    assert(alert:IsVisible() and activeGlows[alert] and badge:GetText() == "97",
        "leaving combat must warn even when ammo did not change")

    ammo = nil
    Event("UNIT_INVENTORY_CHANGED", "player")
    FlushEvents()
    assert(alert:IsVisible() and badge:GetText() == "0" and alert.icon.texture == 12345)
    session.ShowStatus("PASSIVE")
    assert(alert:IsVisible() and session.currentStatusKey == "PASSIVE")
    assert(alert.point[1] == "RIGHT" and alert.point[2] == content and alert.point[3] == "LEFT")
    assert(content.point[4] - content:GetWidth() / 2 + content.icon:GetWidth() / 2 == 0,
        "stance icon must use the same center as the standalone ammo icon")
    session.SetPetCareAlert("feed", 34567)
    local care = session.GetPetCareFrame()
    assert(care:IsVisible() and care.point[2] == content.icon and alert.point[2] == care)
    session.SetAlertIconSize(72)
    assert(alert:GetWidth() == 72 and care:GetWidth() == 72 and content.icon:GetWidth() == 72)
    local anchor = session.addonFrame
    assert(anchor:GetWidth() / 2 - anchor.clampInsets[1] >= 72 / 2 + 2 * (8 + 72) + label:GetWidth(),
        "left edge must include both accessory icons and the ammo label")
    assert(anchor:GetWidth() / 2 + anchor.clampInsets[2] >= content:GetWidth() - 72 / 2,
        "right edge must include the stance text")
    PetStatusAlertDB.customMessages.PASSIVE = string.rep("Long alert text ", 30)
    session.ShowStatus("PASSIVE")
    assert(anchor:GetWidth() - anchor.clampInsets[1] + anchor.clampInsets[2] <= UIParent:GetWidth(),
        "the row must fit even when the centered icon leaves most of the text to its right")
    PetStatusAlertDB.customMessages.PASSIVE = nil
    session.HideStatus()
    assert(alert:IsVisible() and care.point[1] == "CENTER" and alert.point[2] == care)
    session.SetPetCareAlert(nil)
    assert(alert:IsVisible() and alert.point[1] == "CENTER" and alert.point[2] == content,
        "the remaining icon must return to the saved center")
    function anchor:StartMoving() self.moving = true end
    function anchor:StopMovingOrSizing() self.moving = false end
    function anchor:GetPoint() return table.unpack(self.point) end
    session.SetAlertPositionLocked(false)
    anchor.scripts.OnDragStart(anchor)
    assert(anchor.moving and anchor.mouseEnabled)
    anchor:SetPoint("CENTER", UIParent, "CENTER", 120, -40)
    anchor.scripts.OnDragStop(anchor)
    assert(not anchor.moving and PetStatusAlertDB.alertPosition.x == 120 and PetStatusAlertDB.alertPosition.y == -40)

    weapon, ammo, count = 102, 202, 100
    Event("PLAYER_EQUIPMENT_CHANGED", 18)
    FlushEvents()
    assert(not alert:IsVisible() and not activeGlows[alert] and not anchor:IsShown())
    session.SetAlertGlowEnabled(false)
    count = 20
    Event("BAG_UPDATE_DELAYED")
    FlushEvents()
    alert.scripts.OnEnter(alert)
    assert(alert:IsVisible() and badge:GetText() == "20" and tooltip:GetText() == "Low bullets (20 left)"
        and label:GetText() == "Low bullets" and not activeGlows[alert])
    session.SetAmmoThreshold(20)
    FlushEvents()
    assert(not alert:IsShown(), "an amount equal to the custom threshold must not warn")
    session.SetAmmoThreshold(21)
    FlushEvents()
    assert(alert:IsShown(), "a custom threshold must apply without another inventory event")
    local readsBeforeDisable = reads
    session.SetAmmoThreshold(0)
    FlushEvents()
    assert(not alert:IsShown() and reads == readsBeforeDisable, "zero must disable ammo checks")
    session.SetAmmoThreshold(100)
    FlushEvents()
    alert.scripts.OnEnter(alert)
    weapon = 103
    Event("PLAYER_EQUIPMENT_CHANGED", 18)
    FlushEvents()
    assert(badge:GetText() == "0" and tooltip:GetText() == "Low arrows (0 left)", "bullets cannot supply a crossbow")
    weapon = 104
    Event("PLAYER_EQUIPMENT_CHANGED", 18)
    FlushEvents()
    assert(not alert:IsShown() and not next(pending))
    FlushTimers()

    GetBuildInfo = function() return "12.1.5", "70783", "", 120105 end
    local retail = LoadLanguageSession({language = "enUS"})
    assert(not retail.GetForeverAmmo and not retail.addonFrame.events.UNIT_INVENTORY_CHANGED)
    GetBuildInfo, UnitUsesAmmo, C_PaperDollInfo, Enum, C_Item = nil, nil, nil, nil, nil
    GetInventoryItemID, GetInventoryItemCount, GetInventoryItemTexture = nil, nil, nil
    GameTooltip = nil
    C_Timer.After = after
end)

Test("Forever feeding tracks happiness, food, combat, and the stance layout", function()
    GetBuildInfo = function() return "1.60.1", "70862", "", 16001 end
    local happiness, pet, stance = 2, true, "PET_MODE_PASSIVE"
    local food = {itemID = 42, stackCount = 1, iconFileID = 123, itemName = "Meat"}
    local fish = {itemID = 43, stackCount = 4, iconFileID = 456, itemName = "Fish"}
    local bags = {[0] = {food}, [1] = {}}
    local slotReads = {}
    C_PetInfo = {
        GetPetHappiness = function() return happiness end,
        CanPetEatItem = function(id) return id == 42 or id == 43 end,
    }
    C_Container = {
        GetContainerNumSlots = function(bag)
            return bag == 0 and 16 or bags[bag] and #bags[bag] or 0
        end,
        GetContainerItemInfo = function(bag, slot)
            slotReads[bag] = (slotReads[bag] or 0) + 1
            local item = bags[bag][slot]
            if item then
                local snapshot = {}
                for key, value in pairs(item) do snapshot[key] = value end
                return snapshot
            end
        end,
    }
    C_Item = {
        GetItemCount = function(id)
            local count = 0
            for _, items in pairs(bags) do
                for _, item in ipairs(items) do
                    if item.itemID == id then count = count + item.stackCount end
                end
            end
            return count
        end,
        GetItemNameByID = function(id) return id == 42 and food.itemName or fish.itemName end,
        GetItemIconByID = function(id) return id == 42 and food.iconFileID or fish.iconFileID end,
    }
    MenuVariants = {GetDefaultContextMenuMixin = noop}
    Menu = {PopulateDescription = function(build, owner, root) build(owner, root) end}
    MenuUtil = {}
    function MenuUtil.CreateRootMenuDescription()
        return {
            rows = {},
            AddMenuReleasedCallback = function(root, callback) root.release = callback end,
            CreateTitle = noop,
            SetScrollMode = noop,
            CreateRadio = function(root, label, isSelected, selectFood, id)
                assert(not root.rows[id], "duplicate food menu entry")
                root.rows[id] = {label = label, isSelected = isSelected, selectFood = selectFood}
            end,
        }
    end
    function MenuUtil.CreateContextMenu(owner, build)
        local menu = {}
        function menu:SetMenuDescription(root)
            self.rows, self.release = root.rows, root.release
        end
        function menu:Close()
            self.closed = true
            self.release(self)
        end
        local root = MenuUtil.CreateRootMenuDescription()
        Menu.PopulateDescription(build, owner, root)
        menu:SetMenuDescription(root)
        return menu
    end
    UnitGUID = function() return "Player-1" end
    C_SpellBook = {IsSpellKnown = function(id) return id == 883 or id == 6991 end}
    HasPetUI = function() return pet, pet end
    UnitExists = function() return pet end
    UnitIsDeadOrGhost = function() return false end
    SpellIsTargeting = function() return false end
    GetCursorInfo = function() return nil end
    GetPetActionInfo = function() return stance, nil, true, true end
    C_Timer.After = function(_, callback) callback() end

    local session = LoadLanguageSession({language = "enUS"})
    local function Event(event, ...)
        session.addonFrame.scripts.OnEvent(session.addonFrame, event, ...)
    end
    Event("PLAYER_ENTERING_WORLD")
    local care = session.GetPetCareFrame()
    local button = care.children[2]
    assert(button.template == "InsecureActionButtonTemplate")
    assert(button.clicks[1] == "LeftButtonUp" and button.clicks[2] == "RightButtonUp")
    assert(button:IsVisible() and care.icon.texture == 123 and activeGlows[care])
    assert(button.count:GetText() == "1")
    assert(care.point[1] == "RIGHT" and care.point[2] == session.alertText.parent.icon and care.point[3] == "LEFT")
    local anchor = session.addonFrame
    local leftReach = session.alertText.parent.icon:GetWidth() / 2 + 8 + care:GetWidth()
    assert(anchor:GetWidth() / 2 - anchor.clampInsets[1] >= leftReach, "left clamp must include the full care icon")

    local priorAfter, delays = C_Timer.After, {}
    C_Timer.After = function(delay, callback)
        delays[#delays + 1] = delay
        callback()
    end
    local initialReads = slotReads[0]
    Event("UNIT_PET", "party1")
    Event("PET_BAR_UPDATE")
    assert(#delays == 1 and delays[1] == 0.08 and slotReads[0] == initialReads,
        "Forever pet bar updates must only queue one stance check")
    Event("UNIT_HAPPINESS", "pet")
    assert(slotReads[0] == initialReads, "happiness must reuse the cached food slots")
    C_Timer.After = priorAfter

    bags[0], bags[1] = {}, {food}
    button.scripts.PreClick(button, "LeftButton")
    assert(button.attributes.type1 == "spell" and button.attributes.spell1 == 6991)
    assert(button.attributes["target-bag1"] == 1 and button.attributes["target-slot1"] == 1)
    button.scripts.PostClick(button, "LeftButton")
    assert(not button.attributes.type1 and not button.attributes["target-slot1"])
    bags[1] = {}
    button.scripts.PreClick(button, "LeftButton")
    assert(not button.attributes.type1, "click must not use a stale slot")
    Event("BAG_UPDATE_DELAYED")
    assert(not care:IsShown() and not activeGlows[care])
    assert(anchor:GetWidth() / 2 - anchor.clampInsets[1] == session.alertText.parent.icon:GetWidth() / 2 + 3,
        "hidden care icon must release its reserved space")

    bags[0] = {food}
    Event("BAG_UPDATE_DELAYED")
    bags[0] = {food, fish}
    bags[1] = {{itemID = 43, stackCount = 2}, {itemID = 44, stackCount = 7}}
    Event("BAG_UPDATE_DELAYED")
    button.scripts.PreClick(button, "RightButton")
    assert(not button.attributes.type1)
    button.scripts.PostClick(button, "RightButton")
    local menu = button.foodMenu
    assert(menu.rows[0].isSelected(0) and not menu.rows[44])
    assert(menu.rows[43].label == "Fish ×6")
    menu.rows[43].selectFood(43)
    assert(menu.rows[43].isSelected(43) and PetStatusAlertDB.petFeedFoodByCharacter["Player-1"] == 43)
    assert(care.icon.texture == 456 and button.count:GetText() == "6")
    button.scripts.PreClick(button, "LeftButton")
    assert(button.attributes["target-bag1"] == 0 and button.attributes["target-slot1"] == 2)
    button.scripts.PostClick(button, "LeftButton")
    menu:Close()

    local saved = PetStatusAlertDB
    local reloaded = LoadLanguageSession(saved)
    reloaded.RefreshPetCare()
    assert(reloaded.GetPetCareFrame().icon.texture == 456, "food selection must survive reload")
    reloaded.SetPetCareAlert(nil)

    button.scripts.PostClick(button, "RightButton")
    menu = button.foodMenu
    local after = C_Timer.After
    local pending = {}
    C_Timer.After = function(_, callback) pending[#pending + 1] = callback end
    local beforeBag0, beforeBag1 = slotReads[0], slotReads[1]
    Event("UNIT_HAPPINESS", "pet")
    bags[1][1].stackCount = 1
    Event("BAG_UPDATE", 1)
    Event("BAG_UPDATE_DELAYED")
    assert(#pending == 1, "inventory changes should coalesce with other pet updates")
    C_Timer.After = after
    pending[1]()
    assert(button.count:GetText() == "5", "badge must update after a stack changes")
    assert(button.foodMenu == menu and menu.rows[43].label == "Fish ×5", "open menu must update in place")
    assert(slotReads[0] == beforeBag0 and slotReads[1] == beforeBag1 + #bags[1],
        "badge and open menu must share one read of the changed bag")
    fish.isLocked = true
    bags[1][1].isLocked = true
    Event("ITEM_LOCK_CHANGED", 0, 2)
    Event("ITEM_LOCK_CHANGED", 1, 1)
    assert(care.icon.desaturated and button.count:GetText() == "5")
    assert(not menu.rows[43], "menu must remove a temporarily unavailable food")
    assert(PetStatusAlertDB.petFeedFoodByCharacter["Player-1"] == 43, "locked stacks must preserve the selection")
    button.scripts.PreClick(button, "LeftButton")
    assert(not button.attributes.type1)

    bags[0], bags[1] = {food}, {}
    Event("BAG_UPDATE_DELAYED")
    assert(button:IsVisible() and care.icon.texture == 123 and not care.icon.desaturated and button.count:GetText() == "1")
    assert(not PetStatusAlertDB.petFeedFoodByCharacter["Player-1"], "depletion must restore automatic mode")
    button.scripts.PreClick(button, "LeftButton")
    assert(button.attributes.type1 == "spell" and button.attributes["target-slot1"] == 1)
    button.scripts.PostClick(button, "LeftButton")
    assert(not menu.rows[43] and menu.rows[42].label == "Meat ×1" and menu.rows[0].isSelected(0))
    menu.rows[42].selectFood(42)
    menu.rows[0].selectFood(0)
    assert(care.icon.texture == 123 and not care.icon.desaturated and button.count:GetText() == "1")
    assert(not PetStatusAlertDB.petFeedFoodByCharacter["Player-1"])

    inCombat = true
    Event("PLAYER_REGEN_DISABLED")
    assert(not button:IsVisible() and not care:IsShown() and menu.closed and not button.foodMenu)
    menu.rows[42].selectFood(42)
    assert(not PetStatusAlertDB.petFeedFoodByCharacter["Player-1"], "combat must block stale menu callbacks")
    inCombat = false
    Event("PLAYER_REGEN_ENABLED")
    assert(button:IsVisible())
    button.scripts.PostClick(button, "RightButton")
    button.foodMenu.rows[42].selectFood(42)
    bags[0] = {}
    Event("BAG_UPDATE_DELAYED")
    assert(not care:IsShown() and not PetStatusAlertDB.petFeedFoodByCharacter["Player-1"])
    bags[0] = {food}
    Event("BAG_UPDATE_DELAYED")

    happiness, inCombat = 1, true
    Event("UNIT_HAPPINESS", "pet")
    assert(not care:IsShown(), "red with food still hides the button in combat")
    food.isLocked = true
    Event("ITEM_LOCK_CHANGED", 0, 1)
    assert(not care:IsShown(), "locked food must not count as exhausted")
    bags[0] = {}
    Event("BAG_UPDATE_DELAYED")
    assert(care:IsShown() and not button:IsVisible() and care.icon.texture == "UI-PetMad" and activeGlows[care])
    assert(session.addonFrame.scripts.OnUpdate and not care.scripts.OnUpdate)

    stance = "PET_MODE_ASSIST"
    Event("PET_BAR_UPDATE")
    assert(session.currentStatusKey == nil and care:IsVisible() and care.scripts.OnUpdate)
    local content = session.alertText.parent
    assert(care.point[2] == content)
    session.SetAlertIconSize(96)
    assert(anchor.clampInsets[1] < 0 and anchor.clampInsets[2] > 0 and anchor.clampInsets[3] > 0
        and anchor.clampInsets[4] < 0, "standalone red icon and its motion must fit at every edge")
    care.scripts.OnUpdate(care, 0.2)
    assert(content.point[5] ~= 0, "standalone red icon must share the float animation")
    session.SetAlertFloatAmplitude(0)
    assert(not care.scripts.OnUpdate and content.point[5] == 0)

    inCombat = false
    bags[0], food.isLocked = {food}, false
    Event("BAG_UPDATE_DELAYED")
    assert(button:IsVisible() and care.icon.texture == 123)
    happiness = 3
    Event("UNIT_HAPPINESS", "pet")
    assert(not care:IsShown() and not activeGlows[care])
    pet = false
    Event("UNIT_PET", "player")
    assert(not care:IsShown())
end)

print(string.format("RESULT: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
