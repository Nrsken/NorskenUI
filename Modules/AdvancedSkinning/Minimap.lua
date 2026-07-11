---@class NRSKNUI
local NRSKNUI = select(2, ...)
local Theme = NRSKNUI.Theme

local hooksecurefunc = hooksecurefunc
local ipairs = ipairs
local CreateFrame = CreateFrame
local unpack = unpack
local InCombatLockdown = InCombatLockdown
local IsMouseButtonDown = IsMouseButtonDown
local HideUIPanel = HideUIPanel
local ShowUIPanel = ShowUIPanel

local mailBtn = MiniMapMailIcon
local qBtn = QueueStatusButton
local missionBtn = ExpansionLandingPageMinimapButton
local _G = _G

local hooked = {
    border = false,
    queuePosition = false,
    addonCompEnter = false,
    bugSackButton = nil,
}

local lastAppliedSize = nil
local pendingSizeRefresh = false
local pendingCombatUpdate = false

---@class Minimap: AceModule, AceEvent-3.0
local MAP = NRSKNUI:NewModule('Minimap', 'AceEvent-3.0')

function MAP:UpdateDB()
    self.db = NRSKNUI.db.profile.Skinning.Minimap
end

function MAP:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

local function DisableMinimapEditMode()
    if not MinimapCluster then return end
    NRSKNUI:Hide(MinimapCluster)
end

function MAP:OnEnable()
    if NRSKNUI:ShouldNotLoadModule() then return end
    if not self.db.Enabled then return end

    self:StripBlizzMap()
    self:CreateBugSackButton()
    self:ApplySettings()
    self:ApplyButtonReg()

    if not hooked.queuePosition then
        hooksecurefunc(QueueStatusButton, 'UpdatePosition', function() self:UpdateQueueBtn() end)
        hooked.queuePosition = true
    end

    C_Timer.After(0.5, DisableMinimapEditMode)

    self:RegisterEvent('PLAYER_ENTERING_WORLD')

    NRSKNUI.EditMode:RegisterElement({
        key = 'Minimap',
        displayName = 'Minimap',
        frame = Minimap,
        getPosition = function()
            local pos = self.db.Position
            return {
                AnchorFrom = pos.AnchorFrom,
                AnchorTo = pos.AnchorTo,
                XOffset = pos.X,
                YOffset = pos.Y,
            }
        end,
        setPosition = function(pos)
            self.db.Position.AnchorFrom = pos.AnchorFrom
            self.db.Position.AnchorTo = pos.AnchorTo
            self.db.Position.X = pos.XOffset
            self.db.Position.Y = pos.YOffset
            Minimap:ClearAllPoints()
            Minimap:SetPoint(pos.AnchorFrom, UIParent, pos.AnchorTo, pos.XOffset, pos.YOffset)
        end,
        guiPath = 'Minimap',
    })
end

function MAP:PLAYER_REGEN_ENABLED()
    self:UnregisterEvent('PLAYER_REGEN_ENABLED')
    pendingCombatUpdate = false
    self:ApplySettings()
end

function MAP:PLAYER_ENTERING_WORLD()
    C_Timer.After(0.1, function() self:ApplySettings() end)
end

function MAP:StripBlizzMap()
    Minimap:SetParent(UIParent)
    if not Minimap.Layout then Minimap.Layout = nop end

    MinimapCluster.Tracking:SetParent(Minimap)
    MinimapCluster.IndicatorFrame.MailFrame:SetParent(Minimap)
    MinimapCluster.InstanceDifficulty:SetParent(Minimap)
    missionBtn:SetParent(Minimap)

    Minimap:SetMaskTexture('Interface\\BUTTONS\\WHITE8X8')
    MinimapCompassTexture:SetTexture(nil)

    NRSKNUI:Hide('MinimapCluster') -- gtfo lilpup, does so much wierd shit so we yeet it
    NRSKNUI:Hide('MinimapCompassTexture')
    NRSKNUI:Hide('MinimapCluster', 'BorderTop')
    NRSKNUI:Hide('MinimapCluster', 'ZoneTextButton')
    NRSKNUI:Hide('Minimap', 'ZoomIn')
    NRSKNUI:Hide('Minimap', 'ZoomOut')
    NRSKNUI:Hide('Minimap', 'ZoomHitArea')
    NRSKNUI:Hide('GameTimeFrame')

    MinimapCluster.Tracking:ClearAllPoints()
    MinimapCluster.Tracking.Button:SetMenuAnchor(AnchorUtil.CreateAnchor('TOPRIGHT', Minimap, 'BOTTOMLEFT'))
