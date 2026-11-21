local hidden, core, player = {}, {}, {}
local refused, attempts = {}, {}
local current, destroyed = nil, false
local gui = setmetatable({}, {
    __index = function(_, key)
        if key == "Parent" then return current end
        if key == "Destroy" then return function() destroyed = true end end
    end,
    __newindex = function(_, key, value)
        assert(key == "Parent")
        attempts[#attempts + 1] = value
        if refused[value] then error("permissão negada") end
        current = value
    end,
})
local calls = 0
gethui = function() calls += 1; return hidden end
coreValue = core; playerValue = player
assert(Library:ParentGui(gui) == hidden and Library.GuiProtection.lastParent == "gethui")
refused[hidden] = true; current = nil
assert(Library:ParentGui(gui) == core and Library.GuiProtection.lastParent == "CoreGui")
refused[core] = true; current = nil
assert(Library:ParentGui(gui) == player and Library.GuiProtection.lastParent == "PlayerGui")
assert(attempts[#attempts] == player)
gethui = function() error("erro do executor") end
current = nil
assert(Library:ParentGui(gui) == player)
gethui = function() return core end
attempts = {}; current = nil
assert(Library:ParentGui(gui) == player and #attempts == 2) -- core duplicado não é tentado duas vezes
refused[player] = true; current = nil
assert(not pcall(function() Library:ParentGui(gui) end))
createdGui = gui
assert(not pcall(function() Library:CreateRootGui("ScreenGui", {}) end))
assert(destroyed and unprotected == gui)
print("GUI parent fallbacks OK")
