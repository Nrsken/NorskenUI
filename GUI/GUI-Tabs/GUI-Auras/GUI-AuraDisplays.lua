---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class AuraDisplayModule
local AuraDisplay = NRSKNUI:GetModule('AuraDisplay')
---@class PlayerAurasModule
local PlayerAuras = NRSKNUI:GetModule('PlayerAuras')
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast
local AuraCards = NRSKNUI.GUIAuraCards
local TriggerCard = NRSKNUI.GUITriggerCard

local ipairs = ipairs
local format = string.format

local PAGE = 'auras'
local DISPLAYS_SECTION = 'auraDisplays_section'

-- For convenience, these two are kept from the old per tracker modules.
local STANDARD = {
    { key = 'standard:buffs',   title = L['Standard Buffs'],   enableText = L['Enable Standard Buffs'],   harmful = false, GetDB = function() return NRSKNUI.db.profile.Auras.Buffs end,   enchants = true, },
    { key = 'standard:debuffs', title = L['Standard Debuffs'], enableText = L['Enable Standard Debuffs'], harmful = true,  GetDB = function() return NRSKNUI.db.profile.Auras.Debuffs end, },
}
for _, entry in ipairs(STANDARD) do STANDARD[entry.key] = entry end

---Resolve a mini sidebar key to what the page needs to build it.
---@param key string?
---@return table? display
local function Resolve(key)
    -- Default built in trackers.
    local standard = key and STANDARD[key]
    if standard then
        return {
            key = key,
            title = standard.title,
            enableText = standard.enableText,
            harmful = standard.harmful,
            enchants = standard.enchants,
            db = standard.GetDB(),
            Apply = function() PlayerAuras:ApplySettings() end,
            Toggle = function(checked)
                local auras = NRSKNUI.db.profile.Auras
                auras.Enabled = auras.Buffs.Enabled or auras.Debuffs.Enabled

                NRSKNUI:ToggleModule('PlayerAuras', auras.Enabled)
                if auras.Enabled then PlayerAuras:ApplySettings() end
            end,
        }
    end

    local instance = AuraDisplay:Get(key)
    if not instance then return nil end

    -- Custom user trackers.
    return {
        key = key,
        isInstance = true,
        isBuiltin = AuraDisplay:IsBuiltin(key),
        title = instance.name or key,
        enableText = L['Enable'],
        harmful = instance.Trigger == nil or instance.Trigger.Base ~= AuraUtil.AuraFilters.Helpful,
        db = instance,
        Apply = function() AuraDisplay:ApplySettings(key) end,
        Toggle = function()
            NRSKNUI:ToggleModule('AuraDisplay', AuraDisplay:AnyEnabled())
            AuraDisplay:ApplySettings(key)
        end,
    }
end

-- Layout Tab
local function BuildLayoutTab(page, display, db, ctx)
    local enableCard = page:Card(display.title)
    enableCard:Row(rowHL, 0):Checkbox(display.enableText, {
        width = 1,
        master = true,
        value = db.Enabled,
        msgPopup = true,
        msgText = display.title,
        callback = function(checked)
            db.Enabled = checked
            display.Toggle(checked)
            page:Refresh()
        end,
    })

    AuraCards:Grid(page, db, ctx)
    AuraCards:Growth(page, db, ctx)

    if display.enchants then
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
                display.Apply()
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
                display.Apply()
            end,
        })
    end

    AuraCards:Sorting(page, db, ctx)
end

-- Trigger Tab
local function BuildTriggerTab(page, display, db)
    db.Trigger = db.Trigger or NRSKNUI.AuraTriggers:New()

    TriggerCard:Build(page, db.Trigger, { onChange = display.Apply })
end

-- Appearance Tab
local function BuildAppearanceTab(page, display, db, ctx)
    AuraCards:Icons(page, db, ctx)
    AuraCards:Text(page, db, ctx)
    AuraCards:Cooldown(page, db, ctx)
    if display.harmful then AuraCards:Dispel(page, db, ctx) end
    AuraCards:Tooltip(page, db, ctx)
    AuraCards:Reload(page)
