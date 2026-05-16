local E, L = unpack(ART)

local SHARING_VERSION = "ART2"

local function canShare()
    return C_EncodingUtil and C_EncodingUtil.SerializeCBOR and C_EncodingUtil.CompressString and
               C_EncodingUtil.EncodeBase64 and C_EncodingUtil.DecodeBase64 and C_EncodingUtil.DecompressString and
               C_EncodingUtil.DeserializeCBOR
end

local excludedModules = {
    ["Nicknames"] = true,
    ["Notes"] = true
}

local function isPlainTable(v)
    return type(v) == "table"
end

local function validateAppearance(data)
    if not isPlainTable(data) then
        return false, "not a table"
    end
    for _, field in ipairs({"colors", "opacity", "fonts", "textures"}) do
        if data[field] ~= nil and type(data[field]) ~= "table" then
            return false, field .. " must be a table"
        end
    end
    return true
end

local function validateModules(data)
    if not isPlainTable(data) then
        return false, "not a table"
    end
    for modName, modData in pairs(data) do
        if type(modName) ~= "string" or type(modData) ~= "table" then
            return false, "entries must be [string] = table"
        end
    end
    return true
end

local function validateRaidGroups(data)
    if not isPlainTable(data) then
        return false, "not a table"
    end
    for _, p in ipairs(data) do
        if type(p) ~= "table" or type(p.name) ~= "string" or type(p.data) ~= "string" then
            return false, "each preset needs a string name and data"
        end
        if p.note ~= nil and type(p.note) ~= "string" then
            return false, "preset note must be a string"
        end
    end
    return true
end

local function validateNicknames(data)
    if not isPlainTable(data) then
        return false, "not a table"
    end
    if data.myNickname ~= nil and type(data.myNickname) ~= "string" then
        return false, "myNickname must be a string"
    end
    if data.integrations ~= nil and type(data.integrations) ~= "table" then
        return false, "integrations must be a table"
    end
    if data.map ~= nil then
        if type(data.map) ~= "table" then
            return false, "map must be a table"
        end
        for character, nickname in pairs(data.map) do
            if type(character) ~= "string" or type(nickname) ~= "string" then
                return false, "map entries must be [string] = string"
            end
        end
    end
    return true
end

local function validateNotes(data)
    if not isPlainTable(data) then
        return false, "not a table"
    end
    if data.slots ~= nil then
        if type(data.slots) ~= "table" then
            return false, "slots must be a table"
        end
        for i, slot in ipairs(data.slots) do
            if type(slot) ~= "table" then
                return false, "slot " .. i .. " must be a table"
            end
            if slot.name ~= nil and type(slot.name) ~= "string" then
                return false, "slot " .. i .. ".name must be a string"
            end
            if slot.text ~= nil and type(slot.text) ~= "string" then
                return false, "slot " .. i .. ".text must be a string"
            end
            if slot.display ~= nil and type(slot.display) ~= "table" then
                return false, "slot " .. i .. ".display must be a table"
            end
        end
    end
    if data.display ~= nil and type(data.display) ~= "table" then
        return false, "display must be a table"
    end
    return true
end

