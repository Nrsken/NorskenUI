---@class NRSKNUI
local NRSKNUI = select(2, ...)
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme or {}

local ipairs = ipairs
local CreateFrame = CreateFrame
local table_insert = table.insert
local C_Timer = C_Timer

local DUNGEON_ORDER = {
    { key = "MagistersTerrace",  name = "Magisters' Terrace",      iconID = 7439625 },
    { key = "MaisaraCaverns",    name = "Maisara Caverns",         iconID = 7322719 },
    { key = "NexusPointXenas",   name = "Nexus-Point Xenas",       iconID = 7553062 },
    { key = "WindrunnerSpire",   name = "Windrunner Spire",        iconID = 7266215 },
    { key = "AlgetharAcademy",   name = "Algeth'ar Academy",       iconID = 4578414 },
    { key = "PitOfSaron",        name = "Pit of Saron",            iconID = 343641 },
    { key = "SeatOfTriumvirate", name = "Seat of the Triumvirate", iconID = 1711340 },
    { key = "Skyreach",          name = "Skyreach",                iconID = 1002596 },
}

local function GetSettingsDB()
    if not NRSKNUI.db or not NRSKNUI.db.profile then return nil end
    return NRSKNUI.db.profile.DungeonTimers
end

local function CreateSpellIconPreview(parent, iconId, size)
    size = size or 32
    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(size)

    local iconFrame = CreateFrame("Frame", nil, container)
    iconFrame:SetSize(size, size)
    iconFrame:SetPoint("LEFT", container, "LEFT", 0, 0)

    iconFrame.texture = iconFrame:CreateTexture(nil, "ARTWORK")
    iconFrame.texture:SetPoint("TOPLEFT", 1, -1)
    iconFrame.texture:SetPoint("BOTTOMRIGHT", -1, 1)

    local texture = iconId
    if texture then
        iconFrame.texture:SetTexture(texture)
        if NRSKNUI.ApplyZoom then
            iconFrame.texture:SetZoom()
        end
    else
        iconFrame.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end

    local border = CreateFrame("Frame", nil, iconFrame, "BackdropTemplate")
    border:SetAllPoints()
    border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    border:SetBackdropBorderColor(0, 0, 0, 1)

    return container
end

