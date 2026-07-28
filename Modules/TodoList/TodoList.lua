local E, L = unpack(ART)

local MODULE_NAME = "TodoList"
local SHARE_TYPE = "todoList"
local SHARE_VERSION = "ART_TODO1"
local MIN_WIDTH, MIN_HEIGHT = 220, 100
local lastWhisperTarget

E:RegisterModuleDefaults(MODULE_NAME, {
    enabled = true,
    shown = true,
    text = "",
    states = {},
    fontName = "PT Sans Narrow",
    fontSize = 14,
    fontOutline = "OUTLINE",
    textColor = {r = 1, g = 1, b = 1, a = 1},
    backgroundEnabled = true,
    borderEnabled = true,
    hideInInstance = false,
    unlocked = false,
    point = "CENTER",
    relativePoint = "CENTER",
    x = 350,
    y = 120,
    width = 360,
    height = 240
})

local TodoList = E:NewModule(MODULE_NAME, "AceEvent-3.0")

local function clamp(value, low, high)
    value = tonumber(value) or low
    return math.max(low, math.min(high, value))
end

local function cleanText(value, maxLength)
    if type(value) ~= "string" then
        return ""
    end
    value = value:gsub("\r\n", "\n"):gsub("\r", "\n")
    if maxLength and #value > maxLength then
        value = value:sub(1, maxLength)
    end
    return value
end

local function copyStates(source)
    local out = {}
    if type(source) ~= "table" then
        return out
    end
    local count = 0
    for key, state in pairs(source) do
        if type(key) == "string" and type(state) == "table" and #key <= 2000 then
            count = count + 1
            if count > 1000 then
                break
            end
            out[key] = {
                done = state.done and true or false,
                current = type(state.current) == "number" and math.floor(state.current) or nil
            }
        end
    end
    return out
end

local function sanitizeShareData(data)
    if type(data) ~= "table" then
        return nil
    end
    return {
        text = cleanText(data.text, 100000),
        states = copyStates(data.states)
    }
end

local function parseCounter(text)
    local first, last, current, total = text:find("(%d+)%s*/%s*(%d+)")
    current, total = tonumber(current), tonumber(total)
    if not first or not current or not total then
        return nil
    end
    current = math.floor(current)
    total = math.max(0, math.floor(total))
    return {
        first = first,
        last = last,
        initial = clamp(current, 0, total),
        total = total
    }
end

local function lineKey(text, occurrence)
    return text .. "\031" .. occurrence
end

function TodoList:GetLineModels(includeCompleted)
    self.db.states = self.db.states or {}
    local models, occurrences = {}, {}
    local source = cleanText(self.db.text or "", 100000)
    for rawLine in (source .. "\n"):gmatch("(.-)\n") do
        local text = strtrim(rawLine)
        if text ~= "" then
            occurrences[text] = (occurrences[text] or 0) + 1
            local key = lineKey(text, occurrences[text])
            local state = self.db.states[key]
            if type(state) ~= "table" then
                state = {}
                self.db.states[key] = state
            end

            local counter = parseCounter(text)
            local displayText = text
            if counter then
                state.current = clamp(state.current == nil and counter.initial or state.current, 0, counter.total)
                if state.current >= counter.total then
                    state.done = true
                end
                displayText = text:sub(1, counter.first - 1)
                    .. state.current .. "/" .. counter.total
                    .. text:sub(counter.last + 1)
            else
                state.current = nil
            end

            if includeCompleted or not state.done then
                models[#models + 1] = {
                    key = key,
                    text = displayText,
                    counter = counter,
                    state = state
                }
            end
        end
    end
    return models
end

function TodoList:PruneStates()
    local valid = {}
    for _, model in ipairs(self:GetLineModels(true)) do
        valid[model.key] = true
    end
    for key in pairs(self.db.states) do
        if not valid[key] then
            self.db.states[key] = nil
        end
    end
end

function TodoList:SetText(value)
    self.db.text = cleanText(value, 100000)
    self:PruneStates()
    self:Refresh()
end

function TodoList:SetCompleted(key)
    local state = self.db.states and self.db.states[key]
    if state then
        state.done = true
        self:Refresh()
    end
end

function TodoList:ChangeCounter(key, delta)
    delta = tonumber(delta) or 0
    for _, model in ipairs(self:GetLineModels(true)) do
        if model.key == key and model.counter then
            model.state.current = clamp((model.state.current or model.counter.initial) + delta, 0, model.counter.total)
            model.state.done = model.state.current >= model.counter.total
            self:Refresh()
            return true
        end
    end
    return false
end

function TodoList:ResetAll()
    wipe(self.db.states)
    self:Refresh()
