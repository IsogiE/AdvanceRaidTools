local E, L = unpack(ART)
local BossMods = E:GetModule("BossMods")
local Display = {}
BossMods.KickDisplay = Display

Display.defaults = {
    enabled = true,
    position = {
        point = "CENTER",
        x = 0,
        y = 160
    },
    nextTextPosition = {
        point = "CENTER",
        x = 0,
        y = 215
    },
    box = {
        size = 62,
        opacity = 0.88,
        offsetX = -8,
        offsetY = 0,
        gap = 8
    },
    font = {
        name = "Friz Quadrata TT",
        size = 18,
        outline = "OUTLINE",
        color = {1, 1, 1, 1}
    },
    nextText = {
        enabled = true,
        name = "Friz Quadrata TT",
        size = 28,
        outline = "OUTLINE",
        color = {1, 0.82, 0.08, 1}
    },
    nameplate = {
        size = 30,
        numberFontSize = 12,
        nameFontSize = 12,
        anchor = "TOP",
        offsetX = 0,
        offsetY = 0,
        showAll = false
    },
    audio = {
        enabled = false,
        mode = "sound",
        sound = "None",
        channel = "Master",
        ttsText = "Kick",
        voiceID = 0
    }
}

local BOX_COLORS = {
    now = {0.05, 0.78, 0.18, 0.95},
    next = {1, 0.45, 0.02, 0.95},
    idle = {0.50, 0.08, 0.08, 0.70}
}
local PREVIEW_COLORS = {
    now = {0.05, 0.78, 0.18, 0.95},
    next = {1, 0.82, 0.08, 0.95},
    idle = {0.50, 0.08, 0.08, 0.70}
}
local NAMEPLATE_ANCHOR_POINTS = {
    TOP = {"BOTTOM", "TOP"},
    BOTTOM = {"TOP", "BOTTOM"},
    LEFT = {"RIGHT", "LEFT"},
    RIGHT = {"LEFT", "RIGHT"},
    CENTER = {"CENTER", "CENTER"}
}
local VALID_NAMEPLATE_ANCHORS = {
    TOP = true,
    BOTTOM = true,
    LEFT = true,
    RIGHT = true,
    CENTER = true
}

local issecretvalue = _G.issecretvalue or function()
    return false
end

local function isSecret(value)
    return issecretvalue(value)
end

local function clamp(value, minimum, maximum, fallback)
    value = tonumber(value)
    if not value then
        value = fallback or minimum
    end
    return math.max(minimum, math.min(maximum, value))
end

local function colorValue(color, fallback)
    color = color or fallback or {1, 1, 1, 1}
    return color[1] or color.r or fallback[1],
        color[2] or color.g or fallback[2],
        color[3] or color.b or fallback[3],
        color[4] or color.a or fallback[4]
end

local function cleanDisplayName(name)
    if E.SafeString then
        name = E:SafeString(name)
    elseif type(name) ~= "string" or isSecret(name) then
        name = nil
    end

    if not name or name == "" then
        return nil
    end

    if E.BareName then
        name = E:BareName(name)
    else
        name = name:match("^([^%-]+)") or name
    end

    return name ~= "" and name or nil
end

local function fitFontString(fs, text, font, size, outline, maxWidth, minSize)
    if not fs then
        return
    end

    text = text or ""
    size = math.max(minSize or 7, tonumber(size) or minSize or 7)
    maxWidth = math.max(1, tonumber(maxWidth) or 1)
    minSize = math.max(1, tonumber(minSize) or 7)

    E:ApplyFontString(fs, font, size, outline)
    fs:SetText(text)

    while size > minSize and fs:GetStringWidth() > maxWidth do
        size = size - 1
        E:ApplyFontString(fs, font, size, outline)
    end

    while text ~= "" and fs:GetStringWidth() > maxWidth do
        text = text:sub(1, -2)
        fs:SetText(text)
    end
end

local function createAnchor(name, width, height)
    local frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    frame:SetSize(width, height)
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(20)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1
    })
    frame:SetBackdropColor(0, 0, 0, 0.25)
    frame:SetBackdropBorderColor(1, 1, 1, 0.40)
    frame:EnableMouse(false)
    frame:Hide()
    return frame
end

local function createKickBox(parent, name)
    local frame = CreateFrame("Frame", name, parent, "BackdropTemplate")
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(80)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1
    })
    frame:SetBackdropBorderColor(0, 0, 0, 1)

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    frame.text = text

    local nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetJustifyH("CENTER")
    nameText:SetJustifyV("BOTTOM")
    if nameText.SetWordWrap then
        nameText:SetWordWrap(false)
    end
    frame.nameText = nameText

    frame:Hide()
    return frame
