local E, L = unpack(ART)
local T = E.Templates

local OUTLINE_VALUES = {
    [""] = L["None"],
    OUTLINE = L["Outline"],
    THICKOUTLINE = L["ThickOutline"],
    OUTLINE_SLUG = L["BossMods_AAOptions_SlugOutline"]
}
local OUTLINE_ORDER = {"", "OUTLINE", "THICKOUTLINE", "OUTLINE_SLUG"}

local function buildLootCoinBody(parent, mod, isDisabled)
    local width = parent:GetWidth() or 0
    if width <= 0 then
        return {}
    end
    mod:EnsureSettings()

    local tracker = T:MakeTracker()
    local track = tracker.track
    local y = 0
    local gap = 8

    local function refresh()
        mod:Refresh()
        tracker.refresh()
    end

    local function full(widget)
        y = y + T:PlaceFull(parent, widget, y, width) + gap
    end

    local function row(widgets)
        y = y + T:PlaceRow(parent, widgets, y, width) + gap
    end

    local unlockY, unlockController = T:UnlockController(parent, y, width, {
        tracker = tracker,
        isDisabled = isDisabled,
        onEditModeChanged = function(value)
            mod:SetEditMode(value)
        end
    })
    y = unlockY
    full(T:PreviewToggle(parent, {
        module = mod,
        tracker = tracker,
        disabled = isDisabled
    }))

    full(track(T:Slider(parent, {
        label = L["LootCoinDuration"],
        min = 3,
        max = 60,
        step = 1,
        value = mod.db.duration or 10,
        get = function() return mod.db.duration or 10 end,
        onChange = function(value)
            mod.db.duration = math.floor(value + 0.5)
        end,
        disabled = isDisabled
    })))

    full(track(T:Header(parent, {text = L["BossMods_RFSCTextAppearance"]})))

    local fontDropdown = track(T:Dropdown(parent, {
        label = L["Font"],
        values = function() return E:MediaList("font") end,
        get = function() return mod.db.font.name end,
        onChange = function(value)
            mod.db.font.name = value
            refresh()
        end,
        disabled = isDisabled
    }))
    local sizeSlider = track(T:Slider(parent, {
        label = L["BossMods_AAOptions_FontSize"],
        min = 8,
        max = 100,
        step = 1,
        value = mod.db.font.size or 48,
        get = function() return mod.db.font.size or 48 end,
        onChange = function(value)
            mod.db.font.size = math.floor(value + 0.5)
            refresh()
        end,
        disabled = isDisabled
    }))
    local outlineDropdown = track(T:Dropdown(parent, {
        label = L["Outline"],
        values = OUTLINE_VALUES,
        sorting = OUTLINE_ORDER,
        get = function() return mod.db.font.outline or "" end,
        onChange = function(value)
            mod.db.font.outline = value or ""
            refresh()
        end,
        disabled = isDisabled
    }))
    full(fontDropdown)
    row({sizeSlider, outlineDropdown})

    local color = mod.db.font.color or {1, 0.82, 0, 1}
    full(track(T:ColorSwatch(parent, {
        label = L["BossMods_RFSCTextColor"],
        labelTop = true,
        hasAlpha = true,
        r = color[1] or 1,
        g = color[2] or 0.82,
        b = color[3] or 0,
        a = color[4] or 1,
        onChange = function(r, g, b, a)
            mod.db.font.color = {r, g, b, a}
            refresh()
        end,
        disabled = isDisabled
    })))

    local positionY, positionHandle = T:PositionSection(parent, y, width, {
        anchor = mod:GetAnchor(),
        label = L["LootCoin"],
        headerText = L["Position"],
        tracker = tracker,
        getPosition = function()
            local position = mod:GetPosition()
            return {point = position.point, x = position.x, y = position.y}
        end,
        setPosition = function(position)
            mod:SavePosition(position)
        end,
        resetPosition = function() mod:ResetPosition() end,
        resetConfirm = L["BossMods_ResetAnchorPositionConfirm"]:format(L["LootCoin"]),
        resetConfirmTitle = L["ResetPosition"],
        onChanged = refresh,
        isDisabled = isDisabled,
        unlockController = unlockController,
        showOffsets = true
    })
    y = positionY

    local totalHeight = math.max(y + 10, 1)
    parent:SetHeight(totalHeight)
    return {
        height = totalHeight,
        Refresh = tracker.refresh,
        Release = function()
            mod:SetEditMode(false)
            positionHandle.Release()
            unlockController:Release()
            tracker.release()
        end
    }
