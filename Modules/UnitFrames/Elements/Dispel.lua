---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')
---@class NorskenUF
local oUF = NRSKNUI.oUF
local CreateFrame = CreateFrame
local ipairs, pairs = ipairs, pairs

local AF = AuraUtil.AuraFilters

local GRADIENT_TEXTURE = 'Interface\\AddOns\\NorskenUI\\Media\\white_gradient.tga'

local BORDER_EDGES = {
    { from = 'TOPLEFT',    to = 'TOPRIGHT',    height = true },
    { from = 'BOTTOMLEFT', to = 'BOTTOMRIGHT', height = true },
    { from = 'TOPLEFT',    to = 'BOTTOMLEFT',  width = true },
    { from = 'TOPRIGHT',   to = 'BOTTOMRIGHT', width = true },
}

local SOURCE_TOKENS = {
    raid = AF.RaidPlayerDispellable,
    any = AF.Dispellable,
}

local NEVER_MATCH = { includeDispelTypes = {} }

---The compiled branch one Source resolves to, through the same compiler every trigger runs.
---@param source string
---@return table branch
local function SourceBranch(source)
    local token = SOURCE_TOKENS[source] or SOURCE_TOKENS.raid

    return NRSKNUI.AuraFilters:Compile({ { tokens = { [token] = true } } }, AF.Harmful)[1]
end

---@param uDB table
---@param general table?
---@return table
local function ResolveConfig(uDB, general)
    general = general or UF.db.General

    return uDB.Dispel.UseGlobal and general.Dispel or uDB.Dispel
end

---Hand a texture to the game to paint from the aura's dispel type.
---@param button table
---@param texture Texture
---@param cfg table
local function BindDispelColor(button, texture, cfg)
    button:AddDispelTypeTexture(texture, {
        style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
        showWhenHarmful = true,
        showWhenHelpful = true,
        showWithoutDispelType = cfg.ShowWithoutDispelType == true,
        customDispelColorMap = NRSKNUI.Colors.dispel,
    })
end

---Draw the highlight on a slot's button: overlay, optional border, optional dispel type icon.
---@param button table
---@param cfg table
---@param level number
local function BuildHighlight(button, cfg, level)
    local holder = CreateFrame('Frame', nil, button)
    holder:SetAllPoints(button)
    holder:SetFrameLevel(level)
    -- Faded through the holder rather than the textures, which the game recolors.
    holder:SetAlpha(cfg.Alpha or 1)

    local overlay = holder:CreateTexture(nil, 'ARTWORK')
    overlay:SetAllPoints(holder)
    overlay:SetTexture(cfg.Style == 'Gradient' and GRADIENT_TEXTURE or NRSKNUI.WhiteTexture)
    BindDispelColor(button, overlay, cfg)

    -- The border is its own setting rather than a style, so it draws over either of them. Size 0 is off.
    local borderSize = cfg.BorderSize or 0
    if borderSize > 0 then
        for _, edge in ipairs(BORDER_EDGES) do
            local border = holder:CreateTexture(nil, 'OVERLAY')
            border:SetTexture(NRSKNUI.WhiteTexture)
            border:NUISetPixelPoint(edge.from, holder, edge.from, 0, 0)
            border:NUISetPixelPoint(edge.to, holder, edge.to, 0, 0)
            if edge.height then
                border:NUISetPixelHeight(borderSize)
            else
                border:NUISetPixelWidth(borderSize)
            end
            border:NUISetPixelSnap()
            BindDispelColor(button, border, cfg)
        end
    end

    if cfg.ShowIcon then
        local pos = cfg.IconPosition
        local iconHost = CreateFrame('Frame', nil, button)
        iconHost:SetAllPoints(button)
        iconHost:SetFrameLevel(level + 1)

        local icon = iconHost:CreateTexture(nil, 'OVERLAY')
        icon:SetSize(cfg.IconSize, cfg.IconSize)
        icon:SetPoint(pos.AnchorFrom, iconHost, pos.AnchorTo, pos.XOffset, pos.YOffset)
        button:AddDispelTypeTexture(icon, {
            style = Enum.CustomAuraButtonDispelTypeTextureStyle.Icon,
            showWhenHarmful = true,
            showWhenHelpful = true,
        })
    end
