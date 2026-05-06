local E, L = unpack(ART)
local T = E.Templates
local OH = E.OptionsHelpers

local ART_UI = {}
E.OptionsUI = ART_UI

-- Defaults
local WIN_W, WIN_H = 1040, 680
local MIN_WIN_W, MIN_WIN_H = 760, 480
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
local RESIZE_GRIP_SIZE = 18
local RESIZE_SCREEN_MARGIN = 50

-- Modules can config their own min size if needed
--[[
E:RegisterOptions("XYZ", XX, XYZ, {
    minWidth = 980, -- only use this when a panel truly cannot fit smaller
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
ART_UI.refreshDirty = {}
local GLOBAL = {}

ART_UI._resizeHooks = {}
ART_UI._flusherStack = {}
ART_UI._liteChromeFrames = setmetatable({}, {
    __mode = "k"
})

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

local function addRefresh(list, fn, kind)
    if kind then
        list[#list + 1] = {
            fn = fn,
            kind = kind
        }
    else
        list[#list + 1] = fn
    end
end

local function refreshEntry(entry)
    if type(entry) == "table" then
        return entry.fn, entry.kind
    end
    return entry, nil
end

local function runRefreshList(list, forceLayout)
    local needsLayout = forceLayout and true or false

    for _, entry in ipairs(list) do
        local fn, kind = refreshEntry(entry)
        if kind ~= "layout" then
            local ok, layoutChangedOrErr = pcall(fn)
            if ok then
                needsLayout = needsLayout or layoutChangedOrErr == true
            else
                geterrorhandler()(layoutChangedOrErr)
            end
        end
    end

    if not needsLayout then
        return false
    end

    for _, entry in ipairs(list) do
        local fn, kind = refreshEntry(entry)
        if kind == "layout" then
            local ok, err = pcall(fn)
            if not ok then
                geterrorhandler()(err)
            end
        end
    end
    return true
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

function ART_UI:IsResizing()
    return self.mainFrame and self.mainFrame._artResizing and true or false
end

local function activeTabContent(panel)
    if not (panel and panel._tabs) then
        return nil
    end
    if panel._activeTabContent and panel._activeTabContent:IsShown() then
        return panel._activeTabContent
    end
    for _, t in ipairs(panel._tabs) do
        if t.content:IsShown() then
            return t.content
        end
    end
    return nil
end

function ART_UI:MarkPanelDirty(panel, includeTabs)
    if not panel then
        return
    end
    self.refreshDirty[panel] = true
    if includeTabs and panel._tabs then
        for _, t in ipairs(panel._tabs) do
            self.refreshDirty[t.content] = true
        end
    end
end

function ART_UI:MarkRefreshDirty(scope)
    scope = scope or "current"
    if scope == "all" then
        for _, panel in pairs(self.panels) do
            self:MarkPanelDirty(panel, true)
        end
        return
    end

    local panel = self.panels[self.currentKey]
    if panel then
        self.refreshDirty[panel] = true
        local content = activeTabContent(panel)
        if content then
            self.refreshDirty[content] = true
        end
    end
end

-- colour
local c_border = OH.c_border
local c_accent = OH.c_accent
local c_text = OH.c_text

-- Sidebar uses a darker dim than widget chrome
local C_TEXT_DIM_RGB = {0.4, 0.4, 0.4}
local function c_textDim()
    return C_TEXT_DIM_RGB
end

local fontPath = OH.fontPath
local fontSize = OH.fontSize
local fontOutline = OH.fontOutline

local function clamp(value, minValue, maxValue)
    value = tonumber(value) or minValue
    if value < minValue then
        return minValue
    end
    if maxValue and value > maxValue then
        return maxValue
    end
    return value
end

local function roundWindowValue(value)
    return math.floor((tonumber(value) or 0) + 0.5)
end

local function optionsWindowDB()
    local g = E.db and E.db.profile and E.db.profile.general
    if not g then
        return nil
    end
    if type(g.optionsWindow) ~= "table" then
        g.optionsWindow = {}
    end
    return g.optionsWindow
end

local function getSavedWindowSize()
    local db = optionsWindowDB()
    if not db then
        return nil, nil
    end
    return tonumber(db.width), tonumber(db.height)
end

local function saveWindowSize(frame)
    local db = optionsWindowDB()
    if not (db and frame) then
        return
    end
    db.width = roundWindowValue(frame:GetWidth() or WIN_W)
    db.height = roundWindowValue(frame:GetHeight() or WIN_H)
end

local function getPanelMinSize(key)
    local contrib = key and E.optionsContributions and E.optionsContributions[key]
    return math.max(MIN_WIN_W, (contrib and contrib.minWidth) or MIN_WIN_W),
        math.max(MIN_WIN_H, (contrib and contrib.minHeight) or MIN_WIN_H)
end

local function getWindowMaxSize(minW, minH)
    local maxW, maxH = WIN_W, WIN_H
    if UIParent and UIParent.GetSize then
        maxW, maxH = UIParent:GetSize()
    end
    maxW = math.max(minW, (tonumber(maxW) or minW) - RESIZE_SCREEN_MARGIN)
    maxH = math.max(minH, (tonumber(maxH) or minH) - RESIZE_SCREEN_MARGIN)
    return maxW, maxH
end

local function setResizeBounds(frame, minW, minH, maxW, maxH)
    if not frame then
        return
    end
    if frame.SetResizeBounds then
        frame:SetResizeBounds(minW, minH, maxW, maxH)
    else
        if frame.SetMinResize then
            frame:SetMinResize(minW, minH)
        end
        if frame.SetMaxResize then
            frame:SetMaxResize(maxW, maxH)
        end
    end
end

local function getScaledCursorPosition()
    local x, y = GetCursorPosition()
    if not (x and y) then
        return nil, nil
    end
    local scale = (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
    if scale <= 0 then
        scale = 1
    end
    return x / scale, y / scale
end

local function anchorFrameTopLeft(frame)
    local left, top = frame:GetLeft(), frame:GetTop()
    if not (left and top) then
        return nil, nil
    end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    return left, top
end

local function getPositionAwareResizeBounds(frame, minW, minH, maxW, maxH, left, top)
    local uiW, uiH = WIN_W, WIN_H
    if UIParent and UIParent.GetSize then
        uiW, uiH = UIParent:GetSize()
    end
    left = tonumber(left) or (frame and frame:GetLeft()) or 0
    top = tonumber(top) or (frame and frame:GetTop()) or uiH

    local posMaxW = math.max(minW, (tonumber(uiW) or maxW) - left - RESIZE_SCREEN_MARGIN)
    local posMaxH = math.max(minH, top - RESIZE_SCREEN_MARGIN)
    return minW, minH, math.min(maxW, posMaxW), math.min(maxH, posMaxH)
end

function ART_UI:_getWindowBounds(key)
    local minW, minH = getPanelMinSize(key or self.currentKey)
    local maxW, maxH = getWindowMaxSize(minW, minH)
    return minW, minH, maxW, maxH
end

function ART_UI:_updateResizeBounds(key)
    if not self.mainFrame then
        return
    end
    local minW, minH, maxW, maxH = self:_getWindowBounds(key)
    setResizeBounds(self.mainFrame, minW, minH, maxW, maxH)
    return minW, minH, maxW, maxH
end

local function resetWindowSize(frame)
    if not frame then
        return
    end
    local minW, minH, maxW, maxH = ART_UI:_getWindowBounds(ART_UI.currentKey)
    setResizeBounds(frame, minW, minH, maxW, maxH)
    frame:SetSize(clamp(WIN_W, minW, maxW), clamp(WIN_H, minH, maxH))
    saveWindowSize(frame)
    ART_UI:_runResizeFlushers()
end

local function ensureLiteChrome(frame)
    if not frame or frame._artLiteChrome then
        return frame and frame._artLiteChrome
    end

    local c = {}
    local fill = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    fill:SetAllPoints(frame)
    c.fill = fill

    local function edge()
        local tex = frame:CreateTexture(nil, "BORDER", nil, 7)
        tex:SetColorTexture(1, 1, 1, 1)
        return tex
    end

    c.left = edge()
    c.left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    c.left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)

    c.right = edge()
    c.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    c.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

    c.top = edge()
    c.top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    c.top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)

    c.bottom = edge()
    c.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    c.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

    frame._artLiteChrome = c
    return c
end

local function setLiteChromeShown(frame, shown)
    local c = frame and ensureLiteChrome(frame)
    if not c then
        return
    end

    if shown then
        local bg = (frame.artTemplate == "Transparent") and E.media.backdropFadeColor or E.media.backdropColor
        local br = E.media.borderColor
        local px = E:PixelSize(frame)
        c.fill:SetColorTexture(bg[1] or 0, bg[2] or 0, bg[3] or 0, bg[4] or 1)
        c.left:SetWidth(px)
        c.right:SetWidth(px)
        c.top:SetHeight(px)
        c.bottom:SetHeight(px)
        c.left:SetVertexColor(br[1] or 0, br[2] or 0, br[3] or 0, br[4] or 1)
        c.right:SetVertexColor(br[1] or 0, br[2] or 0, br[3] or 0, br[4] or 1)
        c.top:SetVertexColor(br[1] or 0, br[2] or 0, br[3] or 0, br[4] or 1)
        c.bottom:SetVertexColor(br[1] or 0, br[2] or 0, br[3] or 0, br[4] or 1)
        c.fill:Show()
        c.left:Show()
        c.right:Show()
        c.top:Show()
        c.bottom:Show()
    else
        c.fill:Hide()
        c.left:Hide()
        c.right:Hide()
        c.top:Hide()
        c.bottom:Hide()
    end
end

local function applyLiteTemplate(frame, template)
    if not frame then
        return
    end
    frame.artTemplate = template or "Default"
    ART_UI._liteChromeFrames[frame] = true
    setLiteChromeShown(frame, true)
end

ART_UI._liteChromeEvents = ART_UI._liteChromeEvents or E:NewCallbackHandle()
if not ART_UI._liteChromeEventsRegistered then
    ART_UI._liteChromeEvents:RegisterMessage("ART_MEDIA_UPDATED", function()
        for frame in pairs(ART_UI._liteChromeFrames) do
            if frame and frame._artLiteChrome then
                setLiteChromeShown(frame, true)
            end
        end
    end)
    ART_UI._liteChromeEventsRegistered = true
end

local function resizeChromeFrames(frame)
    return frame, frame and frame._title, frame and frame._sidebar, frame and frame._content
end

local function forEachResizeChrome(frame, fn)
    local main, title, sidebar, content = resizeChromeFrames(frame)
    if main then
        fn(main)
    end
    if title then
        fn(title)
    end
    if sidebar then
        fn(sidebar)
    end
    if content then
        fn(content)
    end
end

local function suspendResizeBackdrops(frame)
    if not frame or frame._resizeBackdropsSuspended then
        return
    end

    local suspended
    forEachResizeChrome(frame, function(chrome)
        if chrome and chrome.SetBackdrop then
            setLiteChromeShown(chrome, true)
            chrome:SetBackdrop(nil)
            suspended = true
        end
    end)
    frame._resizeBackdropsSuspended = suspended and true or nil
end

local function restoreResizeBackdrops(frame)
    if not (frame and frame._resizeBackdropsSuspended) then
        return
    end
    frame._resizeBackdropsSuspended = nil

    forEachResizeChrome(frame, function(chrome)
        setLiteChromeShown(chrome, false)
        OH.setTemplate(chrome, chrome.artTemplate or "Default")
    end)
end

local function updateOptionsResize(frame)
    local state = frame and frame._artResizeState
    if not state then
        return
    end

    local cursorX, cursorY = getScaledCursorPosition()
    if not cursorX then
        return
    end

    local width = roundWindowValue(clamp(state.startW + cursorX - state.startX, state.minW, state.maxW))
    local height = roundWindowValue(clamp(state.startH - (cursorY - state.startY), state.minH, state.maxH))
    if math.abs(width - state.lastW) > 0.5 or math.abs(height - state.lastH) > 0.5 then
        frame:SetSize(width, height)
        state.lastW = width
        state.lastH = height
    end
end

local function resizeGripOnUpdate(grip)
    updateOptionsResize(grip:GetParent())
end

local function startOptionsResize(grip, button)
    if button and button ~= "LeftButton" then
        return
    end
    local frame = grip:GetParent()
    if not frame or frame._artResizing then
        return
    end

    local cursorX, cursorY = getScaledCursorPosition()
    local left, top = anchorFrameTopLeft(frame)
    if not (cursorX and left and top) then
        return
    end

    local minW, minH, maxW, maxH = ART_UI:_getWindowBounds(ART_UI.currentKey)
    minW, minH, maxW, maxH = getPositionAwareResizeBounds(frame, minW, minH, maxW, maxH, left, top)
    setResizeBounds(frame, minW, minH, maxW, maxH)

    local clamped
    if frame.IsClampedToScreen then
        clamped = frame:IsClampedToScreen()
    end
    if frame.SetClampedToScreen then
        frame:SetClampedToScreen(false)
    end

    frame._artResizing = true
    frame._artResizeState = {
        startX = cursorX,
        startY = cursorY,
        startW = frame:GetWidth() or WIN_W,
        startH = frame:GetHeight() or WIN_H,
        lastW = frame:GetWidth() or WIN_W,
        lastH = frame:GetHeight() or WIN_H,
        minW = minW,
        minH = minH,
        maxW = maxW,
        maxH = maxH,
        clamped = clamped
    }
    suspendResizeBackdrops(frame)
    grip:SetScript("OnUpdate", resizeGripOnUpdate)
end

local function stopOptionsResize(grip)
    local frame = grip:GetParent()
    if not frame then
        return
    end

    grip:SetScript("OnUpdate", nil)
    updateOptionsResize(frame)
    frame:StopMovingOrSizing()
    if not frame._artResizing then
        return
    end

    local state = frame._artResizeState
    frame._artResizing = nil
    frame._artResizeState = nil
    if frame.SetClampedToScreen and state and state.clamped ~= nil then
        frame:SetClampedToScreen(state.clamped)
    end
    ART_UI:_updateResizeBounds(ART_UI.currentKey)
    saveWindowSize(frame)
    ART_UI:_runResizeFlushers()
    restoreResizeBackdrops(frame)
    if ART_UI._queuedScope and not ART_UI._refreshPending then
        ART_UI:QueueRefresh(ART_UI._queuedScope)
    end
end

local function addOptionsResizeGrip(frame)
    frame:SetResizable(true)
    ART_UI:_updateResizeBounds(ART_UI.currentKey)

    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(RESIZE_GRIP_SIZE, RESIZE_GRIP_SIZE)
    grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    grip:EnableMouse(true)
    grip:RegisterForDrag("LeftButton")
    grip:SetScript("OnMouseDown", startOptionsResize)
    grip:SetScript("OnMouseUp", stopOptionsResize)
    grip:SetScript("OnDragStart", startOptionsResize)
    grip:SetScript("OnDragStop", stopOptionsResize)
    grip:SetScript("OnHide", stopOptionsResize)

    local texture = grip:CreateTexture(nil, "OVERLAY")
    texture:SetTexture([[Interface\ChatFrame\UI-ChatIM-SizeGrabber-Up]])
    texture:SetAllPoints()
    texture:SetAlpha(0.45)
    E:RegisterAccentTexture(texture)
    grip:SetScript("OnEnter", function()
        texture:SetAlpha(0.85)
    end)
    grip:SetScript("OnLeave", function()
        texture:SetAlpha(0.45)
    end)

    frame._resizeGrip = grip
    frame._resizeGripTexture = texture
end

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
        labelTop = option.labelTop,
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
            -- a toggle can change other widgets; refresh the panel unless the option opts out.
            if option.refresh ~= false then
                ART_UI:QueueRefresh("current")
            end
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
        if option.refresh ~= false then
            ART_UI:QueueRefresh("current")
        end
    end

    local buttonWidth
    if option.width ~= "compact" then
        buttonWidth = 1
    end

    local tpl = T:Button(parent, {
        text = evalName(option, info),
        width = buttonWidth,
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
        buttonHeight = option.buttonHeight,
        height = option.dropdownHeight,
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
            if option.refresh ~= false then
                ART_UI:QueueRefresh("current")
            end
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
            if option.refresh ~= false then
                ART_UI:QueueRefresh("current")
            end
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
            -- debounce panel-level refresh so color commits do not rebuild immediately
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
                it.widget.frame:Show()
                visible[#visible + 1] = it
            else
                it.widget.frame:Hide()
            end
        end
        items = visible
        if #items == 0 then
            myState.endY = y
            return
        end

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
        addRefresh(refreshList, runLayout, "layout")
        addRefresh(rootRefreshList, runLayout, "layout")
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
            local opt = widget._option
            local info = widget._info

            if opt and info and evalHidden(opt, info) then
                fr:Hide()
                myState.endY = y
                return
            end

            fr:Show()
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
        addRefresh(refreshList, place, "layout")
        addRefresh(rootRefreshList, place, "layout")
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
                    addRefresh(refreshList, hdr.Refresh)
                    addRefresh(rootRefreshList, hdr.Refresh)
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
                local lastHidden
                local lastHeight = frame:GetHeight()
                local wrap = function()
                    local hid = evalHidden(option, info)
                    local layoutChanged = lastHidden ~= nil and hid ~= lastHidden
                    lastHidden = hid
                    if hid then
                        frame:Hide()
                    else
                        frame:Show()
                    end
                    if not hid and refresh then
                        refresh()
                    end
                    local height = frame:GetHeight()
                    if not hid and lastHeight and height and math.abs(height - lastHeight) > 0.5 then
                        layoutChanged = true
                    end
                    lastHeight = height
                    return layoutChanged
                end
                addRefresh(refreshList, wrap)
                addRefresh(rootRefreshList, wrap)
                wrap()

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
local DEFAULT_CONTENT_INNER_W = WIN_W - PAD * 4 - SIDEBAR_W - INNER_PAD - SCROLLBAR_GUTTER
local MIN_CONTENT_INNER_W = MIN_WIN_W - PAD * 4 - SIDEBAR_W - INNER_PAD - SCROLLBAR_GUTTER

local function createScrollHost(parentFrame)
    local sh = T:ScrollFrame(parentFrame, {
        chrome = false,
        mouseWheelStep = 40,
        autoWidth = true,
        minContentWidth = MIN_CONTENT_INNER_W,
        scrollbarWidth = SCROLLBAR_WIDTH,
        scrollbarGap = SCROLLBAR_GAP
    })
    sh.frame:SetAllPoints(parentFrame)

    sh.scroll:HookScript("OnSizeChanged", sh.ApplyAutoWidth)
    ART_UI:AddResizeFlusher(sh.ApplyAutoWidth, sh.content)

    return sh.content, DEFAULT_CONTENT_INNER_W, sh.scroll
end

-- Panels

local function buildCategoryPanel(parent, key, group, rootRefreshers)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()
    panel:Hide()
    ART_UI.refreshDirty[panel] = true

    local hasTabs = (group.childGroups == "tab") and group.args

    if not hasTabs then
        local contentHolder = CreateFrame("Frame", nil, panel)
        contentHolder:SetPoint("TOPLEFT", PAD, -PAD)
        contentHolder:SetPoint("BOTTOMRIGHT", -PAD, PAD)

        local inner, innerW = createScrollHost(contentHolder)
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
    local headerHost

    if hasHeader then
        headerHost = CreateFrame("Frame", nil, panel)
        headerHost:SetPoint("TOPLEFT", PAD, -PAD)
        headerHost:SetPoint("TOPRIGHT", -PAD, -PAD)

        local innerW = DEFAULT_CONTENT_INNER_W
        ART_UI:PushFlusherOwner(headerHost)
        local headerUsedY, headerFinalState = buildArgsInto(headerHost, headerArgs, {key}, group.handler, 0, innerW,
            panelRefreshers, rootRefreshers, group.colGap)
        headerHost:SetHeight(math.max(1, headerUsedY))
        ART_UI:AddResizeFlusher(function()
            headerHost:SetHeight(math.max(1, headerFinalState.endY))
        end)
        ART_UI:PopFlusherOwner()
    end

    local contentHolder = CreateFrame("Frame", nil, panel)

    local tabDefs = {}
    local tabEntries = {}
    panel._tabs = {}

    for _, entry in ipairs(sortedArgs(group.args)) do
        local tabKey, tabOpt = entry.key, entry.opt
        if tabOpt.type == "group" then
            local tabContent = CreateFrame("Frame", nil, contentHolder)
            tabContent:SetAllPoints()
            tabContent:Hide()
            ART_UI.refreshDirty[tabContent] = true

            local inner, innerW = createScrollHost(tabContent)

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
        onTabChange = function(key, _, oldKey)
            local oldContent = oldKey and tabEntries[oldKey]
            if oldContent then
                oldContent:Hide()
            end

            local content = tabEntries[key]
            if content then
                content:Show()
            end
            panel._activeTabContent = content
            ART_UI:CatchUp()
            ART_UI:RefreshPanel(panel, false)
        end
    })
    if headerHost then
        tabBar.frame:SetPoint("TOPLEFT", headerHost, "BOTTOMLEFT", 0, -HEADER_GAP)
        tabBar.frame:SetPoint("TOPRIGHT", headerHost, "BOTTOMRIGHT", 0, -HEADER_GAP)
    else
        tabBar.frame:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -PAD)
        tabBar.frame:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -PAD)
    end

    contentHolder:SetPoint("TOPLEFT", tabBar.frame, "BOTTOMLEFT", 0, -6)
    contentHolder:SetPoint("TOPRIGHT", tabBar.frame, "BOTTOMRIGHT", 0, -6)
    contentHolder:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -PAD, PAD)

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
            return tabBar.ActivateTab(key)
        end
        return false
    end

    panel.ReapplyTabHighlight = tabBar.ReapplyHighlight
    addRefresh(rootRefreshers, tabBar.ReapplyHighlight)
    addRefresh(panelRefreshers, tabBar.ReapplyHighlight)

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
    local targetW, targetH = self:_updateResizeBounds(key)
    local curW, curH = self.mainFrame:GetWidth(), self.mainFrame:GetHeight()
    local newW = math.max(curW or 0, targetW or WIN_W)
    local newH = math.max(curH or 0, targetH or WIN_H)
    if math.abs((curW or 0) - newW) > 0.5 or math.abs((curH or 0) - newH) > 0.5 then
        self.mainFrame:SetSize(newW, newH)
        saveWindowSize(self.mainFrame)
        self:_runResizeFlushers()
    end
end

-- addon frame

local function buildMainFrame()
    local f = CreateFrame("Frame", "ARTOptionsFrame", UIParent)
    f:Hide()
    local minW, minH, maxW, maxH = ART_UI:_getWindowBounds()
    local savedW, savedH = getSavedWindowSize()
    f:SetSize(clamp(savedW or WIN_W, minW, maxW), clamp(savedH or WIN_H, minH, maxH))
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    tinsert(UISpecialFrames, "ARTOptionsFrame")

    applyLiteTemplate(f, "Default")
    f:HookScript("OnHide", function()
        T:HideDropdownPullout()
        GameTooltip:Hide()
        f:StopMovingOrSizing()
        if f._resizeGrip then
            f._resizeGrip:SetScript("OnUpdate", nil)
        end
        local resizeState = f._artResizeState
        f._artResizing = nil
        f._artResizeState = nil
        if f.SetClampedToScreen and resizeState and resizeState.clamped ~= nil then
            f:SetClampedToScreen(resizeState.clamped)
        end
        restoreResizeBackdrops(f)
        E:SendMessage("ART_OPTIONS_HIDDEN")
    end)

    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    local logo = f:CreateTexture(nil, "ARTWORK")
    logo:SetTexture([[Interface\AddOns\AdvanceRaidTools\Media\Textures\logo.tga]])
    logo:SetSize(LOGO_SIZE, LOGO_SIZE)
    logo:SetPoint("TOP", f, "TOPLEFT", PAD + SIDEBAR_W / 2, -PAD)

    -- title panel
    local title = CreateFrame("Frame", nil, f)
    applyLiteTemplate(title, "Transparent")
    title:SetHeight(TITLE_H)
    title:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + SIDEBAR_W + INNER_PAD, -PAD)
    title:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -PAD)

    -- Sidebar panel
    local sidebar = CreateFrame("Frame", nil, f)
    applyLiteTemplate(sidebar, "Transparent")
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

    local function titleButton(label)
        local btn = CreateFrame("Button", nil, title, "BackdropTemplate")
        setTemplate(btn, "Default")
        btn:SetSize(20, 20)
        local text = newFont(btn, "OVERLAY", 2)
        text:SetText(label)
        text:SetPoint("CENTER", 1, 0)
        text:SetTextColor(unpack(c_text()))
        btn:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(unpack(c_accent()))
        end)
        btn:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(unpack(c_border()))
        end)
        return btn, text
    end

    -- top buttons
    local close = titleButton("X")
    close:SetPoint("RIGHT", -4, 0)
    close:SetScript("OnClick", function()
        f:Hide()
    end)

    local reset = titleButton("R")
    reset:SetPoint("RIGHT", close, "LEFT", -4, 0)
    reset:SetScript("OnClick", function()
        resetWindowSize(f)
    end)
    titleText:SetPoint("RIGHT", reset, "LEFT", -8, 0)

    local content = CreateFrame("Frame", nil, f)
    applyLiteTemplate(content, "Transparent")
    content:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -INNER_PAD)
    content:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT", 0, -INNER_PAD)
    content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, PAD)

    f._title = title
    f._titleText = titleText
    f._navHost = navHost
    f._content = content
    f._sidebar = sidebar
    f._resetSize = reset
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
    addOptionsResizeGrip(f)

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
            local activated
            if not anyActive and panel.ActivateTab then
                activated = panel.ActivateTab(panel._tabs[1].content)
            end
            if not activated then
                self:RefreshPanel(panel, false)
            end
        else
            self:RefreshPanel(panel, false)
        end

        self:CatchUp()
    end
