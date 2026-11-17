---@class NorskenUI
local NRSKNUI = _G.NorskenUI

local CopyTable = CopyTable
local tinsert = table.insert
local ipairs = ipairs
local pairs = pairs

-- moved from global to profile scope
local SCOPE_MOVED_KEYS = { 'Theme', 'UIScale', 'AuraIndicators', 'AuraIndicatorGroups' }

---@param db NRSKNUI.DBObject
local function RunProfileScopeMigration(db)
    if db.global.ProfileScopeMigrated then return end

    for _, key in ipairs(SCOPE_MOVED_KEYS) do
        local old = db.global[key]
        -- overwrite, never skip: AceDB already seeded the active profile with the new defaults
        if old ~= nil then
            for _, profile in pairs(db.profiles) do
                profile[key] = CopyTable(old)
            end
            db.global[key] = nil
        end
    end

    db.global.ProfileScopeMigrated = true
end

---@param db NRSKNUI.DBObject
local function RunLoadEnableMigration(db)
    if db.global.LoadEnableDropped then return end

    -- the raw save, so namespaces and profiles other than the active one come along
    NRSKNUI.LoadConditions:DropEnableToggle(db.sv)
    db.global.LoadEnableDropped = true
end

---@param db NRSKNUI.DBObject
local function RunLoadCombatMigration(db)
    if db.global.LoadCombatMoved then return end

    NRSKNUI.LoadConditions:MoveCombatToState(db.sv)
    db.global.LoadCombatMoved = true
end

-- Old aura displays --

-- what an aura display saved before aura groups; any left means it hasn't moved over
NRSKNUI.OLD_AURA_KEYS = {
    'size', 'perRow', 'elementSpacing', 'lineSpacing', 'horizontalGrowthDirection', 'verticalGrowthDirection',
    'showApplicationCount', 'showDurationText', 'drawSwipe', 'drawEdge', 'reverseSwipe', 'showBorder',
    'showBorderWithoutDispelType', 'showDispelIcon', 'showDebuffDispelIcon', 'dispelIconSize', 'disableMouse',
    'tooltipHideInCombat', 'StackFont', 'DurationFont',
}

-- old style key -> new one, both plain values
local OLD_STYLE = {
    drawSwipe = 'DrawSwipe',
    drawEdge = 'DrawEdge',
    reverseSwipe = 'Reverse',
    tooltipHideInCombat = 'TooltipHideInCombat',
    showDispelIcon = 'DispelIcon',
    showDebuffDispelIcon = 'DispelIcon',
    dispelIconSize = 'DispelIconSize',
}

---An old stack or duration text over its starting look.
---@param base table? the look's own overrides for this text
---@param enabled boolean?
---@param font table? the old StackFont or DurationFont
---@param point string where the old text sat when it saved no point
---@param y number its old offset then
---@return table
function NRSKNUI:OldAuraText(base, enabled, font, point, y)
    local text = CopyTable(base or {})
    if enabled ~= nil then
        text.Enabled = enabled
    end
    if font then
        local pos = font.Position or {}
        text.FontSize = font.FontSize or text.FontSize
        text.Position = { AnchorFrom = 'AUTO', AnchorTo = pos.AnchorFrom or point, XOffset = pos.XOffset or 0, YOffset = pos.YOffset or y }
    end
    return text
end

---A dispel coloured border hands that to an aura type texture after it (2026-11).
---Read off the save, so it runs once.
---@param subRegions table[]?
function NRSKNUI:UpgradeDispelBorders(subRegions)
    local i = 1
    while subRegions and subRegions[i] do
        local element = subRegions[i]
        if element.type == 'border' and element.DispelColor then
            tinsert(subRegions, i + 1, self:NewSubRegion('auratype', {
                Enabled = element.Enabled ~= false,
                DispelUntyped = element.DispelUntyped == true,
                Alpha = element.DispelAlpha or 1,
            }))
            element.DispelColor, element.DispelUntyped, element.DispelAlpha = nil, nil, nil
            i = i + 1
        end
        i = i + 1
    end
