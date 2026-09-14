---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class GroupFinderModule
local GroupFinder = NRSKNUI:GetModule('GroupFinder')
function GroupFinder:UpdateDB() self.db = NRSKNUI.db.profile.Miscellaneous.GroupFinder end

local gmatch, strmatch, strsub, strupper = string.gmatch, string.match, string.sub, string.upper
local hooksecurefunc = hooksecurefunc
local ipairs, pairs = ipairs, pairs
local setmetatable = setmetatable
local tsort = table.sort
local GetTime = GetTime
local next = next
local type = type
local wipe = wipe

local bit_bor = bit.bor
local bit_band = bit.band
local bit_bnot = bit.bnot

local GetSearchResultMemberCounts = C_LFGList and C_LFGList.GetSearchResultMemberCounts
local GetRunHistory = C_MythicPlus and C_MythicPlus.GetRunHistory
local GetAdvancedFilter = C_LFGList and C_LFGList.GetAdvancedFilter
local SaveAdvancedFilter = C_LFGList and C_LFGList.SaveAdvancedFilter
local GetActivityGroupInfo = C_LFGList and C_LFGList.GetActivityGroupInfo
local GetAvailableActivityGroups = C_LFGList and C_LFGList.GetAvailableActivityGroups
local GetDungeonScoreRarityColor = C_ChallengeMode and C_ChallengeMode.GetDungeonScoreRarityColor
local GetChallengeMapTable = C_ChallengeMode and C_ChallengeMode.GetMapTable
local GetChallengeMapUIInfo = C_ChallengeMode and C_ChallengeMode.GetMapUIInfo
local RequestMapInfo = C_MythicPlus and C_MythicPlus.RequestMapInfo
local GetAllGroups = C_SocialQueue and C_SocialQueue.GetAllGroups
local GetGroupQueues = C_SocialQueue and C_SocialQueue.GetGroupQueues
local GetApplicationInfo = C_LFGList and C_LFGList.GetApplicationInfo
local GetSearchResultPlayerInfo = C_LFGList and C_LFGList.GetSearchResultPlayerInfo
local GetActivityInfoTable = C_LFGList and C_LFGList.GetActivityInfoTable
local HasSearchResultInfo = C_LFGList and C_LFGList.HasSearchResultInfo
local GetSearchResultInfo = C_LFGList and C_LFGList.GetSearchResultInfo
local GetLanguageSearchFilter = C_LFGList and C_LFGList.GetLanguageSearchFilter
local Search = C_LFGList and C_LFGList.Search

local RAID_CLASS_COLORS = RAID_CLASS_COLORS

local DUNGEON_CATEGORY = 2
local SERVER_SEARCH_THROTTLE = 3 -- Lower than 3s may cause search failures.
local RESORT_DELAY = 0.2
local FRIEND_REFRESH_INTERVAL = 2
local ABBREVIATION_MIN_WORD = 2

GroupFinder.ServerSearchThrottle = SERVER_SEARCH_THROTTLE

-- Raider.IO's own short names, so the filter buttons read the same as its tooltips.
-- Mirrors ns.expansionDungeons in RaiderIO/db/db_dungeons.lua.
local RAIDER_IO_SHORT_NAMES = {
    ["Pit of Saron"] = 'POS',
    ["Skyreach"] = 'SR',
    ["Seat of the Triumvirate"] = 'SEAT',
    ["Kings' Rest"] = 'KR',
    ["Temple of Sethraliss"] = 'TOS',
    ["Algeth'ar Academy"] = 'AA',
    ["Ruby Life Pools"] = 'RLP',
    ["Windrunner Spire"] = 'WS',
    ["Magisters' Terrace"] = 'MT',
    ["Murder Row"] = 'MR',
    ["The Blinding Vale"] = 'BV',
    ["Den of Nalorakk"] = 'DON',
    ["Maisara Caverns"] = 'MC',
    ["Voidscar Arena"] = 'VSA',
    ["Nexus-Point Xenas"] = 'NPX',
    ["Altar of Fangs"] = 'AOF',
}

