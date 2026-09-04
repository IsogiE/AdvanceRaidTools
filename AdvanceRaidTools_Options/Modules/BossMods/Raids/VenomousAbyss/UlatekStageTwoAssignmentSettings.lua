local E, L = unpack(ART)
local T = E.Templates

local ROW_GAP = 6
local DEFAULT_POSITION = {point = "CENTER", x = 0, y = 120}
local OUTLINE_VALUES = {
    [""] = L["None"] or "None",
    OUTLINE = L["Outline"] or "Outline",
    THICKOUTLINE = L["ThickOutline"] or "Thick Outline",
    OUTLINE_SLUG = "Slug Outline"
}
local OUTLINE_ORDER = {"", "OUTLINE", "THICKOUTLINE", "OUTLINE_SLUG"}

local function build(rightPanel, mod, isDisabled)
    local width = rightPanel:GetWidth() or 0
    if width <= 0 then return {} end

    local settings = mod:GetAbilitySettings()
    if not settings then return {} end
    settings.text.font = settings.text.font or {
        name = "Friz Quadrata TT", size = 34, outline = "THICKOUTLINE"
    }
    settings.difficulties = settings.difficulties or {
        normal = true, heroic = true, mythic = true
    }

    local tracker = T:MakeTracker()
    local track = tracker.track
    local unlockController

    local function refresh()
        mod:Refresh()
        tracker.refresh()
    end
    local function full(y, widget)
        return y + T:PlaceFull(rightPanel, widget, y, width) + ROW_GAP
    end
    local function row(y, widgets)
        return y + T:PlaceRow(rightPanel, widgets, y, width) + ROW_GAP
    end
    local function slider(label, low, high, step, get, set, disabled)
        return track(T:Slider(rightPanel, {
            label = label, min = low, max = high, step = step,
            value = get(), get = get,
            onChange = function(value) set(value); refresh() end,
            disabled = disabled or isDisabled
        }))
    end
    local function checkbox(text, get, set, disabled)
        return track(T:Checkbox(rightPanel, {
            text = text, labelTop = true, get = get,
            onChange = function(_, value) set(value and true or false); refresh() end,
            disabled = disabled or isDisabled
        }))
    end
    local function dropdown(label, values, sorting, get, set, disabled)
        return track(T:Dropdown(rightPanel, {
            label = label, values = values, sorting = sorting, get = get,
            onChange = function(value) set(value); refresh() end,
            disabled = disabled or isDisabled
        }))
    end
    local function color(label, get, set)
        local value = get()
        return track(T:ColorSwatch(rightPanel, {
            label = label, labelTop = true, hasAlpha = true,
            r = value[1] or value.r or 1,
            g = value[2] or value.g or 1,
            b = value[3] or value.b or 1,
            a = value[4] or value.a or 1,
            onChange = function(r, g, b, a)
                set({r, g, b, a}); refresh()
            end,
            disabled = isDisabled
        }))
    end

    local y = 0
    y = full(y, track(T:Header(rightPanel, {
        text = L["BossMods_UlatekStageTwoAssignment"]
    })))
    y = full(y, track(T:Description(rightPanel, {
        text = L["BossMods_UlatekStageTwoAssignmentDesc"], sizeDelta = 1
    })))

    local unlockY
    unlockY, unlockController = T:UnlockController(rightPanel, y, width, {
        tracker = tracker, isDisabled = isDisabled,
        onEditModeChanged = function(value) mod:SetEditMode(value) end
    })
    y = unlockY
    y = full(y, track(T:Button(rightPanel, {
        text = "Preview assignment and arrow",
        onClick = function() mod:Preview() end,
        disabled = isDisabled
    })))

    y = full(y, track(T:Header(rightPanel, {text = "Active difficulties"})))
    y = row(y, {
        checkbox("Normal", function() return settings.difficulties.normal end,
            function(value) settings.difficulties.normal = value end),
        checkbox("Heroic", function() return settings.difficulties.heroic end,
            function(value) settings.difficulties.heroic = value end),
        checkbox("Mythic", function() return settings.difficulties.mythic end,
            function(value) settings.difficulties.mythic = value end)
    })

    y = full(y, track(T:Header(rightPanel, {text = "Countdown"})))
    y = row(y, {
        slider("Display duration", 1, 15, 1,
            function() return settings.text.secondsBefore or 5 end,
            function(value) settings.text.secondsBefore = math.floor(value + 0.5) end),
        checkbox("Show one decimal",
            function() return settings.text.showOneDecimal ~= false end,
            function(value) settings.text.showOneDecimal = value end)
    })

    y = full(y, track(T:Header(rightPanel, {text = "Text appearance"})))
    y = full(y, checkbox("Override default text appearance",
        function() return settings.text.overrideAppearance == true end,
        function(value)
            settings.text.overrideAppearance = value
            settings.text.overrideAppearanceInitialized = true
        end))
    local textDisabled = function()
        return isDisabled() or settings.text.overrideAppearance ~= true
    end
    y = row(y, {
        dropdown(L["Font"] or "Font", function() return E:MediaList("font") end,
            nil, function() return settings.text.font.name end,
            function(value) settings.text.font.name = value end, textDisabled),
        slider("Font size", 8, 72, 1,
            function() return settings.text.font.size or 34 end,
            function(value) settings.text.font.size = math.floor(value + 0.5) end,
            textDisabled),
        dropdown(L["Outline"] or "Outline", OUTLINE_VALUES, OUTLINE_ORDER,
            function() return settings.text.font.outline or "" end,
            function(value) settings.text.font.outline = value or "" end,
            textDisabled)
    })

    y = full(y, track(T:Header(rightPanel, {text = "Arrow appearance"})))
    y = row(y, {
        slider("Arrow size", 20, 160, 1,
            function() return mod.db.arrow.size end,
            function(value) mod.db.arrow.size = math.floor(value + 0.5) end),
        color("Arrow color", function() return mod.db.arrow.color end,
            function(value) mod.db.arrow.color = value end)
    })
    y = row(y, {
        slider("Arrow X offset", -300, 300, 1,
            function() return mod.db.arrow.x end,
            function(value) mod.db.arrow.x = math.floor(value + 0.5) end),
        slider("Arrow Y offset", -300, 300, 1,
            function() return mod.db.arrow.y end,
            function(value) mod.db.arrow.y = math.floor(value + 0.5) end)
    })

    local anchor = mod:GetAnchor()
    local positionY, positionHandle = T:PositionSection(rightPanel, y, width, {
        anchor = anchor,
        label = L["BossMods_UlatekStageTwoAssignment"],
        headerText = (L["BossMods_UlatekStageTwoAssignment"] or "Stage 2 Side Assignment")
            .. " " .. (L["Position"] or "Position"),
        tracker = tracker,
        getPosition = function()
            local position = mod:GetPosition()
            return {point = position.point, x = position.x, y = position.y}
        end,
        setPosition = function(position) mod:SavePosition(position) end,
        defaultPosition = DEFAULT_POSITION, onChanged = refresh,
        isDisabled = isDisabled, unlockController = unlockController,
        showOffsets = true
    })
    y = positionY

    local totalHeight = math.max(y + 10, 1)
    rightPanel:SetHeight(totalHeight)
    return {
        height = totalHeight, Refresh = tracker.refresh,
        Release = function()
            mod:SetEditMode(false)
            positionHandle.Release()
            unlockController:Release()
            tracker.release()
        end
    }
end

local BossMods = E:GetModule("BossMods", true)
if BossMods then
    BossMods:RegisterBossSettingsBuilder("UlatekStageTwoAssignment", build)
end
