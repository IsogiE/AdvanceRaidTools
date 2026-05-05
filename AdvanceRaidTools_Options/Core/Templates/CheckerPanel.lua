local E = unpack(ART)
local T = E.Templates
local P = E.TemplatePrivate

local loc = P.loc

-- =============================================================================
-- Template: CheckerPanel
-- -----------------------------------------------------------------------------
-- opts = {
--     mod            = function() return checkerModule end,     -- required, lazy getter
--     ui             = { contextOverride, sortMode },           -- required; caller owns
--     orderBase      = 20,                                      -- runner widgets use order orderBase..orderBase+9
--
--     contexts       = { auto="...", RAID="...", PARTY="...", GUILD="..." },
--     contextOrder   = { "auto", "RAID", "PARTY", "GUILD" },
--
--     sortModes      = nil | { status="...", name="...", ... },
--     sortOrder      = { "status", "name", ... },
--
--     timeoutMin     = 3,
--     timeoutMax     = 30,
--
--     onStart        = function(mod, contextOverride) -> ok, err   (required)
--     startLabel     = function(mod) -> "Start"/"Stop"  (optional, default "Start Check"/"Stop Check")
--     reportStartError = function(mod, err)             (optional, default mod:ReportCheckError)
--
--     statusText     = function(mod) -> text            (required)
--
--     -- choose one of:
--     resultsText    = function(mod) -> text            -- uses ScrollingText
--     resultsRows    = { items = fn(mod), createRow = fn(parent), updateRow = fn(row, item) },
--     resultsHeight  = 320,
--
--     disabled       = nil | function() -> bool,        -- greys out the runner widgets
-- }
-- =============================================================================

local DEFAULT_CONTEXTS = {
    auto = "AutoDetect",
    RAID = "Raid",
    PARTY = "Party",
    GUILD = "Guild"
}
local DEFAULT_CONTEXT_ORDER = {"auto", "RAID", "PARTY", "GUILD"}

