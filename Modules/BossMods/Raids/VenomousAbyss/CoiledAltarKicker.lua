local E, L = unpack(ART)

E:RegisterModuleDefaults("BossMods_CoiledAltarKicker", {
    enabled = false,
    position = {
        point = "CENTER",
        x = 260,
        y = 80
    },
    squareSize = 82,
    opacity = 0.9,
    iconOffsetX = -8,
    iconOffsetY = 0,
    showList = false,
    nextKickText = {
        enabled = false,
        position = {
            x = 0,
            y = 180
        },
        font = {
            name = "Friz Quadrata TT",
            size = 32,
            outline = "OUTLINE"
        }
    },
    audio = {
        enabled = false,
        mode = "sound",
        sound = "None",
        channel = "Master",
        ttsText = "Your kick",
        voiceID = 0
    }
})

local ENCOUNTER_ID = 3429
local MAX_ASSIGNMENTS = 7
local DISPLAY_ROWS = MAX_ASSIGNMENTS + 1
local FRAME_GAP = 8
local LIST_ROW_HEIGHT = 18

local CoiledAltarKicker = E:NewModule(
    "BossMods_CoiledAltarKicker",
    "AceEvent-3.0"
)
local BossMods = E:GetModule("BossMods")

local function clamp(value, minimum, maximum, fallback)
    value = tonumber(value)
    if not value then
        value = fallback or minimum
    end
    return math.max(minimum, math.min(maximum, value))
end

local function trim(value)
    if type(value) ~= "string" then
        return ""
    end
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function cleanToken(value)
    value = trim(value)
    value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    value = value:gsub("|T.-|t", "")
    return value:gsub("^[,;:]+", ""):gsub("[,;:]+$", "")
end

function CoiledAltarKicker:EnsureDefaults()
    self.db.position = self.db.position or {point = "CENTER", x = 260, y = 80}
    self.db.position.point = self.db.position.point or "CENTER"
    self.db.position.x = tonumber(self.db.position.x) or 260
    self.db.position.y = tonumber(self.db.position.y) or 80
    self.db.squareSize = clamp(self.db.squareSize, 48, 180, 82)
    self.db.opacity = clamp(self.db.opacity, 0.1, 1, 0.9)
    self.db.iconOffsetX = clamp(self.db.iconOffsetX, -300, 300, -8)
    self.db.iconOffsetY = clamp(self.db.iconOffsetY, -300, 300, 0)
    self.db.showList = self.db.showList == true
    self.db.nextKickText = self.db.nextKickText or {}
    self.db.nextKickText.enabled = self.db.nextKickText.enabled == true
    self.db.nextKickText.position = self.db.nextKickText.position or {}
    self.db.nextKickText.position.x = clamp(
        self.db.nextKickText.position.x,
        -1000,
        1000,
        0
    )
    self.db.nextKickText.position.y = clamp(
        self.db.nextKickText.position.y,
        -1000,
        1000,
        180
    )
    self.db.nextKickText.font = self.db.nextKickText.font or {}
    self.db.nextKickText.font.name = self.db.nextKickText.font.name
        or "Friz Quadrata TT"
    self.db.nextKickText.font.size = clamp(
        self.db.nextKickText.font.size,
        12,
        72,
        32
    )
    if self.db.nextKickText.font.outline == nil then
        self.db.nextKickText.font.outline = "OUTLINE"
    end
    self.db.audio = self.db.audio or {}
    self.db.audio.enabled = self.db.audio.enabled == true
    self.db.audio.mode = self.db.audio.mode == "tts" and "tts" or "sound"
    self.db.audio.sound = self.db.audio.sound or "None"
    self.db.audio.channel = self.db.audio.channel or "Master"
    self.db.audio.ttsText = trim(self.db.audio.ttsText) ~= "" and self.db.audio.ttsText or "Your kick"
    self.db.audio.voiceID = tonumber(self.db.audio.voiceID) or 0
end

