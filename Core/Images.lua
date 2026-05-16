local E = unpack(ART)

local pools = {}
local HASH_MOD = 2147483647
local random = math.random
local sort = table.sort
local byte = string.byte

function E:RegisterImagePool(name, spec)
    if type(name) ~= "string" or name == "" then
        return
    end
    if type(spec) ~= "table" then
        return
    end
    pools[name] = spec
end

function E:GetImagePool(name)
    return pools[name]
end

function E:RebuildImagePool(name)
    local spec = pools[name]
    if spec then
        spec._cached = nil
    end
end

function E:RebuildImagePools()
    for _, spec in pairs(pools) do
        spec._cached = nil
    end
end

local function entrySortKey(entry)
    if type(entry) == "string" or type(entry) == "number" then
        return tostring(entry)
    end
    if type(entry) ~= "table" then
        return tostring(entry)
    end
    local key = entry.key or entry.name or entry[4]
    local path = entry[1] or entry.path
    local w = entry[2] or entry.w
    local h = entry[3] or entry.h
    return ("%s\001%s\001%s\001%s"):format(tostring(key or path or ""), tostring(path or ""), tostring(w or ""),
        tostring(h or ""))
end

local function entryLess(a, b)
    return entrySortKey(a) < entrySortKey(b)
end

local function discover(spec)
    if spec._cached then
        return spec._cached
    end
    local list = {}
    if spec.list then
        for _, e in ipairs(spec.list) do
            list[#list + 1] = e
        end
    end
    if spec.lsmType and spec.lsmPrefix then
        local LSM = E.Libs and E.Libs.LSM
        if LSM then
            local hash = LSM:HashTable(spec.lsmType)
            if hash then
                local prefix = spec.lsmPrefix
                local plen = #prefix
                local dims = spec.lsmDims or {}
                for lsmName, path in pairs(hash) do
                    if type(lsmName) == "string" and lsmName:sub(1, plen) == prefix then
                        local d = dims[lsmName]
                        if d then
                            list[#list + 1] = {path, d.w, d.h, key = lsmName}
                        else
                            list[#list + 1] = {path, key = lsmName}
                        end
                    end
                end
            end
        end
    end
    sort(list, entryLess)
    spec._cached = list
    return list
end

local function applyCap(spec, w, h)
    if not w or not h or w <= 0 or h <= 0 then
        return w, h
    end
    local maxW, maxH = spec.maxW, spec.maxH
    local sW = (maxW and w > maxW) and (maxW / w) or 1
    local sH = (maxH and h > maxH) and (maxH / h) or 1
    local s = math.min(sW, sH)
    if s >= 1 then
        return w, h
    end
    return math.floor(w * s + 0.5), math.floor(h * s + 0.5)
end

local function resolveEntry(spec, entry)
    local path, w, h
    if type(entry) == "string" or type(entry) == "number" then
        path, w, h = entry, spec.w, spec.h
    elseif type(entry) == "table" then
        path = entry[1] or entry.path
        w = entry[2] or entry.w or spec.w
        h = entry[3] or entry.h or spec.h
    else
        return nil
    end
    if type(path) ~= "string" and type(path) ~= "number" then
        return nil
    end
    w, h = applyCap(spec, w, h)
    return path, w, h
end

local function hashSeed(seed)
    seed = tostring(seed or "")
    local hash = 5381
    for i = 1, #seed do
        hash = ((hash * 33) + byte(seed, i)) % HASH_MOD
    end
    return hash
end

function E:PickRandomImage(name)
    local spec = pools[name]
    if not spec then
        return nil
    end
    local list = discover(spec)
    if #list == 0 then
        return nil
    end
    local entry = list[random(1, #list)]
    return resolveEntry(spec, entry)
end

function E:PickImageBySeed(name, seed)
    local spec = pools[name]
    if not spec then
        return nil
    end
    local list = discover(spec)
    local count = #list
    if count == 0 then
        return nil
    end
    local entry = list[(hashSeed(seed) % count) + 1]
    return resolveEntry(spec, entry)
end

_G.ART_Media = _G.ART_Media or {}
_G.ART_Media.Dreams = _G.ART_Media.Dreams or {
    prefix = "ART_Dream_",
    dims = {}
}

E:RegisterImagePool("Dreams", {
    lsmType = "background",
    lsmPrefix = "ART_Dream_",
    lsmDims = _G.ART_Media.Dreams.dims,
    maxW = 480,
    maxH = 480,
    w = 480,
    h = 480
})
