local E = unpack(ART)

local function visible(frame)
    if not frame or frame:IsForbidden() then return false end
    local shown = frame:IsVisible()
    return not E:IsSecret(shown) and shown == true
end

local function matches(frame, unit)
    if not visible(frame) then return false end
    local assigned = SecureButton_GetUnit(frame)
    if E:IsSecret(assigned) or not assigned then return false end
    local same = UnitIsUnit(assigned, unit)
    return not E:IsSecret(same) and same == true
end

function E:GetGroupUnitFrame(unit)
    if self:IsSecret(unit) or not unit then return end
    local library = self.Libs and self.Libs.LibGetFrame
    if library and library.GetUnitFrame then
        local ok, frame = pcall(library.GetUnitFrame, unit)
        if ok and visible(frame) then return frame end
    end
    if _G.DandersFrames_GetFrameForUnit then
        local ok, frame = pcall(_G.DandersFrames_GetFrameForUnit, unit)
        if ok and visible(frame) then return frame end
    end
    for group = 1, 8 do
        for member = 1, 5 do
            local frame = _G["ERFGroupHeader" .. group .. "UnitButton" .. member]
            if matches(frame, unit) then return frame end
            frame = _G["CompactRaidGroup" .. group .. "Member" .. member]
            if matches(frame, unit) then return frame end
        end
    end
    for index = 1, 40 do
        local frame = _G["ERFFlatHeaderUnitButton" .. index]
        if matches(frame, unit) then return frame end
    end
    local index = 1
    while _G["CompactRaidFrame" .. index] do
        local frame = _G["CompactRaidFrame" .. index]
        if matches(frame, unit) then return frame end
        index = index + 1
    end
    if matches(_G.ERFPartySelfButton, unit) then return _G.ERFPartySelfButton end
    for member = 1, 5 do
        local frame = _G["ERFPartyHeaderUnitButton" .. member]
        if matches(frame, unit) then return frame end
        frame = _G["CompactPartyFrameMember" .. member]
        if matches(frame, unit) then return frame end
        frame = _G.PartyFrame and _G.PartyFrame["MemberFrame" .. member]
        if matches(frame, unit) then return frame end
    end
    if unit == "player" and visible(_G.PlayerFrame) then return _G.PlayerFrame end
end