end

local function anchorFrameToNameplate(frame, plate, anchor, offsetX, offsetY)
    local points = NAMEPLATE_ANCHOR_POINTS[anchor or "TOP"]
        or NAMEPLATE_ANCHOR_POINTS.TOP
    frame:ClearAllPoints()
    frame:SetPoint(points[1], plate, points[2], offsetX or 0, offsetY or 0)
end

function Display:EnsureDefaults()
    self.db.position = self.db.position or {point = "CENTER", x = 0, y = 160}
    self.db.position.point = self.db.position.point or "CENTER"
    self.db.position.x = clamp(self.db.position.x, -2000, 2000, 0)
    self.db.position.y = clamp(self.db.position.y, -2000, 2000, 160)

    self.db.nextTextPosition = self.db.nextTextPosition or {
        point = "CENTER",
        x = 0,
        y = 215
    }
    self.db.nextTextPosition.point = self.db.nextTextPosition.point or "CENTER"
    self.db.nextTextPosition.x = clamp(self.db.nextTextPosition.x, -2000, 2000, 0)
    self.db.nextTextPosition.y = clamp(self.db.nextTextPosition.y, -2000, 2000, 215)

    self.db.box = self.db.box or {}
    self.db.box.size = clamp(self.db.box.size, 18, 90, 62)
    self.db.box.opacity = clamp(self.db.box.opacity, 0.05, 1, 0.88)
    self.db.box.offsetX = clamp(self.db.box.offsetX, -200, 200, -8)
    self.db.box.offsetY = clamp(self.db.box.offsetY, -200, 200, 0)
    self.db.box.gap = clamp(self.db.box.gap, 0, 40, 8)

    self.db.font = self.db.font or {}
    self.db.font.name = self.db.font.name or "Friz Quadrata TT"
    self.db.font.size = clamp(self.db.font.size, 8, 36, 18)
    self.db.font.outline = self.db.font.outline or "OUTLINE"
    self.db.font.color = self.db.font.color or {1, 1, 1, 1}

    self.db.nextText = self.db.nextText or {}
    self.db.nextText.enabled = self.db.nextText.enabled ~= false
    self.db.nextText.name = self.db.nextText.name or "Friz Quadrata TT"
    self.db.nextText.size = clamp(self.db.nextText.size, 12, 60, 28)
    self.db.nextText.outline = self.db.nextText.outline or "OUTLINE"
    self.db.nextText.color = self.db.nextText.color or {1, 0.82, 0.08, 1}

    self.db.nameplate = self.db.nameplate or {}
    self.db.nameplate.size = clamp(self.db.nameplate.size, 30, 150, 30)
    self.db.nameplate.numberFontSize = clamp(
        self.db.nameplate.numberFontSize,
        8,
        40,
        12
    )
    self.db.nameplate.nameFontSize = clamp(
        self.db.nameplate.nameFontSize,
        8,
        40,
        12
    )
    if not VALID_NAMEPLATE_ANCHORS[self.db.nameplate.anchor] then
        self.db.nameplate.anchor = "TOP"
    end
    self.db.nameplate.offsetX = clamp(self.db.nameplate.offsetX, -200, 200, 0)
    self.db.nameplate.offsetY = clamp(self.db.nameplate.offsetY, -200, 200, 0)
    self.db.nameplate.showAll = self.db.nameplate.showAll == true

    self.db.audio = self.db.audio or {}
    self.db.audio.enabled = self.db.audio.enabled == true
    self.db.audio.mode = self.db.audio.mode == "tts" and "tts" or "sound"
    self.db.audio.sound = self.db.audio.sound or "None"
    self.db.audio.channel = self.db.audio.channel or "Master"
    self.db.audio.ttsText = self.db.audio.ttsText or "Kick"
    self.db.audio.voiceID = tonumber(self.db.audio.voiceID) or 0
end

