---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class MinimapModule
local Map = NRSKNUI:GetModule('Minimap')
function Map:UpdateDB() self.db = NRSKNUI.db.profile.Skinning.Minimap end

local Theme = NRSKNUI.Theme
local Anchors = NRSKNUI.Anchors

local hooksecurefunc = hooksecurefunc
local ipairs = ipairs
local CreateFrame = CreateFrame
local unpack = unpack
local IsMouseButtonDown = IsMouseButtonDown
local HideUIPanel = HideUIPanel
local ShowUIPanel = ShowUIPanel

local math_floor = math.floor

local mailBtn = MiniMapMailIcon
local qBtn = QueueStatusButton
local missionBtn = ExpansionLandingPageMinimapButton
local AddonComp = AddonCompartmentFrame
local _G = _G

local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded
local LoadAddOn = C_AddOns and C_AddOns.LoadAddOn

local hooked = {
    border = false,
    queuePosition = false,
    addonCompEnter = false,
    bugSackButton = nil,
}

local lastAppliedSize = nil
local pendingSizeRefresh = false

function Map:OnEnable()
    if NRSKNUI:ShouldNotLoadModule() then return end

    self:StripBlizzMap()
    self:CreateBugSackButton()
    self:ApplySettings()
    self:ApplyButtonReg()

    if not hooked.queuePosition then
        hooksecurefunc(QueueStatusButton, 'UpdatePosition', function() self:UpdateQueueBtn() end)
        hooked.queuePosition = true
    end

    -- Disable minimap in EditMode.
    _G.MinimapCluster:NUIBanish()

    self:RegisterEvent('PLAYER_ENTERING_WORLD')
    Anchors:Register(self, 'Minimap', _G.Minimap, 'minimap', { xKey = 'X', yKey = 'Y' })
end

function Map:PLAYER_ENTERING_WORLD()
    C_Timer.After(0.1, function() self:ApplySettings() end)
end

function Map:StripBlizzMap()
    Minimap:SetParent(UIParent)
    if not Minimap.Layout then Minimap.Layout = nop end

    MinimapCluster.Tracking:SetParent(Minimap)
    MinimapCluster.IndicatorFrame.MailFrame:SetParent(Minimap)
    MinimapCluster.InstanceDifficulty:SetParent(Minimap)
    missionBtn:SetParent(Minimap)

    Minimap:SetMaskTexture('Interface\\BUTTONS\\WHITE8X8')
    MinimapCompassTexture:SetTexture(nil)

    _G['MinimapCluster']:NUIBanish()
    _G['MinimapCompassTexture']:NUIBanish()
    _G['MinimapCluster']:NUIBanish('BorderTop')
    _G['MinimapCluster']:NUIBanish('ZoneTextButton')
    _G['Minimap']:NUIBanish('ZoomIn')
    _G['Minimap']:NUIBanish('ZoomOut')
    _G['Minimap']:NUIBanish('ZoomHitArea')
    _G['GameTimeFrame']:NUIBanish()

    MinimapCluster.Tracking:ClearAllPoints()
    MinimapCluster.Tracking.Button:SetMenuAnchor(AnchorUtil.CreateAnchor('TOPRIGHT', Minimap, 'BOTTOMLEFT'))
end

function Map:UpdateAddonCompartment()
    if not AddonComp then return end

    if not self.db.AddOnComp.Enabled then
        Minimap.SetParent(AddonComp, NRSKNUI.HiddenFrame)
        return
    end

    AddonComp:NUIStripTextures('Layer', { 'ARTWORK', 'HIGHLIGHT' })
    AddonComp:SetParent(Minimap)
    AddonComp:SetScale(1 / self.db.Scale)
    AddonComp:ClearAllPoints()
    AddonComp:SetSize(self.db.AddOnComp.Size, self.db.AddOnComp.Size)
    AddonComp:SetPoint(self.db.AddOnComp.Anchor, Minimap, self.db.AddOnComp.Anchor, self.db.AddOnComp.X, self.db.AddOnComp.Y)
    AddonComp:SetFrameLevel(Minimap:GetFrameLevel() + 2)
    AddonComp:NUICreateBackdrop()

    local textSize = math_floor(self.db.AddOnComp.Size * 0.6)
    AddonComp.Text:SetFontStyle(self.db, textSize, nil, nil, nil, true)
    AddonComp.Text:SetFontJustify("Center", AddonComp, 1, 0)
    AddonComp.Text:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)

    if not hooked.addonCompEnter then
        AddonComp:HookScript('OnEnter', function()
            AddonComp:SetBorderColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
        end)
        AddonComp:HookScript('OnLeave', function()
            AddonComp:SetBorderColor(0, 0, 0, 1)
        end)
        hooked.addonCompEnter = true
    end