local LEADER_ICON_ATLAS = 'groupfinder-icon-leader'
local ROLE_ATLAS = {
    TANK = 'groupfinder-icon-role-micro-tank',
    HEALER = 'groupfinder-icon-role-micro-heal',
    DAMAGER = 'groupfinder-icon-role-micro-dps',
}
local APPLICANT_ROLE_ICONS = { 'RoleIcon1', 'RoleIcon2', 'RoleIcon3' }
local ROLE_SORT = {
    TANK = 1,
    HEALER = 2,
    DAMAGER = 3,
}
local DECLINED_STATUS = {
    declined = true,
    declined_full = true,
    declined_delisted = true
}

local ROW_WIDTH = 312
local NAME_INSET = 10
local SCORE_WIDTH = 35
local SCORE_RIGHT_INSET = -115
local SCORE_TOP_INSET = -4
local VOICE_CHAT_WIDTH = 20
local TEXT_WIDTH_WITH_SCORE = ROW_WIDTH - NAME_INSET - SCORE_WIDTH + SCORE_RIGHT_INSET

---@param container any
---@param key any
---@return any|nil
local function SafeIndex(container, key)
    if NRSKNUI:IsSecretValue(container) or NRSKNUI:IsSecretTable(container) then return nil end
    if type(container) ~= 'table' then return nil end
    return NRSKNUI:SafeValue(container[key])
end

-- Score --

---RaiderIO is a metatable-only table, so probe the field rather than iterating it.
---@return boolean
function GroupFinder:IsRaiderIOAvailable()
    local raiderIO = _G.RaiderIO
    return raiderIO ~= nil and type(raiderIO.GetScoreColor) == 'function'
end

---@param score number
---@return number r, number g, number b
function GroupFinder:GetScoreColor(score)
    -- If Raider.io is available and selected as the score color source, use it.
    if self.db.ScoreColorSource == 'raiderio' and self:IsRaiderIOAvailable() then
        return _G.RaiderIO.GetScoreColor(score)
    end

    -- Fallback to the default dungeon score color if RaiderIO is not used or unavailable.
    local color = GetDungeonScoreRarityColor(score)
    if color then
        return color.r, color.g, color.b
    end
    return 1, 1, 1
end

-- Friend groups --

local friendResults = {}
local friendResultsStamp = 0

function GroupFinder:RefreshFriendResults()
    wipe(friendResults)
    friendResultsStamp = GetTime()
    if not GetAllGroups then return end

    for _, guid in ipairs(GetAllGroups(true, true) or {}) do
        for _, queue in ipairs(GetGroupQueues(guid) or {}) do
            local data = queue.queueData

            if data and data.queueType == 'lfglist' and data.lfgListID then
                friendResults[data.lfgListID] = true
            end
        end
    end
end

---SOCIAL_QUEUE_UPDATE does not fire for data that settled before the browser was opened.
function GroupFinder:EnsureFriendResults()
    if GetTime() - friendResultsStamp < FRIEND_REFRESH_INTERVAL then return end
    self:RefreshFriendResults()
end

---@param resultID number
---@param info table
---@return boolean
local function IsFriendResult(resultID, info)
    GroupFinder:EnsureFriendResults()

    -- Blizzard's own counts still win when they are readable, the queue set covers when they are not.
    return friendResults[resultID] == true
        or (NRSKNUI:SafeValue(info.numBNetFriends) or 0) > 0
        or (NRSKNUI:SafeValue(info.numCharFriends) or 0) > 0
        or (NRSKNUI:SafeValue(info.numGuildMates) or 0) > 0
end

---Blizzard's own precedence puts declined and delisted ahead of the friend color.
---@param row NUISearchEntry
---@param info table
---@return boolean
local function ShouldColorAsFriend(row, info)
    if row.isApplication then return false end
    if not IsFriendResult(row.resultID, info) then return false end
    if NRSKNUI:SafeValue(info.isDelisted) then return false end

    local _, appStatus = GetApplicationInfo(row.resultID)
    if appStatus and appStatus ~= 'none' then return false end

    local declines = SafeIndex(_G.LFGListFrame, 'declines')
    local partyGUID = NRSKNUI:SafeValue(info.partyGUID)
    if declines and partyGUID and declines[partyGUID] then return false end

    return true
