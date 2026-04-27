local E, L, P = unpack(ART)

P.modules.RaidGroups = {
    enabled = true
}

local RaidGroups = E:NewModule("RaidGroups", "AceEvent-3.0")

local GetCursorPosition = GetCursorPosition
local GetRaidRosterInfo = GetRaidRosterInfo
local GetNumGroupMembers = GetNumGroupMembers
local InCombatLockdown = InCombatLockdown
local UnitAffectingCombat = UnitAffectingCombat
local UnitName = UnitName
local IsInRaid = IsInRaid
local SetRaidSubgroup = SetRaidSubgroup
local SwapRaidSubgroup = SwapRaidSubgroup
local strtrim = strtrim
local strfind = string.find
local strmatch = string.match
local strgmatch = string.gmatch
local strformat = string.format
local tinsert = table.insert
local tconcat = table.concat
local pairs = pairs
local ipairs = ipairs

local GROUP_COUNT = 8
local SLOTS_PER_GROUP = 5
local SLOT_W = 112
local SLOT_H = 20
local SLOT_GAP = 4
local NAME_ROW_H = 20
local EDITOR_W = 1080
local EDITOR_H = 600
local MAX_PROCESS_ATTEMPTS = 10

RaidGroups.GROUP_COUNT = GROUP_COUNT
RaidGroups.SLOTS_PER_GROUP = SLOTS_PER_GROUP
RaidGroups.SLOT_W = SLOT_W
RaidGroups.SLOT_H = SLOT_H
RaidGroups.SLOT_GAP = SLOT_GAP
RaidGroups.NAME_ROW_H = NAME_ROW_H
RaidGroups.EDITOR_W = EDITOR_W
RaidGroups.EDITOR_H = EDITOR_H

-- Utility
local function classColor(token)
    return E:ClassColorRGB(token)
end

