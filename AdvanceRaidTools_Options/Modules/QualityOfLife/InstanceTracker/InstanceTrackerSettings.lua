local E, L = unpack(ART)
local T = E.Templates

local PAD, PIP_GAP, PIP_H, ROW_H, ROW_GAP = 12, 4, 8, 20, 2
local GOOD = {0.25, 1, 0.25}
local WARN = {1, 0.65, 0.1}
local FULL = {1, 0.25, 0.25}
local MUTED = {0.6, 0.6, 0.6}

local function fontSize(delta)
    return (E.media.normFontSize or 12) + (delta or 0)
end

local function usedColor(used, cap)
    if used >= cap then return FULL end
    if cap - used <= 2 then return WARN end
    return GOOD
end

local function classColor(class)
    local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if color then return color.r, color.g, color.b end
    return 1, 1, 1
end

local function createRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_H)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetTexture(E.media.blankTex)
    row.bg:SetVertexColor(1, 1, 1, 0.04)
    row.frees = E:CreateFontString(row, nil, "OVERLAY")
    row.frees:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.frees:SetJustifyH("RIGHT")
    row.frees:SetTextColor(unpack(MUTED))
    row.char = E:CreateFontString(row, nil, "OVERLAY")
    row.char:SetPoint("RIGHT", row.frees, "LEFT", -16, 0)
    row.char:SetJustifyH("RIGHT")
    row.char:SetWordWrap(false)
    row.name = E:CreateFontString(row, nil, "OVERLAY")
    row.name:SetPoint("LEFT", row, "LEFT", 6, 0)
    row.name:SetPoint("RIGHT", row.char, "LEFT", -8, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    return row
end

local function buildHourPanel(parent, mod)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    E:SetTemplate(frame, "Transparent")
    frame:SetHeight(1)
    local widget = {frame = frame, height = 1, fullWidth = true}

    local header = T:Header(frame, {text = L["QoL_InstanceTrackerHour"]})
    local count = E:CreateFontString(frame, nil, "OVERLAY", fontSize(10))
    count:SetJustifyH("LEFT")
    local nextFree = E:CreateFontString(frame, nil, "OVERLAY", fontSize(1))
    nextFree:SetJustifyH("RIGHT")
    local empty = E:CreateFontString(frame, nil, "OVERLAY")
    empty:SetJustifyH("LEFT")
    empty:SetTextColor(unpack(MUTED))
    empty:SetText(L["QoL_InstanceTrackerNone"])

    local pips, rows = {}, {}
    local laidOut = {}

    local function pip(index)
        if not pips[index] then
            local texture = frame:CreateTexture(nil, "ARTWORK")
            texture:SetTexture(E.media.blankTex)
            pips[index] = texture
        end
        return pips[index]
    end

    local function layout()
        local width = frame:GetWidth() or 0
        if width <= 0 then return end
        local inner = width - PAD * 2
        local entries, cap = mod:GetHour()
        local y = T:PlaceFull(frame, header, PAD, width) + PAD + 8

        count:ClearAllPoints()
        count:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
        local countHeight = math.max(fontSize(10), count:GetStringHeight() or 0)
        nextFree:ClearAllPoints()
        nextFree:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -PAD, -(y + countHeight - 2))
        y = y + countHeight + 10

        local pipWidth = (inner - PIP_GAP * (cap - 1)) / cap
        for index = 1, math.max(cap, #pips) do
            local texture = pip(index)
            texture:ClearAllPoints()
            if index <= cap then
                texture:SetSize(math.max(1, pipWidth), PIP_H)
                texture:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + (index - 1) * (pipWidth + PIP_GAP), -y)
                texture:Show()
            else
                texture:Hide()
            end
        end
        y = y + PIP_H + 14

        for index = 1, math.max(#entries, #rows) do
            if index <= #entries then
                rows[index] = rows[index] or createRow(frame)
                local row = rows[index]
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
                row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -y)
                row:Show()
                y = y + ROW_H + ROW_GAP
            elseif rows[index] then
                rows[index]:Hide()
            end
        end

        empty:ClearAllPoints()
        if #entries == 0 then
            empty:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
            empty:Show()
            y = y + ROW_H
        else
            empty:Hide()
        end

        y = y + PAD

        laidOut.entries, laidOut.cap = #entries, cap
        frame:SetHeight(y)
        widget.height = y
    end

    local function update()
        local now = time()
        local entries, cap, frees = mod:GetHour(now)
        if laidOut.entries ~= #entries or laidOut.cap ~= cap then
            layout()
            if E.OptionsUI and E.OptionsUI.QueueRefresh then E.OptionsUI:QueueRefresh("current") end
        end
        local used = #entries
        local color = usedColor(used, cap)
        count:SetText(L["QoL_InstanceTrackerUsed"]:format(used, cap))
        count:SetTextColor(unpack(color))
        if frees then
            nextFree:SetText(L["QoL_InstanceTrackerNextIn"]:format(mod:FormatTime(frees)))
            nextFree:SetTextColor(1, 1, 1)
        else
            nextFree:SetText(L["QoL_InstanceTrackerAllFree"])
            nextFree:SetTextColor(unpack(MUTED))
        end
        for index = 1, cap do
            local texture = pips[index]
            if texture then
                if index <= used then
                    texture:SetVertexColor(color[1], color[2], color[3], 1)
                else
                    texture:SetVertexColor(1, 1, 1, 0.1)
                end
            end
        end
        for index, entry in ipairs(entries) do
            local row = rows[index]
            if row then
                local name = entry.name or ""
                if entry.kind == "raid" and entry.difficultyName then
                    name = ("%s (%s)"):format(name, entry.difficultyName)
                end
                row.name:SetText(name)
                row.char:SetText(entry.charName or "")
                row.char:SetTextColor(classColor(entry.class))
                row.frees:SetText(L["QoL_InstanceTrackerFreesIn"]:format(mod:FormatTime(entry.at + mod.HOUR - now)))
            end
        end
    end

    widget._relayout = function()
        layout()
        update()
    end
    widget.Refresh = update

    local elapsed = 0
    frame:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed < 1 then return end
        elapsed = 0
        update()
    end)

    return widget
