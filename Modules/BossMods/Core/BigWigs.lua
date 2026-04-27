local E = unpack(ART)

local BossMods = E:GetModule("BossMods")
BossMods.BigWigs = BossMods.BigWigs or {}
local BW = BossMods.BigWigs

local LISTENER_TOKEN = "AdvanceRaidTools_BossMods_BW"
local DEBUG_CHANNEL = "BossMods_BigWigs"

E:RegisterDebugChannel(DEBUG_CHANNEL)

local subscribers = {}
local subscriberOrder = {}
local nextToken = 1
local hooked = false

local function dispatch(_, _, key, text, time)
    for i = 1, #subscriberOrder do
        local sub = subscribers[subscriberOrder[i]]
        if sub and (not sub.spellKeys or sub.spellKeys[key]) then
            local ok, err = pcall(sub.onStartBar, key, text, time)
            if not ok then
                E:ChannelWarn(DEBUG_CHANNEL, "subscriber '%s' failed: %s", sub.owner, tostring(err))
            end
        end
    end
end

local function ensureHook()
    if hooked then
        return
    end
    if not BigWigsLoader then
        E:ChannelDebug(DEBUG_CHANNEL, "BigWigsLoader not present; subscription dormant")
        return
    end
    BigWigsLoader.RegisterMessage(LISTENER_TOKEN, "BigWigs_StartBar", dispatch)
    hooked = true
end

local function maybeUnhook()
    if #subscriberOrder > 0 then
        return
    end
    if not hooked then
        return
    end
    if BigWigsLoader then
        BigWigsLoader.UnregisterMessage(LISTENER_TOKEN, "BigWigs_StartBar")
    end
    hooked = false
end

function BW:Subscribe(opts)
    assert(type(opts) == "table", "BigWigs:Subscribe: opts required")
    assert(type(opts.owner) == "string" and opts.owner ~= "", "BigWigs:Subscribe: owner required")
    assert(type(opts.onStartBar) == "function", "BigWigs:Subscribe: onStartBar required")

    local token = nextToken
    nextToken = nextToken + 1

    local sub = {
        owner = opts.owner,
        onStartBar = opts.onStartBar,
        spellKeys = nil
    }
    if opts.spellKeys then
        sub.spellKeys = {}
        for _, k in ipairs(opts.spellKeys) do
            sub.spellKeys[k] = true
        end
    end

    subscribers[token] = sub
    subscriberOrder[#subscriberOrder + 1] = token
    ensureHook()

    return {
        Unsubscribe = function()
            if not subscribers[token] then
                return
            end
            subscribers[token] = nil
            for i = 1, #subscriberOrder do
                if subscriberOrder[i] == token then
                    table.remove(subscriberOrder, i)
                    break
                end
            end
            maybeUnhook()
        end
    }
end
