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
    "SetJustifyH", "SetOrientation", "SetMinMaxValues", "SetValueStep", "SetObeyStepOnDrag"}) do
    Methods[name] = noop
end
function Methods:SetScript(key, callback) self.scripts[key] = callback end
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
function Methods:GetFrameLevel() return 1 end
function Methods:SetPoint(...) self.point = {...} end
function Methods:EnableMouse(value) self.mouseEnabled = value end
function Methods:SetFont() self.fontUpdates = (self.fontUpdates or 0) + 1 end
function Methods:SetText(value) self.text = value end
function Methods:GetText() return self.text end
function Methods:SetWidth(value) self.width = value end
function Methods:GetWidth() return self.width end
function Methods:SetSize(width, height) self.width, self.height = width, height end
function Methods:GetStringWidth() return #self.text * 12 end
function Methods:GetStringHeight() return 28 end
function Methods:SetTexture(value) self.texture = value end
function Methods:CreateTexture() self.icon = Object(self); return self.icon end
function Methods:CreateFontString() return Object(self) end
function Methods:SetValue(value)
    self.value = value
    if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, value) end
end
function Methods:GetValue() return self.value end

CreateFrame = function(_, _, parent) return Object(parent) end
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
        "Core/TTS.lua", "Core/PetLogic.lua", "Core/WarriorLogic.lua", "UI/Options.lua",
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
print(string.format("RESULT: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
