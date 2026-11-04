---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class GUIFrame
local GUIFrame = NRSKNUI.GUIFrame
local L = NRSKNUI.Libs.AL

--[[
#Sidebar Registry Rules

* id:               Must be unique across all entries in the sidebar and use moduleType_id format for module entries.
* type:             Can be either 'header' or 'item'. Headers can contain child items, while items are leaf nodes.
* text:             The display text for the sidebar entry.
* order:            Top-level entries only, sorts them. Core's entries sit here, every other folder adds its own
                    with GUIFrame:AddSidebarEntry from its Sidebar.lua.

* module:           Optional AceModule name whose settings the entry's pages (a header's: all its items) edit.
                    Those pages open under the module header: its name, its on/off and its actions.
* roles:            Set true beside `module` to give the header role tabs, so a role can have its own settings
                    for that module. Off by default: only modules whose look really differs per role want it.

* 'header' entries can have the following optional properties:
* defaultExpanded:  Optional boolean for headers to indicate if they should be expanded by default.
* items:            Optional array of child entries for headers. Each child must follow the same structure.

]]

GUIFrame.SidebarConfig = {
    systems = {
        {
            id = 'profilePage',
            order = 10,
            type = 'item',
            text = L['Profile Settings'],
        },
        {
            id = 'global_section',
            order = 30,
            type = 'header',
            text = L['Global Settings'],
            defaultExpanded = false,
            items = {
                { id = 'globalColors',       text = L['Colors'] },
                { id = 'globalFonts',        text = L['Fonts'] },
                { id = 'globalUIScale',      text = L['UI Scale'] },
                { id = 'globalTextures',     text = L['Textures'] },
                { id = 'globalDurationText', text = L['Duration Text'] },
                { id = 'globalLanguage',     text = L['Language'] },
            }
        },
    },
}

-- Hand the config to the window, it builds the sidebar + search box and drives ShowPage on selection.
GUIFrame:SetSidebar(GUIFrame.SidebarConfig.systems, {
    isDisabled = function(entry)
        return entry.elvUIDisabled and NRSKNUI.ShouldNotLoadModule and NRSKNUI:ShouldNotLoadModule() or false
    end,
})

---Add a top-level entry, a section with its items or a single item, placed by its order.
---The sidebar keeps this table by reference, so a refresh shows entries added after it was built.
---@param entry table
function GUIFrame:AddSidebarEntry(entry)
    local systems = self.SidebarConfig.systems
    local index = #systems + 1
    for i, existing in ipairs(systems) do
        if entry.order < existing.order then
            index = i
            break
        end
    end
    tinsert(systems, index, entry)
    self.sidebar:Refresh()
end
