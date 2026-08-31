local E, L = unpack(ART)
local Data = E.ReadyCheckData

E:RegisterModuleDefaults("QoL_RaidBuffList", {
    enabled = true,
    scale = 1,
    fontName = "PT Sans Narrow",
    fontSize = 11,
    fontOutline = "OUTLINE",
    textColor = {
        r = 1,
        g = 1,
        b = 1,
        a = 1
    },
    useClassColors = true,
    backgroundEnabled = true,
    borderEnabled = true,
    minimizedByGroup = {},
    position = {
        point = "CENTER",
        relPoint = "CENTER",
        x = 0,
        y = 0
    }
})

local RaidBuffList = E:NewModule("QoL_RaidBuffList", "AceEvent-3.0")
local Durability = E.Libs and E.Libs.LibDurability

local READY_ATLAS =
    _G.READY_CHECK_READY_TEXTURE_RAID or "UI-LFG-ReadyMark-Raid"
local NOT_READY_ATLAS =
    _G.READY_CHECK_NOT_READY_TEXTURE_RAID or "UI-LFG-DeclineMark-Raid"
local WAITING_ATLAS =
    _G.READY_CHECK_WAITING_TEXTURE_RAID or "UI-LFG-PendingMark-Raid"

local READY_CHECK_ATLASES = {
    ready = READY_ATLAS,
    notready = NOT_READY_ATLAS,
    waiting = WAITING_ATLAS
}

local COLUMNS = {
    {
        key = "food",
        labelKey = "QoL_ReadyCheckFood",
        texture = 136000
    },
    {
        key = "flask",
        labelKey = "QoL_ReadyCheckFlask",
        texture = 3566840
    },
    {
        key = "rune",
        labelKey = "QoL_ReadyCheckAugmentRune",
        texture = 4549099
    },
    {
        key = "vantus",
        labelKey = "QoL_ReadyCheckVantusRune",
        texture = 1058937
    },
    {
        key = "intellect",
        labelKey = "QoL_ReadyCheckIntellect",
        texture = 135932
    },
    {
        key = "stamina",
        labelKey = "QoL_ReadyCheckStamina",
        texture = 135987
    },
    {
        key = "attackPower",
        labelKey = "QoL_ReadyCheckAttackPower",
        texture = 132333
    },
    {
        key = "versatility",
        labelKey = "QoL_ReadyCheckVersatility",
        texture = 136078
    },
    {
        key = "mastery",
        labelKey = "QoL_ReadyCheckMastery",
        texture = 4630367
    },
    {
        key = "movement",
        labelKey = "QoL_ReadyCheckBlessingOfTheBronze",
        texture = 4622448
    },
    {
        key = "durability",
        kind = "durability",
        labelKey = "QoL_RaidBuffListDurability",
        texture = 134520,
        width = 52
    }
}

local NAME_WIDTH = 130
local COLUMN_WIDTH = 30
local TABLE_WIDTH = NAME_WIDTH
for _, column in ipairs(COLUMNS) do
    column.offset = TABLE_WIDTH
    column.width = column.width or COLUMN_WIDTH
    TABLE_WIDTH = TABLE_WIDTH + column.width
end
local FRAME_WIDTH = TABLE_WIDTH + 34
local HEADER_HEIGHT = 25
local HEADER_GAP = 2
local TIMER_BAR_HEIGHT = 16
local TIMER_BAR_GAP = 4
local TIMER_BAR_FADE_WIDTH = 18
local FRAME_CHROME_HEIGHT = 46
local FRAME_FIXED_HEIGHT =
    FRAME_CHROME_HEIGHT + TIMER_BAR_HEIGHT + TIMER_BAR_GAP + HEADER_HEIGHT +
        HEADER_GAP
local FRAME_MINIMIZED_FIXED_HEIGHT =
    FRAME_CHROME_HEIGHT + TIMER_BAR_HEIGHT + TIMER_BAR_GAP
local MAX_SCREEN_HEIGHT_RATIO = 0.72
local DEFAULT_ROW_HEIGHT = 18
local READY_CHECK_ICON_SIZE = 15
local NAME_LEFT_PADDING = 5
local NAME_ICON_GAP = 3
local NAME_TEXT_OFFSET = NAME_LEFT_PADDING + READY_CHECK_ICON_SIZE +
    NAME_ICON_GAP
local MINIMIZED_COLUMNS = 4
local MINIMIZED_COLUMN_GAP = 6
local MINIMIZED_COLUMN_WIDTH = math.floor(
    (TABLE_WIDTH - (MINIMIZED_COLUMNS - 1) * MINIMIZED_COLUMN_GAP) /
        MINIMIZED_COLUMNS
)
local PREVIEW_SIZE = 30
local PREVIEW_CLASSES = {
    "DEATHKNIGHT",
    "DEMONHUNTER",
    "DRUID",
    "EVOKER",
    "HUNTER",
    "MAGE",
    "MONK",
    "PALADIN",
    "PRIEST",
    "ROGUE",
    "SHAMAN",
    "WARLOCK",
    "WARRIOR"
}

local function clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    return math.max(minimum, math.min(maximum, value))
end

local function text(key, fallback)
    local value = L[key]
    if type(value) == "string" and value ~= "" then
        return value
    end
    return fallback or key
end

local function normalizedOutline(value)
    if value == "NONE" then
        return ""
    end
    return value or "OUTLINE"
end

local function normalizeDurabilityName(name)
    name = E:SafeString(name)
    if not name or name == "" then
        return nil
    end
    name = name:gsub("%s+", "")
    return E:NormalizeName(name)
end

