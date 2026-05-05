local E, L = unpack(ART)

E:RegisterModuleDefaults("QualityOfLife", {
    enabled = true
})

local QoL = E:NewModule("QualityOfLife", "AceEvent-3.0")

local features = E:CreateFeatureRegistry()
QoL.features = features

function QoL:RegisterFeature(key, opts)
    assert(type(opts) == "table", "RegisterFeature: opts required")
    assert(type(opts.moduleName) == "string" and opts.moduleName ~= "", "RegisterFeature: opts.moduleName required")

    features:Register(key, {
        order = opts.order or 100,
        labelKey = opts.labelKey or key,
        descKey = opts.descKey,
        moduleName = opts.moduleName
    })

    E:SetModuleParent(opts.moduleName, self.moduleName)
    E:SendMessage("ART_QOL_FEATURES_CHANGED")
end

function QoL:GetFeatures()
    return features:All()
end

function QoL:GetFeature(key)
    return features:Get(key)
end

function QoL:GetFeatureModule(key)
    local f = features:Get(key)
    if not f then
        return nil
    end
    return E:GetModule(f.moduleName, true)
end

_G.ART = _G.ART or {}
E:MountMethods(_G.ART, {
    GetQoLFeatures = function()
        return QoL:GetFeatures()
    end
}, {
    noClobber = true
})

E:FlushModuleFeatureRegistrations("QualityOfLife")
