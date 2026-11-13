local E, L = unpack(ART)
local MODULE_NAME = "QoL_InstanceTracker"
local HOUR = 3600
local DEFAULT_CAP = 10

E:RegisterModuleDefaults(MODULE_NAME, {
    enabled = true,
    warn = true,
    warnLeft = 2,
    announceReset = false
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
    store.copies = type(store.copies) == "table" and store.copies or {}
    store.generations = type(store.generations) == "table" and store.generations or {}
    return store
end

function Mod:Prune(now)
    local store = self:GetStore()
    now = now or time()
    local kept = {}
    for _, entry in ipairs(store.entries) do
        if type(entry) == "table" and type(entry.at) == "number" and entry.at <= now and now - entry.at < HOUR then
            kept[#kept + 1] = entry
        end
    end
    table.sort(kept, function(a, b) return a.at < b.at end)
    store.entries = kept
    for key, copy in pairs(store.copies) do
        if type(copy) ~= "table" or type(copy.seen) ~= "number" or now - copy.seen >= HOUR then
            store.copies[key] = nil
        end
    end
    return kept
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
    local frees = entries[1] and math.max(0, entries[1].at + HOUR - now) or nil
    return entries, self:GetCap(), frees
end

function Mod:Generation(char)
    return publicNumber(self:GetStore().generations[char]) or 0
end

function Mod:AdvanceGeneration(char)
    char = char or charKey()
    if not char then return end
    local generations = self:GetStore().generations
    generations[char] = self:Generation(char) + 1
end

function Mod:CopyKey(zone, char)
    return ("%s:%d:%d:%d"):format(char, zone.instanceID, zone.difficulty, self:Generation(char))
end

function Mod:Changed()
    E:SendMessage("ART_INSTANCETRACKER_UPDATED")
end

function Mod:AddEntry(zone, char, key, now)
    now = now or time()
    local _, class = UnitClass("player")
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
        key = key
    }
    local store = self:GetStore()
    store.entries[#store.entries + 1] = entry
    store.copies[key] = {seen = now}
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

function Mod:CheckZone(now)
    now = now or time()
    local zone, char = currentZone(), charKey()
    if not zone or not char then
        if self.inside and self.resetOnLeave then
            self.resetOnLeave = nil
            self:AdvanceGeneration(self.inside.char)
        end
        if self.inside then
            local copy = self:GetStore().copies[self.inside.key]
            if copy then copy.seen = now end
        end
        self.inside = nil
        self:StopCopyWatch()
        return
    end
    local key = self:CopyKey(zone, char)
    if self.inside and self.inside.key == key then return end
    local store = self:GetStore()
    self:Prune(now)
    local copy = store.copies[key]
    if copy then
        copy.seen = now
    else
        self:AddEntry(zone, char, key, now)
    end
    self.inside = {key = key, char = char, zone = zone}
    self:StartCopyWatch()
end

function Mod:NoteCopy(copyID, now)
    local inside = self.inside
    if not inside or not copyID then return end
    self:StopCopyWatch()
    local store = self:GetStore()
    local copy = store.copies[inside.key]
    if not copy then return end
    if not copy.id then
        copy.id = copyID
        return
    end
    if copy.id == copyID then return end
    now = now or time()
    self:AdvanceGeneration(inside.char)
    local key = self:CopyKey(inside.zone, inside.char)
    self:AddEntry(inside.zone, inside.char, key, now)
    store.copies[key].id = copyID
    inside.key = key
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
        self:AdvanceGeneration()
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

function Mod:OnRosterUpdate()
    local grouped = IsInGroup()
    if E:IsSecret(grouped) then return end
    grouped = grouped and true or false
    if self.grouped and not grouped then
        if self.inside then
            self.resetOnLeave = true
        else
            self:AdvanceGeneration()
        end
    end
    self.grouped = grouped
end

function Mod:OnEnteringWorld()
    if self.zoneTimer then self.zoneTimer:Cancel() end
    self.zoneTimer = C_Timer.NewTimer(1, function()
        self.zoneTimer = nil
        self:CheckZone()
    end)
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
    local grouped = IsInGroup()
    if not E:IsSecret(grouped) then self.grouped = grouped and true or false end
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEnteringWorld")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "OnEnteringWorld")
    self:RegisterEvent("CHAT_MSG_SYSTEM", "OnSystemMessage")
    self:RegisterEvent("UI_ERROR_MESSAGE", "OnUIError")
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "OnRosterUpdate")
    self:RegisterMessage("ART_INSTANCETRACKER_UPDATED", "OnUpdated")
    self:CheckZone()
    self:ScheduleExpiry()
end

function Mod:OnDisable()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    self.watching = nil
    self.inside = nil
    self.resetOnLeave = nil
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
