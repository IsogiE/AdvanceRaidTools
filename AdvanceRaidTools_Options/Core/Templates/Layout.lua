local E, L = unpack(ART)
local T = E.Templates
local P = E.TemplatePrivate

local H_EDITBOX = P.H_EDITBOX
local c_textDim = P.c_textDim
local c_text = P.c_text
local c_border = P.c_border
local c_accent = P.c_accent
local fontPath = P.fontPath
local fontSize = P.fontSize
local fontOutline = P.fontOutline
local newFont = P.newFont
local safeCall = P.safeCall
local evalMaybeFn = P.evalMaybeFn
local setTemplate = P.setTemplate

-- =============================================================================
-- T:MakeTracker()
--   track(widget)  -- stashes the widget and returns it (so you can chain
--                     `local foo = track(T:Slider(...))`)
--   refresh()      -- calls :Refresh() on every tracked widget so their
--                     get(), disabled(), hidden() callbacks re-evaluate.
--                     Call from onChange of a widget whose value gates
--                     other widgets' disabled state.
--   release()      -- Hide + unparent every tracked widget and wipes the
--                     bookkeeping. Call from the builder's Release().
-- =============================================================================
function T:MakeTracker()
    local widgets = {}
    return {
        track = function(w)
            widgets[#widgets + 1] = w
            return w
        end,
        refresh = function()
            for _, w in ipairs(widgets) do
                if w.Refresh then
                    local ok, err = pcall(w.Refresh)
                    if not ok then
                        E:ChannelWarn("Options", "Tracker refresh failed: %s", tostring(err))
                    end
                end
            end
        end,
        release = function()
            for _, w in ipairs(widgets) do
                if w.frame then
                    w.frame:Hide()
                    w.frame:SetParent(nil)
                    w.frame:ClearAllPoints()
                end
            end
            wipe(widgets)
        end
    }
end

-- =============================================================================
-- T:PlaceRow(parent, widgets, yOffset, widthPx, opts)
-- T:PlaceFull(parent, widget, yOffset, widthPx)
-- =============================================================================
local DEFAULT_ROW_PAD_X = 10
local DEFAULT_ROW_GAP = 8

function T:PlaceRow(parent, widgets, yOffset, widthPx, opts)
    opts = opts or {}
    local n = #widgets
    if n == 0 then
        return 0
    end
    local padX = opts.padX or DEFAULT_ROW_PAD_X
    local gap = opts.gap or DEFAULT_ROW_GAP
    local usable = widthPx - 2 * padX - (n - 1) * gap
    if usable < 0 then
        usable = 0
    end

    local weights = opts.widths
    local totalWeight = 0
    if weights then
        for i = 1, n do
            totalWeight = totalWeight + (weights[i] or 1)
        end
    end

    local x = padX
    local rowH = 0
    for i, w in ipairs(widgets) do
        local share
        if weights and totalWeight > 0 then
            share = usable * ((weights[i] or 1) / totalWeight)
        else
            share = usable / n
        end
        local f = w.frame
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -yOffset)
        f:SetWidth(share)
        if w._relayout then
            w._relayout()
        end
        local h = f:GetHeight() or 22
        if h > rowH then
            rowH = h
        end
        x = x + share + gap
    end
    return rowH
end

function T:PlaceFull(parent, widget, yOffset, widthPx, opts)
    opts = opts or {}
    local padX = opts.padX or DEFAULT_ROW_PAD_X
    local f = widget.frame
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", padX, -yOffset)
    f:SetWidth(math.max(0, widthPx - 2 * padX))
    if widget._relayout then
        widget._relayout()
    end
    return f:GetHeight() or 22
end

-- =============================================================================
-- T:NumericStepper(parent, opts)
-- Compact integer input: [label] / [- editbox +]
-- opts:
--   label     label shown above the input
--   get       function() -> number (current value)
--   set       function(int) commits a new value
--   step      nudge amount per button click (default 1)
--   disabled  bool | function
-- =============================================================================
local STEPPER_LABEL_H = 14
local STEPPER_INPUT_H = H_EDITBOX
local STEPPER_BTN_W = 20

