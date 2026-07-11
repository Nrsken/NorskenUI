---@class NRSKNUI
local NRSKNUI = select(2, ...)
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme
local LSM = NRSKNUI.Libs.LSM

local pairs = pairs

GUIFrame:RegisterContent("GlobalPage", function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.globalMedia
    if not db then return GUIFrame:ShowDBError(scrollChild, yOffset) end

    local fontDB = db.profileFont
    local barDB = db.profileBar

    local manager = GUIFrame:CreateWidgetStateManager()

    local function UpdateAllWidgetStates() manager:UpdateAll(db.Enabled) end

    manager:SetCondition("globFontON", function() return fontDB.Enabled end)
    manager:SetCondition("globBarON", function() return barDB.Enabled end)

    local function ApplyToAllModules()
        for _, module in NRSKNUI:IterateModules() do
            if module:IsEnabled() and module.ApplySettings then
                module:ApplySettings()
            end
        end
    end

    local GlobalFontCard = GUIFrame:CreateCard(scrollChild, "Global Font", yOffset)
    local row1 = GUIFrame:CreateRow(GlobalFontCard.content, Theme.rowHeightLast)
    local globalFontToggle = GUIFrame:CreateCheckbox(row1, "Use Global Font", {
        value = fontDB.Enabled,
        callback = function(checked)
            fontDB.Enabled = checked
            UpdateAllWidgetStates()
            ApplyToAllModules()
            NRSKNUI:RefreshFontStyles()
        end,
        msgPopup = true,
        msgText = "Global Font",
    })
    row1:AddWidget(globalFontToggle, 0.5)

    local fontList = {}
    if LSM then
        for name in pairs(LSM:HashTable("font")) do
            fontList[name] = name
        end
    end

    local fontDropdown = GUIFrame:CreateDropdown(row1, "Font", {
        options = fontList,
        value = fontDB.FontFace,
        callback = function(key)
            fontDB.FontFace = key
            ApplyToAllModules()
            NRSKNUI:RefreshFontStyles()
        end,
        searchable = true,
        isFontPreview = true
    })
    row1:AddWidget(fontDropdown, 0.5)
    manager:Register(fontDropdown, "all", "globFontON")
    GlobalFontCard:AddRow(row1, Theme.rowHeightLast, 0)

    yOffset = GlobalFontCard:GetNextOffset()

    local GlobalBarCard = GUIFrame:CreateCard(scrollChild, "Global Bar", yOffset)
    local row2 = GUIFrame:CreateRow(GlobalBarCard.content, Theme.rowHeightLast)
    local globalBarToggle = GUIFrame:CreateCheckbox(row2, "Use Global Bar Texture", {
        value = barDB.Enabled,
        callback = function(checked)
            barDB.Enabled = checked
            UpdateAllWidgetStates()
            ApplyToAllModules()
        end,
        msgPopup = true,
        msgText = "Global Bar",
    })
    row2:AddWidget(globalBarToggle, 0.5)

    local statusbarList = {}
    if LSM then
        for name in pairs(LSM:HashTable("statusbar")) do
            statusbarList[name] = name
        end
    end

    local barDropdown = GUIFrame:CreateDropdown(row2, "Global Bar Texture", {
        options = statusbarList,
        value = barDB.statusBar,
        callback = function(key)
            barDB.statusBar = key
            ApplyToAllModules()
        end,
        searchable = true,
    })
    row2:AddWidget(barDropdown, 0.5)
    manager:Register(barDropdown, "all", "globBarON")
    GlobalBarCard:AddRow(row2, Theme.rowHeightLast, 0)

    yOffset = GlobalBarCard:GetNextOffset()

    UpdateAllWidgetStates()

    return yOffset
end)
