local E, L, P = unpack(ART)
local Nicknames = E:GetModule("Nicknames")

local originalGetUnitName

local function Init()
    local DF = _G.DandersFrames
    if not DF then
        return
    end
    if originalGetUnitName then
        return
    end

    originalGetUnitName = DF.GetUnitName

    DF.GetUnitName = function(selfFrame, unit)
        if Nicknames:IsIntegrationActive("DandersFrames") then
            local nick = Nicknames:GetIfAny(unit)
            if nick then
                return nick
            end
        end
        return originalGetUnitName(selfFrame, unit)
    end
end

local function Update(unit)
    local DF = _G.DandersFrames
    if not DF or not DF.IterateCompactFrames or not DF.UpdateName then
        return
    end

    for unitFrame in DF:IterateCompactFrames() do
        DF:UpdateName(unitFrame)
    end
end

local function OnToggle(_enabled)
    local DF = _G.DandersFrames
    if not DF or not DF.IterateCompactFrames or not DF.UpdateName then
        return
    end

    for unitFrame in DF:IterateCompactFrames() do
        DF:UpdateName(unitFrame)
    end
end

Nicknames:RegisterIntegration("DandersFrames", {
    Init = Init,
    Update = Update,
    OnToggle = OnToggle
})
