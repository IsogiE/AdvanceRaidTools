local E = unpack(ART)

local BossMods = E:GetModule("BossMods")
local Engines = BossMods.Engines
local Shared = Engines.Shared

local WHITE = Shared.WHITE
local fetchFont = Shared.FetchFont
local fetchBorder = Shared.FetchBorder
local colorTuple = Shared.ColorTuple
local applyFontIfChanged = Shared.ApplyFontIfChanged
local getPlayerSpecID = Shared.GetPlayerSpecID

local ICON_TEX_COORD = {0.08, 0.92, 0.08, 0.92}
local FALLBACK_ICON = 134400
local MAX_GROUP_UNITS = 40
local COUNTER_ELEMENT_WIDTH = 2
local COUNTER_UPDATE_INTERVAL = 0.1

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

function Engines.AuraDisplay(config)
    assert(type(config) == "table", "Engines.AuraDisplay: config required")
    assert(config.parent, "Engines.AuraDisplay: config.parent required")
    assert(type(config.spec) == "table", "Engines.AuraDisplay: config.spec required")

    local state = {
        active = false,
        editMode = false,
        inCombat = false,
        config = config,
        trackedSpells = {},
        displayEntries = {},
        entriesByKey = {},
        icons = {},
        counterSlots = {},
        counterTrackers = {},
        pendingSecureRefresh = false,
        bgApplied = false,
        counterElapsed = 0
    }

    local callbacks = E:NewCallbackHandle()
    local layoutConfig = config.layout or {}
    local anchorSize = layoutConfig.anchorSize or {w = 200, h = 44}

    local anchor = CreateFrame("Frame", nil, config.parent)
    anchor:SetSize(anchorSize.w, anchorSize.h)
    anchor:SetFrameStrata("MEDIUM")

    local display = CreateFrame("Frame", nil, anchor, "BackdropTemplate")
    display:SetAllPoints(anchor)
    display:SetFrameStrata("MEDIUM")
    display:Hide()

    local iconLayer = CreateFrame("Frame", nil, display)
    iconLayer:SetAllPoints(display)
    iconLayer:SetFrameLevel(display:GetFrameLevel() + 10)

    -- These hidden containers encode the total aura count in their combined
    -- width. Their protected aura state is never inspected by addon Lua.
    local counterLayer = CreateFrame("Frame", nil, display, "DisableUntrustedLayoutScriptsTemplate")
    counterLayer:SetAllPoints(display)
    counterLayer:SetAlpha(0)

    local function getUnits()
        if type(state.config.getUnits) == "function" then
            local ok, result = pcall(state.config.getUnits)
            if ok and type(result) == "table" then
                return result
            end
        end

        -- Do not size this list from GetNumGroupMembers(). That API counts
        -- players, while follower-dungeon NPCs still occupy party unit tokens.
        -- Invalid unit tokens simply produce empty AuraContainers, so covering
        -- the complete Blizzard token range is both stable and exact.
        local units = {}
        if IsInRaid and IsInRaid() then
            for index = 1, MAX_GROUP_UNITS do
                units[index] = "raid" .. index
            end
        else
            units[1] = "player"
            for index = 1, 4 do
                units[index + 1] = "party" .. index
            end
        end
        return units
    end

    local function shouldShow()
        if state.editMode then
            return true
        end

        local visibility = state.config.visibility or {}
        local showWhen = visibility.showWhen or "always"
        if showWhen == "never" then
            return false
        elseif showWhen == "combat" then
            return state.inCombat
        elseif showWhen == "nocombat" then
            return not state.inCombat
        end
        return true
    end

    local function isKeyEnabled(key)
        local visibility = state.config.visibility
        if not visibility or not visibility.enabledKeys then
            return true
        end

        local enabled = visibility.enabledKeys[key]
        if enabled == nil then
            return true
        end
        return enabled == true
    end

    local function isSpellValidForSpec(spell, specID)
        if not spell.specIDs then
            return true
        end
        if not specID then
            return false
        end
        for _, validSpecID in ipairs(spell.specIDs) do
            if validSpecID == specID then
                return true
            end
        end
        return false
    end

    local function appendSpellID(entry, spellID)
        for _, existingID in ipairs(entry.spellIDs) do
            if existingID == spellID then
                return
            end
        end
        entry.spellIDs[#entry.spellIDs + 1] = spellID
    end

    local function rebuildTrackedSpells()
        wipe(state.trackedSpells)
        wipe(state.displayEntries)
        wipe(state.entriesByKey)

        local spells = state.config.spec and state.config.spec.spells or {}
        local specID = getPlayerSpecID()

        -- Create the visible entries first so hidden spell variants work even
        -- if a future spell table lists them before their visible counterpart.
        for _, spell in ipairs(spells) do
            if not spell.hidden and isSpellValidForSpec(spell, specID) and isKeyEnabled(spell.key) then
                local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spell.id)
                local entry = {
                    key = spell.key,
                    label = spell.name,
                    color = spell.color,
                    texID = info and info.iconID or FALLBACK_ICON,
                    spellIDs = {}
                }
                state.entriesByKey[spell.key] = entry
                state.displayEntries[#state.displayEntries + 1] = entry
            end
        end

        for _, spell in ipairs(spells) do
            if isSpellValidForSpec(spell, specID) and isKeyEnabled(spell.key) then
                local entry = state.entriesByKey[spell.key]
                if entry then
                    state.trackedSpells[#state.trackedSpells + 1] = spell
                    appendSpellID(entry, spell.id)
                end
            end
        end
    end

    local function applyLabelStyle(fontString, parent, style)
        applyFontIfChanged(fontString, fetchFont(), style.size or 11, style.outline or "OUTLINE")
        local r, g, b, a = colorTuple(style.color, 1, 1, 1, 1)
        fontString:SetTextColor(r, g, b, a)
        fontString:ClearAllPoints()
        local point = style.anchor or "TOPLEFT"
        fontString:SetPoint(point, parent, point, style.offsetX or 0, style.offsetY or 0)
    end

    local function updateIconBorder(icon, borderConfig)
        if not borderConfig or not borderConfig.enabled then
            E:ApplyOuterBorder(icon, {enabled = false})
            return
        end

        local edgeTexture = fetchBorder(borderConfig.texture)
        local edgeSize = math.min(borderConfig.size or 12, 16)
        if not edgeTexture or edgeSize <= 0 then
            E:ApplyOuterBorder(icon, {enabled = false})
            return
        end

        local r, g, b, a = colorTuple(borderConfig.color, 0, 0, 0, 1)
        E:ApplyOuterBorder(icon, {
            enabled = true,
            edgeFile = edgeTexture,
            edgeSize = edgeSize,
            r = r,
            g = g,
            b = b,
            a = a * (borderConfig.opacity or 1)
        })
    end

    local function updateDisplayBackdrop()
        local background = (state.config.style or {}).background
        if not background or not background.enabled then
            if state.bgApplied then
                display:SetBackdrop(nil)
                state.bgApplied = false
            end
            return
        end

        if not state.bgApplied then
            display:SetBackdrop({
                bgFile = WHITE,
                insets = {left = 0, right = 0, top = 0, bottom = 0}
            })
            state.bgApplied = true
        end
        local r, g, b = colorTuple(background.color, 0, 0, 0, 1)
        display:SetBackdropColor(r, g, b, background.opacity or 0.5)
    end

    local function getOrCreateIcon(index)
        if state.icons[index] then
            return state.icons[index]
        end

        local icon = CreateFrame(
            "Frame",
            nil,
            iconLayer,
            "BackdropTemplate,DisableUntrustedLayoutScriptsTemplate"
        )
        icon:SetFrameLevel(iconLayer:GetFrameLevel() + 1)

        icon.texture = icon:CreateTexture(nil, "ARTWORK")
        icon.texture:SetAllPoints(icon)
        icon.texture:SetTexCoord(unpack(ICON_TEX_COORD))

        local overlay = CreateFrame("Frame", nil, icon, "DisableUntrustedLayoutScriptsTemplate")
        overlay:SetAllPoints(icon)
        overlay:SetFrameLevel(icon:GetFrameLevel() + 3)
        -- Give the label a valid font immediately. Some layout branches
        -- clear their text before the configured font style is applied.
        icon.count = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")

        state.icons[index] = icon
        return icon
    end

    local function applyIconLayout()
        local style = state.config.style or {}
        local layout = state.config.layout or {}
        local iconSize = layout.iconSize or 36
        local iconPad = layout.iconPad or 4
        local countStyle = style.count or {}

        updateDisplayBackdrop()

        for index, entry in ipairs(state.displayEntries) do
            local icon = getOrCreateIcon(index)
            icon:SetSize(iconSize, iconSize)
            icon:ClearAllPoints()
            if index == 1 then
                icon:SetPoint("TOPLEFT", iconLayer, "TOPLEFT", 0, 0)
            else
                icon:SetPoint("LEFT", state.icons[index - 1], "RIGHT", iconPad, 0)
            end

            icon.texture:SetTexture(entry.texID)
            icon.texture:SetTexCoord(unpack(ICON_TEX_COORD))
            icon.texture:SetAlpha(style.iconOpacity or 1)
            icon.texture:SetDesaturated(false)

            applyLabelStyle(icon.count, icon, countStyle)
            icon.count:SetText(state.editMode and "1" or "0")
            icon.count:Show()

            updateIconBorder(icon, style.border)
            icon:Show()
        end

        for index = #state.displayEntries + 1, #state.icons do
            state.icons[index]:Hide()
        end

        local visibleCount = math.max(#state.displayEntries, state.editMode and 1 or 0)
        if visibleCount > 0 then
            anchor:SetSize(visibleCount * iconSize + math.max(visibleCount - 1, 0) * iconPad, iconSize)
        else
            anchor:SetSize(iconSize, iconSize)
        end
    end

    local function configureCounterButton(button)
        button:SetSize(COUNTER_ELEMENT_WIDTH, 1)
        button:SetCollapsesLayout(true)
        if button.SetIgnoringChildrenForBounds then
            button:SetIgnoringChildrenForBounds(true)
        end
        if button.SetMouseClickEnabled then
            button:SetMouseClickEnabled(false)
        end
        button:SetMouseMotionEnabled(false)
    end

    local function createCounterSlot(index)
        local anchorFrame = CreateFrame("Frame", nil, counterLayer, "DisableUntrustedLayoutScriptsTemplate")
        anchorFrame:SetSize(1, 1)

        local container = CreateFrame(
            "AuraContainer",
            nil,
            counterLayer,
            "CustomAuraContainerTemplate,DisableUntrustedLayoutScriptsTemplate"
        )
        container:SetSize(1, 1)
        container:SetPoint("TOPLEFT", anchorFrame, "TOPLEFT", 0, 0)
        container:SetUnit("player")
        container:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
        container:SetFlowLayoutAnchorPoint("TOPLEFT")
        container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Down)
        container:SetFlowLayoutMaximumLineSize(math.huge)

        local groupKey = "ART_HoTCounter" .. index
        container:AddAuraGroup(groupKey, "HELPFUL|PLAYER", {
            maxFrameCount = 1,
            sortMethod = AuraContainerSortMethod.AuraInstanceIDOnly,
            sortDirection = AuraContainerSortDirection.Normal,
            candidateFilters = {
                includeSpellIDs = {[FALLBACK_ICON] = true},
                isFromPlayerOrPlayerPet = true
            },
            initializeFrame = configureCounterButton,
            layout = {
                elementWidth = COUNTER_ELEMENT_WIDTH,
                elementHeight = 1,
                elementSpacing = 0,
                lineSpacing = 0
            }
        })

        container:SetEnabled(false)
        container:Hide()

        local slot = {
            anchor = anchorFrame,
            container = container,
            groupKey = groupKey,
            unit = "player",
            spellID = nil,
            assigned = false
        }
        state.counterSlots[index] = slot
        return slot
    end

    local function ensureCounterSlots(requiredCount)
        if #state.counterSlots >= requiredCount then
            return true
        end
        if areAurasRestricted() or not loadAuraContainer() then
            state.pendingSecureRefresh = true
            return false
        end

        for index = #state.counterSlots + 1, requiredCount do
            local ok = pcall(createCounterSlot, index)
            if not ok then
                state.pendingSecureRefresh = true
                return false
            end
        end
        return true
    end

    local function getOrCreateCounterTracker(index)
        if state.counterTrackers[index] then
            return state.counterTrackers[index]
        end

        local root = CreateFrame("Frame", nil, counterLayer, "DisableUntrustedLayoutScriptsTemplate")
        root:SetSize(1, 1)
        root:SetPoint("TOPLEFT", counterLayer, "TOPLEFT", 0, -(index - 1) * 2)

        local extent = CreateFrame("Frame", nil, counterLayer, "DisableUntrustedLayoutScriptsTemplate")
        extent:SetHeight(1)

        local tracker = {
            root = root,
            extent = extent,
            countText = nil,
            slotCount = 0
        }
        state.counterTrackers[index] = tracker
        return tracker
    end

    local function setCounterSlot(slot, unit, spellID, relativeFrame, firstInTracker)
        if slot.unit ~= unit then
            slot.container:SetUnit(unit)
            slot.unit = unit
        end
        if slot.spellID ~= spellID then
            slot.container:SetAuraGroupCandidateFilters(slot.groupKey, {
                includeSpellIDs = {[spellID] = true},
                isFromPlayerOrPlayerPet = true
            })
            slot.spellID = spellID
        end

        slot.anchor:ClearAllPoints()
        if firstInTracker then
            slot.anchor:SetPoint("TOPLEFT", relativeFrame, "TOPLEFT", 0, 0)
        else
            slot.anchor:SetPoint("TOPLEFT", relativeFrame, "TOPRIGHT", 0, 0)
        end
        slot.assigned = true
        local enabled = state.active and not state.editMode
        slot.container:SetEnabled(enabled)
        slot.container:SetShown(enabled)
    end

    local function refreshSecureCounters()
        if areAurasRestricted() or not loadAuraContainer() then
            state.pendingSecureRefresh = true
            return false
        end

        local units = getUnits()
        local unitCount = math.min(#units, MAX_GROUP_UNITS)
        local requiredCount = 0
        for _, entry in ipairs(state.displayEntries) do
            requiredCount = requiredCount + unitCount * #entry.spellIDs
        end

        if not ensureCounterSlots(requiredCount) then
            return false
        end

        for _, slot in ipairs(state.counterSlots) do
            slot.assigned = false
        end

        local slotIndex = 0
        for entryIndex, entry in ipairs(state.displayEntries) do
            local tracker = getOrCreateCounterTracker(entryIndex)
            tracker.countText = state.icons[entryIndex] and state.icons[entryIndex].count or nil
            tracker.slotCount = 0

            local previousFrame = tracker.root
            for unitIndex = 1, unitCount do
                local unit = units[unitIndex]
                for _, spellID in ipairs(entry.spellIDs) do
                    slotIndex = slotIndex + 1
                    tracker.slotCount = tracker.slotCount + 1
                    local slot = state.counterSlots[slotIndex]
                    setCounterSlot(
                        slot,
                        unit,
                        spellID,
                        previousFrame,
                        tracker.slotCount == 1
                    )
                    previousFrame = slot.container
                end
            end

            tracker.extent:ClearAllPoints()
            tracker.extent:SetPoint("LEFT", tracker.root, "LEFT", tracker.slotCount, 0)
            tracker.extent:SetPoint("RIGHT", previousFrame, "RIGHT", 0, 0)
            tracker.extent:SetHeight(1)
        end

        for index = #state.displayEntries + 1, #state.counterTrackers do
            local tracker = state.counterTrackers[index]
            tracker.countText = nil
            tracker.slotCount = 0
            tracker.extent:ClearAllPoints()
            tracker.extent:SetSize(1, 1)
        end

        for _, slot in ipairs(state.counterSlots) do
            if not slot.assigned then
                slot.container:SetEnabled(false)
                slot.container:Hide()
                slot.anchor:ClearAllPoints()
            end
        end

        state.pendingSecureRefresh = false
        return true
    end

    local function updateSecretCounts()
        if not state.active or state.editMode then
            return
        end

        for index = 1, #state.displayEntries do
            local tracker = state.counterTrackers[index]
            if tracker and tracker.countText and tracker.slotCount > 0 then
                -- GetWidth() is secret while AuraContainers are restricted.
                -- SetFormattedText explicitly accepts secret arguments, so the
                -- value is displayed without becoming readable to addon Lua.
                -- Anchored dimensions can carry sub-pixel floating point
                -- error (for example 4.999999 for five active slots). Round
                -- to the nearest whole slot instead of truncating with %d.
                pcall(tracker.countText.SetFormattedText, tracker.countText, "%.0f", tracker.extent:GetWidth())
            end
        end
    end

    local counterUpdater = CreateFrame("Frame")
    counterUpdater:SetScript("OnUpdate", function(_, elapsed)
        state.counterElapsed = state.counterElapsed + elapsed
        if state.counterElapsed < COUNTER_UPDATE_INTERVAL then
            return
        end
        state.counterElapsed = 0
        updateSecretCounts()
    end)

    local function applyVisibility()
        display:SetShown(state.active and shouldShow() and #state.displayEntries > 0)
        for _, slot in ipairs(state.counterSlots) do
            local enabled = state.active and not state.editMode and slot.assigned
            pcall(slot.container.SetEnabled, slot.container, enabled)
            pcall(slot.container.SetShown, slot.container, enabled)
        end
    end

    local function refreshDisplay()
        rebuildTrackedSpells()
        applyIconLayout()
        refreshSecureCounters()
        applyVisibility()
        updateSecretCounts()
    end

    callbacks:RegisterEvent("PLAYER_REGEN_DISABLED", function()
        state.inCombat = true
        applyVisibility()
    end)

    callbacks:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        state.inCombat = false
        if state.pendingSecureRefresh then
            refreshDisplay()
        else
            applyVisibility()
        end
    end)

    callbacks:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED", function(_, _, restrictionState)
        if restrictionState == Enum.AddOnRestrictionState.Inactive and state.pendingSecureRefresh then
            C_Timer.After(0, function()
                if state.active and not areAurasRestricted() then
                    refreshDisplay()
                end
            end)
        end
    end)

    callbacks:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function(_, unit)
        if unit == nil or unit == "player" then
            refreshDisplay()
        end
    end)

    callbacks:RegisterEvent("PLAYER_ENTERING_WORLD", refreshDisplay)

    callbacks:RegisterEvent("GROUP_ROSTER_UPDATE", function()
        if not areAurasRestricted() then
            refreshSecureCounters()
            updateSecretCounts()
        else
            state.pendingSecureRefresh = true
        end
    end)

    local handle = {frame = anchor}

    function handle:SetActive(value)
        value = value == true
        if state.active == value then
            return
        end

        state.active = value
        if value then
            state.inCombat = UnitAffectingCombat and UnitAffectingCombat("player") or false
            refreshDisplay()
        else
            state.editMode = false
            applyIconLayout()
            applyVisibility()
        end
    end

    function handle:SetEditMode(value)
        state.editMode = value == true
        applyIconLayout()
        applyVisibility()
        updateSecretCounts()
    end

    function handle:Apply(newConfig)
        if type(newConfig) == "table" then
            state.config = newConfig
        end
        refreshDisplay()
    end

    function handle:Release()
        state.active = false
        state.editMode = false
        applyVisibility()
        callbacks:UnregisterAllEvents()
        counterUpdater:SetScript("OnUpdate", nil)
        display:Hide()
        anchor:Hide()
    end

    rebuildTrackedSpells()
    applyIconLayout()
    refreshSecureCounters()
    applyVisibility()

    return handle
end
