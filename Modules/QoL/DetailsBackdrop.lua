---@class NRSKNUI
local NRSKNUI = select(2, ...)

-- Credit to unhalted for the idea of this module, not a copy of his code but liked his cook

---@class DetailsBackdrop: AceModule, AceEvent-3.0
local DBG = NRSKNUI:NewModule("DetailsBackdrop", "AceEvent-3.0")

local unpack = unpack
local _G = _G
local C_AddOns = C_AddOns

local MAX_BACKDROPS = 5
local backdropInitialized = {}

---@param instanceNum number
---@return table|nil
local function GetDetailsInstanceSettings(instanceNum)
    local Details = _G.Details
    if not Details then return nil end

    local instance = Details:GetInstance(instanceNum)
    if not instance or not instance.row_info then return nil end

    return {
        barHeight = instance.row_info.height or 14,
        spacing = instance.row_info.space and instance.row_info.space.between or 1,
        titlebarHeight = instance.titlebar_height or 16,
        width = instance.baseframe and instance.baseframe:GetWidth() or 200,
    }
end

function DBG:UpdateDB()
    self.db = NRSKNUI.db.profile.Skinning.DetailsBackdrop
end

function DBG:OnInitialize()
    self:UpdateDB()
    self.backdrops = {}
    self:SetEnabledState(false)
end

function DBG:OnEnable()
    if NRSKNUI:ShouldNotLoadModule() then return end
    if not C_AddOns.IsAddOnLoaded("Details") then return end
    if not self.db.Enabled then return end

    local Details = _G.Details
    if Details then
        local function OnDetailsEvent()
            for i = 1, MAX_BACKDROPS do
                local bgDB = self.db.backdrops[i]
                if bgDB and bgDB.autoSize then self:UpdateBackdrop(i) end
            end
        end
        self.Enabled = true
        self.__enabled = true
        self._detailsEventCallback = OnDetailsEvent
        Details:RegisterEvent(self, "DETAILS_INSTANCE_SIZECHANGED", OnDetailsEvent)
        Details:RegisterEvent(self, "DETAILS_INSTANCE_ENDRESIZE", OnDetailsEvent)
        Details:RegisterEvent(self, "DETAILS_OPTIONS_MODIFIED", OnDetailsEvent)
    end

    for i = 1, MAX_BACKDROPS do
        if not backdropInitialized[i] then
            self:CreateBackdrop(i)
        elseif self.backdrops[i] then
            self.backdrops[i]:Show()
        end

        self:RegisterBackdropWithEditMode(i)
    end
end

---@param index number
function DBG:CreateBackdrop(index)
    if not self.db.Enabled then return end
    local bgDB = self.db.backdrops[index]
    if not bgDB or not bgDB.Enabled then return end
    if backdropInitialized[index] then return end

    local detailsBase = _G["DetailsBaseFrame" .. index]
    local detailsWindow = _G["Details_WindowFrame" .. index]

    local backdrop = NRSKNUI:CreateStandardBackdrop(UIParent, "NRSKNUI_DetailsBg" .. index, 1, bgDB.BackgroundColor,
        bgDB.BorderColor)

    local detailsBars = bgDB.detailsBars
    if bgDB.autoSize and detailsBase and detailsWindow then
        local detailsSettings = GetDetailsInstanceSettings(index)
        local barH = detailsSettings and detailsSettings.barHeight or 14
        local titleH = detailsSettings and detailsSettings.titlebarHeight or 16
        local spacing = detailsSettings and detailsSettings.spacing or 1
        local detailsWidth = detailsSettings and detailsSettings.width or 200

        backdrop:SetFrameStrata("LOW")
        detailsBase:ClearAllPoints()
        detailsWindow:ClearAllPoints()

        local detailHeight = titleH + (barH * detailsBars) + (spacing * detailsBars) + 2
        backdrop:SetSize(detailsWidth + 2, detailHeight)
        backdrop:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", bgDB.Position.XOffset, bgDB.Position.YOffset)

        detailsBase:SetSize(backdrop:GetWidth() - 2, backdrop:GetHeight() - titleH)
        detailsWindow:SetSize(backdrop:GetWidth() - 2, backdrop:GetHeight() - titleH)
        detailsBase:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", -1, -1)
        detailsWindow:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", -1, -1)
    else
        backdrop:SetSize(bgDB.width, bgDB.height)
        backdrop:SetFrameStrata(bgDB.Strata)
        backdrop:SetPoint(bgDB.Position.AnchorFrom, UIParent, bgDB.Position.AnchorTo,
            bgDB.Position.XOffset, bgDB.Position.YOffset)
    end

    self.backdrops[index] = backdrop
    backdropInitialized[index] = true
    self:RegisterBackdropWithEditMode(index)
end