end

local function buildInstanceTrackerTab(mod, isDisabled)
    return {
        warn = {
            order = 10,
            width = "1/2",
            build = function(parent)
                return T:Checkbox(parent, {
                    text = L["QoL_InstanceTrackerWarn"],
                    get = function() return mod.db.warn end,
                    onChange = function(_, value)
                        mod.db.warn = value and true or false
                        if E.OptionsUI and E.OptionsUI.QueueRefresh then E.OptionsUI:QueueRefresh("current") end
                    end,
                    disabled = isDisabled,
                    tooltip = {title = L["QoL_InstanceTrackerWarn"], desc = L["QoL_InstanceTrackerWarnDesc"]}
                })
            end
        },
        warnLeft = {
            order = 11,
            width = "1/2",
            build = function(parent)
                return T:Slider(parent, {
                    label = L["QoL_InstanceTrackerWarnAt"],
                    min = 1,
                    max = 5,
                    step = 1,
                    value = mod.db.warnLeft or 2,
                    get = function() return mod.db.warnLeft or 2 end,
                    onChange = function(value) mod.db.warnLeft = math.floor(value + 0.5) end,
                    format = function(value) return L["QoL_InstanceTrackerLeft"]:format(value) end,
                    disabled = function() return isDisabled() or not mod.db.warn end
                })
            end
        },
        announceReset = {
            order = 12,
            width = "full",
            build = function(parent)
                return T:Checkbox(parent, {
                    text = L["QoL_InstanceTrackerAnnounce"],
                    get = function() return mod.db.announceReset end,
                    onChange = function(_, value) mod.db.announceReset = value and true or false end,
                    disabled = isDisabled,
                    tooltip = {title = L["QoL_InstanceTrackerAnnounce"], desc = L["QoL_InstanceTrackerAnnounceDesc"]}
                })
            end
        },
        hour = {
            order = 20,
            width = "full",
            build = function(parent)
                return buildHourPanel(parent, mod)
            end
        }
    }
end

if E:IsForeverClient() then
    E:RegisterQoLFeatureSettings("InstanceTracker", buildInstanceTrackerTab)
    local events = E:NewCallbackHandle()
    events:RegisterMessage("ART_INSTANCETRACKER_UPDATED", function()
        if E.OptionsUI and E.OptionsUI.QueueRefresh then E.OptionsUI:QueueRefresh("current") end
    end)
end
