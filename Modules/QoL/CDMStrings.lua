---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CooldownStringsModule
local CooldownStrings = NRSKNUI:GetModule('CooldownStrings')
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme

local GetSpecializationInfoForClassID = GetSpecializationInfoForClassID
local GetSpecializationInfoByID = GetSpecializationInfoByID
local GetSpecializationInfo = GetSpecializationInfo
local GetSpecialization = GetSpecialization
local GetServerTime = GetServerTime
local pairs, ipairs = pairs, ipairs
local GetRealmName = GetRealmName
local RunNextFrame = RunNextFrame
local CreateFrame = CreateFrame
local format = string.format
local ReloadUI = ReloadUI
local tonumber = tonumber
local tsort = table.sort
local floor = math.floor
local select = select
local pcall = pcall
local type = type
local next = next

local DecodeBase64 = C_EncodingUtil and C_EncodingUtil.DecodeBase64
local DecompressString = C_EncodingUtil and C_EncodingUtil.DecompressString
local DeserializeCBOR = C_EncodingUtil and C_EncodingUtil.DeserializeCBOR
local GetClassInfo = C_CreatureInfo and C_CreatureInfo.GetClassInfo
local LoadAddOn = C_AddOns and C_AddOns.LoadAddOn

CooldownStrings.panel = nil
CooldownStrings.selected = nil

-- Cooldown Manager access --

---@return boolean
function CooldownStrings.IsCDMLoaded()
    return (CooldownViewerSettings and CooldownViewerUtil) and true or false
end

-- Only for something the player asked for, a passive read must not pull in a Blizzard addon.
local function EnsureCDM()
    if CooldownStrings.IsCDMLoaded() then return true end

    LoadAddOn('Blizzard_CooldownViewer')
    return CooldownStrings.IsCDMLoaded()
end

local function GetLayoutManager()
    if not CooldownStrings.IsCDMLoaded() then return nil end

    return CooldownViewerSettings:GetLayoutManager()
end

-- Pending edits only reach the layout when the window closes.
local function CommitPendingEdits()
    if CooldownViewerSettings and CooldownViewerSettings:IsShown() then
        CooldownViewerSettings:Hide()
    end
end

local function CharacterKey()
    return NRSKNUI.MyName .. '-' .. GetRealmName()
end

-- Spec tags --

-- classAndSpecTag packs both halves into one number: classID * 10 + specIndex.
---@param tag number|string|nil
---@return number? classID, number? specIndex
local function SplitTag(tag)
    tag = tonumber(tag)
    if not tag then return nil end

    local classID, specIndex = floor(tag / 10), tag % 10
    if classID < 1 or classID > 30 or specIndex < 1 or specIndex > 5 then return nil end
    return classID, specIndex
end

---@param tag number|string|nil
---@return number? specID, string? name, number? icon, string? classFile
function CooldownStrings.TagToSpec(tag)
    local classID, specIndex = SplitTag(tag)
    if not classID then return nil end

    local specID, name, _, icon = GetSpecializationInfoForClassID(classID, specIndex)
    local classInfo = GetClassInfo(classID)
    return specID, name, icon, classInfo and classInfo.classFile
end

---@param specID number|nil
---@return number? specID, string? name, number? icon, string? classFile
function CooldownStrings.SpecIDToSpec(specID)
    if not specID then return nil end

    local id, name, _, icon, _, classFile = GetSpecializationInfoByID(specID)
    if not id then return nil end
    return id, name, icon, classFile
end

---Spec of a saved profile, from its tag when it has one and its legacy specID otherwise.
---@param entry table|nil
---@return number? specID, string? name, number? icon, string? classFile
function CooldownStrings.EntrySpec(entry)
    if not entry then return nil end

    local specID, name, icon, classFile = CooldownStrings.TagToSpec(entry.SpecTag)
    if specID then return specID, name, icon, classFile end
    return CooldownStrings.SpecIDToSpec(entry.SpecID)
end