function Display:EnsureFrames()
    if self.frames then
        return
    end

    local prefix = "ART_" .. self.moduleName:gsub("^BossMods_", "")
    self.frames = {}
    self.frames.anchor = createAnchor(prefix .. "Anchor", 92, 46)
    self.frames.nextTextAnchor = CreateFrame(
        "Frame",
        prefix .. "NextTextAnchor",
        UIParent
    )
    self.frames.nextTextAnchor:SetSize(260, 36)
    self.frames.nextTextAnchor:SetFrameStrata("HIGH")
    self.frames.nextTextAnchor:SetFrameLevel(90)
    self.frames.nextTextAnchor:EnableMouse(false)
    self.frames.nextTextAnchor:Hide()
    self.frames.kickBox = createKickBox(
        UIParent,
        prefix .. "_Box"
    )
    self.frames.nameplateRoot = CreateFrame(
        "Frame",
        prefix .. "_Nameplates",
        UIParent
    )
    self.frames.nameplateRoot:SetFrameStrata("HIGH")
    self.frames.nameplateRoot:SetFrameLevel(94)

    local nextText = self.frames.nextTextAnchor:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalHuge"
    )
    nextText:SetPoint("CENTER", self.frames.nextTextAnchor, "CENTER", 0, 0)
    nextText:SetText(L["BossMods_CAKYourKickNext"])
    nextText:SetJustifyH("CENTER")
    self.frames.nextText = nextText

    self:ApplyAppearance()
    self:ApplyPositions()
end

function Display:ApplyPositions()
    self:EnsureDefaults()
    self:EnsureFrames()
    E:GetModule("BossMods").DisplayTemplates:Place(self, "position", self.frames.anchor)
    E:GetModule("BossMods").DisplayTemplates:Place(self, "nextTextPosition", self.frames.nextTextAnchor)
end

function Display:SavePosition(pos, key)
    key = key or "position"
    self.db[key] = self.db[key] or {}
    self.db[key].point = pos.point
    self.db[key].relPoint = pos.relPoint
    self.db[key].x = pos.x
    self.db[key].y = pos.y
    self:ApplyPositions()
    self:UpdateDisplay()
end

function Display:ApplyBoxAppearance(
    frame,
    size,
    numberFontSize,
    nameFontSize
)
    if not frame then
        return
    end

    local font = E:FetchFont(self.db.font.name)
    size = tonumber(size) or self.db.box.size or 62
    frame:SetSize(size, size)
    frame.artBoxSize = size
    frame.artNameFontSize = nameFontSize
        or math.max(7, math.min(12, math.floor(size * 0.18)))

    frame.text:ClearAllPoints()
    frame.text:SetPoint(
        "CENTER",
        frame,
        "CENTER",
        0,
        math.max(2, math.floor(size * 0.08))
    )
    E:ApplyFontString(
        frame.text,
        font,
        numberFontSize or self.db.font.size,
        self.db.font.outline
    )
    frame.text:SetTextColor(colorValue(self.db.font.color, {1, 1, 1, 1}))

    frame.nameText:ClearAllPoints()
    frame.nameText:SetPoint("BOTTOM", frame, "BOTTOM", 0, 3)
    frame.nameText:SetWidth(math.max(1, size - 4))
    E:ApplyFontString(
        frame.nameText,
        font,
        frame.artNameFontSize,
        self.db.font.outline
    )
    frame.nameText:SetTextColor(colorValue(self.db.font.color, {1, 1, 1, 1}))
end

function Display:ApplyAppearance()
    self:EnsureDefaults()
    self:EnsureFrames()

    local size = self.db.box.size
    self.frames.anchor:SetSize(size, size)
    self:ApplyBoxAppearance(self.frames.kickBox, size, self.db.font.size)

    local nextText = self.db.nextText
    E:ApplyFontString(
        self.frames.nextText,
        E:FetchFont(nextText.name),
        nextText.size,
        nextText.outline
    )
    self.frames.nextText:SetTextColor(
        colorValue(nextText.color, {1, 0.82, 0.08, 1})
    )
end

function Display:SetBoxState(
    frame,
    state,
    count,
    currentName,
    colors,
    currentClass
)
    if not frame then
        return
    end

    colors = colors or BOX_COLORS
    local color = colors.idle
    if state == "now" then
        color = colors.now
    elseif state == "next" then
        color = colors.next
    end

    local size = frame.artBoxSize or self.db.box.size or 62
    local r, g, b, a = colorValue(color, {0.5, 0.08, 0.08, 0.70})
    frame:SetBackdropColor(r, g, b, (a or 1) * (self.db.box.opacity or 1))
    frame.text:SetText(count or "")
    fitFontString(
        frame.nameText,
        currentName,
        E:FetchFont(self.db.font.name),
        frame.artNameFontSize or math.max(
            7,
            math.min(12, math.floor(size * 0.18))
        ),
        self.db.font.outline,
        math.max(1, size - 4),
        7
    )

    local nr, ng, nb, na = colorValue(self.db.font.color, {1, 1, 1, 1})
    if currentClass and E.ClassColorRGB then
        nr, ng, nb = E:ClassColorRGB(currentClass)
        na = 1
    end
    frame.nameText:SetTextColor(nr, ng, nb, na)
