local E = unpack(ART)
local saved = _G.AdvanceRaidToolsDB
E.DiagnosticTimingEnabled = type(saved) == "table" and type(saved.global) == "table"
    and saved.global.diagnosticsTiming == true or false

local function finishCall(capture, row, started, ...)
    local elapsed = math.max(0, debugprofilestop() - started)
    row.calls, row.total = row.calls + 1, row.total + elapsed
    if elapsed > row.peak then row.peak = elapsed end
    if elapsed > 5 then
        if #capture.trace < 500 then
            capture.trace[#capture.trace + 1] = {offset = GetTime() - capture.clock,
                channel = row.name, message = ("%.3f ms"):format(elapsed)}
        else capture.traceTruncated = true end
    end
    return ...
end

function E:ProfileCallback(owner, label, callback)
    if not E.DiagnosticTimingEnabled then return callback end
    if type(callback) ~= "function" then return callback end
    local key = owner .. ":" .. label
    local previous, row
    return function(...)
        local capture = E.RaidDiagnosticsCapture
        if not capture then return callback(...) end
        if previous ~= capture.marker then
            previous = capture.marker
            row = capture.handlers[key]
            if not row then
                row = {name = key, calls = 0, total = 0, peak = 0}
                capture.handlers[key] = row
            end
        end
        local started = debugprofilestop()
        return finishCall(capture, row, started, callback(...))
    end
end

function E:InstrumentCallbacks(owner, label)
    if not E.DiagnosticTimingEnabled then return owner end
    for _, method in ipairs({"RegisterEvent", "RegisterMessage", "RegisterComm"}) do
        local register = owner[method]
        if type(register) == "function" then
            owner[method] = function(self, event, callback, ...)
                callback = callback or event
                local handler, name = callback, callback
                if type(callback) == "string" then
                    handler = function(...) return self[callback](self, ...) end
                else name = event end
                return register(self, event, E:ProfileCallback(label, method .. ":" .. name, handler), ...)
            end
        end
    end
    return owner
end

function E:DiagnosticBindings(owner)
    local create, timers, hook = CreateFrame, C_Timer, hooksecurefunc
    if not E.DiagnosticTimingEnabled then return create, timers, hook end
    local function createFrame(...)
        local frame = create(...)
        local setScript, hookScript = frame.SetScript, frame.HookScript
        frame.SetScript = function(self, event, callback)
            return setScript(self, event, E:ProfileCallback(owner, event, callback))
        end
        frame.HookScript = function(self, event, callback)
            return hookScript(self, event, E:ProfileCallback(owner, event, callback))
        end
        return frame
    end
    local timerAPI = setmetatable({}, {__index = timers})
    for _, method in ipairs({"After", "NewTimer", "NewTicker"}) do
        timerAPI[method] = function(delay, callback, ...)
            return timers[method](delay, E:ProfileCallback(owner, method, callback), ...)
        end
    end
    local function secureHook(target, method, callback)
        if type(target) == "string" then return hook(target, E:ProfileCallback(owner, target, method)) end
        return hook(target, method, E:ProfileCallback(owner, method, callback))
    end
    return createFrame, timerAPI, secureHook
end