end

function MAP:UpdateAddonCompartment()
    if not AddonCompartmentFrame then return end

    local db = self.db.AddOnComp

    if not db.Enabled then
        Minimap.SetParent(AddonCompartmentFrame, NRSKNUI.HiddenFrame)
        return
    end

    for _, region in ipairs({ AddonCompartmentFrame:GetRegions() }) do
        if region:GetObjectType() == 'Texture' then
            local layer = region:GetDrawLayer()
            if layer == 'ARTWORK' or layer == 'HIGHLIGHT' then
                region:Hide()
                region:SetAlpha(0)
            end
        end
    end

    local bg = NRSKNUI:CreateStandardBackdrop(AddonCompartmentFrame, 'NRSKNUI_AddonCompBG', Minimap:GetFrameLevel() + 1)
    bg:SetAllPoints()

    if not hooked.addonCompEnter then
        AddonCompartmentFrame:HookScript('OnEnter', function()
            bg:SetBorderColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
        end)
        AddonCompartmentFrame:HookScript('OnLeave', function()
            bg:SetBorderColor(0, 0, 0, 1)
        end)
        hooked.addonCompEnter = true
    end

    AddonCompartmentFrame:SetParent(Minimap)
    AddonCompartmentFrame:SetScale(1 / self.db.Scale)
    AddonCompartmentFrame:ClearAllPoints()
    AddonCompartmentFrame:SetSize(db.Size, db.Size)
    AddonCompartmentFrame:SetPoint(db.Anchor, Minimap, db.Anchor, db.X, db.Y)
    AddonCompartmentFrame:SetFrameLevel(Minimap:GetFrameLevel() + 2)

    local textSize = math.floor(db.Size * 0.6)
    local fontFace = NRSKNUI:GetFontPath(NRSKNUI:GetEffectiveFont(self.db))

    AddonCompartmentFrame.Text:SetPoint('CENTER', AddonCompartmentFrame, 'CENTER', 1, 0)
    AddonCompartmentFrame.Text:SetJustifyH('CENTER')
    AddonCompartmentFrame.Text:SetJustifyV('MIDDLE')
    AddonCompartmentFrame.Text:SetFont(fontFace, textSize, 'OUTLINE')
    AddonCompartmentFrame.Text:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    AddonCompartmentFrame.Text:SetShadowColor(0, 0, 0, 0)
    AddonCompartmentFrame.Text:SetShadowOffset(0, 0)
end

