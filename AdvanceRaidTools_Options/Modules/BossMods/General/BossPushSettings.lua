local E, L = unpack(ART)
local T = E.Templates

local OUTLINE_VALUES = {
    [""] = L["None"],
    OUTLINE = L["Outline"],
    THICKOUTLINE = L["ThickOutline"]
}

local STRATA_VALUES = {
    BACKGROUND = "BACKGROUND",
    LOW = "LOW",
    MEDIUM = "MEDIUM",
    HIGH = "HIGH",
    DIALOG = "DIALOG",
    FULLSCREEN = "FULLSCREEN"
}

local ROW_GAP = 6
local HEADER_GAP = 10

local function borderValues()
    local t = E:MediaList("border")
    t["None"] = nil
    return t
end

local function selectedBar(mod)
    local bar = mod:GetSelectedBar()
    return bar
end

local function clampInt(v, min, max)
    v = math.floor((tonumber(v) or min) + 0.5)
    if v < min then
        return min
    end
    if v > max then
        return max
    end
    return v
end

local function ensureTargetPoint(bar)
    bar.points = bar.points or {}
    if not bar.points[1] then
        bar.points[1] = {
            time = bar.targetTime or 120,
            hp = bar.targetPercent or 70
        }
    end
    bar.points[1].time = bar.targetTime or bar.points[1].time or 120
    bar.points[1].hp = bar.targetPercent or bar.points[1].hp or 70
end

local function syncTiming(bar)
    if not bar then
        return
    end
    bar.targetTime = clampInt(bar.targetTime, 1, 7200)
    bar.showOffset = clampInt(bar.showOffset or ((bar.showAt or (bar.targetTime - 10)) - bar.targetTime), -7200, 0)
    bar.showAt = math.max(0, bar.targetTime + bar.showOffset)
    ensureTargetPoint(bar)
end

local function barDropdownValues(mod)
    local values = {}
    for i, bar in ipairs(mod:GetBars()) do
        values[i] = bar.name or (L["BossMods_BossPushDefaultName"] .. " " .. i)
    end
    return values
end

