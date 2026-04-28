local E, L, P = unpack(ART)

P.modules.Updater = {
    enabled = true
}

local Mod = E:NewModule("Updater", "AceEvent-3.0")

local COMM_PREFIX = "ARTUPD"
local EXPECTED_BTAG = "Isogi#21124"
local POPUP_KEY = "ART_UPDATE_NOTICE"
local IMAGE_POOL = "Dreams"

local POPUP_BODY_PAD = 28
local POPUP_MIN_W = 180

local function getMyBattleTag()
    if type(BNGetInfo) ~= "function" then
        return nil
    end
    local presenceID, btag = BNGetInfo()
    btag = E:SafeString(btag)
    if btag and btag ~= "" then
        return btag
    end
    if presenceID and C_BattleNet and C_BattleNet.GetAccountInfoByID then
        local info = C_BattleNet.GetAccountInfoByID(presenceID)
        if info then
            local resolved = E:SafeString(info.battleTag)
            if resolved and resolved ~= "" then
                return resolved
            end
        end
    end
    return nil
end

local function findGuildMemberGUID(name)
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
        local memberName, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, memberGUID = GetGuildRosterInfo(i)
        if memberName and E:BareName(memberName) == bare then
            return memberGUID
        end
    end
    return nil
end

local function resolveSenderBattleTag(sender)
    if type(sender) ~= "string" or sender == "" then
        return nil
    end
    local guid
    local unit = E:GetGroupUnitByName(sender)
    if unit then
        guid = UnitGUID(unit)
    end
    if not guid then
        guid = findGuildMemberGUID(sender)
    end
    if not guid then
        return nil
    end
    if not (C_BattleNet and C_BattleNet.GetAccountInfoByGUID) then
        return nil
    end
    local info = C_BattleNet.GetAccountInfoByGUID(guid)
    if not info then
        return nil
    end
    local resolved = E:SafeString(info.battleTag)
    if resolved and resolved ~= "" then
        return resolved
    end
    return nil
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
    if resolveSenderBattleTag(sender) ~= EXPECTED_BTAG then
        return
    end
    local senderVersion = E:SafeString(message) or ""
    if E:CompareVersions(senderVersion, E.version or "") <= 0 then
        return
    end
    self:Show()
end

function Mod:Trigger()
    if getMyBattleTag() ~= EXPECTED_BTAG then
        return false
    end
    if not IsInGuild() then
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
        title = "New ART update available",
        text = "Download now, or else :)",
        width = popupWidth,
        minWidth = POPUP_MIN_W,
        build = build,
        buttons = {{
            text = "Reload",
            isDefault = true,
            onClick = function()
                ReloadUI()
            end
        }, {
            text = "Cancel",
            preset = "cancel"
        }}
    })
end