---The class a profile loads onto, from its spec if it has one and its string if it does not.
---@param entry table
---@return string? classFile
local function EntryClassFile(entry)
    local classFile = select(4, CooldownStrings.EntrySpec(entry))
    if classFile then return classFile end

    classFile = select(4, CooldownStrings.TagToSpec(CooldownStrings.ReadStringInfo(entry.String)))
    return classFile
end

---@return number? specID
local function CurrentSpecID()
    local index = GetSpecialization()
    if not index or index <= 0 then return nil end

    return (GetSpecializationInfo(index))
end

-- Profile strings --

---Pasted strings arrive wrapped or padded and base64 carries no whitespace of its own.
---@param str string
---@return string
local function Clean(str)
    return (str:gsub('%s', ''))
end

-- Exports are "<version>|<base64 of deflated CBOR>", older ones wrote two pipes.
---@param str string|nil
---@return table? payload
local function DecodeString(str)
    if type(str) ~= 'string' then return nil end

    local body = Clean(str):match('^%d+|+(.+)$')
    if not body then return nil end

    local ok, decoded = pcall(DecodeBase64, body)
    if not ok or not decoded then return nil end

    ok, decoded = pcall(DecompressString, decoded, Enum.CompressionMethod.Deflate)
    if not ok or not decoded then return nil end

    local payload
    ok, payload = pcall(DeserializeCBOR, decoded)
    if not ok or type(payload) ~= 'table' then return nil end
    return payload
end

---Name and spec of a profile string, so a pasted one needs no describing by hand.
---@param str string|nil
---@return number? tag, string? name
function CooldownStrings.ReadStringInfo(str)
    local payload = DecodeString(str)
    if not payload then return nil end

    local byTag, names = payload[3], payload[4]
    if type(byTag) ~= 'table' or type(names) ~= 'table' then return nil end

    -- An export is always one spec, so the map holds a single tag keying its layouts.
    local tagKey = next(byTag) -- kept off tonumber's arg list, next also returns the value
    local tag = tonumber(tagKey)
    if not SplitTag(tag) then return nil end

    -- A string can hold several layouts for one spec and the first is often an unnamed default,
    -- so the earliest real name wins. pairs, because a null name leaves a hole ipairs stops at.
    local name, found
    for index, candidate in pairs(names) do
        if type(candidate) == 'string' and candidate ~= '' and (not found or index < found) then
            name, found = candidate, index
        end
    end

    return tag, name
end

local function DeepEqual(a, b)
    if a == b then return true end
    if type(a) ~= 'table' or type(b) ~= 'table' then return false end

    for key, value in pairs(a) do
        if not DeepEqual(value, b[key]) then return false end
    end
    for key in pairs(b) do
        if a[key] == nil then return false end
    end
    return true
end

---Per-category lists serialize out of unordered tables, so an untouched layout re-exports them
---in a fresh order every session. Sorted in place, the decoded payload is ours to mutate.
---@param payload table
local function SortCategoryLists(payload)
    local byTag = payload[3]
    if type(byTag) ~= 'table' then return end

    for _, layouts in pairs(byTag) do
        if type(layouts) == 'table' then
            for _, layout in pairs(layouts) do
                -- [1] is the ordered display list and stays put, [2] holds the category sets.
                local categories = type(layout) == 'table' and layout[2]
                if type(categories) == 'table' then
                    for _, list in pairs(categories) do
                        if type(list) == 'table' then tsort(list) end
                    end
                end
            end
        end
    end
end

---The serializer is not byte stable, so identical layouts only compare once decoded.
---@param a string|nil
---@param b string|nil
---@return boolean? match nil when a string would not decode, which is not the same as differing
function CooldownStrings.StringsMatch(a, b)
    if a == b then return true end
    if not a or not b then return nil end

    local payloadA, payloadB = DecodeString(a), DecodeString(b)
    if not payloadA or not payloadB then return nil end

    SortCategoryLists(payloadA)
    SortCategoryLists(payloadB)
    return DeepEqual(payloadA, payloadB)
