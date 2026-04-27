local E, L, P = unpack(ART)

local aceNewModule = E.NewModule

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

local function runModuleInit(mod)
    local name = mod.moduleName
    mod.db = E:GetDB(name)

    mod:SetEnabledState(E:_effectiveModuleEnabled(mod))

    mod.L = L
    if mod.OnModuleInitialize then
        local ok, err = pcall(mod.OnModuleInitialize, mod, mod.db)
        if not ok then
            E:ChannelWarn(name, "init failed: %s", err)
        end
    end
end

function E:NewModule(name, ...)
    assert(type(name) == "string", "NewModule: name must be a string")
    assert(not self:GetModule(name, true), ("Module '%s' already registered"):format(name))

    local mod = aceNewModule(self, name, ...)
    mod.moduleName = name

    -- sanity check for default entry for this module if the declaring module didn't add one
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
