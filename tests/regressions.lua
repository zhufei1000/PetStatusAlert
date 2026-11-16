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
        "Core/FoodBuff.lua", "Core/FoodPicker.lua", "Core/TTS.lua", "Core/PetLogic.lua", "Core/PetFeed.lua", "Core/WarriorLogic.lua", "Core/RetailBuffs.lua", "UI/Options.lua",
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
        assert(reloaded.GetSettingsDefinition({}).tabs[1].title == hunterLabels[locale],
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
    assert(not frame.navButtons.HUNTER:IsShown() and not frame.clientButtons.retail:IsVisible())
    assert(frame.navButtons.classes.text:GetText() == "+ Class Settings")
    frame.navButtons.classes.scripts.OnClick()
    assert(frame.navButtons.HUNTER:IsShown() and frame.navButtons.classes.text:GetText() == "- Class Settings")
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
    local foreverPage = frame.currentPage.children[1].children[1]
    assert(frame.viewForever and frame.clientButtons.forever.buttonState == "PUSHED")
    assert(frame.clientButtons.forever:GetText():find(session.UI.READ_ONLY_TAB, 1, true))
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
    local unsupported = frame.currentPage.children[1].children[1]
    assert(#unsupported.children == 2 and unsupported.children[2]:GetText() == session.UI.CLASS_UNSUPPORTED)
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
    frame.navButtons.classes.scripts.OnClick()
    assert(frame.navButtons.WARRIOR:IsShown() and frame.navButtons.DEATHKNIGHT:IsShown())
    frame.navButtons.MAGE.scripts.OnClick()
    assert(frame.viewForever and frame.navButtons.MAGE.text:GetText() == "法师")
    assert(frame.currentPage.children[1].children[1].children[1]:GetText() == "法师（召唤水元素）")
    assert(FindText(frame.currentPage, session.UI.AGGRESSIVE) and FindText(frame.currentPage, session.UI.MAGE_SUMMON_SETTINGS))
    frame.navButtons.WARRIOR.scripts.OnClick()
    assert(#frame.currentPage.children[1].children[1].children == 2)
    frame.clientButtons.retail.scripts.OnClick()
    local retail = frame.currentPage.children[1].children[1]
    assert(retail.children[1]:GetText() == "武器 / 狂暴战士")
    assert(retail.children[3].children[3]:GetText() == "战士：防御姿态")
    assert(retail.children[3].children[4]:GetText():find("当前处于：防御姿态", 1, true))

    local tabs = session.GetSettingsDefinition({}).tabs
    assert(tabs[5].key == "WARRIOR" and tabs[5].subtabs[2].title == "|cff9a9a9a正式服 · 仅预览|r")
    local section = {
        Check = function(_, _, get, set, _, opts) assert(get() and not set and opts.enabled == false) end,
        EditBox = function(_, _, get, set, _, _, opts) assert(get() == "" and not set and opts.enabled == false) end,
        ColorGrid = function(_, entries) assert(not entries[1].setColor and entries[1].enabled == false) end,
        ButtonRow = function(_, buttons)
            for _, button in ipairs(buttons) do assert(not button.onClick and button.enabled == false) end
        end,
    }
    tabs[5].subtabs[2].build({NewSection = function(_, title, note)
        if title == "战士：防御姿态" then
            assert(note == "当前处于：防御姿态")
            return section
        end
        assert(title == "武器 / 狂暴战士" and note[1] == session.UI.OTHER_CLIENT_SETTINGS)
        return {}
    end, AddSection = noop})
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

Test("display sample works on Forever Warrior and stops when leaving the page", function()
    local originalClass = UnitClass
    GetBuildInfo = function() return "1.60.1", "70862", "", 16001 end
    UnitClass = function() return "Warrior", "WARRIOR" end
    local session = LoadLanguageSession({language = "enUS"})
    session.OpenOptionsFrame()
    local frame = Upvalue(session.RefreshOptionsFrameLocale, "optionsFrame")
    frame.navButtons.display.scripts.OnClick()
    local preview = assert(FindButton(frame.currentPage, session.UI.PREVIEW))
    assert(preview.parent == frame.currentPage, "preview should sit outside the scroll frame")
    preview.scripts.OnClick()
    assert(session.addonFrame:IsShown() and session.alertText:GetText() == session.UI.PREVIEW_SAMPLE)
    assert(preview:GetText() == session.UI.STOP_PREVIEW)
    session.ApplyManagerLanguage("zhCN")
    assert(session.IsDisplayPreviewActive() and session.alertText:GetText() == "提醒预览")
    preview = assert(FindButton(frame.currentPage, session.UI.STOP_PREVIEW))
    session.RefreshPetStatusText()
    assert(session.IsDisplayPreviewActive(), "ordinary runtime refresh must not replace the sample")
    session.SetAlertIconMode("icon")
    assert(session.alertText.parent.icon:IsShown() and not session.alertText:IsShown())
    preview.scripts.OnClick()
    assert(not session.IsDisplayPreviewActive() and not session.addonFrame:IsShown())
    preview.scripts.OnClick()
    frame.currentPage.psaScroll:SetVerticalScroll(38)
    frame.navButtons.voice.scripts.OnClick()
    assert(not session.IsDisplayPreviewActive() and not session.addonFrame:IsShown())
    frame.navButtons.display.scripts.OnClick()
    assert(frame.currentPage.psaScroll:GetVerticalScroll() == 38)
    GetBuildInfo, UnitClass = nil, originalClass
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
    frame.navButtons.classes.scripts.OnClick()
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

Test("Forever threshold settings share the saved numeric value", function()
    GetBuildInfo = function() return "1.60.1", "70862", "", 16001 end
    local session = LoadLanguageSession({language = "zhCN"})
    assert(session.GetAmmoThreshold() == 100)
    local tabs = session.GetSettingsDefinition({}).tabs
    local tab = tabs[#tabs]
    assert(tab.key == "auras" and tab.title == "增益提醒")
    assert(#tab.subtabs == 2 and tab.subtabs[1].key == "consumables" and tab.subtabs[2].key == "ammo")
    local section = {Check = function(_, _, get, set)
        assert(not get())
        set(true)
        assert(get())
        set(false)
    end, EditBox = function(_, _, get, set, _, _, opts)
        assert(opts.numeric and get() == 100)
        assert(set("160") == 160 and get() == 160)
    end}
    local managerPage = {NewSection = function() return section end, AddSection = noop}
    tab.subtabs[1].build(managerPage)
    tab.subtabs[2].build(managerPage)

    session.OpenOptionsFrame()
    local foreverFrame = Upvalue(session.RefreshOptionsFrameLocale, "optionsFrame")
    foreverFrame.navButtons.auras.scripts.OnClick()
    assert(FindText(foreverFrame.currentPage, session.UI.FOOD_PICKER_ENABLE))
    foreverFrame.auraButtons.ammo.scripts.OnClick()
    assert(not FindText(foreverFrame.currentPage, session.UI.FOOD_PICKER_ENABLE))
    local page = foreverFrame.currentPage.children[1].children[1]
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
    local retail = LoadLanguageSession({language = "enUS", ammoThreshold = 250})
    retail.OpenOptionsFrame()
    local frame = Upvalue(retail.RefreshOptionsFrameLocale, "optionsFrame")
    frame.navButtons.auras.scripts.OnClick()
    frame.auraButtons.ammo.scripts.OnClick()
    local retailPage = frame.currentPage.children[1].children[1]
    local retailSection = retailPage.children[#retailPage.children]
    local retailInput = retailSection.children[#retailSection.children]
    assert(retailInput.disabled and retailInput:GetText() == "100" and not retailInput.scripts.OnEditFocusLost)
    assert(retail.GetAmmoThreshold() == 250)
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
    local row = Upvalue(session.SetAmmoAlert, "supplyFrame")
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
    assert(alert.point[2] == row and row.parent == UIParent and not session.addonFrame:IsShown())
    assert(label:GetText() == "Low arrows" and label.point[1] == "LEFT" and label.point[2] == alert
        and label.point[3] == "RIGHT")

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
    assert(alert.point[2] == row)
    assert(content.point[4] - content:GetWidth() / 2 + content.icon:GetWidth() / 2 == 0,
        "stance icon must stay at its own saved center")
    session.SetPetCareAlert("feed", 34567)
    local care = session.GetPetCareFrame()
    assert(care:IsVisible() and care.point[2] == content.icon and alert.point[2] == row)
    session.SetAlertIconSize(72)
    assert(alert:GetWidth() == 72 and care:GetWidth() == 72 and content.icon:GetWidth() == 72)
    local anchor = session.addonFrame
    assert(anchor:GetWidth() / 2 - anchor.clampInsets[1] >= 72 / 2 + 8 + 72,
        "pet row must fit the pet care icon")
    assert(anchor:GetWidth() / 2 + anchor.clampInsets[2] >= content:GetWidth() - 72 / 2,
        "right edge must include the stance text")
    PetStatusAlertDB.customMessages.PASSIVE = string.rep("Long alert text ", 30)
    session.ShowStatus("PASSIVE")
    assert(anchor:GetWidth() - anchor.clampInsets[1] + anchor.clampInsets[2] <= UIParent:GetWidth(),
        "the row must fit even when the centered icon leaves most of the text to its right")
    PetStatusAlertDB.customMessages.PASSIVE = nil
    session.HideStatus()
    assert(alert:IsVisible() and care.point[1] == "CENTER" and alert.point[2] == row)
    session.SetPetCareAlert(nil)
    assert(alert:IsVisible() and not anchor:IsShown())
    for _, draggable in ipairs({anchor, row}) do
        draggable.StartMoving = function(self) self.moving = true end
        draggable.StopMovingOrSizing = function(self) self.moving = false end
        draggable.GetPoint = function(self) return table.unpack(self.point) end
    end
    session.SetAlertPositionLocked(false)
    assert(anchor:IsShown() and row:IsShown() and anchor.mouseEnabled and row.mouseEnabled)
    row.scripts.OnDragStart(row)
    assert(row.moving and not anchor.moving)
    row:SetPoint("CENTER", UIParent, "CENTER", -60, -20)
    row.scripts.OnDragStop(row)
    assert(PetStatusAlertDB.supplyAlertPosition.x == -60 and PetStatusAlertDB.alertPosition.x == 0)
    anchor.scripts.OnDragStart(anchor)
    assert(anchor.moving and anchor.mouseEnabled)
    anchor:SetPoint("CENTER", UIParent, "CENTER", 120, -40)
    anchor.scripts.OnDragStop(anchor)
    assert(not anchor.moving and PetStatusAlertDB.alertPosition.x == 120 and PetStatusAlertDB.alertPosition.y == -40)
    assert(PetStatusAlertDB.supplyAlertPosition.x == -60 and PetStatusAlertDB.supplyAlertPosition.y == -20)
    session.SetAlertPositionLocked(true)
    assert(not anchor:IsShown() and not row.mouseEnabled)

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

Test("Forever food reminder handles gains and removals without polling", function()
    local pending = {}
    local level, reads = 59, 0
    local aura, otherFood, restricted, restrictedFoodID, resting, dead
    local after, newTimer = C_Timer.After, C_Timer.NewTimer
    local priorAuras, priorSecrets = C_UnitAuras, C_Secrets
    local priorLevel, priorResting, priorDead = UnitLevel, IsResting, UnitIsDeadOrGhost
    local priorSpellName = C_Spell.GetSpellName
    C_Timer.After = function(_, callback) pending[#pending + 1] = callback end
    C_Timer.NewTimer = function() error("Food checks must not create an expiry timer") end
    GetBuildInfo = function() return "1.60.1", "70888", "", 16001 end
    UnitLevel = function() return level end
    IsResting = function() return resting end
    UnitIsDeadOrGhost = function() return dead end
    C_Secrets = {
        ShouldAurasBeSecret = function() return restricted end,
        ShouldSpellAuraBeSecret = function(id) return restrictedFoodID == id end,
    }
    C_Spell.GetSpellName = function(id) assert(id == 19705); return "Well Fed" end
    C_UnitAuras = {
        GetAuraDataBySpellName = function(unit, name, filter)
            assert(unit == "player" and name == "Well Fed" and filter == "HELPFUL")
            assert(not restricted and not inCombat and not resting and not dead)
            reads = reads + 1
            return aura
        end,
        GetPlayerAuraBySpellID = function(id)
            assert(id ~= restrictedFoodID, "secret spell IDs must not be queried")
            if id == 18192 then return otherFood end
        end,
    }
    local session = LoadLanguageSession({ language = "enUS", foodBuffAlertEnabled = true })
    local events, pet = session.addonFrame.events, session.addonFrame
    local row = Upvalue(session.SetAmmoAlert, "supplyFrame")
    local function Event(event, ...)
        if events[event] then pet.scripts.OnEvent(pet, event, ...) end
    end
    local function Flush()
        local callbacks = pending
        pending = {}
        for _, callback in ipairs(callbacks) do callback() end
    end

    Event("PLAYER_ENTERING_WORLD")
    Flush()
    local food = assert(FindNode(row, function(node) return node.icon and node.icon.texture == 136000 end))
    local label = food.children[2]
    assert(reads == 1 and events.UNIT_AURA == "player" and food:IsVisible())
    assert(label:GetText() == "Missing food buff · XP food gives +5% kill XP")
    Event("UNIT_AURA", "player", { addedAuras = {{isHelpful = true, spellId = 99, name = "Other"}} })
    Flush()
    assert(reads == 1, "unrelated aura changes must not trigger a food lookup")

    level = 60
    Event("PLAYER_LEVEL_UP", level)
    assert(label:GetText() == "Missing food buff" and food:IsVisible() and reads == 1)
    session.SetAmmoAlert("LOW_ARROWS", 12, 12345)
    local ammo = row.children[#row.children]
    assert(ammo:IsVisible() and food:IsVisible() and ammo.point[2] == row and food.point[4] > ammo.point[4])
    session.SetAmmoAlert()

    aura = { isHelpful = true, spellId = 999, name = "Well Fed", auraInstanceID = 30 }
    Event("UNIT_AURA", "player", { addedAuras = {aura} })
    Flush()
    assert(reads == 2 and not food:IsShown() and events.UNIT_AURA == "player")
    Event("UNIT_AURA", "player", { removedAuraInstanceIDs = {999}, updatedAuraInstanceIDs = {30} })
    assert(#pending == 0 and reads == 2, "unrelated removals and duration changes must not cause a lookup")

    otherFood = { auraInstanceID = 31 }
    aura = nil
    Event("UNIT_AURA", "player", { removedAuraInstanceIDs = {30} })
    Flush()
    assert(reads == 3 and not food:IsShown(), "removing one food aura must not hide another")
    otherFood = nil
    Event("UNIT_AURA", "player", { removedAuraInstanceIDs = {31} })
    Flush()
    assert(reads == 4 and food:IsVisible() and label:GetText() == "Missing food buff")

    aura = { isHelpful = true, spellId = 999, name = "Well Fed", auraInstanceID = 32 }
    Event("UNIT_AURA", "player", { isFullUpdate = true })
    Flush()
    assert(reads == 5 and not food:IsShown())

    inCombat = true
    Event("PLAYER_REGEN_DISABLED")
    assert(not events.UNIT_AURA)
    inCombat = false
    restricted = true
    Event("PLAYER_REGEN_ENABLED")
    Flush()
    assert(reads == 5 and not food:IsShown() and not events.UNIT_AURA)

    restricted = false
    Event("ADDON_RESTRICTION_STATE_CHANGED")
    Flush()
    assert(reads == 6 and events.UNIT_AURA == "player")
    Event("ADDON_RESTRICTION_STATE_CHANGED")
    restricted = true
    Flush()
    assert(reads == 6 and not events.UNIT_AURA, "restriction activation takes effect after dispatch")
    restricted, aura = false, nil
    resting = true
    Event("PLAYER_UPDATE_RESTING")
    resting = false
    Event("PLAYER_UPDATE_RESTING")
    Flush()
    assert(reads == 7 and food:IsVisible() and label:GetText() == "Missing food buff")
    dead = true
    Event("PLAYER_DEAD")
    assert(not food:IsVisible() and not events.UNIT_AURA)
    dead, restrictedFoodID = false, 18192
    Event("PLAYER_ALIVE")
    Event("PLAYER_UNGHOST")
    Flush()
    assert(reads == 8 and not food:IsVisible(),
        "an unreadable candidate is unknown rather than missing")
    session.SetFoodBuffAlertEnabled(false)
    assert(not events.PLAYER_UPDATE_RESTING and not events.PLAYER_LEVEL_UP and not events.UNIT_AURA
        and not events.ADDON_RESTRICTION_STATE_CHANGED)
    Event("PLAYER_REGEN_ENABLED")
    Flush()
    assert(reads == 8)
    assert(not row:IsShown() and not pet:IsShown())
    session.SetAlertPositionLocked(false)
    assert(row:IsShown() and pet:IsShown() and row.mouseEnabled and pet.mouseEnabled)
    assert(not food:IsShown(), "positioning should show a label, not a false food warning")
    session.SetAlertPositionLocked(true)
    assert(not row:IsShown() and not pet:IsShown())

    C_Timer.After, C_Timer.NewTimer = after, newTimer
    C_UnitAuras, C_Secrets = priorAuras, priorSecrets
    UnitLevel, IsResting, UnitIsDeadOrGhost = priorLevel, priorResting, priorDead
    GetBuildInfo, C_Spell.GetSpellName = nil, priorSpellName
end)

Test("Forever player food picker saves a character's valid choice and only scans while its menu is open", function()
    local previous = {}
    local globals = { "GetBuildInfo", "C_Container", "C_Item", "C_UnitAuras", "C_Spell", "MenuUtil",
        "Menu", "MenuVariants", "UnitGUID", "wipe", "SpellIsTargeting", "GetCursorInfo" }
    for _, key in ipairs(globals) do previous[key] = _G[key] end
    local after = C_Timer.After
    local pending, scans = {}, 0
    local guid, nutritiousName = "Player-A", nil
    local coldItem = 102
    local counts = { [101] = 3, [102] = 1, [5525] = 4, [13810] = 1, [999] = 1 }
    local bag = {101, 101, 5525, 13810, 102, 999}
    C_Timer.After = function(_, callback) pending[#pending + 1] = callback end
    GetBuildInfo = function() return "1.60.1", "70888", "", 16001 end
    UnitGUID = function() return guid end
    SpellIsTargeting, GetCursorInfo = noop, noop
    wipe = function(t) for k in pairs(t) do t[k] = nil end end
    C_Container = {
        GetContainerNumSlots = function(bagID) return bagID == 0 and #bag or 0 end,
        GetContainerItemInfo = function(_, slot)
            scans = scans + 1
            local id = bag[slot]
            return id and { itemID = id, stackCount = (id == 101 and (slot == 1 and 1 or 2)) or counts[id] }
        end,
    }
    C_Spell = {
        GetSpellName = function(id) return id == 1248377 and nutritiousName or id == 19705 and "Well Fed" or nil end,
        RequestLoadSpellData = function(id) assert(id == 1248377) end,
    }
    C_UnitAuras = {GetAuraDataBySpellName = noop, GetPlayerAuraBySpellID = noop}
    C_Item = {
        GetItemSpell = function(id) return (id == 101 or id == 102) and "Nutritious Food" or "Food" end,
        GetItemInfoInstant = function(id) return id, nil, nil, nil, nil, id == 999 and 2 or 0 end,
        IsUsableItem = function(id) return id ~= 999 end,
        GetItemCount = function(id) return counts[id] end,
        GetItemIconByID = function(id) return id + 1000 end,
        GetItemNameByID = function(id) return "Item " .. id end,
        IsItemDataCachedByID = function(id) return id ~= coldItem end,
        RequestLoadItemDataByID = function(id) assert(id == coldItem) end,
    }
    local currentMenu
    MenuUtil = {
        CreateRootMenuDescription = function()
            return {
                rows = {},
                AddMenuReleasedCallback = function(self, callback) self.release = callback end,
                CreateTitle = noop, SetScrollMode = noop,
                CreateRadio = function(self, label, selected, choose, id)
                    assert(not self.rows[id], "one entry per item ID")
                    local entry = { label = label, selected = selected, choose = choose, SetTooltip = noop }
                    self.rows[id] = entry
                    return entry
                end,
            }
        end,
    }
    MenuVariants = {GetDefaultContextMenuMixin = noop}
    Menu = {PopulateDescription = function(build, owner, root) build(owner, root) end}
    function MenuUtil.CreateContextMenu(owner, build)
        local popup = {
            SetMenuDescription = function(self, root) self.rows, self.release = root.rows, root.release end,
            Close = function(self) self.closed = true; self.release(self) end,
        }
        local root = MenuUtil.CreateRootMenuDescription()
        build(owner, root)
        popup:SetMenuDescription(root)
        currentMenu = popup
        return popup
    end
    local function FindPicker(session)
        local row = Upvalue(session.SetAmmoAlert, "supplyFrame")
        return FindNode(row, function(node) return node.template == "InsecureActionButtonTemplate" end)
    end

    local saved = {language = "enUS", foodBuffAlertEnabled = true, foodPickerEnabled = true}
    local session = LoadLanguageSession(saved)
    session.SetFoodBuffAlert(true, true)
    local picker = assert(FindPicker(session))
    assert(picker:IsVisible() and scans == 0 and not picker.events)
    picker.scripts.PostClick(picker, "RightButton")
    assert(scans == #bag and currentMenu.rows[13810] and not currentMenu.rows[5525])
    assert(not currentMenu.rows[101] and picker.events.ITEM_DATA_LOAD_RESULT and picker.events.SPELL_DATA_LOAD_RESULT)
    nutritiousName, coldItem = "Nutritious Food", nil
    picker.scripts.OnEvent(picker, "ITEM_DATA_LOAD_RESULT", 102)
    picker.scripts.OnEvent(picker, "SPELL_DATA_LOAD_RESULT", 1248377)
    assert(#pending == 1, "item and spell data callbacks should rebuild the open menu once")
    pending[1]()
    pending = {}
    assert(currentMenu.rows[101] and currentMenu.rows[102] and not currentMenu.rows[5525] and not currentMenu.rows[999])
    assert(currentMenu.rows[101].label == "Item 101 ×3", "stacks of the same food should be combined")
    currentMenu.rows[101].choose(101)
    assert(saved.playerFoodByCharacter["Player-A"] == 101 and currentMenu.rows[101].selected(101))
    assert(picker.foodTexture.texture == 1101 and picker.foodCount:GetText() == "3")
    currentMenu:Close()
    local before = scans
    picker.scripts.PreClick(picker, "LeftButton")
    assert(picker.attributes.type1 == "item" and picker.attributes.item1 == "item:101")
    picker.scripts.PostClick(picker, "LeftButton")
    assert(not picker.attributes.item1 and scans == before, "left click must not scan the bags")

    counts[101] = 0
    picker.scripts.OnEvent(picker, "BAG_UPDATE_DELAYED")
    picker.scripts.PreClick(picker, "LeftButton")
    assert(not picker.attributes.type1 and picker.foodCount:GetText() == "" and saved.playerFoodByCharacter["Player-A"] == 101)
    counts[101] = 2
    local reloaded = LoadLanguageSession(saved)
    reloaded.SetFoodBuffAlert(true, true)
    local restored = assert(FindPicker(reloaded))
    assert(restored.foodCount:GetText() == "2" and scans == before)
    restored.scripts.PreClick(restored, "LeftButton")
    assert(restored.attributes.item1 == "item:101")
    restored.scripts.PostClick(restored, "LeftButton")
    reloaded.SetAlertPositionLocked(false)
    assert(not restored:IsVisible() and not next(restored.events))
    restored.scripts.PreClick(restored, "LeftButton")
    assert(not restored.attributes.type1)
    reloaded.SetAlertPositionLocked(true)
    inCombat = true
    restored.scripts.PreClick(restored, "LeftButton")
    assert(not restored.attributes.type1)
    inCombat = false
    reloaded.SetFoodBuffAlert(false, false)
    assert(not restored:IsVisible() and not next(restored.events) and scans == before)

    guid = "Player-B"
    local alt = LoadLanguageSession(saved)
    alt.SetFoodBuffAlert(true, true)
    local fresh = assert(FindPicker(alt))
    fresh.scripts.PreClick(fresh, "LeftButton")
    assert(not fresh.attributes.type1 and fresh.foodCount:GetText() == "")
    C_Timer.After = after
    for _, key in ipairs(globals) do _G[key] = previous[key] end
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
    happiness = 3
    Event("UNIT_HAPPINESS", "pet")
    assert(not button:IsVisible())
    session.OpenOptionsFrame()
    local options = Upvalue(session.RefreshOptionsFrameLocale, "optionsFrame")
    options.navButtons.classes.scripts.OnClick()
    options.navButtons.HUNTER.scripts.OnClick()
    local feedSettings = assert(FindText(options.currentPage, session.UI.FEED_SETTINGS)).parent
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
    happiness = 1
    Event("UNIT_HAPPINESS", "pet")
    assert(care:IsShown() and care.icon.texture == "UI-PetMad" and not button:IsVisible())
    unhappyCheck:SetChecked(false)
    unhappyCheck.scripts.OnClick(unhappyCheck)
    assert(not care:IsShown(), "the unhappy reminder must have its own switch")
    feedCheck:SetChecked(true)
    feedCheck.scripts.OnClick(feedCheck)
    assert(button:IsVisible() and care.icon.texture == 456)
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

local function WithRetailSupply(playerClass, stat, test)
    local combat, restricted, chatLocked, socialBlocked, auraReadFails = false, false, false, false, false
    local state = { auras = {}, roster = {}, raid = false, gear = {}, enchants = {}, now = 100,
        auraReads = 0, gearReads = 0, inquiries = {}, whispers = {}, errors = {} }
    local secret = {}
    local names = { [19705] = "Well Fed", [6673] = "Battle Shout", [1459] = "Arcane Intellect", [462854] = "Skyfury" }
    local playerSpecID = playerClass == "WARRIOR" and 71 or playerClass == "SHAMAN" and 263 or 63
    local original = { after = C_Timer.After, ticker = C_Timer.NewTicker, timer = C_Timer.NewTimer }
    local overrides = {
        GetBuildInfo = function() return "12.1.5", "70783", "", 120105 end,
        GetTime = function() return state.now end,
        UnitClass = function(unit)
            if unit == "player" then return playerClass, playerClass end
            local member = state.roster[unit]
            if member then return member.class, member.class end
        end,
        UnitIsUnit = function(unit) return unit == "player" or state.roster[unit].isSelf end,
        UnitGUID = function(unit) return state.roster[unit].guid end,
        UnitFullName = function(unit) return state.roster[unit].name, state.roster[unit].realm end,
        UnitIsConnected = function(unit) return state.roster[unit] and not state.roster[unit].offline end,
        UnitIsDeadOrGhost = function() return false end,
        InCombatLockdown = function() return combat end,
        IsInRaid = function() return state.raid end,
        GetNumGroupMembers = function() return state.groupSize or 0 end,
        GetNumSubgroupMembers = function() return state.groupSize or 0 end,
        issecretvalue = function(value) return value == secret end,
        C_SpecializationInfo = {
            GetSpecialization = function() return 1 end,
            GetSpecializationInfo = function() return playerSpecID, nil, nil, nil, nil, stat end,
        },
        C_SpellBook = { IsSpellKnown = function(id)
            if state.knownSpells then return state.knownSpells[id] == true end
            return id == (playerClass == "WARRIOR" and 6673 or playerClass == "MAGE" and 1459 or 0)
        end },
        C_Spell = { GetSpellTexture = function(id) return id + 100000 end, GetSpellName = function(id) return names[id] end },
        C_DurationUtil = {
            CreateDuration = function() return { SetTimeFromEnd = function(self, time) self.expiration = time end } end,
            CreateDurationTextBinding = function()
                return { SetFontString = noop, SetDuration = noop, SetEnabled = function(self, enabled) self.enabled = enabled end }
            end,
        },
        C_Secrets = {
            ShouldAurasBeSecret = function() return restricted end,
            ShouldSpellAuraBeSecret = function(id) return id == state.secretSpell end,
        },
        C_UnitAuras = {
            GetUnitAuras = function(unit, filter)
                state.auraReads = state.auraReads + 1
                assert(unit == "player" and filter == "HELPFUL" and not combat and not restricted)
                if auraReadFails then error("Aura access unavailable") end
                return state.auras
            end,
            GetAuraDataByAuraInstanceID = function(unit, id)
                assert(unit == "player" and not combat and not restricted)
                state.instanceReads = (state.instanceReads or 0) + 1
                for _, aura in ipairs(state.auras) do if aura.auraInstanceID == id then return aura end end
            end,
        },
        Enum = {
            SpellBookSpellBank = { Player = 0 }, ItemClass = { Weapon = 2 }, ItemWeaponSubclass = { Fishingpole = 20 },
            ChatWhisperTargetStatus = { CanWhisper = 0, CanWhisperGuild = 1, Offline = 2, WrongFaction = 3 },
        },
        C_ChatInfo = {
            InChatMessagingLockdown = function() return chatLocked end,
            RequestCanLocalWhisperTarget = function(guid) table.insert(state.inquiries, guid) end,
            SendChatMessage = function(message, channel, _, recipient)
                assert(channel == "WHISPER" and not chatLocked and not socialBlocked)
                table.insert(state.whispers, { message, recipient })
            end,
        },
        C_SocialRestrictions = { CanSendChat = function() return not socialBlocked end },
        UIErrorsFrame = { AddMessage = function(_, message) table.insert(state.errors, message) end },
        GetInventoryItemID = function(_, slot) return state.gear[slot] end,
        C_Item = { GetItemInfoInstant = function(id)
            return id, nil, nil, nil, id + 200000, id == 100 and 4 or 2, id == 101 and 20 or 7
        end },
        C_PaperDollInfo = { GetTemporaryEnchantmentInfo = function(slot)
            state.gearReads = state.gearReads + 1
            assert(not combat)
            return state.enchants[slot]
        end },
    }
    local previous = {}
    for key, value in pairs(overrides) do previous[key] = _G[key]; _G[key] = value end
    local pending, deadlineTimers = {}, {}
    C_Timer.After = function(_, callback) table.insert(pending, callback) end
    C_Timer.NewTicker = function() error("Supply alerts must not poll") end
    C_Timer.NewTimer = function(delay, callback)
        local timer = Timer(callback)
        timer.at = state.now + delay
        table.insert(deadlineTimers, timer)
        return timer
    end
    local ok, err = pcall(function()
        local session = LoadLanguageSession({ language = "enUS" })
        local row = Upvalue(session.SetAmmoAlert, "supplyFrame")
        local frame = Upvalue(session.RefreshRetailBuffAlerts, "eventFrame")
        local function Event(event, ...)
            if event == "UNIT_AURA" then
                if session.addonFrame.events.UNIT_AURA then session.addonFrame.scripts.OnEvent(session.addonFrame, event, ...) end
            elseif frame.events and frame.events[event] then
                frame.scripts.OnEvent(frame, event, ...)
            end
        end
        local function Flush()
            assert(#pending < 3, "Refresh work must coalesce")
            local callbacks = pending
            pending = {}
            for _, callback in ipairs(callbacks) do callback() end
        end
        function state.SetCombat(value) combat = value; Event(value and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED") end
        function state.Restrict(value) Event("ADDON_RESTRICTION_STATE_CHANGED"); restricted = value end
        function state.LockChat(value) chatLocked = value end
        function state.BlockSocial(value) socialBlocked = value end
        function state.FailAuraRead(value) auraReadFails = value end
        function state.SwitchSpec(value, id) stat, playerSpecID = value, id; Event("PLAYER_SPECIALIZATION_CHANGED", "player") end
        function state.Pending() return #pending end
        function state.Deadline()
            local active
            for _, timer in ipairs(deadlineTimers) do
                if not timer.cancelled then
                    assert(not active, "At most one threshold timer may be active")
                    active = timer
                end
            end
            return active and active.at
        end
        function state.Advance(now)
            state.now = now
            local timersAtStart = #deadlineTimers
            for index = 1, timersAtStart do
                local timer = deadlineTimers[index]
                if not timer.cancelled and now >= timer.at then
                    timer.cancelled = true
                    timer.callback()
                end
            end
        end
        function state.Icon(key)
            return FindNode(row, function(node) return node.alertKey == key and node:IsVisible() end)
        end
        state.Event, state.Flush, state.session, state.row, state.secret = Event, Flush, session, row, secret
        test(state)
    end)
    for key in pairs(overrides) do _G[key] = previous[key] end
    C_Timer.After, C_Timer.NewTicker, C_Timer.NewTimer = original.after, original.ticker, original.timer
    assert(ok, err)
end

Test("Retail supply only scans player auras on full updates or relevant state changes", function()
    WithRetailSupply("MAGE", 4, function(s)
        assert(not s.row:IsShown() and not s.session.addonFrame.events.UNIT_AURA and s.Pending() == 0)
        s.session.SetRetailSupplySetting("FOOD", true)
        s.session.SetRetailSupplySetting("CLASS", true)
        s.Flush()
        assert(s.Icon("FOOD") and s.Icon("ARCANE_INTELLECT") and not s.Icon("BATTLE_SHOUT"))
        assert(s.auraReads == 1 and s.session.addonFrame.events.UNIT_AURA == "player")
        assert(s.session.GetRetailSupplyTooltip("FOOD") == "Missing Well Fed")
        local food = { auraInstanceID = 1, spellId = 123, isHelpful = true, icon = 136000 }
        s.Event("UNIT_AURA", "pet", { addedAuras = { food } })
        s.Event("UNIT_AURA", "player", { addedAuras = {{ auraInstanceID = 2, spellId = 500, isHelpful = true, icon = 133950 }},
            removedAuraInstanceIDs = { 99 }, updatedAuraInstanceIDs = { 99 } })
        assert(s.Pending() == 0)
        s.Event("UNIT_AURA", "player", { addedAuras = { food, { auraInstanceID = 3, spellId = 432778, isHelpful = true } } })
        s.Flush()
        assert(not s.Icon("FOOD") and not s.Icon("ARCANE_INTELLECT") and s.auraReads == 1)
        s.Event("UNIT_AURA", "player", { updatedAuraInstanceIDs = { 1 } })
        assert(s.Pending() == 0)
        s.Event("UNIT_AURA", "player", { removedAuraInstanceIDs = { 1, 3 } })
        s.Event("UNIT_AURA", "player", { addedAuras = {{ auraInstanceID = 4, spellId = 124, isHelpful = true, name = "Well Fed", icon = 1 }} })
        assert(s.Pending() == 1)
        s.Flush()
        assert(not s.Icon("FOOD") and s.Icon("ARCANE_INTELLECT") and s.auraReads == 1)
        s.Restrict(true)
        s.Flush()
        assert(not s.row:IsShown() and not s.session.addonFrame.events.UNIT_AURA and s.auraReads == 1)
        s.Restrict(false)
        s.FailAuraRead(true)
        s.Flush()
        s.Event("UNIT_AURA", "player", { addedAuras = { food } })
        assert(not s.row:IsShown() and s.auraReads == 2 and s.Pending() == 0)
        s.FailAuraRead(false)
        s.auras = { { auraInstanceID = 8, spellId = s.secret, isHelpful = true, icon = s.secret } }
        s.secretSpell = 1459
        s.Event("UNIT_AURA", "player", { isFullUpdate = true })
        s.Flush()
        assert(not s.row:IsShown() and s.auraReads == 3)
        s.secretSpell = nil
        s.Event("UNIT_AURA", "player", { removedAuraInstanceIDs = { 8 } })
        s.Flush()
        assert(s.Icon("FOOD") and s.Icon("ARCANE_INTELLECT") and s.auraReads == 3)
        s.SetCombat(true)
        s.Flush()
        assert(not s.row:IsShown() and s.auraReads == 3)
        s.SetCombat(false)
        s.auras = {}
        s.Flush()
        assert(s.Icon("FOOD") and s.auraReads == 4 and s.Pending() == 0)
    end)
end)

Test("Retail supply uses spec and roster, with validated click-only class actions", function()
    WithRetailSupply("WARRIOR", 1, function(s)
        assert(s.session.addonFrame.events.UNIT_AURA == "player" and s.session.HandleWarriorAuraChanged)
        s.groupSize = 5
        s.roster.party1 = { class = "MAGE", guid = "mage", name = "Mage" }
        s.roster.party2 = { class = "SHAMAN", guid = "wrong", name = "Wrong" }
        s.roster.party3 = { class = "SHAMAN", guid = "ally", name = "Ally", realm = "OtherRealm" }
        s.roster.party4 = { class = "DRUID", guid = "druid", name = "Druid" }
        s.roster.party5 = { class = "PRIEST", guid = "priest", name = "Priest", offline = true }
        s.auras = { {auraInstanceID = 9, spellId = 432661, isHelpful = true} }
        s.session.SetRetailSupplySetting("CLASS", true)
        s.Flush()
        local shout, skyfury = assert(s.Icon("BATTLE_SHOUT")), assert(s.Icon("SKYFURY"))
        assert(not s.Icon("ARCANE_INTELLECT") and not s.Icon("MARK_OF_THE_WILD") and not s.Icon("FORTITUDE"))
        assert(#s.inquiries == 1 and s.inquiries[1] == "wrong" and #s.whispers == 0)
        shout.scripts.PreClick(shout, "LeftButton")
        assert(shout.attributes.type1 == "spell" and shout.attributes.spell1 == 6673 and shout.attributes.unit1 == "player")
        shout.scripts.PostClick(shout)
        assert(not shout.attributes.type1 and not shout.attributes.spell1)
        skyfury.scripts.PreClick(skyfury, "LeftButton")
        assert(#s.whispers == 0 and s.errors[#s.errors] == s.session.UI.RETAIL_WHISPER_PENDING)
        s.Event("CAN_LOCAL_WHISPER_TARGET_RESPONSE", "wrong", 3)
        s.Flush()
        assert(#s.inquiries == 2 and s.inquiries[2] == "ally" and #s.whispers == 0)
        s.Event("CAN_LOCAL_WHISPER_TARGET_RESPONSE", "ally", 1)
        s.Flush()
        local _, hint = s.session.GetRetailSupplyTooltip("SKYFURY")
        assert(hint:find("Ally-OtherRealm", 1, true) and #s.whispers == 0)
        s.LockChat(true)
        skyfury.scripts.PreClick(skyfury, "LeftButton")
        s.LockChat(false); s.BlockSocial(true)
        skyfury.scripts.PreClick(skyfury, "LeftButton")
        assert(#s.whispers == 0)
        s.BlockSocial(false)
        skyfury.scripts.PreClick(skyfury, "LeftButton")
        skyfury.scripts.PreClick(skyfury, "LeftButton")
        assert(#s.whispers == 1 and s.whispers[1][2] == "Ally-OtherRealm" and s.whispers[1][1]:find("Skyfury"))
        s.now = 200
        s.roster.party3 = { class = "SHAMAN", guid = "new", name = "New" }
        skyfury.scripts.PreClick(skyfury, "LeftButton")
        assert(#s.whispers == 1)
        s.Flush()
        assert(s.inquiries[3] == "new")
        s.roster, s.groupSize = { raid1 = { class = "WARRIOR", guid = "self", name = "Me", isSelf = true },
            raid2 = { class = "PRIEST", guid = "disc", name = "Disc" } }, 2
        s.raid = true
        s.Event("GROUP_ROSTER_UPDATE")
        s.Flush()
        assert(s.Icon("BATTLE_SHOUT") and s.Icon("FORTITUDE") and not s.Icon("SKYFURY"))
        s.session.SetRetailSupplySetting("BATTLE_SHOUT", false)
        s.Flush()
        assert(not s.Icon("BATTLE_SHOUT") and s.Icon("FORTITUDE"))
    end)
end)

Test("Retail weapon alerts follow both equipped weapons and have a separate drag anchor", function()
    WithRetailSupply("MAGE", 4, function(s)
        s.gear = { [16] = 110, [17] = 100 }
        s.session.SetRetailSupplySetting("WEAPON", true)
        s.Flush()
        assert(s.Icon("MAIN_HAND") and not s.Icon("OFF_HAND") and s.gearReads == 1 and s.auraReads == 0)
        s.gear[17] = 111
        s.Event("PLAYER_EQUIPMENT_CHANGED", 17)
        s.Flush()
        assert(s.Icon("MAIN_HAND") and s.Icon("OFF_HAND") and s.gearReads == 3)
        s.gear[17], s.enchants[16] = 101, {}
        s.Event("WEAPON_ENCHANT_CHANGED")
        s.Flush()
        assert(not s.row:IsShown() and s.gearReads == 4 and s.auraReads == 0)
        s.session.SetAlertPositionLocked(false)
        assert(s.row:IsShown() and s.row.mouseEnabled and s.row.parent == UIParent)
        s.row.GetPoint = function() return "CENTER", UIParent, "CENTER", 10, 95 end
        s.row.scripts.OnDragStop(s.row)
        assert(PetStatusAlertDB.supplyAlertPosition.y == 95 and PetStatusAlertDB.alertPosition.y == 220)
        s.session.SetAlertPositionLocked(true)
        s.enchants[16] = nil
        s.Event("WEAPON_ENCHANT_CHANGED")
        s.Flush()
        assert(s.Icon("MAIN_HAND") and s.gearReads == 5 and s.Pending() == 0)
        s.session.OpenOptionsFrame()
        local options = Upvalue(s.session.RefreshOptionsFrameLocale, "optionsFrame")
        local nav = assert(options.navButtons.auras)
        nav.scripts.OnClick(nav)
        assert(FindText(options.currentPage, s.session.UI.RETAIL_CLASS) and not FindText(options.currentPage, s.session.UI.RETAIL_WEAPON))
        options.auraButtons.consumables.scripts.OnClick()
        assert(FindText(options.currentPage, s.session.UI.RETAIL_WEAPON) and not FindText(options.currentPage, s.session.UI.RETAIL_CLASS))
        s.session.ApplyManagerLanguage("zhCN")
        assert(nav.text:GetText() == "增益提醒" and options.auraButtons.classBuffs:GetText() == "职业增益")
        assert(options.activeAuraTab == "consumables" and FindText(options.currentPage, s.session.UI.RETAIL_WEAPON))
        local tabs = s.session.GetSettingsDefinition({}).tabs
        local found
        for _, tab in ipairs(tabs) do if tab.key == "auras" then found = tab end end
        assert(found and found.title == "增益提醒" and #found.subtabs == 3)
        assert(found.subtabs[1].title == "职业增益" and found.subtabs[3].key == "ammo")
        s.session.SetRetailSupplySetting("WEAPON", false)
        s.Flush()
        assert(not s.row:IsShown() and not s.session.addonFrame.events.UNIT_AURA and s.Pending() == 0)
    end)
end)

Test("Retail class selection follows primary stat for mixed-role classes", function()
    WithRetailSupply("DRUID", 2, function(s)
        s.groupSize = 2
        s.roster.party1 = { class = "WARRIOR", guid = "warrior", name = "Warrior" }
        s.roster.party2 = { class = "MAGE", guid = "mage", name = "Mage" }
        s.session.SetRetailSupplySetting("CLASS", true)
        s.Flush()
        assert(s.Icon("BATTLE_SHOUT") and not s.Icon("ARCANE_INTELLECT"))
        s.SwitchSpec(4, 105)
        s.Flush()
        assert(s.Icon("ARCANE_INTELLECT") and not s.Icon("BATTLE_SHOUT") and s.auraReads == 2)
        s.Event("SPELLS_CHANGED")
        s.Flush()
        assert(s.auraReads == 2 and s.Pending() == 0)
    end)
end)

Test("Retail food and weapon thresholds share one timer and show native countdowns", function()
    WithRetailSupply("MAGE", 4, function(s)
        local food = { auraInstanceID = 1, spellId = 123, isHelpful = true, icon = 136000, expirationTime = 410 }
        s.auras = { food }
        s.gear = { [16] = 110, [17] = 111 }
        s.enchants[16] = { hasExpirationTime = true, remainingTimeMs = 420000 }
        s.enchants[17] = { hasExpirationTime = true, remainingTimeMs = 240000 }
        s.session.SetRetailSupplySetting("FOOD", true)
        s.session.SetRetailSupplySetting("WEAPON", true)
        s.Flush()
        assert(not s.Deadline() and not s.row:IsShown())
        s.session.SetRetailSupplyLeadMinutes("FOOD", "3")
        s.session.SetRetailSupplyLeadMinutes("WEAPON", "2")
        s.Flush()
        assert(s.Deadline() == 220 and not s.row:IsShown())
        local auraReads, gearReads = s.auraReads, s.gearReads
        s.Advance(220)
        local offHand = assert(s.Icon("OFF_HAND"))
        assert(offHand.timeBinding.enabled and offHand.duration.expiration == 340 and s.Deadline() == 230)
        assert(s.auraReads == auraReads and s.gearReads == gearReads)
        s.Advance(230)
        local foodIcon = assert(s.Icon("FOOD"))
        assert(foodIcon.timeBinding.enabled and foodIcon.duration.expiration == 410 and s.Deadline() == 400)
        food.expirationTime = 700
        s.Event("UNIT_AURA", "player", { updatedAuraInstanceIDs = { 1, 80 } })
        s.Flush()
        assert(s.instanceReads == 1 and s.auraReads == auraReads and not s.Icon("FOOD") and not foodIcon.timeBinding.enabled)
        s.SetCombat(true)
        assert(not s.Deadline())
        s.Flush()
        assert(not s.row:IsShown() and not offHand.timeBinding.enabled and s.gearReads == gearReads)
        s.Advance(450)
        s.enchants[16], s.enchants[17] = { hasExpirationTime = true, remainingTimeMs = 70000 }, nil
        s.SetCombat(false)
        s.Flush()
        assert(s.Icon("MAIN_HAND").timeBinding.enabled and s.Icon("OFF_HAND") == offHand and not offHand.timeBinding.enabled)
        assert(s.Deadline() == 520 and s.session.GetRetailSupplyTooltip("OFF_HAND") == s.session.UI.RETAIL_OFF_HAND_MISSING)
        s.session.SetRetailSupplyLeadMinutes("FOOD", 0)
        s.Flush()
        assert(not s.Deadline())
        s.Event("UNIT_AURA", "player", { updatedAuraInstanceIDs = { 1 } })
        assert(s.instanceReads == 1 and s.Pending() == 0)
        s.session.SetRetailSupplyLeadMinutes("FOOD", "700")
        assert(s.session.GetRetailSupplyLeadMinutes("FOOD") == 60)
    end)
end)

Test("Retail thresholds replace stale timers and skip unreadable durations", function()
    WithRetailSupply("MAGE", 4, function(s)
        local food = { auraInstanceID = 1, spellId = 123, isHelpful = true, icon = 136000, expirationTime = 480 }
        local secondFood = { auraInstanceID = 2, spellId = 124, isHelpful = true, icon = 136000, expirationTime = s.secret }
        s.auras = { food, secondFood }
        s.gear[16] = 110
        s.enchants[16] = { hasExpirationTime = true, remainingTimeMs = 300000 }
        s.session.SetRetailSupplyLeadMinutes("FOOD", 2)
        s.session.SetRetailSupplyLeadMinutes("WEAPON", 2)
        s.session.SetRetailSupplySetting("FOOD", true)
        s.session.SetRetailSupplySetting("WEAPON", true)
        s.Flush()
        assert(s.Deadline() == 280 and not s.Icon("FOOD"))
        s.enchants[16] = { hasExpirationTime = true, remainingTimeMs = 900000 }
        s.Event("WEAPON_ENCHANT_CHANGED")
        s.Flush()
        assert(s.Deadline() == 880)
        s.Advance(280)
        assert(not s.row:IsShown() and s.Deadline() == 880)
        s.Event("UNIT_AURA", "player", { removedAuraInstanceIDs = { 2 } })
        s.Flush()
        assert(s.Deadline() == 360)
        s.Restrict(true)
        s.Flush()
        assert(not s.Deadline() and not s.row:IsShown())
        s.enchants[16] = { hasExpirationTime = false, remainingTimeMs = s.secret }
        s.Event("WEAPON_ENCHANT_CHANGED")
        s.Flush()
        assert(not s.row:IsShown() and not s.Deadline())
    end)
end)

Test("Retail Enhancement checks known Windfury and Flametongue in their own weapon slots", function()
    WithRetailSupply("SHAMAN", 2, function(s)
        s.knownSpells = { [33757] = true, [318038] = true }
        s.gear = { [16] = 110, [17] = 111 }
        s.enchants = { [16] = { enchantID = 5400 }, [17] = { enchantID = 6450 } }
        s.session.SetRetailSupplySetting("WEAPON", true)
        s.Flush()
        assert(s.Icon("MAIN_HAND") and s.Icon("OFF_HAND") and s.gearReads == 2)
        assert(s.session.GetRetailSupplyTooltip("MAIN_HAND") == s.session.UI.RETAIL_WINDFURY_MISSING)
        assert(s.session.GetRetailSupplyTooltip("OFF_HAND") == s.session.UI.RETAIL_FLAMETONGUE_MISSING)
        s.enchants = { [16] = { enchantID = 5401 }, [17] = { enchantID = 5400, hasExpirationTime = true, remainingTimeMs = 70000 } }
        s.Event("WEAPON_ENCHANT_CHANGED")
        s.session.SetRetailSupplyLeadMinutes("WEAPON", 2)
        s.Flush()
        assert(not s.Icon("MAIN_HAND") and s.Icon("OFF_HAND").timeBinding.enabled)
        assert(s.session.GetRetailSupplyTooltip("OFF_HAND") == s.session.UI.RETAIL_FLAMETONGUE_EXPIRING)
        s.session.SetRetailSupplySetting("FLAMETONGUE", false)
        s.Flush()
        assert(not s.Icon("OFF_HAND"))
        s.session.SetRetailSupplySetting("FLAMETONGUE", true)
        s.knownSpells[318038] = nil
        s.enchants[17] = { enchantID = 6450 }
        s.Event("SPELLS_CHANGED")
        s.Flush()
        assert(not s.Icon("OFF_HAND"))
        s.enchants[16] = { enchantID = 6450 }
        s.SwitchSpec(4, 262)
        s.Flush()
        assert(not s.Icon("MAIN_HAND") and not s.Icon("OFF_HAND") and s.auraReads == 0)
        s.session.OpenOptionsFrame()
        local options = Upvalue(s.session.RefreshOptionsFrameLocale, "optionsFrame")
        local nav = assert(options.navButtons.auras)
        nav.scripts.OnClick(nav)
        options.auraButtons.shaman.scripts.OnClick()
        assert(FindText(options.currentPage, s.session.UI.RETAIL_WINDFURY))
        assert(FindText(options.currentPage, s.session.UI.RETAIL_FLAMETONGUE))
        assert(not FindText(options.currentPage, s.session.UI.RETAIL_WEAPON_LEAD))
        options.auraButtons.consumables.scripts.OnClick()
        assert(FindText(options.currentPage, s.session.UI.RETAIL_WEAPON_LEAD))
        local sections = {}
        local page = {
            NewSection = function(_, title)
                local section = { labels = {}, title = title }
                local function AddLabel(self, label) self.labels[label] = true end
                section.Check, section.EditBox = AddLabel, AddLabel
                return section
            end,
            AddSection = function(_, section) sections[section.title] = section end,
        }
        for _, tab in ipairs(s.session.GetSettingsDefinition({}).tabs) do
            if tab.key == "auras" then
                assert(#tab.subtabs == 4)
                for _, sub in ipairs(tab.subtabs) do sub.build(page) end
            end
        end
        assert(sections[s.session.UI.RETAIL_ENHANCEMENT].labels[s.session.UI.RETAIL_FLAMETONGUE])
        assert(sections[s.session.UI.AURA_TAB_CONSUMABLES].labels[s.session.UI.RETAIL_FOOD_LEAD])
    end)
end)

print(string.format("RESULT: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