end

-- Row decoration --

-- Keyed by the Blizzard row so no new keys land on a frame one click from the sign-up path.
local rowWidgets = setmetatable({}, { __mode = 'k' })

---@param row NUISearchEntry
---@return table
local function GetRowWidgets(row)
    local widgets = rowWidgets[row]
    if not widgets then
        widgets = { bars = {}, crowns = {} }
        rowWidgets[row] = widgets
    end
    return widgets
end

---@param row NUISearchEntry
---@return FontString
local function AcquireScoreText(row)
    local widgets = GetRowWidgets(row)
    if widgets.score then return widgets.score end

    local text = row:CreateFontString(nil, 'ARTWORK')
    text:SetJustifyH('RIGHT')
    text:SetSize(SCORE_WIDTH, 15)
    text:SetPoint('TOPRIGHT', row, 'TOPRIGHT', SCORE_RIGHT_INSET, SCORE_TOP_INSET)
    text:SetFontStyle(GroupFinder.db, GroupFinder.db.FontSize)

    widgets.score = text
    return text
end

---@param row NUISearchEntry
---@param icon Frame
---@param index number
---@return Texture
local function AcquireClassBar(row, icon, index)
    local widgets = GetRowWidgets(row)
    if widgets.bars[index] then
        return widgets.bars[index]
    end

    local bar = icon:CreateTexture(nil, 'OVERLAY')
    bar:SetSize(16, 3)
    bar:SetPoint('BOTTOM', icon, 'BOTTOM', 0, -3)

    widgets.bars[index] = bar
    return bar
end

---@param row NUISearchEntry
---@param icon Frame
---@param index number
---@return Texture
local function AcquireCrown(row, icon, index)
    local widgets = GetRowWidgets(row)
    if widgets.crowns[index] then
        return widgets.crowns[index]
    end

    local crown = icon:CreateTexture(nil, 'OVERLAY')
    crown:SetAtlas(LEADER_ICON_ATLAS, false)
    crown:SetSize(10, 7)
    crown:SetPoint('BOTTOM', icon, 'TOP', 0, 0)

    widgets.crowns[index] = crown
    return crown
end

---@param row NUISearchEntry
local function HideRowExtras(row)
    local widgets = rowWidgets[row]
    if not widgets then return end

    if widgets.score then widgets.score:Hide() end
    for _, bar in pairs(widgets.bars) do bar:Hide() end
    for _, crown in pairs(widgets.crowns) do crown:Hide() end
end

---@param row NUISearchEntry
---@param info table
local function UpdateRowScore(row, info)
    local score = NRSKNUI:SafeValue(info.leaderOverallDungeonScore)

    if not GroupFinder.db.ShowLeaderScore or row.isApplication or not score or score == 0 then
        local widgets = rowWidgets[row]
        if widgets and widgets.score then
            widgets.score:Hide()
        end
        return
    end

    local text = AcquireScoreText(row)
    text:SetText(score)
    text:SetTextColor(GroupFinder:GetScoreColor(score))
    text:Show()

    -- Blizzard re-widens both every pass, so the narrower cap has to be re-applied on each one.
    local width = TEXT_WIDTH_WITH_SCORE
    if row.VoiceChat and row.VoiceChat:IsShown() then width = width - VOICE_CHAT_WIDTH end
    if row.Name then row.Name:SetWidth(width) end
    if row.ActivityName then row.ActivityName:SetWidth(width) end
end

---Collect the whole roster first, an unreadable one leaves Blizzard's own display alone.
---@param resultID number
---@param info table
---@return table|nil
local function ReadMembers(resultID, info)
    local numMembers = NRSKNUI:SafeValue(info.numMembers)
    if not numMembers then return nil end

    local members = {}
    for index = 1, numMembers do
        local member = GetSearchResultPlayerInfo(resultID, index)
        if not member then return nil end

        local class = NRSKNUI:SafeValue(member.classFilename)
        local role = NRSKNUI:SafeValue(member.assignedRole)
        if not class or not role then return nil end

        members[index] = {
            class = class,
            role = role,
            isLeader = NRSKNUI:SafeValue(member.isLeader) == true,
            isLeaver = NRSKNUI:SafeValue(member.isLeaver) == true,
        }
    end

    tsort(members, function(a, b)
        local roleA, roleB = ROLE_SORT[a.role] or 4, ROLE_SORT[b.role] or 4
        if roleA ~= roleB then return roleA < roleB end
        return a.class < b.class
    end)

    return members
