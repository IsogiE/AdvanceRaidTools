local E, L = unpack(ART)

local MODULE_NAME = "BossMods_UlatekIntermission"

E:RegisterModuleDefaults(MODULE_NAME, {
    enabled = true,
    textOnly = false,
    bar = {
        position = {point = "CENTER", x = 0, y = 220},
        width = 420,
        height = 26,
        scale = 1,
        opacity = 1,
        texture = "Blizzard",
        color = {0.16, 0.58, 0.92, 1},
        backgroundOpacity = 0.7,
        markerWidth = 5,
        font = {
            name = "Friz Quadrata TT",
            size = 14,
            outline = "OUTLINE",
            color = {1, 1, 1, 1}
        }
    },
    assignment = {
        position = {point = "CENTER", x = 0, y = 150},
        font = {
            name = "Friz Quadrata TT",
            size = 30,
            outline = "OUTLINE",
            color = {1, 1, 1, 1}
        }
    },
    clicker = {
        position = {point = "CENTER", x = 0, y = 80},
        scale = 1,
        opacity = 1
    }
})

local ENCOUNTER_ID = 3492
local INSTANCE_ID = 3004
local SPELL_SPECTRAL_COILS = 1300530
local DURATION = 25
local CLICK_WINDOW = 5
local DUPLICATE_WINDOW = 2
local CLICKER_BUTTON_SIZE = 40
local CLICKER_BUTTON_SPACING = 5
local MAX_ASSIGNMENT_SLOTS = 3
local UPDATE_STATE_KEY = "UlatekIntermission:UpdateState"
local DEBUG_LOCAL_TEST = false

local WHITE = [[Interface\Buttons\WHITE8x8]]
local RAID_MARKER_TEXTURE = [[Interface\TargetingFrame\UI-RaidTargetingIcon_%d]]
local ASSIGNMENT_MARKER_MARKUP = [[|TInterface\TargetingFrame\UI-RaidTargetingIcon_%d:30:30|t]]
local ASSIGNMENT_ICON_WIDTH = 30

local DEFAULT_BAR_POSITION = {point = "CENTER", x = 0, y = 220}
local DEFAULT_ASSIGNMENT_POSITION = {point = "CENTER", x = 0, y = 150}
local DEFAULT_CLICKER_POSITION = {point = "CENTER", x = 0, y = 80}
local DEFAULT_FONT_COLOR = {1, 1, 1, 1}
local DEFAULT_BAR_COLOR = {0.16, 0.58, 0.92, 1}
local DEFAULT_MARKER_COLOR = {1, 1, 1, 1}

local GROUP_COLORS = {
    [1] = {0.92, 0.92, 0.86, 1},
    [2] = {1, 0.48, 0.74, 1},
    [3] = {0.78, 0.04, 0.16, 1}
}

local FIXED_MARKERS = {
    {remaining = 17, group = 1},
    {remaining = 15.5, group = 2},
    {remaining = 12, group = 3},
    {remaining = 10.5, group = 1},
    {remaining = 6, group = 2},
    {remaining = 4, group = 3},
    {remaining = 2.5, group = 1},
    {remaining = 0, group = 2}
}

