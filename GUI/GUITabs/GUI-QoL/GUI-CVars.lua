-- NorskenUI namespace
---@class NRSKNUI
local NRSKNUI = select(2, ...)
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

-- Localization Setup
local table_insert = table.insert
local ipairs = ipairs

-- Helper to get MiscVars module
local function GetMiscVarsModule()
    if NorskenUI then
        return NorskenUI:GetModule("MiscVars", true)
    end
    return nil
end

-- Register MiscVars tab content
GUIFrame:RegisterContent("MiscVars", function(scrollChild, yOffset)
    -- Safety check for database
    local db = NRSKNUI.db and NRSKNUI.db.profile.Miscellaneous.MiscVars
    if not db then
        local errorCard = GUIFrame:CreateCard(scrollChild, "Error", yOffset)
        errorCard:AddLabel("Database not available")
        return yOffset + errorCard:GetContentHeight() + Theme.paddingMedium
    end

    -- Get MiscVars module
    local MVAR = GetMiscVarsModule()

    -- Track widgets for enable/disable logic
    local allWidgets = {} -- All widgets (except main toggle)

    -- Comprehensive widget state update
    local function UpdateAllWidgetStates()
        local mainEnabled = db.Enabled ~= false

        -- First: Apply main enable state to ALL widgets
        for _, widget in ipairs(allWidgets) do
            if widget.SetEnabled then
                widget:SetEnabled(mainEnabled)
            end
        end
    end

    ----------------------------------------------------------------
    -- Card 1: CVars, doing this in a for loop so that every cvar defined in MVAR.DEFS, gets its own toggle
    ----------------------------------------------------------------
    local card1 = GUIFrame:CreateCard(scrollChild, "CVars", yOffset)

    if MVAR then
        for i, def in ipairs(MVAR.DEFS) do
            local key = def.key

            local row = GUIFrame:CreateRow(card1.content, 38)

            local checkbox = GUIFrame:CreateCheckbox(
                row,
                def.label,
                db[key],
                function(checked)
                    db[key] = checked

                    -- Suppress CVAR_UPDATE refresh because this came from GUI
                    MVAR._suppressCVarUpdate = true
                    MVAR:ApplySettings()
                    MVAR._suppressCVarUpdate = false
                end
            )

            row:AddWidget(checkbox, 1.0)
            card1:AddRow(row, 38)

            -- Separator only if NOT last
            if i < #MVAR.DEFS then
                local sepRow = GUIFrame:CreateRow(card1.content, 8)
                local sep = GUIFrame:CreateSeparator(sepRow)
                sepRow:AddWidget(sep, 1)
                card1:AddRow(sepRow, 8)
            end
        end
    end

    yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

    -- Apply initial widget states
    UpdateAllWidgetStates()
    yOffset = yOffset - (Theme.paddingSmall)
    return yOffset
end)
