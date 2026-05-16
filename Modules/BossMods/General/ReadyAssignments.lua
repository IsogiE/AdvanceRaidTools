local E, L = unpack(ART)

local TEXT_MIN_WIDTH = 120
local TEXT_PADDING_X = 20
local TEXT_PADDING_Y = 18
local VISUAL_ANCHOR_WIDTH = 520

E:RegisterModuleDefaults("BossMods_AssignmentReminders", {
    enabled = true,
    position = {
        point = "CENTER",
        x = 0,
        y = 190
    },
    visualPosition = {
        point = "CENTER",
        x = 0,
        y = -170
    },
    size = {
        h = 84
    },
    duration = 15,
    font = {
        size = 24,
        outline = "OUTLINE",
        color = {1, 1, 1, 1}
    },
    assignment = {
        color = {1, 0.82, 0, 1}
    },
    background = {
        enabled = true,
        color = {0, 0, 0},
        opacity = 0
    },
    border = {
        enabled = false,
        texture = "Pixel",
        size = 1,
        color = {0, 0, 0, 1}
    }
})

local Mod = E:NewModule("BossMods_AssignmentReminders", "AceEvent-3.0")

local BM

local function getCatalogSheets(Text)
    if Text and Text.GetSheets then
        return Text:GetSheets()
    end
    if Text and Text.GetStandaloneSheets then
        return Text:GetStandaloneSheets()
    end
    return {}
end

local function fontStringWidth(text)
    if not text then
        return 0
    end
    if text.GetUnboundedStringWidth then
        return text:GetUnboundedStringWidth() or 0
    end
    return text:GetStringWidth() or 0
end

local function buildAlertConfig(mod)
    return {
        parent = UIParent,
        strata = "HIGH",
        size = {
            w = TEXT_MIN_WIDTH,
            h = mod.db.size.h or 84
        },
        font = {
            size = mod.db.font.size,
            outline = mod.db.font.outline,
            color = mod.db.font.color
        }
    }
end

local function assignmentColor(mod)
    return mod and mod.db and mod.db.assignment and mod.db.assignment.color or {1, 0.82, 0, 1}
end

local function registerDefaultReminders()
    local Ready = BM and BM.ReadyAssignments
    local Text = BM and BM.ReadyAssignmentText
    if not (Ready and Ready.RegisterTextReminders and Text and (Text.GetSheets or Text.GetStandaloneSheets)) then
        return
    end

    for _, sheet in ipairs(getCatalogSheets(Text)) do
        Ready:RegisterTextReminders(sheet.key)
    end
end

local function stopReadyActions(owner)
    local Ready = BM and BM.ReadyAssignments
    if Ready and Ready.StopActions then
        Ready:StopActions({
            owner = owner
        })
    end
end

local function measureLinesWidth(alert, lines)
    local text = alert and alert.GetTextFontString and alert:GetTextFontString()
    if not text then
        return 0
    end

    local original = text:GetText()
    local width = 0
    for _, line in ipairs(lines or {}) do
        text:SetText(tostring(line or ""))
        width = math.max(width, fontStringWidth(text))
    end
    text:SetText(original or "")
    return width
end

function Mod:OnInitialize()
    BM = BM or E:GetModule("BossMods")
    self.editMode = false
    self:EnsureAlert()
    self:EnsureVisualAnchor()
    self:ApplyVisuals()
    self:ApplyPosition()
    self:ApplyVisualPosition()
    self.alert:Hide()
    self.visualAnchor:Hide()
    registerDefaultReminders()
end

function Mod:EnsureAlert()
    if self.alert then
        return
    end
    self.alert = BM.Engines.TextAlert(buildAlertConfig(self))
    self.alert:Hide()
    self.frame = self.alert.frame
end

