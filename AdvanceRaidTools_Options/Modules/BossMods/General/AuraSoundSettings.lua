local E, L = unpack(ART)
local T = E.Templates

local function build(parent, mod, isDisabled)
    local width = parent:GetWidth() or 0
    if width <= 0 then return {} end
    local tracker = T:MakeTracker()
    local track, y, rebuild = tracker.track, 0, false
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
            full(track(T:Header(parent, {text = L["BossMods_AuraSoundAction"] .. " " .. index})))
            full(track(T:Dropdown(parent, {
                label = L["BossMods_AuraSoundWhen"],
                values = {show = L["BossMods_AuraApplied"], hide = L["BossMods_AuraRemoved"], stackGained = L["BossMods_AuraStackGained"]},
                sorting = {"show", "hide", "stackGained"},
                get = function() return action.condition or "show" end,
                onChange = function(value) action.condition = value; changed() end, disabled = disabled
            })))
            full(track(T:Dropdown(parent, {
                label = L["Sound"], values = function() return E:MediaList("sound") end,
                get = function() return action.sound or "None" end,
                onChange = function(value) action.sound = value; changed() end, disabled = disabled
            })))
            full(track(T:EditBox(parent, {
                label = L["BossMods_AuraSoundTargets"], default = action.unit or "player",
                onCommit = function(value) action.unit = value ~= "" and value or "player"; changed() end,
                disabled = disabled
            })))
            full(track(T:Dropdown(parent, {
                label = L["BossMods_AuraSoundChannel"],
                values = {Master = "Master", SFX = "SFX", Music = "Music", Ambience = "Ambience", Dialog = "Dialog"},
                get = function() return action.outputChannel or "Master" end,
                onChange = function(value) action.outputChannel = value; changed() end, disabled = disabled
            })))
            full(track(T:Slider(parent, {
                label = L["BossMods_AuraSoundRepeat"], min = 1, max = 10, step = 1,
                value = action.repeatCount or 1, get = function() return action.repeatCount or 1 end,
                onChange = function(value) action.repeatCount = value; changed() end, disabled = disabled
            })))
            local preview = track(T:Button(parent, {text = L["Preview"], onClick = function() mod:Preview(action) end, disabled = disabled}))
            local remove = track(T:Button(parent, {text = L["Remove"], onClick = function() table.remove(settings.actions, index); changed(true) end, disabled = disabled}))
            y = y + T:PlaceRow(parent, {preview, remove}, y, width) + 6
        end
        full(track(T:Button(parent, {
            text = L["BossMods_AddAuraSound"], onClick = function()
                settings.actions[#settings.actions + 1] = {sound = "None", condition = "show", unit = "player", outputChannel = "Master", repeatCount = 1}
                changed(true)
            end, disabled = disabled
        })))
    end
    parent:SetHeight(y + 10)
    return {
        height = y + 10,
        Refresh = function() tracker.refresh(); if rebuild then rebuild = false; return true end end,
        Release = function() mod:StopPreview(); tracker.release() end
    }
end

E:GetModule("BossMods"):RegisterBossSettingsBuilder("AuraSounds", build)
