---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
---@field Elements UnitFramesElements
local UF = NRSKNUI:GetModule('UnitFrames')

local abs = math.abs
local ipairs = ipairs
local CreateFrame = CreateFrame

-- Fixed slot set, iterated in order so layout is deterministic.
local SLOTS = { 'TagOne', 'TagTwo', 'TagThree', 'TagFour', 'TagFive' }

-- Units without real events update tags on a timer instead.
local EVENTLESS = {
    targettarget = true,
    focustarget = true,
    pettarget = true,
}

-- Horizontal mirror of an anchor point, used to bound a string's opposite edge.
local MIRROR = {
    LEFT = 'RIGHT',
    RIGHT = 'LEFT',
    TOPLEFT = 'TOPRIGHT',
    TOPRIGHT = 'TOPLEFT',
    BOTTOMLEFT = 'BOTTOMRIGHT',
    BOTTOMRIGHT = 'BOTTOMLEFT',
}

---Build a bound table for a slot.
---@param slotDB table the slot being positioned
---@param target table? the resolved fontstring of the bound-to slot, or the container for a frame bound
---@param toFrame boolean? true when the target is the container (bound to its far edge)
---@return table? bound { relTo, point, relPoint, offsetX, offsetY }
local function BuildBound(slotDB, target, toFrame)
    if not target then return nil end

    local anchor = slotDB.Position.AnchorFrom
    local point = MIRROR[anchor]
    if not point then return nil end -- no horizontal side to bound (CENTER/TOP/BOTTOM)

    local gap = abs(slotDB.Position.XOffset or 0)
    local offsetX = (anchor == 'LEFT' or anchor == 'TOPLEFT' or anchor == 'BOTTOMLEFT') and -gap or gap -- Push the bounded edge inward so the string keeps a gap from the target.
    local relPoint = toFrame and point or anchor                                                        -- Frame bound pins to the container's far/mirror edge, a slot bound pins to the sibling's near edge.

    return { relTo = target, point = point, relPoint = relPoint, offsetX = offsetX, offsetY = 0 }
end

---@class UnitFramesElements
---@field Tags UnitFramesTagsElement
UF.Elements = UF.Elements or {}

---@class UnitFramesTagsElement
UF.Elements.Tags = {
    ---@param self oUF.UnitFrame
    ---@param unit string
    Construct = function(self, unit)
        if self.TagContainer then return end

        local container = CreateFrame('Frame', nil, self)
        container:SetPixelPoint('TOPLEFT', self, 'TOPLEFT', 0, 0)
        container:SetPixelPoint('BOTTOMRIGHT', self, 'BOTTOMRIGHT', 0, 0)
        container:SetFrameLevel(999)
        container:SetFrameStrata('MEDIUM')

        self.TagContainer = container
        self.TagSlots = {}
    end,

    ---@param self oUF.UnitFrame
    ---@param unit string
    ---@param uDB table
    ---@param general table
    Configure = function(self, unit, uDB, general)
        local container = self.TagContainer
        local tagsDB = uDB.Tags
        local slots = self.TagSlots

        for _, name in ipairs(SLOTS) do
            if not slots[name] then
                local fs = container:CreateFontString(nil, 'OVERLAY') --[[@as NUI.TagFontString]]
                fs:SetWordWrap(false)
                slots[name] = fs
            end
            -- oUF binds the timer at Tag() time, so an interval change forces a re-tag below.
            if EVENTLESS[unit] then
                local fs = slots[name]
                local interval = UF.db.TagSettings.UpdateInterval
                if fs.frequentUpdates ~= interval then
                    fs.frequentUpdates = interval
                    if fs.nuiTag then
                        self:Untag(fs)
                        fs.nuiTag = nil
                    end
                end
            end
        end

        for _, name in ipairs(SLOTS) do
            local slotDB = tagsDB[name]
            local fs = slots[name]
            local active = slotDB.Enabled and slotDB.Tag ~= ''

            if active then
                local bound
                local boundTo = slotDB.BoundTo
                if boundTo == 'frame' then
                    bound = BuildBound(slotDB, container, true)
                elseif boundTo and boundTo ~= '' then
                    local targetDB = tagsDB[boundTo]
                    if targetDB and targetDB.Enabled and targetDB.Tag ~= '' then
                        bound = BuildBound(slotDB, slots[boundTo], false)
                    end
                end

                -- Font chain: slot -> UnitFrames General -> global media. Passing `general` as the
                -- source is what makes the General font tab reach the tags at all, the slot only
                -- supplies the face and outline once it opts out of the shared font.
                local useGlobal = slotDB.UseGlobalFont
                fs:SetFontStyle(useGlobal and general or slotDB, slotDB.FontSize,
                    useGlobal and general.FontOutline or slotDB.FontOutline)
                fs:SetFontJustify(slotDB, container, slotDB.Position.XOffset, slotDB.Position.YOffset, nil, bound)

                local c = slotDB.Color
                fs:SetTextColor(c[1], c[2], c[3])

                if fs.nuiTag ~= slotDB.Tag then
                    if fs.nuiTag then self:Untag(fs) end
                    self:Tag(fs, slotDB.Tag)
                    fs.nuiTag = slotDB.Tag
                end

                fs:Show()
            else
                if fs.nuiTag then
                    self:Untag(fs)
                    fs.nuiTag = nil
                end
                fs:Hide()
            end
        end
    end,
}
