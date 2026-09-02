local E = unpack(ART)

local BossMods = E:GetModule("BossMods")
local Engines = BossMods.Engines
local Shared = Engines.Shared

local fetchFont = Shared.FetchFont
local colorTuple = Shared.ColorTuple
local applyFontIfChanged = Shared.ApplyFontIfChanged

local CIRCLE_MASK = [[Interface\Masks\CircleMaskScalable]]
local FALLBACK_FONT = [[Fonts\FRIZQT__.TTF]]
local PREVIEW_DURATION = 5
local PREVIEW_INTERVAL = 0.05

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

local function areAurasRestricted()
    if not C_Secrets or type(C_Secrets.ShouldAurasBeSecret) ~= "function" then
        return false
    end

    local ok, restricted = pcall(C_Secrets.ShouldAurasBeSecret)
    return not ok or restricted == true
end

local function auraSortMethod()
    return AuraContainerSortMethod
        and AuraContainerSortMethod.Expiration
        or 4
end

local function auraSortDirection()
    return AuraContainerSortDirection
        and AuraContainerSortDirection.Normal
        or 0
end

local function buildSpellSet(spellIDs)
    local out = {}

    for _, spellID in ipairs(spellIDs or {}) do
        spellID = tonumber(spellID)
        if spellID then
            out[spellID] = true
        end
    end

    return next(out) and out or nil
end

local function buildCandidateFilters(definition)
    local filters = {}

    for key, value in pairs(definition.candidateFilters or {}) do
        filters[key] = value
    end

    local includeSpellIDs = buildSpellSet(definition.auraSpellIDs)
    if includeSpellIDs then
        filters.includeSpellIDs = includeSpellIDs
    end

    if definition.maxDuration then
        filters.maxDuration = tonumber(definition.maxDuration)
    end

    if definition.isBossOrRoleAura ~= false then
        filters.isBossOrRoleAura = true
    end

    return filters
end

local function safeCall(method, owner, ...)
    if type(method) ~= "function" then
        return false
    end
    return pcall(method, owner, ...)
end

