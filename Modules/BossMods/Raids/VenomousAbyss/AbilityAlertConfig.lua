local E, L = unpack(ART)

local issecretvalue = issecretvalue or function() return false end

local MIGHTY_THUD_SPELL_ID = 1296092
local ROUSE_THE_BROOD_SPELL_ID = 1308356
local RAVENOUS_FEAST_SPELL_ID = 1290516
local VENOM_COAGULATION_SPELL_ID = 1284251
local UNSTABLE_MIASMA_SPELL_ID = 1288232
local GRASPING_DEPTHS_SPELL_ID = 1293212

local COILED_ALTAR_ENCOUNTER_ID = 3429
local COILED_ALTAR_FEATURE_KEY = "VenomousAbyssCoiledAltar"
local COILED_ALTAR_NIGHTFALL_SPELL_ID = 1286918
local COILED_ALTAR_NIGHTFALL_DURATION = 15
local COILED_ALTAR_NIGHTFALL_BAR_ORDER = 130
local COILED_ALTAR_NIGHTFALL_SAMPLE_DELAY = 0.2

local ULATEK_ENCOUNTER_ID = 3492
local ULATEK_FEATURE_KEY = "VenomousAbyssUlatek"
local ULATEK_CHECK_DURATION = 35
local ULATEK_BAR_ORDER = 130
local ULATEK_UNIT_REFRESH_INTERVAL = 0.1
local ULATEK_EMPTY_GRACE = 0.2
local ULATEK_BOSS_UNITS = {"boss2", "boss3"}

local bossMods
local shared

local ENTOMBED_HIDDEN_CASTS = {
    green = {
        [VENOM_COAGULATION_SPELL_ID] = {
            [2] = true, [3] = true, [6] = true,
            [7] = true, [10] = true, [11] = true
        },
        [UNSTABLE_MIASMA_SPELL_ID] = {
            [1] = true, [4] = true, [5] = true,
            [8] = true, [9] = true
        }
    },
    red = {
        [VENOM_COAGULATION_SPELL_ID] = {
            [1] = true, [4] = true, [5] = true,
            [8] = true, [9] = true
        },
        [UNSTABLE_MIASMA_SPELL_ID] = {
            [2] = true, [3] = true, [6] = true,
            [7] = true, [10] = true, [11] = true
        }
    }
}

local function getReadyAssignmentContext()
    local bossMods = E:GetModule("BossMods", true)
    local ready = bossMods and bossMods.ReadyAssignments

    if not ready or not ready.BuildContext
        or not ready.FindPlayerInHashTag
        or not ready.NormalizeTag
        or not ready.Words
        or not ready.TokenIsPlayer
    then
        return nil, nil
    end

    local nicknames = E:GetModule("Nicknames", true)

    if nicknames and nicknames.SyncSelfNickname then
        nicknames:SyncSelfNickname()
    end

    local context = ready:BuildContext()
    local configuredNickname = nicknames
        and nicknames.db
        and nicknames.db.myNickname

    if type(configuredNickname) == "string"
        and configuredNickname ~= ""
        and context
    then
        context.ids = context.ids or {}
        context.ids.nickname = configuredNickname:lower()
    end

    return ready, context
end