local function createKickSquare(parent, number)
    local square = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    square:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 2
    })
    square:SetBackdropBorderColor(0.05, 0.05, 0.05, 1)

    local title = square:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title:SetPoint("TOP", square, "TOP", 0, -6)
    title:SetText(("Kick %d"):format(number))

    local count = square:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    count:SetPoint("CENTER", square, "CENTER", 0, 4)

    local name = square:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    name:SetPoint("BOTTOMLEFT", square, "BOTTOMLEFT", 3, 6)
    name:SetPoint("BOTTOMRIGHT", square, "BOTTOMRIGHT", -3, 6)
    name:SetJustifyH("CENTER")
    name:SetWordWrap(false)

    return square, title, count, name
end

local function createGroupDisplay(parent, number)
    local group = CreateFrame("Frame", nil, parent)
    local square, title, count, name = createKickSquare(group, number)
    local focusSquare, focusTitle, focusCount, focusName =
        createKickSquare(group, number)
    focusTitle:SetText(("Add %d focus"):format(number))
    focusSquare:Hide()

    local list = CreateFrame("Frame", nil, group, "BackdropTemplate")
    list:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1
    })
    list:SetBackdropColor(0.03, 0.03, 0.03, 0.82)
    list:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)

    local listTitle = list:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    listTitle:SetPoint("TOPLEFT", list, "TOPLEFT", 6, -5)
    listTitle:SetText(("Kick %d order"):format(number))

    local rows = {}
    for i = 1, DISPLAY_ROWS do
        local row = list:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row:SetPoint("TOPLEFT", list, "TOPLEFT", 7, -(22 + (i - 1) * LIST_ROW_HEIGHT))
        row:SetPoint("TOPRIGHT", list, "TOPRIGHT", -5, -(22 + (i - 1) * LIST_ROW_HEIGHT))
        row:SetJustifyH("LEFT")
        row:SetWordWrap(false)
        rows[i] = row
    end

    group.square = square
    group.title = title
    group.count = count
    group.name = name
    group.focusSquare = focusSquare
    group.focusTitle = focusTitle
    group.focusCount = focusCount
    group.focusName = focusName
    group.list = list
    group.listTitle = listTitle
    group.rows = rows
    return group
end

local function newStream(unitIndex, primaryGroup, backupGroup)
    return {
        unitIndex = unitIndex,
        primaryGroup = primaryGroup,
        backupGroup = backupGroup,
        castCount = 0,
        observed = false,
        initialCastIgnored = false,
        active = true
    }
end

function CoiledAltarKicker:ResetStreams()
    self.streams = {
        newStream(3, 1, nil),
        newStream(4, 2, nil),
        newStream(5, 1, 1),
        newStream(6, 2, 2)
    }
    self.currentHighestBossFrame = nil
end

function CoiledAltarKicker:EnsureFrame()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "ART_CoiledAltarKicker", UIParent)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(false)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(f)
        if self.editMode then
            f:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        local point, _, _, x, y = f:GetPoint(1)
        self:SavePosition({point = point, x = x, y = y})
    end)

    self.frame = frame
    self.groups = {
        createGroupDisplay(frame, 1),
        createGroupDisplay(frame, 2),
        createGroupDisplay(frame, 3),
        createGroupDisplay(frame, 4)
    }
    frame:Hide()

    local nextKickFrame = CreateFrame(
        "Frame",
        "ART_CoiledAltarKickerNextText",
        UIParent
    )
    nextKickFrame:SetSize(700, 90)
    nextKickFrame:SetFrameStrata("HIGH")
    nextKickFrame:EnableMouse(false)
    local nextKickLabel = nextKickFrame:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalHuge"
    )
    nextKickLabel:SetPoint("CENTER")
    nextKickLabel:SetText(L["BossMods_CAKYourKickNext"] or "Your kick next")
    nextKickFrame:Hide()
    self.nextKickFrame = nextKickFrame
    self.nextKickLabel = nextKickLabel

    self:ApplyAppearance()
    self:ApplyPosition()
