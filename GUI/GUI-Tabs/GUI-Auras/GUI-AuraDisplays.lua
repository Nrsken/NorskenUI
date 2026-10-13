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
local TriggerEditor = NRSKNUI.GUITriggerEditor
local Premade = NRSKNUI.AuraFiltersPremade
local AuraTriggers = NRSKNUI.AuraTriggers

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

    -- Any debuff branch earns the tracker its dispel settings.
    local trigger = instance.Trigger
    local harmful = trigger == nil or trigger.Base ~= AuraUtil.AuraFilters.Helpful
    for _, branch in ipairs(trigger and trigger.branches or {}) do
        if (branch.type or trigger.Base) ~= AuraUtil.AuraFilters.Helpful then harmful = true end
    end

    -- Custom user trackers.
    return {
        key = key,
        isInstance = true,
        isBuiltin = AuraDisplay:IsBuiltin(key),
        title = instance.name or key,
        enableText = L['Enable'],
        harmful = harmful,
        db = instance,
        Apply = function() AuraDisplay:ApplySettings(key) end,
        Toggle = function()
            NRSKNUI:ToggleModule('AuraDisplay', AuraDisplay:AnyEnabled())
            AuraDisplay:ApplySettings(key)
        end,
    }
end

local RefreshSidebar -- defined with the sidebar below

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
            RefreshSidebar() -- the row dims with its tracker
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

    TriggerEditor:Build(page, db.Trigger, { title = L['Tracker'], showUnit = true, onChange = display.Apply })
end

-- Appearance Tab
local function BuildAppearanceTab(page, display, db, ctx)
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
        hideFontSize = true, -- each string's size sits with the rest of its settings in the Text card
        onChangeCallback = display.Apply,
    })

    AuraCards:Text(page, db, ctx)
    AuraCards:Reload(page)
end

-- Sidebar --

local function Reopen(selectKey)
    local window = NRSKNUI.GUIFrame
    if not (window and window.content) then return end

    window.content:ShowPage(PAGE, selectKey and { itemKey = selectKey } or nil)
end

---@param presetKey string? start from this preset
---@param presetName string? its name, the suggested tracker name
local function CreateDisplayPrompt(presetKey, presetName)
    NRSKNUI:CreatePrompt({
        title = L['New Tracker'],
        text = presetName or '',
        editBox = true,
        editBoxLabel = L['Tracker Name'],
        onAccept = function(name)
            if not name or name == '' then
                NRSKNUI:Print(L['Please enter a name'])
                return
            end

            if AuraDisplay:IsMerged() then
                -- New trackers are aura groups in the Cooldown & Aura Manager now.
                local CDM = NRSKNUI:GetModule('CDM')
                local id = CDM:CreateAuraGroup(name, presetKey)
                if not id then return end
                CDM.db.Enabled = true
                NRSKNUI:ToggleModule('CDM', true)
                CDM:ApplySettings(id)
                NRSKNUI.GUIFrame.content:ShowPage('cooldownManager', { itemKey = id })
                return
            end

            local id = AuraDisplay:Create(name, presetKey)
            if not id then return end

            NRSKNUI:ToggleModule('AuraDisplay', true)
            AuraDisplay:ApplySettings(id)
            Reopen(id)
        end,
        acceptText = L['Create'],
        cancelText = L['Cancel'],
    })
end

local function NewTrackerMenu()
    local entries = {
        { text = L['Empty Tracker'], onClick = function() CreateDisplayPrompt() end },
        { divider = true },
    }
    for _, preset in ipairs(Premade:GetList()) do
        entries[#entries + 1] = {
            text = format(L['From %s'], preset.text),
            onClick = function() CreateDisplayPrompt(preset.key, preset.text) end,
        }
    end
    GUI:ShowContextMenu(entries)
end

