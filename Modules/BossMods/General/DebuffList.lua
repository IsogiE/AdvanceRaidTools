local E = unpack(ART)
local BossMods = E:GetModule("BossMods")
local MODULE_NAME = "BossMods_DebuffList"

E:RegisterModuleDefaults(MODULE_NAME, {
    enabled = false, width = 220, rowHeight = 22, spacing = 2,
    font = "PT Sans Narrow", fontSize = 12, texture = "Clean", previewRows = 5,
    position = {point = "CENTER", x = -360, y = 0}
})
local Mod = E:NewModule(MODULE_NAME, "AceEvent-3.0")

function Mod:GetSettings()
    for key, range in pairs({
        width = {100, 500, 220}, rowHeight = {16, 60, 22}, spacing = {0, 20, 2},
        fontSize = {8, 32, 12}, previewRows = {1, 40, 5}
    }) do
        local value = tonumber(self.db[key])
        if not value or value ~= value then value = range[3] end
        self.db[key] = math.floor(math.max(range[1], math.min(range[2], value)) + 0.5)
    end
    return self.db
end

function Mod:GetMembers()
    local units, members = {}, {}
    if IsInRaid() then
        for index = 1, GetNumGroupMembers() do units[#units + 1] = "raid" .. index end
    else
        units[1] = "player"
        for index = 1, GetNumSubgroupMembers() do units[#units + 1] = "party" .. index end
    end
    for _, unit in ipairs(units) do
        local name = E.GetNickname and E:GetNickname(unit) or UnitName(unit)
        local class = UnitClassBase(unit)
        if not E:IsSecret(name) and not E:IsSecret(class) and name and class then
            members[#members + 1] = {unit = unit, name = name, class = class}
        end
    end
    return members
end

function Mod:Refresh()
    if not self:IsEnabled() or not BossMods.Engines.CanConfigureUnitFrameAuras() then return end
    if not self.display then
        self.display = BossMods.Engines.FilteredAuraList({
            getSettings = function() return self:GetSettings() end,
            getMembers = function() return self:GetMembers() end
        })
        self.display:SetActive(true)
    else
        self.display:Refresh()
    end
    E:ApplyFramePosition(self.display.frame, self.db.position)
end

function Mod:ScheduleRefresh()
    if self.refreshTimer then return end
    self.refreshTimer = C_Timer.NewTimer(0, function()
        self.refreshTimer = nil
        self:Refresh()
    end)
end

function Mod:SetEditMode(value)
    self:Refresh()
    if self.display then self.display:SetEditMode(value) end
end

function Mod:SavePosition(position)
    self.db.position = {point = position.point, x = position.x, y = position.y}
    self:Refresh()
end

function Mod:OnEnable()
    E:CancelRunWhenOutOfCombat(MODULE_NAME)
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "ScheduleRefresh")
    self:RegisterEvent("UNIT_NAME_UPDATE", "ScheduleRefresh")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "ScheduleRefresh")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "ScheduleRefresh")
    self:RegisterEvent("READY_CHECK", "Refresh")
    self:RegisterEvent("ENCOUNTER_START", function() self:SetEditMode(false) end)
    self:RegisterMessage("ART_NICKNAME_CHANGED", "ScheduleRefresh")
    self:RegisterMessage("ART_PROFILE_CHANGED", "ScheduleRefresh")
    self:RegisterMessage("ART_MEDIA_UPDATED", "ScheduleRefresh")
    if self.display then self.display:SetActive(true) end
    self:Refresh()
end

function Mod:OnDisable()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    if self.refreshTimer then self.refreshTimer:Cancel(); self.refreshTimer = nil end
    if self.display then self.display:SetEditMode(false); self.display:SetActive(false) end
    E:RunWhenOutOfCombat(MODULE_NAME, function()
        if not self:IsEnabled() and self.display then self.display:SetActive(false) end
    end)
end

E:RegisterBossModFeature("DebuffList", {
    tab = "General", order = 31, labelKey = "BossMods_DebuffList",
    descKey = "BossMods_DebuffListDesc", moduleName = MODULE_NAME
})
