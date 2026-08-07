---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local function ApplySettings(unit) UF:ApplySettings(unit) end

local GrowthOptions = NRSKNUI.GrowthOptions

local SortByOptions = {
    { value = 'INDEX', text = L['Index'] },
    { value = 'NAME',  text = L['Name'] },
    { value = 'CLASS', text = L['Class'] },
    { value = 'ROLE',  text = L['Role'] },
}

local SortMethodOptions = {
    { value = 'INDEX', text = L['Index'] },
    { value = 'NAME',  text = L['Name'] },
}

local SortDirectionOptions = {
    { value = 'ASC',  text = L['Ascending'] },
    { value = 'DESC', text = L['Descending'] },
}

local RoleOptions = {
    { value = 'TANK',    text = L['Tank'] },
    { value = 'HEALER',  text = L['Healer'] },
    { value = 'DAMAGER', text = L['DPS'] },
}

---@param page table
---@param uDB table
---@param unit string
local function BuildGroupSection(page, uDB, unit)
    local gDB = uDB.Group

    -- INDEX and NAME already imply the sort, so the method dropdown does nothing for them.
    page:SetCondition('groupSorted', function() return gDB.SortBy ~= 'INDEX' and gDB.SortBy ~= 'NAME' end)
    page:SetCondition('groupByRole', function() return gDB.SortBy == 'ROLE' end)

    -- Card 1: Layout
    local layoutCard = page:Card(L['Group'], 'unitOn')
    local growthRow = layoutCard:Row(rowH)
    growthRow:Dropdown(L['Growth Direction'], {
        width = 0.5,
        options = GrowthOptions,
        value = gDB.GrowthDirection,
        callback = function(key)
            gDB.GrowthDirection = key; ApplySettings(unit)
        end,
    })
    growthRow:Checkbox(L['Display Player'], {
        width = 0.5,
        tooltip = L['Include the player when not in a raid.'],
        value = gDB.ShowPlayer,
        callback = function(checked)
            gDB.ShowPlayer = checked; ApplySettings(unit)
        end,
    })

    local spacingRow = layoutCard:Row(rowHL, 0)
    spacingRow:Slider(L['Horizontal Spacing'], {
        width = 0.5,
        min = 0,
        max = 50,
        step = 1,
        value = gDB.HorizontalSpacing,
        callback = function(val)
            gDB.HorizontalSpacing = val; ApplySettings(unit)
        end,
        callbackOnRelease = true,
    })
    spacingRow:Slider(L['Vertical Spacing'], {
        width = 0.5,
        min = 0,
        max = 50,
        step = 1,
        value = gDB.VerticalSpacing,
        callback = function(val)
            gDB.VerticalSpacing = val; ApplySettings(unit)
        end,
        callbackOnRelease = true,
    })

    -- Card 2: Sorting
    local sortCard = page:Card(L['Grouping & Sorting'], 'unitOn')
    local sortRow = sortCard:Row(rowH)
    sortRow:Dropdown(L['Group By'], {
        width = 0.5,
        options = SortByOptions,
        value = gDB.SortBy,
        callback = function(key)
            gDB.SortBy = key
            ApplySettings(unit)
            page:Refresh()
        end,
    })
    sortRow:Dropdown(L['Sort Direction'], {
        width = 0.5,
        options = SortDirectionOptions,
        value = gDB.SortDirection,
        callback = function(key)
            gDB.SortDirection = key; ApplySettings(unit)
        end,
    })

    local methodRow = sortCard:Row(rowHL, 0)
    methodRow:Dropdown(L['Sort Method'], {
        width = 0.5,
        conditions = { 'groupSorted' },
        options = SortMethodOptions,
        value = gDB.SortMethod,
        callback = function(key)
            gDB.SortMethod = key; ApplySettings(unit)
        end,
    })
    methodRow:Checkbox(L['Start Near Center'], {
        width = 0.5,
        tooltip = L['Grow outward from the middle rather than from one end.'],
        value = gDB.StartFromCenter,
        callback = function(checked)
            gDB.StartFromCenter = checked; ApplySettings(unit)
        end,
    })

    -- Card 3: Role order, only live when grouping by role.
    local roleCard = page:Card(L['Role Order'], 'unitOn')
    local roleRow = roleCard:Row(rowHL, 0)
    for index = 1, 3 do
        roleRow:Dropdown(L['Prio: '] .. index, {
            width = 1 / 3,
            conditions = { 'groupByRole' },
            options = RoleOptions,
            value = gDB.RoleOrder[index],
            callback = function(key)
                gDB.RoleOrder[index] = key; ApplySettings(unit)
            end,
        })
    end

    -- Card 4: Visibility
    local visCard = page:Card(L['Visibility'], 'unitOn')
    local visRow = visCard:Row(rowHL, 0)
    visRow:EditBox(L['Visibility Macro'], {
        width = 0.75,
        tooltip = L['Macro conditionals deciding when these frames are shown.'],
        value = gDB.Visibility,
        callback = function(val)
            gDB.Visibility = val; ApplySettings(unit)
        end,
    })
    visRow:Button(L['Restore Default'], {
        yOffset = -14,
        height = 24,
        width = 0.25,
        callback = function()
            gDB.Visibility = NRSKNUI:GetDefaultDB().profile.UnitFrames.Units[unit].Group.Visibility
            ApplySettings(unit)
            page:Refresh()
        end,
    })
end

UF.GUISections.group = BuildGroupSection

UF.GUIGroupSearch = {
    L['Group'],
    L['Growth Direction'],
    L['Display Player'],
    L['Horizontal Spacing'],
    L['Vertical Spacing'],
    L['Grouping & Sorting'],
    L['Group By'],
    L['Sort Method'],
    L['Sort Direction'],
    L['Role Order'],
    L['Start Near Center'],
    L['Visibility'],
    L['Visibility Macro'],
}
