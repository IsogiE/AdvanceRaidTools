local E, L = unpack(ART)

E:RegisterModuleDefaults("Updater", {
    enabled = true
})

local Mod = E:NewModule("Updater", "AceEvent-3.0")

local COMM_PREFIX = "ARTUPD"
local OFFICER_RANK_THRESHOLD = 2
local POPUP_KEY = "ART_UPDATE_NOTICE"
local IMAGE_POOL = "Dreams"

local POPUP_BODY_PAD = 28
local POPUP_MIN_W = 180

local function getGuildRankIndexByName(name)
    if not IsInGuild() then
        return nil
    end
    if type(name) ~= "string" or name == "" then
        return nil
    end
    local bare = E:BareName(name)
    if bare == "" then
        return nil
    end
    local n = GetNumGuildMembers() or 0
    for i = 1, n do
        local memberName, _, rankIndex = GetGuildRosterInfo(i)
        if memberName and E:BareName(memberName) == bare then
            return rankIndex
        end
    end
    return nil
end

local function isOfficerRank(rankIndex)
    return type(rankIndex) == "number" and rankIndex <= OFFICER_RANK_THRESHOLD
end

local function senderIsGuildOfficer(sender)
    return isOfficerRank(getGuildRankIndexByName(sender))
end

local function iAmGuildOfficer()
    if not IsInGuild() then
        return false
    end
    return isOfficerRank(getGuildRankIndexByName(UnitName("player")))
end

function Mod:OnEnable()
    E:CallModule("Comms", "RegisterProtocol", COMM_PREFIX, function(_, message, _, sender)
        Mod:OnReceive(message, sender)
    end)
end

function Mod:OnDisable()
    E:CallModule("Comms", "UnregisterProtocol", COMM_PREFIX)
    if E.Templates and E.Templates.HidePopup then
        E.Templates:HidePopup(POPUP_KEY)
    end
end

function Mod:OnReceive(message, sender)
    if not senderIsGuildOfficer(sender) then
        return
    end
    local senderVersion = E:SafeString(message) or ""
    if E:CompareVersions(senderVersion, E.version or "") <= 0 then
        return
    end
    self:Show()
end

function Mod:Trigger()
    if not iAmGuildOfficer() then
        return false
    end
    local Comms = E:GetEnabledModule("Comms")
    if not Comms then
        return false
    end
    Comms:Broadcast(COMM_PREFIX, E.version or "", "GUILD")
    return true
end

function Mod:Show()
    if not E:EnsureOptions() then
        return
    end
    local T = E.Templates
    if not T or not T.Popup then
        return
    end

    local imgPath, imgW, imgH = E:PickRandomImage(IMAGE_POOL)

    local build
    local popupWidth
    if imgPath and imgW and imgH and imgW > 0 and imgH > 0 then
        popupWidth = imgW + POPUP_BODY_PAD
        build = function(_, body, ctx)
            local img = body:CreateTexture(nil, "ARTWORK")
            img:SetTexture(imgPath)
            img:SetPoint("TOP", body, "TOP", 0, ctx.offsetY)
            img:SetSize(imgW, imgH)
            return imgH
        end
    end

    T:Popup({
        key = POPUP_KEY,
        replace = true,
        title = L["Updater_Title"],
        text = L["Updater_Body"],
        width = popupWidth,
        minWidth = POPUP_MIN_W,
        build = build,
        buttons = {{
            text = L["Reload"],
            isDefault = true,
            onClick = function()
                ReloadUI()
            end
        }, {
            text = L["Cancel"],
            preset = "cancel"
        }}
    })
end
