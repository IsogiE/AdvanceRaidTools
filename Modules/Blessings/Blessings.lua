local E, L = unpack(ART)
local _, C_Timer = E:DiagnosticBindings("Modules/Blessings/Blessings")
local MODULE_NAME = "Blessings"

local PREFIX = "PLPWR"
local MAX_MESSAGE = 250

local CLASSES = {"WARRIOR", "ROGUE", "PRIEST", "DRUID", "PALADIN", "HUNTER", "MAGE", "WARLOCK", "SHAMAN"}
local CLASS_INDEX = {}
for i, class in ipairs(CLASSES) do CLASS_INDEX[class] = i end

local BLESSINGS = {
    [1] = {key = "wisdom", ranks = {19742, 19850, 19852, 19853, 19854, 25290}},
    [2] = {key = "might", ranks = {19740, 19834, 19835, 19836, 19837, 19838, 25291}},
    [3] = {key = "kings", ranks = {20217}}
}
local BLESSING_ORDER = {1, 2, 3}

local WANTED = {
    WARRIOR = {2, 3}, ROGUE = {2, 3}, PRIEST = {1, 3}, DRUID = {1, 3, 2}, PALADIN = {1, 3, 2},
    HUNTER = {2, 3, 1}, MAGE = {1, 3}, WARLOCK = {1, 3}, SHAMAN = {1, 3, 2}
}
local AURA_WANTED = {1, 3, 2, 7, 6, 5, 4}
local AURAS = {
    [1] = {key = "devotion", ranks = {465, 10290, 643, 10291, 1032, 10292, 10293}},
    [2] = {key = "retribution", ranks = {7294, 10298, 10299, 10300, 10301}},
    [3] = {key = "concentration", ranks = {19746}},
    [4] = {key = "shadow", ranks = {19876, 19895, 19896}},
    [5] = {key = "frost", ranks = {19888, 19897, 19898}},
    [6] = {key = "fire", ranks = {19891, 19899, 19900}},
    [7] = {key = "sanctity", ranks = {20218}}
}
local AURA_ORDER = {1, 2, 3, 4, 5, 6, 7}
local BLESSING_SLOTS, AURA_SLOTS = 6, 7

E:RegisterModuleDefaults(MODULE_NAME, {
    enabled = true
})

local Mod = E:NewModule(MODULE_NAME, "AceEvent-3.0")
Mod.CLASSES, Mod.CLASS_INDEX = CLASSES, CLASS_INDEX
Mod.BLESSINGS, Mod.BLESSING_ORDER = BLESSINGS, BLESSING_ORDER
Mod.AURAS, Mod.AURA_ORDER = AURAS, AURA_ORDER
Mod.PREFIX = PREFIX

local function safe(v)
    if E:IsSecret(v) then return nil end
    return v
end

local function safeString(v)
    v = E:SafeString(v)
    if v and v ~= "" then return v end
end

local function knows(spellID)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, spellID)
        if ok and safe(known) ~= nil then return known == true end
    end
    if IsPlayerSpell then
        local ok, known = pcall(IsPlayerSpell, spellID)
        if ok then return safe(known) == true end
    end
    return false
end

local function knownRank(entry)
    for i = #entry.ranks, 1, -1 do
        if knows(entry.ranks[i]) then return i end
    end
end
Mod.KnownRank = knownRank

function Mod.SpellIcon(entry)
    local id = entry and entry.ranks[1]
    if not id then return end
    local icon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)
    if not icon and GetSpellTexture then icon = GetSpellTexture(id) end
    return safe(icon)
end

function Mod.SpellName(entry)
    local id = entry and entry.ranks[1]
    local name = id and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
    return safeString(name) or (entry and L["Blessings_" .. entry.key])
end

local function wireName(name) return (name:gsub(" ", "_")) end
local function unwireName(name) return (name:gsub("_", " ")) end
Mod.WireName, Mod.UnwireName = wireName, unwireName

local function ownRealm()
    return safeString(GetNormalizedRealmName and GetNormalizedRealmName())
end

