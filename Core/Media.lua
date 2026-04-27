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

function E:FetchStatusBar(name)
    return lsmFetch("statusbar", name) or E.media.statusbarTexture or E.media.normTex or FALLBACK_STATUSBAR
end

function E:FetchBorder(name)
    if name == "None" or name == "" or name == nil then
        return E.media.blankTex or FALLBACK_BORDER
    end
    return lsmFetch("border", name) or E.media.blankTex or FALLBACK_BORDER
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
