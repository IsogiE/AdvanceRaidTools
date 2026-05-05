local E = unpack(ART)

local BossMods = E:GetModule("BossMods")
BossMods.Engines = BossMods.Engines or {}
local Engines = BossMods.Engines

local Shared = Engines.Shared or {}
Engines.Shared = Shared

Shared.WHITE = E.media.blankTex

function Shared.FetchFont()
    return E:FetchModuleFont()
end

function Shared.FetchStatusBar(tex)
    return E:FetchStatusBar(tex)
end

function Shared.FetchBorder(tex)
    return E:FetchBorder(tex)
end

function Shared.ColorTuple(c, fr, fg, fb, fa)
    return E:ColorTuple(c, fr, fg, fb, fa)
end

function Shared.ApplyFontIfChanged(fs, font, size, outline)
    E:ApplyFontString(fs, font, size, outline)
end

function Shared.ApplyFontTo(fs, style, parent, anchor)
    anchor = anchor or {}
    Shared.ApplyFontIfChanged(fs, Shared.FetchFont(), style.size or 12, style.outline or "")
    fs:ClearAllPoints()
    local justify = style.justify or anchor.justify
    if justify == "CENTER" then
        fs:SetPoint("CENTER", parent, "CENTER", 0, 0)
    elseif justify == "RIGHT" then
        fs:SetPoint("RIGHT", parent, "RIGHT", -6, 0)
    else
        fs:SetPoint("LEFT", parent, "LEFT", 6, 0)
    end
    fs:SetJustifyH(justify or "LEFT")
    local r, g, b, a = Shared.ColorTuple(style.color, 1, 1, 1, 1)
    fs:SetTextColor(r, g, b, a)
end

function Shared.IsSecret(v)
    return E:IsSecret(v)
end

function Shared.IsKnownUnitToken(unit)
    if type(unit) ~= "string" then
        return false
    end
    if unit == "player" or unit == "pet" or unit == "target" or unit == "focus" then
        return true
    end
    if unit:match("^raid%d+$") or unit:match("^party%d+$") or unit:match("^raidpet%d+$") or unit:match("^partypet%d+$") then
        return true
    end
    return false
end

function Shared.GetPlayerSpecID()
    local idx = GetSpecialization and GetSpecialization()
    if not idx then
        return nil
    end
    return GetSpecializationInfo and GetSpecializationInfo(idx) or nil
end

function Shared.DefaultGroupUnits()
    local units = {"player"}
    local n = GetNumGroupMembers() or 0
    if IsInRaid() then
        for i = 1, n do
            local u = "raid" .. i
            if not UnitIsUnit(u, "player") then
                units[#units + 1] = u
            end
        end
    else
        for i = 1, n - 1 do
            units[#units + 1] = "party" .. i
        end
    end
    return units
end