---@param index number
function DBG:UpdateBackdrop(index)
    local backdrop = self.backdrops[index]
    if not backdrop then return end
    local bgDB = self.db.backdrops[index]
    if not bgDB then return end

    local detailsBase = _G["DetailsBaseFrame" .. index]
    local detailsWindow = _G["Details_WindowFrame" .. index]

    local detailsBars = bgDB.detailsBars
    if bgDB.autoSize and detailsBase and detailsWindow then
        local detailsSettings = GetDetailsInstanceSettings(index)
        local barH = detailsSettings and detailsSettings.barHeight or 14
        local titleH = detailsSettings and detailsSettings.titlebarHeight or 16
        local spacing = detailsSettings and detailsSettings.spacing or 1
        local detailsWidth = detailsSettings and detailsSettings.width or 200

        detailsBase:ClearAllPoints()
        detailsWindow:ClearAllPoints()
        backdrop:ClearAllPoints()

        local detailHeight = titleH + (barH * detailsBars) + (spacing * detailsBars) + 2
        backdrop:SetSize(detailsWidth + 2, detailHeight)
        backdrop:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", bgDB.Position.XOffset, bgDB.Position.YOffset)
        backdrop:SetFrameStrata("LOW")

        detailsBase:SetSize(backdrop:GetWidth() - 2, backdrop:GetHeight() - titleH)
        detailsWindow:SetSize(backdrop:GetWidth() - 2, backdrop:GetHeight() - titleH)
        detailsBase:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", -1, -1)
        detailsWindow:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", -1, -1)
    elseif not bgDB.autoSize then
        backdrop:ClearAllPoints()
        backdrop:SetSize(bgDB.width, bgDB.height)
        backdrop:SetFrameStrata(bgDB.Strata)
        backdrop:SetPoint(bgDB.Position.AnchorFrom, UIParent, bgDB.Position.AnchorTo,
            bgDB.Position.XOffset, bgDB.Position.YOffset)
    end

    backdrop:SetBackgroundColor(unpack(bgDB.BackgroundColor))
    backdrop:SetBorderColor(unpack(bgDB.BorderColor))
end

---@param index number
function DBG:RegisterBackdropWithEditMode(index)
    local backdrop = self.backdrops[index]
    if not backdrop then return end

    local config = {
        key = "DetailsBackdrop" .. index,
        displayName = "Details Backdrop: " .. index,
        frame = backdrop,
        getPosition = function()
            local bgDB = self.db.backdrops[index]
            if bgDB.autoSize then
                return {
                    AnchorFrom = "BOTTOMRIGHT",
                    AnchorTo = "BOTTOMRIGHT",
                    XOffset = bgDB.Position.XOffset,
                    YOffset = bgDB.Position.YOffset,
                }
            end
            return bgDB.Position
        end,
        setPosition = function(pos)
            local bgDB = self.db.backdrops[index]
            bgDB.Position.XOffset = pos.XOffset
            bgDB.Position.YOffset = pos.YOffset
            if not bgDB.autoSize then
                bgDB.Position.AnchorFrom = pos.AnchorFrom
                bgDB.Position.AnchorTo = pos.AnchorTo
            end
            DBG:UpdateBackdrop(index)
        end,
        getParentFrame = function()
            return UIParent
        end,
        guiPath = "DetailsBackdrop",
        guiContext = index,
    }
    NRSKNUI.EditMode:RegisterElement(config)
end

function DBG:ApplySettings()
    if NRSKNUI:ShouldNotLoadModule() then return end

    if not self.db.Enabled then
        for i = 1, MAX_BACKDROPS do
            if self.backdrops[i] then self.backdrops[i]:Hide() end
            NRSKNUI.EditMode:UnregisterElement("DetailsBackdrop" .. i)
        end
        return
    end

    for i = 1, MAX_BACKDROPS do
        local bgDB = self.db.backdrops[i]
        if bgDB and bgDB.Enabled then
            if self.backdrops[i] then
                self:UpdateBackdrop(i)
                self.backdrops[i]:Show()
                self:RegisterBackdropWithEditMode(i)
            else
                self:CreateBackdrop(i)
            end
        else
            if self.backdrops[i] then self.backdrops[i]:Hide() end
            NRSKNUI.EditMode:UnregisterElement("DetailsBackdrop" .. i)
        end
    end
end

function DBG:OnDisable()
    self.Enabled = false
    self.__enabled = false

    local Details = _G.Details
    if Details then
        Details:UnregisterEvent(self, "DETAILS_INSTANCE_SIZECHANGED")
        Details:UnregisterEvent(self, "DETAILS_INSTANCE_ENDRESIZE")
        Details:UnregisterEvent(self, "DETAILS_OPTIONS_MODIFIED")
    end

    for i = 1, MAX_BACKDROPS do
        if self.backdrops[i] then self.backdrops[i]:Hide() end
        NRSKNUI.EditMode:UnregisterElement("DetailsBackdrop" .. i)
    end
end
