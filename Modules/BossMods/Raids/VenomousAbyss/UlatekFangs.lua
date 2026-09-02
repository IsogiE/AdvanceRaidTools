local E, L = unpack(ART)

E:RegisterModuleDefaults("BossMods_UlatekFangs", {
    enabled = true,
    position = {
        point = "CENTER",
        x = 0,
        y = 120
    },
    scale = 1,
    opacity = 1,
    width = 300,
    rowHeight = 24,
    fontSize = 14,
    backgroundOpacity = 0.85
})

local ENCOUNTER_ID = 3492
local INSTANCE_ID = 3004
local SPELL_GRASPING_FANGS = 1311611
local DURATION = 40
local ROWS = 3
local COLUMN_GAP = 8
local ROW_SPACING = 2
local PREVIEW_UPDATE_INTERVAL = 0.05
local TIMERS = {
    [15] = {195},
    [16] = {195}
}
local COLUMN_COLORS = {
    {0.72, 0.02, 0.02, 1},
    {0.02, 0.20, 0.78, 1}
}
local PREVIEW_CLASSES = {
    "WARRIOR",
    "PRIEST",
    "ROGUE",
    "MAGE",
    "PALADIN",
    "HUNTER"
}
local PREVIEW_ROLES = {
    "TANK",
    "HEALER",
    "DAMAGER",
    "DAMAGER",
    "HEALER",
    "DAMAGER"
}

local noop = function() end
local UlatekFangs = E:NewModule("BossMods_UlatekFangs", "AceEvent-3.0", "AceTimer-3.0")

local function currentLocationIsSupported()
    local _, _, _, _, _, _, _, mapID = GetInstanceInfo()
    return mapID == INSTANCE_ID
end

local function areAurasRestricted()
    if not C_Secrets or type(C_Secrets.ShouldAurasBeSecret) ~= "function" then
        return false
    end

    local ok, restricted = pcall(C_Secrets.ShouldAurasBeSecret)
    return not ok or restricted == true
end

local function loadAuraContainer()
    if not C_AddOns or type(C_AddOns.LoadAddOn) ~= "function" then
        return false
    end

    if not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        local ok = pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
        if not ok then
            return false
        end
    end

    return C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") == true
end

local function getDisplayName(unit)
    if E.GetNickname then
        local nick = E:GetNickname(unit)
        if type(nick) == "string" and nick ~= "" then
            return nick
        end
    end

    return (UnitNameUnmodified and UnitNameUnmodified(unit))
        or UnitName(unit)
        or unit
end

local function getClassFile(unit)
    local classFile = UnitClassBase and UnitClassBase(unit)
    if not classFile then
        local _, fallback = UnitClass(unit)
        classFile = fallback
    end

    return classFile
end

local function getClassColor(state)
    local classFile = state.classFile or getClassFile(state.unit)
    local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]

    if color then
        return color.r, color.g, color.b, 1
    end

    return 1, 1, 1, 1
end

local function getRoleAtlas(role)
    if E.GetRoleIconAtlas then
        return E:GetRoleIconAtlas(role)
    end

    return nil
end

local function refreshUnitStateIdentity(state)
    state.displayName = getDisplayName(state.unit)
    state.classFile = getClassFile(state.unit)

    local role = E.GetUnitRole and E:GetUnitRole(state.unit)
        or UnitGroupRolesAssigned and UnitGroupRolesAssigned(state.unit)
    state.role = role
    state.roleAtlas = getRoleAtlas(role)
end

local function getSpellIcon()
    local info = C_Spell and C_Spell.GetSpellInfo
        and C_Spell.GetSpellInfo(SPELL_GRASPING_FANGS)
    return info and info.iconID or 134400
end

function UlatekFangs:GetLayout()
    local width = math.max(180, tonumber(self.db.width) or 300)
    local rowHeight = math.max(16, tonumber(self.db.rowHeight) or 24)
    local iconSize = rowHeight
    local columnWidth = math.floor((width - COLUMN_GAP) / 2)
    local totalHeight = ROWS * rowHeight + (ROWS - 1) * ROW_SPACING

    return {
        width = width,
        columnWidth = columnWidth,
        rowHeight = rowHeight,
        iconSize = iconSize,
        totalHeight = totalHeight,
        barWidth = math.max(1, columnWidth - iconSize)
    }
end

