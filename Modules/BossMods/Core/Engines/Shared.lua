local E = unpack(ART)

local BossMods = E:GetModule("BossMods")
BossMods.Engines = BossMods.Engines or {}
local Engines = BossMods.Engines

local Shared = Engines.Shared or {}
Engines.Shared = Shared

Shared.WHITE = E.media.blankTex

local VALID_ANCHOR_POINTS = {
    TOP = true,
    CENTER = true,
    BOTTOM = true,
    LEFT = true,
    RIGHT = true,
    TOPLEFT = true,
    TOPRIGHT = true,
    BOTTOMLEFT = true,
    BOTTOMRIGHT = true
}

function Shared.NormalizeAnchorPoint(point)
    return VALID_ANCHOR_POINTS[point] and point or "CENTER"
end

function Shared.GetCenterRelativePosition(frame, point)
    point = Shared.NormalizeAnchorPoint(point)

    local left, right = frame:GetLeft(), frame:GetRight()
    local top, bottom = frame:GetTop(), frame:GetBottom()
    local screenX, screenY = UIParent:GetCenter()
    if not left or not right or not top or not bottom or not screenX or not screenY then
        return { point = point, x = 0, y = 0 }
    end

    local anchorX = (point:find("LEFT", 1, true) and left)
        or (point:find("RIGHT", 1, true) and right)
        or ((left + right) / 2)
    local anchorY = (point:find("TOP", 1, true) and top)
        or (point:find("BOTTOM", 1, true) and bottom)
        or ((top + bottom) / 2)

    return {
        point = point,
        x = anchorX - screenX,
        y = anchorY - screenY
    }
end

function Shared.UpdateAnchorPointMarker(frame, point, shown)
    if not frame then
        return
    end

    local marker = frame.artAnchorPointMarker
    if not marker then
        marker = CreateFrame("Frame", nil, frame)
        marker:SetSize(14, 14)
        marker:SetFrameLevel(frame:GetFrameLevel() + 20)
        marker:EnableMouse(false)

        local outer = marker:CreateTexture(nil, "OVERLAY", nil, 6)
        outer:SetAllPoints()
        outer:SetColorTexture(0, 0, 0, 1)
        local outerMask = marker:CreateMaskTexture(nil, "OVERLAY")
        outerMask:SetAllPoints(outer)
        outerMask:SetTexture(
            "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask",
            "CLAMPTOBLACKADDITIVE",
            "CLAMPTOBLACKADDITIVE"
        )
        outer:AddMaskTexture(outerMask)

        local inner = marker:CreateTexture(nil, "OVERLAY", nil, 7)
        inner:SetPoint("CENTER")
        inner:SetSize(10, 10)
        inner:SetColorTexture(0.18, 0.60, 1.00, 1)
        local innerMask = marker:CreateMaskTexture(nil, "OVERLAY")
        innerMask:SetAllPoints(inner)
        innerMask:SetTexture(
            "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask",
            "CLAMPTOBLACKADDITIVE",
            "CLAMPTOBLACKADDITIVE"
        )
        inner:AddMaskTexture(innerMask)

        marker:Hide()
        frame.artAnchorPointMarker = marker
    end

    marker:ClearAllPoints()
    marker:SetPoint("CENTER", frame, Shared.NormalizeAnchorPoint(point), 0, 0)
    if shown == true then
        marker:Show()
    elseif shown == false then
        marker:Hide()
    end
end

function Shared.FetchFont(name)
    return E:FetchModuleFont(name)
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
    Shared.ApplyFontIfChanged(
        fs,
        Shared.FetchFont(style.font),
        style.size or 12,
        style.outline or ""
    )
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
    local n = GetNumGroupMembers() or 0
    if IsInRaid() then
        -- raid1..N already includes the player; avoid UnitIsUnit because unit
        -- comparisons can be secret while 12.1 restrictions are active.
        local units = {}
        for i = 1, n do
            units[#units + 1] = "raid" .. i
        end
        return units
    end

    local units = {"player"}
    for i = 1, n - 1 do
        units[#units + 1] = "party" .. i
    end
    return units
end
