local E = unpack(ART)

local BossMods = E:GetModule("BossMods")
local Text = BossMods and BossMods.ReadyAssignmentText

if Text and Text.Register then
    local RAID_META = {
        raidKey = "VenomousAbyss",
        raidLabelKey = "BossMods_VenomousAbyss"
    }

local BOSS_META = {
    nekzali = {
        bossKey = "Nekzali",
        bossLabelKey = "BossMods_Nekzali",
        bossOrder = 10
    },

    entombedSentinels = {
        bossKey = "EntombedSentinels",
        bossLabelKey = "BossMods_EntombedSentinels",
        bossOrder = 20
    },

    lostExplorers = {
        bossKey = "LostExplorers",
        bossLabelKey = "BossMods_LostExplorers",
        bossOrder = 30
    },

    vashnik = {
        bossKey = "Vashnik",
        bossLabelKey = "BossMods_Vashnik",
        bossOrder = 40
    },

    sszorak = {
        bossKey = "Sszorak",
        bossLabelKey = "BossMods_Sszorak",
        bossOrder = 50
    },

    twinFangs = {
        bossKey = "TwinFangs",
        bossLabelKey = "BossMods_TwinFangs",
        bossOrder = 60
    },

    coiledAltar = {
        bossKey = "CoiledAltar",
        bossLabelKey = "BossMods_CoiledAltar",
        bossOrder = 70
    },

    ulatek = {
        bossKey = "Ulatek",
        bossLabelKey = "BossMods_Ulatek",
        bossOrder = 80
    }
}

    local function withMeta(opts, bossMeta)
        for key, value in pairs(RAID_META) do
            opts[key] = opts[key] or value
        end

        for key, value in pairs(bossMeta or {}) do
            opts[key] = opts[key] or value
        end

        return opts
    end

    ---------------------------------------------------------------------------
    -- Small helper function for standard hashtag assignments
    ---------------------------------------------------------------------------
    local function AR(opts)
        local bossMeta = opts.boss
        opts.boss = nil

        opts.source = "hashtag"
        opts.type = opts.type or opts.key
        opts.priority = opts.priority or 70
        opts.hashtagMultiline = opts.hashtagMultiline ~= false
        opts.noteBlockSeparator = opts.noteBlockSeparator or "\n"

        -- Template for "Insert Boss Mod Note"
        opts.note = opts.note or {
            tag = opts.tag,
            template = "#" .. opts.tag .. "\nPlayer1\nPlayer2\nPlayer3"
        }

        local def = withMeta(opts, bossMeta)
        Text:Register(def.key, def)
    end

    ---------------------------------------------------------------------------
    -- Nek'zali
    ---------------------------------------------------------------------------
    AR({
        boss = BOSS_META.nekzali,

        key = "venomousAbyssFocusFarAdd",
        sheet = "VenomousAbyssFocusFarAdd",

        labelKey = "BossMods_NoteFocusFarAdd",
        itemLabelKey = "BossMods_NoteFocusFarAdd",

        tab = "VenomousAbyss",
        order = 10,

        tag = "FocusFarAdd",
        textKey = "BossMods_AR_TextFocusFarAdd"
    })

    ---------------------------------------------------------------------------
    -- Entombed Sentinels
    ---------------------------------------------------------------------------
    AR({
        boss = BOSS_META.entombedSentinels,

        key = "venomousAbyssESGreen",
        sheet = "VenomousAbyssEntombedSentinelsStarts",

        labelKey = "BossMods_NoteStartingSides",
        itemLabelKey = "BossMods_NoteStartingSides",

        tab = "VenomousAbyss",
        order = 20,

        tag = "ESGreen",
        textKey = "BossMods_AR_TextESGreen"
    })

    AR({
        boss = BOSS_META.entombedSentinels,

        key = "venomousAbyssESRed",
        sheet = "VenomousAbyssEntombedSentinelsStarts",

        labelKey = "BossMods_NoteStartingSides",
        itemLabelKey = "BossMods_NoteStartingSides",

        tab = "VenomousAbyss",
        order = 21,

        tag = "ESRed",
        textKey = "BossMods_AR_TextESRed"
    })
