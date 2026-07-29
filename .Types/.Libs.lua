---@meta



---@class NRSKNUI.AceTimer
---
---Schedule a timer to call the given callback after `delay` seconds. Any extra arguments are passed to the callback.
---@field ScheduleTimer fun(self: NRSKNUI.AceTimer, callback: string|fun(), delay: number, ...: any): table
---
---Schedule a repeating timer to call the given callback every `delay` seconds. Any extra arguments are passed to the callback.
---@field ScheduleRepeatingTimer fun(self: NRSKNUI.AceTimer, callback: string|fun(), delay: number, ...: any): table
---
---Cancel a previously scheduled timer. Returns true if the timer was successfully canceled, false if it was not found. If `silent` is true, no error is thrown if the timer is not found.
---@field CancelTimer fun(self: NRSKNUI.AceTimer, id: table, silent?: boolean): boolean

---@class NRSKNUI.AceHook
---
---Hooks a method on an object, replacing it with a new function. The original method can be called from the new function using `self.hooks[obj][method]`.
---@field Hook fun(self: NRSKNUI.AceHook, obj: any, method?: any, handler?: any, secure?: boolean)
---
---Rawly hooks a method on an object, replacing it with a new function. The original method can be called from the new function using `self.hooks[obj][method]`.
---@field RawHook fun(self: NRSKNUI.AceHook, obj: any, method?: any, handler?: any, secure?: boolean)
---
---Securely hooks a method on an object, replacing it with a new function. The original method can be called from the new function using `self.hooks[obj][method]`.
---@field SecureHook fun(self: NRSKNUI.AceHook, obj: any, method?: any, handler?: any)
---
---Rawly hooks a script on a frame, replacing it with a new function. The original script can be called from the new function using `self.hooks[frame][script]`.
---@field RawHookScript fun(self: NRSKNUI.AceHook, frame: Frame, script: string, handler?: any)
---
---Securely hooks a script on a frame, replacing it with a new function. The original script can be called from the new function using `self.hooks[frame][script]`.
---@field SecureHookScript fun(self: NRSKNUI.AceHook, frame: Frame, script: string, handler?: any)
---
---Hooks a script on a frame, replacing it with a new function. The original script can be called from the new function using `self.hooks[frame][script]`.
---@field HookScript fun(self: NRSKNUI.AceHook, frame: Frame, script: string, handler?: any)
---
---Unhooks a previously hooked method or script, restoring the original function.
---@field Unhook fun(self: NRSKNUI.AceHook, obj: any, method?: string)
---
---Unhooks all previously hooked methods and scripts, restoring the original functions.
---@field UnhookAll fun(self: NRSKNUI.AceHook)
---
---IsHooked checks if a method or script is currently hooked.
---@field IsHooked fun(self: NRSKNUI.AceHook, obj: any, method?: string): boolean

-- LibCustomGlow-1.0 --

---@alias NRSKNUI.GlowColor number[]|{ GetRGBA: fun(self: table): number, number, number, number }

---@class NRSKNUI.LibCustomGlowProcOptions
---@field frameLevel? integer
---@field color? NRSKNUI.GlowColor
---@field startAnim? boolean
---@field xOffset? number
---@field yOffset? number
---@field duration? number
---@field key? string

---@class LibCustomGlow-1.0
---@field glowList string[]
---@field startList table<string, fun(frame: Frame, ...: any)>
---@field stopList table<string, fun(frame: Frame, ...: any)>
---@field GlowTexPool table
---@field GlowFramePool table
---@field ButtonGlowPool table
---@field ProcGlowPool table
---@field RegisterTextures fun(texture: string, id: string)
---@field PixelGlow_Start fun(frame: Frame, color?: NRSKNUI.GlowColor, N?: integer, frequency?: number, length?: number, th?: number, xOffset?: number, yOffset?: number, border?: boolean, key?: string, frameLevel?: integer)
---@field PixelGlow_Stop fun(frame: Frame, key?: string): boolean|nil
---@field AutoCastGlow_Start fun(frame: Frame, color?: NRSKNUI.GlowColor, N?: integer, frequency?: number, scale?: number, xOffset?: number, yOffset?: number, key?: string, frameLevel?: integer)
---@field AutoCastGlow_Stop fun(frame: Frame, key?: string): boolean|nil
---@field ButtonGlow_Start fun(frame: Frame, color?: NRSKNUI.GlowColor, frequency?: number, frameLevel?: integer)
---@field ButtonGlow_Stop fun(frame: Frame)
---@field ProcGlow_Start fun(frame: Frame, options?: NRSKNUI.LibCustomGlowProcOptions)
---@field ProcGlow_Stop fun(frame: Frame, key?: string)

-- LibSpecialization --

---@alias LibSpecializationRole "TANK"|"HEALER"|"DAMAGER"
---@alias LibSpecializationPosition "MELEE"|"RANGED"
---@alias LibSpecializationCallback fun(specId: integer, role: LibSpecializationRole, position: LibSpecializationPosition, playerName: string, talents: string|nil)

