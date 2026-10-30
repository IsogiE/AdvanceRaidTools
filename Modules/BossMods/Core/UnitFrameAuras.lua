local E, L = unpack(ART)
local CreateFrame, C_Timer, hooksecurefunc = E:DiagnosticBindings("Modules/BossMods/Core/UnitFrameAuras")
local BossMods = E:GetModule("BossMods")
local Engines = BossMods.Engines
BossMods.unitFrameAuraFeatures = {}

local function clamp(value, minimum, maximum, fallback)
    value = tonumber(value)
    if not value or value ~= value then value = fallback end
    return math.floor(math.max(minimum, math.min(maximum, value)) + 0.5)
end

local function getRole()
    local role = E:GetPlayerRole()
    return role == "DAMAGER" and "DPS" or role
end

function BossMods:RegisterUnitFrameAuraFeature(definition)
    assert(type(definition.encounterID) == "number", "Unit-frame auras need an encounter ID")
    local defaults = {enabled = true, displays = {}}
    for _, display in ipairs(definition.displays) do
        assert(display.key and display.stages and display.aura and display.aura.filters,
            "Unit-frame auras need a key, stages and filters")
        assert(not defaults.displays[display.key], "Duplicate unit-frame aura key")
        defaults.displays[display.key] = {
            enabled = display.defaultEnabled == true, allRoles = false,
            size = 26, x = 0, y = 0, showCooldown = true, showCountdown = false
        }
    end
    E:RegisterModuleDefaults(definition.moduleName, defaults)
    local mod = E:NewModule(definition.moduleName, "AceEvent-3.0")
    mod.definition = definition
    local refreshKey = definition.moduleName .. ":Refresh"

    function mod:GetDisplaySettings(display)
        self.db.displays = type(self.db.displays) == "table" and self.db.displays or {}
        local settings = self.db.displays[display.key]
        if type(settings) ~= "table" then settings = {}; self.db.displays[display.key] = settings end
        if settings.enabled == nil then settings.enabled = display.defaultEnabled == true end
        settings.size = clamp(settings.size, 16, 64, 26)
        settings.x = clamp(settings.x, -100, 100, 0)
        settings.y = clamp(settings.y, -100, 100, 0)
        settings.showCooldown = settings.showCooldown ~= false
        settings.showCountdown = settings.showCountdown == true
        return settings
    end

    function mod:UpdateDisplays()
        for _, display in ipairs(definition.displays) do
            local settings = self:GetDisplaySettings(display)
            local allowedRole = settings.allRoles == true or not display.roles or display.roles[self.role] == true
            local active = self:IsEnabled() and self.encounterActive == true
                and settings.enabled == true and allowedRole
                and display.stages[self.stage] == true and not self.hiddenByChannel[display.key]
            local engine = self.displays[display.key]
            if engine then engine:SetShown(active) end
        end
    end

    function mod:Refresh()
        if not self:IsEnabled() then return end
        if not Engines.CanConfigureUnitFrameAuras() then
            self:UpdateDisplays()
            return
        end
        self.role = getRole()
        local units, frames = {}, {}
        if IsInRaid() then
            for index = 1, GetNumGroupMembers() do units[#units + 1] = "raid" .. index end
        else
            units[1] = "player"
            for index = 1, GetNumSubgroupMembers() do units[#units + 1] = "party" .. index end
        end
        for _, unit in ipairs(units) do frames[unit] = E:GetGroupUnitFrame(unit) end
        for _, display in ipairs(definition.displays) do
            local engine = self.displays[display.key]
            if not engine then
                engine = Engines.UnitFrameAura({
                    definition = display,
                    getSettings = function() return self:GetDisplaySettings(display) end
                })
                self.displays[display.key] = engine
            end
            engine:Prepare(units, frames)
        end
        self:UpdateDisplays()
    end

    function mod:ScheduleRefresh()
        if self.refreshTimer then return end
        self.refreshTimer = C_Timer.NewTimer(0, function()
            self.refreshTimer = nil
            self:Refresh()
        end)
    end

    function mod:SetPreview(key)
        if key and not Engines.CanConfigureUnitFrameAuras() then return end
        self.previewKey = key
        self:Refresh()
        for displayKey, engine in pairs(self.displays) do engine:SetPreview(displayKey == key) end
    end

    function mod:StopEncounter()
        self.encounterActive, self.stage = false, nil
        self.previewKey = nil
        wipe(self.hiddenByChannel)
        for _, engine in pairs(self.displays) do engine:SetPreview(false); engine:SetShown(false) end
    end

    function mod:OnEncounterStart(_, encounterID)
        self:StopEncounter()
        if encounterID ~= definition.encounterID then return end
        self.encounterActive, self.stage = true, 1
        self:ScheduleRefresh()
    end

    function mod:OnStage(_, stage)
        if not self.encounterActive or E:IsSecret(stage) then return end
        stage = tonumber(stage)
        if not stage then return end
        self.stage = stage
        self:UpdateDisplays()
    end

    function mod:OnChannel(event, unit)
        if not self.encounterActive or E:IsSecret(unit) then return end
        for _, display in ipairs(definition.displays) do
            if display.hideDuringUnitChannel == unit then
                self.hiddenByChannel[display.key] = event == "UNIT_SPELLCAST_CHANNEL_START" or nil
            end
        end
        self:UpdateDisplays()
    end

    function mod:OnInitialize()
        self.displays, self.hiddenByChannel = {}, {}
    end

    function mod:OnEnable()
        E:CancelRunWhenOutOfCombat(refreshKey)
        self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
        self:RegisterEvent("ENCOUNTER_END", "StopEncounter")
        self:RegisterEvent("PLAYER_LEAVING_WORLD", "StopEncounter")
        self:RegisterEvent("PLAYER_ENTERING_WORLD", "ScheduleRefresh")
        self:RegisterEvent("PLAYER_REGEN_ENABLED", "ScheduleRefresh")
        self:RegisterEvent("PLAYER_REGEN_DISABLED", function() self:SetPreview(nil) end)
        self:RegisterEvent("GROUP_ROSTER_UPDATE", "ScheduleRefresh")
        self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "ScheduleRefresh")
        self:RegisterEvent("READY_CHECK", "Refresh")
        self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", "OnChannel")
        self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", "OnChannel")
        self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
        local library = E.Libs.LibGetFrame
        if library and library.RegisterCallback then
            library.RegisterCallback(self, "GETFRAME_REFRESH", "ScheduleRefresh")
            library.RegisterCallback(self, "FRAME_UNIT_UPDATE", "ScheduleRefresh")
            library.RegisterCallback(self, "FRAME_UNIT_REMOVED", "ScheduleRefresh")
        end
        self.bigWigsSubscription = BossMods.BigWigs:Subscribe({
            owner = definition.featureKey,
            onStage = function(module, stage) self:OnStage(module, stage) end,
            onStartPull = function() self:Refresh() end
        })
        self:Refresh()
    end

    function mod:OnDisable()
        self:UnregisterAllEvents()
        self:UnregisterAllMessages()
        if self.refreshTimer then self.refreshTimer:Cancel(); self.refreshTimer = nil end
        if self.bigWigsSubscription then self.bigWigsSubscription:Unsubscribe(); self.bigWigsSubscription = nil end
        local library = E.Libs.LibGetFrame
        if library and library.UnregisterAllCallbacks then library.UnregisterAllCallbacks(self) end
        self:StopEncounter()
        E:RunWhenOutOfCombat(refreshKey, function()
            if not self:IsEnabled() then
                for _, engine in pairs(self.displays) do engine:Release() end
            end
        end)
    end

    E:RegisterBossModFeature(definition.featureKey, {
        tab = definition.tab, order = definition.order or 110,
        bossKey = definition.bossKey, bossLabelKey = definition.bossLabelKey, bossOrder = definition.bossOrder,
        labelKey = "BossMods_RaidFrameAuras", navLabelKey = "BossMods_RaidFrameAuras",
        descKey = "BossMods_RaidFrameAurasDesc", moduleName = definition.moduleName
    })
    self.unitFrameAuraFeatures[#self.unitFrameAuraFeatures + 1] = definition.featureKey
end