function UlatekFangs:ConfigureButton(state, button)
    local layout = self:GetLayout()
    local fillColor = COLUMN_COLORS[state.column] or COLUMN_COLORS[1]
    local fontSize = math.max(8, tonumber(self.db.fontSize) or 14)
    local roleSize = math.max(10, math.min(16, layout.rowHeight - 6))
    local showRole = roleSize > 0 and state.roleAtlas ~= nil

    if not state.buttonRegions[button] then
        local regions = {}
        regions.bar = CreateFrame("StatusBar", nil, button, "BackdropTemplate")
        regions.bar:SetBackdrop({
            bgFile = E.media.blankTex,
            insets = {left = 0, right = 0, top = 0, bottom = 0}
        })

        regions.icon = button:CreateTexture(nil, "ARTWORK")
        regions.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button:SetIcon(regions.icon)

        regions.border = CreateFrame("Frame", nil, button, "BackdropTemplate")
        regions.border:SetBackdrop({
            edgeFile = E.media.blankTex,
            edgeSize = 1
        })

        regions.name = regions.bar:CreateFontString(nil, "OVERLAY")
        regions.duration = regions.bar:CreateFontString(nil, "OVERLAY")
        regions.role = regions.bar:CreateTexture(nil, "OVERLAY")
        state.buttonRegions[button] = regions
    end

    local regions = state.buttonRegions[button]
    button:SetSize(layout.columnWidth, layout.rowHeight)

    regions.icon:SetSize(layout.iconSize, layout.iconSize)
    regions.icon:ClearAllPoints()
    regions.icon:SetPoint("LEFT", button, "LEFT", 0, 0)

    regions.bar:SetSize(layout.barWidth, layout.rowHeight)
    regions.bar:ClearAllPoints()
    regions.bar:SetPoint("LEFT", regions.icon, "RIGHT", 0, 0)
    regions.bar:SetStatusBarTexture(E.media.blankTex)
    regions.bar:SetStatusBarColor(unpack(fillColor))
    regions.bar:SetBackdropColor(0, 0, 0, self.db.backgroundOpacity or 0.85)

    regions.border:SetAllPoints(button)
    regions.border:SetBackdropBorderColor(0, 0, 0, 1)

    regions.role:ClearAllPoints()
    if showRole then
        regions.role:SetTexCoord(0, 1, 0, 1)
        regions.role:SetVertexColor(1, 1, 1, 1)
        regions.role:SetAlpha(1)
        regions.role:SetAtlas(state.roleAtlas, false)
        regions.role:SetSize(roleSize, roleSize)
        regions.role:SetPoint("LEFT", regions.bar, "LEFT", 4, 0)
        regions.role:Show()
    else
        regions.role:Hide()
    end

    regions.name:ClearAllPoints()
    if showRole then
        regions.name:SetPoint("LEFT", regions.role, "RIGHT", 4, 0)
    else
        regions.name:SetPoint("LEFT", regions.bar, "LEFT", 5, 0)
    end
    regions.name:SetPoint("RIGHT", regions.bar, "RIGHT", -34, 0)
    regions.name:SetFont([[Fonts\FRIZQT__.TTF]], fontSize, "OUTLINE")
    regions.name:SetJustifyH("LEFT")
    regions.name:SetText(state.displayName or "")
    regions.name:SetTextColor(getClassColor(state))
    regions.name:Show()

    regions.duration:ClearAllPoints()
    regions.duration:SetPoint("RIGHT", regions.bar, "RIGHT", -4, 0)
    regions.duration:SetFont([[Fonts\FRIZQT__.TTF]], math.max(8, fontSize - 2), "OUTLINE")
    regions.duration:SetJustifyH("RIGHT")
    regions.duration:SetTextColor(1, 1, 1, 1)
    regions.duration:Show()

    button:SetDurationText(regions.duration)
    button:SetDurationBar(regions.bar, {
        direction = Enum.StatusBarTimerDirection.RemainingTime
    })
end

function UlatekFangs:EnsureFrames()
    if self.frames then
        return true
    end

    local anchor = CreateFrame(
        "Frame",
        "ART_UlatekFangsOverview",
        UIParent,
        "DisableUntrustedLayoutScriptsTemplate"
    )
    anchor:SetClampedToScreen(true)
    anchor:Hide()

    local columns = {}
    for column = 1, 2 do
        columns[column] = CreateFrame(
            "Frame",
            nil,
            anchor,
            "DisableUntrustedLayoutScriptsTemplate"
        )
    end

    self.frames = {
        anchor = anchor,
        columns = columns
    }
    self:ApplySettings()

    return true
end

