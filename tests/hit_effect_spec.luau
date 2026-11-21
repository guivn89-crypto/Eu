local target = {Parent = true}
showHitEffect(target)
assert(created == 1 and pending[1].delay == 0.3)
assert(Actions.hitFxObjects[objects[1]])
assert(objects[1].FillTransparency == 0.4 and objects[1].Parent == target)
pending[1].callback()
assert(objects[1].destroyed and not Actions.hitFxObjects[objects[1]])
for i = 1, 10 do showHitEffect(target) end
assert(created == 9) -- limite de oito objetos simultâneos
Actions.clearHitEffects()
for i = 2, 9 do assert(objects[i].destroyed) end
Library.Panic = true
showHitEffect(target)
assert(created == 9)
Library.Panic = false
COMBAT.hitFx = false
showHitEffect(target)
assert(created == 9)
print("hit effects cleanup and cap OK")
