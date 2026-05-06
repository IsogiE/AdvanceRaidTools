local E, L = unpack(ART)
local T = E.Templates

local NO_SLOT = 0

local TYPE_SPELL = "spell"
local TYPE_MARK = "mark"
local TYPE_WORLD = "world"
local TYPE_FOCUS = "focus"
local TYPE_FOCUS_MARK = "focus_mark"
local TYPE_CUSTOM = "custom"
local LINE_PREFIX = "prefix"
local LINE_SUFFIX = "suffix"
local TARGET_MODE_TARGET = "target"
local TARGET_MODE_MOUSEOVER = "mouseover"
local TARGET_MODE_NAME = "name"

local TYPE_ORDER = {TYPE_SPELL, TYPE_MARK, TYPE_WORLD, TYPE_FOCUS, TYPE_FOCUS_MARK, TYPE_CUSTOM}
local MARKER_ORDER = {1, 2, 3, 4, 5, 6, 7, 8}
local LINE_ORDER = {LINE_PREFIX, LINE_SUFFIX}
local TARGET_MODE_ORDER = {TARGET_MODE_TARGET, TARGET_MODE_MOUSEOVER, TARGET_MODE_NAME, "focus", "player", "pet", "boss1",
                           "boss2", "boss3", "boss4", "boss5", "arena1", "arena2", "arena3", "arena4", "arena5",
                           "party1", "party2", "party3", "party4"}
local CONTROL_H = E.TemplatePrivate and E.TemplatePrivate.H_EDITBOX or 22
local LABELLED_CONTROL_H = 40
local ROW_GAP = 6

local function optionsResizeActive()
    return E.OptionsUI and E.OptionsUI.IsResizing and E.OptionsUI:IsResizing()
end

local ui = {
    newType = TYPE_SPELL
}
local slotOrder = {}
local slotValues = {}
local typeValueCache
local linePositionValueCache
local targetModeValueCache
local markerValueCache = {}

local Events = E:NewCallbackHandle()
local report
local selected
local statusText

local function refreshStatusLine()
    if ui.statusWidget and ui.statusWidget.SetText and statusText then
        ui.statusWidget.SetText(statusText())
    end
end

local function mod()
    return E:GetModule("Macros", true)
end

local function trim(text)
    return tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function queueRefresh()
    if E.OptionsUI and E.OptionsUI.QueueRefresh then
        E.OptionsUI:QueueRefresh("current")
    end
end

Events:RegisterMessage("ART_MACROS_CHANGED", queueRefresh)

local function changed(opts)
    opts = opts or {}
    local m = mod()
    local slot = selected()
    if opts.sync and m and slot then
        local ok, err, extra = m:SyncSlot(slot, opts.previousName, opts.silent ~= false)
        if err == "QUEUED" then
            E:Printf(L["Macros_UpdateQueued"])
        elseif not ok and err ~= "MEGAMACRO_BLOCKED" then
            report(ok, err, extra)
        end
    end
    if opts.refresh == false and opts.status ~= false then
        refreshStatusLine()
    elseif opts.refresh ~= false then
        queueRefresh()
    end
end

function selected()
    local m = mod()
    return m and m:GetSelectedSlot() or nil
end

local function disabled()
    local m = mod()
    return not (m and m:IsEnabled())
end

local function noSlot()
    return disabled() or selected() == nil
end

local function selectedIsDefault()
    local m, slot = mod(), selected()
    return m and slot and m:IsDefaultSlot(slot)
end

local function selectedMacroExists()
    local m, slot = mod(), selected()
    return m and slot and m:MacroExists(slot)
end

local function deleteActionText()
    if selectedIsDefault() then
        return L["Macros_DefaultMacro"]
    end
    return selectedMacroExists() and L["Macros_DeleteMacro"] or L["Macros_RemoveSetup"]
end

local function deleteConfirmText()
    return selectedMacroExists() and L["Macros_DeleteMacroConfirm"] or L["Macros_RemoveSetupConfirm"]
end

local function deleteSuccessText()
    return selectedMacroExists() and L["Macros_DeleteDone"] or L["Macros_RemoveSetupDone"]
end

local function setField(field, value)
    local slot = selected()
    if not slot then
        return
    end
    slot[field] = value
    changed({
        sync = true
    })
end

