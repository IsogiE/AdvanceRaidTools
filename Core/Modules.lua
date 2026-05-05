local E, L, P = unpack(ART)

local aceNewModule = E.NewModule
local registeredModuleDefaults = {}

local function hasModuleDefaults(name)
    return registeredModuleDefaults[name] or type(P.modules[name]) == "table"
end

function E:RegisterModuleDefaults(name, defaults)
    assert(type(name) == "string" and name ~= "", "RegisterModuleDefaults: name required")
    assert(type(defaults) == "table", "RegisterModuleDefaults: defaults required")
    assert(not self:GetModule(name, true), ("RegisterModuleDefaults: '%s' already registered as a module"):format(name))

    P.modules[name] = defaults
    registeredModuleDefaults[name] = true
    return defaults
end

function E:HasModuleDefaults(name)
    return registeredModuleDefaults[name] and true or false
end

E:RegisterDebugChannel("ModuleDefaults")
E:RegisterDebugChannel("ModuleLifecycle")

function E:_effectiveModuleEnabled(mod)
    local own = mod.db and mod.db.enabled ~= false
    if not own then
        return false
    end
    local parentName = mod._parentModule
    if not parentName then
        return true
    end
    self.db.profile.modules = self.db.profile.modules or {}
    local parentDb = self.db.profile.modules[parentName]
    if not parentDb then
        return true -- parent default is enabled
    end
    return parentDb.enabled ~= false
end

function E:_reapplyModuleEnable(mod)
    if self:_effectiveModuleEnabled(mod) then
        mod:Enable()
    else
        mod:Disable()
    end
end

function E:SetModuleParent(childName, parentName)
    local mod = self:GetModule(childName, true)
    if not mod then
        return
    end
    mod._parentModule = parentName
    if mod.db then
        self:_reapplyModuleEnable(mod)
    end
end

local runModuleInit

local function wrapAceModuleInitialize(mod, init)
    if mod._artWrappedOnInitialize or type(init) ~= "function" then
        return
    end
    mod._artWrappedOnInitialize = true
    mod._artOnInitialize = init
    mod.OnInitialize = function(self)
        if self._artInitialized then
            return
        end
        return runModuleInit(self)
    end
end

local function callModuleInitialize(mod, fn)
    local name = mod.moduleName
    mod._artInitialized = true
    local ok, err = pcall(fn, mod, mod.db)
    if not ok then
        E:ChannelWarn(name, "init failed: %s", err)
    end
end

runModuleInit = function(mod)
    local name = mod.moduleName
    mod.db = E:GetDB(name)

    mod:SetEnabledState(E:_effectiveModuleEnabled(mod))

    mod.L = L

    if mod._artInitialized then
        return
    end

    local init = rawget(mod, "OnInitialize")
    if type(init) == "function" then
        wrapAceModuleInitialize(mod, init)
        callModuleInitialize(mod, init)
        return
    end

    local legacyInit = rawget(mod, "OnModuleInitialize")
    if type(legacyInit) == "function" then
        E:ChannelWarn("ModuleLifecycle", "module '%s' uses deprecated OnModuleInitialize; use OnInitialize(db)", name)
        callModuleInitialize(mod, legacyInit)
    end
end

