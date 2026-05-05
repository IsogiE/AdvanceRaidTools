local E, L = unpack(ART)

E:RegisterModuleDefaults("BossMods_Lurakick", {
    enabled = false,
    position = {
        point = "CENTER",
        x = 300,
        y = 0
    },
    size = {
        w = 155,
        h = 50
    },
    maxRows = 6,
    background = {
        opacity = 1
    },
    border = {
        enabled = true,
        texture = "Pixel",
        size = 1,
        color = {0.3, 0.3, 0.3, 1}
    },
    font = {
        size = 12,
        outline = "OUTLINE",
        justify = "LEFT"
    },
    sound = {
        name = "None",
        channel = "Master"
    }
})

local ENCOUNTER_ID = 3183
local INSTANCE_ID = 2913
local PHASE_SWAP_DEBOUNCE = 5
local KICK_RESET_SECONDS = 30
local FINAL_CAST_DELAY = 2

local Lurakick = E:NewModule("BossMods_Lurakick", "AceEvent-3.0", "AceTimer-3.0")

local BM

local function buildListConfig(mod)
    local db = mod.db
    return {
        parent = UIParent,
        maxRows = db.maxRows,
        size = {
            w = db.size.w,
            h = db.size.h
        },
        style = {
            font = db.font,
            bg = db.background,
            border = db.border,
            colors = {
                upcoming = "|cFFAAAAAA",
                active = "|cFF00FF00",
                done = "|cFF707070"
            }
        }
    }
end

function Lurakick:EnsureList()
    if self.list then
        return
    end
    self.list = BM.Engines.AssignmentList(buildListConfig(self))
    self.list:Hide()
    self.list:SetTitle(L["BossMods_LKKickOrder"])
    self:ApplyPosition()
end

function Lurakick:OnInitialize()
    self.active = false
    self.currentPhase = 1
    self.phaseSwapTime = 0
    self.castCount = 0
    self.myTrackedID = 0
    self.myGroupIdx = 0
    self.myKickPos = 0
    self.assigns = {}
    self.editMode = false

    BM = BM or E:GetModule("BossMods")
    self:EnsureList()
    if self.list then
        self.list:Apply(buildListConfig(self))
        self.list:SetTitle(L["BossMods_LKKickOrder"])
        self:ApplyPosition()
        self.list:Hide()
    end
end

function Lurakick:OnEnable()
    if not self.list then
        self:EnsureList()
    end
    self.list:Apply(buildListConfig(self))
    self:ApplyPosition()

    self.active = false

    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "OnZoneOrLogin")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnZoneOrLogin")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Refresh")

    self:UpdateState()
end

function Lurakick:OnDisable()
    self.editMode = false
    self.active = false
    self.list:Hide()
end

function Lurakick:OnZoneOrLogin()
    self:UpdateState()
end

function Lurakick:UpdateState()
    if not self:IsEnabled() then
        return
    end

    self:UnregisterEvent("ENCOUNTER_START")
    self:UnregisterEvent("ENCOUNTER_END")
    self:UnregisterEvent("UNIT_SPELLCAST_START")
    self:UnregisterEvent("UNIT_SPELLCAST_STOP")
    self:UnregisterEvent("UNIT_DIED")
    self:UnregisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED")
    self:CancelResetTimer()

    local _, _, _, _, _, _, _, mapID = GetInstanceInfo()
    local inCorrectInstance = (mapID == INSTANCE_ID)

    if inCorrectInstance then
        self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
        self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
    else
        self.active = false
        if not self.editMode then
            self.list:Hide()
        end
    end
end

function Lurakick:ApplyPosition()
    local pos = self.db.position
    local f = self.list.frame
    f:ClearAllPoints()
    f:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER", pos.x or 0, pos.y or 0)
end

function Lurakick:SavePosition(pos)
    self.db.position.point = pos.point
    self.db.position.x = pos.x
    self.db.position.y = pos.y
    self:ApplyPosition()
end

function Lurakick:Refresh()
    if not self:IsEnabled() then
        return
    end
    self.list:Apply(buildListConfig(self))
    self:ApplyPosition()
    if self.active then
        self:UpdateDisplay()
    end
end

-- Note

