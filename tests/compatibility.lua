-- Run from the addon source directory: lua tests/compatibility.lua
local passed, failed = 0, 0
local function Test(name, callback)
    local ok, err = pcall(callback)
    if ok then passed = passed + 1; print("PASS " .. name)
    else failed = failed + 1; print("FAIL " .. name .. ": " .. tostring(err)) end
end

local function Session(config)
    config = config or {}
    local session, pending, frames = {}, {}, {}
    local env = setmetatable({}, { __index = _G })
    env._G = env
    local counters = {spec = 0, traits = 0, aura = 0}
    local function SpecQuery()
        counters.spec = counters.spec + 1
        assert(not config.forever, "Forever must not query specializations")
        return 1
    end
    env.GetBuildInfo = function()
        return config.forever and "1.60.1" or "12.1.5", "70790", "Nov 5 2026",
            config.forever and 16001 or 120105, "", "Release"
    end
    env.GetLocale = function() return config.locale or "enUS" end
    env.GetSpecialization = SpecQuery
    env.GetSpecializationInfo = function() SpecQuery(); return config.spec or 253 end
    env.C_SpecializationInfo = {GetSpecialization = SpecQuery, GetSpecializationInfo = env.GetSpecializationInfo}
    env.UnitClass = function() return config.class or "HUNTER", config.class or "HUNTER" end
    env.UnitExists = function() return config.pet == true end
    env.UnitIsDeadOrGhost = function() return config.dead == true end
    env.IsMounted = function() return config.mounted == true end
    env.InCombatLockdown = function() return false end
    env.C_SpellBook = {IsSpellKnown = function(id) return config.known and config.known[id] or false end}
    env.GetPetActionInfo = function(slot)
        if slot ~= 1 then return end
        return config.mode, 1, config.token ~= false, config.active ~= false
    end
    env.PET_MODE_PASSIVE = "Localized Passive"
    env.PET_MODE_DEFENSIVE = "Localized Defensive"
    env.PET_MODE_AGGRESSIVE = "Localized Aggressive"
    env.PET_MODE_ASSIST = "Localized Assist"
    env.issecretvalue = function(value) return config.secret ~= nil and value == config.secret end
    env.C_ClassTalents = {GetActiveConfigID = function()
        counters.traits = counters.traits + 1
        return nil
    end}
    env.C_UnitAuras = {GetPlayerAuraBySpellID = function()
        counters.aura = counters.aura + 1
        return config.stance and {} or nil
    end}
    env.C_Timer = {After = function(_, callback) pending[#pending + 1] = callback end}
    env.CreateFrame = function()
        local frame = {events = {}, scripts = {}}
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:RegisterUnitEvent(event) self.events[event] = true end
        function frame:SetScript(key, callback) self.scripts[key] = callback end
        frames[#frames + 1] = frame
        return frame
    end
    local function Load(path) assert(loadfile(path, "t", env))("PetStatusAlert", session) end
    for _, path in ipairs({"Core/Database.lua", "Core/Compat.lua", "Core/Localization.lua"}) do Load(path) end
    session.InitDB()
    session.ShowStatus = function(key)
        session.currentStatusKey = session.IsStatusEnabled(key) and key or nil
    end
    session.HideStatus = function() session.currentStatusKey = nil end
    session.PreviewStatus = session.ShowStatus
    session.RegisterStatusIcon = function() end
    session.addonFrame = env.CreateFrame()
    session.RegisterNativeOptionsCategory = function() end
    session.StopCombatTTSReminder = function() end
    session.RefreshCombatTTSReminder = function() end
    for _, path in ipairs({"Core/PetLogic.lua", "Core/WarriorLogic.lua", "Core/Events.lua"}) do Load(path) end
    function session.Event(event, ...)
        session.addonFrame.scripts.OnEvent(session.addonFrame, event, ...)
        local callbacks = pending
        pending = {}
        for _, callback in ipairs(callbacks) do callback() end
    end
    function session.Refresh()
        session.RefreshPetStatusText()
        return session.currentStatusKey
    end
    session.env, session.counters, session.frames = env, counters, frames
    return session
end

Test("Forever skips specialization APIs even when shared APIs exist", function()
    local session = Session({forever = true, known = {[883] = true}})
    assert(session.GetPlayerSpecId() == 0 and session.Refresh() == "NO_PET")
    assert(session.counters.spec == 0)
end)
for _, class in ipairs({"HUNTER", "WARLOCK", "MAGE"}) do
    Test("Forever learned summon enables " .. class .. " without a specialization", function()
        local spell = ({HUNTER = 883, WARLOCK = 688, MAGE = 31687})[class]
        local session = Session({forever = true, class = class, known = {[spell] = true}})
        assert(session.Refresh() == "NO_PET")
        assert(session.counters.spec == 0 and session.counters.traits == 0)
    end)
    Test("Forever does not warn before " .. class .. " learns a summon", function()
        assert(Session({forever = true, class = class}).Refresh() == nil)
    end)
end
for _, spell in ipairs({688, 697, 712, 691, 30146}) do
    Test("Forever Warlock summon " .. spell .. " independently enables alerts", function()
        assert(Session({forever = true, class = "WARLOCK", known = {[spell] = true}}).Refresh() == "NO_PET")
    end)
end
Test("Forever summon eligibility does not leak between classes", function()
    assert(Session({forever = true, class = "HUNTER", known = {[688] = true}}).Refresh() == nil)
    assert(Session({forever = true, class = "WARLOCK", known = {[883] = true}}).Refresh() == nil)
    assert(Session({forever = true, class = "MAGE", known = {[688] = true}}).Refresh() == nil)
end)
Test("pet mode detection skips unrelated actions and empty earlier slots", function()
    local session = Session({forever = true, pet = true, known = {[883] = true}})
    session.env.GetPetActionInfo = function(slot)
        if slot == 1 then return "PET_ACTION_ATTACK", 1, true, true end
        if slot == 8 then return "PET_MODE_DEFENSIVE", 1, true, true end
    end
    assert(session.Refresh() == "DEFENSIVE")
end)
Test("old spell-known APIs remain usable when the namespace API is absent", function()
    local session = Session({forever = true})
    session.env.C_SpellBook = false
    session.env.IsPlayerSpell = function(id) return id == 883 end
    assert(session.Refresh() == "NO_PET")
    session.env.IsPlayerSpell = false
    session.env.IsSpellKnown = function(id) return id == 883 end
    session.ClearPetStatusCaches()
    assert(session.Refresh() == "NO_PET")
end)
for _, mode in ipairs({"ASSIST", "DEFENSIVE", "PASSIVE", "AGGRESSIVE"}) do
    Test("Forever identifies " .. mode .. " independently", function()
        local session = Session({forever = true, pet = true, known = {[883] = true}, mode = "PET_MODE_" .. mode})
        local expected = mode ~= "ASSIST" and mode or nil
        assert(session.Refresh() == expected)
    end)
end
Test("localized pet names work without token flags", function()
    local session = Session({forever = true, pet = true, known = {[688] = true}, class = "WARLOCK",
        mode = "Localized Aggressive", token = false})
    assert(session.Refresh() == "AGGRESSIVE")
end)
Test("DefensiveAssist token warns on both clients", function()
    for _, forever in ipairs({true, false}) do
        local session = Session({forever = forever, pet = true, known = {[883] = true}, mode = "PET_MODE_DEFENSIVEASSIST"})
        assert(session.Refresh() == "DEFENSIVE")
    end
end)
Test("unrelated active actions and empty bars are never guessed as Defensive", function()
    for _, mode in ipairs({"PET_ACTION_ATTACK", "", "UNRECOGNIZED_MODE"}) do
        local session = Session({forever = true, pet = true, known = {[883] = true}, mode = mode})
        session.env.PetStatusAlertDB.statusEnabled.UNKNOWN = true
        assert(session.Refresh() == "UNKNOWN")
    end
end)
Test("inactive pet modes do not become active modes", function()
    local session = Session({forever = true, pet = true, known = {[883] = true}, mode = "PET_MODE_PASSIVE", active = false})
    session.env.PetStatusAlertDB.statusEnabled.UNKNOWN = true
    assert(session.Refresh() == "UNKNOWN")
end)
Test("unreadable pet mode values use Unknown", function()
    local secret = {}
    local session = Session({forever = true, pet = true, known = {[883] = true}, mode = secret, secret = secret})
    session.env.PetStatusAlertDB.statusEnabled.UNKNOWN = true
    assert(session.Refresh() == "UNKNOWN")
end)
Test("missing pet action API uses Unknown", function()
    local session = Session({forever = true, pet = true, known = {[883] = true}})
    session.env.GetPetActionInfo = false
    session.env.PetStatusAlertDB.statusEnabled.UNKNOWN = true
    assert(session.Refresh() == "UNKNOWN")
end)
Test("dead pets take priority over normal pet mode", function()
    assert(Session({forever = true, pet = true, dead = true, known = {[883] = true},
        mode = "PET_MODE_DEFENSIVE"}).Refresh() == "PET_DEAD")
end)
Test("mounted players suppress pet alerts", function()
    assert(Session({forever = true, mounted = true, known = {[883] = true}}).Refresh() == nil)
end)
for _, event in ipairs({"SPELLS_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE"}) do
    Test(event .. " refreshes learned-summon eligibility", function()
        local config = {forever = true, known = {}}
        local session = Session(config)
        assert(session.Refresh() == nil)
        config.known[883] = true
        assert(session.Refresh() == nil, "eligibility should remain cached until the event")
        session.Event(event)
        assert(session.currentStatusKey == "NO_PET")
    end)
end
Test("pet UI events refresh mode changes", function()
    local config = {forever = true, pet = true, known = {[883] = true}, mode = "PET_MODE_ASSIST"}
    local session = Session(config)
    assert(session.Refresh() == nil)
    config.mode = "PET_MODE_PASSIVE"
    session.Event("PET_UI_UPDATE")
    assert(session.currentStatusKey == "PASSIVE")
end)
Test("Forever warriors have no stance alerts, previews, settings, or stance events", function()
    local session = Session({forever = true, class = "WARRIOR", stance = true})
    assert(session.Refresh() == nil and #session.STATUS_ORDER == 0)
    session.PreviewStatus("WARRIOR_DEFENSIVE_STANCE")
    assert(session.currentStatusKey == nil and session.GetDisplayMessage("WARRIOR_DEFENSIVE_STANCE") == "")
    assert(#session.frames == 1 and session.counters.aura == 0 and session.counters.spec == 0)
end)
Test("Forever does not enable absent pet classes", function()
    assert(Session({forever = true, class = "DEATHKNIGHT", known = {[46584] = true}}).Refresh() == nil)
end)
Test("Forever exposes both Defensive and Aggressive settings", function()
    local session = Session({forever = true})
    assert(table.concat(session.STATUS_ORDER, ",") == "NO_PET,PET_DEAD,PASSIVE,DEFENSIVE,AGGRESSIVE,UNKNOWN")
    for _, locale in ipairs({"enUS", "zhCN", "zhTW", "ruRU"}) do
        local localized = Session({forever = true, locale = locale})
        assert(localized.STATUS_LABEL.AGGRESSIVE and localized.GetDefaultMessage("AGGRESSIVE") ~= "")
    end
end)
Test("Forever Defensive alert respects its saved switch", function()
    local session = Session({forever = true, pet = true, known = {[883] = true}, mode = "PET_MODE_DEFENSIVE"})
    assert(session.Refresh() == "DEFENSIVE")
    session.SetStatusEnabled("DEFENSIVE", false)
    assert(session.Refresh() == nil)
    session.SetStatusEnabled("DEFENSIVE", true)
    assert(session.Refresh() == "DEFENSIVE")
end)
Test("Retail still excludes Marksmanship and requires Frost for Mage", function()
    assert(Session({spec = 254}).Refresh() == nil)
    assert(Session({spec = 253}).Refresh() == "NO_PET")
    assert(Session({class = "MAGE", spec = 63, known = {[31687] = true}}).Refresh() == nil)
    assert(Session({class = "MAGE", spec = 64, known = {[31687] = true}}).Refresh() == "NO_PET")
end)
Test("Retail Defensive still warns and Assist stays normal", function()
    assert(Session({pet = true, mode = "PET_MODE_DEFENSIVE"}).Refresh() == "DEFENSIVE")
    assert(Session({pet = true, mode = "PET_MODE_ASSIST"}).Refresh() == nil)
end)
Test("Retail Arms and Fury stance alerts remain enabled, Protection remains excluded", function()
    for _, spec in ipairs({71, 72, 73}) do
        local session = Session({class = "WARRIOR", spec = spec, stance = true})
        if spec == 73 then assert(session.Refresh() == nil)
        else assert(session.Refresh() == "WARRIOR_DEFENSIVE_STANCE") end
    end
end)
Test("Retail supports namespaced specialization APIs when globals are absent", function()
    local session = Session({spec = 252, class = "DEATHKNIGHT"})
    session.env.GetSpecialization, session.env.GetSpecializationInfo = false, false
    assert(session.Refresh() == "NO_PET")
end)

print(string.format("RESULT: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
