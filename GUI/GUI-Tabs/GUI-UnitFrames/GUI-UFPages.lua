---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI

local ipairs = ipairs
local type = type

local UNITS = {
    'player',
    'target',
    'targettarget',
    'focus',
    'focustarget',
    'pet',
    'pettarget',
    'boss',
    'party',
}

-- Mini sidebar, in order. Power, Castbar and Group drop out for the units that never have them.
local SECTIONS = {
    { key = 'frame',          text = L['Frame'] },
    { key = 'group',          text = L['Group'] },
    { key = 'health',         text = L['Health'] },
    { key = 'power',          text = L['Power'] },
    { key = 'castbar',        text = L['Castbar'] },
    { key = 'tags',           text = L['Tags'] },
    { key = 'indicators',     text = L['Indicators'] },
    { key = 'aurabuffs',      text = L['Aura Buffs'] },
    { key = 'auradebuffs',    text = L['Aura Debuffs'] },
    { key = 'auraindicators', text = L['Aura Indicators'] },
}

-- Only these sections carry a sub-tab strip.
local SECTION_TABS = {
    tags = UF.GUITagTabs,
    indicators = UF.GUIIndicatorTabs,
    aurabuffs = UF.GUIAuras.tabs,
    auradebuffs = UF.GUIAuras.tabs,
    auraindicators = UF.GUIAuraIndicatorTabs,
}

---@param unit string
---@return table items
local function SectionItems(unit)
    local isGroup = UF.GroupConfigs[unit]
    local items = {}
    for _, section in ipairs(SECTIONS) do
        local skip = UF.GUINoPower[unit] and (section.key == 'power' or section.key == 'castbar')
        -- Group units are deliberately castbar-free, and only they have a header to configure.
        skip = skip or (isGroup and section.key == 'castbar') or (not isGroup and section.key == 'group')

        if not skip then
            items[#items + 1] = { key = section.key, text = section.text }
        end
    end
    return items
end

-- Search terms and their associated section.
local function SearchTerms()
    local terms = {
        { text = L['Frame'],             itemKey = 'frame' },
        { text = L['Width'],             itemKey = 'frame' },
        { text = L['Height'],            itemKey = 'frame' },
        { text = L['Boss Frames'],       itemKey = 'frame' },
        { text = L['Spacing'],           itemKey = 'frame' },
        { text = L['Growth Direction'],  itemKey = 'frame' },
        { text = L['Health'],            itemKey = 'health' },
        { text = L['Inverse Fill'],      itemKey = 'health' },
        { text = L['Heal Absorb'],       itemKey = 'health' },
        { text = L['Damage Absorb'],     itemKey = 'health' },
        { text = L['Use Global Colors'], itemKey = 'health' },
        { text = L['Power'],             itemKey = 'power' },
        { text = L['Enable Power Bar'],  itemKey = 'power' },
        { text = L['Castbar'],           itemKey = 'castbar' },
        { text = L['Enable Castbar'],    itemKey = 'castbar' },
        { text = L['Safe Zone'],         itemKey = 'castbar' },
        { text = L['Tags'],              itemKey = 'tags' },
        { text = L['Tag Text'],          itemKey = 'tags' },
        { text = L['Insert Health Tag'], itemKey = 'tags' },
        { text = L['Insert Power Tag'],  itemKey = 'tags' },
        { text = L['Insert Name Tag'],   itemKey = 'tags' },
        { text = L['Insert Misc Tag'],   itemKey = 'tags' },
        { text = L['Bound To'],          itemKey = 'tags' },
        { text = L['Indicators'],        itemKey = 'indicators' },
    }

    -- Each indicator is its own tab, so name them all and land on the right one.
    for _, name in ipairs(UF.GUIIndicatorNames()) do
        terms[#terms + 1] = { text = name.text, itemKey = 'indicators', tabId = name.key }
    end

    -- The aura terms apply to both displays
    terms[#terms + 1] = { text = L['Aura Buffs'], itemKey = 'aurabuffs' }
    terms[#terms + 1] = { text = L['Aura Debuffs'], itemKey = 'auradebuffs' }
    terms[#terms + 1] = { text = L['Aura Indicators'], itemKey = 'auraindicators' }
    for _, term in ipairs(UF.GUIAuras.search) do
        terms[#terms + 1] = { text = term, itemKey = 'aurabuffs' }
    end

    for _, term in ipairs(UF.GUIGroupSearch) do
        terms[#terms + 1] = { text = term, itemKey = 'group' }
    end

    return terms
end

---@param unit string
---@return string
function UF.GUIPageID(unit)
    return 'unitFrames_' .. unit
end

do
    for _, unit in ipairs(UNITS) do
        GUI:RegisterPage(UF.GUIPageID(unit), {
            mode = 'tabs',
            noHarvest = true,
            search = SearchTerms(),
            sidebar = { items = SectionItems(unit), default = 'frame' },
            tabs = function(sectionKey)
                local tabs = SECTION_TABS[sectionKey]
                if type(tabs) == 'function' then return tabs(unit) end
                return tabs or {}
            end,
            build = function(page, tabId, sectionKey)
                if not sectionKey then return end

                local db = NRSKNUI.db.profile.UnitFrames
                local uDB = db.Units[unit]

                UF:PreviewAuraIndicator(unit, sectionKey == 'auraindicators' and tonumber(tabId) or nil)
                UF:PreviewIndicator(unit, sectionKey == 'indicators' and tabId or nil)

                local auraDef = UF.GUIAuraSections[sectionKey]
                if auraDef then
                    -- The aura sections own their SetEnabled chain, which gates on the display too.
                    UF.GUIAuras.Build(page, auraDef, tabId, unit)
                    return
                end

                local builder = UF.GUISections[sectionKey]
                if not builder then return end

                page:SetEnabled(function() return db.Enabled and not NRSKNUI.UFBlocked end)
                page:SetCondition('unitOn', function() return uDB.Enabled end)

                builder(page, uDB, unit, tabId)
            end,
        })
    end
end
