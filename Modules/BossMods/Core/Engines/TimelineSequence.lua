local E, L = unpack(ART)

local BossMods = E:GetModule("BossMods")
local Engines = BossMods.Engines
local Shared = Engines.Shared

local colorTuple = Shared.ColorTuple

local function clamp(value, minValue, maxValue, fallback)
    value = tonumber(value) or fallback
    if value < minValue then
        return minValue
    elseif value > maxValue then
        return maxValue
    end
    return value
end

local function copyColor(value, fallback)
    value = value or fallback or {}

    return {
        value[1] or value.r or 1,
        value[2] or value.g or 1,
        value[3] or value.b or 1,
        value[4] or value.a or 1
    }
end

local function copyPosition(value)
    value = value or {}

    return {
        point = value.point or "CENTER",
        x = tonumber(value.x) or 0,
        y = tonumber(value.y) or 0
    }
end

local function textValue(entry, fallback)
    if not entry then
        return fallback or ""
    end

    local key = entry.textKey or entry.labelKey
    return entry.text or entry.label or (key and L[key]) or fallback or ""
end

local function rowState(sequence, row)
    return sequence and sequence.rows and sequence.rows[row.key]
end

local function rowEndTime(sequence, row)
    local state = rowState(sequence, row)
    if not state then
        return 0
    end

    local phases = state.phases or state.stages
    if phases then
        local total = tonumber(state.start) or 0

        for _, phase in ipairs(phases) do
            total = total + (tonumber(phase.duration) or 0)
        end

        return total
    end

    return (tonumber(state.start) or 0) + (tonumber(state.duration) or 0)
end

local function sequenceEnd(definition, sequence)
    local endTime = tonumber(sequence and sequence.duration) or 0

    for _, row in ipairs(definition.rows or {}) do
        endTime = math.max(endTime, rowEndTime(sequence, row))
    end

    return endTime
end

local function defaultPreviewSequenceKey(definition)
    if definition.previewSequenceKey ~= nil then
        return definition.previewSequenceKey
    end

    local firstKey
    local highest

    for key in pairs(definition.sequences or {}) do
        firstKey = firstKey or key
        if type(key) == "number" and (not highest or key > highest) then
            highest = key
        end
    end

    return highest or firstKey
end

local function findActivePhase(state, elapsed)
    local phases = state.phases or state.stages
    if not phases then
        return nil
    end

    local cursor = tonumber(state.start) or 0
    for _, phase in ipairs(phases) do
        local duration = tonumber(phase.duration) or 0
        local phaseEnd = cursor + duration

        if elapsed >= cursor and elapsed < phaseEnd then
            return phase, phaseEnd - elapsed, duration
        end

        cursor = phaseEnd
    end
end

