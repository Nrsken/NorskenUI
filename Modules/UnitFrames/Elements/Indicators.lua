---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFrames
local UF = NRSKNUI:GetModule('UnitFrames')

local ipairs = ipairs
local CreateFrame = CreateFrame

-- Status-icon slots, separate from the text tag slots. Iterated in order.
local SLOTS = { 'IndicatorOne', 'IndicatorTwo', 'IndicatorThree', 'IndicatorFour' }

-- Units without real events update their tags on a timer instead.
local EVENTLESS = {
    targettarget = true,
    focustarget = true,
    pettarget = true,
}

UF.Elements = UF.Elements or {}
UF.Elements.Indicators = {
    Construct = function(frame, unit)
        if frame.IndicatorContainer then return end

        -- Own overlay above the text container so icons never sit behind the name.
        local container = CreateFrame('Frame', nil, frame)
        container:SetPixelPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        container:SetPixelPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        container:SetFrameLevel(1000)
        container:SetFrameStrata("MEDIUM")

        frame.IndicatorContainer = container
        frame.IndicatorSlots = {}
    end,

    Configure = function(frame, unit, uDB, general)
        local container = frame.IndicatorContainer
        local indDB = uDB.Indicators
        local slots = frame.IndicatorSlots

        for _, name in ipairs(SLOTS) do
            local slotDB = indDB[name]
            local fs = slots[name]

            if not fs then
                fs = container:CreateFontString(nil, 'OVERLAY')
                if EVENTLESS[unit] then fs.frequentUpdates = 0.5 end
                fs:SetWordWrap(false)
                slots[name] = fs
            end

            if slotDB.Enabled and slotDB.Tag ~= '' then
                fs:SetFontStyle(slotDB)
                fs:SetFontJustify(slotDB, container, slotDB.Position.XOffset, slotDB.Position.YOffset)

                if fs.nuiTag ~= slotDB.Tag then
                    if fs.nuiTag then frame:Untag(fs) end
                    frame:Tag(fs, slotDB.Tag)
                    fs.nuiTag = slotDB.Tag
                end

                fs:Show()
            else
                if fs.nuiTag then
                    frame:Untag(fs)
                    fs.nuiTag = nil
                end
                fs:Hide()
            end
        end
    end,
}