end

---@param row NUISearchEntry
local function HideRoleExtras(row)
    local widgets = rowWidgets[row]
    if not widgets then return end

    for _, bar in pairs(widgets.bars) do bar:Hide() end
    for _, crown in pairs(widgets.crowns) do crown:Hide() end
end

---@param row NUISearchEntry
---@param info table
local function UpdateRowRoles(row, info)
    local display = row.DataDisplay
    local enumerate = display and display.Enumerate
    if not enumerate or not enumerate:IsShown() then return end

    local icons = enumerate.Icons
    if not icons then return end

    if GroupFinder.db.RoleIconStyle ~= 'bar' then
        HideRoleExtras(row)
        return
    end

    local activityID = SafeIndex(info.activityIDs, 1)
    local activityInfo = activityID and GetActivityInfoTable(activityID)
    local maxPlayers = activityInfo and NRSKNUI:SafeValue(activityInfo.maxNumPlayers)
    if not maxPlayers or maxPlayers > #icons then return end

    local members = ReadMembers(row.resultID, info)
    if not members then return end

    -- Blizzard fills the slots from the highest index down, which reads left-to-right on screen.
    local slot = maxPlayers
    for _, member in ipairs(members) do
        if slot < 1 then break end

        local icon = icons[slot]
        local color = RAID_CLASS_COLORS[member.class]

        icon.RoleIconWithBackground:Hide()
        icon.ClassCircle:Hide()
        icon.RoleIcon:SetAtlas(ROLE_ATLAS[member.role] or ROLE_ATLAS.DAMAGER, false)
        icon.RoleIcon:Show()
        icon.LeaverIcon:SetShown(member.isLeaver)

        local bar = AcquireClassBar(row, icon, slot)
        bar:SetColorTexture(color and color.r or 1, color and color.g or 1, color and color.b or 1, 1)
        bar:Show()

        AcquireCrown(row, icon, slot):SetShown(member.isLeader)

        slot = slot - 1
    end

    local widgets = GetRowWidgets(row)
    for index = 1, slot do
        if widgets.bars[index] then widgets.bars[index]:Hide() end
        if widgets.crowns[index] then widgets.crowns[index]:Hide() end
    end
end

---@param row NUISearchEntry
local function UpdateRow(row)
    if not GroupFinder.db.Enabled then
        HideRowExtras(row)
        return
    end

    local resultID = row.resultID
    if not resultID or not HasSearchResultInfo(resultID) then
        HideRowExtras(row)
        return
    end

    local info = GetSearchResultInfo(resultID)
    if not info then
        HideRowExtras(row)
        return
    end

    if ShouldColorAsFriend(row, info) and row.Name then
        local color = _G.BATTLENET_FONT_COLOR
        if color then
            row.Name:SetTextColor(color.r, color.g, color.b)
        end
    end

    UpdateRowScore(row, info)
    UpdateRowRoles(row, info)
end

-- Applicant list --

---@type table<string, string>?
local flatRoleAtlas

---Blizzard's plated atlas keyed back to our flat glyph. Built on first use, the table it reads from
---belongs to the group finder addon and loads later than this file.
---@param plated string?
---@return string?
local function FlatRoleAtlas(plated)
    if not plated then return nil end

    if not flatRoleAtlas then
        local plates = _G.LFG_LIST_GROUP_DATA_ATLASES
        if not plates then return nil end

        flatRoleAtlas = {}
        for role, atlas in pairs(plates) do
            flatRoleAtlas[atlas] = ROLE_ATLAS[role]
        end
    end

    return flatRoleAtlas[plated]
end