local ASSIGNMENT_TIMINGS = {{}, {}, {}}
for _, data in ipairs(FIXED_MARKERS) do
    ASSIGNMENT_TIMINGS[data.group][#ASSIGNMENT_TIMINGS[data.group] + 1] =
        DURATION - data.remaining
end

local VARIATIONS = {
    PINK = {
        markerID = 7,
        groups = {
            {7, 2, 1},
            {3, 8, 5},
            {4, 6}
        }
    },
    WHITE = {
        markerID = 4,
        groups = {
            {2, 1, 8},
            {4, 5, 6},
            {7, 3}
        }
    },
    RED = {
        markerID = 1,
        groups = {
            {1, 8, 7},
            {3, 4, 5},
            {6, 2}
        }
    }
}
local BUTTON_ORDER = {"PINK", "WHITE", "RED"}
local CHAT_PAYLOADS = {
    PINK = "%s",
    WHITE = "%.0s%s",
    RED = "%.0s%.0s%s"
}

local UlatekIntermission = E:NewModule(MODULE_NAME, "AceEvent-3.0", "AceTimer-3.0")
local BossMods

local function formatCountdown(remaining)
    remaining = tonumber(remaining) or 0
    if remaining % 1 == 0 then
        return tostring(math.floor(remaining))
    end

    return ("%.1f"):format(remaining)
end

local function formatAssignmentCountdown(remaining)
    return ("%.1f"):format(math.max(0, tonumber(remaining) or 0))
end

local function sequenceMarkup(sequence)
    local result = {}
    for index, markerID in ipairs(sequence or {}) do
        result[#result + 1] = ASSIGNMENT_MARKER_MARKUP:format(markerID)
        if index < #sequence then
            result[#result + 1] = " Into "
        end
    end

    return table.concat(result)
end

local function buildVisibleSequence(sequence, indexes)
    local result = {}
    for _, sourceIndex in ipairs(indexes or {}) do
        result[#result + 1] = sequence[sourceIndex]
    end

    return result
end

local function copyPosition(position, fallback)
    fallback = fallback or DEFAULT_BAR_POSITION
    position = type(position) == "table" and position or fallback

    return {
        point = position.point or fallback.point or "CENTER",
        relPoint = position.relPoint,
        x = tonumber(position.x) or fallback.x or 0,
        y = tonumber(position.y) or fallback.y or 0
    }
end

local function ensurePosition(db, key, fallback)
    if type(db[key]) ~= "table" then
        db[key] = copyPosition(fallback, fallback)
        return
    end

    db[key].point = db[key].point or fallback.point or "CENTER"
    db[key].x = tonumber(db[key].x) or fallback.x or 0
    db[key].y = tonumber(db[key].y) or fallback.y or 0
end

local function ensureColor(value, fallback)
    if type(value) == "table" then
        return value
    end

    return {
        fallback[1] or 1,
        fallback[2] or 1,
        fallback[3] or 1,
        fallback[4] or 1
    }
end

local function ensureFont(font, defaultSize)
    font = type(font) == "table" and font or {}
    font.name = font.name or "Friz Quadrata TT"
    font.size = math.floor((tonumber(font.size) or defaultSize) + 0.5)
    font.outline = font.outline or "OUTLINE"
    font.color = ensureColor(font.color, DEFAULT_FONT_COLOR)
    return font
end

local function currentLocationIsSupported()
    if DEBUG_LOCAL_TEST then
        return true
    end

    local _, _, _, _, _, _, _, mapID = GetInstanceInfo()
    return mapID == INSTANCE_ID
end

function UlatekIntermission:EnsureDefaults()
    self.db.textOnly = self.db.textOnly == true
    self.db.bar = type(self.db.bar) == "table" and self.db.bar or {}
    self.db.assignment = type(self.db.assignment) == "table" and self.db.assignment or {}
    self.db.clicker = type(self.db.clicker) == "table" and self.db.clicker or {}

    ensurePosition(self.db.bar, "position", DEFAULT_BAR_POSITION)
    ensurePosition(self.db.assignment, "position", DEFAULT_ASSIGNMENT_POSITION)
    ensurePosition(self.db.clicker, "position", DEFAULT_CLICKER_POSITION)

    self.db.bar.width = math.max(180, tonumber(self.db.bar.width) or 420)
    self.db.bar.height = math.max(10, tonumber(self.db.bar.height) or 26)
    self.db.bar.scale = tonumber(self.db.bar.scale) or 1
    self.db.bar.opacity = tonumber(self.db.bar.opacity) or 1
    self.db.bar.texture = self.db.bar.texture or "Blizzard"
    self.db.bar.color = ensureColor(self.db.bar.color, DEFAULT_BAR_COLOR)
    self.db.bar.backgroundOpacity = tonumber(self.db.bar.backgroundOpacity) or 0.7
    self.db.bar.markerWidth = math.max(1, tonumber(self.db.bar.markerWidth) or 5)
    self.db.bar.font = ensureFont(self.db.bar.font, 14)

    self.db.assignment.font = ensureFont(self.db.assignment.font, 30)

    self.db.clicker.scale = tonumber(self.db.clicker.scale) or 1
    self.db.clicker.opacity = tonumber(self.db.clicker.opacity) or 1
end

function UlatekIntermission:CreateAnchor(name, enableMouse)
    local anchor = CreateFrame(
        "Frame",
        name,
        UIParent,
        "DisableUntrustedLayoutScriptsTemplate"
    )
    anchor:SetClampedToScreen(true)
    anchor:SetFrameStrata("HIGH")
    anchor:EnableMouse(enableMouse == true)
    anchor:Hide()
    return anchor
end

function UlatekIntermission:EnsureFrames()
    if self.frames then
        return true
    end
    if InCombatLockdown() then
        return false
    end

    local barAnchor = self:CreateAnchor("ART_UlatekIntermissionBar", false)
    local bar = CreateFrame("StatusBar", nil, barAnchor, "BackdropTemplate")
    bar:SetAllPoints(barAnchor)
    bar:SetMinMaxValues(0, DURATION)
    bar:SetValue(0)
    bar:SetBackdrop({
        bgFile = E.media.blankTex or WHITE,
        insets = {left = 0, right = 0, top = 0, bottom = 0}
    })

    local barLabel = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    barLabel:SetPoint("LEFT", bar, "LEFT", 6, 0)
    barLabel:SetJustifyH("LEFT")

    local barTime = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    barTime:SetPoint("RIGHT", bar, "RIGHT", -6, 0)
    barTime:SetJustifyH("RIGHT")

    local barMarkers = {}
    for index, data in ipairs(FIXED_MARKERS) do
        local marker = bar:CreateTexture(nil, "OVERLAY", nil, 7)
        marker:SetTexture(WHITE)
        marker:SetVertexColor(
            unpack(GROUP_COLORS[data.group] or DEFAULT_MARKER_COLOR)
        )
        E:DisableSharpening(marker)
        barMarkers[index] = marker
    end

    local assignmentAnchor = self:CreateAnchor(
        "ART_UlatekIntermissionAssignment",
        false
    )
    local assignmentText = assignmentAnchor:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlight"
    )
    assignmentText:SetPoint("TOP", assignmentAnchor, "TOP", 0, 0)
    assignmentText:SetJustifyH("CENTER")
    assignmentText:SetJustifyV("MIDDLE")
    assignmentText:Hide()

    local assignmentMeasure = assignmentAnchor:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlight"
    )
    assignmentMeasure:Hide()

    local assignmentCountdowns = {}
    for index = 1, MAX_ASSIGNMENT_SLOTS do
        local countdown = assignmentAnchor:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontHighlight"
        )
        countdown:SetJustifyH("CENTER")
        countdown:SetJustifyV("TOP")
        countdown:Hide()
        assignmentCountdowns[index] = countdown
    end

    local clickerWidth = #BUTTON_ORDER * CLICKER_BUTTON_SIZE
        + (#BUTTON_ORDER - 1) * CLICKER_BUTTON_SPACING
    local clickerAnchor = CreateFrame(
        "Frame",
        "ART_UlatekIntermissionClicker",
        UIParent,
        "SecureHandlerStateTemplate"
    )
    clickerAnchor:SetSize(clickerWidth, CLICKER_BUTTON_SIZE)
    clickerAnchor:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    clickerAnchor:SetClampedToScreen(true)
    clickerAnchor:SetFrameStrata("HIGH")
    clickerAnchor:Hide()

    local clickerButtons = {}
    for index, variationKey in ipairs(BUTTON_ORDER) do
        local variation = VARIATIONS[variationKey]
        local button = CreateFrame(
            "Button",
            "ART_UlatekIntermission_Btn" .. index,
            clickerAnchor,
            "SecureActionButtonTemplate"
        )
        button:SetSize(CLICKER_BUTTON_SIZE, CLICKER_BUTTON_SIZE)
        button:SetPoint(
            "LEFT",
            clickerAnchor,
            "LEFT",
            (index - 1) * (CLICKER_BUTTON_SIZE + CLICKER_BUTTON_SPACING),
            0
        )
        button:SetAttribute("type1", "macro")
        button:SetAttribute(
            "macrotext1",
            (DEBUG_LOCAL_TEST and "/say " or "/raid ")
                .. CHAT_PAYLOADS[variationKey]
        )
        button:RegisterForClicks("AnyUp", "AnyDown")
        button:SetFrameStrata("MEDIUM")
        button:SetFrameLevel(5)

        local outer = button:CreateTexture(nil, "BACKGROUND")
        outer:SetAllPoints()
        outer:SetColorTexture(0.3, 0.3, 0.3, 1)

        local inner = button:CreateTexture(nil, "BORDER")
        inner:SetPoint("TOPLEFT", 1, -1)
        inner:SetPoint("BOTTOMRIGHT", -1, 1)
        inner:SetColorTexture(0, 0, 0, 1)

        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
        icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
        icon:SetTexture(RAID_MARKER_TEXTURE:format(variation.markerID))

        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints(button)
        highlight:SetColorTexture(1, 1, 1, 0.3)
        highlight:SetBlendMode("ADD")

        clickerButtons[index] = button
    end

    barAnchor:SetScript("OnUpdate", function()
        self:UpdateDisplay()
    end)

    self.frames = {
        barAnchor = barAnchor,
        bar = bar,
        barLabel = barLabel,
        barTime = barTime,
        barMarkers = barMarkers,
        assignmentAnchor = assignmentAnchor,
        assignmentText = assignmentText,
        assignmentMeasure = assignmentMeasure,
        assignmentCountdowns = assignmentCountdowns,
        clickerAnchor = clickerAnchor,
        clickerButtons = clickerButtons
    }

    self.barAnchor = barAnchor
    self.assignmentAnchor = assignmentAnchor
    self.clickerAnchor = clickerAnchor

    self:ApplySettings()
    return true
end

function UlatekIntermission:ApplySettings()
    if not self.frames then
        return
    end

    self:EnsureDefaults()

    local f = self.frames
    local barDB = self.db.bar
    local assignmentDB = self.db.assignment
    local clickDB = self.db.clicker

    local barWidth = math.max(180, tonumber(barDB.width) or 420)
    local barHeight = math.max(10, tonumber(barDB.height) or 26)
    local markerWidth = math.max(1, tonumber(barDB.markerWidth) or 5)
    local barR, barG, barB, barA = E:ColorTuple(barDB.color, 1, 1, 1, 1)
    local textR, textG, textB, textA = E:ColorTuple(
        barDB.font.color,
        1,
        1,
        1,
        1
    )

    f.barAnchor:SetSize(barWidth, barHeight)
    f.barAnchor:SetScale(tonumber(barDB.scale) or 1)
    f.barAnchor:SetAlpha(tonumber(barDB.opacity) or 1)
    E:ApplyFramePosition(f.barAnchor, barDB.position)

    f.bar:SetMinMaxValues(0, DURATION)
    f.bar:SetStatusBarTexture(E:FetchStatusBar(barDB.texture))
    f.bar:SetStatusBarColor(barR, barG, barB, barA)
    f.bar:SetBackdropColor(0, 0, 0, tonumber(barDB.backgroundOpacity) or 0.7)

    local barFont = E:FetchFont(barDB.font.name)
    E:ApplyFontString(f.barLabel, barFont, barDB.font.size, barDB.font.outline)
    E:ApplyFontString(f.barTime, barFont, barDB.font.size, barDB.font.outline)
    f.barLabel:SetText(L["BossMods_NoteUTIntermission"])
    f.barLabel:SetTextColor(textR, textG, textB, textA)
    f.barTime:SetTextColor(textR, textG, textB, textA)

    for index, data in ipairs(FIXED_MARKERS) do
        local marker = f.barMarkers[index]
        if marker then
            marker:SetVertexColor(
                unpack(GROUP_COLORS[data.group] or DEFAULT_MARKER_COLOR)
            )
            local x = barWidth * data.remaining / DURATION
            x = math.max(markerWidth / 2, math.min(barWidth - markerWidth / 2, x))

            marker:ClearAllPoints()
            marker:SetPoint("CENTER", f.bar, "LEFT", x, 0)
            marker:SetSize(markerWidth, barHeight)
        end
    end

    local assignmentSize = math.max(12, tonumber(assignmentDB.font.size) or 30)
    local assignmentR, assignmentG, assignmentB, assignmentA = E:ColorTuple(
        assignmentDB.font.color,
        1,
        1,
        1,
        1
    )
    local countdownSize = math.max(14, math.floor(assignmentSize * 0.7 + 0.5))
    local rowHeight = math.max(40, assignmentSize + 10)
    local assignmentHeight = rowHeight + countdownSize + 12
    local assignmentWidth = 700

    f.assignmentAnchor:SetSize(assignmentWidth, math.max(60, assignmentHeight))
    E:ApplyFramePosition(f.assignmentAnchor, assignmentDB.position)

    local assignmentFont = E:FetchFont(assignmentDB.font.name)
    E:ApplyFontString(
        f.assignmentText,
        assignmentFont,
        assignmentSize,
        assignmentDB.font.outline
    )
    f.assignmentText:SetTextColor(
        assignmentR,
        assignmentG,
        assignmentB,
        assignmentA
    )
    f.assignmentText:ClearAllPoints()
    f.assignmentText:SetPoint("TOP", f.assignmentAnchor, "TOP", 0, -2)
    f.assignmentText:SetSize(assignmentWidth, rowHeight)

    E:ApplyFontString(
        f.assignmentMeasure,
        assignmentFont,
        assignmentSize,
        assignmentDB.font.outline
    )
    f.assignmentMeasure:SetText(" Into ")

    for _, countdown in ipairs(f.assignmentCountdowns or {}) do
        E:ApplyFontString(
            countdown,
            assignmentFont,
            countdownSize,
            assignmentDB.font.outline
        )
        countdown:SetTextColor(
            assignmentR,
            assignmentG,
            assignmentB,
            assignmentA
        )
        countdown:SetSize(80, countdownSize + 4)
    end

    self.assignmentLayout = {
        connectorWidth = math.max(
            assignmentSize * 1.2,
            f.assignmentMeasure:GetStringWidth()
        ),
        countdownOffsetY = -(rowHeight + 17),
        iconWidth = ASSIGNMENT_ICON_WIDTH,
        width = assignmentWidth
    }

    if not InCombatLockdown() then
        f.clickerAnchor:SetScale(tonumber(clickDB.scale) or 1)
        f.clickerAnchor:SetAlpha(tonumber(clickDB.opacity) or 1)
        E:ApplyFramePosition(f.clickerAnchor, clickDB.position)
    end
end

function UlatekIntermission:GetAssignments()
    BossMods = BossMods or E:GetModule("BossMods", true)

    local Ready = BossMods and BossMods.ReadyAssignments
    if not (Ready and Ready.BuildContext and Ready.FindPlayerInHashTag) then
        return nil, false
    end

    local Nicknames = E:GetModule("Nicknames", true)
    if Nicknames and Nicknames.SyncSelfNickname then
        Nicknames:SyncSelfNickname()
    end

    local context = Ready:BuildContext()
    local group
    for index = 1, 3 do
        if Ready:FindPlayerInHashTag(context, "UTInt" .. index, {
            hashtagMultiline = true
        }) then
            group = index
            break
        end
    end

    local caller = Ready:FindPlayerInHashTag(context, "UTIntClicker", {
        hashtagMultiline = true
    })

    return group, caller ~= nil
end

function UlatekIntermission:IsClickWindowOpen()
    if DEBUG_LOCAL_TEST then
        return true
    end

    if not self.activeStartedAt then
        return false
    end

    local now = GetTime()
    return now >= self.activeStartedAt and now < self.activeStartedAt + CLICK_WINDOW
end

function UlatekIntermission:OnChatMsg(_, msg)
    if not DEBUG_LOCAL_TEST
        and (not self.encounterActive or not self:IsClickWindowOpen())
    then
        return
    end

    if DEBUG_LOCAL_TEST then
        self.encounterActive = true
        self.playerGroup, self.isCaller = self:GetAssignments()
        self.activeStartedAt = GetTime()
    end

    if not self.playerGroup then
        return
    end

    self.assignmentMessage = msg
    self:UpdateDisplay()
end

function UlatekIntermission:StartIntermissionBar()
    if not self.encounterActive and not DEBUG_LOCAL_TEST then
        return
    end

    self.activeStartedAt = GetTime()
    self.assignmentMessage = nil
    self.playerGroup, self.isCaller = self:GetAssignments()
    self:UpdateDisplay()
end

function UlatekIntermission:CancelPendingCoils()
    if self.pendingCoils and self.pendingCoils.timer then
        self:CancelTimer(self.pendingCoils.timer)
    end

    self.pendingCoils = nil
end

function UlatekIntermission:ScheduleFromCoils(duration)
    duration = tonumber(duration)
    if not self.encounterActive
        or not duration
        or duration < 0
        or (not self.waitingForIntermissionCoils and not self.pendingCoils)
    then
        return
    end

    local target = GetTime() + duration

    if self.pendingCoils then
        if math.abs((self.pendingCoils.target or 0) - target) > DUPLICATE_WINDOW then
            return
        end

        self:CancelPendingCoils()
    elseif self.intermissionCoilsClaimed then
        return
    end

    self.intermissionCoilsClaimed = true
    self.waitingForIntermissionCoils = false

    local timer
    timer = self:ScheduleTimer(function()
        if self.pendingCoils and self.pendingCoils.timer == timer then
            self.pendingCoils = nil
        end
        self:StartIntermissionBar()
    end, duration)

    self.pendingCoils = {
        timer = timer,
        target = target
    }
end

function UlatekIntermission:OnBigWigsStartBar(key, _, duration)
    if key == SPELL_SPECTRAL_COILS
        or tonumber(key) == SPELL_SPECTRAL_COILS
    then
        self:ScheduleFromCoils(duration)
    end
end

function UlatekIntermission:OnBigWigsStage(moduleInfo, stage)
    if not self.encounterActive
        or not moduleInfo
        or moduleInfo.moduleName ~= "Ula'tek"
    then
        return
    end

    stage = tonumber(stage)
    if stage == 2.5 then
        self.waitingForIntermissionCoils = true
        self.intermissionCoilsClaimed = false
        self.assignmentMessage = nil
        self:CancelPendingCoils()
    elseif stage and stage >= 3 then
        self.waitingForIntermissionCoils = false
        self:CancelPendingCoils()
    end
end

function UlatekIntermission:ShouldShowClicker()
    if self.editMode then
        return true
    end

    local normalAvailable = currentLocationIsSupported() or self.encounterActive
    return normalAvailable and self.isCaller
end

function UlatekIntermission:ApplyClickerInteraction()
    if not self.frames or InCombatLockdown() then
        return
    end

    for _, button in ipairs(self.frames.clickerButtons) do
        button:EnableMouse(not self.editMode)
    end
end

function UlatekIntermission:ApplyClickerVisibility()
    if not self.frames then
        return
    end

    local shown = self:ShouldShowClicker()
    if InCombatLockdown() then
        if shown ~= self.frames.clickerAnchor:IsShown() then
            E:RunWhenOutOfCombat(UPDATE_STATE_KEY, function()
                if self:IsEnabled() then
                    self:UpdateState()
                end
            end)
        end
        return
    end

    self.frames.clickerAnchor:SetShown(shown)
    self:ApplyClickerInteraction()
end

function UlatekIntermission:HideAssignmentSlots()
    if not self.frames then
        return
    end

    self.frames.assignmentText:Hide()
    for _, countdown in ipairs(self.frames.assignmentCountdowns or {}) do
        countdown:Hide()
    end
end

function UlatekIntermission:UpdateAssignmentSlots(formatMessage, group, elapsed)
    if not self.frames then
        return false
    end

    local pink = VARIATIONS.PINK.groups[group]
    local white = VARIATIONS.WHITE.groups[group]
    local red = VARIATIONS.RED.groups[group]
    local timings = ASSIGNMENT_TIMINGS[group]

    if not formatMessage or not pink or not white or not red or not timings then
        self:HideAssignmentSlots()
        return false
    end

    local totalCount = math.min(#pink, #white, #red, #timings, MAX_ASSIGNMENT_SLOTS)
    if totalCount <= 0 then
        self:HideAssignmentSlots()
        return false
    end

    local f = self.frames
    local layout = self.assignmentLayout or {}
    local connectorWidth = layout.connectorWidth or 40
    elapsed = tonumber(elapsed) or 0

    local activeIndexes = {}
    local activeTimeLeft = {}
    for index = 1, totalCount do
        local timeLeft = (tonumber(timings[index]) or 0) - elapsed
        if timeLeft > 0 then
            activeIndexes[#activeIndexes + 1] = index
            activeTimeLeft[#activeTimeLeft + 1] = timeLeft
        end
    end

    local count = #activeIndexes
    if count <= 0 then
        self:HideAssignmentSlots()
        return false
    end

    f.assignmentText:SetFormattedText(
        formatMessage,
        sequenceMarkup(buildVisibleSequence(pink, activeIndexes)),
        sequenceMarkup(buildVisibleSequence(white, activeIndexes)),
        sequenceMarkup(buildVisibleSequence(red, activeIndexes))
    )
    f.assignmentText:Show()

    local rowWidth = f.assignmentText:GetStringWidth()
    if not rowWidth or rowWidth <= 0 then
        rowWidth = count * ASSIGNMENT_ICON_WIDTH + (count - 1) * connectorWidth
    end

    local iconWidth = (rowWidth - (count - 1) * connectorWidth) / count
    iconWidth = math.max(layout.iconWidth or ASSIGNMENT_ICON_WIDTH, iconWidth)

    local x = -rowWidth / 2 + iconWidth / 2
    for index = 1, MAX_ASSIGNMENT_SLOTS do
        local countdown = f.assignmentCountdowns[index]

        if countdown and index <= count then
            countdown:ClearAllPoints()
            countdown:SetPoint(
                "TOP",
                f.assignmentAnchor,
                "TOP",
                x,
                layout.countdownOffsetY or -(ASSIGNMENT_ICON_WIDTH + 12)
            )
            local timeLeft = activeTimeLeft[index]
            if timeLeft > 0 then
                countdown:SetText(formatAssignmentCountdown(timeLeft))
                countdown:Show()
            else
                countdown:Hide()
            end

            x = x + iconWidth + connectorWidth
        elseif countdown then
            countdown:Hide()
        end
    end

    return true
end

function UlatekIntermission:HideDisplay()
    if not self.frames then
        return
    end

    self.frames.barAnchor:Hide()
    self.frames.assignmentAnchor:Hide()
    self:HideAssignmentSlots()
    self:ApplyClickerVisibility()
end

function UlatekIntermission:UpdateDisplay()
    if not self.frames then
        return
    end

    local editMode = self.editMode == true
    local elapsed = editMode
        and 0
        or (self.activeStartedAt and GetTime() - self.activeStartedAt)
    local active = editMode or (elapsed and elapsed >= 0 and elapsed <= DURATION)

    if not active then
        if not editMode then
            self.activeStartedAt = nil
            self.assignmentMessage = nil
        end
        self:HideDisplay()
        return
    end

    local f = self.frames
    local remaining = editMode and DURATION or math.max(0, DURATION - elapsed)

    f.bar:SetValue(remaining)
    if remaining % 1 == 0 then
        f.barTime:SetText(tostring(math.floor(remaining)))
    else
        f.barTime:SetText(("%.1f"):format(remaining))
    end
    f.bar:SetShown(self.db.textOnly ~= true)
    f.barAnchor:Show()

    if editMode then
        self:UpdateAssignmentSlots(CHAT_PAYLOADS.PINK, 1, 0)
        f.assignmentAnchor:Show()
    elseif self.assignmentMessage
        and self.playerGroup
        and self:UpdateAssignmentSlots(
            self.assignmentMessage,
            self.playerGroup,
            elapsed
        )
    then
        f.assignmentAnchor:Show()
    else
        self:HideAssignmentSlots()
        f.assignmentAnchor:Hide()
    end

    self:ApplyClickerVisibility()
end

function UlatekIntermission:SetEditMode(value)
    if not self:IsEnabled() then
        return
    end
    if value and not self.frames then
        self:UpdateState()
    end

    self.editMode = value and true or false

    self:UpdateDisplay()
    self:ApplyClickerInteraction()
end

function UlatekIntermission:SavePosition(kind, position)
    self:EnsureDefaults()

    if not self.db[kind] or type(self.db[kind].position) ~= "table" then
        return
    end

    self.db[kind].position = copyPosition(position, self.db[kind].position)
    self:ApplySettings()
end

function UlatekIntermission:Refresh()
    if not self:IsEnabled() then
        return
    end

    self:UpdateState()
end

function UlatekIntermission:HookBigWigs()
    if self.bigWigsSubscription then
        return
    end

    BossMods = BossMods or E:GetModule("BossMods", true)
    if not (BossMods and BossMods.BigWigs and BossMods.BigWigs.Subscribe) then
        return
    end

    self.bigWigsSubscription = BossMods.BigWigs:Subscribe({
        owner = "UlatekIntermission",
        spellKeys = {SPELL_SPECTRAL_COILS},
        onStartBar = function(key, text, duration)
            self:OnBigWigsStartBar(key, text, duration)
        end,
        onStage = function(moduleInfo, stage)
            self:OnBigWigsStage(moduleInfo, stage)
        end
    })
end

function UlatekIntermission:UnhookBigWigs()
    if not self.bigWigsSubscription then
        return
    end

    self.bigWigsSubscription:Unsubscribe()
    self.bigWigsSubscription = nil
end

function UlatekIntermission:StartChatListener()
    self:RegisterEvent("CHAT_MSG_RAID", "OnChatMsg")
    self:RegisterEvent("CHAT_MSG_RAID_LEADER", "OnChatMsg")

    if DEBUG_LOCAL_TEST then
        self:RegisterEvent("CHAT_MSG_SAY", "OnChatMsg")
    end
end

function UlatekIntermission:StopChatListener()
    self:UnregisterEvent("CHAT_MSG_RAID")
    self:UnregisterEvent("CHAT_MSG_RAID_LEADER")
    self:UnregisterEvent("CHAT_MSG_SAY")
end

function UlatekIntermission:UpdateState()
    if not self:IsEnabled() then
        return
    end

    if not self.frames then
        if InCombatLockdown() then
            E:RunWhenOutOfCombat(UPDATE_STATE_KEY, function()
                if self:IsEnabled() then
                    self:UpdateState()
                end
            end)
            return
        end

        if not self:EnsureFrames() then
            return
        end
    end

    self.playerGroup, self.isCaller = self:GetAssignments()
    if DEBUG_LOCAL_TEST then
        self.encounterActive = true
        self:StartChatListener()
    end

    self:ApplySettings()
    self:UpdateDisplay()
end

function UlatekIntermission:OnEncounterStart(_, encounterID)
    if tonumber(encounterID) ~= ENCOUNTER_ID or not currentLocationIsSupported() then
        return
    end

    self.encounterActive = true
    self.waitingForIntermissionCoils = false
    self.intermissionCoilsClaimed = false
    self.activeStartedAt = nil
    self.assignmentMessage = nil
    self.playerGroup, self.isCaller = self:GetAssignments()
    self:CancelPendingCoils()
    self:StartChatListener()
    self:UpdateDisplay()
end

function UlatekIntermission:OnEncounterEnd(_, encounterID)
    if tonumber(encounterID) ~= ENCOUNTER_ID then
        return
    end

    self.encounterActive = false
    self.waitingForIntermissionCoils = false
    self.intermissionCoilsClaimed = false
    self.activeStartedAt = nil
    self.assignmentMessage = nil
    self:CancelPendingCoils()
    self:StopChatListener()
    self:UpdateDisplay()
end

function UlatekIntermission:OnInitialize()
    BossMods = E:GetModule("BossMods", true)

    self.encounterActive = false
    self.editMode = false
    self.waitingForIntermissionCoils = false
    self.intermissionCoilsClaimed = false
    self.assignmentMessage = nil
    self.playerGroup = nil
    self.isCaller = false

    self:EnsureDefaults()

    if not InCombatLockdown() then
        self:EnsureFrames()
        self:HideDisplay()
        if self.frames then
            self.frames.clickerAnchor:Hide()
        end
    end
end

function UlatekIntermission:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateState")
    self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
    self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
    self:RegisterMessage("ART_NOTE_CHANGED", "UpdateState")
    self:RegisterMessage("ART_NICKNAME_CHANGED", "UpdateState")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Refresh")
    self:HookBigWigs()
    self:UpdateState()
end

function UlatekIntermission:OnDisable()
    self:UnhookBigWigs()
    self:StopChatListener()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    self:CancelPendingCoils()

    self.encounterActive = false
    self.editMode = false
    self.waitingForIntermissionCoils = false
    self.intermissionCoilsClaimed = false
    self.activeStartedAt = nil
    self.assignmentMessage = nil
    self.playerGroup = nil
    self.isCaller = false

    self:HideDisplay()
    if self.frames then
        if not InCombatLockdown() then
            self.frames.clickerAnchor:Hide()
        else
            E:RunWhenOutOfCombat("UlatekIntermission:HideClicker", function()
                if not self:IsEnabled() and self.frames then
                    self.frames.clickerAnchor:Hide()
                end
            end)
        end
    end
end

E:RegisterBossModFeature("UlatekIntermission", {
    tab = "AbyssCustom",
    order = 73,
    labelKey = "BossMods_UlatekIntermission",
    descKey = "BossMods_UlatekIntermissionDesc",
    moduleName = MODULE_NAME
})
