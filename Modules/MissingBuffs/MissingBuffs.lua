---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class MissingBuffsModule
local MissingBuffs = NRSKNUI:GetModule('MissingBuffs')
function MissingBuffs:UpdateDB() self.db = NRSKNUI.db.profile.MissingBuffs end

local Anchors = NRSKNUI.Anchors
local LS = NRSKNUI.Libs.LS
local L = NRSKNUI.Libs.AL

local ceil = math.ceil
local GetTime = GetTime
local IsFlying = IsFlying
local IsInGroup = IsInGroup
local format = string.format
local UnitOnTaxi = UnitOnTaxi
local CreateFrame = CreateFrame
local UnitInVehicle = UnitInVehicle
local UnitHasVehicleUI = UnitHasVehicleUI
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local ipairs, pairs, type, wipe = ipairs, pairs, type, wipe

local IsInBattle = C_PetBattles and C_PetBattles.IsInBattle
local GetSpellTexture = C_Spell and C_Spell.GetSpellTexture
local GetSpellName = C_Spell and C_Spell.GetSpellName

local GameTooltip = GameTooltip

local UPDATE_INTERVAL = 0.5
local COMBAT_TICK = 3
local PREVIEW_REMAINING = 300
local INSTANCE_ENTRY_DURATION = 30
local READY_CHECK_DURATION = 15
local GLOW_KEY = 'NRSKNUI_MissingBuffs'

-- Nameplates and other tokens repeat a group member's auras, only these carry group payloads.
local GROUP_UNITS = {}
for i = 1, 4 do GROUP_UNITS['party' .. i] = true end
for i = 1, 40 do GROUP_UNITS['raid' .. i] = true end

-- Raid and personal reminders share the Raid group, targeted buffs sit in their own.
local GROUPS = { 'Raid', 'Targeted' }
local GROUP_OF = {
    Raid = 'Raid',
    Presence = 'Raid',
    Targeted = 'Targeted',
    Self = 'Raid',
    Consumable = 'Raid',
    Utility = 'Raid',
}
local GROUP_INFO = {
    Raid = { anchor = 'MissingBuffsRaid', guiPath = 'missingBuffsRaid', displayName = 'Missing Buffs' },
    Targeted = { anchor = 'MissingBuffsTargeted', guiPath = 'missingBuffsTargeted', displayName = 'Missing Targeted Buffs' },
}
local CATEGORY_DISPLAY_ORDER = { 'Raid', 'Presence', 'Targeted', 'Self', 'Consumable', 'Utility' }

MissingBuffs.icons = {} ---@type table<string, Frame>
MissingBuffs.lastUpdate = 0

-- Display order within a group follows the category, then the data order.
local entryOrder = {}
local settingsKeys = {} ---@type table<string, string> entry key -> the key its settings live under
for categoryIndex, category in ipairs(CATEGORY_DISPLAY_ORDER) do
    for entryIndex, entry in ipairs(MissingBuffs.Data[category]) do
        entryOrder[entry.key] = categoryIndex * 100 + entryIndex
        settingsKeys[entry.key] = entry.settingsKey or entry.key
    end
end

---An entry's settings, shared with another entry when it has a settingsKey.
---@param key string
---@return table
function MissingBuffs:GetSettings(key)
    return self.db.Buffs[settingsKeys[key]]
end

---The name a reminder goes by, in the settings and on hover.
---@param entry MissingBuffs.Entry
---@return string
function MissingBuffs.GetEntryName(entry)
    return entry.nameSpellID and GetSpellName(entry.nameSpellID) or L[(entry.key:gsub('(%l)(%u)', '%1 %2'))]
end

-- Icons --

