---@class NRSKNUI
local NRSKNUI = select(2, ...)

---@class HealerMana: AceModule, AceEvent-3.0, AceTimer-3.0
local HM = NRSKNUI:NewModule("HealerMana", "AceEvent-3.0", "AceTimer-3.0")

local EM = NRSKNUI.EditMode

local CreateFrame = CreateFrame
local UnitExists = UnitExists
local UnitIsConnected = UnitIsConnected
local UnitClass = UnitClass
local UnitName = UnitName
local UnitPowerPercent = UnitPowerPercent
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local IsInRaid = IsInRaid
local IsInGroup = IsInGroup
local pairs = pairs
local ipairs = ipairs
local wipe = wipe
local issecretvalue = issecretvalue
local NotifyInspect = NotifyInspect
local GetInspectSpecialization = GetInspectSpecialization
local GetSpecializationInfoByID = GetSpecializationInfoByID
local CanInspect = CanInspect
local UnitGUID = UnitGUID
local select = select
local GetNumGroupMembers = GetNumGroupMembers
local format = string.format
local C_Timer_After = C_Timer.After
local IsInInstance = IsInInstance

HM.healerFrames = {}
HM.currentHealers = {}
HM.inspectQueue = {}
HM.specCache = {}

local FALLBACK_ICON = 135915
local PREVIEW_SPECS = { 105, 270, 65, 256, 257, 264, 1468 }
local INSPECT_DELAY = 0.05

function HM:UpdateDB()
    self.db = NRSKNUI.db.profile.HealerMana
end

function HM:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

function HM:HideAllFrames()
    wipe(self.currentHealers)
    self:ClearInspectQueue()
    for _, frame in pairs(self.healerFrames) do frame:Hide() end
    if self.containerFrame then self.containerFrame:Hide() end
end

function HM:UpdateManaDisplay(frame, unit, connected)
    if connected then
        local manaColor = self.db.HighManaColor
        frame.mana:SetTextColor(manaColor[1], manaColor[2], manaColor[3])
        frame.icon:SetVertexColor(1, 1, 1)
        local pct = UnitPowerPercent(unit, Enum.PowerType.Mana, true, CurveConstants.ScaleTo100)
        frame.mana:SetText(format("%.0f%%", pct))
    else
        frame.mana:SetTextColor(0.5, 0.5, 0.5)
        frame.mana:SetText("OFFLINE")
        frame.icon:SetVertexColor(0.4, 0.4, 0.4)
    end
end

function HM:CreateHealerFrame(index)
    local frame = CreateFrame("Frame", "NorskenUI_HealerMana_" .. index, self.containerFrame)
    frame:SetSize(self.db.FrameWidth, self.db.IconSize)

    frame.iconFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.iconFrame:SetSize(self.db.IconSize, self.db.IconSize)
    frame.iconFrame:SetPoint("LEFT", frame, "LEFT", 0, 0)
    frame.iconFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame.iconFrame:SetBackdropColor(0, 0, 0, 1)
    frame.iconFrame:SetBackdropBorderColor(0, 0, 0, 1)

    frame.icon = frame.iconFrame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetPoint("TOPLEFT", 1, -1)
    frame.icon:SetPoint("BOTTOMRIGHT", -1, 1)

    frame.name = frame:CreateFontString(nil, "OVERLAY")
    frame.name:SetPoint("BOTTOMLEFT", frame.iconFrame, "RIGHT", 4, self.db.NameYOffset)
    frame.name:SetJustifyH("LEFT")
    frame.name:SetFontStyle(self.db, self.db.NameFontSize)

    frame.mana = frame:CreateFontString(nil, "OVERLAY")
    frame.mana:SetPoint("TOPLEFT", frame.iconFrame, "RIGHT", 4, self.db.ManaYOffset)
    frame.mana:SetJustifyH("LEFT")
    frame.mana:SetFontStyle(self.db, self.db.ManaFontSize)

    frame:Hide()
    return frame
end

function HM:GetHealerFrame(index)
    if not self.healerFrames[index] then self.healerFrames[index] = self:CreateHealerFrame(index) end
    return self.healerFrames[index]
end

function HM:CreateContainer()
    if self.containerFrame then return self.containerFrame end

    local frame = CreateFrame("Frame", "NorskenUI_HealerMana_Container", UIParent)
    frame:SetSize(self.db.FrameWidth, self.db.IconSize)

    self.containerFrame = frame
    self:ApplyPosition()
    return frame
end

