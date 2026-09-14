---@meta

---@class HidingBarAddon : Frame, table
---@field addToIgnoreFrameList fun(self: HidingBarAddon, frame: Frame|string)

---@class BugSack : Frame, table
---@field UpdateDisplay fun(self: BugSack)
---@field GetErrors fun(self: BugSack, sessionId: number): table

---@class BugGrabber : Frame, table
---@field GetSessionId fun(self: BugGrabber): number

---One of Details' windows. Instances take the Details table as their metatable.
---@class DetailsInstance : table
---@field row_info table
---@field titlebar_height number
---@field baseframe Frame
---@field GetId fun(self: DetailsInstance): number
---@field IsShown fun(self: DetailsInstance): boolean

---@class DetailsAddon : table
---@field GetInstance fun(self: DetailsAddon, id: number): DetailsInstance?
---@field RegisterEvent fun(self: DetailsAddon, object: table, event: string, func: fun(event: string, instance: DetailsInstance?))

---RaiderIO's guild best panel, parented to ChallengesFrame on the Mythic+ tab.
---@class RaiderIOGuildWeeklyFrame : Frame
---@field Title FontString
---@field SubTitle FontString
---@field SwitchGuildBest RaiderIOGuildWeeklyCheck
---@field GuildBestNoRun RaiderIOGuildWeeklyNoRun
---@field GuildBests RaiderIOGuildWeeklyRun[] Twenty rows, built with the panel and never rebuilt
---@field maxVisible number How many of those rows a refresh is allowed to fill
---@field SetUp fun(self: RaiderIOGuildWeeklyFrame, guildName: string?)

---UICheckButtonTemplate, whose label region RaiderIO reaches through as `text`.
---@class RaiderIOGuildWeeklyCheck : CheckButton
---@field text FontString

---@class RaiderIOGuildWeeklyNoRun : Frame
---@field Text FontString

---CharacterName holds the dungeon name, not a character's.
---@class RaiderIOGuildWeeklyRun : Frame
---@field CharacterName FontString
---@field Level FontString
---@field runInfo RaiderIOGuildWeeklyRunInfo?

---@class RaiderIOGuildWeeklyRunInfo
---@field clear_time string?
---@field upgrades number

---RaiderIO's talent builds window, a ButtonFrameTemplate the addon builds the first time it opens.
---@class RaiderIOTalentBuildsFrame : Frame
---@field TitleContainer RaiderIOTalentBuildsTitle
---@field ResizeButton Button
---@field InstanceMenu WowStyle1DropdownTemplate
---@field DifficultyMenu WowStyle1DropdownTemplate
---@field WeaponMenu WowStyle1DropdownTemplate
---@field SpeedMenu WowStyle1DropdownTemplate
---@field ScrollBox ScrollBox
---@field ScrollBar NUIScrollBar
---@field EmptyContainer RaiderIOTalentBuildsEmpty

---@class RaiderIOTalentBuildsTitle : Frame
---@field TitleText FontString

---The no data callout, a tutorial nine slice whose message is anchored inside its corner pieces.
---@class RaiderIOTalentBuildsEmpty : Frame
---@field Image Texture
---@field Text FontString

---Row of the builds list, pooled by the frame's ScrollBox. RaiderIO mixes BackdropTemplateMixin into
---a row and hangs its own focus setters off it the first time the list initializes that row.
---@class RaiderIOTalentBuildRow : Button
---@field isInit boolean? RaiderIO's own flag, set once the row has been built
---@field ActionMenuToggle RaiderIOTalentBuildRowToggle?
---@field SetBackdropColor fun(self: RaiderIOTalentBuildRow, r: number, g: number, b: number, a: number?)
---@field SetBackdropBorderColor fun(self: RaiderIOTalentBuildRow, r: number, g: number, b: number, a: number?)
---@field SetBackdropFocus fun(self: RaiderIOTalentBuildRow)
---@field ClearBackdropFocus fun(self: RaiderIOTalentBuildRow)
---@field NUIBackdrop Frame & PublicBackdropMixin
---@field NUISkinned boolean?

---SquareIconButtonTemplate, RaiderIO reuses its atlas icon as the button's own highlight.
---@class RaiderIOTalentBuildRowToggle : Button
---@field Icon Texture?

---RaiderIO's public API table. Reads go through a metatable, so a key is nil until RaiderIO loads.
---@class RaiderIOAPI
---@field GetScoreColor fun(score: number, isPreviousSeason?: boolean): number, number, number
---@field GetScoreForKeystone fun(level: number): number?, number?

---@class _G
---@field RaiderIO RaiderIOAPI?
---@field HidingBarAddon HidingBarAddon
---@field BugSack BugSack
---@field BugGrabber BugGrabber
---@field Details DetailsAddon
---@field NorskenUI NRSKNUI
---@field NorskenUF NorskenUF
---@field RaiderIO_GuildWeeklyFrame RaiderIOGuildWeeklyFrame
---@field RaiderIO_TalentBuildsFrame RaiderIOTalentBuildsFrame
---@field RaiderIO_TalentBuildsTalentFrameShortcut Button