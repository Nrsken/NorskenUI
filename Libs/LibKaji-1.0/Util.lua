--[[
# Util

* Helpers for the library and its consumers.
* Exposes a safe call wrapper, a pixel-perfect scaling helper and a media resolver.

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
local InstanceMixin = lib.InstanceMixin
local LSM = LibStub("LibSharedMedia-3.0", true)

local geterrorhandler = geterrorhandler
local xpcall = xpcall

---Runs a consumer-supplied callback through the game's error handler so a broken handler surfaces an error but never breaks library layout.
---@param func? function
---@return ... results of func
function lib.safecall(func, ...)
    if not func then return end
    return xpcall(func, function(err) return geterrorhandler()(err) end, ...)
end

---Returns the best pixel size for the current resolution. See Pixel.lua for the math.
---@return number
function InstanceMixin:GetBestPixelSize()
    return lib.Pixel.GetBestPixelSize()
end

---Resolves an LSM media name to its path; a real path passes through unchanged.
---@param mediaType string 'font'|'sound'|'statusbar'|'border'|'background'
---@param name? string
---@return string? path
function InstanceMixin:ResolveMedia(mediaType, name)
    if not name or name == "" then return name end
    if LSM and LSM:IsValid(mediaType, name) then
        return LSM:Fetch(mediaType, name, true) -- noDefault: nil when unregistered
    end
    return name
end

---Registers a widget with the host's search index, if the host injected one.
---The library has no search UI of its own, this is a no-op without the hook.
---@param widget Frame
---@param label? string
function InstanceMixin:RegisterSearchableWidget(widget, label)
    local register = self.services.registerSearchable
    if register then register(widget, label) end
end
