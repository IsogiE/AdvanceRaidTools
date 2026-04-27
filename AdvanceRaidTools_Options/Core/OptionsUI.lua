local E, L = unpack(ART)
local T = E.Templates
local OH = E.OptionsHelpers

local ART_UI = {}
E.OptionsUI = ART_UI

-- Defaults
local WIN_W, WIN_H = 1040, 680
local SIDEBAR_W = 180
local TITLE_H = 28
local TAB_H = 24
local TAB_PAD_X = 16 -- horizontal padding
local TAB_GAP = 2 -- gap between tab buttons
local TAB_MIN_W = 80 -- floor so very short labels like "General" don't look tiny
local PAD = 12 -- outer padding between the frame edge and content stuff
local INNER_PAD = 6 -- gap between panels
local LOGO_SIZE = 110
local ROW_GAP = 6
local COL_GAP = 6 -- default horizontal gap between widgets sharing a row
local H_WIDGET = 22
local H_HEADER = 24
local H_TOGGLE = 18
local H_SLIDER = 20 -- match the dropdown button height so mixed rows align
local H_COLOR = 18
local BASE_WIDTH = 180

-- Modules can config their own min size if needed
--[[
E:RegisterOptions("XYZ", XX, XYZ, {
    minWidth = 980,
    minHeight = 620
})
--]]

-- State
ART_UI.mainFrame = nil
ART_UI.panels = {}
ART_UI.sidebarBtns = {}
ART_UI.currentKey = nil
ART_UI.allRefreshers = {}
ART_UI.panelRefreshers = {}
local GLOBAL = {}

ART_UI._resizeHooks = {}
ART_UI._flusherStack = {}

