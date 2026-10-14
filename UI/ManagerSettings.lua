local _, PSA = ...
local definition, rebuild
local function Text(en, cn, tw)
    local locale = PSA.GetActiveLocale()
    return locale == "zhCN" and cn or locale == "zhTW" and tw or en
end
function PSA.TryOpenManager(key)
    local manager = rawget(_G, "QFXAddonManagerAPI")
    if not manager or not manager.OpenAddonSettings then return false end
    if PSA.HideStandaloneConfig then PSA.HideStandaloneConfig() end
    manager.OpenAddonSettings("PetStatusAlert", key)
    return true
end
local function StopPreview()
    if PSA.currentStatusForce then PSA.HideStatus(); PSA.RefreshPetStatusText() end
end
function PSA.GetSettingsDefinition(context)
    if PSA.HideStandaloneConfig then PSA.HideStandaloneConfig() end
    PSA.InitDB()
    if not definition then
        definition = {external=true, tabs={
            {key="alerts", title=Text("Alerts", "提醒设置", "提醒設定"), build=function(page)
                for _, value in ipairs(PSA.STATUS_ORDER) do
                    local key = value
                    local s = page:NewSection(PSA.STATUS_LABEL[key], PSA.GetDefaultMessage(key))
                    s:Check(Text("Enable", "启用", "啟用"), function() return PSA.IsStatusEnabled(key) end,
                        function(on) PSA.SetStatusEnabled(key,on); PSA.RefreshPetStatusText() end)
                    s:EditBox(Text("Custom text", "自定义文字", "自訂文字"), function() return PetStatusAlertDB.customMessages[key] or "" end,
                        function(v) PetStatusAlertDB.customMessages[key]=v; PSA.RefreshPetStatusText() end, nil, 220)
                    s:ColorGrid({{label=Text("Text color", "文字颜色", "文字顏色"), alpha=true,
                        getColor=function() return {PSA.GetStatusColor(key)} end,
                        setColor=function(c) PSA.SetStatusColor(key,c[1],c[2],c[3],c[4]); PSA.ApplyAlertTextColor() end}}, {columns=1})
                    s:ButtonRow({{text=PSA.UI.PREVIEW, onClick=function() PSA.PreviewStatus(key) end},
                        {text=Text("Default text", "默认文字", "預設文字"), onClick=function() PetStatusAlertDB.customMessages[key]=""; PSA.RefreshPetStatusText() end},
                        {text=Text("Reset color", "重置颜色", "重設顏色"), onClick=function() PSA.ResetStatusColor(key); PSA.ApplyAlertTextColor() end}})
                    page:AddSection(s)
                end
            end},
            {key="display", title=Text("Display", "显示样式", "顯示樣式"), build=function(page)
                local s=page:NewSection(Text("Position & preview", "位置与预览", "位置與預覽"))
                s:Check(PSA.UI.LOCKED_STATUS, function() return PetStatusAlertDB.alertLocked end, PSA.SetAlertPositionLocked)
                s:ButtonRow({{text=PSA.UI.PREVIEW, onClick=function() PSA.PreviewStatus("PASSIVE") end},
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
                local s=page:NewSection(PSA.UI.COMBAT_TTS,PSA.UI.COMBAT_TTS_HINT)
                s:Check(PSA.UI.COMBAT_TTS,function() return PetStatusAlertDB.combatTTSEnabled end,function(on)
                    PetStatusAlertDB.combatTTSEnabled=on
                    if on then PSA.RefreshCombatTTSReminder(true) else PSA.StopCombatTTSReminder() end
                end)
                s:ValueSlider(PSA.UI.COMBAT_TTS_RATE,-10,10,1,PSA.GetCombatTTSRate,PSA.SetCombatTTSRate,{note=PSA.UI.COMBAT_TTS_RATE_HINT})
                page:AddSection(s)
            end},
            {key="general", title=Text("General", "通用", "一般"), build=function(page)
                local title=Text("Language", "语言", "語言")
                local s=page:NewSection(title,PSA.UI.LANGUAGE_DESC)
                s:Dropdown(title,PSA.GetSavedLanguageMode,function(v)
                    PSA.ApplyManagerLanguage(v); definition=nil
                    if rebuild then rebuild() end
                end,{{value="auto",text=PSA.UI.LANGUAGE_AUTO},{value="enUS",text=PSA.UI.LANGUAGE_ENUS},{value="zhCN",text=PSA.UI.LANGUAGE_ZHCN},{value="zhTW",text=PSA.UI.LANGUAGE_ZHTW},{value="ruRU",text=PSA.UI.LANGUAGE_RURU}},nil,180)
                page:AddSection(s)
            end},
        }, OnSettingsHide=function() rebuild=nil; StopPreview() end, OnTabShow=StopPreview}
    end
    definition.OnSettingsShow=function() rebuild=context.Rebuild end
    return definition
end