E.sharingCategories = {{
    key = "appearance",
    version = 1,
    label = "Appearance",
    desc = "Appearance_Desc",
    validate = validateAppearance,
    export = function(profile)
        return profile.cosmetic and CopyTable(profile.cosmetic) or nil
    end,
    import = function(profile, data)
        profile.cosmetic = CopyTable(data)
    end
}, {
    key = "general",
    version = 1,
    label = "General",
    desc = "General_Desc",
    validate = isPlainTable,
    export = function(profile)
        return profile.general and CopyTable(profile.general) or nil
    end,
    import = function(profile, data)
        profile.general = CopyTable(data)
    end
}, {
    key = "modules",
    version = 1,
    label = "ModuleSettings",
    desc = "ModuleSettings_Desc",
    validate = validateModules,
    export = function(profile)
        if not profile.modules then
            return nil
        end
        local out = {}
        for modName, modData in pairs(profile.modules) do
            if not excludedModules[modName] then
                out[modName] = CopyTable(modData)
            end
        end
        return next(out) and out or nil
    end,
    import = function(profile, data)
        profile.modules = profile.modules or {}
        for modName, modData in pairs(data) do
            profile.modules[modName] = CopyTable(modData)
        end
    end
}, {
    key = "nicknames",
    version = 1,
    label = "NicknameSettings",
    desc = "NicknameSettings_Desc",
    validate = validateNicknames,
    export = function(profile)
        local nm = profile.modules and profile.modules.Nicknames
        if not nm then
            return nil
        end
        return {
            enabled = nm.enabled,
            myNickname = nm.myNickname,
            map = nm.map and CopyTable(nm.map) or nil,
            integrations = nm.integrations and CopyTable(nm.integrations) or nil
        }
    end,
    import = function(profile, data)
        profile.modules = profile.modules or {}
        profile.modules.Nicknames = profile.modules.Nicknames or {}
        local nm = profile.modules.Nicknames

        if data.enabled ~= nil then
            nm.enabled = data.enabled
        end

        if data.myNickname ~= nil then
            nm.myNickname = data.myNickname
        end
        if data.integrations then
            nm.integrations = CopyTable(data.integrations)
        end
        if data.map ~= nil then
            nm.map = CopyTable(data.map)
        end
    end
}, {
    key = "notes",
    version = 1,
    label = "Notes",
    desc = "NoteSlots_Desc",
    validate = validateNotes,
    export = function(profile)
        local n = profile.modules and profile.modules.Notes
        if not n then
            return nil
        end
        return CopyTable(n)
    end,
    import = function(profile, data)
        profile.modules = profile.modules or {}
        profile.modules.Notes = CopyTable(data)
    end
}, {
    key = "raidgroups",
    version = 1,
    label = "RaidGroupPresets",
    desc = "RaidGroupPresets_Desc",
    validate = validateRaidGroups,
    export = function(profile)
        local g = E.db.global.modules and E.db.global.modules.RaidGroups
        if not g or not g.presets or #g.presets == 0 then
            return nil
        end
        return CopyTable(g.presets)
    end,
    import = function(profile, data)
        E.db.global.modules = E.db.global.modules or {}
        E.db.global.modules.RaidGroups = E.db.global.modules.RaidGroups or {}
        E.db.global.modules.RaidGroups.presets = E.db.global.modules.RaidGroups.presets or {}

        local presets = E.db.global.modules.RaidGroups.presets
        local byName = {}
        for i, p in ipairs(presets) do
            byName[p.name] = i
        end
        for _, p in ipairs(data) do
            if p.name and p.data then
                if byName[p.name] then
                    presets[byName[p.name]] = CopyTable(p)
                else
                    table.insert(presets, CopyTable(p))
                    byName[p.name] = #presets
                end
            end
        end
        E:SendMessage("ART_RAIDGROUPS_PRESETS_CHANGED")
    end
}}

-- Export

function E:GetExportString(selectedCategories)
    if not canShare() then
        E:Printf(L["SharingUnsupported"])
        return ""
    end

    local categories = {}
    for _, cat in ipairs(self.sharingCategories) do
        if not selectedCategories or selectedCategories[cat.key] then
            local value = cat.export(E.db.profile)
            if value ~= nil then
                categories[cat.key] = {
                    v = cat.version or 1,
                    data = value
                }
            end
        end
    end

    local ok, result = pcall(function()
        local payload = {
            version = SHARING_VERSION,
            categories = categories
        }
        local serialized = C_EncodingUtil.SerializeCBOR(payload)
        local compressed = C_EncodingUtil.CompressString(serialized, Enum.CompressionMethod.Deflate)
        local encoded = C_EncodingUtil.EncodeBase64(compressed)
        return SHARING_VERSION .. ":" .. encoded
    end)

    if not ok then
        E:Printf(L["ExportFailed"], result)
        return ""
    end
    return result
