local E = unpack(ART)

local BossMods = E:GetModule("BossMods")
local Text = BossMods and BossMods.ReadyAssignmentText

if Text and Text.Register then
    local RAID_META = {
        raidKey = "Voidspire",
        raidLabelKey = "BossMods_Voidspire"
    }

    local BOSS_META = {
        vaelgorEzzorak = {
            bossKey = "VaelgorEzzorak",
            bossLabelKey = "BossMods_VaelgorEzzorak",
            bossOrder = 40
        },
        vanguard = {
            bossKey = "Vanguard",
            bossLabelKey = "BossMods_Vanguard",
            bossOrder = 50
        },
        alleria = {
            bossKey = "Alleria",
            bossLabelKey = "BossMods_Alleria",
            bossOrder = 60
        }
    }

    local function raidMarker(index)
        return ("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%d:0|t"):format(index)
    end

    local function withMeta(opts, bossMeta)
        for key, value in pairs(RAID_META) do
            opts[key] = opts[key] or value
        end
        for key, value in pairs(bossMeta or {}) do
            opts[key] = opts[key] or value
        end
        return opts
    end

    local function register(defs)
        for _, def in ipairs(defs) do
            Text:Register(def.key, def)
        end
    end

    local function displayName(token)
        local NoteBlock = BossMods and BossMods.NoteBlock
        if NoteBlock and NoteBlock.GetColoredDisplayName then
            return NoteBlock:GetColoredDisplayName(token) or token
        end
        if NoteBlock and NoteBlock.GetDisplayName then
            return NoteBlock:GetDisplayName(token) or token
        end
        return token
    end

    local function evaluateGapAssist(provider, ctx, out, api)
        local NoteBlock = BossMods and BossMods.NoteBlock
        if not (NoteBlock and NoteBlock.ExtractBlock) then
            return
        end

        local block = NoteBlock:ExtractBlock(ctx and ctx.noteText or "", provider.noteBlock)
        if not block then
            return
        end

        local lineIndex = 0
        for raw in block:gmatch("[^\r\n]+") do
            local line = raw:gsub("^%s+", ""):gsub("%s+$", "")
            if line ~= "" then
                lineIndex = lineIndex + 1

                local words = api:Words(line)
                local assignee = words[1]
                local target = words[2]
                if assignee and target and api:TokenIsPlayer(assignee, ctx) then
                    api:Add(out, api:NewReminder(provider, {
                        key = provider.key,
                        type = provider.type or provider.key,
                        noteBlock = provider.noteBlock,
                        lineIndex = lineIndex,
                        tokenIndex = 1,
                        line = line,
                        target = displayName(target),
                        priority = provider.priority or 50
                    }))
                    return
                end
            end
        end
    end

    register({withMeta({
        key = "voidspireGloomG1",
        sheet = "VoidspireGloom",
        labelKey = "BossMods_NoteGloomSoaks",
        itemLabelKey = "BossMods_NoteGloomSoaks",
        tab = "Voidspire",
        order = 40,
        source = "hashtag",
        tag = "GloomG1",
        type = "voidspireGloom",
        textKey = "BossMods_AR_TextSoakAssignment",
        priority = 70,
        players = 7,
        noteBlockSeparator = "\n",
        localeValues = {
            assignment = "BossMods_AR_AssignmentGloom1"
        }
    }, BOSS_META.vaelgorEzzorak), withMeta({
        key = "voidspireGloomG2",
        sheet = "VoidspireGloom",
        source = "hashtag",
        tag = "GloomG2",
        type = "voidspireGloom",
        textKey = "BossMods_AR_TextSoakAssignment",
        priority = 70,
        players = 7,
        localeValues = {
            assignment = "BossMods_AR_AssignmentGloom2"
        }
    }, BOSS_META.vaelgorEzzorak), withMeta({
        key = "voidspireVanguardCross",
        sheet = "VoidspireVanguardSoaks",
        labelKey = "BossMods_NoteMarkerSoaks",
        itemLabelKey = "BossMods_NoteMarkerSoaks",
        tab = "Voidspire",
        order = 50,
        source = "hashtag",
        tag = "VanCross",
        type = "voidspireVanguardSoak",
        textKey = "BossMods_AR_TextSoakAssignment",
        priority = 70,
        players = 5,
        noteBlockSeparator = "\n",
        defaultValues = {
            assignment = raidMarker(7)
        }
    }, BOSS_META.vanguard), withMeta({
        key = "voidspireVanguardDiamond",
        sheet = "VoidspireVanguardSoaks",
        source = "hashtag",
        tag = "VanDiamond",
        type = "voidspireVanguardSoak",
        textKey = "BossMods_AR_TextSoakAssignment",
        priority = 70,
        players = 5,
        defaultValues = {
            assignment = raidMarker(3)
        }
    }, BOSS_META.vanguard), withMeta({
        key = "voidspireVanguardTriangle",
        sheet = "VoidspireVanguardSoaks",
        source = "hashtag",
        tag = "VanTriangle",
        type = "voidspireVanguardSoak",
        textKey = "BossMods_AR_TextSoakAssignment",
        priority = 70,
        players = 5,
        defaultValues = {
            assignment = raidMarker(4)
        }
    }, BOSS_META.vanguard), withMeta({
        key = "voidspireVanguardSquare",
        sheet = "VoidspireVanguardSoaks",
        source = "hashtag",
        tag = "VanSquare",
        type = "voidspireVanguardSoak",
        textKey = "BossMods_AR_TextSoakAssignment",
        priority = 70,
        players = 5,
        defaultValues = {
            assignment = raidMarker(6)
        }
    }, BOSS_META.vanguard), withMeta({
        key = "voidspireElkBait",
        sheet = "VoidspireElkBait",
        labelKey = "BossMods_NoteElkBait",
        itemLabelKey = "BossMods_NoteElkBait",
        tab = "Voidspire",
        order = 51,
        source = "hashtag",
        tag = "ElkBait",
        type = "voidspireElkBait",
        textKey = "BossMods_AR_TextElkBait",
        priority = 65,
        players = 3
    }, BOSS_META.vanguard), withMeta({
        key = "voidspireCrownKillSquad",
        sheet = "VoidspireCrownKillSquad",
        labelKey = "BossMods_NoteKillSquad",
        itemLabelKey = "BossMods_NoteKillSquad",
        tab = "Voidspire",
        order = 60,
        source = "hashtag",
        tag = "CrownKillSquad",
        type = "voidspireCrownKillSquad",
        textKey = "BossMods_AR_TextKillSquad",
        priority = 70,
        players = 3
    }, BOSS_META.alleria), withMeta({
        key = "voidspireCrownGapAssist",
        sheet = "VoidspireCrownGapAssist",
        labelKey = "BossMods_NoteGapAssist",
        itemLabelKey = "BossMods_NoteGapAssist",
        tab = "Voidspire",
        order = 61,
        noteBlock = "crowngap",
        type = "voidspireCrownGapAssist",
        textKey = "BossMods_AR_TextAssistOver",
        priority = 68,
        evaluate = evaluateGapAssist,
        values = {
            target = "target"
        },
        note = {
            tag = "crowngap",
            template = "crowngapStart\nPlayer1 Player2\nPlayer3 Player4\nPlayer5 Player6\ncrowngapEnd"
        }
    }, BOSS_META.alleria)})

    E:RegisterBossModNoteGroup("Voidspire_VaelgorEzzorak", {
        labelKey = "BossMods_VaelgorEzzorak",
        itemLabelKey = "BossMods_NoteFull",
        raidKey = RAID_META.raidKey,
        raidLabelKey = RAID_META.raidLabelKey,
        bossKey = BOSS_META.vaelgorEzzorak.bossKey,
        bossLabelKey = BOSS_META.vaelgorEzzorak.bossLabelKey,
        bossOrder = BOSS_META.vaelgorEzzorak.bossOrder,
        itemOrder = 0,
        tab = "Voidspire",
        order = 40,
        entries = {"VoidspireGloom"}
    })

    E:RegisterBossModNoteGroup("Voidspire_Vanguard", {
        labelKey = "BossMods_Vanguard",
        itemLabelKey = "BossMods_NoteFull",
        raidKey = RAID_META.raidKey,
        raidLabelKey = RAID_META.raidLabelKey,
        bossKey = BOSS_META.vanguard.bossKey,
        bossLabelKey = BOSS_META.vanguard.bossLabelKey,
        bossOrder = BOSS_META.vanguard.bossOrder,
        itemOrder = 0,
        tab = "Voidspire",
        order = 50,
        entries = {"VoidspireVanguardSoaks", "VoidspireElkBait"}
    })

    E:RegisterBossModNoteGroup("Voidspire_Alleria", {
        labelKey = "BossMods_Alleria",
        itemLabelKey = "BossMods_NoteFull",
        raidKey = RAID_META.raidKey,
        raidLabelKey = RAID_META.raidLabelKey,
        bossKey = BOSS_META.alleria.bossKey,
        bossLabelKey = BOSS_META.alleria.bossLabelKey,
        bossOrder = BOSS_META.alleria.bossOrder,
        itemOrder = 0,
        tab = "Voidspire",
        order = 60,
        entries = {"VoidspireCrownKillSquad", "VoidspireCrownGapAssist"}
    })
end