---Hangs a bordered icon off the tooltip's left edge, sized to its height. Call after GameTooltip:Show().
---GameTooltip is shared, so the icon goes away whenever anything clears it for new content.
---@param texture number|string
function MissingBuffs:SetTooltipIcon(texture)
    local frame = self.tooltipIcon
    if not frame then
        frame = CreateFrame('Frame', nil, GameTooltip)
        frame:NUIAddBorders()
        frame:SetBorderColor(0, 0, 0, 1)
        frame.texture = frame:CreateTexture(nil, 'ARTWORK')
        frame.texture:NUISetPixelInside(frame, 1, 1)
        frame.texture:NUISetZoom()
        GameTooltip:HookScript('OnTooltipCleared', function() frame:Hide() end)
        self.tooltipIcon = frame
    end

    local height = 36
    frame:NUISetPixelSize(height, height)
    frame:ClearAllPoints()
    frame:NUISetPixelPoint('TOPRIGHT', GameTooltip, 'TOPLEFT', 0, -1)
    frame.texture:SetTexture(texture)
    frame:Show()
end

-- The icon only takes the mouse when nothing is left to click: a bag-based reminder with an empty bag.
-- Anything clickable is covered by its secure button, which carries its own tooltip.
---@param icon Frame
local function OnIconEnter(icon)
    local result = MissingBuffs.shown[icon.key]
    if not result or not result.noItem then return end

    GameTooltip:SetOwner(icon, 'ANCHOR_NONE')
    GameTooltip:SetPoint('BOTTOMRIGHT', _G.NRSKNUI_TooltipAnchorFrame or GameTooltipDefaultContainer)
    GameTooltip:AddLine(NRSKNUI:ColorTextByTheme(MissingBuffs.GetEntryName(result.entry)))
    GameTooltip:AddLine(L['None in your bags'], 0.70, 0.70, 0.70)
    GameTooltip:Show()
    MissingBuffs:SetTooltipIcon(result.icon)
end

---@param seconds number
---@return string
local function FormatMinutes(seconds)
    if seconds < 60 then return '<1m' end
    return format('%dm', ceil(seconds / 60))
end

---@param icon Frame
---@param db table
---@return boolean resized
local function ConfigureIcon(icon, db)
    local size = db.IconSize
    local border = db.BorderColor
    local resized = icon.size ~= size
    icon.size = size

    icon:NUISetPixelSize(size, size)
    icon:SetBorderColor(border[1], border[2], border[3], border[4])
    icon.texture:NUISetPixelInside(icon, 1, 1)
    icon.texture:NUISetZoom()

    icon.count:SetFontStyle(db)
    icon.count:SetFontJustify(db.CountText, icon, db.CountText.Position.XOffset, db.CountText.Position.YOffset)
    icon.timer:SetFontStyle(db)
    icon.timer:SetFontJustify(db.TimerText, icon, db.TimerText.Position.XOffset, db.TimerText.Position.YOffset)

    return resized
end

---@param key string
---@param groupName string
---@return Frame
function MissingBuffs:GetIcon(key, groupName)
    local icon = self.icons[key]
    if icon then return icon end

    local group = self.groups[groupName]
    icon = CreateFrame('Frame', nil, group)
    -- Hover only, clicks always pass through; motion is switched on per update.
    icon:EnableMouse(false)
    icon:SetScript('OnEnter', OnIconEnter)
    icon:SetScript('OnLeave', GameTooltip_Hide)
    icon.key = key
    icon:NUIAddBorders()
    icon:NUISetPixelSnap()
    icon.texture = icon:CreateTexture(nil, 'ARTWORK')
    icon.count = icon:CreateFontString(nil, 'OVERLAY')
    icon.count:SetWordWrap(false)
    icon.timer = icon:CreateFontString(nil, 'OVERLAY')
    icon.timer:SetWordWrap(false)
    icon.groupName = groupName
    icon.glowing = false

    ConfigureIcon(icon, self.db.Groups[groupName])
    group:AttachChild(icon, key, entryOrder[key])
    group:NotifyChildResized(key, self.db.Groups[groupName].IconSize, self.db.Groups[groupName].IconSize)
    icon:Show()

    self.icons[key] = icon
    return icon
end