function Engines.AuraCircle(config)
    assert(type(config) == "table", "Engines.AuraCircle: config required")
    assert(config.parent, "Engines.AuraCircle: config.parent required")
    assert(type(config.definition) == "table", "Engines.AuraCircle: definition required")
    assert(type(config.getSettings) == "function", "Engines.AuraCircle: getSettings required")

    local state = {
        active = false,
        editMode = false,
        previewMode = false,
        liveWindow = false,
        pendingContainer = false,
        auraVisuals = {},
        config = config
    }

    local callbacks = E:NewCallbackHandle()

    local function definition()
        return state.config.definition
    end

    local function settings()
        local db = state.config.getSettings() or {}
        local def = definition()

        db.position = db.position or copyPosition(def.position)
        db.size = clamp(db.size, 30, 180, def.size or 72)
        db.opacity = clamp(db.opacity, 0.1, 1, 1)
        db.backgroundOpacity = clamp(db.backgroundOpacity, 0, 1, 0.72)
        db.color = copyColor(db.color, def.color)
        db.font = db.font or {}
        db.font.name = db.font.name or "Friz Quadrata TT"
        db.font.size = clamp(db.font.size, 8, 72, 24)
        if db.font.outline == nil then
            db.font.outline = "OUTLINE"
        end
        db.font.color = copyColor(db.font.color, {1, 1, 1, 1})

        return db
    end

    local function createVisual(parent)
        local background = parent:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints(parent)

        local mask = parent:CreateMaskTexture()
        mask:SetAllPoints(background)
        mask:SetTexture(
            CIRCLE_MASK,
            "CLAMPTOBLACKADDITIVE",
            "CLAMPTOBLACKADDITIVE"
        )
        background:AddMaskTexture(mask)

        local cooldown = CreateFrame("Cooldown", nil, parent, "CooldownFrameTemplate")
        cooldown:SetAllPoints(parent)
        cooldown:SetReverse(false)
        cooldown:SetDrawEdge(false)
        cooldown:SetDrawBling(false)
        cooldown:SetDrawSwipe(true)
        cooldown:SetSwipeTexture(CIRCLE_MASK)
        cooldown:SetHideCountdownNumbers(false)
        cooldown:SetCountdownMillisecondsThreshold(3)

        local duration = cooldown.GetCountdownFontString
            and cooldown:GetCountdownFontString()

        if duration then
            applyFontIfChanged(duration, fetchFont() or FALLBACK_FONT, 24, "OUTLINE")
            duration:SetTextColor(1, 1, 1, 1)
        end

        local overlay = CreateFrame("Frame", nil, parent, "DisableUntrustedLayoutScriptsTemplate")
        overlay:SetAllPoints(parent)
        overlay:SetFrameLevel(parent:GetFrameLevel() + 20)

        local stacks = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        stacks:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", -3, 3)
        stacks:SetTextColor(1, 1, 1, 1)
        stacks:SetText("")

        return {
            background = background,
            mask = mask,
            cooldown = cooldown,
            duration = duration,
            overlay = overlay,
            stacks = stacks
        }
    end

    local function applyVisual(frame, visual)
        if not frame or not visual then
            return
        end

        local db = settings()
        local r, g, b, a = colorTuple(db.color, 1, 1, 1, 0.95)
        local tr, tg, tb, ta = colorTuple(db.font.color, 1, 1, 1, 1)

        frame:SetSize(db.size, db.size)
        visual.background:SetColorTexture(0, 0, 0, db.backgroundOpacity)
        visual.cooldown:SetSwipeColor(r, g, b, a)

        if visual.duration then
            applyFontIfChanged(
                visual.duration,
                fetchFont(db.font.name) or FALLBACK_FONT,
                db.font.size,
                db.font.outline
            )
            visual.duration:SetTextColor(tr, tg, tb, ta)
        end

        applyFontIfChanged(
            visual.stacks,
            fetchFont(db.font.name) or FALLBACK_FONT,
            math.max(8, math.floor(db.font.size * 0.75)),
            db.font.outline
        )
        visual.stacks:SetTextColor(tr, tg, tb, ta)
        visual.stacks:SetShown(definition().showStacks == true)
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

        local preview = CreateFrame(
            "Frame",
            nil,
            anchor,
            "DisableUntrustedLayoutScriptsTemplate"
        )
        preview:SetAllPoints(anchor)
        preview:Hide()

        state.anchor = anchor
        state.previewFrame = preview
        state.previewVisual = createVisual(preview)
        applyVisual(preview, state.previewVisual)

        return true
    end

    local function initializeAuraButton(button)
        safeCall(button.EnableMouse, button, false)
        safeCall(button.SetMouseMotionEnabled, button, false)
        safeCall(button.SetMouseClickEnabled, button, false)
        safeCall(button.SetCollapsesLayout, button, true)

        local visual = createVisual(button)
        applyVisual(button, visual)

        if button.SetDurationCooldown then
            button:SetDurationCooldown(visual.cooldown)
        end

        if definition().showStacks and button.SetApplicationCount then
            button:SetApplicationCount(visual.stacks)
        else
            visual.stacks:Hide()
        end

        state.auraVisuals[button] = visual
    end

    local function createAuraContainer()
        local def = definition()
        local db = settings()
        local groupKey = def.groupKey or ("ART_AuraCircle_" .. def.featureKey)
        local container = CreateFrame(
            "AuraContainer",
            nil,
            state.anchor,
            "CustomAuraContainerTemplate,DisableUntrustedLayoutScriptsTemplate"
        )

        container:SetAllPoints(state.anchor)
        container:SetSize(db.size, db.size)
        container:SetUnit(def.unit or "player")

        if AnchorUtil and AnchorUtil.FlowLayoutAxis then
            container:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
            container:SetFlowLayoutAnchorPoint(def.anchorPoint or "CENTER")
            container:SetFlowLayoutGrowthDirection(
                AnchorUtil.FlowDirection.Right,
                AnchorUtil.FlowDirection.Down
            )
            container:SetFlowLayoutMaximumLineSize(math.huge)
        end

        container:AddAuraGroup(groupKey, def.filter or "HARMFUL", {
            maxFrameCount = def.maxFrameCount or 1,
            candidateFilters = buildCandidateFilters(def),
            sortMethod = def.sortMethod or auraSortMethod(),
            sortDirection = def.sortDirection or auraSortDirection(),
            initializeFrame = initializeAuraButton,
            layout = {
                elementSpacing = 0,
                elementWidth = db.size,
                elementHeight = db.size
            }
        })

        container:SetEnabled(false)
        container:Hide()

        state.groupKey = groupKey
        state.container = container
        state.pendingContainer = false
    end

    local function ensureAuraContainer()
        if definition().mode ~= "aura" or state.container then
            return true
        end

        ensureFrames()

        if areAurasRestricted() or not loadAuraContainer() then
            state.pendingContainer = true
            return false
        end

        local ok, err = pcall(createAuraContainer)
        if not ok then
            state.pendingContainer = true
            E:ChannelWarn(
                definition().moduleName or "BossMods",
                "Aura circle creation deferred: %s",
                tostring(err)
            )
            return false
        end

        return true
    end

    local function updateContainerLayout()
        if not state.container or not state.groupKey then
            return
        end

        local size = settings().size
        pcall(state.container.SetAuraGroupLayout, state.container, state.groupKey, {
            elementSpacing = 0,
            elementWidth = size,
            elementHeight = size
        })
    end

    local function applyAuraVisuals()
        for button, visual in pairs(state.auraVisuals) do
            local canAccess = true

            if button.CanBeAccessedInContext then
                local ok, access = pcall(button.CanBeAccessedInContext, button)
                canAccess = not ok or access == true
            end

            if canAccess then
                pcall(applyVisual, button, visual)
            end
        end
    end

    local function startPreviewTicker()
        if state.previewTicker then
            return
        end

        state.previewStartedAt = GetTime()
        state.previewTicker = C_Timer.NewTicker(PREVIEW_INTERVAL, function()
            if not state.previewVisual then
                return
            end

            local elapsed = (GetTime() - state.previewStartedAt) % PREVIEW_DURATION
            state.previewVisual.cooldown:SetCooldown(
                GetTime() - elapsed,
                PREVIEW_DURATION
            )

            if definition().showStacks then
                state.previewVisual.stacks:SetText("4")
                state.previewVisual.stacks:Show()
            end
        end)
    end

    local function stopPreviewTicker()
        if state.previewTicker then
            state.previewTicker:Cancel()
            state.previewTicker = nil
        end
        state.previewStartedAt = nil
    end

    local function applyVisibility()
        if not state.anchor then
            return
        end

        local def = definition()
        local previewShown = state.editMode or state.previewMode
        local timedShown = def.mode == "timed"
            and state.active
            and state.liveWindow
            and not previewShown

        state.previewFrame:SetShown(previewShown or timedShown)
        if previewShown then
            startPreviewTicker()
        else
            stopPreviewTicker()
        end

        if state.container then
            local containerShown = def.mode == "aura"
                and state.active
                and state.liveWindow
                and not previewShown

            state.container:SetShown(containerShown)
            state.container:SetEnabled(containerShown)
        end

        state.anchor:SetShown(previewShown or timedShown or state.liveWindow)
    end

    local handle = {
        frame = nil
    }

    function handle:GetFrame()
        ensureFrames()
        self.frame = state.anchor
        return state.anchor
    end

    function handle:SetActive(value)
        state.active = value == true
        ensureFrames()
        if state.active then
            ensureAuraContainer()
        end
        applyVisibility()
    end

    function handle:SetEditMode(value)
        state.editMode = value == true
        ensureFrames()
        applyVisibility()
    end

    function handle:SetPreviewMode(value)
        state.previewMode = value == true
        ensureFrames()
        applyVisibility()
    end

    function handle:SetLiveWindow(value)
        state.liveWindow = value == true
        if state.liveWindow and state.active then
            ensureAuraContainer()
        end
        applyVisibility()
    end

    function handle:StartTimed(duration)
        ensureFrames()

        duration = tonumber(duration) or 0
        if duration <= 0 then
            self:StopLive()
            return
        end

        state.liveWindow = true
        state.previewVisual.cooldown:SetCooldown(GetTime(), duration)
        state.previewVisual.stacks:Hide()
        applyVisibility()

        if state.liveTimer then
            state.liveTimer:Cancel()
        end

        state.liveTimer = C_Timer.NewTimer(duration, function()
            state.liveTimer = nil
            state.liveWindow = false
            applyVisibility()
        end)
    end

    function handle:StopLive()
        if state.liveTimer then
            state.liveTimer:Cancel()
            state.liveTimer = nil
        end
        state.liveWindow = false
        applyVisibility()
    end

    function handle:Apply(newConfig)
        if type(newConfig) == "table" then
            state.config = newConfig
        end

        ensureFrames()

        local db = settings()
        state.anchor:SetSize(db.size, db.size)
        state.anchor:SetAlpha(db.opacity)
        E:ApplyFramePosition(state.anchor, db.position)
        applyVisual(state.previewFrame, state.previewVisual)
        updateContainerLayout()
        applyAuraVisuals()
        applyVisibility()
    end

    function handle:Refresh()
        if state.active and state.pendingContainer then
            ensureAuraContainer()
        end
        self:Apply()
    end

    function handle:Release()
        state.active = false
        state.editMode = false
        state.previewMode = false
        state.liveWindow = false
        callbacks:UnregisterAllEvents()
        self:StopLive()
        stopPreviewTicker()
        if state.container then
            state.container:SetEnabled(false)
            state.container:Hide()
        end
        if state.anchor then
            state.anchor:Hide()
        end
    end

    callbacks:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        if state.active and state.pendingContainer then
            handle:Refresh()
        end
    end)

    callbacks:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED", function(_, _, restrictionState)
        if state.active
            and state.pendingContainer
            and restrictionState == Enum.AddOnRestrictionState.Inactive
        then
            C_Timer.After(0, function()
                if state.active then
                    handle:Refresh()
                end
            end)
        end
    end)

    handle:Apply()
    handle.frame = state.anchor
    return handle
