assert(FX.BBC_Atmosfera and FX.BBC_Atmosfera.Parent == nil)
assert(FX.BBC_Ceu and FX.BBC_Ceu.Parent == nil)
assert(FX.BBC_Nuvens == nil) -- nenhum Cloud é criado durante o startup
for _, entry in ipairs(attached) do assert(entry.enabled == false) end
local c = mkFx("Clouds", "testCloud", Terrain, true)
assert(c and not c.Enabled and c.Parent == Terrain)
assert(not mkFx("Fail", "testFail", Lighting, true))
assert(objects[#objects].state.destroyed and not FX.testFail)
print("effects start inactive and failed instance is cleaned up")
