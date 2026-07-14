---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class GUIFrame
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

local table_insert = table.insert
local ipairs = ipairs
local CreateFrame = CreateFrame

---BigWigs spell browser with search, grouped by boss
---@param scrollChild Frame
---@param yOffset number
---@param config table
---@return table|nil card
---@return number newYOffset
function GUIFrame:CreateSpellBrowserCard(scrollChild, yOffset, config)
    config = config or {}
    local title = config.title or "Browse BigWigs Spells"
    local spells = config.spells or {}
    local searchFilter = config.searchFilter or ""
    local onSearchChange = config.onSearchChange
    local onSpellSelect = config.onSpellSelect

    if #spells == 0 then
        local noBwCard = GUIFrame:CreateCard(scrollChild, "BigWigs Spell Browser", yOffset)
        noBwCard:AddLabel(
            "No BigWigs data available for this dungeon. Make sure BigWigs is installed and the dungeon module is loaded.")
        return noBwCard, noBwCard:GetNextOffset()
    end

    local card = GUIFrame:CreateCard(scrollChild, title, yOffset)

    local searchRow = GUIFrame:CreateRow(card.content, Theme.rowHeight)
    local searchInput = GUIFrame:CreateEditBox(searchRow, "Search spells", {
        value = searchFilter,
        callback = function(text)
            if onSearchChange then onSearchChange(text) end
        end
    })
    searchRow:AddWidget(searchInput, 1)
    card:AddRow(searchRow, Theme.rowHeight)

    local filteredSpells = {}
    local searchLower = searchFilter:lower()
    for _, spell in ipairs(spells) do
        if searchLower == "" or (spell.name and spell.name:lower():find(searchLower, 1, true)) then
            table_insert(filteredSpells, spell)
        end
    end

    local bossGroups = {}
    local bossOrder = {}
    local bossInfo = {}
    for _, spell in ipairs(filteredSpells) do
        local bossKey = spell.sortKey or 999999
        if not bossGroups[bossKey] then
            bossGroups[bossKey] = {}
            table_insert(bossOrder, bossKey)
            bossInfo[bossKey] = {
                name = spell.bossName or "Unknown",
                num = spell.bossNum or 0,
            }
        end
        table_insert(bossGroups[bossKey], spell)
    end

    table.sort(bossOrder)

    for _, bossKey in ipairs(bossOrder) do
        local boss = bossInfo[bossKey]
        local headerText = boss.num > 0
            and string.format("B%d %s", boss.num, boss.name)
            or string.format("— %s —", boss.name)

        local headerRow = GUIFrame:CreateRow(card.content, 14)
        local headerLabel = headerRow:CreateFontString(nil, "OVERLAY")
        headerLabel:SetPoint("LEFT", headerRow, "LEFT", 4, -4)
        NRSKNUI:ApplyThemeFont(headerLabel, "normal")
        headerLabel:SetText(headerText)
        headerLabel:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
        card:AddRow(headerRow, 14)

        local separator1 = GUIFrame:CreateSeparator(card.content)
        card:AddRow(separator1, 4)

        for _, spell in ipairs(bossGroups[bossKey]) do
            local spellRow = GUIFrame:CreateRow(card.content, 28)

            spellRow:EnableMouse(true)
            local capturedSpellIdForTooltip = spell.spellId
            spellRow:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT", 30, 0)
                GameTooltip:SetSpellByID(capturedSpellIdForTooltip)
                GameTooltip:Show()
            end)
            spellRow:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)

            local iconFrame = CreateFrame("Frame", nil, spellRow)
            iconFrame:SetSize(24, 24)
            iconFrame:SetPoint("LEFT", spellRow, "LEFT", 4, 0)

            local iconTexture = iconFrame:CreateTexture(nil, "ARTWORK")
            iconTexture:SetPoint("TOPLEFT", 1, -1)
            iconTexture:SetPoint("BOTTOMRIGHT", -1, 1)
            iconTexture:SetTexture(spell.icon or 134400)
            iconTexture:SetZoom()

            local iconBorder = CreateFrame("Frame", nil, iconFrame, "BackdropTemplate")
            iconBorder:SetAllPoints()
            iconBorder:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
            iconBorder:SetBackdropBorderColor(0, 0, 0, 1)

            local spellLabel = spellRow:CreateFontString(nil, "OVERLAY")
            spellLabel:SetPoint("LEFT", iconFrame, "RIGHT", 6, 0)
            spellLabel:SetPoint("RIGHT", spellRow, "RIGHT", -70, 0)
            spellLabel:SetJustifyH("LEFT")
            NRSKNUI:ApplyThemeFont(spellLabel, "small")
            spellLabel:SetText(spell.name .. "|cffffffff (" .. spell.spellId .. ")|r")
            spellLabel:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)

            local capturedSpellId = spell.spellId
            local useBtn = GUIFrame:CreateButton(spellRow, "Use", {
                width = 80,
                height = 22,
                callback = function()
                    if onSpellSelect then
                        onSpellSelect(capturedSpellId)
                    end
                end,
            })
            useBtn:SetPoint("RIGHT", spellRow, "RIGHT", -4, 0)

            -- Override tooltip to show spell info
            useBtn:HookScript("OnEnter", function(btn)
                GameTooltip:SetOwner(btn, "ANCHOR_CURSOR_RIGHT", 30, 0)
                GameTooltip:SetSpellByID(capturedSpellIdForTooltip)
                GameTooltip:Show()
            end)

            card:AddRow(spellRow, 28)
        end
    end

    if #filteredSpells == 0 and searchFilter ~= "" then
        local noMatchRow = GUIFrame:CreateRow(card.content, 30)
        local noMatchLabel = noMatchRow:CreateFontString(nil, "OVERLAY")
        noMatchLabel:SetPoint("LEFT", noMatchRow, "LEFT", 4, 0)
        NRSKNUI:ApplyThemeFont(noMatchLabel, "small")
        noMatchLabel:SetText("No spells match your search.")
        noMatchLabel:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
        card:AddRow(noMatchRow, 30)
    end

    return card, card:GetNextOffset()
end
