local E = unpack(ART)

local BossMods = E:GetModule("BossMods")
local Engines = BossMods.Engines
local Shared = Engines.Shared

local WHITE = Shared.WHITE
local fetchFont = Shared.FetchFont
local fetchBorder = Shared.FetchBorder
local colorTuple = Shared.ColorTuple
local applyFontIfChanged = Shared.ApplyFontIfChanged

local ASSIGN_DEFAULT_UPCOMING = "|cFFAAAAAA"
local ASSIGN_DEFAULT_ACTIVE = "|cFF00FF00"
local ASSIGN_DEFAULT_DONE = "|cFF707070"
local ASSIGN_TITLE_OFFSET_Y = -7
local ASSIGN_ROWS_START_Y = 22
local ASSIGN_ROWS_PAD_X = 8

function Engines.AssignmentList(config)
    assert(type(config) == "table", "Engines.AssignmentList: config required")
    assert(config.parent, "Engines.AssignmentList: config.parent required")

    local state = {
        config = config,
        rows = {},
        title = "",
        highlight = false
    }

    local sizeCfg = config.size or {
        w = 155,
        h = 50
    }

    local anchor = CreateFrame("Frame", nil, config.parent)
    anchor:SetSize(sizeCfg.w, sizeCfg.h)
    anchor:SetFrameStrata("MEDIUM")

    local display = CreateFrame("Frame", nil, anchor, "BackdropTemplate")
    display:SetAllPoints(anchor)
    display:Hide()

    local titleFS = display:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    titleFS:SetPoint("TOP", display, "TOP", 0, ASSIGN_TITLE_OFFSET_Y)

    local rowFS = {}

    local function rowHeight()
        local font = state.config.style and state.config.style.font or {}
        return math.max(20, (font.size or 12) + 4)
    end

    local function applyBackdrop()
        local style = state.config.style or {}
        local border = style.border or {}
        local bg = style.bg or {}
        local enabled = state.highlight or (border.enabled ~= false)
        local edgeFile = fetchBorder(border.texture)
        local edgeSize = math.min(border.size or 16, 16)

        local r, g, b, a
        if state.highlight then
            r, g, b, a = 0, 1, 0.1, 1
        else
            r, g, b, a = colorTuple(border.color, 0.3, 0.3, 0.3, 1)
        end

        if display._artBdMode ~= "bg" then
            display:SetBackdrop({
                bgFile = WHITE,
                insets = {
                    left = 0,
                    right = 0,
                    top = 0,
                    bottom = 0
                }
            })
            E:DisablePixelSnap(display)
            display._artBdMode = "bg"
        end
        E:ApplyOuterBorder(display, {
            enabled = enabled,
            edgeFile = edgeFile,
            edgeSize = edgeSize,
            r = r,
            g = g,
            b = b,
            a = a
        })

        display:SetBackdropColor(0.1, 0.1, 0.1, bg.opacity or 1)
    end

    local function applyFonts()
        local style = state.config.style or {}
        local font = style.font or {}
        local fontPath = fetchFont()
        local size = font.size or 12
        local outline = font.outline or "OUTLINE"

        applyFontIfChanged(titleFS, fontPath, size + 2, outline)
        local justify = font.justify or "LEFT"

        local maxRows = state.config.maxRows or 6
        for i = 1, maxRows do
            if not rowFS[i] then
                rowFS[i] = display:CreateFontString(nil, "OVERLAY")
            end
            local fs = rowFS[i]
            applyFontIfChanged(fs, fontPath, size, outline)
            fs:SetJustifyH(justify)
            fs:ClearAllPoints()
            local yOffset = -(ASSIGN_ROWS_START_Y + (i - 1) * rowHeight())
            if justify == "RIGHT" then
                fs:SetPoint("TOPRIGHT", display, "TOPRIGHT", -ASSIGN_ROWS_PAD_X, yOffset)
            elseif justify == "CENTER" then
                fs:SetPoint("TOP", display, "TOP", 0, yOffset)
            else
                fs:SetPoint("TOPLEFT", display, "TOPLEFT", ASSIGN_ROWS_PAD_X, yOffset)
            end
        end
    end

    local function renderRows()
        local maxRows = state.config.maxRows or 6
        local style = state.config.style or {}
        local colors = style.colors or {}
        local upcoming = colors.upcoming or ASSIGN_DEFAULT_UPCOMING
        local active = colors.active or ASSIGN_DEFAULT_ACTIVE
        local done = colors.done or ASSIGN_DEFAULT_DONE

        local rows = state.rows
        local n = math.min(#rows, maxRows)

        for i = 1, maxRows do
            local fs = rowFS[i]
            if not fs then
                -- First Apply hasn't run yet
                break
            end
            if i <= n then
                local row = rows[i]
                local colorStr, prefix
                if row.state == "active" then
                    colorStr, prefix = active, "-> "
                elseif row.state == "done" then
                    colorStr, prefix = done, "  "
                else
                    colorStr, prefix = upcoming, "  "
                end
                fs:SetText(("%s%s%d. %s|r"):format(colorStr, prefix, i, row.text or ""))
                fs:Show()
            else
                fs:SetText("")
                fs:Hide()
            end
        end

        -- Resize anchor to fit the current row count
        local titleH = 26
        local h = titleH + n * rowHeight()
        if h < sizeCfg.h then
            h = sizeCfg.h
        end
        anchor:SetHeight(h)
    end

    local handle = {
        frame = anchor
    }

    function handle:SetTitle(text)
        state.title = text or ""
        titleFS:SetText(state.title)
    end

    function handle:SetRows(rows)
        state.rows = rows or {}
        renderRows()
    end

    function handle:Clear()
        wipe(state.rows)
        renderRows()
    end

    function handle:SetHighlight(v)
        local target = v and true or false
        if state.highlight == target then
            return
        end
        state.highlight = target
        applyBackdrop()
    end

    function handle:Apply(newConfig)
        if type(newConfig) == "table" then
            state.config = newConfig
        end
        sizeCfg = state.config.size or sizeCfg
        applyFonts()
        applyBackdrop()
        renderRows()
    end

    function handle:Show()
        display:Show()
    end

    function handle:Hide()
        display:Hide()
    end

    function handle:Release()
        display:Hide()
        for _, fs in ipairs(rowFS) do
            fs:Hide()
            fs:SetText("")
        end
        wipe(rowFS)
        display:SetParent(nil)
        anchor:Hide()
        anchor:ClearAllPoints()
        anchor:SetParent(nil)
        wipe(state.rows)
    end

    handle:Apply()
    return handle
end
