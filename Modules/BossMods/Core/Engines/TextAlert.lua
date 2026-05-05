local E = unpack(ART)

local BossMods = E:GetModule("BossMods")
local Engines = BossMods.Engines
local Shared = Engines.Shared

local fetchFont = Shared.FetchFont
local colorTuple = Shared.ColorTuple
local applyFontIfChanged = Shared.ApplyFontIfChanged

function Engines.TextAlert(config)
    assert(type(config) == "table", "Engines.TextAlert: config required")
    assert(config.parent, "Engines.TextAlert: config.parent required")

    local sizeCfg = config.size or {
        w = 400,
        h = 80
    }

    local frame = CreateFrame("Frame", nil, config.parent, "BackdropTemplate")
    frame:SetSize(sizeCfg.w, sizeCfg.h)
    frame:SetFrameStrata(config.strata or "MEDIUM")
    frame:Hide()

    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER")

    local state = {
        config = config
    }

    local handle = {
        frame = frame
    }

    function handle:SetText(t)
        text:SetText(t or "")
    end

    function handle:Show()
        frame:Show()
    end
    function handle:Hide()
        frame:Hide()
    end

    function handle:Apply(newConfig)
        if type(newConfig) == "table" then
            state.config = newConfig
        end
        local c = state.config
        if c.size then
            frame:SetSize(c.size.w or 400, c.size.h or 80)
        end
        local font = c.font or {}
        applyFontIfChanged(text, fetchFont(), font.size or 28, font.outline or "OUTLINE")
        if font.color then
            local r, g, b, a = colorTuple(font.color, 1, 1, 1, 1)
            text:SetTextColor(r, g, b, a)
        end
        if c.strata then
            frame:SetFrameStrata(c.strata)
        end
    end

    function handle:Release()
        frame:Hide()
        frame:SetBackdrop(nil)
        frame:ClearAllPoints()
        frame:SetParent(nil)
    end

    handle:Apply()
    return handle
end
