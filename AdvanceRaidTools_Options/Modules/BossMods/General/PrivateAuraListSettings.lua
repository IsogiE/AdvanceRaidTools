local E, L = unpack(ART)
local T = E.Templates

local SHOW_WHEN_VALUES = {
    always = L["Always"],
    combat = L["InCombat"],
    nocombat = L["OutOfCombat"]
}

local OUTLINE_VALUES = {
    [""] = L["None"],
    OUTLINE = L["Outline"],
    THICKOUTLINE = L["ThickOutline"]
}

local ROW_GAP = 6
local HEADER_GAP = 10

local function borderValues()
    local t = E:MediaList("border")
    t["None"] = nil
    return t
end

local function rosterSignature(roster)
    local parts = {}
    for i, entry in ipairs(roster or {}) do
        parts[i] = table.concat({
            entry.key or "",
            entry.displayName or "",
            entry.classFile or ""
        }, "\002")
    end
    return table.concat(parts, "\001")
end

local function buildPrivateAuraListBody(rightPanel, mod, isDisabled)
    local widthPx = rightPanel:GetWidth() or 0
    if widthPx <= 0 then
        return {}
    end

    if mod.EnsureDisplay then
        mod:EnsureDisplay()
    end

    local tracker = T:MakeTracker()
    local track = tracker.track
    local refreshPanel = tracker.refresh
    local currentRosterSignature = rosterSignature(mod:GetRosterEntries())

    local function refreshLive()
        mod:CallIfEnabled("Refresh")
        refreshPanel()
    end

    local function background()
        mod.db.style = mod.db.style or {}
        mod.db.style.background = mod.db.style.background or {
            enabled = false,
            color = {0, 0, 0},
            opacity = 0.45
        }
        return mod.db.style.background
    end

    local function privateAuras()
        mod.db.privateAuras = mod.db.privateAuras or {}
        mod.db.privateAuras.customBorder = mod.db.privateAuras.customBorder or {
            enabled = true,
            texture = "Pixel",
            size = 1,
            color = {0, 0, 0, 1},
            opacity = 1
        }
        return mod.db.privateAuras
    end

    local function slider(opts)
        return track(T:Slider(rightPanel, {
            label = opts.label,
            min = opts.min,
            max = opts.max,
            step = opts.step or 1,
            value = opts.get(),
            get = opts.get,
            isPercent = opts.isPercent,
            onChange = function(v)
                opts.onChange(v)
                refreshLive()
            end,
            disabled = opts.disabled or isDisabled
        }))
    end

    local function checkbox(opts)
        return track(T:Checkbox(rightPanel, {
            text = opts.text,
            labelTop = opts.labelTop,
            checked = opts.get(),
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
            disabled = opts.disabled or isDisabled
        }))
    end

    local function row(y, widgets)
        return y + T:PlaceRow(rightPanel, widgets, y, widthPx) + ROW_GAP
    end

    local function full(y, widget)
        return y + T:PlaceFull(rightPanel, widget, y, widthPx) + ROW_GAP
    end

    local function section(y, key)
        local h = track(T:Header(rightPanel, {
            text = L[key] or key
        }))
        return y + T:PlaceFull(rightPanel, h, y, widthPx) + HEADER_GAP
    end

    local previewUnlocked = false
    local previewRows
    local function previewDisabled()
        local moduleDisabled = isDisabled
        if type(isDisabled) == "function" then
            moduleDisabled = isDisabled()
        end
        return moduleDisabled or not previewUnlocked
    end
    local function refreshPreviewControls()
        if previewRows and previewRows.SetDisabled then
            previewRows.SetDisabled(previewDisabled())
        end
    end

    local y = 0
    y = full(y, track(T:Header(rightPanel, {
        text = L["BossMods_PrivateAuraList"]
    })))
    y = full(y, track(T:Description(rightPanel, {
        text = L["BossMods_PrivateAuraListDesc"],
        sizeDelta = 1
    })))

    local unlockY, unlockCtrl = T:UnlockController(rightPanel, y, widthPx, {
        tracker = tracker,
        isDisabled = isDisabled,
        onEditModeChanged = function(v)
            previewUnlocked = v and true or false
            refreshPreviewControls()
            mod:SetEditMode(v)
        end
    })
    y = unlockY

    previewRows = slider({
        label = ((L["Preview"] or "Preview") .. " " .. (L["Rows"] or "Rows")),
        min = 1,
        max = 40,
        step = 1,
        get = function()
            return mod.db.layout.previewRows or 5
        end,
        onChange = function(v)
            mod.db.layout.previewRows = math.max(1, math.min(40, math.floor(v + 0.5)))
        end,
        disabled = previewDisabled
    })
    y = row(y, {previewRows})

    local enableBg = checkbox({
        text = (L["Enable"] .. " " .. L["Background"]),
        labelTop = true,
        get = function()
            return background().enabled
        end,
        onChange = function(v)
            background().enabled = v
        end
    })
    local enableBorder = checkbox({
        text = (L["Enable"] .. " " .. L["Border"]),
        labelTop = true,
        get = function()
            return mod.db.style.border.enabled
        end,
        onChange = function(v)
            mod.db.style.border.enabled = v
        end
    })
    y = row(y, {enableBg, enableBorder})

    y = section(y, "Visibility")
    local showWhen = dropdown({
        label = L["BossMods_ShowWhen"],
        values = SHOW_WHEN_VALUES,
        get = function()
            local v = mod.db.visibility.showWhen
            return SHOW_WHEN_VALUES[v] and v or "always"
        end,
        onChange = function(v)
            mod.db.visibility.showWhen = v
        end
    })
    y = row(y, {showWhen})

    y = section(y, "BossMods_PALRoster")
    local reset = track(T:LabelAlignedButton(rightPanel, {
        text = L["BossMods_PALResetExclusions"],
        onClick = function()
            mod:ClearExclusions()
            refreshPanel()
        end,
        disabled = function()
            return isDisabled() or not mod.db.excluded or next(mod.db.excluded) == nil
        end
    }))
    y = row(y, {reset})

    local roster = mod:GetRosterEntries()
    if #roster == 0 then
        y = full(y, track(T:Description(rightPanel, {
            text = L["BossMods_PALNoRoster"],
            sizeDelta = 0
        })))
    else
        for i = 1, #roster, 2 do
            local entries = {roster[i], roster[i + 1]}
            local widgets = {}
            for _, entry in ipairs(entries) do
                local colorCode = entry.classFile and E:ClassColorCode(entry.classFile) or "|cffffffff"
                widgets[#widgets + 1] = track(T:Checkbox(rightPanel, {
                    text = ("%s%s|r"):format(colorCode, entry.displayName or entry.key),
                    checked = not mod.db.excluded[entry.key],
                    get = function()
                        return not mod.db.excluded[entry.key]
                    end,
                    onChange = function(_, v)
                        mod:SetPlayerIncluded(entry.key, v)
                    end,
                    disabled = isDisabled
                }))
            end
            y = row(y, widgets)
        end
    end

    y = section(y, "BossMods_PALPrivateAuraIcons")
    local showCooldownText = checkbox({
        text = L["BossMods_PALShowCooldownText"],
        labelTop = true,
        get = function()
            return privateAuras().showDurationText ~= false
        end,
        onChange = function(v)
            privateAuras().showDurationText = v and true or false
        end
    })
    local cooldownTextScale = slider({
        label = L["BossMods_PALCooldownTextScale"],
        min = 0.1,
        max = 4,
        step = 0.1,
        isPercent = true,
        get = function()
            local v = tonumber(privateAuras().cooldownTextScale) or 1
            return math.max(0.1, math.min(4, v))
        end,
        onChange = function(v)
            privateAuras().cooldownTextScale = math.max(0.1, math.min(4, v))
        end
    })
    y = row(y, {showCooldownText, cooldownTextScale})

    local showDefaultBorder = checkbox({
        text = L["BossMods_PALShowDefaultAuraBorder"],
        labelTop = true,
        get = function()
            return privateAuras().showBorder ~= false
        end,
        onChange = function(v)
            privateAuras().showBorder = v and true or false
        end
    })
    local useArtBorder = checkbox({
        text = L["BossMods_PALUseCustomIconBorder"],
        labelTop = true,
        get = function()
            return privateAuras().customBorder.enabled ~= false
        end,
        onChange = function(v)
            privateAuras().customBorder.enabled = v and true or false
        end,
        disabled = function()
            local moduleDisabled = isDisabled
            if type(isDisabled) == "function" then
                moduleDisabled = isDisabled()
            end
            return moduleDisabled or privateAuras().showBorder ~= false
        end
    })
    y = row(y, {showDefaultBorder, useArtBorder})

    y = section(y, "Layout")
    local listWidth = slider({
        label = L["Width"],
        min = 80,
        max = 500,
        step = 1,
        get = function()
            return mod.db.layout.width
        end,
        onChange = function(v)
            mod.db.layout.width = math.floor(v)
        end
    })
    local rowHeight = slider({
        label = L["BossMods_PALRowHeight"],
        min = 12,
        max = 60,
        step = 1,
        get = function()
            return mod.db.layout.rowHeight
        end,
        onChange = function(v)
            mod.db.layout.rowHeight = math.floor(v)
        end
    })
    y = row(y, {listWidth, rowHeight})

    local rowGap = slider({
        label = L["BossMods_PALRowGap"],
        min = 0,
        max = 20,
        step = 1,
        get = function()
            return mod.db.layout.rowGap
        end,
        onChange = function(v)
            mod.db.layout.rowGap = math.floor(v)
        end
    })
    local iconCount = slider({
        label = (L["Icon"] .. " " .. L["Count"]),
        min = 1,
        max = 10,
        step = 1,
        get = function()
            return mod.db.layout.auraSlots or 3
        end,
        onChange = function(v)
            mod.db.layout.auraSlots = math.floor(v)
        end
    })
    y = row(y, {rowGap, iconCount})

    y = section(y, L["Background"] .. " & " .. L["Border"])
    local opacity = slider({
        label = L["Opacity"],
        min = 0,
        max = 1,
        step = 0.05,
        get = function()
            return mod.db.style.classColorAlpha
        end,
        onChange = function(v)
            mod.db.style.classColorAlpha = v
        end
    })
    local borderTex = dropdown({
        label = (L["Border"] .. " " .. L["Texture"]),
        values = borderValues,
        get = function()
            return mod.db.style.border.texture
        end,
        onChange = function(v)
            mod.db.style.border.texture = v
        end
    })
    y = row(y, {opacity, borderTex})

    local borderSize = slider({
        label = (L["Border"] .. " " .. L["Size"]),
        min = 1,
        max = 16,
        step = 1,
        get = function()
            return mod.db.style.border.size
        end,
        onChange = function(v)
            mod.db.style.border.size = math.floor(v)
        end
    })
    local borderCol = color({
        label = (L["Border"] .. " " .. L["Color"]),
        get = function()
            return mod.db.style.border.color
        end,
        onChange = function(r, g, b, a)
            mod.db.style.border.color = {r, g, b, a}
        end
    })
    y = row(y, {borderSize, borderCol})

    y = section(y, "Font")
    local fontSize = slider({
        label = (L["Font"] .. " " .. L["Size"]),
        min = 7,
        max = 24,
        step = 1,
        get = function()
            return mod.db.style.font.size
        end,
        onChange = function(v)
            mod.db.style.font.size = math.floor(v)
        end
    })
    local fontOutline = dropdown({
        label = L["Outline"],
        values = OUTLINE_VALUES,
        get = function()
            return mod.db.style.font.outline
        end,
        onChange = function(v)
            mod.db.style.font.outline = v
        end
    })
    y = row(y, {fontSize, fontOutline})

    local posNewY, posHandle = T:PositionSection(rightPanel, y, widthPx, {
        anchor = mod.display and mod.display.frame,
        label = L["BossMods_PrivateAuraList"],
        headerText = L["BossMods_PrivateAuraList"] .. " " .. L["Position"],
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
            x = -360,
            y = 0
        },
        onChanged = refreshLive,
        isDisabled = isDisabled,
        unlockController = unlockCtrl,
        showOffsets = true
    })
    y = posNewY

    local totalHeight = math.max(y + 10, 1)
    rightPanel:SetHeight(totalHeight)

    return {
        height = totalHeight,
        Refresh = function()
            if rosterSignature(mod:GetRosterEntries()) ~= currentRosterSignature then
                return true
            end
            tracker.refresh()
        end,
        Release = function()
            posHandle.Release()
            unlockCtrl:Release()
            tracker.release()
        end
    }
end

do
    local BossMods = E:GetModule("BossMods", true)
    if BossMods and BossMods.RegisterBossSettingsBuilder then
        BossMods:RegisterBossSettingsBuilder("PrivateAuraList", buildPrivateAuraListBody)
    end
end

local rosterEvents = E:NewCallbackHandle()
local function refreshOpenOptions()
    if not (E.OptionsUI and E.OptionsUI.mainFrame and E.OptionsUI.mainFrame:IsShown()) then
        return
    end
    if E.OptionsUI.currentKey ~= "BossMods" then
        return
    end
    if E.OptionsUI.QueueRefresh then
        E.OptionsUI:QueueRefresh("current")
    end
end

rosterEvents:RegisterMessage("ART_ROSTER_INVALIDATED", refreshOpenOptions)
rosterEvents:RegisterEvent("GROUP_LEFT", refreshOpenOptions)
