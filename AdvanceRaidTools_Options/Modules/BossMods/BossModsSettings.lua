local E, L = unpack(ART)
local T = E.Templates

local NAV_WIDTH = 220
local NAV_ROW_H = 26
local NAV_ROW_GAP = 2
local NAV_PAD = 4
local NAV_VISIBLE_ROWS = 15
local NAV_INNER_HEIGHT = NAV_VISIBLE_ROWS * NAV_ROW_H + (NAV_VISIBLE_ROWS - 1) * NAV_ROW_GAP
local NAV_BOX_HEIGHT = NAV_INNER_HEIGHT + NAV_PAD * 2
local COL_GAP = 8
local VIEWPORT_SLACK = 8

local BODY_SCROLLBAR_GUTTER = 18

local function paintNavRow(row, isSelected, featureEnabled)
    if isSelected then
        local ac = E.media.valueColor
        row:SetBackdropColor(ac[1], ac[2], ac[3], 0.35)
    else
        row:SetBackdropColor(0, 0, 0, 0)
    end
    row._label:SetTextColor(featureEnabled and 1 or 0.55, featureEnabled and 0.82 or 0.55, featureEnabled and 0 or 0.55)
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
    local bodyContentW = availW - NAV_WIDTH - COL_GAP - BODY_SCROLLBAR_GUTTER
    if bodyContentW < 1 then
        bodyContentW = 1
    end

    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(NAV_BOX_HEIGHT)

    local navBox = CreateFrame("Frame", nil, container, "BackdropTemplate")
    E:SetTemplate(navBox, "Transparent")
    navBox:SetSize(NAV_WIDTH, NAV_BOX_HEIGHT)
    navBox:SetPoint("TOPLEFT", 0, 0)

    local navScroll = T:ScrollFrame(navBox, {
        chrome = false,
        autoWidth = true,
        mouseWheelStep = NAV_ROW_H + NAV_ROW_GAP,
        scrollbarWidth = 10,
        scrollbarGap = 4
    })
    navScroll.frame:SetPoint("TOPLEFT", NAV_PAD, -NAV_PAD)
    navScroll.frame:SetPoint("BOTTOMRIGHT", -NAV_PAD, NAV_PAD)
    navScroll.scroll:HookScript("OnSizeChanged", navScroll.ApplyAutoWidth)

    local body = T:ScrollFrame(container, {
        chrome = false,
        autoWidth = true,
        minContentWidth = bodyContentW,
        mouseWheelStep = 40
    })
    body.frame:SetPoint("TOPLEFT", navBox, "TOPRIGHT", COL_GAP, 0)
    body.frame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
    body.scroll:HookScript("OnSizeChanged", body.ApplyAutoWidth)

    local state = {
        activeFeature = nil,
        navRows = {},
        featureBodies = {},
        placeholder = nil
    }

    local function isBossModsEnabled()
        return BossMods:IsEnabled()
    end

    local function paintAllRows()
        for _, entry in ipairs(state.navRows) do
            if entry.feature then
                local m = E:GetModule(entry.feature.moduleName, true)
                paintNavRow(entry.row, entry.feature.key == state.activeFeature, m and m:IsEnabled() or false)
                if entry.row._check and entry.row._check.Refresh then
                    entry.row._check.Refresh()
                end
            end
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
            return not (isBossModsEnabled() and mod:IsEnabled())
        end

        local handle = builder(wrapper, mod, isDisabled) or {}
        local h = handle.height or wrapper:GetHeight() or 30
        wrapper:SetHeight(math.max(1, h))

        local fb = {
            wrapper = wrapper,
            handle = handle,
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

    local function preBuildAllBodies()
        if (body.content:GetWidth() or 0) <= 0 then
            return
        end
        local features = BossMods:GetFeaturesForTab(tabKey)
        for _, feat in ipairs(features) do
            ensureFeatureBody(feat.key)
        end
    end

    local function showPlaceholder(text)
        destroyPlaceholder()
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

        for k, fb in pairs(state.featureBodies) do
            if fb and fb.wrapper and k ~= key then
                fb.wrapper:Hide()
            end
        end

        if not key then
            showPlaceholder(L["BossMods_PickFeature"])
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
        local h = fb.handle.height or fb.wrapper:GetHeight() or 30
        body.content:SetHeight(math.max(1, h))
        body.scroll:UpdateScrollChildRect()
        if resetScroll then
            body.ScrollToTop()
        end
    end

    local function selectFeature(key)
        local changed = key ~= state.activeFeature
        state.activeFeature = key
        showFeatureBody(key, changed)
        paintAllRows()
        local fb = state.featureBodies[key]
        if fb and fb.handle and fb.handle.Refresh then
            pcall(fb.handle.Refresh)
        end
    end

    local function rebuildNav()
        for _, entry in ipairs(state.navRows) do
            entry.row:Hide()
            entry.row:SetParent(nil)
            entry.row:ClearAllPoints()
        end
        wipe(state.navRows)

        local features = BossMods:GetFeaturesForTab(tabKey)
        if #features == 0 then
            local empty = T:Description(navScroll.content, {
                text = L["BossMods_NoFeatures"],
                sizeDelta = 0
            })
            empty.frame:SetPoint("TOPLEFT", 4, -4)
            navScroll.content:SetHeight(empty.frame:GetHeight() or 30)
            navScroll.scroll:UpdateScrollChildRect()
            state.navRows[#state.navRows + 1] = {
                row = empty.frame
            }
            state.activeFeature = nil
            return
        end

        local totalH = #features * NAV_ROW_H + math.max(0, #features - 1) * NAV_ROW_GAP
        navScroll.content:SetHeight(totalH)

        for i, feat in ipairs(features) do
            local y = (i - 1) * (NAV_ROW_H + NAV_ROW_GAP)

            local row = CreateFrame("Button", nil, navScroll.content, "BackdropTemplate")
            E:SetTemplate(row, "Default")
            row:SetHeight(NAV_ROW_H)
            row:SetPoint("TOPLEFT", 0, -y)
            row:SetPoint("TOPRIGHT", 0, -y)

            local label = row:CreateFontString(nil, "OVERLAY")
            E:RegisterFontString(label, 0)
            label:SetPoint("LEFT", 28, 0)
            label:SetPoint("RIGHT", -4, 0)
            label:SetJustifyH("LEFT")
            label:SetWordWrap(false)
            label:SetText(L[feat.labelKey] or feat.labelKey)
            row._label = label

            local check = T:Checkbox(row, {
                text = "",
                get = function()
                    local m = E:GetModule(feat.moduleName, true)
                    return m and m:IsEnabled() or false
                end,
                onChange = function(_, v)
                    E:SetModuleEnabled(feat.moduleName, v)
                end,
                disabled = function()
                    return not isBossModsEnabled()
                end
            })
            check.frame:SetPoint("LEFT", row, "LEFT", 4, 0)
            if check.Refresh then
                check.Refresh()
            end
            row._check = check

            row:SetScript("OnClick", function()
                selectFeature(feat.key)
            end)

            state.navRows[#state.navRows + 1] = {
                row = row,
                feature = feat
            }
        end

        navScroll.scroll:UpdateScrollChildRect()
        local first = state.navRows[1]
        state.activeFeature = first and first.feature and first.feature.key or nil
        paintAllRows()
    end

    container:SetScript("OnShow", function()
        if state.activeFeature then
            showFeatureBody(state.activeFeature)
        end
    end)

    rebuildNav()
    preBuildAllBodies()

    local function viewportHeight()
        local scroll = parent and parent.GetParent and parent:GetParent()
        if scroll and scroll.GetHeight then
            local h = scroll:GetHeight()
            if h and h > 0 then
                return h
            end
        end
        return NAV_BOX_HEIGHT
    end

    return {
        frame = container,
        height = NAV_BOX_HEIGHT,
        fullWidth = true,
        _relayout = function()
            container:SetHeight(math.max(NAV_BOX_HEIGHT, viewportHeight() - VIEWPORT_SLACK))
            navScroll.ApplyAutoWidth()
            body.ApplyAutoWidth()
            local newW = body.content:GetWidth() or 0
            if newW <= 0 then
                return
            end

            preBuildAllBodies()

            if state.activeFeature then
                showFeatureBody(state.activeFeature)
            end
        end,
        Refresh = function()
            paintAllRows()
            if not state.activeFeature then
                return
            end
            local fb = state.featureBodies[state.activeFeature]
            if fb and fb.handle and fb.handle.Refresh then
                pcall(fb.handle.Refresh)
            end
        end
    }
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
        tabs[tab.key] = buildTabGroup(tab)
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