local function setFieldQuiet(field, value, opts)
    local slot = selected()
    if not slot then
        return
    end
    slot[field] = value
    opts = opts or {}
    opts.sync = true
    opts.refresh = false
    changed(opts)
end

local function setFieldStatusOnly(field, value)
    local slot = selected()
    if not slot then
        return
    end
    slot[field] = value
    changed({
        sync = true,
        refresh = false
    })
end

local function typeValues()
    if typeValueCache then
        return typeValueCache
    end
    typeValueCache = {
        [TYPE_SPELL] = L["Spell"],
        [TYPE_MARK] = L["Macros_TypeMark"],
        [TYPE_WORLD] = L["Macros_TypeWorld"],
        [TYPE_FOCUS] = L["Focus"],
        [TYPE_FOCUS_MARK] = L["Macros_TypeFocusMark"],
        [TYPE_CUSTOM] = L["Custom"]
    }
    return typeValueCache
end

local function linePositionValues()
    if linePositionValueCache then
        return linePositionValueCache
    end
    linePositionValueCache = {
        [LINE_PREFIX] = L["Macros_LinePrefix"],
        [LINE_SUFFIX] = L["Macros_LineSuffix"]
    }
    return linePositionValueCache
end

local function targetModeValues()
    if targetModeValueCache then
        return targetModeValueCache
    end
    targetModeValueCache = {
        [TARGET_MODE_TARGET] = L["Target"],
        [TARGET_MODE_MOUSEOVER] = L["Mouseover"],
        [TARGET_MODE_NAME] = L["Name"],
        focus = L["Focus"],
        player = L["Macros_TargetModePlayer"],
        pet = L["Macros_TargetModePet"],
        boss1 = L["Macros_TargetModeBoss"]:format(1),
        boss2 = L["Macros_TargetModeBoss"]:format(2),
        boss3 = L["Macros_TargetModeBoss"]:format(3),
        boss4 = L["Macros_TargetModeBoss"]:format(4),
        boss5 = L["Macros_TargetModeBoss"]:format(5),
        arena1 = L["Macros_TargetModeArena"]:format(1),
        arena2 = L["Macros_TargetModeArena"]:format(2),
        arena3 = L["Macros_TargetModeArena"]:format(3),
        arena4 = L["Macros_TargetModeArena"]:format(4),
        arena5 = L["Macros_TargetModeArena"]:format(5),
        party1 = L["Macros_TargetModeParty"]:format(1),
        party2 = L["Macros_TargetModeParty"]:format(2),
        party3 = L["Macros_TargetModeParty"]:format(3),
        party4 = L["Macros_TargetModeParty"]:format(4)
    }
    return targetModeValueCache
end

local function createButtonText()
    return L["Macros_Add"]
end