end

-- Import

function E:VerifyImportString(str)
    if type(str) ~= "string" or str == "" then
        return nil
    end
    if not canShare() then
        return nil
    end

    local version, encoded = str:match("^(%w+):(.+)$")
    if version ~= SHARING_VERSION then
        return nil
    end

    local ok, result = pcall(function()
        local decoded = C_EncodingUtil.DecodeBase64(encoded)
        local decompressed = C_EncodingUtil.DecompressString(decoded, Enum.CompressionMethod.Deflate)
        return C_EncodingUtil.DeserializeCBOR(decompressed)
    end)

    if not ok or type(result) ~= "table" or result.version ~= SHARING_VERSION then
        return nil
    end
    if type(result.categories) ~= "table" then
        return nil
    end
    return result
end

local function switchProfileSilently(target)
    E.db.UnregisterCallback(E, "OnProfileChanged")
    local ok, err = pcall(E.db.SetProfile, E.db, target)
    E.db.RegisterCallback(E, "OnProfileChanged", "OnProfileChanged")
    if not ok then
        E:Printf(L["ImportProfileSwitchFailed"], target, err or "?")
    end
    return ok
end

function E:ImportProfile(str, profileName, selectedCategories)
    local data = E:VerifyImportString(str)
    if not data or not data.categories then
        E:Printf(L["ImportInvalid"])
        return false
    end

    if profileName and strtrim(profileName) ~= "" then
        local target = strtrim(profileName)
        if target ~= E.db:GetCurrentProfile() then
            if not switchProfileSilently(target) then
                return false
            end
        end
    end

    for _, cat in ipairs(self.sharingCategories) do
        local include = not selectedCategories or selectedCategories[cat.key]
        local payload = data.categories[cat.key]
        if include and payload ~= nil then
            if type(payload) ~= "table" or payload.data == nil then
                E:Warn("Import: skipping '%s' (malformed payload).", cat.key)
            elseif (payload.v or 1) ~= (cat.version or 1) then
                E:Warn("Import: skipping '%s' (version %s, expected %s).", cat.key, tostring(payload.v),
                    tostring(cat.version or 1))
            else
                local ok, err = true, nil
                if cat.validate then
                    ok, err = cat.validate(payload.data)
                end
                if not ok then
                    E:Warn("Import: skipping '%s' (%s).", cat.key, err or "failed validation")
                else
                    local importOk, importErr = pcall(cat.import, E.db.profile, payload.data)
                    if not importOk then
                        E:Warn("Import: '%s' raised: %s", cat.key, importErr)
                    end
                end
            end
        end
    end

    E:OnProfileChanged()

    return true
end

-- Generic sharing

local MODULE_SHARE_COMM_PREFIX = "ART_SHARE"
local MODULE_SHARE_CHAT_LINK_PREFIX = "garrmission:artshare-"

local moduleShareTypes = {}
local moduleShareCache = {}
local moduleShareHooked = false
local moduleShareChatFiltersInstalled = false
local moduleShareCommRegistered = false

local function cleanShareText(text)
    text = strtrim(tostring(text or ""))
    if strsub(text, 1, 3) == "\239\187\191" then
        text = strsub(text, 4)
    end
    if #text > 1 and strsub(text, 1, 1) == '"' and strsub(text, -1) == '"' then
        text = strsub(text, 2, -2)
    end
    return text
end

local function shareChatType()
    if not IsInGroup() then
        return nil
    end
    if IsInRaid() then
        return "RAID"
    end
    return "PARTY"
end

local function sendShareChatMessage(message, chatType)
    if C_ChatInfo and C_ChatInfo.SendChatMessage then
        C_ChatInfo.SendChatMessage(message, chatType)
    else
        SendChatMessage(message, chatType)
    end
end

local function sanitizeLinkLabel(label, fallback)
    label = E:SafeString(label) or fallback or "ART Share"
    label = label:gsub("[|%[%]]", "")
    if #label > 52 then
        label = strsub(label, 1, 49) .. "..."
    end
    return label