function ART_UI:PushFlusherOwner(owner)
    self._flusherStack[#self._flusherStack + 1] = owner
end

function ART_UI:PopFlusherOwner()
    self._flusherStack[#self._flusherStack] = nil
end

function ART_UI:AddResizeFlusher(fn, owner)
    local key = owner or self._flusherStack[#self._flusherStack] or GLOBAL
    local bucket = self._resizeHooks[key]
    if not bucket then
        bucket = {
            list = {},
            dirty = false
        }
        self._resizeHooks[key] = bucket
    end
    bucket.list[#bucket.list + 1] = fn
end

local function runFlusherList(list)
    for _, fn in ipairs(list) do
        local ok, err = pcall(fn)
        if not ok then
            geterrorhandler()(err)
        end
    end
end

function ART_UI:_runResizeFlushers()
    for owner, bucket in pairs(self._resizeHooks) do
        if owner == GLOBAL or owner:IsVisible() then
            runFlusherList(bucket.list)
            bucket.dirty = false
        else
            bucket.dirty = true
        end
    end
end

function ART_UI:CatchUp()
    for owner, bucket in pairs(self._resizeHooks) do
        if bucket.dirty and owner ~= GLOBAL and owner:IsVisible() then
            runFlusherList(bucket.list)
            bucket.dirty = false
        end
    end
end

-- colour
local c_border = OH.c_border
local c_accent = OH.c_accent
local c_bg = OH.c_backdrop
local c_bgFade = OH.c_bgFade
local c_text = OH.c_text

-- Sidebar uses a darker dim than widget chrome
local C_TEXT_DIM_RGB = {0.4, 0.4, 0.4}
local function c_textDim()
    return C_TEXT_DIM_RGB
end

local fontPath = OH.fontPath
local fontSize = OH.fontSize
local fontOutline = OH.fontOutline

local function callFn(v, ...)
    if type(v) == "function" then
        return v(...)
    end
    return v
end

-- AceConfig stuff
local function makeInfo(path, option, handler, appName)
    local info = {}
    for i, seg in ipairs(path) do
        info[i] = seg
    end
    info.option = option
    info.type = option.type
    info.handler = handler
    info.appName = appName or E.addonName
    info.options = E._rootOptions
    info.arg = option.arg
    return info
end

local function invokeField(field, info, defaultMethod, ...)
    if type(field) == "function" then
        return field(info, ...)
    end
    local h = info and info.handler
    if type(field) == "string" then
        if h and type(h[field]) == "function" then
            return h[field](h, info, ...)
        end
        return nil
    end
    if field == nil and defaultMethod and h and type(h[defaultMethod]) == "function" then
        return h[defaultMethod](h, info, ...)
    end
    return nil
end

local function resolveField(field, info)
    if type(field) == "function" then
        return field(info)
    end
    if type(field) == "string" then
        local h = info and info.handler
        if h and type(h[field]) == "function" then
            return h[field](h, info)
        end
    end
    return field
end

local function callGet(option, info, ...)
    return invokeField(option.get, info, "Get" .. (info[#info] or ""), ...)
end

local function callSet(option, info, ...)
    return invokeField(option.set, info, "Set" .. (info[#info] or ""), ...)
end

local function callFunc(option, info, ...)
    return invokeField(option.func, info, nil, ...)
end

local function callValidate(option, info, ...)
    local v = option.validate
    if v == nil or v == true then
        return true
    end
    local r = invokeField(v, info, nil, ...)
    if r == nil then
        return true
    end
    return r
end

local function evalName(option, info)
    local n = resolveField(option.name, info)
    if type(n) == "string" or type(n) == "number" then
        return n
    end
    return ""
end

local function evalDesc(option, info)
    return resolveField(option.desc, info)
end

local function evalHidden(option, info)
    return resolveField(option.hidden, info)
end

local function evalDisabled(option, info)
    return resolveField(option.disabled, info)
end

local function evalValues(option, info)
    return resolveField(option.values, info) or {}
end

local function evalConfirm(option, info)
    return resolveField(option.confirm, info)
end

local function confirmText(option, info)
    local t = resolveField(option.confirmText, info)
    if t then
        return t
    end
    if type(option.confirm) == "string" then
        return option.confirm
    end
    return (L and L["AreYouSure"]) or "Are you sure?"
end

local function newFont(parent, layer, delta)
    return OH.newFont(parent, delta, layer)
end

local measureStringWidth = OH.measureStringWidth
local setTemplate = OH.setTemplate
local newBackdropFrame = OH.newBackdropFrame

local function aceWrap(tpl, opts)
    opts = opts or {}
    local extra = opts.Refresh
    local function Refresh()
        if extra then
            extra(tpl)
        end
        if tpl.Refresh then
            tpl.Refresh()
        end
    end
    Refresh()
    return {
        frame = tpl.frame,
        Refresh = Refresh,
        height = tpl.height,
        fullWidth = opts.fullWidth,
        GetNaturalWidth = opts.GetNaturalWidth or tpl.GetNaturalWidth,
        _relayout = opts._relayout or tpl.Relayout
    }
end

-- Header
local function buildHeader(parent, option, info)
    local tpl = T:Header(parent, {
        text = evalName(option, info)
    })
    return aceWrap(tpl, {
        fullWidth = true,
        Refresh = function(tpl)
            tpl.SetText(evalName(option, info))
        end
    })
end

-- Description
local function buildDescription(parent, option, info)
    local tpl = T:Description(parent, {
        text = evalName(option, info),
        sizeDelta = option.fontSize == "large" and 2 or option.fontSize == "medium" and 1 or 0
    })
    return aceWrap(tpl, {
        fullWidth = true,
        Refresh = function(tpl)
            tpl.SetText(evalName(option, info))
        end
    })
end

-- Toggle
local function buildToggle(parent, option, info)
    local tpl = T:Checkbox(parent, {
        text = evalName(option, info),
        checked = callGet(option, info) and true or false,
        tooltip = function()
            local title = evalName(option, info)
            local desc = evalDesc(option, info)
            if title or desc then
                return {
                    title = title,
                    desc = desc
                }
            end
        end,
        disabled = function()
            return evalDisabled(option, info)
        end,
        onChange = function(_, newVal)
            callSet(option, info, newVal)
            -- a toggle can change other widgets; refresh the panel
            ART_UI:QueueRefresh("current")
        end
    })
    ART_UI:AddResizeFlusher(tpl.Refresh)

    local BOX_W, GAP, PAD_R = 16, 6, 4
    return aceWrap(tpl, {
        Refresh = function(tpl)
            tpl.SetLabel(evalName(option, info))
            tpl.SetChecked(callGet(option, info) and true or false)
        end,
        GetNaturalWidth = function()
            local textW = measureStringWidth(tpl.label)
            return math.max(40, BOX_W + GAP + textW + PAD_R)
        end
    })
end

-- Execute
local function buildExecute(parent, option, info)
    local function doFire()
        callFunc(option, info)
        ART_UI:QueueRefresh("current")
    end

    local tpl = T:Button(parent, {
        text = evalName(option, info),
        height = 24,
        tooltip = function()
            local desc = evalDesc(option, info)
            if desc then
                return {
                    title = evalName(option, info),
                    desc = desc
                }
            end
        end,
        tooltipAnchor = "ANCHOR_CURSOR",
        disabled = function()
            return evalDisabled(option, info)
        end,
        confirm = function()
            local c = evalConfirm(option, info)
            if not c then
                return nil
            end
            return confirmText(option, info)
        end,
        confirmTitle = function()
            return evalName(option, info)
        end,
        onClick = doFire
    })

    return aceWrap(tpl, {
        Refresh = function(tpl)
            tpl.SetLabel(evalName(option, info))
        end
    })
end

-- Slider
local function buildRange(parent, option, info)
    local tpl = T:Slider(parent, {
        label = evalName(option, info),
        value = callGet(option, info) or option.min or 0,
        min = option.min or 0,
        max = option.max or 1,
        step = option.step or 0.01,
        isPercent = option.isPercent,
        tooltip = function()
            local desc = evalDesc(option, info)
            if desc then
                return {
                    title = evalName(option, info),
                    desc = desc
                }
            end
        end,
        tooltipAnchor = "ANCHOR_CURSOR",
        disabled = function()
            return evalDisabled(option, info)
        end,
        onChange = function(v)
            callSet(option, info, v)
        end
    })

    return aceWrap(tpl, {
        Refresh = function(tpl)
            tpl.SetLabel(evalName(option, info))
            tpl.SetMinMax(option.min or 0, option.max or 1)
            tpl.SetStep(option.step or 0.01)
            tpl.SetValue(callGet(option, info) or option.min or 0)
        end,
        GetNaturalWidth = function()
            return 150
        end
    })
end

-- Dropdown
local function buildDropdown(parent, option, info)
    local multi = option.type == "multiselect"

    local tpl = T:Dropdown(parent, {
        label = evalName(option, info),
        values = function()
            return evalValues(option, info)
        end,
        sorting = option.sorting,
        multi = multi,
        get = function(key)
            if multi then
                return callGet(option, info, key)
            end
            return callGet(option, info)
        end,
        onChange = function(key, newBool)
            if multi then
                callSet(option, info, key, newBool)
            else
                callSet(option, info, key)
            end
            ART_UI:QueueRefresh("current")
        end,
        disabled = function()
            return evalDisabled(option, info)
        end,
        tooltip = function()
            local desc = evalDesc(option, info)
            if desc then
                return {
                    title = evalName(option, info),
                    desc = desc
                }
            end
        end
    })

    return aceWrap(tpl, {
        Refresh = function(tpl)
            tpl.SetLabel(evalName(option, info))
        end
    })
end

-- Single-line EditBox
local function buildEditBox(parent, option, info)
    local tpl = T:EditBox(parent, {
        label = evalName(option, info),
        default = tostring(callGet(option, info) or ""),
        showCommitButton = true,
        template = "Default",
        commitOn = "enter",
        validate = function(text)
            return callValidate(option, info, text)
        end,
        onCommit = function(text)
            callSet(option, info, text)
            ART_UI:QueueRefresh("current")
        end,
        disabled = function()
            return evalDisabled(option, info)
        end
    })

    return aceWrap(tpl, {
        Refresh = function(tpl)
            tpl.SetLabel(evalName(option, info))
            if not tpl.editBox:HasFocus() then
                tpl.SetText(tostring(callGet(option, info) or ""))
            end
        end
    })
end

-- Multi-line EditBox
local function buildMultilineEditBox(parent, option, info)
    local lines = type(option.multiline) == "number" and option.multiline or 8
    local tpl
    tpl = T:MultilineEditBox(parent, {
        label = evalName(option, info),
        default = tostring(callGet(option, info) or ""),
        lines = lines,
        template = "Default",
        onTextChanged = function(text, userInput)
            if not userInput then
                return
            end
            -- Debounced push to the setter
            tpl._debounceSeq = (tpl._debounceSeq or 0) + 1
            local seq = tpl._debounceSeq
            C_Timer.After(0.25, function()
                if tpl._debounceSeq == seq then
                    if callValidate(option, info, text) == true then
                        callSet(option, info, text)
                    end
                end
            end)
        end,
        disabled = function()
            return evalDisabled(option, info)
        end
    })

    return aceWrap(tpl, {
        Refresh = function(tpl)
            tpl.SetLabel(evalName(option, info))
            if not tpl.editBox:HasFocus() then
                tpl.SetText(tostring(callGet(option, info) or ""))
            end
        end
    })
end

-- Color
local function buildColor(parent, option, info)
    local function read()
        local r, g, b, a = callGet(option, info)
        return r or 1, g or 1, b or 1, a or 1
    end

    local initR, initG, initB, initA = read()
    local tpl
    tpl = T:ColorSwatch(parent, {
        label = evalName(option, info),
        r = initR,
        g = initG,
        b = initB,
        a = initA,
        hasAlpha = option.hasAlpha,
        tooltip = function()
            local desc = evalDesc(option, info)
            if desc then
                return {
                    title = evalName(option, info),
                    desc = desc
                }
            end
        end,
        tooltipAnchor = "ANCHOR_CURSOR",
        disabled = function()
            return evalDisabled(option, info)
        end,
        onChange = function(r, g, b, a)
            callSet(option, info, r, g, b, a)
            -- debounce panel-level refresh so dragging the hue slider is smooth
            tpl._colorSeq = (tpl._colorSeq or 0) + 1
            local seq = tpl._colorSeq
            C_Timer.After(0.1, function()
                if tpl._colorSeq == seq then
                    ART_UI:QueueRefresh("current")
                end
            end)
        end,
        onCancel = function(r, g, b, a)
            callSet(option, info, r, g, b, a)
        end
    })

    return aceWrap(tpl, {
        Refresh = function(tpl)
            tpl.SetLabel(evalName(option, info))
            tpl.SetColor(read())
        end,
        GetNaturalWidth = function()
            return 40 -- swatch + label, laid out by caller
        end
    })
end

-- Layout

local function widthColumns(option)
    local w = option.width
    if w == "full" then
        return nil
    end -- nil means fill row
    if w == "double" then
        return 2.0
    end
    if w == "half" then
        return 0.5
    end
    if w == "normal" then
        return 1.0
    end
    if type(w) == "number" then
        return w
    end
    if option.type == "toggle" then
        return 1.0
    end
    if option.type == "color" then
        return 0.5
    end
    if option.type == "execute" then
        return 1.0
    end
    return nil -- range, select, input, multiselect: fill
end

local function parseRowFraction(w)
    if type(w) ~= "string" then
        return nil
    end
    local num, den = w:match("^(%d+)%s*/%s*(%d+)$")
    if not num then
        return nil
    end
    local n, d = tonumber(num), tonumber(den)
    if not n or not d or d <= 0 or n <= 0 then
        return nil
    end
    local f = n / d
    if f > 1 then
        return nil
    end
    return f
end

local function buildWidget(parent, option, info)
    if type(option.build) == "function" then
        local ok, inst = pcall(option.build, parent, info, option)
        if not ok then
            E:ChannelWarn("Options", "Custom widget build failed: %s", inst)
            return nil
        end
        return inst
    end

    local t = option.type
    if t == "header" then
        return buildHeader(parent, option, info)
    elseif t == "description" then
        return buildDescription(parent, option, info)
    elseif t == "toggle" then
        return buildToggle(parent, option, info)
    elseif t == "range" then
        return buildRange(parent, option, info)
    elseif t == "select" then
        return buildDropdown(parent, option, info)
    elseif t == "multiselect" then
        return buildDropdown(parent, option, info)
    elseif t == "execute" then
        return buildExecute(parent, option, info)
    elseif t == "color" then
        return buildColor(parent, option, info)
    elseif t == "input" then
        if option.multiline then
            return buildMultilineEditBox(parent, option, info)
        end
        return buildEditBox(parent, option, info)
    end
    return nil
end

-- sort args table into an array
local function sortedArgs(args)
    if not args then
        return {}
    end
    local out = {}
    for key, opt in pairs(args) do
        if type(opt) == "table" then
            out[#out + 1] = {
                key = key,
                opt = opt,
                order = opt.order or 100
            }
        end
    end
    table.sort(out, function(a, b)
        if a.order == b.order then
            return a.key < b.key
        end
        return a.order < b.order
    end)
    return out
end

local function buildArgsInto(parent, args, path, inheritedHandler, startY, contentW, refreshList, rootRefreshList,
    colGap, inChain)
    local entries = sortedArgs(args)
    colGap = colGap or COL_GAP

    local prevState = inChain or {
        endY = startY or 0
    }
    local segItems = {}

    local function layoutSegment(items, baseState, myState)
        local w = parent:GetWidth()
        if not w or w <= 0 then
            w = contentW
        end
        local y = baseState.endY

        local visible = {}
        for _, it in ipairs(items) do
            local opt = it.widget._option
            local info = it.widget._info
            if not (opt and info) or not evalHidden(opt, info) then
                visible[#visible + 1] = it
            end
        end
        items = visible

        local cursorX = 0
        local subItems = {}
        local subRowH = 0

        local flushFW = {}

        local function fixedWidthOf(it)
            local cached = flushFW[it]
            if cached ~= nil then
                return cached or nil
            end
            local fw
            if it._compact then
                local nat = it.widget.GetNaturalWidth and it.widget.GetNaturalWidth() or 0
                if not nat or nat <= 0 then
                    nat = BASE_WIDTH
                end
                fw = math.min(nat, w)
            elseif it._cols then
                fw = math.min(it._cols * BASE_WIDTH, w)
            end
            flushFW[it] = fw or false
            return fw
        end

        local function positionSubRow(sItems, sY)
            local n = #sItems
            if n == 0 then
                return
            end
            local totalGaps = (n > 1) and (colGap * (n - 1)) or 0
            local usableW = math.max(0, w - totalGaps)

            local fracSum = 0
            local fixedTotal = 0
            local fixedPx = {}
            for i, it in ipairs(sItems) do
                if it._frac then
                    fracSum = fracSum + it._frac
                else
                    local fw = fixedWidthOf(it)
                    if fw then
                        fixedPx[i] = fw
                        fixedTotal = fixedTotal + fw
                    end
                end
            end
            local fracAvail = math.max(0, usableW - fixedTotal)

            local sizes = {}
            for i, it in ipairs(sItems) do
                local px
                if it._frac then
                    if fracSum > 0 then
                        if fixedTotal > 0 then
                            px = (it._frac / fracSum) * fracAvail
                        else
                            px = it._frac * usableW
                        end
                    else
                        px = 0
                    end
                elseif fixedPx[i] then
                    px = fixedPx[i]
                else
                    px = w
                end
                sizes[i] = math.max(0, px)
            end

            local x = 0
            for i, it in ipairs(sItems) do
                if i > 1 then
                    x = x + colGap
                end
                local fr = it.widget.frame
                fr:ClearAllPoints()
                fr:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -sY)
                fr:SetWidth(sizes[i])
                if it.widget._relayout then
                    it.widget._relayout()
                end
                x = x + sizes[i]
            end
        end

        local function measureRowHeight(sItems)
            local hMax = 0
            for _, it in ipairs(sItems) do
                local h = it.widget.frame:GetHeight()
                if not h or h <= 0 then
                    h = it.widget.height or H_WIDGET
                end
                if h > hMax then
                    hMax = h
                end
            end
            return hMax
        end

        for _, it in ipairs(items) do
            local approxPx
            if it._frac then
                approxPx = math.max(0, it._frac * w - colGap)
            else
                local fw = fixedWidthOf(it)
                approxPx = fw or w
            end

            local gap = (#subItems > 0) and colGap or 0
            if (cursorX + gap + approxPx > w + 0.5) and #subItems > 0 then
                positionSubRow(subItems, y)
                subRowH = measureRowHeight(subItems)
                y = y + subRowH + ROW_GAP
                subItems = {}
                cursorX = 0
                subRowH = 0
                gap = 0
            end

            subItems[#subItems + 1] = it
            cursorX = cursorX + gap + approxPx
        end

        positionSubRow(subItems, y)
        subRowH = measureRowHeight(subItems)
        y = y + subRowH

        myState.endY = y + ROW_GAP
    end

    local function commitSegment()
        if #segItems == 0 then
            return
        end
        local items = segItems
        segItems = {}

        local baseState = prevState
        local myState = {
            endY = baseState.endY
        }

        local function runLayout()
            layoutSegment(items, baseState, myState)
        end
        ART_UI:AddResizeFlusher(runLayout)
        refreshList[#refreshList + 1] = runLayout
        rootRefreshList[#rootRefreshList + 1] = runLayout
        runLayout()
        prevState = myState
    end

    local function commitFullWidth(widget)
        local baseState = prevState
        local myState = {
            endY = baseState.endY
        }

        local function place()
            local y = baseState.endY
            local fr = widget.frame
            fr:ClearAllPoints()
            fr:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
            fr:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -y)
            if widget._relayout then
                widget._relayout()
            end
            local h = fr:GetHeight()
            if not h or h <= 0 then
                h = widget.height or H_WIDGET
            end
            myState.endY = y + h + ROW_GAP
        end

        ART_UI:AddResizeFlusher(place)
        place()
        prevState = myState
    end

    for _, entry in ipairs(entries) do
        local key, option = entry.key, entry.opt
        local path2 = {unpack(path)}
        path2[#path2 + 1] = key
        local handler = option.handler or inheritedHandler
        local info = makeInfo(path2, option, handler)

        if option.type == "group" then
            if option.inline then
                commitSegment()

                local nm = evalName(option, info)
                if nm and nm ~= "" then
                    local hdr = buildHeader(parent, {
                        type = "header",
                        name = nm
                    }, info)
                    commitFullWidth(hdr)
                    refreshList[#refreshList + 1] = hdr.Refresh
                    rootRefreshList[#rootRefreshList + 1] = hdr.Refresh
                end

                local innerGap = option.colGap or colGap
                local _, innerState = buildArgsInto(parent, option.args, path2, handler, 0, contentW, refreshList,
                    rootRefreshList, innerGap, prevState)
                prevState = innerState
            end
        else
            local widget = buildWidget(parent, option, info)
            if widget then
                widget._option = option
                widget._info = info
                widget._handler = handler

                local refresh = widget.Refresh
                local frame = widget.frame
                local wrap = function()
                    local hid = evalHidden(option, info)
                    if hid then
                        frame:Hide()
                    else
                        frame:Show()
                    end
                    if not hid and refresh then
                        refresh()
                    end
                end
                refreshList[#refreshList + 1] = wrap
                rootRefreshList[#rootRefreshList + 1] = wrap

                if widget.fullWidth then
                    commitSegment()
                    commitFullWidth(widget)
                else
                    local isCompact = (option.width == "compact") and (widget.GetNaturalWidth ~= nil)
                    local frac = (not isCompact) and parseRowFraction(option.width) or nil
                    local cols = (not isCompact) and (not frac) and widthColumns(option) or nil
                    segItems[#segItems + 1] = {
                        widget = widget,
                        _frac = frac,
                        _cols = cols,
                        _compact = isCompact
                    }
                end
            end
        end
    end

    commitSegment()
    return prevState.endY, prevState
end

-- Category panel scroll host
local SCROLLBAR_WIDTH = 12
local SCROLLBAR_GAP = 6
local SCROLLBAR_GUTTER = SCROLLBAR_WIDTH + SCROLLBAR_GAP
local CONTENT_INNER_W = WIN_W - PAD * 4 - SIDEBAR_W - INNER_PAD - SCROLLBAR_GUTTER

local function createScrollHost(parentFrame, minWidth)
    local sh = T:ScrollFrame(parentFrame, {
        chrome = false,
        mouseWheelStep = 40,
        autoWidth = true,
        minContentWidth = minWidth,
        scrollbarWidth = SCROLLBAR_WIDTH,
        scrollbarGap = SCROLLBAR_GAP
    })
    sh.frame:SetAllPoints(parentFrame)

    sh.scroll:HookScript("OnSizeChanged", sh.ApplyAutoWidth)
    ART_UI:AddResizeFlusher(sh.ApplyAutoWidth, sh.content)

    return sh.content, minWidth, sh.scroll
end

-- Panels

local function buildCategoryPanel(parent, key, group, rootRefreshers)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()
    panel:Hide()

    local hasTabs = (group.childGroups == "tab") and group.args

    if not hasTabs then
        local contentHolder = CreateFrame("Frame", nil, panel)
        contentHolder:SetPoint("TOPLEFT", PAD, -PAD)
        contentHolder:SetPoint("BOTTOMRIGHT", -PAD, PAD)

        local inner, innerW = createScrollHost(contentHolder, CONTENT_INNER_W)
        local panelRefreshers = {}
        ART_UI.panelRefreshers[panel] = panelRefreshers
        ART_UI:PushFlusherOwner(inner)
        local usedY, finalState = buildArgsInto(inner, group.args, {key}, group.handler, 0, innerW, panelRefreshers,
            rootRefreshers, group.colGap)
        inner:SetHeight(math.max(1, usedY))
        ART_UI:AddResizeFlusher(function()
            inner:SetHeight(math.max(1, finalState.endY))
        end)
        ART_UI:PopFlusherOwner()

        panel._tabs = {}
        return panel
    end

    local headerArgs = {}
    local hasHeader = false
    for argKey, opt in pairs(group.args) do
        if type(opt) == "table" and opt.type ~= "group" then
            headerArgs[argKey] = opt
            hasHeader = true
        end
    end

    local panelRefreshers = {}
    ART_UI.panelRefreshers[panel] = panelRefreshers

    local HEADER_GAP = 14
    local headerUsedY = 0

    if hasHeader then
        local headerHost = CreateFrame("Frame", nil, panel)
        headerHost:SetPoint("TOPLEFT", PAD, -PAD)
        headerHost:SetPoint("TOPRIGHT", -PAD, -PAD)

        local innerW = CONTENT_INNER_W
        ART_UI:PushFlusherOwner(headerHost)
        headerUsedY = buildArgsInto(headerHost, headerArgs, {key}, group.handler, 0, innerW, panelRefreshers,
            rootRefreshers, group.colGap)
        ART_UI:PopFlusherOwner()
        headerHost:SetHeight(math.max(1, headerUsedY))
    end

    local tabBarTop = PAD + (hasHeader and (headerUsedY + HEADER_GAP) or 0)

    local contentHolder = CreateFrame("Frame", nil, panel)
    contentHolder:SetPoint("TOPLEFT", PAD, -(tabBarTop + TAB_H + 6))
    contentHolder:SetPoint("BOTTOMRIGHT", -PAD, PAD)

    local tabDefs = {} -- for T:TabBar
    local tabEntries = {}
    panel._tabs = {}

    for _, entry in ipairs(sortedArgs(group.args)) do
        local tabKey, tabOpt = entry.key, entry.opt
        if tabOpt.type == "group" then
            local tabContent = CreateFrame("Frame", nil, contentHolder)
            tabContent:SetAllPoints()
            tabContent:Hide()

            local inner, innerW = createScrollHost(tabContent, CONTENT_INNER_W)

            local tabRefreshers = {}
            ART_UI.panelRefreshers[tabContent] = tabRefreshers
            local tabGap = tabOpt.colGap or group.colGap
            ART_UI:PushFlusherOwner(inner)
            local usedY, finalState = buildArgsInto(inner, tabOpt.args, {key, tabKey}, tabOpt.handler or group.handler,
                0, innerW, tabRefreshers, rootRefreshers, tabGap)
            inner:SetHeight(math.max(1, usedY))
            ART_UI:AddResizeFlusher(function()
                inner:SetHeight(math.max(1, finalState.endY))
            end)
            ART_UI:PopFlusherOwner()

            tabDefs[#tabDefs + 1] = {
                key = tabKey,
                label = evalName(tabOpt, makeInfo({key, tabKey}, tabOpt, tabOpt.handler))
            }
            tabEntries[tabKey] = tabContent

            panel._tabs[#panel._tabs + 1] = {
                key = tabKey,
                content = tabContent,
                option = tabOpt
            }
        end
    end

    local tabBar = T:TabBar(panel, {
        tabs = tabDefs,
        height = TAB_H,
        minTabW = TAB_MIN_W,
        tabPadX = TAB_PAD_X,
        tabGap = TAB_GAP,
        autoActivateFirst = false,
        onTabChange = function(key)
            for k, content in pairs(tabEntries) do
                content:SetShown(k == key)
            end
            panel._activeTabContent = tabEntries[key]
            ART_UI:CatchUp()
            ART_UI:RefreshPanel(panel)
        end
    })
    tabBar.frame:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -tabBarTop)
    tabBar.frame:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -tabBarTop)

    for _, t in ipairs(panel._tabs) do
        t.button = tabBar.buttons[t.key]
    end

    panel.ActivateTab = function(target)
        local key
        if type(target) == "string" then
            key = target
        else
            for k, content in pairs(tabEntries) do
                if content == target then
                    key = k
                    break
                end
            end
        end
        if key then
            tabBar.ActivateTab(key)
        end
    end

    panel.ReapplyTabHighlight = tabBar.ReapplyHighlight
    rootRefreshers[#rootRefreshers + 1] = tabBar.ReapplyHighlight
    panelRefreshers[#panelRefreshers + 1] = tabBar.ReapplyHighlight

    panel._refreshTabLabels = function()
        for _, t in ipairs(panel._tabs) do
            tabBar.SetTabLabel(t.key, evalName(t.option, makeInfo({key, t.key}, t.option, t.option.handler)))
        end
    end

    return panel
end

function ART_UI:_applyPanelMinSize(key)
    if not self.mainFrame or not key then
        return
    end
    local contrib = E.optionsContributions and E.optionsContributions[key]
    local targetW = (contrib and contrib.minWidth) or WIN_W
    local targetH = (contrib and contrib.minHeight) or WIN_H
    local curW, curH = self.mainFrame:GetWidth(), self.mainFrame:GetHeight()
    if math.abs(curW - targetW) > 0.5 or math.abs(curH - targetH) > 0.5 then
        self.mainFrame:SetSize(targetW, targetH)
        self:_runResizeFlushers()
    end
end

-- addon frame

local function buildMainFrame()
    local f = CreateFrame("Frame", "ARTOptionsFrame", UIParent, "BackdropTemplate")
    f:Hide()
    f:SetSize(WIN_W, WIN_H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    tinsert(UISpecialFrames, "ARTOptionsFrame")

    setTemplate(f, "Default")
    f:HookScript("OnHide", function()
        T:HideDropdownPullout()
        GameTooltip:Hide()
        f:StopMovingOrSizing()
    end)

    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    local logo = f:CreateTexture(nil, "ARTWORK")
    logo:SetTexture([[Interface\AddOns\AdvanceRaidTools\Media\Textures\logo.tga]])
    logo:SetSize(LOGO_SIZE, LOGO_SIZE)
    logo:SetPoint("TOP", f, "TOPLEFT", PAD + SIDEBAR_W / 2, -PAD)

    -- title panel
    local title = CreateFrame("Frame", nil, f, "BackdropTemplate")
    setTemplate(title, "Transparent")
    title:SetHeight(TITLE_H)
    title:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + SIDEBAR_W + INNER_PAD, -PAD)
    title:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -PAD)

    -- Sidebar panel
    local sidebar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    setTemplate(sidebar, "Transparent")
    sidebar:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(PAD + LOGO_SIZE + INNER_PAD))
    sidebar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, PAD)
    sidebar:SetWidth(SIDEBAR_W)

    local navHost = CreateFrame("Frame", nil, sidebar)
    navHost:SetPoint("TOPLEFT", 4, -4)
    navHost:SetPoint("BOTTOMRIGHT", -4, 4)

    -- version text
    local titleText = newFont(title, "OVERLAY", 2)
    E:RegisterAccentText(titleText)
    titleText:SetPoint("LEFT", title, "LEFT", 8, 0)
    titleText:SetJustifyH("LEFT")
    local version =
        (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("AdvanceRaidTools", "Version")) or "?"
    local function refreshVersionText()
        titleText:SetText(("%s: %s"):format(E:L("Version") or "Version", version))
    end
    refreshVersionText()
    f._refreshVersionText = refreshVersionText

    -- x button
    local close = CreateFrame("Button", nil, title, "BackdropTemplate")
    setTemplate(close, "Default")
    close:SetSize(20, 20)
    close:SetPoint("RIGHT", -4, 0)
    local xText = newFont(close, "OVERLAY", 2)
    xText:SetText("X")
    xText:SetPoint("CENTER", 1, 0)
    xText:SetTextColor(unpack(c_text()))
    close:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(unpack(c_accent()))
    end)
    close:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(c_border()))
    end)
    close:SetScript("OnClick", function()
        f:Hide()
    end)

    local content = CreateFrame("Frame", nil, f, "BackdropTemplate")
    setTemplate(content, "Transparent")
    content:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -INNER_PAD)
    content:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT", 0, -INNER_PAD)
    content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, PAD)

    f._title = title
    f._titleText = titleText
    f._navHost = navHost
    f._content = content
    f._sidebar = sidebar
    return f
end

-- building

function ART_UI:Build(rootOptions)
    if self.mainFrame then
        return
    end
    E._rootOptions = rootOptions
    local f = buildMainFrame()
    self.mainFrame = f

    -- Collect top-level categories in order
    local cats = sortedArgs(rootOptions.args)

    local reg = E.Libs.AceConfigRegistry
    if reg and reg.RegisterCallback then
        reg.RegisterCallback(self, "ConfigTableChange", function(_, appName)
            if appName == E.addonName and self.mainFrame and self.mainFrame:IsShown() then
                self:QueueRefresh("current")
            end
        end)
    end

    -- create sidebar button + panel per category
    local y = 0
    for _, entry in ipairs(cats) do
        local key, group = entry.key, entry.opt
        if group.type == "group" then
            local btn = CreateFrame("Button", nil, f._navHost, "BackdropTemplate")
            btn:SetHeight(26)
            btn:SetPoint("TOPLEFT", 4, -y)
            btn:SetPoint("TOPRIGHT", -4, -y)
            y = y + 28

            -- flat button
            btn:SetBackdrop(nil)

            local label = newFont(btn, "OVERLAY", 1)
            label:SetPoint("LEFT", 8, 0)
            label:SetPoint("RIGHT", -4, 0)
            label:SetJustifyH("LEFT")
            label:SetTextColor(unpack(c_text()))
            btn._label = label
            btn._key = key

            -- selected indicator
            local bar = btn:CreateTexture(nil, "OVERLAY")
            bar:SetColorTexture(1, 1, 1)
            bar:SetWidth(2)
            bar:SetPoint("TOPLEFT", 0, 0)
            bar:SetPoint("BOTTOMLEFT", 0, 0)
            bar:Hide()
            E:RegisterAccentTexture(bar)
            btn._bar = bar

            local hi = btn:CreateTexture(nil, "HIGHLIGHT")
            hi:SetColorTexture(c_accent()[1], c_accent()[2], c_accent()[3], 0.2)
            hi:SetAllPoints()
            btn._hi = hi

            local panel = buildCategoryPanel(f._content, key, group, self.allRefreshers)
            self.panels[key] = panel
            self.sidebarBtns[key] = btn

            btn:SetScript("OnClick", function()
                self:SelectCategory(key)
            end)

            btn.Refresh = function()
                label:SetText(evalName(group, makeInfo({key}, group, group.handler)))
                local isSelected = self.currentKey == key
                if isSelected then
                    label:SetTextColor(1, 1, 1)
                else
                    local mod = E:GetModule(key, true)
                    if mod and not mod:IsEnabled() then
                        label:SetTextColor(unpack(c_textDim()))
                    else
                        label:SetTextColor(unpack(c_text()))
                    end
                end
                local ac = c_accent()
                if btn._hi then
                    btn._hi:SetColorTexture(ac[1], ac[2], ac[3], 0.2)
                end
            end
            btn.Refresh()
        end
    end

    -- pck the first category by default
    if cats[1] then
        self:SelectCategory(cats[1].key)
    end

    if next(self._resizeHooks) then
        C_Timer.After(0, function()
            if self.mainFrame then
                self:_runResizeFlushers()
            end
        end)
    end
end

function ART_UI:SelectCategory(key)
    self.currentKey = key

    for _, panel in pairs(self.panels) do
        panel:Hide()
    end
    for _, btn in pairs(self.sidebarBtns) do
        btn._bar:Hide()
        if btn.Refresh then
            btn.Refresh()
        end
    end

    local panel = self.panels[key]
    local btn = self.sidebarBtns[key]
    if panel then
        self:_applyPanelMinSize(key)

        panel:Show()
        if btn then
            btn._bar:Show()
            btn._label:SetTextColor(1, 1, 1)
        end

        if panel._tabs and #panel._tabs > 0 then
            local anyActive
            for _, t in ipairs(panel._tabs) do
                if t.content:IsShown() then
                    anyActive = true
                    break
                end
            end
            if not anyActive and panel.ActivateTab then
                panel.ActivateTab(panel._tabs[1].content)
            end
        end

        self:RefreshPanel(panel)
        self:CatchUp()
    end
end

function ART_UI:RefreshPanel(panel)
    local headerList = ART_UI.panelRefreshers[panel]
    if headerList then
        for _, fn in ipairs(headerList) do
            local ok, err = pcall(fn);
            if not ok then
                geterrorhandler()(err)
            end
        end
    end

    if panel._tabs and #panel._tabs > 0 then
        for _, t in ipairs(panel._tabs) do
            if t.content:IsShown() then
                local list = ART_UI.panelRefreshers[t.content]
                if list then
                    for _, fn in ipairs(list) do
                        local ok, err = pcall(fn);
                        if not ok then
                            geterrorhandler()(err)
                        end
                    end
                end
                return
            end
        end
        -- no tab visible yet, nothing more to do
    end
end

function ART_UI:RefreshCurrent()
    local panel = self.panels[self.currentKey]
    if panel then
        self:RefreshPanel(panel)
    end
    for _, btn in pairs(self.sidebarBtns) do
        if btn.Refresh then
            btn.Refresh()
        end
    end
end

function ART_UI:RefreshAll()
    local panel = self.panels[self.currentKey]
    if panel then
        self:RefreshPanel(panel)
    end
    for _, btn in pairs(self.sidebarBtns) do
        if btn.Refresh then
            btn.Refresh()
        end
    end
end

function ART_UI:QueueRefresh(scope)
    scope = scope or "current"
    if self._queuedScope == "all" then
    elseif scope == "all" then
        self._queuedScope = "all"
    elseif self._queuedScope == nil then
        self._queuedScope = "current"
    end

    if self._refreshPending then
        return
    end
    self._refreshPending = true
    C_Timer.After(0, function()
        self._refreshPending = false
        local s = self._queuedScope
        self._queuedScope = nil
        if not self.mainFrame or not self.mainFrame:IsShown() then
            return
        end
        if s == "all" then
            self:RefreshAll()
        else
            self:RefreshCurrent()
        end
    end)
end

function ART_UI:ScheduleRebuild()
    if self._rebuildPending then
        return
    end
    self._rebuildPending = true
    C_Timer.After(0, function()
        self._rebuildPending = false
        if self.mainFrame then
            self:Rebuild()
        end
    end)
end

function ART_UI:Retranslate()
    if not self.mainFrame then
        return
    end
    if self.mainFrame._refreshVersionText then
        self.mainFrame._refreshVersionText()
    end
    for _, panel in pairs(self.panels) do
        if panel._refreshTabLabels then
            panel._refreshTabLabels()
        end
    end
    self:RefreshAll()
end

function ART_UI:Rebuild()
    if not self.mainFrame then
        return
    end

    local prevKey = self.currentKey
    local wasShown = self.mainFrame:IsShown()

    T:HideDropdownPullout()

    local reg = E.Libs.AceConfigRegistry
    if reg and reg.UnregisterCallback then
        pcall(reg.UnregisterCallback, reg, self, "ConfigTableChange")
    end

    self.mainFrame:Hide()
    self.mainFrame:SetParent(nil)
    self.mainFrame = nil
    self.panels = {}
    self.sidebarBtns = {}
    self.allRefreshers = {}
    self.panelRefreshers = {}
    self._resizeHooks = {}
    self._flusherStack = {}
    self.currentKey = nil

    local root = E._rootOptions
    if not root then
        return
    end
    self:Build(root)

    if self.mainFrame then
        if prevKey and self.panels[prevKey] then
            self:SelectCategory(prevKey)
        end
        if wasShown then
            self.mainFrame:Show()
        end
    end
end

function ART_UI:Show()
    if not self.mainFrame then
        return
    end
    self.mainFrame:Show()
    -- refresh on open to re-sync values
    self:RefreshCurrent()
    C_Timer.After(0, function()
        if self.mainFrame then
            self:CatchUp()
        end
    end)
end

function ART_UI:Hide()
    if self.mainFrame then
        self.mainFrame:Hide()
    end
    T:HideDropdownPullout()
end

function ART_UI:Toggle()
    if self.mainFrame and self.mainFrame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function ART_UI:IsShown()
    return self.mainFrame and self.mainFrame:IsShown()
end

function ART_UI:GetMainFrame()
    return self.mainFrame
end

local UIEvents = E:NewCallbackHandle()
UIEvents:RegisterMessage("ART_MEDIA_UPDATED", function()
    if not ART_UI.mainFrame then
        return
    end
    if ART_UI.panels then
        for _, panel in pairs(ART_UI.panels) do
            if panel.ReapplyTabHighlight then
                panel.ReapplyTabHighlight()
            end
        end
    end
    if ART_UI.sidebarBtns then
        local ac = c_accent()
        for _, btn in pairs(ART_UI.sidebarBtns) do
            if btn._hi then
                btn._hi:SetColorTexture(ac[1], ac[2], ac[3], 0.2)
            end
        end
    end
end)
