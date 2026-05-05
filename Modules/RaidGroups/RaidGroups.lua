local E, L = unpack(ART)

E:RegisterModuleDefaults("RaidGroups", {
    enabled = true
})

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
local strlower = string.lower
local strmatch = string.match
local strgmatch = string.gmatch
local strformat = string.format
local strsub = string.sub
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
    local normalized, err = self:ValidateAndNormalizePresetString(dataString)
    if not normalized then
        return false, err
    end
    local presets = self:GetPresets()
    local existing, idx = self:GetPresetByName(name)
    if existing then
        presets[idx] = {
            name = name,
            data = normalized
        }
    else
        tinsert(presets, {
            name = name,
            data = normalized
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

local PRESET_STRING_VERSION = "ART_RG1"

local function emptyPresetGroups()
    local groups = {}
    for g = 1, GROUP_COUNT do
        local slots = {}
        for s = 1, SLOTS_PER_GROUP do
            slots[s] = ""
        end
        groups[g] = slots
    end
    return groups
end

local function cleanImportText(text)
    text = strtrim(text or "")
    if strsub(text, 1, 3) == "\239\187\191" then
        text = strsub(text, 4)
    end
    if #text > 1 and strsub(text, 1, 1) == '"' and strsub(text, -1) == '"' then
        text = strsub(text, 2, -2)
    end
    return text
end

local function canPresetString()
    return C_EncodingUtil and C_EncodingUtil.EncodeBase64 and C_EncodingUtil.DecodeBase64
end

local function encodePayload(payload)
    if not canPresetString() then
        return nil, L["RG_PresetCodecUnsupported"]
    end
    local ok, encoded = pcall(C_EncodingUtil.EncodeBase64, payload or "")
    if not ok or type(encoded) ~= "string" or encoded == "" then
        return nil, L["RG_PresetEncodeFailed"]
    end
    return PRESET_STRING_VERSION .. ":" .. encoded
end

local function decodePayload(code)
    code = cleanImportText(code)
    local encoded = strmatch(code, "^" .. PRESET_STRING_VERSION .. ":(.+)$")
    if not encoded then
        return nil, strformat(L["RG_InvalidPresetCode"], PRESET_STRING_VERSION)
    end
    if not canPresetString() then
        return nil, L["RG_PresetCodecUnsupported"]
    end
    local ok, decoded = pcall(C_EncodingUtil.DecodeBase64, encoded)
    if not ok or type(decoded) ~= "string" or decoded == "" then
        return nil, L["RG_PresetDecodeFailed"]
    end
    return decoded
end

local function splitDelimited(line, delim)
    local out = {}
    local start = 1
    while true do
        local pos = strfind(line, delim, start, true)
        if not pos then
            tinsert(out, strtrim(strsub(line, start)))
            break
        end
        tinsert(out, strtrim(strsub(line, start, pos - 1)))
        start = pos + #delim
    end
    return out
end

local function detectDelimiter(line)
    if strfind(line, "\t", 1, true) then
        return "\t"
    end
    if strfind(line, ",", 1, true) then
        return ","
    end
    if strfind(line, "|", 1, true) then
        return "|"
    end
    if strfind(line, ";", 1, true) then
        return ";"
    end
end

local function normalizeHeader(cell)
    cell = strlower(strtrim(cell or ""))
    cell = cell:gsub("[%s_%-%./]+", "")
    if cell == "preset" or cell == "presettitle" or cell == "presetname" or cell == "title" then
        return "preset"
    end
    if cell == "group" or cell == "grp" then
        return "group"
    end
    if cell == "slot" or cell == "pos" or cell == "position" or cell == "grouppos" or cell == "groupposition" or
        cell == "positioningroup" then
        return "slot"
    end
    if cell == "character" or cell == "char" or cell == "player" or cell == "characterrealm" or cell == "playerrealm" or
        cell == "name" then
        return "character"
    end
end

local function headerMapFor(cols)
    local map = {}
    for i, col in ipairs(cols) do
        local key = normalizeHeader(col)
        if key and not map[key] then
            map[key] = i
        end
    end
    if map.group and map.slot and map.character then
        return map
    end
end

local function normalizeGroups(groups)
    local normalized = emptyPresetGroups()
    local seen = {}
    local hasAny = false

    for groupNum = 1, GROUP_COUNT do
        for slotNum = 1, SLOTS_PER_GROUP do
            local name = groups[groupNum] and groups[groupNum][slotNum] or ""
            name = strtrim(name or "")
            if name ~= "" then
                name = E:NormalizeName(name)
                if seen[name] then
                    return nil, strformat(L["RG_DuplicateName"], name)
                end
                seen[name] = true
                hasAny = true
            end
            normalized[groupNum][slotNum] = name
        end
    end

    if not hasAny then
        return nil, L["RG_AtLeastOneGroup"]
    end

    return normalized
end

local function addImportRow(buckets, order, title, groupNum, slotNum, character, lineNum, errors)
    if not groupNum or groupNum < 1 or groupNum > GROUP_COUNT then
        tinsert(errors, ("Line %d: group must be 1-%d"):format(lineNum, GROUP_COUNT))
        return
    end
    if not slotNum or slotNum < 1 or slotNum > SLOTS_PER_GROUP then
        tinsert(errors, ("Line %d: slot must be 1-%d"):format(lineNum, SLOTS_PER_GROUP))
        return
    end
    character = strtrim(character or "")
    if character == "" then
        return
    end

    title = strtrim(title or "")
    local key = title ~= "" and title or "\001"
    local bucket = buckets[key]
    if not bucket then
        bucket = {
            name = title,
            groups = emptyPresetGroups(),
            assigned = {}
        }
        buckets[key] = bucket
        tinsert(order, key)
    end

    bucket.assigned[groupNum] = bucket.assigned[groupNum] or {}
    if bucket.assigned[groupNum][slotNum] then
        tinsert(errors, ("Line %d: duplicate group %d slot %d"):format(lineNum, groupNum, slotNum))
        return
    end
    bucket.assigned[groupNum][slotNum] = true
    bucket.groups[groupNum][slotNum] = character
end

local function parsePayloadRows(text)
    local errors = {}
    local buckets, order = {}, {}
    local headerMap
    local currentTitle = ""
    local lineNum = 0

    for line in strgmatch(text or "", "[^\r\n]+") do
        lineNum = lineNum + 1
        local trimmed = strtrim(line)
        if trimmed ~= "" then
            local directiveTitle = strmatch(trimmed, "^[Pp]reset%s*[:=]%s*(.-)%s*$") or
                strmatch(trimmed, "^[Tt]itle%s*[:=]%s*(.-)%s*$")
            if directiveTitle then
                currentTitle = strtrim(directiveTitle)
            else
                local delim = detectDelimiter(trimmed)
                if delim then
                    local cols = splitDelimited(trimmed, delim)
                    local maybeHeader = headerMapFor(cols)
                    if maybeHeader then
                        headerMap = maybeHeader
                    else
                        local title, groupRaw, slotRaw, character
                        if headerMap then
                            title = headerMap.preset and cols[headerMap.preset] or currentTitle
                            groupRaw = cols[headerMap.group]
                            slotRaw = cols[headerMap.slot]
                            character = cols[headerMap.character]
                        elseif #cols >= 4 then
                            if tonumber(cols[1]) then
                                groupRaw, slotRaw, character, title = cols[1], cols[2], cols[3], cols[4]
                            else
                                title, groupRaw, slotRaw, character = cols[1], cols[2], cols[3], cols[4]
                            end
                            if title == "" then
                                title = currentTitle
                            end
                        elseif #cols >= 3 then
                            title = currentTitle
                            groupRaw, slotRaw, character = cols[1], cols[2], cols[3]
                        end

                        if groupRaw and slotRaw and character then
                            addImportRow(buckets, order, title, tonumber(groupRaw), tonumber(slotRaw), character, lineNum,
                                errors)
                        else
                            tinsert(errors, ("Line %d: expected group, slot, character"):format(lineNum))
                        end
                    end
                else
                    tinsert(errors, ("Line %d: expected tab, comma, pipe, or semicolon separated columns"):format(lineNum))
                end
            end
        end
    end

    if #order == 0 then
        return nil, errors
    end

    local imports = {}
    for _, key in ipairs(order) do
        local bucket = buckets[key]
        local groups, err = normalizeGroups(bucket.groups)
        if groups then
            tinsert(imports, {
                name = bucket.name,
                groups = groups
            })
        else
            tinsert(errors, ("%s: %s"):format(bucket.name ~= "" and bucket.name or (L["RG_DefaultPresetName"] or "Preset"),
                err or "invalid"))
        end
    end

    return imports, errors
end

local function appendPayloadRows(out, groups, presetName, includePreset)
    for groupNum = 1, GROUP_COUNT do
        for slotNum = 1, SLOTS_PER_GROUP do
            local name = groups[groupNum] and groups[groupNum][slotNum] or ""
            if name and name ~= "" then
                if includePreset then
                    tinsert(out, ("%s,%d,%d,%s"):format(presetName or "", groupNum, slotNum, name))
                else
                    tinsert(out, ("%d,%d,%s"):format(groupNum, slotNum, name))
                end
            end
        end
    end
end

local function encodeGroups(groups, presetName, includePreset)
    local out = {}
    if includePreset then
        tinsert(out, "preset,group,slot,character")
        appendPayloadRows(out, groups, presetName, true)
    else
        if presetName and presetName ~= "" then
            tinsert(out, "title=" .. presetName)
        end
        tinsert(out, "group,slot,character")
        appendPayloadRows(out, groups, nil, false)
    end
    return encodePayload(tconcat(out, "\n"))
end

function RaidGroups:NextDefaultPresetName(reserved)
    reserved = reserved or {}
    local base = L["RG_DefaultPresetName"] or "Preset"
    local i = 1
    local name = ("%s %d"):format(base, i)
    while self:GetPresetByName(name) or reserved[name] do
        i = i + 1
        name = ("%s %d"):format(base, i)
    end
    reserved[name] = true
    return name
end

function RaidGroups:ParsePresetImportString(text)
    text = cleanImportText(text)
    if text == "" then
        return nil, {L["RG_BulkImportEmpty"]}
    end

    text = text:gsub("%s+", "")
    local payload, decodeErr = decodePayload(text)
    if not payload then
        return nil, {decodeErr or L["RG_InvalidString"]}
    end

    local imports, errors = parsePayloadRows(payload)
    if not imports or #imports == 0 then
        return nil, errors or {L["RG_InvalidString"]}
    end
    return imports, errors or {}
end

function RaidGroups:PresetStringToGroups(text)
    local imports, errors = self:ParsePresetImportString(text)
    if imports and #imports == 1 then
        return imports[1].groups
    end
    if imports and #imports > 1 then
        return nil, L["RG_OnePresetOnly"]
    end
    return nil, errors and errors[1] or L["RG_InvalidString"]
end

function RaidGroups:BulkImport(text)
    local imports, errors = self:ParsePresetImportString(text)
    errors = errors or {}
    if not imports or #imports == 0 then
        return 0, (#errors > 0 and errors) or {L["RG_BulkImportEmpty"]}
    end

    local imported = 0
    local usedNames = {}
    local reservedAutoNames = {}

    for _, item in ipairs(imports) do
        local name = strtrim(item.name or "")
        if name == "" then
            name = self:NextDefaultPresetName(reservedAutoNames)
        elseif usedNames[name] then
            tinsert(errors, ("'%s' duplicated in batch"):format(name))
            name = nil
        end

        if name then
            local data, encodeErr = encodeGroups(item.groups)
            if not data then
                tinsert(errors, ("%s: %s"):format(name, encodeErr or L["RG_PresetEncodeFailed"]))
            else
                local ok, saveErr = self:SavePreset(name, data)
                if ok then
                    imported = imported + 1
                    usedNames[name] = true
                else
                    tinsert(errors, ("%s: %s"):format(name, saveErr or "save failed"))
                end
            end
        end
    end

    return imported, errors
end

function RaidGroups:ExportPresetString(preset)
    if type(preset) == "string" then
        preset = self:GetPresetByName(preset)
    end
    if not preset or not preset.data then
        return ""
    end
    local groups, err = self:PresetStringToGroups(preset.data)
    if not groups then
        return err or ""
    end
    local encoded = encodeGroups(groups, preset.name)
    return encoded or ""
end

function RaidGroups:BulkExportString()
    local out = {"preset,group,slot,character"}
    for _, preset in ipairs(self:GetPresets()) do
        local groups = self:PresetStringToGroups(preset.data)
        if groups then
            appendPayloadRows(out, groups, preset.name, true)
        end
    end
    local encoded = encodePayload(tconcat(out, "\n"))
    return encoded or ""
end

function RaidGroups:ValidateAndNormalizePresetString(text)
    if type(text) ~= "string" then
        return nil, L["RG_InvalidString"]
    end

    local groups, err = self:PresetStringToGroups(text)
    if not groups then
        return nil, err
    end
    return encodeGroups(groups)
end

function RaidGroups:SerializeSlots(slots)
    local groups = emptyPresetGroups()
    for g = 1, GROUP_COUNT do
        for s = 1, SLOTS_PER_GROUP do
            local eb = slots[g][s]
            groups[g][s] = eb.usedName or ""
        end
    end
    local normalized = normalizeGroups(groups)
    return encodeGroups(normalized or groups)
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
    if InCombatLockdown() then
        E:RunWhenOutOfCombat("RaidGroups:ProcessRoster", function()
            if self:IsEnabled() and self._needGroup then
                self:ProcessRoster()
            end
        end)
        return
    end

    if IsInRaid() and not E:HasBroadcastAuthority(UnitName("player")) then
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
end

function RaidGroups:OnDisable()
    if self._processTimer then
        self._processTimer:Cancel()
        self._processTimer = nil
    end
    E:CancelRunWhenOutOfCombat("RaidGroups:ProcessRoster")
    -- If the editor is open it will close itself on ART_RAIDGROUPS_DISABLED
    E:SendMessage("ART_RAIDGROUPS_DISABLED")
end

function RaidGroups:OnRosterUpdate()
    if not self._needGroup then
        return
    end
    if InCombatLockdown() then
        E:RunWhenOutOfCombat("RaidGroups:ProcessRoster", function()
            if self:IsEnabled() and self._needGroup then
                self:ProcessRoster()
            end
        end)
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
