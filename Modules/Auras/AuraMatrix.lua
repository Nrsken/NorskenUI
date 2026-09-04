---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class AuraMatrixModule
local AuraMatrix = NRSKNUI:GetModule('AuraMatrix')
function AuraMatrix:UpdateDB() self.db = NRSKNUI.db.global.AuraMatrix end

local CreateFrame = CreateFrame
local ipairs, pairs = ipairs, pairs
local tinsert, tsort = table.insert, table.sort
local floor, ceil, max = math.floor, math.ceil, math.max
local format = string.format
local pcall = pcall
local UIParent = UIParent
local AuraUtil = AuraUtil

local AF = AuraUtil.AuraFilters
local NEG = AuraUtil.AuraFilterNegationPrefix
local BASE = AF.Harmful
local BL_DEBUFFS = NRSKNUI.AuraFilters.BloodlustDebuffs
local NON_NEGATABLE = { [AF.IncludeNameplateOnly] = true, [AF.Maw] = true, }
local DISPEL_TYPES = { 'Magic', 'Poison', 'Disease', 'Curse', 'Stealth', 'Special', 'Enrage', 'Bleed' }
local PROCESSED_TYPES = { 'Debuff', 'Buff', 'Dispel' }
local DURATION_CUTOFFS = { 5, 15, 30, 60, 300 }

local ICON_SIZE = 28
local ICON_SPACING = 2
local ICONS_PER_ROW = 6
local LABEL_HEIGHT = 12
local CELL_WIDTH = ICONS_PER_ROW * (ICON_SIZE + ICON_SPACING)
local CELL_HEIGHT = LABEL_HEIGHT + 2 + ICON_SIZE + 6
local COLUMN_GAP = 2
local BLOCK_GAP = 2
local HEADER_HEIGHT = 20
local PADDING = 2

---One axis per line, one cell per column: { positive }, or { positive, negative } where the axis has
---an opposite. An axis that only fills the left column is telling you it has no negated form.
---@return table[] axes
local function BuildAxes()
    local axes = {}

    local tokens = {}
    for _, token in pairs(AF) do
        if token ~= AF.Harmful and token ~= AF.Helpful then
            tinsert(tokens, token)
        end
    end
    tsort(tokens)

    for _, token in ipairs(tokens) do
        local axis = {}

        local positive = AuraUtil.CreateFilterString(BASE, token)
        if AuraUtil.IsValidFilterString(positive) then
            tinsert(axis, { label = token, filter = positive })
        end

        if not NON_NEGATABLE[token] then
            local negative = AuraUtil.CreateFilterString(BASE, NEG .. token)
            if AuraUtil.IsValidFilterString(negative) then
                tinsert(axis, { label = NEG .. token, filter = negative })
            end
        end

        if axis[1] then tinsert(axes, axis) end
    end

    for _, field in ipairs(NRSKNUI.AuraFilters.BoolCandidateFields) do
        tinsert(axes, {
            { label = field .. ' true',  filter = BASE, candidates = { [field] = true } },
            { label = field .. ' false', filter = BASE, candidates = { [field] = false } },
        })
    end

    for _, dispel in ipairs(DISPEL_TYPES) do
        tinsert(axes, {
            { label = 'include ' .. dispel, filter = BASE, candidates = { includeDispelTypes = { [dispel] = true } } },
            { label = 'exclude ' .. dispel, filter = BASE, candidates = { excludeDispelTypes = { [dispel] = true } } },
        })
    end

    for _, name in ipairs(PROCESSED_TYPES) do
        tinsert(axes, {
            { label = 'processed ' .. name, filter = BASE, candidates = { processedAuraType = AuraUtil.AuraUpdateChangedType[name] } },
        })
    end

    for _, cutoff in ipairs(DURATION_CUTOFFS) do
        tinsert(axes, {
            { label = format('maxDuration %ds', cutoff), filter = BASE, candidates = { maxDuration = cutoff } },
        })
    end

    return axes
end

---@return table config
local function CellConfig()
    return {
        maximumLineSize = CELL_WIDTH,
        anchorPoint = 'TOPLEFT',
        horizontalGrowthDirection = 'RIGHT',
        verticalGrowthDirection = 'DOWN',
        size = ICON_SIZE,
        elementSpacing = ICON_SPACING,
        lineSpacing = ICON_SPACING,
        maxFrameCount = ICONS_PER_ROW,
        sortMethod = AuraContainerSortMethod.ExpirationOnly,
        sortDirection = AuraContainerSortDirection.Normal,
        showApplicationCount = true,
        showDurationText = true,
        durationTextColorCurve = true,
        drawSwipe = false,
        showDebuffBorder = true,
        showWithoutDispelType = true,
    }
