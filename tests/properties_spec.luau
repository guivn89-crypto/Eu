local obj = { Speed = 16, Flag = false }
assert(Actions.setProperty(obj, "Speed", 32))
assert(obj.Speed == 32)
Actions.restoreProperty(obj, "Speed")
assert(obj.Speed == 16)
assert(Actions.setProperty(obj, "Speed", 32))
obj.Speed = 21 -- outra lógica mudou o valor depois
Actions.restoreProperty(obj, "Speed")
assert(obj.Speed == 21)
assert(Actions.setProperty(obj, "Flag", true))
Actions.restoreProperty(obj, "Flag")
assert(obj.Flag == false)
local locked = setmetatable({}, {
    __index = function() return 4 end,
    __newindex = function() error("somente leitura") end,
})
assert(not Actions.setProperty(locked, "Speed", 5))
Actions.restoreProperty(locked, "Speed")
