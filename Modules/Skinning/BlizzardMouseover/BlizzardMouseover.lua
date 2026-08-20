---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class BlizzardMouseoverModule
local BMO = NRSKNUI:GetModule('BlizzardMouseover')

local CreateFrame = CreateFrame
local ipairs = ipairs
local concat = table.concat
local tremove = table.remove
local mmin = math.min

local POLL_INTERVAL = 0.1

---What an element file passes to RegisterElement.
---@class BlizzardMouseoverElementDef
---@field label string
---@field frame fun(): Frame? Resolved on every apply, the Blizzard frame may not exist yet
---@field hoverPad number? Grows the hover rect outward on every edge

---@class BlizzardMouseoverElement: BlizzardMouseoverElementDef
---@field key string
---@field resolved Frame?
---@field savedRolesets string[]? Captured before the first hide, restored when it is turned off
---@field active boolean?
---@field alpha number
---@field target number
---@field from number
---@field elapsed number
---@field duration number? Set while a fade is running

---@type table<string, BlizzardMouseoverElement>
BMO.elements = {}
-- Registration order, which is the load order in BlizzardMouseover.xml. Drives the GUI's mini sidebar.
---@type BlizzardMouseoverElement[]
BMO.elementOrder = {}
---@type BlizzardMouseoverElement[]
BMO.active = {}

function BMO:UpdateDB() self.db = NRSKNUI.db.profile.Skinning.BlizzardMouseover end

---Register a Blizzard frame the module can fade or hide. Element files call this at load.
---@param key string DB key under db.mouseoverElements
---@param def BlizzardMouseoverElementDef
function BMO:RegisterElement(key, def)
    ---@cast def BlizzardMouseoverElement
    def.key = key
    def.alpha = 1
    def.target = 1
    self.elements[key] = def
    self.elementOrder[#self.elementOrder + 1] = def
end

local driver = CreateFrame('Frame')
driver:Hide()

---@param element BlizzardMouseoverElement
---@param wanted boolean
local function SetActive(element, wanted)
    if element.active == wanted then return end
    element.active = wanted

    if wanted then
        BMO.active[#BMO.active + 1] = element
        driver.poll = 0
        driver:Show()
        return
    end

    for index = 1, #BMO.active do
        if BMO.active[index] == element then
            tremove(BMO.active, index)
            return
        end
    end
end

---@param element BlizzardMouseoverElement
---@param frame Frame
---@param target number
local function StartFade(element, frame, target)
    element.target = target

    local duration = target > element.alpha and BMO.db.FadeInDuration or BMO.db.FadeOutDuration
    if duration <= 0 then
        element.alpha = target
        element.duration = nil
        frame:SetAlpha(target)
        return
    end

    element.from = element.alpha
    element.elapsed = 0
    element.duration = duration
end

driver:SetScript('OnUpdate', function(self, elapsed)
    self.poll = self.poll + elapsed
    local checkHover = self.poll >= POLL_INTERVAL
    if checkHover then self.poll = 0 end

    for index = #BMO.active, 1, -1 do
        local element = BMO.active[index]
        local frame = element.resolved

        if not frame then
            tremove(BMO.active, index)
            element.active = false
        else
            if checkHover then
                local pad = element.hoverPad or 0
                local target = frame:IsMouseOver(pad, -pad, -pad, pad) and 1 or BMO.db.Alpha
                if target ~= element.target then StartFade(element, frame, target) end
            end

            if element.duration then
                element.elapsed = element.elapsed + elapsed
                local progress = mmin(element.elapsed / element.duration, 1)
                element.alpha = element.from + (element.target - element.from) * progress
                frame:SetAlpha(element.alpha)
                if progress >= 1 then element.duration = nil end
            end
        end
    end

    if #BMO.active == 0 then self:Hide() end
end)

-- alwaysBlocked is engine-side, so it survives the UI mode stack that owns C_Roleset.ApplyRolesetFilters.
---@param element BlizzardMouseoverElement
---@param hidden boolean
local function ApplyRoleset(element, hidden)
    local frame = element.resolved

    if hidden then
        if element.savedRolesets then return end
        element.savedRolesets = frame:GetRolesetNames()
        NRSKNUI:RunWhenSafe(function() frame:SetRolesets('alwaysBlocked') end)
        return
    end

    local saved = element.savedRolesets
    if not saved then return end
    element.savedRolesets = nil

    local names = saved[1] ~= 'roleless' and concat(saved, ',') or nil
    NRSKNUI:RunWhenSafe(function() frame:SetRolesets(names) end)
end

---@param key string
function BMO:ApplyElement(key)
    local element = self.elements[key]
    if not element then return end

    local frame = element.frame()
    element.resolved = frame
    if not frame then return end

    local elementDB = self.db.mouseoverElements[key]
    local on = self:IsEnabled() and self.db.Enabled and elementDB.Enabled
    local hidden = on and elementDB.Hide

    ApplyRoleset(element, hidden)

    if not on or hidden then
        SetActive(element, false)
        element.alpha = 1
        element.target = 1
        element.duration = nil
        frame:SetAlpha(1)
        return
    end

    -- Snap rather than fade, a config change should not animate from wherever the bar happened to be.
    local pad = element.hoverPad or 0
    local target = frame:IsMouseOver(pad, -pad, -pad, pad) and 1 or self.db.Alpha
    element.alpha = target
    element.target = target
    element.duration = nil
    frame:SetAlpha(target)
    SetActive(element, true)
end

function BMO:ApplySettings()
    if NRSKNUI:ShouldNotLoadModule() then return end -- ElvUI owns this, don't fight it
    for _, element in ipairs(self.elementOrder) do
        self:ApplyElement(element.key)
    end
end

function BMO:OnEnable() self:ApplySettings() end

function BMO:OnDisable() self:ApplySettings() end -- IsEnabled() already reads false, so every element restores