GUIFrame:RegisterContent("DT_General", function(scrollChild, yOffset)
    local DT_GUI = NRSKNUI.GUI and NRSKNUI.GUI.DungeonTimers
    if DT_GUI then
        if DT_GUI.HideBarPreviews then DT_GUI.HideBarPreviews() end
        if DT_GUI.HideTextPreviews then DT_GUI.HideTextPreviews() end
    end

    local db = GetSettingsDB()
    if not db then return yOffset end

    local DT = NRSKNUI:GetModule("DungeonTimers", true)
    local manager = GUIFrame:CreateWidgetStateManager()
    local activeCards = {}

    local function ApplyModuleState(enabled)
        if not DT then return end
        db.Enabled = enabled
        if enabled then
            NRSKNUI:EnableModule("DungeonTimers")
        else
            NRSKNUI:DisableModule("DungeonTimers")
        end
        manager:UpdateAll(enabled)
    end

    local card1 = GUIFrame:CreateCard(scrollChild, "Dungeon Timers", yOffset)
    table_insert(activeCards, card1)

    local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeightLast)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Dungeon Timers", {
        value = db.Enabled ~= false,
        callback = function(checked)
            ApplyModuleState(checked)
        end,
        msgPopup = true,
        msgText = "Dungeon Timers",
    })
    row1:AddWidget(enableCheck, 1)
    card1:AddRow(row1, Theme.rowHeightLast, 0)
    yOffset = card1:GetNextOffset()

    local card2 = GUIFrame:CreateCard(scrollChild, "Import / Export", yOffset)
    table_insert(activeCards, card2)
    manager:Register(card2, "all")

    local padding = 0
    local buttonWidth = 100
    local buttonHeight = 28
    local buttonSpacing = Theme.paddingSmall

    local function RefreshAfterImport()
        if DT and DT.ApplySettings then DT:ApplySettings() end
        C_Timer.After(0.1, function()
            GUIFrame:RefreshContent()
        end)
    end

    local rowAll = GUIFrame:CreateRow(card2.content, 32)

    local iconPAll = CreateSpellIconPreview(rowAll, 525134, 28)
    rowAll:AddWidget(iconPAll, 0.5)

    local labelAll = rowAll:CreateFontString(nil, "OVERLAY")
    NRSKNUI:ApplyThemeFont(labelAll, "normal")
    labelAll:SetText("All Dungeons")
    labelAll:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    labelAll:SetPoint("LEFT", rowAll, "LEFT", padding + 28 + Theme.paddingSmall, 0)

    local exportAllBtn = GUIFrame:CreateButton(rowAll, "Export", {
        tooltip = "Export timers for all dungeons",
        width = buttonWidth,
        height = buttonHeight,
        callback = function()
            if not DT then return end
            local exportString, err = DT:ExportAllDungeonTimers()
            if exportString then
                NRSKNUI:CreateCopyDialog("Export All Timers", exportString, "Copy this string to share")
            else
                NRSKNUI:Print("Export failed: " .. (err or "Unknown error"))
            end
        end
    })
    exportAllBtn:SetPoint("RIGHT", rowAll, "RIGHT", -padding - (buttonWidth + buttonSpacing) * 3, 0)
    manager:Register(exportAllBtn, "all")

    local importAllBtn = GUIFrame:CreateButton(rowAll, "Import", {
        width = buttonWidth,
        height = buttonHeight,
        tooltip = "Import timers for all dungeons",
        callback = function()
            NRSKNUI:CreatePrompt({
                title = "Import All Timers",
                text = "",
                editBox = true,
                editBoxLabel = "Paste import string",
                onAccept = function(inputText)
                    if not DT then return end
                    local success, result = DT:ImportAllDungeonTimers(inputText)
                    if success then
                        NRSKNUI:Print("Import successful: " .. result)
                        RefreshAfterImport()
                    else
                        NRSKNUI:Print("Import failed: " .. (result or "Unknown error"))
                    end
                end,
                acceptText = "Import",
                cancelText = "Cancel",
            })
        end
    })
    importAllBtn:SetPoint("RIGHT", rowAll, "RIGHT", -padding - (buttonWidth + buttonSpacing) * 2, 0)
    manager:Register(importAllBtn, "all")

    local importNUIAllBtn = GUIFrame:CreateButton(rowAll, "NUI", {
        width = buttonWidth,
        height = buttonHeight,
        tooltip = "Import NUI presets for all dungeons",
        callback = function()
            if not DT then return end
            local success, result = DT:ImportAllNUIPresets()
            if success then
                NRSKNUI:Print("NUI Presets imported: " .. result)
                RefreshAfterImport()
            else
                NRSKNUI:Print("Import failed: " .. (result or "No presets available"))
            end
        end
    })
    importNUIAllBtn:SetPoint("RIGHT", rowAll, "RIGHT", -padding - (buttonWidth + buttonSpacing), 0)
    manager:Register(importNUIAllBtn, "all")

    local resetAllBtn = GUIFrame:CreateButton(rowAll, "Reset", {
        tooltip = "Reset timers for all dungeons",
        width = buttonWidth,
        height = buttonHeight,
        callback = function()
            NRSKNUI:CreatePrompt({
                title = "Reset All Timers",
                text = "Are you sure you want to clear ALL timers from ALL dungeons?\n\nThis cannot be undone.",
                onAccept = function()
                    if not DT then return end
                    local success, result = DT:ResetAllDungeonTimers()
                    if success then
                        NRSKNUI:Print("Reset successful: " .. result)
                        RefreshAfterImport()
                    else
                        NRSKNUI:Print("Reset failed: " .. (result or "Unknown error"))
                    end
                end,
                acceptText = "Reset All",
                cancelText = "Cancel",
            })
        end
    })
    resetAllBtn:SetPoint("RIGHT", rowAll, "RIGHT", 0, 0)
    manager:Register(resetAllBtn, "all")

    card2:AddRow(rowAll, 32)

    local sepRow = GUIFrame:CreateRow(card2.content, 8)
    local sep = GUIFrame:CreateSeparator(sepRow)
    sepRow:AddWidget(sep, 1)
    card2:AddRow(sepRow, 8)

    for i, dungeon in ipairs(DUNGEON_ORDER) do
        local dungeonKey = dungeon.key
        local dungeonName = dungeon.name
        local iconID = dungeon.iconID
        local isLast = (i == #DUNGEON_ORDER)
        local rowHeight = 32

        local dungeonRow = GUIFrame:CreateRow(card2.content, rowHeight)

        local iconPreview = CreateSpellIconPreview(dungeonRow, iconID, 28 - 2)
        dungeonRow:AddWidget(iconPreview, 0.5)

        local dungeonLabel = dungeonRow:CreateFontString(nil, "OVERLAY")
        NRSKNUI:ApplyThemeFont(dungeonLabel, "small")
        dungeonLabel:SetText(dungeonName)
        dungeonLabel:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
        dungeonLabel:SetPoint("LEFT", dungeonRow, "LEFT", padding + 28 + Theme.paddingSmall, 0)

        local exportBtn = GUIFrame:CreateButton(dungeonRow, "Export", {
            width = buttonWidth,
            height = buttonHeight - 2,
            tooltip = "Export timers for " .. dungeonName,
            callback = function()
                if not DT then return end
                local exportString, err = DT:ExportDungeonTimers(dungeonKey)
                if exportString then
                    NRSKNUI:CreateCopyDialog("Export: " .. dungeonName, exportString, "Copy this string to share")
                else
                    NRSKNUI:Print("Export failed: " .. (err or "Unknown error"))
                end
            end
        })
        exportBtn:SetPoint("RIGHT", dungeonRow, "RIGHT", -padding - (buttonWidth + buttonSpacing) * 3, 0)
        manager:Register(exportBtn, "all")

        local importBtn = GUIFrame:CreateButton(dungeonRow, "Import", {
            width = buttonWidth,
            height = buttonHeight - 2,
            tooltip = "Import timers for " .. dungeonName,
            callback = function()
                NRSKNUI:CreatePrompt({
                    title = "Import: " .. dungeonName,
                    text = "",
                    editBox = true,
                    editBoxLabel = "Paste import string",
                    onAccept = function(inputText)
                        if not DT then return end
                        local success, result = DT:ImportDungeonTimers(inputText, dungeonKey)
                        if success then
                            NRSKNUI:Print("Import successful: " .. result)
                            RefreshAfterImport()
                        else
                            NRSKNUI:Print("Import failed: " .. (result or "Unknown error"))
                        end
                    end,
                    acceptText = "Import",
                    cancelText = "Cancel",
                })
            end
        })
        importBtn:SetPoint("RIGHT", dungeonRow, "RIGHT", -padding - (buttonWidth + buttonSpacing) * 2, 0)
        manager:Register(importBtn, "all")

        local importNUIBtn = GUIFrame:CreateButton(dungeonRow, "NUI", {
            width = buttonWidth,
            height = buttonHeight - 2,
            tooltip = "Import NUI presets for " .. dungeonName,
            callback = function()
                if not DT then return end
                local success, result = DT:ImportNUIPreset(dungeonKey)
                if success then
                    NRSKNUI:Print("NUI Preset imported: " .. result)
                    RefreshAfterImport()
                else
                    NRSKNUI:Print("Import failed: " .. (result or "No presets available"))
                end
            end
        })
        importNUIBtn:SetPoint("RIGHT", dungeonRow, "RIGHT", -padding - (buttonWidth + buttonSpacing), 0)
        manager:Register(importNUIBtn, "all")

        local resetBtn = GUIFrame:CreateButton(dungeonRow, "Reset", {
            tooltip = "Reset timers for " .. dungeonName,
            width = buttonWidth,
            height = buttonHeight - 2,
            callback = function()
                NRSKNUI:CreatePrompt({
                    title = "Reset: " .. dungeonName,
                    text = "Are you sure you want to clear all timers for " .. dungeonName .. "?\n\nThis cannot be undone.",
                    onAccept = function()
                        if not DT then return end
                        local success, result = DT:ResetDungeonTimers(dungeonKey)
                        if success then
                            NRSKNUI:Print("Reset successful: " .. result)
                            RefreshAfterImport()
                        else
                            NRSKNUI:Print("Reset failed: " .. (result or "Unknown error"))
                        end
                    end,
                    acceptText = "Reset",
                    cancelText = "Cancel",
                })
            end
        })
        resetBtn:SetPoint("RIGHT", dungeonRow, "RIGHT", -padding, 0)
        manager:Register(resetBtn, "all")

        card2:AddRow(dungeonRow, rowHeight, isLast and 0 or nil)
    end

    yOffset = card2:GetNextOffset()
    manager:UpdateAll(db.Enabled ~= false)

    return yOffset
end)
