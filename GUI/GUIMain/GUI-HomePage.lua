-- NorskenUI namespace
---@class NRSKNUI
local NRSKNUI = select(2, ...)
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

-- Localization
local UnitName = UnitName
local UnitClass = UnitClass
local GetRealmName = GetRealmName
local ipairs = ipairs
local ReloadUI = ReloadUI

-- Addon info
local ADDON_VERSION = NRSKNUI.Version
local ADDON_AUTHOR = NRSKNUI.Author

-- Register HomePage content
GUIFrame:RegisterContent("HomePage", function(scrollChild, yOffset)
    local _, class = UnitClass("player")
    local classColor = RAID_CLASS_COLORS[class] or { r = 1, g = 1, b = 1 }

    ----------------------------------------------------------------
    -- Card 1: Welcome Header
    ----------------------------------------------------------------
    local card1 = GUIFrame:CreateCard(scrollChild, "Welcome to NorskenUI", yOffset)

    -- Player greeting
    local playerName = UnitName("player") or "Adventurer"
    local greetingText = "Hello, |cff" ..
        string.format("%02x%02x%02x", classColor.r * 255, classColor.g * 255, classColor.b * 255) ..
        playerName .. "|r!"
    local greetingLabel = card1:AddLabel(greetingText)

    card1:AddSpacing(4)

    -- Version and author info
    local infoText = "Version: |cffffffff" .. ADDON_VERSION .. "|r  -  Author: |cffffffff" .. ADDON_AUTHOR .. "|r"
    local infoLabel = card1:AddLabel(infoText)
    infoLabel:SetTextColor(Theme.textMuted[1], Theme.textMuted[2], Theme.textMuted[3], 1)

    yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 2: Quick Actions
    ----------------------------------------------------------------
    local card2 = GUIFrame:CreateCard(scrollChild, "Quick Actions", yOffset)

    local row1 = GUIFrame:CreateRow(card2.content, 38)

    -- Edit Mode Button
    local editModeBtn = GUIFrame:CreateButton(row1, "Toggle Anchors", {
        width = 140,
        height = 32,
        callback = function()
            if NRSKNUI.EditMode then
                NRSKNUI.EditMode:Toggle()
            end
        end
    })
    row1:AddWidget(editModeBtn, 0.5)

    -- Reload UI Button
    local reloadBtn = GUIFrame:CreateButton(row1, "Reload UI", {
        width = 140,
        height = 32,
        callback = function()
            ReloadUI()
        end
    })
    row1:AddWidget(reloadBtn, 0.5)

    card2:AddRow(row1, 38)

    card2:AddSpacing(4)
    local tipLabel = card2:AddLabel(
        "Use /nui edit to toggle Edit Mode from chat, also note that Edit Mode is very much WIP!")
    tipLabel:SetTextColor(Theme.textMuted[1], Theme.textMuted[2], Theme.textMuted[3], 1)

    yOffset = yOffset + card2:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 1: ElvUI Intergration Card
    ----------------------------------------------------------------
    local ElvUIcard = GUIFrame:CreateCard(scrollChild, "ElvUI Intergration", yOffset)
    local ElvUIDB = NRSKNUI.db.profile.UseElvUI

    -- Enable Checkbox
    local ElvUIrow = GUIFrame:CreateRow(ElvUIcard.content, 40)
    local enableCheck = GUIFrame:CreateCheckbox(ElvUIrow, "Use ElvUI Skinning", ElvUIDB.Enabled ~= false,
        function(checked)
            ElvUIDB.Enabled = checked
            NRSKNUI:CreateReloadPrompt("Disabling/Enabling this requires a reload to take full effect.")
        end,
        true,
        "Use ElvUI",
        "On",
        "Off"
    )
    ElvUIrow:AddWidget(enableCheck, 1)
    ElvUIcard:AddRow(ElvUIrow, 40)

    -- Separator
    local ElvUIsep = GUIFrame:CreateRow(ElvUIcard.content, 8)
    local sepCBCard = GUIFrame:CreateSeparator(ElvUIsep)
    ElvUIsep:AddWidget(sepCBCard, 1)
    ElvUIcard:AddRow(ElvUIsep, 8)

    local rowHeight = 50
    local row = GUIFrame:CreateRow(ElvUIcard.content, rowHeight)
    local textWidget = GUIFrame:CreateText(
        row,
        NRSKNUI:ColorTextByTheme("Information"),
        NRSKNUI:ColorTextByTheme("• ") ..
        "Disables all skinning modules when ElvUI is loaded.\nThis way you can still use the non skinning features of the addon without conflict.",
        rowHeight,
        "hide"
    )
    row:AddWidget(textWidget, 1)
    ElvUIcard:AddRow(row, rowHeight)

    yOffset = yOffset + ElvUIcard:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card MapIcon: Minimap Icon Card
    ----------------------------------------------------------------
    local MapIconcard = GUIFrame:CreateCard(scrollChild, "Minimap Icon", yOffset)
    local MapIconDB = NRSKNUI.db.profile.Minimap

    -- Enable Checkbox
    local MapIconrow = GUIFrame:CreateRow(MapIconcard.content, 36)
    local enableMapIcon = GUIFrame:CreateCheckbox(MapIconrow, "Hide Minimap Icon", MapIconDB.hide ~= false,
        function(checked)
            MapIconDB.hide = checked
        end,
        true,
        "Hide Minimap Icon",
        "On",
        "Off"
    )
    MapIconrow:AddWidget(enableMapIcon, 1)
    MapIconcard:AddRow(MapIconrow, 36)

    yOffset = yOffset + MapIconcard:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 3: Current Profile
    ----------------------------------------------------------------
    local card3 = GUIFrame:CreateCard(scrollChild, "Profile", yOffset)

    local profileName = NRSKNUI.db and NRSKNUI.db:GetCurrentProfile() or "Default"
    local profileLabel = card3:AddLabel("Active Profile: |cffffffff" .. profileName .. "|r")

    card3:AddSpacing(4)

    local realmName = GetRealmName() or "Unknown"
    local charInfo = playerName .. " - " .. realmName
    local charLabel = card3:AddLabel("Character: |cffffffff" .. charInfo .. "|r")
    charLabel:SetTextColor(Theme.textMuted[1], Theme.textMuted[2], Theme.textMuted[3], 1)

    yOffset = yOffset + card3:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 5: Getting Started
    ----------------------------------------------------------------
    local card5 = GUIFrame:CreateCard(scrollChild, "Getting Started", yOffset)

    local tips = {
        "Use the sidebar to navigate between different module settings.",
        "The Theme tab lets you customize colors to match your style.",
        "Edit Mode allows you to drag and reposition UI elements.",
        "Most changes apply instantly without needing reload, however i recommend to always do it anways just to be safe. Modules where reload is required will prompt you to reload.",
    }

    for _, tip in ipairs(tips) do
        local tipLabel2 = card5:AddLabel(NRSKNUI:ColorTextByTheme("• ") .. tip)
        tipLabel2:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
        card5:AddSpacing(2)
    end

    yOffset = yOffset + card5:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 6: Support
    ----------------------------------------------------------------
    local card6 = GUIFrame:CreateCard(scrollChild, "Support", yOffset)

    local supportLabel = card6:AddLabel("Found a bug or have a suggestion?")
    card6:AddSpacing(4)

    local discordLabel = card6:AddLabel("Join the Discord or open an issue on GitHub!")
    discordLabel:SetTextColor(Theme.textMuted[1], Theme.textMuted[2], Theme.textMuted[3], 1)

    yOffset = yOffset + card6:GetContentHeight() + Theme.paddingSmall

    yOffset = yOffset - (Theme.paddingSmall * 3)
    return yOffset
end)
