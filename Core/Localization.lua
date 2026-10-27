---@class NRSKNUI
local NRSKNUI = select(2, ...)

-- Our own locale registry instead of AceLocale: AceLocale drops every locale but the client's while
-- the files load, so it can't follow a language picked in the options.

local GetLocale = GetLocale
local setmetatable = setmetatable
local pairs = pairs

-- the ten locales we ship files for, in the order the picker lists them, with their own names
NRSKNUI.LANGUAGES = {
    { key = 'enUS', text = 'English' },
    { key = 'deDE', text = 'Deutsch' },
    { key = 'esES', text = 'Español' },
    { key = 'frFR', text = 'Français' },
    { key = 'itIT', text = 'Italiano' },
    { key = 'ptBR', text = 'Português' },
    { key = 'ruRU', text = 'Русский' },
    -- every client ships these (Blizzard_Fonts_Shared/Shared/Fonts.xml), so a Latin theme font can still show the names
    { key = 'koKR', text = '한국어', font = 'Fonts\\2002.TTF' },
    { key = 'zhCN', text = '简体中文', font = 'Fonts\\ARKai_T.ttf' },
    { key = 'zhTW', text = '繁體中文', font = 'Fonts\\blei00d.TTF' },
}

-- client locales without a file of their own read the closest one
local CLIENT_FALLBACK = { enGB = 'enUS', esMX = 'esES' }
local clientLocale = GetLocale()
clientLocale = CLIENT_FALLBACK[clientLocale] or clientLocale

local english = {} -- keyed by the English text, `true` meaning the key itself
local translations = { [clientLocale] = {} }
local active = clientLocale ~= 'enUS' and translations[clientLocale] or nil
local language = clientLocale
local chosen = false
local pending = {}

local englishWriter = setmetatable({}, {
    __newindex = function(_, key, value)
        if english[key] == nil then
            english[key] = value == true and key or value
        end
    end,
})

-- Lookups ask the chosen language, then English, then show the key itself.
NRSKNUI.L = setmetatable({}, {
    __index = function(_, key)
        local value = active and active[key]
        if value == nil then
            value = english[key]
        end
        if value == nil then
            return key
        end
        return value
    end,
})

---The table a locale file writes its strings into, e.g. `L['Enable'] = 'Aktivieren'`.
---@param locale string
---@return table
function NRSKNUI:NewLocale(locale)
    if locale == 'enUS' then
        return englishWriter
    end

    -- Core's own locale files run before the saved choice exists, so until then every language is kept
    if not chosen then
        translations[locale] = translations[locale] or {}
    end

    return setmetatable({}, {
        __newindex = function(_, key, value)
            local strings = translations[locale]
            if strings then
                strings[key] = value
            end
        end,
    })
end

---Pick the language for this session. Strings already shown keep theirs until a reload.
---@param choice string 'auto' or a locale from NRSKNUI.LANGUAGES
function NRSKNUI:SetLanguage(choice)
    language = (choice and choice ~= 'auto') and choice or clientLocale
    chosen = true

    for locale in pairs(translations) do
        if locale ~= language then
            translations[locale] = nil
        end
    end
    translations[language] = translations[language] or {}
    active = language ~= 'enUS' and translations[language] or nil

    -- the picker only changes the saved choice, so this runs once per session
    if pending then
        for _, build in ipairs(pending) do
            build()
        end
        pending = nil
    end
end

---Run 'build' once the saved language is applied or right away when it already is.
---Core files load before the saved choice exists, so text they translate at load would stay in the client's language.
---@param build fun()
function NRSKNUI:OnLanguageSet(build)
    if chosen then
        return build()
    end
    pending[#pending + 1] = build
end

---@return string locale the language strings are shown in
function NRSKNUI:GetLanguage()
    return language
end

---@return string locale the client's own language, as Auto would pick it
function NRSKNUI:GetClientLanguage()
    return clientLocale
end
