---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CooldownStringsModule
local CooldownStrings = NRSKNUI:GetModule('CooldownStrings')
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local date = date
local ipairs = ipairs
local tsort = table.sort
local format = string.format
local GetNumClasses = GetNumClasses
local GetSpecializationInfoForClassID = GetSpecializationInfoForClassID

local GetClassInfo = C_CreatureInfo and C_CreatureInfo.GetClassInfo
local GetNumSpecializationsForClassID = C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID

local PAGE = 'cdmStrings'
local EDITBOX_HEIGHT = 130
local ICON_Y_OFFSET = -4

---@param name string
---@param icon number|string|nil
---@return string
local function SpecLabel(name, icon)
    if not icon then return name end

    return format('|T%s:0:0:0:%d:64:64:5:59:5:59|t %s', icon, ICON_Y_OFFSET, name)
end

local specOptions

---@return table[]
local function BuildSpecOptions()
    local options = {}
    for classID = 1, GetNumClasses() do
        local classInfo = GetClassInfo(classID)
        for specIndex = 1, GetNumSpecializationsForClassID(classID) do
            local specID, specName, _, specIcon = GetSpecializationInfoForClassID(classID, specIndex)
            if specID then
                options[#options + 1] = {
                    key = specID,
                    text = SpecLabel(classInfo.className .. ' - ' .. specName, specIcon),
                    color = NRSKNUI:GetClassColor(classInfo.classFile),
                }
            end
        end
    end

    tsort(options, function(a, b) return a.text < b.text end)
    return options
end

-- Sidebar --

local function Reopen(selectKey)
    local window = NRSKNUI.GUIFrame
    if not (window and window.content) then return end

    window.content:ShowPage(PAGE, selectKey and { itemKey = selectKey } or nil)
end

