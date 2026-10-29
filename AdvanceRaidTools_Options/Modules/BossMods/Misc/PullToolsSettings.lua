local E, L = unpack(ART)
local T = E.Templates

local function build(parent, mod, isDisabled)
    local tracker = T:MakeTracker()
    local y, width = 0, parent:GetWidth()
    local function full(widget)
        tracker.track(widget)
        y = y + T:PlaceFull(parent, widget, y, width) + 6
    end
    full(T:Header(parent, {text = L["BossMods_PullTools"]}))
    full(T:Description(parent, {text = L["BossMods_PullToolsDesc"]}))
    for _, setting in ipairs({
        {key = "recoverCountdown", label = "BossMods_PullRecovery", desc = "BossMods_PullRecoveryDesc"},
        {key = "benchGuard", label = "BossMods_PullBenchGuard", desc = "BossMods_PullBenchGuardDesc"}
    }) do
        full(T:Checkbox(parent, {
            text = L[setting.label], tooltip = L[setting.desc],
            get = function() return mod.db[setting.key] == true end,
            onChange = function(_, value) mod.db[setting.key] = value; mod:Refresh() end,
            disabled = isDisabled
        }))
    end
    parent:SetHeight(y)
    return {height = y, Refresh = tracker.refresh, Release = tracker.release}
end

E:GetModule("BossMods"):RegisterBossSettingsBuilder("PullTools", build)
