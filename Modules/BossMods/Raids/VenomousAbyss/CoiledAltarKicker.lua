local E, L = unpack(ART)

E:RegisterModuleDefaults("BossMods_CoiledAltarKicker", {
    enabled = true,
    position = {
        point = "CENTER",
        x = 0,
        y = 160
    },
    nextTextPosition = {
        point = "CENTER",
        x = 0,
        y = 215
    },
    box = {
        size = 62,
        opacity = 0.88,
        offsetX = -8,
        offsetY = 0,
        gap = 8
    },
    font = {
        name = "Friz Quadrata TT",
        size = 18,
        outline = "OUTLINE",
        color = {1, 1, 1, 1}
    },
    nextText = {
        enabled = true,
        name = "Friz Quadrata TT",
        size = 28,
        outline = "OUTLINE",
        color = {1, 0.82, 0.08, 1}
    },
    audio = {
        enabled = false,
        mode = "sound",
        sound = "None",
        channel = "Master",
        ttsText = "Kick",
        voiceID = 0
    }
})

local ENCOUNTER_ID = 3429
local MYTHIC_DIFFICULTY_ID = 16
local HEROIC_BOSS_UNITS = {"boss3", "boss4"}
local MYTHIC_BOSS_UNITS = {"boss3", "boss4", "boss5", "boss6"}
local BOX_COLORS = {
    now = {0.05, 0.78, 0.18, 0.95},
    next = {1, 0.82, 0.08, 0.95},
    idle = {0.50, 0.08, 0.08, 0.70}
}

local CoiledAltarKicker = E:NewModule(
    "BossMods_CoiledAltarKicker",
    "AceEvent-3.0"
)
local BossMods

local function isSecret(value)
    return E.IsSecret and E:IsSecret(value) or false
end

local function clamp(value, minimum, maximum, fallback)
    value = tonumber(value)
    if not value then
        value = fallback or minimum
    end
    return math.max(minimum, math.min(maximum, value))
end

local function colorValue(color, fallback)
    color = color or fallback or {1, 1, 1, 1}
    return color[1] or color.r or fallback[1],
        color[2] or color.g or fallback[2],
        color[3] or color.b or fallback[3],
        color[4] or color.a or fallback[4]
end

local function cleanDisplayName(name)
    if E.SafeString then
        name = E:SafeString(name)
    elseif type(name) ~= "string" or isSecret(name) then
        name = nil
    end

    if not name or name == "" then
        return nil
    end

    if E.BareName then
        name = E:BareName(name)
    else
        name = name:match("^([^%-]+)") or name
    end

    return name ~= "" and name or nil
end

local function fitFontString(fs, text, font, size, outline, maxWidth, minSize)
    if not fs then
        return
    end

    text = text or ""
    size = math.max(minSize or 7, tonumber(size) or minSize or 7)
    maxWidth = math.max(1, tonumber(maxWidth) or 1)
    minSize = math.max(1, tonumber(minSize) or 7)

    E:ApplyFontString(fs, font, size, outline)
    fs:SetText(text)

    while size > minSize and fs:GetStringWidth() > maxWidth do
        size = size - 1
        E:ApplyFontString(fs, font, size, outline)
    end

    while text ~= "" and fs:GetStringWidth() > maxWidth do
        text = text:sub(1, -2)
        fs:SetText(text)
    end
end

local function isActiveEnemyUnit(unit)
    if not unit or not UnitExists(unit) then
        return false
    end

    local enemy = UnitIsEnemy(unit, "player")
    if not isSecret(enemy) and not enemy then
        return false
    end

    if UnitIsDeadOrGhost then
        local dead = UnitIsDeadOrGhost(unit)
        if not isSecret(dead) and dead then
            return false
        end
    end

    if UnitHealth then
        local health = UnitHealth(unit)
        if type(health) == "number" and health <= 0 then
            return false
        end
    end

    return true
end

local function isTrackedBossUnit(unit)
    return unit == "boss3"
        or unit == "boss4"
        or unit == "boss5"
        or unit == "boss6"