end

function Map:ApplyButtonReg()
    if self.clickOverlay then return end

    local clickOverlay = CreateFrame('Frame', nil, Minimap)
    clickOverlay:SetAllPoints()
    clickOverlay:EnableMouse(true)
    clickOverlay:SetPassThroughButtons('LeftButton')
    clickOverlay:SetPropagateMouseMotion(true)
    clickOverlay:SetScript('OnMouseUp', function(_, button)
        if button == 'MiddleButton' then -- Middle-click: open calendar
            if NRSKNUI:InCombat() then
                NRSKNUI:Print('Cannot open calendar in combat.')
            else
                if not IsAddOnLoaded('Blizzard_Calendar') then LoadAddOn('Blizzard_Calendar') end
                if CalendarFrame:IsShown() then
                    HideUIPanel(CalendarFrame)
                else
                    ShowUIPanel(CalendarFrame)
                end
            end
        elseif button == 'RightButton' then -- Right-click: open tracking menu
            MinimapCluster.Tracking.Button:OpenMenu()
        end
    end)
    self.clickOverlay = clickOverlay
end

function Map:UpdateMinimapBorder()
    if not hooked.border then
        Minimap.Border = CreateFrame('Frame', nil, Minimap, 'BackdropTemplate')
        Minimap.Border:SetAllPoints(Minimap)
        Minimap.Border:SetFrameLevel(Minimap:GetFrameLevel() + 1)
        hooked.border = true
    end

    Minimap.Border:SetScale(1 / self.db.Scale)
    Minimap.Border:SetBackdrop({ edgeFile = 'Interface\\Buttons\\WHITE8X8', edgeSize = self.db.Border.Thickness, })
    Minimap.Border:SetBackdropBorderColor(unpack(self.db.Border.Color))
end

function Map:UpdateMailBtn()
    if not mailBtn then return end
    local mailFrame = MinimapCluster.IndicatorFrame.MailFrame
    local db = self.db.Mail

    if not db.Enabled then
        Minimap.SetParent(mailFrame, NRSKNUI.HiddenFrame)
        return
    end

    Minimap.SetParent(mailFrame, Minimap)
    mailBtn:ClearAllPoints()
    mailBtn:SetPoint('CENTER', mailFrame, 'CENTER', 0, 0)
    mailFrame:SetScale(db.Scale)
    mailFrame:ClearAllPoints()
    mailFrame:SetPoint(db.Anchor, Minimap, db.Anchor, db.X, db.Y)
end

local landingPageHooked = false

function Map:UpdateLandingPageBtn()
    if not missionBtn then return end

    local lpDB = self.db.LandingPage
    local size = lpDB.Size

    if not lpDB.Enabled then
        Minimap.SetParent(missionBtn, NRSKNUI.HiddenFrame)
        return
    end

    Minimap.SetParent(missionBtn, Minimap)
    Minimap.SetScale(missionBtn, 1 / self.db.Scale)
    Minimap.SetSize(missionBtn, size, size)
    Minimap.ClearAllPoints(missionBtn)
    Minimap.SetPoint(missionBtn, lpDB.Anchor, Minimap, lpDB.Anchor, lpDB.X, lpDB.Y)

    if not landingPageHooked then
        local function ForcePosition()
            if not self.db.LandingPage.Enabled then return end
            local db = self.db.LandingPage
            Minimap.ClearAllPoints(missionBtn)
            Minimap.SetPoint(missionBtn, db.Anchor, Minimap, db.Anchor, db.X, db.Y)
        end

        hooksecurefunc(missionBtn, 'SetSize', function()
            if not self.db.LandingPage.Enabled then return end
            Minimap.SetSize(missionBtn, self.db.LandingPage.Size, self.db.LandingPage.Size)
        end)

        if missionBtn.UpdateIconForGarrison then
            hooksecurefunc(missionBtn, 'UpdateIconForGarrison', ForcePosition)
        end

        if missionBtn.SetLandingPageIconOffset then
            hooksecurefunc(missionBtn, 'SetLandingPageIconOffset', ForcePosition)
        end

        -- Other pepega addons sometimes reparent this button out from us, pull it
        -- back to whichever parent our setting dictates (Minimap when enabled,
        -- HiddenFrame when disabled). Calling via Minimap.SetParent uses the
        -- un-hooked method, so this doesn't recurse.
        hooksecurefunc(missionBtn, 'SetParent', function(_, parent)
            local target = self.db.LandingPage.Enabled and Minimap or NRSKNUI.HiddenFrame
            if parent == target then return end
            Minimap.SetParent(missionBtn, target)
            if self.db.LandingPage.Enabled then ForcePosition() end
        end)

        landingPageHooked = true
    end
