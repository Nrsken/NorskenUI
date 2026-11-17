---@class NorskenUI
local NRSKNUI = _G.NorskenUI
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')
---@class NorskenUF
local oUF = NRSKNUI.oUF
local AuraIndicators = NRSKNUI.AuraIndicators

local CreateFrame = CreateFrame
local ipairs, pairs = ipairs, pairs
local setmetatable = setmetatable
local tremove = table.remove
local wipe = wipe
local next = next

local Styles = AuraIndicators.Styles

-- the size a slot's button is made at, before its spot sizes it
local SLOT_LAYOUT = { width = 24, height = 24, disableMouse = true }

-- every unit's placements, so renaming an indicator updates the units listing it
AuraIndicators:RegisterPlacements(function(fn)
    for _, uDB in pairs(UF.db.Units) do
        for _, placement in ipairs(uDB.AuraIndicators or {}) do
            fn(placement)
        end
    end
end)

-- the spots previewing, rebuilt on every Preview pass
local previewing = {}

-- Look --

-- a tint or a text alone: no icon, swipe or timer of its own
local plain = {
    style = NRSKNUI:ReadStyle({}, NRSKNUI.ICON_STYLE_TEMPLATE),
    color = { 1, 1, 1, 1 },
    showIcon = false,
    swipe = false,
    timerText = false,
    spellName = '',
    subRegions = {},
}

---Draw a slot's button as its spot's style, in its indicator's colour. Preview dummies too.
---@param entry AuraDisplayEntry
local function StyleIndicator(entry)
    local id = entry.id
    local placement = id.placement
    local spec = AuraIndicators:GetSpec(id.key)
    if not spec then return end

    -- the indicator's colour, faded by the spot's alpha
    local color, tint = spec.Color, entry.tint or {}
    entry.tint = tint
    tint[1], tint[2], tint[3], tint[4] = color[1], color[2], color[3], (color[4] or 1) * (placement.Alpha or 1)

    local refs = entry.refs
    local button = refs.button
    -- before the look, which levels the elements off the button
    if not entry.preview then
        button:SetFrameLevel(UF.GetIndicatorLevel(id.frame, id.placements, placement))
    end
    button:ClearAllPoints()
    button:SetAllPoints(entry.host)
    if placement.Style == Styles.Icon then
        NRSKNUI:ApplyIconLook(refs, NRSKNUI:ReadStyle(placement.IconStyle, NRSKNUI.ICON_STYLE_TEMPLATE), placement.SubRegions, 1, tint)
    else
        local element = placement.Tint
        if placement.Style == Styles.Duration then
            -- the text takes the indicator's colour, as the tint does
            local text = entry.text
            if not text or entry.textOf ~= placement.Text then
                text = setmetatable({}, { __index = placement.Text })
                entry.text, entry.textOf = text, placement.Text
            end
            text.Color = tint
            element = text
        end
        plain.subRegions[1] = element
        plain.textParent, plain.tintColor = refs.inner, tint
        NRSKNUI:ApplyAuraLook(refs, plain)
        refs.inner:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT')
    end
    -- never the unit frame's clicks
    button:EnableMouse(false)
end

-- Element --

---Point a spot's proxy at its attach target.
---@param frame oUF.UnitFrame
---@param proxy Frame
---@param placement table
---@return boolean anchored
local function AnchorProxy(frame, proxy, placement)
    local target = UF.ResolveAttachTarget(frame, placement.Attach)
    if not target then return false end

    proxy:ClearAllPoints()
    if AuraIndicators.Sized[placement.Style] then
        local pos = placement.Position
        local size = placement.Style == Styles.Icon and placement.IconStyle or placement.Size
        proxy:NCSetSize(size.Width, size.Height)
        proxy:NCSetPoint(pos.AnchorFrom, target, pos.AnchorTo, pos.XOffset, pos.YOffset)
    else
        -- Everything else covers the target.
        proxy:SetAllPoints(target)
    end

    return true
end

---@param frame oUF.UnitFrame
local function Update(frame)
    local display = frame.nuiAuraIndicators
    if not display or not display.config then return end

    for placement, proxy in pairs(frame.nuiIndicatorProxies) do
        if not proxy.nuiAnchored then
            proxy.nuiAnchored = AnchorProxy(frame, proxy, placement)
        end
    end

    -- a roster change can point the same token at someone else
    display:SetUnit(frame.__unit)
    display:Refresh()
end

---@param frame oUF.UnitFrame
---@return boolean
local function Enable(frame)
    if frame.nuiAuraIndicators then
        frame.nuiAuraIndicators.host:Show()
    end
    return true
end

---@param frame oUF.UnitFrame
local function Disable(frame)
    if frame.nuiAuraIndicators then
        frame.nuiAuraIndicators.host:Hide()
    end
end

oUF:AddElement('NRSKNAuraIndicators', Update, Enable, Disable)

-- what edits wait for Reapply: all frames, an indicator's or a unit's
local pending = { all = false, keys = {}, units = {} }

---@param frame oUF.UnitFrame
---@param unit string
local function ReapplyFrame(frame, unit)
    local element = UF.Elements.AuraIndicators
    local uDB = UF.GetUnitDB(unit)
    element.Configure(frame, unit, uDB, UF.db.General, true)
    element.Preview(frame, unit, uDB)
end

