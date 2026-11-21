local freed, protected = {}, {}
protectgui = function(gui)
    assert(gui.Parent == nil, "proteção deve ocorrer antes de Parent")
    protected[#protected + 1] = gui
end
unprotectgui = function(gui) freed[#freed + 1] = gui end
local parent = {}
local first = create("ScreenGui", {Name = "test"}, parent)
assert(first.Parent == parent and #protected == 1 and Library.GuiProtection.succeeded == 1)
assert(Library:ProtectGui(first) and #protected == 1) -- não protege duas vezes
first.Destroying.fire()
assert(#freed == 1 and freed[1] == first)
first.Destroying.fire(); assert(#freed == 1)
local second = create("BillboardGui", {}, parent)
local ordinary = create("Frame", {}, parent)
assert(#protected == 2 and ordinary.Parent == parent)
Library:UnprotectAllGuis()
assert(#freed == 2 and freed[2] == second)
protectgui = nil; unprotectgui = nil
local before = #warnings
local unprotected = create("ScreenGui", {}, parent)
create("ScreenGui", {}, parent)
assert(unprotected.Parent == parent and Library.GuiProtection.unavailable == 2 and #warnings == before + 1)
local fallbackCount = 0
syn = { protect_gui = function(gui) fallbackCount += 1 end, unprotect_gui = function(gui) freed[#freed + 1] = gui end }
local third = create("ScreenGui", {}, parent)
assert(fallbackCount == 1 and Library.GuiProtection.succeeded == 3)
third.Destroying.fire(); assert(#freed == 3)
protectgui = function() error("API indisponível") end
before = #warnings
create("ScreenGui", {}, parent); create("ScreenGui", {}, parent)
assert(Library.GuiProtection.failed == 2 and #warnings == before + 1)
protectgui = function() return false end
create("ScreenGui", {}, parent)
assert(Library.GuiProtection.failed == 3)
print("GUI API integration OK")
