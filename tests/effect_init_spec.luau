local Lighting, Terrain = {}, {}
local objects, attached = {}, {}
local Instance = {}
function Instance.new(class)
    local state = {ClassName = class, Enabled = true}
    local object = {}
    function object:Destroy() state.destroyed = true end
    setmetatable(object, {
        __index = function(_, key) return state[key] end,
        __newindex = function(_, key, value)
            if key == "Enabled" and (class == "Sky" or class == "Atmosphere") then error("property unavailable") end
            if key == "Parent" and value ~= nil then
                if class == "Clouds" then assert(state.Enabled == false, "nuvem ativada antes de associar") end
                if class == "Fail" then error("parent failed") end
                table.insert(attached, {class = class, enabled = state.Enabled})
            end
            state[key] = value
        end,
    })
    objects[#objects + 1] = {object = object, state = state}
    return object
end
-- O runner injeta a criação dos efeitos aqui.