end

local function bossUnitLine(unit)
    local bossIndex = tonumber(unit and unit:match("^boss(%d+)$"))
    if not bossIndex then
        return nil
    end
    return bossIndex - 2
end

function CoiledAltarKicker:IsActiveBossUnit(unit)
    for _, activeUnit in ipairs(self:GetActiveBossUnits()) do
        if unit == activeUnit then
            return true
        end
    end
    return false
end

function CoiledAltarKicker:EnsureDefaults()
    self.db.position = self.db.position or {point = "CENTER", x = 0, y = 160}
    self.db.position.point = self.db.position.point or "CENTER"
    self.db.position.x = clamp(self.db.position.x, -2000, 2000, 0)
    self.db.position.y = clamp(self.db.position.y, -2000, 2000, 160)

    self.db.nextTextPosition = self.db.nextTextPosition or {
        point = "CENTER",
        x = 0,
        y = 215
    }
    self.db.nextTextPosition.point = self.db.nextTextPosition.point or "CENTER"
    self.db.nextTextPosition.x = clamp(self.db.nextTextPosition.x, -2000, 2000, 0)
    self.db.nextTextPosition.y = clamp(self.db.nextTextPosition.y, -2000, 2000, 215)

    self.db.box = self.db.box or {}
    self.db.box.size = clamp(self.db.box.size, 18, 90, 62)
    self.db.box.opacity = clamp(self.db.box.opacity, 0.05, 1, 0.88)
    self.db.box.offsetX = clamp(self.db.box.offsetX, -200, 200, -8)
    self.db.box.offsetY = clamp(self.db.box.offsetY, -200, 200, 0)
    self.db.box.gap = clamp(self.db.box.gap, 0, 40, 8)

    self.db.font = self.db.font or {}
    self.db.font.name = self.db.font.name or "Friz Quadrata TT"
    self.db.font.size = clamp(self.db.font.size, 8, 36, 18)
    self.db.font.outline = self.db.font.outline or "OUTLINE"
    self.db.font.color = self.db.font.color or {1, 1, 1, 1}

    self.db.nextText = self.db.nextText or {}
    self.db.nextText.enabled = self.db.nextText.enabled ~= false
    self.db.nextText.name = self.db.nextText.name or "Friz Quadrata TT"
    self.db.nextText.size = clamp(self.db.nextText.size, 12, 60, 28)
    self.db.nextText.outline = self.db.nextText.outline or "OUTLINE"
    self.db.nextText.color = self.db.nextText.color or {1, 0.82, 0.08, 1}

    self.db.audio = self.db.audio or {}
    self.db.audio.enabled = self.db.audio.enabled == true
    self.db.audio.mode = self.db.audio.mode == "tts" and "tts" or "sound"
    self.db.audio.sound = self.db.audio.sound or "None"
    self.db.audio.channel = self.db.audio.channel or "Master"
    self.db.audio.ttsText = self.db.audio.ttsText or "Kick"
    self.db.audio.voiceID = tonumber(self.db.audio.voiceID) or 0
end

local function createAnchor(name, width, height)
    local frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    frame:SetSize(width, height)
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(20)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1
    })
    frame:SetBackdropColor(0, 0, 0, 0.25)
    frame:SetBackdropBorderColor(1, 1, 1, 0.40)
    frame:EnableMouse(false)
    frame:Hide()
    return frame
end

function CoiledAltarKicker:GetActiveBossUnits()
    if self:IsMythic() then
        return MYTHIC_BOSS_UNITS
    end
    return HEROIC_BOSS_UNITS
end

function CoiledAltarKicker:IsMythic()
    return tonumber(self.difficultyID) == MYTHIC_DIFFICULTY_ID
end

local function createKickBox(parent, name)
    local frame = CreateFrame("Frame", name, parent, "BackdropTemplate")
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(80)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1
    })
    frame:SetBackdropBorderColor(0, 0, 0, 1)

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    frame.text = text

    local nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetJustifyH("CENTER")
    nameText:SetJustifyV("BOTTOM")
    if nameText.SetWordWrap then
        nameText:SetWordWrap(false)
    end
    frame.nameText = nameText

    frame:Hide()
    return frame
