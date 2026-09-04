local E, L = unpack(ART)
local T = E.Templates

local ROW_GAP = 6
local OUTLINE_VALUES = {
    [""] = L["None"] or "None",
    OUTLINE = L["Outline"] or "Outline",
    THICKOUTLINE = L["ThickOutline"] or "Thick Outline",
    OUTLINE_SLUG = "Slug Outline"
}
local OUTLINE_ORDER = {"", "OUTLINE", "THICKOUTLINE", "OUTLINE_SLUG"}
local SIDE_VALUES = {ABOVE = "Above", BELOW = "Below"}
local SIDE_ORDER = {"ABOVE", "BELOW"}
local DEFAULT_POSITION = {point = "CENTER", x = 0, y = 220}

local function build(rightPanel, mod, isDisabled)
    local width = rightPanel:GetWidth() or 0
    if width <= 0 then return {} end

    mod:EnsureDefaults()
    mod:EnsureFrame()

    local tracker = T:MakeTracker()
    local track = tracker.track
    local positionHandles = {}
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
    local function slider(label, low, high, step, get, set)
        return track(T:Slider(rightPanel, {
            label = label, min = low, max = high, step = step,
            value = get(), get = get,
            onChange = function(value) set(value); refresh() end,
            disabled = isDisabled
        }))
    end
    local function dropdown(label, values, sorting, get, set)
        return track(T:Dropdown(rightPanel, {
            label = label, values = values, sorting = sorting, get = get,
            onChange = function(value) set(value); refresh() end,
            disabled = isDisabled
        }))
    end
    local function editbox(label, get, set)
        return track(T:EditBox(rightPanel, {
            label = label, default = get(), get = get, commitOn = "enter",
            onCommit = function(value) set(value); refresh() end,
            disabled = isDisabled
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
    local function button(text, onClick)
        return track(T:Button(rightPanel, {
            text = text, onClick = onClick, disabled = isDisabled
        }))
    end
    local function fontSection(y, title, data)
        y = full(y, track(T:Header(rightPanel, {text = title})))
        y = row(y, {
            dropdown(L["Font"] or "Font", function() return E:MediaList("font") end,
                nil, function() return data.name end,
                function(value) data.name = value end),
            dropdown(L["Outline"] or "Outline", OUTLINE_VALUES, OUTLINE_ORDER,
                function() return data.outline or "" end,
                function(value) data.outline = value or "" end)
        })
        y = row(y, {
            slider((L["Font"] or "Font") .. " " .. (L["Size"] or "Size"),
                8, 60, 1, function() return data.size end,
                function(value) data.size = math.floor(value + 0.5) end),
            color(L["Color"] or "Color", function() return data.color end,
                function(value) data.color = value end)
        })
        return y
    end

    local y = 0
    y = full(y, track(T:Header(rightPanel, {
        text = L["BossMods_CoiledAltarIntermissionBar"]
    })))
    y = full(y, track(T:Description(rightPanel, {
        text = L["BossMods_CoiledAltarIntermissionBarDesc"], sizeDelta = 1
    })))

    local unlockY
    unlockY, unlockController = T:UnlockController(rightPanel, y, width, {
        tracker = tracker, isDisabled = isDisabled,
        onEditModeChanged = function(value) mod:SetEditMode(value) end
    })
    y = unlockY
    y = row(y, {
        button("Preview 34 seconds", function() mod:Preview() end),
        button("Stop preview", function() mod:StopPreview() end)
    })

    y = full(y, track(T:Header(rightPanel, {text = "Bar appearance"})))
    y = row(y, {
        slider("Width", 180, 1000, 5, function() return mod.db.width end,
            function(value) mod.db.width = math.floor(value + 0.5) end),
        slider("Height", 10, 100, 1, function() return mod.db.height end,
            function(value) mod.db.height = math.floor(value + 0.5) end)
    })
    y = row(y, {
        slider("Scale", 0.5, 2, 0.05, function() return mod.db.scale end,
            function(value) mod.db.scale = value end),
        slider("Opacity", 0.1, 1, 0.05, function() return mod.db.opacity end,
            function(value) mod.db.opacity = value end)
    })
    y = row(y, {
        dropdown(L["Texture"] or "Texture",
            function() return E:MediaList("statusbar") end, nil,
            function() return mod.db.texture end,
            function(value) mod.db.texture = value end),
        color("Bar color", function() return mod.db.color end,
            function(value) mod.db.color = value end)
    })
    y = row(y, {
        color("Background color", function() return mod.db.backgroundColor end,
            function(value) mod.db.backgroundColor = value end),
        color("Marker color", function() return mod.db.markerColor end,
            function(value) mod.db.markerColor = value end)
    })
    y = row(y, {
        slider("Marker thickness", 1, 14, 1,
            function() return mod.db.markerWidth end,
            function(value) mod.db.markerWidth = math.floor(value + 0.5) end),
        slider("Marker text offset", 0, 30, 1,
            function() return mod.db.markerTextOffset end,
            function(value) mod.db.markerTextOffset = math.floor(value + 0.5) end)
    })

    y = fontSection(y, "Bar text", mod.db.font)
    y = fontSection(y, "Marker text", mod.db.markerFont)

    y = full(y, track(T:Header(rightPanel, {text = "Markers"})))
    y = full(y, track(T:Description(rightPanel, {
        text = "Times are measured from the start of the 34-second intermission cast. Marker text can be changed freely."
    })))
    for index = 1, 7 do
        local marker = mod.db.markers[index]
        y = full(y, track(T:Header(rightPanel, {text = "Marker " .. index})))
        y = row(y, {
            slider("Time after cast starts", 0, 34, 0.1,
                function() return marker.time end,
                function(value) marker.time = value end),
            editbox("Text", function() return marker.text end,
                function(value) marker.text = tostring(value or "") end),
            dropdown("Text position", SIDE_VALUES, SIDE_ORDER,
                function() return marker.side end,
                function(value) marker.side = value end)
        })
    end

    y = full(y, track(T:Header(rightPanel, {text = "Share layout"})))
    y = row(y, {
        button("Import", function()
            E:PromptMultiline({
                key = "ART_COILED_ALTAR_INTERMISSION_IMPORT",
                title = "Import Intermission Bar layout", parent = rightPanel,
                input = {multiline = 8, default = "", maxLetters = 200000},
                onAccept = function(text)
                    local ok, err = mod:ImportLayoutString(text or "")
                    if ok then
                        E:Printf("Imported Coiled Altar Intermission Bar layout")
                        if E.OptionsUI and E.OptionsUI.QueueRefresh then
                            E.OptionsUI:QueueRefresh("current")
                        end
                    elseif err then
                        E:Printf("|cffff4040%s|r", err)
                    end
                end
            })
        end),
        button("Export", function()
            E:ShowText({
                key = "ART_COILED_ALTAR_INTERMISSION_EXPORT",
                title = "Export Intermission Bar layout", parent = rightPanel,
                viewer = {text = mod:ExportLayoutString(), lines = 10}
            })
        end),
        button("Share in raid chat", function()
            local ok, err = mod:ShareLayoutToChat()
            if not ok and err then E:Printf("|cffff4040%s|r", err) end
        end)
    })

    local positionY, positionHandle = T:PositionSection(rightPanel, y, width, {
        anchor = mod.frame,
        label = L["BossMods_CoiledAltarIntermissionBar"],
        headerText = (L["BossMods_CoiledAltarIntermissionBar"] or "Intermission Bar")
            .. " " .. (L["Position"] or "Position"),
        tracker = tracker,
        getPosition = function()
            return {point = mod.db.position.point, x = mod.db.position.x,
                y = mod.db.position.y}
        end,
        setPosition = function(position) mod:SavePosition(position) end,
        defaultPosition = DEFAULT_POSITION, onChanged = refresh,
        isDisabled = isDisabled, unlockController = unlockController,
        showOffsets = true
    })
    y = positionY
    positionHandles[#positionHandles + 1] = positionHandle

    local totalHeight = math.max(y + 10, 1)
    rightPanel:SetHeight(totalHeight)
    return {
        height = totalHeight, Refresh = tracker.refresh,
        Release = function()
            mod:SetEditMode(false)
            mod:StopPreview()
            for _, handle in ipairs(positionHandles) do handle.Release() end
            unlockController:Release()
            tracker.release()
        end
    }
end

local BossMods = E:GetModule("BossMods", true)
if BossMods then
    BossMods:RegisterBossSettingsBuilder("CoiledAltarIntermissionBar", build)
end
