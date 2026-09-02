local E = unpack(ART)

local BossMods = E:GetModule("BossMods", true)

if BossMods and BossMods.RegisterAuraCircleSettingsBuilder then
    BossMods:RegisterAuraCircleSettingsBuilder("SerpentsBiteTarget")
    BossMods:RegisterAuraCircleSettingsBuilder("BlightVeinCircle")
    BossMods:RegisterAuraCircleSettingsBuilder("VolatilePurgeCircle")
end