end

local function stripChatCodes(text)
    text = tostring(text or "")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    return text
end

local function playerShareKeys()
    local name, realm = UnitFullName("player")
    name = name or UnitName("player") or "player"
    if not realm or realm == "" then
        realm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName()
        realm = tostring(realm or ""):gsub("%s+", "")
    end
    return name .. "+" .. realm, name .. "-" .. realm
end

local function normalizeShareSender(sender)
    if not sender or sender == "" then
        return nil
    end
    local name, realm = UnitFullName(sender)
    if not name then
        name, realm = tostring(sender):match("^([^%-]+)%-(.+)$")
    end
    name = name or tostring(sender)
    if not realm or realm == "" or #realm < 3 then
        local _, playerRealm = UnitFullName("player")
        realm = playerRealm
    end
    if not realm or realm == "" then
        realm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName()
        realm = tostring(realm or ""):gsub("%s+", "")
    end
    return name .. "-" .. realm
end

local function storeShareCache(typeKey, senderFull, label, data, senderDisplay)
    if not (typeKey and senderFull and label and type(data) == "table") then
        return
    end
    moduleShareCache[typeKey] = moduleShareCache[typeKey] or {}
    moduleShareCache[typeKey][senderFull] = moduleShareCache[typeKey][senderFull] or {}
    moduleShareCache[typeKey][senderFull][label] = {
        data = data,
        label = label,
        sender = senderDisplay or senderFull,
        expires = GetTime() + 600
    }
end

local function dispatchSharedImport(typeKey, data, sender, source)
    local cfg = moduleShareTypes[typeKey]
    if not cfg then
        E:Printf("|cffff4040%s|r", L["SharingUnknownType"] or "Unknown share type.")
        return
    end
    if cfg.sanitize then
        data = cfg.sanitize(data)
    end
    if type(data) ~= "table" then
        E:Printf("|cffff4040%s|r", L["ImportInvalid"])
        return
    end
    E:ShowShareImportPopup(typeKey, data, sender, source)
end

local function evalShareOpt(v, ...)
    if type(v) == "function" then
        local ok, result = pcall(v, ...)
        if ok then
            return result
        end
        return nil
    end
    return v
end

local function defaultShareImportText(cfg, data, sender)
    local name = evalShareOpt(cfg.getImportName, data, sender) or cfg.label or "shared data"
    if sender and sender ~= "" then
        return (L["SharingImportConfirmFrom"] or "Import %s from %s?"):format(name, sender)
    end
    return (L["SharingImportConfirm"] or "Import %s?"):format(name)
end

local function runShareImportCallback(typeKey, data, sender, source)
    local cfg = moduleShareTypes[typeKey]
    if cfg and cfg.onImport then
        cfg.onImport(data, sender, source)
    end
end

function E:ShowShareImportPopup(typeKey, data, sender, source)
    local cfg = moduleShareTypes[typeKey]
    if not cfg then
        return
    end

    local title = evalShareOpt(cfg.confirmTitle, data, sender, source) or cfg.label or (L["Import"] or "Import")
    local text = evalShareOpt(cfg.confirmText, data, sender, source) or defaultShareImportText(cfg, data, sender)
    local function accept()
        runShareImportCallback(typeKey, data, sender, source)
    end

    if E.Confirm then
        E:Confirm({
            key = "ART_SHARE_IMPORT_" .. typeKey,
            title = title,
            text = text,
            onAccept = accept
        })
        return
    end

    StaticPopupDialogs.ART_SHARE_IMPORT_CONFIRM = StaticPopupDialogs.ART_SHARE_IMPORT_CONFIRM or {
        button1 = ACCEPT or OKAY,
        button2 = CANCEL,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
        OnAccept = function(_, payload)
            if payload and payload.accept then
                payload.accept()
            end
        end
    }
    StaticPopupDialogs.ART_SHARE_IMPORT_CONFIRM.text = text
    StaticPopup_Show("ART_SHARE_IMPORT_CONFIRM", nil, nil, {
        accept = accept
    })
