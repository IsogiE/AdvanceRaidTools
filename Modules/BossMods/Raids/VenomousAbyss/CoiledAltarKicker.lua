local E, L = unpack(ART)
local BossMods = E:GetModule("BossMods")
local Display = BossMods.KickDisplay

E:RegisterModuleDefaults("BossMods_CoiledAltarKicker", CopyTable(Display.defaults))

local ENCOUNTER_ID = 3429
local BIGWIGS_MODULE_NAME = "The Coiled Altar"
local INTERMISSION_PHASE = 2.5
local PHASE_THREE = 3
local INTERRUPT_ADD_LEVEL = 92
local LINE_COUNT = 2
local UNMARKED_LINE = 1
local MARKED_LINE = 2
local BOX_COLORS = Display.colors
local PREVIEW_COLORS = Display.previewColors
local createKickBox = Display.CreateBox
local anchorFrameToNameplate = Display.AnchorToNameplate
local isSecret = _G.issecretvalue or function() return false end

local CoiledAltarKicker = E:NewModule("BossMods_CoiledAltarKicker", "AceEvent-3.0")
Display:Install(CoiledAltarKicker)

local function isInterruptBossUnit(unit)
    return unit == "boss3" or unit == "boss4"
end

function CoiledAltarKicker:GetLineAssignment(line, count)
    local group = self.assignments and self.assignments[line]
    if not group or #group == 0 then
        return nil, nil
    end
    count = math.max(tonumber(count) or 1, 1)
    local currentIndex = ((count - 1) % #group) + 1
    local nextIndex = (count % #group) + 1
    return group[currentIndex], group[nextIndex]
end

function CoiledAltarKicker:IsPlayerToken(token)
    local Ready = BossMods and BossMods.ReadyAssignments
    if Ready and Ready.TokenIsPlayer then
        return Ready:TokenIsPlayer(token, self.noteContext)
    end
    local NoteBlock = BossMods and BossMods.NoteBlock
    if NoteBlock and NoteBlock.IsPlayerToken then
        return NoteBlock:IsPlayerToken(token)
    end
    return false
end

function CoiledAltarKicker:GetLineState(line, count)
    local current = self:GetLineAssignment(line, count)
    local _, nextPlayer = self:GetLineAssignment(line, count)
    if current and self:IsPlayerToken(current) then
        return "now"
    end
    if nextPlayer and self:IsPlayerToken(nextPlayer) then
        return "next"
    end
    return "idle"
end

function CoiledAltarKicker:GetAssignedLine()
    for line = 1, LINE_COUNT do
        local group = self.assignments and self.assignments[line]
        if group then
            for _, token in ipairs(group) do
                if self:IsPlayerToken(token) then
                    return line
                end
            end
        end
    end
    return nil
end

function CoiledAltarKicker:HasLineAssignments(line)
    local group = self.assignments and self.assignments[line]
    return group and #group > 0
end

function CoiledAltarKicker:FindPersonalLine()
    local bestLine
    local bestState
    local bestUnit
    for line = 1, LINE_COUNT do
        local state = self:GetLineState(line, self.castCounts[line])
        local unit = state ~= "idle" and self:GetUnitForLine(line) or nil
        if state == "now" then
            return line, state, unit
        elseif state == "next" and not bestLine then
            bestLine = line
            bestState = state
            bestUnit = unit
        end
    end
    return bestLine, bestState, bestUnit
end

function CoiledAltarKicker:GetUnitForLine(line)
    for _, unit in ipairs({"boss3", "boss4"}) do
        if UnitExists(unit) and UnitIsEnemy(unit, "player") then
            local raidMarker = GetRaidTargetIndex(unit)
            local hasRaidMarker = isSecret(raidMarker)
            if line == MARKED_LINE and hasRaidMarker then
                return unit
            elseif line == UNMARKED_LINE and not hasRaidMarker then
                return unit
            end
        end
    end
    return nil
end

function CoiledAltarKicker:GetOtherBossUnit(unit)
    if unit == "boss3" then
        return "boss4"
    elseif unit == "boss4" then
        return "boss3"
    end
    return nil
end

function CoiledAltarKicker:GetCounterUnitForLine(line)
    if self.assignedBossUnit then
        if line == MARKED_LINE then
            return self.assignedBossUnit
        end
        return self:GetOtherBossUnit(self.assignedBossUnit)
    end

    return line == MARKED_LINE and "boss4" or "boss3"
end

function CoiledAltarKicker:GetLineForBossUnit(unit)
    if not isInterruptBossUnit(unit) then
        return nil
    end
    if not UnitExists(unit) then
        return nil
    end

    if self.assignedBossUnit then
        return unit == self.assignedBossUnit and MARKED_LINE or UNMARKED_LINE
    end

    local raidMarker = GetRaidTargetIndex(unit)
    return isSecret(raidMarker) and MARKED_LINE or UNMARKED_LINE
end

function CoiledAltarKicker:ResolveAnchorFrame(unit)
    if BossMods
        and BossMods.Alerts
        and BossMods.Alerts.ResolveFrame
    then
        return BossMods.Alerts:ResolveFrame(unit)
    end
    return nil
end

function CoiledAltarKicker:AnchorKickBox(line, unit)
    local target
    unit = unit or self:GetUnitForLine(line)
    target = unit and self:ResolveAnchorFrame(unit) or nil

    local frame = self.frames.kickBox
    frame:ClearAllPoints()
    if target then
        frame:SetPoint(
            "RIGHT",
            target,
            "LEFT",
            self.db.box.offsetX or -8,
            self.db.box.offsetY or 0
        )
    else
        frame:SetPoint("CENTER", self.frames.anchor, "CENTER", 0, 0)
    end
end

function CoiledAltarKicker:SyncCastCounts()
    self.castCountsByUnit = self.castCountsByUnit
        or {boss3 = 1, boss4 = 1}
    local unmarkedUnit = self:GetCounterUnitForLine(UNMARKED_LINE)
    local markedUnit = self:GetCounterUnitForLine(MARKED_LINE)
    self.castCounts[UNMARKED_LINE] =
        self.castCountsByUnit[unmarkedUnit or "boss3"] or 1
    self.castCounts[MARKED_LINE] =
        self.castCountsByUnit[markedUnit or "boss4"] or 1
end

function CoiledAltarKicker:IsInterruptUnit(unit)
    return isInterruptBossUnit(unit)
end

function CoiledAltarKicker:HideNameplateDisplays()
    for _, display in pairs(self.nameplateDisplays or {}) do
        for _, box in ipairs(display.boxes or {}) do
            box:Hide()
        end
    end
end

function CoiledAltarKicker:ResetKickCounters()
    self:HideNameplateDisplays()
    self.assignedBossUnit = nil
    self.castCountsByUnit = {boss3 = 1, boss4 = 1}
    self.castCounts = {[1] = 1, [2] = 1}
    self.castingUnits = {}
    self.lastAudioKey = nil
    for _, display in pairs(self.nameplateDisplays or {}) do
        display.plate = nil
    end
end

function CoiledAltarKicker:ResetInterruptDisplay()
    self:ResetKickCounters()
    self.interruptActive = false
    self.boss3Available = false
end

function CoiledAltarKicker:UpdateAssignedBoss()
    local assignedBoss = self.assignedBossUnit
    local migratedBoss
    if assignedBoss == "boss4" and not UnitExists("boss4") and UnitExists("boss3") then
        migratedBoss = "boss3"
    elseif assignedBoss == "boss3" and not UnitExists("boss3") and UnitExists("boss4") then
        migratedBoss = "boss4"
    end

    if migratedBoss then
        local counts = self.castCountsByUnit or {}
        counts[migratedBoss] = math.max(
            counts[migratedBoss] or 1,
            counts[assignedBoss] or 1
        )
        self.castCountsByUnit = counts
        if self.castingUnits and self.castingUnits[assignedBoss] then
            self.castingUnits[migratedBoss] = true
        end
        if self.castingUnits then
            self.castingUnits[assignedBoss] = nil
        end
        self.assignedBossUnit = migratedBoss
    end

    if self.assignedBossUnit or not self.interruptActive then
        self:SyncCastCounts()
        self:UpdateDisplay()
        return
    end

    local boss3Marker = GetRaidTargetIndex("boss3")
    local boss4Marker = GetRaidTargetIndex("boss4")
    if isSecret(boss3Marker) then
        self.assignedBossUnit = "boss3"
    elseif isSecret(boss4Marker) then
        self.assignedBossUnit = "boss4"
    end
    self:SyncCastCounts()
    self:UpdateDisplay()
end

function CoiledAltarKicker:AddNameplateUnit(unit)
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    self.nameplateDisplays = self.nameplateDisplays or {}

    if not plate or UnitLevel(unit) ~= INTERRUPT_ADD_LEVEL then
        local oldDisplay = self.nameplateDisplays[unit]
        if oldDisplay then
            for _, box in ipairs(oldDisplay.boxes or {}) do
                box:Hide()
            end
            oldDisplay.plate = nil
        end
        return
    end

    local display = self.nameplateDisplays[unit]
    if not display then
        display = {
            plate = plate,
            boxes = {}
        }
        self.nameplateDisplays[unit] = display
        for boxIndex = 1, LINE_COUNT do
            local box = createKickBox(self.frames.nameplateRoot)
            box:SetFrameLevel(95)
            display.boxes[boxIndex] = box
        end
    elseif display.plate ~= plate then
        display.plate = plate
    end

    self:UpdateDisplay()
end

function CoiledAltarKicker:RefreshNameplateUnits()
    local activeUnits = {}
    if C_NamePlate and C_NamePlate.GetNamePlates then
        for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
            local unit = plate.namePlateUnitToken
            if unit then
                activeUnits[unit] = true
                self:AddNameplateUnit(unit)
            end
        end
    end

    for unit, display in pairs(self.nameplateDisplays or {}) do
        if not activeUnits[unit] then
            for _, box in ipairs(display.boxes or {}) do
                box:Hide()
            end
            display.plate = nil
        end
    end
end

function CoiledAltarKicker:RemoveNameplateUnit(unit)
    local display = self.nameplateDisplays and self.nameplateDisplays[unit]
    if not display then
        return
    end
    for _, box in ipairs(display.boxes or {}) do
        box:Hide()
    end
    display.plate = nil
end

function CoiledAltarKicker:UpdateNameplateDisplays()
    local active = self.interruptActive
        and self.boss3Available ~= false
        and self.assignments
        and self.assignments[UNMARKED_LINE]
        and self.assignments[MARKED_LINE]
    if not active then
        self:HideNameplateDisplays()
        return
    end

    local boxSize = self.db.nameplate.size or 30
    local fontScale = boxSize / 30
    local numberFontSize = (self.db.nameplate.numberFontSize or 12) * fontScale
    local nameFontSize = (self.db.nameplate.nameFontSize or 12) * fontScale
    local assignedLine = self:GetAssignedLine()

    for unit, display in pairs(self.nameplateDisplays or {}) do
        if display.plate then
            local raidMarker = GetRaidTargetIndex(unit)
            local hasRaidMarker = isSecret(raidMarker)

            for _, box in ipairs(display.boxes or {}) do
                box:SetAlpha(0)
                box:Hide()
            end

            for boxIndex, box in ipairs(display.boxes or {}) do
                local displayLine = boxIndex == MARKED_LINE and MARKED_LINE
                    or UNMARKED_LINE
                local lineNames = self.assignments[displayLine] or {}
                local countUnit = self:GetCounterUnitForLine(displayLine)
                local castCount = self.castCountsByUnit[countUnit] or 1
                local currentToken = #lineNames > 0
                    and lineNames[((castCount - 1) % #lineNames) + 1]
                    or nil
                local nextToken = #lineNames > 0
                    and lineNames[(castCount % #lineNames) + 1]
                    or nil
                local state = "idle"
                if currentToken and self:IsPlayerToken(currentToken) then
                    state = "now"
                elseif nextToken and self:IsPlayerToken(nextToken) then
                    state = "next"
                end
                local displayName, classFile =
                    self:GetKickDisplayInfo(currentToken)

                self:ApplyBoxAppearance(
                    box,
                    boxSize,
                    numberFontSize,
                    nameFontSize
                )
                self:SetBoxState(
                    box,
                    state,
                    castCount,
                    displayName,
                    BOX_COLORS,
                    classFile
                )
                anchorFrameToNameplate(
                    box,
                    display.plate,
                    self.db.nameplate.anchor,
                    self.db.nameplate.offsetX,
                    self.db.nameplate.offsetY
                )

                local boxVisible =
                    (self.db.nameplate.showAll or assignedLine == displayLine)
                        and ((boxIndex == MARKED_LINE) == hasRaidMarker)
                if boxVisible then
                    box:SetAlpha(1)
                    box:Show()
                end
            end
        end
    end
end

function CoiledAltarKicker:UpdatePreviewDisplay()
    self.frames.anchor:SetShown(self.editMode)

    local line
    local state
    local unit
    if self.editMode then
        line = UNMARKED_LINE
        state = "now"
    elseif self.interruptActive then
        line, state, unit = self:FindPersonalLine()
    end

    local showBox = line
        and (
            self.editMode
            or (
                self.interruptActive
                and self.boss3Available ~= false
                and state ~= "idle"
                and self:HasLineAssignments(line)
            )
        )

    if showBox then
        local count = self.castCounts[line] or 1
        local currentToken = self:GetLineAssignment(line, count)
        local displayName, classFile = self:GetKickDisplayInfo(currentToken)

        if self.editMode then
            currentToken = UnitName("player") or L["Player"]
            displayName, classFile = self:GetKickDisplayInfo(currentToken)
            if not classFile then
                _, classFile = UnitClass("player")
            end
        end

        self:ApplyBoxAppearance(
            self.frames.kickBox,
            self.db.box.size,
            self.db.font.size
        )
        self:SetBoxState(
            self.frames.kickBox,
            state,
            count,
            displayName,
            self.editMode and PREVIEW_COLORS or BOX_COLORS,
            classFile
        )
        self:AnchorKickBox(line, unit)
        self.frames.kickBox:Show()
    else
        self.frames.kickBox:Hide()
    end

    self:UpdateNextText(showBox and state == "next")
end

function CoiledAltarKicker:UpdateDisplay()
    self:EnsureFrames()
    self:EnsureDefaults()
    self:ApplyAppearance()
    self:UpdatePreviewDisplay()
    self:UpdateNameplateDisplays()
end

function CoiledAltarKicker:PlayPersonalAudioForUnit(unit)
    if self.editMode or not self.interruptActive then
        return
    end

    local line = self:GetLineForBossUnit(unit)
    if not line then
        return
    end

    local count = self.castCountsByUnit[unit] or 1
    local currentToken = self:GetLineAssignment(line, count)
    if currentToken and self:IsPlayerToken(currentToken) then
        self:PlayConfiguredAudio(line, count)
    end
end

function CoiledAltarKicker:ParseHashAssignments(ctx)
    local Ready = BossMods and BossMods.ReadyAssignments
    if not Ready or not Ready.Words then
        return false
    end

    local found = false
    local tagPrefix = self.currentPhase == PHASE_THREE and "cap3kick" or "cakick"
    for line = 1, LINE_COUNT do
        local tag = tagPrefix .. line
        local sections = ctx.tags and ctx.tags[tag]
        if sections then
            for _, section in ipairs(sections) do
                local text = section.text or section.headerText or ""
                for _, token in ipairs(Ready:Words(text)) do
                    self.assignments[line][#self.assignments[line] + 1] =
                        token
                    found = true
                end
            end
        end
    end
    return found
end

function CoiledAltarKicker:ParseAssignments()
    self.assignments = {{}, {}}
    BossMods = BossMods or E:GetModule("BossMods")
    local Ready = BossMods and BossMods.ReadyAssignments
    local NoteBlock = BossMods and BossMods.NoteBlock
    local noteText = Ready and Ready.GetMainNoteText
        and Ready:GetMainNoteText()
        or (NoteBlock and NoteBlock:GetMainNoteText())
        or ""
    local sections
    local tags
    if Ready and Ready.ParseHashSections then
        sections, tags = Ready:ParseHashSections(noteText)
    end
    self.noteContext = {
        noteText = noteText,
        hashSections = sections or {},
        tags = tags or {},
        ids = NoteBlock
            and NoteBlock.GetPlayerIdentifiers
            and NoteBlock:GetPlayerIdentifiers()
            or nil
    }

    self:ParseHashAssignments(self.noteContext)
end

function CoiledAltarKicker:OnBigWigsStage(module, stage)
    if not self.encounterActive
        or not module
        or module.moduleName ~= BIGWIGS_MODULE_NAME
    then
        return
    end

    local phase = tonumber(stage)
    if not phase or phase == self.currentPhase then
        return
    end

    self.currentPhase = phase
    if not self.interruptActive or phase == INTERMISSION_PHASE then
        return
    end

    self:ParseAssignments()
    self:ResetKickCounters()
    self:RefreshNameplateUnits()
    self:INSTANCE_ENCOUNTER_ENGAGE_UNIT()
end

function CoiledAltarKicker:HookBigWigs()
    if self.bigWigsSubscription or not BossMods or not BossMods.BigWigs then
        return
    end

    self.bigWigsSubscription = BossMods.BigWigs:Subscribe({
        owner = "CoiledAltarKicker",
        onStage = function(module, stage)
            self:OnBigWigsStage(module, stage)
        end
    })
end

function CoiledAltarKicker:UnhookBigWigs()
    if self.bigWigsSubscription then
        self.bigWigsSubscription:Unsubscribe()
        self.bigWigsSubscription = nil
    end
end

function CoiledAltarKicker:HandleCastStart(unit)
    self:UpdateAssignedBoss()
    if self.interruptActive
        and self:IsInterruptUnit(unit)
        and UnitIsEnemy(unit, "player")
    then
        self.castingUnits[unit] = true
        self:UpdateDisplay()
        self:PlayPersonalAudioForUnit(unit)
    end
end

function CoiledAltarKicker:HandleCastInterrupted(unit)
    self:UpdateAssignedBoss()
    if self.interruptActive
        and self:IsInterruptUnit(unit)
        and self.castingUnits[unit]
    then
        self.castingUnits[unit] = nil
        self.castCountsByUnit[unit] = (self.castCountsByUnit[unit] or 1) + 1
        self:SyncCastCounts()
    end
    self.lastAudioKey = nil
    self:UpdateDisplay()
end

function CoiledAltarKicker:HandleCastStop(unit)
    self:UpdateAssignedBoss()
    if self.interruptActive
        and self:IsInterruptUnit(unit)
        and self.castingUnits[unit]
    then
        self.castingUnits[unit] = nil
        self.castCountsByUnit[unit] = (self.castCountsByUnit[unit] or 1) + 1
        self:SyncCastCounts()
    end
    self.lastAudioKey = nil
    self:UpdateDisplay()
end

function CoiledAltarKicker:EnsureSpellcastFrame()
    if self.spellcastFrame then
        return
    end

    self.spellcastFrame = CreateFrame("Frame")
    self.spellcastFrame:SetScript("OnEvent", function(_, event, unit)
        if event == "UNIT_SPELLCAST_START" then
            self:HandleCastStart(unit)
        elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
            self:HandleCastInterrupted(unit)
        elseif event == "UNIT_SPELLCAST_STOP" then
            self:HandleCastStop(unit)
        end
    end)
end

function CoiledAltarKicker:RegisterSpellcastEvents()
    self:EnsureSpellcastFrame()
    self.spellcastFrame:RegisterUnitEvent(
        "UNIT_SPELLCAST_START",
        "boss3",
        "boss4"
    )
    self.spellcastFrame:RegisterUnitEvent(
        "UNIT_SPELLCAST_INTERRUPTED",
        "boss3",
        "boss4"
    )
    self.spellcastFrame:RegisterUnitEvent(
        "UNIT_SPELLCAST_STOP",
        "boss3",
        "boss4"
    )
end

function CoiledAltarKicker:UnregisterSpellcastEvents()
    if self.spellcastFrame then
        self.spellcastFrame:UnregisterAllEvents()
    end
end

function CoiledAltarKicker:OnUnitDisplayUpdate()
    self:UpdateDisplay()
end

function CoiledAltarKicker:NAME_PLATE_UNIT_ADDED(_, unit)
    if not self.interruptActive then
        return
    end
    self:AddNameplateUnit(unit)
end

function CoiledAltarKicker:NAME_PLATE_UNIT_REMOVED(_, unit)
    if not self.interruptActive then
        return
    end
    self:RemoveNameplateUnit(unit)
    self:UpdateDisplay()
end

function CoiledAltarKicker:INSTANCE_ENCOUNTER_ENGAGE_UNIT()
    local boss3Exists = UnitExists("boss3")
    if not boss3Exists then
        self.boss3Available = false
        self.assignedBossUnit = nil
        self.castCountsByUnit = {boss3 = 1, boss4 = 1}
        self.castingUnits = {}
        self:SyncCastCounts()
        self:UpdateDisplay()
        return
    end

    self.boss3Available = true
    self:UpdateAssignedBoss()
end

function CoiledAltarKicker:OnEncounterStart(_, encounterID)
    if tonumber(encounterID) ~= ENCOUNTER_ID then
        return
    end

    self.encounterActive = true
    self.currentPhase = 1
    self:ParseAssignments()
    self:ResetInterruptDisplay()
    self.interruptActive = true
    self.boss3Available = false
    self:RegisterSpellcastEvents()
    self:RefreshNameplateUnits()
    self:UpdateAssignedBoss()
end

function CoiledAltarKicker:OnEncounterEnd(_, encounterID)
    if tonumber(encounterID) ~= ENCOUNTER_ID then
        return
    end

    self:UnregisterSpellcastEvents()
    self:ResetInterruptDisplay()
    self.encounterActive = false
    self.currentPhase = 1
    self:UpdateDisplay()
end

function CoiledAltarKicker:SetEditMode(value)
    self.editMode = value and true or false
    if self.editMode then
        self.assignments = {{
            UnitName("player") or L["Player"],
            "Next"
        }, {}}
    else
        self:ParseAssignments()
    end
    self:UpdateDisplay()
end

function CoiledAltarKicker:Refresh()
    if not self:IsEnabled() then
        return
    end
    self:EnsureDefaults()
    self:ApplyAppearance()
    self:ApplyPositions()
    self:UpdateDisplay()
end

function CoiledAltarKicker:OnInitialize()
    BossMods = E:GetModule("BossMods")
    self.encounterActive = false
    self.currentPhase = 1
    self.editMode = false
    self.nameplateDisplays = {}
    self.assignments = {{}, {}}
    self:ResetInterruptDisplay()
    self:EnsureFrames()
    self:ParseAssignments()
    self:UpdateDisplay()
end

function CoiledAltarKicker:OnEnable()
    BossMods = BossMods or E:GetModule("BossMods")
    self:EnsureFrames()
    self:Refresh()
    self:HookBigWigs()
    self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
    self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
    self:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
    self:RegisterEvent("RAID_TARGET_UPDATE", "UpdateAssignedBoss")
    self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    self:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    self:RegisterEvent("PLAYER_FOCUS_CHANGED", "OnUnitDisplayUpdate")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Refresh")
end

function CoiledAltarKicker:OnDisable()
    self:UnhookBigWigs()
    self:UnregisterSpellcastEvents()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    self:ResetInterruptDisplay()
    if self.frames then
        self.frames.anchor:Hide()
        self.frames.nextTextAnchor:Hide()
        self.frames.kickBox:Hide()
    end
end

E:RegisterBossModFeature("CoiledAltarKicker", {
    tab = "VenomousAbyss",
    order = 85,
    bossKey = "CoiledAltar",
    bossLabelKey = "BossMods_CoiledAltar",
    bossOrder = 70,
    labelKey = "BossMods_CoiledAltarKicker",
    navLabelKey = "BossMods_CoiledAltarKickerNav",
    descKey = "BossMods_CoiledAltarKickerDesc",
    moduleName = "BossMods_CoiledAltarKicker"
})
