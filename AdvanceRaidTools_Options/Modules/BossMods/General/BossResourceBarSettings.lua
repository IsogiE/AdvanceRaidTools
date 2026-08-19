local E, L = unpack(ART)
local T = E.Templates

local ROW_GAP = 6
local HEADER_GAP = 10

local OUTLINE_VALUES = {
    [""] = "None",
    OUTLINE = "Outline",
    THICKOUTLINE = "Thick Outline",
    OUTLINE_SLUG = "Slug Outline"
}

local OUTLINE_SORTING = {"", "OUTLINE", "THICKOUTLINE", "OUTLINE_SLUG"}

local STRATA_VALUES = {
    BACKGROUND = "Background",
    LOW = "Low",
    MEDIUM = "Medium",
    HIGH = "High",
    DIALOG = "Dialog"
}

local STRATA_SORTING = {"BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG"}

local function selected(mod)
    return mod:GetSelectedBar()
end

local function buildBody(parent, mod, isDisabled)
    local widthPx = parent:GetWidth() or 0
    if widthPx <= 0 then
        return {height = 1}
    end

    local tracker = T:MakeTracker()
    local track = tracker.track
    local needsRebuild = false

    local function refresh(rebuild)
        mod:CallIfEnabled("Refresh")
        tracker.refresh()
        if rebuild then
            needsRebuild = true
            if E.OptionsUI and E.OptionsUI.QueueRefresh then
                E.OptionsUI:QueueRefresh("current")
            end
        end
    end

    local function unavailable()
        return isDisabled() or not selected(mod)
    end

    local function row(y, widgets)
        return y + T:PlaceRow(parent, widgets, y, widthPx) + ROW_GAP
    end

    local function full(y, widget)
        return y + T:PlaceFull(parent, widget, y, widthPx) + ROW_GAP
    end

    local function section(y, text)
        local header = track(T:Header(parent, {text = text}))
        return y + T:PlaceFull(parent, header, y, widthPx) + HEADER_GAP
    end

    local function button(opts)
        return track(T:Button(parent, {
            text = opts.text,
            onClick = opts.onClick,
            confirm = opts.confirm,
            confirmTitle = opts.confirmTitle,
            disabled = opts.disabled or isDisabled
        }))
    end

    local function dropdown(opts)
        return track(T:Dropdown(parent, {
            label = opts.label,
            values = opts.values,
            sorting = opts.sorting,
            placeholder = opts.placeholder,
            get = opts.get,
            onChange = function(value)
                opts.set(value)
                refresh(opts.rebuild)
            end,
            disabled = opts.disabled or isDisabled
        }))
    end

    local function checkbox(opts)
        local control = track(T:Checkbox(parent, {
            text = opts.text,
            labelTop = opts.labelTop,
            checked = opts.get(),
            get = opts.get,
            onChange = function(_, value)
                opts.set(value)
                refresh(opts.rebuild)
            end,
            disabled = opts.disabled or isDisabled
        }))
        control.Refresh()
        return control
    end

    local function editbox(opts)
        return track(T:EditBox(parent, {
            label = opts.label,
            get = opts.get,
            default = opts.get(),
            numeric = opts.numeric,
            commitOn = "enter",
            onCommit = function(value)
                opts.set(value)
                refresh(opts.rebuild)
            end,
            disabled = opts.disabled or isDisabled
        }))
    end

    local function slider(opts)
        return track(T:Slider(parent, {
            label = opts.label,
            min = opts.min,
            max = opts.max,
            step = opts.step or 1,
            value = opts.get(),
            get = opts.get,
            onChange = function(value)
                opts.set(value)
                refresh(false)
            end,
            disabled = opts.disabled or isDisabled
        }))
    end

    local function stepper(opts)
        return track(T:NumericStepper(parent, {
            label = opts.label,
            get = opts.get,
            set = function(value)
                opts.set(value)
                refresh(false)
            end,
            min = opts.min,
            max = opts.max,
            step = opts.step or 1,
            decimals = opts.decimals,
            disabled = opts.disabled or isDisabled
        }))
    end

    local function color(opts)
        local value = opts.get()
        return track(T:ColorSwatch(parent, {
            label = opts.label,
            labelTop = true,
            hasAlpha = opts.hasAlpha ~= false,
            r = value[1] or 1,
            g = value[2] or 1,
            b = value[3] or 1,
            a = value[4] or 1,
            onChange = function(r, g, b, a)
                opts.set({r, g, b, a})
                refresh(false)
            end,
            disabled = opts.disabled or isDisabled
        }))
    end

    local y = 0
    y = full(y, track(T:Header(parent, {text = "Boss Resource Bar"})))
    y = full(y, track(T:Description(parent, {
        text = "Displays the resource of a selected boss frame during the chosen encounter and difficulty. Mythic also includes Mythic (Flexible). Each saved bar has its own position and appearance.",
        sizeDelta = 1
    })))

    local unlockY, unlockCtrl = T:UnlockController(parent, y, widthPx, {
        tracker = tracker,
        isDisabled = function() return unavailable() end,
        onEditModeChanged = function(value)
            mod:SetEditMode(value)
        end
    })
    y = unlockY

    y = section(y, "Saved Bars")
    local values = {}
    for index, bar in ipairs(mod:GetBars()) do
        values[index] = bar.name
    end

    y = full(y, dropdown({
        label = "Selected bar",
        values = values,
        placeholder = "None",
        get = function() return mod.db.selectedBar end,
        set = function(value)
            mod.db.selectedBar = tonumber(value)
            mod:SetEditMode(false)
        end,
        rebuild = true,
        disabled = function() return isDisabled() or #mod:GetBars() == 0 end
    }))

    y = row(y, {
        button({
            text = "Add",
            onClick = function()
                mod:AddBar()
                refresh(true)
            end
        }),
        button({
            text = "Duplicate",
            onClick = function()
                mod:DuplicateBar()
                refresh(true)
            end,
            disabled = unavailable
        }),
        button({
            text = "Delete",
            confirmTitle = "Delete Boss Resource Bar",
            confirm = function()
                local bar = selected(mod)
                return bar and ("Delete '%s'?"):format(bar.name)
            end,
            onClick = function()
                mod:DeleteBar()
                refresh(true)
            end,
            disabled = unavailable
        })
    })

    y = row(y, {
        button({
            text = "Import",
            onClick = function()
                E:PromptMultiline({
                    key = "ART_BOSS_RESOURCE_IMPORT",
                    title = "Import Boss Resource Bar",
                    parent = parent,
                    input = {multiline = 8, default = "", maxLetters = 200000},
                    onAccept = function(text)
                        local index, err = mod:ImportBarString(text or "")
                        if index then
                            E:Printf("Imported Boss Resource Bar")
                            refresh(true)
                        elseif err then
                            E:Printf("|cffff4040%s|r", err)
                        end
                    end
                })
            end
        }),
        button({
            text = "Export",
            onClick = function()
                E:ShowText({
                    key = "ART_BOSS_RESOURCE_EXPORT",
                    title = "Export Boss Resource Bar",
                    parent = parent,
                    viewer = {text = mod:ExportBarString(), lines = 10}
                })
            end,
            disabled = unavailable
        }),
        button({
            text = "Share in Chat",
            onClick = function()
                local ok, err = mod:ShareBarToChat()
                if not ok and err then
                    E:Printf("|cffff4040%s|r", err)
                end
            end,
            disabled = unavailable
        })
    })

    local bar = selected(mod)
    if bar then
        y = section(y, "Bar Settings")
        y = row(y, {
            checkbox({
                text = "Enable bar",
                labelTop = true,
                get = function() return bar.enabled end,
                set = function(value) bar.enabled = value end,
                disabled = unavailable
            }),
            checkbox({
                text = "Show percentage text",
                labelTop = true,
                get = function() return bar.showPercent end,
                set = function(value) bar.showPercent = value end,
                disabled = unavailable
            })
        })

        y = row(y, {
            editbox({
                label = "Name",
                get = function() return bar.name end,
                set = function(value)
                    value = strtrim(value or "")
                    bar.name = value ~= "" and value or "Boss Resource Bar"
                end,
                rebuild = true,
                disabled = unavailable
            }),
            editbox({
                label = "Bar text",
                get = function() return bar.label end,
                set = function(value)
                    value = strtrim(value or "")
                    bar.label = value ~= "" and value or bar.name
                end,
                disabled = unavailable
            })
        })

        y = row(y, {
            dropdown({
                label = "Boss frame",
                values = function() return mod:GetUnitValues() end,
                sorting = function() return mod:GetUnitSorting() end,
                get = function() return bar.bossUnit end,
                set = function(value) bar.bossUnit = value end,
                disabled = unavailable
            }),
            dropdown({
                label = "Resource type",
                values = function() return mod:GetPowerValues() end,
                sorting = function() return mod:GetPowerSorting() end,
                get = function() return bar.powerType end,
                set = function(value)
                    bar.powerType = value == "auto" and "auto" or tonumber(value)
                end,
                disabled = unavailable
            })
        })

        y = row(y, {
            dropdown({
                label = "Encounter",
                values = function() return mod:GetEncounterValues() end,
                sorting = function() return mod:GetEncounterSorting() end,
                get = function() return bar.encounterID end,
                set = function(value) bar.encounterID = tonumber(value) or 0 end,
                disabled = unavailable
            }),
            dropdown({
                label = "Difficulty",
                values = function() return mod:GetDifficultyValues() end,
                sorting = function() return mod:GetDifficultySorting() end,
                get = function() return bar.difficulty end,
                set = function(value) bar.difficulty = value end,
                disabled = unavailable
            })
        })

        y = row(y, {
            dropdown({
                label = "Show bar",
                values = function() return mod:GetDisplayValues() end,
                sorting = function() return mod:GetDisplaySorting() end,
                get = function() return bar.displayWhen end,
                set = function(value) bar.displayWhen = value end,
                rebuild = true,
                disabled = unavailable
            }),
            stepper({
                label = "Resource threshold (%)",
                min = 0,
                max = 100,
                step = 1,
                decimals = 0,
                get = function() return bar.displayThreshold end,
                set = function(value) bar.displayThreshold = value end,
                disabled = function() return unavailable() or bar.displayWhen == "always" end
            })
        })

        y = section(y, "Appearance")
        y = row(y, {
            slider({
                label = "Width",
                min = 80,
                max = 1200,
                get = function() return bar.appearance.width end,
                set = function(value) bar.appearance.width = math.floor(value + 0.5) end,
                disabled = unavailable
            }),
            slider({
                label = "Height",
                min = 8,
                max = 120,
                get = function() return bar.appearance.height end,
                set = function(value) bar.appearance.height = math.floor(value + 0.5) end,
                disabled = unavailable
            })
        })

        y = row(y, {
            dropdown({
                label = "Bar texture",
                values = function() return E:MediaList("statusbar") end,
                get = function() return bar.appearance.texture end,
                set = function(value) bar.appearance.texture = value end,
                disabled = unavailable
            }),
            dropdown({
                label = "Frame strata",
                values = STRATA_VALUES,
                sorting = STRATA_SORTING,
                get = function() return bar.appearance.strata end,
                set = function(value) bar.appearance.strata = value end,
                disabled = unavailable
            })
        })

        y = row(y, {
            color({
                label = "Bar color",
                get = function() return bar.appearance.fillColor end,
                set = function(value) bar.appearance.fillColor = value end,
                disabled = unavailable
            }),
            color({
                label = "Background color and opacity",
                get = function() return bar.appearance.backgroundColor end,
                set = function(value) bar.appearance.backgroundColor = value end,
                disabled = unavailable
            })
        })

        y = row(y, {
            dropdown({
                label = "Font",
                values = function() return E:MediaList("font") end,
                get = function() return bar.appearance.font.name end,
                set = function(value) bar.appearance.font.name = value end,
                disabled = unavailable
            }),
            dropdown({
                label = "Outline",
                values = OUTLINE_VALUES,
                sorting = OUTLINE_SORTING,
                get = function() return bar.appearance.font.outline end,
                set = function(value) bar.appearance.font.outline = value end,
                disabled = unavailable
            })
        })

        y = row(y, {
            slider({
                label = "Font size",
                min = 8,
                max = 48,
                get = function() return bar.appearance.font.size end,
                set = function(value) bar.appearance.font.size = math.floor(value + 0.5) end,
                disabled = unavailable
            }),
            color({
                label = "Font color",
                get = function() return bar.appearance.font.color end,
                set = function(value) bar.appearance.font.color = value end,
                disabled = unavailable
            })
        })

        y = row(y, {
            checkbox({
                text = "Enable border",
                labelTop = true,
                get = function() return bar.appearance.border.enabled end,
                set = function(value) bar.appearance.border.enabled = value end,
                disabled = unavailable
            }),
            slider({
                label = "Border size",
                min = 1,
                max = 16,
                get = function() return bar.appearance.border.size end,
                set = function(value) bar.appearance.border.size = math.floor(value + 0.5) end,
                disabled = unavailable
            })
        })

        y = row(y, {
            dropdown({
                label = "Border texture",
                values = function() return E:MediaList("border") end,
                get = function() return bar.appearance.border.texture end,
                set = function(value) bar.appearance.border.texture = value end,
                disabled = unavailable
            }),
            color({
                label = "Border color",
                get = function() return bar.appearance.border.color end,
                set = function(value) bar.appearance.border.color = value end,
                disabled = unavailable
            })
        })

        local frame = mod:BuildFrame(bar)
        local nextY, positionHandle = T:PositionSection(parent, y, widthPx, {
            anchor = frame,
            label = bar.name,
            headerText = "Position",
            tracker = tracker,
            getPosition = function() return bar.position end,
            setPosition = function(position) mod:SaveSelectedPosition(position) end,
            defaultPosition = {point = "CENTER", x = 0, y = 250},
            onChanged = function() refresh(false) end,
            isDisabled = unavailable,
            unlockController = unlockCtrl,
            showOffsets = true
        })
        y = nextY

        local totalHeight = math.max(y + 10, 1)
        parent:SetHeight(totalHeight)
        return {
            height = totalHeight,
            Refresh = function()
                tracker.refresh()
                if needsRebuild then
                    needsRebuild = false
                    return true
                end
            end,
            Release = function()
                positionHandle.Release()
                unlockCtrl:Release()
                tracker.release()
            end
        }
    end

    local totalHeight = math.max(y + 10, 1)
    parent:SetHeight(totalHeight)
    return {
        height = totalHeight,
        Refresh = function()
            tracker.refresh()
            if needsRebuild then
                needsRebuild = false
                return true
            end
        end,
        Release = function()
            unlockCtrl:Release()
            tracker.release()
        end
    }
end

local BossMods = E:GetModule("BossMods", true)
if BossMods then
    BossMods:RegisterBossSettingsBuilder("BossResourceBar", buildBody)
end
