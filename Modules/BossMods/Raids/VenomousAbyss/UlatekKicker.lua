local E = unpack(ART)
local BossMods = E:GetModule("BossMods")
local MODULE_NAME = "BossMods_UlatekKicker"
local ENCOUNTER_ID = 3492
local TRACKING_START = 240
local BOSS_UNITS = {"boss2", "boss3", "boss4", "boss5"}
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
    self.noteContext = Ready:BuildContext()
    self.assignment = nil
    self.myKick = nil
    for groupIndex = 1, 4 do
        local group = self:ParseGroup(self.noteContext, groupIndex)
        if group then
            for index, token in ipairs(group.players) do
                if Ready:TokenIsPlayer(token, self.noteContext) then
                    self.assignment = group
                    self.myKick = index
                    return
                end
            end
        end
    end
end

function Kicker:GetFocusedBossUnit()
    for _, unit in ipairs(BOSS_UNITS) do
        local matches = UnitIsUnit("focus", unit)
        if issecretvalue(matches) then return nil end
        if matches then return unit end
    end
end

function Kicker:ResetCounters()
    self.bossCounts = {boss2 = 1, boss3 = 1, boss4 = 1, boss5 = 1}
    self.focusedBoss = nil
    self.casting = false
    self.lastAudioKey = nil
    self.displayReady = false
end

function Kicker:AdvanceCounter(unit)
    if not self.assignment or not self.bossCounts[unit] then return end
    self.bossCounts[unit] = self.bossCounts[unit] % #self.assignment.players + 1
end

function Kicker:HideDisplays()
    if self.frames then
        self.frames.anchor:Hide()
        self.frames.kickBox:Hide()
        self.frames.nextTextAnchor:Hide()
    end
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

function Kicker:UpdateDisplay()
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
        self.nameplateBox:Hide()
        return
    end
    if not self.encounterActive or not self.trackingEnabled
        or not self.assignment or not self.displayReady or not self.focusedBoss
        or self:GetFocusedBossUnit() ~= self.focusedBoss
    then
        self:HideDisplays()
        return
    end

    local count = self.bossCounts[self.focusedBoss]
    local players = self.assignment.players
    local current = count == self.myKick
    local nextKick = count % #players + 1 == self.myKick
    local staticState = current and (self.casting and "now" or "next")
        or (nextKick and "next" or "idle")
    local plateState = current and "now" or (nextKick and "next" or "idle")
    local name, class = self:GetKickDisplayInfo(players[count])
    self:SetBoxState(box, staticState, count, name, nil, class)
    box:Show()
    self:UpdateNextText(staticState == "next")

    local config = self.db.nameplate
    local plate = not config.hide and C_NamePlate.GetNamePlateForUnit("focus")
    if plate then
        Display.AnchorToNameplate(self.nameplateBox, plate,
            config.anchor, config.offsetX, config.offsetY)
        self.nameplateBox:SetScale(plate:GetEffectiveScale() / UIParent:GetEffectiveScale())
        self:SetBoxState(self.nameplateBox, plateState, count, name, nil, class)
        self.nameplateBox:Show()
    else
        self.nameplateBox:Hide()
    end
end

function Kicker:OnFocusChanged()
    if not self.trackingEnabled then return end
    self.focusedBoss = self:GetFocusedBossUnit()
    self.casting = false
    self.lastAudioKey = nil
    self.displayReady = self.focusedBoss ~= nil
    self:UpdateDisplay()
end

function Kicker:OnSpellcast(event, unit)
    if not self.trackingEnabled or not self.assignment then return end
    if unit == "focus" then
        if not self.focusedBoss then return end
        if event == "UNIT_SPELLCAST_START" then
            if not UnitCastingInfo("focus") then return end
            self.casting = true
            self.displayReady = true
            if self.bossCounts[self.focusedBoss] == self.myKick and self.db.audio.enabled then
                self:PlayConfiguredAudio(self.focusedBoss, self.bossCounts[self.focusedBoss])
            end
        elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
            self:AdvanceCounter(self.focusedBoss)
            self.casting = false
            self.lastAudioKey = nil
            self.displayReady = true
        else
            return
        end
        self:UpdateDisplay()
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" and unit ~= self.focusedBoss then
        self:AdvanceCounter(unit)
    end
end

function Kicker:RegisterSpellcastEvents()
    for _, key in ipairs({"spellcastFrame", "bossSpellcastFrame"}) do
        if not self[key] then
            self[key] = CreateFrame("Frame")
            self[key]:SetScript("OnEvent", function(_, event, unit)
                self:OnSpellcast(event, unit)
            end)
        end
    end
    self.spellcastFrame:RegisterUnitEvent("UNIT_SPELLCAST_START", "focus")
    self.spellcastFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "focus")
    self.bossSpellcastFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", unpack(BOSS_UNITS))
end

function Kicker:StopEncounter()
    self.encounterActive = false
    self.trackingEnabled = false
    if self.startTimer then
        self.startTimer:Cancel()
        self.startTimer = nil
    end
    if self.spellcastFrame then self.spellcastFrame:UnregisterAllEvents() end
    if self.bossSpellcastFrame then self.bossSpellcastFrame:UnregisterAllEvents() end
    self:ResetCounters()
    self:HideDisplays()
end

function Kicker:OnEncounterStart(_, encounterID, _, difficultyID)
    self:StopEncounter()
    self.editMode = false
    if encounterID ~= ENCOUNTER_ID or difficultyID ~= 16 then return end
    self:ParseAssignments()
    if not self.assignment then return end
    self.encounterActive = true
    self:RegisterSpellcastEvents()
    self.startTimer = C_Timer.NewTimer(TRACKING_START, function()
        self.startTimer = nil
        if not self.encounterActive then return end
        self:ResetCounters()
        self.trackingEnabled = true
        self.focusedBoss = self:GetFocusedBossUnit()
        self:HideDisplays()
    end)
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
    self:ResetCounters()
    self:ApplySettings()
    self:HideDisplays()
end

function Kicker:OnEnable()
    self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
    self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
    self:RegisterEvent("PLAYER_FOCUS_CHANGED", "OnFocusChanged")
    self:RegisterEvent("NAME_PLATE_UNIT_ADDED", "UpdateDisplay")
    self:RegisterEvent("NAME_PLATE_UNIT_REMOVED", "UpdateDisplay")
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