end

function Display:CreateAnchorPreview(kind)
    if kind == "nextTextPosition" then
        local owner = self
        local frame = CreateFrame("Frame", nil, UIParent)
        frame:SetSize(260, 36)
        frame:EnableMouse(false)
        local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        text:SetPoint("CENTER", frame, "CENTER", 0, 0)
        text:SetJustifyH("CENTER")
        text:SetText(L["BossMods_CAKYourKickNext"])
        local handle = {frame = frame}
        function handle:Refresh()
            local config = owner.db.nextText
            E:ApplyFontString(text, E:FetchFont(config.name), config.size, config.outline)
            text:SetTextColor(colorValue(config.color, {1, 0.82, 0.08, 1}))
        end
        function handle:Show() self:Refresh(); frame:Show() end
        function handle:Hide() frame:Hide() end
        handle:Refresh()
        frame:Hide()
        return handle
    end
    local box = createKickBox(UIParent)
    local owner = self
    local handle = {frame = box}
    function handle:Refresh()
        owner:ApplyBoxAppearance(box, owner.db.box.size, owner.db.font.size)
        owner:SetBoxState(box, "now", 1, UnitName("player") or L["Player"], PREVIEW_COLORS)
        box:SetFrameStrata("DIALOG")
    end
    function handle:Show() self:Refresh(); box:Show() end
    function handle:Hide() box:Hide() end
    return handle
end

function Display:GetKickDisplayName(token)
    if type(token) ~= "string" or token == "" then
        return ""
    end

    local NoteBlock = BossMods and BossMods.NoteBlock
    local unit = NoteBlock
        and NoteBlock.FindUnitByToken
        and NoteBlock:FindUnitByToken(token)

    local unitExists = unit and UnitExists(unit)
    if not isSecret(unitExists) and unitExists then
        if E.GetNickname then
            local nickname = cleanDisplayName(E:GetNickname(unit))
            if nickname then
                return nickname
            end
        end

        local unitName = cleanDisplayName(
            (UnitNameUnmodified and UnitNameUnmodified(unit)) or UnitName(unit)
        )
        if unitName then
            return unitName
        end
    end

    if NoteBlock and NoteBlock.GetDisplayName then
        local displayName = cleanDisplayName(NoteBlock:GetDisplayName(token))
        if displayName then
            return displayName
        end
    end

    return cleanDisplayName(token) or ""
end

function Display:GetKickDisplayInfo(token)
    local displayName = self:GetKickDisplayName(token)
    local classFile
    local NoteBlock = BossMods and BossMods.NoteBlock

    if NoteBlock and NoteBlock.GetClassForToken then
        classFile = NoteBlock:GetClassForToken(token)
        if not classFile and displayName ~= token then
            classFile = NoteBlock:GetClassForToken(displayName)
        end
    end

    if not classFile and E.GetClassByName then
        classFile = E:GetClassByName(token) or E:GetClassByName(displayName)
    end

    return displayName, classFile
end

function Display:UpdateNextText(showNext)
    local anchor = self.frames.nextTextAnchor
    if not self.db.nextText.enabled then
        anchor:Hide()
        return
    end

    if self.editMode or showNext then
        anchor:Show()
        return
    end
    anchor:Hide()
end

function Display:PlayConfiguredAudio(line, count)
    local audio = self.db.audio
    if not audio or not audio.enabled or not BossMods or not BossMods.Alerts then
        return
    end

    local key = tostring(line) .. ":" .. tostring(count or 1)
    if self.lastAudioKey == key then
        return
    end
    self.lastAudioKey = key

    if audio.mode == "tts" then
        BossMods.Alerts:SpeakTTS({
            text = audio.ttsText or "Kick",
            voiceID = audio.voiceID or 0
        })
    else
        BossMods.Alerts:PlaySound({
            name = audio.sound,
            channel = audio.channel or "Master"
        })
    end
end

Display.CreateBox = createKickBox
Display.AnchorToNameplate = anchorFrameToNameplate
Display.colors = BOX_COLORS
Display.previewColors = PREVIEW_COLORS

function Display:Install(module)
    for _, method in ipairs({
        "EnsureDefaults", "EnsureFrames", "ApplyPositions",
        "SavePosition", "ApplyBoxAppearance", "ApplyAppearance",
        "SetBoxState", "CreateAnchorPreview", "GetKickDisplayName",
        "GetKickDisplayInfo", "UpdateNextText", "PlayConfiguredAudio",
    }) do
        module[method] = self[method]
    end
end