---@param key string
---@param expiring boolean
---@return boolean
function MissingBuffs:WantsGlow(key, expiring)
    local settings = self:GetSettings(key)
    return settings.GlowEnabled and (settings.GlowMode == 'always' or expiring) or false
end

---Restarts the glow of every icon using these settings, for when the glow settings or the size changed.
---Nothing else restarts a glow.
---@param key string
function MissingBuffs:RefreshGlow(key)
    for iconKey, icon in pairs(self.icons) do
        if settingsKeys[iconKey] == settingsKeys[key] then
            self:SetGlow(icon, iconKey, false)
            if self.groups[icon.groupName]:IsChildActive(iconKey) then
                self:SetGlow(icon, iconKey, self:WantsGlow(iconKey, icon.expiring))
            end
        end
    end
end

---@param icon Frame
---@param key string
---@param glow boolean
function MissingBuffs:SetGlow(icon, key, glow)
    if glow == icon.glowing then return end
    icon.glowing = glow

    if glow then
        NRSKNUI:StartGlow(icon, self:GetSettings(key), GLOW_KEY)
    else
        NRSKNUI:StopGlow(icon, GLOW_KEY)
    end
end

-- Runeforge and weapon oil come in a main and an off hand copy that look alike, so they say which.
---@param entry MissingBuffs.Entry
---@return string?
local function GetSlotText(entry)
    if entry.check == 'Runeforge' or entry.itemList == 'WeaponOil' then
        return entry.enchantSlot == 'offhand' and L['OH'] or L['MH']
    end
end

---@param result MissingBuffs.Result
---@return string
local function GetCountText(result)
    if result.eating then return 'Eating' end
    if result.total then return format('%d/%d', result.total - result.missing, result.total) end
    return GetSlotText(result.entry) or ''
end

---@param result MissingBuffs.Result
---@return string
local function GetTimerText(result)
    if result.expiring and result.remaining then return FormatMinutes(result.remaining) end
    return ''
end

-- Update --

---@return boolean
function MissingBuffs:ShouldShow()
    if UnitIsDeadOrGhost('player') or IsInBattle() then return false end
    return not (UnitInVehicle('player') or UnitHasVehicleUI('player') or UnitOnTaxi('player') or IsFlying())
end

function MissingBuffs:HideAll()
    for key, icon in pairs(self.icons) do
        self:SetGlow(icon, key, false)
        self.groups[icon.groupName]:DeactivateChild(key)
    end
end

function MissingBuffs:Update()
    self.updatePending = false
    self.lastUpdate = GetTime()
    if not self.groups or self.isPreview then return end

    if not self:ShouldShow() then
        self:HideAll()
        self:SyncButtons()
        self:ScheduleNextChange(nil)
        return
    end

    local nextChange = self:Evaluate()

    for _, group in pairs(self.groups) do group:Suspend() end

    for key, icon in pairs(self.icons) do
        if not self.shown[key] then
            self:SetGlow(icon, key, false)
            self.groups[icon.groupName]:DeactivateChild(key)
        end
    end

    for category, list in pairs(self.results) do
        local groupName = GROUP_OF[category]
        for _, result in ipairs(list) do
            local key = result.entry.key
            local icon = self:GetIcon(key, groupName)
            icon.texture:SetTexture(result.icon)
            icon.texture:SetDesaturated(result.noItem == true and result.entry.itemList ~= nil
                and self:GetSettings(key).EmptyBagMode == 'desaturate')
            icon.count:SetText(GetCountText(result))
            icon.timer:SetText(GetTimerText(result))
            icon.expiring = result.expiring
            icon:SetMouseMotionEnabled(result.noItem == true)
            self:SetGlow(icon, key, self:WantsGlow(key, result.expiring))
            self.groups[groupName]:ActivateChild(key)

            -- The timer reads whole minutes rounded up, so it next changes as the remaining time crosses a minute.
            local remaining = result.remaining
            if result.expiring and remaining and remaining >= 60 then
                local tick = remaining % 60
                if tick == 0 then tick = 60 end
                if not nextChange or tick < nextChange then nextChange = tick end
            end
        end
    end

    for _, group in pairs(self.groups) do group:Resume() end
    self:SyncButtons()
    self:ScheduleNextChange(nextChange)
