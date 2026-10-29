local E, L = unpack(ART)
local T = E.Templates

local NAV_WIDTH = 220
local NAV_ROW_H = 26
local NAV_ROW_GAP = 2
local NAV_PAD = 4
local NAV_VISIBLE_ROWS = 15
local NAV_INNER_HEIGHT = NAV_VISIBLE_ROWS * NAV_ROW_H + (NAV_VISIBLE_ROWS - 1) * NAV_ROW_GAP
local NAV_MIN_HEIGHT = NAV_INNER_HEIGHT + NAV_PAD * 2
local COL_GAP = 8
local FILTER_WIDTH = 140
local TOOLBAR_GAP = 8

local navCollapsedState = {}
local sectionStates, selectedFeatures = {}, {}
local navigationFilters = {}

local function getSectionState(key)
    sectionStates[key] = sectionStates[key] or {}
    return sectionStates[key]
end

local function optionsResizeActive()
    return E.OptionsUI and E.OptionsUI.IsResizing and E.OptionsUI:IsResizing()
end

local function getNavCollapsedState(tabKey)
    navCollapsedState[tabKey] = navCollapsedState[tabKey] or {}
    return navCollapsedState[tabKey]
end

local function localized(key, fallback)
    if not key then
        return fallback
    end

    local text = L[key]
    if text == key then
        return fallback
    end

    return text or fallback
end