end

function CoiledAltarKicker:EnsureFrames()
    if self.frames then
        return
    end

    self.frames = {}
    self.frames.anchor = createAnchor("ART_CoiledAltarKickerAnchor", 92, 46)
    self.frames.nextTextAnchor = CreateFrame(
        "Frame",
        "ART_CoiledAltarKickerNextTextAnchor",
        UIParent
    )
    self.frames.nextTextAnchor:SetSize(260, 36)
    self.frames.nextTextAnchor:SetFrameStrata("HIGH")
    self.frames.nextTextAnchor:SetFrameLevel(90)
    self.frames.nextTextAnchor:EnableMouse(false)
    self.frames.nextTextAnchor:Hide()

    self.frames.kickBox = createKickBox(
        UIParent,
        "ART_CoiledAltarKicker_Box"
    )

    local nextText = self.frames.nextTextAnchor:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalHuge"
    )
    nextText:SetPoint("CENTER", self.frames.nextTextAnchor, "CENTER", 0, 0)
    nextText:SetText(L["BossMods_CAKYourKickNext"] or "Your kick next")
    nextText:SetJustifyH("CENTER")
    self.frames.nextText = nextText

    self:ApplyAppearance()
    self:ApplyPositions()
end

function CoiledAltarKicker:ApplyPositions()
    self:EnsureDefaults()
    self:EnsureFrames()
    E:ApplyFramePosition(self.frames.anchor, self.db.position)
    E:ApplyFramePosition(
        self.frames.nextTextAnchor,
        self.db.nextTextPosition
    )
end

function CoiledAltarKicker:SavePosition(pos, key)
    key = key or "position"
    self.db[key] = self.db[key] or {}
    self.db[key].point = pos.point
    self.db[key].relPoint = pos.relPoint
    self.db[key].x = pos.x
    self.db[key].y = pos.y
    self:ApplyPositions()
    self:UpdateDisplay()
end

function CoiledAltarKicker:ApplyAppearance()
    self:EnsureDefaults()
    self:EnsureFrames()

    local size = self.db.box.size
    self.frames.anchor:SetSize(size, size)

    self.frames.kickBox:SetSize(size, size)
    self.frames.kickBox.text:ClearAllPoints()
    self.frames.kickBox.text:SetPoint(
        "CENTER",
        self.frames.kickBox,
        "CENTER",
        0,
        math.max(3, math.floor(size * 0.08))
    )
    E:ApplyFontString(
        self.frames.kickBox.text,
        E:FetchFont(self.db.font.name),
        self.db.font.size,
        self.db.font.outline
    )
    self.frames.kickBox.text:SetTextColor(
        colorValue(self.db.font.color, {1, 1, 1, 1})
    )
    self.frames.kickBox.nameText:ClearAllPoints()
    self.frames.kickBox.nameText:SetPoint(
        "BOTTOM",
        self.frames.kickBox,
        "BOTTOM",
        0,
        3
    )
    self.frames.kickBox.nameText:SetWidth(math.max(1, size - 4))
    E:ApplyFontString(
        self.frames.kickBox.nameText,
        E:FetchFont(self.db.font.name),
        math.max(7, math.min(12, math.floor(size * 0.18))),
        self.db.font.outline
    )
    self.frames.kickBox.nameText:SetTextColor(
        colorValue(self.db.font.color, {1, 1, 1, 1})
    )

    local nextText = self.db.nextText
    E:ApplyFontString(
        self.frames.nextText,
        E:FetchFont(nextText.name),
        nextText.size,
        nextText.outline
    )
    self.frames.nextText:SetTextColor(
        colorValue(nextText.color, {1, 0.82, 0.08, 1})
    )
end