function UlatekFangs:ApplySettings()
    if not self.frames then
        return
    end

    local layout = self:GetLayout()
    local f = self.frames

    f.anchor:SetSize(layout.width, layout.totalHeight)
    f.anchor:SetScale(self.db.scale or 1)
    f.anchor:SetAlpha(self.db.opacity or 1)
    E:ApplyFramePosition(f.anchor, self.db.position)

    f.columns[1]:ClearAllPoints()
    f.columns[1]:SetPoint("TOPLEFT", f.anchor, "TOPLEFT", 0, 0)
    f.columns[1]:SetSize(layout.columnWidth, layout.totalHeight)
    f.columns[2]:ClearAllPoints()
    f.columns[2]:SetPoint("TOPRIGHT", f.anchor, "TOPRIGHT", 0, 0)
    f.columns[2]:SetSize(layout.columnWidth, layout.totalHeight)

    if self.containers then
        for _, state in ipairs(self.containers) do
            state.container:SetAuraGroupLayout("UlatekGraspingFangs", {
                elementWidth = layout.columnWidth,
                elementHeight = layout.rowHeight + ROW_SPACING,
                elementSpacing = 0,
                lineSpacing = 0
            })

            if not areAurasRestricted() then
                for button in pairs(state.buttonRegions) do
                    self:ConfigureButton(state, button)
                end
            end
        end
    end

    self:LayoutContainers()
    self:LayoutPreviewRows()
end

function UlatekFangs:LayoutContainers()
    if not self.containers or not self.frames then
        return
    end

    local groupCount = math.max(20, GetNumGroupMembers() or 0)
    local splitIndex = math.ceil(groupCount / 2)
    local previous = {}

    for _, state in ipairs(self.containers) do
        local raidIndex = tonumber(state.unit:match("raid(%d+)")) or 1
        local column = raidIndex <= splitIndex and 1 or 2

        if column ~= state.column then
            state.column = column
            if not areAurasRestricted() then
                for button in pairs(state.buttonRegions) do
                    self:ConfigureButton(state, button)
                end
            end
        end

        state.container:ClearAllPoints()
        if previous[column] then
            state.container:SetPoint("TOPLEFT", previous[column], "BOTTOMLEFT", 0, 0)
        else
            state.container:SetPoint(
                "TOPLEFT",
                self.frames.columns[column],
                "TOPLEFT",
                0,
                0
            )
        end
        previous[column] = state.container
    end
end

function UlatekFangs:UpdateContainerNames()
    if areAurasRestricted() then
        return
    end

    for _, state in ipairs(self.containers or {}) do
        refreshUnitStateIdentity(state)

        for button in pairs(state.buttonRegions) do
            self:ConfigureButton(state, button)
        end
    end
end

