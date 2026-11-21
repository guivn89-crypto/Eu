applyHotbar(true)
assert(hotbar.gui.Enabled and #hotbar.tools == 2)
assert(hotbar.slots[1].Text == "1  Axe" and hotbar.slots[2].Text == "2  Sword")
fire(hotbar.slots[1].MouseButton1Click)
assert(equipped == axe)
axe.Parent = character
fire(character.ChildAdded)
fire(hotbar.slots[1].MouseButton1Click)
assert(unequipped)
Library.Panic = true
applyHotbar(true)
assert(not hotbar.gui.Enabled)
equipped = nil; axe.Parent = backpack
fire(hotbar.slots[1].MouseButton1Click)
assert(equipped == nil)
Library.Panic = false
applyHotbar(false)
assert(not hotbar.gui.Enabled)
applyHotbar(true)
assert(hotbar.gui.Enabled)
Actions.alive = false
cleanup()
assert(hotbar.gui.destroyed)
print("hotbar OK")