local function colorize(name, r, g, b)
    return strformat("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, name or "")
end

local function stripColor(text)
    return E:StripColorCodes(text)
end

-- Expose for reuse by the editor
RaidGroups.classColor = classColor
RaidGroups.colorize = colorize
RaidGroups.stripColor = stripColor

-- Nicknames
local function nicknameModule()
    local mod = E:GetModule("Nicknames", true)
    if mod and mod:IsEnabled() and mod.db and mod.db.map then
        return mod
    end
end

function RaidGroups:DisplayName(realName)
    if not realName or realName == "" then
        return realName
    end
    local mod = nicknameModule()
    if not mod then
        return realName
    end
    local key = realName
    if not strfind(key, "-", 1, true) then
        key = realName .. "-" .. GetRealmName()
    end
    return mod.db.map[key] or realName
end

function RaidGroups:ResolveNickname(typed)
    if not typed or typed == "" then
        return typed
    end
    local mod = nicknameModule()
    if not mod then
        return typed
    end
    for realKey, nick in pairs(mod.db.map) do
        if nick == typed then
            local base, realm = strmatch(realKey, "^(.-)%-(.+)$")
            if realm and realm == GetRealmName() then
                return base
            end
            return realKey
        end
    end
    return typed
end

local function cursorOver(frame, mx, my)
    if not frame or not frame:IsShown() then
        return false
    end
    local l, r, t, b = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    if not (l and r and t and b) then
        return false
    end
    mx = mx or (select(1, GetCursorPosition()) / frame:GetEffectiveScale())
    my = my or (select(2, GetCursorPosition()) / frame:GetEffectiveScale())
    return mx >= l and mx <= r and my >= b and my <= t
end

-- Presets
function RaidGroups:GetPresets()
    local g = E:GetGlobal("RaidGroups")
    g.presets = g.presets or {}
    return g.presets
end

function RaidGroups:GetPresetByName(name)
    if not name then
        return nil
    end
    for i, preset in ipairs(self:GetPresets()) do
        if preset.name == name then
            return preset, i
        end
    end
end

function RaidGroups:SavePreset(name, dataString)
    name = name and strtrim(name) or ""
    if name == "" or not dataString then
        return false, L["RG_ErrorNameEmpty"]
    end
    local presets = self:GetPresets()
    local existing, idx = self:GetPresetByName(name)
    if existing then
        presets[idx] = {
            name = name,
            data = dataString
        }
    else
        tinsert(presets, {
            name = name,
            data = dataString
        })
    end
    E:SendMessage("ART_RAIDGROUPS_PRESETS_CHANGED", name)
    return true
end

function RaidGroups:DeletePreset(name)
    local _, idx = self:GetPresetByName(name)
    if not idx then
        return false
    end
    tremove(self:GetPresets(), idx)
    local presets = self:GetPresets()
    local nextName = (presets[idx] or presets[#presets] or {}).name
    E:SendMessage("ART_RAIDGROUPS_PRESETS_CHANGED", nextName)
    return true
end

function RaidGroups:RenamePreset(oldName, newName)
    newName = newName and strtrim(newName) or ""
    if newName == "" then
        return false
    end
    if self:GetPresetByName(newName) and newName ~= oldName then
        return false, L["RG_ErrorNameInUse"]
    end
    local preset = self:GetPresetByName(oldName)
    if not preset then
        return false
    end
    preset.name = newName
    -- Focus on the new name so both surfaces re-select it automatically
    E:SendMessage("ART_RAIDGROUPS_PRESETS_CHANGED", newName)
    return true
end

function RaidGroups:BulkImport(text)
    local errors = {}
    if not text or strtrim(text) == "" then
        return 0, {L["RG_BulkImportEmpty"]}
    end

    text = strtrim(text)
    -- tolerate wrapping quotes from copy/paste
    if #text > 1 and text:sub(1, 1) == '"' and text:sub(-1) == '"' then
        text = text:sub(2, -2)
    end

    local imported = 0
    local seenInBatch = {}
    local lineNum = 0

    for line in strgmatch(text, "[^\r\n]+") do
        lineNum = lineNum + 1
        local trimmed = strtrim(line)
        if trimmed ~= "" then
            local name, payload = strmatch(trimmed, "^(.-):(.*)$")
            if not (name and payload) then
                tinsert(errors, ("Line %d: missing ':'"):format(lineNum))
            else
                name = strtrim(name)
                payload = strtrim(payload)
                if name == "" then
                    tinsert(errors, ("Line %d: empty name"):format(lineNum))
                elseif seenInBatch[name] then
                    tinsert(errors, ("Line %d: '%s' duplicated in batch"):format(lineNum, name))
                else
                    local normalized, err = self:ValidateAndNormalizePresetString(payload)
                    if not normalized then
                        tinsert(errors, ("Line %d (%s): %s"):format(lineNum, name, err or "invalid"))
                    else
                        local ok, saveErr = self:SavePreset(name, normalized)
                        if ok then
                            imported = imported + 1
                            seenInBatch[name] = true
                        else
                            tinsert(errors, ("Line %d (%s): %s"):format(lineNum, name, saveErr or "save failed"))
                        end
                    end
                end
            end
        end
    end

    return imported, errors
end

function RaidGroups:BulkExportString()
    local out = {}
    for _, preset in ipairs(self:GetPresets()) do
        tinsert(out, preset.name .. ":" .. preset.data)
    end
    return tconcat(out, "\n")
end

function RaidGroups:ValidateAndNormalizePresetString(text)
    if type(text) ~= "string" then
        return nil, L["RG_InvalidString"]
    end

    local parts = {}
    for part in strgmatch(text, "([^;]+)") do
        tinsert(parts, part)
    end
    if #parts < 1 then
        return nil, L["RG_AtLeastOneGroup"]
    end
    if #parts > GROUP_COUNT then
        return nil, L["RG_TooManyGroups"]
    end

    local groups = {}
    for i, chunk in ipairs(parts) do
        local num, namesStr = strmatch(chunk, "^%s*Group(%d+):%s*(.*)%s*$")
        if not num then
            return nil, strformat(L["RG_MalformedGroup"], i)
        end
        num = tonumber(num)
        if num ~= i then
            return nil, strformat(L["RG_WrongGroupIndex"], i, num)
        end
        local names = {}
        for name in strgmatch(namesStr or "", "([^,]+)") do
            local clean = strtrim(name)
            if clean ~= "" then
                tinsert(names, E:NormalizeName(clean))
            end
        end
        if #names > SLOTS_PER_GROUP then
            return nil, strformat(L["RG_TooManyInGroup"], i)
        end
        while #names < SLOTS_PER_GROUP do
            tinsert(names, "")
        end
        groups[i] = names
    end

    -- pad missing groups
    for i = #groups + 1, GROUP_COUNT do
        local names = {}
        for _ = 1, SLOTS_PER_GROUP do
            tinsert(names, "")
        end
        groups[i] = names
    end

    local seen = {}
    for gi, names in ipairs(groups) do
        for _, name in ipairs(names) do
            if name ~= "" then
                if seen[name] then
                    return nil, strformat(L["RG_DuplicateName"], name)
                end
                seen[name] = true
            end
        end
    end

    local out = {}
    for i, names in ipairs(groups) do
        tinsert(out, ("Group%d: %s"):format(i, tconcat(names, ",")))
    end
    return tconcat(out, ";")
end

function RaidGroups:SerializeSlots(slots)
    local out = {}
    for g = 1, GROUP_COUNT do
        local names = {}
        for s = 1, SLOTS_PER_GROUP do
            local eb = slots[g][s]
            tinsert(names, eb.usedName or "")
        end
        tinsert(out, ("Group%d: %s"):format(g, tconcat(names, ",")))
    end
    return tconcat(out, ";")
end

-- Apply logic
function RaidGroups:ApplyGroups(list)
    if not IsInRaid() then
        E:Printf(L["RG_NotInRaid"])
        return
    end
    if InCombatLockdown() then
        E:Printf(L["RG_InCombat"])
        return
    end
    for i = 1, 40 do
        if UnitAffectingCombat("raid" .. i) then
            E:Printf(L["RG_RaidInCombat"])
            return
        end
    end

    local needGroup = {}
    local needPosInGroup = {}
    local lockedUnit = {}

    local RLName, _, RLGroup = GetRaidRosterInfo(1)
    local isRLfound = false
    for i = 1, 8 do
        local pos = 1
        for j = 1, 5 do
            local name = list[(i - 1) * 5 + j]
            if name == RLName then
                needGroup[name] = i
                needPosInGroup[name] = pos
                pos = pos + 1
                isRLfound = true
                break
            end
        end
        for j = 1, 5 do
            local name = list[(i - 1) * 5 + j]
            if name and name ~= RLName and UnitName(name) then
                needGroup[name] = i
                needPosInGroup[name] = pos
                pos = pos + 1
            end
        end
    end

    self._needGroup = needGroup
    self._needPosInGroup = needPosInGroup
    self._lockedUnit = lockedUnit
    self._groupsReady = false
    self._groupWithRL = isRLfound and 0 or RLGroup
    self._processAttempts = 0

    self:ProcessRoster()
end

function RaidGroups:_GiveUpProcessRoster(reason)
    self._needGroup = nil
    self._needPosInGroup = nil
    self._lockedUnit = nil
    self._processAttempts = 0
    if self._processTimer then
        self._processTimer:Cancel()
        self._processTimer = nil
    end
    E:Printf(L["RG_ApplyGaveUp"], reason or "too many attempts")
end

function RaidGroups:ProcessRoster()
    if InCombatLockdown() or (IsInRaid() and not E:HasBroadcastAuthority(UnitName("player"))) then
        self._needGroup = nil
        return
    end

    local needGroup = self._needGroup
    local needPosInGroup = self._needPosInGroup
    local lockedUnit = self._lockedUnit
    if not needGroup then
        return
    end

    self._processAttempts = (self._processAttempts or 0) + 1
    if self._processAttempts > MAX_PROCESS_ATTEMPTS then
        self:_GiveUpProcessRoster(L["RG_ApplyUnreachable"])
        return
    end

    local currentGroup, currentPos, nameToID, groupSize = {}, {}, {}, {}
    for i = 1, 8 do
        groupSize[i] = 0
    end

    for i = 1, GetNumGroupMembers() do
        local name, _, subgroup = GetRaidRosterInfo(i)
        if name then
            local checkName = name
            if not needGroup[checkName] then
                local bare = E:BareName(name)
                if bare ~= "" and bare ~= name and needGroup[bare] then
                    checkName = bare
                end
            end
            currentGroup[checkName] = subgroup
            nameToID[checkName] = i
            groupSize[subgroup] = groupSize[subgroup] + 1
            currentPos[checkName] = groupSize[subgroup]
        end
    end

    if not self._groupsReady then
        local waitForGroup = false
        for unit, group in pairs(needGroup) do
            if currentGroup[unit] and currentGroup[unit] ~= group and nameToID[unit] then
                if groupSize[group] < 5 then
                    SetRaidSubgroup(nameToID[unit], group)
                    waitForGroup = true
                end
            end
        end
        if waitForGroup then
            return
        end

        local setToSwap, waitForSwap = {}, false
        for unit, group in pairs(needGroup) do
            if not setToSwap[unit] and currentGroup[unit] and currentGroup[unit] ~= group and nameToID[unit] then
                local unitToSwap
                for unit2, group2 in pairs(currentGroup) do
                    if not setToSwap[unit2] and group2 == group and needGroup[unit2] ~= group2 and nameToID[unit2] then
                        unitToSwap = unit2
                        break
                    end
                end
                if unitToSwap then
                    SwapRaidSubgroup(nameToID[unit], nameToID[unitToSwap])
                    waitForSwap = true
                    setToSwap[unit] = true
                    setToSwap[unitToSwap] = true
                end
            end
        end
        if waitForSwap then
            return
        end

        self._groupsReady = true
    end

    do
        local setToSwap, waitForSwap = {}, false
        for unit, pos in pairs(needPosInGroup) do
            if not lockedUnit[unit] and currentPos[unit] and currentPos[unit] ~= pos and nameToID[unit] and
                nameToID[unit] ~= 1 and not setToSwap[unit] then
                local unitToSwap, unitToSwapBridge

                for unit2, pos2 in pairs(currentPos) do
                    if currentGroup[unit2] == currentGroup[unit] and pos2 == pos and nameToID[unit2] and nameToID[unit2] ~=
                        1 and not setToSwap[unit2] then
                        unitToSwap = unit2
                        break
                    end
                end

                for unit2, group2 in pairs(currentGroup) do
                    if group2 ~= currentGroup[unit] and nameToID[unit2] and nameToID[unit2] ~= 1 and
                        not setToSwap[unit2] then
                        unitToSwapBridge = unit2
                        break
                    end
                end

                if unitToSwap and unitToSwapBridge then
                    lockedUnit[unit] = true

                    SwapRaidSubgroup(nameToID[unit], nameToID[unitToSwapBridge])
                    SwapRaidSubgroup(nameToID[unitToSwapBridge], nameToID[unitToSwap])
                    SwapRaidSubgroup(nameToID[unit], nameToID[unitToSwapBridge])

                    waitForSwap = true
                    setToSwap[unit] = true
                    setToSwap[unitToSwap] = true
                    setToSwap[unitToSwapBridge] = true
                end
            end
        end
        if waitForSwap then
            return
        end
    end

    self._needGroup = nil
    self._processAttempts = 0
    if self._processTimer then
        self._processTimer:Cancel()
        self._processTimer = nil
    end
end

function E:OpenRaidGroups()
    if not self:EnsureOptions() then
        return
    end
    local mod = self:GetModule("RaidGroups", true)
    if mod and mod.OpenEditor then
        mod:OpenEditor()
    end
end

function E:ToggleRaidGroups()
    if not self:EnsureOptions() then
        return
    end
    local mod = self:GetModule("RaidGroups", true)
    if mod and mod.ToggleEditor then
        mod:ToggleEditor()
    end
end

function RaidGroups:OnEnable()
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "OnRosterUpdate")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnRegenEnabled")
end

function RaidGroups:OnDisable()
    if self._processTimer then
        self._processTimer:Cancel()
        self._processTimer = nil
    end
    -- If the editor is open it will close itself on ART_RAIDGROUPS_DISABLED
    E:SendMessage("ART_RAIDGROUPS_DISABLED")
end

function RaidGroups:OnRegenEnabled()
    if self._needGroup then
        self:ProcessRoster()
    end
end

function RaidGroups:OnRosterUpdate()
    if InCombatLockdown() or not self._needGroup then
        return
    end
    if self._processTimer then
        self._processTimer:Cancel()
    end
    self._processTimer = C_Timer.NewTimer(0.6, function()
        RaidGroups._processTimer = nil
        RaidGroups:ProcessRoster()
    end)
end

RaidGroups:RegisterMessage("ART_PROFILE_CHANGED", function()
    if RaidGroups:IsEnabled() then
        E:InvalidateRosterCache()
    end
end)

_G.ART = _G.ART or {}
E:MountMethods(_G.ART, {
    GetRaidGroupPresets = function()
        if not RaidGroups:IsEnabled() then
            return {}
        end
        local out = {}
        for i, preset in ipairs(RaidGroups:GetPresets()) do
            out[i] = {
                name = preset.name,
                data = preset.data
            }
        end
        return out
    end,
    GetRaidGroupPreset = function(_, name)
        if not RaidGroups:IsEnabled() or not name then
            return nil
        end
        local preset = RaidGroups:GetPresetByName(name)
        if not preset then
            return nil
        end
        return {
            name = preset.name,
            data = preset.data
        }
    end
}, {
    noClobber = true
})
