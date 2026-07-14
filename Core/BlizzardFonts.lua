---@class NRSKNUI
local NRSKNUI = select(2, ...)

local _G = _G
local pairs = pairs
local tostring = tostring
local max = math.max
local CreateFrame = CreateFrame

local vertexEnum = Enum and Enum.FontStringScaleAnimationMode and Enum.FontStringScaleAnimationMode.Vertex
local fontSizeEnum = Enum and Enum.FontStringScaleAnimationMode and Enum.FontStringScaleAnimationMode.FontSize

local originalData = {}

-- Fonts that are pinned to their original size and cannot be resized by the Families/Overrides system.
local pinnedSizes = {
    GameFontNormalHuge = true, -- RaidWarning animates GameFontNormalHuge via SetTextHeight and we can't access RAID_NOTICE_MIN/MAX_HEIGHT.
}

-- Special fonts that can be styled independently of the master blizzardFonts settings.
NRSKNUI.SpecialFonts = {
    { key = 'ZoneText',     label = 'Zone Text',     objects = { 'ZoneTextFont', 'WorldMapTextFont' } },
    { key = 'SubZoneText',  label = 'Sub Zone Text', objects = { 'SubZoneTextFont' } },
    { key = 'PvPZoneText',  label = 'PvP Zone Text', objects = { 'PVPArenaTextString', 'PVPInfoTextString' } },
    { key = 'ErrorText',    label = 'Error Text',    objects = { 'ErrorFont' } },
    { key = 'ActionStatus', label = 'Action Status', objects = { 'ActionStatus.Text' } },
    { key = 'ChatBubbles',  label = 'Chat Bubbles',  objects = { 'ChatBubbleFont' } },
    {
        key = 'Nameplates',
        label = 'Nameplates',
        objects = {
            'SystemFont_NamePlate',
            'SystemFont_NamePlateFixed',
            'SystemFont_LargeNamePlate',
            'SystemFont_LargeNamePlateFixed',
            'SystemFont_NamePlateCastBar',
        },
    },
    { key = 'CombatText', label = 'Combat Text',    objects = { 'CombatTextFont' }, lodAddon = 'Blizzard_CombatText' },
    { key = 'CombatFont', label = 'Combat Font',    globalVar = 'DAMAGE_TEXT_FONT', relog = true },
    { key = 'NameFont',   label = 'Unit Name Font', globalVar = 'UNIT_NAME_FONT',   relog = true },
}

---Assign a family name to a font size, we use this to categorize fonts and apply consistent sizing.
---@param size number the font size to categorize
---@return string family the family name for this size
local function FamilyOf(size)
    if size <= 9 then
        return 'tiny'
    elseif size <= 11 then
        return 'small'
    elseif size <= 14 then
        return 'medium'
    elseif size <= 18 then
        return 'large'
    elseif size <= 24 then
        return 'huge'
    else
        return 'display'
    end
end

---Store the original font data for a Blizzard font object so we can restore it later.
---@param obj table font object to capture
---@return table|nil the captured font data, or nil if the object is unrealized or tainted
local function StoreOriginalFontData(obj)
    local existing = originalData[obj]
    if existing then return existing end -- Already captured

    local path, size, flags = obj:GetFont()
    if not path or not size then return end             -- Font object not yet realized
    if not NRSKNUI:CanAccessValue(size) then return end -- Tainted by another addon, comparing it in FamilyOf would error

    -- Capture the native shadow too so hiding it stays fully reversible
    local sr, sg, sb, sa = obj:GetShadowColor()
    local sx, sy = obj:GetShadowOffset()

    existing = {
        path = path,
        size = size,
        flags = flags or '',
        family = FamilyOf(size),
        shadow = { sr, sg, sb, sa, sx, sy },
    }
    originalData[obj] = existing
    return existing
end