end

-- Layouts --

---EnumerateLayouts never sees any character but the one we are logged in on.
---@return table[] list of { name, layoutID, tag }
function CooldownStrings:GetLiveLayouts()
    local layoutManager = GetLayoutManager()
    if not layoutManager then return {} end

    local _, layouts = layoutManager:EnumerateLayouts()
    local list = {}
    for _, layout in pairs(layouts) do
        list[#list + 1] = {
            name = layout.layoutName,
            layoutID = layout.layoutID,
            tag = tonumber(layout.classAndSpecTag),
        }
    end

    tsort(list, function(a, b) return a.name < b.name end)
    return list
end

---@param layoutName string
---@return table? layout
function CooldownStrings:GetLiveLayout(layoutName)
    for _, layout in ipairs(self:GetLiveLayouts()) do
        if layout.name == layoutName then return layout end
    end
    return nil
end

---The Cooldown Manager name a backup carries, which is the string's and never ours to change.
---Profiles saved before it was stored were keyed by that name.
---@param name string profile key
---@return string
function CooldownStrings:LayoutName(name)
    return self.db.Profiles[name].LayoutName or name
end

---@param name string profile key
---@return table? layout
function CooldownStrings:GetLiveLayoutFor(name)
    return self:GetLiveLayout(self:LayoutName(name))
end

-- Callers commit first, so a passive read cannot close the window under the player.
---@param layoutID number
---@return string? profileString
local function SerializeLayout(layoutID)
    local layoutManager = GetLayoutManager()
    if not layoutManager then return nil end

    return layoutManager:GetSerializer():SerializeLayouts(layoutID)
end