end

local function isDisabled()
    local mod = E:GetModule("LootCoin", true)
    return not (mod and mod:IsEnabled())
end

local PANEL_GAP, PANEL_PAD, SETTINGS_MIN_W, SPLIT_MIN_W = 12, 10, 260, 640
local CARD_GAP, PAD, HEADER_H, BAR_H, ROW_H, ICON_SIZE, SUMMARY_H = 10, 10, 20, 3, 18, 14, 30
local CHECK_ICON = "Interface\\RaidFrame\\ReadyCheck-Ready"
local DONE_COLOR = {0.25, 1, 0.25}
local GOLD = {1, 0.82, 0}

local function formatReset(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    local hours, minutes = math.floor(seconds / 3600), math.floor(seconds % 3600 / 60)
    if hours > 0 then return ("%dh %dm"):format(hours, minutes) end
    return ("%dm"):format(math.max(1, minutes))
end

local function secondsUntilReset()
    local seconds = C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset and C_DateAndTime.GetSecondsUntilDailyReset()
    if seconds == nil or E:IsSecret(seconds) then return end
    return tonumber(seconds)
end

local function fontSize(delta)
    return (E.media.normFontSize or 12) + (delta or 0)
end

local function createCard(parent, source)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    E:SetTemplate(card, "Transparent")

    local header = CreateFrame("Frame", nil, card)
    header:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -PAD)
    header:SetPoint("TOPRIGHT", card, "TOPRIGHT", -PAD, -PAD)
    header:SetHeight(HEADER_H - 4)

    card.count = E:CreateFontString(header, nil, "OVERLAY", fontSize(1))
    card.count:SetPoint("RIGHT", header, "RIGHT", 0, 0)
    card.count:SetJustifyH("RIGHT")

    card.title = E:CreateFontString(header, nil, "OVERLAY", fontSize(1))
    card.title:SetPoint("LEFT", header, "LEFT", 0, 0)
    card.title:SetPoint("RIGHT", card.count, "LEFT", -8, 0)
    card.title:SetJustifyH("LEFT")
    card.title:SetWordWrap(false)
    card.title:SetTextColor(unpack(GOLD))
    card.title:SetText(source.name)

    card.barBG = card:CreateTexture(nil, "ARTWORK")
    card.barBG:SetTexture(E.media.blankTex)
    card.barBG:SetVertexColor(1, 1, 1, 0.08)
    card.barBG:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -(PAD + HEADER_H))
    card.barBG:SetPoint("TOPRIGHT", card, "TOPRIGHT", -PAD, -(PAD + HEADER_H))
    card.barBG:SetHeight(BAR_H)

    card.bar = card:CreateTexture(nil, "OVERLAY")
    card.bar:SetTexture(E.media.blankTex)
    card.bar:SetPoint("TOPLEFT", card.barBG, "TOPLEFT")
    card.bar:SetHeight(BAR_H)

    card.rows = {}
    for index, boss in ipairs(source.bosses) do
        local row = CreateFrame("Frame", nil, card)
        row.icon = row:CreateTexture(nil, "OVERLAY")
        row.icon:SetSize(ICON_SIZE, ICON_SIZE)
        row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -(ROW_H - ICON_SIZE) / 2)
        row.name = E:CreateFontString(row, nil, "OVERLAY")
        row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, -1)
        row.name:SetJustifyH("LEFT")
        row.name:SetJustifyV("TOP")
        row.name:SetWordWrap(true)
        row.name:SetText(boss.name)
        card.rows[index] = row
    end
    return card
end

local function layoutCard(card, width)
    card:SetWidth(width)
    local textWidth = math.max(20, width - PAD * 2 - ICON_SIZE - 6)
    local y = PAD + HEADER_H + BAR_H + 6
    for _, row in ipairs(card.rows) do
        row.name:SetWidth(textWidth)
        local textHeight = row.name:GetStringHeight() or 0
        local height = math.max(ROW_H, math.ceil(textHeight) + (ROW_H - fontSize()))
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -y)
        row:SetPoint("TOPRIGHT", card, "TOPRIGHT", -PAD, -y)
        row:SetHeight(height)
        y = y + height
    end
    card.height = y + PAD - 2
    card:SetHeight(card.height)
    return card.height
