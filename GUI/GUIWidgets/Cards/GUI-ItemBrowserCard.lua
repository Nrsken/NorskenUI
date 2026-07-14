---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class GUIFrame
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

local CreateFrame = CreateFrame
local C_Item = C_Item

local qualityAtlasPattern = "|A:(Professions%-ChatIcon%-Quality%-[^:]+):%d+:%d+"

local TRACK_MODES = {
    { key = "exact",  text = "Exact Rank Only" },
    { key = "auto",   text = "Any Rank (Auto)" },
    { key = "manual", text = "Any Rank (Manual)" },
}

local function ParseItemID(val)
    local id = tonumber(val)
    if not id then id = tonumber(val:match("item:(%d+)")) end
    return id and id > 0 and id or nil
end

---Item browser card with tracking modes, icons, quality overlays, and add/remove buttons
---@param scrollChild Frame
---@param yOffset number
---@param config table
---@return table card
---@return number newYOffset
function GUIFrame:CreateItemBrowserCard(scrollChild, yOffset, config)
    config = config or {}
    local title = config.title or "Item IDs"
    local items = config.items or {}
    local trackingMode = config.trackingMode or "manual"
    local onItemRemove = config.onItemRemove
    local onItemAdd = config.onItemAdd
    local onTrackingModeChange = config.onTrackingModeChange

    local card = GUIFrame:CreateCard(scrollChild, title, yOffset)

    local modeRow = GUIFrame:CreateRow(card.content, Theme.rowHeight)
    local modeDropdown = GUIFrame:CreateDropdown(modeRow, "Tracking Mode", {
        options = TRACK_MODES,
        value = trackingMode,
        callback = function(key)
            if onTrackingModeChange then
                C_Timer.After(0.2, function()
                    onTrackingModeChange(key)
                end)
            end
        end
    })
    modeRow:AddWidget(modeDropdown, 1)
    card:AddRow(modeRow, Theme.rowHeight)

    local sep1 = GUIFrame:CreateSeparator(card.content)
    card:AddRow(sep1, Theme.rowHeightSeparator)

    local function CreateItemRow(itemData, allowRemove)
        local currentItemID = itemData.itemID
        local rank = itemData.rank or 1
        local isAutoDetected = itemData.isAutoDetected

        local itemRow = GUIFrame:CreateRow(card.content, 28)

        itemRow:EnableMouse(true)
        local capturedItemID = currentItemID

        local iconFrame = CreateFrame("Frame", nil, itemRow)
        iconFrame:SetSize(24, 24)
        iconFrame:SetPoint("LEFT", itemRow, "LEFT", 0, 0)

        local iconTexture = iconFrame:CreateTexture(nil, "ARTWORK")
        iconTexture:SetPoint("TOPLEFT", 1, -1)
        iconTexture:SetPoint("BOTTOMRIGHT", -1, 1)
        local itemIcon = C_Item.GetItemIconByID(currentItemID)
        iconTexture:SetTexture(itemIcon or 134400)
        iconTexture:SetZoom()

        local iconBorder = CreateFrame("Frame", nil, iconFrame, "BackdropTemplate")
        iconBorder:SetAllPoints()
        iconBorder:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        iconBorder:SetBackdropBorderColor(0, 0, 0, 1)

        local qualityFrame = CreateFrame("Frame", nil, iconFrame)
        qualityFrame:SetFrameLevel(iconFrame:GetFrameLevel() + 10)
        qualityFrame:SetSize(16, 16)
        qualityFrame:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", -5, 5)

        local qualityTexture = qualityFrame:CreateTexture(nil, "OVERLAY")
        qualityTexture:SetAllPoints()
        qualityTexture:Hide()

        local function TrySetQuality()
            local _, itemLink = C_Item.GetItemInfo(currentItemID)
            if itemLink then
                local atlas = itemLink:match(qualityAtlasPattern)
                if atlas then
                    qualityTexture:SetAtlas(atlas, false)
                    qualityTexture:Show()
                    return true
                end
            end
            return false
        end

        if not TrySetQuality() then
            local item = Item:CreateFromItemID(currentItemID)
            item:ContinueOnItemLoad(function()
                TrySetQuality()
            end)
        end

        local displayName = C_Item.GetItemNameByID(currentItemID) or ("Item " .. currentItemID)
        local labelText = displayName .. "|cffffffff (" .. currentItemID .. ")|r"
        if isAutoDetected then
            labelText = labelText .. " |cff888888[auto]|r"
        end

        local itemLabel = itemRow:CreateFontString(nil, "OVERLAY")
        itemLabel:SetPoint("LEFT", iconFrame, "RIGHT", 6, 0)
        itemLabel:SetPoint("RIGHT", itemRow, "RIGHT", allowRemove and -90 or 0, 0)
        itemLabel:SetJustifyH("LEFT")
        NRSKNUI:ApplyThemeFont(itemLabel, "small")
        itemLabel:SetText(labelText)
        itemLabel:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)

        if allowRemove then
            local capturedRank = rank
            local removeBtn = GUIFrame:CreateButton(itemRow, "Remove", {
                width = 80,
                height = 22,
                callback = function()
                    if onItemRemove then
                        onItemRemove(capturedItemID, capturedRank)
                    end
                end,
            })
            removeBtn:SetPoint("RIGHT", itemRow, "RIGHT", 0, 0)
        end

        return itemRow
    end

    if trackingMode == "exact" then
        if #items > 0 then
            local primaryItem = items[1]
            local itemRow = CreateItemRow(primaryItem, true)
            card:AddRow(itemRow, 28)
        else
            local emptyRow = GUIFrame:CreateRow(card.content, 30)
            local emptyLabel = emptyRow:CreateFontString(nil, "OVERLAY")
            emptyLabel:SetPoint("LEFT", emptyRow, "LEFT", 4, 0)
            NRSKNUI:ApplyThemeFont(emptyLabel, "small")
            emptyLabel:SetText("No item set.")
            emptyLabel:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
            card:AddRow(emptyRow, 30)

            local separatorAdd = GUIFrame:CreateSeparator(card.content)
            card:AddRow(separatorAdd, Theme.rowHeightSeparator)

            local addRow = GUIFrame:CreateRow(card.content, Theme.rowHeight)
            local addInput
            addInput = GUIFrame:CreateEditBox(addRow, "Item ID", {
                value = "",
                callback = function()
                    local id = ParseItemID(addInput:GetValue())
                    if id and onItemAdd then onItemAdd(id); addInput:SetValue("") end
                end,
            })
            addRow:AddWidget(addInput, 0.7)

            local addBtn = GUIFrame:CreateButton(addRow, "Set", {
                height = 24,
                callback = function()
                    local id = ParseItemID(addInput:GetValue())
                    if id and onItemAdd then onItemAdd(id); addInput:SetValue("") end
                end,
            })
            addRow:AddWidget(addBtn, 0.3, nil, 0, -14)
            card:AddRow(addRow, Theme.rowHeight)
        end
    elseif trackingMode == "auto" then
        local infoRow = GUIFrame:CreateRow(card.content, 20)
        local infoLabel = infoRow:CreateFontString(nil, "OVERLAY")
        infoLabel:SetPoint("LEFT", infoRow, "LEFT", 4, 0)
        NRSKNUI:ApplyThemeFont(infoLabel, "small")
        infoLabel:SetText("|cff888888Automatically counts all items with the same name|r")
        infoLabel:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
        card:AddRow(infoRow, 20)

        local infoSep = GUIFrame:CreateSeparator(card.content)
        card:AddRow(infoSep, Theme.rowHeightSeparator)

        if #items > 0 then
            local primaryItem = items[1]
            local itemRow = CreateItemRow(primaryItem, true)
            card:AddRow(itemRow, 28)
        else
            local emptyRow = GUIFrame:CreateRow(card.content, 30)
            local emptyLabel = emptyRow:CreateFontString(nil, "OVERLAY")
            emptyLabel:SetPoint("LEFT", emptyRow, "LEFT", 4, 0)
            NRSKNUI:ApplyThemeFont(emptyLabel, "small")
            emptyLabel:SetText("No item set.")
            emptyLabel:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
            card:AddRow(emptyRow, 30)

            local separatorAdd = GUIFrame:CreateSeparator(card.content)
            card:AddRow(separatorAdd, Theme.rowHeightSeparator)

            local addRow = GUIFrame:CreateRow(card.content, Theme.rowHeight)
            local addInput
            addInput = GUIFrame:CreateEditBox(addRow, "Item ID", {
                value = "",
                callback = function()
                    local id = ParseItemID(addInput:GetValue())
                    if id and onItemAdd then onItemAdd(id); addInput:SetValue("") end
                end,
            })
            addRow:AddWidget(addInput, 0.7)

            local addBtn = GUIFrame:CreateButton(addRow, "Set", {
                height = 24,
                callback = function()
                    local id = ParseItemID(addInput:GetValue())
                    if id and onItemAdd then onItemAdd(id); addInput:SetValue("") end
                end,
            })
            addRow:AddWidget(addBtn, 0.3, nil, 0, -14)
            card:AddRow(addRow, Theme.rowHeight)
        end
    else -- manual mode
        for _, itemData in ipairs(items) do
            local itemRow = CreateItemRow(itemData, true)
            card:AddRow(itemRow, 28)
        end

        if #items == 0 then
            local emptyRow = GUIFrame:CreateRow(card.content, 30)
            local emptyLabel = emptyRow:CreateFontString(nil, "OVERLAY")
            emptyLabel:SetPoint("LEFT", emptyRow, "LEFT", 4, 0)
            NRSKNUI:ApplyThemeFont(emptyLabel, "small")
            emptyLabel:SetText("No items added yet.")
            emptyLabel:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
            card:AddRow(emptyRow, 30)
        end

        local separatorAdd = GUIFrame:CreateSeparator(card.content)
        card:AddRow(separatorAdd, Theme.rowHeightSeparator)

        local addRow = GUIFrame:CreateRow(card.content, Theme.rowHeight)
        local addInput
        addInput = GUIFrame:CreateEditBox(addRow, "Add Item ID", {
            value = "",
            callback = function()
                local id = ParseItemID(addInput:GetValue())
                if id and onItemAdd then onItemAdd(id); addInput:SetValue("") end
            end,
        })
        addRow:AddWidget(addInput, 0.7)

        local addBtn = GUIFrame:CreateButton(addRow, "Add", {
            height = 24,
            callback = function()
                local id = ParseItemID(addInput:GetValue())
                if id and onItemAdd then onItemAdd(id); addInput:SetValue("") end
            end,
        })
        addRow:AddWidget(addBtn, 0.3, nil, 0, -14)
        card:AddRow(addRow, Theme.rowHeight)
    end

    return card, card:GetNextOffset()
end