end

function CoiledAltarKicker:ApplyPosition()
    if not self.frame then
        return
    end
    E:ApplyFramePosition(self.frame, self.db.position)
end

function CoiledAltarKicker:SavePosition(position)
    self.db.position.point = position.point or "CENTER"
    self.db.position.x = tonumber(position.x) or 0
    self.db.position.y = tonumber(position.y) or 0
    self:ApplyPosition()
end

function CoiledAltarKicker:ApplyAppearance()
    self:EnsureDefaults()
    if not self.frame or not self.groups then
        return
    end

    local size = self.db.squareSize
    local columnWidth = math.max(size, 150)
    local listHeight = 27 + DISPLAY_ROWS * LIST_ROW_HEIGHT
    local listsVisible = self.db.showList or self.editMode
    local totalHeight = listsVisible and listHeight or 1
    self.frame:SetSize(columnWidth * 4 + FRAME_GAP * 3, totalHeight)

    for i, group in ipairs(self.groups) do
        group:ClearAllPoints()
        group:SetPoint("TOPLEFT", self.frame, "TOPLEFT", (i - 1) * (columnWidth + FRAME_GAP), 0)
        group:SetSize(columnWidth, totalHeight)
        group.square:SetSize(size, size)
        group.focusSquare:SetSize(size, size)
        group.count:SetFontObject("GameFontNormalHuge")

        group.list:ClearAllPoints()
        group.list:SetPoint("TOP", group, "TOP", 0, 0)
        group.list:SetSize(columnWidth, listHeight)
        group.list:SetShown(listsVisible)
    end

    local text = self.db.nextKickText
    self.nextKickFrame:ClearAllPoints()
    self.nextKickFrame:SetPoint(
        "CENTER",
        UIParent,
        "CENTER",
        text.position.x,
        text.position.y
    )
    E:ApplyFontString(
        self.nextKickLabel,
        E:FetchFont(text.font.name),
        text.font.size,
        text.font.outline
    )
end

function CoiledAltarKicker:ResolveBossFrame(unitIndex)
    local unit = "boss" .. unitIndex
    local resolver = BossMods.Alerts and BossMods.Alerts.ResolveFrame
    if resolver then
        local frame = BossMods.Alerts:ResolveFrame(unit)
        if frame and (not frame.IsVisible or frame:IsVisible()) then
            return frame
        end
    end

    local candidateNames = {
        "Boss" .. unitIndex .. "TargetFrame",
        "BossTargetFrame" .. unitIndex,
        "ElvUF_Boss" .. unitIndex,
        "SUFUnitboss" .. unitIndex,
        "EllesmereUIUnitFrames_Boss" .. unitIndex
    }
    for _, name in ipairs(candidateNames) do
        local frame = _G[name]
        if frame and (not frame.IsVisible or frame:IsVisible()) then
            return frame
        end
    end
    return nil
end

function CoiledAltarKicker:ResolveFocusFrame()
    local resolver = BossMods.Alerts and BossMods.Alerts.ResolveFrame
    if resolver then
        local frame = BossMods.Alerts:ResolveFrame("focus")
        if frame and (not frame.IsVisible or frame:IsVisible()) then
            return frame
        end
    end

    local candidateNames = {
        "FocusFrame",
        "ElvUF_Focus",
        "SUFUnitfocus",
        "EllesmereUIUnitFrames_Focus"
    }
    for _, name in ipairs(candidateNames) do
        local frame = _G[name]
        if frame and (not frame.IsVisible or frame:IsVisible()) then
            return frame
        end
    end
    return nil
end

function CoiledAltarKicker:IsPlayerInStream(stream)
    for _, entry in ipairs(self:GetStreamRows(stream)) do
        if entry.token and self:IsMe(entry.token) then
            return true
        end
    end
    return false
end

