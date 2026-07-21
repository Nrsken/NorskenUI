---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class GUIFrame
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

local table_insert = table.insert
local pairs, ipairs = pairs, ipairs

---On Show / On Hide sound dropdowns with test buttons
---@param scrollChild Frame
---@param yOffset number
---@param config table
---@return table card
---@return number newYOffset
function GUIFrame:CreateSoundSettingsCard(scrollChild, yOffset, config)
    config = config or {}
    local title = config.title or "Sound"
    local db = config.db
    local dbKeys = config.dbKeys or {}
    local onChange = config.onChangeCallback

    local keys = {
        onShowSound = dbKeys.onShowSound or "actionOnShowSound",
        onHideSound = dbKeys.onHideSound or "actionOnHideSound",
    }

    local LSM = NRSKNUI.Libs.LSM
    local soundList = { ["None"] = "None" }
    if LSM then
        for name in pairs(LSM:HashTable("sound")) do
            soundList[name] = name
        end
    end

    local widgets = {}
    local card = GUIFrame:CreateCard(scrollChild, title, yOffset)

    local row1 = GUIFrame:CreateRow(card.content, Theme.rowHeight)
    local onShowDropdown = GUIFrame:CreateDropdown(row1, "On Show", {
        options = soundList,
        value = db[keys.onShowSound] or "None",
        callback = function(key)
            db[keys.onShowSound] = key
            if onChange then onChange() end
        end,
        searchable = true
    })
    row1:AddWidget(onShowDropdown, 0.7)
    table_insert(widgets, onShowDropdown)

    local testShowBtn = GUIFrame:CreateButton(row1, "Test", {
        width = 60,
        height = 24,
        callback = function()
            local soundName = db[keys.onShowSound]
            if soundName and soundName ~= "None" and LSM then
                NRSKNUI:PlaySafeSound(soundName)
            end
        end,
    })
    row1:AddWidget(testShowBtn, 0.3, nil, 0, -14)
    table_insert(widgets, testShowBtn)
    card:AddRow(row1, Theme.rowHeight)

    local row2 = GUIFrame:CreateRow(card.content, Theme.rowHeightLast)
    local onHideDropdown = GUIFrame:CreateDropdown(row2, "On Hide", {
        options = soundList,
        value = db[keys.onHideSound] or "None",
        callback = function(key)
            db[keys.onHideSound] = key
            if onChange then onChange() end
        end,
        searchable = true
    })
    row2:AddWidget(onHideDropdown, 0.7)
    table_insert(widgets, onHideDropdown)

    local testHideBtn = GUIFrame:CreateButton(row2, "Test", {
        width = 60,
        height = 24,
        callback = function()
            local soundName = db[keys.onHideSound]
            if soundName and soundName ~= "None" and LSM then
                NRSKNUI:PlaySafeSound(soundName)
            end
        end,
    })
    row2:AddWidget(testHideBtn, 0.3, nil, 0, -14)
    table_insert(widgets, testHideBtn)
    card:AddRow(row2, Theme.rowHeightLast, 0)

    card.soundWidgets = widgets

    function card:SetEnabled(enabled)
        if enabled then
            self:SetAlpha(1)
        else
            self:SetAlpha(0.5)
        end
        for _, widget in ipairs(self.soundWidgets) do
            if widget.SetEnabled then
                widget:SetEnabled(enabled)
            end
        end
    end

    return card, card:GetNextOffset()
end