end

-- Font Tab
local function BuildFontTab(page, display, db, ctx)
    page:FontSettingsCard({
        db = db,
        includeSoftOutline = true,
        globalOverride = {},
        fontSizes = {
            { label = L['Stack Size'],    dbKey = 'StackFont.FontSize' },
            { label = L['Duration Size'], dbKey = 'DurationFont.FontSize' },
        },
        onChangeCallback = display.Apply,
    })

    AuraCards:TextPosition(page, db, ctx)
    AuraCards:Reload(page)
end

-- Sidebar --

local function Reopen(selectKey)
    local window = NRSKNUI.GUIFrame
    if not (window and window.content) then return end

    window.content:ShowPage(PAGE, selectKey and { itemKey = selectKey } or nil)
end

local function CreateDisplayPrompt()
    NRSKNUI:CreatePrompt({
        title = L['New Tracker'],
        text = '',
        editBox = true,
        editBoxLabel = L['Tracker Name'],
        onAccept = function(name)
            if not name or name == '' then
                NRSKNUI:Print(L['Please enter a name'])
                return
            end

            local id = AuraDisplay:Create(name)
            if not id then return end

            NRSKNUI:ToggleModule('AuraDisplay', true)
            AuraDisplay:ApplySettings(id)
            Reopen(id)
        end,
        acceptText = L['Create'],
        cancelText = L['Cancel'],
    })
end

local function RenameDisplayPrompt(key)
    NRSKNUI:CreatePrompt({
        title = L['Rename Tracker'],
        text = AuraDisplay:GetName(key),
        editBox = true,
        editBoxLabel = L['Tracker Name'],
        onAccept = function(name)
            if not name or name == '' then return end

            AuraDisplay:Rename(key, name)
            Reopen(key)
        end,
        acceptText = L['Rename'],
        cancelText = L['Cancel'],
    })
end

local function CreateGroupPrompt(key)
    NRSKNUI:CreatePrompt({
        title = L['Create New Group'],
        text = '',
        editBox = true,
        editBoxLabel = L['Group Name'],
        onAccept = function(name)
            if not name or name == '' then
                NRSKNUI:Print(L['Please enter a name'])
                return
            end

            local groupId = AuraDisplay:CreateGroup(name)
            if not groupId then return end

            AuraDisplay:SetGroup(key, groupId)
            Reopen(key)
        end,
        acceptText = L['Create'],
        cancelText = L['Cancel'],
    })
end

local function DeleteDisplayPrompt(key)
    NRSKNUI:CreatePrompt({
        title = L['Delete Tracker'],
        text = format(L["Delete the display '%s'? This cannot be undone."], AuraDisplay:GetName(key)),
        onAccept = function()
            if not AuraDisplay:Delete(key) then return end

            NRSKNUI:ToggleModule('AuraDisplay', AuraDisplay:AnyEnabled())
            Reopen()
        end,
        acceptText = L['Delete'],
        cancelText = L['Cancel'],
    })
end

