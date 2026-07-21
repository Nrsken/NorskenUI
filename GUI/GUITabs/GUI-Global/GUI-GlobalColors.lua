---@class NRSKNUI
local NRSKNUI = select(2, ...)
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme
local rowHLast = Theme.rowHeightLast
local rowH = Theme.rowHeight

local min = math.min

-- { key, label } specs drive the color-picker grids below. key indexes db.profile.Colors.<category>.
local PowerColorSpecs = {
    { key = 0,  label = 'Mana' },
    { key = 1,  label = 'Rage' },
    { key = 2,  label = 'Focus' },
    { key = 3,  label = 'Energy' },
    { key = 6,  label = 'Runic Power' },
    { key = 8,  label = 'Lunar Power' },
    { key = 11, label = 'Maelstrom' },
    { key = 13, label = 'Insanity' },
    { key = 17, label = 'Fury' },
    { key = 18, label = 'Pain' },
}

local ReactionColorSpecs = {
    { key = 1, label = 'Hated' },
    { key = 2, label = 'Hostile' },
    { key = 3, label = 'Unfriendly' },
    { key = 4, label = 'Neutral' },
    { key = 5, label = 'Friendly' },
    { key = 6, label = 'Honored' },
    { key = 7, label = 'Revered' },
    { key = 8, label = 'Exalted' },
}

local ClassColorSpecs = {
    { key = 'DEATHKNIGHT', label = 'Death Knight' },
    { key = 'DEMONHUNTER', label = 'Demon Hunter' },
    { key = 'DRUID',       label = 'Druid' },
    { key = 'EVOKER',      label = 'Evoker' },
    { key = 'HUNTER',      label = 'Hunter' },
    { key = 'MAGE',        label = 'Mage' },
    { key = 'MONK',        label = 'Monk' },
    { key = 'PALADIN',     label = 'Paladin' },
    { key = 'PRIEST',      label = 'Priest' },
    { key = 'ROGUE',       label = 'Rogue' },
    { key = 'SHAMAN',      label = 'Shaman' },
    { key = 'WARLOCK',     label = 'Warlock' },
    { key = 'WARRIOR',     label = 'Warrior' },
}

local StatusColorSpecs = {
    { key = 'Tapped',       label = 'Tapped' },
    { key = 'Disconnected', label = 'Disconnected' },
    { key = 'Dead',         label = 'Dead' },
}

GUIFrame:RegisterContent('global_colors', function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.Colors
    if not db then return GUIFrame:ShowDBError(scrollChild, yOffset) end

    local manager = GUIFrame:CreateWidgetStateManager()
    local function UpdateAllWidgetStates() manager:UpdateAll(db.Enabled) end

    local function RefreshColors()
        NRSKNUI:LoadCustomColors()
        NRSKNUI:ApplyToAllModules()
    end

    -- Build one card of color pickers laid out three per row from a { key, label } spec list.
    local function BuildColorCard(title, dbTable, specs, storeAlpha)
        local card = GUIFrame:CreateCard(scrollChild, title, yOffset)
        local count = #specs

        for i = 1, count, 3 do
            local isLast = (i + 2) >= count
            local rowHeight = (isLast and rowHLast) or rowH
            local row = GUIFrame:CreateRow(card.content, rowHeight)

            for j = i, min(i + 2, count) do
                local spec = specs[j]

                local picker = GUIFrame:CreateColorPicker(row, spec.label, {
                    color = dbTable[spec.key],
                    callback = function(r, g, b, a)
                        dbTable[spec.key] = storeAlpha and { r, g, b, a } or { r, g, b }
                        RefreshColors()
                    end,
                })
                row:AddWidget(picker, 1 / 3)
            end
            card:AddRow(row, rowHeight, isLast and 0 or nil)
        end
        yOffset = card:GetNextOffset()
    end

    BuildColorCard('Power Colors', db.Power, PowerColorSpecs, false)
    BuildColorCard('Reaction Colors', db.Reaction, ReactionColorSpecs, false)
    BuildColorCard('Class Colors', db.Class, ClassColorSpecs, false)
    BuildColorCard('Status Colors', db.Status, StatusColorSpecs, true)

    UpdateAllWidgetStates()

    return yOffset
end)