end

function Map:UpdateInstanceBtn()
    local db = self.db.InstanceDifficulty
    local instanceFrame = MinimapCluster.InstanceDifficulty

    if not db.Enabled then
        Minimap.SetParent(instanceFrame, NRSKNUI.HiddenFrame)
        return
    end

    Minimap.SetParent(instanceFrame, Minimap)
    instanceFrame:SetScale(db.Scale)
    instanceFrame:ClearAllPoints()
    instanceFrame:SetPoint(db.Anchor, Minimap, db.Anchor, db.X, db.Y)

    for _, child in ipairs({ instanceFrame.ChallengeMode, instanceFrame.Default, instanceFrame.Guild }) do
        child:ClearAllPoints()
        child:SetPoint('CENTER', instanceFrame, 'CENTER', 0, 0)
    end
end

function Map:UpdateQueueBtn()
    if not qBtn then return end

    local db = self.db.QueueStatus

    if not db.Enabled then
        Minimap.SetParent(qBtn, NRSKNUI.HiddenFrame)
        return
    end

    Minimap.SetParent(qBtn, Minimap)
    qBtn:ClearAllPoints()
    qBtn:SetPoint(db.Anchor, Minimap, db.Anchor, db.X, db.Y)
    qBtn:SetScale(db.Scale)
    qBtn:SetFrameLevel(10)
end

---@class MinimapLayoutOpts
---@field scaleChanged? boolean GUI scale slider changed - recalculate position to compensate
---@field deferZoom? boolean GUI size slider - defer zoom refresh until mouse released

---@param opts? MinimapLayoutOpts
function Map:ApplyLayout(opts)
    opts = opts or {}

    if opts.scaleChanged then
        local oldScale = Minimap:GetScale()
        local newScale = self.db.Scale
        if oldScale ~= newScale then
            local ratio = oldScale / newScale
            self.db.Position.X = self.db.Position.X * ratio
            self.db.Position.Y = self.db.Position.Y * ratio
        end
    end

    Minimap:SetScale(self.db.Scale)
    Minimap:ClearAllPoints()
    Minimap:SetPoint(
        self.db.Position.AnchorFrom, UIParent, self.db.Position.AnchorTo,
        self.db.Position.X, self.db.Position.Y
    )

    local newSize = self.db.Size
    Minimap:SetSize(newSize, newSize)

    if lastAppliedSize ~= newSize then
        if opts.deferZoom then
            if not pendingSizeRefresh then
                pendingSizeRefresh = true
                local function CheckAndRefresh()
                    if IsMouseButtonDown('LeftButton') then
                        C_Timer.After(0.1, CheckAndRefresh)
                        return
                    end
                    pendingSizeRefresh = false
                    if lastAppliedSize ~= self.db.Size then
                        lastAppliedSize = self.db.Size
                        Minimap:SetZoom(1)
                        Minimap:SetZoom(0)
                    end
                end
                C_Timer.After(0.1, CheckAndRefresh)
            end
        else
            lastAppliedSize = newSize
            Minimap:SetZoom(1)
            Minimap:SetZoom(0)
        end
    end
end