end

local function installModuleShareChatFilters()
    if moduleShareChatFiltersInstalled then
        return
    end
    local addFilter = ChatFrame_AddMessageEventFilter or (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter)
    if not addFilter then
        return
    end
    moduleShareChatFiltersInstalled = true

    local function filterFunc(chatFrame, event, msg, player, l, cs, t, flag, channelId, ...)
        if flag == "GM" or flag == "DEV" or (event == "CHAT_MSG_CHANNEL" and type(channelId) == "number" and channelId > 0) then
            return
        end

        local newMsg = ""
        local remaining = msg or ""
        local found = false
        while true do
            local start, finish, typeKey, senderKey, displayName =
                remaining:find("%[ART: ([^:]+): ([^%s]+) %- ([^%]]+)%]")
            if not start then
                newMsg = newMsg .. remaining
                break
            end

            newMsg = newMsg .. remaining:sub(1, start - 1)
            typeKey = stripChatCodes(typeKey)
            senderKey = stripChatCodes(senderKey)
            displayName = stripChatCodes(displayName)

            if moduleShareTypes[typeKey] then
                local link = ("|cff1784d1|H%s%s-%s|h[%s]|h|r"):format(MODULE_SHARE_CHAT_LINK_PREFIX, typeKey, senderKey,
                    displayName)
                newMsg = newMsg .. link
                found = true
            else
                newMsg = newMsg .. remaining:sub(start, finish)
            end
            remaining = remaining:sub(finish + 1)
        end

        if found then
            return false, newMsg, player, l, cs, t, flag, channelId, ...
        end
    end

    addFilter("CHAT_MSG_PARTY", filterFunc)
    addFilter("CHAT_MSG_PARTY_LEADER", filterFunc)
    addFilter("CHAT_MSG_RAID", filterFunc)
    addFilter("CHAT_MSG_RAID_LEADER", filterFunc)
    addFilter("CHAT_MSG_INSTANCE_CHAT", filterFunc)
    addFilter("CHAT_MSG_INSTANCE_CHAT_LEADER", filterFunc)
end

