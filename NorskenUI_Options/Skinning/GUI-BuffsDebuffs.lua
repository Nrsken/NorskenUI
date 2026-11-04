---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_Skinning') then return end
---@class PlayerAurasModule
local PlayerAuras = NRSKNUI:GetModule('PlayerAuras')
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast
local AuraCards = NRSKNUI.GUIAuraCards

local ipairs = ipairs

--[[
Standard Buffs and Standard Debuffs: the player's own buff and debuff frames (PlayerAuras).
]]

local PAGE = 'buffsDebuffs'

local FRAMES = {
    { key = 'buffs',   title = L['Standard Buffs'],   harmful = false, enchants = true, dbKey = 'Buffs' },
    { key = 'debuffs', title = L['Standard Debuffs'], harmful = true,  dbKey = 'Debuffs' },
}
-- both frames come and go with the module header's one switch
local ITEMS = {}
for _, frame in ipairs(FRAMES) do
    FRAMES[frame.key] = frame
    ITEMS[#ITEMS + 1] = { key = frame.key, text = frame.title }
end

local function Apply()
    PlayerAuras:ApplySettings()
end

---@param page table
---@param frame table
---@param db table
---@param ctx table
local function BuildLayoutTab(page, frame, db, ctx)
    AuraCards:Grid(page, db, ctx)
    AuraCards:Growth(page, db, ctx)

    if frame.enchants then
        local enchantCard = page:Card(L['Weapon Enchants'], 'all')
        enchantCard:Row(rowH):Checkbox(L['Show Weapon Enchants'], {
            width = 1,
            tooltip = L['Flows the temporary main and off-hand enchants in front of the buffs.'],
            value = db.showWeaponEnchants,
            callback = function(checked)
                db.showWeaponEnchants = checked
                NRSKNUI:CreateReloadPrompt(L['Adding or removing the weapon enchants requires a reload to take full effect.'])
            end,
        })

        local groupRow = enchantCard:Row(rowHL, 0)
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

    AuraCards:Sorting(page, db, ctx)
end

GUI:RegisterPage(PAGE, {
    mode = 'tabs',
    search = { L['Standard Buffs'], L['Standard Debuffs'], L['Weapon Enchants'] },
    sidebar = { items = ITEMS },
    tabs = function()
        return {
            { id = 'layout', text = L['Layout'] },
            { id = 'appearance', text = L['Appearance'] },
            { id = 'font', text = L['Font Settings'] },
            { id = 'position', text = L['Position Settings'] },
        }
    end,
    build = function(page, tabId, itemKey)
        local frame = FRAMES[itemKey or 'buffs']
        if not frame then return end
        local db = NRSKNUI.PlayerAuras.db[frame.dbKey]

        page:SetEnabled(function() return NRSKNUI.PlayerAuras.db.Enabled end)
        local ctx = { Apply = Apply, filtered = false, dispelIconKey = 'showDebuffDispelIcon', withoutDispelType = true }

        if tabId == 'layout' then
            BuildLayoutTab(page, frame, db, ctx)
        elseif tabId == 'appearance' then
            AuraCards:Cooldown(page, db, ctx)
            if frame.harmful then AuraCards:Dispel(page, db, ctx) end
            AuraCards:Tooltip(page, db, ctx)
            AuraCards:Reload(page)
        elseif tabId == 'font' then
            page:FontSettingsCard({
                db = db,
                includeSoftOutline = true,
                globalOverride = {},
                hideFontSize = true, -- each string's size sits with the rest of its settings in the Text card
                onChangeCallback = Apply,
            })
            AuraCards:Text(page, db, ctx)
            AuraCards:Reload(page)
        elseif tabId == 'position' then
            page:PositionCard({
                db = db,
                showAnchorFrameType = true,
                showStrata = true,
                onChangeCallback = Apply,
            })
        end
    end,
})

-- Blizzard's own buff and debuff frames come back only with a reload
NRSKNUI.ModuleHeader:OnToggle('PlayerAuras', function(enabled)
    if enabled then return end

    NRSKNUI:CreateReloadPrompt(L['Enabling/Disabling this UI element requires a reload to take full effect.'])
end)