---------------------------------------------------------------------------
-- The Lost Explorers
---------------------------------------------------------------------------

AR({
    boss = BOSS_META.lostExplorers,

    key = "venomousAbyssLEThud1",
    sheet = "VenomousAbyssLostExplorersThuds",

    labelKey = "BossMods_NoteLEThuds",
    itemLabelKey = "BossMods_NoteLEThuds",

    tab = "VenomousAbyss",
    order = 30,

    tag = "LEThud1",
    textKey = "BossMods_AR_TextLEThud1"
})

AR({
    boss = BOSS_META.lostExplorers,

    key = "venomousAbyssLEThud2",
    sheet = "VenomousAbyssLostExplorersThuds",

    labelKey = "BossMods_NoteLEThuds",
    itemLabelKey = "BossMods_NoteLEThuds",

    tab = "VenomousAbyss",
    order = 31,

    tag = "LEThud2",
    textKey = "BossMods_AR_TextLEThud2"
})

AR({
    boss = BOSS_META.lostExplorers,

    key = "venomousAbyssLEThud3",
    sheet = "VenomousAbyssLostExplorersThuds",

    labelKey = "BossMods_NoteLEThuds",
    itemLabelKey = "BossMods_NoteLEThuds",

    tab = "VenomousAbyss",
    order = 32,

    tag = "LEThud3",
    textKey = "BossMods_AR_TextLEThud3"
})

---------------------------------------------------------------------------
-- Sszorak
---------------------------------------------------------------------------

AR({
    boss = BOSS_META.sszorak,

    key = "venomousAbyssSSZSoak1",
    sheet = "VenomousAbyssSszorakSoaks",

    labelKey = "BossMods_NoteSSZSoaks",
    itemLabelKey = "BossMods_NoteSSZSoaks",

    tab = "VenomousAbyss",
    order = 50,

    tag = "SSZSoak1",
    textKey = "BossMods_AR_TextSSZSoak1"
})

AR({
    boss = BOSS_META.sszorak,

    key = "venomousAbyssSSZSoak2",
    sheet = "VenomousAbyssSszorakSoaks",

    labelKey = "BossMods_NoteSSZSoaks",
    itemLabelKey = "BossMods_NoteSSZSoaks",

    tab = "VenomousAbyss",
    order = 51,

    tag = "SSZSoak2",
    textKey = "BossMods_AR_TextSSZSoak2"
})

AR({
    boss = BOSS_META.sszorak,

    key = "venomousAbyssSSZWindCaller",
    sheet = "VenomousAbyssSszorakWindMarkers",

    labelKey = "BossMods_SszorakMarkers",
    itemLabelKey = "BossMods_NoteSSZWindCaller",

    tab = "VenomousAbyss",
    order = 52,

    type = "sszorakWindCaller",
    moduleName = "BossMods_SszorakMarkers",
    tag = "sszwinds",
    hashtagMultiline = false,
    textKey = "BossMods_AR_TextSSZWindCaller",
    priority = 80,
    note = {
        tag = "sszwinds",
        template = "#sszwinds Player1 Player2 Player3"
    }
})

---------------------------------------------------------------------------
-- The Twin Fangs: kick-position parser
---------------------------------------------------------------------------