---The listing header drives the same icon widget the search rows use, but always down the plated
---branch, so the filled slots are swapped to the flat glyphs the applicant rows already show.
---@param viewer LFGListApplicationViewer
local function UpdateEntryRoles(viewer)
    if not GroupFinder.db.Enabled or GroupFinder.db.RoleIconStyle ~= 'bar' then return end

    local display = viewer.DataDisplay
    local enumerate = display and display.Enumerate
    if not enumerate or not enumerate:IsShown() then return end

    for _, icon in ipairs(enumerate.Icons or {}) do
        local plated = icon.RoleIconWithBackground
        -- Blizzard re-atlases the plated layer without re-showing it, so only the atlas marks a slot.
        local atlas = icon:IsShown() and plated and FlatRoleAtlas(plated:GetAtlas())

        if atlas then
            plated:Hide()
            icon.ClassCircle:Hide()
            icon.RoleIcon:SetAtlas(atlas, false)
            -- The glyph layer is the small one, so it takes the plated layer's slot to match the rows.
            icon.RoleIcon:SetAllPoints(icon)
            icon.RoleIcon:Show()
        end
    end
end

---Applicant rows carry Blizzard's plated role icons, so the bar style re-atlases them to the same
---flat glyphs the search results use. Blizzard stamps the role on each icon just before this runs.
---@param member Button
local function UpdateApplicantRoles(member)
    if not GroupFinder.db.Enabled or GroupFinder.db.RoleIconStyle ~= 'bar' then return end

    for _, key in ipairs(APPLICANT_ROLE_ICONS) do
        local icon = member[key]
        local atlas = icon and icon:IsShown() and ROLE_ATLAS[icon.role]

        if atlas then
            icon:GetNormalTexture():SetAtlas(atlas, false)
            icon:GetHighlightTexture():SetAtlas(atlas, false)
        end
    end
end

-- Filtering --

---@return boolean
local function IsDungeonMode()
    local frame = _G.LFGListFrame
    local selection = frame and frame.CategorySelection

    return (selection and selection.selectedCategory == DUNGEON_CATEGORY) == true
end
GroupFinder.IsDungeonMode = IsDungeonMode

---@param resultID number
---@param info table
---@return boolean
local function ReadDeclined(resultID, info)
    local _, appStatus = GetApplicationInfo(resultID)
    if appStatus and DECLINED_STATUS[appStatus] then return true end

    local declines = SafeIndex(_G.LFGListFrame, 'declines')
    local partyGUID = NRSKNUI:SafeValue(info.partyGUID)

    return (declines and partyGUID and declines[partyGUID]) ~= nil
end

---Every unreadable value keeps the group, a filter must never hide a listing it could not judge.
---@param resultID number
---@param info table
---@return boolean
local function PassesFilters(resultID, info)
    local filters = GroupFinder.filters

    if next(filters.dungeons) then
        local activityID = SafeIndex(info.activityIDs, 1)
        local activityInfo = activityID and GetActivityInfoTable(activityID)
        local groupID = activityInfo and NRSKNUI:SafeValue(activityInfo.groupFinderActivityGroupID)
        if groupID and not filters.dungeons[groupID] then return false end
    end

    -- hasTank, hasHealer, needsRole and noMySpec are pushed into Blizzard's advanced filter, which
    -- flags a listing that stops matching as isNowFilteredOut and paints the row red. Dropping those
    -- here would delete the row before that can happen, so they are left to Blizzard. hasEither has
    -- no advanced filter equivalent, so it stays local.
    if filters.hasEither then
        local counts = GetSearchResultMemberCounts(resultID)
        if counts then
            local tank = SafeIndex(counts, 'TANK')
            local healer = SafeIndex(counts, 'HEALER')

            if tank == 0 and healer == 0 then return false end
        end
    end

    if filters.notDeclined and ReadDeclined(resultID, info) then return false end

    return true
end

-- Sorting --

local scoreCache = {}
local declinedCache = {}
local friendCache = {}
local appliedCache = {}
local orderCache = {}

---@param resultID number
---@return boolean
local function ReadApplied(resultID)
    local _, appStatus, pendingStatus = GetApplicationInfo(resultID)
    if pendingStatus then return true end

    return appStatus ~= nil and appStatus ~= 'none'
end