function CoiledAltarKicker:SetBoxState(frame, state, count, currentName)
    if not frame then
        return
    end

    local color = BOX_COLORS.idle
    if state == "now" then
        color = BOX_COLORS.now
    elseif state == "next" then
        color = BOX_COLORS.next
    end

    local r, g, b, a = colorValue(color, {0.5, 0.08, 0.08, 0.70})
    frame:SetBackdropColor(r, g, b, (a or 1) * (self.db.box.opacity or 1))
    frame.text:SetText(count or "")
    fitFontString(
        frame.nameText,
        currentName,
        E:FetchFont(self.db.font.name),
        math.max(7, math.min(12, math.floor((self.db.box.size or 62) * 0.18))),
        self.db.font.outline,
        math.max(1, (self.db.box.size or 62) - 4),
        7
    )
end

function CoiledAltarKicker:GetLineForUnit(unit, lineIndex)
    if self.editMode and lineIndex then
        return lineIndex
    end

    local guid = unit and UnitGUID(unit)
    return guid and self.guidLines[guid] or self.unitLines[unit] or bossUnitLine(unit)
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

function CoiledAltarKicker:HasLineAssignments(line)
    local group = self.assignments and self.assignments[line]
    return group and #group > 0
end

function CoiledAltarKicker:GetKickDisplayName(token)
    if type(token) ~= "string" or token == "" then
        return ""
    end

    local NoteBlock = BossMods and BossMods.NoteBlock
    local unit = NoteBlock
        and NoteBlock.FindUnitByToken
        and NoteBlock:FindUnitByToken(token)

    if unit and UnitExists(unit) then
        if E.GetNickname then
            local nickname = cleanDisplayName(E:GetNickname(unit))
            if nickname then
                return nickname
            end
        end

        local unitName = cleanDisplayName(
            (UnitNameUnmodified and UnitNameUnmodified(unit)) or UnitName(unit)
        )
        if unitName then
            return unitName
        end
    end

    if NoteBlock and NoteBlock.GetDisplayName then
        local displayName = cleanDisplayName(NoteBlock:GetDisplayName(token))
        if displayName then
            return displayName
        end
    end

    return cleanDisplayName(token) or ""
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

function CoiledAltarKicker:GetLineState(line)
    local current = self:GetLineAssignment(line, self.castCounts[line])
    local _, nextPlayer = self:GetLineAssignment(line, self.castCounts[line])
    if current and self:IsPlayerToken(current) then
        return "now"
    end
    if nextPlayer and self:IsPlayerToken(nextPlayer) then
        return "next"
    end
    return "idle"
end

function CoiledAltarKicker:FindPersonalLine()
    local bestLine
    local bestState
    local bestUnit
    for line = 1, 4 do
        local state = self:GetLineState(line)
        local unit = state ~= "idle" and self:GetUnitForLine(line) or nil
        if unit and state == "now" then
            return line, state, unit
        elseif unit and state == "next" and not bestLine then
            bestLine = line
            bestState = state
            bestUnit = unit
        end
    end
    return bestLine, bestState, bestUnit
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

function CoiledAltarKicker:GetUnitForLine(line)
    if not line then
        return nil
    end

    for _, unit in ipairs(self:GetActiveBossUnits()) do
        if isActiveEnemyUnit(unit) and self:GetLineForUnit(unit) == line then
            return unit
        end
    end
    return nil
end

function CoiledAltarKicker:UpdateNextText(showNext)
    local anchor = self.frames.nextTextAnchor
    if not self.db.nextText.enabled then
        anchor:Hide()
        return
    end

    if self.editMode or showNext then
        anchor:Show()
        return
    end
    anchor:Hide()
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

function CoiledAltarKicker:UpdateDisplay()
    self:EnsureFrames()
    self:ApplyAppearance()

    local line
    local state
    local unit
    if self.editMode then
        line = 1
        state = "now"
    elseif self.encounterActive then
        line, state, unit = self:FindPersonalLine()
    end

    local showBox = line
        and (
            self.editMode
            or (
                self.encounterActive
                and unit
                and state ~= "idle"
                and self:HasLineAssignments(line)
            )
        )

    self.frames.anchor:SetShown(self.editMode)

    if showBox then
        local currentToken = self:GetLineAssignment(line, self.castCounts[line])
        self:AnchorKickBox(line, unit)
        self:SetBoxState(
            self.frames.kickBox,
            state,
            self.castCounts[line] or 1,
            self:GetKickDisplayName(currentToken)
        )
        self.frames.kickBox:Show()
    else
        self.frames.kickBox:Hide()
    end

    self:UpdateNextText(showBox and state == "next")