function T:NumericStepper(parent, opts)
    opts = opts or {}
    assert(type(opts.get) == "function", "NumericStepper: get required")
    assert(type(opts.set) == "function", "NumericStepper: set required")

    local step = opts.step or 1

    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(STEPPER_LABEL_H + 2 + STEPPER_INPUT_H)

    local labelFS = newFont(container, 0)
    labelFS:SetTextColor(unpack(c_text()))
    labelFS:SetPoint("TOPLEFT", 0, 0)
    labelFS:SetPoint("TOPRIGHT", 0, 0)
    labelFS:SetJustifyH("LEFT")
    labelFS:SetWordWrap(false)
    labelFS:SetText(opts.label or "")

    local function makeNudgeButton(glyph)
        local btn = CreateFrame("Button", nil, container, "BackdropTemplate")
        setTemplate(btn, "Default")
        btn:SetSize(STEPPER_BTN_W, STEPPER_INPUT_H)
        local fs = newFont(btn, 0)
        fs:SetText(glyph)
        fs:SetPoint("CENTER", 0, 0)
        btn._fs = fs
        return btn
    end

    local minusBtn = makeNudgeButton("-")
    minusBtn:SetPoint("TOPLEFT", 0, -(STEPPER_LABEL_H + 2))

    local plusBtn = makeNudgeButton("+")
    plusBtn:SetPoint("TOPRIGHT", 0, -(STEPPER_LABEL_H + 2))

    local box = CreateFrame("Frame", nil, container, "BackdropTemplate")
    setTemplate(box, "Default")
    box:SetPoint("LEFT", minusBtn, "RIGHT", 2, 0)
    box:SetPoint("RIGHT", plusBtn, "LEFT", -2, 0)
    box:SetHeight(STEPPER_INPUT_H)

    local eb = CreateFrame("EditBox", nil, box)
    eb:SetPoint("TOPLEFT", 2, -1)
    eb:SetPoint("BOTTOMRIGHT", -2, 1)
    eb:SetAutoFocus(false)
    eb:SetFont(fontPath(), fontSize(), fontOutline())
    eb:SetTextInsets(4, 4, 0, 0)
    eb:SetTextColor(1, 1, 1)
    eb:SetJustifyH("CENTER")
    eb:SetMaxLetters(8)
    E.skinnedFontStrings[eb] = 0

    local state = {
        disabled = false
    }

    local function readDisplay()
        local v = opts.get()
        return math.floor((v or 0) + 0.5)
    end

    local function syncText()
        if not eb:HasFocus() then
            eb:SetText(tostring(readDisplay()))
            eb:SetCursorPosition(0)
        end
    end
    syncText()

    local function commitFromText()
        local txt = eb:GetText() or ""
        local n = tonumber(txt)
        if n then
            opts.set(math.floor(n))
        end
        syncText()
    end

    eb:SetScript("OnEditFocusGained", function(self_)
        self_:HighlightText()
    end)
    eb:SetScript("OnEnterPressed", function(self_)
        commitFromText()
        self_:ClearFocus()
    end)
    eb:SetScript("OnEscapePressed", function(self_)
        self_:ClearFocus()
        syncText()
    end)
    eb:SetScript("OnEditFocusLost", function()
        commitFromText()
    end)

    local function nudge(delta)
        if state.disabled then
            return
        end
        opts.set(readDisplay() + delta)
        syncText()
    end

    local function hookHover(btn)
        btn:SetScript("OnEnter", function(self_)
            if not state.disabled then
                self_:SetBackdropBorderColor(unpack(c_accent()))
            end
        end)
        btn:SetScript("OnLeave", function(self_)
            if not state.disabled then
                self_:SetBackdropBorderColor(unpack(c_border()))
            end
        end)
    end
    hookHover(minusBtn)
    hookHover(plusBtn)

    minusBtn:SetScript("OnClick", function()
        nudge(-step)
    end)
    plusBtn:SetScript("OnClick", function()
        nudge(step)
    end)

    local function SetDisabled(d)
        state.disabled = d and true or false
        eb:EnableMouse(not state.disabled)
        eb:SetEnabled(not state.disabled)
        minusBtn:EnableMouse(not state.disabled)
        plusBtn:EnableMouse(not state.disabled)
        local txt = state.disabled and c_textDim() or c_text()
        local bdr = state.disabled and c_textDim() or c_border()
        labelFS:SetTextColor(unpack(txt))
        minusBtn._fs:SetTextColor(unpack(txt))
        plusBtn._fs:SetTextColor(unpack(txt))
        eb:SetTextColor(state.disabled and c_textDim()[1] or 1, state.disabled and c_textDim()[2] or 1,
            state.disabled and c_textDim()[3] or 1)
        minusBtn:SetBackdropBorderColor(unpack(bdr))
        plusBtn:SetBackdropBorderColor(unpack(bdr))
        box:SetBackdropBorderColor(unpack(bdr))
    end

    SetDisabled(evalMaybeFn(opts.disabled, container))

    return {
        frame = container,
        height = container:GetHeight(),
        editBox = eb,
        SetDisabled = SetDisabled,
        IsDisabled = function()
            return state.disabled
        end,
        Refresh = function()
            syncText()
            SetDisabled(evalMaybeFn(opts.disabled, container))
        end
    }