function E:NewModule(name, ...)
    assert(type(name) == "string", "NewModule: name must be a string")
    assert(not self:GetModule(name, true), ("Module '%s' already registered"):format(name))

    local mod = aceNewModule(self, name, ...)
    mod.moduleName = name

    if not hasModuleDefaults(name) then
        E:ChannelWarn("ModuleDefaults", "module '%s' did not register defaults before NewModule", name)
    end

    P.modules[name] = P.modules[name] or {
        enabled = true
    }

    -- Every module gets its own debug channel
    E:RegisterDebugChannel(name)

    mod.Debug = function(self, fmt, ...)
        return E:ChannelDebug(self.moduleName, fmt, ...)
    end
    mod.Warn = function(self, fmt, ...)
        return E:ChannelWarn(self.moduleName, fmt, ...)
    end

    local userOnEnable = mod.OnEnable
    local userOnDisable = mod.OnDisable

    mod._cleanups = {}

    mod.RegisterCleanup = function(self, fn)
        if type(fn) == "function" then
            self._cleanups = self._cleanups or {}
            table.insert(self._cleanups, fn)
        end
    end

    mod.CallIfEnabled = function(self, methodName, ...)
        if not self:IsEnabled() then
            return nil
        end
        local fn = self[methodName]
        if type(fn) ~= "function" then
            return nil
        end
        return fn(self, ...)
    end

    mod.OnEnable = function(self, ...)
        self.db = E:GetDB(name)
        self.L = L
        if userOnEnable then
            local ok, err = pcall(userOnEnable, self, ...)
            if not ok then
                E:ChannelWarn(name, "enable failed: %s", err)
            end
        end
        E:SendMessage("ART_MODULE_ENABLED", name)
    end

    mod.OnDisable = function(self, ...)
        if userOnDisable then
            local ok, err = pcall(userOnDisable, self, ...)
            if not ok then
                E:ChannelWarn(name, "disable failed: %s", err)
            end
        end
        if self._cleanups then
            for i = #self._cleanups, 1, -1 do
                local fn = self._cleanups[i]
                local ok, err = pcall(fn, self)
                if not ok then
                    E:ChannelWarn(name, "cleanup failed: %s", err)
                end
            end
        end
        E:SendMessage("ART_MODULE_DISABLED", name)
    end

    if E.db then
        runModuleInit(mod)
    end

    return mod
end

function E:InitializeAllModules()
    for _, mod in self:IterateModules() do
        if not mod.db then
            runModuleInit(mod)
        end
    end
end

local pendingModuleFeatures = {}

local function shallowCopy(src)
    local out = {}
    for k, v in pairs(src) do
        out[k] = v
    end
    return out
end

local function getFeatureBucket(parentName)
    local bucket = pendingModuleFeatures[parentName]
    if not bucket then
        bucket = {
            order = {},
            entries = {}
        }
        pendingModuleFeatures[parentName] = bucket
    end
    return bucket
end

