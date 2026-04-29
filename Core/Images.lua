local E = unpack(ART)

local pools = {}
local random = math.random

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
                            list[#list + 1] = {path, d.w, d.h}
                        else
                            list[#list + 1] = path
                        end
                    end
                end
            end
        end
    end
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
    local path, w, h
    if type(entry) == "string" then
        path, w, h = entry, spec.w, spec.h
    elseif type(entry) == "table" then
        path = entry[1] or entry.path
        w = entry[2] or entry.w or spec.w
        h = entry[3] or entry.h or spec.h
    else
        return nil
    end
    w, h = applyCap(spec, w, h)
    return path, w, h
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
