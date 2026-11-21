---@class NorskenUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_Interface') then return end
---@class PlayerAurasModule
local PlayerAuras = NRSKNUI:GetModule('PlayerAuras')
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local AuraLook = NRSKNUI.GUIAuraLook
local TriggerEditor = NRSKNUI.GUITriggerEditor

local ipairs = ipairs
local setmetatable = setmetatable

--[[
Standard Buffs and Standard Debuffs: the player's own buff and debuff frames (PlayerAuras), each an
aura group edited the way the unit frames' aura kinds are.
]]

local PAGE = 'buffsDebuffs'

local FRAMES = {
    { key = 'buffs',   title = L['Standard Buffs'],   enchants = true, dbKey = 'Buffs' },
    { key = 'debuffs', title = L['Standard Debuffs'], dbKey = 'Debuffs' },
}
-- both frames come and go with the module header's one switch
local ITEMS = { { type = 'label', key = 'frames', text = L['Frames'] } }
for _, frame in ipairs(FRAMES) do
    FRAMES[frame.key] = frame
    ITEMS[#ITEMS + 1] = { key = frame.key, text = frame.title }
end

local function Apply()
    PlayerAuras:ApplySettings()
end

-- Group Tab
---@param page table
---@param frame table
---@param db table
local function BuildGroupTab(page, frame, db)
    page:Card(frame.title, 'all'):Rebuild(function(card)
        if AuraLook.Section(card, 'groupLayout', L['Dynamic Group Settings']) then
            card:Premade('DynamicGroupCard', {
                db = db.Layout,
                showLimit = false,
                extraRows = function(c) AuraLook.AuraGroupCountRows(c, db, Apply) end,
                onChangeCallback = Apply,
            })
        end

        if frame.enchants and AuraLook.Section(card, 'groupEnchants', L['Weapon Enchants']) then
            card:Row(rowH):Checkbox(L['Show Weapon Enchants'], {
                width = 1,
                tooltip = L['Flows the temporary main and off-hand enchants in front of the buffs.'],
                value = db.showWeaponEnchants,
                callback = function(checked)
                    db.showWeaponEnchants = checked
                    Apply()
                end,
            })

            local groupRow = card:Row(rowH)
            groupRow:Slider(L['Group Spacing'], {
                width = 0.5,
                tooltip = L['Spacing at the seam between the weapon enchants and the buffs.'],
                min = 0,
                max = 40,
                step = 1,
                value = db.groupSpacing,
                callback = function(val)
                    db.groupSpacing = val
                    Apply()
                end,
            })
            groupRow:Slider(L['Group Line Spacing'], {
                width = 0.5,
                tooltip = L['Spacing between the weapon enchant rows and the buff rows.'],
                min = 0,
                max = 40,
                step = 1,
                value = db.groupLineSpacing,
                callback = function(val)
                    db.groupLineSpacing = val
                    Apply()
                end,
            })
        end

        if AuraLook.Section(card, 'groupPosition', L['Position Settings']) then
            card:Premade('PositionCard', {
                db = db,
                showAnchorFrameType = true,
                showStrata = true,
                onChangeCallback = Apply,
            })
        end
    end)
end

-- Display Tab
---@param page table
---@param frame table
---@param db table
local function BuildDisplayTab(page, frame, db)
    local style = PlayerAuras:Prepare(frame.dbKey)
    -- edited as an aura group with no triggers of its own; writes reach the frame's settings
    local displays = { setmetatable({ Triggers = {}, type = 'auragroup', name = frame.title }, { __index = db, __newindex = db }) }
    local mixed = AuraLook.Differ(displays, function() return style end)
    local function set(path, value)
        AuraLook.Assign(db.Style, path, value)
        Apply()
    end

    page:Card(frame.title, 'all'):Rebuild(function(card)
        AuraLook.AuraGroupRows(card, page, style, set, mixed, false, function()
            AuraLook.SubElements(card, page, displays, Apply, {
                adds = AuraLook.AuraGroupAdds,
                auraGroup = true,
                enchants = frame.enchants,
            })
        end)
    end)
end

-- Trigger Tab
---@param page table
---@param frame table
---@param db table
local function BuildTriggerTab(page, frame, db)
    -- no Unit row: the frames show the player's auras, the vehicle's under a vehicle UI
    TriggerEditor:BuildSections(page, db.Trigger, { title = frame.title, apply = Apply })
end

local TAB_BUILDERS = {
    group = BuildGroupTab,
    display = BuildDisplayTab,
    trigger = BuildTriggerTab,
}

GUI:RegisterPage(PAGE, {
    mode = 'tabs',
    search = {
        L['Standard Buffs'], L['Standard Debuffs'], L['Weapon Enchants'], L['Dynamic Group Settings'],
        L['Sort Method'], L['Icon Settings'], L['Swipe Settings'], L['Size Settings'], L['Sub Elements'],
        L['Trigger'], L['Show Dispel Icon'], L['Aura Type Texture'],
    },
    sidebar = { items = ITEMS },
    tabs = function()
        return {
            { id = 'group', text = L['Group'] },
            { id = 'display', text = L['Display'] },
            { id = 'trigger', text = L['Trigger'] },
        }
    end,
    build = function(page, tabId, itemKey)
        local frame = FRAMES[itemKey or 'buffs']
        local builder = frame and TAB_BUILDERS[tabId]
        if not builder then return end

        page:SetEnabled(function() return PlayerAuras.db.Enabled end)
        builder(page, frame, PlayerAuras.db[frame.dbKey])
    end,
})

-- Blizzard's own buff and debuff frames come back only with a reload
NRSKNUI.ModuleHeader:OnToggle('PlayerAuras', function(enabled)
    if enabled then return end

    NRSKNUI:CreateReloadPrompt(L['Enabling/Disabling this UI element requires a reload to take full effect.'])
end)
