---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenAuras') then return end
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local TriggerEditor = NRSKNUI.GUITriggerEditor
local IconPicker = NRSKNUI.CDMIconPicker

local ipairs = ipairs
local select = select

local Shared = NRSKNUI.CDMOptions
local AURA_GROUP_TABS, Applier, BuildAuraGroupLayoutTab, BuildDisplayTab = Shared.AURA_GROUP_TABS, Shared.Applier, Shared.BuildAuraGroupLayoutTab, Shared.BuildDisplayTab
local BuildGroupTab, BuildImportPage, BuildInformationTab, BuildLoadTab = Shared.BuildGroupTab, Shared.BuildImportPage, Shared.BuildInformationTab, Shared.BuildLoadTab
local BuildNewPage, BuildTriggerTab, BuildTrinketPage = Shared.BuildNewPage, Shared.BuildTriggerTab, Shared.BuildTrinketPage
local ContextMenu, IMPORT, MultiContextMenu, PAGE = Shared.ContextMenu, Shared.IMPORT, Shared.MultiContextMenu, Shared.PAGE
local PreviewLevel, RefreshTree, SectionIcons = Shared.PreviewLevel, Shared.RefreshTree, Shared.SectionIcons
local TABS, TRINKETS, TreeContent, TriggerChip = Shared.TABS, Shared.TRINKETS, Shared.TreeContent, Shared.TriggerChip
local TriggerTitle, expandedGroups = Shared.TriggerTitle, Shared.expandedGroups
local EditTargets, MULTI_TABS, Reopen = Shared.EditTargets, Shared.MULTI_TABS, Shared.Reopen

GUI:RegisterPage(PAGE, {
    mode = 'tabs',
    search = { L['Cooldown & Aura Manager'], L['Sub Elements'], L['Swipe Settings'] },
    onEnter = function()
        CDM.onStateChanged = RefreshTree
    end,
    onLeave = function()
        CDM.onStateChanged = nil
        CDM:SetSelectionPreview(nil)
    end,
    sidebar = {
        width = 260,
        create = NRSKNUI.CreateItemTree,
        locked = function() return not CDM.db.Enabled end,
        items = TreeContent,
        onSelectionChanged = function(key)
            CDM:SetSelectionPreview(CDM:Get(key) and key or nil)
        end,
        onToggleExpanded = function(key, expanded)
            if CDM:IsGroup(key) then
                expandedGroups[CDM:Get(key).uid] = expanded or nil
            else
                NRSKNUI.db.global.SidebarCollapsed[PAGE][key] = (not expanded) or nil
            end
        end,
        onRename = function(key, text)
            CDM:Rename(key, text)
            RefreshTree()
        end,
        -- Into a group that can hold it, or next to a display inside one, the top level stays alphabetical.
        canDrop = function(item, target, position)
            if position == 'into' then return target.isGroup and CDM:CanContain(target.key, item.key) end
            local parent = CDM:Get(target.key).parent
            return parent ~= nil and CDM:CanContain(parent, item.key)
        end,
        onMove = function(keys, targetKey, position)
            -- A display inside a moved group travels with it.
            local moving, top = {}, {}
            for _, key in ipairs(keys) do moving[key] = true end
            for _, key in ipairs(keys) do
                local inside = false
                for _, ancestor in ipairs(CDM:GetAncestors(key)) do
                    if moving[ancestor] then
                        inside = true
                        break
                    end
                end
                if not inside then top[#top + 1] = key end
            end
            -- Into a group each one leads it, after a display each one follows it: reversed, they keep their order.
            local reverse = position ~= 'before'
            for i = reverse and #top or 1, reverse and 1 or #top, reverse and -1 or 1 do
                if position == 'into' then
                    CDM:SetParent(top[i], targetKey, true)
                else
                    CDM:MoveNextTo(top[i], targetKey, position)
                end
            end
            CDM:ApplySettings()
            RefreshTree()
        end,
        onMoveInGroup = function(key, delta)
            CDM:MoveInGroup(key, delta)
            CDM:ApplySettings(CDM:Get(key).parent)
            RefreshTree()
        end,
        onUngroup = function(key)
            CDM:Ungroup(key)
            CDM:ApplySettings()
            RefreshTree()
        end,
        onTogglePreview = function(key)
            CDM:SetPreview(key, CDM:GetPreview(key) == 2 and 0 or 2)
        end,
        onSectionPreview = function(sectionKey)
            for _, section in ipairs(TreeContent().sections) do
                if section.key == sectionKey then
                    local ids = SectionIcons(section)
                    local level = PreviewLevel(ids) ~= 2 and 2 or nil
                    for _, id in ipairs(ids) do CDM.preview[id] = level end
                    CDM:RefreshLoad()
                end
            end
        end,
        onContextMenu = function(key)
            if CDM:Get(key) then ContextMenu(key) end
        end,
        onMultiContextMenu = MultiContextMenu,
        -- a Ctrl/Shift pick turns the shown row's page into the multi edit and back
        onPicksChanged = function()
            local tree = Shared.Tree()
            Reopen(tree and tree:GetSelected())
        end,
    },
    tabs = function(itemKey)
        local display = CDM:Get(itemKey)
        -- the new display page has no tabs
        if not display then
            return {}
        end

        if select(2, EditTargets(itemKey)) then
            return MULTI_TABS
        end
        if display.type == 'auragroup' then
            return AURA_GROUP_TABS
        end

        -- a group has no triggers of its own and its children's work too differently to edit together
        local skip = CDM:IsGroup(itemKey) and 'trigger' or 'group'
        local tabs = {}
        for _, tab in ipairs(TABS) do
            if tab.id ~= skip then
                tabs[#tabs + 1] = tab
            end
        end
        return tabs
    end,
    build = function(page, tabId, itemKey)
        local display = CDM:Get(itemKey)
        if itemKey == IconPicker.PAGE then
            IconPicker:Build(page)
            return
        end
        IconPicker:Release()
        IconPicker.currentKey = itemKey

        if itemKey == TRINKETS then
            BuildTrinketPage(page)
            return
        elseif itemKey == IMPORT then
            BuildImportPage(page)
            return
        elseif not display then
            BuildNewPage(page)
            return
        end

        page:SetEnabled(function() return CDM.db.Enabled end)

        if tabId == 'group' then
            BuildGroupTab(page, itemKey)
        elseif tabId == 'display' then
            BuildDisplayTab(page, itemKey)
        elseif tabId == 'layout' then
            BuildAuraGroupLayoutTab(page, itemKey)
        elseif tabId == 'trigger' and CDM.LAYERED_TYPES[display.type] then
            BuildTriggerTab(page, itemKey)
        elseif tabId == 'trigger' and display.type == 'auragroup' then
            display.Trigger = display.Trigger or NRSKNUI.AuraTriggers:New()
            TriggerEditor:Build(page, display.Trigger, { title = L['Tracker'], group = 'all', showUnit = true, onChange = Applier(itemKey) })
        elseif tabId == 'conditions' then
            NRSKNUI.CDMConditionsTab:Build(page, itemKey, Applier(itemKey), TriggerTitle, TriggerChip)
        elseif tabId == 'load' then
            BuildLoadTab(page, itemKey)
        elseif tabId == 'information' then
            BuildInformationTab(page, itemKey)
        end
    end,
})
