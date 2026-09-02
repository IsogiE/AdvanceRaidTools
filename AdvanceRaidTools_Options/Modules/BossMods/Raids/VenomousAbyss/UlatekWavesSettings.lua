local E = unpack(ART)

local BossMods = E:GetModule("BossMods", true)
if BossMods and BossMods.RegisterTimelineSequenceSettingsBuilder then
    BossMods:RegisterTimelineSequenceSettingsBuilder("UlatekWaves")
end
