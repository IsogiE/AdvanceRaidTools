local E = unpack(ART)

local frame = CreateFrame("Frame", nil, UIParent)
frame:SetFrameStrata("TOOLTIP")
frame:EnableMouse(false)
frame:SetSize(120, 22)
frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 4, -4)

local text = frame:CreateFontString(nil, "OVERLAY")
text:SetFont([[Interface\AddOns\AdvanceRaidTools\Media\Fonts\PTSansNarrow.ttf]], 18, "OUTLINE")
text:SetTextColor(0.85, 0.85, 0.85, 1)
text:SetPoint("TOPLEFT")
text:SetJustifyH("LEFT")

local started
local function stop()
    frame:Hide()
    frame:SetScript("OnUpdate", nil)
    started = nil
end

local function show()
    started = GetTimePreciseSec()
    text:SetText(string.format("%d", GetServerTime()))
    frame:Show()
    frame:SetScript("OnUpdate", function()
        if GetTimePreciseSec() - started >= 5 then
            stop()
        end
    end)
end

function E:PreviewReplayTimestamp()
    if not started and not C_InstanceEncounter.IsEncounterInProgress() then
        show()
    end
end

frame:SetScript("OnEvent", function(_, event, _, _, difficultyID)
    stop()
    if event == "ENCOUNTER_START" then
        local _, instanceType = GetInstanceInfo()
        if instanceType == "raid" and (difficultyID == 14 or difficultyID == 15 or difficultyID == 16) then
            show()
        end
    end
end)
frame:RegisterEvent("ENCOUNTER_START")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
stop()
