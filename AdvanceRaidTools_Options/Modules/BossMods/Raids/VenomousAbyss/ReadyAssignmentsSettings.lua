local E = unpack(ART)

local BossMods = E:GetModule("BossMods", true)

if BossMods and BossMods.RegisterBossSettingsBuilder then
    local builder = BossMods:GetSettingsBuilder("ReadyAssignments")

    if builder then
        BossMods:RegisterBossSettingsBuilder(
            "VenomousAbyssNekzali",
            function(rightPanel, mod, isDisabled, requestLayout)
                return builder(rightPanel, mod, isDisabled, requestLayout, {
                    hideUnlockFrame = true
                })
            end
        )
    end
end