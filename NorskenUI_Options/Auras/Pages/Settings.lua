---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenAuras') then return end
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local ipairs = ipairs

local GUI = NRSKNUI.GUI
local Shared = NRSKNUI.CDMOptions
local PAGE, RefreshTree, ScheduleAnchorUpdate = Shared.PAGE, Shared.RefreshTree, Shared.ScheduleAnchorUpdate
local SETTINGS_PAGE, TRINKETS = Shared.SETTINGS_PAGE, Shared.TRINKETS
local BuildTrinketPage = Shared.BuildTrinketPage

local GENERAL_ITEM = 'general'

-- the main window's own pages, built here as they are
local GLOBAL_PAGES = {
    { key = 'globalFonts',        text = L['Fonts'] },
    { key = 'globalTextures',     text = L['Textures'] },
    { key = 'globalDurationText', text = L['Duration Text'] },
    { key = 'globalLanguage',     text = L['Language'] },
    { key = 'themePage',          text = L['Theme'] },
}

---@param page table
local function BuildGeneralPage(page)
    page:SetEnabled(function() return CDM.db.Enabled end)
    page:Card(L['Cooldown & Aura Manager']):Row(rowHL, 0):Checkbox(L['Enable Cooldown & Aura Manager'], {
        width = 1,
        master = true,
        value = CDM.db.Enabled,
        callback = function(checked)
            CDM.db.Enabled = checked
            NRSKNUI:ToggleModule('CDM', checked)
            page:Refresh()
            RefreshTree()
        end,
    })

    local integration = page:Card(L['Integration'], 'all')
    integration:Row(rowH):Checkbox(L['Hide Blizzard Player Cast Bar'], {
        width = 1,
        value = CDM.db.HidePlayerCastBar,
        tooltip = L["For a cast bar of your own. Showing Blizzard's again takes a reload."],
        callback = function(checked)
            CDM.db.HidePlayerCastBar = checked
            if checked and CDM:IsEnabled() then
                CDM:HidePlayerCastBar()
            elseif not checked then
                NRSKNUI:CreatePrompt({
                    title = L['Reload UI'],
                    text = L["Blizzard's cast bar comes back after a reload. Reload now?"],
                    onAccept = ReloadUI,
                })
            end
        end,
    })
    integration:Separator()
    integration:Row(rowHL, 0):Slider(L['Unit Frame Anchor Minimum Width'], {
        width = 1,
        min = 0,
        max = 600,
        step = 1,
        value = CDM.db.AnchorMinWidth,
        tooltip = L['The unit frame anchor is never narrower than this, so frames beside it keep their distance from a short group.'],
        callback = function(value)
            CDM.db.AnchorMinWidth = value
            ScheduleAnchorUpdate()
        end,
    })
end

---@return table[]
local function SettingsItems()
    local items = {
        { type = 'label', key = 'cdm:settings', text = L['Cooldown & Aura Manager'] },
        { key = GENERAL_ITEM, text = L['General'] },
        { key = TRINKETS, text = L['Trinket Blacklist'] },
    }
    for _, item in ipairs(GUI._pages.globalColors.sidebar.items) do
        items[#items + 1] = item
    end
    items[#items + 1] = { type = 'label', key = 'cdm:global', text = L['Global Settings'] }
    for _, item in ipairs(GLOBAL_PAGES) do
        items[#items + 1] = item
    end
    return items
end

GUI:RegisterPage(SETTINGS_PAGE, {
    mode = 'clean',
    sidebar = {
        items = SettingsItems,
        default = GENERAL_ITEM,
        buttons = {
            {
                text = L['Back'],
                onClick = function() NRSKNUI.CDMWindow:ShowPage(PAGE) end,
            },
        },
    },
    build = function(page, _, itemKey, item)
        if itemKey == GENERAL_ITEM then
            BuildGeneralPage(page)
        elseif itemKey == TRINKETS then
            Shared.trinketReturnKey = nil -- this way in has no trigger to go back to
            BuildTrinketPage(page)
        elseif item.specs then
            GUI._pages.globalColors.build(page, nil, nil, item)
        else
            GUI._pages[itemKey].build(page)
        end
    end,
})
