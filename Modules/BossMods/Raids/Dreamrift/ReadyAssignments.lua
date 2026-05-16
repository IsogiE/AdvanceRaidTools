local E = unpack(ART)

local BossMods = E:GetModule("BossMods")
local Text = BossMods and BossMods.ReadyAssignmentText

if Text and Text.Register then
    local RAID_META = {
        raidKey = "Dreamrift",
        raidLabelKey = "BossMods_Dreamrift"
    }
    local BOSS_META = {
        bossKey = "Chimaerus",
        bossLabelKey = "BossMods_Chimaerus",
        bossOrder = 10
    }

    local function withMeta(opts)
        for key, value in pairs(RAID_META) do
            opts[key] = opts[key] or value
        end
        for key, value in pairs(BOSS_META) do
            opts[key] = opts[key] or value
        end
        return opts
    end

    for _, def in ipairs({withMeta({
        key = "dreamriftGodG1",
        sheet = "DreamriftGodSoaks",
        labelKey = "BossMods_NoteGodSoaks",
        itemLabelKey = "BossMods_NoteGodSoaks",
        tab = "Dreamrift",
        order = 10,
        source = "hashtag",
        tag = "GodG1",
        type = "dreamriftGodSoak",
        textKey = "BossMods_AR_TextSoakWithGroup",
        priority = 70,
        players = 10,
        noteBlockSeparator = "\n",
        defaultValues = {
            group = 1
        }
    }), withMeta({
        key = "dreamriftGodG2",
        sheet = "DreamriftGodSoaks",
        source = "hashtag",
        tag = "GodG2",
        type = "dreamriftGodSoak",
        textKey = "BossMods_AR_TextSoakWithGroup",
        priority = 70,
        players = 10,
        defaultValues = {
            group = 2
        }
    }), withMeta({
        key = "dreamriftGodG1Swapper",
        sheet = "DreamriftGodSwappers",
        labelKey = "BossMods_NoteGodSwappers",
        itemLabelKey = "BossMods_NoteGodSwappers",
        tab = "Dreamrift",
        order = 11,
        source = "hashtag",
        tag = "GodG1Swapper",
        type = "dreamriftGodSwapper",
        textKey = "BossMods_AR_TextGroupSwapper",
        priority = 68,
        players = 2,
        noteBlockSeparator = "\n",
        defaultValues = {
            group = 1
        }
    }), withMeta({
        key = "dreamriftGodG2Swapper",
        sheet = "DreamriftGodSwappers",
        source = "hashtag",
        tag = "GodG2Swapper",
        type = "dreamriftGodSwapper",
        textKey = "BossMods_AR_TextGroupSwapper",
        priority = 68,
        players = 2,
        defaultValues = {
            group = 2
        }
    }), withMeta({
        key = "dreamriftGodFar1",
        sheet = "DreamriftGodFarKicks",
        labelKey = "BossMods_NoteGodFarKicks",
        itemLabelKey = "BossMods_NoteGodFarKicks",
        tab = "Dreamrift",
        order = 12,
        source = "hashtag",
        tag = "GodFar1",
        type = "dreamriftGodFarKick",
        textKey = "BossMods_AR_TextKickFarGroup",
        priority = 66,
        players = 2,
        noteBlockSeparator = "\n",
        defaultValues = {
            group = 1
        }
    }), withMeta({
        key = "dreamriftGodFar2",
        sheet = "DreamriftGodFarKicks",
        source = "hashtag",
        tag = "GodFar2",
        type = "dreamriftGodFarKick",
        textKey = "BossMods_AR_TextKickFarGroup",
        priority = 66,
        players = 2,
        defaultValues = {
            group = 2
        }
    })}) do
        Text:Register(def.key, def)
    end

    E:RegisterBossModNoteGroup("Dreamrift_Chimaerus", {
        labelKey = "BossMods_Chimaerus",
        itemLabelKey = "BossMods_NoteFull",
        raidKey = RAID_META.raidKey,
        raidLabelKey = RAID_META.raidLabelKey,
        bossKey = BOSS_META.bossKey,
        bossLabelKey = BOSS_META.bossLabelKey,
        bossOrder = BOSS_META.bossOrder,
        itemOrder = 0,
        tab = "Dreamrift",
        order = 10,
        entries = {"DreamriftGodSoaks", "DreamriftGodSwappers", "DreamriftGodFarKicks"}
    })
end
