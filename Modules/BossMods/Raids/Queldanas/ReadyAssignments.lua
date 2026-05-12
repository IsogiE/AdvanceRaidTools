local E = unpack(ART)

local BossMods = E:GetModule("BossMods")
local Text = BossMods and BossMods.ReadyAssignmentText

if Text and Text.Register then
    local REMINDER_TEXT = {
        reminders = {{
            key = "luraCrystals",
            sheet = "LuraCrystals",
            standalone = true,
            labelKey = "BossMods_LuraCrystals",
            tab = "Queldanas",
            order = 25,
            source = "hashtag",
            tag = "lurapickup",
            type = "hashtag",
            textKey = "BossMods_AR_TextLuraCrystals",
            priority = 60,
            players = 6
        }, {
            key = "luraMapReady",
            sheet = "LuraMap",
            standalone = true,
            labelKey = "BossMods_LuraMap",
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
        }, {
            key = "kick",
            sheet = "Lurakick",
            labelKey = "BossMods_Lurakick",
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
        }, {
            key = "dirge",
            sheet = "Dirge",
            labelKey = "BossMods_Dirge",
            tab = "Queldanas",
            order = 50,
            source = "noteBlock",
            noteBlock = "dirge",
            type = "dirge",
            moduleName = "BossMods_Dirge",
            textKey = "BossMods_AR_TextDirgeRunes",
            priority = 80,
            rows = 3
        }, {
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
        }, {
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
        }}
    }

    for _, def in ipairs(REMINDER_TEXT.reminders) do
        Text:Register(def.key, def)
    end
end
