-- startup class check
local function p(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffAAD372INFO|r: " .. tostring(msg))
end
if UnitClass("player") ~= "Hunter" then
        p("Addon only works for Hunters.")
        return
    else
        p("Welcome |cffAAD372Hunter|r. Use /|cffAAD372beastrp|r or /|cffAAD372brp|r to open config.")
end

-- mainframe
local BRP = CreateFrame("Frame", nil, UIParent)
BRP:RegisterEvent("ADDON_LOADED")
BRP:RegisterEvent("PLAYER_ENTERING_WORLD")
BRP:RegisterEvent("PLAYER_REGEN_ENABLED")
BRP:RegisterEvent("PLAYER_REGEN_DISABLED")
BRP:RegisterEvent("UNIT_PET")
BRP:RegisterEvent("PET_BAR_UPDATE")

-- debug
local DEBUG_MODE = false
local function pd(msg)
    if DEBUG_MODE then
        if type(msg) == "table" then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000DEBUG TABLE|r: " .. "[" .. tostring(msg) .. "] : " .. (getmetatable(msg) and "Metatable" or "No metatable"))
            for key, value in pairs(msg) do
                DEFAULT_CHAT_FRAME:AddMessage("|cffff7777>CONTENT|r: " .. "[" .. tostring(msg) .. "] : " .. tostring(key) .. " : " .. tostring(value))
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000DEBUG|r: " .. tostring(msg))
        end
    end
end

-- config
BeastRP_config = BeastRP_config or {
    afterCOMBAT = true,
    afterCALL = true,
    afterAFK = true,
    AFKTimeout = 25,
    AFKrepeat = 30,
    ProcChance = 50,
}
pd(BeastRP_config)

-- soundmap
local soundMap = {}
local baseSoundPath = "Interface\\AddOns\\BeastRP\\sounds\\"
local petTypes = {
    "Bat", "Bear", "Boar", "Carrion Bird", "Cat", "Crab", "Crocolisk", "Gorilla", "Hyena", "Owl",
    "Raptor", "Scorpid", "Spider", "Tallstrider", "Turtle", "Wind Serpent", "Wolf"
}
for _, petType in ipairs(petTypes) do
    soundMap[petType] = {}
    for i = 1, 4 do
        table.insert(soundMap[petType], baseSoundPath .. petType .. "\\" .. i .. ".mp3")
    end
end
pd(soundMap)

-- functions
local function PetInfo(info)
    if info == "exists" then return UnitExists("pet") end
    if info == "family" then return UnitCreatureFamily("pet") end
    if info == "alive" then return not UnitIsDead("pet") end
    return nil
end

local function PlaySound()
    if PetInfo("exists") and PetInfo("alive") and soundMap[PetInfo("family")] then
        PlaySoundFile(soundMap[PetInfo("family")][math.random(1, 4)])
    end
end

local lastActivityTime = GetTime()
local isAFK = false
local function C_Timer(delay, callback)
    local f = CreateFrame("Frame")
    local startTime = GetTime()

    f:SetScript("OnUpdate", function()
        if GetTime() - startTime >= delay then
            callback()
            f:SetScript("OnUpdate", nil)
        end
    end)
    return f
end

local function PlayAFKSound()
    if isAFK and not UnitAffectingCombat("player") and  BeastRP_config["afterAFK"] then
        if PetInfo("family") then
            PlaySound()
            pd("Sound played (afterAFK) - (" .. PetInfo("family")..") - ("..BeastRP_config.AFKTimeout.." sec) - ("..BeastRP_config.AFKrepeat.." sec)")
        end
        -- next sound after x seconds
        C_Timer(BeastRP_config.AFKrepeat, PlayAFKSound)
    end
end

local function ResetAFKTimer()
    lastActivityTime = GetTime()
    if isAFK then
        pd("AFK |cFFFF0000canceled")
        isAFK = false
    end
end

-- handler
local lastPetType = nil -- UNIT_PET fires multiple times, this prevents it

BRP:SetScript("OnEvent", function ()
    if event == "PLAYER_REGEN_ENABLED" and BeastRP_config["afterCOMBAT"] then
        if math.random(1, 100) <= BeastRP_config.ProcChance then
            pd("Timer started 2 sec")
            C_Timer(2, function()
                if not UnitAffectingCombat("player") then
                    PlaySound()
                    pd("Sound played (afterCOMBAT)")
                else
                    pd("Sound canceled (combat)")
                end
            end)
        else
            pd("No sound played (afterCOMBAT)")
        end
    end

    if event == "UNIT_PET" and arg1 == "player" and BeastRP_config["afterCALL"] then
        if PetInfo("family") ~= lastPetType then
            PlaySound()
            pd("Sound played (afterCALL)")
            lastPetType = PetInfo("family")
        end
    end

    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        if BeastRP_config["afterAFK"] then
            pd("AFK timer |cFFFFD700changed")
            ResetAFKTimer()
        end
    end
end)

BRP:SetScript("OnUpdate", function()
    if not BeastRP_config["afterAFK"] then return end
        if GetTime() - lastActivityTime >= BeastRP_config.AFKTimeout and not isAFK and not UnitAffectingCombat("player") then
            pd("AFK |cFF00FF00enabled")
            isAFK = true
            PlayAFKSound()
        end
end)

-- gui
local optionsFrame = CreateFrame("Frame", "optionsFrame", UIParent)
    optionsFrame:RegisterEvent("ADDON_LOADED")

    optionsFrame:SetPoint("CENTER", 0, 0)
    optionsFrame:SetHeight(350)
    optionsFrame:SetWidth(200)
    optionsFrame:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background"})
    optionsFrame:SetBackdropColor(0, 0, 0, 0.5)
    optionsFrame:EnableMouse(true)
    optionsFrame:SetMovable(true)
    optionsFrame:SetScript("OnMouseDown", function() optionsFrame:StartMoving() end)
    optionsFrame:SetScript("OnMouseUp", function() optionsFrame:StopMovingOrSizing() end)
    optionsFrame:Hide()
    tinsert(UISpecialFrames, optionsFrame:GetName())

    local logoTexture = optionsFrame:CreateTexture(nil, "ARTWORK")
    logoTexture:SetWidth(256)
    logoTexture:SetHeight(32)
    logoTexture:SetPoint("CENTER", optionsFrame, "TOP", 0, 0)
    logoTexture:SetTexture("Interface\\AddOns\\BeastRP\\logo\\bRPlogo.tga")

    -- checkboxes func
    local checkboxes = {}
    local function createCheckbox(label, varName, yPos)
        local checkbox = CreateFrame("CheckButton", nil, optionsFrame, "UICheckButtonTemplate")
        checkbox:SetPoint("TOPLEFT", 16, yPos)
        checkbox.text = checkbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        checkbox.text:SetPoint("LEFT", checkbox, "RIGHT", 2, 0)
        checkbox.text:SetText(label)

        checkbox:SetScript("OnClick", function()
            BeastRP_config[varName] = checkbox:GetChecked() and true or false
        end)

        checkboxes[varName] = checkbox
    end

    -- create checkboxes
    createCheckbox("After Combat", "afterCOMBAT", -40)
    createCheckbox("After Call", "afterCALL", -110)
    createCheckbox("On AFK", "afterAFK", -145)

    -- inputboxes
    local inputBoxProcc = CreateFrame("EditBox", nil, optionsFrame)
    inputBoxProcc:SetWidth(30)
    inputBoxProcc:SetHeight(20)
    inputBoxProcc:SetPoint("TOP", -48, -80)
    inputBoxProcc:SetAutoFocus(false)
    inputBoxProcc:SetFontObject(ChatFontNormal)
    inputBoxProcc:SetBackdrop({bgFile = "Interface/ChatFrame/ChatFrameBackground"})
    inputBoxProcc:SetBackdropColor(0, 0, 0, 1)
    inputBoxProcc:Show()

    local fontStringProcc = inputBoxProcc:CreateFontString(nil, "OVERLAY")
    fontStringProcc:SetPoint("LEFT", inputBoxProcc, "RIGHT", 5, 0)
    fontStringProcc:SetFontObject(ChatFontNormal)

    inputBoxProcc:SetScript("OnChar", function()
        local char = arg1
        if not string.find("0123456789", char, 1, true) then
            inputBoxProcc:SetText(inputBoxProcc:GetText():sub(1, -2))
        end
    end)
    inputBoxProcc:SetScript("OnEnterPressed", function()
        local value = tonumber(this:GetText())
        if value then
            BeastRP_config.ProcChance = value
            pd("ProcChance set to: " .. value)
            pd(BeastRP_config.ProcChance)
        end
        this:SetText("")
        this:ClearFocus()
        fontStringProcc:SetText("Chance: "..tostring(BeastRP_config.ProcChance).." %")
    end)
    inputBoxProcc:SetScript("OnEscapePressed", function()
        this:SetText("")
        this:ClearFocus()
    end)

    local inputBox = CreateFrame("EditBox", nil, optionsFrame)
    inputBox:SetWidth(30)
    inputBox:SetHeight(20)
    inputBox:SetPoint("CENTER", -48, -21)
    inputBox:SetAutoFocus(false)
    inputBox:SetFontObject(ChatFontNormal)
    inputBox:SetBackdrop({bgFile = "Interface/ChatFrame/ChatFrameBackground"})
    inputBox:SetBackdropColor(0, 0, 0, 1)
    inputBox:Show()

    local fontString = inputBox:CreateFontString(nil, "OVERLAY")
    fontString:SetPoint("LEFT", inputBox, "RIGHT", 5, 0)
    fontString:SetFontObject(ChatFontNormal)

    inputBox:SetScript("OnChar", function()
        local char = arg1
        if not string.find("0123456789", char, 1, true) then
            inputBox:SetText(inputBox:GetText():sub(1, -2)) -- Remove invalid input
        end
    end)
    inputBox:SetScript("OnEnterPressed", function()
        local value = tonumber(this:GetText())
        if value then
            BeastRP_config.AFKTimeout = value
            pd("AFKTimeout set to: " .. value)
            pd(BeastRP_config.AFKTimeout)
        end
        this:SetText("")
        this:ClearFocus()
        fontString:SetText("Start after: "..tostring(BeastRP_config.AFKTimeout).." sec")
    end)
    inputBox:SetScript("OnEscapePressed", function()
        this:SetText("")
        this:ClearFocus()
    end)

    local inputBox2 = CreateFrame("EditBox", nil, inputBox)
    inputBox2:SetWidth(30)
    inputBox2:SetHeight(20)
    inputBox2:SetPoint("CENTER", 0, -30)
    inputBox2:SetAutoFocus(false)
    inputBox2:SetFontObject(ChatFontNormal)
    inputBox2:SetBackdrop({bgFile = "Interface/ChatFrame/ChatFrameBackground"})
    inputBox2:SetBackdropColor(0, 0, 0, 1)
    inputBox2:Show()

    local fontString2 = inputBox2:CreateFontString(nil, "OVERLAY")
    fontString2:SetPoint("LEFT", inputBox2, "RIGHT", 5, 0)
    fontString2:SetFontObject(ChatFontNormal)

    inputBox2:SetScript("OnChar", function()
        local char = arg1
        if not string.find("0123456789", char, 1, true) then
            inputBox2:SetText(inputBox2:GetText():sub(1, -2)) -- Remove invalid input
        end
    end)
    inputBox2:SetScript("OnEnterPressed", function()
        local value = tonumber(this:GetText())
        if value then
            BeastRP_config.AFKrepeat = value
            pd("AFKRepeat set to: " .. value)
            pd(BeastRP_config.AFKrepeat)
        end
        this:SetText("")
        this:ClearFocus()
        fontString2:SetText(("Repeat after: "..tostring(BeastRP_config.AFKrepeat)).." sec")
    end)
    inputBox2:SetScript("OnEscapePressed", function()
        this:SetText("")
        this:ClearFocus()
    end)

    -- debug button
    local debugButton = CreateFrame("Button", "DebugButton", optionsFrame)
        debugButton:SetWidth(120)
        debugButton:SetHeight(30)
        debugButton:SetScale(0.8)
        debugButton:SetPoint("BOTTOM", 0, 40)
        debugButton:SetNormalTexture(nil)
        debugButton:SetPushedTexture(nil)
        debugButton:SetHighlightTexture(nil)

        local text = debugButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetText("Debug")
        text:SetPoint("CENTER", 0, 0)

        debugButton:SetScript("OnClick", function()
            DEBUG_MODE = not DEBUG_MODE
            if DEBUG_MODE then
                text:SetTextColor(1, 0, 0)
                p("Debug mode |cFF00FF00enabled|r.")
            else
                text:SetTextColor(1, 0.82, 0)
                p("Debug mode |cFFFF0000disabled|r.")
            end
    end)

    -- exit button
    local closeButton = CreateFrame("Button", nil, optionsFrame, "UIPanelButtonTemplate")
        closeButton:SetWidth(80)
        closeButton:SetHeight(20)
        closeButton:SetPoint("BOTTOM", optionsFrame, "BOTTOM", 0, 5)
        closeButton:SetText("Exit")
        closeButton:SetNormalTexture(nil)
        closeButton:SetPushedTexture(nil)
        closeButton:SetHighlightTexture(nil)
        closeButton:SetScript("OnClick", function()
            UIFrameFadeOut(optionsFrame, 0.4, optionsFrame:GetAlpha(), 0)
            C_Timer(0.4, function() optionsFrame:Hide() end)
    end)

    -- event
    optionsFrame:SetScript("OnEvent", function()
        if event == "ADDON_LOADED" and arg1 == "BeastRP" then
            for varName, checkbox in pairs(checkboxes) do
                if BeastRP_config[varName] ~= nil then
                    checkbox:SetChecked(BeastRP_config[varName])
                end
            end
            fontStringProcc:SetText("Chance: "..tostring(BeastRP_config.ProcChance).." %")
            fontString:SetText("Start after: "..tostring(BeastRP_config.AFKTimeout).." sec")
            fontString2:SetText("Repeat after: "..tostring(BeastRP_config.AFKrepeat).." sec")

        end
end)

SLASH_BEASTRP1 = "/brp"
SLASH_BEASTRP2 = "/beastrp"
    SlashCmdList["BEASTRP"] = function()
    if optionsFrame:IsShown() then
        UIFrameFadeOut(optionsFrame, 0.4, optionsFrame:GetAlpha(), 0)
        C_Timer(0.4, function() optionsFrame:Hide() end)
    else
        optionsFrame:Show()
        UIFrameFadeIn(optionsFrame, 0.4, 0, 1)
    end
end