---Unknown rather than zero: scoring it 0 would hoist every secret listing to one end of the list.
---@param info table
---@return number? score nil when the value could not be read
local function ReadSortScore(info)
    if GroupFinder.db.SortBy == 'dungeonScore' then
        local entry = SafeIndex(info.leaderDungeonScoreInfo, 1)
        if not entry then return nil end

        return SafeIndex(entry, 'mapScore')
    end
    return NRSKNUI:SafeValue(info.leaderOverallDungeonScore)
end

---@param a number
---@param b number
---@return boolean
local function CompareResults(a, b)
    if declinedCache[a] ~= declinedCache[b] then
        return declinedCache[b] == true
    end

    -- Groups you have applied to are the ones you are waiting on, so they lead the score order
    -- the way they do unsorted. A decline still drops them, since that is tested first.
    if appliedCache[a] ~= appliedCache[b] then
        return appliedCache[a] == true
    end

    -- Groups with a friend or guildmate stay pinned above the score order.
    if friendCache[a] ~= friendCache[b] then
        return friendCache[a] == true
    end

    local scoreA, scoreB = scoreCache[a], scoreCache[b]

    -- An unread score cannot be ranked, so those rows fall behind the ones that could be.
    if (scoreA == nil) ~= (scoreB == nil) then
        return scoreB == nil
    end

    if scoreA and scoreA ~= scoreB then
        if GroupFinder.db.SortDescending then
            return scoreA > scoreB
        end
        return scoreA < scoreB
    end

    -- Blizzard's own order is the tiebreak, so equal and unreadable rows hold their places.
    return (orderCache[a] or 0) < (orderCache[b] or 0)
end

-- Result pass --

local rawResults = {}

---Only the filters PassesFilters can act on, the rest are the server's and buy no local pass.
---@return boolean
local function HasActiveFilters()
    local filters = GroupFinder.filters
    return next(filters.dungeons) ~= nil
        or filters.hasEither
        or filters.notDeclined
end

---@param a table
---@param b table?
---@return boolean
local function ResultsDiffer(a, b)
    if not b or #a ~= #b then return true end

    for index = 1, #a do
        if a[index] ~= b[index] then return true end
    end

    return false
end

