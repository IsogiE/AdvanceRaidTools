local E, L = unpack(ART)
local Nicknames = E:GetModule("Nicknames")

local unitButtonTables = {}

local function UpdateAll()
    if not _G.Cell then
        return
    end

    for _, unitButtonTable in pairs(unitButtonTables) do
        for _, unitButton in pairs(unitButtonTable) do
            if type(unitButton) == "table" then
                if unitButton.states and unitButton.states.isPlayer then
                    if unitButton.indicators and unitButton.indicators.nameText and
                        unitButton.indicators.nameText.UpdateName then
                        unitButton.indicators.nameText:UpdateName()
                    end
                end
            end
        end
    end
end

local function Update(unit)
    if not _G.Cell then
        return
    end

    local playerFrame = _G.CellSoloFramePlayer

    for _, unitButtonTable in pairs(unitButtonTables) do
        for _, unitButton in pairs(unitButtonTable) do
            if type(unitButton) == "table" then
                local buttonUnit = unitButton == playerFrame and "player" or unitButton.unit

                if buttonUnit and UnitIsUnit(buttonUnit, unit) then
                    if unitButton.indicators and unitButton.indicators.nameText and
                        unitButton.indicators.nameText.UpdateName then
                        unitButton.indicators.nameText:UpdateName()
                    end
                end
            end
        end
    end
end

local function OnToggle(_enabled)
    UpdateAll()
end

local function Init()
    local Cell = _G.Cell
    if not Cell then
        return
    end

    local F = Cell.funcs
    local LibTranslit = E.Libs.LibTranslit

    unitButtonTables = {Cell.unitButtons.solo, Cell.unitButtons.party, Cell.unitButtons.quickAssist,
                        Cell.unitButtons.spotlight, Cell.unitButtons.raid.CellRaidFrameHeader0,
                        Cell.unitButtons.raid.CellRaidFrameHeader1, Cell.unitButtons.raid.CellRaidFrameHeader2,
                        Cell.unitButtons.raid.CellRaidFrameHeader3, Cell.unitButtons.raid.CellRaidFrameHeader4,
                        Cell.unitButtons.raid.CellRaidFrameHeader5, Cell.unitButtons.raid.CellRaidFrameHeader6,
                        Cell.unitButtons.raid.CellRaidFrameHeader7, Cell.unitButtons.raid.CellRaidFrameHeader8}

    local function NicknameFunction(parent, nickname)
        local nameText = parent.indicators.nameText
        local name = nickname

        if Cell.loaded and CellDB and CellDB["general"] and CellDB["general"]["translit"] and LibTranslit then
            name = LibTranslit:Transliterate(name)
        end

        F.UpdateTextWidth(nameText.name, name, nameText.width, parent.widgets.healthBar)

        if CELL_SHOW_GROUP_PET_OWNER_NAME and parent.isGroupPet then
            local owner = F.GetPlayerUnit(parent.states.unit)
            owner = UnitName(owner)

            if E:SafeString(owner) then
                if CELL_SHOW_GROUP_PET_OWNER_NAME == "VEHICLE" then
                    F.UpdateTextWidth(nameText.vehicle, owner, nameText.width, parent.widgets.healthBar)
                elseif CELL_SHOW_GROUP_PET_OWNER_NAME == "NAME" then
                    F.UpdateTextWidth(nameText.name, owner, nameText.width, parent.widgets.healthBar)
                end
            end
        end

        if nameText.name:GetText() then
            if nameText.isPreview then
                if nameText.showGroupNumber then
                    nameText.name:SetText("|cffbbbbbb7-|r" .. nameText.name:GetText())
                end
            else
                if IsInRaid() and nameText.showGroupNumber then
                    local raidIndex = UnitInRaid(parent.states.unit)
                    if raidIndex then
                        local subgroup = select(3, GetRaidRosterInfo(raidIndex))
                        nameText.name:SetText("|cffbbbbbb" .. subgroup .. "-|r" .. nameText.name:GetText())
                    end
                end
            end
        end

        nameText:SetSize(nameText.name:GetWidth(), nameText.name:GetHeight())
    end

    for _, unitButtonTable in pairs(unitButtonTables) do
        -- Check if the table actually exists to prevent errors if Cell modifies its headers
        if unitButtonTable then
            for _, unitButton in pairs(unitButtonTable) do
                if type(unitButton) == "table" then
                    local nameTextIndicator = unitButton.indicators and unitButton.indicators.nameText
                    local OriginalFunction = nameTextIndicator and nameTextIndicator.UpdateName

                    if OriginalFunction and not unitButton.__artHooked then
                        unitButton.__artHooked = true
                        unitButton.indicators.nameText.UpdateName = function(...)
                            local unit = unitButton == _G.CellSoloFramePlayer and "player" or unitButton.unit

                            local nickname = nil
                            if Nicknames:IsIntegrationActive("Cell") then
                                nickname = Nicknames:GetIfAny(unit)
                            end

                            if nickname then
                                NicknameFunction(unitButton, nickname)
                            else
                                OriginalFunction(...)
                            end
                        end
                    end
                end
            end
        end
    end

    UpdateAll()
end

Nicknames:RegisterIntegration("Cell", {
    Init = Init,
    Update = Update,
    OnToggle = OnToggle
})