end

local function updateCard(card, source, coinIcon, here)
    local got = 0
    for index, boss in ipairs(source.bosses) do
        local row = card.rows[index]
        if row then
            if boss.looted then
                got = got + 1
                row.icon:SetTexture(CHECK_ICON)
                row.icon:SetTexCoord(0, 1, 0, 1)
                row.name:SetTextColor(0.5, 0.5, 0.5)
            else
                row.icon:SetTexture(coinIcon)
                row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                row.name:SetTextColor(1, 1, 1)
            end
        end
    end
    local total = #source.bosses
    local done = total > 0 and got >= total
    card.count:SetText(("%d / %d"):format(got, total))
    if done then card.count:SetTextColor(unpack(DONE_COLOR)) else card.count:SetTextColor(1, 1, 1) end

    local barWidth = (card:GetWidth() or 0) - PAD * 2
    local fraction = total > 0 and got / total or 0
    card.bar:SetWidth(math.max(0.01, barWidth * fraction))
    card.bar:SetShown(fraction > 0 and barWidth > 0)
    if done then card.bar:SetVertexColor(unpack(DONE_COLOR)) else card.bar:SetVertexColor(unpack(E.media.valueColor)) end

    if here then
        card:SetBackdropBorderColor(unpack(E.media.valueColor))
    else
        card:SetBackdropBorderColor(unpack(E.media.borderColor))
    end
    return got, total
end

local function createCoinList(parent, mod)
    local list = {frame = CreateFrame("Frame", nil, parent)}
    local frame = list.frame

    list.header = T:Header(frame, {text = L["LootCoinToday"]})

    local summaryIcon = frame:CreateTexture(nil, "OVERLAY")
    summaryIcon:SetSize(20, 20)
    summaryIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local summary = E:CreateFontString(frame, nil, "OVERLAY", fontSize(2))
    summary:SetPoint("LEFT", summaryIcon, "RIGHT", 8, 0)
    local reset = E:CreateFontString(frame, nil, "OVERLAY")
    reset:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    reset:SetPoint("TOP", summaryIcon, "TOP", 0, 0)
    reset:SetPoint("BOTTOM", summaryIcon, "BOTTOM", 0, 0)
    reset:SetJustifyH("RIGHT")
    reset:SetTextColor(0.6, 0.6, 0.6)

    local sources = mod:GetCoinList()
    local cards = {}
    for index, source in ipairs(sources) do cards[index] = createCard(frame, source) end

    local lastReset
    local function updateReset()
        local seconds = secondsUntilReset()
        if seconds and lastReset and seconds > lastReset + 60 then
            lastReset = seconds
            list.Refresh()
            return
        end
        lastReset = seconds
        reset:SetText(seconds and L["LootCoinResetsIn"]:format(formatReset(seconds)) or "")
    end
    list.UpdateReset = updateReset

    function list.Refresh()
        sources = mod:GetCoinList()
        local _, _, _, _, _, _, _, instanceID = GetInstanceInfo()
        if E:IsSecret(instanceID) then instanceID = nil end
        local coinIcon = mod:GetCoinIcon()
        local got, total = 0, 0
        for index, source in ipairs(sources) do
            if cards[index] then
                local cardGot, cardTotal = updateCard(cards[index], source, coinIcon, instanceID ~= nil and source.instanceID == instanceID)
                got, total = got + cardGot, total + cardTotal
            end
        end
        summaryIcon:SetTexture(coinIcon)
        summary:SetText(L["LootCoinLooted"]:format(got, total))
        updateReset()
    end

    function list.Layout(width)
        frame:SetWidth(width)
        local top = T:PlaceFull(frame, list.header, 0, width) + 6
        summaryIcon:ClearAllPoints()
        summaryIcon:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -(top + (SUMMARY_H - 20) / 2))
        top = top + SUMMARY_H + 8

        local columns = width >= 900 and 3 or width >= 480 and 2 or 1
        local cardWidth = (width - CARD_GAP * (columns - 1)) / columns
        local heights = {}
        for column = 1, columns do heights[column] = 0 end
        for _, card in ipairs(cards) do
            local column = 1
            for c = 2, columns do
                if heights[c] < heights[column] then column = c end
            end
            local height = layoutCard(card, cardWidth)
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", frame, "TOPLEFT", (column - 1) * (cardWidth + CARD_GAP), -(top + heights[column]))
            heights[column] = heights[column] + height + CARD_GAP
        end
        local tallest = 0
        for column = 1, columns do tallest = math.max(tallest, heights[column]) end
        local height = top + math.max(0, tallest - CARD_GAP)
        frame:SetHeight(height)
        list.Refresh()
        return height
    end

    return list