---Resolve the final font size, outline flags, slug, and shadow visibility for a font object.
---@param name string the font object name, used to look up overrides
---@param orig table the original font data captured for this object
---@param cfg table the blizzardFonts config table
---@param outlineMode boolean whether to apply the configured outline (false keeps the object outline-free)
---@param noSlug boolean whether to hard-block slug for this object, for fonts that read poorly with it
---@param spec table? Specials db entry, FontFace/Size/Outline/HideShadow override the globals
---@return number size the resolved font size to apply
---@return string flags the resolved outline flags to apply
---@return boolean slug whether to force slug on
---@return boolean hideShadow whether to hide the shadow on this font object
local function ResolveStyle(name, orig, cfg, outlineMode, noSlug, spec)
    local override = cfg.Overrides and cfg.Overrides[name]

    -- Resolve size
    local size
    if spec and spec.Size then
        size = spec.Size
    elseif override and override.size then
        size = override.size
    elseif name and pinnedSizes[name] then
        size = orig.size
    else
        local offset = cfg.Families and cfg.Families[orig.family]
        size = max(orig.size + (offset or 0), 1) -- Clamp so that size wont be <= 0
    end

    -- Resolve outline and slug
    local outlineValue, slugPref
    if spec and spec.Outline then
        outlineValue, slugPref = spec.Outline, false
    else
        outlineValue = outlineMode and ((override and override.outline) or cfg.Outline) or nil
        if noSlug then
            slugPref = false
        elseif override and override.slug ~= nil then -- explicit true forces on, false forces off
            slugPref = override.slug
        else
            slugPref = cfg.Slug
        end
    end
    local flags, slug = NRSKNUI:ResolveFlags(outlineValue, slugPref)

    -- Resolve shadow visibility
    local hideShadow
    if spec and spec.HideShadow ~= nil then
        hideShadow = spec.HideShadow
    elseif override and override.hideShadow ~= nil then -- explicit true forces hidden, false forces the native shadow back
        hideShadow = override.hideShadow
    else
        hideShadow = cfg.HideShadow
    end

    return size, flags, slug, hideShadow
end

---Put an object back exactly the way we found it, including scale-animation mode.
---@param obj table font object to restore
local function RestoreOriginal(obj)
    local orig = originalData[obj]
    if not orig then return end

    obj:SetFont(orig.path, orig.size, orig.flags)

    local s = orig.shadow
    obj:SetShadowColor(s[1], s[2], s[3], s[4])
    obj:SetShadowOffset(s[5], s[6])

    -- Slug fonts were switched to vertex scaling, put them back to the default.
    if obj.SetScaleAnimationMode and fontSizeEnum then
        obj:SetScaleAnimationMode(fontSizeEnum)
    end
end

---Set the font for a Blizzard font object, applying the configured outline, slug, and shadow settings.
---@param obj table font object to style
---@param outlineMode boolean? apply the configured outline (false keeps the object outline-free)
---@param noSlug boolean? hard-block slug for this object, for fonts that read poorly with it
---@param spec table? Specials db entry, FontFace/Size/Outline/HideShadow override the globals
function NRSKNUI:SetFont(obj, outlineMode, noSlug, spec)
    if not obj then return end
    local font = self.db.profile.globalMedia.profileFont.FontFace
    local blizDB = self.db.profile.globalMedia.blizzardFonts

    local orig = StoreOriginalFontData(obj)
    if not orig then return end -- unrealized or tainted, skip so we never index a nil capture
    local path = self:ResolveFontPath(spec and spec.FontFace or font)

    local name = obj:GetName()
    local size, flags, slug, hideShadow = ResolveStyle(name, orig, blizDB, outlineMode, noSlug, spec)

    -- Slug needs vertex-based scale animation, everything else font-size based.
    if obj.SetScaleAnimationMode and vertexEnum then
        obj:SetScaleAnimationMode(slug and vertexEnum or fontSizeEnum)
    end

    obj:SetFont(path, size, flags)

    -- Hide the shadow or restore the captured native one so toggling off reverts without a reload.
    if hideShadow then
        obj:SetShadowColor(0, 0, 0, 0)
        obj:SetShadowOffset(0, 0)
    else
        local s = orig.shadow
        obj:SetShadowColor(s[1], s[2], s[3], s[4])
        obj:SetShadowOffset(s[5], s[6])
    end
end