function Mod:EnsureVisualAnchor()
    if self.visualAnchor then
        return
    end
    local f = CreateFrame("Frame", "ART_AssignmentReminders_VisualAnchor", UIParent)
    f:SetFrameStrata("HIGH")
    local text = f:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER")
    f.text = text
    f:Hide()
    self.visualAnchor = f
    self:ApplyVisualAnchorStyle()
end

function Mod:ApplyVisualAnchorStyle()
    if not self.visualAnchor then
        return
    end
    local f = self.visualAnchor
    f:SetSize(VISUAL_ANCHOR_WIDTH, self.db.size.h or 84)
    f:SetFrameStrata("HIGH")

    local text = f.text
    if text then
        text:SetFont(E:FetchModuleFont() or [[Fonts\FRIZQT__.TTF]], self.db.font.size or 24,
            self.db.font.outline or "OUTLINE")
        local r, g, b, a = E:ColorTuple(self.db.font.color, 1, 1, 1, 1)
        text:SetTextColor(r, g, b, a)
        text:SetText(L["BossMods_AR_VisualPreview"] or "Assignment Visuals - drag to move")
    end
end

function Mod:ApplyVisuals()
    if not self.alert then
        return
    end
    self.alert:Apply(buildAlertConfig(self))
    self:ApplyVisualAnchorStyle()

    local f = self.alert.frame
    local bg = self.db.background
    if bg.enabled then
        f:SetBackdrop({
            bgFile = E.media.blankTex,
            insets = {
                left = 0,
                right = 0,
                top = 0,
                bottom = 0
            }
        })
        local r, g, b = E:ColorTuple(bg.color, 0, 0, 0)
        f:SetBackdropColor(r, g, b, bg.opacity or 0.45)
    else
        f:SetBackdrop(nil)
        f:SetBackdropColor(0, 0, 0, 0)
    end

    local border = self.db.border
    E:ApplyOuterBorder(f, {
        enabled = border.enabled,
        edgeFile = E:FetchBorder(border.texture),
        edgeSize = math.min(border.size or 1, 16),
        r = (border.color and border.color[1]) or 0,
        g = (border.color and border.color[2]) or 0,
        b = (border.color and border.color[3]) or 0,
        a = (border.color and border.color[4]) or 1
    })
end

function Mod:ApplyPosition()
    if not self.alert then
        return
    end
    E:ApplyFramePosition(self.alert.frame, self.db.position)
end

function Mod:ApplyVisualPosition()
    self:EnsureVisualAnchor()
    E:ApplyFramePosition(self.visualAnchor, self.db.visualPosition)
end

function Mod:SavePosition(pos)
    local p = self.db.position
    p.point = (pos and pos.point) or "CENTER"
    p.x = (pos and pos.x) or 0
    p.y = (pos and pos.y) or 190
    self:ApplyPosition()
end

function Mod:SaveVisualPosition(pos)
    local p = self.db.visualPosition
    p.point = (pos and pos.point) or "CENTER"
    p.x = (pos and pos.x) or 0
    p.y = (pos and pos.y) or -170
    self:ApplyVisualPosition()
end

function Mod:Refresh()
    if not self:IsEnabled() then
        return
    end
    self:ApplyVisuals()
    self:ApplyPosition()
    self:ApplyVisualPosition()
    if self.editMode then
        self:RenderEditPreview()
    end
end

function Mod:RenderEditPreview()
    self:EnsureVisualAnchor()
    self:ApplyVisualAnchorStyle()
    self.visualAnchor:Show()

    self:ShowLines({L["BossMods_RA_TextPreview"] or "Assignment Reminders - drag to move"}, 0)
end

function Mod:SetEditMode(v)
    self.editMode = v and true or false
    if self.editMode then
        self:RenderEditPreview()
    else
        self:Hide()
        if self.visualAnchor then
            self.visualAnchor:Hide()
        end
        stopReadyActions(self)
    end
end

