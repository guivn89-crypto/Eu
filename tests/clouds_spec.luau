local Actions = {}
local FX, children = {}, {}
local Terrain = { fail = false }
function Terrain:GetChildren() if self.fail then error("unavailable") end; return children end
local created = 0
local function cloud(enabled, cover)
    local item = { Parent = Terrain, Enabled = enabled, Cover = cover }
    function item:IsA(class) return class == "Clouds" end
    function item:Destroy() self.Parent = nil; self.destroyed = true end
    return item
end
local function mkFx(class, name, parent, disabled)
    assert(class == "Clouds" and parent == nil and disabled)
    created += 1
    local item = cloud(false, 0.5); item.Parent = nil; FX[name] = item; return item
end
-- O runner injeta restauração real e o controlador de nuvens aqui.