---Sidebar items for the mini sidebar.
---@return table[]
local function SidebarItems()
    local items = {}

    -- Default built in trackers.
    local shipped = {}
    for _, entry in ipairs(AuraDisplay:GetList()) do
        if AuraDisplay:IsBuiltin(entry.key) then
            shipped[#shipped + 1] = { key = entry.key, text = entry.text }
        end
    end
    for _, entry in ipairs(STANDARD) do
        shipped[#shipped + 1] = { key = entry.key, text = entry.title }
    end

    items[#items + 1] = {
        type = 'header',
        key = DISPLAYS_SECTION,
        text = L['Default Trackers'],
        defaultExpanded = true,
        items = shipped,
    }

    -- Grouped user trackers.
    for _, group in ipairs(AuraDisplay:GetGroups()) do
        local members = {}
        for _, entry in ipairs(AuraDisplay:GetList()) do
            local instance = AuraDisplay:Get(entry.key)
            if instance and instance.group == group.key then
                members[#members + 1] = { key = entry.key, text = entry.text }
            end
        end

        if members[1] then
            items[#items + 1] = {
                type = 'header',
                key = group.key,
                text = group.name,
                defaultExpanded = true,
                items = members,
            }
        end
    end

    -- Ungrouped user trackers.
    for _, entry in ipairs(AuraDisplay:GetList()) do
        local instance = AuraDisplay:Get(entry.key)
        if instance and not AuraDisplay:IsBuiltin(entry.key) and not instance.group then
            items[#items + 1] = { key = entry.key, text = entry.text }
        end
    end

    return items
end

GUI:RegisterPage(PAGE, {
    mode = 'tabs',
    search = {
        L['Advanced Debuffs'], L['Defensives'], L['Speed'],
        L['Standard Buffs'], L['Standard Debuffs'], L['Trigger'],
    },
    sidebar = {
        buttons = { { text = L['New Tracker'], onClick = CreateDisplayPrompt }, },
        items = SidebarItems,
        onContextMenu = function(key)
            if STANDARD[key] or AuraDisplay:IsBuiltin(key) then return end -- no context menu for the built in trackers

            local instance = AuraDisplay:Get(key)
            if not instance then return end

            local entries = {
                { text = L['Rename'],           onClick = function() RenameDisplayPrompt(key) end },
                { text = L['Delete'],           onClick = function() DeleteDisplayPrompt(key) end },
                { divider = true },
                { text = L['Create New Group'], onClick = function() CreateGroupPrompt(key) end },
            }

            for _, group in ipairs(AuraDisplay:GetGroups()) do
                if group.key ~= instance.group then
                    entries[#entries + 1] = {
                        text = format(L['Add to %s'], group.name),
                        onClick = function()
                            AuraDisplay:SetGroup(key, group.key)
                            Reopen(key)
                        end,
                    }
                end
            end

            if instance.group then
                entries[#entries + 1] = {
                    text = L['Remove from Group'],
                    onClick = function()
                        AuraDisplay:SetGroup(key, nil)
                        Reopen(key)
                    end,
                }
            end

            GUI:ShowContextMenu(entries)
        end,
    },
    tabs = function(itemKey)
        local tabs = { { id = 'layout', text = L['Layout'] } }

        local display = Resolve(itemKey)
        if display and display.isInstance and not display.isBuiltin then
            tabs[#tabs + 1] = { id = 'trigger', text = L['Trigger'] }
        end
        tabs[#tabs + 1] = { id = 'appearance', text = L['Appearance'] }
        tabs[#tabs + 1] = { id = 'font', text = L['Font Settings'] }
        tabs[#tabs + 1] = { id = 'position', text = L['Position Settings'] }

        return tabs
    end,
    build = function(page, tabId, itemKey)
        local display = Resolve(itemKey)
        if not display or not display.db then return end

        AuraDisplay:SetPreviewTarget(display.isInstance and itemKey or nil)
        page:SetEnabled(function() return display.db.Enabled end)

        local ctx = {
            Apply = display.Apply,
            filtered = display.isInstance,
            dispelIconKey = 'showDebuffDispelIcon',
            withoutDispelType = true,
        }

        if tabId == 'layout' then
            BuildLayoutTab(page, display, display.db, ctx)
        elseif tabId == 'trigger' then
            BuildTriggerTab(page, display, display.db)
        elseif tabId == 'appearance' then
            BuildAppearanceTab(page, display, display.db, ctx)
        elseif tabId == 'font' then
            BuildFontTab(page, display, display.db, ctx)
        elseif tabId == 'position' then
            page:PositionCard({
                db = display.db,
                showAnchorFrameType = true,
                showStrata = true,
                onChangeCallback = display.Apply,
            })
        end
    end,
})
