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
    "SetNumeric", "SetSpacing", "StartMoving", "StopMovingOrSizing", "Raise"}) do
    Methods[name] = noop
end
function Methods:SetScript(key, callback) self.scripts[key] = callback end
function Methods:RegisterEvent(event)
    self.events = self.events or {}
    self.events[event] = true
end
function Methods:RegisterUnitEvent(event, unit)
    self:RegisterEvent(event)
    self.events[event] = unit
end
function Methods:UnregisterEvent(event)
    if self.events then self.events[event] = nil end
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
function Methods:GetFontString() return self end
function Methods:SetChecked(value) self.checked = value end
function Methods:GetChecked() return self.checked end
function Methods:HasFocus() return self.focused == true end
function Methods:SetTextColor(...) self.textColor = {...} end
function Methods:SetAlpha(alpha) self.alpha = alpha end
function Methods:Disable() self.disabled = true end
function Methods:SetButtonState(state) self.buttonState = state end
function Methods:SetParent(parent)
    if self.parent then
        for index, child in ipairs(self.parent.children) do
            if child == self then table.remove(self.parent.children, index); break end
        end
    end
    self.parent = parent
    if parent then parent.children[#parent.children + 1] = self end
end
function Methods:SetWidth(value) self.width = value end
function Methods:SetHeight(value) self.height = value end
function Methods:GetWidth() return self.width end
function Methods:GetHeight() return self.height end
function Methods:SetSize(width, height) self.width, self.height = width, height end
function Methods:SetClampRectInsets(...) self.clampInsets = {...} end
function Methods:SetHitRectInsets(...) self.hitInsets = {...} end
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
function Methods:GetVerticalScroll() return self.scrollOffset or 0 end
function Methods:GetVerticalScrollRange() return 300 end
function Methods:SetVerticalScroll(offset) self.scrollOffset = offset end

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
    NewTicker = function(interval, callback)
        local timer = Timer(callback); timer.interval = interval; tickers[#tickers + 1] = timer; return timer
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

Test("speech reads no alert text while disabled and reads it once per reminder", function()
    local originalGetText = psa.alertText.GetText
    local reads, before = 0, #spoken
    inCombat, PetStatusAlertDB.combatTTSEnabled = true, false
    psa.SetAlertIconMode("both")
    psa.ShowStatus("PASSIVE")
    psa.alertText.GetText = function(self)
        reads = reads + 1
        return originalGetText(self)
    end
    psa.RefreshCombatTTSReminder(true)
    assert(reads == 0 and #spoken == before and ActiveTickers() == 0)
    PetStatusAlertDB.combatTTSEnabled = true
    psa.RefreshCombatTTSReminder(true)
    assert(reads == 1 and #spoken == before + 1 and ActiveTickers() == 1)
    tickers[#tickers].callback()
    assert(reads == 2 and #spoken == before + 2)
    psa.alertText.GetText = originalGetText
    psa.HideStatus()
    inCombat = false
end)

-- Run the real local slider factory, supplying only its UI dependencies.
local file = assert(io.open("UI/Options.lua", "rb"))
local source = file:read("*a"); file:close()
local first = assert(source:find("local function AddTooltip", 1, true))
local last = assert(source:find("-- Color picker", first, true))
local environment = setmetatable({STYLE = {}, LAYOUT = {sliderWidth = 300},
    CreateText = function() return Object() end, HideSliderTemplateLabels = noop}, {__index = _G})
local createSlider = assert(load(source:sub(first, last - 1) .. "\nreturn CreateSliderRow",
    "@UI/Options.lua", "t", environment))()
local function FlushTimers()
    local pending = timers; timers = {}
    for _, timer in ipairs(pending) do if not timer.cancelled then timer.callback() end end
end
Test("hovering the font size slider passes tooltip opacity before wrapping", function()
    local panel = Object(UIParent)
    local hint = "调整屏幕提示文字的字体大小。默认：28。"
    local tooltip = {
        SetOwner = function(self, owner) self.owner = owner end,
        SetText = function(self, message, _, _, _, alpha, wrap)
            assert(type(alpha) == "number", "GameTooltip:SetText expects numeric opacity before wrap")
            assert(message == hint and alpha == 1 and wrap == true)
        end,
        Show = function(self) self.shown = true end,
        Hide = function(self) self.shown = false end,
    }
    environment.GameTooltip = tooltip
    local slider = createSlider(panel, "Font size", hint, 0, 12, 72, 1, 28, "28", noop)
    local labelHover = assert(panel.children[1])
    local ok, err = pcall(function()
        for _, target in ipairs({ labelHover, slider }) do
            target.scripts.OnEnter(target)
            assert(tooltip.owner == target and tooltip.shown)
            target.scripts.OnLeave(target)
            assert(not tooltip.shown)
        end
    end)
    environment.GameTooltip = nil
    assert(ok, err)
end)
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
        "Core/TTS.lua", "Core/PetLogic.lua", "Core/PetAutocast.lua", "Core/PetFeed.lua", "Core/WarriorLogic.lua",
        "Core/ForeverFormAlerts.lua", "Core/ForeverAspect.lua", "UI/Options.lua",
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
local function FindNode(node, predicate)
    if predicate(node) then return node end
    for _, child in ipairs(node.children) do
        local match = FindNode(child, predicate)
        if match then return match end
    end
end
local function FindText(node, value)
    return FindNode(node, function(child) return child:GetText() == value end)
end
local function FindButton(node, value)
    return FindNode(node, function(child) return child.template == "UIPanelButtonTemplate" and child:GetText() == value end)
end
local hunterLabels = {enUS = "Hunter", zhCN = "猎人", zhTW = "獵人", ruRU = "Охотник"}
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
        reloaded.OpenOptionsFrame()
        local frame = Upvalue(reloaded.RefreshOptionsFrameLocale, "optionsFrame")
        assert(frame.navButtons.HUNTER.text:GetText() == hunterLabels[locale],
            "standalone navigation kept the client language")
        for _, key in ipairs({"PASSIVE", "DEFENSIVE", "NO_PET", "PET_DEAD", "UNKNOWN", "WARRIOR_DEFENSIVE_STANCE"}) do
            assert(reloaded.GetDefaultMessage(key) == reloaded.LOCALIZED_MESSAGES[locale][key], key .. " used the wrong language")
        end
        assert(reloaded.STATUS_LABEL.WARRIOR_DEFENSIVE_STANCE == reloaded.UI["WARRIOR_DEFENSIVE_STANCE"],
            "Warrior label was lost while restoring language")
        reloaded.ShowStatus("NO_PET")
        assert(reloaded.alertText:GetText() == reloaded.LOCALIZED_MESSAGES[locale].NO_PET,
            "runtime alert did not use the restored language")
        local managerTabs = reloaded.GetSettingsDefinition({}).tabs
        assert(managerTabs[1].title == hunterLabels[locale],
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
Test("manager definition changes with language and ignores current specialization", function()
    local session = LoadLanguageSession({language = "zhCN"})
    local original = session.GetSettingsDefinition({})
    assert(session.GetSettingsDefinition({}) == original)
    session.ApplyManagerLanguage("enUS")
    local translated = session.GetSettingsDefinition({})
    assert(translated ~= original and translated.tabs[1].title == "Hunter", "manager reused old-language tabs")
    assert(session.GetSettingsDefinition({}) == translated)
    for _, tab in ipairs(translated.tabs) do
        assert(tab.key ~= "masters" and tab.key ~= "ammo", "Retail must not show master controls or Forever ammo")
    end
    for index = #session.STATUS_ORDER, 1, -1 do session.STATUS_ORDER[index] = nil end
    session.STATUS_ORDER[1] = "WARRIOR_DEFENSIVE_STANCE"
    assert(session.GetSettingsDefinition({}) == translated, "player status list changed the class catalog")
end)

Test("standalone navigation edits another class from an unsupported character", function()
    local originalClass = UnitClass
    UnitClass = function() return "Priest", "PRIEST" end
    local session = LoadLanguageSession({language = "enUS",
        customMessages = {NO_PET = "Legacy message"},
        statusEnabled = {NO_PET = true}, textColors = {NO_PET = {r = 0.5, g = 0.3, b = 0.2, a = 1}}})
    session.OpenOptionsFrame()
    local frame = Upvalue(session.RefreshOptionsFrameLocale, "optionsFrame")
    assert(frame.navButtons.HUNTER:IsShown() and frame.clientButtons.retail:IsVisible())
    assert(frame.navButtons.classes.text:GetText() == "- " .. session.UI.PET_SETTINGS)
    frame.navButtons.classes.scripts.OnClick()
    assert(not frame.navButtons.HUNTER:IsShown()
        and frame.navButtons.classes.text:GetText() == "+ " .. session.UI.PET_SETTINGS)
    frame.navButtons.classes.scripts.OnClick()
    assert(frame.navButtons.HUNTER:IsShown()
        and frame.navButtons.classes.text:GetText() == "- " .. session.UI.PET_SETTINGS)
    frame.navButtons.WARLOCK.scripts.OnClick()
    local warlockPage = frame.currentPage
    assert(not frame.viewForever and frame.clientButtons.retail:IsVisible())
    assert(frame.clientButtons.retail.buttonState == "PUSHED")
    local cards = warlockPage.children[1].children[1].children
    local card, nextCard = cards[3], cards[4]
    local spacing = card.point[5] - nextCard.point[5] - card:GetHeight()
    assert(card:GetHeight() <= 64 and spacing >= 0 and spacing <= 8, "alert cards should fit two compact rows")
    assert(card.children[4]:GetText() == "Default: No pet summoned!")
    local rules = cards[#cards - 1]
    local advanced = assert(FindButton(rules, "+ Advanced"))
    local ruleID = assert(FindNode(rules, function(control)
        return control.template == "InputBoxTemplate" and control:GetText() == "124691"
    end))
    assert(not ruleID:IsVisible() and FindButton(rules, "Affliction").buttonState == "PUSHED")
    advanced.scripts.OnClick(advanced)
    assert(ruleID:IsVisible())
    FindButton(rules, "Destruction").scripts.OnClick()
    assert(ruleID:GetText() == "125618")
    ruleID:SetText("135713")
    ruleID.scripts.OnEditFocusLost(ruleID)
    assert(session.GetWarlockSacrificeID(267) == 135713 and session.GetWarlockSacrificeID(265) == 124691)
    local wrongCard = assert(FindText(rules, session.UI.WARLOCK_WRONG_PET)).parent
    local toggle = assert(FindNode(wrongCard, function(node) return node.template == "UICheckButtonTemplate" end))
    assert(FindText(rules, session.UI.WRONG_PET_OFF) and not toggle:GetChecked())
    toggle:SetChecked(true)
    toggle.scripts.OnClick(toggle)
    assert(FindText(rules, session.UI.WRONG_PET_NONE))
    local sayaad = assert(FindText(rules, session.GetWarlockPetLabel(17))).point[2]
    sayaad:SetChecked(true)
    sayaad.scripts.OnClick(sayaad)
    assert(FindText(rules, session.UI.WARLOCK_PET_RULES_HINT) and session.GetWarlockBlockedPets(267)[17])
    toggle:SetChecked(false)
    toggle.scripts.OnClick(toggle)
    assert(sayaad:GetChecked() and FindText(rules, session.UI.WRONG_PET_OFF))
    local check, input
    for _, child in ipairs(card.children) do
        if child.template == "UICheckButtonTemplate" then check = child end
        if child.template == "InputBoxTemplate" then input = child end
    end
    assert(check:GetChecked() and input:GetText() == "Legacy message")
    check:SetChecked(false)
    check.scripts.OnClick(check)
    input:SetText("Warlock only")
    input.scripts.OnTextChanged(input, true)
    session.ResetStatusColor("NO_PET", "WARLOCK")
    assert(session.IsStatusEnabled("NO_PET", "HUNTER"))
    assert(session.GetDisplayMessage("NO_PET", "HUNTER") == "Legacy message")
    assert(session.GetStatusColor("NO_PET", "HUNTER") == 0.5)
    assert(not session.IsStatusEnabled("NO_PET", "WARLOCK"))
    assert(session.GetStatusColor("NO_PET", "WARLOCK") == 1)

    frame.clientButtons.forever.scripts.OnClick()
    frame.navButtons.WARLOCK.scripts.OnClick()
    local foreverPage = frame.currentPage.children[1].children[1]
    assert(frame.viewForever and frame.clientButtons.forever.buttonState == "PUSHED")
    assert(FindText(frame.clientButtons.forever.parent, session.UI.OTHER_CLIENT_SETTINGS):IsVisible())
    assert(not frame.navButtons.DEATHKNIGHT:IsShown() and frame.navButtons.ammo:IsShown())
    assert(FindText(foreverPage, "Pet: Aggressive") and FindText(foreverPage.children[#foreverPage.children], "Wrong summon alert"))
    assert(not FindButton(foreverPage, session.UI.CLASS_RESET))
    assert(foreverPage.children[3]:GetHeight() == card:GetHeight())
    local disabled = 0
    for _, child in ipairs(foreverPage.children[3].children) do
        if child.disabled then
            disabled = disabled + 1
            assert(child.alpha == 0.5 and not child.scripts.OnClick and not child.scripts.OnTextChanged)
        end
        if child.template == "UICheckButtonTemplate" then assert(child:GetChecked()) end
        if child.template == "InputBoxTemplate" then assert(child:GetText() == "") end
    end
    assert(disabled == 5, "all controls on a preview card should be disabled")
    frame.clientButtons.retail.scripts.OnClick()
    assert(frame.currentPage == warlockPage and input:GetText() == "Warlock only" and not check:GetChecked())

    frame.navButtons.WARRIOR.scripts.OnClick()
    local stancePage = frame.currentPage.children[1].children[1]
    assert(#stancePage.children == 4, "warrior settings should have one stance card and a reset action")
    frame.clientButtons.forever.scripts.OnClick()
    assert(frame.activePage == "WARLOCK", "each server must remember its own navigation")
    frame.navButtons.WARRIOR.scripts.OnClick()
    local foreverWarrior = frame.currentPage.children[1].children[1]
    assert(#foreverWarrior.children == 5 and not FindButton(foreverWarrior, session.UI.CLASS_RESET))
    for _, key in ipairs(session.GetClassAlertStatuses("WARRIOR", true)) do
        assert(FindText(foreverWarrior, session.UI[key]) and not session.IsStatusEnabled(key, "WARRIOR"))
    end
    frame.clientButtons.retail.scripts.OnClick()
    assert(frame.activePage == "WARRIOR")
    frame.navButtons.WARLOCK.scripts.OnClick()
    assert(frame.currentPage == warlockPage and input:GetText() == "Warlock only")
    frame.navButtons.classes.scripts.OnClick()
    assert(not frame.navButtons.WARLOCK:IsShown() and frame.currentPage == warlockPage)
    local reloaded = LoadLanguageSession(PetStatusAlertDB)
    assert(reloaded.GetDisplayMessage("NO_PET", "WARLOCK") == "Warlock only")
    reloaded.SetCustomMessage("NO_PET", "", "WARLOCK")
    assert(reloaded.GetDisplayMessage("NO_PET", "WARLOCK") == reloaded.GetDefaultMessage("NO_PET"))
    UnitClass = originalClass
end)

Test("cross-class preview uses its own icon and runtime restores the player's rule", function()
    local originalTexture, originalExists = C_Spell.GetSpellTexture, UnitExists
    C_Spell.GetSpellTexture = function(spellID) return spellID end
    UnitExists = function() return false end
    local session = LoadLanguageSession({language = "enUS", combatTTSEnabled = true})
    inCombat = true
    session.ShowStatus("NO_PET")
    local icon = session.alertText.parent.icon
    assert(icon.texture == 883 and ActiveTickers() == 1)
    local before = #spoken
    session.PreviewStatus("NO_PET", "WARLOCK")
    assert(icon.texture == 688 and session.currentStatusClass == "WARLOCK")
    assert(ActiveTickers() == 0 and #spoken == before)
    session.SetCustomMessage("NO_PET", "Hunter runtime", "HUNTER")
    session.SetCustomMessage("NO_PET", "Warlock preview", "WARLOCK")
    session.RefreshConfiguredAlert("NO_PET", "WARLOCK")
    assert(session.alertText:GetText() == "Warlock preview")
    session.StopSettingsPreview()
    assert(not session.currentStatusForce and icon.texture == 883)
    assert(session.alertText:GetText() == "Hunter runtime")
    session.HideStatus()
    inCombat, C_Spell.GetSpellTexture, UnitExists = false, originalTexture, originalExists
end)

Test("Forever opens its own class tab and shows Retail Warrior defaults", function()
    GetBuildInfo = function() return "1.60.1", "70862", "", 16001 end
    local session = LoadLanguageSession({language = "zhCN"})
    session.OpenOptionsFrame()
    local frame = Upvalue(session.RefreshOptionsFrameLocale, "optionsFrame")
    assert(frame.navButtons.WARRIOR:IsShown() and not frame.navButtons.DEATHKNIGHT:IsShown())
    frame.navButtons.MAGE.scripts.OnClick()
    assert(frame.viewForever and frame.navButtons.MAGE.text:GetText() == "法师")
    assert(frame.currentPage.children[1].children[1].children[1]:GetText() == "法师（召唤水元素）")
    assert(FindText(frame.currentPage, session.UI.AGGRESSIVE) and FindText(frame.currentPage, session.UI.MAGE_SUMMON_SETTINGS))
    frame.navButtons.WARRIOR.scripts.OnClick()
    local forever = frame.currentPage.children[1].children[1]
    local statuses = session.GetClassAlertStatuses("WARRIOR", true)
    assert(#forever.children == 6 and forever.children[1]:GetText() == "战士")
    for index, key in ipairs(statuses) do
        local card = forever.children[index + 2]
        local check = assert(FindNode(card, function(node) return node.template == "UICheckButtonTemplate" end))
        assert(FindText(card, session.UI[key]) and not check:GetChecked())
        if index ~= 2 then
            check:SetChecked(true)
            check.scripts.OnClick(check)
        end
    end
    frame.clientButtons.retail.scripts.OnClick()
    assert(frame.navButtons.DEATHKNIGHT:IsShown() and not frame.navButtons.ammo:IsShown())
    frame.navButtons.WARRIOR.scripts.OnClick()
    local retail = frame.currentPage.children[1].children[1]
    assert(retail.children[1]:GetText() == "武器 / 狂暴战士")
    assert(retail.children[3].children[3]:GetText() == "战士：防御姿态")
    assert(retail.children[3].children[4]:GetText():find("当前处于：防御姿态", 1, true))

    local tabs = session.GetSettingsDefinition({}).tabs
    local warriorTab = tabs[4]
    assert(warriorTab.key == "WARRIOR" and not warriorTab.subtabs)
    local toggles = {}
    warriorTab.build({ NewSection = function(_, title)
        return setmetatable({ Check = function(_, _, get, set) toggles[title] = { get = get, set = set } end },
            { __index = function() return noop end })
    end, AddSection = noop })
    for index, key in ipairs(statuses) do
        local toggle = assert(toggles[session.UI[key]])
        assert(toggle.set and toggle.get() == (index ~= 2))
    end
    local saved = PetStatusAlertDB
    local reloaded = LoadLanguageSession(saved)
    for index, key in ipairs(statuses) do
        assert(reloaded.IsStatusEnabled(key, "WARRIOR") == (index ~= 2))
    end
    GetBuildInfo = nil
end)
Test("Forever Aggressive uses its own icon, text, and settings entry", function()
    GetBuildInfo = function() return "1.60.1", "70790", "Nov 5 2026", 16001 end
    local session = LoadLanguageSession({language = "enUS"})
    session.SetAlertIconMode("both")
    session.SetStatusEnabled("AGGRESSIVE", true)
    session.ShowStatus("AGGRESSIVE")
    assert(session.alertText:GetText() == "Pet: Aggressive")
    assert(session.alertText.parent.icon.texture == "Interface\\Icons\\Ability_Racial_BloodRage")
    session.SetAlertIconMode("icon")
    assert(session.alertText.parent.icon:IsShown() and not session.alertText:IsShown())
    assert(session.STATUS_ORDER[4] == "DEFENSIVE" and session.STATUS_ORDER[5] == "AGGRESSIVE")
    assert(session.GetClassAlertStatuses("HUNTER", true)[5] == "AGGRESSIVE")
    assert(session.GetClassAlertStatuses("HUNTER", false)[5] == "UNKNOWN")
    session.HideStatus()
    GetBuildInfo = nil
end)
Test("Forever Warrior previews show their own localized stance text and icon", function()
    GetBuildInfo = function() return "1.60.1", "70790", "Nov 5 2026", 16001 end
    local originalClass, originalTexture = UnitClass, C_Spell.GetSpellTexture
    UnitClass = function() return "Warrior", "WARRIOR" end
    C_Spell.GetSpellTexture = function(id) return id end
    local session = LoadLanguageSession({language = "enUS"})
    session.SetAlertIconMode("both")
    for _, language in ipairs({"enUS", "zhCN", "zhTW", "ruRU"}) do
        session.ApplyManagerLanguage(language)
        session.PreviewStatus("PASSIVE")
        assert(not session.addonFrame:IsShown() and #session.STATUS_ORDER == 3)
        session.PreviewStatus("WARRIOR_DEFENSIVE_STANCE")
        assert(not session.addonFrame:IsShown())
        for _, key in ipairs(session.STATUS_ORDER) do
            session.PreviewStatus(key, "WARRIOR")
            assert(session.addonFrame:IsShown() and session.alertText:GetText() == session.GetDefaultMessage(key))
            assert(session.alertText.parent.icon.texture == session.FOREVER_FORM_ALERT_SPELLS[key])
        end
    end
    GetBuildInfo, UnitClass, C_Spell.GetSpellTexture = nil, originalClass, originalTexture
end)

Test("General controls the preview and position while visual pages keep the sample", function()
    local originalClass = UnitClass
    GetBuildInfo = function() return "1.60.1", "70862", "", 16001 end
    UnitClass = function() return "Warrior", "WARRIOR" end
    local session = LoadLanguageSession({language = "enUS"})
    session.OpenOptionsFrame()
    local frame = Upvalue(session.RefreshOptionsFrameLocale, "optionsFrame")
    frame.navButtons.display.scripts.OnClick()
    assert(not FindButton(frame.currentPage, session.UI.PREVIEW))
    frame.navButtons.general.scripts.OnClick()
    local preview = assert(FindButton(frame.currentPage, session.UI.PREVIEW))
    assert(preview.parent == frame.currentPage, "preview should sit outside the scroll frame")
    local lock = assert(FindButton(frame.currentPage, "Unlock move"))
    lock.scripts.OnClick()
    assert(not PetStatusAlertDB.alertLocked and lock:GetText() == "Lock position")
    lock.scripts.OnClick()
    assert(PetStatusAlertDB.alertLocked)
    preview.scripts.OnClick()
    assert(session.addonFrame:IsShown() and session.alertText:GetText() == session.UI.PREVIEW_SAMPLE)
    assert(preview:GetText() == session.UI.STOP_PREVIEW)
    frame.navButtons.display.scripts.OnClick()
    assert(session.IsDisplayPreviewActive(), "changing to Display should keep the General preview")
    session.ApplyManagerLanguage("zhCN")
    assert(session.IsDisplayPreviewActive() and session.alertText:GetText() == "提醒预览")
    frame.navButtons.general.scripts.OnClick()
    preview = assert(FindButton(frame.currentPage, session.UI.STOP_PREVIEW))
    session.RefreshPetStatusText()
    assert(session.IsDisplayPreviewActive(), "ordinary runtime refresh must not replace the sample")
    session.SetAlertIconMode("icon")
    assert(session.alertText.parent.icon:IsShown() and not session.alertText:IsShown())
    preview.scripts.OnClick()
    assert(not session.IsDisplayPreviewActive() and not session.addonFrame:IsShown())
    PetStatusAlertDB.alertPosition.x = 123
    local reset = assert(FindButton(frame.currentPage, session.UI.RESET_ALERT_POSITION))
    reset.scripts.OnClick()
    assert(PetStatusAlertDB.alertPosition.x == 0 and session.IsDisplayPreviewActive())
    frame.navButtons.display.scripts.OnClick()
    assert(session.IsDisplayPreviewActive())
    frame.currentPage.psaScroll:SetVerticalScroll(38)
    local displayPage = frame.currentPage
    local iconSlider = assert(FindNode(displayPage, function(node)
        return node.template == "OptionsSliderTemplate" and node:GetValue() == session.GetAlertIconSize()
    end))
    frame.navButtons.voice.scripts.OnClick()
    local voicePage = frame.currentPage
    assert(not session.IsDisplayPreviewActive() and not session.addonFrame:IsShown())
    session.SetAlertIconSize(62)
    for _ = 1, 3 do
        frame.navButtons.display.scripts.OnClick()
        assert(frame.currentPage == displayPage and displayPage.psaScroll:GetVerticalScroll() == 38)
        assert(iconSlider:GetValue() == 62)
        frame.navButtons.voice.scripts.OnClick()
        assert(frame.currentPage == voicePage)
    end
    GetBuildInfo, UnitClass = nil, originalClass
end)

Test("Forever Warrior icon opens a multi-select menu that outlives the visible alert", function()
    local oldBuild, oldClass, oldMenu = GetBuildInfo, UnitClass, MenuUtil
    local oldCount, oldForm, oldTexture = GetNumShapeshiftForms, GetShapeshiftFormInfo, C_Spell.GetSpellTexture
    GetBuildInfo = function() return "1.60.1", "70938", "", 16001 end
    UnitClass = function() return "Warrior", "WARRIOR" end
    local active = 2458
    GetNumShapeshiftForms = function() return 3 end
    GetShapeshiftFormInfo = function(index)
        local spellID = ({2457, 71, 2458})[index]
        return nil, active == spellID, true, spellID
    end
    C_Spell.GetSpellTexture = function(id) return id end
    local entries
    MenuUtil = { CreateContextMenu = function(owner, build)
        assert(owner == nil, "the menu must use the default top-level owner")
        entries = {}
        build(UIParent, {
            CreateTitle = noop,
            CreateCheckbox = function(_, label, selected, toggle, key)
                entries[key] = { label = label, selected = selected, toggle = toggle }
            end,
        })
    end }

    local session = LoadLanguageSession({language = "zhCN"})
    local battle, defensive, berserker = table.unpack(session.GetClassAlertStatuses("WARRIOR", true))
    session.SetStatusEnabled(berserker, true, "WARRIOR")
    local button = assert(FindNode(session.alertText.parent, function(node)
        return node.clicks and node.clicks[1] == "RightButtonUp"
    end))
    assert(button:IsVisible() and session.currentStatusKey == berserker)
    button.scripts.OnClick(button, "LeftButton")
    assert(not entries)

    session.SetAlertIconMode("text")
    assert(not button:IsVisible())
    session.SetAlertIconMode("both")
    session.SetAlertPositionLocked(false)
    assert(not button:IsVisible())
    session.SetAlertPositionLocked(true)
    session.PreviewStatus(berserker, "WARRIOR")
    assert(not button:IsVisible(), "previewing the same stance must disable the menu")
    session.RefreshPetStatusText()
    assert(button:IsVisible())

    button.scripts.OnClick(button, "RightButton")
    assert(entries[battle].label == "战斗姿态" and entries[defensive].label == "防御姿态"
        and entries[berserker].label == "狂暴姿态")
    assert(entries[berserker].selected(berserker) and not entries[battle].selected(battle))
    entries[berserker].toggle(berserker)
    assert(not button:IsVisible() and not entries[berserker].selected(berserker))
    entries[battle].toggle(battle)
    entries[defensive].toggle(defensive)
    assert(entries[battle].selected(battle) and entries[defensive].selected(defensive))
    assert(session.IsStatusEnabled(battle, "WARRIOR") and session.IsStatusEnabled(defensive, "WARRIOR"))
    assert(not session.currentStatusKey)
    active = 71
    session.RefreshPetStatusText()
    assert(button:IsVisible() and session.currentStatusKey == defensive)

    GetBuildInfo, UnitClass, MenuUtil = oldBuild, oldClass, oldMenu
    GetNumShapeshiftForms, GetShapeshiftFormInfo, C_Spell.GetSpellTexture = oldCount, oldForm, oldTexture
end)

Test("Forever Paladin ignores old buff settings and has no aura controls", function()
    local oldBuild, oldClass, oldBook = GetBuildInfo, UnitClass, C_SpellBook
    local oldAuras, oldTexture = C_UnitAuras, C_Spell.GetSpellTexture
    GetBuildInfo = function() return "1.60.1", "70938", "", 16001 end
    UnitClass = function() return "Paladin", "PALADIN" end
    C_SpellBook = {IsSpellKnown = function(id) return id == 465 end}
    C_UnitAuras = {GetUnitAuras = function() error("Paladin must not scan auras") end}
    C_Spell.GetSpellTexture = function(id) return id end
    local ok, err = pcall(function()
        local session = LoadLanguageSession({language = "enUS", buffAlertsEnabled = true,
            foreverClassBuffs = {PALADIN_AURA = true}})
        assert(not session.GetClassAlertStatuses("PALADIN", true))
        assert(not session.addonFrame.events.UNIT_AURA)
        assert(not Upvalue(session.RefreshCombatAspectAlert, "frame"))
        assert(not session.GetForeverFormAlertStatuses("PALADIN"))
        for _, tab in ipairs(session.GetSettingsDefinition({}).tabs) do
            assert(tab.key ~= "PALADIN", "Forever Paladin must not expose a class-alert page")
        end
        session.OpenOptionsFrame()
        local frame = Upvalue(session.RefreshOptionsFrameLocale, "optionsFrame")
        assert(not frame.navButtons.PALADIN)
    end)
    GetBuildInfo, UnitClass, C_SpellBook, C_UnitAuras, C_Spell.GetSpellTexture =
        oldBuild, oldClass, oldBook, oldAuras, oldTexture
    assert(ok, err)
end)

Test("Forever Mage page updates eligibility when the summon ability is learned", function()
    local originalClass, originalSpellBook = UnitClass, C_SpellBook
    local knowsSummon = false
    GetBuildInfo = function() return "1.60.1", "70862", "", 16001 end
    UnitClass = function() return "Mage", "MAGE" end
    C_SpellBook = { IsSpellKnown = function(id) return knowsSummon and id == 31687 end }
    local session = LoadLanguageSession({language = "zhCN"})
    session.OpenOptionsFrame()
    local frame = Upvalue(session.RefreshOptionsFrameLocale, "optionsFrame")
    frame.navButtons.classes.scripts.OnClick()
    frame.navButtons.MAGE.scripts.OnClick()
    assert(FindText(frame.currentPage, session.UI.ELIGIBILITY_UNMET))
    knowsSummon = true
    session.addonFrame.scripts.OnEvent(session.addonFrame, "SPELLS_CHANGED")
    assert(FindText(frame.currentPage, session.UI.ELIGIBILITY_MET))
    frame.clientButtons.retail.scripts.OnClick()
    assert(not FindText(frame.currentPage, session.UI.ELIGIBILITY_MET))
    GetBuildInfo, UnitClass, C_SpellBook = nil, originalClass, originalSpellBook
end)

Test("voice settings provide an out-of-combat sample and save both playback modes", function()
    local session = LoadLanguageSession({language = "enUS"})
    session.OpenOptionsFrame()
    local frame = Upvalue(session.RefreshOptionsFrameLocale, "optionsFrame")
    frame.navButtons.voice.scripts.OnClick()
    local page = frame.currentPage
    local before = #spoken
    assert(session.GetCombatTTSInterval() == 3)
    FindButton(page, session.UI.TTS_SAMPLE).scripts.OnClick()
    assert(#spoken == before + 1 and spoken[#spoken] == session.UI.PREVIEW_SAMPLE)
    session.SetCombatTTSInterval(6)
    FindButton(page, session.UI.TTS_ONCE).scripts.OnClick()
    assert(session.GetCombatTTSInterval() == 0 and session.GetCombatTTSRepeatInterval() == 6)
    PetStatusAlertDB.combatTTSEnabled, inCombat = true, true
    session.ShowStatus("PASSIVE")
    session.RefreshCombatTTSReminder(true)
    assert(#spoken == before + 2 and ActiveTickers() == 0)
    session.ShowStatus("DEFENSIVE")
    assert(#spoken == before + 3 and ActiveTickers() == 0)
    session.PreviewStatus("PASSIVE", "HUNTER")
    assert(#spoken == before + 3 and ActiveTickers() == 0)
    session.ShowStatus("DEFENSIVE")
    FindButton(page, session.UI.TTS_REPEAT).scripts.OnClick()
    assert(session.GetCombatTTSInterval() == 6 and tickers[#tickers].interval == 6)
    tickers[#tickers].callback()
    assert(#spoken == before + 5)
    session.HideStatus()
    inCombat = false
    assert(LoadLanguageSession(PetStatusAlertDB).GetCombatTTSInterval() == 6)
end)

Test("class reset waits for confirmation and isolates class and client rules", function()
    local session = LoadLanguageSession({language = "enUS", customMessages = {NO_PET = "Legacy"}})
    session.SetCustomMessage("NO_PET", "Custom Warlock", "WARLOCK")
    session.SetStatusEnabled("NO_PET", false, "WARLOCK")
    session.SetWarlockBlockedPet(265, 17, true)
    session.SetWarlockBlockedPet(0, 17, true)
    session.SetWarlockSacrificeID(265, 123)
    session.SetClassOption("warlockIgnoreSacrifice", false)
    session.SetClassOption("mageSummonID", 111)
    session.SetCombatTTSInterval(9)
    session.OpenOptionsFrame()
    local frame = Upvalue(session.RefreshOptionsFrameLocale, "optionsFrame")
    frame.navButtons.WARLOCK.scripts.OnClick()
    local confirm
    StaticPopupDialogs = {}
    StaticPopup_Show = function(key, title, body, data)
        assert(title:find("Warlock", 1, true) and body == session.UI.CLASS_RESET_BODY)
        confirm = function() StaticPopupDialogs[key].OnAccept(nil, data) end
    end
    FindButton(frame.currentPage, session.UI.CLASS_RESET).scripts.OnClick()
    assert(confirm and session.GetCustomMessage("NO_PET", "WARLOCK") == "Custom Warlock")
    confirm()
    assert(session.IsStatusEnabled("NO_PET", "WARLOCK") and session.GetCustomMessage("NO_PET", "WARLOCK") == "")
    assert(not session.GetWarlockBlockedPets(265) and session.GetWarlockBlockedPets(0)[17])
    assert(session.GetWarlockSacrificeID(265) == 124691 and session.GetClassOption("warlockIgnoreSacrifice"))
    assert(session.GetCustomMessage("NO_PET", "HUNTER") == "Legacy" and session.GetClassOption("mageSummonID") == 111)
    assert(session.GetCombatTTSInterval() == 9)
    StaticPopup_Show, StaticPopupDialogs = nil, nil
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

Test("global animation page keeps the General preview and updates both active glow rates", function()
    local oldBuild, oldLib, oldTexture = GetBuildInfo, LibStub, C_Spell.GetSpellTexture
    GetBuildInfo = function() return "1.60.1", "70938", "", 16001 end
    C_Spell.GetSpellTexture = function() return 123 end
    local ticks = {}
    LibStub = function()
        return {
            PixelGlow_Start = function(frame, _, _, _, _, _, _, _, _, key)
                local glow = Object()
                function glow:GetScript(script) return self.scripts[script] end
                local index = #ticks + 1
                ticks[index] = 0
                glow:SetScript("OnUpdate", function() ticks[index] = ticks[index] + 1 end)
                frame["_PixelGlow" .. key] = glow
            end,
            PixelGlow_Stop = function(frame, key) frame["_PixelGlow" .. key] = nil end,
        }
    end
    local ok, err = pcall(function()
        local session = LoadLanguageSession({language = "zhCN"})
        session.OpenOptionsFrame()
        local frame = Upvalue(session.RefreshOptionsFrameLocale, "optionsFrame")
        frame.navButtons.display.scripts.OnClick()
        assert(not FindText(frame.currentPage, session.UI.ANIMATION_GLOW_FPS))
        assert(not FindText(frame.currentPage, session.UI.ANIMATION_AMPLITUDE))
        frame.navButtons.classes.scripts.OnClick()
        assert(frame.navButtons.animation:IsVisible() and not frame.navButtons.display:IsShown())
        frame.navButtons.general.scripts.OnClick()
        local preview = assert(FindButton(frame.currentPage, session.UI.PREVIEW))
        preview.scripts.OnClick()
        frame.navButtons.animation.scripts.OnClick()
        local page = frame.currentPage
        assert(FindText(page, session.UI.ANIMATION_FLOAT) and FindText(page, session.UI.ANIMATION_GLOW_FPS))
        local slider = assert(FindNode(page, function(node)
            return node.template == "OptionsSliderTemplate" and node:GetValue() == 20
        end))
        assert(not FindButton(page, session.UI.PREVIEW) and session.IsDisplayPreviewActive())
        session.SetAmmoAlert("LOW_BULLETS", 9, 123)
        local anchor = session.addonFrame
        assert(session.IsDisplayPreviewActive() and #ticks == 2)
        anchor.scripts.OnUpdate(anchor, 0.06)
        assert(ticks[1] == 1 and ticks[2] == 0, "the main glow should refresh before the ammo glow at the default rate")
        anchor.scripts.OnUpdate(anchor, 0.01)
        assert(ticks[2] == 1)

        slider:SetValue(30)
        slider.scripts.OnMouseUp(slider)
        assert(session.GetAlertGlowFPS() == 30 and FindText(page, "30 次/秒"))
        anchor.scripts.OnUpdate(anchor, 0.045)
        assert(#ticks == 2 and ticks[1] == 2 and ticks[2] == 2, "the live glows should update sooner without restarting")
        session.SetAmmoAlert()
        frame.navButtons.general.scripts.OnClick()
        assert(session.IsDisplayPreviewActive())
        local stop = assert(FindButton(frame.currentPage, session.UI.STOP_PREVIEW))
        stop.scripts.OnClick()
        assert(not session.IsDisplayPreviewActive() and not anchor.scripts.OnUpdate)

        local manager = session.GetSettingsDefinition({})
        local general = manager.tabs[#manager.tabs]
        assert(general.key == "general")
        local headings, buttons = {}, {}
        general.build({NewSection = function(_, title)
            headings[#headings + 1] = title
            return {Check = noop, Dropdown = noop, ButtonRow = function(_, items)
                for _, item in ipairs(items) do buttons[item.text] = item.onClick end
            end}
        end, AddSection = noop})
        assert(headings[1] == session.UI.POSITION_AND_PREVIEW and buttons[session.UI.RESET_ALERT_POSITION])
        buttons[session.UI.PREVIEW]()
        manager.OnTabShow("animation")
        assert(session.IsDisplayPreviewActive())
        manager.OnTabShow("voice")
        assert(not session.IsDisplayPreviewActive())
        for _, tab in ipairs(manager.tabs) do
            if tab.key == "animation" then
                local foundSlider = false
                tab.build({NewSection = function() return {
                    ButtonRow = noop, Check = noop,
                    ValueSlider = function(_, label, low, high, _, get)
                        if label == session.UI.ANIMATION_GLOW_FPS then
                            assert(low == 10 and high == 30 and get() == 30)
                            foundSlider = true
                        end
                    end,
                } end, AddSection = noop})
                assert(foundSlider)
                local reloaded = LoadLanguageSession(PetStatusAlertDB)
                assert(reloaded.GetAlertGlowFPS() == 30)
                return
            end
        end
        error("QFXAddonManager is missing the Animation tab")
    end)
    GetBuildInfo, LibStub, C_Spell.GetSpellTexture = oldBuild, oldLib, oldTexture
    assert(ok, err)
end)

Test("server navigation keeps Forever Hunter tabs and ammo separate", function()
    local oldBuild = GetBuildInfo
    local ok, err = pcall(function()
        GetBuildInfo = function() return "1.60.1", "70938", "", 16001 end
        local session = LoadLanguageSession({language = "zhCN", buffAlertsEnabled = false,
            foreverClassBuffs = {ASPECT = false}})
        local tab, hunter, hunterTools
        for _, candidate in ipairs(session.GetSettingsDefinition({}).tabs) do
            if candidate.key == "ammo" then tab = candidate end
            if candidate.key == "HUNTER" then hunter = candidate end
            if candidate.key == "hunterTools" then hunterTools = candidate end
        end
        assert(tab and tab.title == session.UI.AMMO_TAB)
        assert(hunter and not hunter.subtabs)
        assert(hunterTools and hunterTools.title == "猎人专用" and #hunterTools.subtabs == 2
            and hunterTools.subtabs[1].key == "feeding" and hunterTools.subtabs[2].key == "aspect")
        local section = {
            Check = function(_, label, get, set)
                assert(label == session.UI.AMMO_ENABLE and get())
                set(false)
                assert(not get())
                set(true)
            end,
            EditBox = function(_, _, get, set, _, _, opts)
                assert(opts.numeric and get() == 100)
                assert(set("160") == 160 and get() == 160)
            end,
        }
        tab.build({NewSection = function() return section end, AddSection = noop})

        session.OpenOptionsFrame()
        local frame = Upvalue(session.RefreshOptionsFrameLocale, "optionsFrame")
        assert(frame.activePage == "HUNTER" and frame.viewForever)
        assert(frame.clientButtons.retail:IsVisible() and frame.clientButtons.forever:IsVisible())
        assert(not frame.hunterButtons.aspect:IsVisible() and not frame.hunterButtons.feeding:IsVisible())
        assert(FindText(frame.currentPage, session.UI.AGGRESSIVE))
        assert(not FindText(frame.currentPage, session.UI.FEED_SETTINGS))
        local nav = frame.navButtons
        assert(nav.classes.text:GetText() == "- 宠物提醒")
        local lastY = nav.classes.point[5]
        for _, key in ipairs({"HUNTER", "MAGE", "WARLOCK", "WARRIOR", "display", "voice", "hunterTools", "ammo"}) do
            assert(nav[key]:IsShown() and nav[key].point[5] < lastY, key .. " is out of order")
            lastY = nav[key].point[5]
        end
        nav.classes.scripts.OnClick()
        assert(not nav.HUNTER:IsShown() and not nav.display:IsShown() and not nav.voice:IsShown())
        assert(nav.hunterTools:IsShown() and nav.ammo:IsShown())
        nav.classes.scripts.OnClick()
        nav.hunterTools.scripts.OnClick()
        assert(frame.hunterButtons.aspect:IsVisible() and frame.hunterButtons.feeding:IsVisible())
        assert(FindText(frame.currentPage, session.UI.FEED_ENABLED) and not FindText(frame.currentPage, session.UI.AGGRESSIVE))
        local feedingPage = frame.currentPage
        frame.hunterButtons.aspect.scripts.OnClick()
        local aspectPage = frame.currentPage
        local aspectCheck = assert(FindNode(aspectPage, function(node) return node.template == "UICheckButtonTemplate" end))
        assert(not aspectCheck:GetChecked() and not FindText(aspectPage, session.UI.FEED_ENABLED))
        aspectCheck:SetChecked(true)
        aspectCheck.scripts.OnClick(aspectCheck)
        assert(session.GetCombatAspectAlertEnabled(), "an old master setting must not disable the new checkbox")
        frame.clientButtons.retail.scripts.OnClick()
        assert(not frame.hunterButtons.feeding:IsVisible() and not frame.navButtons.ammo:IsShown()
            and not frame.navButtons.hunterTools:IsShown() and frame.navButtons.DEATHKNIGHT:IsShown())
        frame.clientButtons.forever.scripts.OnClick()
        assert(frame.currentPage == aspectPage and aspectCheck:GetChecked())
        frame.hunterButtons.feeding.scripts.OnClick()
        assert(frame.currentPage == feedingPage)
        frame.navButtons.ammo.scripts.OnClick()
        assert(not frame.navButtons.masters and not frame.hunterButtons.aspect:IsVisible())
        local input = assert(FindNode(frame.currentPage, function(node) return node.template == "InputBoxTemplate" end))
        local ammoCheck = assert(FindNode(frame.currentPage, function(node) return node.template == "UICheckButtonTemplate" end))
        assert(ammoCheck:GetChecked() and input:GetText() == "160")
        function input:ClearFocus() self.scripts.OnEditFocusLost(self) end
        input:SetText("250")
        input.scripts.OnEnterPressed(input)
        assert(session.GetAmmoThreshold() == 250)
        input:SetText("300")
        input.scripts.OnEscapePressed(input)
        assert(session.GetAmmoThreshold() == 250 and input:GetText() == "250")
        assert(session.SetAmmoThreshold("bad") == 250 and session.SetAmmoThreshold(10000) == 9999)
        session.SetAmmoThreshold(250)
        ammoCheck:SetChecked(false)
        ammoCheck.scripts.OnClick(ammoCheck)
        assert(not session.GetAmmoAlertEnabled() and session.GetAmmoThreshold() == 250)
        local saved = PetStatusAlertDB
        local reloaded = LoadLanguageSession(saved)
        assert(not reloaded.GetAmmoAlertEnabled() and reloaded.GetAmmoThreshold() == 250 and reloaded.GetCombatAspectAlertEnabled())
        local migrated = LoadLanguageSession({language = "enUS", ammoThreshold = 0})
        assert(not migrated.GetAmmoAlertEnabled() and migrated.GetAmmoThreshold() == 100)
        migrated.SetAmmoAlertEnabled(true)
        assert(migrated.GetAmmoAlertEnabled() and migrated.GetAmmoThreshold() == 100)

        GetBuildInfo = nil
        local retail = LoadLanguageSession({language = "enUS", ammoThreshold = 250,
            petFeedEnabled = false, foreverClassBuffs = {ASPECT = false}})
        retail.OpenOptionsFrame()
        local options = Upvalue(retail.RefreshOptionsFrameLocale, "optionsFrame")
        options.clientButtons.forever.scripts.OnClick()
        options.navButtons.hunterTools.scripts.OnClick()
        options.hunterButtons.feeding.scripts.OnClick()
        local feedCheck = assert(FindText(options.currentPage, retail.UI.FEED_ENABLED)).point[2]
        assert(feedCheck.disabled and feedCheck:GetChecked(), "the other client must show defaults without editing")
        options.hunterButtons.aspect.scripts.OnClick()
        local previewCheck = assert(FindNode(options.currentPage, function(node)
            return node.template == "UICheckButtonTemplate"
        end))
        assert(previewCheck.disabled and previewCheck:GetChecked() and not previewCheck.scripts.OnClick)
        options.navButtons.ammo.scripts.OnClick()
        local previewInput = assert(FindNode(options.currentPage, function(node) return node.template == "InputBoxTemplate" end))
        local previewAmmoCheck = assert(FindNode(options.currentPage, function(node) return node.template == "UICheckButtonTemplate" end))
        assert(previewAmmoCheck.disabled and previewAmmoCheck:GetChecked() and not previewAmmoCheck.scripts.OnClick)
        assert(previewInput.disabled and previewInput:GetText() == "100" and retail.GetAmmoThreshold() == 250)
    end)
    GetBuildInfo = oldBuild
    assert(ok, err)
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

    local session = LoadLanguageSession({language = "enUS", buffAlertsEnabled = false, foreverClassBuffs = {ASPECT = false},
        supplyAlertPosition = {point = "CENTER", relativePoint = "CENTER", x = -60, y = -20}})
    local events = session.addonFrame.events
    assert(events.BAG_UPDATE_DELAYED and events.UNIT_INVENTORY_CHANGED == "player" and events.PLAYER_EQUIPMENT_CHANGED)
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
    local anchor = session.addonFrame
    local row = Upvalue(session.SetAmmoAlert, "supplyFrame")
    local frameCount, timerCount = #row.children, #timers
    assert(reads == 1 and not next(activeGlows) and not anchor.scripts.OnUpdate, "100 must not warn or animate")

    count = 99
    Event("UNIT_INVENTORY_CHANGED", "pet")
    Event("PLAYER_EQUIPMENT_CHANGED", 5)
    assert(#pending == 0, "other units and armor slot changes must not schedule ammo checks")
    Event("UNIT_INVENTORY_CHANGED", "player")
    Event("BAG_UPDATE_DELAYED")
    Event("PLAYER_EQUIPMENT_CHANGED", 0)
    assert(#pending == 1, "ammo checks must coalesce")
    FlushEvents()
    assert(reads == 2 and #row.children == frameCount + 1 and #timers == timerCount)
    local alert = row.children[#row.children]
    local _, badge, label = table.unpack(alert.children)
    assert(alert:IsVisible() and activeGlows[alert] and alert.icon.texture == 45678)
    assert(badge:GetText() == "99" and session.currentStatusKey == nil)
    assert(alert.point[2] == row and row.parent.parent == session.addonFrame and session.addonFrame:IsShown())
    assert(row.point[1] == "LEFT" and row.point[2] == content and row.point[3] == "CENTER"
        and row.point[4] + alert.point[4] == 0, "the first supply icon must start at the anchor")
    anchor.scripts.OnUpdate(anchor, 0.2)
    local floatY = content.point[5]
    assert(floatY ~= 0, "ammo must float without a pet status")
    assert(not label and badge.point[1] == "TOP" and badge.point[2] == alert and badge.point[3] == "BOTTOM",
        "ammo should draw just its remaining count below the icon")
    local tooltip = Object()
    function tooltip:IsForbidden() return false end
    function tooltip:IsOwned(owner) return self.owner == owner end
    function tooltip:SetOwner(owner) self.owner = owner end
    GameTooltip = tooltip
    alert.scripts.OnEnter(alert)
    assert(tooltip:GetText() == "Low arrows (99 left)")

    local position = alert.point
    count = 98
    Event("BAG_UPDATE_DELAYED")
    FlushEvents()
    assert(badge:GetText() == "98" and tooltip:GetText() == "Low arrows (98 left)" and #timers == timerCount)
    assert(itemInfoReads == 2, "inventory events must reuse weapon and ammo metadata")
    assert(alert.point == position, "changing the count should not rebuild the row")
    FlushTimers()
    assert(alert:IsVisible() and activeGlows[alert], "out-of-combat warning must stay visible")
    session.ApplyManagerLanguage("zhCN")
    assert(badge:GetText() == "98" and tooltip:GetText() == "箭矢不足（剩余 98）")
    session.ApplyManagerLanguage("enUS")

    local beforeCombat = reads
    Event("BAG_UPDATE_DELAYED")
    inCombat = true
    Event("PLAYER_REGEN_DISABLED")
    assert(not alert:IsVisible() and not activeGlows[alert] and not tooltip:IsShown())
    assert(not anchor.scripts.OnUpdate and content.point[5] == 0, "hiding the last alert must stop and reset floating")
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
    assert(alert.point[2] == row and row.point[1] == "RIGHT" and row.point[2] == content.icon
        and row.point[3] == "LEFT" and row.point[4] < 0, "supply icons must sit left of the pet status")
    assert(content.point[4] - content:GetWidth() / 2 + content.icon:GetWidth() / 2 == 0,
        "stance icon must stay at the shared saved center")
    session.SetPetCareAlert("feed", 34567)
    local care = session.GetPetCareFrame()
    assert(care:IsVisible() and care.point[2] == content.icon and row.point[2] == care and alert.point[2] == row)
    session.SetAlertIconSize(72)
    assert(alert:GetWidth() == 72 and care:GetWidth() == 72 and content.icon:GetWidth() == 72)
    assert(anchor:GetWidth() / 2 - anchor.clampInsets[1] >= 72 / 2 + 8 + 72 + 8 + row:GetWidth(),
        "left edge must include the pet care and supply icons")
    assert(anchor:GetWidth() / 2 + anchor.clampInsets[2] >= content:GetWidth() - 72 / 2,
        "right edge must include the stance text")
    PetStatusAlertDB.customMessages.PASSIVE = string.rep("Long alert text ", 30)
    session.ShowStatus("PASSIVE")
    assert(anchor:GetWidth() - anchor.clampInsets[1] + anchor.clampInsets[2] <= UIParent:GetWidth(),
        "the row must fit even when the centered icon leaves most of the text to its right")
    PetStatusAlertDB.customMessages.PASSIVE = nil
    session.HideStatus()
    assert(alert:IsVisible() and care.point[1] == "CENTER" and row.point[2] == care
        and anchor.scripts.OnUpdate, "pet care takes the anchor when it is the only visible pet icon")
    session.SetPetCareAlert(nil)
    assert(alert:IsVisible() and anchor:IsShown() and row.point[1] == "LEFT" and row.point[4] + alert.point[4] == 0)
    anchor.StartMoving = function(self) self.moving = true end
    anchor.StopMovingOrSizing = function(self) self.moving = false end
    anchor.GetPoint = function(self) return table.unpack(self.point) end
    session.SetAlertPositionLocked(false)
    assert(anchor:IsShown() and row:IsShown() and anchor.mouseEnabled and not row.mouseEnabled
        and not row.scripts.OnDragStart and not row.scripts.OnDragStop)
    session.ShowStatus("PASSIVE")
    assert(anchor.hitInsets[1] < 0, "drag target must cover the icons to the left of the pet status")
    anchor.scripts.OnDragStart(anchor)
    assert(anchor.moving and anchor.mouseEnabled)
    anchor:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 120, -40)
    anchor.scripts.OnDragStop(anchor)
    assert(not anchor.moving and PetStatusAlertDB.alertPosition.point == "TOPLEFT"
        and PetStatusAlertDB.alertPosition.x == 120 and PetStatusAlertDB.alertPosition.y == -40)
    assert(PetStatusAlertDB.supplyAlertPosition.x == -60 and PetStatusAlertDB.supplyAlertPosition.y == -20
        and alert:IsVisible(), "the old supply position is preserved but no longer drives a frame")
    local anchorWidth, anchorHeight, anchorPoint = anchor:GetWidth(), anchor:GetHeight(), anchor.point
    session.HideStatus()
    assert(anchor:GetWidth() == anchorWidth and anchor:GetHeight() == anchorHeight and anchor.point == anchorPoint,
        "the saved edge anchor must keep its center when the pet status disappears")
    session.SetAlertPositionLocked(true)
    assert(anchor:IsShown() and not anchor.mouseEnabled)

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
        and not activeGlows[alert])
    session.SetAmmoThreshold(20)
    FlushEvents()
    assert(not alert:IsShown(), "an amount equal to the custom threshold must not warn")
    session.SetAmmoThreshold(21)
    FlushEvents()
    assert(alert:IsShown(), "a custom threshold must apply without another inventory event")
    local readsBeforeDisable = reads
    session.SetAmmoAlertEnabled(false)
    assert(not events.UNIT_INVENTORY_CHANGED and not events.PLAYER_EQUIPMENT_CHANGED,
        "turning ammo off must remove ammo-only subscriptions")
    Event("BAG_UPDATE_DELAYED")
    FlushEvents()
    assert(not alert:IsShown() and reads == readsBeforeDisable and session.GetAmmoThreshold() == 21,
        "the switch must disable ammo checks and keep the threshold")
    session.SetAmmoAlertEnabled(true)
    FlushEvents()
    assert(events.UNIT_INVENTORY_CHANGED == "player" and alert:IsShown() and session.GetAmmoThreshold() == 21)
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
    local oldBuild, oldAuras, oldSecrets = GetBuildInfo, C_UnitAuras, C_Secrets
    GetBuildInfo = function() return "1.60.1", "70862", "", 16001 end
    local happiness, pet, stance = 2, true, "PET_MODE_PASSIVE"
    local eating, restricted = false, false
    C_Secrets = {ShouldAurasBeSecret = function() return restricted end}
    C_UnitAuras = {GetUnitAuraBySpellID = function(unit, spell)
        assert(unit == "pet" and spell == 1539 and not inCombat and not restricted)
        return eating and {} or nil
    end}
    local food = {itemID = 42, stackCount = 1, iconFileID = 123, itemName = "Meat"}
    local fish = {itemID = 43, stackCount = 4, iconFileID = 456, itemName = "Fish"}
    local bags = {[0] = {food}, [1] = {}}
    local slotReads, happinessReads, foodCountReads = {}, 0, 0
    C_PetInfo = {
        GetPetHappiness = function() happinessReads = happinessReads + 1; return happiness end,
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
            foodCountReads = foodCountReads + 1
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
    local latestMenu
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
            if self.release then self.release(self) end
        end
        local root = MenuUtil.CreateRootMenuDescription()
        Menu.PopulateDescription(build, owner, root)
        menu:SetMenuDescription(root)
        latestMenu = menu
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
    assert(session.addonFrame.events.UNIT_AURA == "pet")
    eating = true
    button.scripts.PreClick(button, "LeftButton")
    assert(not button.attributes.type1, "the live click guard must block feeding again before the aura refresh runs")
    Event("UNIT_AURA", "pet")
    assert(not button:IsVisible() and not care:IsShown(), "feeding in progress must hide the reminder")
    restricted = true
    Event("UNIT_AURA", "pet")
    assert(button:IsVisible(), "an unavailable aura must not be read or treated as active")
    eating, restricted = false, false
    Event("UNIT_AURA", "pet")
    session.SetClassOption("petFeedEnabled", false)
    session.SetClassOption("petUnhappyAlertEnabled", false)
    assert(not care:IsVisible() and not session.addonFrame.events.BAG_UPDATE)
    bags[0] = {}
    session.SetClassOption("petFeedEnabled", true)
    session.SetClassOption("petUnhappyAlertEnabled", true)
    assert(not button:IsVisible(), "re-enable must discard cached bag slots from before shutdown")
    bags[0] = {food}
    Event("BAG_UPDATE_DELAYED")
    assert(button:IsVisible())
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
    local bankReads, bankTimers = happinessReads, #delays
    Event("BAG_UPDATE", -1)
    Event("BAG_UPDATE_DELAYED")
    assert(happinessReads == bankReads and #delays == bankTimers, "bank changes must not refresh pet care")
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
    eating = true
    Event("BAG_UPDATE_DELAYED")
    assert(not care:IsShown() and not activeGlows[care])
    assert(anchor:GetWidth() / 2 - anchor.clampInsets[1] == session.alertText.parent.icon:GetWidth() / 2 + 3,
        "hidden care icon must release its reserved space")
    eating = false
    Event("UNIT_AURA", "pet")
    local emptyCount = assert(FindText(care, "0"))
    assert(care:IsShown() and not button:IsVisible() and care.icon.desaturated and emptyCount:IsVisible(),
        "running out during feeding only shows the empty-food indicator once the effect ends")

    bags[0] = {food}
    Event("BAG_UPDATE_DELAYED")
    assert(button:IsVisible() and not emptyCount:IsShown(), "picking up suitable food restores the feed button")
    bags[0] = {food, fish}
    bags[1] = {{itemID = 43, stackCount = 2}, {itemID = 44, stackCount = 7}}
    Event("BAG_UPDATE_DELAYED")
    happiness = 3
    Event("UNIT_HAPPINESS", "pet")
    assert(not button:IsVisible())
    session.OpenOptionsFrame()
    local options = Upvalue(session.RefreshOptionsFrameLocale, "optionsFrame")
    options.navButtons.hunterTools.scripts.OnClick()
    options.hunterButtons.feeding.scripts.OnClick()
    local feedSettings = options.currentPage
    local feedCheck = assert(FindText(feedSettings, session.UI.FEED_ENABLED)).point[2]
    local unhappyCheck = assert(FindText(feedSettings, session.UI.PET_UNHAPPY_ENABLED)).point[2]
    local foodSelector = assert(FindButton(feedSettings, session.UI.FEED_CHOOSE_AUTO))
    assert(feedCheck:GetChecked() and foodSelector:GetText() == "Choose Automatically")
    foodSelector.scripts.OnClick(foodSelector)
    latestMenu.rows[43].selectFood(43)
    assert(foodSelector:GetText() == "Fish" and PetStatusAlertDB.petFeedFoodByCharacter["Player-1"] == 43)
    happiness = 2
    feedCheck:SetChecked(false)
    feedCheck.scripts.OnClick(feedCheck)
    assert(not session.GetClassOption("petFeedEnabled") and not button:IsVisible())
    local events = session.addonFrame.events
    assert(events.UNIT_HAPPINESS == "pet" and not events.UNIT_AURA and not events.BAG_UPDATE and not events.BAG_UPDATE_DELAYED
        and not events.ITEM_LOCK_CHANGED)
    happiness = 1
    local beforeUnhappy = foodCountReads
    Event("UNIT_HAPPINESS", "pet")
    assert(care:IsShown() and care.icon.texture == "UI-PetMad" and not button:IsVisible())
    assert(foodCountReads == beforeUnhappy, "the standalone unhappy reminder must not read food counts")
    unhappyCheck:SetChecked(false)
    unhappyCheck.scripts.OnClick(unhappyCheck)
    assert(not care:IsShown() and not events.UNIT_HAPPINESS, "both disabled settings must stop happiness monitoring")
    local inactiveReads = happinessReads
    Event("PET_UI_UPDATE")
    assert(happinessReads == inactiveReads)
    feedCheck:SetChecked(true)
    feedCheck.scripts.OnClick(feedCheck)
    assert(button:IsVisible() and care.icon.texture == 456 and events.BAG_UPDATE and events.UNIT_HAPPINESS == "pet")
    unhappyCheck:SetChecked(true)
    unhappyCheck.scripts.OnClick(unhappyCheck)
    happiness = 2
    latestMenu.rows[0].selectFood(0)
    assert(foodSelector:GetText() == "Choose Automatically" and care.icon.texture == 123)
    options:Hide()

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
    assert(care:IsShown() and emptyCount:IsVisible() and not PetStatusAlertDB.petFeedFoodByCharacter["Player-1"])
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
    assert(session.currentStatusKey == nil and care:IsVisible() and anchor.scripts.OnUpdate and not care.scripts.OnUpdate)
    local content = session.alertText.parent
    assert(care.point[2] == content)
    session.SetAlertIconSize(96)
    assert(anchor.clampInsets[1] < 0 and anchor.clampInsets[2] > 0 and anchor.clampInsets[3] > 0
        and anchor.clampInsets[4] < 0, "standalone red icon and its motion must fit at every edge")
    anchor.scripts.OnUpdate(anchor, 0.2)
    assert(content.point[5] ~= 0, "standalone red icon must share the float animation")
    session.SetAlertFloatAmplitude(0)
    assert(not anchor.scripts.OnUpdate and content.point[5] == 0)

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
    session.SetClassOption("petFeedEnabled", false)
    session.SetClassOption("petUnhappyAlertEnabled", false)
    pet, happiness = true, 2
    assert(session.ResetClassSettings("HUNTER") and events.BAG_UPDATE and events.UNIT_HAPPINESS == "pet")
    assert(button:IsVisible(), "resetting Hunter settings must restore the watchers and refresh the current bags")
    GetBuildInfo, C_UnitAuras, C_Secrets = oldBuild, oldAuras, oldSecrets
end)

Test("old master switches do not gate individual pet alerts", function()
    local session = LoadLanguageSession({language = "enUS", petAlertsEnabled = false})
    assert(session.addonFrame.events.UNIT_PET)
    session.ShowStatus("PASSIVE")
    assert(session.addonFrame:IsShown())
    session.SetStatusEnabled("PASSIVE", false)
    session.ShowStatus("PASSIVE")
    assert(not session.addonFrame:IsShown())
end)

Test("Forever Hunter warns in combat for personal Cheetah or Pack and clears on switch or removal", function()
    local oldBuild, oldClass, oldBook, oldAuras = GetBuildInfo, UnitClass, C_SpellBook, C_UnitAuras
    local oldAfter, oldSpell, oldSecret, oldSecrets = C_Timer.After, C_Spell, issecretvalue, C_Secrets
    local secret = {}
    local auras, pending, reads, restricted = {}, {}, 0, false
    local known = {[13165] = true, [14318] = true, [5118] = true, [13159] = true}
    local cheetah = {spellId = 5118, auraInstanceID = 1, sourceUnit = "player"}
    local pack = {spellId = 13159, auraInstanceID = 2, sourceUnit = "player"}
    local partyPack = {spellId = 13159, auraInstanceID = 3, sourceUnit = "party1"}
    GetBuildInfo = function() return "1.60.1", "70938", "", 16001 end
    UnitClass = function() return "Hunter", "HUNTER" end
    C_SpellBook = {IsSpellKnown = function(id) return known[id] end}
    C_UnitAuras = {GetUnitAuras = function(unit, filter)
        reads = reads + 1
        assert(unit == "player" and filter == "HELPFUL" and not inCombat and not restricted)
        return auras
    end}
    issecretvalue = function(value) return value == secret end
    C_Secrets = {ShouldAurasBeSecret = function() return restricted end}
    C_Spell = {GetSpellTexture = function(id) return 100000 + id end}
    C_Timer.After = function(_, callback) pending[#pending + 1] = callback end
    local ok, err = pcall(function()
        local session = LoadLanguageSession({buffAlertsEnabled = false, petAlertsEnabled = false})
        local listener = assert(Upvalue(session.RefreshCombatAspectAlert, "frame"))
        local function Flush()
            local callbacks = pending
            pending = {}
            for _, fn in ipairs(callbacks) do fn() end
        end
        local function Event(event, ...)
            if listener.events[event] then listener.scripts.OnEvent(listener, event, ...) end
        end
        local function Aura(change)
            Event("UNIT_AURA", "player", change)
        end
        local function Cast(id, unit)
            Event("UNIT_SPELLCAST_SUCCEEDED", unit or "player", "cast", id)
        end
        local function ExpectAspect(spell)
            local icon = Upvalue(session.SetCombatAspectAlert, "aspectFrame")
            assert(spell and icon and icon:IsVisible() and icon.icon.texture == 100000 + spell and activeGlows[icon]
                or not spell and (not icon or not icon:IsVisible()), "unexpected aspect reminder for " .. tostring(spell))
        end
        local function Combat(start)
            inCombat = start
            Event(start and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED")
        end

        auras = {cheetah, partyPack}
        Flush()
        assert(reads == 1 and listener.events.UNIT_AURA == "player" and not session.addonFrame.events.UNIT_AURA)
        ExpectAspect(nil)
        restricted = true
        Combat(true)
        ExpectAspect(14318)
        Cast(14318, "pet")
        Cast(secret)
        Cast(75)
        Aura({addedAuras = {partyPack, {spellId = secret}}, removedAuraInstanceIDs = {secret}})
        ExpectAspect(14318)
        Cast(14318)
        ExpectAspect(nil)
        Cast(5118)
        Aura({addedAuras = {cheetah}})
        ExpectAspect(14318)
        Aura({removedAuraInstanceIDs = {1}})
        ExpectAspect(nil)
        Aura({isFullUpdate = true})
        Event("ADDON_RESTRICTION_STATE_CHANGED")
        Flush()
        assert(reads == 1, "combat must not read an aura snapshot")

        auras = {partyPack}
        Combat(false)
        restricted = false
        Flush()
        Combat(true)
        ExpectAspect(nil)
        Cast(13159)
        ExpectAspect(14318)
        known[469145] = true
        Event("SPELLS_CHANGED")
        ExpectAspect(469145)
        Cast(469145)
        ExpectAspect(nil)
        Cast(13159)
        ExpectAspect(469145)
        Event("PLAYER_DEAD")
        ExpectAspect(nil)
        Event("PLAYER_ALIVE")
        Cast(13159)
        ExpectAspect(469145)
        auras = {pack}
        Combat(false)
        Flush()
        ExpectAspect(nil)
        Combat(true)
        ExpectAspect(469145)
        session.SetCombatAspectAlertEnabled(false)
        ExpectAspect(nil)
        assert(not next(listener.events), "the aspect switch must remove its subscriptions")
        session.SetCombatAspectAlertEnabled(true)
        assert(listener.events.UNIT_SPELLCAST_SUCCEEDED == "player")
        Cast(13159)
        ExpectAspect(469145)
        session.SetCombatAspectAlertEnabled(false)
        ExpectAspect(nil)
        Flush()
        assert(not next(listener.events) and not session.addonFrame.scripts.OnUpdate)
    end)
    inCombat = false
    GetBuildInfo, UnitClass, C_SpellBook, C_UnitAuras = oldBuild, oldClass, oldBook, oldAuras
    C_Timer.After, C_Spell, issecretvalue, C_Secrets = oldAfter, oldSpell, oldSecret, oldSecrets
    assert(ok, err)
end)

Test("Forever Hunter checks Growl by location and Cower against the real Growl state", function()
    local previous = {}
    local function Mock(key, value)
        previous[#previous + 1] = {key, _G[key]}
        _G[key] = value
    end
    local pending, oldAfter = {}, C_Timer.After
    local raid, instanceType, pet, dead = false, "none", true, false
    local growl, cower, petSpellCount, reads = false, true, 3, 0
    local secret = {}
    Mock("GetBuildInfo", function() return "1.60.1", "70938", "", 16001 end)
    Mock("UnitClass", function() return "Hunter", "HUNTER" end)
    Mock("IsInRaid", function() return raid end)
    Mock("IsInInstance", function() return instanceType ~= "none", instanceType end)
    Mock("UnitExists", function(unit) return unit == "pet" and pet end)
    Mock("UnitIsDeadOrGhost", function(unit) return unit == "pet" and dead end)
    Mock("issecretvalue", function(value) return value == secret end)
    local names = {[2649] = "低吼", [1742] = "畏缩"}
    Mock("C_Spell", {
        GetSpellName = function(id) return names[id] end,
        GetSpellTexture = function(id) return 100000 + id end,
    })
    Mock("Enum", {SpellBookSpellBank = {Pet = 1}})
    Mock("C_SpellBook", {
        HasPetSpells = function() reads = reads + 1; return petSpellCount end,
        GetSpellBookItemName = function(slot, bank)
            assert(bank == 1)
            return ({"撕咬", "低吼", "畏缩"})[slot], "Rank 3"
        end,
        GetSpellBookItemAutoCast = function(slot, bank)
            assert(bank == 1 and slot ~= 1)
            if slot == 2 then return true, growl end
            return true, cower
        end,
    })
    C_Timer.After = function(_, fn) pending[#pending + 1] = fn end
    local ok, err = pcall(function()
        local session = LoadLanguageSession({language = "zhCN", petFeedEnabled = false, petUnhappyAlertEnabled = false})
        local function Flush()
            local callbacks = pending
            pending = {}
            for _, fn in ipairs(callbacks) do fn() end
        end
        local function Event(event, ...)
            local frame = session.addonFrame
            if frame.events[event] then frame.scripts.OnEvent(frame, event, ...) end
        end
        local function Expect(spell, mark)
            local icon = Upvalue(session.SetPetAutocastAlert, "autocastFrame")
            assert(spell and icon and icon:IsVisible() and icon.icon.texture == 100000 + spell
                and Upvalue(session.SetPetAutocastAlert, "autocastBadge"):GetText() == mark
                or not spell and (not icon or not icon:IsVisible()), "unexpected autocast reminder for " .. tostring(spell))
        end

        -- Solo outdoors; a normal party uses the same rule. Event bursts only read once.
        Event("PLAYER_ENTERING_WORLD")
        Event("GROUP_ROSTER_UPDATE")
        Flush()
        Expect(2649, "+")
        assert(reads == 1)
        growl = true
        Event("PET_BAR_UPDATE")
        Flush()
        Expect(1742, "−")
        cower = false
        Event("PET_BAR_UPDATE")
        Flush()
        Expect()

        -- A five-player instance disables Growl even while solo.
        instanceType = "party"
        Event("ZONE_CHANGED_NEW_AREA")
        Flush()
        Expect(2649, "−")
        growl = false
        Event("PET_BAR_UPDATE")
        Flush()
        Expect(1742, "+")
        cower = true
        Event("PET_BAR_UPDATE")
        Flush()
        Expect()
        instanceType = "raid"
        Event("PLAYER_ENTERING_WORLD")
        Flush()
        Expect()
        instanceType, raid, growl = "none", true, true
        Event("ZONE_CHANGED_NEW_AREA")
        Flush()
        Expect(2649, "−")
        raid, cower = false, false -- Convert back to a regular party without moving.
        Event("GROUP_ROSTER_UPDATE")
        Flush()
        Expect()

        petSpellCount, cower = 2, true
        Event("UNIT_PET", "player")
        Flush()
        Expect() -- A pet without Cower can't trigger its warning.
        petSpellCount, growl = 3, secret
        Event("PET_BAR_UPDATE")
        Flush()
        Expect() -- Unknown Growl never implies a Cower target.
        growl, dead = false, true
        Event("UNIT_FLAGS", "pet")
        Flush()
        Expect()
        dead = false
        Event("UNIT_FLAGS", "pet")
        Flush()
        Expect(2649, "+")
        session.SetClassOption("petAutocastAlertEnabled", false)
        Expect()
        assert(not session.addonFrame.events.GROUP_ROSTER_UPDATE and not session.addonFrame.events.ZONE_CHANGED_NEW_AREA)
        session.ResetClassSettings("HUNTER")
        Flush()
        Expect(2649, "+")
        pet = false
        Event("UNIT_PET", "player")
        Flush()
        Expect()

        Mock("GetBuildInfo", function() return "12.1.5", "70783", "", 120105 end)
        local retail = LoadLanguageSession({language = "zhCN"})
        assert(not retail.RefreshPetAutocast and not retail.addonFrame.events.GROUP_ROSTER_UPDATE)
    end)
    C_Timer.After = oldAfter
    for index = #previous, 1, -1 do _G[previous[index][1]] = previous[index][2] end
    assert(ok, err)
end)

Test("older Retail buff and consumable settings stay inactive after upgrade", function()
    local saved = {language = "enUS", buffAlertsEnabled = true, foodBuffAlertEnabled = true,
        retailSupply = {FOOD = true, WEAPON = true, CLASS = true}}
    local retail = LoadLanguageSession(saved)
    assert(not retail.RefreshCombatAspectAlert and not retail.GetForeverAmmo and not retail.RefreshRetailBuffAlerts)
    assert(not retail.addonFrame.events.UNIT_AURA and not retail.addonFrame.events.UNIT_INVENTORY_CHANGED)
    for _, tab in ipairs(retail.GetSettingsDefinition({}).tabs) do
        assert(tab.key ~= "auras" and tab.key ~= "ammo")
    end
end)

print(string.format("RESULT: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