function UlatekFangs:EnsureContainers()
    if not self:EnsureFrames() or not loadAuraContainer() then
        return false
    end
    if self.containers then
        self:LayoutContainers()
        return true
    end

    self.containers = {}
    local layout = self:GetLayout()

    for raidIndex = 1, 40 do
        local unit = "raid" .. raidIndex
        local state = {
            unit = unit,
            column = raidIndex <= 10 and 1 or 2,
            buttonRegions = {}
        }
        refreshUnitStateIdentity(state)

        local container = CreateFrame(
            "AuraContainer",
            nil,
            self.frames.anchor,
            "CustomAuraContainerTemplate,DisableUntrustedLayoutScriptsTemplate"
        )
        state.container = container
        container:SetFrameStrata("HIGH")
        container:SetUnit(unit)
        container:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Vertical)
        container:SetFlowLayoutAnchorPoint("TOPLEFT")
        container:SetFlowLayoutGrowthDirection(
            AnchorUtil.FlowDirection.Right,
            AnchorUtil.FlowDirection.Down
        )
        container:AddAuraGroup("UlatekGraspingFangs", "HARMFUL|!PLAYER|!DISPELLABLE", {
            maxFrameCount = 2,
            candidateFilters = {isBossOrRoleAura = true},
            initializeFrame = function(button)
                self:ConfigureButton(state, button)
            end,
            layout = {
                elementWidth = layout.columnWidth,
                elementHeight = layout.rowHeight + ROW_SPACING,
                elementSpacing = 0,
                lineSpacing = 0
            }
        })
        container:SetEnabled(false)
        container:Hide()
        container:SetSize(0, 0)
        self.containers[#self.containers + 1] = state
    end

    self:LayoutContainers()
    return true
end

function UlatekFangs:SetContainersShown(shown)
    if shown and not self:EnsureContainers() then
        return false
    end

    self:UpdateContainerNames()

    for _, state in ipairs(self.containers or {}) do
        local visible = shown
            and UnitExists(state.unit)
            and UnitIsVisible(state.unit)

        state.container:SetShown(visible)
        state.container:SetEnabled(visible)
        if not visible then
            state.container:SetSize(0, 0)
        end
    end

    return true
end

function UlatekFangs:EnsurePreviewRows()
    if not self:EnsureFrames() then
        return
    end
    if self.previewRows then
        return
    end

    self.previewRows = {}
    for column = 1, 2 do
        self.previewRows[column] = {}

        for rowIndex = 1, ROWS do
            local index = rowIndex + (column - 1) * ROWS
            local row = CreateFrame("Frame", nil, self.frames.columns[column], "BackdropTemplate")
            row.SetIcon = noop
            row.SetDurationText = noop
            row.SetDurationBar = noop
            row.fangsState = {
                unit = "player",
                column = column,
                classFile = PREVIEW_CLASSES[(index - 1) % #PREVIEW_CLASSES + 1],
                role = PREVIEW_ROLES[(index - 1) % #PREVIEW_ROLES + 1],
                buttonRegions = {}
            }
            row.fangsState.roleAtlas = getRoleAtlas(row.fangsState.role)
            row:Hide()
            self.previewRows[column][rowIndex] = row
        end
    end
end

function UlatekFangs:LayoutPreviewRows()
    if not self.previewRows then
        return
    end

    local icon = getSpellIcon()

    for column, rows in ipairs(self.previewRows) do
        local previous

        for rowIndex, row in ipairs(rows) do
            local index = rowIndex + (column - 1) * ROWS
            local state = row.fangsState
            state.column = column
            state.displayName = ("Player%d"):format(index)
            self:ConfigureButton(state, row)

            local regions = state.buttonRegions[row]
            if regions then
                regions.icon:SetTexture(icon)
                regions.bar:SetMinMaxValues(0, 1)
            end

            row:ClearAllPoints()
            if previous then
                row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -ROW_SPACING)
            else
                row:SetPoint("TOPLEFT", self.frames.columns[column], "TOPLEFT", 0, 0)
            end
            previous = row
        end
    end
end

function UlatekFangs:UpdatePreviewBars()
    if not self.previewRows then
        return
    end

    local startedAt = self.previewStartedAt or GetTime()
    local elapsed = (GetTime() - startedAt) % DURATION

    for column, rows in ipairs(self.previewRows) do
        for rowIndex, row in ipairs(rows) do
            local index = rowIndex + (column - 1) * ROWS
            local state = row.fangsState
            local regions = state
                and state.buttonRegions
                and state.buttonRegions[row]

            if regions then
                local rowElapsed = (elapsed + (index - 1) * 2.5) % DURATION
                local remaining = math.max(0, DURATION - rowElapsed)
                regions.bar:SetMinMaxValues(0, 1)
                regions.bar:SetValue(remaining / DURATION)
                regions.duration:SetText(("%d"):format(math.ceil(remaining)))
            end
        end
    end
end

function UlatekFangs:StartPreviewTicker()
    if self.previewTicker then
        return
    end

    self.previewStartedAt = GetTime()
    self:UpdatePreviewBars()
    self.previewTicker = C_Timer.NewTicker(PREVIEW_UPDATE_INTERVAL, function()
        if self:IsEnabled() and self.editMode then
            self:UpdatePreviewBars()
        end
    end)
end

function UlatekFangs:StopPreviewTicker()
    if self.previewTicker then
        self.previewTicker:Cancel()
        self.previewTicker = nil
    end
    self.previewStartedAt = nil
end

function UlatekFangs:SetPreviewShown(shown)
    if shown then
        self:EnsurePreviewRows()
        self:LayoutPreviewRows()
        self:StartPreviewTicker()
    else
        self:StopPreviewTicker()
    end

    for _, rows in pairs(self.previewRows or {}) do
        for _, row in ipairs(rows) do
            row:SetShown(shown == true)
        end
    end
end

function UlatekFangs:ApplyVisibility()
    if not self.frames or not self:IsEnabled() then
        return
    end

    if self.editMode or self.liveShown then
        self.frames.anchor:Show()
    else
        self.frames.anchor:Hide()
    end
end

function UlatekFangs:StartOverview(duration)
    if not self:IsEnabled() then
        return
    end
    if not self:SetContainersShown(true) then
        return
    end

    self.liveShown = true
    self:SetPreviewShown(false)
    self:ApplyVisibility()

    if self.hideTimer then
        self:CancelTimer(self.hideTimer)
    end
    self.hideTimer = self:ScheduleTimer(function()
        self.hideTimer = nil
        self:StopOverview()
    end, duration or DURATION)
end

function UlatekFangs:StopOverview()
    if self.hideTimer then
        self:CancelTimer(self.hideTimer)
        self.hideTimer = nil
    end

    self.liveShown = false
    self:SetContainersShown(false)
    if self.editMode then
        self:SetPreviewShown(true)
    end
    self:ApplyVisibility()
end

function UlatekFangs:CancelEncounterTimers()
    for _, timer in ipairs(self.encounterTimers or {}) do
        self:CancelTimer(timer)
    end
    self.encounterTimers = {}
end

function UlatekFangs:ScheduleOverview(difficultyID)
    self:CancelEncounterTimers()
    self:StopOverview()

    local timers = TIMERS[tonumber(difficultyID)]
    if not timers then
        return
    end

    self.encounterTimers = {}
    local encounterStart = self.encounterStartTime or GetTime()
    local elapsed = GetTime() - encounterStart

    for _, applyTime in ipairs(timers) do
        local remaining = applyTime + DURATION - elapsed

        if elapsed >= applyTime and remaining > 0 then
            self:StartOverview(remaining)
        elseif elapsed < applyTime then
            self.encounterTimers[#self.encounterTimers + 1] =
                self:ScheduleTimer(function()
                    if self.encounterActive then
                        self:StartOverview(DURATION)
                    end
                end, applyTime - elapsed)
        end
    end
end

function UlatekFangs:SetEditMode(value)
    self.editMode = value and true or false
    if self.editMode then
        self:SetContainersShown(false)
        self:SetPreviewShown(true)
    else
        self:SetPreviewShown(false)
        if self.liveShown then
            self:SetContainersShown(true)
        end
    end
    self:ApplyVisibility()
end

function UlatekFangs:SavePosition(position)
    local saved = self.db.position
    saved.point = position.point
    saved.x = position.x
    saved.y = position.y
    self:ApplySettings()
end

function UlatekFangs:Refresh()
    if not self:IsEnabled() then
        return
    end

    self:EnsureFrames()
    self:ApplySettings()
    if self.editMode then
        self:SetPreviewShown(true)
    end
    if self.liveShown then
        self:SetContainersShown(true)
    end
    self:ApplyVisibility()
end

function UlatekFangs:OnRosterChanged()
    self:LayoutContainers()
    self:UpdateContainerNames()
    if self.liveShown then
        self:SetContainersShown(true)
    end
end

function UlatekFangs:OnEncounterStart(_, encounterID, _, difficultyID)
    if encounterID ~= ENCOUNTER_ID or not currentLocationIsSupported() then
        return
    end

    self.encounterActive = true
    self.difficultyID = difficultyID
    self.encounterStartTime = GetTime()
    self:ScheduleOverview(difficultyID)
end

function UlatekFangs:OnEncounterEnd(_, encounterID)
    if encounterID ~= ENCOUNTER_ID then
        return
    end

    self.encounterActive = false
    self.difficultyID = nil
    self.encounterStartTime = nil
    self:CancelEncounterTimers()
    self:StopOverview()
end

function UlatekFangs:OnInitialize()
    self.encounterActive = false
    self.editMode = false
    self.liveShown = false
    self.encounterTimers = {}
    self:EnsureFrames()
    if self.frames then
        self.frames.anchor:Hide()
    end
end

function UlatekFangs:OnEnable()
    self:EnsureFrames()
    self:ApplySettings()
    self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
    self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "OnRosterChanged")
    self:RegisterMessage("ART_NICKNAME_CHANGED", "OnRosterChanged")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Refresh")
    self:ApplyVisibility()
end

function UlatekFangs:OnDisable()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    self.encounterActive = false
    self.editMode = false
    self.liveShown = false
    self:CancelEncounterTimers()
    self:StopOverview()
    self:SetPreviewShown(false)
    if self.frames then
        self.frames.anchor:Hide()
    end
end

E:RegisterBossModFeature("UlatekFangs", {
    tab = "AbyssCustom",
    order = 65,
    labelKey = "BossMods_UlatekGraspingFangsOverview",
    descKey = "BossMods_UlatekGraspingFangsOverviewDesc",
    moduleName = "BossMods_UlatekFangs"
})