local function isUnitInspectable(unit)
    local connectedOK, connected = pcall(UnitIsConnected, unit)
    if not connectedOK or E:IsSecret(connected) or not connected then
        return false
    end

    local visibleOK, visible = pcall(UnitIsVisible, unit)
    return visibleOK and not E:IsSecret(visible) and visible == true
end

local function isUnitConnected(unit)
    local connectedOK, connected = pcall(UnitIsConnected, unit)
    return connectedOK and not E:IsSecret(connected) and connected == true
end

local function attachTooltip(region, labelKey)
    region:EnableMouse(true)
    region:SetScript("OnEnter", function(self)
        if self.tooltipEnabled == false then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetText(text(labelKey))
        for _, line in ipairs(self.tooltipLines or {}) do
            GameTooltip:AddLine(line, nil, nil, nil, true)
        end
        GameTooltip:Show()
    end)
    region:SetScript("OnLeave", GameTooltip_Hide)
end

local function colorComponents(color, fallbackR, fallbackG, fallbackB)
    if type(color) == "table" then
        return color.r or color[1] or fallbackR,
            color.g or color[2] or fallbackG,
            color.b or color[3] or fallbackB
    end
    return fallbackR, fallbackG, fallbackB
end

local function unitFlag(func, unit)
    if type(func) ~= "function" then
        return false
    end

    local ok, value = pcall(func, unit)
    return ok and value == true
end

local function setHorizontalFade(texture, r, g, b, startAlpha, endAlpha)
    if texture.SetGradient and type(CreateColor) == "function" then
        texture:SetGradient(
            "HORIZONTAL",
            CreateColor(r, g, b, startAlpha),
            CreateColor(r, g, b, endAlpha)
        )
        return
    end
    texture:SetColorTexture(r, g, b, startAlpha)
end

local function setReadyState(cell, value, available, connected)
    cell.tooltipLines = nil
    cell.tooltipEnabled = available and true or false
    cell.value:Hide()
    if not available then
        cell.icon:Hide()
        if connected then
            local r, g, b =
                colorComponents(_G.GRAY_FONT_COLOR, 0.5, 0.5, 0.5)
            cell.value:SetText("–")
            cell.value:SetTextColor(r, g, b, 1)
            cell.value:Show()
        end
        return
    end

    cell.icon:Show()
    cell.icon:SetAtlas(value and READY_ATLAS or NOT_READY_ATLAS, false)
    cell.icon:SetDesaturated(false)
    cell.icon:SetAlpha(1)
end

local function getReadyCheckStatus(unit)
    if type(GetReadyCheckStatus) == "function" then
        local ok, value = pcall(GetReadyCheckStatus, unit)
        if ok and not E:IsSecret(value) then
            return value
        end
    end
    return nil
end

local function setReadyCheckIcon(icon, status)
    local atlas = READY_CHECK_ATLASES[status]
    if not atlas then
        icon:Hide()
        return
    end

    icon:SetAtlas(atlas, false)
    icon:SetDesaturated(false)
    icon:SetAlpha(1)
    icon:Show()
end

local function setDurabilityState(cell, report)
    cell.tooltipLines = nil
    cell.tooltipEnabled = report and true or false

    if not report then
        cell.value:Hide()
        cell.icon:Hide()
        return
    end

    cell.icon:Hide()
    cell.value:Show()
    local percent = report.percent
    local broken = report.broken or 0
    cell.value:SetText(("%d%%%s"):format(percent, broken > 0 and " !" or ""))

    local r, g, b
    if broken > 0 or percent <= 20 then
        r, g, b = colorComponents(_G.RED_FONT_COLOR, 1, 0.2, 0.2)
    elseif percent < 50 then
        r, g, b = colorComponents(_G.ORANGE_FONT_COLOR, 1, 0.5, 0)
    else
        r, g, b = colorComponents(_G.GREEN_FONT_COLOR, 0.2, 1, 0.2)
    end
    cell.value:SetTextColor(r, g, b, 1)

    if broken > 0 then
        local formatString =
            text("QoL_RaidBuffListBrokenItems", "Broken items: %d")
        cell.tooltipLines = {
            formatString:format(broken)
        }
    end
end

function RaidBuffList:GetRowHeight()
    local size = clamp(self.db.fontSize, 8, 22)
    return math.max(DEFAULT_ROW_HEIGHT, size + 7)
end

function RaidBuffList:GetMinimizedRowHeight()
    local size = clamp(self.db.fontSize, 8, 22)
    return math.max(16, size + 5)
end

function RaidBuffList:HasReadyCheckControl()
    return unitFlag(UnitIsGroupLeader, "player") or
        unitFlag(UnitIsGroupAssistant, "player")
end

function RaidBuffList:GetMinimizedGroup()
    return self:HasReadyCheckControl() and "controller" or "member"
end

function RaidBuffList:GetMinimizedPreferences()
    if not self.db then
        return {}
    end

    local preferences = rawget(self.db, "minimizedByGroup")
    if type(preferences) ~= "table" then
        preferences = {}
        self.db.minimizedByGroup = preferences
    end
    return preferences
end

function RaidBuffList:MigrateMinimizedPreference()
    if self.minimizedPreferenceMigrated or not self.db then
        return
    end
    self.minimizedPreferenceMigrated = true

    local oldValue = rawget(self.db, "minimized")
    if oldValue == nil then
        return
    end

    local preferences = self:GetMinimizedPreferences()
    local group = self:GetMinimizedGroup()
    if preferences[group] == nil then
        preferences[group] = oldValue == true
    end
    self.db.minimized = nil
end

function RaidBuffList:GetDefaultMinimized()
    return not self:HasReadyCheckControl()
