local E, L = unpack(ART)
local CreateFrame, C_Timer, hooksecurefunc = E:DiagnosticBindings("Modules/BossMods/Raids/VenomousAbyss/CoiledAltarKicker")
local BossMods = E:GetModule("BossMods")
local Display = BossMods.KickDisplay

E:RegisterModuleDefaults("BossMods_CoiledAltarKicker", CopyTable(Display.defaults))

local ENCOUNTER_ID = 3429
local BIGWIGS_MODULE_NAME = "The Coiled Altar"
local INTERMISSION_PHASE = 2.5
local PHASE_THREE = 3
local INTERRUPT_ADD_LEVEL = 92
local INTERRUPT_UNIT = "boss3"
local BOX_COLORS = Display.colors
local PREVIEW_COLORS = Display.previewColors
local createKickBox = Display.CreateBox
local anchorFrameToNameplate = Display.AnchorToNameplate

local CoiledAltarKicker = E:NewModule("BossMods_CoiledAltarKicker", "AceEvent-3.0")
Display:Install(CoiledAltarKicker)

function CoiledAltarKicker:GetAssignment(count)
    local group = self.assignments
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

function CoiledAltarKicker:GetAssignmentState(count)
    local current, nextPlayer = self:GetAssignment(count)
    if current and self:IsPlayerToken(current) then
        return "now"
    end
    if nextPlayer and self:IsPlayerToken(nextPlayer) then
        return "next"
    end
    return "idle"
end

function CoiledAltarKicker:IsPlayerAssigned()
    for _, token in ipairs(self.assignments or {}) do
        if self:IsPlayerToken(token) then
            return true
        end
    end
    return false
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

function CoiledAltarKicker:AnchorKickBox()
    local target = not self.editMode and self.interruptUnitAvailable
        and self:ResolveAnchorFrame(INTERRUPT_UNIT) or nil

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

function CoiledAltarKicker:HideNameplateDisplays()
    for _, display in pairs(self.nameplateDisplays or {}) do
        for _, box in ipairs(display.boxes or {}) do
            box:Hide()
        end
    end
end

function CoiledAltarKicker:ResetKickCounters()
    self.castCount = 1
    self.casting = false
    self.lastAudioKey = nil
end

function CoiledAltarKicker:ResetInterruptDisplay()
    self:HideNameplateDisplays()
    self:ResetKickCounters()
    self.interruptActive = false
    self.interruptUnitAvailable = false
    for _, display in pairs(self.nameplateDisplays or {}) do
        display.plate = nil
    end
end

function CoiledAltarKicker:RefreshInterruptUnit()
    self.interruptUnitAvailable = self.interruptActive
        and UnitExists(INTERRUPT_UNIT)
        and UnitIsEnemy(INTERRUPT_UNIT, "player")
    if not self.interruptUnitAvailable then
        self:ResetKickCounters()
    end
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
        local box = createKickBox(self.frames.nameplateRoot)
        box:SetFrameLevel(95)
        display.boxes[1] = box
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
        and self.interruptUnitAvailable
        and self.assignments
        and #self.assignments > 0
        and (self.db.nameplate.showAll or self:IsPlayerAssigned())
    if not active then
        self:HideNameplateDisplays()
        return
    end

    local boxSize = self.db.nameplate.size or 30
    local fontScale = boxSize / 30
    local numberFontSize = (self.db.nameplate.numberFontSize or 12) * fontScale
    local nameFontSize = (self.db.nameplate.nameFontSize or 12) * fontScale
    local castCount = self.castCount or 1
    local currentToken = self:GetAssignment(castCount)
    local state = self:GetAssignmentState(castCount)
    local displayName, classFile = self:GetKickDisplayInfo(currentToken)

    for _, display in pairs(self.nameplateDisplays or {}) do
        if display.plate then
            local box = display.boxes[1]
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
            box:SetAlpha(1)
            box:Show()
        end
    end
end

function CoiledAltarKicker:UpdatePreviewDisplay()
    self.frames.anchor:SetShown(self.editMode)

    local state = self.editMode and "now"
        or self:GetAssignmentState(self.castCount)
    local showBox = self.editMode
        or (
            self.interruptActive
            and self.interruptUnitAvailable
            and state ~= "idle"
        )

    if showBox then
        local count = self.editMode and 1 or self.castCount or 1
        local currentToken = self:GetAssignment(count)
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
        self:AnchorKickBox()
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
    if self.editMode or not self.interruptActive
        or not self.interruptUnitAvailable or unit ~= INTERRUPT_UNIT
    then
        return
    end

    local count = self.castCount or 1
    local currentToken = self:GetAssignment(count)
    if currentToken and self:IsPlayerToken(currentToken) then
        self:PlayConfiguredAudio(1, count)
    end
end

function CoiledAltarKicker:ParseHashAssignments(ctx)
    local Ready = BossMods and BossMods.ReadyAssignments
    if not Ready or not Ready.Words then
        return false
    end

    local found = false
    local tag = self.currentPhase == PHASE_THREE and "cap3kick" or "cakick"
    local sections = ctx.tags and ctx.tags[tag]
    if sections then
        for _, section in ipairs(sections) do
            local text = section.text or section.headerText or ""
            for _, token in ipairs(Ready:Words(text)) do
                self.assignments[#self.assignments + 1] = token
                found = true
            end
        end
    end
    return found
end

function CoiledAltarKicker:ParseAssignments()
    self.assignments = {}
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
    if not self.interruptActive or unit ~= INTERRUPT_UNIT then
        return
    end
    -- The opening cast can arrive before the engage event.
    self:RefreshInterruptUnit()
    if self.interruptUnitAvailable then
        self.casting = true
        self:UpdateDisplay()
        self:PlayPersonalAudioForUnit(unit)
    end
end

function CoiledAltarKicker:HandleCastInterrupted(unit)
    self:HandleCastStop(unit)
end

function CoiledAltarKicker:HandleCastStop(unit)
    if not self.interruptActive or unit ~= INTERRUPT_UNIT then
        return
    end
    self:RefreshInterruptUnit()
    if self.casting then
        self.casting = false
        self.castCount = (self.castCount or 1) + 1
        self.lastAudioKey = nil
    end
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
        INTERRUPT_UNIT
    )
    self.spellcastFrame:RegisterUnitEvent(
        "UNIT_SPELLCAST_INTERRUPTED",
        INTERRUPT_UNIT
    )
    self.spellcastFrame:RegisterUnitEvent(
        "UNIT_SPELLCAST_STOP",
        INTERRUPT_UNIT
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
    self:RefreshInterruptUnit()
    self:UpdateDisplay()
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
    self:RegisterSpellcastEvents()
    self:RefreshNameplateUnits()
    self:INSTANCE_ENCOUNTER_ENGAGE_UNIT()
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
        self.assignments = {
            UnitName("player") or L["Player"],
            "Next"
        }
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
    self.assignments = {}
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
