---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class DetailsBackdropModule
local DBG = NRSKNUI:GetModule('DetailsBackdrop')
local L = NRSKNUI.Libs.AL
function DBG:UpdateDB() self.db = NRSKNUI.db.profile.Skinning.DetailsBackdrop end

-- Credit to unhalted for the idea of this module, not a copy of his code but liked his cook

local C_AddOns = C_AddOns
local CreateFrame = CreateFrame
local format = string.format
local ipairs = ipairs
local tostring = tostring
local _G = _G

local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded

local MAX_BACKDROPS = 5
local ANCHOR_PREFIX = 'DetailsBackdrop'

DBG.backdrops = {}

local anchorNames = {}
for index = 1, MAX_BACKDROPS do
    anchorNames[index] = format(L['Details Backdrop %d'], index)
end

-- Details' own defaults, for a window it has not created yet.
local DEFAULT_BAR_HEIGHT = 14
local DEFAULT_TITLEBAR_HEIGHT = 16
local DEFAULT_SPACING = 1
local DEFAULT_WIDTH = 200

local DETAILS_EVENTS = {
    'DETAILS_INSTANCE_OPEN',
    'DETAILS_INSTANCE_CLOSE',
    'DETAILS_INSTANCE_SIZECHANGED',
    'DETAILS_INSTANCE_ENDRESIZE',
    'DETAILS_OPTIONS_MODIFIED',
}

---Geometry of one Details window, as values so a resize tick allocates nothing.
---@param index number
---@return number barHeight
---@return number titlebarHeight
---@return number spacing
---@return number width
local function GetInstanceGeometry(index)
    local Details = _G.Details
    local instance = Details and Details:GetInstance(index)
    local rowInfo = instance and instance.row_info
    if not rowInfo then
        return DEFAULT_BAR_HEIGHT, DEFAULT_TITLEBAR_HEIGHT, DEFAULT_SPACING, DEFAULT_WIDTH
    end

    return rowInfo.height or DEFAULT_BAR_HEIGHT,
        instance.titlebar_height or DEFAULT_TITLEBAR_HEIGHT,
        rowInfo.space and rowInfo.space.between or DEFAULT_SPACING,
        instance.baseframe and instance.baseframe:GetWidth() or DEFAULT_WIDTH
end

-- The event carries the window that changed, so only its backdrop needs re-applying.
local function OnDetailsEvent(_, instance)
    local index = instance and instance:GetId()
    if index then
        DBG:ApplyBackdrop(index)
    else
        DBG:ApplySettings()
    end
end

function DBG:HookDetailsEvents()
    local Details = _G.Details
    if not Details then return end

    self.Enabled = true -- Details' dispatcher drops any listener without both of these set
    self.__enabled = true

    if self.detailsHooked then return end

    for _, event in ipairs(DETAILS_EVENTS) do
        Details:RegisterEvent(self, event, OnDetailsEvent)
    end
    self.detailsHooked = true
end

function DBG:ADDON_LOADED(_, addon)
    if addon ~= 'Details' then return end

    self:UnregisterEvent('ADDON_LOADED')
    self:HookDetailsEvents()
    self:ApplySettings()
end

function DBG:OnEnable()
    if NRSKNUI:ShouldNotLoadModule() then return end

    if not IsAddOnLoaded('Details') then
        self:RegisterEvent('ADDON_LOADED') -- Details can be made load-on-demand, so wait rather than give up
        return
    end

    self:HookDetailsEvents()
    self:ApplySettings()
end

---@param index number
---@return Frame
function DBG:CreateBackdrop(index)
    local backdrop = CreateFrame('Frame', 'NRSKNUI_DetailsBg' .. index, UIParent)
    backdrop:NUICreateBackdrop(nil, 0)
    backdrop:SetFrameLevel(1)

    self.backdrops[index] = backdrop
    return backdrop
end

---@param index number
function DBG:RegisterAnchor(index)
    NRSKNUI.Anchors:Register(self, ANCHOR_PREFIX .. index, self.backdrops[index], 'detailsBackdrop', {
        db = function(aceModule) return aceModule.db.backdrops[index] end, -- read live, UpdateDB re-points self.db
        displayName = anchorNames[index],
        guiContext = tostring(index),
    })
end

---Size is all the two modes disagree on, position, strata and colour are shared.
---@param index number
function DBG:ApplyBackdrop(index)
    local bgDB = self.db.backdrops[index]

    if not (self.db.Enabled and bgDB and bgDB.Enabled) then
        local existing = self.backdrops[index]
        if existing then existing:Hide() end
        NRSKNUI.Anchors:Unregister(ANCHOR_PREFIX .. index)
        return
    end

    local backdrop = self.backdrops[index] or self:CreateBackdrop(index)
    local detailsBase = _G['DetailsBaseFrame' .. index]
    local detailsWindow = _G['Details_WindowFrame' .. index]

    if bgDB.autoSize and detailsBase and detailsWindow then
        local barHeight, titlebarHeight, spacing, width = GetInstanceGeometry(index)
        local bars = bgDB.detailsBars
        local backdropWidth = width + 2
        local backdropHeight = titlebarHeight + (barHeight * bars) + (spacing * bars) + 2
        local innerWidth, innerHeight = backdropWidth - 2, backdropHeight - titlebarHeight

        backdrop:NUISetPixelSize(backdropWidth, backdropHeight)
        backdrop:NUIApplyPosition(bgDB)

        -- Only the anchor moves, so Details keeps its parents and it is its saved position we override.
        detailsBase:ClearAllPoints()
        detailsBase:NUISetPixelSize(innerWidth, innerHeight)
        detailsBase:NUISetPixelPoint('BOTTOMRIGHT', backdrop, 'BOTTOMRIGHT', -1, -1)

        detailsWindow:ClearAllPoints()
        detailsWindow:NUISetPixelSize(innerWidth, innerHeight)
        detailsWindow:NUISetPixelPoint('BOTTOMRIGHT', backdrop, 'BOTTOMRIGHT', -1, -1)

        local instance = _G.Details:GetInstance(index)
        backdrop:SetShown(not instance or instance:IsShown()) -- a frame for a window is only a frame while it is open
    else
        backdrop:NUISetPixelSize(bgDB.width, bgDB.height)
        backdrop:NUIApplyPosition(bgDB)
        backdrop:Show()
    end

    backdrop:UpdateBackdropFromDB(bgDB)
    self:RegisterAnchor(index)
end

function DBG:ApplySettings()
    if NRSKNUI:ShouldNotLoadModule() then return end

    for index = 1, MAX_BACKDROPS do
        self:ApplyBackdrop(index)
    end
end

function DBG:OnDisable()
    self.Enabled = false -- stops Details delivery without unregistering, so re-enabling cannot double up
    self.__enabled = false

    for index = 1, MAX_BACKDROPS do
        local backdrop = self.backdrops[index]
        if backdrop then backdrop:Hide() end
        NRSKNUI.Anchors:Unregister(ANCHOR_PREFIX .. index)
    end
end
