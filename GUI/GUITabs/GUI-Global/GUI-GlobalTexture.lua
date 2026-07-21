---@class NRSKNUI
local NRSKNUI = select(2, ...)
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme
local LSM = NRSKNUI.Libs.LSM

GUIFrame:RegisterContent('global_textures', function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.globalMedia.profileBar
    if not db then return GUIFrame:ShowDBError(scrollChild, yOffset) end

    local manager = GUIFrame:CreateWidgetStateManager()
    local function UpdateAllWidgetStates() manager:UpdateAll(db.Enabled) end
    manager:SetCondition('globBarON', function() return db.Enabled end)

    local GlobalBarCard = GUIFrame:CreateCard(scrollChild, 'Global Bar', yOffset)
    local row2 = GUIFrame:CreateRow(GlobalBarCard.content, Theme.rowHeightLast)
    local globalBarToggle = GUIFrame:CreateCheckbox(row2, 'Use Global Bar Texture', {
        value = db.Enabled,
        callback = function(checked)
            db.Enabled = checked
            UpdateAllWidgetStates()
            NRSKNUI:ApplyToAllModules()
        end,
        msgPopup = true,
        msgText = 'Global Bar',
    })
    row2:AddWidget(globalBarToggle, 0.5)

    local statusbarList = {}
    if LSM then
        for name in pairs(LSM:HashTable('statusbar')) do
            statusbarList[name] = name
        end
    end

    local barDropdown = GUIFrame:CreateDropdown(row2, 'Global Bar Texture', {
        options = statusbarList,
        value = db.statusBar,
        callback = function(key)
            db.statusBar = key
            NRSKNUI:ApplyToAllModules()
        end,
        searchable = true,
    })
    row2:AddWidget(barDropdown, 0.5)
    manager:Register(barDropdown, 'all', 'globBarON')
    GlobalBarCard:AddRow(row2, Theme.rowHeightLast, 0)

    yOffset = GlobalBarCard:GetNextOffset()

    UpdateAllWidgetStates()

    return yOffset
end)