end

function RaidBuffList:IsMinimized()
    if not self.db then
        return true
    end

    self:MigrateMinimizedPreference()
    local preferences = self:GetMinimizedPreferences()
    local value = preferences[self:GetMinimizedGroup()]
    if value ~= nil then
        return value == true
    end
    return self:GetDefaultMinimized()
end

function RaidBuffList:ResizeForRoster(rosterCount)
    local frame = self.frame
    if not frame then
        return
    end

    if self:IsMinimized() then
        local rows = math.max(
            1,
            math.ceil((rosterCount or 0) / MINIMIZED_COLUMNS)
        )
        frame:SetHeight(
            FRAME_MINIMIZED_FIXED_HEIGHT +
                rows * self:GetMinimizedRowHeight()
        )
        return
    end

    local rowHeight = self:GetRowHeight()
    local scale = clamp(self.db.scale, 0.75, 1.5)
    local screenHeight = UIParent:GetHeight() or 768
    local rowSpace = screenHeight * MAX_SCREEN_HEIGHT_RATIO / scale -
        FRAME_FIXED_HEIGHT
    local maximumRows = math.max(
        1,
        math.floor(rowSpace / rowHeight)
    )
    local visibleRows = clamp(rosterCount or 0, 1, maximumRows)
    frame:SetHeight(
        FRAME_FIXED_HEIGHT + visibleRows * rowHeight
    )
end

function RaidBuffList:GetBaseTitle()
    return text("QoL_RaidBuffList", "Raid Buff List")
end

function RaidBuffList:GetPreviewPlayer()
    local fullName
    if type(E.GetUnitFullName) == "function" then
        fullName = E:GetUnitFullName("player", true)
    end
    if not fullName and type(UnitNameUnmodified) == "function" then
        fullName = UnitNameUnmodified("player")
    end
    if not fullName and type(UnitName) == "function" then
        fullName = UnitName("player")
    end
    fullName = fullName or "Player"

    local class
    if type(UnitClass) == "function" then
        local ok, _, classFile = pcall(UnitClass, "player")
        if ok and not E:IsSecret(classFile) then
            class = classFile
        end
    end

    return {
        unit = "player",
        fullName = fullName,
        shortName = E:BareName(fullName) or fullName,
        class = class or "PRIEST",
        subgroup = 1,
        preview = true
    }
end

