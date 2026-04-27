local E, L = unpack(ART)
local T = E.Templates

local SHOW_WHEN_VALUES = {
    always = L["BossMods_ShowAlways"],
    combat = L["BossMods_ShowCombat"],
    nocombat = L["BossMods_ShowNoCombat"],
    never = L["BossMods_ShowNever"]
}

local OUTLINE_VALUES = {
    [""] = L["None"],
    OUTLINE = L["Outline"],
    THICKOUTLINE = L["ThickOutline"]
}

local ANCHOR_VALUES = {
    TOPLEFT = L["BossMods_AnchorTL"],
    TOP = L["BossMods_AnchorT"],
    TOPRIGHT = L["BossMods_AnchorTR"],
    LEFT = L["Left"],
    CENTER = L["Center"],
    RIGHT = L["Right"],
    BOTTOMLEFT = L["BossMods_AnchorBL"],
    BOTTOM = L["BossMods_AnchorB"],
    BOTTOMRIGHT = L["BossMods_AnchorBR"]
}

local DECIMALS_VALUES = {
    [0] = "1",
    [1] = "1.1",
    [2] = "1.11"
}

local ROW_GAP = 6
local HEADER_GAP = 10

local function borderValues()
    local t = E:MediaList("border")
    t["None"] = nil
    return t
end

-- Build a row of widgets on `parent`, advancing y
local function row(parent, y, widthPx, widgets, opts)
    return y + T:PlaceRow(parent, widgets, y, widthPx, opts) + ROW_GAP
end
local function full(parent, y, widthPx, widget)
    return y + T:PlaceFull(parent, widget, y, widthPx) + ROW_GAP
end
local function section(parent, y, widthPx, textKey)
    local h = T:Header(parent, {
        text = L[textKey] or textKey
    })
    local nextY = y + T:PlaceFull(parent, h, y, widthPx) + HEADER_GAP
    return nextY, h
end