local function queueModuleFeature(parentName, key, opts)
    local bucket = getFeatureBucket(parentName)
    if not bucket.entries[key] then
        bucket.order[#bucket.order + 1] = key
    end
    bucket.entries[key] = {
        opts = shallowCopy(opts),
        warned = false
    }
end

function E:RegisterModuleFeature(parentName, key, opts)
    assert(type(parentName) == "string" and parentName ~= "", "RegisterModuleFeature: parentName required")
    assert(type(key) == "string" and key ~= "", "RegisterModuleFeature: key required")
    assert(type(opts) == "table", "RegisterModuleFeature: opts required")

    local parent = self:GetModule(parentName, true)
    if parent and type(parent.RegisterFeature) == "function" then
        parent:RegisterFeature(key, opts)
        return true
    end

    queueModuleFeature(parentName, key, opts)
    return false
end

function E:FlushModuleFeatureRegistrations(parentName)
    local bucket = pendingModuleFeatures[parentName]
    if not bucket then
        return true
    end

    local parent = self:GetModule(parentName, true)
    if not parent or type(parent.RegisterFeature) ~= "function" then
        return false
    end

    for _, key in ipairs(bucket.order) do
        local entry = bucket.entries[key]
        if entry then
            parent:RegisterFeature(key, entry.opts)
        end
    end

    pendingModuleFeatures[parentName] = nil
    return true
end

function E:FlushAllModuleFeatureRegistrations()
    local parents = {}
    for parentName in pairs(pendingModuleFeatures) do
        parents[#parents + 1] = parentName
    end
    for _, parentName in ipairs(parents) do
        self:FlushModuleFeatureRegistrations(parentName)
    end
end

function E:WarnUnresolvedModuleFeatureRegistrations()
    for parentName, bucket in pairs(pendingModuleFeatures) do
        for _, key in ipairs(bucket.order) do
            local entry = bucket.entries[key]
            if entry and not entry.warned then
                self:ChannelWarn("FeatureRegistry", "feature '%s' is still waiting for parent module '%s'", key,
                    parentName)
                entry.warned = true
            end
        end
    end
end

function E:RegisterBossModFeature(key, opts)
    return self:RegisterModuleFeature("BossMods", key, opts)
end

function E:RegisterQoLFeature(key, opts)
    return self:RegisterModuleFeature("QualityOfLife", key, opts)
end

local pendingBossModNoteBlocks = {
    order = {},
    entries = {}
}

function E:RegisterBossModNoteBlock(key, opts)
    assert(type(key) == "string" and key ~= "", "RegisterBossModNoteBlock: key required")
    assert(type(opts) == "table", "RegisterBossModNoteBlock: opts required")

    local BossMods = self:GetModule("BossMods", true)
    local NoteBlock = BossMods and BossMods.NoteBlock
    if NoteBlock and type(NoteBlock.RegisterNoteBlock) == "function" then
        NoteBlock:RegisterNoteBlock(key, opts)
        return true
    end

    if not pendingBossModNoteBlocks.entries[key] then
        pendingBossModNoteBlocks.order[#pendingBossModNoteBlocks.order + 1] = key
    end
    pendingBossModNoteBlocks.entries[key] = {
        opts = shallowCopy(opts),
        warned = false
    }
    return false
end

function E:FlushBossModNoteBlockRegistrations()
    local BossMods = self:GetModule("BossMods", true)
    local NoteBlock = BossMods and BossMods.NoteBlock
    if not NoteBlock or type(NoteBlock.RegisterNoteBlock) ~= "function" then
        return false
    end

    for _, key in ipairs(pendingBossModNoteBlocks.order) do
        local entry = pendingBossModNoteBlocks.entries[key]
        if entry then
            NoteBlock:RegisterNoteBlock(key, entry.opts)
        end
    end

    wipe(pendingBossModNoteBlocks.order)
    wipe(pendingBossModNoteBlocks.entries)
    return true
end

function E:WarnUnresolvedBossModNoteBlockRegistrations()
    for _, key in ipairs(pendingBossModNoteBlocks.order) do
        local entry = pendingBossModNoteBlocks.entries[key]
        if entry and not entry.warned then
            self:ChannelWarn("FeatureRegistry", "note block '%s' is still waiting for BossMods.NoteBlock", key)
            entry.warned = true
        end
    end
end

function E:CreateFeatureRegistry()
    local entries = {}
    local order = {}
    local registry = {}

    local function defaultCmp(a, b)
        local ea, eb = entries[a], entries[b]
        if (ea.order or 100) == (eb.order or 100) then
            return a < b
        end
        return (ea.order or 100) < (eb.order or 100)
    end

    local function resort()
        table.sort(order, registry._cmp or defaultCmp)
    end

    function registry:Register(key, info)
        assert(type(key) == "string" and key ~= "", "FeatureRegistry:Register: key required")
        assert(type(info) == "table", "FeatureRegistry:Register: info required")
        local entry = {}
        for k, v in pairs(info) do
            entry[k] = v
        end
        entry.key = key
        entry.order = entry.order or 100
        if entries[key] then
            entries[key] = entry
        else
            entries[key] = entry
            order[#order + 1] = key
        end
        resort()
        return entry
    end

    function registry:Get(key)
        return entries[key]
    end

    function registry:Has(key)
        return entries[key] ~= nil
    end

    function registry:All()
        local out = {}
        for _, k in ipairs(order) do
            out[#out + 1] = entries[k]
        end
        return out
    end

    function registry:Filter(predicate)
        local out = {}
        for _, k in ipairs(order) do
            local e = entries[k]
            if predicate(e) then
                out[#out + 1] = e
            end
        end
        return out
    end

    function registry:SetSortKey(fn)
        if type(fn) == "function" then
            self._cmp = function(a, b)
                return fn(entries[a], entries[b])
            end
        else
            self._cmp = nil
        end
        resort()
    end

    function registry:Resort()
        resort()
    end

    return registry
end