function Mod:ShowLines(lines, holdSeconds)
    if type(lines) ~= "table" or #lines == 0 then
        self:Hide()
        return
    end

    self.alert:SetText(table.concat(lines, "\n"))

    local fontSize = self.db.font.size or 24
    local lineHeight = fontSize + 6
    local width = math.max(TEXT_MIN_WIDTH, math.ceil(measureLinesWidth(self.alert, lines)) + (TEXT_PADDING_X * 2))
    local height = math.max(self.db.size.h or 84, (#lines * lineHeight) + TEXT_PADDING_Y)
    self.alert.frame:SetSize(width, height)
    self.alert:Show()

    if self.hideTimer then
        self.hideTimer:Cancel()
        self.hideTimer = nil
    end

    holdSeconds = tonumber(holdSeconds)
    if holdSeconds and holdSeconds > 0 then
        self.hideTimer = C_Timer.NewTimer(holdSeconds, function()
            self.hideTimer = nil
            if self:IsEnabled() and not self.editMode then
                self:Hide()
            end
        end)
    end
end

function Mod:Hide()
    if self.hideTimer then
        self.hideTimer:Cancel()
        self.hideTimer = nil
    end
    if self.alert then
        self.alert:Hide()
    end
    if self.visualAnchor and not self.editMode then
        self.visualAnchor:Hide()
    end
end

function Mod:OnReadyCheck()
    if not self:IsEnabled() or InCombatLockdown() or self.editMode then
        return
    end
    if not IsInRaid() then
        return
    end

    local Ready = BM and BM.ReadyAssignments
    local Text = BM and BM.ReadyAssignmentText
    if not (Ready and Text) then
        return
    end

    local ctx = Ready:BuildContext()
    self:EnsureVisualAnchor()
    self:ApplyVisualPosition()
    if Ready.RunActions then
        Ready:RunActions(ctx, {
            duration = self.db.duration or 15,
            visualAnchor = self.visualAnchor,
            owner = self
        })
    end

    local reminders = Ready:Collect(ctx)
    local lines = Text:CompileAll(reminders, {
        highlightColor = assignmentColor(self)
    })
    self:ShowLines(lines, self.db.duration or 15)
end

function Mod:OnEnable()
    BM = BM or E:GetModule("BossMods")
    self:EnsureAlert()
    self:EnsureVisualAnchor()
    self:ApplyVisuals()
    self:ApplyPosition()
    self:ApplyVisualPosition()
    registerDefaultReminders()

    self:RegisterEvent("READY_CHECK", "OnReadyCheck")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Refresh")
end

function Mod:OnDisable()
    self:UnregisterEvent("READY_CHECK")
    self:UnregisterMessage("ART_PROFILE_CHANGED")
    self:UnregisterMessage("ART_MEDIA_UPDATED")
    self.editMode = false
    self:Hide()
    stopReadyActions(self)
end

E:RegisterBossModFeature("ReadyAssignments", {
    tab = "General",
    order = 20,
    labelKey = "BossMods_AssignmentReminders",
    descKey = "BossMods_AssignmentRemindersDesc",
    moduleName = "BossMods_AssignmentReminders"
})

local ReadyText = E:GetModule("BossMods").ReadyAssignmentText
for _, sheet in ipairs(getCatalogSheets(ReadyText)) do
    local blocks = ReadyText:BuildNoteBlocks(sheet.key)
    if #blocks > 0 then
        E:RegisterBossModNoteBlock(sheet.key, {
            blocks = blocks,
            moduleName = sheet.moduleName or "BossMods_AssignmentReminders",
            tab = sheet.tab,
            order = sheet.order,
            labelKey = sheet.labelKey,
            raidKey = sheet.raidKey,
            raidLabelKey = sheet.raidLabelKey,
            bossKey = sheet.bossKey,
            bossLabelKey = sheet.bossLabelKey,
            bossOrder = sheet.bossOrder,
            itemKey = sheet.itemKey,
            itemLabelKey = sheet.itemLabelKey,
            itemOrder = sheet.itemOrder,
            blockSeparator = sheet.noteBlockSeparator
        })
    end
end