---@param panel NUISearchPanel
local function DoResultPass(panel)
    if not GroupFinder.db.Enabled or not IsDungeonMode() then return end

    if panel.searchFailed then return end

    -- A re-filter can land before Blizzard has ever delivered a list, and an empty snapshot would
    -- blank the panel rather than filter it.
    if #rawResults == 0 then return end

    -- With nothing to filter or sort there is no reason to write to Blizzard's results table at all.
    local sortByScore = GroupFinder.db.SortBy ~= 'default'
    if not sortByScore and not HasActiveFilters() then return end

    local filtered = {}

    wipe(scoreCache)
    wipe(declinedCache)
    wipe(friendCache)
    wipe(appliedCache)
    wipe(orderCache)

    for index = 1, #rawResults do
        local resultID = rawResults[index]
        local info = GetSearchResultInfo(resultID)

        if info and PassesFilters(resultID, info) then
            filtered[#filtered + 1] = resultID
            if sortByScore then
                orderCache[resultID] = index
                scoreCache[resultID] = ReadSortScore(info)
                declinedCache[resultID] = ReadDeclined(resultID, info)
                friendCache[resultID] = IsFriendResult(resultID, info)
                appliedCache[resultID] = ReadApplied(resultID)
            end
        end
    end

    if sortByScore then
        tsort(filtered, CompareResults)
    end

    if not ResultsDiffer(filtered, panel.results) then return end

    panel.results = filtered
    panel.totalResults = #filtered

    LFGListSearchPanel_UpdateResults(panel)
end

---Snapshot the raw delivery so relaxing a filter resurrects rows without a re-search.
---@param panel NUISearchPanel
local function OnUpdateResultList(panel)
    if not GroupFinder.db.Enabled then return end

    -- A rejected search delivers an empty list, which would erase what is still on screen.
    if not panel.searchFailed then
        local results = panel.results
        wipe(rawResults)
        for index = 1, results and #results or 0 do
            rawResults[index] = results[index]
        end
    end

    DoResultPass(panel)
end

---Re-filter what already arrived, with no server round trip.
function GroupFinder:RefreshResults()
    local frame = _G.LFGListFrame
    ---@type NUISearchPanel?
    local panel = frame and frame.SearchPanel
    if not panel or not panel:IsVisible() then return end

    DoResultPass(panel)
end

-- Server-side advanced filter --

---Push what the server can filter on so the result cap is spent on relevant listings.
function GroupFinder:PushAdvancedFilter()
    if not IsDungeonMode() then return end

    local enabled = GetAdvancedFilter()
    if not enabled then return end

    local filters = self.filters
    local role = NRSKNUI.MySpec.role

    enabled.hasTank = filters.hasTank
    enabled.hasHealer = filters.hasHealer
    enabled.needsTank = filters.needsRole and role == 'TANK' or false
    enabled.needsHealer = filters.needsRole and role == 'HEALER' or false
    enabled.needsDamage = filters.needsRole and role == 'DAMAGER' or false
    enabled.needsMyClass = filters.noMySpec

    local activities = {}
    for groupID in pairs(filters.dungeons) do
        activities[#activities + 1] = groupID
    end
    enabled.activities = activities

    SaveAdvancedFilter(enabled)
end

function GroupFinder:DoServerSearch()
    local frame = _G.LFGListFrame
    local panel = frame and frame.SearchPanel
    if not panel or not panel:IsVisible() then return end

    self:PushAdvancedFilter()

    -- Throttled clicks still re-filter locally, so the button is never a silent no-op.
    local now = GetTime()
    if now - (self.lastServerSearch or 0) < self.ServerSearchThrottle then
        self:RefreshResults()
        return
    end
    self.lastServerSearch = now

    -- Dungeons only ever list recommended groups, and only they carry an advanced filter.
    local isDungeon = panel.categoryID == DUNGEON_CATEGORY
    local filters = panel.filters or 0
    if isDungeon then
        filters = bit_band(bit_bnot(Enum.LFGListFilter.NotRecommended), bit_bor(filters, Enum.LFGListFilter.Recommended))
    end

    -- GetLanguageSearchFilter is absent from the generated API docs, so it is called only if present.
    local languages = GetLanguageSearchFilter and GetLanguageSearchFilter()
    Search(panel.categoryID, filters, panel.preferredFilters, languages, nil, isDungeon and GetAdvancedFilter() or nil)
end

function GroupFinder:OnFilterChanged()
    self:PushAdvancedFilter()
    self:RefreshResults()
    self:RefreshPanel()
end

-- Available dungeons --

---@param name string
---@return string
local function Abbreviate(name)
    local trimmed = strmatch(name, ':%s*(.+)$') or name

    local known = RAIDER_IO_SHORT_NAMES[name] or RAIDER_IO_SHORT_NAMES[trimmed]
    if known then return known end

    local letters = ''

    for word in gmatch(trimmed, '[^%s%-,]+') do
        if #word > ABBREVIATION_MIN_WORD then
            letters = letters .. strupper(strsub(word, 1, 1))
            if #letters >= 4 then
                break
            end
        end
    end

    if #letters < 2 then
        return strupper(strsub(trimmed, 1, 3))
    end

    return letters
end

---LFGList activity groups carry neither art nor a challenge map ID, so the season's
---challenge mode maps supply both. The dungeon name is the only key the two lists share.
---@return table<string, { icon: number, mapID: number, timeLimit: number }>
local function GetChallengeMaps()
    local maps = {}

    for _, mapID in ipairs(GetChallengeMapTable() or {}) do
        local name, _, timeLimit, texture = GetChallengeMapUIInfo(mapID)
        if name then
            maps[name] = {
                icon = texture,
                mapID = mapID,
                timeLimit = timeLimit
            }
        end
    end

    return maps
end

---@return table
function GroupFinder:GetSeasonDungeons()
    if self.seasonDungeons then return self.seasonDungeons end

    local groups = {}
    local maps = GetChallengeMaps()
    local seasonFilter = bit_bor(Enum.LFGListFilter.CurrentSeason, Enum.LFGListFilter.PvE)

    for _, groupID in ipairs(GetAvailableActivityGroups(DUNGEON_CATEGORY, seasonFilter) or {}) do
        local name = GetActivityGroupInfo(groupID)
        if name then
            local map = maps[name]
            groups[#groups + 1] = {
                id = groupID,
                name = name,
                short = Abbreviate(name),
                icon = map and map.icon,
                mapID = map and map.mapID,
                timeLimit = map and map.timeLimit,
            }
        end
    end

    tsort(groups, function(a, b)
        return a.name < b.name
    end)

    self.seasonDungeons = groups
    return groups
end

-- Weekly runs --

---@return number count, table levels
function GroupFinder:GetWeeklyRuns()
    local runs = GetRunHistory(false, true, true) or {}
    local levels = {}

    for _, run in ipairs(runs) do
        local level = NRSKNUI:SafeValue(run.level)
        if level then
            levels[#levels + 1] = level
        end
    end

    tsort(levels, function(a, b)
        return a > b
    end)

    return #runs, levels
end

-- Events --

function GroupFinder:CHALLENGE_MODE_MAPS_UPDATE()
    self.seasonDungeons = nil
    if self.panel then self.panel.laidOut = nil end
    self:RefreshPanel()
end

function GroupFinder:LFG_LIST_SEARCH_RESULT_UPDATED()
    if self.resortPending then return end
    if self.db.SortBy == 'default' and not HasActiveFilters() then return end

    self.resortPending = true
    C_Timer.After(RESORT_DELAY, function()
        self.resortPending = nil
        self:RefreshResults()
    end)
end

-- Lifecycle --

function GroupFinder:InstallHooks()
    if self.hooksInstalled then return end
    self.hooksInstalled = true

    hooksecurefunc('LFGListSearchEntry_Update', UpdateRow)
    hooksecurefunc('LFGListApplicationViewer_UpdateApplicantMember', UpdateApplicantRoles)
    hooksecurefunc('LFGListApplicationViewer_UpdateGroupData', UpdateEntryRoles)
    hooksecurefunc('LFGListSearchPanel_UpdateResultList', OnUpdateResultList)
    hooksecurefunc('LFGListSearchPanel_SetCategory', function() self:UpdatePanelVisibility() end)

    local searchPanel = _G.LFGListFrame and _G.LFGListFrame.SearchPanel
    if searchPanel then
        searchPanel:HookScript('OnShow', function() self:UpdatePanelVisibility() end)
        searchPanel:HookScript('OnHide', function() self:UpdatePanelVisibility() end)
    end

    local pve = _G.PVEFrame
    if pve then
        pve:HookScript('OnShow', function() self:UpdatePanelVisibility() end)
        pve:HookScript('OnHide', function() if self.panel then self.panel:Hide() end end)
    end
end

---Filters are session state, a stale dungeon selection must not silently hide every group at login.
function GroupFinder:ResetFilters()
    self.filters = {
        dungeons = {},
        needsRole = false,
        hasTank = false,
        hasHealer = false,
        hasEither = false,
        noMySpec = false,
        notDeclined = false,
    }
end

function GroupFinder:ApplySettings()
    if not self.db.Enabled then return end

    self:CreatePanel()
    self:ApplyPanelWidth()
    self:UpdatePanelVisibility()
    self:RefreshResults()
end

function GroupFinder:OnEnable()
    self:UpdateDB()
    self:ResetFilters()
    self:RefreshFriendResults()
    self:InstallHooks()

    self:RegisterEvent('LFG_LIST_SEARCH_RESULT_UPDATED')
    self:RegisterEvent('SOCIAL_QUEUE_UPDATE', 'RefreshFriendResults')
    self:RegisterEvent('CHALLENGE_MODE_COMPLETED', 'RefreshPanel')
    self:RegisterEvent('CHALLENGE_MODE_MAPS_UPDATE')

    -- The dungeon art and the weekly run history both arrive with this request.
    RequestMapInfo()

    self:ApplySettings()
end

function GroupFinder:OnDisable()
    self.resortPending = nil
    if self.panel then
        self.panel:Hide()
    end
end
