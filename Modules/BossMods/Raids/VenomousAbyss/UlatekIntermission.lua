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
    reminder = {
        position = {point = "CENTER", x = 0, y = 150},
        font = {
            name = "Friz Quadrata TT",
            size = 30,
            outline = "OUTLINE",
            color = {1, 1, 1, 1}
        }
    },
    careCircles = {
        enabled = true,
        position = {point = "CENTER", x = 0, y = 150},
        font = {
            name = "Friz Quadrata TT",
            size = 30,
            outline = "OUTLINE",
            color = {1, 1, 1, 1}
        }
    },
    wave = {
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
        hideLeftRight = false,
        scale = 1,
        opacity = 1
    }
})

local ENCOUNTER_ID = 3492
local INSTANCE_ID = 3004
local SPELL_SPECTRAL_COILS = 1300530
local DURATION = 25
local CLICK_WINDOW = 10
local REMINDER_CLICK_START = 160
local REMINDER_CLICK_END = 175
local REMINDER_SHOW_AT = 275
local REMINDER_DURATION = 10
local CARE_CIRCLES_SHOW_AT = 200
local CARE_CIRCLES_DURATION = 3
local DUPLICATE_WINDOW = 2
local CLICKER_BUTTON_SIZE = 40
local CLICKER_BUTTON_SPACING = 5
local WAVE_DIRECTION_DURATION = 8
local WAVE_INPUT_WINDOWS = {
    {kind = "wave", start = 50, finish = 62},
    {kind = "submerge", start = 73.4, finish = 85.4},
    {kind = "secondWave", start = 107, finish = 119}
}
local MAX_ASSIGNMENT_SLOTS = 4
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
    {remaining = 12, group = 1},
    {remaining = 10.5, group = 2},
    {remaining = 6, group = 1},
    {remaining = 4, group = 2},
    {remaining = 2.5, group = 3},
    {remaining = 0, group = 1}
}

-- Note groups are personal routes through the eight numbered soaks.
local GROUP_SOAKS = {
    {1, 3, 5, 8}, -- UTInt1: main odd-soak group, then soak 8
    {2, 4, 6},    -- UTInt2: main even-soak group
    {7},          -- UTInt3: soak 7 only
    {1, 3, 5, 7}, -- UTInt4: odd soaks, then join soak 7
    {2, 4, 7},    -- UTInt5: first two even soaks, then join soak 7
    {2, 4, 6, 8}  -- UTInt6: even soaks, then join soak 8
}
local ASSIGNMENT_TIMINGS = {}
for group, soaks in ipairs(GROUP_SOAKS) do
    ASSIGNMENT_TIMINGS[group] = {}
    for index, soak in ipairs(soaks) do
        ASSIGNMENT_TIMINGS[group][index] = DURATION - FIXED_MARKERS[soak].remaining
    end
end

-- Marker IDs in soak order (1-8), selected by the first soak's marker.
local VARIATIONS = {
    PINK = {
        markerID = 7,
        soaks = {7, 3, 4, 2, 8, 6, 1, 5}
    },
    WHITE = {
        markerID = 4,
        soaks = {4, 2, 7, 5, 1, 3, 6, 8}
    },
    RED = {
        markerID = 1,
        soaks = {1, 3, 6, 8, 4, 2, 7, 5}
    }
}
for _, variation in pairs(VARIATIONS) do
    variation.groups = {}
    for group, soaks in ipairs(GROUP_SOAKS) do
        local sequence = {}
        for index, soak in ipairs(soaks) do
            sequence[index] = variation.soaks[soak]
        end
        variation.groups[group] = sequence
    end
end
local BUTTON_ORDER = {"PINK", "WHITE", "RED"}
local WAVE_BUTTONS = {
    {label = L["Left"], macro = "/rw Left"},
    {label = L["Right"], macro = "/raid Right"}
}
local REMINDER_BUTTONS = {
    {markerID = 5, payload = "%s"},
    {markerID = 6, payload = "%.0s%s"}
}
local CLICKER_HEIGHT = 2 * CLICKER_BUTTON_SIZE + CLICKER_BUTTON_SPACING
local CHAT_PAYLOADS = {
    PINK = "%s",
    WHITE = "%.0s%s",
    RED = "%.0s%.0s%s"
}