local lastSignature
---@param force boolean? force a full re-apply even if nothing changed.
function NRSKNUI:ApplyBlizzardFonts(force)
    local db = self.db.profile.globalMedia

    if not db.blizzardFonts.Enabled then
        if force or lastSignature ~= 'disabled' then
            lastSignature = 'disabled'
            for obj in pairs(originalData) do
                RestoreOriginal(obj)
            end
        end
        self:ApplySpecialFonts()
        return
    end

    -- Skip the full pass when nothing that shapes it changed.
    local cfg = db.blizzardFonts
    local sig = self:ResolveFontPath(db.profileFont.FontFace) .. '|' .. tostring(cfg.Outline) .. '|' .. tostring(cfg.Slug) .. '|' .. tostring(cfg.HideShadow)
    if not force and sig == lastSignature then return end
    lastSignature = sig

    -- Number Fonts --
    self:SetFont(_G.Number12Font, true)             -- Crafting order duration dropdown text
    self:SetFont(_G.Number12Font_o1, true)          -- Some number text?
    self:SetFont(_G.Number12FontOutline, true)      -- 'Midnight Engineering 1/100' text
    self:SetFont(_G.Number13FontYellow, true)       -- Auctions list text
    self:SetFont(_G.Number13FontWhite, true)        -- Some auction house text
    self:SetFont(_G.Number14FontWhite, true)        -- Crafting order item name texts
    self:SetFont(_G.Number14FontGray, true)         -- Some auction house text
    self:SetFont(_G.Number15FontWhite, true)        -- Some auction house text
    self:SetFont(_G.NumberFontNormalSmall, true)    -- Calendar, EncounterJournal
    self:SetFont(_G.NumberFontNormal, true)         -- Stacks, timewarped badge e.g
    self:SetFont(_G.NumberFontNormalLarge, true)    -- Large number text
    self:SetFont(_G.NumberFontSmallWhiteLeft, true) -- Some journey text

    -- Game Fonts --
    self:SetFont(_G.Game10Font_o1, true)            -- Some number text?
    self:SetFont(_G.Game12Font, true)               -- Some quests text?
    self:SetFont(_G.Game13Font_o1, true)            -- Some quests text?
    self:SetFont(_G.Game13FontShadow, true)         -- PvP text when inspecting a player?
    self:SetFont(_G.Game15Font_Shadow, true)        -- Campaign quest log titles
    self:SetFont(_G.Game16Font, true)               -- Help text on the map?
    self:SetFont(_G.Game18Font, true)               -- Talent Lodout Ex / MissionUI Bonus Chance
    self:SetFont(_G.Game24Font, true)
    self:SetFont(_G.Game30Font, true)               -- Spec choice / Mission Level
    self:SetFont(_G.Game27Font, true)               -- Omnium Folio title text
    self:SetFont(_G.Game32Font_Shadow2, true, true) -- Looks bad with slug, too big.
    self:SetFont(_G.Game40Font, true, true)         -- New Season! text in lfg.
    self:SetFont(_G.Game40Font_Shadow2, true, true) -- Looks bad with slug, too big.
    self:SetFont(_G.Game48Font, true, true)
    self:SetFont(_G.Game60Font, true, true)         -- Looks bad with slug, too big.
    self:SetFont(_G.Game72Font, true, true)         -- 'What's new' frame big text, looks bad with slug, too big.

    -- Fancy Fonts --
    self:SetFont(_G.Fancy16Font, true)  -- Some artifact text maybe?
    self:SetFont(_G.Fancy24Font, true)  -- Artifact collection frame, weapon name
    self:SetFont(_G.Fancy27Font, false) -- Catchup experience text

    -- Game Fonts --
    self:SetFont(_G.GameFontNormalTiny, true)  -- 'Current CPU', 'Avarage CPU' etc text in the addons menu
    self:SetFont(_G.GameFontNormalTiny2, true) -- RaiderIO records text
    self:SetFont(_G.GameFontNormalMed1, true)  -- Guildfinder frame text / WoW Token Info
    self:SetFont(_G.GameFontNormalMed3, true)  -- 'Ongoing Events' text on the map
    self:SetFont(_G.GameFontNormalMed2, true)  -- Talent tree spec page role texts.
    self:SetFont(_G.GameFontNormalHuge, true)
    self:SetFont(_G.GameFontNormal, true)
    self:SetFont(_G.GameFontNormalSmall, true)          -- Tab labels, etc.
    self:SetFont(_G.GameFontNormalHuge2, true)          -- Mythic weekly dung text
    self:SetFont(_G.GameFontNormalHuge3, true)          -- Some text in the store frame, probably for Trader’s Tender?
    self:SetFont(_G.GameFontNormalHuge4, true)          -- 'Searching...' text in the auction house frame
    self:SetFont(_G.GameFontNormalLarge2, true)         -- Talent tree spec page active spec.
    self:SetFont(_G.GameFontNormal_NoShadow, true)      -- Some 'New' text for collections
    self:SetFont(_G.GameFontHighlightSmall2, true)      -- Profession requires X materials text
    self:SetFont(_G.GameFontHighlightMedium, true)      -- Achievement category names, Questlog quest titles, etc.
    self:SetFont(_G.GameFontHighlightHuge2, true, true) -- Talent tree node names / Talent point texts, looks bad with slug, too big.
    self:SetFont(_G.GameFontHighlightMed2, false)
    self:SetFont(_G.GameFontBlack, false)               -- Dungeon journal text
    self:SetFont(_G.GameFontWhite, true)                -- Toy box 'Page 1 / 56' text
    self:SetFont(_G.GameFontWhiteSmall, true)           -- Spellbook spell labels

    -- Misc Fonts --
    self:SetFont(_G.SubSpellFont, false)         -- Spellbook Sub Names / Profession description texts
    self:SetFont(_G.GameTooltipHeader, false)    -- Tooltip header / Suggested quest description text
    self:SetFont(_G.PriceFont, true)
    self:SetFont(_G.TextStatusBarText, true)     -- Some '0/0' text for bars
    self:SetFont(_G.InvoiceTextFontNormal, true) -- Invoice frame text
    self:SetFont(_G.MailFont_Large, false)       -- Mail frame subject text
    self:SetFont(_G.DestinyFontHuge, false)      -- Garrison Mission Report / Suggested content text
    self:SetFont(_G.SplashHeaderFont, true)      -- Splash screen header text

    -- System Fonts --
    self:SetFont(_G.System15Font, true)
    self:SetFont(_G.SystemFont_Small2, true) -- Store frame text
    self:SetFont(_G.SystemFont_Med1, false)  -- Adventure guide description text
    self:SetFont(_G.SystemFont_Med2, false)  -- 'Bring your friends to Azeroth...' text
    self:SetFont(_G.SystemFont_Med3, false)  -- Adventure guide reward text
    self:SetFont(_G.SystemFont_Huge2, false) -- Spellbook spec text
    self:SetFont(_G.SystemFont_Huge1_Outline, true)
    self:SetFont(_G.SystemFont_Shadow_Huge2, true)
    self:SetFont(_G.SystemFont_Shadow_Large2, true)
    self:SetFont(_G.SystemFont_Shadow_Med2, true)           -- 'What's New' text in the collections frame
    self:SetFont(_G.SystemFont_Shadow_Med3, true)
    self:SetFont(_G.SystemFont_Shadow_Small, true)          -- 'Already Known' text in profession trainer frame
    self:SetFont(_G.SystemFont_Shadow_Small2, true)         -- Campaign: 0/3 Chapters text
    self:SetFont(_G.SystemFont16_Shadow_ThickOutline, true) -- Talent & Profession SpendText
    self:SetFont(_G.SystemFont22_Shadow_ThickOutline, true) -- Talent & Profession HeaderText
    self:SetFont(_G.SystemFont_Shadow_Large_Outline, false) -- Not sure.
    self:SetFont(_G.SystemFont_Shadow_Med1_Outline, true)
    self:SetFont(_G.SystemFont_Large, false)                -- Spellbook spell labels
    self:SetFont(_G.SystemFont_Shadow_Large, true)          -- Talent tree hero specialization names
    self:SetFont(_G.SystemFont_OutlineThick_Huge2, true)    -- Talent tree node names

    -- Achievement Fonts --
    self:SetFont(_G.AchievementPointsFontSmall, true)  -- Achievement points text
    self:SetFont(_G.AchievementDescriptionFont, false) -- Achievement description text
    self:SetFont(_G.AchievementCriteriaFont, false)    -- Achievement criteria text
    self:SetFont(_G.AchievementDateFont, true)         -- Achievement date text

    -- Quest Fonts, outline looks scuffed so skip --
    self:SetFont(_G.QuestMapRewardsFont, false)    -- Quest log rewards item names
    self:SetFont(_G.QuestTitleFont, false)         -- Quest log quest titles
    self:SetFont(_G.QuestFont, false)              -- Quest log quest objectives
    self:SetFont(_G.QuestFontNormalSmall, false)   -- Quest log quest objectives
    self:SetFont(_G.QuestFont_Super_Huge, false)   -- Quest log quest titles
    self:SetFont(_G.QuestFont_Large, false)        -- Quest log quest titles
    self:SetFont(_G.QuestFont_Shadow_Small, false) -- Quest log quest objectives
    self:SetFont(_G.QuestFont_Huge, false)         -- Quest log rewards title text
    self:SetFont(_G.QuestFont_Enormous, false)     -- Quest log quest titles

    -- Friendlist Fonts --
    self:SetFont(_G.FriendsFont_Small, true)                -- 'Tell your friends what you're doing' text
    self:SetFont(_G.FriendsFont_Normal, true)               -- 'Blizzard services are unavailable' text
    self:SetFont(_G.FriendsFont_Large, true)                -- 'Blizzard services are unavailable' text
    self:SetFont(_G.UserScaledFontGameDisableSmall, true)   -- 'Search Zones, Guilds, Classes, Races, Levels' text
    self:SetFont(_G.UserScaledFontGameNormalSmall, true)
    self:SetFont(_G.UserScaledFontGameHighlightSmall, true) -- 'Name' text
    self:SetFont(_G.UserScaledFontGameHighlight, true)      -- 'Zone' text
    self:SetFont(_G.FriendsFont_UserText, true)

    -- Blizzard Options Fonts --
    self:SetFont(_G.UserScaledFontHeader, true) -- 'Example' text
    self:SetFont(_G.UserScaledFontBody, true)   -- 'This is a preview of the text size...' text

    -- Chat Fonts --
    self:SetFont(_G.ChatFontNormal, true)

    -- Special Fonts --
    self:ApplySpecialFonts()