---@class LibSpecialization
---@field callbackMapGroup table<table, LibSpecializationCallback>
---@field callbackMapGuild table<table, LibSpecializationCallback>
---@field callbackMapPlayerSpecChange table<table, fun()>
---@field frame Frame
---@field RegisterGroup fun(addon: table, callback: LibSpecializationCallback)
---@field UnregisterGroup fun(addon: table)
---@field RegisterGuild fun(addon: table, callback: LibSpecializationCallback)
---@field UnregisterGuild fun(addon: table)
---@field RegisterPlayerSpecChange fun(addon: table, callback: fun())
---@field UnregisterPlayerSpecChange fun(addon: table)
---@field MySpecialization fun(): integer|nil, LibSpecializationRole|nil, LibSpecializationPosition|nil, string|nil
---@field RequestGroupSpecialization fun()
---@field RequestGuildSpecialization fun()

-- LibRangeCheck-3.0 --

---@alias LibRangeCheckChecker fun(unit: string): boolean|nil
---@alias LibRangeCheckFallbackChecker fun(unit: string): boolean|nil
---@alias LibRangeCheckCheckerIterator fun(): number, LibRangeCheckChecker

---@class LibRangeCheck-3.0
---@field CHECKERS_CHANGED string
---@field MeleeRange number
---@field RegisterCallback fun(target: table, eventName: string, callback: function|string)
---@field UnregisterCallback fun(target: table, eventName: string)
---@field UnregisterAllCallbacks fun(target: table)
---@field findSpellIndex fun(self: LibRangeCheck-3.0, spell: string|number): integer|nil
---@field getRangeAsString fun(self: LibRangeCheck-3.0, unit: string, checkVisible?: boolean, showOutOfRange?: boolean): string|nil
---@field GetFriendCheckers fun(self: LibRangeCheck-3.0, inCombat?: boolean): LibRangeCheckCheckerIterator
---@field GetFriendCheckersNoItems fun(self: LibRangeCheck-3.0, inCombat?: boolean): LibRangeCheckCheckerIterator
---@field GetHarmCheckers fun(self: LibRangeCheck-3.0, inCombat?: boolean): LibRangeCheckCheckerIterator
---@field GetHarmCheckersNoItems fun(self: LibRangeCheck-3.0, inCombat?: boolean): LibRangeCheckCheckerIterator
---@field GetMiscCheckers fun(self: LibRangeCheck-3.0, inCombat?: boolean): LibRangeCheckCheckerIterator
---@field GetFriendMinChecker fun(self: LibRangeCheck-3.0, range: number, inCombat?: boolean): LibRangeCheckChecker|nil, number|nil
---@field GetHarmMinChecker fun(self: LibRangeCheck-3.0, range: number, inCombat?: boolean): LibRangeCheckChecker|nil, number|nil
---@field GetMiscMinChecker fun(self: LibRangeCheck-3.0, range: number, inCombat?: boolean): LibRangeCheckChecker|nil, number|nil
---@field GetFriendMaxChecker fun(self: LibRangeCheck-3.0, range: number, inCombat?: boolean): LibRangeCheckChecker|nil, number|nil
---@field GetHarmMaxChecker fun(self: LibRangeCheck-3.0, range: number, inCombat?: boolean): LibRangeCheckChecker|nil, number|nil
---@field GetMiscMaxChecker fun(self: LibRangeCheck-3.0, range: number, inCombat?: boolean): LibRangeCheckChecker|nil, number|nil
---@field GetFriendChecker fun(self: LibRangeCheck-3.0, range: number, inCombat?: boolean): LibRangeCheckChecker|nil
---@field GetHarmChecker fun(self: LibRangeCheck-3.0, range: number, inCombat?: boolean): LibRangeCheckChecker|nil
---@field GetMiscChecker fun(self: LibRangeCheck-3.0, range: number, inCombat?: boolean): LibRangeCheckChecker|nil
---@field GetSmartMinChecker fun(self: LibRangeCheck-3.0, range: number, inCombat?: boolean): LibRangeCheckChecker
---@field GetSmartMaxChecker fun(self: LibRangeCheck-3.0, range: number, inCombat?: boolean): LibRangeCheckChecker
---@field GetSmartChecker fun(self: LibRangeCheck-3.0, range: number, fallback?: LibRangeCheckFallbackChecker, inCombat?: boolean): LibRangeCheckChecker
---@field GetRange fun(self: LibRangeCheck-3.0, unit: string, checkVisible?: boolean, noItems?: boolean, maxCacheAge?: number): number|nil, number|nil
---@field getRange fun(self: LibRangeCheck-3.0, unit: string, checkVisible?: boolean, noItems?: boolean, maxCacheAge?: number): number|nil, number|nil
