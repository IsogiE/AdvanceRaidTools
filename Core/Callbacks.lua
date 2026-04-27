local E = unpack(ART)

E.Libs = {
    AceAddon = LibStub("AceAddon-3.0"),
    AceEvent = LibStub("AceEvent-3.0"),
    AceDB = LibStub("AceDB-3.0"),
    AceConfig = LibStub("AceConfig-3.0"),
    AceConfigRegistry = LibStub("AceConfigRegistry-3.0"),
    AceDBOptions = LibStub("AceDBOptions-3.0"),
    LibSerialize = LibStub("LibSerialize"),
    LibDeflate = LibStub("LibDeflate"),
    LSM = LibStub("LibSharedMedia-3.0", true),
    LDB = LibStub("LibDataBroker-1.1", true),
    LDBIcon = LibStub("LibDBIcon-1.0", true),
    LibTranslit = LibStub("LibTranslit-1.0", true),
    LibCustomGlow = LibStub("LibCustomGlow-1.0", true),
    LibGetFrame = LibStub("LibGetFrame-1.0", true)
}

E._deferredHandles = E._deferredHandles or {}

local function queueCall(pending, kind, ...)
    pending[#pending + 1] = {kind, select("#", ...), ...}
end

local function makeDeferredHandle()
    local handle = E.Libs.AceEvent:Embed({})
    local pending = {}
    handle._artPending = pending

    local realRegisterEvent = handle.RegisterEvent
    local realRegisterMessage = handle.RegisterMessage

    handle.RegisterEvent = function(self, ...)
        if E._prebuildActive then
            queueCall(pending, "event", ...)
        else
            realRegisterEvent(self, ...)
        end
    end
    handle.RegisterMessage = function(self, ...)
        if E._prebuildActive then
            queueCall(pending, "message", ...)
        else
            realRegisterMessage(self, ...)
        end
    end

    E._deferredHandles[#E._deferredHandles + 1] = handle
    return handle
end

function E:NewCallbackHandle()
    if self._prebuildActive then
        return makeDeferredHandle()
    end
    return self.Libs.AceEvent:Embed({})
end

function E:ArmOptionsDeferredHandles()
    if self._handlesArmed then
        return
    end
    self._handlesArmed = true
    local list = self._deferredHandles
    for i = 1, #list do
        local handle = list[i]
        local pending = handle._artPending
        if pending then
            for j = 1, #pending do
                local call = pending[j]
                local kind, n = call[1], call[2]
                if kind == "event" then
                    handle:RegisterEvent(unpack(call, 3, 2 + n))
                else
                    handle:RegisterMessage(unpack(call, 3, 2 + n))
                end
            end
            handle._artPending = nil
        end
    end
    wipe(list)
end
