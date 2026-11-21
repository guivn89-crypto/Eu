local a, b = effect(true), effect(true)
objects = {a, b}
removeEffects(true)
removeEffects(false)
pending[1](); assert(a.Enabled and b.Enabled) -- varredura antiga cancelada
removeEffects(true); pending[2](); assert(not a.Enabled and not b.Enabled)
a.Enabled = true -- alteração posterior do jogo é preservada
removeEffects(false); assert(a.Enabled and b.Enabled)
removeEffects(true); Actions.alive = false; pending[3](); assert(a.Enabled and b.Enabled)
print("incremental effects scan OK")