function RaidBuffList:GetPreviewRoster()
    local player = self:GetPreviewPlayer()
    if self.previewRoster and self.previewPlayerName == player.fullName and
        self.previewPlayerClass == player.class then
        return self.previewRoster
    end

    local roster = {
        player
    }
    for index = 2, PREVIEW_SIZE do
        local classIndex = ((index * 7) % #PREVIEW_CLASSES) + 1
        local name = "Player" .. index
        roster[index] = {
            fullName = name,
            shortName = name,
            class = PREVIEW_CLASSES[classIndex],
            subgroup = math.ceil(index / 5),
            preview = true
        }
    end

    self.previewRoster = roster
    self.previewPlayerName = player.fullName
    self.previewPlayerClass = player.class
    return roster
end

function RaidBuffList:GetDisplayRoster()
    if self.localTest or self.unlocked then
        return self:GetPreviewRoster()
    end
    return Data:GetRoster() or {}
end

function RaidBuffList:UpdateTitle()
    local frame = self.frame
    if not frame then
        return
    end

    local title = self:GetBaseTitle()
    if self.readyCheckEndTime then
        local remaining = math.max(0, self.readyCheckEndTime - GetTime())
        frame:SetTitle(("%s (%d sec.)"):format(title, math.ceil(remaining)))
        return
    end

    frame:SetTitle(title)
end

function RaidBuffList:UpdateTimerBar()
    local frame = self.frame
    local bar = frame and frame.timerBar
    if not bar then
        return
    end

    local fullWidth = math.max(1, bar:GetWidth() or TABLE_WIDTH)
    local width = 1
    if self.readyCheckEndTime and self.readyCheckDuration then
        local remaining = math.max(0, self.readyCheckEndTime - GetTime())
        width = math.max(
            1,
            fullWidth * remaining / math.max(1, self.readyCheckDuration)
        )
    end
    local fadeWidth = math.min(TIMER_BAR_FADE_WIDTH, width)
    local fillWidth = math.max(1, width - fadeWidth)
    bar.fill:SetWidth(fillWidth)
    if bar.fade then
        bar.fade:SetWidth(fadeWidth)
        bar.fade:SetShown(width > 1)
    end

    local total = tonumber(self.readyTotal) or 0
    local responded = tonumber(self.readyResponded) or 0
    bar.text:SetFormattedText("%d/%d", responded, total)

    local progress = total > 0 and responded / total or 0
    local r, g, b
    if progress >= 0.66 then
        local step = (progress - 0.66) / 0.34
        r = 0.6 - (0.6 - 0.2) * step
        g = 0.6 - (0.6 - 0.7) * step
        b = 0.2
    else
        local step = progress / 0.66
        r = 1 - (1 - 0.6) * step
        g = 0.2 - (0.2 - 0.6) * step
        b = 0.2
    end
    bar.fill:SetColorTexture(r, g, b, 0.9)
    if bar.fade then
        setHorizontalFade(bar.fade, r, g, b, 0.9, 0)
    end
    self:UpdateTitle()
end

function RaidBuffList:OnTimerUpdate(elapsed)
    self.timerUpdateElapsed = (self.timerUpdateElapsed or 0) + elapsed
    if self.timerUpdateElapsed < 0.1 then
        return
    end
    self.timerUpdateElapsed = 0
    self:UpdateTimerBar()

    if self.readyCheckEndTime and self.readyCheckEndTime <= GetTime() and
        self.frame and self.frame.timerBar then
        self.frame.timerBar:SetScript("OnUpdate", nil)
    end
end

function RaidBuffList:StartTimer(duration)
    duration = clamp(duration, 5, 60)
    self.readyCheckDuration = duration
    self.readyCheckEndTime = GetTime() + duration
    self.timerUpdateElapsed = 0

    if self.frame and self.frame.timerBar then
        self.frame.timerBar:SetScript("OnUpdate", function(_, elapsed)
            RaidBuffList:OnTimerUpdate(elapsed)
        end)
    end
    self:UpdateTimerBar()
end

function RaidBuffList:StopTimer()
    self.readyCheckDuration = nil
    self.readyCheckEndTime = nil
    self.timerUpdateElapsed = 0

    if self.frame and self.frame.timerBar then
        self.frame.timerBar:SetScript("OnUpdate", nil)
    end
    self:UpdateTimerBar()
end

function RaidBuffList:UpdateMinimizeButton()
    local button = self.frame and self.frame.minimizeButton
    if not button then
        return
    end

    if button.arrow then
        button.arrow:SetRotation(self:IsMinimized() and -math.pi / 2 or
            math.pi / 2)
    end
end

function RaidBuffList:ApplyViewMode()
    local frame = self.frame
    if not frame then
        return
    end

    local minimized = self:IsMinimized()
    frame.headers:SetShown(not minimized)
    frame.list.frame:SetShown(not minimized)
    frame.miniContent:SetShown(minimized)
    self:UpdateMinimizeButton()
    self:ResizeForRoster(self.rosterCount)
end

function RaidBuffList:SetMinimized(value)
    value = value and true or false
    local group = self:GetMinimizedGroup()
    local preferences = self:GetMinimizedPreferences()
    if preferences[group] == value then
        self:ApplyViewMode()
        return
    end

    preferences[group] = value
    self.db.minimized = nil
    self:ApplyViewMode()
    self:RefreshList()
end

function RaidBuffList:ApplyRowBackground(row, index, r, g, b)
    if not row or not row.highlight then
        return
    end

    if self.db.backgroundEnabled == false then
        row.highlight:SetColorTexture(0, 0, 0, 0)
        return
    end

    if self.db.useClassColors == false then
        r, g, b = colorComponents(E.media.valueColor, 0.09, 0.52, 0.82)
    end

    row.highlight:SetColorTexture(
        r,
        g,
        b,
        index % 2 == 0 and 0.16 or 0.08
    )
end

function RaidBuffList:SavePosition(position)
    if not position then
        if not self.frame then
            return
        end
        position = E:GetFramePosition(self.frame, UIParent)
    end

    self.db.position.point = position.point or "CENTER"
    self.db.position.relPoint = nil
    self.db.position.x = tonumber(position.x) or 0
    self.db.position.y = tonumber(position.y) or 0
    self:ApplyPosition()
end

function RaidBuffList:ApplyPosition()
    if self.frame then
        E:ApplyFramePosition(self.frame, self.db.position)
    end
end

function RaidBuffList:ResetPosition()
    self.db.position = {
        point = "CENTER",
        x = 0,
        y = 0
    }
    self:ApplyPosition()
end

function RaidBuffList:CreateRow(index)
    local frame = self.frame
    local row = CreateFrame("Frame", nil, frame.content)
    row:SetWidth(TABLE_WIDTH)

    row.highlight = row:CreateTexture(nil, "BACKGROUND")
    row.highlight:SetAllPoints()

    row.readyCheck = row:CreateTexture(nil, "ARTWORK")
    row.readyCheck:SetPoint("LEFT", NAME_LEFT_PADDING, 0)
    row.readyCheck:SetSize(READY_CHECK_ICON_SIZE, READY_CHECK_ICON_SIZE)
    row.readyCheck:Hide()

    row.name = E:CreateFontString(row, nil, "ARTWORK")
    row.name:SetPoint("LEFT", NAME_TEXT_OFFSET, 0)
    row.name:SetWidth(NAME_WIDTH - NAME_TEXT_OFFSET - NAME_LEFT_PADDING)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    frame:RegisterDragRegion(row)

    row.cells = {}
    for _, column in ipairs(COLUMNS) do
        local cell = CreateFrame("Frame", nil, row)
        cell:SetPoint(
            "LEFT",
            row,
            "LEFT",
            column.offset,
            0
        )
        cell:SetWidth(column.width)
        attachTooltip(cell, column.labelKey)
        frame:RegisterDragRegion(cell)

        cell.icon = cell:CreateTexture(nil, "ARTWORK")
        cell.icon:SetPoint("CENTER")
        cell.icon:SetSize(15, 15)
        cell.icon:Hide()

        cell.value = E:CreateFontString(cell, nil, "ARTWORK")
        cell.value:SetPoint("CENTER")
        cell.value:SetJustifyH("CENTER")
        cell.value:Hide()

        row.cells[column.key] = cell
    end

    frame.rows[index] = row
    return row
end

function RaidBuffList:CreateMiniRow(index)
    local frame = self.frame
    local row = CreateFrame("Frame", nil, frame.miniContent)
    row:SetWidth(MINIMIZED_COLUMN_WIDTH)

    row.highlight = row:CreateTexture(nil, "BACKGROUND")
    row.highlight:SetAllPoints()

    row.readyCheck = row:CreateTexture(nil, "ARTWORK")
    row.readyCheck:SetPoint("LEFT", NAME_LEFT_PADDING, 0)
    row.readyCheck:SetSize(READY_CHECK_ICON_SIZE, READY_CHECK_ICON_SIZE)
    row.readyCheck:Hide()

    row.name = E:CreateFontString(row, nil, "ARTWORK")
    row.name:SetPoint("LEFT", NAME_TEXT_OFFSET, 0)
    row.name:SetWidth(
        MINIMIZED_COLUMN_WIDTH - NAME_TEXT_OFFSET - NAME_LEFT_PADDING
    )
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    frame:RegisterDragRegion(row)

    frame.miniRows[index] = row
    return row
end

function RaidBuffList:CreateFrame()
    if self.frame then
        return self.frame
    end

    if not E:EnsureOptions() then
        return nil
    end
    local T = E.Templates

    local frame = E:CreateWindowFrame({
        name = "ART_QoL_RaidBuffListFrame",
        width = FRAME_WIDTH,
        height = FRAME_FIXED_HEIGHT + DEFAULT_ROW_HEIGHT,
        strata = "DIALOG",
        template = "Transparent",
        title = text("QoL_RaidBuffList", "Raid Buff List"),
        canMove = function()
            return not InCombatLockdown()
        end,
        onMove = function(currentFrame)
            RaidBuffList:SavePosition(
                E:GetFramePosition(currentFrame, UIParent)
            )
        end,
        onClose = function()
            RaidBuffList:HideList()
        end
    })
    frame.artSkipAutoBorder = true
    frame.artOnMediaUpdate = function()
        RaidBuffList:ApplyAppearance()
    end
    function frame:RegisterDragRegion(region)
        region:EnableMouse(true)
        region:RegisterForDrag("LeftButton")
        region:SetScript("OnDragStart", function()
            if not InCombatLockdown() then
                frame:StartMoving()
            end
        end)
        region:SetScript("OnDragStop", function()
            frame:StopMovingOrSizing()
            RaidBuffList:SavePosition(
                E:GetFramePosition(frame, UIParent)
            )
        end)
    end
    local minimize = E:CreateWindowCloseButton(frame.titleBar, {
        size = 20,
        onClick = function()
            RaidBuffList:SetMinimized(not RaidBuffList:IsMinimized())
        end
    })
    minimize.glyph:SetText("")
    minimize:SetPoint("RIGHT", frame.close, "LEFT", -4, 0)
    frame.title:ClearAllPoints()
    frame.title:SetPoint("LEFT")
    frame.title:SetPoint("RIGHT", minimize, "LEFT", -6, 0)

    local arrow = minimize:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture([[Interface\ChatFrame\ChatFrameExpandArrow]])
    arrow:SetDesaturated(true)
    arrow:SetSize(10, 10)
    arrow:SetPoint("CENTER")
    E:RegisterAccentTexture(arrow)
    minimize.arrow = arrow
    frame.minimizeButton = minimize

    frame:RegisterDragRegion(frame.body)

    local timerBar = CreateFrame("Frame", nil, frame.body)
    timerBar:SetPoint("TOPLEFT")
    timerBar:SetSize(TABLE_WIDTH, TIMER_BAR_HEIGHT)
    frame:RegisterDragRegion(timerBar)

    timerBar.background = timerBar:CreateTexture(nil, "BACKGROUND")
    timerBar.background:SetAllPoints()
    timerBar.background:SetColorTexture(0, 0, 0, 0.35)

    timerBar.fill = timerBar:CreateTexture(nil, "ARTWORK")
    timerBar.fill:SetPoint("TOPLEFT")
    timerBar.fill:SetPoint("BOTTOMLEFT")
    timerBar.fill:SetWidth(TABLE_WIDTH)
    timerBar.fill:SetColorTexture(1, 0.2, 0.2, 0.9)

    timerBar.fade = timerBar:CreateTexture(nil, "ARTWORK")
    timerBar.fade:SetPoint("TOPLEFT", timerBar.fill, "TOPRIGHT")
    timerBar.fade:SetPoint("BOTTOMLEFT", timerBar.fill, "BOTTOMRIGHT")
    timerBar.fade:SetWidth(TIMER_BAR_FADE_WIDTH)
    setHorizontalFade(timerBar.fade, 1, 0.2, 0.2, 0.9, 0)

    timerBar.text = E:CreateFontString(timerBar, nil, "OVERLAY")
    timerBar.text:SetPoint("CENTER")
    timerBar.text:SetJustifyH("CENTER")
    timerBar.text:SetText("0/0")
    frame.timerBar = timerBar

    local headers = CreateFrame("Frame", nil, frame.body)
    headers:SetPoint("TOPLEFT", timerBar, "BOTTOMLEFT", 0, -TIMER_BAR_GAP)
    headers:SetSize(TABLE_WIDTH, HEADER_HEIGHT)
    frame.headers = headers
    frame:RegisterDragRegion(headers)

    headers.background = headers:CreateTexture(nil, "BACKGROUND")
    headers.background:SetAllPoints()
    headers.background:SetColorTexture(0, 0, 0, 0.22)

    local nameHeader = E:CreateFontString(headers, nil, "OVERLAY")
    nameHeader:SetPoint("LEFT", NAME_TEXT_OFFSET, 0)
    nameHeader:SetWidth(NAME_WIDTH - NAME_TEXT_OFFSET - NAME_LEFT_PADDING)
    nameHeader:SetJustifyH("LEFT")
    frame.nameHeader = nameHeader

    for _, column in ipairs(COLUMNS) do
        local header = CreateFrame("Frame", nil, headers)
        header:SetSize(column.width, HEADER_HEIGHT)
        header:SetPoint(
            "LEFT",
            headers,
            "LEFT",
            column.offset,
            0
        )
        attachTooltip(header, column.labelKey)
        frame:RegisterDragRegion(header)

        local icon = header:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("CENTER")
        icon:SetSize(18, 18)
        icon:SetTexture(column.texture)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        header.icon = icon
    end

    local list = T:ScrollFrame(frame.body, {
        chrome = false,
        minContentWidth = TABLE_WIDTH,
        mouseWheelStep = self:GetRowHeight() * 2,
        scrollbarWidth = 10,
        scrollbarGap = 4
    })
    list.frame:SetPoint(
        "TOPLEFT",
        headers,
        "BOTTOMLEFT",
        0,
        -HEADER_GAP
    )
    list.frame:SetPoint("BOTTOMRIGHT")
    frame.list = list
    frame.scroll = list.scroll
    frame.content = list.content
    frame.rows = {}
    frame:RegisterDragRegion(list.frame)
    frame:RegisterDragRegion(list.scroll)
    frame:RegisterDragRegion(list.content)

    local miniContent = CreateFrame("Frame", nil, frame.body)
    miniContent:SetPoint(
        "TOPLEFT",
        timerBar,
        "BOTTOMLEFT",
        0,
        -TIMER_BAR_GAP
    )
    miniContent:SetSize(TABLE_WIDTH, DEFAULT_ROW_HEIGHT)
    miniContent:Hide()
    frame.miniContent = miniContent
    frame.miniRows = {}
    frame:RegisterDragRegion(miniContent)

    self.frame = frame
    frame:SetScale(clamp(self.db.scale, 0.75, 1.5))
    self:ApplyPosition()
    self:ApplyAppearance()
    return frame
end

function RaidBuffList:ApplyAppearance()
    local frame = self.frame
    if not frame then
        return
    end

    frame:SetScale(clamp(self.db.scale, 0.75, 1.5))

    local background = E.media.backdropFadeColor or {0.07, 0.07, 0.07, 0.85}
    local border = E.media.borderColor or {0, 0, 0, 1}
    frame:SetBackdropColor(
        background[1],
        background[2],
        background[3],
        self.db.backgroundEnabled == false and 0 or background[4]
    )
    frame:SetBackdropBorderColor(
        border[1],
        border[2],
        border[3],
        self.db.borderEnabled == false and 0 or border[4]
    )

    local font = E:FetchModuleFont(self.db.fontName)
    local fontSize = clamp(self.db.fontSize, 8, 22)
    local outline = normalizedOutline(self.db.fontOutline)
    local r, g, b, a = E:ColorTuple(self.db.textColor, 1, 1, 1, 1)

    E:ApplyFontString(
        frame.timerBar.text,
        font,
        math.max(8, fontSize - 1),
        outline
    )
    frame.timerBar.text:SetTextColor(r, g, b, a)
    frame.timerBar.background:SetColorTexture(
        background[1],
        background[2],
        background[3],
        self.db.backgroundEnabled == false and 0 or 0.35
    )
    frame.headers.background:SetColorTexture(
        background[1],
        background[2],
        background[3],
        self.db.backgroundEnabled == false and 0 or 0.22
    )

    E:ApplyFontString(frame.nameHeader, font, fontSize, outline)
    self:UpdateTitle()
    frame.nameHeader:SetText(text("Name", "Name"))
    frame.nameHeader:SetTextColor(r, g, b, a)

    local accent = E.media.valueColor or {0.09, 0.52, 0.82, 1}
    local rowHeight = self:GetRowHeight()
    for index, row in ipairs(frame.rows) do
        row:ClearAllPoints()
        row:SetPoint(
            "TOPLEFT",
            frame.content,
            "TOPLEFT",
            0,
            -(index - 1) * rowHeight
        )
        row:SetHeight(rowHeight)
        row.highlight:SetColorTexture(
            accent[1],
            accent[2],
            accent[3],
            self.db.backgroundEnabled == false and 0 or
                (index % 2 == 0 and 0.075 or 0.025)
        )
        E:ApplyFontString(row.name, font, fontSize, outline)
        for _, cell in pairs(row.cells) do
            cell:SetHeight(rowHeight)
            E:ApplyFontString(
                cell.value,
                font,
                math.max(8, fontSize - 1),
                outline
            )
        end
    end
    local miniRowHeight = self:GetMinimizedRowHeight()
    for index, row in ipairs(frame.miniRows) do
        local column = (index - 1) % MINIMIZED_COLUMNS
        local rowIndex = math.floor((index - 1) / MINIMIZED_COLUMNS)
        row:ClearAllPoints()
        row:SetPoint(
            "TOPLEFT",
            frame.miniContent,
            "TOPLEFT",
            column * (MINIMIZED_COLUMN_WIDTH + MINIMIZED_COLUMN_GAP),
            -rowIndex * miniRowHeight
        )
        row:SetSize(MINIMIZED_COLUMN_WIDTH, miniRowHeight)
        row.highlight:SetColorTexture(
            accent[1],
            accent[2],
            accent[3],
            self.db.backgroundEnabled == false and 0 or
                (index % 2 == 0 and 0.075 or 0.025)
        )
        E:ApplyFontString(row.name, font, fontSize, outline)
        row.name:SetWidth(
            MINIMIZED_COLUMN_WIDTH - NAME_TEXT_OFFSET - NAME_LEFT_PADDING
        )
    end
    frame.list.SetMouseWheelStep(self:GetRowHeight() * 2)
    self:UpdateTimerBar()
    self:ApplyViewMode()
end

function RaidBuffList:StoreDurabilityReport(percent, broken, sender, allowTest)
    if not self.listActive or (self.localTest and not allowTest) or
        E:IsSecret(percent) or E:IsSecret(broken) then
        return
    end

    percent = tonumber(percent)
    broken = tonumber(broken)
    local key = normalizeDurabilityName(sender)
    if not percent or not broken or not key then
        return
    end

    local bareName = E:BareName(sender)
    self.durabilityReports = self.durabilityReports or {}
    self.durabilityReports[key] = {
        percent = math.floor(clamp(percent, 0, 100)),
        broken = math.floor(clamp(broken, 0, 18)),
        bareKey = normalizeDurabilityName(bareName)
    }
end

function RaidBuffList:SeedLocalDurability()
    if not Durability or type(Durability.GetDurability) ~= "function" then
        return
    end

    local ok, percent, broken = pcall(Durability.GetDurability)
    if not ok then
        return
    end

    local playerName = E:GetUnitFullName("player", true) or
        UnitNameUnmodified("player")
    self:StoreDurabilityReport(percent, broken, playerName, true)
end

function RaidBuffList:GetDurabilityReport(member)
    local reports = self.durabilityReports or {}
    local fullName = E:SafeString(member and member.fullName)
    if not fullName then
        return nil
    end

    local candidates = {
        fullName
    }
    if type(Ambiguate) == "function" then
        local ok, ambiguous = pcall(Ambiguate, fullName, "none")
        if ok and not E:IsSecret(ambiguous) and type(ambiguous) == "string" then
            candidates[#candidates + 1] = ambiguous
        end
    end

    for _, candidate in ipairs(candidates) do
        local report = reports[normalizeDurabilityName(candidate)]
        if report then
            return report
        end
    end

    local bareKey = normalizeDurabilityName(E:BareName(fullName))
    local match
    for _, report in pairs(reports) do
        if bareKey and report.bareKey == bareKey then
            if match and match ~= report then
                return nil
            end
            match = report
        end
    end
    return match
end

function RaidBuffList:OnDurability(percent, broken, sender)
    self:StoreDurabilityReport(percent, broken, sender, false)
    self:ScheduleRefresh(0)
end

function RaidBuffList:RefreshList()
    local frame = self.frame
    if not frame or not frame:IsShown() then
        return
    end
    if InCombatLockdown() then
        self:HideList()
        return
    end
    if not self.localTest and not self.unlocked and not IsInGroup() then
        self:HideList()
        return
    end

    local roster = self:GetDisplayRoster()
    self.rosterCount = #roster
    self.readyTotal = #roster

    local minimized = self:IsMinimized()
    local createdRows = false
    for index = 1, #roster do
        if minimized then
            if not frame.miniRows[index] then
                self:CreateMiniRow(index)
                createdRows = true
            end
        elseif not frame.rows[index] then
            self:CreateRow(index)
            createdRows = true
        end
    end
    if createdRows then
        self:ApplyAppearance()
    else
        self:ApplyViewMode()
    end

    local textR, textG, textB =
        E:ColorTuple(self.db.textColor, 1, 1, 1, 1)
    local responded = 0

    for index, member in ipairs(roster) do
        local preview = member.preview == true
        local connected = preview or isUnitConnected(member.unit)
        local r, g, b = textR, textG, textB
        if self.db.useClassColors ~= false then
            r, g, b = E:ClassColorRGB(member.class)
        end
        if not connected then
            r, g, b = colorComponents(_G.GRAY_FONT_COLOR, 0.5, 0.5, 0.5)
        end

        local status = preview and "waiting" or getReadyCheckStatus(member.unit)
        if status == "ready" or status == "notready" then
            responded = responded + 1
        end

        if minimized then
            local row = frame.miniRows[index]
            row:Show()
            row.name:SetText(member.shortName or "?")
            row.name:SetTextColor(r, g, b)
            setReadyCheckIcon(row.readyCheck, status)
            self:ApplyRowBackground(row, index, r, g, b)
        else
            local row = frame.rows[index]
            row:Show()
            row.name:SetText(member.shortName or "?")
            row.name:SetTextColor(r, g, b)
            setReadyCheckIcon(row.readyCheck, status)
            self:ApplyRowBackground(row, index, r, g, b)

            local scan, available
            if not preview and isUnitInspectable(member.unit) then
                scan, available = Data:ScanUnit(member.unit)
            else
                scan, available = {}, false
            end
            scan = scan or {}

            local durabilityReport = preview and nil or
                self:GetDurabilityReport(member)

            for _, column in ipairs(COLUMNS) do
                local cell = row.cells[column.key]
                if column.kind == "durability" then
                    setDurabilityState(cell, durabilityReport)
                else
                    setReadyState(
                        cell,
                        scan[column.key],
                        available,
                        connected
                    )
                end
            end
        end
    end
    self.readyResponded = responded

    for index = #roster + 1, #frame.rows do
        frame.rows[index]:Hide()
    end
    for index = #roster + 1, #frame.miniRows do
        frame.miniRows[index]:Hide()
    end
    frame.miniContent:SetHeight(
        math.max(
            self:GetMinimizedRowHeight(),
            math.ceil(#roster / MINIMIZED_COLUMNS) *
                self:GetMinimizedRowHeight()
        )
    )

    if not minimized then
        local contentHeight = math.max(
            frame.scroll:GetHeight() or 1,
            #roster * self:GetRowHeight()
        )
        frame.list.SetContentSize(TABLE_WIDTH, contentHeight)
    end
    self:ResizeForRoster(#roster)
    self:UpdateTimerBar()
end

function RaidBuffList:ShowList(localTest, timeout)
    local isTest = localTest and true or false
    if InCombatLockdown() or self.unlocked or self:IsTesting() or
        (not isTest and not IsInGroup()) then
        return
    end

    if self.refreshTimer then
        self.refreshTimer:Cancel()
        self.refreshTimer = nil
    end
    if self.hideTimer then
        self.hideTimer:Cancel()
        self.hideTimer = nil
    end
    local duration = 35
    if not E:IsSecret(timeout) and type(timeout) == "number" then
        duration = clamp(timeout, 5, 60)
    end

    self.unlocked = false
    self.localTest = isTest
    self.durabilityReports = {}

    local frame = self:CreateFrame()
    if not frame then
        self.localTest = false
        return
    end
    frame.list.ScrollToTop()
    frame:Show()
    self.listActive = true
    self:StartTimer(duration)
    self:SeedLocalDurability()
    self:RefreshList()
    -- Let roster and aura state settle once, matching Blizzard ready-check
    -- consumers that perform their local checks shortly after the event.
    self:ScheduleRefresh(1)

    if not isTest then
        self.hideTimer = C_Timer.NewTimer(duration + 2, function()
            self.hideTimer = nil
            if self.listActive and not self.localTest then
                self:HideList()
            end
        end)
    end
end

function RaidBuffList:HideList()
    local wasUnlocked = self.unlocked
    local wasTesting = self.localTest
    self.listActive = false
    self.unlocked = false
    self.localTest = false
    self.durabilityReports = {}
    self.readyTotal = 0
    self.readyResponded = 0
    if self.refreshTimer then
        self.refreshTimer:Cancel()
        self.refreshTimer = nil
    end
    if self.hideTimer then
        self.hideTimer:Cancel()
        self.hideTimer = nil
    end
    self:StopTimer()
    if self.frame then
        self.frame:Hide()
    end
    if (wasUnlocked or wasTesting) and E.RefreshOptions then
        E:RefreshOptions()
    end
end

function RaidBuffList:OnReadyCheck(_, _, timeout)
    self:ShowList(false, timeout)
end

function RaidBuffList:OnReadyCheckFinished()
    if self.listActive and not self.localTest and not self.unlocked then
        self:HideList()
    end
end

function RaidBuffList:OnReadyCheckConfirm()
    if self.refreshTimer then
        self.refreshTimer:Cancel()
        self.refreshTimer = nil
    end
    self:ScheduleRefresh(0)
end

function RaidBuffList:ScheduleRefresh(delay)
    if InCombatLockdown() or not self.listActive or self.refreshTimer then
        return
    end
    delay = type(delay) == "number" and clamp(delay, 0, 1) or 0.2
    self.refreshTimer = C_Timer.NewTimer(delay, function()
        self.refreshTimer = nil
        self:RefreshList()
    end)
end

function RaidBuffList:OnGroupRosterUpdate()
    if self.listActive and not self.localTest and not self.unlocked and
        not IsInGroup() then
        self:HideList()
        return
    end
    self:ScheduleRefresh()
end

function RaidBuffList:OnGroupLeft()
    if self.unlocked or self:IsTesting() then
        self:ScheduleRefresh()
    else
        self:HideList()
    end
end

function RaidBuffList:IsUnlocked()
    return self.unlocked and true or false
end

function RaidBuffList:IsTesting()
    return self.listActive and self.localTest and true or false
end

function RaidBuffList:SetUnlocked(value)
    value = value and true or false
    if value == self.unlocked then
        return
    end

    if not value then
        self:HideList()
        return
    end
    if self:IsTesting() or not self:IsEnabled() or InCombatLockdown() then
        return
    end

    if self.refreshTimer then
        self.refreshTimer:Cancel()
        self.refreshTimer = nil
    end
    if self.hideTimer then
        self.hideTimer:Cancel()
        self.hideTimer = nil
    end

    local frame = self:CreateFrame()
    if not frame then
        return
    end

    self.unlocked = true
    self.localTest = false
    self.listActive = true
    self.durabilityReports = {}
    self.readyTotal = 0
    self.readyResponded = 0
    frame.list.ScrollToTop()
    frame:Show()
    self:StartTimer(35)
    self:SeedLocalDurability()
    self:RefreshList()
    self:ScheduleRefresh(1)
end

function RaidBuffList:Test()
    if self:IsTesting() then
        self:HideList()
        return
    end

    self:ShowList(true)
    if self:IsTesting() and E.RefreshOptions then
        E:RefreshOptions()
    end
end

function RaidBuffList:Refresh()
    if not self.frame then
        return
    end
    self:ApplyAppearance()
    self:ApplyPosition()
    self:RefreshList()
end

function RaidBuffList:OnEnable()
    self.unlocked = false
    if Durability then
        Durability:Register(self, "OnDurability")
    end
    self:RegisterEvent("READY_CHECK", "OnReadyCheck")
    self:RegisterEvent("READY_CHECK_CONFIRM", "OnReadyCheckConfirm")
    self:RegisterEvent("READY_CHECK_FINISHED", "OnReadyCheckFinished")
    self:RegisterEvent("GROUP_LEFT", "OnGroupLeft")
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "OnGroupRosterUpdate")
    self:RegisterEvent("UNIT_AURA", "ScheduleRefresh")
    self:RegisterEvent("UNIT_CONNECTION", "ScheduleRefresh")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "HideList")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Refresh")
end

function RaidBuffList:OnDisable()
    if Durability then
        Durability:Unregister(self)
    end
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    self:HideList()
end

E:RegisterQoLFeature("RaidBuffList", {
    order = 60,
    labelKey = "QoL_RaidBuffList",
    descKey = "QoL_RaidBuffListDesc",
    moduleName = "QoL_RaidBuffList"
})
