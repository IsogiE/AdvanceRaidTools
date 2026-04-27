local E, L, P = unpack(ART)
local Nicknames = E:GetModule("Nicknames")

local hookedFrames = {}
local inUpdate = {}
local hookedCompactSetup = false

local function UpdateFrame(frame, force)
    if not force and not Nicknames:IsIntegrationActive("Blizzard") then
        return
    end

    if not frame then
        return
    end
    if frame:IsForbidden() then
        return
    end

    if inUpdate[frame] then
        return
    end

    local unit = frame.displayedUnit or frame.unit

    if unit and unit:match("nameplate") then
        return
    end

    local nameFrame = frame.name

    if not unit then
        return
    end
    if not nameFrame then
        return
    end
    if not UnitIsPlayer(unit) then
        return
    end
    if not E:SafeString(UnitName(unit)) then
        return
    end

    inUpdate[frame] = true
    if Nicknames:IsIntegrationActive("Blizzard") then
        local nickname = Nicknames:GetIfAny(unit)
        if nickname then
            nameFrame:SetFormattedText(nickname)
            inUpdate[frame] = nil
            return
        end
    end

    local name = GetUnitName(frame.unit, true)
    nameFrame:SetFormattedText(name)
    inUpdate[frame] = nil
end

local function UpdatePartyFrames(force)
    if not PartyFrame then
        return
    end

    for i = 1, 4 do
        local frame = PartyFrame["MemberFrame" .. i]
        UpdateFrame(frame, force)
    end
end

local function UpdateRaidFrames(force)
    if not CompactRaidFrameContainer then
        return
    end
    if not CompactRaidFrameContainer.frameUpdateList then
        return
    end
    if not CompactRaidFrameContainer.frameUpdateList.normal then
        return
    end

    for _, frameGroup in pairs(CompactRaidFrameContainer.frameUpdateList.normal) do
        if frameGroup.memberUnitFrames then
            for _, frame in pairs(frameGroup.memberUnitFrames) do
                if frame.unitExists then
                    UpdateFrame(frame, force)
                end
            end
        end
    end
end

local function UpdatePlayerFrame(force)
    if PlayerFrame then
        UpdateFrame(PlayerFrame, force)
    end
end

local function UpdateTargetFrame(force)
    if TargetFrame then
        UpdateFrame(TargetFrame, force)
    end
end

local function UpdateFocusFrame(force)
    if FocusFrame then
        UpdateFrame(FocusFrame, force)
    end
end

local function ForceUpdate(force)
    UpdatePartyFrames(force)
    UpdateRaidFrames(force)
    UpdatePlayerFrame(force)
    UpdateTargetFrame(force)
    UpdateFocusFrame(force)
end

local function Update(_unit)
    if not Nicknames:IsIntegrationActive("Blizzard") then
        return
    end
    ForceUpdate(false)
end

local function OnToggle(_enabled)
    ForceUpdate(true)
end

local function Init()
    if PartyFrame then
        for i = 1, 4 do
            local memberFrame = PartyFrame["MemberFrame" .. i]
            if memberFrame and memberFrame.name and not hookedFrames[memberFrame.name] then
                hooksecurefunc(memberFrame.name, "SetText", function()
                    UpdateFrame(memberFrame)
                end)
                hookedFrames[memberFrame.name] = true
            end
        end
    end

    if PlayerFrame and PlayerFrame.name and not hookedFrames[PlayerFrame.name] then
        hooksecurefunc(PlayerFrame.name, "SetText", function()
            UpdateFrame(PlayerFrame)
        end)
        hookedFrames[PlayerFrame.name] = true
    end

    if TargetFrame and TargetFrame.name and not hookedFrames[TargetFrame.name] then
        hooksecurefunc(TargetFrame.name, "SetText", function()
            UpdateFrame(TargetFrame)
        end)
        hookedFrames[TargetFrame.name] = true
    end

    if FocusFrame and FocusFrame.name and not hookedFrames[FocusFrame.name] then
        hooksecurefunc(FocusFrame.name, "SetText", function()
            UpdateFrame(FocusFrame)
        end)
        hookedFrames[FocusFrame.name] = true
    end

    if CompactRaidFrameContainer and CompactRaidFrameContainer.frameUpdateList and
        CompactRaidFrameContainer.frameUpdateList.normal then
        for _, frameGroup in pairs(CompactRaidFrameContainer.frameUpdateList.normal) do
            if frameGroup.memberUnitFrames then
                for _, frame in pairs(frameGroup.memberUnitFrames) do
                    if frame and frame.name and not hookedFrames[frame.name] then
                        hooksecurefunc(frame.name, "SetText", function()
                            UpdateFrame(frame)
                        end)
                        hookedFrames[frame.name] = true
                    end
                end
            end
        end
    end

    if DefaultCompactUnitFrameSetup and not hookedCompactSetup then
        hookedCompactSetup = true
        hooksecurefunc("DefaultCompactUnitFrameSetup", function(frame)
            if frame and frame.name and not hookedFrames[frame.name] then
                hooksecurefunc(frame.name, "SetText", function()
                    UpdateFrame(frame)
                end)
                hookedFrames[frame.name] = true
            end
        end)
    end

    ForceUpdate(true)
end

Nicknames:RegisterIntegration("Blizzard", {
    Init = Init,
    Update = Update,
    OnToggle = OnToggle
})