end

function CoiledAltarKicker:PlayConfiguredAudio(line, count)
    local audio = self.db.audio
    if not audio or not audio.enabled then
        return
    end

    local key = tostring(line) .. ":" .. tostring(count or 1)
    if self.lastAudioKey == key then
        return
    end
    self.lastAudioKey = key

    if audio.mode == "tts" then
        BossMods.Alerts:SpeakTTS({
            text = audio.ttsText or "Kick",
            voiceID = audio.voiceID or 0
        })
    else
        BossMods.Alerts:PlaySound({
            name = audio.sound,
            channel = audio.channel or "Master"
        })
    end
end

function CoiledAltarKicker:ParseHashAssignments(ctx)
    local Ready = BossMods and BossMods.ReadyAssignments
    if not Ready or not Ready.Words then
        return false
    end

    local found = false
    for line = 1, 4 do
        local tag = "cakick" .. line
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
    self.assignments = {{}, {}, {}, {}}
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

function CoiledAltarKicker:ResetCastCounts()
    for line = 1, 4 do
        self.castCounts[line] = 1
    end
    wipe(self.castingUnits)
    wipe(self.castingGUIDs)
    wipe(self.unitGUIDs)
    wipe(self.unitLines)
    wipe(self.guidLines)
    self.lastAudioKey = nil
    self:UpdateDisplay()
end

function CoiledAltarKicker:RefreshUnitGUID(unit)
    if not isTrackedBossUnit(unit) then
        return nil
    end

    if not self:IsActiveBossUnit(unit) then
        return nil
    end

    if not isActiveEnemyUnit(unit) then
        return nil
    end

    local guid = UnitGUID(unit)
    if not guid then
        return self:GetLineForUnit(unit)
    end

    local line = self.guidLines[guid]
    local isNewAdd = line == nil
    if isNewAdd then
        line = bossUnitLine(unit)
        if line then
            self.guidLines[guid] = line
        end
    end

    if not line then
        return nil
    end

    if self.unitGUIDs[unit] ~= guid then
        self.unitGUIDs[unit] = guid
        self.unitLines[unit] = line
        self.castingUnits[unit] = nil
        if isNewAdd then
            self.castCounts[line] = 1
            self.lastAudioKey = nil
        end
    elseif self.unitLines[unit] ~= line then
        self.unitLines[unit] = line
    end
    return line
end

function CoiledAltarKicker:RefreshActiveUnits()
    if not self.encounterActive then
        return
    end
    for _, unit in ipairs(MYTHIC_BOSS_UNITS) do
        self:RefreshUnitGUID(unit)
    end
end

function CoiledAltarKicker:HandleCastStart(unit)
    if not self.encounterActive
        or not self:IsActiveBossUnit(unit)
        or not isActiveEnemyUnit(unit)
    then
        return
    end

    local line = self:RefreshUnitGUID(unit)
    if not line then
        return
    end

    local guid = UnitGUID(unit)
    self.castingUnits[unit] = true
    if guid then
        self.castingGUIDs[guid] = true
    end
    if self:GetLineState(line) == "now" then
        self:PlayConfiguredAudio(line, self.castCounts[line])
    end
    self:UpdateDisplay()
end

function CoiledAltarKicker:HandleCastInterrupted(unit)
    if not self.encounterActive then
        return
    end

    self.castingUnits[unit] = nil
    local guid = UnitGUID(unit) or self.unitGUIDs[unit]
    if guid then
        self.castingGUIDs[guid] = nil
    end
    self:UpdateDisplay()
end

