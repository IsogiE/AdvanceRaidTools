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