end

function TodoList:ExportListString()
    return E:EncodeShareString(SHARE_TYPE, {
        text = self.db.text or "",
        states = copyStates(self.db.states)
    })
end

function TodoList:ImportListData(data)
    data = sanitizeShareData(data)
    if not data then
        return false
    end
    self.db.text = data.text
    self.db.states = data.states
    self:PruneStates()
    self:Refresh()
    E:SendMessage("ART_TODO_LIST_CHANGED")
    return true
end

function TodoList:ImportListString(value)
    local data, err = E:DecodeShareString(SHARE_TYPE, value)
    if not data then
        return false, err or L["ImportInvalid"]
    end
    return self:ImportListData(data)
end

function TodoList:ShareToGuild()
    if not IsInGuild() then
        return false, L["SharingGuildUnavailable"]
    end
    return E:ShareDataToChat(SHARE_TYPE, {
        text = self.db.text or "",
        states = copyStates(self.db.states)
    }, "ART To-do List", "GUILD")
end

function TodoList:ShareToParty()
    local chatType
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and not IsInRaid() then
        chatType = "INSTANCE_CHAT"
    elseif IsInGroup() and not IsInRaid() then
        chatType = "PARTY"
    end
    if not chatType then
        return false, L["TodoList_PartyUnavailable"]
    end
    return E:ShareDataToChat(SHARE_TYPE, {
        text = self.db.text or "",
        states = copyStates(self.db.states)
    }, "ART To-do List", chatType)
end

function TodoList:ShareToRaid()
    if not IsInRaid() then
        return false, L["TodoList_RaidUnavailable"]
    end
    return E:ShareDataToChat(SHARE_TYPE, {
        text = self.db.text or "",
        states = copyStates(self.db.states)
    }, "ART To-do List", "RAID")
end

function TodoList:GetLastWhisperTarget()
    local target = E:SafeString(lastWhisperTarget)
    if target and target ~= "" then return target end
    if ChatEdit_GetLastTellTarget then
        local ok, value = pcall(ChatEdit_GetLastTellTarget)
        value = ok and E:SafeString(value) or nil
        if value and value ~= "" then return value end
    end
    return nil
end

function TodoList:ShareToLastWhisper()
    local target = self:GetLastWhisperTarget()
    if not target then
        return false, L["TodoList_NoRecentWhisper"]
    end
    local ok, err = E:ShareDataToChat(SHARE_TYPE, {
        text = self.db.text or "",
        states = copyStates(self.db.states)
    }, "ART To-do List", "WHISPER", target)
    return ok, err, target
end

function TodoList:RememberWhisper(_, _, playerName)
    playerName = E:SafeString(playerName)
    if playerName and playerName ~= "" then
        lastWhisperTarget = playerName
        if E.RefreshOptions then E:RefreshOptions() end
    end
end

function TodoList:SaveFramePosition()
    local frame = self.frame
    if not frame then return end
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    self.db.point = point or "CENTER"
    self.db.relativePoint = relativePoint or self.db.point
    self.db.x = math.floor((x or 0) + 0.5)
    self.db.y = math.floor((y or 0) + 0.5)
    self.db.width = math.floor((frame:GetWidth() or 360) + 0.5)
    self.db.height = math.floor((frame:GetHeight() or 240) + 0.5)
end

local function makeSmallButton(parent, label)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    E:SetTemplate(button, "Default")
    button:SetSize(22, 20)
    local text = button:CreateFontString(nil, "OVERLAY")
    E:RegisterFontString(text, 0)
    text:SetPoint("CENTER")
    text:SetText(label)
    button.label = text
    return button
end

function TodoList:CreateRow(parent)
    local row = CreateFrame("Frame", nil, parent)

    local text = row:CreateFontString(nil, "OVERLAY")
    text:SetPoint("TOPLEFT", 4, -3)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetWordWrap(true)
    row.text = text

    local check = CreateFrame("Button", nil, row, "BackdropTemplate")
    E:SetTemplate(check, "Default")
    check:SetSize(16, 16)
    check:SetPoint("RIGHT", -5, 0)
    local checkMark = check:CreateTexture(nil, "OVERLAY")
    checkMark:SetTexture([[Interface\Buttons\UI-CheckBox-Check]])
    checkMark:SetDesaturated(true)
    checkMark:SetPoint("TOPLEFT", -3, 3)
    checkMark:SetPoint("BOTTOMRIGHT", 3, -3)
    E:RegisterAccentTexture(checkMark)
    checkMark:Hide()
    check.mark = checkMark
    check:SetScript("OnClick", function(self_)
        if self_._todoKey then
            self_.mark:Show()
            TodoList:SetCompleted(self_._todoKey)
        end
    end)
    row.check = check

    local plus = makeSmallButton(row, "+")
    plus:SetPoint("RIGHT", check, "LEFT", -2, 0)
    plus:SetScript("OnClick", function(self_)
        if self_._todoKey then
            TodoList:ChangeCounter(self_._todoKey, 1)
        end
    end)
    row.plus = plus

    local minus = makeSmallButton(row, "-")
    minus:SetPoint("RIGHT", plus, "LEFT", -2, 0)
    minus:SetScript("OnClick", function(self_)
        if self_._todoKey then
            TodoList:ChangeCounter(self_._todoKey, -1)
        end
    end)
    row.minus = minus

    return row
