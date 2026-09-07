local E = unpack(ART)
local BossMods = E:GetModule("BossMods")
local MODULE_NAME = "BossMods_UlatekKicker"
local ENCOUNTER_ID = 3492
local TRACKING_START = 240
local INTERRUPT_ADD_LEVEL = 92
local INTERRUPT_CAST_WINDOW = 5
local BOSS_UNITS = {"boss2", "boss3", "boss4", "boss5"}
local SPELLCAST_EVENTS = {"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_STOP"}
local MARKERS = {
    star = 1, circle = 2, diamond = 3, triangle = 4,
    moon = 5, square = 6, cross = 7, skull = 8
}
local Display = BossMods.KickDisplay
local issecretvalue = _G.issecretvalue or function() return false end

local defaults = CopyTable(Display.defaults)
defaults.nameplate.hide = false
E:RegisterModuleDefaults(MODULE_NAME, defaults)
local Kicker = E:NewModule(MODULE_NAME, "AceEvent-3.0")
Display:Install(Kicker)

function Kicker:MarkerText(marker)
    return "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_" .. marker .. ":0|t"
end

function Kicker:ParseGroup(ctx, groupIndex)
    local Ready = BossMods.ReadyAssignments
    local sections = ctx.tags and ctx.tags["ulakick" .. groupIndex] or {}
    local group = {players = {}}
    for _, section in ipairs(sections) do
        local words = Ready:Words(section.text or section.headerText or "")
        for _, token in ipairs(words) do
            if not group.marker then
                local markerToken = token:lower():match("^{(.-)}$")
                local marker = markerToken and (
                    tonumber(markerToken:match("^rt([1-8])$")) or MARKERS[markerToken]
                )
                if not marker then return nil end
                group.marker = marker
            else
                group.players[#group.players + 1] = token
            end
        end
    end
    if group.marker and #group.players > 0 then return group end
end

function Kicker:ParseAssignments()
    local Ready = BossMods.ReadyAssignments
    local NoteBlock = BossMods.NoteBlock
    self.noteContext = Ready:BuildContext()
    self.Interrupts = self.Interrupts or {}
    self.Interrupts.assignTable = {}
    self.Interrupts.myID = 0
    self.Interrupts.myKick = 0
    self.Interrupts.myTrackedID = 0
    self.Interrupts.castCount = 1
    self.Interrupts.max = 0
    self.Interrupts.myTable = {}
    self.Interrupts.disabled = true
    local count = 1
    for groupIndex = 1, 4 do
        local group = self:ParseGroup(self.noteContext, groupIndex)
        if group then
            count = count + 1
            local num = 0
            self.Interrupts.assignTable[count] = {}
            for _, token in ipairs(group.players) do
                local unit = NoteBlock:FindUnitByToken(token)
                local name = unit and E:GetUnitFullName(unit, true)
                if name and UnitInRaid(name) then
                    num = num + 1
                    table.insert(self.Interrupts.assignTable[count], name)
                    if UnitIsUnit(name, "player") then
                        self.Interrupts.disabled = false
                        self.Interrupts.myID = count
                        self.Interrupts.myKick = num
                    end
                    if count == self.Interrupts.myID then
                        self.Interrupts.max = #self.Interrupts.assignTable[count]
                    end
                end
            end
        end
    end
    self.Interrupts.myTrackedID = self.Interrupts.myID
    self.Interrupts.myTable = self.Interrupts.assignTable[self.Interrupts.myID] or {}
end

function Kicker:GetFocusedBossUnit()
    for bossIndex = 2, 5 do
        local bossUnit = "boss" .. bossIndex
        local isBoss = UnitIsUnit("focus", bossUnit)
        if issecretvalue(isBoss) then return end
        if isBoss and UnitLevel(bossUnit) == INTERRUPT_ADD_LEVEL then return bossUnit end
    end
end

function Kicker:ConsumeInterruptCastStart(unit)
    if UnitLevel(unit) ~= INTERRUPT_ADD_LEVEL then return false end
    local startedAt = self.castStarts[unit]
    if not startedAt then return false end
    self.castStarts[unit] = nil
    return GetTime() - startedAt <= INTERRUPT_CAST_WINDOW
end

function Kicker:ResetInterrupts()
    self.Interrupts.castCount = 1
    self.Interrupts.myTrackedID = self.Interrupts.myID
    self:HideInterrupt()
end

function Kicker:OnBossSpellcast(event, unit)
    if not self.trackingEnabled or unit == self.focusedBoss then return end
    if event == "UNIT_SPELLCAST_START" then
        if UnitLevel(unit) == INTERRUPT_ADD_LEVEL then
            self.castStarts[unit] = GetTime()
        end
        return
    end
    if event == "UNIT_SPELLCAST_STOP" then
        self.castStarts[unit] = nil
        return
    end
    if not self:ConsumeInterruptCastStart(unit) then return end
    local castCount = self.bossCounts[unit] + 1
    if castCount > self.Interrupts.max then
        castCount = 1
    end
    self.bossCounts[unit] = castCount
end

function Kicker:HideInterrupt()
    self.staticDisplay = nil
    if self.frames then
        self.frames.anchor:Hide()
        self.frames.kickBox:Hide()
        self.frames.nextTextAnchor:Hide()
    end
end

function Kicker:HideDisplays()
    self:HideInterrupt()
    if self.nameplateBox then self.nameplateBox:Hide() end
end

function Kicker:ApplySettings()
    self:EnsureDefaults()
    self:EnsureFrames()
    self:ApplyAppearance()
    self:ApplyPositions()
    if not self.nameplateBox then
        self.nameplateBox = Display.CreateBox(self.frames.nameplateRoot)
        self.nameplateBox:SetFrameLevel(95)
    end
    local config = self.db.nameplate
    local scale = config.size / 30
    self:ApplyBoxAppearance(self.nameplateBox, config.size,
        config.numberFontSize * scale, config.nameFontSize * scale)
end

function Kicker:DisplayInterrupt(isCastStart)
    local myKick = self.Interrupts.myKick
    local castCount = self.Interrupts.castCount
    local unit = self.Interrupts.myTable[castCount]
    local name, class = "", nil
    if unit and UnitExists(unit) then
        name, class = self:GetKickDisplayInfo(unit)
    end
    local state = "idle"
    if castCount == myKick then
        if isCastStart then
            state = "now"
        else
            state = "next"
        end
    elseif (castCount + 1 == myKick) or (myKick == 1 and castCount == self.Interrupts.max) then
        state = "next"
    end
    self.staticDisplay = {count = castCount, name = name, class = class, state = state}
    self:UpdateStaticDisplay()
end

function Kicker:UpdateStaticDisplay()
    if not self.frames then return end
    self.frames.anchor:SetShown(self.editMode == true)
    local box = self.frames.kickBox
    box:ClearAllPoints()
    box:SetPoint("CENTER", self.frames.anchor, "CENTER", 0, 0)
    if self.editMode then
        local name, class = self:GetKickDisplayInfo(UnitName("player"))
        self:SetBoxState(box, "now", 1, name, Display.previewColors, class)
        box:Show()
        self:UpdateNextText(true)
        return
    end
    local display = self.staticDisplay
    if not display then
        box:Hide()
        self.frames.nextTextAnchor:Hide()
        return
    end
    self:SetBoxState(box, display.state, display.count, display.name, nil, display.class)
    box:Show()
    self:UpdateNextText(display.state == "next")
end

function Kicker:UpdateNameplateDisplay()
    if not self.nameplateBox then return end
    if self.editMode or not self.encounterActive then
        self.nameplateBox:Hide()
        return
    end
    if not self:GetFocusedBossUnit() then
        self.nameplateBox:Hide()
        return
    end
    if not self.Interrupts or self.Interrupts.disabled or self.Interrupts.myTrackedID == 0 then
        self.nameplateBox:Hide()
        return
    end

    local interruptNames = self.Interrupts.myTable
    local castCount = self.Interrupts.castCount
    local currentName = #interruptNames > 0 and interruptNames[castCount] or nil
    local nextName = #interruptNames > 0 and interruptNames[castCount % #interruptNames + 1] or nil
    local state = "idle"
    if currentName and UnitIsUnit(currentName, "player") then
        state = "now"
    elseif nextName and UnitIsUnit(nextName, "player") then
        state = "next"
    end
    local name, class = self:GetKickDisplayInfo(currentName)

    local config = self.db.nameplate
    local plate = not config.hide and C_NamePlate.GetNamePlateForUnit("focus")
    if plate then
        Display.AnchorToNameplate(self.nameplateBox, plate,
            config.anchor, config.offsetX, config.offsetY)
        self.nameplateBox:SetScale(plate:GetEffectiveScale() / UIParent:GetEffectiveScale())
        self:SetBoxState(self.nameplateBox, state, castCount, name, nil, class)
        self.nameplateBox:Show()
    else
        self.nameplateBox:Hide()
    end
end

function Kicker:UpdateDisplay()
    self:UpdateStaticDisplay()
    self:UpdateNameplateDisplay()
end

function Kicker:PlayInterruptSound()
    self.lastAudioKey = nil
    self:PlayConfiguredAudio(self.focusedBoss, self.Interrupts.castCount)
end

function Kicker:InterruptOnCastStart(unit)
    if not self.Interrupts or self.Interrupts.disabled then return end
    if self.Interrupts.myTrackedID == 0 then return end
    if not UnitCastingInfo(unit) then return end
    self:DisplayInterrupt(true)
    if self.Interrupts.castCount == self.Interrupts.myKick then
        self:PlayInterruptSound()
    end
end

function Kicker:OnInterrupt(shouldCount)
    if not self.Interrupts or self.Interrupts.disabled then return end
    if self.Interrupts.myTrackedID == 0 then return end
    if shouldCount then
        self.Interrupts.castCount = self.Interrupts.castCount + 1
        if self.Interrupts.castCount > self.Interrupts.max then
            self.Interrupts.castCount = 1
        end
    end
    self:DisplayInterrupt()
end

function Kicker:OnFocusEvent(event, unit)
    if not self.trackingEnabled then return end
    if event == "PLAYER_FOCUS_CHANGED" then
        self.focusedBoss = self:GetFocusedBossUnit()
        self:ResetInterrupts()
        if self.focusedBoss then
            self.Interrupts.castCount = self.bossCounts[self.focusedBoss]
            self:DisplayInterrupt()
        end
        self:UpdateNameplateDisplay()
    elseif event == "UNIT_SPELLCAST_START" and unit == "focus" then
        if self.focusedBoss and UnitLevel(unit) == INTERRUPT_ADD_LEVEL then
            self.castStarts[self.focusedBoss] = GetTime()
            self:InterruptOnCastStart(unit)
            self:UpdateNameplateDisplay()
        end
    elseif event == "UNIT_SPELLCAST_STOP" and unit == "focus" and self.focusedBoss then
        self.castStarts[self.focusedBoss] = nil
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" and unit == "focus" and self.focusedBoss
        and self:ConsumeInterruptCastStart(self.focusedBoss) then
        self:OnInterrupt(true)
        self.bossCounts[self.focusedBoss] = self.Interrupts.castCount
        self:UpdateNameplateDisplay()
    end
end

function Kicker:RegisterSpellcastEvents()
    if not self.spellcastFrame then
        self.spellcastFrame = CreateFrame("Frame")
        self.spellcastFrame:SetScript("OnEvent", function(_, event, unit)
            self:OnFocusEvent(event, unit)
        end)
    end
    if not self.bossSpellcastFrame then
        self.bossSpellcastFrame = CreateFrame("Frame")
        self.bossSpellcastFrame:SetScript("OnEvent", function(_, event, unit)
            self:OnBossSpellcast(event, unit)
        end)
    end
    self.spellcastFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    for _, event in ipairs(SPELLCAST_EVENTS) do
        self.spellcastFrame:RegisterUnitEvent(event, "focus")
        self.bossSpellcastFrame:RegisterUnitEvent(event, unpack(BOSS_UNITS))
    end
end

function Kicker:StopEncounter()
    self.encounterActive = false
    self.trackingEnabled = false
    self.focusedBoss = nil
    self.bossCounts = nil
    self.castStarts = nil
    if self.startTimer then
        self.startTimer:Cancel()
        self.startTimer = nil
    end
    if self.spellcastFrame then self.spellcastFrame:UnregisterAllEvents() end
    if self.bossSpellcastFrame then self.bossSpellcastFrame:UnregisterAllEvents() end
    if self.Interrupts then self:ResetInterrupts() end
    if self.nameplateBox then self.nameplateBox:Hide() end
end

function Kicker:OnEncounterStart(_, encounterID, _, difficultyID)
    self:StopEncounter()
    self.editMode = false
    if encounterID ~= ENCOUNTER_ID or difficultyID ~= 16 then return end
    self.encounterActive = true
    self:ParseAssignments()
    self:ResetInterrupts()
    self.bossCounts = {boss2 = 1, boss3 = 1, boss4 = 1, boss5 = 1}
    self.castStarts = {}
    self.focusedBoss = nil
    self.trackingEnabled = false
    self:RegisterSpellcastEvents()
    self.startTimer = C_Timer.NewTimer(TRACKING_START, function()
        self.startTimer = nil
        if not self.encounterActive then return end
        self.bossCounts = {boss2 = 1, boss3 = 1, boss4 = 1, boss5 = 1}
        self.castStarts = {}
        self.trackingEnabled = true
        self:ResetInterrupts()
        self.focusedBoss = self:GetFocusedBossUnit()
        if self.nameplateBox then self.nameplateBox:Hide() end
    end)
    self:UpdateNameplateDisplay()
end

function Kicker:OnEncounterEnd(_, encounterID)
    if encounterID == ENCOUNTER_ID then self:StopEncounter() end
end

function Kicker:SetEditMode(value)
    self.editMode = value and true or false
    self:ApplySettings()
    self:UpdateDisplay()
end

function Kicker:Refresh()
    self:ApplySettings()
    self:UpdateDisplay()
end

function Kicker:OnInitialize()
    self:ApplySettings()
    self:HideDisplays()
end

function Kicker:OnEnable()
    self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
    self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Refresh")
    self:Refresh()
end

function Kicker:OnDisable()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    self.editMode = false
    self:StopEncounter()
end

E:RegisterBossModFeature("UlatekKicker", {
    tab = "VenomousAbyss", order = 75,
    bossKey = "Ulatek", bossLabelKey = "BossMods_Ulatek", bossOrder = 80,
    labelKey = "BossMods_UlatekKicker", navLabelKey = "BossMods_UlatekKickerNav",
    descKey = "BossMods_UlatekKickerDesc", moduleName = MODULE_NAME
})
