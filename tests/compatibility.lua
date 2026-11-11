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
    env.UnitCreatureFamily = function() return config.familyName, config.familyID end
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
        return config.traitID and 1
    end}
    env.C_Traits = {
        GetConfigInfo = function() return {treeIDs = {1}} end,
        GetTreeNodes = function() return {1} end,
        GetNodeInfo = function()
            return {currentRank = config.traitRank or 1, activeEntry = {definitionID = config.traitID}}
        end,
    }
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
for _, spell in ipairs({688, 697, 712, 713, 691, 30146}) do
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
        if mode == "AGGRESSIVE" then
            assert(session.Refresh() == nil, "Aggressive should be silent by default")
            session.SetStatusEnabled(mode, true)
        end
        local expected = mode ~= "ASSIST" and mode or nil
        assert(session.Refresh() == expected)
    end)
end
Test("localized pet names work without token flags", function()
    local session = Session({forever = true, pet = true, known = {[688] = true}, class = "WARLOCK",
        mode = "Localized Aggressive", token = false})
    session.env.PetStatusAlertDB.statusEnabled.AGGRESSIVE = true
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

Test("Retail wrong summon is opt-in and uses the current spec's multi-selection", function()
    local config = {class = "WARLOCK", spec = 265, pet = true, familyID = 23, mode = "PET_MODE_ASSIST"}
    local session = Session(config)
    local key = session.WRONG_PET_STATUS_KEY
    session.SetWarlockBlockedPet(265, 23, true)
    session.SetWarlockBlockedPet(265, 16, true)
    assert(not session.IsStatusEnabled(key) and not session.Refresh())
    session.SetStatusEnabled(key, true)
    session.Event("UNIT_PET", "player")
    assert(session.currentStatusKey == key)
    config.familyID = 101 -- Voidlord is treated as its base Voidwalker family.
    assert(session.Refresh() == key)
    config.spec = 267
    session.Event("PLAYER_SPECIALIZATION_CHANGED", "player")
    assert(not session.currentStatusKey)
    session.SetWarlockBlockedPet(267, 16, true)
    assert(session.Refresh() == key)
    config.dead = true
    assert(session.Refresh() == "PET_DEAD")
    config.dead = false
    session.SetWarlockBlockedPet(267, 16, false)
    assert(not session.Refresh() and session.GetWarlockBlockedPets(265)[16])
end)

Test("wrong summon ignores restricted family data and leaves normal alerts available", function()
    local config = {class = "WARLOCK", spec = 266, pet = true, familyName = "Imp",
        familyID = 23, secret = 23, mode = "PET_MODE_PASSIVE"}
    local session = Session(config)
    session.SetStatusEnabled(session.WRONG_PET_STATUS_KEY, true)
    session.SetWarlockBlockedPet(266, 23, true)
    assert(session.Refresh() == "PASSIVE")
    config.secret = nil
    assert(session.Refresh() == session.WRONG_PET_STATUS_KEY)
end)

Test("Retail Grimoire defaults and custom talent IDs control suppression", function()
    local config = {class = "WARLOCK", spec = 265, pet = true, familyID = 23, traitID = 124691, mode = "PET_MODE_ASSIST"}
    local session = Session(config)
    local key = session.WRONG_PET_STATUS_KEY
    session.SetStatusEnabled(key, true)
    session.SetWarlockBlockedPet(265, 23, true)
    assert(session.GetClassOption("warlockIgnoreSacrifice") and session.GetWarlockSacrificeID(267) == 125618)
    assert(not session.Refresh())
    session.SetClassOption("warlockIgnoreSacrifice", false)
    session.RefreshClassPetSettings("WARLOCK")
    assert(session.currentStatusKey == key)
    session.SetClassOption("warlockIgnoreSacrifice", true)
    config.traitID = 131313
    session.SetWarlockSacrificeID(265, "131313")
    session.RefreshClassPetSettings("WARLOCK")
    assert(not session.currentStatusKey and session.GetWarlockSacrificeID(265, true) == 124691)
    config.pet = false
    assert(not session.Refresh())
    session.SetWarlockSacrificeID(265, "")
    session.RefreshClassPetSettings("WARLOCK")
    assert(session.currentStatusKey == "NO_PET" and session.GetWarlockSacrificeID(265) == 124691)
end)

Test("saved Succubus and Incubus choices merge into one Sayaad rule", function()
    local config = {class = "WARLOCK", spec = 265, pet = true, familyID = 17, mode = "PET_MODE_ASSIST"}
    local session = Session(config)
    session.env.PetStatusAlertDB.warlockBlockedPets = {
        [265] = {[302] = true, [23] = true},
        [266] = {[17] = true, [302] = false},
        [267] = {[302] = false},
        [0] = {[302] = true},
    }
    session.Event("ADDON_LOADED", "PetStatusAlert")
    local blocked = session.GetWarlockBlockedPets(265)
    assert(blocked[17] and blocked[23] and blocked[302] == nil)
    assert(session.GetWarlockBlockedPets(266)[17])
    assert(not session.GetWarlockBlockedPets(267)[17])
    assert(session.GetWarlockBlockedPets(0)[17])
    session.SetStatusEnabled(session.WRONG_PET_STATUS_KEY, true)
    for _, familyID in ipairs({17, 302, 102}) do
        config.familyID = familyID
        assert(session.Refresh() == session.WRONG_PET_STATUS_KEY)
    end
    session.SetWarlockBlockedPet(265, 17, false)
    assert(not session.Refresh() and session.GetWarlockBlockedPets(265)[23])
    assert(not session.GetWarlockBlockedPets(265)[302])
end)

Test("Forever Warlocks expose one Sayaad option and recognize both localized names", function()
    local config = {forever = true, locale = "zhCN", class = "WARLOCK", pet = true,
        familyName = "夜魔", known = {[713] = true}, mode = "PET_MODE_ASSIST"}
    local session = Session(config)
    session.env.PetStatusAlertDB.language = "enUS"
    session.RefreshLocaleTables()
    local key = session.WRONG_PET_STATUS_KEY
    session.SetStatusEnabled(key, true)
    session.SetWarlockBlockedPet(0, 17, true)
    assert(session.GetWarlockPetLabel(17) == "Sayaad (Succubus or Incubus)")
    assert(table.concat(session.GetWarlockPetFamilies(true), ",") == "23,16,15,17")
    assert(table.concat(session.GetWarlockPetFamilies(false), ",") == "23,16,15,17,29")
    assert(session.Refresh() == key)
    config.familyName = "魅魔"
    assert(session.Refresh() == key)
    assert(session.counters.spec == 0 and session.counters.traits == 0)
end)

Test("Mage summon requirement uses default, custom talent, and opt-out", function()
    local config = {class = "MAGE", spec = 64, traitID = 131313}
    local session = Session(config)
    assert(session.GetClassOption("mageRequireSummon") and session.GetClassOption("mageSummonID") == 31687)
    assert(not session.Refresh())
    session.SetClassOption("mageSummonID", "131313")
    session.RefreshClassPetSettings("MAGE")
    assert(session.currentStatusKey == "NO_PET")
    session.SetClassOption("mageSummonID", "-5")
    assert(session.GetClassOption("mageSummonID") == 131313)
    session.SetClassOption("mageSummonID", "")
    session.SetClassOption("mageRequireSummon", false)
    session.RefreshClassPetSettings("MAGE")
    assert(session.currentStatusKey == "NO_PET" and session.GetClassOption("mageSummonID") == 31687)
    config.spec = 63
    assert(not session.Refresh())

    local forever = Session({forever = true, class = "MAGE", known = {[131313] = true}})
    assert(not forever.Refresh())
    forever.SetClassOption("mageSummonID", "131313")
    forever.RefreshClassPetSettings("MAGE")
    assert(forever.currentStatusKey == "NO_PET" and forever.counters.traits == 0)
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