-- one function, so edits made in combat queue it once
local function Reapply()
    local keys = pending.keys
    if pending.all or next(keys) then
        local all = pending.all
        UF:ForEachFrame(function(frame, unit)
            local wanted = all
            for _, placement in ipairs(UF.GetUnitDB(unit).AuraIndicators) do
                for _, key in ipairs(placement.Keys) do
                    wanted = wanted or keys[key] == true
                end
            end
            if wanted then
                ReapplyFrame(frame, unit)
            end
        end)
    end
    for unit in pairs(pending.units) do
        UF:ForEachFrame(ReapplyFrame, unit)
    end
    pending.all = false
    wipe(keys)
    wipe(pending.units)
end

---Re-read the indicators an edit reaches: one indicator's frames, one unit's or all.
---Indicator edits land here through the AuraIndicators callback in Core.lua.
---@param key string? an indicator edit; nil with no unit is every frame
---@param unit string? a spot edit on this unit's page
function UF:ReapplyAuraIndicators(key, unit)
    if unit then
        pending.units[unit] = true
    elseif key then
        pending.keys[key] = true
    else
        pending.all = true
    end
    NRSKNUI:RunWhenSafe(Reapply)
end

---@class UnitFramesElements
---@field AuraIndicators UnitFramesAuraIndicatorsElement
UF.Elements = UF.Elements or {}

---@class UnitFramesAuraIndicatorsElement
UF.Elements.AuraIndicators = {
    ---One slot display for every spot; it gets a container once a spot has an indicator.
    ---@param self oUF.UnitFrame
    ---@param unit string
    Construct = function(self, unit)
        if self.nuiAuraIndicators then return end

        self.nuiAuraIndicators = NRSKNUI:NewAuraDisplay(self, { shape = 'slots', style = StyleIndicator })
        self.nuiIndicatorProxies, self.nuiIndicatorIds, self.nuiFreeProxies = {}, {}, {}
        self.nuiIndicatorLive, self.nuiIndicatorSpots = {}, {}
    end,

    ---A slot per spot and assigned indicator, each covering its spot's proxy.
    ---@param self oUF.UnitFrame
    ---@param unit string
    ---@param uDB table
    ---@param general table
    ---@param edited (table|boolean)? only an edit re-points; spawning and previews configure too
    Configure = function(self, unit, uDB, general, edited)
        local display = self.nuiAuraIndicators
        if not display then return end

        local placements = uDB.AuraIndicators
        local proxies, ids = self.nuiIndicatorProxies, self.nuiIndicatorIds
        local live, spots = self.nuiIndicatorLive, self.nuiIndicatorSpots
        wipe(live)
        wipe(spots)
        for _, placement in ipairs(placements) do
            spots[placement] = true
        end
        -- a frame can't be destroyed, so a spot that's gone hands its proxy on
        for placement, proxy in pairs(proxies) do
            if not spots[placement] then
                proxies[placement], ids[placement] = nil, nil
                proxy:ClearAllPoints()
                self.nuiFreeProxies[#self.nuiFreeProxies + 1] = proxy
            end
        end

        for _, placement in ipairs(placements) do
            local proxy = proxies[placement]
            if not proxy then
                proxy = tremove(self.nuiFreeProxies) or CreateFrame('Frame', nil, self)
                proxies[placement] = proxy
            end
            proxy.nuiAnchored = AnchorProxy(self, proxy, placement)
            -- a preview dummy sits on the proxy, so it layers where the live button does
            proxy:SetFrameLevel(UF.GetIndicatorLevel(self, placements, placement))

            local own = ids[placement] or {}
            ids[placement] = own
            for _, key in ipairs(placement.Keys) do
                local spec = AuraIndicators:GetSpec(key)
                if spec then
                    local id = own[key]
                    local new = not id or not display.slots[id] or not display.slots[id].shown
                    if not id then
                        id = { frame = self, placement = placement, key = key }
                        own[key] = id
                    end
                    id.placements = placements
                    live[id] = true
                    if new or edited then
                        if not display.config then
                            display:SetLayout(SLOT_LAYOUT)
                        end
                        display:SetSlot(id, spec.Trigger, proxy, {
                            sortMethod = AuraContainerSortMethod[spec.sortMethod],
                            sortDirection = AuraContainerSortDirection[spec.sortDirection],
                        })
                    end
                end
            end
        end
        for id in pairs(display.slots) do
            if not live[id] then
                display:RemoveSlot(id)
            end
        end
        if not display.config then return end

        -- the live token, which a preview repoints away from the configured unit
        display:SetUnit(self.__unit or unit)
        if edited then
            display:Restyle()
        end
    end,

    ---Dummies while the unit's indicator section is open. A tint covers its target whole,
    ---so it previews alone on its own tab; the rest preview together to show the layout.
    ---@param self oUF.UnitFrame
    ---@param unit string
    ---@param uDB table
    Preview = function(self, unit, uDB)
        local display = self.nuiAuraIndicators
        if not display then return end

        local selected = UF.Preview:GetAuraIndicatorTab(self.nuiConfig or unit)
        wipe(previewing)
        if selected then
            for index, placement in ipairs(uDB.AuraIndicators) do
                if not AuraIndicators.FullCover[placement.Style] or index == selected then
                    previewing[placement] = true
                end
            end
        end

        for id in pairs(display.slots) do
            display:SetPreview(previewing[id.placement] == true, id)
        end
    end,
}