function HM:GetGrowAnchor(anchor)
    local growDown = self.db.GrowDirection == "DOWN"
    local verticalTarget = growDown and "TOP" or "BOTTOM"
    local verticalOpposite = growDown and "BOTTOM" or "TOP"

    if anchor:find(verticalOpposite) then
        return anchor:gsub(verticalOpposite, verticalTarget)
    elseif anchor:find(verticalTarget) then
        return anchor
    elseif anchor == "LEFT" then
        return verticalTarget .. "LEFT"
    elseif anchor == "RIGHT" then
        return verticalTarget .. "RIGHT"
    else
        return verticalTarget
    end
end

function HM:GetCurrentPosition()
    if self.isPreview and self.previewContext then
        return self.previewContext == "raid" and self.db.RaidPosition or self.db.PartyPosition
    end
    if not self.db.SplitPositioning then return self.db.PartyPosition end
    local inRaid = IsInRaid()
    return inRaid and self.db.RaidPosition or self.db.PartyPosition
end

function HM:SetPreviewContext(context)
    self.previewContext = context
    if self.isPreview then
        self:ApplyPosition()
    end
end

function HM:ApplyPosition()
    if not self.containerFrame then return end

    local pos = self:GetCurrentPosition()
    local adjustedPos = {
        AnchorFrom = self:GetGrowAnchor(pos.AnchorFrom),
        AnchorTo = pos.AnchorTo,
        XOffset = pos.XOffset,
        YOffset = pos.YOffset,
    }

    self.containerFrame:ApplyPosition(adjustedPos)
end

function HM:UpdateContainerSize()
    if not self.containerFrame then return end

    local count = #self.currentHealers
    if count == 0 then
        self.containerFrame:SetSize(self.db.FrameWidth, self.db.IconSize)
        return
    end

    local totalHeight = (self.db.IconSize * count) + (self.db.FrameSpacing * (count - 1))
    self.containerFrame:SetSize(self.db.FrameWidth, totalHeight)
end

function HM:PositionFrames()
    local growDown = self.db.GrowDirection == "DOWN"
    local spacing = self.db.FrameSpacing
    local iconSize = self.db.IconSize

    for i, healer in ipairs(self.currentHealers) do
        local frame = self.healerFrames[healer.frameIndex]
        if frame then
            frame:ClearAllPoints()
            local yOffset = (i - 1) * (iconSize + spacing)
            if growDown then
                frame:SetPoint("TOPLEFT", self.containerFrame, "TOPLEFT", 0, -yOffset)
            else
                frame:SetPoint("BOTTOMLEFT", self.containerFrame, "BOTTOMLEFT", 0, yOffset)
            end
        end
    end
end

