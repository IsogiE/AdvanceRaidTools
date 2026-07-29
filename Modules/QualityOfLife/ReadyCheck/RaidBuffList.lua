local E, L = unpack(ART)
local Data = E.ReadyCheckData

E:RegisterModuleDefaults("QoL_RaidBuffList", {
    enabled = false,
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
        width = 60
    }
}

local NAME_WIDTH = 180
local COLUMN_WIDTH = 46
local TABLE_WIDTH = NAME_WIDTH
for _, column in ipairs(COLUMNS) do
    column.offset = TABLE_WIDTH
    column.width = column.width or COLUMN_WIDTH
    TABLE_WIDTH = TABLE_WIDTH + column.width
end
local FRAME_WIDTH = TABLE_WIDTH + 36
local FRAME_HEIGHT = 500
local DEFAULT_ROW_HEIGHT = 19

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

local function attachTooltip(region, labelKey)
    region:EnableMouse(true)
    region:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(text(labelKey))
        for _, line in ipairs(self.tooltipLines or {}) do
            GameTooltip:AddLine(line, nil, nil, nil, true)
        end
        GameTooltip:Show()
    end)
    region:SetScript("OnLeave", GameTooltip_Hide)
end

local function setReadyState(cell, value, available)
    cell.tooltipLines = nil
    cell.value:Hide()
    if not available then
        cell.icon:Hide()
        return
    end

    cell.icon:Show()
    cell.icon:SetAtlas(value and READY_ATLAS or NOT_READY_ATLAS, false)
    cell.icon:SetDesaturated(false)
    cell.icon:SetAlpha(1)
end

local function colorComponents(color, fallbackR, fallbackG, fallbackB)
    if type(color) == "table" then
        return color.r or color[1] or fallbackR,
            color.g or color[2] or fallbackG,
            color.b or color[3] or fallbackB
    end
    return fallbackR, fallbackG, fallbackB
end

local function setDurabilityState(cell, report)
    cell.tooltipLines = nil

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

function RaidBuffList:SavePosition()
    if self.frame then
        self.db.position = E:GetFramePosition(self.frame, UIParent)
    end
end

function RaidBuffList:ApplyPosition()
    if self.frame then
        E:ApplyFramePosition(self.frame, self.db.position, UIParent)
    end
end

