---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local AuraCards = NRSKNUI.GUIAuraCards
local IconPicker = NRSKNUI.CDMIconPicker
local rowHL = Theme.rowHeightLast

local ipairs = ipairs
local tostring = tostring
local tonumber = tonumber

local Shared = NRSKNUI.CDMOptions
local Applier, PositionCard, RefreshTree, TriggerChip = Shared.Applier, Shared.PositionCard, Shared.RefreshTree, Shared.TriggerChip

---Any debuff branch earns an aura group its dispel settings, as on the Auras page.
---@param trigger table?
---@return boolean
local function HasHarmful(trigger)
    local helpful = AuraUtil.AuraFilters.Helpful
    if trigger == nil or trigger.Base ~= helpful then return true end
    for _, branch in ipairs(trigger.branches or {}) do
        if (branch.type or trigger.Base) ~= helpful then return true end
    end
    return false
end

local auraSectionOpen = {} -- [title] = true, for the session; sections start closed as on an icon's Display tab

-- What a collapsed section's rows build into: every widget call does nothing.
local NULL_ROW = setmetatable({}, { __index = function() return function() end end })
local NULL_CARD = { Row = function() return NULL_ROW end, Separator = function() end }

---Lets the Auras page cards build as collapsible sections of one card, the way an icon's Display tab is laid out.
---@param page table
---@param card table
---@return table
local function SectionPage(page, card)
    return {
        Card = function(_, title)
            local open = card:Section(title, {
                key = 'cdm:aura:' .. title,
                collapsed = not auraSectionOpen[title],
                onToggle = function()
                    auraSectionOpen[title] = not auraSectionOpen[title] or nil
                    card:Rebuild()
                end,
            })
            return open and card or NULL_CARD
        end,
        SetCondition = function(_, ...) return page:SetCondition(...) end,
        Refresh = function() page:Refresh() end,
    }
end

---@param id string
---@return table ctx what the Auras page cards read
local function AuraCardContext(id)
    return { Apply = Applier(id), filtered = true, dispelIconKey = 'showDebuffDispelIcon', withoutDispelType = true }
end

---An aura group's look, sectioned like an icon's: the list icon, the swipe, the texts, then the rest.
---@param page table
---@param id string
local function BuildAuraGroupDisplayTab(page, id)
    local display = CDM:Get(id)
    local ctx = AuraCardContext(id)
    local Heading = NRSKNUI.CDMDisplayTab.Heading

    page:Card(L['Display'], 'all'):Rebuild(function(card)
        local sections = SectionPage(page, card)
        Heading(card, L['Icon'])
        local iconRow = sections:Card(L['Icon Settings']):Row(rowHL, 0)
        iconRow:EditBox(L['Icon ID'], {
            width = 0.9,
            tooltip = L['The icon this aura group shows in the list. Empty uses its first spell.'],
            value = display.Icon and tostring(display.Icon) or '',
            callback = function(text)
                display.Icon = tonumber(text)
                RefreshTree()
            end,
        })
        IconPicker:BrowseButton(iconRow, display.Icon, function()
            IconPicker:Open(display.Icon, function(texture)
                display.Icon = texture
                RefreshTree()
            end)
        end)
        AuraCards:Cooldown(sections, display, ctx)
        Heading(card, L['Sub Elements'])
        AuraCards:Text(sections, display, ctx)
        Heading(card, L['General'])
        if HasHarmful(display.Trigger) then AuraCards:Dispel(sections, display, ctx) end
        AuraCards:Tooltip(sections, display, ctx)
    end)

    page:FontSettingsCard({
        db = display,
        includeSoftOutline = true,
        globalOverride = {},
        hideFontSize = true, -- each string's size sits with the rest of its settings in its section
        onChangeCallback = ctx.Apply,
    })
    AuraCards:Reload(page)
end

---Where an aura group's auras go: the grid, its growth and order, then the group's own position.
---@param page table
---@param id string
local function BuildAuraGroupLayoutTab(page, id)
    local display = CDM:Get(id)
    local ctx = AuraCardContext(id)

    page:Card(L['Layout'], 'all'):Rebuild(function(card)
        local sections = SectionPage(page, card)
        AuraCards:Grid(sections, display, ctx)
        AuraCards:Growth(sections, display, ctx)
        AuraCards:Sorting(sections, display, ctx)
    end)
    PositionCard(page, id)
end

---@param page table
---@param id string
local function BuildDisplayTab(page, id)
    local display = CDM:Get(id)
    if display.type == 'auragroup' then
        BuildAuraGroupDisplayTab(page, id)
        return
    elseif CDM:IsGroup(id) then
        local ids = CDM:GetIcons(id)
        local kind = ids[1] and CDM:Get(ids[1]).type
        for _, iconId in ipairs(ids) do
            if CDM:Get(iconId).type ~= kind then
                page:Card(L['Display']):Row(rowHL, 0):Text(nil, { width = 1, text = L['This group holds more than one kind of display; edit their look per display.'], bgMode = 'hide' })
                return
            end
        end
        NRSKNUI.CDMDisplayTab:Build(page, ids, Applier(id), RefreshTree, TriggerChip)
        return
    end

    NRSKNUI.CDMDisplayTab:Build(page, { id }, Applier(id), RefreshTree, TriggerChip)
end

Shared.BuildAuraGroupLayoutTab = BuildAuraGroupLayoutTab
Shared.BuildDisplayTab = BuildDisplayTab