local function buildBossPushBody(rightPanel, mod, isDisabled)
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

    local function refreshAfterListChange()
        refreshLive()
        if E.OptionsUI and E.OptionsUI.QueueRefresh then
            E.OptionsUI:QueueRefresh("current")
        end
    end

    local function selectedBarDisabled()
        return isDisabled() or not selectedBar(mod)
    end

    local function encounterDisabled()
        local b = selectedBar(mod)
        return selectedBarDisabled() or not b or b.trigger == "combat"
    end

    local function slider(opts)
        return track(T:Slider(rightPanel, {
            label = opts.label,
            min = opts.min,
            max = opts.max,
            step = opts.step or 1,
            value = opts.get(),
            get = opts.get,
            format = opts.format,
            onChange = function(v)
                opts.onChange(v)
                refreshLive()
            end,
            disabled = opts.disabled or isDisabled
        }))
    end

    local function stepper(opts)
        return track(T:NumericStepper(rightPanel, {
            label = opts.label,
            get = opts.get,
            set = function(v)
                opts.set(v)
                refreshLive()
            end,
            step = opts.step or 1,
            disabled = opts.disabled or isDisabled
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
            sorting = opts.sorting,
            placeholder = opts.placeholder,
            get = opts.get,
            onChange = function(v)
                opts.onChange(v)
                refreshLive()
            end,
            disabled = opts.disabled or isDisabled
        }))
    end

    local function editbox(opts)
        return track(T:EditBox(rightPanel, {
            label = opts.label,
            default = opts.get(),
            get = opts.get,
            numeric = opts.numeric,
            commitOn = "enter",
            onCommit = function(text)
                opts.onCommit(text)
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

    local function button(opts)
        return track(T:Button(rightPanel, {
            text = opts.text,
            tooltip = opts.tooltip,
            confirm = opts.confirm,
            confirmTitle = opts.confirmTitle,
            onClick = opts.onClick,
            disabled = opts.disabled or isDisabled
        }))
    end

    local function row(y, widgets, opts)
        return y + T:PlaceRow(rightPanel, widgets, y, widthPx, opts) + ROW_GAP
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

    local y = 0
    y = full(y, track(T:Header(rightPanel, {
        text = L["BossMods_BossPush"]
    })))
    y = full(y, track(T:Description(rightPanel, {
        text = L["BossMods_BossPushDesc"],
        sizeDelta = 1
    })))

    local unlockY, unlockCtrl = T:UnlockController(rightPanel, y, widthPx, {
        tracker = tracker,
        isDisabled = isDisabled,
        onEditModeChanged = function(v)
            mod:SetEditMode(v)
        end
    })
    y = unlockY

    y = section(y, "BossMods_BossPushBars")

    local selectBar = dropdown({
        label = L["BossMods_BossPushSelectedBar"],
        values = function()
            return barDropdownValues(mod)
        end,
        placeholder = L["None"],
        get = function()
            return mod.db.selectedBar
        end,
        onChange = function(v)
            mod.db.selectedBar = v
        end,
        disabled = function()
            return isDisabled() or #mod:GetBars() == 0
        end
    })
    y = row(y, {selectBar})

    local addBtn = button({
        text = L["Add"],
        onClick = function()
            mod:AddBar()
            refreshAfterListChange()
        end
    })
    local duplicateBtn = button({
        text = L["Duplicate"],
        onClick = function()
            mod:DuplicateBar(mod.db.selectedBar)
            refreshAfterListChange()
        end,
        disabled = function()
            return isDisabled() or not selectedBar(mod)
        end
    })
    local deleteBtn = button({
        text = L["Delete"],
        confirm = function()
            local bar = selectedBar(mod)
            return bar and L["BossMods_BossPushDeleteConfirm"]:format(bar.name) or nil
        end,
        confirmTitle = L["Delete"],
        onClick = function()
            mod:DeleteBar(mod.db.selectedBar)
            refreshAfterListChange()
        end,
        disabled = function()
            return isDisabled() or not selectedBar(mod)
        end
    })
    y = row(y, {addBtn, duplicateBtn, deleteBtn})

    local importBtn = button({
        text = L["Import"],
        onClick = function()
            E:PromptMultiline({
                key = "ART_BOSSPUSH_IMPORT",
                title = L["BossMods_BossPushImport"],
                text = L["BossMods_BossPushImportDesc"],
                parent = rightPanel,
                input = {
                    multiline = 8,
                    default = "",
                    maxLetters = 200000
                },
                onAccept = function(text)
                    local idx, err = mod:ImportBarString(text or "")
                    if idx then
                        local bar = mod:GetBar(idx)
                        E:Printf(L["BossMods_BossPushImported"]:format(bar and bar.name or L["BossMods_BossPush"]))
                        refreshAfterListChange()
                    elseif err then
                        E:Printf("|cffff4040%s|r", err)
                    end
                end
            })
        end
    })
    local exportBtn = button({
        text = L["Export"],
        onClick = function()
            E:ShowText({
                key = "ART_BOSSPUSH_EXPORT",
                title = L["BossMods_BossPushExport"],
                parent = rightPanel,
                viewer = {
                    text = mod:GetExportText(mod.db.selectedBar),
                    lines = 10
                }
            })
        end,
        disabled = function()
            return isDisabled() or not selectedBar(mod)
        end
    })
    local shareBtn = button({
        text = L["Share"],
        onClick = function()
            local ok, err = mod:ShareBarToChat(mod.db.selectedBar)
            if not ok and err then
                E:Printf("|cffff4040%s|r", err)
            end
        end,
        disabled = function()
            return isDisabled() or not selectedBar(mod)
        end
    })
    y = row(y, {importBtn, exportBtn, shareBtn})

    y = section(y, "BossMods_BossPushBarSettings")

        local enabled = checkbox({
            text = L["Enable"],
            labelTop = true,
            get = function()
                local b = selectedBar(mod)
                return b and b.enabled or false
            end,
            onChange = function(v)
                local b = selectedBar(mod)
                if b then
                    b.enabled = v
                end
            end,
            disabled = selectedBarDisabled
        })
        local trigger = dropdown({
            label = L["BossMods_BossPushTrigger"],
            values = function()
                return mod:GetTriggerValues()
            end,
            sorting = function()
                return mod:GetTriggerSorting()
            end,
            get = function()
                local b = selectedBar(mod)
                return b and b.trigger or "encounter"
            end,
            onChange = function(v)
                local b = selectedBar(mod)
                if b then
                    b.trigger = v
                end
            end,
            disabled = selectedBarDisabled
        })
        y = row(y, {enabled, trigger})

        local nameBox = editbox({
            label = L["Name"],
            get = function()
                local b = selectedBar(mod)
                return b and b.name or ""
            end,
            onCommit = function(text)
                local b = selectedBar(mod)
                if b then
                    b.name = strtrim(text or "") ~= "" and strtrim(text) or L["BossMods_BossPush"]
                end
            end,
            disabled = selectedBarDisabled
        })
        y = row(y, {nameBox})

        local bossUnit = dropdown({
            label = L["BossMods_BossPushBossUnit"],
            values = function()
                return mod:GetUnitValues()
            end,
            sorting = function()
                return mod:GetUnitSorting()
            end,
            get = function()
                local b = selectedBar(mod)
                return b and b.bossUnit or "boss1"
            end,
            onChange = function(v)
                local b = selectedBar(mod)
                if b then
                    b.bossUnit = v
                end
            end,
            disabled = selectedBarDisabled
        })
        local encounter = dropdown({
            label = L["BossMods_BossPushEncounter"],
            values = function()
                return mod:GetEncounterValues()
            end,
            sorting = function()
                return mod:GetEncounterSorting()
            end,
            get = function()
                local b = selectedBar(mod)
                if not b then
                    return 0
                end
                local customKey = mod:GetCustomEncounterKey()
                local values = mod:GetEncounterValues()
                if b.encounterMode == customKey or values[b.encounterID] == nil then
                    return customKey
                end
                return b.encounterID or 0
            end,
            onChange = function(v)
                local b = selectedBar(mod)
                if b then
                    local customKey = mod:GetCustomEncounterKey()
                    if v == customKey then
                        b.encounterMode = customKey
                        b.customEncounterID = b.customEncounterID or b.encounterID or 0
                        b.encounterID = b.customEncounterID
                    else
                        b.encounterMode = "preset"
                        b.encounterID = tonumber(v) or 0
                    end
                end
            end,
            disabled = encounterDisabled
        })
        y = row(y, {bossUnit, encounter})

        local customEncounterID = editbox({
            label = L["BossMods_BossPushCustomEncounterID"],
            numeric = true,
            get = function()
                local b = selectedBar(mod)
                return tostring(b and b.customEncounterID or b and b.encounterID or 0)
            end,
            onCommit = function(text)
                local b = selectedBar(mod)
                if b then
                    b.customEncounterID = clampInt(text, 0, 999999)
                    if b.encounterMode == mod:GetCustomEncounterKey() then
                        b.encounterID = b.customEncounterID
                    end
                end
            end,
            disabled = function()
                local b = selectedBar(mod)
                return encounterDisabled() or not b or b.encounterMode ~= mod:GetCustomEncounterKey()
            end
        })
        y = row(y, {customEncounterID})

        y = section(y, "BossMods_BossPushTiming")

        local showOffset = stepper({
            label = L["BossMods_BossPushShowOffset"],
            get = function()
                local b = selectedBar(mod)
                return b and b.showOffset or -10
            end,
            set = function(v)
                local b = selectedBar(mod)
                if b then
                    b.showOffset = clampInt(v, -7200, 0)
                    syncTiming(b)
                end
            end,
            disabled = selectedBarDisabled
        })
        local targetTime = stepper({
            label = L["BossMods_BossPushTargetTime"],
            get = function()
                local b = selectedBar(mod)
                return b and b.targetTime or 120
            end,
            set = function(v)
                local b = selectedBar(mod)
                if b then
                    b.targetTime = clampInt(v, 1, 7200)
                    syncTiming(b)
                end
            end,
            disabled = selectedBarDisabled
        })
        y = row(y, {showOffset, targetTime})

        y = section(y, "BossMods_BossPushHealth")

        local targetPercent = stepper({
            label = L["BossMods_BossPushTargetPercent"],
            get = function()
                local b = selectedBar(mod)
                return b and b.targetPercent or 70
            end,
            set = function(v)
                local b = selectedBar(mod)
                if b then
                    b.targetPercent = clampInt(v, 0, 100)
                    ensureTargetPoint(b)
                end
            end,
            disabled = selectedBarDisabled
        })
        y = row(y, {targetPercent})

    y = section(y, "BossMods_BossPushDisplay")

    local width = slider({
        label = L["Width"],
        min = 120,
        max = 800,
        get = function()
            return mod.db.bar.width
        end,
        onChange = function(v)
            mod.db.bar.width = math.floor(v)
        end
    })
    local height = slider({
        label = L["Height"],
        min = 10,
        max = 60,
        get = function()
            return mod.db.bar.height
        end,
        onChange = function(v)
            mod.db.bar.height = math.floor(v)
        end
    })
    y = row(y, {width, height})

    local strata = dropdown({
        label = L["Strata"],
        values = STRATA_VALUES,
        get = function()
            return mod.db.strata
        end,
        onChange = function(v)
            mod.db.strata = v
        end
    })
    y = row(y, {strata})

    local fontSize = slider({
        label = (L["Font"] .. " " .. L["Size"]),
        min = 8,
        max = 32,
        get = function()
            return mod.db.font.size
        end,
        onChange = function(v)
            mod.db.font.size = math.floor(v)
        end
    })
    local outline = dropdown({
        label = L["Outline"],
        values = OUTLINE_VALUES,
        get = function()
            return mod.db.font.outline
        end,
        onChange = function(v)
            mod.db.font.outline = v
        end
    })
    local fontColor = color({
        label = (L["Font"] .. " " .. L["Color"]),
        hasAlpha = true,
        get = function()
            return mod.db.font.color
        end,
        onChange = function(r, g, b, a)
            mod.db.font.color = {r, g, b, a}
        end
    })
    y = row(y, {fontSize, outline, fontColor})

    y = section(y, "Color")

    local barColor = color({
        label = L["BossMods_BossPushBarColor"],
        hasAlpha = true,
        get = function()
            return mod.db.bar.color
        end,
        onChange = function(r, g, b, a)
            mod.db.bar.color = {r, g, b, a}
        end
    })
    local lineColor = color({
        label = L["BossMods_BossPushLineColor"],
        hasAlpha = true,
        get = function()
            return mod.db.bar.lineColor
        end,
        onChange = function(r, g, b, a)
            mod.db.bar.lineColor = {r, g, b, a}
        end
    })
    y = row(y, {barColor, lineColor})

    y = section(y, "Background")

    local enableBg = checkbox({
        text = (L["Enable"] .. " " .. L["Background"]),
        labelTop = true,
        get = function()
            return mod.db.background.enabled
        end,
        onChange = function(v)
            mod.db.background.enabled = v
        end
    })
    local bgOpacity = slider({
        label = (L["Background"] .. " " .. L["Opacity"]),
        min = 0,
        max = 1,
        step = 0.05,
        get = function()
            return mod.db.background.opacity
        end,
        onChange = function(v)
            mod.db.background.opacity = v
        end
    })
    local bgColor = color({
        label = (L["Background"] .. " " .. L["Color"]),
        hasAlpha = false,
        get = function()
            return mod.db.background.color
        end,
        onChange = function(r, g, b)
            mod.db.background.color = {r, g, b}
        end
    })
    y = row(y, {enableBg, bgOpacity, bgColor})

    y = section(y, "Border")

    local enableBorder = checkbox({
        text = (L["Enable"] .. " " .. L["Border"]),
        labelTop = true,
        get = function()
            return mod.db.border.enabled
        end,
        onChange = function(v)
            mod.db.border.enabled = v
        end
    })
    local borderTex = dropdown({
        label = (L["Border"] .. " " .. L["Texture"]),
        values = borderValues,
        get = function()
            return mod.db.border.texture
        end,
        onChange = function(v)
            mod.db.border.texture = v
        end
    })
    y = row(y, {enableBorder, borderTex})

    local borderSize = slider({
        label = (L["Border"] .. " " .. L["Size"]),
        min = 1,
        max = 16,
        get = function()
            return mod.db.border.size
        end,
        onChange = function(v)
            mod.db.border.size = math.floor(v)
        end
    })
    local borderColor = color({
        label = (L["Border"] .. " " .. L["Color"]),
        hasAlpha = true,
        get = function()
            return mod.db.border.color
        end,
        onChange = function(r, g, b, a)
            mod.db.border.color = {r, g, b, a}
        end
    })
    y = row(y, {borderSize, borderColor})

    local posNewY, posHandle = T:PositionSection(rightPanel, y, widthPx, {
        anchor = mod.frame,
        label = L["BossMods_BossPush"],
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
            y = 260
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
        Refresh = tracker.refresh,
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
        BossMods:RegisterBossSettingsBuilder("BossPush", buildBossPushBody)
    end
end

local bossPushEvents = E:NewCallbackHandle()
bossPushEvents:RegisterMessage("ART_BOSSPUSH_BARS_CHANGED", function()
    if E.OptionsUI and E.OptionsUI.QueueRefresh then
        E.OptionsUI:QueueRefresh("current")
    end
end)