end

local function createSettingsPanel(parent, mod)
    local panel = {frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")}
    E:SetTemplate(panel.frame, "Transparent")
    local inner = CreateFrame("Frame", nil, panel.frame)
    inner:SetPoint("TOPLEFT", panel.frame, "TOPLEFT", 0, -PANEL_PAD)
    local header = T:Header(inner, {text = L["LootCoinReminder"]})
    local body = CreateFrame("Frame", nil, inner)
    local handle, builtWidth

    function panel.Layout(width)
        panel.frame:SetWidth(width)
        local innerWidth = math.max(1, width)
        inner:SetWidth(innerWidth)
        local top = T:PlaceFull(inner, header, 0, innerWidth) + 6
        body:ClearAllPoints()
        body:SetPoint("TOPLEFT", inner, "TOPLEFT", 0, -top)
        body:SetWidth(innerWidth)
        if not builtWidth or math.abs(builtWidth - innerWidth) >= 0.5 then
            if handle and handle.Release then handle.Release() end
            builtWidth = innerWidth
            handle = buildLootCoinBody(body, mod, isDisabled)
        end
        local height = top + (handle and handle.height or 1)
        inner:SetHeight(height)
        panel.frame:SetHeight(height + PANEL_PAD * 2)
        return height + PANEL_PAD * 2
    end

    function panel.Refresh()
        if handle and handle.Refresh then handle.Refresh() end
    end

    return panel
end

local function buildPage(parent)
    local mod = E:GetModule("LootCoin")
    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(1)
    local widget = {frame = container, height = 1, fullWidth = true}
    local list = createCoinList(container, mod)
    local settings = createSettingsPanel(container, mod)
    local builtWidth

    widget._relayout = function()
        local width = container:GetWidth() or 0
        if width <= 0 or (builtWidth and math.abs(builtWidth - width) < 0.5) then return end
        builtWidth = width
        local height
        list.frame:ClearAllPoints()
        settings.frame:ClearAllPoints()
        list.frame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        if width >= SPLIT_MIN_W then
            local settingsWidth = math.max(SETTINGS_MIN_W, math.floor(width * 0.3))
            local listHeight = list.Layout(width - settingsWidth - PANEL_GAP)
            settings.frame:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
            height = math.max(listHeight, settings.Layout(settingsWidth))
        else
            local listHeight = list.Layout(width)
            settings.frame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -(listHeight + PANEL_GAP))
            height = listHeight + PANEL_GAP + settings.Layout(width)
        end
        widget.height = height
        container:SetHeight(height)
    end

    widget.Refresh = function()
        list.Refresh()
        settings.Refresh()
    end

    local elapsed = 0
    container:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed < 1 then return end
        elapsed = 0
        list.UpdateReset()
    end)
    container:SetScript("OnHide", function()
        mod:SetEditMode(false)
    end)

    return widget
end

local function buildPanel()
    return {
        type = "group",
        name = L["LootCoin"],
        args = {
            desc = {order = 1, width = "full", build = function(parent)
                return T:Description(parent, {text = L["LootCoinDesc"], sizeDelta = 1})
            end},
            page = {order = 10, width = "full", build = buildPage}
        }
    }
end

if E:IsForeverClient() then
    E:RegisterOptions("LootCoin", 34, buildPanel)
    local events = E:NewCallbackHandle()
    events:RegisterMessage("ART_LOOTCOIN_UPDATED", function()
        if E.OptionsUI and E.OptionsUI.QueueRefresh then E.OptionsUI:QueueRefresh("current") end
    end)
end
