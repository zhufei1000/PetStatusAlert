-------------------------------------------------
-- PetStatusAlert slash commands
-------------------------------------------------

local ADDON_NAME, PSA = ...
PSA = PSA or _G.PetStatusAlert

local Trim = PSA.Trim
local InitDB = PSA.InitDB
local STATUS_ORDER = PSA.STATUS_ORDER
local RefreshPetStatusText = PSA.RefreshPetStatusText
local OpenNativeOptionsFrame = PSA.OpenNativeOptionsFrame
local OpenOptionsFrame = PSA.OpenOptionsFrame

local UI = setmetatable({}, {
    __index = function(_, key)
        return PSA.UI and PSA.UI[key]
    end,
})

SLASH_PETSTATUSALERT1 = "/petstatusalert"
SLASH_PETSTATUSALERT2 = "/psa"
SlashCmdList.PETSTATUSALERT = function(msg)
    msg = Trim(msg):lower()
    if msg == "reset" then
        InitDB()
        for _, statusKey in ipairs(STATUS_ORDER) do
            PetStatusAlertDB.customMessages[statusKey] = ""
        end
        print("|cff3aa6ffPetStatusAlert:|r " .. UI.RESET_DONE)
        RefreshPetStatusText()
        return
    end

    if msg == "options" or msg == "setting" or msg == "settings" then
        OpenNativeOptionsFrame()
        return
    end

    OpenOptionsFrame()
end