end

function TodoList:BuildFrame()
    if self.frame then
        return self.frame
    end

    local frame = CreateFrame("Frame", "ARTTodoListFrame", UIParent, "BackdropTemplate")
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT)
    elseif frame.SetMinResize then
        frame:SetMinResize(MIN_WIDTH, MIN_HEIGHT)
    end
    E:SetTemplate(frame, "Default")
    frame.artOnMediaUpdate = function()
        TodoList:ApplyAppearance()
    end
    local function startDragging(self_)
        if TodoList.db.unlocked and not InCombatLockdown() then
            frame:StartMoving()
        end
    end
    local function stopDragging()
        frame:StopMovingOrSizing()
        TodoList:SaveFramePosition()
    end
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", startDragging)
    frame:SetScript("OnDragStop", stopDragging)
    frame:SetScript("OnSizeChanged", function()
        if not frame._todoReady then return end
        TodoList:SaveFramePosition()
        if not TodoList.resizePending then
            TodoList.resizePending = true
            C_Timer.After(0, function()
                TodoList.resizePending = nil
                if TodoList:IsEnabled() then TodoList:Refresh() end
            end)
        end
    end)

    local scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", 5, -5)
    scroll:SetPoint("BOTTOMRIGHT", -5, 5)
    scroll:EnableMouse(true)
    scroll:EnableMouseWheel(true)
    scroll:RegisterForDrag("LeftButton")
    scroll:SetScript("OnDragStart", startDragging)
    scroll:SetScript("OnDragStop", stopDragging)
    scroll:SetScript("OnMouseWheel", function(self_, delta)
        local child = self_:GetScrollChild()
        local maxScroll = child and math.max(0, child:GetHeight() - self_:GetHeight()) or 0
        self_:SetVerticalScroll(clamp(self_:GetVerticalScroll() - delta * 24, 0, maxScroll))
    end)
    frame.scroll = scroll

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    frame.content = content
    frame.rows = {}

    local grip = CreateFrame("Frame", nil, frame)
    grip:SetSize(14, 14)
    grip:SetPoint("BOTTOMRIGHT", -1, 1)
    grip:EnableMouse(true)
    local gripTexture = grip:CreateTexture(nil, "OVERLAY")
    gripTexture:SetAllPoints()
    gripTexture:SetColorTexture(1, 1, 1, 0.35)
    grip:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" and TodoList.db.unlocked and not InCombatLockdown() then
            frame:StartSizing("BOTTOMRIGHT")
        end
    end)
    grip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        TodoList:SaveFramePosition()
    end)
    frame.grip = grip

    frame:ClearAllPoints()
    frame:SetPoint(self.db.point or "CENTER", UIParent, self.db.relativePoint or self.db.point or "CENTER", self.db.x or 350, self.db.y or 120)
    frame:SetSize(clamp(self.db.width, MIN_WIDTH, 1200), clamp(self.db.height, MIN_HEIGHT, 1200))
    frame._todoReady = true
    self.frame = frame
    self:ApplyAppearance()
    return frame
end

function TodoList:ApplyAppearance()
    local frame = self.frame
    if not frame or not frame.SetBackdropColor then return end
    if self.db.backgroundEnabled ~= false then
        frame:SetBackdropColor(0, 0, 0, 0.7)
    else
        frame:SetBackdropColor(0, 0, 0, 0)
    end
    if frame.SetBackdropBorderColor then
        if self.db.borderEnabled ~= false then
            frame:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
        else
            frame:SetBackdropBorderColor(0, 0, 0, 0)
        end
    end
end

function TodoList:ApplyFramePosition()
    local frame = self:BuildFrame()
    frame._todoReady = false
    frame:ClearAllPoints()
    frame:SetPoint(self.db.point or "CENTER", UIParent, self.db.relativePoint or self.db.point or "CENTER", self.db.x or 350, self.db.y or 120)
    frame:SetSize(clamp(self.db.width, MIN_WIDTH, 1200), clamp(self.db.height, MIN_HEIGHT, 1200))
    frame._todoReady = true
    self:Refresh()
