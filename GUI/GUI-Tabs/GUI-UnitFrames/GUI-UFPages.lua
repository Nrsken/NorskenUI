---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI

local ipairs = ipairs

local UNITS = {
    'player',
    'target',
    'targettarget',
    'focus',
    'focustarget',
    'pet',
    'pettarget',
    'boss',
}

-- Mini sidebar, in order. Power and Castbar drop out for the units that never have them.
local SECTIONS = {
    { key = 'frame',       text = L['Frame'] },
    { key = 'health',      text = L['Health'] },
    { key = 'power',       text = L['Power'] },
    { key = 'castbar',     text = L['Castbar'] },
    { key = 'tags',        text = L['Tags'] },
    { key = 'indicators',  text = L['Indicators'] },
    { key = 'misc',        text = L['Miscellaneous'] },
    { key = 'aurabuffs',   text = L['Aura Buffs'] },
    { key = 'auradebuffs', text = L['Aura Debuffs'] },
}

-- Only these sections carry a sub-tab strip.
local SECTION_TABS = {
    tags = UF.GUITagTabs,
    indicators = UF.GUIIndicatorTabs,
    aurabuffs = UF.GUIAuras.tabs,
    auradebuffs = UF.GUIAuras.tabs,
}

---@param unit string
---@return table items
local function SectionItems(unit)
    local items = {}
    for _, section in ipairs(SECTIONS) do
        local skip = UF.GUINoPower[unit] and (section.key == 'power' or section.key == 'castbar')
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
        { text = L['Insert Tag'],        itemKey = 'tags' },
        { text = L['Bound To'],          itemKey = 'tags' },
        { text = L['Indicators'],        itemKey = 'indicators' },
        { text = L['Miscellaneous'],     itemKey = 'misc' },
        { text = L['Raid Icon'],         itemKey = 'misc' },
        { text = L['Leader Indicator'],  itemKey = 'misc' },
    }

    -- Each indicator is its own tab, so name them all and land on the right one.
    for _, tab in ipairs(UF.GUIIndicatorTabs) do
        terms[#terms + 1] = { text = tab.text, itemKey = 'indicators', tabId = tab.id }
    end

    -- The aura terms apply to both displays
    terms[#terms + 1] = { text = L['Aura Buffs'], itemKey = 'aurabuffs' }
    terms[#terms + 1] = { text = L['Aura Debuffs'], itemKey = 'auradebuffs' }
    for _, term in ipairs(UF.GUIAuras.search) do
        terms[#terms + 1] = { text = term, itemKey = 'aurabuffs' }
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
        local isBoss = unit == 'boss'

        GUI:RegisterPage(UF.GUIPageID(unit), {
            mode = 'tabs',
            noHarvest = true,
            search = SearchTerms(),
            sidebar = { items = SectionItems(unit), default = 'frame' },
            tabs = function(sectionKey)
                return SECTION_TABS[sectionKey] or {}
            end,
            build = function(page, tabId, sectionKey)
                if not sectionKey then return end

                local db = NRSKNUI.db.profile.UnitFrames
                local uDB = db.Units[unit]

                local auraDef = UF.GUIAuraSections[sectionKey]
                if auraDef then
                    -- The aura sections own their SetEnabled chain, which gates on the display too.
                    UF.GUIAuras.Build(page, auraDef, tabId, unit)
                    return
                end

                local builder = UF.GUISections[sectionKey]
                if not builder then return end

                page:SetEnabled(function() return db.Enabled end)
                page:SetCondition('unitOn', function() return uDB.Enabled end)

                builder(page, uDB, unit, tabId)
            end,
            -- Boss frame preview handling.
            onEnter = isBoss and function() UF.Preview:Request('boss') end or nil,
            onLeave = isBoss and function() UF.Preview:Release('boss') end or nil,
        })
    end
end
