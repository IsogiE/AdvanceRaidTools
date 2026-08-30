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
    nameplate = {
        size = 30,
        numberFontSize = 12,
        nameFontSize = 12,
        anchor = "TOP",
        offsetX = 0,
        offsetY = 0,
        showAll = false
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
local INTERRUPT_ADD_LEVEL = 92
local LINE_COUNT = 2
local UNMARKED_LINE = 1
local MARKED_LINE = 2
local BOX_COLORS = {
    now = {0.05, 0.78, 0.18, 0.95},
    next = {1, 0.45, 0.02, 0.95},
    idle = {0.50, 0.08, 0.08, 0.70}
}
local PREVIEW_COLORS = {
    now = {0.05, 0.78, 0.18, 0.95},
    next = {1, 0.82, 0.08, 0.95},
    idle = {0.50, 0.08, 0.08, 0.70}
}
local NAMEPLATE_ANCHOR_POINTS = {
    TOP = {"BOTTOM", "TOP"},
    BOTTOM = {"TOP", "BOTTOM"},
    LEFT = {"RIGHT", "LEFT"},
    RIGHT = {"LEFT", "RIGHT"},
    CENTER = {"CENTER", "CENTER"}
}
local VALID_NAMEPLATE_ANCHORS = {
    TOP = true,
    BOTTOM = true,
    LEFT = true,
    RIGHT = true,
    CENTER = true
}

local CoiledAltarKicker = E:NewModule(
    "BossMods_CoiledAltarKicker",
    "AceEvent-3.0"
)
local BossMods
local issecretvalue = _G.issecretvalue or function()
    return false
end

local function isSecret(value)
    return issecretvalue(value)
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

local function isInterruptBossUnit(unit)
    return unit == "boss3" or unit == "boss4"
end

local function anchorFrameToNameplate(frame, plate, anchor, offsetX, offsetY)
    local points = NAMEPLATE_ANCHOR_POINTS[anchor or "TOP"]
        or NAMEPLATE_ANCHOR_POINTS.TOP
    frame:ClearAllPoints()
    frame:SetPoint(points[1], plate, points[2], offsetX or 0, offsetY or 0)
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

    self.db.nameplate = self.db.nameplate or {}
    self.db.nameplate.size = clamp(self.db.nameplate.size, 30, 150, 30)
    self.db.nameplate.numberFontSize = clamp(
        self.db.nameplate.numberFontSize,
        8,
        40,
        12
    )
    self.db.nameplate.nameFontSize = clamp(
        self.db.nameplate.nameFontSize,
        8,
        40,
        12
    )
    if not VALID_NAMEPLATE_ANCHORS[self.db.nameplate.anchor] then
        self.db.nameplate.anchor = "TOP"
    end
    self.db.nameplate.offsetX = clamp(self.db.nameplate.offsetX, -200, 200, 0)
    self.db.nameplate.offsetY = clamp(self.db.nameplate.offsetY, -200, 200, 0)
    self.db.nameplate.showAll = self.db.nameplate.showAll == true

    self.db.audio = self.db.audio or {}
    self.db.audio.enabled = self.db.audio.enabled == true
    self.db.audio.mode = self.db.audio.mode == "tts" and "tts" or "sound"
    self.db.audio.sound = self.db.audio.sound or "None"
    self.db.audio.channel = self.db.audio.channel or "Master"
    self.db.audio.ttsText = self.db.audio.ttsText or "Kick"
    self.db.audio.voiceID = tonumber(self.db.audio.voiceID) or 0
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
    self.frames.nameplateRoot = CreateFrame(
        "Frame",
        "ART_CoiledAltarKicker_Nameplates",
        UIParent
    )
    self.frames.nameplateRoot:SetFrameStrata("HIGH")
    self.frames.nameplateRoot:SetFrameLevel(94)

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

function CoiledAltarKicker:ApplyBoxAppearance(
    frame,
    size,
    numberFontSize,
    nameFontSize
)
    if not frame then
        return
    end

    local font = E:FetchFont(self.db.font.name)
    size = tonumber(size) or self.db.box.size or 62
    frame:SetSize(size, size)
    frame.artBoxSize = size
    frame.artNameFontSize = nameFontSize
        or math.max(7, math.min(12, math.floor(size * 0.18)))

    frame.text:ClearAllPoints()
    frame.text:SetPoint(
        "CENTER",
        frame,
        "CENTER",
        0,
        math.max(2, math.floor(size * 0.08))
    )
    E:ApplyFontString(
        frame.text,
        font,
        numberFontSize or self.db.font.size,
        self.db.font.outline
    )
    frame.text:SetTextColor(colorValue(self.db.font.color, {1, 1, 1, 1}))

    frame.nameText:ClearAllPoints()
    frame.nameText:SetPoint("BOTTOM", frame, "BOTTOM", 0, 3)
    frame.nameText:SetWidth(math.max(1, size - 4))
    E:ApplyFontString(
        frame.nameText,
        font,
        frame.artNameFontSize,
        self.db.font.outline
    )
    frame.nameText:SetTextColor(colorValue(self.db.font.color, {1, 1, 1, 1}))
end

function CoiledAltarKicker:ApplyAppearance()
    self:EnsureDefaults()
    self:EnsureFrames()

    local size = self.db.box.size
    self.frames.anchor:SetSize(size, size)
    self:ApplyBoxAppearance(self.frames.kickBox, size, self.db.font.size)

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

function CoiledAltarKicker:SetBoxState(
    frame,
    state,
    count,
    currentName,
    colors,
    currentClass
)
    if not frame then
        return
    end

    colors = colors or BOX_COLORS
    local color = colors.idle
    if state == "now" then
        color = colors.now
    elseif state == "next" then
        color = colors.next
    end

    local size = frame.artBoxSize or self.db.box.size or 62
    local r, g, b, a = colorValue(color, {0.5, 0.08, 0.08, 0.70})
    frame:SetBackdropColor(r, g, b, (a or 1) * (self.db.box.opacity or 1))
    frame.text:SetText(count or "")
    fitFontString(
        frame.nameText,
        currentName,
        E:FetchFont(self.db.font.name),
        frame.artNameFontSize or math.max(
            7,
            math.min(12, math.floor(size * 0.18))
        ),
        self.db.font.outline,
        math.max(1, size - 4),
        7
    )

    local nr, ng, nb, na = colorValue(self.db.font.color, {1, 1, 1, 1})
    if currentClass and E.ClassColorRGB then
        nr, ng, nb = E:ClassColorRGB(currentClass)
        na = 1
    end
    frame.nameText:SetTextColor(nr, ng, nb, na)
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

function CoiledAltarKicker:GetKickDisplayName(token)
    if type(token) ~= "string" or token == "" then
        return ""
    end

    local NoteBlock = BossMods and BossMods.NoteBlock
    local unit = NoteBlock
        and NoteBlock.FindUnitByToken
        and NoteBlock:FindUnitByToken(token)

    local unitExists = unit and UnitExists(unit)
    if not isSecret(unitExists) and unitExists then
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

function CoiledAltarKicker:GetKickDisplayInfo(token)
    local displayName = self:GetKickDisplayName(token)
    local classFile
    local NoteBlock = BossMods and BossMods.NoteBlock

    if NoteBlock and NoteBlock.GetClassForToken then
        classFile = NoteBlock:GetClassForToken(token)
        if not classFile and displayName ~= token then
            classFile = NoteBlock:GetClassForToken(displayName)
        end
    end

    if not classFile and E.GetClassByName then
        classFile = E:GetClassByName(token) or E:GetClassByName(displayName)
    end

    return displayName, classFile
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

function CoiledAltarKicker:SyncCastCounts()
    self.castCountsByUnit = self.castCountsByUnit
        or {boss3 = 1, boss4 = 1}
    local countUnit = self.assignedBossUnit
    self.castCounts[UNMARKED_LINE] =
        self.castCountsByUnit[countUnit or "boss3"] or 1
    self.castCounts[MARKED_LINE] =
        self.castCountsByUnit[countUnit or "boss4"] or 1
end

function CoiledAltarKicker:IsInterruptUnit(unit)
    if not isInterruptBossUnit(unit) then
        return false
    end
    if not self.assignedBossUnit then
        return true
    end
    return unit == self.assignedBossUnit
end

function CoiledAltarKicker:HideNameplateDisplays()
    for _, display in pairs(self.nameplateDisplays or {}) do
        for _, box in ipairs(display.boxes or {}) do
            box:Hide()
        end
    end
end

function CoiledAltarKicker:ResetInterruptDisplay()
    self:HideNameplateDisplays()
    self.assignedBossUnit = nil
    self.interruptActive = false
    self.boss3Available = false
    self.castCountsByUnit = {boss3 = 1, boss4 = 1}
    self.castCounts = {[1] = 1, [2] = 1}
    self.castingUnits = {}
    self.lastAudioKey = nil
    for _, display in pairs(self.nameplateDisplays or {}) do
        display.plate = nil
    end
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
    local assignedBoss = self.assignedBossUnit
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
                local bossUnit = boxIndex == UNMARKED_LINE and "boss3" or "boss4"
                local displayLine = boxIndex == MARKED_LINE and MARKED_LINE
                    or UNMARKED_LINE
                local lineNames = self.assignments[displayLine] or {}
                local countUnit = assignedBoss or bossUnit
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
                and state ~= "idle"
                and self:HasLineAssignments(line)
            )
        )

    if showBox then
        local count = self.castCounts[line] or 1
        local currentToken = self:GetLineAssignment(line, count)
        local displayName, classFile = self:GetKickDisplayInfo(currentToken)

        if self.editMode then
            currentToken = UnitName("player") or "Player"
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