local function slotChoices()
    wipe(slotOrder)
    wipe(slotValues)

    local m = mod()
    if m then
        for _, slot in ipairs(m:GetSlots()) do
            local label = trim(slot.name) ~= "" and slot.name or slot.macroName
            slotValues[slot.id] = label
            slotOrder[#slotOrder + 1] = slot.id
        end
    end

    if #slotOrder == 0 then
        slotValues[NO_SLOT] = L["None"]
        slotOrder[1] = NO_SLOT
    end
    return slotValues
end

local function selectedID()
    local slot = selected()
    return slot and slot.id or NO_SLOT
end

local function markerChoices()
    local m = mod()
    local slot = selected()
    local kind = slot and slot.type == TYPE_WORLD and "world" or "target"
    if markerValueCache[kind] then
        return markerValueCache[kind]
    end
    local values = {}
    for i = 1, 8 do
        local icon = ""
        if m then
            icon = kind == "world" and m:GetWorldMarkerIconText(i) or m:GetMarkerIconText(i)
        end
        values[i] = icon .. " " .. L["Macros_MarkerN"]:format(i)
    end
    markerValueCache[kind] = values
    return values
end

function report(ok, err, extra, successText)
    if ok then
        if err == "SKIPPED" then
            return
        end
        E:Printf(err == "QUEUED" and L["Macros_UpdateQueued"] or successText or L["Macros_UpdateDone"])
        return
    end

    if err == "TOO_LONG" then
        local m = mod()
        E:Printf(L["Macros_ErrorTooLong"]:format(#tostring(extra or ""), m and m:GetTextLimit() or 255))
    elseif err == "EMPTY" then
        E:Printf(L["Macros_ErrorEmpty"])
    elseif err == "NAME_IN_USE" then
        E:Printf(L["Macros_ErrorNameInUse"])
    elseif err == "GENERAL_FULL" then
        E:Printf(L["Macros_ErrorGeneralFull"])
    elseif err == "MEGAMACRO_BLOCKED" then
        E:Printf(L["Macros_ErrorMegaMacro"])
    elseif err == "WRITE_FAILED" then
        E:Printf(L["Macros_ErrorWriteFailed"]:format(tostring(extra or "")))
    elseif err == "BIND_FAILED" then
        E:Printf(L["Macros_ErrorBindFailed"])
    elseif err == "DEFAULT_LOCKED" then
        E:Printf(L["Macros_ErrorDefaultLocked"])
    elseif err == "NO_TARGET" then
        E:Printf(L["Macros_ErrorNoTarget"])
    elseif err == "TARGET_NOT_PLAYER" then
        E:Printf(L["Macros_ErrorTargetNotPlayer"])
    else
        E:Printf(L["Macros_ErrorGeneric"]:format(tostring(err or "?")))
    end
end

local function editLines(kind)
    local m, slot = mod(), selected()
    if not (m and slot) then
        return
    end

    local field = "body"
    local title = L["Macros_EditBody"]
    E:PromptMultiline({
        key = "ART_MACROS_" .. kind,
        title = title,
        text = title,
        parent = E.OptionsUI and E.OptionsUI.mainFrame,
        input = {
            multiline = kind == "body" and 10 or 6,
            default = slot[field] or "",
            maxLetters = 1000
        },
        onAccept = function(text)
            slot[field] = tostring(text or "")
            changed({
                sync = true,
                refresh = false
            })
        end
    })
end

local function buildCustomLines(parent)
    local container = CreateFrame("Frame", nil, parent)
    local widgets = {}
    local renderedKey, renderedWidth

    local function track(widget)
        widgets[#widgets + 1] = widget
        return widget
    end

    local function releaseWidgets()
        for _, widget in ipairs(widgets) do
            if widget.frame then
                widget.frame:Hide()
                widget.frame:SetParent(nil)
                widget.frame:ClearAllPoints()
            end
        end
        wipe(widgets)
    end

    local function refreshWidgets()
        for _, widget in ipairs(widgets) do
            if widget.Refresh then
                widget.Refresh()
            end
        end
    end

    local function full(y, widget, width)
        return y + T:PlaceFull(container, widget, y, width, {
            padX = 0
        }) + ROW_GAP
    end

    local function row(y, rowWidgets, width, widths)
        return y + T:PlaceRow(container, rowWidgets, y, width, {
            padX = 0,
            widths = widths
        }) + ROW_GAP
    end

    local function rebuild(force)
        local m, slot = mod(), selected()
        if not (m and slot) then
            if renderedKey ~= nil then
                releaseWidgets()
                renderedKey = nil
            end
            container:SetHeight(1)
            return
        end

        local width = container:GetWidth() or 0
        if width <= 0 then
            width = 760
        end
        local key = ("%s:%d"):format(tostring(slot.id), #(slot.customLines or {}))
        if not force and key == renderedKey and math.abs(width - (renderedWidth or 0)) < 0.5 then
            refreshWidgets()
            return
        end

        renderedKey = key
        renderedWidth = width
        releaseWidgets()

        local y = 0

        for index, line in ipairs(slot.customLines or {}) do
            local lineBox = track(T:EditBox(container, {
                label = L["Macros_CustomLine"],
                default = line.text or "",
                commitOn = "focuslost",
                maxLetters = 255,
                onCommit = function(text)
                    m:SetCustomLineText(slot, index, text, true)
                    changed({
                        sync = true,
                        refresh = false
                    })
                end,
                disabled = noSlot
            }))

            local position = track(T:Dropdown(container, {
                label = L["Macros_CustomLinePosition"],
                buttonHeight = CONTROL_H,
                height = LABELLED_CONTROL_H,
                values = linePositionValues,
                sorting = LINE_ORDER,
                get = function()
                    return line.position or LINE_PREFIX
                end,
                onChange = function(value)
                    m:SetCustomLinePosition(slot, index, value, true)
                    changed({
                        sync = true,
                        refresh = false,
                        status = false
                    })
                end,
                disabled = noSlot
            }))

            local remove = track(T:LabelAlignedButton(container, {
                text = "X",
                buttonHeight = CONTROL_H,
                totalHeight = LABELLED_CONTROL_H,
                buttonWidth = CONTROL_H,
                tooltip = {
                    title = L["Macros_RemoveCustomLine"],
                    desc = L["Macros_RemoveCustomLine"]
                },
                onClick = function()
                    m:RemoveCustomLine(slot, index, true)
                    changed({
                        sync = true
                    })
                end,
                disabled = noSlot
            }))

            y = row(y, {lineBox, position, remove}, width, {5, 1.25, 0.35})
        end

        local add = track(T:Button(container, {
            text = L["Macros_AddCustomLine"],
            width = 140,
            onClick = function()
                m:AddCustomLine(slot, LINE_PREFIX, true)
                changed({
                    sync = true
                })
            end,
            disabled = noSlot
        }))
        add.frame:ClearAllPoints()
        add.frame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -y)
        y = y + add.frame:GetHeight() + ROW_GAP

        container:SetHeight(math.max(1, y))
    end

    container:HookScript("OnSizeChanged", function()
        if not optionsResizeActive() then
            rebuild(true)
        end
    end)
    if E.OptionsUI and E.OptionsUI.AddResizeFlusher then
        E.OptionsUI:AddResizeFlusher(function()
            rebuild(true)
        end, container)
    end
    rebuild(true)

    return {
        frame = container,
        height = container:GetHeight(),
        fullWidth = true,
        Refresh = function()
            rebuild(false)
        end,
        _relayout = function()
            rebuild(false)
        end
    }
end

local function startBindingCapture()
    local m, slot = mod(), selected()
    if not (m and slot) then
        return
    end

    local function finish(popup, key)
        if key == "ESCAPE" then
            local ok, err = m:ClearBinding(slot)
            report(ok, err, nil, L["Macros_KeybindCleared"])
            popup:Close()
            return
        end

        local combo = m:NormalizeKey(key)
        if not combo then
            return
        end

        local ok, err, extra = m:Bind(slot, combo)
        report(ok, err, extra, L["Macros_BindDone"])
        popup:Close()
    end

    E:ShowPopup({
        key = "ART_MACROS_BIND",
        replace = true,
        title = L["Macros_KeybindPopupTitle"]:format(slot.name or slot.macroName),
        text = L["Macros_KeybindPopupText"],
        parent = E.OptionsUI and E.OptionsUI.mainFrame,
        buttons = {{
            text = L["Cancel"],
            preset = "cancel"
        }},
        onShow = function(popup)
            popup:EnableKeyboard(true)
            if popup.SetPropagateKeyboardInput then
                popup:SetPropagateKeyboardInput(false)
            end
            popup:SetScript("OnKeyDown", finish)
            popup:SetScript("OnMouseDown", function(self, button)
                finish(self, button)
            end)
        end,
        onHide = function(popup)
            popup:SetScript("OnKeyDown", nil)
            popup:SetScript("OnMouseDown", nil)
            popup:EnableKeyboard(false)
            if popup.SetPropagateKeyboardInput then
                popup:SetPropagateKeyboardInput(true)
            end
        end
    })
end

local function writeSelectedMacro()
    local m, slot = mod(), selected()
    if not (m and slot) then
        return
    end
    local ok, err, extra = m:Write(slot)
    report(ok, err, extra, L["Macros_CreateMacroDone"])
end

local function fillTargetNameFromCurrentTarget()
    local m, slot = mod(), selected()
    if not (m and slot) then
        return
    end
    local name, err = m:GetCurrentTargetName("target")
    if not name then
        report(false, err)
        return
    end
    slot.targetName = name
    changed({
        sync = true
    })
end

statusText = function()
    local m, slot = mod(), selected()
    if not (m and slot) then
        return L["Macros_NoSlot"]
    end
    if m:IsMacroManagerBlocked() then
        return L["Macros_StatusMegaMacro"]
    end

    local text, err = m:BuildText(slot)
    local length = #tostring(text or "")
    local status = m:MacroExists(slot) and L["Macros_StatusExists"] or L["Macros_StatusMissing"]
    if err then
        status = L["Macros_StatusInvalid"]
    end

    return ("%s   %s: %d/%d"):format(status, L["Macros_Length"], length, m:GetTextLimit())
end

local function buildPanel()
    local m = mod()
    if not m then
        return {
            type = "group",
            name = L["Macros"],
            args = {
                notice = {
                    order = 1,
                    build = function(parent)
                        return T:Description(parent, {
                            text = L["LoadModule"],
                            sizeDelta = 1
                        })
                    end
                }
            }
        }
    end

    return {
        type = "group",
        name = L["Macros"],
        args = {
            pickHeader = {
                order = 10,
                type = "header",
                name = L["Macros_Library"]
            },
            selected = {
                order = 11,
                type = "select",
                width = "1/2",
                name = L["Macros_Selected"],
                buttonHeight = CONTROL_H,
                dropdownHeight = LABELLED_CONTROL_H,
                values = slotChoices,
                sorting = slotOrder,
                get = selectedID,
                set = function(_, value)
                    if value ~= NO_SLOT then
                        m:SelectSlot(value)
                    end
                end,
                disabled = disabled
            },
            duplicate = {
                order = 13,
                width = "1/4",
                build = function(parent)
                    return T:LabelAlignedButton(parent, {
                        text = L["Macros_Duplicate"],
                        buttonHeight = CONTROL_H,
                        totalHeight = LABELLED_CONTROL_H,
                        onClick = function()
                            local slot = selected()
                            if slot then
                                m:DuplicateSlot(slot.id)
                            end
                        end,
                        disabled = noSlot
                    })
                end
            },
            delete = {
                order = 14,
                width = "1/4",
                build = function(parent)
                    return T:LabelAlignedButton(parent, {
                        text = deleteActionText,
                        buttonHeight = CONTROL_H,
                        totalHeight = LABELLED_CONTROL_H,
                        confirm = deleteConfirmText,
                        onClick = function()
                            local slot = selected()
                            if slot then
                                local successText = deleteSuccessText()
                                local ok, err, extra = m:DeleteSlot(slot.id)
                                report(ok, err, extra, successText)
                            end
                        end,
                        disabled = function()
                            return noSlot() or selectedIsDefault()
                        end
                    })
                end
            },

            createHeader = {
                order = 20,
                type = "header",
                name = L["Macros_CreateNew"]
            },
            newType = {
                order = 21,
                type = "select",
                width = "1/2",
                name = L["Type"],
                buttonHeight = CONTROL_H,
                dropdownHeight = LABELLED_CONTROL_H,
                values = typeValues,
                sorting = TYPE_ORDER,
                get = function()
                    return ui.newType
                end,
                set = function(_, value)
                    ui.newType = value
                end,
                refresh = false,
                disabled = disabled
            },
            add = {
                order = 22,
                width = "1/2",
                build = function(parent)
                    return T:LabelAlignedButton(parent, {
                        text = createButtonText,
                        buttonHeight = CONTROL_H,
                        totalHeight = LABELLED_CONTROL_H,
                        emphasize = true,
                        onClick = function()
                            m:AddSlot(ui.newType)
                        end,
                        disabled = disabled
                    })
                end
            },

            editHeader = {
                order = 30,
                type = "header",
                name = L["Macros_WhatItDoes"]
            },
            status = {
                order = 31,
                build = function(parent)
                    local widget = T:StatusLine(parent, {
                        height = 22,
                        text = statusText
                    })
                    ui.statusWidget = widget
                    return widget
                end
            },
            draftName = {
                order = 32,
                type = "input",
                width = "1/3",
                name = L["Macros_DraftName"],
                desc = L["Macros_DraftNameDesc"],
                get = function()
                    local slot = selected()
                    return slot and slot.name or ""
                end,
                set = function(_, value)
                    local slot = selected()
                    if not slot then
                        return
                    end
                    if m:IsDefaultSlot(slot) then
                        return
                    end
                    slot.name = m:MakeUniqueDraftName(value, slot.id)
                    changed()
                end,
                validate = function(_, value)
                    if #trim(value) > m:GetDraftNameLimit() then
                        return false, L["Macros_ErrorDraftNameTooLong"]:format(m:GetDraftNameLimit())
                    end
                    return true
                end,
                disabled = function()
                    return noSlot() or selectedIsDefault()
                end
            },
            name = {
                order = 33,
                type = "input",
                width = "1/3",
                name = L["Macros_MacroName"],
                desc = L["Macros_MacroNameDesc"],
                get = function()
                    local slot = selected()
                    return slot and slot.macroName or ""
                end,
                set = function(_, value)
                    local slot = selected()
                    if not slot then
                        return
                    end
                    if m:IsDefaultSlot(slot) then
                        return
                    end
                    local previousName = slot.macroName
                    local previousDraftName = trim(slot.name)
                    slot.macroName = m:MakeUniqueMacroName(value, slot.id)
                    if previousDraftName == "" or previousDraftName == previousName then
                        slot.name = slot.macroName
                    end
                    changed({
                        sync = true,
                        previousName = previousName
                    })
                end,
                validate = function(_, value)
                    if #trim(value) > m:GetNameLimit() then
                        return false, L["Macros_ErrorNameTooLong"]:format(m:GetNameLimit())
                    end
                    return true
                end,
                disabled = function()
                    return noSlot() or selectedIsDefault()
                end
            },
            type = {
                order = 34,
                type = "select",
                width = "1/3",
                name = L["Type"],
                buttonHeight = CONTROL_H,
                dropdownHeight = LABELLED_CONTROL_H,
                values = typeValues,
                sorting = TYPE_ORDER,
                get = function()
                    local slot = selected()
                    return slot and slot.type or TYPE_SPELL
                end,
                set = function(_, value)
                    setField("type", value)
                end,
                disabled = noSlot
            },

            spell = {
                order = 40,
                type = "input",
                width = "1/3",
                name = L["Spell"],
                hidden = function()
                    local slot = selected()
                    return not (slot and slot.type == TYPE_SPELL)
                end,
                get = function()
                    local slot = selected()
                    return slot and slot.spell or ""
                end,
                set = function(_, value)
                    setFieldStatusOnly("spell", trim(value))
                end,
                refresh = false,
                disabled = noSlot
            },
            targetName = {
                order = 42,
                type = "input",
                width = "1/3",
                name = L["Macros_TargetName"],
                desc = L["Macros_TargetNameDesc"],
                hidden = function()
                    local slot = selected()
                    return not (slot and (slot.type == TYPE_SPELL or
                                   ((slot.type == TYPE_MARK or slot.type == TYPE_FOCUS or slot.type == TYPE_FOCUS_MARK) and
                                       slot.targetMode == TARGET_MODE_NAME)))
                end,
                get = function()
                    local slot = selected()
                    return slot and slot.targetName or ""
                end,
                set = function(_, value)
                    setFieldStatusOnly("targetName", m:NormalizeTargetName(value))
                end,
                refresh = false,
                disabled = noSlot
            },
            targetFromCurrent = {
                order = 43,
                width = "1/3",
                build = function(parent)
                    return T:LabelAlignedButton(parent, {
                        text = L["Macros_UseCurrentTarget"],
                        buttonHeight = CONTROL_H,
                        totalHeight = LABELLED_CONTROL_H,
                        tooltip = {
                            title = L["Macros_UseCurrentTarget"],
                            desc = L["Macros_UseCurrentTargetDesc"]
                        },
                        onClick = fillTargetNameFromCurrentTarget,
                        disabled = noSlot
                    })
                end,
                hidden = function()
                    local slot = selected()
                    return not (slot and slot.type == TYPE_SPELL)
                end
            },
            targetMode = {
                order = 41,
                type = "select",
                width = "1/2",
                name = L["Target"],
                buttonHeight = CONTROL_H,
                dropdownHeight = LABELLED_CONTROL_H,
                values = targetModeValues,
                sorting = TARGET_MODE_ORDER,
                hidden = function()
                    local slot = selected()
                    return not (slot and (slot.type == TYPE_MARK or slot.type == TYPE_FOCUS or slot.type == TYPE_FOCUS_MARK))
                end,
                get = function()
                    local slot = selected()
                    return slot and slot.targetMode or TARGET_MODE_TARGET
                end,
                set = function(_, value)
                    local slot = selected()
                    if not slot then
                        return
                    end
                    local needsLayout = slot.targetMode == TARGET_MODE_NAME or value == TARGET_MODE_NAME
                    slot.targetMode = value
                    changed({
                        sync = true,
                        refresh = needsLayout
                    })
                end,
                refresh = false,
                disabled = noSlot
            },
            marker = {
                order = 44,
                type = "select",
                width = "1/2",
                name = L["Macros_Marker"],
                buttonHeight = CONTROL_H,
                dropdownHeight = LABELLED_CONTROL_H,
                values = markerChoices,
                sorting = MARKER_ORDER,
                hidden = function()
                    local slot = selected()
                    return not (slot and (slot.type == TYPE_MARK or slot.type == TYPE_WORLD or slot.type == TYPE_FOCUS_MARK))
                end,
                get = function()
                    local slot = selected()
                    return slot and slot.marker or 1
                end,
                set = function(_, value)
                    setFieldQuiet("marker", tonumber(value) or 1, {
                        status = false
                    })
                end,
                refresh = false,
                disabled = noSlot
            },
            mouseover = {
                order = 45,
                type = "toggle",
                width = "1/4",
                name = L["Mouseover"],
                labelTop = true,
                hidden = function()
                    local slot = selected()
                    return not (slot and slot.type == TYPE_SPELL)
                end,
                get = function()
                    local slot = selected()
                    return slot and slot.useMouseover
                end,
                set = function(_, value)
                    setFieldStatusOnly("useMouseover", value)
                end,
                refresh = false,
                disabled = noSlot
            },
            trinket1 = {
                order = 46,
                type = "toggle",
                width = "1/4",
                name = L["Macros_Trinket1"],
                labelTop = true,
                hidden = function()
                    local slot = selected()
                    return not (slot and slot.type == TYPE_SPELL)
                end,
                get = function()
                    local slot = selected()
                    return slot and slot.useTrinket1
                end,
                set = function(_, value)
                    setFieldStatusOnly("useTrinket1", value)
                end,
                refresh = false,
                disabled = noSlot
            },
            trinket2 = {
                order = 47,
                type = "toggle",
                width = "1/4",
                name = L["Macros_Trinket2"],
                labelTop = true,
                hidden = function()
                    local slot = selected()
                    return not (slot and slot.type == TYPE_SPELL)
                end,
                get = function()
                    local slot = selected()
                    return slot and slot.useTrinket2
                end,
                set = function(_, value)
                    setFieldStatusOnly("useTrinket2", value)
                end,
                refresh = false,
                disabled = noSlot
            },
            cursor = {
                order = 48,
                type = "toggle",
                width = "1/4",
                name = L["Macros_UseCursor"],
                labelTop = true,
                hidden = function()
                    local slot = selected()
                    return not (slot and slot.type == TYPE_WORLD)
                end,
                get = function()
                    local slot = selected()
                    return slot and slot.useCursor
                end,
                set = function(_, value)
                    setFieldStatusOnly("useCursor", value)
                end,
                refresh = false,
                disabled = noSlot
            },
            clearFirst = {
                order = 49,
                type = "toggle",
                width = "1/4",
                name = L["Macros_ClearFirst"],
                labelTop = true,
                hidden = function()
                    local slot = selected()
                    return not (slot and slot.type == TYPE_WORLD)
                end,
                get = function()
                    local slot = selected()
                    return slot and slot.clearFirst
                end,
                set = function(_, value)
                    setFieldStatusOnly("clearFirst", value)
                end,
                refresh = false,
                disabled = noSlot
            },
            customLines = {
                order = 50,
                build = buildCustomLines,
                hidden = function()
                    local slot = selected()
                    return not (slot and slot.type ~= TYPE_CUSTOM)
                end,
                disabled = noSlot
            },
            body = {
                order = 51,
                type = "execute",
                width = "1/2",
                name = L["Macros_EditBody"],
                refresh = false,
                hidden = function()
                    local slot = selected()
                    return not (slot and slot.type == TYPE_CUSTOM)
                end,
                func = function()
                    editLines("body")
                end,
                disabled = noSlot
            },

            writeMacro = {
                order = 61,
                type = "execute",
                width = "1/2",
                refresh = false,
                name = L["Macros_CreateMacro"],
                desc = L["Macros_WriteMacroDesc"],
                func = writeSelectedMacro,
                disabled = function()
                    return noSlot() or selectedMacroExists()
                end
            },
            bind = {
                order = 62,
                type = "execute",
                width = "1/2",
                refresh = false,
                name = function()
                    local slot = selected()
                    return L["Macros_SetKeybind"]:format(slot and m:BindingText(slot) or L["Macros_Unbound"])
                end,
                func = startBindingCapture,
                disabled = noSlot
            }
        }
    }
end

E:RegisterOptions("Macros", 33, buildPanel)