function Lurakick:ParseNote()
    self.assigns = {}
    self.myGroupIdx = 0
    self.myKickPos = 0

    local NoteBlock = BM.NoteBlock
    local noteText = NoteBlock:GetMainNoteText()
    if not noteText or noteText == "" then
        self.myTrackedID = 0
        return
    end

    local playerName = (UnitName("player") or ""):lower()
    local realmName = (GetRealmName() or ""):lower():gsub("%s+", "")
    local fullName = playerName .. "-" .. realmName

    local nickname
    if E.GetNickname then
        local n = E:GetNickname("player")
        if n and n ~= "" then
            nickname = n:lower()
        end
    end

    local count = 1
    local inBlock = false

    for rawLine in noteText:gmatch("[^\r\n]+") do
        local line = strtrim(rawLine)
        local lower = line:lower()

        if lower == "kickend" then
            inBlock = false
            break
        elseif lower == "kickstart" then
            inBlock = true
            count = 1
        elseif inBlock then
            local num = 0
            count = count + 1
            self.assigns[count] = {}

            for word in line:gmatch("%S+") do
                local lword = word:lower()
                local resolvedUnit

                if UnitInRaid(word) or UnitInParty(word) or UnitIsUnit(word, "player") then
                    resolvedUnit = word
                elseif E.GetNickname then
                    for j = 1, GetNumGroupMembers() do
                        local unit = "raid" .. j
                        local nick = E:GetNickname(unit)
                        if nick and nick:lower() == lword then
                            resolvedUnit = UnitName(unit)
                            break
                        end
                    end
                end

                if resolvedUnit then
                    num = num + 1
                    table.insert(self.assigns[count], resolvedUnit)

                    local isMe = (lword == playerName) or (lword == fullName) or (nickname and lword == nickname) or
                                     UnitIsUnit(resolvedUnit, "player")
                    if isMe then
                        self.myGroupIdx = count
                        self.myKickPos = num
                    end
                end
            end
        end
    end

    self.myTrackedID = self.myGroupIdx
end

-- lifecycle

function Lurakick:OnEncounterStart(_, encounterID)
    if encounterID ~= ENCOUNTER_ID then
        return
    end
    self.active = true
    self.currentPhase = 1
    self.phaseSwapTime = GetTime()

    self:ParseNote()
    self.castCount = 1
    self:CancelResetTimer()

    self:RegisterEvent("UNIT_SPELLCAST_START", "OnSpellcastStart")
    self:RegisterEvent("UNIT_SPELLCAST_STOP", "OnSpellcastStop")
    self:RegisterEvent("UNIT_DIED", "OnUnitDied")
    self:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED", "OnTimelineEvent")

    self:UpdateDisplay()
end

function Lurakick:OnEncounterEnd()
    self.active = false
    self:CancelResetTimer()
    self.castCount = 1
    self:UnregisterEvent("UNIT_SPELLCAST_START")
    self:UnregisterEvent("UNIT_SPELLCAST_STOP")
    self:UnregisterEvent("UNIT_DIED")
    self:UnregisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED")
    if self.list and not self.editMode then
        self.list:Hide()
    end
end

function Lurakick:OnTimelineEvent(_, info)
    if not self.active or not info then
        return
    end
    if Enum and Enum.EncounterTimelineEventSource and info.source ~= Enum.EncounterTimelineEventSource.Encounter then
        return
    end
    local now = GetTime()
    if now < self.phaseSwapTime + PHASE_SWAP_DEBOUNCE then
        return
    end

    if info.duration == 45 and self.currentPhase == 1 then
        self.currentPhase = 2
        self.phaseSwapTime = now
        self:CancelResetTimer()
        self.castCount = 1
        self.myTrackedID = 0
        self:UnregisterEvent("UNIT_SPELLCAST_START")
        self:UnregisterEvent("UNIT_SPELLCAST_STOP")
        self:UnregisterEvent("UNIT_DIED")
        self:UnregisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED")
        if self.list and not self.editMode then
            self.list:Hide()
        end
    end
end

-- Spellcast tracking

function Lurakick:OnSpellcastStart(_, unit)
    if not self.active or self.myTrackedID == 0 then
        return
    end
    if unit ~= ("boss" .. self.myTrackedID) then
        return
    end
    if not UnitIsEnemy(unit, "player") then
        return
    end

    if self.castCount < 1 then
        self.castCount = 1
    end

    if self.castCount == self.myKickPos then
        self:PlayKickSound()
    end

    self:UpdateDisplay()

    if self.castCount == 4 then
        self:ScheduleTimer("HardResetInterrupts", FINAL_CAST_DELAY)
    end
    self:ArmResetTimer()
end