---This character's live layouts plus whatever the logout snapshot holds for the others.
---@return table[] groups of { character, isCurrent, layouts }
function CooldownStrings:GetAvailableLayouts()
    EnsureCDM()

    local groups = {}
    local current = CharacterKey()

    local live = self:GetLiveLayouts()
    if live[1] then
        groups[#groups + 1] = {
            character = current,
            name = NRSKNUI.MyName,
            classFile = NRSKNUI.MyClass,
            isCurrent = true,
            layouts = live,
        }
    end

    for key, cached in pairs(self.cache) do
        if key ~= current then
            local layouts = {}
            for name, data in pairs(cached.layouts) do
                layouts[#layouts + 1] = { name = name, tag = data.SpecTag, String = data.String }
            end

            tsort(layouts, function(a, b) return a.name < b.name end)
            if layouts[1] then
                -- Every layout a character owns carries its class, so the snapshot need not store it.
                local classFile = select(4, self.TagToSpec(layouts[1].tag))
                groups[#groups + 1] = {
                    character = key,
                    name = cached.name,
                    classFile = classFile,
                    layouts = layouts,
                }
            end
        end
    end

    tsort(groups, function(a, b)
        if a.isCurrent ~= b.isCurrent then return a.isCurrent == true end
        return a.character < b.character
    end)
    return groups
end

-- Saved profiles --

---@param name string
---@return string
function CooldownStrings:UniqueName(name)
    if not self.db.Profiles[name] then return name end

    local index = 2
    while self.db.Profiles[name .. ' (' .. index .. ')'] do index = index + 1 end
    return name .. ' (' .. index .. ')'
end

---@param name string
---@param profileString string
---@param source string
---@param character string|nil
---@return table entry
function CooldownStrings:Save(name, profileString, source, character)
    local entry = self.db.Profiles[name] or {}
    local tag, layoutName = CooldownStrings.ReadStringInfo(profileString)

    entry.String = profileString
    entry.LayoutName = layoutName
    entry.SpecTag = tag
    entry.SpecID = CooldownStrings.TagToSpec(tag) or entry.SpecID -- a tagless save must not wipe a hand picked spec
    entry.Source = source
    entry.Character = character
    entry.UpdatedAt = GetServerTime()
    entry.Created = entry.Created or entry.UpdatedAt

    self.db.Profiles[name] = entry
    return entry
end

---@param name string
function CooldownStrings:Delete(name)
    self.db.Profiles[name] = nil
    if self.selected == name then self.selected = nil end
end

---@return table[] sorted by class then name
function CooldownStrings:GetProfiles()
    local list = {}
    for name, entry in pairs(self.db.Profiles) do
        local specID, _, icon, classFile = self.EntrySpec(entry)
        list[#list + 1] = { name = name, specID = specID, icon = icon, classFile = classFile }
    end

    tsort(list, function(a, b)
        local classA, classB = a.classFile or 'ZZZZ', b.classFile or 'ZZZZ'
        if classA ~= classB then return classA < classB end
        return a.name < b.name
    end)
    return list
end

---@return table[]
function CooldownStrings:GetCurrentSpecProfiles()
    local specID = CurrentSpecID()
    if not specID then return {} end

    local list = {}
    for _, profile in ipairs(self:GetProfiles()) do
        if profile.specID == specID then list[#list + 1] = profile end
    end
    return list
end

---@param name string
---@return 'match'|'drift'|'absent'|'unknown'
function CooldownStrings:GetStatus(name)
    if not self.IsCDMLoaded() then return 'unknown' end

    local layout = self:GetLiveLayoutFor(name)
    if not layout then return 'absent' end

    local live = SerializeLayout(layout.layoutID)
    if not live then return 'absent' end

    local match = self.StringsMatch(live, self.db.Profiles[name].String)
    if match == nil then return 'unknown' end
    return match and 'match' or 'drift'
end

---@param layoutID number
---@param name string
---@return boolean success
function CooldownStrings:Capture(layoutID, name)
    CommitPendingEdits()

    local profileString = SerializeLayout(layoutID)
    if not profileString then
        NRSKNUI:Print(L['Could not read that Cooldown Manager layout.'])
        return false
    end

    self:Save(name, profileString, 'capture', CharacterKey())
    return true
end

---@param name string
---@return boolean success
function CooldownStrings:Sync(name)
    local layout = self:GetLiveLayoutFor(name)
    if not layout then
        NRSKNUI:Print(L['That layout is not on this character.'])
        return false
    end

    return self:Capture(layout.layoutID, name)
end

---Sync overwrites the saved string, so a backup that would actually change asks first.
---@param name string
---@param onDone? fun()
function CooldownStrings:PromptSync(name, onDone)
    if not self:GetLiveLayoutFor(name) then
        NRSKNUI:Print(L['That layout is not on this character.'])
        return
    end

    -- Identical content leaves nothing to lose, so only a real difference is worth a prompt.
    if self:GetStatus(name) == 'match' then
        if self:Sync(name) and onDone then onDone() end
        return
    end

    NRSKNUI:CreatePrompt({
        title = L['Sync from CDM'],
        text = format(L['Overwrite this backup with the "%s" layout as it is now? The saved string is replaced.'],
            self:LayoutName(name)),
        onAccept = function()
            if self:Sync(name) and onDone then onDone() end
        end,
        acceptText = L['Overwrite'],
        cancelText = L['Cancel'],
    })
end

-- Restore --

---Unknown counts as loadable, the same as CanRestore only refusing a class it can actually name.
---@param name string
---@return boolean
function CooldownStrings:IsForThisClass(name)
    local classFile = EntryClassFile(self.db.Profiles[name])
    return not classFile or classFile == NRSKNUI.MyClass
end

---Answered before the player is asked to confirm, so a restore is never offered and then refused.
---@param name string
---@return boolean ok, string? reason, table? existing
function CooldownStrings:CanRestore(name)
    if NRSKNUI:InCombat() then
        return false, L['Cannot change Cooldown Manager layouts in combat.']
    end

    local entry = self.db.Profiles[name]
    if not entry.String or entry.String == '' then
        return false, L['That profile has no string saved.']
    end

    if not EnsureCDM() then
        return false, L['The Cooldown Manager is not available.']
    end

    -- A layout only loads onto its own class, and importing to find out taints the whole viewer.
    local classFile = EntryClassFile(entry)
    if classFile and classFile ~= NRSKNUI.MyClass then
        return false, L['That profile belongs to another class.']
    end

    -- Replacing frees the slot it takes, so the slot limit only bites when adding a new one.
    local existing = self:GetLiveLayoutFor(name)
    if not existing and GetLayoutManager():AreLayoutsFullyMaxed() then
        return false, L['The Cooldown Manager is out of layout slots, delete one first.']
    end

    return true, nil, existing
end

---Writing a layout from insecure code taints the Cooldown Manager, which then errors on its own
---aura events, so this always ends in a reload and callers must confirm that first.
---@param name string
function CooldownStrings:Restore(name)
    -- Re-checked because the player could have pulled something while the prompt was open.
    local ok, reason, existing = self:CanRestore(name)
    if not ok then
        NRSKNUI:Print(reason)
        return
    end

    local entry = self.db.Profiles[name]
    local layoutManager = GetLayoutManager()
    local classFile = EntryClassFile(entry)

    CommitPendingEdits()
    if existing then layoutManager:RemoveLayout(existing.layoutID) end

    local read, layoutIDs = pcall(layoutManager.CreateLayoutsFromSerializedData, layoutManager, Clean(entry.String))
    if not read or type(layoutIDs) ~= 'table' or not layoutIDs[1] then
        NRSKNUI:Print(L['Could not read that profile string.'])
        return
    end

    -- A string can hold several layouts and the first is often an unnamed default, so activate
    -- the one the profile was named after and fall back to the first that carries any name.
    local importedName = self:LayoutName(name)
    local _, layouts = layoutManager:EnumerateLayouts()

    local active, named
    for _, layoutID in ipairs(layoutIDs) do
        for _, layout in pairs(layouts) do
            if layout.layoutID == layoutID then
                if layout.layoutName == importedName then active = layoutID end
                if not named and layout.layoutName and layout.layoutName ~= '' then named = layoutID end

                -- Only an undecodable string gets here, so the import answers for the class.
                -- Undone but still reloaded, the viewer is tainted once we have written to it.
                if not classFile then
                    local layoutClass = SplitTag(layout.classAndSpecTag)
                    if layoutClass and layoutClass ~= NRSKNUI.MyClassID then
                        for _, id in ipairs(layoutIDs) do layoutManager:RemoveLayout(id) end
                        layoutManager:SaveLayouts()
                        ReloadUI()
                        return
                    end
                end
                break
            end
        end
    end

    layoutManager:SetActiveLayoutByID(active or named or layoutIDs[1])
    layoutManager:SaveLayouts()
    ReloadUI()
end

---@param name string|nil
function CooldownStrings:PromptRestore(name)
    if not name then return end

    local ok, reason, existing = self:CanRestore(name)
    if not ok then
        NRSKNUI:Print(reason)
        return
    end

    NRSKNUI:CreatePrompt({
        title = L['Restore to CDM'],
        text = existing
            and format(L['Replace the Cooldown Manager layout "%s" with this backup? Your UI reloads straight after.'], self:LayoutName(name))
            or format(L['Restore "%s" to the Cooldown Manager? Your UI reloads straight after.'], self:LayoutName(name)),
        onAccept = function() self:Restore(name) end,
        acceptText = existing and L['Replace'] or L['Restore'],
        cancelText = L['Cancel'],
    })
end

-- Logout snapshot --

---Snapshots this character's layouts so another character can still capture them.
---Never loads the addon here, an untouched Cooldown Manager just leaves the last snapshot standing.
function CooldownStrings:CacheLayouts()
    if not self.IsCDMLoaded() then return end

    local layouts = {}
    for _, layout in ipairs(self:GetLiveLayouts()) do
        local profileString = SerializeLayout(layout.layoutID)
        if profileString then
            layouts[layout.name] = { String = profileString, SpecTag = layout.tag }
        end
    end

    if not next(layouts) then return end

    self.cache[CharacterKey()] = {
        name = NRSKNUI.MyName,
        updatedAt = GetServerTime(),
        layouts = layouts,
    }
end

-- Attached panel --

local PANEL_WIDTH = 240
local PANEL_HEIGHT = 125
local BUTTON_HEIGHT = 26

-- In the Cooldown Manager's anchor family, so moving it is a protected call and never inline.
local function ApplyPanelPosition(panel)
    NRSKNUI:RunWhenSafe(function()
        if not CooldownViewerSettings then return end

        panel:ClearAllPoints()
        panel:NUISetPixelPoint('TOPLEFT', CooldownViewerSettings, 'BOTTOMLEFT', 0, -2)
    end)
end

function CooldownStrings:CreatePanel()
    if self.panel then return self.panel end

    local panel = CreateFrame('Frame', 'NRSKNUI_CooldownStringsPanel', UIParent)
    panel:SetFrameStrata('DIALOG')
    panel:SetClampedToScreen(true)
    panel:NUISetPixelSize(PANEL_WIDTH, PANEL_HEIGHT)
    NRSKNUI:CreateBackdrop(panel)
    panel:SetBackgroundColor(Theme.bgLight[1], Theme.bgLight[2], Theme.bgLight[3], 0.95)
    panel:SetBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], Theme.border[4])
    panel:NUISetScheduledUpdate(ApplyPanelPosition)

    local header = CreateFrame('Frame', nil, panel)
    header:NUISetPixelHeight(Theme.headerHeight)
    header:NUISetPixelPoint('TOPLEFT', panel, 'TOPLEFT', 0, 0)
    header:NUISetPixelPoint('TOPRIGHT', panel, 'TOPRIGHT', 0, 0)

    local divider = header:CreateTexture(nil, 'OVERLAY')
    divider:NUISetPixelHeight(Theme.borderSize)
    divider:NUISetPixelPoint('BOTTOMLEFT', header, 'BOTTOMLEFT', 0, 0)
    divider:NUISetPixelPoint('BOTTOMRIGHT', header, 'BOTTOMRIGHT', 0, 0)
    divider:SetColorTexture(Theme.border[1], Theme.border[2], Theme.border[3], Theme.border[4])

    local title = header:CreateFontString(nil, 'OVERLAY')
    title:NUISetPixelPoint('LEFT', header, 'LEFT', Theme.paddingMedium, 0)
    title:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    NRSKNUI.GUI:ApplyFont(title, 'large')
    panel.title = title

    local open = CreateFrame('Button', nil, header)
    open:NUISetPixelSize(14, 14)
    open:NUISetPixelPoint('RIGHT', header, 'RIGHT', -Theme.paddingMedium, 0)

    local openIcon = open:CreateTexture(nil, 'ARTWORK')
    openIcon:SetAllPoints()
    openIcon:SetTexture('Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\NorskenCustomCrossv3.png')
    openIcon:SetVertexColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    openIcon:NUISetPixelSnap()
    open:SetNormalTexture(openIcon)

    open:SetScript('OnEnter', function(button)
        openIcon:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
        GameTooltip:SetOwner(button, 'ANCHOR_TOP')
        GameTooltip:SetText(L['Open Profile Manager'], 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    open:SetScript('OnLeave', function()
        openIcon:SetVertexColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
        GameTooltip:Hide()
    end)
    open:SetScript('OnClick', function()
        local window = NRSKNUI.GUIFrame
        if not window:IsShown() then window:Show() end
        window:ShowPage('cdmStrings')
    end)

    local content = CreateFrame('Frame', nil, panel)
    content:NUISetPixelPoint('TOPLEFT', panel, 'TOPLEFT', Theme.paddingMedium, -Theme.headerHeight - Theme.paddingMedium)
    content:NUISetPixelPoint('BOTTOMRIGHT', panel, 'BOTTOMRIGHT', -Theme.paddingMedium, Theme.paddingMedium)
    panel.content = content

    panel:Hide()
    self.panel = panel
    return panel
end

function CooldownStrings:BuildPanel()
    local panel = self.panel
    if not panel then return end

    local GUI = NRSKNUI.GUI
    for _, child in ipairs({ panel.content:GetChildren() }) do
        GUI:ReleaseWidget(child) -- pooled, orphaning them leaks the subtree
    end

    local profiles = self:GetCurrentSpecProfiles()
    local _, specName = self.SpecIDToSpec(CurrentSpecID())
    panel.title:SetText(specName and (specName .. ' ' .. L['Profiles']) or L['CDM Profiles'])

    if not profiles[1] then
        local empty = GUI:CreateText(panel.content, nil, {
            bgMode = 'hide',
            text = L['No profiles saved for this specialization.'],
        })
        empty:SetAllPoints(panel.content)
        return
    end

    local options = {}
    for _, profile in ipairs(profiles) do
        options[#options + 1] = { key = profile.name, text = profile.name }
    end

    if not self.selected or not self.db.Profiles[self.selected] then self.selected = profiles[1].name end

    local restore = GUI:CreateButton(panel.content, L['Add / Restore to CDM'], {
        height = BUTTON_HEIGHT,
        callback = function() self:PromptRestore(self.selected) end,
    })
    restore:NUISetPixelPoint('TOPLEFT', panel.content, 'TOPLEFT', 0, 0)
    restore:NUISetPixelPoint('TOPRIGHT', panel.content, 'TOPRIGHT', 0, 0)

    local dropdown = GUI:CreateDropdown(panel.content, L['Profile'], {
        options = options,
        value = self.selected,
        callback = function(key) self.selected = key end,
    })
    dropdown:NUISetPixelPoint('TOPLEFT', restore, 'BOTTOMLEFT', 0, -Theme.paddingSmall)
    dropdown:NUISetPixelPoint('TOPRIGHT', restore, 'BOTTOMRIGHT', 0, -Theme.paddingSmall)
end

function CooldownStrings:ShowPanel()
    self:CreatePanel()
    self:BuildPanel()
    self.panel:NUIScheduleUpdate()
    self.panel:Show()
end

function CooldownStrings:HidePanel()
    if self.panel then
        self.panel:Hide()
    end
end

function CooldownStrings:HookSettingsFrame()
    local settings = CooldownViewerSettings
    if not settings or self.hooked then return end
    self.hooked = true

    settings:HookScript('OnShow', function()
        if self.db.Enabled then
            self:ShowPanel()
        end
    end)
    settings:HookScript('OnHide', function()
        self:HidePanel()
        RunNextFrame(function()
            self:CacheLayouts()
        end)
    end)
end

-- Module --

function CooldownStrings:UpdateDB()
    self.db = NRSKNUI.db.profile.Miscellaneous.CooldownStrings
    self.cache = NRSKNUI.db.global.CDMLayoutCache
end

function CooldownStrings:ApplySettings()
    self:UpdateDB()
    if self.panel and self.panel:IsShown() then
        self:BuildPanel()
    end
end

function CooldownStrings:ADDON_LOADED(_, addOnName)
    if addOnName ~= 'Blizzard_CooldownViewer' then return end

    self:HookSettingsFrame()
    self:UnregisterEvent('ADDON_LOADED')
end

function CooldownStrings:PLAYER_LOGOUT()
    self:CacheLayouts()
end

function CooldownStrings:OnEnable()
    self:UpdateDB()
    self:RegisterEvent('PLAYER_LOGOUT')

    if self.IsCDMLoaded() then
        self:HookSettingsFrame()
    else
        self:RegisterEvent('ADDON_LOADED')
    end
end

function CooldownStrings:OnDisable()
    self:HidePanel()
end