---@param btn Button
local function UpdateBugSackButtonState(btn)
    if not btn then return end

    local bugSack = _G.BugSack
    local bugGrabber = _G.BugGrabber
    local count = #bugSack:GetErrors(bugGrabber:GetSessionId())

    if count == 0 then
        btn.Text:SetTextColor(0.25, 1, 0.25)
    else
        btn.Text:SetTextColor(1, 0.25, 0.25)
    end
    btn.Text:SetText(count)
end

function Map:UpdateBugSackButton()
    local btn = hooked.bugSackButton
    if not btn or not self.db.BugSack.Enabled then return end

    btn:SetScale(1 / self.db.Scale)
    btn:SetSize(self.db.BugSack.Size, self.db.BugSack.Size)

    btn:ClearAllPoints()
    btn:SetPoint(self.db.BugSack.Anchor, Minimap, self.db.BugSack.Anchor, self.db.BugSack.X, self.db.BugSack.Y)

    btn.Text:SetFontStyle(self.db, self.db.BugSack.Size - 4)

    UpdateBugSackButtonState(btn)
    btn:Show()
end

function Map:CreateBugSackButton()
    if not self.db.BugSack.Enabled then
        if hooked.bugSackButton then
            hooked.bugSackButton:Hide()
        end
        return
    end

    if not IsAddOnLoaded('BugSack') then return end
    if not IsAddOnLoaded('!BugGrabber') then return end

    local bugSackLDB = NRSKNUI.Libs.LDB:GetDataObjectByName('BugSack')
    if not bugSackLDB then return end

    local bugSack = _G.BugSack
    local bugGrabber = _G.BugGrabber
    if (not bugSack) or
        (not bugGrabber) or
        (not bugSack.UpdateDisplay) or
        (not bugSack.GetErrors) then
        return
    end

    if not hooked.bugSackButton then
        local btn = CreateFrame('Button', 'NRSKNUI_BugSackButton', Minimap)
        btn:SetScale(1 / self.db.Scale)
        btn:SetSize(self.db.BugSack.Size, self.db.BugSack.Size)
        btn:NUICreateBackdrop()

        btn.Text = btn:CreateFontString(nil, 'OVERLAY')
        btn.Text:SetFontStyle(self.db, self.db.BugSack.Size - 4)
        btn.Text:SetPoint('CENTER')

        -- Set inital state of the button based on the current error count.
        UpdateBugSackButtonState(btn)

        btn:SetScript('OnClick', function(_, mouseButton)
            if bugSackLDB.OnClick then
                bugSackLDB.OnClick(btn, mouseButton)
            end
        end)

        btn:SetScript('OnEnter', function()
            btn:SetBorderColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
            if bugSackLDB.OnTooltipShow then
                GameTooltip:SetOwner(btn, 'ANCHOR_NONE')
                GameTooltip:SetPoint('BOTTOMRIGHT', Minimap, 'BOTTOMLEFT', -2, -1)
                bugSackLDB.OnTooltipShow(GameTooltip)
                GameTooltip:Show()
            end
        end)

        btn:SetScript('OnLeave', function()
            btn:SetBorderColor(0, 0, 0, 1)
            GameTooltip:Hide()
        end)

        -- Update the button state whenever BugSack updates its display.
        hooksecurefunc(bugSack, 'UpdateDisplay', function()
            if self.db.BugSack.Enabled then
                UpdateBugSackButtonState(btn)
            end
        end)

        -- If HidingBar addon is loaded, auto add our button to the ignore list.
        if IsAddOnLoaded('HidingBar') then
            local HidingBarPublicAPI = _G.HidingBarAddon

            if HidingBarPublicAPI and HidingBarPublicAPI.addToIgnoreFrameList then
                HidingBarPublicAPI:addToIgnoreFrameList('NRSKNUI_BugSackButton')
            end
        end

        hooked.bugSackButton = btn
    end

    self:UpdateBugSackButton()
end

---@param opts? MinimapLayoutOpts
function Map:ApplySettings(opts)
    if NRSKNUI:ShouldNotLoadModule() then return end
    if not self.db.Enabled then return end
    NRSKNUI:RunWhenSafe(function()
        self:ApplyLayout(opts)
        self:UpdateMinimapBorder()
        self:UpdateMailBtn()
        self:UpdateInstanceBtn()
        self:UpdateQueueBtn()
        self:UpdateLandingPageBtn()
        self:UpdateBugSackButton()
        self:UpdateAddonCompartment()
    end)
end