local function evaluateTFKick(provider, ctx, out, api)
    local tag = api:NormalizeTag(provider.tag)

    if not tag or not ctx or not ctx.tags then
        return
    end

    local sections = ctx.tags[tag]

    if not sections then
        return
    end

    for _, section in ipairs(sections) do
        local text = section.text or section.headerText or ""
        local words = api:Words(text)

        -- Only the first two players are used:
        -- position 1 = first kick
        -- position 2 = second kick
        for position = 1, math.min(#words, 2) do
            if api:TokenIsPlayer(words[position], ctx) then
                api:Add(out, api:NewReminder(provider, {
                    key = provider.key,
                    type = provider.type or provider.key,
                    tag = provider.tag,
                    section = section,
                    tokenIndex = position,
                    kickOrder = position == 1 and "first" or "second",
                    addNumber = provider.addNumber,
                    priority = provider.priority or 70
                }))

                return
            end
        end
    end
end

---------------------------------------------------------------------------
-- The Twin Fangs
---------------------------------------------------------------------------

for addNumber = 1, 10 do
    local tag = "TFKick" .. addNumber
    local key = "venomousAbyssTFKick" .. addNumber

    Text:Register(key, withMeta({
        key = key,
        sheet = "VenomousAbyssTwinFangsKicks",

        labelKey = "BossMods_NoteTFKicks",
        itemLabelKey = "BossMods_NoteTFKicks",

        tab = "VenomousAbyss",
        order = 60 + addNumber - 1,

        tag = tag,
        type = "venomousAbyssTFKick",
        textKey = "BossMods_AR_TextTFKick",
        priority = 70,

        addNumber = addNumber,
        evaluate = evaluateTFKick,

        values = {
            kickOrder = "kickOrder",
            addNumber = "addNumber"
        },

        noteBlockSeparator = "\n",

        note = {
            tag = tag,
            template = "#" .. tag .. " Player1 Player2"
        }
    }, BOSS_META.twinFangs))
end

AR({
    boss = BOSS_META.twinFangs,

    key = "venomousAbyssTFFeast1",
    sheet = "VenomousAbyssTwinFangsFeasts",

    labelKey = "BossMods_NoteTFFeasts",
    itemLabelKey = "BossMods_NoteTFFeasts",

    tab = "VenomousAbyss",
    order = 71,

    tag = "TFFeast1",
    textKey = "BossMods_AR_TextTFFeast1"
})

AR({
    boss = BOSS_META.twinFangs,

    key = "venomousAbyssTFFeast2",
    sheet = "VenomousAbyssTwinFangsFeasts",

    labelKey = "BossMods_NoteTFFeasts",
    itemLabelKey = "BossMods_NoteTFFeasts",

    tab = "VenomousAbyss",
    order = 72,

    tag = "TFFeast2",
    textKey = "BossMods_AR_TextTFFeast2"
})

AR({
    boss = BOSS_META.twinFangs,

    key = "venomousAbyssTFFeast3",
    sheet = "VenomousAbyssTwinFangsFeasts",

    labelKey = "BossMods_NoteTFFeasts",
    itemLabelKey = "BossMods_NoteTFFeasts",

    tab = "VenomousAbyss",
    order = 73,

    tag = "TFFeast3",
    textKey = "BossMods_AR_TextTFFeast3"
})

---------------------------------------------------------------------------
-- The Coiled Altar
---------------------------------------------------------------------------

AR({
    boss = BOSS_META.coiledAltar,

    key = "venomousAbyssCAG1",
    sheet = "VenomousAbyssCoiledAltarGuillotines",

    labelKey = "BossMods_NoteCAGuillotines",
    itemLabelKey = "BossMods_NoteCAGuillotines",

    tab = "VenomousAbyss",
    order = 70,

    tag = "CAG1",
    textKey = "BossMods_AR_TextCAG1"
})

AR({
    boss = BOSS_META.coiledAltar,

    key = "venomousAbyssCAG2",
    sheet = "VenomousAbyssCoiledAltarGuillotines",

    labelKey = "BossMods_NoteCAGuillotines",
    itemLabelKey = "BossMods_NoteCAGuillotines",

    tab = "VenomousAbyss",
    order = 71,

    tag = "CAG2",
    textKey = "BossMods_AR_TextCAG2"
})

AR({
    boss = BOSS_META.coiledAltar,

    key = "venomousAbyssCAG3",
    sheet = "VenomousAbyssCoiledAltarGuillotines",

    labelKey = "BossMods_NoteCAGuillotines",
    itemLabelKey = "BossMods_NoteCAGuillotines",

    tab = "VenomousAbyss",
    order = 72,

    tag = "CAG3",
    textKey = "BossMods_AR_TextCAG3"
})

AR({
    boss = BOSS_META.coiledAltar,

    key = "venomousAbyssCAMythOrb",
    sheet = "VenomousAbyssCoiledAltarOrbs",

    labelKey = "BossMods_NoteCAOrbs",
    itemLabelKey = "BossMods_NoteCAOrbs",

    tab = "VenomousAbyss",
    order = 73,

    tag = "CAMythOrb",
    textKey = "BossMods_AR_TextCAMythOrb"
})

AR({
    boss = BOSS_META.coiledAltar,

    key = "venomousAbyssCAHcOrb",
    sheet = "VenomousAbyssCoiledAltarOrbs",

    labelKey = "BossMods_NoteCAOrbs",
    itemLabelKey = "BossMods_NoteCAOrbs",

    tab = "VenomousAbyss",
    order = 74,

    tag = "CAHcOrb",
    textKey = "BossMods_AR_TextCAHcOrb"
})

    ---------------------------------------------------------------------------
    -- Note groups
    ---------------------------------------------------------------------------
    E:RegisterBossModNoteGroup("VenomousAbyss_Nekzali", {
        labelKey = "BossMods_Nekzali",
        itemLabelKey = "BossMods_NoteFull",

        raidKey = RAID_META.raidKey,
        raidLabelKey = RAID_META.raidLabelKey,

        bossKey = BOSS_META.nekzali.bossKey,
        bossLabelKey = BOSS_META.nekzali.bossLabelKey,
        bossOrder = BOSS_META.nekzali.bossOrder,

        itemOrder = 0,
        tab = "VenomousAbyss",
        order = 10,

        entries = {
            "VenomousAbyssFocusFarAdd"
        }
    })

    E:RegisterBossModNoteGroup("VenomousAbyss_EntombedSentinels", {
        labelKey = "BossMods_EntombedSentinels",
        itemLabelKey = "BossMods_NoteFull",

        raidKey = RAID_META.raidKey,
        raidLabelKey = RAID_META.raidLabelKey,

        bossKey = BOSS_META.entombedSentinels.bossKey,
        bossLabelKey = BOSS_META.entombedSentinels.bossLabelKey,
        bossOrder = BOSS_META.entombedSentinels.bossOrder,

        itemOrder = 0,
        tab = "VenomousAbyss",
        order = 20,

        entries = {
            "VenomousAbyssEntombedSentinelsStarts"
        }
    })

    E:RegisterBossModNoteGroup("VenomousAbyss_LostExplorers", {
        labelKey = "BossMods_LostExplorers",
        itemLabelKey = "BossMods_NoteFull",

        raidKey = RAID_META.raidKey,
        raidLabelKey = RAID_META.raidLabelKey,

        bossKey = BOSS_META.lostExplorers.bossKey,
        bossLabelKey = BOSS_META.lostExplorers.bossLabelKey,
        bossOrder = BOSS_META.lostExplorers.bossOrder,

        itemOrder = 0,
        tab = "VenomousAbyss",
        order = 30,

        entries = {
            "VenomousAbyssLostExplorersThuds"
        }
    })

    E:RegisterBossModNoteGroup("VenomousAbyss_Sszorak", {
        labelKey = "BossMods_Sszorak",
        itemLabelKey = "BossMods_NoteFull",

        raidKey = RAID_META.raidKey,
        raidLabelKey = RAID_META.raidLabelKey,

        bossKey = BOSS_META.sszorak.bossKey,
        bossLabelKey = BOSS_META.sszorak.bossLabelKey,
        bossOrder = BOSS_META.sszorak.bossOrder,

        itemOrder = 0,
        tab = "VenomousAbyss",
        order = 50,

        entries = {
            "VenomousAbyssSszorakSoaks",
            "VenomousAbyssSszorakWindMarkers"
        }
    })

    E:RegisterBossModNoteGroup("VenomousAbyss_TwinFangs", {
        labelKey = "BossMods_TwinFangs",
        itemLabelKey = "BossMods_NoteFull",

        raidKey = RAID_META.raidKey,
        raidLabelKey = RAID_META.raidLabelKey,

        bossKey = BOSS_META.twinFangs.bossKey,
        bossLabelKey = BOSS_META.twinFangs.bossLabelKey,
        bossOrder = BOSS_META.twinFangs.bossOrder,

        itemOrder = 0,
        tab = "VenomousAbyss",
        order = 60,

        entries = {
            "VenomousAbyssTwinFangsKicks",
            "VenomousAbyssTwinFangsFeasts"
        }
    })

    E:RegisterBossModNoteGroup("VenomousAbyss_CoiledAltar", {
        labelKey = "BossMods_CoiledAltar",
        itemLabelKey = "BossMods_NoteFull",

        raidKey = RAID_META.raidKey,
        raidLabelKey = RAID_META.raidLabelKey,

        bossKey = BOSS_META.coiledAltar.bossKey,
        bossLabelKey = BOSS_META.coiledAltar.bossLabelKey,
        bossOrder = BOSS_META.coiledAltar.bossOrder,

        itemOrder = 0,
        tab = "VenomousAbyss",
        order = 70,

        entries = {
            "VenomousAbyssCoiledAltarGuillotines",
            "VenomousAbyssCoiledAltarOrbs"
        }
    })
end
-------------------------------------------------------------------------------
-- Combat Tools features
-------------------------------------------------------------------------------
E:RegisterBossModFeature("VenomousAbyssNekzali", {
    tab = "VenomousAbyss",
    order = 10,
    labelKey = "BossMods_Nekzali",
    descKey = "BossMods_NekzaliDesc",
    moduleName = "BossMods_AssignmentReminders"
})

E:RegisterBossModFeature("VenomousAbyssEntombedSentinels", {
    tab = "VenomousAbyss",
    order = 20,
    labelKey = "BossMods_EntombedSentinels",
    descKey = "BossMods_EntombedSentinelsDesc",
    moduleName = "BossMods_AssignmentReminders"
})

E:RegisterBossModFeature("VenomousAbyssLostExplorers", {
    tab = "VenomousAbyss",
    order = 30,
    labelKey = "BossMods_LostExplorers",
    descKey = "BossMods_LostExplorersDesc",
    moduleName = "BossMods_AssignmentReminders"
})

E:RegisterBossModFeature("VenomousAbyssVashnik", {
    tab = "VenomousAbyss",
    order = 40,
    labelKey = "BossMods_Vashnik",
    descKey = "BossMods_VashnikDesc",
    moduleName = "BossMods_AssignmentReminders"
})

E:RegisterBossModFeature("VenomousAbyssSszorak", {
    tab = "VenomousAbyss",
    order = 50,
    labelKey = "BossMods_Sszorak",
    descKey = "BossMods_SszorakDesc",
    moduleName = "BossMods_AssignmentReminders"
})

E:RegisterBossModFeature("VenomousAbyssTwinFangs", {
    tab = "VenomousAbyss",
    order = 60,
    labelKey = "BossMods_TwinFangs",
    descKey = "BossMods_TwinFangsDesc",
    moduleName = "BossMods_AssignmentReminders"
})

E:RegisterBossModFeature("VenomousAbyssCoiledAltar", {
    tab = "VenomousAbyss",
    order = 70,
    labelKey = "BossMods_CoiledAltar",
    descKey = "BossMods_CoiledAltarDesc",
    moduleName = "BossMods_AssignmentReminders"
})

E:RegisterBossModFeature("VenomousAbyssUlatek", {
    tab = "VenomousAbyss",
    order = 80,
    labelKey = "BossMods_Ulatek",
    descKey = "BossMods_UlatekDesc",
    moduleName = "BossMods_AssignmentReminders"
})
