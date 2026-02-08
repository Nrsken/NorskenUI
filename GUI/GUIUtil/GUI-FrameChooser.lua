-- NorskenUI namespace
local _, NRSKNUI = ...

-- Module Namespace
NRSKNUI.FrameChooser = {}
local FC = NRSKNUI.FrameChooser
local Theme = NRSKNUI.Theme

-- Localization
local ResetCursor = ResetCursor
local tostring = tostring
local pairs = pairs
local CreateFrame = CreateFrame
local IsMouseButtonDown = IsMouseButtonDown
local SetCursor = SetCursor
local GetMouseFoci = GetMouseFoci
local GetMouseFocus = GetMouseFocus

-- State Variables
local chooserFrame = nil
local chooserBox = nil
local isActive = false
local currentCallback = nil
local originalValue = nil
local oldFocus = nil
local oldFocusName = nil

-- RecurseGetName: Get frame name recursively, using parent key if no name exists
local function RecurseGetName(frame)
    if not frame then return nil end

    local name = frame.GetName and frame:GetName() or nil
    if name then
        return name
    end

    local parent = frame.GetParent and frame:GetParent()
    if parent then
        for key, child in pairs(parent) do
            if child == frame then
                local parentName = RecurseGetName(parent)
                if parentName then
                    return parentName .. "." .. tostring(key)
                end
            end
        end
    end

    return nil
end

-- EnsureFrameChooserUI: Create the frame chooser UI elements (highlight box, instructions)
local function EnsureFrameChooserUI()
    if chooserFrame then return end

    -- Invisible frame that captures the OnUpdate
    chooserFrame = CreateFrame("Frame", "NRSKNUIFrameChooser", UIParent)
    chooserFrame:SetFrameStrata("TOOLTIP")
    chooserFrame:SetAllPoints(UIParent)
    chooserFrame:EnableMouse(false) -- Don't block clicks
    chooserFrame:Hide()

    -- Green box that highlights the hovered frame
    chooserBox = CreateFrame("Frame", nil, chooserFrame, "BackdropTemplate")
    chooserBox:SetFrameStrata("TOOLTIP")
    chooserBox:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 3,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    local accent = (Theme and Theme.accent) or { 1, 0.82, 0, 1 }
    chooserBox:SetBackdropBorderColor(accent[1], accent[2], accent[3], accent[4] or 1)
    chooserBox:Hide()

    -- Instructions text
    local instructions = chooserFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    instructions:SetPoint("TOP", UIParent, "TOP", 0, -50)
    instructions:SetText("Click on a frame to select it as anchor\nRight-click to cancel")
    instructions:SetTextColor(0, 1, 0, 1)
    chooserFrame.instructions = instructions
end

-- OnUpdateHandler: Tracks mouse position, highlights frames, handles click input
local function OnUpdateHandler(self, elapsed)
    if not isActive then return end

    -- Right-click cancels
    if IsMouseButtonDown("RightButton") then
        FC:Stop(true) -- cancelled
        return
    end

    -- Left-click confirms
    if IsMouseButtonDown("LeftButton") and oldFocusName then
        FC:Stop(false) -- confirmed
        return
    end

    -- Set cursor to indicate selection mode
    SetCursor("CAST_CURSOR")

    -- Get the frame under cursor
    local focus
    if GetMouseFocus then
        focus = GetMouseFocus()
    elseif GetMouseFoci then
        local foci = GetMouseFoci()
        focus = foci and foci[1] or nil
    end

    local focusName = nil

    if focus then
        focusName = RecurseGetName(focus)

        -- If it's WorldFrame or no name, check our displays
        if focusName == "WorldFrame" or not focusName then
            focusName = nil

            -- Check NorskenAuras displays
            local displays = NRSKNUI.db and NRSKNUI.db.profile.CustomIcons and NRSKNUI.db.profile.CustomIcons.Displays
            if displays and NRSKNUI.DisplaySystem and NRSKNUI.DisplaySystem.regions then
                for id, displayData in pairs(displays) do
                    local region = NRSKNUI.DisplaySystem.regions[id]
                    if region and region:IsVisible() and MouseIsOver(region) then
                        local isGroup = displayData.type == "group" or displayData.type == "dynamicgroup"
                        -- Prefer non-groups over groups when overlapping
                        if not focusName or (not isGroup) then
                            focus = region
                            focusName = "NRSKNUI:" .. id
                        end
                    end
                end
            end
        end

        -- Update highlight box if focus changed
        if focus ~= oldFocus then
            if chooserBox then
                if focusName then
                    chooserBox:ClearAllPoints()
                    chooserBox:SetPoint("BOTTOMLEFT", focus, "BOTTOMLEFT", -4, -4)
                    chooserBox:SetPoint("TOPRIGHT", focus, "TOPRIGHT", 4, 4)
                    chooserBox:Show()
                else
                    chooserBox:Hide()
                end
            end

            -- Update preview value
            if focusName ~= oldFocusName then
                oldFocusName = focusName
                -- Show preview in the input field if we have a callback
                if currentCallback then
                    currentCallback(focusName, true) -- true = preview mode
                end
            end

            oldFocus = focus
        end
    end

    if not focusName then
        if chooserBox then
            chooserBox:Hide()
        end
    end
end

-- Start: Begin frame chooser mode. callback(frameName, isPreview) called with selection
function FC:Start(callback, initialValue)
    EnsureFrameChooserUI()

    if isActive then
        self:Stop(true)
    end

    isActive = true
    currentCallback = callback
    originalValue = initialValue
    oldFocus = nil
    oldFocusName = nil

    if chooserFrame then
        chooserFrame:SetScript("OnUpdate", OnUpdateHandler)
        chooserFrame:Show()
    end

    -- Print instruction
    if NRSKNUI.Print then
        NRSKNUI:Print("Frame chooser active. Click a frame to select, right-click to cancel.")
    end
end

-- Stop: End frame chooser mode. If cancelled, restores original value
function FC:Stop(cancelled)
    if not isActive then return end

    isActive = false

    if chooserFrame then
        chooserFrame:SetScript("OnUpdate", nil)
        chooserFrame:Hide()
    end

    if chooserBox then
        chooserBox:Hide()
    end

    ResetCursor()

    -- Call final callback
    if currentCallback then
        if cancelled then
            currentCallback(originalValue, false) -- Restore original
        else
            currentCallback(oldFocusName, false)  -- Confirm selection
        end
    end

    -- Refresh options
    if NRSKNUI.OptionsRegistry then
        NRSKNUI.OptionsRegistry:NotifyChange()
    end

    currentCallback = nil
    originalValue = nil
    oldFocus = nil
    oldFocusName = nil
end

-- IsActive: Check if frame chooser is currently active
function FC:IsActive()
    return isActive
end
