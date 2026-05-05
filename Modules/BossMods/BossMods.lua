local E, L = unpack(ART)

E:RegisterModuleDefaults("BossMods", {
    enabled = true,
    activeTab = "Misc"
})

local BossMods = E:NewModule("BossMods", "AceEvent-3.0")

local features = E:CreateFeatureRegistry()
local raidTabs = E:CreateFeatureRegistry()
BossMods.features = features
BossMods.raidTabs = raidTabs

-- Sort features by their tab's order first, then their own order
features:SetSortKey(function(fa, fb)
    if fa.tab ~= fb.tab then
        local ta, tb = raidTabs:Get(fa.tab), raidTabs:Get(fb.tab)
        local ao = ta and ta.order or 1000
        local bo = tb and tb.order or 1000
        if ao ~= bo then
            return ao < bo
        end
        return (fa.tab or "") < (fb.tab or "")
    end
    if fa.order == fb.order then
        return fa.key < fb.key
    end
    return fa.order < fb.order
end)

-- Per-feature settings builder registry
-- [key] = function(mod, isDisabled) -> argsTable
BossMods.settingsBuilders = {}

function BossMods:RegisterRaidTab(key, opts)
    opts = opts or {}
    raidTabs:Register(key, {
        labelKey = opts.labelKey or key,
        order = opts.order or 1000
    })
    features:Resort()
    E:SendMessage("ART_BOSSMODS_TABS_CHANGED")
end

function BossMods:RegisterFeature(key, opts)
    assert(type(opts) == "table", "RegisterFeature: opts required")
    assert(type(opts.moduleName) == "string" and opts.moduleName ~= "", "RegisterFeature: opts.moduleName required")
    local tab = opts.tab or "Misc"

    -- Auto-register unknown tabs so a new boss file doesn't drop
    if not raidTabs:Has(tab) then
        self:Warn("feature '%s' references unknown tab '%s'; auto-registering", key, tab)
        self:RegisterRaidTab(tab, {
            labelKey = tab,
            order = 1000
        })
    end

    features:Register(key, {
        order = opts.order or 100,
        tab = tab,
        labelKey = opts.labelKey or key,
        descKey = opts.descKey,
        moduleName = opts.moduleName
    })

    E:SetModuleParent(opts.moduleName, self.moduleName)
    E:SendMessage("ART_BOSSMODS_FEATURES_CHANGED")
end

function BossMods:RegisterBossSettingsBuilder(key, fn)
    assert(type(key) == "string" and key ~= "", "RegisterBossSettingsBuilder: key required")
    assert(type(fn) == "function", "RegisterBossSettingsBuilder: fn required")
    self.settingsBuilders[key] = fn

    if E.OptionsUI and E.OptionsUI.mainFrame and E.RebuildOptions then
        E:RebuildOptions()
    end
end

function BossMods:GetSettingsBuilder(key)
    return self.settingsBuilders[key]
end

function BossMods:GetTabs()
    return raidTabs:All()
end

function BossMods:GetFeaturesForTab(tab)
    return features:Filter(function(f)
        return f.tab == tab
    end)
end

function BossMods:GetFeature(key)
    return features:Get(key)
end

function BossMods:GetFeatureModule(key)
    local f = features:Get(key)
    if not f then
        return nil
    end
    return E:GetModule(f.moduleName, true)
end

E:MountMethods(E, {
    GetBossMods = function()
        return BossMods
    end
}, {
    noClobber = true
})

-- New raids can append here or call BossMods:RegisterRaidTab
BossMods:RegisterRaidTab("Misc", {
    labelKey = "BossMods_Misc",
    order = 10
})
BossMods:RegisterRaidTab("Queldanas", {
    labelKey = "BossMods_Queldanas",
    order = 20
})
BossMods:RegisterRaidTab("Voidspire", {
    labelKey = "BossMods_Voidspire",
    order = 30
})

E:FlushModuleFeatureRegistrations("BossMods")
