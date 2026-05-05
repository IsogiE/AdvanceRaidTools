local E, L = unpack(ART)
local Nicknames = E:GetModule("Nicknames")

local nicknameMethods = {}

local function UpdateAll()
    if not _G.ElvUF then
        return
    end

    for tagName in pairs(nicknameMethods) do
        _G.ElvUF.Tags:RefreshMethods(tagName)
    end

    _G.ElvUF.Tags:RefreshMethods("nickname")
    for i = 1, 12 do
        _G.ElvUF.Tags:RefreshMethods("nickname-len" .. i)
    end
end

local function Update(_unit)
    UpdateAll()
end

local function OnToggle(_enabled)
    UpdateAll()
end

local function Init()
    if not _G.ElvUI or not _G.ElvUF then
        return
    end

    -- Unpack ElvUI to local variables to prevent clashing with our core
    local Elv_E, Elv_L = unpack(_G.ElvUI)
    local _TAGS = _G.ElvUF.Tags.Methods
    local NameHealthColor = _G.ElvUF.Tags.Env.NameHealthColor
    local Translit = Elv_E.Libs.Translit
    local translitMark = '!'

    nicknameMethods = {
        ["name"] = function(unit)
            return Nicknames:Get(unit)
        end,
        ["name:health"] = function(unit, _, args)
            local name = Nicknames:Get(unit)
            local min, max, bco, fco = UnitHealth(unit), UnitHealthMax(unit), strsplit(':', args or '')
            local to = math.ceil(string.utf8len(name) * (min / max))
            local fill = NameHealthColor(_TAGS, fco, unit, '|cFFff3333')
            local base = NameHealthColor(_TAGS, bco, unit, '|cFFffffff')
            return
                to > 0 and (base .. string.utf8sub(name, 0, to) .. fill .. string.utf8sub(name, to + 1, -1)) or fill ..
                    name
        end,
        ["name:first"] = function(unit)
            return Nicknames:Get(unit)
        end,
        ["name:last"] = function(unit)
            return Nicknames:Get(unit)
        end,
        ["name:veryshort"] = function(unit)
            local name = Nicknames:Get(unit)
            return Elv_E:ShortenString(name, 5)
        end,
        ["name:veryshort:status"] = function(unit)
            local status = UnitIsDead(unit) and Elv_L["Dead"] or UnitIsGhost(unit) and Elv_L["Ghost"] or
                               not UnitIsConnected(unit) and Elv_L["Offline"]
            if status then
                return status
            end
            local name = Nicknames:Get(unit)
            return Elv_E:ShortenString(name, 5)
        end,
        ["name:veryshort:translit"] = function(unit)
            local nickname = Nicknames:Get(unit)
            local name = Translit:Transliterate(nickname, translitMark)
            if name then
                return Elv_E:ShortenString(name, 5)
            end
        end,
        ["name:short"] = function(unit)
            local name = Nicknames:Get(unit)
            return Elv_E:ShortenString(name, 10)
        end,
        ["name:short:status"] = function(unit)
            local status = UnitIsDead(unit) and Elv_L["Dead"] or UnitIsGhost(unit) and Elv_L["Ghost"] or
                               not UnitIsConnected(unit) and Elv_L["Offline"]
            if status then
                return status
            end
            local name = Nicknames:Get(unit)
            return Elv_E:ShortenString(name, 10)
        end,
        ["name:short:translit"] = function(unit)
            local nickname = Nicknames:Get(unit)
            local name = Translit:Transliterate(nickname, translitMark)
            if name then
                return Elv_E:ShortenString(name, 10)
            end
        end,
        ["name:medium"] = function(unit)
            return Nicknames:Get(unit)
        end,
        ["name:medium:status"] = function(unit)
            local status = UnitIsDead(unit) and Elv_L["Dead"] or UnitIsGhost(unit) and Elv_L["Ghost"] or
                               not UnitIsConnected(unit) and Elv_L["Offline"]
            if status then
                return status
            end
            return Nicknames:Get(unit)
        end,
        ["name:medium:translit"] = function(unit)
            local nickname = Nicknames:Get(unit)
            local name = Translit:Transliterate(nickname, translitMark)
            if name then
                return Elv_E:ShortenString(name, 15)
            end
        end,
        ["name:long"] = function(unit)
            return Nicknames:Get(unit)
        end,
        ["name:long:status"] = function(unit)
            local status = UnitIsDead(unit) and Elv_L["Dead"] or UnitIsGhost(unit) and Elv_L["Ghost"] or
                               not UnitIsConnected(unit) and Elv_L["Offline"]
            if status then
                return status
            end
            return Nicknames:Get(unit)
        end,
        ["name:long:translit"] = function(unit)
            local nickname = Nicknames:Get(unit)
            local name = Translit:Transliterate(nickname, translitMark)
            if name then
                return Elv_E:ShortenString(name, 20)
            end
        end,
        ["name:abbrev"] = function(unit)
            return Nicknames:Get(unit)
        end,
        ["name:abbrev:veryshort"] = function(unit)
            local name = Nicknames:Get(unit)
            return Elv_E:ShortenString(name, 5)
        end,
        ["name:abbrev:short"] = function(unit)
            local name = Nicknames:Get(unit)
            return Elv_E:ShortenString(name, 10)
        end,
        ["name:abbrev:medium"] = function(unit)
            return Nicknames:Get(unit)
        end,
        ["name:abbrev:long"] = function(unit)
            return Nicknames:Get(unit)
        end
    }

    for tagName, NicknameMethod in pairs(nicknameMethods) do
        local OriginalMethod = _TAGS[tagName]
        if OriginalMethod then
            _TAGS[tagName] = function(unit, _, args)
                local useNickname = Nicknames:IsIntegrationActive("ElvUI") and Nicknames:Has(unit)
                if useNickname then
                    return NicknameMethod(unit, _, args)
                else
                    return OriginalMethod(unit, _, args)
                end
            end
        end
    end

    Elv_E:AddTag("nickname", "UNIT_NAME_UPDATE", function(unit)
        return Nicknames:GetIfAny(unit) or ""
    end)

    for i = 1, 12 do
        Elv_E:AddTag("nickname-len" .. i, "UNIT_NAME_UPDATE", function(unit)
            local nickname = Nicknames:GetIfAny(unit)
            return nickname and strsub(nickname, 1, i) or ""
        end)
    end

    UpdateAll()
end

Nicknames:RegisterIntegration("ElvUI", {
    Init = Init,
    Update = Update,
    OnToggle = OnToggle
})