end

-- =============================================================================
-- T:PositionSection(parent, yOffset, widthPx, opts)
-- opts:
--   anchor              frame to reposition (optional — unlock disabled if nil)
--   label               shown on the MovableFrame ghost
--   headerText          overrides the default "Position" header
--   getPosition         function() -> { point, x, y }   (caller db)
--   setPosition         function({ point, x, y })       (caller db)
--   defaultPosition     { point, x, y } for the Reset button
--   onChanged           fires after setPosition; typically re-applies the
--                       anchor's SetPoint from db
--   onEditModeChanged   fires when the unlock toggles (bool)
--   isDisabled          function() -> bool
--   showOffsets         render compact X/Y sliders above the reset button
--   offsetMin/offsetMax slider bounds (default ±2000)
--
-- Returns (newY, handle). handle.Release() releases the MovableFrame, fires
-- onEditModeChanged(false), hides/unparents the section's own widgets.
-- =============================================================================
local POSITION_SECTION_HEADER_GAP = 10
local POSITION_SECTION_ROW_GAP = 6

-- =============================================================================
-- T:UnlockController(parent, yOffset, widthPx, opts)
-- opts:
--   tracker            outer tracker for refresh integration
--   isDisabled         function() -> bool. Grays out the toggle (module disabled).
--   label              shown on movable ghosts when no per-anchor label supplied
--   onEditModeChanged  function(bool) — fires when toggled
--
-- Returns (newY, controller). controller exposes:
--   :Attach(movable)       — register a MovableFrame handle to lock/unlock as a group
--   :IsUnlocked()
--   :SetUnlocked(bool)
--   :Refresh()             — reconciles state with isDisabled (auto-locks if disabled)
--   :Release()
-- =============================================================================
function T:UnlockController(parent, yOffset, widthPx, opts)
    opts = opts or {}

    local own = {}
    local outerTracker = opts.tracker
    local function trackOwn(w)
        own[#own + 1] = w
        if outerTracker and outerTracker.track then
            outerTracker.track(w)
        end
        return w
    end

    local isDisabled = opts.isDisabled or function()
        return false
    end

    local controller = {
        movables = {},
        unlocked = false
    }

    local unlockCheck

    function controller:Attach(movable)
        if not movable then
            return
        end
        self.movables[#self.movables + 1] = movable
        if self.unlocked then
            movable:SetUnlocked(true)
        end
    end

    function controller:IsUnlocked()
        return self.unlocked
    end

    function controller:SetUnlocked(v)
        v = v and true or false
        if v == self.unlocked then
            return
        end
        self.unlocked = v
        for _, m in ipairs(self.movables) do
            m:SetUnlocked(v)
        end
        if opts.onEditModeChanged then
            opts.onEditModeChanged(v)
        end
        if unlockCheck and unlockCheck.Refresh then
            unlockCheck.Refresh()
        end
    end

    function controller:Refresh()
        if isDisabled() and self.unlocked then
            self:SetUnlocked(false)
        end
    end

    function controller:Release()
        for _, m in ipairs(self.movables) do
            m:Release()
        end
        wipe(self.movables)
        if self.unlocked then
            self.unlocked = false
            if opts.onEditModeChanged then
                opts.onEditModeChanged(false)
            end
        end
        for _, w in ipairs(own) do
            if w.frame then
                w.frame:Hide()
                w.frame:SetParent(nil)
                w.frame:ClearAllPoints()
            end
        end
        wipe(own)
    end

    unlockCheck = trackOwn(T:Checkbox(parent, {
        text = L["BossMods_UnlockFrame"],
        labelTop = true,
        tooltip = {
            title = L["BossMods_UnlockFrame"],
            desc = L["DragToMove"] or ""
        },
        get = function()
            return controller.unlocked
        end,
        onChange = function(_, v)
            controller:SetUnlocked(v)
        end,
        disabled = isDisabled
    }))

    local origRefresh = unlockCheck.Refresh
    unlockCheck.Refresh = function()
        if isDisabled() and controller.unlocked then
            controller.unlocked = false
            for _, m in ipairs(controller.movables) do
                m:SetUnlocked(false)
            end
            if opts.onEditModeChanged then
                opts.onEditModeChanged(false)
            end
        end
        if origRefresh then
            origRefresh()
        end
    end

    local newY = yOffset + T:PlaceRow(parent, {unlockCheck}, yOffset, widthPx) + POSITION_SECTION_ROW_GAP

    return newY, controller
end

function T:PositionSection(parent, yOffset, widthPx, opts)
    opts = opts or {}
    assert(type(opts.getPosition) == "function", "PositionSection: getPosition required")
    assert(type(opts.setPosition) == "function", "PositionSection: setPosition required")

    local own = {}
    local outerTracker = opts.tracker
    local function trackOwn(w)
        own[#own + 1] = w
        if outerTracker and outerTracker.track then
            outerTracker.track(w)
        end
        return w
    end

    local isDisabled = opts.isDisabled or function()
        return false
    end

    local newY = yOffset

    local movable
    if opts.anchor then
        movable = T:MovableFrame(opts.anchor, {
            label = opts.label or "",
            getPosition = opts.getPosition,
            setPosition = opts.setPosition,
            onChanged = opts.onChanged
        })
    end

    if opts.showOffsets then
        local function readX()
            return math.floor((opts.getPosition().x or 0) + 0.5)
        end
        local function readY()
            return math.floor((opts.getPosition().y or 0) + 0.5)
        end
        local function writeX(v)
            local pos = opts.getPosition()
            opts.setPosition({
                point = pos.point or "CENTER",
                x = math.floor(v),
                y = pos.y or 0
            })
            if opts.onChanged then
                opts.onChanged()
            end
        end
        local function writeY(v)
            local pos = opts.getPosition()
            opts.setPosition({
                point = pos.point or "CENTER",
                x = pos.x or 0,
                y = math.floor(v)
            })
            if opts.onChanged then
                opts.onChanged()
            end
        end

        local posHeader = trackOwn(T:Header(parent, {
            text = L["Position"]
        }))
        newY = newY + T:PlaceFull(parent, posHeader, newY, widthPx) + POSITION_SECTION_HEADER_GAP

        local xStepper = trackOwn(T:NumericStepper(parent, {
            label = L["QoL_XOffset"],
            get = readX,
            set = writeX,
            disabled = isDisabled
        }))
        local yStepper = trackOwn(T:NumericStepper(parent, {
            label = L["QoL_YOffset"],
            get = readY,
            set = writeY,
            disabled = isDisabled
        }))
        newY = newY + T:PlaceRow(parent, {xStepper, yStepper}, newY, widthPx) + POSITION_SECTION_ROW_GAP
    end

    local resetBtn = trackOwn(T:LabelAlignedButton(parent, {
        text = (L["Reset"] .. " " .. L["Position"]) or "Reset Position",
        onClick = function()
            local def = opts.defaultPosition or {
                point = "CENTER",
                x = 0,
                y = 0
            }
            opts.setPosition({
                point = def.point or "CENTER",
                x = def.x or 0,
                y = def.y or 0
            })
            if opts.onChanged then
                opts.onChanged()
            end
        end,
        disabled = isDisabled
    }))

    if opts.unlockController then
        if movable then
            opts.unlockController:Attach(movable)
        end
        newY = newY + T:PlaceRow(parent, {resetBtn}, newY, widthPx) + POSITION_SECTION_ROW_GAP
    else
        local unlockCheck = trackOwn(T:Checkbox(parent, {
            text = L["BossMods_UnlockFrame"],
            labelTop = true,
            tooltip = {
                title = L["BossMods_UnlockFrame"],
                desc = L["DragToMove"] or ""
            },
            get = function()
                return movable and movable:IsUnlocked() or false
            end,
            onChange = function(_, v)
                if movable then
                    movable:SetUnlocked(v)
                end
                if opts.onEditModeChanged then
                    opts.onEditModeChanged(v)
                end
            end,
            disabled = function()
                return isDisabled() or not movable
            end
        }))

        local origUnlockRefresh = unlockCheck.Refresh
        unlockCheck.Refresh = function()
            if isDisabled() and movable and movable:IsUnlocked() then
                movable:SetUnlocked(false)
                if opts.onEditModeChanged then
                    opts.onEditModeChanged(false)
                end
            end
            if origUnlockRefresh then
                origUnlockRefresh()
            end
        end

        newY = newY + T:PlaceRow(parent, {unlockCheck, resetBtn}, newY, widthPx) + POSITION_SECTION_ROW_GAP
    end

    return newY, {
        movable = movable,
        widgets = own,
        Release = function()
            if movable and not opts.unlockController then
                movable:Release()
                movable = nil
            end
            if opts.onEditModeChanged and not opts.unlockController then
                opts.onEditModeChanged(false)
            end
            for _, w in ipairs(own) do
                if w.frame then
                    w.frame:Hide()
                    w.frame:SetParent(nil)
                    w.frame:ClearAllPoints()
                end
            end
            wipe(own)
        end
    }
end

-- =============================================================================
-- T:MovableFrame(anchor, opts)
--
-- opts:
--   getPosition  function() -> { point, x, y }
--   setPosition  function({ point, x, y })
--   onChanged    function()  -- fires after save so owner can reapply position
--
-- Returns {
--   frame       = anchor,
--   IsUnlocked  = function() -> bool,
--   SetUnlocked = function(bool),
--   Toggle      = function(),
--   Release     = function(),
-- }
-- =============================================================================
function T:MovableFrame(anchor, opts)
    assert(anchor and anchor.GetWidth, "MovableFrame: anchor must be a frame")
    assert(type(opts) == "table", "MovableFrame: opts required")
    assert(type(opts.getPosition) == "function", "MovableFrame: getPosition required")
    assert(type(opts.setPosition) == "function", "MovableFrame: setPosition required")

    local unlocked = false
    local armed = false
    local priorMovable, priorMouseEnabled
    local priorOnDragStart, priorOnDragStop

    local function onDragStart(self_)
        if not unlocked then
            return
        end
        self_:StartMoving()
    end

    local function onDragStop(self_)
        self_:StopMovingOrSizing()
        local parent = self_:GetParent() or UIParent
        local fcx, fcy = self_:GetCenter()
        local pcx, pcy = parent:GetCenter()
        local point, x, y = "CENTER", 0, 0
        if fcx and pcx then
            local fScale = self_:GetEffectiveScale()
            local pScale = parent:GetEffectiveScale()
            x = (fcx * fScale - pcx * pScale) / pScale
            y = (fcy * fScale - pcy * pScale) / pScale
        else
            local p, _, _, ox, oy = self_:GetPoint(1)
            point = p or "CENTER"
            x = ox or 0
            y = oy or 0
        end
        opts.setPosition({
            point = point,
            x = x,
            y = y
        })
        if opts.onChanged then
            safeCall("MovableFrame.onChanged", opts.onChanged)
        end
    end

    local function arm()
        if armed then
            return
        end
        priorMovable = anchor:IsMovable()
        priorMouseEnabled = anchor:IsMouseEnabled()
        priorOnDragStart = anchor:GetScript("OnDragStart")
        priorOnDragStop = anchor:GetScript("OnDragStop")
        anchor:SetMovable(true)
        anchor:EnableMouse(true)
        anchor:RegisterForDrag("LeftButton")
        anchor:SetScript("OnDragStart", onDragStart)
        anchor:SetScript("OnDragStop", onDragStop)
        armed = true
    end

    local function disarm()
        if not armed then
            return
        end
        anchor:SetScript("OnDragStart", priorOnDragStart)
        anchor:SetScript("OnDragStop", priorOnDragStop)
        anchor:RegisterForDrag()
        if priorMovable == false then
            anchor:SetMovable(false)
        end
        if priorMouseEnabled == false then
            anchor:EnableMouse(false)
        end
        priorOnDragStart, priorOnDragStop = nil, nil
        priorMovable, priorMouseEnabled = nil, nil
        armed = false
    end

    local handle = {
        frame = anchor
    }

    function handle:IsUnlocked()
        return unlocked
    end

    function handle:SetUnlocked(v)
        local target = v and true or false
        if target == unlocked then
            return
        end
        unlocked = target
        if unlocked then
            arm()
        else
            disarm()
        end
    end

    function handle:Toggle()
        handle:SetUnlocked(not unlocked)
    end

    function handle:Release()
        disarm()
        unlocked = false
    end

    return handle
end
