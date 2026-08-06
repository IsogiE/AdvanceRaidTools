local E = unpack(ART)

E.DreamriftAbilityData = {
    {
        bossKey = "Chimaerus",
        bossName = "Chimaerus, the Undreamt God",
        bossOrder = 10,
        abilities = {
            { spellID = 1264756, name = "Rift Madness (Mythic)", defaultBarColor = "FF7400", defaultBarEnabled = true, order = 10 },
            { spellID = 1245396, name = "Consume (Adds)", defaultBarColor = "FF0011", defaultBarEnabled = true, order = 20 },
            { spellID = 1245406, name = "Ravenous Dive (Return to Stage 1)", defaultBarColor = "FF0011", defaultBarEnabled = true, order = 30 },
            { spellID = 1262289, name = "Alndust Upheaval (Soak)", defaultBarColor = "FF7400", defaultBarEnabled = true, order = 40 },
            { spellID = 1272726, name = "Rending Tear (Frontal Cone)", defaultBarColor = "0094FF", defaultBarEnabled = true, order = 50 },
        },
    },
}

E:RegisterAbilityAlertData(
    "Dreamrift",
    "BossMods_VoidspireAbilityAlerts",
    E.DreamriftAbilityData,
    "Voidspire"
)