function CoiledAltarKicker:PlayConfiguredAudio(line, count)
    local audio = self.db.audio
    if not audio or not audio.enabled or not BossMods or not BossMods.Alerts then
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

function CoiledAltarKicker:PlayPersonalAudioForCount(count)
    if self.editMode or not self.interruptActive then
        return
    end

    for line = 1, LINE_COUNT do
        local currentToken = self:GetLineAssignment(line, count)
        if currentToken and self:IsPlayerToken(currentToken) then
            self:PlayConfiguredAudio(line, count)
        end
    end
end

function CoiledAltarKicker:ParseHashAssignments(ctx)
    local Ready = BossMods and BossMods.ReadyAssignments
    if not Ready or not Ready.Words then
        return false
    end

    local found = false
    for line = 1, LINE_COUNT do
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

function CoiledAltarKicker:HandleCastStart(unit)
    self:UpdateAssignedBoss()
    if self.interruptActive
        and self:IsInterruptUnit(unit)
        and UnitIsEnemy(unit, "player")
    then
        self.castingUnits[unit] = true
        self:UpdateDisplay()
        self:PlayPersonalAudioForCount(self.castCountsByUnit[unit] or 1)
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

    self:ParseAssignments()
    self:ResetInterruptDisplay()
    self.interruptActive = true
    self.boss3Available = true
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
    self:UpdateDisplay()
end

function CoiledAltarKicker:SetEditMode(value)
    self.editMode = value and true or false
    if self.editMode then
        self.assignments = {{
            UnitName("player") or "Player",
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
    tab = "AbyssCustom",
    order = 85,
    labelKey = "BossMods_CoiledAltarKicker",
    descKey = "BossMods_CoiledAltarKickerDesc",
    moduleName = "BossMods_CoiledAltarKicker"
})