for buttonName, labelKey in pairs({
    ART_UlatekP1_Btn1 = "BossMods_UlatekBindingLeft",
    ART_UlatekP1_Btn2 = "BossMods_UlatekBindingRight",
    ART_UlatekReminder_Btn1 = "BossMods_UlatekBindingMoon",
    ART_UlatekReminder_Btn2 = "BossMods_UlatekBindingBlue",
    ART_UlatekIntermission_Btn1 = "BossMods_UlatekBindingCross",
    ART_UlatekIntermission_Btn2 = "BossMods_UlatekBindingTriangle",
    ART_UlatekIntermission_Btn3 = "BossMods_UlatekBindingStar"
}) do
    _G["BINDING_NAME_CLICK " .. buttonName .. ":LeftButton"] = L[labelKey]
end

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
            result[#result + 1] = L["BossMods_UlatekIntermissionSequenceConnector"]
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

local function getPlayerRaidSubgroup()
    local raidIndex = UnitInRaid and UnitInRaid("player")
    if E:IsSecret(raidIndex) or type(raidIndex) ~= "number" then return end

    local subgroup = select(3, GetRaidRosterInfo(raidIndex))
    if E:IsSecret(subgroup) or type(subgroup) ~= "number" then return end
    return subgroup
end

function UlatekIntermission:EnsureDefaults()
    self.db.textOnly = self.db.textOnly == true
    self.db.bar = type(self.db.bar) == "table" and self.db.bar or {}
    self.db.assignment = type(self.db.assignment) == "table" and self.db.assignment or {}
    self.db.reminder = type(self.db.reminder) == "table" and self.db.reminder or {}
    self.db.careCircles = type(self.db.careCircles) == "table" and self.db.careCircles or {}
    self.db.careCircles.enabled = self.db.careCircles.enabled ~= false
    self.db.wave = type(self.db.wave) == "table" and self.db.wave or {}
    self.db.clicker = type(self.db.clicker) == "table" and self.db.clicker or {}

    ensurePosition(self.db.bar, "position", DEFAULT_BAR_POSITION)
    ensurePosition(self.db.assignment, "position", DEFAULT_ASSIGNMENT_POSITION)
    ensurePosition(self.db.reminder, "position", DEFAULT_ASSIGNMENT_POSITION)
    ensurePosition(self.db.careCircles, "position", DEFAULT_ASSIGNMENT_POSITION)
    ensurePosition(self.db.wave, "position", DEFAULT_ASSIGNMENT_POSITION)
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
    self.db.reminder.font = ensureFont(self.db.reminder.font, 30)
    self.db.careCircles.font = ensureFont(self.db.careCircles.font, 30)
    self.db.wave.font = ensureFont(self.db.wave.font, 30)

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

local function createAssignmentRegions(assignmentAnchor)
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

    return assignmentText, assignmentMeasure, assignmentCountdowns
end

local function applyAssignmentAppearance(f, assignmentDB)
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
    f.assignmentMeasure:SetText(L["BossMods_UlatekIntermissionSequenceConnector"])

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

    return {
        connectorWidth = math.max(
            assignmentSize * 1.2,
            f.assignmentMeasure:GetStringWidth()
        ),
        countdownOffsetY = -(rowHeight + 17),
        iconWidth = ASSIGNMENT_ICON_WIDTH,
        width = assignmentWidth
    }
end

local function createClickerArtwork(button, markerID, interactive, labelText)
    local border = button:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints(button)
    border:SetColorTexture(1, 1, 1, 1)
    border:SetVertexColor(0.3, 0.3, 0.3, 1)
    E:DisableSharpening(border)

    local background = button:CreateTexture(nil, "BORDER")
    background:SetColorTexture(0, 0, 0, 1)
    background:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    background:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    E:DisableSharpening(background)

    if labelText then
        local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
        label:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
        label:SetText(labelText)
    else
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
        icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
        icon:SetTexture(RAID_MARKER_TEXTURE:format(markerID))
    end

    if interactive then
        local function clearHighlight()
            border:SetVertexColor(0.3, 0.3, 0.3, 1)
        end
        button:HookScript("OnEnter", function()
            border:SetVertexColor(0.7, 0.7, 0.7, 1)
        end)
        button:HookScript("OnLeave", clearHighlight)
        button:HookScript("OnHide", clearHighlight)
        button:HookScript("OnShow", clearHighlight)
        button.artClearHighlight = clearHighlight
    end
end

local function reminderMarkup(markerID, labelKey)
    return ASSIGNMENT_MARKER_MARKUP:format(markerID) .. " " .. L[labelKey]
end

local function createReminderText(anchor)
    local text = anchor:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetAllPoints(anchor)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    return text
end

local function applyReminderAppearance(anchor, text, db, assignmentDB)
    local assignmentSize = math.max(12, tonumber(assignmentDB.font.size) or 30)
    local rowHeight = math.max(40, assignmentSize + 10)
    local countdownSize = math.max(14, math.floor(assignmentSize * 0.7 + 0.5))
    anchor:SetSize(700, math.max(60, rowHeight + countdownSize + 12))
    text:ClearAllPoints()
    text:SetPoint("TOP", anchor, "TOP", 0, -2)
    text:SetSize(700, rowHeight)
    E:ApplyFontString(text, E:FetchFont(db.font.name), db.font.size, db.font.outline)
    text:SetTextColor(E:ColorTuple(db.font.color, 1, 1, 1, 1))
end

local function positionClickerButton(button, anchor, index, count, row)
    local width = count * CLICKER_BUTTON_SIZE + (count - 1) * CLICKER_BUTTON_SPACING
    button:ClearAllPoints()
    button:SetSize(CLICKER_BUTTON_SIZE, CLICKER_BUTTON_SIZE)
    button:SetPoint("TOPLEFT", anchor, "TOP", -width / 2
        + (index - 1) * (CLICKER_BUTTON_SIZE + CLICKER_BUTTON_SPACING),
        -(row - 1) * (CLICKER_BUTTON_SIZE + CLICKER_BUTTON_SPACING))
end

local function layoutClickerButtons(anchor, buttons, hideLeftRight)
    local waveCount = hideLeftRight and 0 or #WAVE_BUTTONS
    local topRowCount = waveCount + #REMINDER_BUTTONS
    local widestRowCount = math.max(topRowCount, #BUTTON_ORDER)
    anchor:SetSize(widestRowCount * CLICKER_BUTTON_SIZE
        + (widestRowCount - 1) * CLICKER_BUTTON_SPACING, CLICKER_HEIGHT)

    for index = 1, #WAVE_BUTTONS do
        local button = buttons[index]
        button:SetShown(not hideLeftRight)
        if not hideLeftRight then
            positionClickerButton(button, anchor, index, topRowCount, 1)
        end
    end
    for index = 1, #BUTTON_ORDER do
        positionClickerButton(buttons[#WAVE_BUTTONS + index], anchor, index, #BUTTON_ORDER, 2)
    end
    for index = 1, #REMINDER_BUTTONS do
        positionClickerButton(buttons[#WAVE_BUTTONS + #BUTTON_ORDER + index], anchor,
            waveCount + index, topRowCount, 1)
    end
end

local function createBarRegions(barAnchor)
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

    return bar, barLabel, barTime, barMarkers
end

local function applyBarAppearance(f, barDB)
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
end

function UlatekIntermission:EnsureFrames()
    if self.frames then
        return true
    end
    if InCombatLockdown() then
        return false
    end

    local barAnchor = self:CreateAnchor("ART_UlatekIntermissionBar", false)
    local bar, barLabel, barTime, barMarkers = createBarRegions(barAnchor)

    local assignmentAnchor = self:CreateAnchor(
        "ART_UlatekIntermissionAssignment",
        false
    )
    local assignmentText, assignmentMeasure, assignmentCountdowns =
        createAssignmentRegions(assignmentAnchor)

    local reminderAnchor = self:CreateAnchor("ART_UlatekMovementReminder", false)
    local reminderText = createReminderText(reminderAnchor)
    local careCirclesAnchor = self:CreateAnchor("ART_UlatekCareCircles", false)
    local careCirclesText = createReminderText(careCirclesAnchor)
    local waveAnchor = self:CreateAnchor("ART_UlatekWaveDirection", false)
    local waveText = createReminderText(waveAnchor)

    local clickerAnchor = CreateFrame(
        "Frame",
        "ART_UlatekIntermissionClicker",
        UIParent,
        "SecureHandlerStateTemplate"
    )
    clickerAnchor:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    clickerAnchor:SetClampedToScreen(true)
    clickerAnchor:SetFrameStrata("HIGH")
    clickerAnchor:Hide()

    local clickerButtons = {}
    for index, data in ipairs(WAVE_BUTTONS) do
        local button = CreateFrame("Button", "ART_UlatekP1_Btn" .. index,
            clickerAnchor, "SecureActionButtonTemplate")
        button:SetAttribute("type1", "macro")
        button:SetAttribute("macrotext1", data.macro)
        button:RegisterForClicks("AnyUp", "AnyDown")
        button:SetFrameStrata("MEDIUM")
        button:SetFrameLevel(5)
        createClickerArtwork(button, nil, true, data.label)
        clickerButtons[#clickerButtons + 1] = button
    end

    for index, variationKey in ipairs(BUTTON_ORDER) do
        local variation = VARIATIONS[variationKey]
        local button = CreateFrame(
            "Button",
            "ART_UlatekIntermission_Btn" .. index,
            clickerAnchor,
            "SecureActionButtonTemplate"
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

        createClickerArtwork(button, variation.markerID, true)

        clickerButtons[#clickerButtons + 1] = button
    end

    for index, data in ipairs(REMINDER_BUTTONS) do
        local button = CreateFrame("Button", "ART_UlatekReminder_Btn" .. index,
            clickerAnchor, "SecureActionButtonTemplate")
        button:SetAttribute("type1", "macro")
        button:SetAttribute("macrotext1", (DEBUG_LOCAL_TEST and "/say " or "/raid ") .. data.payload)
        button:RegisterForClicks("AnyUp", "AnyDown")
        button:SetFrameStrata("MEDIUM")
        button:SetFrameLevel(5)
        createClickerArtwork(button, data.markerID, true)
        clickerButtons[#clickerButtons + 1] = button
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
        reminderAnchor = reminderAnchor,
        reminderText = reminderText,
        careCirclesAnchor = careCirclesAnchor,
        careCirclesText = careCirclesText,
        waveAnchor = waveAnchor,
        waveText = waveText,
        clickerAnchor = clickerAnchor,
        clickerButtons = clickerButtons
    }

    self.barAnchor = barAnchor
    self.assignmentAnchor = assignmentAnchor
    self.reminderAnchor = reminderAnchor
    self.careCirclesAnchor = careCirclesAnchor
    self.waveAnchor = waveAnchor
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

    applyBarAppearance(f, barDB)
    E:GetModule("BossMods").DisplayTemplates:Place(self, "bar", f.barAnchor)

    self.assignmentLayout = applyAssignmentAppearance(f, assignmentDB)
    E:GetModule("BossMods").DisplayTemplates:Place(self, "assignment", f.assignmentAnchor)

    applyReminderAppearance(f.reminderAnchor, f.reminderText, self.db.reminder, self.db.assignment)
    E:GetModule("BossMods").DisplayTemplates:Place(self, "reminder", f.reminderAnchor)
    applyReminderAppearance(f.careCirclesAnchor, f.careCirclesText, self.db.careCircles, self.db.assignment)
    E:GetModule("BossMods").DisplayTemplates:Place(self, "careCircles", f.careCirclesAnchor)
    applyReminderAppearance(f.waveAnchor, f.waveText, self.db.wave, self.db.assignment)
    E:GetModule("BossMods").DisplayTemplates:Place(self, "wave", f.waveAnchor)

    if not InCombatLockdown() then
        layoutClickerButtons(f.clickerAnchor, f.clickerButtons, clickDB.hideLeftRight == true)
        f.clickerAnchor:SetScale(tonumber(clickDB.scale) or 1)
        f.clickerAnchor:SetAlpha(tonumber(clickDB.opacity) or 1)
        E:GetModule("BossMods").DisplayTemplates:Place(self, "clicker", f.clickerAnchor)
    else
        E:RunWhenOutOfCombat(UPDATE_STATE_KEY, function()
            if self:IsEnabled() then
                self:UpdateState()
            end
        end)
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
    for index = 1, #GROUP_SOAKS do
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

function UlatekIntermission:HandleWaveInput(event)
    if not self.encounterActive or self.encounterDifficulty ~= 16
        or not self.encounterStartedAt then return false end

    local direction
    if event == "CHAT_MSG_RAID_WARNING" then
        direction = "Left"
    elseif event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER" then
        direction = "Right"
    else
        return false
    end

    local elapsed = GetTime() - self.encounterStartedAt
    for _, window in ipairs(WAVE_INPUT_WINDOWS) do
        if elapsed >= window.start and elapsed < window.finish then
            if window.kind ~= "submerge" then
                self.waveDirection = direction
                if self.waveHideTimer then self:CancelTimer(self.waveHideTimer) end
                self.waveHideTimer = self:ScheduleTimer("HideWaveDirection", WAVE_DIRECTION_DURATION)
                self:UpdateWaveDisplay()
            end
            return true
        end
    end
    return false
end

function UlatekIntermission:HideWaveDirection()
    self.waveHideTimer = nil
    self.waveDirection = nil
    self:UpdateWaveDisplay()
end

function UlatekIntermission:OnChatMsg(event, msg)
    if self:HandleWaveInput(event) then return end
    if event == "CHAT_MSG_RAID_WARNING" then return end
    if self.encounterActive and self.encounterStartedAt then
        local elapsed = GetTime() - self.encounterStartedAt
        if elapsed >= REMINDER_CLICK_START and elapsed < REMINDER_CLICK_END then
            if self.frames then
                self.frames.reminderText:SetFormattedText(msg,
                    reminderMarkup(5, "BossMods_UlatekGoToMoon"),
                    reminderMarkup(6, "BossMods_UlatekGoToBlue"), "")
                local subgroup = getPlayerRaidSubgroup()
                self.frames.careCirclesText:SetFormattedText(msg,
                    (subgroup == 3 or subgroup == 4) and L["BossMods_UlatekCareCircles"] or "",
                    (subgroup == 1 or subgroup == 2) and L["BossMods_UlatekCareCircles"] or "", "")
            end
            return
        end
    end

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

function UlatekIntermission:ResetReminder()
    if self.waveHideTimer then
        self:CancelTimer(self.waveHideTimer)
        self.waveHideTimer = nil
    end
    self.waveDirection = nil
    self.encounterDifficulty = nil
    if self.reminderShowTimer then
        self:CancelTimer(self.reminderShowTimer)
        self.reminderShowTimer = nil
    end
    if self.reminderHideTimer then
        self:CancelTimer(self.reminderHideTimer)
        self.reminderHideTimer = nil
    end
    if self.careCirclesShowTimer then
        self:CancelTimer(self.careCirclesShowTimer)
        self.careCirclesShowTimer = nil
    end
    if self.careCirclesHideTimer then
        self:CancelTimer(self.careCirclesHideTimer)
        self.careCirclesHideTimer = nil
    end
    self.encounterStartedAt = nil
    self.reminderVisible = false
    self.careCirclesVisible = false
    if self.frames then
        self.frames.reminderAnchor:Hide()
        self.frames.reminderText:SetText("")
        self.frames.careCirclesAnchor:Hide()
        self.frames.careCirclesText:SetText("")
        self.frames.waveAnchor:Hide()
        self.frames.waveText:SetText("")
    end
end

function UlatekIntermission:ShowReminder()
    self.reminderShowTimer = nil
    if not self.encounterActive then return end
    self.reminderVisible = true
    self:UpdateReminderDisplay()
end

function UlatekIntermission:HideReminder()
    self.reminderHideTimer = nil
    self.reminderVisible = false
    self:UpdateReminderDisplay()
end

function UlatekIntermission:UpdateReminderDisplay()
    if not self.frames then return end
    local f = self.frames
    if self.editMode then
        f.reminderText:SetText(reminderMarkup(5, "BossMods_UlatekGoToMoon"))
    end
    f.reminderAnchor:SetShown(self.editMode or (self.encounterActive and self.reminderVisible) or false)
end

function UlatekIntermission:ShowCareCircles()
    self.careCirclesShowTimer = nil
    if not self.encounterActive then return end
    self.careCirclesVisible = true
    self:UpdateCareCirclesDisplay()
end

function UlatekIntermission:HideCareCircles()
    self.careCirclesHideTimer = nil
    self.careCirclesVisible = false
    self:UpdateCareCirclesDisplay()
end

function UlatekIntermission:UpdateCareCirclesDisplay()
    if not self.frames then return end
    local f = self.frames
    if self.editMode then
        f.careCirclesText:SetText(L["BossMods_UlatekCareCircles"])
    end
    f.careCirclesAnchor:SetShown(self.db.careCircles.enabled ~= false
        and (self.editMode or (self.encounterActive and self.careCirclesVisible)) or false)
end

function UlatekIntermission:UpdateWaveDisplay()
    if not self.frames then return end
    local f = self.frames
    local direction = self.editMode and "Left" or self.waveDirection
    f.waveText:SetText(direction and L["BossMods_UlatekWave" .. direction] or "")
    f.waveAnchor:SetShown(self.editMode or (self.encounterActive and direction ~= nil) or false)
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
        if self.editMode then button.artClearHighlight() end
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

function UlatekIntermission:CreateAnchorPreview(kind)
    if kind ~= "assignment" and kind ~= "buttons" and kind ~= "bar"
        and kind ~= "reminder" and kind ~= "careCircles" and kind ~= "wave" then return end
    local owner = self
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:EnableMouse(false)
    local preview = {frames = {}, HideAssignmentSlots = self.HideAssignmentSlots}
    if kind == "bar" then
        local bar, label, time, markers = createBarRegions(frame)
        preview.frames = {barAnchor = frame, bar = bar, barLabel = label, barTime = time, barMarkers = markers}
        frame:SetScript("OnUpdate", function()
            if not preview.startedAt then return end
            local remaining = DURATION - (GetTime() - preview.startedAt) % DURATION
            bar:SetValue(remaining)
            time:SetText(formatCountdown(remaining))
        end)
    elseif kind == "assignment" then
        local text, measure, countdowns = createAssignmentRegions(frame)
        preview.frames = {
            assignmentAnchor = frame, assignmentText = text,
            assignmentMeasure = measure, assignmentCountdowns = countdowns
        }
    elseif kind == "reminder" or kind == "careCircles" or kind == "wave" then
        preview.frames.reminderText = createReminderText(frame)
    else
        local buttons = {}
        preview.frames.clickerButtons = buttons
        for index, data in ipairs(WAVE_BUTTONS) do
            local button = CreateFrame("Frame", nil, frame)
            button:EnableMouse(false)
            createClickerArtwork(button, nil, false, data.label)
            buttons[#buttons + 1] = button
        end
        for index, variationKey in ipairs(BUTTON_ORDER) do
            local button = CreateFrame("Frame", nil, frame)
            button:EnableMouse(false)
            createClickerArtwork(button, VARIATIONS[variationKey].markerID)
            buttons[#buttons + 1] = button
        end
        for index, data in ipairs(REMINDER_BUTTONS) do
            local button = CreateFrame("Frame", nil, frame)
            button:EnableMouse(false)
            createClickerArtwork(button, data.markerID)
            buttons[#buttons + 1] = button
        end
    end
    local handle = {frame = frame}
    function handle:Refresh()
        if kind == "bar" then
            applyBarAppearance(preview.frames, owner.db.bar)
            preview.frames.bar:SetShown(owner.db.textOnly ~= true)
            if not preview.startedAt then
                preview.frames.bar:SetValue(DURATION)
                preview.frames.barTime:SetText(tostring(DURATION))
            end
        elseif kind == "assignment" then
            preview.assignmentLayout = applyAssignmentAppearance(preview.frames, owner.db.assignment)
            UlatekIntermission.UpdateAssignmentSlots(preview, CHAT_PAYLOADS.PINK, 1, 0)
        elseif kind == "reminder" then
            applyReminderAppearance(frame, preview.frames.reminderText, owner.db.reminder, owner.db.assignment)
            preview.frames.reminderText:SetText(reminderMarkup(5, "BossMods_UlatekGoToMoon"))
        elseif kind == "careCircles" then
            applyReminderAppearance(frame, preview.frames.reminderText, owner.db.careCircles, owner.db.assignment)
            preview.frames.reminderText:SetText(L["BossMods_UlatekCareCircles"])
        elseif kind == "wave" then
            applyReminderAppearance(frame, preview.frames.reminderText, owner.db.wave, owner.db.assignment)
            preview.frames.reminderText:SetText(L["BossMods_UlatekWaveLeft"])
        else
            layoutClickerButtons(frame, preview.frames.clickerButtons, owner.db.clicker.hideLeftRight == true)
            frame:SetScale(tonumber(owner.db.clicker.scale) or 1)
            frame:SetAlpha(tonumber(owner.db.clicker.opacity) or 1)
        end
    end
    function handle:Show()
        preview.startedAt = nil
        self:Refresh()
        preview.startedAt = GetTime()
        frame:Show()
    end
    function handle:Hide()
        preview.startedAt = nil
        frame:Hide()
    end
    handle:Refresh()
    frame:Hide()
    return handle
end

function UlatekIntermission:UpdateDisplay()
    if not self.frames then
        return
    end

    self:UpdateReminderDisplay()
    self:UpdateCareCirclesDisplay()

    local editMode = self.editMode == true
    self:UpdateWaveDisplay()
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
    self:RegisterEvent("CHAT_MSG_RAID_WARNING", "OnChatMsg")
    self:RegisterEvent("CHAT_MSG_RAID", "OnChatMsg")
    self:RegisterEvent("CHAT_MSG_RAID_LEADER", "OnChatMsg")

    if DEBUG_LOCAL_TEST then
        self:RegisterEvent("CHAT_MSG_SAY", "OnChatMsg")
    end
end

function UlatekIntermission:StopChatListener()
    self:UnregisterEvent("CHAT_MSG_RAID_WARNING")
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

function UlatekIntermission:OnEncounterStart(_, encounterID, _, difficultyID)
    if tonumber(encounterID) ~= ENCOUNTER_ID or not currentLocationIsSupported() then
        return
    end

    self:ResetReminder()
    self.encounterDifficulty = tonumber(difficultyID)
    self.encounterStartedAt = GetTime()
    self.encounterActive = true
    self.reminderShowTimer = self:ScheduleTimer("ShowReminder", REMINDER_SHOW_AT)
    self.reminderHideTimer = self:ScheduleTimer("HideReminder", REMINDER_SHOW_AT + REMINDER_DURATION)
    self.careCirclesShowTimer = self:ScheduleTimer("ShowCareCircles", CARE_CIRCLES_SHOW_AT)
    self.careCirclesHideTimer = self:ScheduleTimer("HideCareCircles", CARE_CIRCLES_SHOW_AT + CARE_CIRCLES_DURATION)
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

    self:ResetReminder()
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
    self:ResetReminder()
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
    tab = "VenomousAbyss",
    order = 73,
    bossKey = "Ulatek",
    bossLabelKey = "BossMods_Ulatek",
    bossOrder = 80,
    labelKey = "BossMods_UlatekIntermission",
    descKey = "BossMods_UlatekIntermissionDesc",
    moduleName = MODULE_NAME
})
