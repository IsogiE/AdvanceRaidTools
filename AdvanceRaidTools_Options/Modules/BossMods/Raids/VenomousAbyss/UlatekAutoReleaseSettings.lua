local E, L = unpack(ART)
local T = E.Templates

local function build(rightPanel)
    local width = rightPanel:GetWidth() or 0
    if width <= 0 then return {} end
    local tracker = T:MakeTracker()
    local track = tracker.track
    local y = T:PlaceFull(rightPanel,
        track(T:Header(rightPanel, {text = L["BossMods_UlatekAutoRelease"]})), 0, width) + 6
    y = y + T:PlaceFull(rightPanel,
        track(T:Description(rightPanel, {text = L["BossMods_UlatekAutoReleaseDesc"]})), y, width) + 16
    rightPanel:SetHeight(y)
    return {height = y, Refresh = tracker.refresh, Release = tracker.release}
end

E:GetModule("BossMods"):RegisterBossSettingsBuilder("UlatekAutoRelease", build)