end

function ART_UI:RefreshPanel(panel, force)
    if not panel then
        return false
    end

    local refreshed = false
    local headerList = ART_UI.panelRefreshers[panel]
    if headerList and (force or self.refreshDirty[panel]) then
        runRefreshList(headerList, force)
        self.refreshDirty[panel] = nil
        refreshed = true
    end

    if panel._tabs and #panel._tabs > 0 then
        local content = activeTabContent(panel)
        if content then
            local list = ART_UI.panelRefreshers[content]
            if list and (force or self.refreshDirty[content]) then
                runRefreshList(list, force)
                self.refreshDirty[content] = nil
                refreshed = true
            end
        end
    end
    return refreshed
end

function ART_UI:RefreshCurrent(force)
    if force == nil then
        force = true
    end
    local panel = self.panels[self.currentKey]
    if panel then
        self:RefreshPanel(panel, force)
    end
    for _, btn in pairs(self.sidebarBtns) do
        if btn.Refresh then
            btn.Refresh()
        end
    end
end

function ART_UI:RefreshAll(force)
    if force == nil then
        force = true
    end
    local panel = self.panels[self.currentKey]
    if panel then
        self:RefreshPanel(panel, force)
    end
    for _, btn in pairs(self.sidebarBtns) do
        if btn.Refresh then
            btn.Refresh()
        end
    end
end

function ART_UI:QueueRefresh(scope)
    scope = scope or "current"
    self:MarkRefreshDirty(scope)
    if self._queuedScope == "all" then
    elseif scope == "all" then
        self._queuedScope = "all"
    elseif self._queuedScope == nil then
        self._queuedScope = "current"
    end

    if self:IsResizing() then
        return
    end

    if self._refreshPending then
        return
    end
    self._refreshPending = true
    C_Timer.After(0, function()
        self._refreshPending = false
        local s = self._queuedScope
        if self:IsResizing() then
            return
        end
        self._queuedScope = nil
        if not self.mainFrame or not self.mainFrame:IsShown() then
            return
        end
        if s == "all" then
            self:RefreshAll(false)
        else
            self:RefreshCurrent(false)
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
    self.refreshDirty = {}
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