---@param key string
local function ToggleDisplay(key)
    local instance = AuraDisplay:Get(key)
    instance.Enabled = not instance.Enabled
    NRSKNUI:ToggleModule('AuraDisplay', AuraDisplay:AnyEnabled())
    AuraDisplay:ApplySettings(key)
    Reopen(key)
end

---@param key string
local function DuplicateDisplay(key)
    local newId = AuraDisplay:Duplicate(key)
    if not newId then return end

    NRSKNUI:ToggleModule('AuraDisplay', AuraDisplay:AnyEnabled())
    AuraDisplay:ApplySettings(newId)
    Reopen(newId)
end

---@param key string
local function BuiltinMenu(key)
    local instance = AuraDisplay:Get(key)
    local shipped = AuraTriggers:GetShipped(instance.Trigger)
    local entries = {
        { text = instance.Enabled and L['Disable'] or L['Enable'], onClick = function() ToggleDisplay(key) end },
        { text = L['Duplicate as Custom'], onClick = function() DuplicateDisplay(key) end },
        { divider = true },
    }

    if shipped and (shipped.Added or shipped.Removed) then
        entries[#entries + 1] = {
            text = L['Reset Spells to Default'],
            onClick = function()
                NRSKNUI:CreatePrompt({
                    title = L['Reset Spells to Default'],
                    text = L['Remove the spells you added and switch every default spell back on?'],
                    onAccept = function()
                        shipped.Added, shipped.Removed = nil, nil
                        AuraTriggers:Invalidate()
                        Reopen(key)
                    end,
                    acceptText = L['Reset'],
                    cancelText = L['Cancel'],
                })
            end,
        }
    end

    entries[#entries + 1] = {
        text = L['Reset Everything to Default'],
        onClick = function()
            NRSKNUI:CreatePrompt({
                title = L['Reset Everything to Default'],
                text = format(L["Put '%s' back to how it shipped, spells, layout and position included?"], AuraDisplay:GetName(key)),
                onAccept = function()
                    AuraDisplay:ResetBuiltin(key)
                    NRSKNUI:ToggleModule('AuraDisplay', AuraDisplay:AnyEnabled())
                    AuraDisplay:ApplySettings(key)
                    AuraTriggers:Invalidate()
                    Reopen(key)
                end,
                acceptText = L['Reset'],
                cancelText = L['Cancel'],
            })
        end,
    }

    GUI:ShowContextMenu(entries)
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

---@return table? miniSidebar
local function MiniSidebar()
    local content = NRSKNUI.GUIFrame and NRSKNUI.GUIFrame.content
    return content and content.miniSidebar
end

---@param key string
---@param instance table
---@return table
local function TrackerItem(key, text, instance)
    return {
        key = key,
        text = text,
        disabled = not instance.Enabled,
        draggable = true,
        renamable = true,
        grouped = instance.group ~= nil,
    }
end

---@param key string
---@return boolean
local function IsOpen(key)
    return not NRSKNUI.db.global.SidebarCollapsed[PAGE][key]
end