end

function BossMods:RegisterAuraCircleFeature(definition)
    assert(type(definition) == "table", "RegisterAuraCircleFeature: definition required")
    assert(type(definition.featureKey) == "string" and definition.featureKey ~= "",
        "RegisterAuraCircleFeature: featureKey required")
    assert(type(definition.moduleName) == "string" and definition.moduleName ~= "",
        "RegisterAuraCircleFeature: moduleName required")

    E:RegisterModuleDefaults(definition.moduleName, {
        enabled = definition.defaultEnabled == true,
        position = copyPosition(definition.position),
        size = definition.size or 72,
        opacity = 1,
        backgroundOpacity = 0.72,
        color = copyColor(definition.color),
        font = {
            name = "Friz Quadrata TT",
            size = 24,
            outline = "OUTLINE",
            color = {1, 1, 1, 1}
        }
    })

    local module = E:NewModule(definition.moduleName, "AceEvent-3.0")
    module.definition = definition

    function module:EnsureDefaults()
        if not self.display then
            return
        end
        self.display:Apply()
    end

    function module:EnsureDisplay()
        if not self.display then
            self.display = Engines.AuraCircle({
                parent = UIParent,
                definition = self.definition,
                getSettings = function()
                    return self.db
                end
            })
        end
        return self.display
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

    function module:StartLiveWindow(duration)
        if not self.encounterActive then
            return
        end

        local display = self:EnsureDisplay()
        if self.definition.mode == "timed" then
            display:StartTimed(duration)
        else
            display:SetLiveWindow(true)
        end
    end

    function module:StopLiveWindow()
        if self.display then
            self.display:StopLive()
        end
    end

    function module:ScheduleWindow(duration)
        duration = tonumber(duration)
        if not self.encounterActive or not duration or duration < 0 then
            return
        end

        local delay = duration + (self.definition.triggerOffset or 0)
        local target = GetTime() + delay
        self.pendingTimers = self.pendingTimers or {}

        for timer, existingTarget in pairs(self.pendingTimers) do
            if math.abs(existingTarget - target) < 2 then
                timer:Cancel()
                self.pendingTimers[timer] = nil
            end
        end

        local timer
        timer = C_Timer.NewTimer(delay, function()
            self.pendingTimers[timer] = nil
            self:StartLiveWindow(self.definition.windowDuration or PREVIEW_DURATION)
        end)
        self.pendingTimers[timer] = target
    end

    function module:OnBigWigsStartBar(key, _, duration)
        if self.encounterActive and key == self.definition.timerSpellID then
            self:ScheduleWindow(duration)
        end
    end

    function module:OnBigWigsStage(moduleInfo, stage)
        if not self.encounterActive
            or not self.definition.stageWindow
            or not moduleInfo
            or moduleInfo.moduleName ~= (self.definition.bigWigsModuleName or "Ula'tek")
        then
            return
        end

        stage = tonumber(stage)
        if stage == self.definition.stageWindow then
            self:EnsureDisplay():SetLiveWindow(true)
        elseif stage and stage >= (self.definition.stageWindowEnd or 3) then
            self:EnsureDisplay():SetLiveWindow(false)
        end
    end

    function module:HookBigWigs()
        if self.bigWigsSubscription then
            return
        end

        local callbacks = {}
        if self.definition.timerSpellID then
            callbacks.onStartBar = function(key, text, duration)
                self:OnBigWigsStartBar(key, text, duration)
            end
            callbacks.spellKeys = {self.definition.timerSpellID}
        end
        if self.definition.stageWindow then
            callbacks.onStage = function(moduleInfo, stage)
                self:OnBigWigsStage(moduleInfo, stage)
            end
        end

        if not callbacks.onStartBar and not callbacks.onStage then
            return
        end

        callbacks.owner = self.definition.featureKey
        self.bigWigsSubscription = BossMods.BigWigs:Subscribe(callbacks)
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
        self:CancelPendingTimers()
        self:EnsureDisplay():SetLiveWindow(false)
    end

    function module:OnEncounterEnd(_, encounterID)
        if tonumber(encounterID) ~= tonumber(self.definition.encounterID) then
            return
        end

        self.encounterActive = false
        self:CancelPendingTimers()
        self:StopLiveWindow()
    end

    function module:OnInitialize()
        self.encounterActive = false
        self.editMode = false
        self.previewMode = false
        self.pendingTimers = {}
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
        self.editMode = false
        self.previewMode = false
        self:CancelPendingTimers()
        if self.display then
            self.display:SetActive(false)
            self.display:SetEditMode(false)
            self.display:SetPreviewMode(false)
            self.display:StopLive()
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
