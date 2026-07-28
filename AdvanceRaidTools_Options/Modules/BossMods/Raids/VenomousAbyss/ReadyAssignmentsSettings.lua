local E = unpack(ART)

local BossMods = E:GetModule("BossMods", true)

if BossMods and BossMods.RegisterBossSettingsBuilder then
    local builder = BossMods:GetSettingsBuilder("ReadyAssignments")

    if builder then
        BossMods:RegisterBossSettingsBuilder(
            "VenomousAbyssNekzali",
            function(rightPanel, mod, isDisabled)
                return builder(rightPanel, mod, isDisabled, {
                    hideUnlockFrame = true
                })
            end
        )
    end
end