local function installModuleShareHook()
    if moduleShareHooked then
        return
    end
    moduleShareHooked = true

    hooksecurefunc("SetItemRef", function(link, text)
        local cacheType, senderKey
        if link and link:sub(1, #MODULE_SHARE_CHAT_LINK_PREFIX) == MODULE_SHARE_CHAT_LINK_PREFIX then
            cacheType, senderKey = link:sub(#MODULE_SHARE_CHAT_LINK_PREFIX + 1):match("^([^%-]+)%-(.+)$")
        end
        if cacheType and senderKey then
            local label = text and text:match("%[(.-)%]")
            label = stripChatCodes(label or "")
            local senderFull = senderKey:gsub("%+", "-")
            local cache = moduleShareCache[cacheType]
            local cached = cache and cache[senderFull] and cache[senderFull][label]
            if not cached or not cached.data then
                E:Printf("|cffff4040%s|r", L["SharingCachedPayloadMissing"] or "That shared data is not available. Ask for it to be shared again.")
                return
            end
            dispatchSharedImport(cacheType, cached.data, cached.sender, "chat")
            return
        end
    end)
end

local function ensureModuleShareComm()
    if moduleShareCommRegistered then
        return
    end
    local Comms = E:GetModule("Comms", true)
    if not (Comms and Comms.RegisterProtocol) then
        return
    end
    moduleShareCommRegistered = true
    Comms:RegisterProtocol(MODULE_SHARE_COMM_PREFIX, function(_, message, _, sender)
        local comms = E:GetModule("Comms", true)
        if not comms then
            return
        end
        local payload = comms:DecodePayload(message)
        if type(payload) ~= "table" or type(payload.typeKey) ~= "string" or type(payload.label) ~= "string" or
            type(payload.data) ~= "table" then
            return
        end
        local cfg = moduleShareTypes[payload.typeKey]
        if not cfg then
            return
        end
        local label = sanitizeLinkLabel(payload.label, cfg.label or "ART Share")
        storeShareCache(payload.typeKey, normalizeShareSender(sender), label, payload.data, sender)
    end)
end

function E:RegisterShareType(typeKey, opts)
    assert(type(typeKey) == "string" and typeKey ~= "", "RegisterShareType: typeKey required")
    assert(type(opts) == "table", "RegisterShareType: opts required")
    assert(type(opts.version) == "string" and opts.version ~= "", "RegisterShareType: opts.version required")
    moduleShareTypes[typeKey] = opts
    installModuleShareHook()
    installModuleShareChatFilters()
    ensureModuleShareComm()
end

function E:GetShareType(typeKey)
    return moduleShareTypes[typeKey]
end

function E:EncodeShareString(typeKey, data)
    local cfg = moduleShareTypes[typeKey]
    if not cfg then
        return ""
    end
    local ok, result = pcall(function()
        local payload = {
            v = 1,
            data = data
        }
        local serialized = E.Libs.LibSerialize:Serialize(payload)
        local compressed = E.Libs.LibDeflate:CompressDeflate(serialized)
        local encoded = E.Libs.LibDeflate:EncodeForPrint(compressed)
        return cfg.version .. ":" .. encoded
    end)
    if not ok then
        E:Warn("Share export failed for '%s': %s", typeKey, tostring(result))
        return ""
    end
    return result
end

function E:DecodeShareString(typeKey, text)
    local cfg = moduleShareTypes[typeKey]
    if not cfg then
        return nil, L["SharingUnknownType"] or "Unknown share type."
    end
    text = cleanShareText(text)
    local encoded = text:match("^" .. cfg.version .. ":(.+)$")
    if not encoded then
        return nil, L["ImportInvalid"]
    end

    local ok, payload = pcall(function()
        local decoded = E.Libs.LibDeflate:DecodeForPrint(encoded)
        if not decoded then
            return nil
        end
        local decompressed = E.Libs.LibDeflate:DecompressDeflate(decoded)
        if not decompressed then
            return nil
        end
        local success, data = E.Libs.LibSerialize:Deserialize(decompressed)
        if not success then
            return nil
        end
        return data
    end)
    if not ok or type(payload) ~= "table" or payload.v ~= 1 then
        return nil, L["ImportInvalid"]
    end

    local data = payload.data
    if cfg.sanitize then
        data = cfg.sanitize(data)
    end
    if type(data) ~= "table" then
        return nil, L["ImportInvalid"]
    end
    return data
end

function E:ShareDataToChat(typeKey, data, label)
    local cfg = moduleShareTypes[typeKey]
    if not cfg then
        return false, L["SharingUnknownType"] or "Unknown share type."
    end
    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then
        return false, L["SharingChatLocked"] or "Chat is currently locked."
    end

    local chatType = shareChatType()
    if not chatType then
        return false
    end

    local Comms = E:GetEnabledModule("Comms")
    if not Comms then
        return false, L["LoadModule"]
    end

    local senderKey, senderFull = playerShareKeys()
    local linkLabel = sanitizeLinkLabel(label, cfg.label or "ART Share")
    storeShareCache(typeKey, senderFull, linkLabel, data, senderFull)

    local chatMessage = ("[ART: %s: %s - %s]"):format(typeKey, senderKey, linkLabel)
    local sentChat = false
    local function sendChatLink()
        if sentChat then
            return
        end
        sentChat = true
        sendShareChatMessage(chatMessage, chatType)
    end

    Comms:SendPayload(MODULE_SHARE_COMM_PREFIX, {
        typeKey = typeKey,
        label = linkLabel,
        data = data
    }, nil, chatType, function(_, bytesSent, bytesToSend)
        if bytesSent == bytesToSend then
            sendChatLink()
        end
    end)
    return true
end