end

---An axis' own candidate filters plus the exclusions every cell carries.
---@param candidates table? the axis' candidate filters
---@return table
local function CellCandidates(candidates)
    local merged = { excludeSpellIDs = BL_DEBUFFS }
    for key, value in pairs(candidates or {}) do merged[key] = value end
    return merged
end

---@param parent Frame
---@param spec table { label, filter, candidates? }
---@return Frame host
---@return boolean rejected
local function CreateCell(parent, spec)
    local host = CreateFrame('Frame', nil, parent)
    host:SetSize(CELL_WIDTH, CELL_HEIGHT)

    local label = host:CreateFontString(nil, 'OVERLAY')
    label:SetFontStyle(nil, 11, 'OUTLINE')
    label:SetPoint('TOPLEFT', host, 'TOPLEFT')
    label:SetJustifyH('LEFT')
    label:SetText(spec.label)

    local container = host:CreateAuraContainer(CellConfig())
    if not container then return host, true end

    local candidates = CellCandidates(spec.candidates)

    -- Anchored to the host rather than the other way around, a container carries forbidden aspects.
    container:ClearAllPoints()
    container:SetPoint('TOPLEFT', host, 'TOPLEFT', 0, -(LABEL_HEIGHT + 2))

    -- AddGroup does not do this for us the way AddFilteredGroup and AddSlot do.
    container:EnsureProcessAuraPolicy(candidates)

    local accepted = pcall(container.AddGroup, container, spec.filter, { candidateFilters = candidates })
    if not accepted then
        label:SetText(spec.label .. ' |cffff3333(refused)|r')
        return host, true
    end

    container:SetUnit('player')
    container:UpdateUnitGate() -- also starts the container watching what can move a gate verdict

    host.container = container
    return host, false
end

function AuraMatrix:Build()
    if self.frame then return end

    local frame = CreateFrame('Frame', 'NRSKNUI_AuraMatrix', UIParent)
    frame:Hide() -- the build can land after a toggle back off, when it was queued out of combat
    frame:SetPoint('CENTER')
    frame:SetFrameStrata('HIGH')
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag('LeftButton')
    frame:SetScript('OnDragStart', frame.StartMoving)
    frame:SetScript('OnDragStop', frame.StopMovingOrSizing)
    frame:NUICreateBackdrop()

    local title = frame:CreateFontString(nil, 'OVERLAY')
    title:SetFontStyle(nil, 12, 'OUTLINE')
    title:SetPoint('TOPLEFT', frame, 'TOPLEFT', PADDING, -PADDING)
    title:SetJustifyH('LEFT')
    title:SetText('AuraMatrix  |cffb3b3b3player / ' .. BASE .. ', drag to move. maxDuration rows also drop permanent auras.|r')

    local axes = BuildAxes()
    local usableHeight = UIParent:GetHeight() - (PADDING * 2 + HEADER_HEIGHT)
    local maxRows = max(6, floor(usableHeight / CELL_HEIGHT))
    local blocks = max(1, ceil(#axes / maxRows))
    local rowsPerBlock = ceil(#axes / blocks) -- balanced, so the last column is never a lone stub
    local blockWidth = CELL_WIDTH * 2 + COLUMN_GAP

    self.cells = {}
    local refused = 0
    for index, axis in ipairs(axes) do
        local blockIndex = floor((index - 1) / rowsPerBlock)
        local rowIndex = (index - 1) % rowsPerBlock
        local originX = PADDING + blockIndex * (blockWidth + BLOCK_GAP)
        local originY = -(PADDING + HEADER_HEIGHT + rowIndex * CELL_HEIGHT)

        for column, spec in ipairs(axis) do
            local cell, rejected = CreateCell(frame, spec)
            cell:SetPoint('TOPLEFT', frame, 'TOPLEFT', originX + (column - 1) * (CELL_WIDTH + COLUMN_GAP), originY)
            self.cells[#self.cells + 1] = cell
            if rejected then refused = refused + 1 end
        end
    end

    frame:SetSize(PADDING * 2 + blocks * blockWidth + (blocks - 1) * BLOCK_GAP, PADDING * 2 + HEADER_HEIGHT + rowsPerBlock * CELL_HEIGHT)

    self.frame = frame
    NRSKNUI:Print(format('AuraMatrix built %d axes across %d columns, %d refused by the client.', #axes, blocks, refused))
end

function AuraMatrix:OnEnable()
    NRSKNUI:RunWhenSafe(function()
        self:Build()
        if self:IsEnabled() and self.frame then
            self.frame:Show()
        end
    end)
end

function AuraMatrix:OnDisable()
    if self.frame then
        self.frame:Hide()
    end
end
