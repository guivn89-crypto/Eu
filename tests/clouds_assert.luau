-- A nuvem ativa do jogo é reutilizada e restaurada sem ser destruída.
local existing = cloud(true, 0.2)
children = {existing}
applyClouds(true, 0.8)
assert(created == 0 and existing.Enabled and existing.Cover == 0.8)
applyClouds(false, 0.8)
assert(not existing.destroyed and existing.Parent == Terrain and existing.Cover == 0.2 and existing.Enabled)
-- Uma mudança posterior do jogo não deve ser sobrescrita na restauração.
applyClouds(true, 0.7); existing.Cover = 0.4; applyClouds(false, 0)
assert(existing.Cover == 0.4)
-- Uma nuvem previamente desativada volta ao estado original.
local inactive = cloud(false, 0.3); children = {inactive}
applyClouds(true, 0.6); assert(inactive.Enabled and inactive.Cover == 0.6)
applyClouds(false, 0); assert(not inactive.Enabled and inactive.Cover == 0.3 and not inactive.destroyed)
-- Sem nuvem do jogo, cria uma desativada e a destrói ao desligar.
children = {}; applyClouds(true, 0.9)
local owned = FX.BBC_Nuvens
assert(created == 1 and owned.Parent == Terrain and owned.Enabled and owned.Cover == 0.9)
applyClouds(false, 0)
assert(owned.destroyed and FX.BBC_Nuvens == nil)
-- Sem acesso aos filhos, não supõe que o terreno está vazio.
Terrain.fail = true; applyClouds(true, 0.6); assert(created == 1)
-- Prefere uma instância já ativa e lida com a troca de objetos pelo jogo.
Terrain.fail = false
local first = cloud(false, 0.1)
local active = cloud(true, 0.5)
children = {first, active}; applyClouds(true, 0.75)
assert(not first.Enabled and active.Cover == 0.75)
active.Parent = nil
local replacement = cloud(true, 0.33); children = {replacement}
applyClouds(true, 0.85)
assert(replacement.Cover == 0.85 and not replacement.destroyed)
applyClouds(false, 0)
assert(replacement.Cover == 0.33 and replacement.Enabled)
print("cloud reuse and conditional restore OK")
