local E, L = unpack(ART)
local MODULE_NAME = "QoL_InstanceTracker"
local HOUR = 3600
local DEFAULT_CAP = 10

E:RegisterModuleDefaults(MODULE_NAME, {
    enabled = true,
    warn = true,
    warnLeft = 2,
    announceReset = true
})

local Mod = E:NewModule(MODULE_NAME, "AceEvent-3.0")
Mod.HOUR = HOUR

local function publicNumber(value)
    if E:IsSecret(value) then return end
    local number = tonumber(value)
    if number and number == number and math.abs(number) < math.huge then return number end
end

local function publicString(value)
    if type(value) ~= "string" or E:IsSecret(value) or value == "" then return end
    return value
end

local function linePattern(text)
    if type(text) ~= "string" then return end
    local escaped = text:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    return "^" .. escaped:gsub("%%%%s", "(.+)") .. "$"
end

local function charKey()
    local guid = UnitGUID("player")
    if publicString(guid) then return guid end
    local name = publicString(UnitName("player"))
    if name then return name .. "-" .. (publicString(GetRealmName()) or "") end
end

local function currentZone()
    local inInstance, kind = IsInInstance()
    if E:IsSecret(inInstance) or E:IsSecret(kind) then return end
    if not inInstance or (kind ~= "party" and kind ~= "raid") then return end
    local name, _, difficulty, difficultyName, _, _, _, instanceID = GetInstanceInfo()
    name, instanceID = publicString(name), publicNumber(instanceID)
    if not name or not instanceID then return end
    return {
        name = name,
        instanceID = instanceID,
        difficulty = publicNumber(difficulty) or 0,
        difficultyName = publicString(difficultyName),
        kind = kind
    }
end

function Mod.CopyFromGUID(guid, instanceID)
    if type(guid) ~= "string" or E:IsSecret(guid) then return end
    local kind, _, _, mapID, zoneUID = strsplit("-", guid)
    if kind ~= "Creature" or tonumber(mapID) ~= instanceID then return end
    local copy = tonumber(zoneUID)
    if copy and copy > 0 then return copy end
end

function Mod:GetStore()
    local store = E:GetGlobal(MODULE_NAME)
    store.entries = type(store.entries) == "table" and store.entries or {}
    store.open = type(store.open) == "table" and store.open or {}
    store.copies, store.generations = nil, nil
    return store
end

function Mod:Expires(entry)
    return (entry.left or entry.at) + HOUR
end