function HM:QueueInspect(healer)
    if not healer or not healer.unit or not healer.guid then return end
    for _, queued in ipairs(self.inspectQueue) do if queued.guid == healer.guid then return end end
    self.inspectQueue[#self.inspectQueue + 1] = healer
    self:ProcessInspectQueue()
end

function HM:ProcessInspectQueue()
    if self.currentInspect then return end
    if #self.inspectQueue == 0 then return end

    local healer = self.inspectQueue[1]
    if not healer or not UnitExists(healer.unit) or not CanInspect(healer.unit) then
        table.remove(self.inspectQueue, 1)
        C_Timer_After(0.1, function() self:ProcessInspectQueue() end)
        return
    end

    self.currentInspect = healer.guid
    NotifyInspect(healer.unit)

    C_Timer_After(2, function()
        if self.currentInspect == healer.guid then
            self.currentInspect = nil
            self:ProcessInspectQueue()
        end
    end)
end

function HM:OnInspectReady(guid)
    if self.currentInspect ~= guid then return end
    self.currentInspect = nil

    for i, queued in ipairs(self.inspectQueue) do
        if queued.guid == guid then
            table.remove(self.inspectQueue, i)
            break
        end
    end

    local healer = self:GetHealerByGUID(guid)
    if not healer or not UnitExists(healer.unit) then
        C_Timer_After(INSPECT_DELAY, function() self:ProcessInspectQueue() end)
        return
    end

    local specID = GetInspectSpecialization(healer.unit)
    if specID and specID > 0 then
        self.specCache[guid] = specID
        healer.specID = specID
        self:UpdateHealerFrame(healer)
    end

    C_Timer_After(INSPECT_DELAY, function() self:ProcessInspectQueue() end)
end

function HM:GetHealerByGUID(guid)
    for _, healer in ipairs(self.currentHealers) do
        if healer.guid == guid then
            return healer
        end
    end
    return nil
end

function HM:OnSpecChanged(_, unit)
    if not unit then return end

    local _, instanceType = IsInInstance()
    if instanceType == "arena" or instanceType == "pvp" then return end

    local guid = UnitGUID(unit)
    if guid then
        self.specCache[guid] = nil
    end

    C_Timer_After(0.5, function()
        self:FindHealers()
    end)
end

function HM:ClearInspectQueue()
    wipe(self.inspectQueue)
    self.currentInspect = nil
end

function HM:FindHealers()
    if not self.db or not self.db.Enabled then return end
    if self.isPreview then return end

    local _, instanceType = IsInInstance()
    if instanceType == "arena" or instanceType == "pvp" then
        self:HideAllFrames()
        return
    end

    local inRaid = IsInRaid()
    local inGroup = IsInGroup()

    local currentGroupType = inRaid and "raid" or (inGroup and "party" or nil)
    local groupTypeChanged = self.lastGroupType ~= currentGroupType
    self.lastGroupType = currentGroupType

    if not inGroup then
        self:HideAllFrames()
        return
    end

    if inRaid and not self.db.EnableInRaid then
        self:HideAllFrames()
        return
    end

    if groupTypeChanged then
        self:ClearInspectQueue()
        self:ApplyPosition()
    end

    local prevHealerCount = #self.currentHealers
    wipe(self.currentHealers)
    local healerCount = 0
    local maxHealers = inRaid and self.db.MaxHealers or 1

    if inRaid then
        local numMembers = GetNumGroupMembers()
        for i = 1, numMembers do
            if healerCount >= maxHealers then break end

            local unit = "raid" .. i
            if UnitExists(unit) and UnitGroupRolesAssigned(unit) == "HEALER" then
                healerCount = healerCount + 1
                self:AddHealer(unit, healerCount)
            end
        end
    else
        for i = 1, 4 do
            if healerCount >= maxHealers then break end

            local unit = "party" .. i
            if UnitExists(unit) and UnitGroupRolesAssigned(unit) == "HEALER" then
                healerCount = healerCount + 1
                self:AddHealer(unit, healerCount)
            end
        end
    end

    if healerCount == 0 then
        self:HideAllFrames()
        return
    end

    for i = healerCount + 1, prevHealerCount do
        if self.healerFrames[i] then self.healerFrames[i]:Hide() end
    end

    self:UpdateContainerSize()
    self:PositionFrames()

    for _, healer in ipairs(self.currentHealers) do self:UpdateHealerFrame(healer) end

    self.containerFrame:Show()
end

function HM:AddHealer(unit, frameIndex)
    local healerName = UnitName(unit)
    if issecretvalue and issecretvalue(healerName) then healerName = "Healer" end
    local _, healerClass = UnitClass(unit)
    local guid = UnitGUID(unit)

    local healer = {
        unit = unit,
        guid = guid,
        name = healerName,
        class = healerClass,
        classColor = NRSKNUI:GetClassColor(healerClass),
        connected = UnitIsConnected(unit),
        frameIndex = frameIndex,
        specID = self.specCache[guid],
    }

    self.currentHealers[#self.currentHealers + 1] = healer
end

function HM:UpdateHealerFrame(healer)
    if not healer then return end
    local frame = self:GetHealerFrame(healer.frameIndex)

    local icon
    if healer.specID then
        icon = select(4, GetSpecializationInfoByID(healer.specID))
    else
        self:QueueInspect(healer)
    end

    frame.icon:SetTexture(icon or FALLBACK_ICON)
    frame.icon:SetZoom()

    frame.name:SetText(healer.name)
    frame.name:SetTextColor(healer.classColor[1], healer.classColor[2], healer.classColor[3])

    self:UpdateManaDisplay(frame, healer.unit, healer.connected)

    frame:Show()
end

function HM:UpdateMana()
    if self.isPreview then return end

    for _, healer in ipairs(self.currentHealers) do
        local frame = self.healerFrames[healer.frameIndex]
        if frame and frame:IsShown() then
            local connected = UnitIsConnected(healer.unit)
            healer.connected = connected
            self:UpdateManaDisplay(frame, healer.unit, connected)
        end
    end
end

function HM:ShowPreview()
    self:UpdateDB()
    if not self.db then return end

    self.isPreview = true
    self:CreateContainer()

    wipe(self.currentHealers)
    local previewCount = self.db.MaxHealers

    for i = 1, previewCount do
        local specID = PREVIEW_SPECS[((i - 1) % #PREVIEW_SPECS) + 1]
        local _, _, _, icon, _, class = GetSpecializationInfoByID(specID)

        local healer = {
            unit = "player",
            guid = "preview" .. i,
            name = i == 1 and UnitName("player") or ("Healer " .. i),
            class = class,
            classColor = NRSKNUI:GetClassColor(class),
            connected = true,
            frameIndex = i,
            specID = specID,
        }
        self.currentHealers[i] = healer

        local frame = self:GetHealerFrame(i)
        frame:SetSize(self.db.FrameWidth, self.db.IconSize)
        frame.iconFrame:SetSize(self.db.IconSize, self.db.IconSize)
        frame.name:ClearAllPoints()
        frame.name:SetPoint("BOTTOMLEFT", frame.iconFrame, "RIGHT", 4, self.db.NameYOffset)
        frame.name:SetFontStyle(self.db, self.db.NameFontSize)
        frame.mana:ClearAllPoints()
        frame.mana:SetPoint("TOPLEFT", frame.iconFrame, "RIGHT", 4, self.db.ManaYOffset)
        frame.mana:SetFontStyle(self.db, self.db.ManaFontSize)

        frame.icon:SetTexture(icon or FALLBACK_ICON)
        frame.icon:SetVertexColor(1, 1, 1)
        frame.icon:SetZoom()

        frame.name:SetText(healer.name)
        frame.name:SetTextColor(healer.classColor[1], healer.classColor[2], healer.classColor[3])

        local manaColor = self.db.HighManaColor
        frame.mana:SetTextColor(manaColor[1], manaColor[2], manaColor[3])
        frame.mana:SetText(format("%d%%", math.random(1, 100)))

        frame:Show()
    end

    for i = previewCount + 1, #self.healerFrames do self.healerFrames[i]:Hide() end

    self:UpdateContainerSize()
    self:PositionFrames()
    self.containerFrame:Show()
end

function HM:HidePreview()
    self.isPreview = false
    self.previewContext = nil
    self:HideAllFrames()

    if self.db and self.db.Enabled then
        self:ApplyPosition()
        self:FindHealers()
    end
end

function HM:ApplySettings()
    self:UpdateDB()
    if not self.db or not self.db.Enabled then
        if self.containerFrame then self.containerFrame:Hide() end
        return
    end

    self:CreateContainer()
    self:ApplyPosition()

    for _, frame in pairs(self.healerFrames) do
        frame:SetSize(self.db.FrameWidth, self.db.IconSize)
        frame.iconFrame:SetSize(self.db.IconSize, self.db.IconSize)
        frame.name:ClearAllPoints()
        frame.name:SetPoint("BOTTOMLEFT", frame.iconFrame, "RIGHT", 4, self.db.NameYOffset)
        frame.name:SetFontStyle(self.db, self.db.NameFontSize)
        frame.mana:ClearAllPoints()
        frame.mana:SetPoint("TOPLEFT", frame.iconFrame, "RIGHT", 4, self.db.ManaYOffset)
        frame.mana:SetFontStyle(self.db, self.db.ManaFontSize)
    end

    self:UpdateContainerSize()

    if self.isPreview then
        self:ShowPreview()
    else
        self:FindHealers()
    end
end

function HM:StartUpdates()
    if self.updateTimer then return end
    self.updateTimer = self:ScheduleRepeatingTimer("UpdateMana", 1)
end

function HM:StopUpdates()
    if self.updateTimer then
        self:CancelTimer(self.updateTimer)
        self.updateTimer = nil
    end
end

function HM:OnEnable()
    self:UpdateDB()
    if not self.db or not self.db.Enabled then return end

    self:ApplySettings()
    self:StartUpdates()
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "FindHealers")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "FindHealers")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "OnSpecChanged")
    self:RegisterEvent("INSPECT_READY", function(_, guid) HM:OnInspectReady(guid) end)

    C_Timer_After(0.5, function() self:ApplyPosition() end)

    EM:Register(self, 'HealerMana', self.containerFrame, 'HealerMana')
end

function HM:OnDisable()
    self:StopUpdates()
    self:UnregisterAllEvents()
    wipe(self.currentHealers)
    wipe(self.specCache)
    self:ClearInspectQueue()
    self.lastGroupType = nil
    self.isPreview = false
    if self.containerFrame then self.containerFrame:Hide() end
    for _, frame in pairs(self.healerFrames) do frame:Hide() end
end
