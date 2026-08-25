---@meta

---@class BigWigs.Module
---@field name string
---@field moduleName string
---@field displayName string
---@field instanceId number|number[]
---@field journalId number?
---@field engageId number?
---@field toggleOptions (number|string|table)[] filled by SetupOptions at registration
---@field optionHeaders table?

---@class BigWigs.ColorsPlugin : BigWigs.Module
---@field GetColorTable fun(self: BigWigs.ColorsPlugin, hint: string, module?: BigWigs.Module|string, key?: number|string): number[]
---@field GetColor fun(self: BigWigs.ColorsPlugin, hint: string, module?: BigWigs.Module|string, key?: number|string): number, number, number, number

---@class BigWigs.Core
---@field GetPlugin fun(self: BigWigs.Core, name: string, silent?: boolean): BigWigs.Module?
---@field GetBossModule fun(self: BigWigs.Core, name: string, silent?: boolean): BigWigs.Module?
---@field IterateBossModules fun(self: BigWigs.Core): fun(t: table, k: any): any, BigWigs.Module
BigWigs = {}

-- currentSeason and zones are instanceId -> addon name; zones covers the whole expansion, not just the season.
---@class BigWigs.Expansion
---@field name string
---@field currentSeason table<number, string>
---@field zones table<number, string>

---@class BigWigs.Loader
---@field RegisterMessage fun(target: table, message: BigWigs.Message, handler?: string|function)
---@field UnregisterMessage fun(target: table, message: BigWigs.Message)
---@field SendMessage fun(target: table, message: string, ...: any)
---@field currentExpansion BigWigs.Expansion
---@field GetZoneMenus fun(self: BigWigs.Loader): table<number, true|BigWigs.Module[]>
---@field LoadZone fun(self: BigWigs.Loader, instanceId: number)
BigWigsLoader = {}

---@alias BigWigs.Message
---| "BigWigs_StartBar"
---| "BigWigs_Timer"
---| "BigWigs_TargetTimer"
---| "BigWigs_CastTimer"
---| "BigWigs_StartBreak"
---| "BigWigs_StartPull"
---| "BigWigs_StopBar"
---| "BigWigs_StopBars"
---| "BigWigs_PauseBar"
---| "BigWigs_ResumeBar"
---| "BigWigs_OnBossDisable"
---| "BigWigs_OnBossWipe"
---| "BigWigs_OnPluginDisable"

-- AceEvent payloads: the message name arrives as the first argument.

-- isBarEnabled is the user's BAR flag; the message fires either way. module/key are nil for BigWigsAPI addon bars.
---@alias BigWigs.OnTimer fun(event: "BigWigs_Timer", module: BigWigs.Module?, key: number|string|nil, time: number, maxTime: number?, text: string, count: number, icon: number|string, isCD: boolean, isBarEnabled: boolean)

---@alias BigWigs.OnTargetTimer fun(event: "BigWigs_TargetTimer", module: BigWigs.Module, key: number|string, time: number, maxTime: number?, text: string, count: number, icon: number|string, player: string, isBarEnabled: boolean)

-- rawText is text without the "Cast: " wrapper.
---@alias BigWigs.OnCastTimer fun(event: "BigWigs_CastTimer", module: BigWigs.Module, key: number|string, time: number, maxTime: number?, text: string, count: number, icon: number|string, rawText: string, isBarEnabled: boolean)

-- reboot means the break was restored after a reload rather than freshly started.
---@alias BigWigs.OnStartBreak fun(event: "BigWigs_StartBreak", plugin: BigWigs.Module, seconds: number, nick: string, isDBM: boolean?, reboot: boolean?, text: string, icon: number)

---@alias BigWigs.OnStartPull fun(event: "BigWigs_StartPull", plugin: BigWigs.Module, seconds: number, name: string, text: string, icon: number)

-- Timeline modules send (nil, nil, eventId) in place of (module, text); match eventId first.
---@alias BigWigs.OnBarState fun(event: "BigWigs_StopBar"|"BigWigs_PauseBar"|"BigWigs_ResumeBar", module: BigWigs.Module?, text: string?, eventId: number?)

-- StopBars fires on wipe, OnBossDisable on kill or disable but never on wipe.
---@alias BigWigs.OnModuleStop fun(event: "BigWigs_StopBars"|"BigWigs_OnBossDisable"|"BigWigs_OnBossWipe"|"BigWigs_OnPluginDisable", module: BigWigs.Module)

-- eventId is the timeline event ID, the only message that carries one.
---@alias BigWigs.OnStartBar fun(event: "BigWigs_StartBar", module: BigWigs.Module?, key: number|string|nil, text: string, time: number, icon: number|string, isApprox: boolean, maxTime: number?, eventId: number?, spellIndicators: any?)

---@class BigWigsTimers.Bar
---@field addon BigWigs.Module? the module that started it, so its own messages can clear it
---@field spellId string stringified so the pull/break sentinels compare against user input
---@field text string also the registry key
---@field duration number
---@field expirationTime number
---@field icon number|string
---@field count number parsed out of the "(N)" in the bar text by BigWigs
---@field isCooldown boolean true for :CDBar, an estimated duration
---@field isBarEnabled boolean the user's BAR flag, the messages fire either way
---@field timerType 'timer'|'cast'|'break'|'pull'
---@field bwBarColor number[]
---@field bwTextColor number[]
---@field bwBgColor number[]
---@field paused boolean?
---@field remaining number? frozen countdown while paused
---@field keepUntil number? a positive trigger offset holds the bar past its own expiry

---@class BigWigsTimers.SeasonInstance
---@field instanceId number
---@field name string
---@field type 'dungeon'|'raid'

---@class BigWigsTimers.BossEntry
---@field journalId number encounter journal ID, the identity a timer is filed under
---@field name string
---@field num number position in the encounter order

---@class BigWigsTimers.SpellEntry
---@field spellId number
---@field name string
---@field icon number
---@field bossName string
---@field bossNum number? nil for a trash or event module, which has no encounter number
---@field journalId number?

---@class BigWigsTimers.CountTest
---@field first number
---@field last number
---@field interval number

---@class BigWigsTimers.Counter
---@field tests BigWigsTimers.CountTest[]
---@field fast boolean[]