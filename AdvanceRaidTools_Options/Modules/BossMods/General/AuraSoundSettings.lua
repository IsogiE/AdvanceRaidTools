local E, L = unpack(ART)
local T = E.Templates
local collapsedActions = setmetatable({}, {__mode = "k"})

local function build(parent, mod, isDisabled, requestLayout)
    local width = parent:GetWidth() or 0
    if width <= 0 then return {} end
    local tracker = T:MakeTracker()
    local track, y, rebuild = tracker.track, 0, false
    local sections, ui = {}, {}
    local relayout, addButton, previewAction
    local function full(widget) y = y + T:PlaceFull(parent, widget, y, width) + 6 end
    local function disabled()
        return (type(isDisabled) == "function" and isDisabled() or isDisabled == true) or InCombatLockdown()
    end
    local function changed(structural)
        mod:CallIfEnabled("Refresh")
        rebuild = rebuild or structural
        tracker.refresh()
        if E.OptionsUI and E.OptionsUI.QueueRefresh then E.OptionsUI:QueueRefresh("current") end
    end
    local categories, categoryValues, categoryOrder = mod:GetCategories(), {}, {}
    local selectedCategory
    for _, category in ipairs(categories) do
        categoryValues[category.key] = category.name
        categoryOrder[#categoryOrder + 1] = category.key
        if category.key == mod.selectedCategory then selectedCategory = category end
    end
    selectedCategory = selectedCategory or categories[1]
    mod.selectedCategory = selectedCategory.key
    full(track(T:Header(parent, {text = L["BossMods_AuraSounds"]})))
    full(track(T:Description(parent, {text = L["BossMods_AuraSoundsDesc"]})))
    full(track(T:Dropdown(parent, {
        label = L["Category"], values = categoryValues, sorting = categoryOrder,
        get = function() return mod.selectedCategory end,
        onChange = function(value) mod.selectedCategory = value; mod.selectedAura = nil; changed(true) end,
        disabled = disabled
    })))
    local auraValues, auraOrder, aura = {}, {}, nil
    for _, entry in ipairs(selectedCategory.auras) do
        local key = mod:GetAuraKey(selectedCategory, entry)
        auraValues[key] = mod:GetAuraName(entry)
        auraOrder[#auraOrder + 1] = key
        if key == mod.selectedAura then aura = entry end
    end
    aura = aura or selectedCategory.auras[1]
    mod.selectedAura = aura and mod:GetAuraKey(selectedCategory, aura) or nil
    full(track(T:Dropdown(parent, {
        label = L["BossMods_Aura"], values = auraValues, sorting = auraOrder,
        get = function() return mod.selectedAura end,
        onChange = function(value) mod.selectedAura = value; changed(true) end,
        disabled = disabled
    })))
    if selectedCategory.key == "custom" then
        full(track(T:EditBox(parent, {
            label = L["BossMods_AddAuraSpellID"], numeric = true,
            onCommit = function(value)
                local added = mod:AddCustomAura(value)
                if added then mod.selectedAura = mod:GetAuraKey(selectedCategory, added); changed(true) end
            end,
            disabled = disabled
        })))
    end
    if aura then
        local settings = mod:GetSettings(selectedCategory, aura)
        full(track(T:Checkbox(parent, {
            text = L["Enable"], get = function() return settings.enabled end,
            onChange = function(_, value) settings.enabled = value; changed() end, disabled = disabled
        })))
        if aura.description and aura.description ~= "" then
            full(track(T:Description(parent, {text = aura.description})))
        end
        for index, action in ipairs(settings.actions) do
            if collapsedActions[action] == nil then collapsedActions[action] = index > 1 end
            local section = {action = action, rows = {}}
            sections[#sections + 1] = section
            section.header = track(T:Header(parent, {
                text = L["BossMods_AuraSoundAction"] .. " " .. index,
                collapsed = function() return collapsedActions[action] end,
                onToggle = function(value)
                    collapsedActions[action] = value
                    if value and previewAction == action then mod:StopPreview(); previewAction = nil end
                    relayout()
                    tracker.refresh()
                end
            }))
            local function row(...)
                section.rows[#section.rows + 1] = {...}
            end
            row(track(T:Dropdown(parent, {
                label = L["BossMods_AuraSoundWhen"],
                values = {show = L["BossMods_AuraApplied"], hide = L["BossMods_AuraRemoved"], stackGained = L["BossMods_AuraStackGained"]},
                sorting = {"show", "hide", "stackGained"},
                get = function() return action.condition or "show" end,
                onChange = function(value) action.condition = value; changed() end, disabled = disabled
            })))
            row(track(T:Dropdown(parent, {
                label = L["Sound"], values = function() return E:MediaList("sound") end,
                get = function() return action.sound or "None" end,
                onChange = function(value) action.sound = value; changed() end, disabled = disabled
            })))
            row(track(T:EditBox(parent, {
                label = L["BossMods_AuraSoundTargets"], default = action.unit or "player",
                onCommit = function(value) action.unit = value ~= "" and value or "player"; changed() end,
                disabled = disabled
            })))
            row(track(T:Dropdown(parent, {
                label = L["BossMods_AuraSoundChannel"],
                values = {Master = "Master", SFX = "SFX", Music = "Music", Ambience = "Ambience", Dialog = "Dialog"},
                get = function() return action.outputChannel or "Master" end,
                onChange = function(value) action.outputChannel = value; changed() end, disabled = disabled
            })))
            row(track(T:Slider(parent, {
                label = L["BossMods_AuraSoundRepeat"], min = 1, max = 10, step = 1,
                tooltip = L["BossMods_AuraSoundRepeatDesc"],
                value = action.repeatCount or 1, get = function() return action.repeatCount or 1 end,
                onChange = function(value) action.repeatCount = value; changed() end, disabled = disabled
            })))
            local preview = track(T:Button(parent, {
                text = L["Preview"], onClick = function() previewAction = action; mod:Preview(action) end, disabled = disabled
            }))
            local remove = track(T:Button(parent, {text = L["Remove"], onClick = function() table.remove(settings.actions, index); changed(true) end, disabled = disabled}))
            row(preview, remove)
        end
        addButton = track(T:Button(parent, {
            text = L["BossMods_AddAuraSound"], onClick = function()
                local action = {sound = "None", condition = "show", unit = "player", outputChannel = "Master", repeatCount = 1}
                settings.actions[#settings.actions + 1] = action
                collapsedActions[action] = false
                changed(true)
            end, disabled = disabled
        }))
    end
    local topHeight = y
    relayout = function()
        y = topHeight
        for _, section in ipairs(sections) do
            full(section.header)
            local shown = not collapsedActions[section.action]
            for _, widgets in ipairs(section.rows) do
                for _, widget in ipairs(widgets) do widget.frame:SetShown(shown) end
                if shown then
                    if #widgets == 1 then full(widgets[1])
                    else y = y + T:PlaceRow(parent, widgets, y, width) + 6 end
                end
            end
        end
        if addButton then full(addButton) end
        ui.height = y + 10
        parent:SetHeight(ui.height)
        if requestLayout then requestLayout() end
    end
    ui.Refresh = function() tracker.refresh(); if rebuild then rebuild = false; return true end end
    ui.Release = function() mod:StopPreview(); tracker.release() end
    relayout()
    return ui
end

E:GetModule("BossMods"):RegisterBossSettingsBuilder("AuraSounds", build)
