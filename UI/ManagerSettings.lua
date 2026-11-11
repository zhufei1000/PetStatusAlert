local _, PSA = ...
local definition, definitionKey, rebuild
local AddAlertSettings
local warlockAdvanced, warlockSpec = {}, {}
local function Text(en, cn, tw)
    local locale = PSA.GetActiveLocale()
    return locale == "zhCN" and cn or locale == "zhTW" and tw or en
end

local function BuildWarlockRules(page, forever, readOnly, availability)
    local ui = PSA.UI
    local section = page:NewSection(ui.WARLOCK_PET_RULES, ui.WARLOCK_PET_RULES_HINT)
    AddAlertSettings(section, PSA.WRONG_PET_STATUS_KEY, "WARLOCK", readOnly, availability, ui.WARLOCK_WRONG_PET)
    local spec = forever and 0 or PSA.WARLOCK_SPECS[1]
    if not forever then
        if not readOnly and PSA.GetPlayerClassFile() == "WARLOCK" then
            local current = PSA.GetPlayerSpecId()
            if ui.WARLOCK_SPECS[current] then spec = current end
        end
        spec = warlockSpec[readOnly] or spec
        local specs = {}
        for _, specID in ipairs(PSA.WARLOCK_SPECS) do
            specs[#specs + 1] = { value = specID, text = ui.WARLOCK_SPECS[specID] }
        end
        section:Dropdown(ui.WARLOCK_SPEC, function() return spec end, function(value)
            spec = value
            warlockSpec[readOnly] = value
        end, specs, nil, 180, {})
    end

    local pets = {}
    for _, familyID in ipairs(PSA.GetWarlockPetFamilies(forever)) do
        pets[#pets + 1] = {
            label = PSA.GetWarlockPetLabel(familyID),
            enabled = availability.enabled, disabledTooltip = availability.disabledTooltip,
            getValue = function()
                local blocked = not readOnly and PSA.GetWarlockBlockedPets(spec)
                return blocked and blocked[familyID] == true or false
            end,
            setValue = not readOnly and function(on)
                PSA.SetWarlockBlockedPet(spec, familyID, on)
                PSA.RefreshClassPetSettings("WARLOCK")
            end,
        }
    end
    section:CheckGrid(pets, { columns = 2 })
    if not readOnly then
        section:DynamicText(function()
            if not PSA.IsStatusEnabled(PSA.WRONG_PET_STATUS_KEY, "WARLOCK") then return ui.WRONG_PET_OFF end
            local blocked = PSA.GetWarlockBlockedPets(spec)
            return blocked and next(blocked) and ui.WARLOCK_PET_RULES_HINT or ui.WRONG_PET_NONE
        end)
    end
    if not forever then
        section:Check(ui.WARLOCK_IGNORE_SACRIFICE, function()
            return PSA.GetClassOption("warlockIgnoreSacrifice", readOnly)
        end, not readOnly and function(on)
            PSA.SetClassOption("warlockIgnoreSacrifice", on)
            PSA.RefreshClassPetSettings("WARLOCK")
        end, nil, availability)
        section:ButtonRow({{text = (warlockAdvanced[readOnly] and "- " or "+ ") .. ui.ADVANCED, onClick = function()
            warlockAdvanced[readOnly] = not warlockAdvanced[readOnly]
            if rebuild then rebuild() end
        end}})
        if warlockAdvanced[readOnly] then
            section:EditBox(ui.WARLOCK_SACRIFICE_ID, function()
                return tostring(PSA.GetWarlockSacrificeID(spec, readOnly) or "")
            end, not readOnly and function(value)
                PSA.SetWarlockSacrificeID(spec, value)
                PSA.RefreshClassPetSettings("WARLOCK")
            end, nil, 100, { numeric = true, enabled = availability.enabled, disabledTooltip = availability.disabledTooltip,
                note = ui.WARLOCK_SACRIFICE_HINT })
        end
    end
    page:AddSection(section)
end

local function BuildClassRules(page, classFile, forever, readOnly, availability)
    local ui = PSA.UI
    if classFile == "WARLOCK" then
        BuildWarlockRules(page, forever, readOnly, availability)
    elseif classFile == "MAGE" then
        local section = page:NewSection(ui.MAGE_SUMMON_SETTINGS, ui.MAGE_SUMMON_HINT)
        section:Check(ui.MAGE_REQUIRE_SUMMON, function()
            return PSA.GetClassOption("mageRequireSummon", readOnly)
        end, not readOnly and function(on)
            PSA.SetClassOption("mageRequireSummon", on)
            PSA.RefreshClassPetSettings("MAGE")
        end, nil, availability)
        section:EditBox(ui.MAGE_SUMMON_ID, function()
            return tostring(PSA.GetClassOption("mageSummonID", readOnly))
        end, not readOnly and function(value)
            PSA.SetClassOption("mageSummonID", value)
            PSA.RefreshClassPetSettings("MAGE")
        end, nil, 100, { numeric = true, enabled = availability.enabled, disabledTooltip = availability.disabledTooltip })
        page:AddSection(section)
    elseif forever and classFile == "HUNTER" then
        local section = page:NewSection(ui.FEED_SETTINGS, ui.FEED_SETTINGS_HINT)
        section:Check(ui.FEED_ENABLED, function()
            return PSA.GetClassOption("petFeedEnabled", readOnly)
        end, not readOnly and function(on)
            PSA.SetClassOption("petFeedEnabled", on)
            if PSA.RefreshPetCare then PSA.RefreshPetCare() end
        end, nil, availability)
        section:Check(ui.PET_UNHAPPY_ENABLED, function()
            return PSA.GetClassOption("petUnhappyAlertEnabled", readOnly)
        end, not readOnly and function(on)
            PSA.SetClassOption("petUnhappyAlertEnabled", on)
            if PSA.RefreshPetCare then PSA.RefreshPetCare() end
        end, nil, availability)
        local openMenu = not readOnly and PSA.OpenPetFoodSettingsMenu
        local row
        row = section:ButtonRow({{
            text = ui.FEED_CHOOSE_AUTO, width = 220,
            getText = openMenu and PSA.GetPetFeedFoodLabel,
            getEnabled = function()
                if readOnly then return false, ui.OTHER_CLIENT_SETTINGS end
                if not openMenu then return false, ui.FEED_REQUIRES_HUNTER end
                return not InCombatLockdown(), ui.SETTING_OUT_OF_COMBAT
            end,
            onClick = openMenu and function() if row then openMenu(row, rebuild) end end,
        }})
        page:AddSection(section)
    end
end

AddAlertSettings = function(s, statusKey, classFile, readOnly, availability, enableLabel)
        local function RefreshAlert()
            PSA.RefreshConfiguredAlert(statusKey, classFile)
        end
        s:Check(enableLabel or Text("Enable", "启用", "啟用"), function()
            if readOnly then return PSA.GetDefaultStatusEnabled(statusKey) end
            return PSA.IsStatusEnabled(statusKey, classFile)
        end, not readOnly and function(on)
            PSA.SetStatusEnabled(statusKey, on, classFile)
            RefreshAlert()
        end, nil, availability)
        s:EditBox(Text("Custom text", "自定义文字", "自訂文字"), function()
            if readOnly then return "" end
            return PSA.GetCustomMessage(statusKey, classFile)
        end, not readOnly and function(value)
            PSA.SetCustomMessage(statusKey, value, classFile)
            RefreshAlert()
        end, nil, 220, availability)
        s:ColorGrid({{
            label = Text("Text color", "文字颜色", "文字顏色"), alpha = true,
            enabled = availability.enabled, disabledTooltip = availability.disabledTooltip,
            getColor = function()
                if readOnly then return { PSA.GetDefaultStatusColor() } end
                return { PSA.GetStatusColor(statusKey, classFile) }
            end,
            setColor = not readOnly and function(color)
                PSA.SetStatusColor(statusKey, color[1], color[2], color[3], color[4], classFile)
                RefreshAlert()
            end,
        }}, { columns = 1 })
        local actions = {
            {text = PSA.UI.PREVIEW, onClick = function() PSA.PreviewStatus(statusKey, classFile) end},
            {text = Text("Default text", "默认文字", "預設文字"), onClick = function()
                PSA.SetCustomMessage(statusKey, "", classFile)
                RefreshAlert()
                if rebuild then rebuild() end
            end},
            {text = Text("Reset color", "重置颜色", "重設顏色"), onClick = function()
                PSA.ResetStatusColor(statusKey, classFile)
                RefreshAlert()
                if rebuild then rebuild() end
            end},
        }
        if readOnly then
            for _, action in ipairs(actions) do
                action.enabled = false
                action.disabledTooltip = availability.disabledTooltip
                action.onClick = nil
            end
        end
        s:ButtonRow(actions)
end

local function BuildClassAlerts(page, classFile, forever)
    local statuses = PSA.GetClassAlertStatuses(classFile, forever)
    if not statuses then
        page:AddSection(page:NewSection(PSA.GetAlertClassLabel(classFile), PSA.UI.CLASS_UNSUPPORTED))
        return
    end
    local readOnly = forever ~= PSA.IsForeverClient()
    local notes = {}
    if readOnly then notes[#notes + 1] = PSA.UI.OTHER_CLIENT_SETTINGS end
    notes[#notes + 1] = PSA.GetClassSupportNote(classFile, forever)
    page:AddSection(page:NewSection(PSA.GetAlertClassLabel(classFile, forever), notes))
    local availability = { enabled = not readOnly, disabledTooltip = PSA.UI.OTHER_CLIENT_SETTINGS }
    for _, statusKey in ipairs(statuses) do
        if statusKey ~= PSA.WRONG_PET_STATUS_KEY then
            local section = page:NewSection(PSA.STATUS_LABEL[statusKey], PSA.GetDefaultMessage(statusKey))
            AddAlertSettings(section, statusKey, classFile, readOnly, availability)
            page:AddSection(section)
        end
    end
    BuildClassRules(page, classFile, forever, readOnly, availability)
    if not readOnly then
        local section = page:NewSection(PSA.UI.CLASS_RESET)
        section:ButtonRow({{text = PSA.UI.CLASS_RESET, onClick = function() PSA.ConfirmClassReset(classFile, rebuild) end}})
        page:AddSection(section)
    end
end

local function ClassTabs(forever)
    local tabs = {}
    for _, classFile in ipairs(PSA.GetAlertClasses(false)) do
        local versions = {}
        for _, version in ipairs({ forever, not forever }) do
            local title = PSA.GetAlertClientName(version)
            if version ~= forever then
                title = "|cff9a9a9a" .. title .. " · " .. PSA.UI.READ_ONLY_TAB .. "|r"
            end
            versions[#versions + 1] = {
                key = version and "forever" or "retail", title = title,
                build = function(page) BuildClassAlerts(page, classFile, version) end,
            }
        end
        tabs[#tabs + 1] = {
            key = classFile,
            title = PSA.GetAlertClassLabel(classFile),
            subtabs = versions,
        }
    end
    return tabs
end

function PSA.GetSettingsDefinition(context)
    if PSA.HideStandaloneConfig then PSA.HideStandaloneConfig() end
    PSA.InitDB()
    local key = PSA.GetActiveLocale()
    if definitionKey ~= key then definition, definitionKey = nil, key end
    if not definition then
        local forever = PSA.IsForeverClient()
        definition = {external=true, tabs=ClassTabs(forever),
            OnSettingsHide=function() rebuild=nil; PSA.StopSettingsPreview() end, OnTabShow=PSA.StopSettingsPreview}
        local shared = {
            {key="display", title=Text("Display", "显示样式", "顯示樣式"), build=function(page)
                local s=page:NewSection(Text("Position & preview", "位置与预览", "位置與預覽"))
                s:Check(PSA.UI.LOCKED_STATUS, function() return PetStatusAlertDB.alertLocked end, PSA.SetAlertPositionLocked)
                s:ButtonRow({{text=PSA.UI.PREVIEW, onClick=PSA.PreviewDisplay}, {text=PSA.UI.STOP_PREVIEW, onClick=PSA.StopSettingsPreview},
                    {text=Text("Reset position", "重置位置", "重設位置"), onClick=function()
                        PetStatusAlertDB.alertPosition={point="CENTER",relativePoint="CENTER",x=0,y=220}; PSA.ApplyAlertPosition()
                    end}})
                page:AddSection(s)
                s=page:NewSection(PSA.UI.ANIMATION_ICON_MODE)
                s:Dropdown(PSA.UI.ANIMATION_ICON_MODE, PSA.GetAlertIconMode, PSA.SetAlertIconMode,
                    {{value="text",text=Text("Text", "文字", "文字")},{value="icon",text=Text("Icon", "图标", "圖示")},{value="both",text=Text("Icon + Text", "图标+文字", "圖示+文字")}},nil,180)
                local function Slider(section, key, low, high, step, get, set)
                    section:ValueSlider(PSA.UI[key],low,high,step,get,set,{note=PSA.UI[key.."_HINT"]})
                end
                Slider(s,"ANIMATION_ICON_SIZE",24,96,1,PSA.GetAlertIconSize,PSA.SetAlertIconSize)
                s:ValueSlider(Text("Icon / text spacing", "图标与文字间距", "圖示與文字間距"),0,40,1,PSA.GetAlertIconGap,PSA.SetAlertIconGap)
                page:AddSection(s)
                s=page:NewSection(Text("Text & movement", "文字与动画", "文字與動畫"))
                Slider(s,"ANIMATION_FONT_SIZE",12,72,1,PSA.GetAlertFontSize,PSA.SetAlertFontSize)
                Slider(s,"ANIMATION_AMPLITUDE",0,24,1,PSA.GetAlertFloatAmplitude,PSA.SetAlertFloatAmplitude)
                Slider(s,"ANIMATION_SPEED",0.1,3,0.1,PSA.GetAlertFloatSpeed,PSA.SetAlertFloatSpeed)
                s:Check(PSA.UI.ANIMATION_GLOW_ENABLE,PSA.GetAlertGlowEnabled,PSA.SetAlertGlowEnabled,PSA.UI.ANIMATION_GLOW_ENABLE_HINT)
                Slider(s,"ANIMATION_GLOW_SPEED",0.2,3,0.1,PSA.GetAlertGlowSpeed,PSA.SetAlertGlowSpeed)
                page:AddSection(s)
            end},
            {key="voice", title=Text("Voice", "语音提醒", "語音提醒"), build=function(page)
                local s=page:NewSection(PSA.UI.COMBAT_TTS,PSA.UI.TTS_BEHAVIOR_HINT)
                s:Check(PSA.UI.COMBAT_TTS,function() return PetStatusAlertDB.combatTTSEnabled end,function(on)
                    PetStatusAlertDB.combatTTSEnabled=on
                    if on then PSA.RefreshCombatTTSReminder(true) else PSA.StopCombatTTSReminder() end
                end)
                s:ValueSlider(PSA.UI.COMBAT_TTS_RATE,-10,10,1,PSA.GetCombatTTSRate,PSA.SetCombatTTSRate,{note=PSA.UI.COMBAT_TTS_RATE_HINT})
                s:Check(PSA.UI.TTS_REPEAT,function() return PSA.GetCombatTTSInterval() > 0 end,function(on)
                    PSA.SetCombatTTSInterval(on and PSA.GetCombatTTSRepeatInterval() or 0)
                end)
                s:ValueSlider(PSA.UI.TTS_INTERVAL,2,15,1,PSA.GetCombatTTSRepeatInterval,PSA.SetCombatTTSInterval,
                    {getEnabled = function() return PSA.GetCombatTTSInterval() > 0, PSA.UI.TTS_ONCE end})
                s:ButtonRow({{text=PSA.UI.TTS_SAMPLE, onClick=PSA.PlayCombatTTSSample}})
                page:AddSection(s)
            end},
            {key="general", title=Text("General", "通用", "一般"), build=function(page)
                local title=Text("Language", "语言", "語言")
                local s=page:NewSection(title,PSA.UI.LANGUAGE_DESC)
                s:Dropdown(title,PSA.GetSavedLanguageMode,function(v)
                    PSA.ApplyManagerLanguage(v)
                    -- 语言切换会替换所有静态文案，需要重建当前页面。
                    if rebuild then rebuild() end
                end,{{value="auto",text=PSA.UI.LANGUAGE_AUTO},{value="enUS",text=PSA.UI.LANGUAGE_ENUS},{value="zhCN",text=PSA.UI.LANGUAGE_ZHCN},{value="zhTW",text=PSA.UI.LANGUAGE_ZHTW},{value="ruRU",text=PSA.UI.LANGUAGE_RURU}},nil,180)
                page:AddSection(s)
            end},
        }
        for _, tab in ipairs(shared) do definition.tabs[#definition.tabs + 1] = tab end
        definition.tabs[#definition.tabs + 1] = {
            key = "forever",
            title = forever and PSA.UI.AMMO_SETTINGS or "|cff9a9a9a" .. PSA.UI.AMMO_SETTINGS .. "|r",
            build = function(page)
                local note = { PSA.UI.AMMO_WEAPON_HINT, PSA.UI.AMMO_THRESHOLD_HINT }
                if not forever then table.insert(note, 1, PSA.UI.OTHER_CLIENT_SETTINGS) end
                local s = page:NewSection(PSA.UI.AMMO_SETTINGS, note)
                s:EditBox(PSA.UI.AMMO_THRESHOLD, function()
                    return forever and PSA.GetAmmoThreshold() or PSA.DEFAULT_AMMO_THRESHOLD
                end, forever and PSA.SetAmmoThreshold, nil, 84, {numeric=true, enabled=forever,
                    disabledTooltip=PSA.UI.OTHER_CLIENT_SETTINGS})
                page:AddSection(s)
            end,
        }
    end
    -- 外部插件设置页由 UI.RefreshToolboxSettings 提供 Rebuild；管理器内部页面
    -- 只有 Refresh（W:Refresh）。两者都保留，按钮/语言切换后控件不会停在旧值。
    definition.OnSettingsShow=function()
        rebuild = context and (context.Rebuild or context.Refresh) or nil
    end
    return definition
end