function Engines.TimelineSequence(config)
    assert(type(config) == "table", "Engines.TimelineSequence: config required")
    assert(config.parent, "Engines.TimelineSequence: config.parent required")
    assert(type(config.definition) == "table", "Engines.TimelineSequence: definition required")
    assert(type(config.getSettings) == "function", "Engines.TimelineSequence: getSettings required")

    local state = {
        active = false,
        editMode = false,
        previewMode = false,
        activeSequence = nil,
        bars = {},
        config = config
    }

    local function definition()
        return state.config.definition
    end

    local function settings()
        local db = state.config.getSettings() or {}
        local def = definition()

        db.position = db.position or copyPosition(def.position)
        db.width = clamp(db.width, 140, 900, def.width or 360)
        db.height = clamp(db.height, 10, 80, def.height or 24)
        db.spacing = clamp(db.spacing, 0, 30, def.spacing or 4)
        db.scale = clamp(db.scale, 0.5, 2, 1)
        db.opacity = clamp(db.opacity, 0.1, 1, 1)
        db.backgroundOpacity = clamp(db.backgroundOpacity, 0, 1, 0.65)
        db.statusBarTexture = db.statusBarTexture or def.statusBarTexture or "Blizzard"
        db.textOnly = db.textOnly == true
        db.barColors = db.barColors or {}

        for _, row in ipairs(def.rows or {}) do
            db.barColors[row.key] = copyColor(db.barColors[row.key], row.color)
        end

        db.font = db.font or {}
        db.font.name = db.font.name or "Friz Quadrata TT"
        db.font.size = clamp(db.font.size, 8, 48, 14)
        if db.font.outline == nil then
            db.font.outline = "OUTLINE"
        end
        db.font.color = copyColor(db.font.color, {1, 1, 1, 1})

        return db
    end

    local function buildBarConfig(row)
        local db = settings()
        local color = copyColor(db.barColors[row.key], row.color)
        local fontColor = copyColor(db.font.color, {1, 1, 1, 1})

        if db.textOnly then
            color[4] = 0
        end

        return {
            parent = state.anchor,
            showFill = true,
            strata = definition().strata or "HIGH",
            size = {
                w = db.width,
                h = db.height
            },
            icon = {
                enabled = false
            },
            statusBar = {
                texture = db.statusBarTexture,
                color = color
            },
            label = {
                font = db.font.name,
                size = db.font.size,
                outline = db.font.outline,
                color = fontColor,
                justify = "LEFT"
            },
            right = {
                font = db.font.name,
                size = db.font.size,
                outline = db.font.outline,
                color = fontColor,
                justify = "RIGHT"
            },
            center = {
                font = db.font.name,
                size = db.font.size,
                outline = db.font.outline,
                color = fontColor,
                justify = "CENTER"
            },
            background = {
                color = {0, 0, 0, 1},
                opacity = db.textOnly and 0 or db.backgroundOpacity
            },
            border = {
                enabled = not db.textOnly,
                texture = "Pixel",
                size = 1,
                color = {0, 0, 0, 1}
            }
        }
    end

    local function ensureFrames()
        if state.anchor then
            return true
        end

        local def = definition()
        local anchor = CreateFrame(
            "Frame",
            def.frameName or ("ART_" .. def.featureKey),
            state.config.parent,
            "DisableUntrustedLayoutScriptsTemplate"
        )
        anchor:SetClampedToScreen(true)
        anchor:SetFrameStrata(def.strata or "HIGH")
        anchor:EnableMouse(false)
        anchor:Hide()
        anchor:SetScript("OnUpdate", function()
            state.handle:UpdateDisplay()
        end)

        state.anchor = anchor

        for index, row in ipairs(def.rows or {}) do
            local bar = Engines.Bar(buildBarConfig(row))
            bar:SetMode("label")
            state.bars[index] = {
                definition = row,
                handle = bar
            }
        end

        return true
    end

    local function applyLayout()
        local db = settings()
        local rowCount = #(definition().rows or {})
        local totalHeight = rowCount > 0
            and rowCount * db.height + (rowCount - 1) * db.spacing
            or db.height

        state.anchor:SetSize(db.width, totalHeight)
        state.anchor:SetScale(db.scale)
        state.anchor:SetAlpha(db.opacity)
        E:ApplyFramePosition(state.anchor, db.position)

        local offset = 0
        for _, entry in ipairs(state.bars) do
            entry.handle:Apply(buildBarConfig(entry.definition))
            entry.handle.frame:ClearAllPoints()
            entry.handle.frame:SetPoint("TOP", state.anchor, "TOP", 0, -offset)
            entry.handle:SetMode(db.textOnly and "center" or "label")
            offset = offset + db.height + db.spacing
        end
    end

    local function displayedSequence()
        local def = definition()

        if state.previewMode or state.editMode then
            state.previewStartedAt = state.previewStartedAt or GetTime()

            local key = defaultPreviewSequenceKey(def)
            local sequence = def.sequences and def.sequences[key]
            if not sequence then
                return nil
            end

            local duration = math.max(sequenceEnd(def, sequence), 1)
            local elapsed = (GetTime() - state.previewStartedAt) % (duration + 1)

            return key, sequence, elapsed, true
        end

        if not state.activeSequence then
            return nil
        end

        local sequence = def.sequences and def.sequences[state.activeSequence.key]
        if not sequence then
            return nil
        end

        return state.activeSequence.key,
            sequence,
            GetTime() - state.activeSequence.startedAt,
            false
    end

    local function applyBarState(entry, label, remaining, total)
        local db = settings()
        remaining = math.max(0, remaining or 0)
        total = math.max(0.001, tonumber(total) or 0.001)

        entry.handle:SetMode(db.textOnly and "center" or "label")
        entry.handle:SetLabel(label)
        entry.handle:SetRight(("%.1f"):format(remaining))
        entry.handle:SetCenter(("%s %.1f"):format(label, remaining))
        entry.handle:SetValue(remaining / total)
        entry.handle:Show()
    end

    local handle = {}
    state.handle = handle

    function handle:GetFrame()
        ensureFrames()
        return state.anchor
    end

    function handle:SetActive(value)
        state.active = value == true
        ensureFrames()
        if not state.active then
            self:Stop()
        else
            self:UpdateDisplay()
        end
    end

    function handle:SetEditMode(value)
        state.editMode = value == true
        state.previewStartedAt = state.editMode and GetTime() or state.previewStartedAt
        ensureFrames()
        self:UpdateDisplay()
    end

    function handle:SetPreviewMode(value)
        state.previewMode = value == true
        state.previewStartedAt = state.previewMode and GetTime() or state.previewStartedAt
        ensureFrames()
        self:UpdateDisplay()
    end

    function handle:StartSequence(sequenceKey)
        ensureFrames()

        if not state.active or not definition().sequences[sequenceKey] then
            return
        end

        state.activeSequence = {
            key = sequenceKey,
            startedAt = GetTime()
        }
        self:UpdateDisplay()
    end

    function handle:Stop()
        state.activeSequence = nil

        for _, entry in ipairs(state.bars) do
            entry.handle:Hide()
        end

        if state.anchor and not state.editMode and not state.previewMode then
            state.anchor:Hide()
        end
    end

    function handle:UpdateDisplay()
        ensureFrames()

        local _, sequence, elapsed, preview = displayedSequence()
        if not sequence then
            self:Stop()
            return
        end

        local anyShown = false

        for _, entry in ipairs(state.bars) do
            local row = rowState(sequence, entry.definition)
            local shown = false

            if row then
                local phase, remaining, total = findActivePhase(row, elapsed)

                if phase then
                    applyBarState(
                        entry,
                        textValue(phase, textValue(entry.definition)),
                        remaining,
                        total
                    )
                    shown = true
                elseif row.duration then
                    local start = tonumber(row.start) or 0
                    local duration = tonumber(row.duration) or 0
                    local remainingTime = start + duration - elapsed

                    if elapsed >= start and remainingTime > 0 then
                        applyBarState(
                            entry,
                            textValue(row, textValue(entry.definition)),
                            remainingTime,
                            duration
                        )
                        shown = true
                    end
                end
            end

            if shown then
                anyShown = true
            else
                entry.handle:Hide()
            end
        end

        if not preview and elapsed >= sequenceEnd(definition(), sequence) then
            self:Stop()
            return
        end

        state.anchor:SetShown(anyShown or state.editMode or state.previewMode)
    end

    function handle:Apply(newConfig)
        if type(newConfig) == "table" then
            state.config = newConfig
        end

        ensureFrames()
        applyLayout()
        self:UpdateDisplay()
    end

    function handle:Refresh()
        self:Apply()
    end

    function handle:Release()
        state.active = false
        state.editMode = false
        state.previewMode = false
        state.previewStartedAt = nil
        self:Stop()
    end

    ensureFrames()
    applyLayout()

    return handle