function RaidBuffList:ResetPosition()
    self.db.position = {
        point = "CENTER",
        relPoint = "CENTER",
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

    row.name = E:CreateFontString(row, nil, "ARTWORK")
    row.name:SetPoint("LEFT", 5, 0)
    row.name:SetWidth(NAME_WIDTH - 10)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

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

function RaidBuffList:UpdateScrollRange()
    local frame = self.frame
    if not frame then
        return
    end

    local viewportHeight = frame.scroll:GetHeight() or 1
    local contentHeight = frame.content:GetHeight() or 1
    local maximum = math.max(0, contentHeight - viewportHeight)
    local current = clamp(frame.scroll:GetVerticalScroll(), 0, maximum)

    frame.scrollbar:SetMinMaxValues(0, maximum)
    frame.scrollbar:SetValue(current)
    frame.scrollbar:SetShown(maximum > 0)

    local thumbHeight = viewportHeight
    if contentHeight > 0 then
        thumbHeight = viewportHeight * viewportHeight / contentHeight
    end
    frame.scrollbarThumb:SetHeight(clamp(thumbHeight, 24, viewportHeight))
end

function RaidBuffList:CreateFrame()
    if self.frame then
        return self.frame
    end

    local frame = E:CreateWindowFrame({
        name = "ART_QoL_RaidBuffListFrame",
        width = FRAME_WIDTH,
        height = FRAME_HEIGHT,
        strata = "DIALOG",
        template = "Transparent",
        title = text("QoL_RaidBuffList", "Raid Buff List"),
        canMove = function()
            return not InCombatLockdown()
        end,
        onMove = function()
            RaidBuffList:SavePosition()
        end,
        onClose = function()
            RaidBuffList:HideList()
        end
    })
    frame.artSkipAutoBorder = true
    frame.artOnMediaUpdate = function()
        RaidBuffList:ApplyAppearance()
    end

    local headers = CreateFrame("Frame", nil, frame.body)
    headers:SetPoint("TOPLEFT")
    headers:SetSize(TABLE_WIDTH, 27)
    frame.headers = headers

    local nameHeader = E:CreateFontString(headers, nil, "OVERLAY")
    nameHeader:SetPoint("LEFT", 5, 0)
    nameHeader:SetWidth(NAME_WIDTH - 10)
    nameHeader:SetJustifyH("LEFT")
    frame.nameHeader = nameHeader

    for _, column in ipairs(COLUMNS) do
        local header = CreateFrame("Frame", nil, headers)
        header:SetSize(column.width, 27)
        header:SetPoint(
            "LEFT",
            headers,
            "LEFT",
            column.offset,
            0
        )
        attachTooltip(header, column.labelKey)

        local icon = header:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("CENTER")
        icon:SetSize(20, 20)
        icon:SetTexture(column.texture)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        header.icon = icon
    end

    local scroll = CreateFrame("ScrollFrame", nil, frame.body)
    scroll:SetPoint("TOPLEFT", headers, "BOTTOMLEFT", 0, -4)
    scroll:SetPoint(
        "BOTTOMRIGHT",
        frame.body,
        "BOTTOMLEFT",
        TABLE_WIDTH,
        0
    )
    scroll:EnableMouse(true)
    scroll:EnableMouseWheel(true)
    frame.scroll = scroll

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(TABLE_WIDTH, 1)
    scroll:SetScrollChild(content)
    frame.content = content
    frame.rows = {}

    local scrollbar =
        CreateFrame("Slider", nil, frame.body, "BackdropTemplate")
    scrollbar:SetOrientation("VERTICAL")
    scrollbar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 4, 0)
    scrollbar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 4, 0)
    scrollbar:SetWidth(11)
    scrollbar:SetValueStep(1)
    if scrollbar.SetObeyStepOnDrag then
        scrollbar:SetObeyStepOnDrag(false)
    end
    E:SetTemplate(scrollbar, "Transparent")
    scrollbar:SetScript("OnValueChanged", function(_, value)
        scroll:SetVerticalScroll(value)
    end)
    frame.scrollbar = scrollbar

    local thumb = scrollbar:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture(E.media.blankTex)
    thumb:SetSize(9, 30)
    thumb:SetColorTexture(1, 1, 1, 1)
    E:RegisterAccentTexture(thumb)
    scrollbar:SetThumbTexture(thumb)
    frame.scrollbarThumb = thumb

    scroll:SetScript("OnMouseWheel", function(_, delta)
        local _, maximum = scrollbar:GetMinMaxValues()
        scrollbar:SetValue(
            clamp(scrollbar:GetValue() - delta * 38, 0, maximum)
        )
    end)
    scroll:SetScript("OnSizeChanged", function()
        RaidBuffList:UpdateScrollRange()
    end)

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

    E:ApplyFontString(frame.title, font, fontSize + 2, outline)
    E:ApplyFontString(frame.nameHeader, font, fontSize, outline)
    frame:SetTitle(text("QoL_RaidBuffList", "Raid Buff List"))
    frame.nameHeader:SetText(
        text("QoL_RaidBuffListGroupPlayer", "Group / Player")
    )
    frame.title:SetTextColor(r, g, b, a)
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
                (index % 2 == 0 and 0.055 or 0.018)
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
    if not self.localTest and not IsInGroup() then
        self:HideList()
        return
    end

    local roster = Data:GetRoster()
    roster = roster or {}
    for index = 1, #roster do
        if not frame.rows[index] then
            self:CreateRow(index)
        end
    end
    self:ApplyAppearance()

    local textR, textG, textB =
        E:ColorTuple(self.db.textColor, 1, 1, 1, 1)

    for index, member in ipairs(roster) do
        local row = frame.rows[index]
        row:Show()

        local r, g, b = textR, textG, textB
        if self.db.useClassColors ~= false then
            r, g, b = E:ClassColorRGB(member.class)
        end
        if IsInRaid() then
            row.name:SetText(
                ("%d. %s"):format(
                    member.subgroup or 1,
                    member.shortName or "?"
                )
            )
        else
            row.name:SetText(member.shortName or "?")
        end
        row.name:SetTextColor(r, g, b)

        local scan, available
        if isUnitInspectable(member.unit) then
            scan, available = Data:ScanUnit(member.unit)
        else
            scan, available = {}, false
        end
        scan = scan or {}

        local durabilityReport = self:GetDurabilityReport(member)

        for _, column in ipairs(COLUMNS) do
            local cell = row.cells[column.key]
            if column.kind == "durability" then
                setDurabilityState(cell, durabilityReport)
            else
                setReadyState(
                    cell,
                    scan[column.key],
                    available
                )
            end
        end
    end

    for index = #roster + 1, #frame.rows do
        frame.rows[index]:Hide()
    end

    local contentHeight = math.max(
        frame.scroll:GetHeight() or 1,
        #roster * self:GetRowHeight()
    )
    frame.content:SetHeight(contentHeight)
    frame.scroll:UpdateScrollChildRect()
    self:UpdateScrollRange()
end

function RaidBuffList:ShowList(localTest, timeout)
    local isTest = localTest and true or false
    if InCombatLockdown() or (not isTest and not IsInGroup()) then
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

    self.localTest = isTest
    self.durabilityReports = {}

    local frame = self:CreateFrame()
    frame.scrollbar:SetValue(0)
    frame:Show()
    self.listActive = true
    self:SeedLocalDurability()
    self:RefreshList()
    -- Let roster and aura state settle once, matching Blizzard ready-check
    -- consumers that perform their local checks shortly after the event.
    self:ScheduleRefresh(1)

    if not isTest then
        local duration = 62
        if not E:IsSecret(timeout) and type(timeout) == "number" then
            duration = clamp(timeout, 5, 60) + 2
        end
        self.hideTimer = C_Timer.NewTimer(duration, function()
            self.hideTimer = nil
            if self.listActive and not self.localTest then
                self:HideList()
            end
        end)
    end
end

function RaidBuffList:HideList()
    self.listActive = false
    self.localTest = false
    self.durabilityReports = {}
    if self.refreshTimer then
        self.refreshTimer:Cancel()
        self.refreshTimer = nil
    end
    if self.hideTimer then
        self.hideTimer:Cancel()
        self.hideTimer = nil
    end
    if self.frame then
        self.frame:Hide()
    end
end

function RaidBuffList:OnReadyCheck(_, _, timeout)
    self:ShowList(false, timeout)
end

function RaidBuffList:OnReadyCheckFinished()
    if self.listActive and not self.localTest then
        self:HideList()
    end
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
    if self.listActive and not self.localTest and not IsInGroup() then
        self:HideList()
        return
    end
    self:ScheduleRefresh()
end

function RaidBuffList:Test()
    self:ShowList(true)
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
    if Durability then
        Durability:Register(self, "OnDurability")
    end
    self:RegisterEvent("READY_CHECK", "OnReadyCheck")
    self:RegisterEvent("READY_CHECK_FINISHED", "OnReadyCheckFinished")
    self:RegisterEvent("GROUP_LEFT", "HideList")
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