function CoiledAltarKicker:ApplyBossFrameAnchors()
    if not self.groups or not self.streams then
        return
    end

    local size = self.db.squareSize
    local columnWidth = math.max(size, 150)
    for groupNumber, group in ipairs(self.groups) do
        local stream = self.streams[groupNumber]
        local target = self.encounterActive
            and stream
            and stream.active
            and stream.observed
            and self:ResolveBossFrame(stream.unitIndex)

        if target then
            group.square:ClearAllPoints()
            group.square:SetPoint(
                "RIGHT",
                target,
                "LEFT",
                self.db.iconOffsetX,
                self.db.iconOffsetY
            )
            group.square:Show()
        elseif self.previewMode then
            group.square:ClearAllPoints()
            group.square:SetPoint(
                "BOTTOM",
                group,
                "TOP",
                self.db.iconOffsetX,
                12 + self.db.iconOffsetY
            )
            group.square:Show()
        else
            group.square:Hide()
        end
        group.square:SetSize(size, size)

        local unit = stream and ("boss" .. stream.unitIndex)
        local focusTarget = self.encounterActive
            and stream
            and stream.active
            and stream.observed
            and unit
            and UnitExists("focus")
            and UnitIsUnit("focus", unit)
            and self:IsPlayerInStream(stream)
            and self:ResolveFocusFrame()
        if focusTarget then
            group.focusSquare:ClearAllPoints()
            group.focusSquare:SetPoint(
                "RIGHT",
                focusTarget,
                "LEFT",
                self.db.iconOffsetX,
                self.db.iconOffsetY
            )
            group.focusSquare:Show()
        else
            group.focusSquare:Hide()
        end
        group.focusSquare:SetSize(size, size)

        -- Interrupt lists use their own movable anchor and do not follow the
        -- boss frames. Only the kick squares are boss-frame anchored.
        group.list:ClearAllPoints()
        group.list:SetPoint("TOP", group, "TOP", 0, 0)
        group.list:SetWidth(columnWidth)
        group.list:SetShown(
            (self.db.showList or self.editMode)
                and stream.active
                and (stream.observed or self.previewMode or self.editMode)
        )
    end
end

