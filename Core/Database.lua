local E = unpack(ART)

local function normalizeDebugShape(profile)
    local g = profile and profile.general
    if not g then
        return
    end
    if type(g.debug) ~= "table" then
        local prior = g.debug and true or false
        g.debug = {
            enabled = prior,
            channels = {}
        }
    else
        g.debug.channels = g.debug.channels or {}
        g.debug.enabled = g.debug.enabled and true or false
    end
end

function E:InitializeDatabase(defaultsProfile, defaultsGlobal)
    local defaults = {
        profile = defaultsProfile or {},
        global = defaultsGlobal or {},
        char = {
            specProfiles = {},
            specProfilesEnabled = false,
            specOverrides = {}
        }
    }

    self.db = E.Libs.AceDB:New("AdvanceRaidToolsDB", defaults, true)
    normalizeDebugShape(self.db.profile)

    local stored = self.db.global.version
    local current = self.version
    if stored ~= current then
        self:RunMigrations(stored, current)
        self.db.global.version = current
    end

    self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")
end

E.migrations = {}

function E:RegisterMigration(fromVersion, fn)
    table.insert(self.migrations, {
        from = fromVersion,
        fn = fn
    })
end

function E:RunMigrations(stored, current)
    if not stored then
        return
    end
    for _, entry in ipairs(self.migrations) do
        if entry.from == stored then
            local ok, err = pcall(entry.fn, self)
            if not ok then
                -- /art debug log warn
                self:Warn("Migration failed (%s -> %s): %s", stored, current, err)
            end
        end
    end
end

function E:OnProfileChanged()
    normalizeDebugShape(self.db.profile)

    -- Two-pass: rebind every module's db first, then evaluate the parent gate
    -- for each (the gate reads sibling/parent DBs, so all dbs must be live).
    for _, mod in self:IterateModules() do
        mod.db = E:GetDB(mod.moduleName)
    end

    for _, mod in self:IterateModules() do
        E:_reapplyModuleEnable(mod)
    end

    self:SendMessage("ART_PROFILE_CHANGED")
end
