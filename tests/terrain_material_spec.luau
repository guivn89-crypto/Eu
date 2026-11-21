local strict = setmetatable({Grass="Grass", Sand="Sand", Rock="Rock", Ground="Ground"}, {
    __index = function(_, key) error("material inexistente: " .. tostring(key)) end,
})
local Enum = {Material = strict}
local Actions = {}
local Terrain = { colors = {Ground = "original"} }
function Terrain:GetMaterialColor(material) return self.colors[material] end
function Terrain:SetMaterialColor(material, color) self.colors[material] = color end
function Actions.setProperty(obj, key, value) obj[key] = value end
-- O runner injeta o mapeamento e paintTerrain aqui.