function CoiledAltarKicker:GetAssignments(tag)
    local Ready = BossMods.ReadyAssignments
    local NoteBlock = BossMods.NoteBlock
    local noteText = NoteBlock and NoteBlock:GetMainNoteText() or ""
    local result = {}

    if Ready and Ready.ParseHashSections then
        local _, sections = Ready:ParseHashSections(noteText)
        local entries = sections and sections[tag:lower()]
        local section = entries and entries[1]
        if section then
            for _, token in ipairs(Ready:Words(section.text or section.headerText or "")) do
                token = cleanToken(token)
                if token ~= "" then
                    result[#result + 1] = token
                    if #result >= MAX_ASSIGNMENTS then
                        break
                    end
                end
            end
        end
    end
    return result
end

function CoiledAltarKicker:ParseAssignments()
    self.assignments = {
        self:GetAssignments("cakick1"),
        self:GetAssignments("cakick2")
    }
    self.backupAssignments = {
        self:GetAssignments("cabukick1")[1],
        self:GetAssignments("cabukick2")[1]
    }
end

function CoiledAltarKicker:IsMe(token)
    local NoteBlock = BossMods.NoteBlock
    return NoteBlock and NoteBlock:IsPlayerToken(token) or false
end

function CoiledAltarKicker:GetPrimaryIndex(stream)
    local assignments = self.assignments[stream.primaryGroup] or {}
    if #assignments == 0 then
        return nil
    end

    -- A BU assignment replaces CA1 for the first cycle. The second cast on a
    -- backup stream therefore starts at CA2; CA1 returns after the final CA
    -- assignment when the rotation wraps normally.
    local primaryCastCount = stream.castCount
    return ((math.max(1, primaryCastCount) - 1) % #assignments) + 1
end

function CoiledAltarKicker:GetCurrentAssignment(stream)
    local backup = stream.backupGroup and self.backupAssignments[stream.backupGroup]
    if backup and stream.castCount <= 1 then
        return backup, "BU", 1
    end

    local index = self:GetPrimaryIndex(stream)
    local assignments = self.assignments[stream.primaryGroup] or {}
    local rowOffset = backup and 1 or 0
    return index and assignments[index], index, index and index + rowOffset or nil
end

function CoiledAltarKicker:GetStreamRows(stream)
    local rows = {}
    if stream.backupGroup then
        local backup = self.backupAssignments[stream.backupGroup]
        if backup then
            rows[#rows + 1] = {token = backup, label = "BU"}
        end
    end

    for index, token in ipairs(self.assignments[stream.primaryGroup] or {}) do
        rows[#rows + 1] = {token = token, label = tostring(index)}
    end
    return rows
end

function CoiledAltarKicker:PlayConfiguredAudio()
    local audio = self.db.audio
    if not audio or not audio.enabled then
        return
    end
    if audio.mode == "tts" then
        BossMods.Alerts:SpeakTTS({
            text = audio.ttsText or "Your kick",
            voiceID = audio.voiceID or 0
        })
    else
        BossMods.Alerts:PlaySound({
            name = audio.sound or "None",
            channel = audio.channel or "Master"
        })
    end
end

function CoiledAltarKicker:UpdateGroup(groupNumber)
    local group = self.groups[groupNumber]
    local stream = self.streams[groupNumber]
    local assigned, displayIndex, rowIndex = self:GetCurrentAssignment(stream)
    local isMine = assigned and self:IsMe(assigned)

    group.title:SetText(("Add %d  •  boss%d"):format(groupNumber, stream.unitIndex))
    group.listTitle:SetText(("Add %d"):format(groupNumber))

    local visible = stream.active
        and (stream.observed or self.previewMode or self.editMode)
    group:SetShown(visible)
    if not visible then
        return
    end

    if not assigned then
        group.count:SetText("–")
        group.focusCount:SetText("–")
        group.name:SetText(L["BossMods_CAKNoAssignments"] or "No assignments")
        group.focusName:SetText(L["BossMods_CAKNoAssignments"] or "No assignments")
        group.square:SetBackdropColor(0.45, 0.08, 0.08, self.db.opacity)
        group.focusSquare:SetBackdropColor(0.45, 0.08, 0.08, self.db.opacity)
    else
        group.count:SetText(displayIndex)
        group.focusCount:SetText(displayIndex)
        local displayName = BossMods.NoteBlock:GetDisplayName(assigned) or assigned
        group.name:SetText(displayName)
        group.focusName:SetText(displayName)
        if isMine then
            group.square:SetBackdropColor(0.08, 0.65, 0.14, self.db.opacity)
            group.focusSquare:SetBackdropColor(0.08, 0.65, 0.14, self.db.opacity)
        else
            group.square:SetBackdropColor(0.70, 0.08, 0.08, self.db.opacity)
            group.focusSquare:SetBackdropColor(0.70, 0.08, 0.08, self.db.opacity)
        end
    end

    local displayRows = self:GetStreamRows(stream)
    for i, row in ipairs(group.rows) do
        local entry = displayRows[i]
        if entry then
            local display = BossMods.NoteBlock:GetDisplayName(entry.token) or entry.token
            if i == rowIndex then
                row:SetText(("|cFF00FF00> %s. %s|r"):format(entry.label, display))
            else
                row:SetText(("|cFFB8B8B8  %s. %s|r"):format(entry.label, display))
            end
            row:Show()
        else
            row:SetText("")
            row:Hide()
        end
    end
end

function CoiledAltarKicker:UpdateNextKickText()
    if not self.nextKickFrame then
        return
    end

    local show = self.previewMode
    if not show
        and self.encounterActive
        and self.db.nextKickText.enabled
    then
        for _, stream in ipairs(self.streams or {}) do
            if stream.active
                and stream.observed
                and UnitExists("boss" .. stream.unitIndex)
            then
                local assigned = self:GetCurrentAssignment(stream)
                if assigned and self:IsMe(assigned) then
                    show = true
                    break
                end
            end
        end
    end
    self.nextKickFrame:SetShown(show and self.db.nextKickText.enabled)
end

function CoiledAltarKicker:UpdateDisplay()
    self:EnsureFrame()
    if not self.encounterActive and not self.previewMode and not self.editMode then
        self.frame:Hide()
        if self.nextKickFrame then
            self.nextKickFrame:Hide()
        end
        return
    end

    for groupNumber = 1, #self.groups do
        self:UpdateGroup(groupNumber)
    end
    self:ApplyBossFrameAnchors()
    self:UpdateNextKickText()
    self.frame:Show()
end

function CoiledAltarKicker:OnSpellcastStart(_, unit)
    if not self.encounterActive then
        return
    end

    local stream
    for _, candidate in ipairs(self.streams) do
        if candidate.active and unit == ("boss" .. candidate.unitIndex) then
            stream = candidate
            break
        end
    end
    if not stream then
        return
    end

    stream.observed = true
    if not stream.initialCastIgnored then
        stream.initialCastIgnored = true
        self:UpdateDisplay()
        return
    end

    stream.castCount = stream.castCount + 1
    local assigned = self:GetCurrentAssignment(stream)
    self:UpdateDisplay()
    if assigned and self:IsMe(assigned) then
        self:PlayConfiguredAudio()
    end
end

function CoiledAltarKicker:MarkPresentStreamsObserved()
    local changed = false
    for _, stream in ipairs(self.streams) do
        if stream.active
            and not stream.observed
            and UnitExists("boss" .. stream.unitIndex)
        then
            stream.observed = true
            changed = true
        end
    end
    return changed
end

function CoiledAltarKicker:GetHighestTrackedBossFrame()
    local highest = 2
    for index = 3, 6 do
        if UnitExists("boss" .. index) then
            highest = index
        end
    end
    return highest
end

function CoiledAltarKicker:ShiftAfterLowestBossDies()
    local removedIndex = 3
    for _, stream in ipairs(self.streams) do
        if stream.active then
            if stream.unitIndex == removedIndex then
                stream.active = false
            elseif stream.unitIndex > removedIndex then
                stream.unitIndex = stream.unitIndex - 1
            end
        end
    end
end

function CoiledAltarKicker:ReconcileBossFrames()
    if not self.encounterActive then
        return
    end

    local observedChanged = self:MarkPresentStreamsObserved()
    local highest = self:GetHighestTrackedBossFrame()
    if not self.currentHighestBossFrame then
        self.currentHighestBossFrame = highest
        if observedChanged then
            self:UpdateDisplay()
        end
        return
    end

    if highest > self.currentHighestBossFrame then
        self.currentHighestBossFrame = highest
        self:UpdateDisplay()
    elseif highest < self.currentHighestBossFrame then
        local removed = self.currentHighestBossFrame - highest
        for _ = 1, removed do
            self:ShiftAfterLowestBossDies()
        end
        self.currentHighestBossFrame = highest
        self:UpdateDisplay()
    elseif observedChanged then
        self:UpdateDisplay()
    end
end

function CoiledAltarKicker:OnBossFramesChanged()
    if not self.encounterActive then
        return
    end
    C_Timer.After(0.1, function()
        self:ReconcileBossFrames()
    end)
    C_Timer.After(0.5, function()
        self:ReconcileBossFrames()
    end)
end

function CoiledAltarKicker:OnFocusChanged()
    if not self.encounterActive then
        return
    end
    self:UpdateDisplay()
    C_Timer.After(0.1, function()
        if self.encounterActive then
            self:UpdateDisplay()
        end
    end)
end

function CoiledAltarKicker:OnNoteChanged()
    if self.previewMode then
        return
    end
    self:ParseAssignments()
    self:UpdateDisplay()
end

function CoiledAltarKicker:OnEncounterStart(_, encounterID)
    if tonumber(encounterID) ~= ENCOUNTER_ID then
        return
    end
    self.encounterActive = true
    self:ResetStreams()
    self:ParseAssignments()
    self:MarkPresentStreamsObserved()
    self.currentHighestBossFrame = self:GetHighestTrackedBossFrame()
    self:RegisterEvent("UNIT_SPELLCAST_START", "OnSpellcastStart")
    self:RegisterEvent("UNIT_DIED", "OnBossFramesChanged")
    self:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT", "OnBossFramesChanged")
    self:RegisterEvent("PLAYER_FOCUS_CHANGED", "OnFocusChanged")
    self:UpdateDisplay()
end

function CoiledAltarKicker:OnEncounterEnd(_, encounterID)
    if tonumber(encounterID) ~= ENCOUNTER_ID then
        return
    end
    self.encounterActive = false
    self:ResetStreams()
    self:UnregisterEvent("UNIT_SPELLCAST_START")
    self:UnregisterEvent("UNIT_DIED")
    self:UnregisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
    self:UnregisterEvent("PLAYER_FOCUS_CHANGED")
    self:UpdateDisplay()
end

function CoiledAltarKicker:SetEditMode(value)
    self.editMode = value and true or false
    self:EnsureFrame()
    if self.editMode and not self.encounterActive and not self.previewMode then
        self:ParseAssignments()
    end
    self.frame:EnableMouse(self.editMode)
    self:ApplyAppearance()
    self:UpdateDisplay()
end

function CoiledAltarKicker:SetPreviewMode(value)
    if self.encounterActive then
        self.previewMode = false
        return
    end
    self.previewMode = value and true or false
    if self.previewMode then
        self.assignments = {
            {"Tankone", "Healertwo", "Dpsone", "Dpstwo", "Dpsthree"},
            {"Tanktwo", "Healerone", "Dpsfour", "Dpsfive", "Dpssix", "Dpsseven", "Dpseight"}
        }
        self.backupAssignments = {"Backupone", "Backuptwo"}
        self:ResetStreams()
        self.streams[1].castCount = 3
        self.streams[2].castCount = 5
        self.streams[3].castCount = 1
        self.streams[4].castCount = 4
    elseif self.encounterActive then
        self:ParseAssignments()
    else
        self.assignments = {{}, {}}
        self.backupAssignments = {nil, nil}
        self:ResetStreams()
    end
    self:UpdateDisplay()
end

function CoiledAltarKicker:Refresh()
    self:EnsureDefaults()
    self:EnsureFrame()
    self:ApplyAppearance()
    self:ApplyPosition()
    self:UpdateDisplay()
end

function CoiledAltarKicker:OnInitialize()
    self.encounterActive = false
    self.editMode = false
    self.previewMode = false
    self.assignments = {{}, {}}
    self.backupAssignments = {nil, nil}
    self:ResetStreams()
    self:EnsureDefaults()
    self:EnsureFrame()
end

function CoiledAltarKicker:OnEnable()
    self:EnsureFrame()
    self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
    self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
    self:RegisterMessage("ART_NOTE_CHANGED", "OnNoteChanged")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Refresh")
    self:Refresh()
end

function CoiledAltarKicker:OnDisable()
    self.encounterActive = false
    self.editMode = false
    self.previewMode = false
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    if self.frame then
        self.frame:EnableMouse(false)
        self.frame:Hide()
    end
    if self.nextKickFrame then
        self.nextKickFrame:Hide()
    end
end

E:RegisterBossModFeature("CoiledAltarKicker", {
    tab = "AbyssCustom",
    order = 90,
    labelKey = "BossMods_CoiledAltarKicker",
    descKey = "BossMods_CoiledAltarKickerDesc",
    moduleName = "BossMods_CoiledAltarKicker"
})