local function buildHoTTrackerBody(rightPanel, mod, isDisabled)
    local widthPx = rightPanel:GetWidth() or 0
    if widthPx <= 0 then
        return {}
    end

    local tracker = T:MakeTracker()
    local track = tracker.track
    local refreshPanel = tracker.refresh

    local function refreshLive()
        mod:CallIfEnabled("Refresh")
        refreshPanel()
    end

    -- slider that writes to a nested db path and triggers refresh
    local function slider(opts)
        return track(T:Slider(rightPanel, {
            label = opts.label,
            min = opts.min,
            max = opts.max,
            step = opts.step or 1,
            value = opts.value(),
            get = opts.value,
            onChange = function(v)
                opts.onChange(v)
                refreshLive()
            end,
            disabled = isDisabled
        }))
    end

    local function checkbox(opts)
        return track(T:Checkbox(rightPanel, {
            text = opts.text,
            labelTop = opts.labelTop,
            tooltip = opts.tooltip,
            get = opts.get,
            onChange = function(_, v)
                opts.onChange(v)
                refreshLive()
            end,
            disabled = opts.disabled or isDisabled
        }))
    end

    local function dropdown(opts)
        return track(T:Dropdown(rightPanel, {
            label = opts.label,
            values = opts.values,
            get = opts.get,
            onChange = function(v)
                opts.onChange(v)
                refreshLive()
            end,
            disabled = opts.disabled or isDisabled
        }))
    end

    local function color(opts)
        local c = opts.get()
        return track(T:ColorSwatch(rightPanel, {
            label = opts.label,
            labelTop = true,
            hasAlpha = opts.hasAlpha ~= false,
            r = c[1] or c.r or 1,
            g = c[2] or c.g or 1,
            b = c[3] or c.b or 1,
            a = c[4] or c.a or 1,
            onChange = function(r, g, b, a)
                opts.onChange(r, g, b, a)
                refreshLive()
            end,
            disabled = isDisabled
        }))
    end

    local y = 0
    local header = track(T:Header(rightPanel, {
        text = L["BossMods_HoTTracker"]
    }))
    y = full(rightPanel, y, widthPx, header)

    local desc = track(T:Description(rightPanel, {
        text = L["BossMods_HoTTrackerDesc"],
        sizeDelta = 1
    }))
    y = full(rightPanel, y, widthPx, desc)

    -- Visibility
    y = section(rightPanel, y, widthPx, "BossMods_Visibility")

    local showWhenDd = dropdown({
        label = L["BossMods_ShowWhen"],
        values = SHOW_WHEN_VALUES,
        get = function()
            return mod.db.visibility.showWhen
        end,
        onChange = function(v)
            mod.db.visibility.showWhen = v
        end
    })
    y = row(rightPanel, y, widthPx, {showWhenDd})

    -- Icon
    y = section(rightPanel, y, widthPx, "BossMods_IconSection")

    local sizeSlider = slider({
        label = L["BossMods_IconSize"],
        min = 16,
        max = 72,
        step = 1,
        value = function()
            return mod.db.layout.iconSize
        end,
        onChange = function(v)
            mod.db.layout.iconSize = math.floor(v)
        end
    })
    local spacingSlider = slider({
        label = L["BossMods_IconSpacing"],
        min = 0,
        max = 20,
        step = 1,
        value = function()
            return mod.db.layout.iconPad
        end,
        onChange = function(v)
            mod.db.layout.iconPad = math.floor(v)
        end
    })
    y = row(rightPanel, y, widthPx, {sizeSlider, spacingSlider})

    local opacitySlider = slider({
        label = L["Opacity"],
        min = 0,
        max = 1,
        step = 0.05,
        value = function()
            return mod.db.style.iconOpacity
        end,
        onChange = function(v)
            mod.db.style.iconOpacity = v
        end
    })
    y = row(rightPanel, y, widthPx, {opacitySlider})

    -- Background
    y = section(rightPanel, y, widthPx, "Background")

    local bgEnable = checkbox({
        text = L["BossMods_BgEnable"],
        labelTop = true,
        get = function()
            return mod.db.style.background.enabled
        end,
        onChange = function(v)
            mod.db.style.background.enabled = v
        end
    })
    local bgOpacity = slider({
        label = L["BackgroundOpacity"],
        min = 0,
        max = 1,
        step = 0.05,
        value = function()
            return mod.db.style.background.opacity
        end,
        onChange = function(v)
            mod.db.style.background.opacity = v
        end
    })
    y = row(rightPanel, y, widthPx, {bgEnable, bgOpacity})

    local bgColor = color({
        label = L["BossMods_BgColor"],
        hasAlpha = false,
        get = function()
            return mod.db.style.background.color
        end,
        onChange = function(r, g, b)
            mod.db.style.background.color = {r, g, b}
        end
    })
    y = row(rightPanel, y, widthPx, {bgColor})

    -- Border
    y = section(rightPanel, y, widthPx, "Border")

    local borderEnable = checkbox({
        text = L["BossMods_BorderEnable"],
        labelTop = true,
        get = function()
            return mod.db.style.border.enabled
        end,
        onChange = function(v)
            mod.db.style.border.enabled = v
        end
    })
    local borderTex = dropdown({
        label = L["BossMods_BorderTexture"],
        values = borderValues,
        get = function()
            return mod.db.style.border.texture
        end,
        onChange = function(v)
            mod.db.style.border.texture = v
        end
    })
    y = row(rightPanel, y, widthPx, {borderEnable, borderTex})

    local borderSize = slider({
        label = L["BossMods_BorderSize"],
        min = 1,
        max = 16,
        step = 1,
        value = function()
            return mod.db.style.border.size
        end,
        onChange = function(v)
            mod.db.style.border.size = math.floor(v)
        end
    })
    local borderOpacity = slider({
        label = L["BossMods_BorderOpacity"],
        min = 0,
        max = 1,
        step = 0.05,
        value = function()
            return mod.db.style.border.opacity
        end,
        onChange = function(v)
            mod.db.style.border.opacity = v
        end
    })
    y = row(rightPanel, y, widthPx, {borderSize, borderOpacity})

    local borderColor = color({
        label = L["BorderColor"],
        hasAlpha = true,
        get = function()
            return mod.db.style.border.color
        end,
        onChange = function(r, g, b, a)
            mod.db.style.border.color = {r, g, b, a}
        end
    })
    y = row(rightPanel, y, widthPx, {borderColor})

    -- Count
    y = section(rightPanel, y, widthPx, "BossMods_CountSection")

    local countEnable = checkbox({
        text = L["BossMods_CountEnable"],
        labelTop = true,
        get = function()
            return mod.db.style.count.enabled
        end,
        onChange = function(v)
            mod.db.style.count.enabled = v
        end
    })
    local countAnchor = dropdown({
        label = L["BossMods_Anchor"],
        values = ANCHOR_VALUES,
        get = function()
            return mod.db.style.count.anchor
        end,
        onChange = function(v)
            mod.db.style.count.anchor = v
        end
    })
    y = row(rightPanel, y, widthPx, {countEnable, countAnchor})

    local countOx = slider({
        label = L["BossMods_OffsetX"],
        min = -30,
        max = 30,
        step = 1,
        value = function()
            return mod.db.style.count.offsetX
        end,
        onChange = function(v)
            mod.db.style.count.offsetX = math.floor(v)
        end
    })
    local countOy = slider({
        label = L["BossMods_OffsetY"],
        min = -30,
        max = 30,
        step = 1,
        value = function()
            return mod.db.style.count.offsetY
        end,
        onChange = function(v)
            mod.db.style.count.offsetY = math.floor(v)
        end
    })
    y = row(rightPanel, y, widthPx, {countOx, countOy})

    local countSize = slider({
        label = L["FontSize"],
        min = 7,
        max = 24,
        step = 1,
        value = function()
            return mod.db.style.count.size
        end,
        onChange = function(v)
            mod.db.style.count.size = math.floor(v)
        end
    })
    local countOutline = dropdown({
        label = L["Outline"],
        values = OUTLINE_VALUES,
        get = function()
            return mod.db.style.count.outline
        end,
        onChange = function(v)
            mod.db.style.count.outline = v
        end
    })
    y = row(rightPanel, y, widthPx, {countSize, countOutline})

    local countColor = color({
        label = L["BossMods_CountColor"],
        hasAlpha = true,
        get = function()
            return mod.db.style.count.color
        end,
        onChange = function(r, g, b, a)
            mod.db.style.count.color = {r, g, b, a}
        end
    })
    y = row(rightPanel, y, widthPx, {countColor})

    -- Timer
    y = section(rightPanel, y, widthPx, "BossMods_TimerSection")

    local timerEnable = checkbox({
        text = L["BossMods_TimerEnable"],
        labelTop = true,
        get = function()
            return mod.db.style.timer.enabled
        end,
        onChange = function(v)
            mod.db.style.timer.enabled = v
        end
    })
    local timerAnchor = dropdown({
        label = L["BossMods_Anchor"],
        values = ANCHOR_VALUES,
        get = function()
            return mod.db.style.timer.anchor
        end,
        onChange = function(v)
            mod.db.style.timer.anchor = v
        end
    })
    y = row(rightPanel, y, widthPx, {timerEnable, timerAnchor})

    local timerOx = slider({
        label = L["BossMods_OffsetX"],
        min = -30,
        max = 30,
        step = 1,
        value = function()
            return mod.db.style.timer.offsetX
        end,
        onChange = function(v)
            mod.db.style.timer.offsetX = math.floor(v)
        end
    })
    local timerOy = slider({
        label = L["BossMods_OffsetY"],
        min = -30,
        max = 30,
        step = 1,
        value = function()
            return mod.db.style.timer.offsetY
        end,
        onChange = function(v)
            mod.db.style.timer.offsetY = math.floor(v)
        end
    })
    y = row(rightPanel, y, widthPx, {timerOx, timerOy})

    local timerSize = slider({
        label = L["FontSize"],
        min = 7,
        max = 24,
        step = 1,
        value = function()
            return mod.db.style.timer.size
        end,
        onChange = function(v)
            mod.db.style.timer.size = math.floor(v)
        end
    })
    local timerOutline = dropdown({
        label = L["Outline"],
        values = OUTLINE_VALUES,
        get = function()
            return mod.db.style.timer.outline
        end,
        onChange = function(v)
            mod.db.style.timer.outline = v
        end
    })
    y = row(rightPanel, y, widthPx, {timerSize, timerOutline})

    local timerColor = color({
        label = L["BossMods_TimerColor"],
        hasAlpha = true,
        get = function()
            return mod.db.style.timer.color
        end,
        onChange = function(r, g, b, a)
            mod.db.style.timer.color = {r, g, b, a}
        end
    })
    y = row(rightPanel, y, widthPx, {timerColor})

    local timerDecimals = dropdown({
        label = L["BossMods_TimerDecimals"],
        values = DECIMALS_VALUES,
        get = function()
            return mod.db.style.timer.decimals
        end,
        onChange = function(v)
            mod.db.style.timer.decimals = v
        end
    })
    y = row(rightPanel, y, widthPx, {timerDecimals})

    -- Tracked Spells
    y = section(rightPanel, y, widthPx, "BossMods_TrackedSpells")

    local available = mod:GetAvailableSpells()
    if #available == 0 then
        local empty = track(T:Description(rightPanel, {
            text = L["BossMods_NoTrackedSpellsForClass"],
            sizeDelta = 0
        }))
        y = full(rightPanel, y, widthPx, empty)
    else
        local rowWidgets = {}
        for i, spell in ipairs(available) do
            local key = spell.key
            local cb = checkbox({
                text = spell.name,
                labelTop = false,
                get = function()
                    local v = mod.db.enabledKeys[key]
                    return v == nil and true or v
                end,
                onChange = function(v)
                    mod.db.enabledKeys[key] = v and true or false
                end
            })
            rowWidgets[#rowWidgets + 1] = cb
            if #rowWidgets == 2 or i == #available then
                y = row(rightPanel, y, widthPx, rowWidgets)
                rowWidgets = {}
            end
        end
    end

    local posNewY, posHandle = T:PositionSection(rightPanel, y, widthPx, {
        anchor = mod.display and mod.display.frame,
        label = L["BossMods_HoTTracker"],
        tracker = tracker,
        getPosition = function()
            return {
                point = mod.db.position.point,
                x = mod.db.position.x,
                y = mod.db.position.y
            }
        end,
        setPosition = function(pos)
            mod:SavePosition(pos)
        end,
        defaultPosition = {
            point = "CENTER",
            x = 0,
            y = 150
        },
        onChanged = refreshLive,
        onEditModeChanged = function(v)
            mod:SetEditMode(v)
        end,
        isDisabled = isDisabled
    })
    y = posNewY

    local totalHeight = math.max(y + 10, 1)
    rightPanel:SetHeight(totalHeight)

    return {
        height = totalHeight,
        Refresh = tracker.refresh,
        Release = function()
            posHandle.Release()
            tracker.release()
        end
    }
end

do
    local BossMods = E:GetModule("BossMods", true)
    if BossMods and BossMods.RegisterBossSettingsBuilder then
        BossMods:RegisterBossSettingsBuilder("HoTTracker", buildHoTTrackerBody)
    end
end