function Mod:Prune(now)
    local store = self:GetStore()
    now = now or time()
    local open = {}
    for _, row in pairs(store.open) do
        if type(row) == "table" and row.at then open[row.at] = true end
    end
    local kept, active = {}, {}
    for _, entry in ipairs(store.entries) do
        if type(entry) == "table" and type(entry.at) == "number" and entry.at <= now then
            local live = self:Expires(entry) > now
            if live or open[entry.at] then kept[#kept + 1] = entry end
            if live then active[#active + 1] = entry end
        end
    end
    local function byTime(a, b) return a.at < b.at end
    table.sort(kept, byTime)
    table.sort(active, byTime)
    store.entries = kept
    return active
end

function Mod:GetCap()
    local cap = publicNumber(self:GetStore().cap)
    if cap and cap >= 1 then return math.floor(cap) end
    return DEFAULT_CAP
end

function Mod:IsCapLearned()
    return publicNumber(self:GetStore().cap) ~= nil
end

function Mod:GetHour(now)
    now = now or time()
    local entries = self:Prune(now)
    local frees
    for _, entry in ipairs(entries) do
        local left = math.max(0, self:Expires(entry) - now)
        if not frees or left < frees then frees = left end
    end
    return entries, self:GetCap(), frees
end

local function sameZone(a, b)
    return a and b and a.instanceID == b.instanceID and a.difficulty == b.difficulty
end

function Mod:FindEntry(at)
    if not at then return end
    for index, entry in ipairs(self:GetStore().entries) do
        if entry.at == at then return entry, index end
    end
end

function Mod:Changed()
    E:SendMessage("ART_INSTANCETRACKER_UPDATED")
end

function Mod:AddEntry(zone, char, now)
    now = now or time()
    local _, class = UnitClass("player")
    local store = self:GetStore()
    local prior = store.entries[#store.entries]
    local entry = {
        at = now,
        name = zone.name,
        instanceID = zone.instanceID,
        difficulty = zone.difficulty,
        difficultyName = zone.difficultyName,
        kind = zone.kind,
        char = char,
        charName = publicString(UnitName("player")),
        class = publicString(class),
        prior = prior and prior.copy and prior.at or nil
    }
    while self:FindEntry(entry.at) do entry.at = entry.at + 1 end
    store.entries[#store.entries + 1] = entry
    self:Prune(now)
    self:Warn(now)
    self:Changed()
    return entry
end

function Mod:FormatTime(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    local hours, minutes, secs = math.floor(seconds / 3600), math.floor(seconds % 3600 / 60), seconds % 60
    if hours > 0 then return ("%d:%02d:%02d"):format(hours, minutes, secs) end
    return ("%d:%02d"):format(minutes, secs)
end

function Mod:Warn(now)
    if not self.db.warn then return end
    local entries, cap, frees = self:GetHour(now)
    local left = cap - #entries
    if left > (publicNumber(self.db.warnLeft) or 2) then return end
    local when = self:FormatTime(frees)
    if left <= 0 then
        E:Printf(L["QoL_InstanceTrackerCapText"], when)
    else
        E:Printf(L["QoL_InstanceTrackerWarnText"], #entries, cap, when)
    end
end

function Mod:MarkLeft(char, now)
    local open = self:GetStore().open[char]
    local entry = self:FindEntry(open and open.at)
    if entry then entry.left = now or time() end
end

function Mod:CheckZone(reload, now)
    now = now or time()
    local zone, char = currentZone(), charKey()
    if not char then return end
    local store = self:GetStore()
    if not zone then
        local inInstance, kind = IsInInstance()
        if E:IsSecret(inInstance) or E:IsSecret(kind) then return end
        if inInstance and (kind == "party" or kind == "raid") then return end
        if self.inside then
            self:MarkLeft(char, now)
            self:Changed()
        end
        self.inside = nil
        self:StopCopyWatch()
        return
    end
    if self.inside and sameZone(self.inside.zone, zone) then return end
    self:Prune(now)
    local open = store.open[char]
    local ghost = self.ghostUntil and GetTime() < self.ghostUntil
    if not ghost and not (reload and sameZone(open, zone)) then
        local entry = self:AddEntry(zone, char, now)
        store.open[char] = {at = entry.at, instanceID = zone.instanceID, difficulty = zone.difficulty}
    end
    self.inside = {char = char, zone = zone}
    self:StartCopyWatch()
end

function Mod:OnLeavingWorld()
    local ghost = UnitIsGhost("player")
    if E:IsSecret(ghost) or ghost then self.ghostUntil = GetTime() + 5 end
end

function Mod:OnUnghost()
    self.ghostUntil = GetTime() + 4
end

function Mod:OnLogout()
    local char = charKey()
    if self.inside and char then self:MarkLeft(char) end
end

function Mod:NoteCopy(copyID)
    local inside = self.inside
    if not inside or not copyID then return end
    self:StopCopyWatch()
    local open = self:GetStore().open[inside.char]
    local entry, index = self:FindEntry(open and open.at)
    if not entry or entry.copy then return end
    local prior = self:FindEntry(entry.prior)
    entry.prior = nil
    if prior and prior.copy == copyID then
        table.remove(self:GetStore().entries, index)
        open.at = prior.at
        self:Changed()
        return
    end
    entry.copy = copyID
end

function Mod:ReadUnitCopy(unit)
    if not self.inside or type(unit) ~= "string" then return end
    local copyID = self.CopyFromGUID(UnitGUID(unit), self.inside.zone.instanceID)
    if copyID then self:NoteCopy(copyID) end
end

function Mod:OnTargetChanged()
    self:ReadUnitCopy("target")
end

function Mod:OnMouseoverUnit()
    self:ReadUnitCopy("mouseover")
end

function Mod:OnNamePlateAdded(_, unit)
    self:ReadUnitCopy(unit)
end

local COPY_EVENTS = {
    PLAYER_TARGET_CHANGED = "OnTargetChanged",
    UPDATE_MOUSEOVER_UNIT = "OnMouseoverUnit",
    NAME_PLATE_UNIT_ADDED = "OnNamePlateAdded"
}

function Mod:StartCopyWatch()
    if self.watching then return end
    self.watching = true
    for event, handler in pairs(COPY_EVENTS) do
        self:RegisterEvent(event, handler)
    end
    if C_NamePlate and C_NamePlate.GetNamePlates then
        for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
            if not self.watching then return end
            local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
            if unit then self:ReadUnitCopy(unit) end
        end
    end
end

function Mod:StopCopyWatch()
    if not self.watching then return end
    self.watching = nil
    for event in pairs(COPY_EVENTS) do
        self:UnregisterEvent(event)
    end
end

function Mod:LearnCap()
    local entries = self:GetHour()
    local count = #entries
    local store = self:GetStore()
    if count >= 1 and count > (publicNumber(store.cap) or 0) then
        store.cap = count
    end
    self:Changed()
end

local patterns
local function getPatterns()
    if patterns then return patterns end
    patterns = {
        reset = linePattern(INSTANCE_RESET_SUCCESS),
        cap = linePattern(TRANSFER_ABORT_TOO_MANY_INSTANCES)
    }
    return patterns
end

function Mod:OnGameText(text)
    if type(text) ~= "string" or E:IsSecret(text) then return end
    local p = getPatterns()
    if p.cap and text:match(p.cap) then
        self:LearnCap()
    elseif p.reset and text:match(p.reset) then
        self:AnnounceReset()
    end
end

function Mod:AnnounceReset()
    local now = GetTime()
    if self.lastAnnounce and now - self.lastAnnounce < 5 then return end
    if not self.db.announceReset or not C_ChatInfo or not C_ChatInfo.SendChatMessage then return end
    local inRaid, inGroup = IsInRaid(), IsInGroup()
    if E:IsSecret(inRaid) or E:IsSecret(inGroup) or not inGroup then return end
    local locked = C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()
    if E:IsSecret(locked) or locked then return end
    self.lastAnnounce = now
    pcall(C_ChatInfo.SendChatMessage, L["QoL_InstanceTrackerResetText"], inRaid and "RAID" or "PARTY")
end

function Mod:OnSystemMessage(_, text)
    self:OnGameText(text)
end

function Mod:OnUIError(_, _, text)
    self:OnGameText(text)
end

function Mod:OnEnteringWorld(_, _, isReload)
    self.seenWorld = true
    local reload = isReload and true or false
    if self.zoneTimer then
        self.zoneTimer:Cancel()
        reload = reload or self.zoneReload
    end
    self.zoneReload = reload
    self.zoneTimer = C_Timer.NewTimer(0.5, function()
        self.zoneTimer, self.zoneReload = nil, nil
        self:CheckZone(reload)
    end)
end

function Mod:OnZoneChanged()
    if self.zoneTimer then return end
    self:OnEnteringWorld()
end

function Mod:ScheduleExpiry()
    if self.expiryTimer then
        self.expiryTimer:Cancel()
        self.expiryTimer = nil
    end
    local _, _, frees = self:GetHour()
    if not frees then return end
    self.expiryTimer = C_Timer.NewTimer(math.max(1, frees + 1), function()
        self.expiryTimer = nil
        self:Changed()
        self:ScheduleExpiry()
    end)
end

function Mod:OnUpdated()
    self:ScheduleExpiry()
end

function Mod:Refresh()
    self:Changed()
end

function Mod:OnEnable()
    if not E:IsForeverClient() then return end
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEnteringWorld")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "OnZoneChanged")
    self:RegisterEvent("CHAT_MSG_SYSTEM", "OnSystemMessage")
    self:RegisterEvent("UI_ERROR_MESSAGE", "OnUIError")
    self:RegisterMessage("ART_INSTANCETRACKER_UPDATED", "OnUpdated")
    self:RegisterEvent("PLAYER_LEAVING_WORLD", "OnLeavingWorld")
    self:RegisterEvent("PLAYER_UNGHOST", "OnUnghost")
    self:RegisterEvent("PLAYER_LOGOUT", "OnLogout")
    if self.seenWorld then self:CheckZone(true) end
    self:ScheduleExpiry()
end

function Mod:OnDisable()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    self.watching = nil
    self.inside = nil
    if self.zoneTimer then self.zoneTimer:Cancel() end
    if self.expiryTimer then self.expiryTimer:Cancel() end
    self.zoneTimer, self.expiryTimer = nil, nil
end

if E:IsForeverClient() then
    E:RegisterQoLFeature("InstanceTracker", {
        order = 80,
        labelKey = "QoL_InstanceTracker",
        descKey = "QoL_InstanceTrackerDesc",
        moduleName = MODULE_NAME
    })
end