---@return table[]
local function SidebarItems()
    local sections, order = {}, {}

    for _, profile in ipairs(CooldownStrings:GetProfiles()) do
        local classFile = profile.classFile
        local section = sections[classFile or 'UNKNOWN']

        if not section then
            local className = classFile and LOCALIZED_CLASS_NAMES_MALE[classFile] or L['Unknown Spec']
            section = {
                type = 'header',
                key = 'class_' .. (classFile or 'UNKNOWN'),
                text = NRSKNUI:ColorTextByClass(className, classFile),
                defaultExpanded = true,
                items = {},
            }
            sections[classFile or 'UNKNOWN'] = section
            order[#order + 1] = section
        end

        section.items[#section.items + 1] = {
            key = profile.name,
            -- Always the name the string carries, the key only has to stay unique.
            text = CooldownStrings:LayoutName(profile.name),
            icon = profile.icon,
        }
    end

    return order
end

local function PastePrompt()
    NRSKNUI:CreatePrompt({
        title = L['Paste Profile String'],
        text = '',
        editBox = true,
        editBoxLabel = L['Cooldown Manager export string'],
        onAccept = function(profileString)
            if not profileString or profileString == '' then return end

            local tag, name = CooldownStrings.ReadStringInfo(profileString)
            name = CooldownStrings:UniqueName(name or L['Imported Profile'])

            CooldownStrings:Save(name, profileString, 'paste', nil)
            if not tag then
                NRSKNUI:Print(L['Could not read the spec out of that string, pick one on the profile page.'])
            end
            Reopen(name)
        end,
        acceptText = L['Save'],
        cancelText = L['Cancel'],
    })
end

local function CapturePrompt()
    local groups = CooldownStrings:GetAvailableLayouts()
    if not groups[1] then
        NRSKNUI:Print(L['No Cooldown Manager layouts found. Open the Cooldown Manager once first.'])
        return
    end

    local entries = {}
    for index, group in ipairs(groups) do
        if index > 1 then entries[#entries + 1] = { divider = true } end
        entries[#entries + 1] = {
            -- Uncoloured without a class, since ColorTextByClass falls back to the player's own.
            text = group.classFile and NRSKNUI:ColorTextByClass(group.name, group.classFile) or group.name,
            disabled = true,
        }

        for _, layout in ipairs(group.layouts) do
            local _, _, specIcon = CooldownStrings.TagToSpec(layout.tag)
            entries[#entries + 1] = {
                text = SpecLabel(layout.name, specIcon),
                onClick = function()
                    local name = CooldownStrings:UniqueName(layout.name)

                    if layout.layoutID then
                        if not CooldownStrings:Capture(layout.layoutID, name) then return end
                    else
                        CooldownStrings:Save(name, layout.String, 'capture', group.character)
                    end
                    Reopen(name)
                end,
            }
        end
    end

    GUI:ShowContextMenu(entries)
end

---@param name string
local function DeletePrompt(name)
    NRSKNUI:CreatePrompt({
        title = L['Delete Profile'],
        text = format(L["Delete the saved profile '%s'? This cannot be undone."], CooldownStrings:LayoutName(name)),
        onAccept = function()
            CooldownStrings:Delete(name)
            Reopen()
        end,
        acceptText = L['Delete'],
        cancelText = L['Cancel'],
    })
end

-- Cards --

local STATUS_TEXT = {
    match   = { text = L['Matches the live layout'], color = { 0.4, 0.8, 0.4, 1 } },
    drift   = { text = L['Differs from the live layout'], color = { 0.9, 0.7, 0.3, 1 } },
    absent  = { text = L['No layout of this name on this character'], color = { 0.6, 0.6, 0.6, 1 } },
    unknown = { text = L['Open the Cooldown Manager to compare'], color = { 0.6, 0.6, 0.6, 1 } },
}

---@param page KajiGUIPage
local function BuildEnableCard(page, db)
    local card = page:Card(L['CDM Profiles'])

    card:Row(rowH):Checkbox(L['Enable CDM Profiles'], {
        width = 1,
        master = true,
        value = db.Enabled,
        msgPopup = true,
        msgText = L['CDM Profiles'],
        callback = function(checked)
            db.Enabled = checked
            NRSKNUI:ToggleModule('CooldownStrings', checked)
            page:Refresh()
        end,
    })

    card:Separator()

    local infoHeight = 50
    card:Row(infoHeight, 0):Text(NRSKNUI:ColorTextByTheme(L['Functionality Info']), {
        width = 1,
        height = infoHeight,
        autoHeight = true,
        bgMode = 'hide',
        text = {
            L['Backs up Cooldown Manager layouts as profile strings you can restore later.'],
            L['Layouts from your other characters are snapshotted on logout, so they stay available here.'],
        },
    })

    card:Separator()

    local buttonHeight = 34
    card:Row(buttonHeight):Button(L['Open Cooldown Manager Settings'], {
        width = 1,
        height = buttonHeight,
        callback = function()
            local frame = _G['CooldownViewerSettings']
            if frame then
                frame:Show(); frame:Raise()
            else
                NRSKNUI:Print('CooldownViewerSettings not found. Make sure Cooldown Manager is enabled in Edit Mode.')
            end
        end
    })
end

---@param page KajiGUIPage
---@param name string
---@return KajiGUIFluentCard
local function BuildDetailsCard(page, name)
    local entry = CooldownStrings.db.Profiles[name]
    local card = page:Card(L['Backup'], 'all')

    return card:Rebuild(function(built)
        local _, specName, specIcon = CooldownStrings.EntrySpec(entry)
        local status = STATUS_TEXT[CooldownStrings:GetStatus(name)]

        local lines = {
            format('%s: %s', L['Specialization'], specName and SpecLabel(specName, specIcon) or L['Unknown Spec']),
            format('%s: %s', L['Status'], NRSKNUI:ColorText(status.text, status.color)),
        }

        if entry.Character then
            lines[#lines + 1] = format('%s: %s', L['Captured from'], entry.Character)
        end
        if entry.UpdatedAt then
            lines[#lines + 1] = format('%s: %s', L['Last updated'], date('%Y-%m-%d %H:%M', entry.UpdatedAt))
        end

        built:Row(22, 0):Text(nil, {
            width = 1,
            height = 22,
            autoHeight = true,
            bgMode = 'hide',
            text = lines,
        })
    end)
end

---@param page KajiGUIPage
---@param name string
---@param detailsCard KajiGUIFluentCard
local function BuildActionsCard(page, name, detailsCard)
    local card = page:Card(L['Actions'], 'all')

    card:Rebuild(function(built)
        local row = built:Row(rowH)
        row:Button(L['Add / Restore to CDM'], {
            width = 0.5,
            conditions = { 'sameClass' },
            tooltip = L['Adds this backup to the CDM'],
            callback = function() CooldownStrings:PromptRestore(name) end,
        })
        row:Button(L['Sync from CDM'], {
            width = 0.5,
            conditions = { 'hasLiveLayout' },
            tooltip = L['Re-read this backup from the CDM layout of the same name and syncs it.'],
            callback = function()
                CooldownStrings:PromptSync(name, function()
                    built:Rebuild()
                    detailsCard:Rebuild()
                end)
            end,
        })

        local lastRow = built:Row(rowHL)
        lastRow:Button(L['Copy String'], {
            width = 0.5,
            callback = function()
                NRSKNUI:CreateCopyDialog(L['Profile String'], CooldownStrings.db.Profiles[name].String, name)
            end,
        })
        lastRow:Button(L['Delete'], {
            width = 0.5,
            callback = function() DeletePrompt(name) end,
        })
    end)
end

---@param page KajiGUIPage
---@param name string
---@param detailsCard KajiGUIFluentCard
local function BuildStringCard(page, name, detailsCard)
    local entry = CooldownStrings.db.Profiles[name]
    local card = page:Card(L['Profile String'], 'all')

    card:Rebuild(function(built)
        local knownSpec = CooldownStrings.EntrySpec(entry) ~= nil

        -- The row has to be told the height the widget builds itself to: label + box + gap.
        local row = built:Row(EDITBOX_HEIGHT + 18, knownSpec and 0 or nil)
        row:MultiLineEditBox(L['Cooldown Manager export string'], {
            width = 1,
            height = EDITBOX_HEIGHT,
            value = entry.String,
            tooltip = L['CTRL+V to paste, CTRL+A to select all'],
            callback = function(text)
                entry.String = text

                local tag, layoutName = CooldownStrings.ReadStringInfo(text)
                entry.LayoutName = layoutName
                if tag then
                    entry.SpecTag = tag
                    entry.SpecID = CooldownStrings.TagToSpec(tag)
                end

                -- The sidebar shows the layout name, so a new string relabels the entry.
                Reopen(name)
            end,
        })

        -- Only asked for when the string would not say.
        if not knownSpec then
            specOptions = specOptions or BuildSpecOptions()

            built:Row(rowHL, 0):Dropdown(L['Specialization'], {
                width = 1,
                options = specOptions,
                value = entry.SpecID,
                searchable = true,
                callback = function(specID)
                    entry.SpecID = specID
                    Reopen(name)
                end,
            })
        end
    end)
end

-- Page --

GUI:RegisterPage(PAGE, {
    mode = 'clean',
    search = { L['CDM Profiles'], L['Restore to CDM'], L['Sync from CDM'], L['Profile String'] },
    sidebar = {
        buttons = {
            { text = L['Capture from CDM'], onClick = CapturePrompt },
            { text = L['Paste String'],     onClick = PastePrompt },
        },
        items = SidebarItems,
        onContextMenu = function(key, item)
            if item.type == 'header' or not CooldownStrings.db.Profiles[key] then return end

            GUI:ShowContextMenu({
                { text = L['Sync from CDM'], onClick = function() CooldownStrings:PromptSync(key, function() Reopen(key) end) end },
                { divider = true },
                { text = L['Delete'],        onClick = function() DeletePrompt(key) end },
            })
        end,
    },
    build = function(page, _, itemKey)
        local db = NRSKNUI.db.profile.Miscellaneous.CooldownStrings

        page:SetEnabled(function() return db.Enabled end)
        page:SetCondition('hasLiveLayout', function() return itemKey and CooldownStrings:GetLiveLayoutFor(itemKey) ~= nil end)
        page:SetCondition('sameClass', function() return itemKey and CooldownStrings:IsForThisClass(itemKey) end)

        -- Card 1
        BuildEnableCard(page, db)

        if not itemKey or not db.Profiles[itemKey] then
            local card = page:Card(L['Backup'], 'all')

            card:Row(rowHL, 0):Text(L['Help'], {
                width = 1,
                autoHeight = true,
                bgMode = 'hide',
                text = L['Capture a layout out of the Cooldown Manager, or paste a string, using the buttons on the left.'],
            })
            return
        end

        -- Card 2
        local detailsCard = BuildDetailsCard(page, itemKey)
        -- Card 3
        BuildActionsCard(page, itemKey, detailsCard)
        -- Card 4
        BuildStringCard(page, itemKey, detailsCard)
    end,
})