end

function TodoList:SetUnlocked(value)
    self.db.unlocked = value and true or false
    self:Refresh()
end

function TodoList:ApplyInteractionState()
    local frame = self.frame
    if not frame then return end
    local frameInteractive = self.db.unlocked and true or false
    frame:EnableMouse(frameInteractive)
    frame.scroll:EnableMouse(frameInteractive)
    frame.scroll:EnableMouseWheel(frameInteractive)
    for _, row in ipairs(frame.rows or {}) do
        row.check:EnableMouse(true)
        row.plus:EnableMouse(true)
        row.minus:EnableMouse(true)
    end
end

function TodoList:ShouldShow(models)
    if not self.db.shown then
        return false
    end
    local inInstance = IsInInstance and IsInInstance() or false
    if self.db.hideInInstance and inInstance then
        return false
    end
    return self.db.unlocked or #models > 0
end

function TodoList:Refresh()
    if not self:IsEnabled() then return end
    local models = self:GetLineModels(false)
    local frame = self:BuildFrame()
    if not self:ShouldShow(models) then
        frame:Hide()
        return
    end

    frame:Show()
    self:ApplyAppearance()
    self:ApplyInteractionState()
    if self.db.unlocked then frame.grip:Show() else frame.grip:Hide() end
    local width = frame.scroll:GetWidth()
    if not width or width <= 1 then
        width = (frame:GetWidth() or 360) - 10
    end
    width = math.max(1, width)
    frame.content:SetWidth(width)
    local fontPath = E:FetchFont(self.db.fontName)
    local fontSize = clamp(self.db.fontSize, 8, 40)
    local fontOutline = self.db.fontOutline or "OUTLINE"
    if fontOutline == "NONE" then fontOutline = "" end
    local color = type(self.db.textColor) == "table" and self.db.textColor or {}
    local colorR = clamp(color.r or color[1] or 1, 0, 1)
    local colorG = clamp(color.g or color[2] or 1, 0, 1)
    local colorB = clamp(color.b or color[3] or 1, 0, 1)
    local colorA = clamp(color.a or color[4] or 1, 0, 1)
    local y = 0

    for index, model in ipairs(models) do
        local row = frame.rows[index]
        if not row then
            row = self:CreateRow(frame.content)
            frame.rows[index] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetWidth(width)
        E:ApplyFontString(row.text, fontPath, fontSize, fontOutline)
        row.text:SetTextColor(colorR, colorG, colorB, colorA)
        row.text:SetText(model.text)
        row.check._todoKey = model.key
        row.check.mark:Hide()
        row.plus._todoKey = model.key
        row.minus._todoKey = model.key
        row.check:EnableMouse(true)
        row.plus:EnableMouse(true)
        row.minus:EnableMouse(true)
        if model.counter then
            row.plus:Show()
            row.minus:Show()
            row.text:SetWidth(math.max(20, width - 82))
        else
            row.plus:Hide()
            row.minus:Hide()
            row.text:SetWidth(math.max(20, width - 30))
        end
        local height = math.max(24, (row.text:GetStringHeight() or fontSize) + 7)
        row:SetHeight(height)
        row:Show()
        y = y + height
    end

    for index = #models + 1, #frame.rows do
        frame.rows[index]:Hide()
    end
    frame.content:SetHeight(math.max(y, frame.scroll:GetHeight() or 1))
end

function TodoList:OnInitialize()
    E:RegisterShareType(SHARE_TYPE, {
        version = SHARE_VERSION,
        label = L["TodoList"],
        sanitize = sanitizeShareData,
        getImportName = function() return L["TodoList"] end,
        confirmTitle = L["TodoList_ImportTitle"],
        confirmText = L["TodoList_ImportConfirm"],
        onImport = function(data)
            if self:ImportListData(data) then
                E:Printf(L["TodoList_Imported"])
            end
        end
    })
end

function TodoList:OnEnable()
    self.db.states = self.db.states or {}
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "Refresh")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "Refresh")
    self:RegisterEvent("CHAT_MSG_WHISPER", "RememberWhisper")
    self:RegisterEvent("CHAT_MSG_WHISPER_INFORM", "RememberWhisper")
    self:RegisterMessage("ART_PROFILE_CHANGED", "ApplyFramePosition")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Refresh")
    self:ApplyFramePosition()
    self:Refresh()
end

function TodoList:OnDisable()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    if self.frame then self.frame:Hide() end
end