local function searchText(feature)
    local parts = {}
    for _, field in ipairs({"labelKey", "navLabelKey", "groupLabelKey", "bossLabelKey", "descKey"}) do
        parts[#parts + 1] = localized(feature[field], "")
    end
    for _, field in ipairs({"navLabel", "groupLabel", "bossName", "key", "bossKey"}) do
        parts[#parts + 1] = feature[field] or ""
    end
    return table.concat(parts, " "):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):lower()
end

local function buildTabBody(parent, tabKey)
    local BossMods = E:GetModule("BossMods", true)
    if not BossMods then
        local desc = T:Description(parent, {
            text = L["LoadModule"],
            sizeDelta = 1
        })
        return {
            frame = desc.frame,
            height = desc.height or 30,
            fullWidth = true
        }
    end

    local outerScroll = parent.GetParent and parent:GetParent()
    local scrollW = (outerScroll and outerScroll.GetWidth and outerScroll:GetWidth()) or 0
    local availW = math.max(scrollW, parent:GetWidth() or 0)
    local container = CreateFrame("Frame", nil, parent)
    local toolbarHeight = 0
    container:SetHeight(NAV_MIN_HEIGHT)

    local isBossModsEnabled
    local isFeatureActive
    local selectFeature
    local updateNavigation
    navigationFilters[tabKey] = navigationFilters[tabKey] or {query = "", status = "all"}
    local filter = navigationFilters[tabKey]
    local function isFiltered()
        return filter.query:find("%S") ~= nil or filter.status ~= "all"
    end
    local search = T:EditBox(container, {
        label = L["BossMods_SearchFeatures"], default = filter.query,
        showCommitButton = false, commitOn = "change", maxLetters = 100, height = 24,
        onChange = function(value)
            filter.query = value
            if updateNavigation then updateNavigation() end
        end
    })
    search.frame:SetPoint("TOPLEFT", 0, 0)
    search.frame:SetWidth(NAV_WIDTH)
    local statusFilter = T:Dropdown(container, {
        label = L["BossMods_FeatureFilter"],
        buttonHeight = 24,
        values = {all = L["BossMods_AllFeatures"], enabled = L["BossMods_EnabledFeatures"], disabled = L["BossMods_DisabledFeatures"]},
        sorting = {"all", "enabled", "disabled"}, get = function() return filter.status end,
        onChange = function(value)
            filter.status = value
            if updateNavigation then updateNavigation() end
        end
    })
    statusFilter.frame:SetPoint("TOPLEFT", container, "TOPLEFT", NAV_WIDTH + COL_GAP, 0)
    statusFilter.frame:SetWidth(FILTER_WIDTH)

    local body = T:ScrollFrame(container, {
        chrome = false,
        autoWidth = true,
        minContentWidth = 1,
        mouseWheelStep = 40
    })
    local state = {
        activeFeature = selectedFeatures[tabKey],
        featureBodies = {},
        placeholder = nil
    }
    local function currentSections()
        local feature = state.activeFeature and state.featureBodies[state.activeFeature]
        return feature and feature.sections
    end
    local function sectionsDisabled()
        local sections = currentSections()
        return not sections or not sections:HasSections()
    end
    local expand = T:Button(container, {
        text = L["ExpandAll"], disabled = sectionsDisabled,
        onClick = function() local sections = currentSections(); if sections then sections:SetAll(false) end end
    })
    local collapse = T:Button(container, {
        text = L["CollapseAll"], disabled = sectionsDisabled,
        onClick = function() local sections = currentSections(); if sections then sections:SetAll(true) end end
    })
    local function refreshSectionButtons()
        expand.Refresh()
        collapse.Refresh()
    end

    local nav
    nav = T:GroupedNavList(container, {
        width = NAV_WIDTH,
        height = NAV_MIN_HEIGHT,
        minHeight = NAV_MIN_HEIGHT,
        fillViewport = true,
        rowHeight = NAV_ROW_H,
        rowGap = NAV_ROW_GAP,
        pad = NAV_PAD,
        indent = 14,
        scrollbarWidth = 10,
        scrollbarGap = 4,
        mouseWheelStep = NAV_ROW_H + NAV_ROW_GAP,
        emptyText = function() return isFiltered() and L["BossMods_NoMatchingFeatures"] or L["BossMods_NoFeatures"] end,
        collapsedState = getNavCollapsedState(tabKey),
        forceExpanded = isFiltered,
        itemKey = function(feature)
            return feature.key
        end,
        itemLabel = function(feature)
            return localized(feature.navLabelKey, nil)
                or feature.navLabel
                or localized(feature.labelKey, feature.labelKey)
        end,
        itemOrder = function(feature)
            return feature.order or 100
        end,
        itemEnabled = function(feature)
            return isFeatureActive and isFeatureActive(feature) or false
        end,
        onItemClick = function(feature)
            if selectFeature then
                selectFeature(feature.key)
            end
        end,
        getItemToggle = function(feature)
            return isFeatureActive and isFeatureActive(feature) or false
        end,
        onItemToggle = function(feature, value)
            BossMods:SetFeatureEnabled(feature.key, value)

            if value then
                E:SetModuleEnabled(feature.moduleName, true)
            else
                local keepModuleEnabled = false
                for _, sibling in ipairs(BossMods.features:All()) do
                    if sibling.moduleName == feature.moduleName
                        and BossMods:IsFeatureEnabled(sibling.key)
                    then
                        keepModuleEnabled = true
                        break
                    end
                end

                if not keepModuleEnabled then
                    E:SetModuleEnabled(feature.moduleName, false)
                end
            end

            nav.Refresh()

            local fb = state.featureBodies[feature.key]
            if fb and fb.handle and fb.handle.Refresh then
                pcall(fb.handle.Refresh)
            end
            if filter.status ~= "all" then updateNavigation() end
        end,
        itemToggleDisabled = function()
            return not (isBossModsEnabled and isBossModsEnabled())
        end,
        groupKey = function(feature)
            return feature.groupKey or feature.bossKey
        end,
        groupLabel = function(_, feature)
            return localized(feature.groupLabelKey, nil)
                or feature.groupLabel
                or localized(feature.bossLabelKey, nil)
                or feature.bossName
                or feature.groupKey
                or feature.bossKey
        end,
        groupOrder = function(_, feature)
            return feature.groupOrder or feature.bossOrder or feature.order or 100
        end
    })
    collapse.frame:SetPoint("LEFT", expand.frame, "RIGHT", 6, 0)
    body.frame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
    body.scroll:HookScript("OnSizeChanged", body.ApplyAutoWidth)

    local function layoutToolbar()
        local width = container:GetWidth()
        if not width or width <= 0 then width = availW end
        local controlsHeight = math.max(search.frame:GetHeight(), statusFilter.frame:GetHeight())
        local buttonsX, buttonsY = NAV_WIDTH + COL_GAP + FILTER_WIDTH + COL_GAP, 16
        local buttonsWidth = expand.frame:GetWidth() + 6 + collapse.frame:GetWidth()
        if buttonsX + buttonsWidth > width then
            buttonsX, buttonsY = NAV_WIDTH + COL_GAP, controlsHeight + 6
        end
        toolbarHeight = math.max(controlsHeight,
            buttonsY + math.max(expand.frame:GetHeight(), collapse.frame:GetHeight())) + TOOLBAR_GAP
        expand.frame:ClearAllPoints()
        expand.frame:SetPoint("TOPLEFT", container, "TOPLEFT", buttonsX, -buttonsY)
        nav.frame:ClearAllPoints()
        nav.frame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -toolbarHeight)
        body.frame:ClearAllPoints()
        body.frame:SetPoint("TOPLEFT", container, "TOPLEFT", NAV_WIDTH + COL_GAP, -toolbarHeight)
        body.frame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
    end
    layoutToolbar()
    container:SetHeight(NAV_MIN_HEIGHT + toolbarHeight)

    isBossModsEnabled = function()
        return BossMods:IsEnabled()
    end

    isFeatureActive = function(feature)
        local mod = feature and E:GetModule(feature.moduleName, true)
        return mod
            and mod:IsEnabled()
            and BossMods:IsFeatureEnabled(feature.key)
            or false
    end

    local function syncFeatureBodySize(fb)
        if not (fb and fb.wrapper) then
            return 1
        end

        local h = fb.handle and fb.handle.height or fb.wrapper:GetHeight() or 30
        h = math.max(1, h)
        fb.wrapper:SetHeight(h)

        if fb.wrapper:IsShown() then
            body.content:SetHeight(h)
            body.scroll:UpdateScrollChildRect()
        end
        refreshSectionButtons()

        return h
    end

    local function applyFeatureBodyHeight(fb, requestedHeight)
        if not fb then
            return 1
        end

        local handle = fb.handle
        if handle and type(handle.SetHeight) == "function" then
            local minH = tonumber(handle.minHeight or handle.height or fb.wrapper:GetHeight()) or 1
            local targetH = math.max(minH, tonumber(requestedHeight) or minH)
            local ok = pcall(handle.SetHeight, handle, targetH)
            if not ok then
                pcall(handle.SetHeight, targetH)
            end
        end

        return syncFeatureBodySize(fb)
    end

    local function requestFeatureLayout(featureKey)
        local fb = state.featureBodies[featureKey]
        if fb then
            syncFeatureBodySize(fb)
        end
    end

    local function destroyPlaceholder()
        if not state.placeholder then
            return
        end
        state.placeholder:Hide()
        state.placeholder:ClearAllPoints()
        state.placeholder:SetParent(nil)
        state.placeholder = nil
    end

    local function destroyFeatureBody(key)
        local fb = state.featureBodies[key]
        if not fb then
            return
        end
        if fb.handle and fb.handle.Release then
            pcall(fb.handle.Release)
        end
        if fb.wrapper then
            fb.wrapper:Hide()
            fb.wrapper:ClearAllPoints()
            fb.wrapper:SetParent(nil)
        end
        state.featureBodies[key] = nil
    end

    local function buildFeatureBody(featureKey)
        local feature = BossMods:GetFeature(featureKey)
        local mod = feature and E:GetModule(feature.moduleName, true)
        local builder = BossMods:GetSettingsBuilder(featureKey)
        if not (feature and mod and builder) then
            return nil
        end

        local contentW = body.content:GetWidth() or 0
        if contentW <= 0 then
            return nil
        end

        local wrapper = CreateFrame("Frame", nil, body.content)
        wrapper:SetPoint("TOPLEFT", 0, 0)
        wrapper:SetPoint("TOPRIGHT", 0, 0)
        wrapper:SetWidth(contentW)
        wrapper:SetHeight(1)
        wrapper:Hide()

        local function isDisabled()
            return not (
                isBossModsEnabled()
                and mod:IsEnabled()
                and BossMods:IsFeatureEnabled(featureKey)
            )
        end

        local sections
        local function requestLayout()
            if sections then sections:Apply() end
            requestFeatureLayout(featureKey)
        end

        sections = T:CollapsibleSections(wrapper, {
            state = getSectionState(tabKey .. ":" .. featureKey), refreshLayout = true,
            onChanged = function() requestFeatureLayout(featureKey) end
        })
        local handle = builder(wrapper, mod, isDisabled, requestLayout) or {}
        sections:Bind(handle)
        local h = handle.height or wrapper:GetHeight() or 30
        wrapper:SetHeight(math.max(1, h))

        local fb = {
            wrapper = wrapper,
            handle = handle,
            sections = sections,
            mod = mod,
            builtAtWidth = contentW
        }
        state.featureBodies[featureKey] = fb
        return fb
    end

    local function ensureFeatureBody(key)
        if not key then
            return nil
        end
        local fb = state.featureBodies[key]
        local contentW = body.content:GetWidth() or 0
        if contentW <= 0 then
            return fb
        end

        if fb and fb.builtAtWidth and math.abs(fb.builtAtWidth - contentW) < 0.5 then
            return fb
        end
        if fb then
            destroyFeatureBody(key)
        end
        return buildFeatureBody(key)
    end

    local function showPlaceholder(text)
        destroyPlaceholder()
        refreshSectionButtons()
        local contentW = body.content:GetWidth() or 0
        if contentW <= 0 then
            body.content:SetHeight(1)
            body.scroll:UpdateScrollChildRect()
            body.ScrollToTop()
            return
        end
        local msg = T:Description(body.content, {
            text = text,
            sizeDelta = 1
        })
        msg.frame:SetPoint("TOPLEFT", 0, 0)
        msg.frame:SetPoint("TOPRIGHT", 0, 0)
        state.placeholder = msg.frame
        body.content:SetHeight(msg.frame:GetHeight() or 30)
        body.scroll:UpdateScrollChildRect()
        body.ScrollToTop()
    end

    local function showFeatureBody(key, resetScroll)
        destroyPlaceholder()
        if not optionsResizeActive() then
            body.ApplyAutoWidth()
        end

        for k, fb in pairs(state.featureBodies) do
            if fb and fb.wrapper and k ~= key then
                fb.wrapper:Hide()
            end
        end

        if not key then
            showPlaceholder(isFiltered() and L["BossMods_NoMatchingFeatures"] or L["BossMods_PickFeature"])
            return
        end

        local fb = ensureFeatureBody(key)
        if not fb then
            local feature = BossMods:GetFeature(key)
            local mod = feature and E:GetModule(feature.moduleName, true)
            local builder = BossMods:GetSettingsBuilder(key)
            if not (feature and mod and builder) then
                showPlaceholder(L["LoadModule"])
            else
                body.content:SetHeight(1)
                body.scroll:UpdateScrollChildRect()
                body.ScrollToTop()
            end
            return
        end

        fb.wrapper:Show()
        local h = applyFeatureBodyHeight(fb, body.scroll:GetHeight())
        body.content:SetHeight(math.max(1, h))
        body.scroll:UpdateScrollChildRect()
        if resetScroll then
            body.ScrollToTop()
        end
    end

    selectFeature = function(key)
        local changed = key ~= state.activeFeature
        state.activeFeature = key
        selectedFeatures[tabKey] = key
        showFeatureBody(key, changed)
        nav:SetSelectedKey(key)
        local fb = state.featureBodies[key]
        if fb and fb.handle and fb.handle.Refresh then
            pcall(fb.handle.Refresh)
        end
    end

    local function rebuildNav()
        local features = {}
        for _, feature in ipairs(BossMods:GetFeaturesForTab(tabKey)) do
            local active = isFeatureActive(feature)
            local matches = filter.status == "all" or (filter.status == "enabled" and active)
                or (filter.status == "disabled" and not active)
            local text = searchText(feature)
            for term in filter.query:lower():gmatch("%S+") do
                if not text:find(term, 1, true) then matches = false; break end
            end
            if matches then features[#features + 1] = feature end
        end
        nav:SetItems(features)

        if #features == 0 then
            state.activeFeature = nil
            nav:SetSelectedKey(nil)
            return
        end

        local foundActive = false
        for _, feat in ipairs(features) do
            if feat.key == state.activeFeature then
                foundActive = true
                break
            end
        end

        if not foundActive then
            state.activeFeature = features[1].key
        end
        if not isFiltered() then selectedFeatures[tabKey] = state.activeFeature end

        nav:SetSelectedKey(state.activeFeature)
    end

    updateNavigation = function()
        if not isFiltered() then state.activeFeature = selectedFeatures[tabKey] end
        rebuildNav()
        showFeatureBody(state.activeFeature, true)
    end

    container:SetScript("OnShow", function()
        layoutToolbar()
        body.ApplyAutoWidth()
        showFeatureBody(state.activeFeature)
    end)

    rebuildNav()

    local api
    local function resizeContent(height)
        layoutToolbar()
        local targetH = math.max(NAV_MIN_HEIGHT + toolbarHeight, tonumber(height) or container:GetHeight() or NAV_MIN_HEIGHT)
        if api then api.minHeight = NAV_MIN_HEIGHT + toolbarHeight end
        container:SetHeight(targetH)
        if nav.SetHeight then
            nav:SetHeight(targetH - toolbarHeight)
        else
            nav.frame:SetHeight(targetH - toolbarHeight)
            nav._relayout()
        end
        body.ApplyAutoWidth()

        local newW = body.content:GetWidth() or 0
        if newW <= 0 then
            return
        end

        local fb = state.activeFeature and state.featureBodies[state.activeFeature]
        if fb and fb.wrapper then
            fb.wrapper:Show()
            body.content:SetHeight(applyFeatureBodyHeight(fb, body.scroll:GetHeight()))
            body.scroll:UpdateScrollChildRect()
        elseif state.activeFeature then
            showFeatureBody(state.activeFeature)
        end
    end

    api = {
        frame = container,
        height = NAV_MIN_HEIGHT + toolbarHeight,
        minHeight = NAV_MIN_HEIGHT + toolbarHeight,
        fillViewport = true,
        fullWidth = true,
        SetHeight = function(selfOrHeight, maybeHeight)
            resizeContent(selfOrHeight == api and maybeHeight or selfOrHeight)
        end,
        _relayout = function()
            if optionsResizeActive() then
                return
            end
            resizeContent()
        end,
        Refresh = function()
            local previous = state.activeFeature
            rebuildNav()
            if previous ~= state.activeFeature then showFeatureBody(state.activeFeature, true) end
            if not state.activeFeature then
                return
            end
            local fb = state.featureBodies[state.activeFeature]
            if fb and fb.handle and fb.handle.Refresh then
                local ok, rebuild = pcall(fb.handle.Refresh)
                if ok and rebuild then
                    destroyFeatureBody(state.activeFeature)
                    showFeatureBody(state.activeFeature)
                end
            end
        end
    }
    return api
end

local function buildTabGroup(tab)
    local tabKey = tab.key
    return {
        type = "group",
        order = tab.order,
        name = L[tab.labelKey] or tab.labelKey,
        args = {
            body = {
                order = 1,
                width = "full",
                build = function(parent)
                    if tab.settingsKey then
                        local builder = E:GetModule("BossMods"):GetSettingsBuilder(tab.settingsKey)
                        local sections = T:CollapsibleSections(parent, {
                            state = getSectionState("tab:" .. tabKey),
                            onChanged = function()
                                if E.OptionsUI and E.OptionsUI.QueueRefresh then E.OptionsUI:QueueRefresh("current") end
                            end
                        })
                        local handle = builder(parent)
                        sections:Bind(handle)
                        handle.fullWidth = true
                        return handle
                    end
                    return buildTabBody(parent, tabKey)
                end
            }
        }
    }
end

local function buildBossModsPanel()
    local BossMods = E:GetModule("BossMods", true)
    if not BossMods then
        return {
            type = "group",
            name = L["BossMods"],
            args = {
                notice = {
                    type = "description",
                    order = 1,
                    fontSize = "medium",
                    name = L["LoadModule"]
                }
            }
        }
    end

    local tabs = {}
    for _, tab in ipairs(BossMods:GetTabs()) do
        if tab.settingsKey or #BossMods:GetFeaturesForTab(tab.key) > 0 then
            tabs[tab.key] = buildTabGroup(tab)
        end
    end

    return {
        type = "group",
        name = L["BossMods"],
        childGroups = "tab",
        args = T:MergeArgs({
            intro = {
                type = "description",
                order = 1,
                fontSize = "medium",
                name = L["BossModsDesc"]
            }
        }, tabs)
    }
end

E:RegisterOptions("BossMods", 21, buildBossModsPanel)

local bmEvents = E:NewCallbackHandle()
bmEvents:RegisterMessage("ART_BOSSMODS_FEATURES_CHANGED", function()
    if E.RebuildOptions then
        E:RebuildOptions()
    end
end)
bmEvents:RegisterMessage("ART_BOSSMODS_TABS_CHANGED", function()
    if E.RebuildOptions then
        E:RebuildOptions()
    end
end)