end

function BossMods:RegisterTimelineSequenceFeature(definition)
    assert(type(definition) == "table", "RegisterTimelineSequenceFeature: definition required")
    assert(type(definition.featureKey) == "string" and definition.featureKey ~= "",
        "RegisterTimelineSequenceFeature: featureKey required")
    assert(type(definition.moduleName) == "string" and definition.moduleName ~= "",
        "RegisterTimelineSequenceFeature: moduleName required")

    local barColors = {}
    for _, row in ipairs(definition.rows or {}) do
        barColors[row.key] = copyColor(row.color)
    end

    E:RegisterModuleDefaults(definition.moduleName, {
        enabled = definition.defaultEnabled == true,
        position = copyPosition(definition.position),
        width = definition.width or 360,
        height = definition.height or 24,
        spacing = definition.spacing or 4,
        scale = 1,
        opacity = 1,
        textOnly = false,
        statusBarTexture = definition.statusBarTexture or "Blizzard",
        backgroundOpacity = 0.65,
        barColors = barColors,
        font = {
            name = "Friz Quadrata TT",
            size = 14,
            outline = "OUTLINE",
            color = {1, 1, 1, 1}
        }
    })

    local module = E:NewModule(definition.moduleName, "AceEvent-3.0")
    module.definition = definition

    function module:EnsureDisplay()
        if not self.display then
            self.display = Engines.TimelineSequence({
                parent = UIParent,
                definition = self.definition,
                getSettings = function()
                    return self.db
                end
            })
        end

        return self.display
    end

    function module:EnsureDefaults()
        if self.display then
            self.display:Apply()
        end
    end

    function module:Refresh()
        if self.display then
            self.display:Refresh()
        elseif self:IsEnabled() then
            self:EnsureDisplay():SetActive(true)
        end
    end

    function module:SetEditMode(value)
        self.editMode = value == true
        self:EnsureDisplay():SetEditMode(value)
    end

    function module:SetPreviewMode(value)
        self.previewMode = value == true
        self:EnsureDisplay():SetPreviewMode(value)
    end

    function module:SavePosition(position)
        self.db.position = copyPosition(position)
        self:Refresh()
    end

    function module:CancelPendingTimers()
        for timer in pairs(self.pendingTimers or {}) do
            timer:Cancel()
        end
        self.pendingTimers = {}
    end

    function module:SequenceKeyForCount(count)
        local keys = self.definition.sequenceKeys
        return keys and keys[count] or count
    end

    function module:StartSequence(sequenceKey)
        if not self.encounterActive then
            return
        end

        self:EnsureDisplay():StartSequence(sequenceKey)
    end

    function module:ScheduleSequence(duration)
        duration = tonumber(duration)
        if not self.encounterActive or not duration then
            return
        end

        local requiredStage = self.definition.stageRequired
        if requiredStage and tonumber(self.stage) ~= tonumber(requiredStage) then
            return
        end

        local delay = math.max(0, duration + (tonumber(self.definition.triggerOffset) or 0))
        local target = GetTime() + delay
        local duplicateWindow = tonumber(self.definition.duplicateWindow) or 2
        local sequenceKey

        self.pendingTimers = self.pendingTimers or {}
        for timer, data in pairs(self.pendingTimers) do
            if data.target and math.abs(data.target - target) <= duplicateWindow then
                sequenceKey = data.sequenceKey
                timer:Cancel()
                self.pendingTimers[timer] = nil
            end
        end

        if sequenceKey == nil then
            local nextCount = (self.sequenceCount or 0) + 1
            local maxCount = tonumber(self.definition.maxSequenceCount)

            if maxCount and nextCount > maxCount then
                return
            end

            sequenceKey = self:SequenceKeyForCount(nextCount)
            if not self.definition.sequences[sequenceKey] then
                return
            end

            self.sequenceCount = nextCount
        end

        local timer
        timer = C_Timer.NewTimer(delay, function()
            self.pendingTimers[timer] = nil
            self:StartSequence(sequenceKey)
        end)
        self.pendingTimers[timer] = {
            target = target,
            sequenceKey = sequenceKey
        }
    end

    function module:OnBigWigsStartBar(key, _, duration)
        local timerSpellID = self.definition.timerSpellID

        if key == timerSpellID or tonumber(key) == tonumber(timerSpellID) then
            self:ScheduleSequence(duration)
        end
    end

    function module:OnBigWigsStage(moduleInfo, stage)
        if not self.encounterActive
            or not moduleInfo
            or moduleInfo.moduleName ~= (self.definition.bigWigsModuleName or "Ula'tek")
        then
            return
        end

        self.stage = tonumber(stage) or self.stage

        local endStage = tonumber(self.definition.endStage)
        if endStage and self.stage and self.stage >= endStage then
            self:CancelPendingTimers()
            if self.display then
                self.display:Stop()
            end
        end
    end

    function module:HookBigWigs()
        if self.bigWigsSubscription then
            return
        end

        self.bigWigsSubscription = BossMods.BigWigs:Subscribe({
            owner = self.definition.featureKey,
            spellKeys = {self.definition.timerSpellID},
            onStartBar = function(key, text, duration)
                self:OnBigWigsStartBar(key, text, duration)
            end,
            onStage = function(moduleInfo, stage)
                self:OnBigWigsStage(moduleInfo, stage)
            end
        })
    end

    function module:UnhookBigWigs()
        if self.bigWigsSubscription then
            self.bigWigsSubscription:Unsubscribe()
            self.bigWigsSubscription = nil
        end
    end

    function module:OnEncounterStart(_, encounterID)
        if tonumber(encounterID) ~= tonumber(self.definition.encounterID) then
            return
        end

        self.encounterActive = true
        self.stage = tonumber(self.definition.initialStage) or 1
        self.sequenceCount = 0
        self:CancelPendingTimers()
        if self.display then
            self.display:Stop()
        end
    end

    function module:OnEncounterEnd(_, encounterID)
        if tonumber(encounterID) ~= tonumber(self.definition.encounterID) then
            return
        end

        self.encounterActive = false
        self.sequenceCount = 0
        self:CancelPendingTimers()
        if self.display then
            self.display:Stop()
        end
    end

    function module:OnInitialize()
        self.encounterActive = false
        self.stage = tonumber(self.definition.initialStage) or 1
        self.sequenceCount = 0
        self.pendingTimers = {}
        self.editMode = false
        self.previewMode = false
    end

    function module:OnEnable()
        self:EnsureDisplay():SetActive(true)
        self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
        self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
        self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
        self:RegisterMessage("ART_MEDIA_UPDATED", "Refresh")
        self:HookBigWigs()
    end

    function module:OnDisable()
        self:UnhookBigWigs()
        self:UnregisterAllEvents()
        self:UnregisterAllMessages()
        self.encounterActive = false
        self.sequenceCount = 0
        self.editMode = false
        self.previewMode = false
        self:CancelPendingTimers()
        if self.display then
            self.display:SetActive(false)
            self.display:SetEditMode(false)
            self.display:SetPreviewMode(false)
            self.display:Stop()
        end
    end

    E:RegisterBossModFeature(definition.featureKey, {
        tab = definition.tab or "AbyssCustom",
        order = definition.order or 100,
        labelKey = definition.labelKey or definition.featureKey,
        descKey = definition.descKey,
        moduleName = definition.moduleName
    })

    return module
end