end

---@param seconds number?
function MissingBuffs:ScheduleNextChange(seconds)
    if self.changeTimer then
        self.changeTimer:Cancel()
        self.changeTimer = nil
    end
    if seconds then
        self.changeTimer = C_Timer.NewTimer(seconds + 0.1, self.onTimedUpdate)
    end
end

function MissingBuffs:RequestUpdate()
    if self.updatePending then return end
    self.updatePending = true

    local wait = self.lastUpdate + UPDATE_INTERVAL - GetTime()
    C_Timer.After(wait > 0 and wait or 0, self.onTimedUpdate)
end

-- Events --

function MissingBuffs:UNIT_AURA(_, unit, updateInfo)
    if unit == 'player' or unit == 'pet' then
        self:RequestUpdate()
    elseif GROUP_UNITS[unit] and self:IsTrackedAuraUpdate(updateInfo) then
        self:RequestUpdate()
    end
end

-- Group payloads only matter out of combat and in a group, otherwise just player and pet.
function MissingBuffs:RegisterAuraEvents()
    local frame = self.auraFrame
    frame:UnregisterEvent('UNIT_AURA')
    if self.inCombat or not IsInGroup() then
        frame:RegisterUnitEvent('UNIT_AURA', 'player', 'pet')
    else
        frame:RegisterEvent('UNIT_AURA')
    end
end

function MissingBuffs:GROUP_ROSTER_UPDATE()
    self:RegisterAuraEvents()
    self:RequestUpdate()
end

---@param _ string
---@param spellID number
function MissingBuffs:OnOverlayGlow(_, spellID)
    if self.glowSpells[spellID] then self:RequestUpdate() end
end

function MissingBuffs:OnBagsChanged()
    self:InvalidateBagItems()
    self:RequestUpdate()
end

function MissingBuffs:OnTalentsChanged()
    self.heroChoicesDirty = true
    self:RequestUpdate()
end

function MissingBuffs:PLAYER_REGEN_DISABLED()
    self.inCombat = true
    self:CloseFlyout() -- the last moment its secure buttons can still be hidden
    self:RegisterAuraEvents()

    -- Group payloads stay off in combat, the ticker covers the trackable group buffs instead.
    if self.combatTicker then self.combatTicker:Cancel() end
    self.combatTicker = C_Timer.NewTicker(COMBAT_TICK, self.onTimedUpdate)
    self:RequestUpdate()
end

function MissingBuffs:PLAYER_REGEN_ENABLED()
    self.inCombat = false
    self:RegisterAuraEvents()

    if self.combatTicker then
        self.combatTicker:Cancel()
        self.combatTicker = nil
    end
    self:RequestUpdate()
end

---@param _ string
---@param isLogin boolean
---@param isReload boolean
function MissingBuffs:PLAYER_ENTERING_WORLD(_, isLogin, isReload)
    self:ResetSpellSecrecy()
    if isLogin or isReload then wipe(self.groupSpecs) end

    C_Timer.After(1, function()
        if self:IsInstanceEntryZone() then
            self:SetWindow('inInstanceEntry', INSTANCE_ENTRY_DURATION)
        end
        self:RequestUpdate()
    end)
    self:RequestUpdate()
end

-- Delves have no loading screen and the instance info is still stale when this fires.
function MissingBuffs:ZONE_CHANGED_NEW_AREA()
    self:RequestUpdate()
    C_Timer.After(1, function() self:RequestUpdate() end)
end

function MissingBuffs:READY_CHECK()
    self:SetWindow('inReadyCheck', READY_CHECK_DURATION)
end

