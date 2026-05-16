local E = unpack(ART)

local BossMods = E:GetModule("BossMods")
local Text = BossMods and BossMods.ReadyAssignmentText

if Text and Text.Register then
    local LURA_NOTE_META = {
        raidKey = "Queldanas",
        raidLabelKey = "BossMods_Queldanas",
        bossKey = "Lura",
        bossLabelKey = "BossMods_Lura"
    }

    local function luraNote(opts)
        for key, value in pairs(LURA_NOTE_META) do
            opts[key] = opts[key] or value
        end
        return opts
    end

    local REMINDER_TEXT = {
        reminders = {luraNote({
            key = "luraCrystals",
            sheet = "LuraCrystals",
            standalone = true,
            labelKey = "BossMods_LuraCrystals",
            itemLabelKey = "BossMods_NoteCrystals",
            tab = "Queldanas",
            order = 25,
            source = "hashtag",
            tag = "lurapickup",
            type = "hashtag",
            textKey = "BossMods_AR_TextLuraCrystals",
            priority = 60,
            players = 6
        }), luraNote({
            key = "luraMapReady",
            sheet = "LuraMap",
            standalone = true,
            labelKey = "BossMods_LuraMap",
            itemLabelKey = "BossMods_NoteSpreadMap",
            tab = "Queldanas",
            order = 40,
            source = "hashtagWord",
            tag = "showmap",
            word = "lura",
            type = "visual",
            moduleName = "BossMods_LuraMap",
            action = {
                moduleName = "BossMods_LuraMap",
                method = "ShowReadyAssignments",
                hideMethod = "HideReadyAssignments",
                args = {"duration", "visualAnchor"}
            }
        }), luraNote({
            key = "kick",
            sheet = "Lurakick",
            labelKey = "BossMods_Lurakick",
            itemLabelKey = "BossMods_NoteKickAssignments",
            tab = "Queldanas",
            order = 30,
            source = "noteBlock",
            noteBlock = "kick",
            type = "kick",
            moduleName = "BossMods_Lurakick",
            textKey = "BossMods_AR_TextKick",
            priority = 90,
            rows = {3, 3, 3},
            values = {
                prism = "lineIndex",
                kickIndex = "tokenIndex"
            },
            defaultValues = {
                prism = 0,
                kickIndex = 0
            }
        }), luraNote({
            key = "dirge",
            sheet = "Dirge",
            labelKey = "BossMods_Dirge",
            itemLabelKey = "BossMods_NoteMemoryGame",
            tab = "Queldanas",
            order = 50,
            source = "noteBlock",
            noteBlock = "dirge",
            type = "dirge",
            moduleName = "BossMods_Dirge",
            textKey = "BossMods_AR_TextDirgeRunes",
            priority = 80,
            rows = 3
        }), luraNote({
            key = "requiemRight",
            sheet = "Dirge",
            source = "noteBlock",
            noteBlock = "requimg1",
            type = "requiem",
            moduleName = "BossMods_Dirge",
            textKey = "BossMods_AR_TextRequiem",
            priority = 78,
            rows = 3,
            localeValues = {
                direction = "Right"
            }
        }), luraNote({
            key = "requiemLeft",
            sheet = "Dirge",
            source = "noteBlock",
            noteBlock = "requimg2",
            type = "requiem",
            moduleName = "BossMods_Dirge",
            textKey = "BossMods_AR_TextRequiem",
            priority = 78,
            rows = 3,
            localeValues = {
                direction = "Left"
            }
        })}
    }

    for _, def in ipairs(REMINDER_TEXT.reminders) do
        Text:Register(def.key, def)
    end

    E:RegisterBossModNoteGroup("Queldanas_Lura", {
        labelKey = "BossMods_Lura",
        itemLabelKey = "BossMods_NoteFull",
        raidKey = "Queldanas",
        raidLabelKey = "BossMods_Queldanas",
        bossKey = "Lura",
        bossLabelKey = "BossMods_Lura",
        itemOrder = 0,
        tab = "Queldanas",
        order = 20,
        entries = {"LuraCrystals", "Lurakick", "LuraMap", "Dirge"}
    })
end
