---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')

local pairs = pairs

function CDM:UpdateDB()
    self.db = NRSKNUI.db.profile.CDM
end

function CDM:OnInitialize()
    self:UpdateDB()
    self.frames = {} ---@type table<string, Frame>
end

---Tear down a display's runtime frame, if it has one.
---@param id string
function CDM:Release(id)
    local frame = self.frames[id]
    if not frame then return end

    frame:Hide()
    self.frames[id] = nil
end

function CDM:OnCatalogueChanged()
end

function CDM:ApplySettings()
end

function CDM:OnEnable()
    self:ApplySettings()
end

function CDM:OnDisable()
    for id in pairs(self.frames) do
        self:Release(id)
    end
end

---@param args string
function CDM:HandleCommand(args)
    if args == 'dump' then
        self.Catalogue:Dump()
    else
        NRSKNUI:Print('/nui cdm dump')
    end
end
