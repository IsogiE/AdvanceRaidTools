local addonName, addonTable = ...

local AceAddon = LibStub("AceAddon-3.0")

local E = AceAddon:NewAddon(addonName, "AceEvent-3.0", "AceConsole-3.0")

local LanguageSettings = setmetatable({}, {
    __index = function(_, key)
        local active = (E.db and E.db.profile.general.locale) or GetLocale()
        local Locales = addonTable.Locales or {}

        if not Locales[active] then
            active = "enUS"
        end

        local activeTable = Locales[active] or {}
        local fallbackTable = Locales["enUS"] or {}

        local translation = activeTable[key]
        if translation == nil then
            translation = fallbackTable[key]
        end

        if translation == true then
            return key
        end

        return translation or key
    end
})

local L = LanguageSettings

local P = {
    general = {
        firstRun = true,
        minimapIcon = {
            hide = false
        },
        locale = nil,
        scale = 1.0,
        debug = {
            enabled = false, -- Warn/Debug chat output
            channels = {} -- [channelName] = true; honored even when master is off
        }
    },
    modules = {}
}

local G = {
    version = nil -- last-seen addon version
}

-- media paths
E.media = {
    backdropColor = {0.07, 0.07, 0.07, 1.00},
    backdropFadeColor = {0.07, 0.07, 0.07, 0.85},
    borderColor = {0.00, 0.00, 0.00, 1.00},
    valueColor = {23 / 255, 132 / 255, 209 / 255, 1.00},
    normFontSize = 12,
    normFontOutline = "OUTLINE"
}

do
    local _, class = UnitClass("player")
    E.myClass = class
    E.classColor = RAID_CLASS_COLORS[class] or {
        r = 1,
        g = 1,
        b = 1
    }
end

addonTable[1] = E
addonTable[2] = L
addonTable[3] = P
addonTable[4] = G
_G.ART = addonTable

E.version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "0.0.0"
E.apiVersion = 1
E.addonName = addonName

function E:OnInitialize()
    self:InitializeDatabase(P, G)
    self:RegisterMedia()
    self:InitializePixelPerfect()
    self:RegisterSlashCommands()
    self:InitializeMinimapIcon()

    self:InitializeAllModules()
    self:FlushAllModuleFeatureRegistrations()
    self:FlushBossModNoteBlockRegistrations()
    self:WarnUnresolvedModuleFeatureRegistrations()
    self:WarnUnresolvedBossModNoteBlockRegistrations()

    self:SendMessage("ART_CORE_INITIALIZED")

    self:PrebuildOptions()
end
