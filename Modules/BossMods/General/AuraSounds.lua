local E, L = unpack(ART)
local BossMods = E:GetModule("BossMods")
local MODULE_NAME = "BossMods_AuraSounds"
local CHANNELS = {Master = true, SFX = true, Music = true, Ambience = true, Dialog = true}

E:RegisterModuleDefaults(MODULE_NAME, {enabled = true, auras = {}, custom = {}})
local Mod = E:NewModule(MODULE_NAME, "AceEvent-3.0")

local function canRegister()
    return not InCombatLockdown()
        and not (C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown())
end

function Mod:GetCategories()
    local categories = {}
    for _, category in ipairs(BossMods.AuraSoundPresets or {}) do categories[#categories + 1] = category end
    categories[#categories + 1] = {key = "custom", name = L["Custom"], auras = self.db.custom}
    return categories
end

function Mod:GetAuraKey(category, aura)
    return category.key .. "/" .. (aura.key or aura.spellID)
end

function Mod:GetSettings(category, aura)
    local key = self:GetAuraKey(category, aura)
    local settings = self.db.auras[key]
    if type(settings) ~= "table" then
        settings = {enabled = false, actions = CopyTable(aura.defaultSoundActions or {})}
        self.db.auras[key] = settings
    end
    settings.actions = type(settings.actions) == "table" and settings.actions or {}
    return settings
end

function Mod:GetAuraName(aura)
    local info = C_Spell.GetSpellInfo(aura.spellID)
    return aura.name or (info and info.name) or tostring(aura.spellID)
end

function Mod:AddCustomAura(spellID)
    spellID = tonumber(spellID)
    if not spellID or spellID < 1 or spellID % 1 ~= 0 or not C_Spell.GetSpellInfo(spellID) then return end
    for _, aura in ipairs(self.db.custom) do if aura.spellID == spellID then return aura end end
    local aura = {spellID = spellID}
    self.db.custom[#self.db.custom + 1] = aura
    return aura
end

function Mod:ResolveUnits(text)
    local group, result, seen = {}, {}, {}
    if IsInRaid() then
        for index = 1, GetNumGroupMembers() do group[#group + 1] = "raid" .. index end
    else
        group[1] = "player"
        for index = 1, GetNumSubgroupMembers() do group[#group + 1] = "party" .. index end
    end
    local function add(unit)
        if not seen[unit] then seen[unit] = true; result[#result + 1] = unit end
    end
    for target in (text or "player"):lower():gmatch("[^,%s]+") do
        local matched
        for _, unit in ipairs(group) do
            local name = E:SafeString(UnitName(unit)) or ""
            local full = E:GetUnitFullName(unit, true) or ""
            local nickname = E.GetNickname and E:GetNickname(unit) or ""
            if (target == "cotank" and E:GetUnitRole(unit) == "TANK" and not UnitIsUnit(unit, "player"))
                or target == name:lower() or target == full:lower() or target == nickname:lower() then
                add(unit)
                matched = true
            end
        end
        if not matched and target ~= "cotank" and UnitExists(target) then add(target) end
    end
    return result
end

function Mod:ResolveSound(action)
    local sound = action.sound
    if type(sound) ~= "string" or sound == "" or sound == "None" then return end
    local lsm = E.Libs.LSM
    return lsm and lsm:Fetch("sound", sound, true)
end

function Mod:ClearSounds()
    for _, id in ipairs(self.soundIDs or {}) do C_UnitAuras.RemoveAuraSound(id) end
    self.soundIDs = {}
end

function Mod:Refresh()
    if not self:IsEnabled() or not C_UnitAuras.AddAuraSound then return end
    if not canRegister() then self.pending = true; return end
    self.pending = false
    self:ClearSounds()
    local triggers = {
        show = Enum.UnitAuraSoundTrigger.Added,
        hide = Enum.UnitAuraSoundTrigger.Removed,
        stackGained = Enum.UnitAuraSoundTrigger.ApplicationsIncreased
    }
    for _, category in ipairs(self:GetCategories()) do
        for _, aura in ipairs(category.auras) do
            local settings = self:GetSettings(category, aura)
            if settings.enabled then
                for _, action in ipairs(settings.actions) do
                    local sound = self:ResolveSound(action)
                    local trigger = triggers[action.condition or "show"]
                    if sound and trigger then
                        E:RegisterSoundPreload(sound)
                        local repeats = tonumber(action.repeatCount) or 1
                        if repeats ~= repeats then repeats = 1 end
                        repeats = math.max(1, math.min(10, math.floor(repeats)))
                        for _, unit in ipairs(self:ResolveUnits(action.unit)) do
                            for _, spellID in ipairs(aura.spellIDs or {aura.spellID}) do
                                for _ = 1, repeats do
                                    local ok, id = pcall(C_UnitAuras.AddAuraSound, trigger, {
                                        unitToken = unit, spellID = spellID,
                                        soundFileName = type(sound) == "string" and sound or nil,
                                        soundFileID = type(sound) == "number" and sound or nil,
                                        outputChannel = CHANNELS[action.outputChannel] and action.outputChannel or "Master"
                                    })
                                    if ok and id then self.soundIDs[#self.soundIDs + 1] = id end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

function Mod:ScheduleRefresh()
    self.pending = true
    if not canRegister() or self.refreshTimer then return end
    self.refreshTimer = C_Timer.NewTimer(0, function()
        self.refreshTimer = nil
        self:Refresh()
    end)
end

function Mod:Preview(action)
    self:StopPreview()
    local sound = self:ResolveSound(action)
    if not sound then return end
    local _, handle = PlaySoundFile(sound, CHANNELS[action.outputChannel] and action.outputChannel or "Master")
    self.previewHandle = handle
end

function Mod:StopPreview()
    if self.previewHandle then StopSound(self.previewHandle); self.previewHandle = nil end
end

function Mod:OnInitialize()
    self.soundIDs = {}
end

function Mod:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "ScheduleRefresh")
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "ScheduleRefresh")
    self:RegisterEvent("PLAYER_ROLES_ASSIGNED", "ScheduleRefresh")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "ScheduleRefresh")
    self:RegisterEvent("ENCOUNTER_END", "ScheduleRefresh")
    self:RegisterMessage("ART_NICKNAME_CHANGED", "ScheduleRefresh")
    self:RegisterMessage("ART_PROFILE_CHANGED", "ScheduleRefresh")
    self:ScheduleRefresh()
end

function Mod:OnDisable()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    if self.refreshTimer then self.refreshTimer:Cancel(); self.refreshTimer = nil end
    self:ClearSounds()
    self:StopPreview()
end

E:RegisterBossModFeature("AuraSounds", {
    tab = "General", order = 35, labelKey = "BossMods_AuraSounds",
    descKey = "BossMods_AuraSoundsDesc", moduleName = MODULE_NAME
})