end

---Texts saved before a text chose its colours (2026-11) always drew the shared Duration Text
---ones, so they keep them. Read off the save: only those texts have no value.
---@param subRegions table[]?
function NRSKNUI:UpgradeTimeColor(subRegions)
    for _, element in ipairs(subRegions or {}) do
        if element.type == 'text' and element.GlobalTimeColor == nil then
            element.GlobalTimeColor = true
        end
    end
end

---An old aura display's flat keys as an aura group's Layout, Style and SubRegions.
---Only what the save holds is written; what it left out was the old default, which the new
---defaults draw the same.
---@param cfg table
---@param old table the old defaults: horizontal and vertical growth, [4] per row, [5] most auras
---@param look table DefaultAuraGroupSubRegions' starting look; its texts take the old ones
function NRSKNUI:UpgradeOldAuraGroup(cfg, old, look)
    local horizontal = cfg.horizontalGrowthDirection or old[1]
    local vertical = cfg.verticalGrowthDirection or old[2]
    local perRow = cfg.perRow or old[4]

    local layout = cfg.Layout or {}
    cfg.Layout = layout
    layout.GridWidth = perRow
    layout.Spacing = cfg.elementSpacing or layout.Spacing
    layout.RowSpacing = cfg.lineSpacing or layout.RowSpacing
    -- only a non-grid group centres a row, and it never wraps
    if horizontal == 'CENTER' and perRow >= (cfg.maxFrameCount or old[5]) then
        layout.Grow = 'HORIZONTAL'
        layout.Align = vertical == 'UP' and 'BOTTOM' or vertical == 'DOWN' and 'TOP' or 'CENTER'
    else
        layout.Grow = 'GRID'
        layout.Align = 'CENTER'
        layout.GridType = (horizontal == 'LEFT' and 'L' or 'R') .. (vertical == 'UP' and 'U' or 'D')
    end

    local style = cfg.Style or {}
    cfg.Style = style
    if cfg.size then
        style.Width, style.Height = cfg.size, cfg.size
    end
    for oldKey, new in pairs(OLD_STYLE) do
        if cfg[oldKey] ~= nil then
            style[new] = cfg[oldKey]
        end
    end
    if cfg.disableMouse ~= nil then
        style.Tooltip = not cfg.disableMouse
    end

    -- the old border's dispel colouring is an aura type texture now; a seed that already
    -- skips buffs is Standard Buffs', kept off for both for its weapon enchants
    if cfg.showBorder then
        local auraType = CopyTable(look.auraType or {})
        auraType.ShowHelpful, auraType.ShowHarmful = true, true
        look.auraType = auraType
    elseif cfg.showBorder == false and look.auraType and look.auraType.ShowHelpful == false then
        look.auraType = CopyTable(look.auraType)
        look.auraType.ShowHarmful = false
    elseif cfg.showBorder == false then
        look.auraType = nil
    end
    if cfg.showBorderWithoutDispelType ~= nil and look.auraType then
        look.auraType.DispelUntyped = cfg.showBorderWithoutDispelType
    end
    look.timer = self:OldAuraText(look.timer, cfg.showDurationText, cfg.DurationFont, 'CENTER', 0)
    look.stacks = self:OldAuraText(look.stacks, cfg.showApplicationCount, cfg.StackFont, 'BOTTOMRIGHT', 2)
    cfg.SubRegions = self:DefaultAuraGroupSubRegions(look)

    for _, key in ipairs(self.OLD_AURA_KEYS) do
        cfg[key] = nil
    end
end

---Old layouts, fixed right after AceDB loads and before any module takes its namespace.
---@param db NRSKNUI.DBObject
function NRSKNUI:UpgradeSavedProfiles(db)
    RunProfileScopeMigration(db)
    RunLoadEnableMigration(db)
    RunLoadCombatMigration(db)
end