function MAP:ApplyButtonReg()
    if self.clickOverlay then return end

    local clickOverlay = CreateFrame('Frame', nil, Minimap)
    clickOverlay:SetAllPoints()
    clickOverlay:EnableMouse(true)
    clickOverlay:SetPassThroughButtons('LeftButton')
    clickOverlay:SetPropagateMouseMotion(true)
    clickOverlay:SetScript('OnMouseUp', function(_, button)
        if button == 'MiddleButton' then -- Middle-click: open calendar
            if InCombatLockdown() then
                NRSKNUI:Print('Cannot open calendar in combat.')
            else
                if not C_AddOns.IsAddOnLoaded('Blizzard_Calendar') then C_AddOns.LoadAddOn('Blizzard_Calendar') end
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

function MAP:UpdateMinimapBorder()
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

function MAP:UpdateMailBtn()
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

function MAP:UpdateLandingPageBtn()
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

function MAP:UpdateInstanceBtn()
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

function MAP:UpdateQueueBtn()
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
function MAP:ApplyLayout(opts)
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

function MAP:CreateBugSackButton()
    if not self.db.BugSack.Enabled then
        if hooked.bugSackButton then
            hooked.bugSackButton:Hide()
        end
        return
    end

    if not C_AddOns.IsAddOnLoaded('BugSack') then return end
    local bugSackLDB = NRSKNUI.Libs.LDB:GetDataObjectByName('BugSack')
    if not bugSackLDB then return end
    local bugAddon = _G['BugSack']
    if not bugAddon or not bugAddon.UpdateDisplay or not bugAddon.GetErrors then return end

    if not hooked.bugSackButton then
        local btn = CreateFrame('Button', 'NRSKNABugSackButton', Minimap, 'BackdropTemplate')
        btn.Text = btn:CreateFontString(nil, 'OVERLAY')
        btn.Text:SetFont('Fonts\\FRIZQT__.TTF', 12, 'OUTLINE')
        btn.Text:SetPoint('CENTER', btn, 'CENTER', 0, 0)
        btn.Text:SetTextColor(1, 1, 1)
        btn.Text:SetText('|cFF40FF400|r')

        btn:SetBackdrop({
            bgFile = 'Interface\\Buttons\\WHITE8x8',
            edgeFile = 'Interface\\Buttons\\WHITE8x8',
            tile = false,
            tileSize = 0,
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        btn:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
        btn:SetBackdropBorderColor(0, 0, 0, 1)

        btn:SetScript('OnClick', function(self, mouseButton)
            if bugSackLDB.OnClick then
                bugSackLDB.OnClick(self, mouseButton)
            end
        end)

        btn:SetScript('OnEnter', function(self)
            btn:SetBackdropBorderColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
            if bugSackLDB.OnTooltipShow then
                GameTooltip:SetOwner(self, 'ANCHOR_NONE')
                GameTooltip:SetPoint('BOTTOMRIGHT', Minimap, 'BOTTOMLEFT', -2, -1)
                bugSackLDB.OnTooltipShow(GameTooltip)
                GameTooltip:Show()
            end
        end)

        btn:SetScript('OnLeave', function()
            btn:SetBackdropBorderColor(0, 0, 0, 1)
            GameTooltip:Hide()
        end)

        hooksecurefunc(bugAddon, 'UpdateDisplay', function()
            local count = #bugAddon:GetErrors(BugGrabber:GetSessionId())
            if count == 0 then
                btn.Text:SetText('|cFF40FF40' .. count .. '|r')
            else
                btn.Text:SetText('|cFFFF4040' .. count .. '|r')
            end
        end)

        hooked.bugSackButton = btn
    end

    self:UpdateBugSackButton()
end

function MAP:UpdateBugSackButton()
    local btn = hooked.bugSackButton
    local db = self.db.BugSack
    if btn and db then
        btn:SetScale(1 / self.db.Scale)
        btn:SetSize(db.Size, db.Size)
        btn:ClearAllPoints()
        btn:SetPoint(db.Anchor, Minimap, db.Anchor, db.X, db.Y)
        btn.Text:SetFont('Fonts\\FRIZQT__.TTF', db.Size - 4, 'OUTLINE')
        btn:Show()
    end
end

---@param opts? MinimapLayoutOpts
function MAP:ApplySettings(opts)
    if NRSKNUI:ShouldNotLoadModule() then return end
    if not self.db.Enabled then return end

    if InCombatLockdown() then
        if not pendingCombatUpdate then
            pendingCombatUpdate = true
            self:RegisterEvent('PLAYER_REGEN_ENABLED')
        end
        return
    end

    self:ApplyLayout(opts)
    self:UpdateMinimapBorder()
    self:UpdateMailBtn()
    self:UpdateInstanceBtn()
    self:UpdateQueueBtn()
    self:UpdateLandingPageBtn()
    self:UpdateBugSackButton()
    self:UpdateAddonCompartment()
end
