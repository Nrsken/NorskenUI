---@class NRSKNUI
local NRSKNUI = select(2, ...)

local pairs = pairs
local type = type
local getmetatable = getmetatable

-- Generic metatable-injection utility.

---@param object table A representative instance whose type metatable receives the methods
---@param methods table<string, function> name -> function pairs to inject
function NRSKNUI:InjectAPI(object, methods)
    if not object or type(methods) ~= 'table' then return end

    local mt = getmetatable(object)
    local index = mt and mt.__index
    if type(index) ~= 'table' then return end

    for name, fn in pairs(methods) do
        if index[name] == nil then
            index[name] = fn
        end
    end
end