local function findPlayerPositionInHashTag(ready, context, tag, maxPosition)
    tag = ready:NormalizeTag(tag)

    if not tag or not context or not context.tags then
        return nil
    end

    for _, section in ipairs(context.tags[tag] or {}) do
        local text = section.text or section.headerText or ""
        local words = ready:Words(text)

        for position = 1, math.min(#words, maxPosition) do
            if ready:TokenIsPlayer(words[position], context) then
                return position
            end
        end
    end
end

local function findPlayerHitsInTags(ready, context, prefix, count)
    local hits = {}
    local found

    for hit = 1, count do
        if ready:FindPlayerInHashTag(
            context,
            prefix .. hit,
            { hashtagMultiline = true }
        ) then
            hits[hit] = true
            found = true
        end
    end

    return found and hits or nil
end

local function isMightyThudAbility(ability)
    local spellID = ability and tonumber(ability.spellID)
    local triggerSpellID = ability and tonumber(ability.triggerSpellID)

    return spellID == MIGHTY_THUD_SPELL_ID
        or spellID == -MIGHTY_THUD_SPELL_ID
        or triggerSpellID == MIGHTY_THUD_SPELL_ID
end

local function getAbilityAssignment(ability)
    local spellID = ability and tonumber(ability.spellID)
    local mightyThud = isMightyThudAbility(ability)

    if not mightyThud
        and spellID ~= ROUSE_THE_BROOD_SPELL_ID
        and spellID ~= RAVENOUS_FEAST_SPELL_ID
    then
        return nil
    end

    local ready, context = getReadyAssignmentContext()

    if not ready then
        return nil
    end

    local assignments = {}

    if mightyThud then
        for hit = 1, 3 do
            if ready:FindPlayerInHashTag(
                context,
                "LEThud" .. hit,
                { hashtagMultiline = true }
            ) then
                assignments[#assignments + 1] =
                    L["BossMods_VA_Assignment_SoakThud"]:format(hit)
            end
        end
    elseif spellID == ROUSE_THE_BROOD_SPELL_ID then
        for addNumber = 1, 10 do
            local position = findPlayerPositionInHashTag(
                ready,
                context,
                "TFKick" .. addNumber,
                2
            )

            if position then
                local localeKey = position == 1
                    and "BossMods_VA_Assignment_KickAddFirst"
                    or "BossMods_VA_Assignment_KickAddSecond"
                assignments[#assignments + 1] =
                    L[localeKey]:format(addNumber)
            end
        end
    else
        local hits = findPlayerHitsInTags(ready, context, "TFFeast", 3)

        for hit = 1, 3 do
            if hits and hits[hit] then
                assignments[#assignments + 1] =
                    L["BossMods_VA_Assignment_SoakHit"]:format(hit)
            end
        end
    end

    return #assignments > 0 and table.concat(assignments, " | ") or nil
end

local function getAssignedHits(kind)
    local ready, context = getReadyAssignmentContext()

    if not ready then
        return nil
    end

    if kind == "mightyThud" then
        return findPlayerHitsInTags(ready, context, "LEThud", 3)
    elseif kind == "ravenousFeast" then
        return findPlayerHitsInTags(ready, context, "TFFeast", 3)
    end
end

local function getEntombedAssignment()
    local _, _, difficultyID = GetInstanceInfo()

    if not issecretvalue(difficultyID) and tonumber(difficultyID) == 16 then
        if not IsInRaid or not IsInRaid() then
            return nil
        end

        local raidIndex = UnitInRaid and UnitInRaid("player")
        if type(raidIndex) ~= "number" or issecretvalue(raidIndex) then
            return nil
        end

        local subgroup = select(3, GetRaidRosterInfo(raidIndex))
        if type(subgroup) ~= "number" or issecretvalue(subgroup) then
            return nil
        end

        if subgroup == 1 or subgroup == 2 then
            return "green"
        elseif subgroup == 3 or subgroup == 4 then
            return "red"
        end

        return nil
    end

    local ready, context = getReadyAssignmentContext()

    if not ready then
        return nil
    end

    local green = ready:FindPlayerInHashTag(
        context,
        "ESGreen",
        { hashtagMultiline = true }
    )
    local red = ready:FindPlayerInHashTag(
        context,
        "ESRed",
        { hashtagMultiline = true }
    )

    if green and not red then
        return "green"
    elseif red and not green then
        return "red"
    end
end

local function getNekzaliGroupAssignment()
    local ready, context = getReadyAssignmentContext()

    if not ready then
        return nil
    end

    local groupOne = ready:FindPlayerInHashTag(
        context,
        "NekG1",
        { hashtagMultiline = true }
    )
    local groupTwo = ready:FindPlayerInHashTag(
        context,
        "NekG2",
        { hashtagMultiline = true }
    )

    -- A malformed note containing the player in both groups consistently
    -- follows Group 1 rather than changing behavior between countdowns.
    if groupOne then
        return 1
    elseif groupTwo then
        return 2
    end
end

local function getAssignmentTextState(self, ability, testMode)
    if not ability
        or ability.kind ~= "assignmentText"
        or tonumber(ability.triggerSpellID) ~= GRASPING_DEPTHS_SPELL_ID
    then
        return nil
    end

    local group = testMode and 1 or getNekzaliGroupAssignment()

    if not group then
        return nil
    end

    local castNumber

    if testMode then
        castNumber = 1
    else
        local now = GetTime()
        local lastTimer = self.nekzaliGraspingLastTimer

        if lastTimer and now - lastTimer.time < 0.75 then
            castNumber = lastTimer.castNumber
        else
            castNumber = (self.nekzaliGraspingCastCount or 0) + 1
            self.nekzaliGraspingCastCount = castNumber
            self.nekzaliGraspingLastTimer = {
                time = now,
                castNumber = castNumber
            }
        end
    end

    local groupGoingDown = castNumber % 2 == group % 2

    return {
        castNumber = castNumber,
        message = groupGoingDown
            and L["BossMods_VA_Assignment_GroupGoingDown"]
            or L["BossMods_VA_Assignment_NotGoingDown"],
        color = groupGoingDown
            and {0.10, 0.90, 0.20, 1}
            or {1.00, 0.10, 0.10, 1}
    }
end

local function isCoiledAltarNightfallBarEnabled(self)
    return self.db.coiledAltarNightfallBarEnabled ~= false
        and bossMods:IsFeatureEnabled(COILED_ALTAR_FEATURE_KEY)
end

local function applyCoiledAltarNightfallAbsorb(bar, absorb)
    if not absorb then
        return false
    end

    if issecretvalue(absorb) then
        if not bar.maxAbsorb then
            bar.maxAbsorb = absorb
            bar.maxAbsorbIsSecret = true
        end

        bar.frame:SetMinMaxValues(0, bar.maxAbsorb)
        bar.frame:SetValue(absorb)
        bar:SetMiddle("")
        return true
    end

    absorb = tonumber(absorb)
    if not absorb then
        return false
    end

    if bar.maxAbsorbIsSecret then
        bar.frame:SetMinMaxValues(0, bar.maxAbsorb)
        bar.frame:SetValue(absorb)
        bar:SetMiddle("")
        return true
    end

    if absorb > 0 or (bar.maxAbsorb or 0) > 0 then
        bar.maxAbsorb = math.max(bar.maxAbsorb or 0, absorb)
        local maxAbsorb = math.max(1, bar.maxAbsorb or 0)

        bar.frame:SetMinMaxValues(0, maxAbsorb)
        bar.frame:SetValue(math.max(0, math.min(maxAbsorb, absorb)))
        bar:SetMiddle("")
        return true
    end

    return false
end

local function paintCoiledAltarNightfallBar(bar, elapsed)
    local unit = bar.unit

    if unit and UnitExists(unit) then
        if elapsed
            and elapsed < COILED_ALTAR_NIGHTFALL_SAMPLE_DELAY
            and not bar.maxAbsorb
        then
            bar.frame:SetMinMaxValues(0, 1)
            bar.frame:SetValue(1)
            return
        end

        if UnitGetTotalAbsorbs
            and applyCoiledAltarNightfallAbsorb(
                bar,
                UnitGetTotalAbsorbs(unit)
            )
        then
            return
        end

        shared.PaintUnitHealth(bar.frame, unit)
        bar:SetMiddle("")
        return
    end

    bar.frame:SetMinMaxValues(0, 1)
    bar.frame:SetValue(0)
    bar:SetMiddle("")
end

local function ensureCoiledAltarNightfallBar(self)
    local bar = self:EnsureManagedBar(
        "coiledAltarNightfall",
        "CoiledAltar",
        COILED_ALTAR_NIGHTFALL_BAR_ORDER,
        {manualFill = true}
    )

    if not self.coiledAltarNightfallBar then
        bar.onFrame = function(elapsed, total)
            if bar.testPaceOffset ~= nil then
                local requiredShield = (total - elapsed) / total
                local simulatedShield = math.max(
                    0,
                    math.min(1, requiredShield + bar.testPaceOffset)
                )

                bar.frame:SetMinMaxValues(0, 1)
                bar.frame:SetValue(simulatedShield)
                bar:SetMiddle("")
            else
                paintCoiledAltarNightfallBar(bar, elapsed)
            end
        end

        bar.onTick = function(elapsed, total)
            local remaining = math.max(0, total - elapsed)
            bar:SetRight(("%.1f"):format(remaining))
            bar:SetMarker(total > 0 and remaining / total or nil)
        end

        bar.onStop = function()
            bar.unit = nil
            bar.maxAbsorb = nil
            bar.maxAbsorbIsSecret = nil
            bar.testPaceOffset = nil
            bar:SetMarker(nil)
            paintCoiledAltarNightfallBar(bar)
            bar:Hide()
            self:ApplyPositions()
        end

        self.coiledAltarNightfallBar = bar
    end

    return bar
end

local function clearCoiledAltarNightfallTimer(self)
    if self.coiledAltarNightfallTimer then
        self.coiledAltarNightfallTimer:Cancel()
        self.coiledAltarNightfallTimer = nil
    end
end

local function stopCoiledAltarNightfall(self)
    clearCoiledAltarNightfallTimer(self)

    local bar = self.coiledAltarNightfallBar

    if not bar then
        return
    end

    if bar:IsRunning() then
        bar:Stop()
    else
        bar.unit = nil
        bar.maxAbsorb = nil
        bar.maxAbsorbIsSecret = nil
        bar.testPaceOffset = nil
        paintCoiledAltarNightfallBar(bar)
        bar:Hide()
    end
end

local function startCoiledAltarNightfall(self)
    if not self.coiledAltarEncounterActive
        or not isCoiledAltarNightfallBarEnabled(self)
    then
        return
    end

    local now = GetTime()

    if self.coiledAltarNightfallStartedAt
        and now - self.coiledAltarNightfallStartedAt < 1
    then
        return
    end

    clearCoiledAltarNightfallTimer(self)

    local bar = ensureCoiledAltarNightfallBar(self)

    if bar:IsRunning() then
        bar:Stop()
    end

    self.coiledAltarNightfallStartedAt = now
    bar.unit = "boss2"
    bar.maxAbsorb = nil
    bar.maxAbsorbIsSecret = nil
    bar.testPaceOffset = nil
    bar.frame:SetMinMaxValues(0, 1)
    bar:SetMode("label")
    bar:SetLabel(L["BossMods_CoiledAltarNightfallBar"])
    bar:SetMiddle("")
    bar:SetRight(("%.1f"):format(COILED_ALTAR_NIGHTFALL_DURATION))
    bar:Start({total = COILED_ALTAR_NIGHTFALL_DURATION})
    self:ApplyPositions()
end

local function scheduleCoiledAltarNightfall(self, duration)
    if not self.coiledAltarEncounterActive
        or not isCoiledAltarNightfallBarEnabled(self)
    then
        return
    end

    clearCoiledAltarNightfallTimer(self)

    local delay = math.max(0, tonumber(duration) or 0)

    if delay <= COILED_ALTAR_NIGHTFALL_DURATION + 0.5 then
        startCoiledAltarNightfall(self)
        return
    end

    self.coiledAltarNightfallTimer = C_Timer.NewTimer(delay, function()
        self.coiledAltarNightfallTimer = nil
        startCoiledAltarNightfall(self)
    end)
end

local function testCoiledAltarNightfallBar(self)
    if not isCoiledAltarNightfallBarEnabled(self) then
        return
    end

    local bar = ensureCoiledAltarNightfallBar(self)

    if bar:IsRunning() then
        bar:Stop()
    end

    bar.unit = nil
    bar.maxAbsorb = nil
    bar.maxAbsorbIsSecret = nil
    bar.testPaceOffset = 0.12
    bar.frame:SetMinMaxValues(0, 1)
    bar:SetMode("label")
    bar:SetLabel(L["BossMods_CoiledAltarNightfallBar"])
    bar:SetMiddle("")
    bar:SetRight(("%.1f"):format(COILED_ALTAR_NIGHTFALL_DURATION))
    bar:Start({total = COILED_ALTAR_NIGHTFALL_DURATION})
    self:ApplyPositions()
end

local function onCoiledAltarBigWigsStartBar(self, spellID, _, duration)
    if tonumber(spellID) ~= COILED_ALTAR_NIGHTFALL_SPELL_ID then
        return
    end

    scheduleCoiledAltarNightfall(self, duration)
end

local function onCoiledAltarBigWigsStage(self, module)
    if not self.coiledAltarEncounterActive
        or not module
        or module.moduleName ~= "The Coiled Altar"
    then
        return
    end

    stopCoiledAltarNightfall(self)
end

local reconcileUlatekUnits

local function ensureUlatekBars(self)
    self.ulatekShriekerBars = self.ulatekShriekerBars or {}

    for row = 1, 2 do
        local bar = self:EnsureManagedBar(
            "ulatekShrieker" .. row,
            "Ulatek",
            ULATEK_BAR_ORDER + row,
            {manualFill = true}
        )

        if not self.ulatekShriekerBars[row] then
            bar.onFrame = function(elapsed, total)
                if bar.testPaceOffset ~= nil then
                    local requiredHealth = (total - elapsed) / total
                    local simulatedHealth = math.max(
                        0,
                        math.min(1, requiredHealth + bar.testPaceOffset)
                    )
                    bar.frame:SetMinMaxValues(0, 1)
                    bar.frame:SetValue(simulatedHealth)
                else
                    shared.PaintUnitHealth(bar.frame, bar.unit)
                end
            end

            bar.onTick = function(elapsed, total)
                local remaining = math.max(0, total - elapsed)
                bar:SetRight(("%.1f"):format(remaining))
                bar:SetMarker(remaining / total)
            end

            bar.onStop = function()
                bar.unit = nil
                bar.testPaceOffset = nil
                bar:SetMarker(nil)
                shared.PaintUnitHealth(bar.frame, nil)
                bar:Hide()
                self:ApplyPositions()
            end

            self.ulatekShriekerBars[row] = bar
        end
    end
end

local function isUlatekBarEnabled(self)
    return self.db.ulatekShriekerBarEnabled ~= false
        and bossMods:IsFeatureEnabled(ULATEK_FEATURE_KEY)
end

local function updateUlatekFinalPhase(self)
    if self.ulatekFinalPhase then
        return true
    end

    local stage = tonumber(self.ulatekBigWigsStage)

    -- BigWigs reaches stage 2 when boss1 first becomes untargetable. Its
    -- return is the final phase; latch it because Ula'tek can Submerge later.
    if stage and stage >= 2
        and UnitExists("boss1")
        and UnitCanAttack("player", "boss1")
    then
        self.ulatekFinalPhase = true
    end

    return self.ulatekFinalPhase
end

local function onUlatekBigWigsStage(self, module, stage)
    if not self.ulatekEncounterActive
        or not module
        or module.moduleName ~= "Ula'tek"
    then
        return
    end

    self.ulatekBigWigsStage = tonumber(stage)

    if self.ulatekBigWigsStage
        and self.ulatekBigWigsStage >= 3
    then
        self.ulatekFinalPhase = true
    end
end

local function stopUlatekWave(self)
    self.ulatekWaveActive = false
    self.ulatekUnitStartTimes = nil
    self.ulatekEmptySince = nil

    if self.ulatekWaveTicker then
        self.ulatekWaveTicker:Cancel()
        self.ulatekWaveTicker = nil
    end

    for _, bar in ipairs(self.ulatekShriekerBars or {}) do
        if bar:IsRunning() then
            bar:Stop()
        else
            bar.unit = nil
            shared.PaintUnitHealth(bar.frame, nil)
            bar:Hide()
        end
    end
end

reconcileUlatekUnits = function(self)
    if not self.ulatekWaveActive then
        return
    end

    local unitCount = 0

    for _, unit in ipairs(ULATEK_BOSS_UNITS) do
        if UnitExists(unit) then
            unitCount = unitCount + 1
        end
    end

    if unitCount == 0 then
        local now = GetTime()
        self.ulatekEmptySince = self.ulatekEmptySince or now

        if now - self.ulatekEmptySince >= ULATEK_EMPTY_GRACE then
            stopUlatekWave(self)
        end

        return
    end

    self.ulatekEmptySince = nil
    local now = GetTime()
    local startedBar = false

    for row, unit in ipairs(ULATEK_BOSS_UNITS) do
        local bar = self.ulatekShriekerBars[row]
        local startTime = self.ulatekUnitStartTimes
            and self.ulatekUnitStartTimes[unit]

        if UnitExists(unit) and startTime then
            bar.unit = unit
            bar:SetMode("label")
            bar:SetLabel(UnitName(unit) or L["BossMods_UlatekBrightscaleShrieker"])
            bar:SetMiddle("")

            if not bar:IsRunning()
                and now - startTime < ULATEK_CHECK_DURATION
            then
                bar:Start({
                    total = ULATEK_CHECK_DURATION,
                    lead = startTime - now
                })
                startedBar = true
            end
        elseif bar:IsRunning() then
            bar:Stop()
        else
            bar.unit = nil
            bar:Hide()
        end
    end

    if startedBar then
        self:ApplyPositions()
    end
end

local function startUlatekWave(self, unit)
    if not isUlatekBarEnabled(self) then
        return
    end

    ensureUlatekBars(self)

    if not self.ulatekWaveActive then
        for _, bar in ipairs(self.ulatekShriekerBars) do
            if bar:IsRunning() then
                bar:Stop()
            end
        end

        self.ulatekWaveActive = true
        self.ulatekUnitStartTimes = {}
        self.ulatekEmptySince = nil

        -- Keep reconciling after the 35-second bars expire. This holds the wave
        -- lock until surviving Shriekers disappear, so a later cast cannot rearm.
        self.ulatekWaveTicker = C_Timer.NewTicker(
            ULATEK_UNIT_REFRESH_INTERVAL,
            function()
                reconcileUlatekUnits(self)
            end
        )
    end

    self.ulatekUnitStartTimes = self.ulatekUnitStartTimes or {}
    self.ulatekUnitStartTimes[unit] =
        self.ulatekUnitStartTimes[unit] or GetTime()

    reconcileUlatekUnits(self)
end

local function testEncounterBars(self, bossKey)
    if bossKey == "CoiledAltar" then
        testCoiledAltarNightfallBar(self)
        return
    end

    if bossKey ~= "Ulatek"
        or not isUlatekBarEnabled(self)
        or self.ulatekWaveActive
    then
        return
    end

    ensureUlatekBars(self)

    for row, bar in ipairs(self.ulatekShriekerBars) do
        if bar:IsRunning() then
            bar:Stop()
        end

        bar.unit = nil
        -- One row previews ahead of the required pace and one behind it.
        bar.testPaceOffset = row == 1 and -0.12 or 0.12
        bar:SetMode("label")
        bar:SetLabel(L["BossMods_UlatekBrightscaleShrieker"])
        bar:SetMiddle("")
        bar:Start({total = ULATEK_CHECK_DURATION})
    end

    self:ApplyPositions()
end

local function onUlatekSpellcastStart(self, _, unit)
    -- In the final phase only Shriekers occupy boss2/boss3. Deliberately use
    -- the unit event alone: cast and NPC IDs are restricted in 12.1.
    if not self.ulatekEncounterActive
        or unit ~= "boss2" and unit ~= "boss3"
    then
        return
    end

    if UnitExists(unit) and updateUlatekFinalPhase(self) then
        startUlatekWave(self, unit)
    end
end

local function onBigWigsStage(self, module, stage)
    onUlatekBigWigsStage(self, module, stage)
    onCoiledAltarBigWigsStage(self, module, stage)
end

local function initializeEncounterBars(self, currentBossMods)
    bossMods = currentBossMods
    shared = bossMods.Engines.Shared
end

local function onEncounterStart(self, encounterID)
    if encounterID == ULATEK_ENCOUNTER_ID then
        self.ulatekEncounterActive = true
        self.ulatekFinalPhase = false
        self.ulatekBigWigsStage = 1
    end

    if encounterID == COILED_ALTAR_ENCOUNTER_ID then
        self.coiledAltarEncounterActive = true
        stopCoiledAltarNightfall(self)
    end
end

local function refreshEncounterBars(self)
    if not isUlatekBarEnabled(self) then
        stopUlatekWave(self)
    end

    if not isCoiledAltarNightfallBarEnabled(self) then
        stopCoiledAltarNightfall(self)
    end
end

local function onFeatureEnabledChanged(self, _, key, enabled)
    if key == ULATEK_FEATURE_KEY and not enabled then
        stopUlatekWave(self)
    elseif key == COILED_ALTAR_FEATURE_KEY and not enabled then
        stopCoiledAltarNightfall(self)
    end
end

local function resetEncounterTracking(self)
    self.entombedCastCounts = self.entombedCastCounts or {}
    self.entombedLastCast = self.entombedLastCast or {}
    wipe(self.entombedCastCounts)
    wipe(self.entombedLastCast)
    self.entombedAssignment = nil
    self.entombedAssignmentResolved = false
    self.nekzaliGraspingCastCount = 0
    self.nekzaliGraspingLastTimer = nil
    self.ulatekEncounterActive = false
    self.ulatekFinalPhase = false
    self.ulatekBigWigsStage = nil
    stopUlatekWave(self)
    self.coiledAltarEncounterActive = false
    self.coiledAltarNightfallStartedAt = nil
    stopCoiledAltarNightfall(self)
end

local function shouldSuppressCast(self, spellID)
    spellID = tonumber(spellID)

    if spellID ~= VENOM_COAGULATION_SPELL_ID
        and spellID ~= UNSTABLE_MIASMA_SPELL_ID
    then
        return false
    end

    self.entombedCastCounts = self.entombedCastCounts or {}
    self.entombedLastCast = self.entombedLastCast or {}

    local now = GetTime()
    local lastCast = self.entombedLastCast[spellID]

    if lastCast and now - lastCast.time < 1 then
        return lastCast.suppressed == true
    end

    local castNumber = (self.entombedCastCounts[spellID] or 0) + 1
    self.entombedCastCounts[spellID] = castNumber

    if not self.entombedAssignmentResolved then
        self.entombedAssignment = getEntombedAssignment()
        self.entombedAssignmentResolved = true
    end

    local hiddenCasts = self.entombedAssignment
        and ENTOMBED_HIDDEN_CASTS[self.entombedAssignment]
    local filteringEnabled = not self.db
        or self.db.entombedAssignmentFilteringEnabled ~= false
    local suppressed = filteringEnabled
        and hiddenCasts
        and hiddenCasts[spellID]
        and hiddenCasts[spellID][castNumber]
        or false

    self.entombedLastCast[spellID] = {
        time = now,
        suppressed = suppressed
    }

    return suppressed
end

E:CreateAbilityAlertsModule({
    moduleName = "BossMods_VenomousAbyssAbilityAlerts",
    featurePrefix = "VenomousAbyss",
    initialize = initializeEncounterBars,
    events = {
        UNIT_SPELLCAST_START = onUlatekSpellcastStart
    },
    onBigWigsStartBar = onCoiledAltarBigWigsStartBar,
    onBigWigsStage = onBigWigsStage,
    onEncounterStart = onEncounterStart,
    onFeatureEnabledChanged = onFeatureEnabledChanged,
    testEncounterBars = testEncounterBars,
    refresh = refreshEncounterBars,
    getAbilityData = function()
        return E.VenomousAbyssAbilityData or {}
    end,
    extraDefaults = {
        entombedAssignmentFilteringEnabled = true,
        coiledAltarNightfallBarEnabled = true,
        ulatekShriekerBarEnabled = true
    },
    presetVersionField = "venomousBarPresetVersion",
    enableAllBarsMigrationField = "enableAllVenomousBarsMigration",
    defaultBarEnabledWhenUnset = true,
    getAbilityAssignment = getAbilityAssignment,
    getAssignedHits = getAssignedHits,
    getAssignmentTextState = getAssignmentTextState,
    resetEncounterTracking = resetEncounterTracking,
    shouldSuppressCast = shouldSuppressCast
})