function CoiledAltarKicker:HandleCastStop(unit)
    if not self.encounterActive or not self:IsActiveBossUnit(unit) then
        return
    end

    local guid = UnitGUID(unit) or self.unitGUIDs[unit]
    if not self.castingUnits[unit]
        and not (guid and self.castingGUIDs[guid])
    then
        return
    end

    local line = guid and self.guidLines[guid]
        or self.unitLines[unit]
        or self:GetLineForUnit(unit)
    self.castingUnits[unit] = nil
    if guid then
        self.castingGUIDs[guid] = nil
    end
    if line then
        self.castCounts[line] = (self.castCounts[line] or 1) + 1
    end
    self.lastAudioKey = nil
    self:UpdateDisplay()
end

function CoiledAltarKicker:UNIT_SPELLCAST_START(_, unit)
    self:HandleCastStart(unit)
end

function CoiledAltarKicker:UNIT_SPELLCAST_STOP(_, unit)
    self:HandleCastStop(unit)
end

function CoiledAltarKicker:UNIT_SPELLCAST_INTERRUPTED(_, unit)
    self:HandleCastInterrupted(unit)
end

function CoiledAltarKicker:OnRaidTargetUpdate()
    self:RefreshActiveUnits()
    self:UpdateDisplay()
end

function CoiledAltarKicker:OnEncounterStart(_, encounterID, _, difficultyID)
    if tonumber(encounterID) ~= ENCOUNTER_ID then
        return
    end
    self.encounterActive = true
    self.difficultyID = tonumber(difficultyID) or 16
    self:ParseAssignments()
    self:ResetCastCounts()
    self:RefreshActiveUnits()
end

function CoiledAltarKicker:OnEncounterEnd(_, encounterID)
    if tonumber(encounterID) ~= ENCOUNTER_ID then
        return
    end
    self.encounterActive = false
    wipe(self.castingUnits)
    wipe(self.castingGUIDs)
    wipe(self.unitGUIDs)
    wipe(self.unitLines)
    wipe(self.guidLines)
    self.lastAudioKey = nil
    self:UpdateDisplay()
end

function CoiledAltarKicker:SetEditMode(value)
    self.editMode = value and true or false
    if self.editMode then
        self.assignments = {{
            UnitName("player") or "Player",
            "Next"
        }}
        for line = 1, 4 do
            self.castCounts[line] = 1
        end
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
    self.editMode = false
    self.castCounts = {[1] = 1, [2] = 1, [3] = 1, [4] = 1}
    self.castingUnits = {}
    self.castingGUIDs = {}
    self.unitGUIDs = {}
    self.unitLines = {}
    self.guidLines = {}
    self.assignments = {{}, {}, {}, {}}
    self:EnsureFrames()
    self:ParseAssignments()
    self:UpdateDisplay()
end

function CoiledAltarKicker:OnEnable()
    BossMods = BossMods or E:GetModule("BossMods")
    self:EnsureFrames()
    self:Refresh()
    self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
    self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
    self:RegisterEvent("UNIT_SPELLCAST_START")
    self:RegisterEvent("UNIT_SPELLCAST_STOP")
    self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    self:RegisterEvent("UNIT_DIED", "OnRaidTargetUpdate")
    self:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT", "OnRaidTargetUpdate")
    self:RegisterEvent("PLAYER_FOCUS_CHANGED", "OnRaidTargetUpdate")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Refresh")
end

function CoiledAltarKicker:OnDisable()
    self.encounterActive = false
    self.editMode = false
    wipe(self.castingUnits)
    wipe(self.castingGUIDs)
    wipe(self.unitGUIDs)
    wipe(self.unitLines)
    wipe(self.guidLines)
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    if self.frames then
        self.frames.anchor:Hide()
        self.frames.nextTextAnchor:Hide()
        self.frames.kickBox:Hide()
    end
end

E:RegisterBossModFeature("CoiledAltarKicker", {
    tab = "AbyssCustom",
    order = 85,
    labelKey = "BossMods_CoiledAltarKicker",
    descKey = "BossMods_CoiledAltarKickerDesc",
    moduleName = "BossMods_CoiledAltarKicker"
})