function Lurakick:OnSpellcastStop(_, unit)
    if not self.active or self.myTrackedID == 0 then
        return
    end
    if unit ~= ("boss" .. self.myTrackedID) then
        return
    end
    if not UnitIsEnemy(unit, "player") then
        return
    end

    self.castCount = self.castCount + 1
    self:UpdateDisplay()

    if self.castCount == 4 then
        self:ScheduleTimer("HardResetInterrupts", FINAL_CAST_DELAY)
    end
    self:ArmResetTimer()
end

function Lurakick:OnUnitDied()
    if not self.active then
        return
    end
    if UnitExists("boss2") and UnitIsEnemy("boss2", "player") then
        if self.myTrackedID == 4 then
            self.myTrackedID = 3
        elseif self.myTrackedID == 3 then
            if not UnitExists("boss3") or not UnitIsEnemy("boss3", "player") then
                self.myTrackedID = 2
            end
        end
        self:UpdateDisplay()
        return
    end

    if not UnitExists("boss2") or not UnitIsEnemy("boss2", "player") then
        self:HardResetInterrupts()
    end
end

-- Reset timers

function Lurakick:ArmResetTimer()
    self:CancelResetTimer()
    self.resetTimer = self:ScheduleTimer("HardResetInterrupts", KICK_RESET_SECONDS)
end

function Lurakick:CancelResetTimer()
    if self.resetTimer then
        self:CancelTimer(self.resetTimer)
        self.resetTimer = nil
    end
end

function Lurakick:HardResetInterrupts()
    self.castCount = 1
    self.myTrackedID = self.myGroupIdx
    self:CancelResetTimer()
    self:UpdateDisplay()
end

-- Display + sound

function Lurakick:UpdateDisplay()
    if self.myGroupIdx == 0 or not self.assigns[self.myGroupIdx] then
        if not self.editMode then
            self.list:Hide()
        end
        return
    end

    local trackedUnit = "boss" .. self.myTrackedID
    if not self.active or not UnitExists(trackedUnit) or not UnitIsEnemy(trackedUnit, "player") then
        if not self.editMode then
            self.list:Hide()
        end
        return
    end

    if self.castCount > self.myKickPos and self.myKickPos > 0 then
        if not self.editMode then
            self.list:Hide()
        end
        return
    end

    self.list:SetTitle(L["BossMods_LKPrismN"]:format(self.myGroupIdx - 1))

    local NoteBlock = BM.NoteBlock
    local group = self.assigns[self.myGroupIdx]
    local rows = {}
    for i, charName in ipairs(group) do
        local state
        if i == self.castCount then
            state = "active"
        elseif i < self.castCount then
            state = "done"
        else
            state = "upcoming"
        end
        rows[i] = {
            text = NoteBlock:GetDisplayName(charName),
            state = state
        }
    end
    self.list:SetRows(rows)
    self.list:SetHighlight(self.castCount > 0 and self.castCount == self.myKickPos)
    self.list:Show()
end

function Lurakick:PlayKickSound()
    BM.Alerts:PlaySound({
        name = self.db.sound.name,
        channel = self.db.sound.channel
    })
end

function Lurakick:SetEditMode(v)
    if not self:IsEnabled() then
        return
    end
    self.editMode = v and true or false

    if self.editMode then
        self.list:SetRows({{
            text = L["BossMods_LKPlaceholder"]:format(1),
            state = "active"
        }, {
            text = L["BossMods_LKPlaceholder"]:format(2),
            state = "upcoming"
        }, {
            text = L["BossMods_LKPlaceholder"]:format(3),
            state = "upcoming"
        }})
        self.list:SetHighlight(self.castCount > 0 and self.castCount == self.myKickPos)
        self.list:Show()
    else
        if self.active then
            self:UpdateDisplay()
        else
            self.list:Hide()
        end
    end
end

E:RegisterBossModFeature("Lurakick", {
    tab = "Queldanas",
    order = 30,
    labelKey = "BossMods_Lurakick",
    descKey = "BossMods_LurakickDesc",
    moduleName = "BossMods_Lurakick"
})

E:RegisterBossModNoteBlock("Lurakick", {
    blocks = {{
        tag = "kick",
        template = "kickStart\nPlayer1 Player2 Player3\nPlayer4 Player5 Player6\nPlayer7 Player8 Player9\nkickEnd"
    }},
    moduleName = "BossMods_Lurakick",
    tab = "Queldanas",
    order = 30,
    labelKey = "BossMods_Lurakick"
})