-- Instance entry and ready check open a short window, cooldown-gated reminders only matter inside one.
---@param flag 'inInstanceEntry'|'inReadyCheck'
---@param duration number
function MissingBuffs:SetWindow(flag, duration)
    local timers = self.windowTimers
    if timers[flag] then timers[flag]:Cancel() end

    self[flag] = true
    self:RegisterEvent('SPELL_UPDATE_COOLDOWN', 'RequestUpdate')

    timers[flag] = C_Timer.NewTimer(duration, function()
        timers[flag] = nil
        self[flag] = false
        if not self.inInstanceEntry and not self.inReadyCheck then
            self:UnregisterEvent('SPELL_UPDATE_COOLDOWN')
        end
        self:RequestUpdate()
    end)
    self:RequestUpdate()
end

-- Settings --

function MissingBuffs:CreateFrames()
    if self.groups then return end

    self.groups = {}
    for _, name in ipairs(GROUPS) do
        local info = GROUP_INFO[name]
        local group = NRSKNUI:CreateDynamicGroup('NRSKNUI_' .. info.anchor, UIParent)
        self.groups[name] = group
        Anchors:Register(self, info.anchor, group, info.guiPath, {
            db = function(aceModule) return aceModule.db.Groups[name] end,
            displayName = info.displayName,
            guiContext = 'general',
        })
    end

    self.auraFrame = CreateFrame('Frame')
    self.auraFrame:SetScript('OnEvent', function(_, event, ...) self[event](self, event, ...) end)
    self.windowTimers = {}
    self.onTimedUpdate = function() self:Update() end
end

function MissingBuffs:ApplySettings()
    if not self.groups then return end
    self:UpdateDB()

    for name, group in pairs(self.groups) do
        local db = self.db.Groups[name]
        group:SetConfig(db.Config)
        group:UpdateGroupPosition(db, db.Config.Grow)

        group:Suspend()
        for key, icon in pairs(self.icons) do
            if icon.groupName == name then
                -- Button and proc glows size themselves once at start, so only a resize restarts them.
                if ConfigureIcon(icon, db) and icon.glowing then self:RefreshGlow(key) end
                group:NotifyChildResized(key, db.IconSize, db.IconSize)
            end
        end
        group:Resume()
    end

    if self.isPreview then
        self:ShowPreviewIcons()
    else
        self:Update()
    end

    for _, group in pairs(self.groups) do group:ForceLayout() end
end

-- Lifecycle --

function MissingBuffs:OnEnable()
    self:UpdateDB()
    self:BuildTrackedSpells()
    self:CreateFrames()

    self.inCombat = NRSKNUI:InCombat()
    self:RegisterAuraEvents()

    local request = 'RequestUpdate'
    self:RegisterEvent('PLAYER_ENTERING_WORLD')
    self:RegisterEvent('PLAYER_REGEN_DISABLED')
    self:RegisterEvent('PLAYER_REGEN_ENABLED')
    self:RegisterEvent('READY_CHECK')
    self:RegisterEvent('ADDON_RESTRICTION_STATE_CHANGED', request)
    self:RegisterEvent('GROUP_ROSTER_UPDATE')
    self:RegisterEvent('UNIT_CONNECTION', request)
    self:RegisterEvent('UNIT_PHASE', request)
    self:RegisterEvent('PLAYER_DEAD', request)
    self:RegisterEvent('PLAYER_ALIVE', request)
    self:RegisterEvent('PLAYER_UNGHOST', request)
    self:RegisterEvent('PLAYER_EQUIPMENT_CHANGED', 'OnBagsChanged')
    self:RegisterEvent('WEAPON_ENCHANT_CHANGED', request)
    self:RegisterEvent('BAG_UPDATE_DELAYED', 'OnBagsChanged')
    self:RegisterEvent('BAG_UPDATE_COOLDOWN', request) -- using a Healthstone charge keeps its bag slot, no bag update
    self:RegisterEvent('SPELLS_CHANGED', 'OnTalentsChanged')
    self:RegisterEvent('TRAIT_CONFIG_UPDATED', 'OnTalentsChanged')
    self:RegisterEvent('PLAYER_SPECIALIZATION_CHANGED', 'OnTalentsChanged')
    self:RegisterEvent('PLAYER_LEVEL_UP', request)
    self:RegisterEvent('PLAYER_MOUNT_DISPLAY_CHANGED', request)
    self:RegisterEvent('UNIT_ENTERED_VEHICLE', request)
    self:RegisterEvent('UNIT_EXITED_VEHICLE', request)
    self:RegisterEvent('PET_BATTLE_OPENING_START', request)
    self:RegisterEvent('PET_BATTLE_CLOSE', request)
    self:RegisterEvent('CHALLENGE_MODE_START', request)
    self:RegisterEvent('CHALLENGE_MODE_COMPLETED', request)
    self:RegisterEvent('ZONE_CHANGED_NEW_AREA')
    if next(self.glowSpells) then
        self:RegisterEvent('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW', 'OnOverlayGlow')
        self:RegisterEvent('SPELL_ACTIVATION_OVERLAY_GLOW_HIDE', 'OnOverlayGlow')
    end

    LS.RegisterGroup(self, function(...) self:OnGroupSpec(...) end)
    NRSKNUI.LoadConditions:RegisterCallback(self, function() self:RequestUpdate() end)

    self:ApplySettings()