---Defaults first, then groups and loose trackers by name; only a group's own trackers keep a manual order.
---@return table[]
local function SidebarItems()
    local items = {}
    local merged = AuraDisplay:IsMerged() -- the trackers are listed in the Cooldown & Aura Manager

    local shipped = {}
    for _, entry in ipairs(merged and {} or AuraDisplay:GetList()) do
        if AuraDisplay:IsBuiltin(entry.key) then
            local instance = AuraDisplay:Get(entry.key)
            shipped[#shipped + 1] = { key = entry.key, text = entry.text, disabled = not instance.Enabled }
        end
    end
    for _, entry in ipairs(STANDARD) do
        shipped[#shipped + 1] = { key = entry.key, text = entry.title, disabled = not entry.GetDB().Enabled }
    end

    items[#items + 1] = {
        type = 'header',
        key = DISPLAYS_SECTION,
        text = L['Default Trackers'],
        defaultExpanded = IsOpen(DISPLAYS_SECTION),
        items = shipped,
    }

    if merged then return items end

    -- An empty group stays listed, so a tracker can be dragged back into it.
    for _, group in ipairs(AuraDisplay:GetGroups()) do
        local members = {}
        for _, member in ipairs(AuraDisplay:GetMembers(group.key)) do
            members[#members + 1] = TrackerItem(member.key, member.text, AuraDisplay:Get(member.key))
        end

        items[#items + 1] = {
            type = 'header',
            key = group.key,
            text = group.name,
            isGroup = true,
            defaultExpanded = IsOpen(group.key),
            items = members,
        }
    end

    for _, entry in ipairs(AuraDisplay:GetList()) do
        local instance = AuraDisplay:Get(entry.key)
        if instance and not AuraDisplay:IsBuiltin(entry.key) and not instance.group then
            items[#items + 1] = TrackerItem(entry.key, entry.text, instance)
        end
    end

    return items
end

function RefreshSidebar()
    local sidebar = MiniSidebar()
    if sidebar then sidebar:SetItems(SidebarItems()) end
end

---@param groupKey string
local function GroupMenu(groupKey)
    GUI:ShowContextMenu({
        { text = L['Rename'], onClick = function() MiniSidebar():BeginRename(groupKey) end },
        {
            text = L['Delete Group'],
            onClick = function()
                AuraDisplay:DeleteGroup(groupKey)
                RefreshSidebar()
            end,
        },
    })
end

GUI:RegisterPage(PAGE, {
    mode = 'tabs',
    search = {
        L['Advanced Debuffs'], L['Defensives'], L['Speed'],
        L['Standard Buffs'], L['Standard Debuffs'], L['Trigger'],
    },
    sidebar = {
        buttons = { { text = L['New Tracker'], onClick = NewTrackerMenu }, },
        items = SidebarItems,
        onToggle = function(key, expanded)
            NRSKNUI.db.global.SidebarCollapsed[PAGE][key] = (not expanded) or nil
        end,
        onRename = function(key, text, item)
            if item.isGroup then
                AuraDisplay:RenameGroup(key, text)
            else
                AuraDisplay:Rename(key, text)
            end
            RefreshSidebar()
        end,
        -- Into a group, or next to a grouped tracker; next to a loose one only takes a tracker out of its group.
        canDrop = function(item, target, position)
            if position == 'into' then return target.isGroup == true end
            return target.draggable == true and (target.grouped or item.grouped)
        end,
        onMove = function(key, targetKey, position)
            if position == 'into' then
                AuraDisplay:SetGroup(key, targetKey)
            else
                AuraDisplay:MoveNextTo(key, targetKey, position)
            end
            RefreshSidebar()
            if position == 'into' then MiniSidebar():SetExpanded(targetKey, true) end
        end,
        onContextMenu = function(key, item)
            if item and item.isGroup then return GroupMenu(key) end
            if STANDARD[key] then return end
            if AuraDisplay:IsBuiltin(key) then return BuiltinMenu(key) end

            local instance = AuraDisplay:Get(key)
            if not instance then return end

            local entries = {
                { text = instance.Enabled and L['Disable'] or L['Enable'], onClick = function() ToggleDisplay(key) end },
                { text = L['Rename'],           onClick = function() MiniSidebar():BeginRename(key) end },
                { text = L['Duplicate'],        onClick = function() DuplicateDisplay(key) end },
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
                            RefreshSidebar()
                        end,
                    }
                end
            end

            if instance.group then
                entries[#entries + 1] = {
                    text = L['Remove from Group'],
                    onClick = function()
                        AuraDisplay:SetGroup(key, nil)
                        RefreshSidebar()
                    end,
                }
            end

            GUI:ShowContextMenu(entries)
        end,
    },
    tabs = function(itemKey)
        local tabs = { { id = 'layout', text = L['Layout'] } }

        local display = Resolve(itemKey)
        if display and display.isInstance then
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
