local E, L = unpack(ART)
local Nicknames = E:GetModule("Nicknames")

local vuhDoHooks = {}
local vuhDoPanelSettings = {}

local function UpdateVuhDoName(unit, nameText, buttonName)
    if not unit or not UnitExists(unit) then
        return
    end

    local name
    if Nicknames:IsIntegrationActive("VuhDo") then
        name = Nicknames:GetIfAny(unit)
    end

    if not name then
        name = UnitName(unit)
    end

    local panelNumber = buttonName and buttonName:match("^Vd(%d+)")
    panelNumber = tonumber(panelNumber)

    local maxChars = panelNumber and vuhDoPanelSettings[panelNumber] and vuhDoPanelSettings[panelNumber].maxChars

    if name and maxChars and maxChars > 0 then
        name = name:sub(1, maxChars)
    end

    nameText:SetFormattedText(name or "")
end

local function UpdateAll()
    if not _G.VUHDO_UNIT_BUTTONS then
        return
    end

    for unit, unitButtons in pairs(_G.VUHDO_UNIT_BUTTONS) do
        if UnitExists(unit) then
            for _, button in ipairs(unitButtons) do
                local unitButtonName = button:GetName()
                local nameText = _G[unitButtonName .. "BgBarHlBarTxPnlUnN"]
                if nameText then
                    UpdateVuhDoName(unit, nameText, unitButtonName)
                end
            end
        end
    end
end

local function Update(unit)
    if not _G.VUHDO_UNIT_BUTTONS or not unit or not UnitExists(unit) then
        return
    end

    for vuhDoUnit, unitButtons in pairs(_G.VUHDO_UNIT_BUTTONS) do
        if UnitIsUnit(unit, vuhDoUnit) then
            for _, button in ipairs(unitButtons) do
                local unitButtonName = button:GetName()
                local nameText = _G[unitButtonName .. "BgBarHlBarTxPnlUnN"]
                if nameText then
                    UpdateVuhDoName(unit, nameText, unitButtonName)
                end
            end
            break
        end
    end
end

local function OnToggle(_enabled)
    UpdateAll()
end

local function Init()
    if not _G.VUHDO_PANEL_SETUP or not _G.VUHDO_getBarText then
        return
    end

    for i, settings in pairs(_G.VUHDO_PANEL_SETUP) do
        if type(settings) == "table" and settings.PANEL_COLOR and settings.PANEL_COLOR.TEXT then
            vuhDoPanelSettings[i] = settings.PANEL_COLOR.TEXT
        end
    end

    hooksecurefunc("VUHDO_getBarText", function(unitHealthBar)
        local unitFrameName = unitHealthBar and unitHealthBar:GetName()
        if not unitFrameName then
            return
        end

        local nameText = _G[unitFrameName .. "TxPnlUnN"]
        if not nameText or vuhDoHooks[nameText] then
            return
        end

        local unitButton = _G[unitFrameName:match("(.+)BgBarHlBar")]
        if not unitButton then
            return
        end

        hooksecurefunc(nameText, "SetText", function(self)
            local unit = unitButton.raidid
            UpdateVuhDoName(unit, self, unitFrameName)
        end)

        vuhDoHooks[nameText] = true
    end)
end

Nicknames:RegisterIntegration("VuhDo", {
    Init = Init,
    Update = Update,
    OnToggle = OnToggle
})