end

---Look up a global object by name, supporting dot notation for nested objects.
---@param name string the global object name to look up, e.g. 'ActionStatus.Text'
---@return table|nil the object, or nil if not found
local function LookupObject(name)
    local dot = name:find('.', 1, true)
    if dot then
        local parent = _G[name:sub(1, dot - 1)]
        return parent and parent[name:sub(dot + 1)]
    end
    return _G[name]
end

---Apply the global font variables for special fonts.
function NRSKNUI:ApplyGlobalFontVars()
    local media = self.db.profile.globalMedia
    local specials = media.blizzardFonts.Specials
    if not specials then return end

    for i = 1, #self.SpecialFonts do
        local entry = self.SpecialFonts[i]

        if entry.globalVar then
            local sdb = specials[entry.key]

            if sdb and sdb.Enabled then
                _G[entry.globalVar] = self:ResolveFontPath(sdb.FontFace or media.profileFont.FontFace)
            end
        end
    end
end

---Apply the Specials settings to the objects they control, skipping any that are not enabled.
function NRSKNUI:ApplySpecialFonts()
    local specials = self.db.profile.globalMedia.blizzardFonts.Specials
    if not specials then return end

    self:ApplyGlobalFontVars()

    for i = 1, #self.SpecialFonts do
        local entry = self.SpecialFonts[i]
        local sdb = specials[entry.key]

        if sdb and entry.objects then
            for j = 1, #entry.objects do
                local obj = LookupObject(entry.objects[j])

                if obj then
                    if sdb.Enabled then
                        self:SetFont(obj, true, nil, sdb)
                    else
                        RestoreOriginal(obj)
                    end
                end
            end
        end
    end
end

do
    -- CombatTextFont only exists once the LoD Blizzard_CombatText addon loads.
    local watcher = CreateFrame('Frame')
    watcher:RegisterEvent('ADDON_LOADED')
    watcher:SetScript('OnEvent', function(frame, _, addon)
        if addon ~= 'Blizzard_CombatText' then return end
        frame:UnregisterAllEvents()
        if NRSKNUI.db then
            NRSKNUI:ApplySpecialFonts()
        end
    end)
end