function T:CheckerPanel(opts)
    assert(type(opts) == "table", "CheckerPanel: opts required")
    assert(type(opts.mod) == "function", "CheckerPanel: opts.mod (getter) required")
    assert(type(opts.ui) == "table", "CheckerPanel: opts.ui required")
    assert(type(opts.onStart) == "function", "CheckerPanel: opts.onStart required")
    assert(type(opts.statusText) == "function", "CheckerPanel: opts.statusText required")

    local L = ART[2]
    local mod = opts.mod
    local ui = opts.ui
    local base = opts.orderBase or 20

    local contexts = opts.contexts or DEFAULT_CONTEXTS
    local contextOrder = opts.contextOrder or DEFAULT_CONTEXT_ORDER

    local resolvedContexts = {}
    for k, v in pairs(contexts) do
        resolvedContexts[k] = loc(v)
    end

    local disabled = opts.disabled or function()
        local m = opts.mod()
        return not (m and m:IsEnabled())
    end

    local args = {}

    -- Target dropdown
    local hasSort = type(opts.sortModes) == "table"
    local targetWidth = hasSort and "1/3" or "1/2"

    args.contextSel = {
        order = base,
        width = targetWidth,
        build = function(parent)
            return T:Dropdown(parent, {
                label = L["Target"],
                values = resolvedContexts,
                sorting = contextOrder,
                get = function()
                    return ui.contextOverride or "auto"
                end,
                onChange = function(v)
                    ui.contextOverride = v
                end,
                disabled = disabled
            })
        end
    }

    if hasSort then
        local resolvedSortModes = {}
        for k, v in pairs(opts.sortModes) do
            resolvedSortModes[k] = loc(v)
        end
        args.sortSel = {
            order = base + 1,
            width = "1/3",
            build = function(parent)
                return T:Dropdown(parent, {
                    label = L["SortBy"],
                    values = resolvedSortModes,
                    sorting = opts.sortOrder,
                    get = function()
                        return ui.sortMode
                    end,
                    onChange = function(v)
                        ui.sortMode = v
                        if E.OptionsUI and E.OptionsUI.QueueRefresh then
                            E.OptionsUI:QueueRefresh("current")
                        end
                    end,
                    disabled = disabled
                })
            end
        }
    end

    args.timeout = {
        order = base + 2,
        width = hasSort and "1/3" or "1/2",
        build = function(parent)
            return T:Slider(parent, {
                label = L["Timeout"],
                tooltip = {
                    title = L["Timeout"],
                    desc = L["TimeoutDesc"]
                },
                min = opts.timeoutMin or 3,
                max = opts.timeoutMax or 30,
                step = 1,
                get = function()
                    local m = mod()
                    return m and m.db and m.db.timeoutSeconds or 5
                end,
                onChange = function(v)
                    local m = mod()
                    if m and m.db then
                        m.db.timeoutSeconds = v
                    end
                end,
                disabled = disabled
            })
        end
    }

    args.startBtn = {
        order = base + 3,
        width = "2/3",
        build = function(parent)
            return T:LabelAlignedButton(parent, {
                text = function()
                    local m = mod()
                    if opts.startLabel then
                        return opts.startLabel(m)
                    end
                    if m and m:IsInProgress() then
                        return L["StopCheck"]
                    end
                    return L["StartCheck"]
                end,
                emphasize = true,
                onClick = function()
                    local m = mod()
                    if not m then
                        return
                    end
                    if m:IsInProgress() then
                        m:CancelCheck()
                        return
                    end
                    local ok, err = opts.onStart(m, ui.contextOverride or "auto")
                    if not ok and err then
                        if opts.reportStartError then
                            opts.reportStartError(m, err)
                        elseif m.ReportCheckError then
                            m:ReportCheckError(err)
                        end
                    end
                end,
                disabled = disabled
            })
        end
    }

    args.exportBtn = {
        order = base + 4,
        width = "1/3",
        build = function(parent)
            return T:LabelAlignedButton(parent, {
                text = L["Export"],
                onClick = function()
                    local m = mod()
                    if not m then
                        return
                    end
                    local txt
                    if opts.exportResults then
                        txt = opts.exportResults(m)
                    elseif m.ExportResults then
                        txt = m:ExportResults()
                    end
                    if not txt or txt == "" then
                        E:Printf(L["NoResultsToExport"])
                        return
                    end
                    T:ShowText({
                        title = L["ExportResults"],
                        viewer = txt
                    })
                end,
                disabled = disabled
            })
        end
    }

    args.statusLine = {
        order = base + 5,
        width = "full",
        build = function(parent)
            return T:StatusLine(parent, {
                text = function()
                    local m = mod()
                    return m and opts.statusText(m) or ""
                end
            })
        end
    }

    if opts.resultsRows then
        local rows = opts.resultsRows
        args.results = {
            order = base + 6,
            width = "full",
            build = function(parent)
                return T:ScrollingPanel(parent, {
                    height = opts.resultsHeight or 320,
                    rowHeight = rows.rowHeight or 20,
                    template = "Transparent",
                    forwardWheelToOuter = true,
                    createRow = function(p)
                        local m = mod()
                        return m and rows.createRow(m, p)
                    end,
                    updateRow = function(row, item)
                        local m = mod()
                        if m then
                            rows.updateRow(m, row, item)
                        end
                    end,
                    items = function()
                        local m = mod()
                        return m and rows.items(m) or {}
                    end
                })
            end
        }
    elseif opts.resultsText then
        args.results = {
            order = base + 6,
            width = "full",
            build = function(parent)
                return T:ScrollingText(parent, {
                    height = opts.resultsHeight or 320,
                    template = "Transparent",
                    forwardWheelToOuter = true,
                    spacing = 2,
                    text = function()
                        local m = mod()
                        return m and opts.resultsText(m) or ""
                    end
                })
            end
        }
    end

    return args
end
