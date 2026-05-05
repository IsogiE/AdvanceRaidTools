local E = unpack(ART)

local LSM = E.Libs.LSM

local FONTS = {
    ["PT Sans Narrow"] = [[Interface\AddOns\AdvanceRaidTools\Media\Fonts\PTSansNarrow.ttf]]
}

local STATUSBARS = {
    ["Clean"] = [[Interface\AddOns\AdvanceRaidTools\Media\Textures\Statusbar_Clean]]
}

local BORDERS = {
    ["Pixel"] = [[Interface\Buttons\WHITE8x8]]
}

E.media.normTex = STATUSBARS["Clean"]
E.media.blankTex = BORDERS["Pixel"]
E.media.normFont = FONTS["PT Sans Narrow"]

local lsmSweepTarget = {}
local lsmSweepPending = false

local function scheduleLSMSweep()
    if lsmSweepPending then
        return
    end
    lsmSweepPending = true
    C_Timer.After(0.2, function()
        lsmSweepPending = false
        local Home = E.GetModule and E:GetModule("HomeSettings", true)
        if Home and Home.SyncMediaTable then
            Home:SyncMediaTable()
        end
        if E.UpdateMedia then
            E:UpdateMedia()
        elseif E.SendMessage then
            E:SendMessage("ART_MEDIA_UPDATED")
        end
    end)
end

-- Font shenanigans 
local fontPreloader
local preloadedFonts = {}
local function ensureFontPreloader()
    if fontPreloader then
        return fontPreloader
    end
    fontPreloader = CreateFrame("Frame")
    fontPreloader:SetPoint("TOP", UIParent, "BOTTOM", 0, -90000)
    fontPreloader:SetSize(100, 100)
    return fontPreloader
end

local function cacheFont(name, path)
    if not name or preloadedFonts[name] then
        return
    end
    if type(path) ~= "string" or path == "" then
        return
    end
    local fs = ensureFontPreloader():CreateFontString(nil, "ARTWORK")
    fs:SetAllPoints()
    local ok = pcall(fs.SetFont, fs, path, 14)
    if ok then
        pcall(fs.SetText, fs, "cache")
        pcall(fs.GetStringWidth, fs)
        preloadedFonts[name] = fs
    end
end

local function preloadAllFonts()
    if not LSM then
        return
    end
    local hash = LSM:HashTable("font")
    if not hash then
        return
    end
    for name, path in pairs(hash) do
        cacheFont(name, path)
    end
end

function E:RegisterMedia()
    if not LSM then
        return
    end
    for name, path in pairs(FONTS) do
        LSM:Register(LSM.MediaType.FONT, name, path)
    end
    for name, path in pairs(STATUSBARS) do
        LSM:Register(LSM.MediaType.STATUSBAR, name, path)
    end
    for name, path in pairs(BORDERS) do
        LSM:Register(LSM.MediaType.BORDER, name, path)
    end

    if LSM.RegisterCallback then
        LSM.RegisterCallback(lsmSweepTarget, "LibSharedMedia_Registered", scheduleLSMSweep)
        LSM.RegisterCallback(lsmSweepTarget, "LibSharedMedia_SetGlobal", scheduleLSMSweep)
    end

    -- Preload everything LSM knows about right now, then hook future
    preloadAllFonts()
    if not E._lsmRegisterHooked and hooksecurefunc then
        E._lsmRegisterHooked = true
        hooksecurefunc(LSM, "Register", function(_, mediaType, key, data)
            if type(mediaType) ~= "string" then
                return
            end
            if mediaType:lower() == "font" then
                cacheFont(key, data)
            end
        end)
    end
end

function E:Fetch(mediaType, name)
    if LSM then
        return LSM:Fetch(mediaType, name)
    end
    if mediaType == "font" then
        return E.media.normFont
    end
    if mediaType == "statusbar" then
        return E.media.normTex
    end
    if mediaType == "border" then
        return E.media.blankTex
    end
end

local FALLBACK_FONT = [[Fonts\FRIZQT__.TTF]]
local FALLBACK_STATUSBAR = [[Interface\TargetingFrame\UI-StatusBar]]
local FALLBACK_BORDER = [[Interface\Tooltips\UI-Tooltip-Border]]

local function lsmFetch(mediaType, name)
    if not LSM or not name or name == "" then
        return nil
    end
    local ok, result = pcall(LSM.Fetch, LSM, mediaType, name)
    if ok and type(result) == "string" and result ~= "" then
        return result
    end
    return nil
end

function E:FetchFont(name)
    return lsmFetch("font", name) or E.media.normFont or FALLBACK_FONT
end

function E:FetchModuleFont(name)
    return lsmFetch("font", name) or E.media.moduleFont or E.media.normFont or FALLBACK_FONT
end

function E:FetchStatusBar(name)
    return lsmFetch("statusbar", name) or E.media.statusbarTexture or E.media.normTex or FALLBACK_STATUSBAR
end

function E:FetchBorder(name)
    if name == "None" or name == "" or name == nil then
        return E.media.blankTex or FALLBACK_BORDER
    end
    return lsmFetch("border", name) or E.media.blankTex or FALLBACK_BORDER
end

local fontFallbackObjects = {}
local fontFallbackCount = 0

local function fontFallbackObject(font, size, outline)
    local key = font .. "|" .. tostring(size) .. "|" .. tostring(outline or "")
    local fontObj = fontFallbackObjects[key]
    if not fontObj then
        fontFallbackCount = fontFallbackCount + 1
        local objName = "ART_FontFallback_" .. fontFallbackCount
        fontObj = _G[objName] or CreateFont(objName)
        fontFallbackObjects[key] = fontObj
    end
    fontObj:SetFont(font, size, outline or "")
    return fontObj
end

function E:ApplyFontString(fs, font, size, outline)
    if not fs or not fs.SetFont or not font then
        return false
    end
    if fs._artFont == font and fs._artSize == size and fs._artOutline == outline then
        return true
    end
    fs:SetFont(font, size, outline)
    if not fs:GetFont() and fs.SetFontObject then
        pcall(fs.SetFontObject, fs, fontFallbackObject(font, size, outline))
    end
    if fs:GetFont() then
        fs._artFont, fs._artSize, fs._artOutline = font, size, outline
        return true
    end
    return false
end

function E:MediaList(mediaType)
    local out = {}
    local hash = LSM and LSM:HashTable(mediaType)
    if hash then
        for name in next, hash do
            out[name] = name
        end
    end
    return out
end