end

function MissingBuffs:OnDisable()
    LS.UnregisterGroup(self)
    NRSKNUI.LoadConditions:UnregisterCallback(self)

    self.auraFrame:UnregisterAllEvents()
    if self.combatTicker then self.combatTicker:Cancel() end
    self.combatTicker = nil
    self:ScheduleNextChange(nil)
    for flag, timer in pairs(self.windowTimers) do
        timer:Cancel()
        self.windowTimers[flag] = nil
        self[flag] = false
    end

    self.isPreview = false
    self:HideAll()
    self:SyncButtons()
end

-- Preview --

function MissingBuffs:ShowPreviewIcons()
    local wanted = {}

    for category, groupName in pairs(GROUP_OF) do
        for index, entry in ipairs(self.Data[category]) do
            local own = not entry.class or entry.class == NRSKNUI.MyClass
            if self:GetSettings(entry.key).Enabled and (own or category == 'Raid' or category == 'Targeted') then
                wanted[entry.key] = true
                local icon = self:GetIcon(entry.key, groupName)
                local spell = entry.castSpellID or entry.spellID
                icon.texture:SetTexture(entry.icon or GetSpellTexture((type(spell) == 'table' and spell[1] or spell or 0) --[[@as number]]))
                icon.texture:SetDesaturated(false)
                local counted = category == 'Raid' and index % 2 == 1
                icon.count:SetText(counted and '3/5' or GetSlotText(entry) or '')
                icon.timer:SetText(not counted and not entry.noExpiry and FormatMinutes(PREVIEW_REMAINING) or '')
                icon.expiring = true
                icon:SetMouseMotionEnabled(false)
                self:SetGlow(icon, entry.key, self:WantsGlow(entry.key, true))
                self.groups[groupName]:ActivateChild(entry.key)
            end
        end
    end

    for key, icon in pairs(self.icons) do
        if not wanted[key] then
            self:SetGlow(icon, key, false)
            self.groups[icon.groupName]:DeactivateChild(key)
        end
    end

    for _, group in pairs(self.groups) do group:ForceLayout() end
end

-- Every group previews on every Missing Buffs page, so moving between them changes nothing.
function MissingBuffs:UpdatePreviewScope() end

function MissingBuffs:ShowPreview()
    self:CreateFrames()
    self.isPreview = true
    self:ScheduleNextChange(nil)
    self:SyncButtons()
    self:ApplySettings()
end

function MissingBuffs:HidePreview()
    if not self.isPreview then return end
    self.isPreview = false
    self:HideAll()
    self:Update()
end
