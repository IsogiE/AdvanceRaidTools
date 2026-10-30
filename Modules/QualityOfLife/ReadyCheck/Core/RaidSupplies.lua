local E = unpack(ART)
local CreateFrame, C_Timer, hooksecurefunc = E:DiagnosticBindings("Modules/QualityOfLife/ReadyCheck/Core/RaidSupplies")

E:RegisterModuleDefaults("QoL_RaidSupplies", {enabled = true})
local Mod = E:NewModule("QoL_RaidSupplies", "AceEvent-3.0")
E:SetModuleParent("QoL_RaidSupplies", "QualityOfLife")

local PREFIX = "ART_SUPPLIES"
local UNKNOWN, NOT_APPLICABLE, PERMANENT, NO_WEAPON = -1, -2, -3, -4
local ITEMS = {healthstones = {5512, 224464}, potions = {271884, 271883}, runes = {259085}}
local FIELDS = {"itemLevel", "healthstones", "potions", "runes", "mainHand", "offHand"}
Mod.reports = {}

local function number(value)
    if not E:IsSecret(value) and type(value) == "number" and value == value
        and value > -math.huge and value < math.huge then return value end
end

local function canRead()
    return not InCombatLockdown() and not IsEncounterInProgress()
        and not (C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown())
end

local function countItems(items, charges)
    local total = 0
    for _, itemID in ipairs(items) do
        local count = number(C_Item.GetItemCount(itemID, false, charges, false, false))
        if not count then return UNKNOWN end
        total = total + count
    end
    return total
end

local function weaponSeconds(slot)
    local itemID = GetInventoryItemID("player", slot)
    if E:IsSecret(itemID) then return UNKNOWN end
    if not itemID then return slot == 16 and NO_WEAPON or NOT_APPLICABLE end
    local itemClass = select(6, C_Item.GetItemInfoInstant(itemID))
    if not number(itemClass) then return UNKNOWN end
    if itemClass ~= Enum.ItemClass.Weapon then return NOT_APPLICABLE end
    if not C_PaperDollInfo or not C_PaperDollInfo.GetTemporaryEnchantmentInfo then return UNKNOWN end
    local enchant = C_PaperDollInfo.GetTemporaryEnchantmentInfo(slot)
    if E:IsSecret(enchant) then return UNKNOWN end
    if not enchant then return 0 end
    if E:IsSecret(enchant.hasExpirationTime) then return UNKNOWN end
    if not enchant.hasExpirationTime then return PERMANENT end
    local remaining = number(enchant.remainingTimeMs)
    return remaining and math.max(0, math.ceil(remaining / 1000)) or UNKNOWN
end

function Mod:Collect()
    if not canRead() then return end
    local equipped = number(select(2, GetAverageItemLevel()))
    return {
        equipped and math.floor(equipped * 10 + 0.5) or UNKNOWN,
        countItems(ITEMS.healthstones, true), countItems(ITEMS.potions, false),
        countItems(ITEMS.runes, false), weaponSeconds(16), weaponSeconds(17)
    }
end

function Mod:Store(unit, values, age)
    local guid = UnitGUID(unit)
    if not E:SafeString(guid) then return end
    local report = {received = GetTime() - (age or 0)}
    for index, key in ipairs(FIELDS) do report[key] = values[index] end
    self.reports[guid] = report
    E:SendMessage("ART_RAID_SUPPLIES_UPDATED")
end

function Mod:GetReport(unit)
    if not self:IsEnabled() or not canRead() then return end
    local guid = UnitGUID(unit)
    if not E:SafeString(guid) then return end
    local report = self.reports[guid]
    if report and GetTime() - report.received <= 60 then return report end
end

function Mod:Publish()
    self.responseTimer = nil
    if not self:IsEnabled() or not self.endsAt or GetTime() > self.endsAt or not canRead() then return end
    local values = self:Collect()
    if not values then return end
    self:Store("player", values)
    self.lastSent = GetTime()
    local comms = E:GetModule("Comms")
    if IsInGroup() and comms:IsEnabled() then
        local channel = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or (IsInRaid() and "RAID" or "PARTY")
        comms:Broadcast(PREFIX, "1;" .. GetServerTime() .. ";" .. table.concat(values, ";"), channel)
    end
end

function Mod:ScheduleReport()
    if not self.endsAt or GetTime() > self.endsAt or self.responseTimer or not canRead() then return end
    local delay = math.max(0.3, 2 - (GetTime() - (self.lastSent or -2)))
    self.responseTimer = C_Timer.NewTimer(delay, function() self:Publish() end)
end

function Mod:BeginCheck()
    self:Clear()
    if not canRead() then return end
    self.startedAt, self.endsAt = GetServerTime(), GetTime() + 60
    self:ScheduleReport()
end

function Mod:OnCommReceived(_, message, channel, sender)
    if not self.endsAt or GetTime() > self.endsAt or not canRead()
        or (channel ~= "RAID" and channel ~= "PARTY" and channel ~= "INSTANCE_CHAT")
        or not E:SafeString(message) or #message > 160 then return end
    local unit = E:GetGroupUnitByName(sender)
    if not unit then return end
    local fields = {strsplit(";", message)}
    if fields[1] ~= "1" or #fields ~= 8 then return end
    local sent = number(tonumber(fields[2]))
    local age = sent and GetServerTime() - sent
    if not sent or sent % 1 ~= 0 or sent < self.startedAt - 1 or age < -1 or age > 5 then return end
    local values = {}
    for index = 1, 6 do
        local value = number(tonumber(fields[index + 2]))
        local minimum, maximum = index >= 5 and NO_WEAPON or UNKNOWN, index >= 5 and 86400 or 100000
        if not value or value % 1 ~= 0 or value < minimum or value > maximum then return end
        values[index] = value
    end
    self:Store(unit, values, math.max(0, age))
end

function Mod:Clear()
    if self.responseTimer then self.responseTimer:Cancel(); self.responseTimer = nil end
    self.startedAt, self.endsAt = nil, nil
    wipe(self.reports)
end

function Mod:OnEnable()
    E:GetModule("Comms"):RegisterProtocol(PREFIX, self)
    self:RegisterEvent("READY_CHECK", "BeginCheck")
    self:RegisterEvent("BAG_UPDATE_DELAYED", "ScheduleReport")
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", "ScheduleReport")
    self:RegisterEvent("UNIT_INVENTORY_CHANGED", "ScheduleReport")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "Clear")
    self:RegisterEvent("GROUP_LEFT", "Clear")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Clear")
end

function Mod:OnDisable()
    self:Clear()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    E:GetModule("Comms"):UnregisterProtocol(PREFIX)
    E:SendMessage("ART_RAID_SUPPLIES_UPDATED")
end
