local E, L, P = unpack(ART)
local LSM = E.Libs.LSM

local function rgba(r, g, b, a)
    return {
        r = r,
        g = g,
        b = b,
        a = a or 1
    }
end

P.general = P.general or {}
P.general.minimapIcon = P.general.minimapIcon or {
    hide = false
}
P.general.locale = P.general.locale or GetLocale()

P.cosmetic = P.cosmetic or {}
P.cosmetic.colors = {
    backdrop = rgba(0.07, 0.07, 0.07), -- panel fill
    border = rgba(0.00, 0.00, 0.00), -- edge
    accent = rgba(23 / 255, 132 / 255, 209 / 255) -- highlights, ticks, arrows
}
P.cosmetic.opacity = {
    backdrop = 0.50, -- main panels
    backdropFaded = 0.55 -- dropdown pullouts, popups, inline groups
}
P.cosmetic.fonts = {
    normal = "PT Sans Narrow",
    size = 12,
    outline = "OUTLINE"
}
P.cosmetic.textures = {
    statusbar = "Clean"
}

local PRESETS = {
    default = {
        label = "ARTDefault",
        colors = CopyTable(P.cosmetic.colors),
        opacity = CopyTable(P.cosmetic.opacity)
    },
    classColor = {
        label = "ClassColor",
        colors = {
            backdrop = rgba(0.07, 0.07, 0.07),
            border = rgba(0.00, 0.00, 0.00)
        },
        opacity = {
            backdrop = 1.00,
            backdropFaded = 0.85
        },
        useClassColor = true
    },
    midnight = {
        label = "Midnight",
        colors = {
            backdrop = rgba(0.03, 0.03, 0.05),
            border = rgba(0.15, 0.15, 0.18),
            accent = rgba(0.45, 0.35, 0.85)
        },
        opacity = {
            backdrop = 0.95,
            backdropFaded = 0.80
        }
    },
    highContrast = {
        label = "HighContrast",
        colors = {
            backdrop = rgba(0.00, 0.00, 0.00),
            border = rgba(1.00, 1.00, 1.00),
            accent = rgba(1.00, 0.84, 0.00)
        },
        opacity = {
            backdrop = 1.00,
            backdropFaded = 0.95
        }
    }
}

-- Module
local HomeSettings = E:NewModule("HomeSettings", "AceEvent-3.0")
HomeSettings.PRESETS = PRESETS

function HomeSettings:UpdateMinimap()
    local LDBIcon = E.Libs.LDBIcon
    if LDBIcon then
        if E.db.profile.general.minimapIcon.hide then
            LDBIcon:Hide("AdvanceRaidTools")
        else
            LDBIcon:Show("AdvanceRaidTools")
        end
    end
end

function HomeSettings:SyncMediaTable()
    local db = E.db.profile.cosmetic
    E.media = E.media or {}

    local bg = db.colors.backdrop
    local br = db.colors.border
    local ac = db.colors.accent
    local op = db.opacity

    E.media.backdropColor = {bg.r, bg.g, bg.b, op.backdrop or 1.00}
    E.media.backdropFadeColor = {bg.r, bg.g, bg.b, op.backdropFaded or 0.85}
    E.media.borderColor = {br.r, br.g, br.b, 1}
    E.media.valueColor = {ac.r, ac.g, ac.b, 1}
    E.media.accentColor = E.media.valueColor

    if LSM then
        E.media.normFont = LSM:Fetch("font", db.fonts.normal) or E.media.normFont
        E.media.statusbarTexture = LSM:Fetch("statusbar", db.textures.statusbar) or E.media.normTex
    end
    E.media.normFontSize = db.fonts.size or 12
    E.media.normFontOutline = db.fonts.outline or "OUTLINE"
end

local function applyMediaSweep(kind)
    if kind == nil then
        if E.UpdateMedia then
            E:UpdateMedia()
        end
        return
    end

    if kind == "backdropColor" or kind == "opacity" or kind == "border" then
        if E.UpdateMediaBackdropColors then
            E:UpdateMediaBackdropColors()
        end
    end
    if kind == "border" then
        if E.UpdateMediaBorder then
            E:UpdateMediaBorder()
        end
    end
    if kind == "accent" then
        if E.UpdateMediaAccent then
            E:UpdateMediaAccent()
        end
    end
    if kind == "font" then
        if E.UpdateMediaFonts then
            E:UpdateMediaFonts()
        end
    end

    if E.SendMessage then
        E:SendMessage("ART_MEDIA_UPDATED")
    end
end

function HomeSettings:UpdateCosmetics(skipNotify, kind)
    self:SyncMediaTable()
    applyMediaSweep(kind)

    -- prevent AceConfig from rebuilding the panel when doing stuff
    if not skipNotify then
        if E.RefreshOptions then
            E:RefreshOptions()
        end
    end
end

function HomeSettings:ApplyPreset(name)
    local preset = PRESETS[name]
    if not preset then
        return
    end

    local db = E.db.profile.cosmetic

    if preset.colors then
        for k, v in pairs(preset.colors) do
            local dst = db.colors[k]
            if dst and v then
                dst.r, dst.g, dst.b, dst.a = v.r, v.g, v.b, v.a or 1
            end
        end
    end
    if preset.opacity then
        for k, v in pairs(preset.opacity) do
            db.opacity[k] = v
        end
    end
    if preset.useClassColor and E.classColor then
        local cc = E.classColor
        db.colors.accent.r, db.colors.accent.g, db.colors.accent.b = cc.r, cc.g, cc.b
        db.colors.accent.a = 1
    end

    self:UpdateCosmetics()
end

function HomeSettings:ApplyClassColor()
    if not E.classColor then
        return
    end
    local cc = E.classColor
    local dst = E.db.profile.cosmetic.colors.accent
    dst.r, dst.g, dst.b, dst.a = cc.r, cc.g, cc.b, 1
    self:UpdateCosmetics()
end

local function migrateLegacyCosmetics(db)
    local colors = db.colors
    local legacy = rawget(colors, "value")
    local modern = rawget(colors, "accent")
    if legacy and not modern then
        colors.accent = {
            r = legacy.r,
            g = legacy.g,
            b = legacy.b,
            a = legacy.a or 1
        }
    end
    if legacy then
        -- drop the stored value so it falls back to defaults cleanly
        colors.value = nil
    end
end

function HomeSettings:OnInitialize()
    local db = E.db.profile.cosmetic
    migrateLegacyCosmetics(db)

    self:UpdateMinimap()
    self:UpdateCosmetics()
end

function HomeSettings:OnProfileChanged()
    if not self:IsEnabled() then
        return
    end

    local db = E.db.profile.cosmetic
    migrateLegacyCosmetics(db)

    self:UpdateMinimap()
    self:UpdateCosmetics()
end

-- register the message on the module itself to prevent other modules from overwriting it
HomeSettings:RegisterMessage("ART_PROFILE_CHANGED", "OnProfileChanged")