end

---@param dispel table
---@param source string
---@param shown boolean
local function SetSlotShown(dispel, source, shown)
    local key = dispel.keys[source]
    if not key then return end

    local filters
    if not shown then filters = NEVER_MATCH end

    dispel.container:SetAuraSlotCandidateFilters(key, filters)
end

---Point the proxy at whatever the config attaches to.
---The highlight always covers its target, so it has no size or offset of its own.
---@param frame oUF.UnitFrame
---@param cfg table
---@return boolean anchored
local function AnchorProxy(frame, cfg)
    local dispel = frame.nuiDispel
    local target = UF.ResolveAttachTarget(frame, cfg.Attach)
    if not (target and dispel.proxy) then return false end

    dispel.proxy:ClearAllPoints()
    dispel.proxy:SetAllPoints(target)

    return true
end

---Build the container and the slot for a Source the frame has not shown yet.
---@param frame oUF.UnitFrame
---@param cfg table
local function EnsureSlot(frame, cfg)
    local dispel = frame.nuiDispel
    if dispel.keys[cfg.Source] then return end

    local container = dispel.container
    if not container then
        container = frame:CreateAuraContainer()
        if not container then return end

        dispel.container = container
        dispel.proxy = CreateFrame('Frame', nil, frame)
    end

    local branch = SourceBranch(cfg.Source)
    local proxy = dispel.proxy

    local _, key = container:AddSlot(branch.filterString, {
        candidateFilters = branch.candidateFilters,
        assistOnly = true,
        initializeFrame = function(button)
            local level = UF.GetLayerLevel(frame, cfg.Layer)

            button:EnableMouse(false) -- the highlight must never eat the unit frame's clicks
            button:SetFrameLevel(level)
            button:SetAllPoints(proxy)
            BuildHighlight(button, cfg, level)
        end,
    })

    dispel.keys[cfg.Source] = key
end

---@param frame oUF.UnitFrame
local function Update(frame)
    local dispel = frame.nuiDispel
    local container = dispel and dispel.container
    if not container then return end

    -- A healthFill attach resolves to nothing until Health's Configure has built the fill, so retry
    -- here until it takes rather than leaving the highlight anchored to nothing.
    if not dispel.anchored and dispel.config then
        dispel.anchored = AnchorProxy(frame, dispel.config)
    end

    container:SetUnit(frame.unit) -- early-outs when the token is unchanged
    container:UpdateUnitGate()
    container:UpdateAllAuras()
end

---@param frame oUF.UnitFrame
---@return boolean
local function Enable(frame)
    return true
end

---@param frame oUF.UnitFrame
local function Disable(frame)
    local dispel = frame.nuiDispel
    if dispel and dispel.container then
        dispel.container:Hide()
    end
end

oUF:AddElement('NRSKNDispel', Update, Enable, Disable)

---@class UnitFramesElements
---@field Dispel UnitFramesDispelElement
UF.Elements = UF.Elements or {}

---@class UnitFramesDispelElement
UF.Elements.Dispel = {
    ---@param self oUF.UnitFrame
    ---@param unit string
    Construct = function(self, unit)
        if self.nuiDispel then return end

        self.nuiDispel = { keys = {} }
    end,

    ---@param self oUF.UnitFrame
    ---@param unit string
    ---@param uDB table
    ---@param general table?
    Configure = function(self, unit, uDB, general)
        local dispel = self.nuiDispel
        if not dispel then return end

        local cfg = ResolveConfig(uDB, general)
        dispel.config = cfg

        if not cfg.Enabled then
            for source in pairs(dispel.keys) do
                SetSlotShown(dispel, source, false)
            end
            return
        end

        NRSKNUI:RunWhenSafe(function()
            EnsureSlot(self, cfg)
            if not dispel.container then return end

            for source in pairs(dispel.keys) do
                SetSlotShown(dispel, source, source == cfg.Source)
            end

            dispel.anchored = AnchorProxy(self, cfg)
            dispel.container:SetUnit(self.unit or unit)
            dispel.container:UpdateUnitGate()
            dispel.container:UpdateAllAuras()
        end)
    end,
}