local function stripRealm(name)
    local realm = ownRealm()
    if realm and #name > #realm + 1 and name:sub(-#realm - 1) == "-" .. realm then
        return name:sub(1, -#realm - 2)
    end
    return name
end

local function unitNames(unit)
    local names = {}
    local function add(n)
        n = safeString(n)
        if n then names[#names + 1] = n end
    end
    add(GetUnitName and GetUnitName(unit, true))
    add(UnitName(unit))
    if UnitFullName then
        local first, second = UnitFullName(unit)
        first, second = safeString(first), safeString(second)
        if first and second then
            add(first .. " " .. second)
            add(first .. "-" .. second)
        end
    end
    return names
end

local function groupUnits()
    local units = {}
    if IsInRaid() then
        for i = 1, (safe(GetNumGroupMembers()) or 0) do units[#units + 1] = {unit = "raid" .. i, index = i} end
    else
        units[1] = {unit = "player"}
        for i = 1, (safe(GetNumSubgroupMembers and GetNumSubgroupMembers()) or 0) do
            units[#units + 1] = {unit = "party" .. i}
        end
    end
    return units
end

local function rosterName(entry)
    if entry.index then
        local name = safeString((GetRaidRosterInfo(entry.index)))
        if name then return name end
    end
    return safeString(GetUnitName and GetUnitName(entry.unit, true)) or safeString(UnitName(entry.unit))
end

local function unitMatches(unit, name)
    if not name then return false end
    local bare = stripRealm(name)
    for _, n in ipairs(unitNames(unit)) do
        if n == name or n == bare or stripRealm(n) == bare then return true end
    end
    return false
end

function Mod:PlayerName()
    return safeString(GetUnitName and GetUnitName("player", true)) or safeString(UnitName("player")) or "?"
end

function Mod:IsMe(name)
    return name ~= nil and unitMatches("player", unwireName(name))
end

function Mod:ScanGroup()
    local members, byKey = {}, {}
    if IsInGroup() then
        for _, entry in ipairs(groupUnits()) do
            local unit = entry.unit
            if UnitExists(unit) then
                local name = rosterName(entry)
                local class = safeString((select(2, UnitClass(unit))))
                if name and class and CLASS_INDEX[class] then
                    local rank = 0
                    if entry.index then
                        rank = safe((select(2, GetRaidRosterInfo(entry.index)))) or 0
                    elseif safe(UnitIsGroupLeader(unit)) then
                        rank = 2
                    end
                    local member = {
                        name = name, class = class, unit = unit, me = UnitIsUnit(unit, "player") == true,
                        lead = type(rank) == "number" and rank > 0
                    }
                    members[#members + 1] = member
                    byKey[name] = member
                end
            end
        end
    end
    if not next(byKey) then
        local class = safeString((select(2, UnitClass("player"))))
        local member = {name = self:PlayerName(), class = class, unit = "player", me = true, lead = true}
        members[1], byKey[member.name] = member, member
    end
    self.members, self.memberByName, self.paladins = members, byKey, nil
    return members
end

function Mod:FindMember(name)
    if not name then return end
    name = unwireName(name)
    local members = self.memberByName or {}
    if members[name] then return members[name] end
    for _, member in pairs(members) do
        if unitMatches(member.unit, name) then return member end
    end
end

local function instanceGroup()
    return IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and IsInInstance()
end

function Mod:IsLeader(member)
    if not member then return false end
    if not IsInGroup() then return member.me end
    if instanceGroup() then return false end
    return member.lead == true
end

function Mod:CanEdit(paladinName)
    local me = self:FindMember(self:PlayerName()) or {me = true, lead = not IsInGroup()}
    if self:IsMe(paladinName) then return true end
    return self:IsLeader(me)
end

local function newPlan()
    return {classes = {}, players = {}, aura = 0, known = {}, auraKnown = {}}
end

function Mod:OwnPlan()
    local char = E.db and E.db.char
    if not char then return newPlan() end
    local saved = type(char.blessings) == "table" and char.blessings or {}
    char.blessings = saved
    saved.classes = type(saved.classes) == "table" and saved.classes or {}
    saved.players = type(saved.players) == "table" and saved.players or {}
    saved.aura = tonumber(saved.aura) or 0
    for i = 1, #CLASSES do
        local b = tonumber(saved.classes[i])
        saved.classes[i] = (b and BLESSINGS[b]) and b or nil
    end
    for name, choice in pairs(saved.players) do
        if type(choice) ~= "table" or not BLESSINGS[tonumber(choice[2]) or 0] then saved.players[name] = nil end
    end
    if not AURAS[saved.aura] then saved.aura = 0 end
    return saved
end

function Mod:IsPaladin()
    return safeString((select(2, UnitClass("player")))) == "PALADIN"
end

function Mod:RefreshOwnKnown()
    local plan = self:OwnPlan()
    local known, auraKnown = {}, {}
    if self:IsPaladin() then
        for i, entry in pairs(BLESSINGS) do known[i] = knownRank(entry) end
        for i, entry in pairs(AURAS) do auraKnown[i] = knownRank(entry) end
    end
    self.ownKnown, self.ownAuraKnown = known, auraKnown
    return plan
end

function Mod:GetPlan(name)
    local known = self.memberByName and self.memberByName[name]
    if (known and known.me) or (not known and self:IsMe(name)) then
        local plan = self:OwnPlan()
        plan.known, plan.auraKnown, plan.heard = self.ownKnown or {}, self.ownAuraKnown or {}, true
        return plan
    end
    local member = self:FindMember(name)
    local key = member and member.name or unwireName(name)
    self.plans[key] = self.plans[key] or newPlan()
    return self.plans[key], key
end

function Mod:GetPaladins()
    local list = self.paladins
    if not list then
        list = {}
        for _, member in ipairs(self.members or self:ScanGroup()) do
            if member.class == "PALADIN" then
                list[#list + 1] = {name = member.name, member = member, me = member.me}
            end
        end
        table.sort(list, function(a, b)
            if a.me ~= b.me then return a.me end
            return a.name < b.name
        end)
        self.paladins = list
    end
    for _, paladin in ipairs(list) do paladin.plan = self:GetPlan(paladin.name) end
    return list
end

function Mod:OtherGivers(paladinName, blessing, classIndex, member)
    local names = {}
    if not BLESSINGS[blessing or 0] then return names end
    for _, paladin in ipairs(self:GetPaladins()) do
        if paladin.name ~= paladinName then
            local given
            if member then
                given = self:BlessingFor(paladin.plan, member)
            else
                given = paladin.plan.classes[classIndex]
            end
            if given == blessing then names[#names + 1] = paladin.name end
        end
    end
    return names
end

function Mod:ClassCounts()
    local counts = {}
    for _, member in ipairs(self.members or self:ScanGroup()) do
        local i = CLASS_INDEX[member.class]
        if i then counts[i] = (counts[i] or 0) + 1 end
    end
    return counts
end

function Mod:MembersOfClass(classIndex)
    local list = {}
    for _, member in ipairs(self.members or self:ScanGroup()) do
        if CLASS_INDEX[member.class] == classIndex then list[#list + 1] = member end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

function Mod:BlessingFor(plan, member)
    local own = plan.players[member.name]
    if own then return own[2], true end
    return plan.classes[CLASS_INDEX[member.class]], false
end

function Mod:Changed()
    E:SendMessage("ART_BLESSINGS_UPDATED")
end

local function groupChannel()
    if instanceGroup() then return "INSTANCE_CHAT" end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
end

function Mod:Send(message)
    if not self:IsActive() then return end
    local channel = groupChannel()
    local Comms = E:GetModule("Comms", true)
    if not (channel and Comms and Comms.Broadcast) then return end
    Comms:Broadcast(PREFIX, message, channel)
end

local function rankPairs(known, slots)
    local s = {}
    for i = 1, slots do
        local rank = known[i]
        s[i] = rank and string.format("%x%x", math.min(rank, 15), 0) or "nn"
    end
    return table.concat(s)
end

local function classDigits(classes)
    local s = {}
    for i = 1, #CLASSES do
        local b = classes[i]
        s[i] = (b and b > 0 and b < 10) and tostring(b) or "n"
    end
    return table.concat(s)
end

function Mod:SendBatched(head, entries)
    local line = head
    local count = 0
    for _, entry in ipairs(entries) do
        local nextLine = count == 0 and (line .. " " .. entry) or (line .. "@" .. entry)
        if count > 0 and #nextLine > MAX_MESSAGE then
            self:Send(line)
            line, count = head .. " " .. entry, 1
        else
            line, count = nextLine, count + 1
        end
    end
    if count > 0 then self:Send(line) end
end

function Mod:NAssignEntries(paladin, players)
    local entries = {}
    local names = {}
    for name in pairs(players) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        local choice = players[name]
        entries[#entries + 1] = string.format("%s %d %s %d", wireName(paladin), choice[1], wireName(name), choice[2])
    end
    return entries
end

local function pallyPowerLoaded()
    local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    return isLoaded and isLoaded("PallyPower") == true
end

function Mod:IsActive()
    return E:IsForeverClient() and self:IsEnabled()
end

function Mod:SendSelf()
    if not (self:IsActive() and IsInGroup() and self:IsPaladin()) or pallyPowerLoaded() then return end
    local plan = self:RefreshOwnKnown()
    self:Send("SELF " .. rankPairs(self.ownKnown, BLESSING_SLOTS) .. "@" .. classDigits(plan.classes))
    self:Send("ASELF " .. rankPairs(self.ownAuraKnown, AURA_SLOTS) .. "@" .. tostring(plan.aura or 0))
    self:SendBatched("NASSIGN", self:NAssignEntries(self:PlayerName(), plan.players))
end

function Mod:QueueSendSelf()
    if self.sendTimer then return end
    self.sendTimer = C_Timer.NewTimer(1, function()
        self.sendTimer = nil
        self:SendSelf()
    end)
end

function Mod:SetClassBlessing(paladinName, classIndex, blessing)
    if not (CLASSES[classIndex] and self:CanEdit(paladinName)) then return end
    blessing = BLESSINGS[blessing or 0] and blessing or nil
    local plan = self:GetPlan(paladinName)
    plan.classes[classIndex] = blessing
    if self:IsMe(paladinName) then
        self:QueueSendSelf()
    else
        self:Send(string.format("ASSIGN %s %d %d", paladinName, classIndex, blessing or 0))
    end
    self:Changed()
end

function Mod:SetPlayerBlessing(paladinName, member, blessing)
    if not (member and self:CanEdit(paladinName)) then return end
    local classIndex = CLASS_INDEX[member.class]
    if not classIndex then return end
    blessing = BLESSINGS[blessing or 0] and blessing or nil
    local plan = self:GetPlan(paladinName)
    plan.players[member.name] = blessing and {classIndex, blessing} or nil
    local sender = self:IsMe(paladinName) and self:PlayerName() or paladinName
    self:Send(string.format("NASSIGN %s %d %s %d", wireName(sender), classIndex, wireName(member.name), blessing or 0))
    self:Changed()
end

function Mod:SetAura(paladinName, aura)
    if not self:CanEdit(paladinName) then return end
    aura = AURAS[aura or 0] and aura or 0
    local plan = self:GetPlan(paladinName)
    plan.aura = aura
    if self:IsMe(paladinName) then
        self:QueueSendSelf()
    else
        self:Send(string.format("AASSIGN %s %d", paladinName, aura))
    end
    self:Changed()
end

function Mod:ClearAll()
    local plan = self:OwnPlan()
    wipe(plan.classes)
    wipe(plan.players)
    plan.aura = 0
    local me = self:FindMember(self:PlayerName())
    if me and self:IsLeader(me) then
        for _, other in pairs(self.plans) do
            wipe(other.classes)
            wipe(other.players)
            other.aura = 0
        end
    end
    self:Send("CLEAR")
    self:SendSelf()
    self:Changed()
end

function Mod:RequestPlans()
    self:ScanGroup()
    self:Send("REQ")
    self:QueueSendSelf()
    self:Changed()
end

local function knows(known, index)
    return not next(known) or known[index] ~= nil
end

local function knownCount(known, order)
    if not next(known) then return #order end
    local count = 0
    for _, index in ipairs(order) do
        if known[index] then count = count + 1 end
    end
    return count
end

function Mod:AutoPlanners()
    local planners, fixed = {}, {}
    for _, paladin in ipairs(self:GetPaladins()) do
        if paladin.plan.heard and self:CanEdit(paladin.name) then
            planners[#planners + 1] = paladin
        else
            fixed[#fixed + 1] = paladin
        end
    end
    return planners, fixed
end

function Mod:HasAssignments()
    for _, paladin in ipairs(self:GetPaladins()) do
        if next(paladin.plan.classes) or (paladin.plan.aura or 0) > 0 then return true end
    end
    return false
end

local function pickFirst(wanted, known, taken)
    for _, index in ipairs(wanted) do
        if not taken[index] and knows(known, index) then
            taken[index] = true
            return index
        end
    end
end

function Mod:AutoAssign()
    local planners, fixed = self:AutoPlanners()
    if #planners == 0 then return end
    table.sort(planners, function(a, b)
        local ka, kb = knownCount(a.plan.known, BLESSING_ORDER), knownCount(b.plan.known, BLESSING_ORDER)
        if ka ~= kb then return ka < kb end
        if a.me ~= b.me then return a.me end
        return a.name < b.name
    end)

    local counts = self:ClassCounts()
    for classIndex, class in ipairs(CLASSES) do
        if (counts[classIndex] or 0) > 0 then
            local taken = {}
            for _, paladin in ipairs(fixed) do
                local given = paladin.plan.classes[classIndex]
                if given then taken[given] = true end
            end
            for _, paladin in ipairs(planners) do
                paladin.plan.classes[classIndex] = pickFirst(WANTED[class], paladin.plan.known, taken)
            end
        end
    end

    local takenAuras = {}
    for _, paladin in ipairs(fixed) do
        if (paladin.plan.aura or 0) > 0 then takenAuras[paladin.plan.aura] = true end
    end
    local auraOrder = {}
    for i, paladin in ipairs(planners) do auraOrder[i] = paladin end
    table.sort(auraOrder, function(a, b)
        local ka, kb = knownCount(a.plan.auraKnown, AURA_ORDER), knownCount(b.plan.auraKnown, AURA_ORDER)
        if ka ~= kb then return ka < kb end
        if a.me ~= b.me then return a.me end
        return a.name < b.name
    end)
    for _, paladin in ipairs(auraOrder) do
        local known = paladin.plan.auraKnown
        paladin.plan.aura = pickFirst(AURA_WANTED, known, takenAuras) or pickFirst(AURA_WANTED, known, {}) or 0
    end

    for _, paladin in ipairs(planners) do
        if paladin.me then
            self:QueueSendSelf()
        else
            self:Send("PASSIGN " .. paladin.name .. "@" .. classDigits(paladin.plan.classes))
            self:Send(string.format("AASSIGN %s %d", paladin.name, paladin.plan.aura))
        end
    end
    self:Changed()
end

local function parseRanks(numbers, slots)
    local known = {}
    numbers = numbers or ""
    for i = 1, slots do
        local rank = numbers:sub(i * 2 - 1, i * 2 - 1)
        if rank ~= "" and rank ~= "n" then
            local value = tonumber(rank, 16)
            if value and value > 0 then known[i] = value end
        end
    end
    return known
end

local function parseClasses(digits, into)
    wipe(into)
    digits = digits or ""
    for i = 1, #CLASSES do
        local b = tonumber(digits:sub(i, i))
        if b and BLESSINGS[b] then into[i] = b end
    end
end

function Mod:MayChange(sender, paladin)
    if paladin and (sender.name == paladin or unitMatches(sender.unit, paladin)) then return true end
    return self:IsLeader(sender)
end

function Mod:ApplyToMe(name, apply)
    if not self:IsMe(name) then return false end
    apply(self:OwnPlan())
    self:QueueSendSelf()
    return true
end

function Mod:OnCommReceived(_, message, distribution, senderName)
    if not self:IsActive() then return end
    message = safeString(message)
    senderName = safeString(senderName)
    if not (message and senderName) then return end
    if distribution ~= "PARTY" and distribution ~= "RAID" and distribution ~= "INSTANCE_CHAT"
        and distribution ~= "WHISPER" then
        return
    end
    if self:IsMe(senderName) then return end
    self:ScanGroup()
    local sender = self:FindMember(senderName)
    if not sender then return end
    local changed = self:HandleMessage(sender, message)
    if changed then self:Changed() end
end

function Mod:HandleMessage(sender, message)
    if message == "REQ" then
        self:QueueSendSelf()
        return false
    end

    local cmd = message:match("^(%u+)")
    if cmd == "SELF" then
        if sender.class ~= "PALADIN" then return false end
        local numbers, digits = message:match("^SELF ([0-9a-fn]*)@([0-9n]*)")
        if not numbers then return false end
        local plan = self:GetPlan(sender.name)
        plan.known = parseRanks(numbers, BLESSING_SLOTS)
        parseClasses(digits, plan.classes)
        plan.heard = true
        return true
    elseif cmd == "ASELF" then
        if sender.class ~= "PALADIN" then return false end
        local numbers, aura = message:match("^ASELF ([0-9a-fn]*)@([0-9n]*)")
        if not numbers then return false end
        local plan = self:GetPlan(sender.name)
        if not plan.heard then return false end
        plan.auraKnown = parseRanks(numbers, AURA_SLOTS)
        local a = tonumber(aura)
        plan.aura = (a and AURAS[a]) and a or 0
        return true
    elseif cmd == "ASSIGN" then
        local name, class, blessing = message:match("^ASSIGN (.+) (%d+) (%d+)$")
        class, blessing = tonumber(class), tonumber(blessing)
        if not (name and CLASSES[class] and self:MayChange(sender, name)) then return false end
        blessing = BLESSINGS[blessing] and blessing or nil
        if self:ApplyToMe(name, function(plan) plan.classes[class] = blessing end) then return true end
        self:GetPlan(name).classes[class] = blessing
        return true
    elseif cmd == "PASSIGN" then
        local name, digits = message:match("^PASSIGN (.+)@([0-9n]*)$")
        if not (name and self:MayChange(sender, name)) then return false end
        if self:ApplyToMe(name, function(plan) parseClasses(digits, plan.classes) end) then return true end
        parseClasses(digits, self:GetPlan(name).classes)
        return true
    elseif cmd == "MASSIGN" then
        local name, blessing = message:match("^MASSIGN (.+) (%d+)$")
        blessing = tonumber(blessing)
        if not (name and self:MayChange(sender, name)) then return false end
        blessing = BLESSINGS[blessing] and blessing or nil
        local function all(plan) for i = 1, #CLASSES do plan.classes[i] = blessing end end
        if self:ApplyToMe(name, all) then return true end
        all(self:GetPlan(name))
        return true
    elseif cmd == "AASSIGN" then
        local name, aura = message:match("^AASSIGN (.+) (%d+)$")
        aura = tonumber(aura)
        if not (name and self:MayChange(sender, name)) then return false end
        aura = AURAS[aura] and aura or 0
        if self:ApplyToMe(name, function(plan) plan.aura = aura end) then return true end
        self:GetPlan(name).aura = aura
        return true
    elseif cmd == "NASSIGN" then
        local changed = false
        for paladin, class, player, blessing in message:sub(9):gmatch("([^@ ]+) ([^@ ]+) ([^@ ]+) ([^@ ]+)") do
            paladin, player = unwireName(paladin), unwireName(player)
            class, blessing = tonumber(class), tonumber(blessing)
            if CLASSES[class] and self:MayChange(sender, paladin) then
                local member = self:FindMember(player)
                local key = member and member.name or player
                local choice = (blessing and BLESSINGS[blessing]) and {class, blessing} or nil
                if not self:ApplyToMe(paladin, function(plan) plan.players[key] = choice end) then
                    self:GetPlan(paladin).players[key] = choice
                end
                changed = true
            end
        end
        return changed
    elseif cmd == "CLEAR" then
        local function clear(plan)
            wipe(plan.classes)
            wipe(plan.players)
            if not message:find("SKIP", 1, true) then plan.aura = 0 end
        end
        if self:IsLeader(sender) then
            clear(self:OwnPlan())
            for _, plan in pairs(self.plans) do clear(plan) end
            self:QueueSendSelf()
        end
        return true
    end
    return false
end

function Mod:OnRosterChanged()
    local wasGrouped = self.grouped
    self.grouped = IsInGroup()
    self:ScanGroup()
    for name in pairs(self.plans) do
        if not self.memberByName[name] then self.plans[name] = nil end
    end
    if self.grouped and not wasGrouped then
        self:RequestPlans()
    end
    self:Changed()
end

function Mod:OnSpellsChanged()
    self:RefreshOwnKnown()
    if IsInGroup() then self:QueueSendSelf() end
    self:Changed()
end

function Mod:OnInitialize()
    self.plans = {}
end

function Mod:OnEnable()
    if not E:IsForeverClient() then return end
    self.plans = self.plans or {}
    self:RefreshOwnKnown()
    self:ScanGroup()
    local Comms = E:GetModule("Comms", true)
    if Comms then Comms:RegisterProtocol(PREFIX, self) end
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "OnRosterChanged")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnRosterChanged")
    self:RegisterEvent("SPELLS_CHANGED", "OnSpellsChanged")
    self.grouped = false
    self:OnRosterChanged()
end

function Mod:OnDisable()
    self:UnregisterAllEvents()
    local Comms = E:GetModule("Comms", true)
    if Comms then Comms:UnregisterProtocol(PREFIX) end
    if self.sendTimer then
        self.sendTimer:Cancel()
        self.sendTimer = nil
    end
    self.plans = {}
end
