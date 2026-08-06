local E = unpack(ART)

E.SporefallAbilityData = {
    {
        bossKey = "Rotmire",
        bossName = "Rotmire",
        bossOrder = 10,
        abilities = {
            { spellID = 1221622, name = "Awaken Fungi", defaultBarColor = "00FF41", defaultBarEnabled = true, castTimeAdjustment = 2, order = 10 },
            { spellID = 1221637, name = "Fungal Bloom", defaultBarColor = "FF0011", defaultBarEnabled = true, castTimeAdjustment = 6, postHitStages = { stages = { { duration = 16, text = "DoT" } } }, order = 20 },
            { spellID = 1222088, name = "Festering Vines", defaultBarColor = "00FFC3", defaultBarEnabled = true, castTimeAdjustment = 2, order = 30 },
            { spellID = 1221787, name = "Bursting Pustules", defaultBarColor = "FF0011", defaultBarEnabled = true, castTimeAdjustment = 2, order = 40 },
            { spellID = 1221781, name = "Putrid Fist (Tank)", defaultBarColor = "001FFF", defaultBarEnabled = false, order = 50 },
        },
    },
}

E:RegisterAbilityAlertData(
    "Sporefall",
    "BossMods_VoidspireAbilityAlerts",
    E.SporefallAbilityData,
    "Voidspire"
)
