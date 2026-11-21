local pending = {}
local Actions, EXTRA, Library = {alive=true}, {}, {Panic=false, StreamScan={}}
local Workspace = {}
local task = {spawn=function(fn) pending[#pending+1]=fn end}
local function say() end
local objects = {}
function Library.StreamScan.run(root, active, visit)
    for _, d in ipairs(objects) do if active() then visit(d) end end
end
local function effect(value)
    local d = {Enabled=value}
    function d:IsA(kind) return kind == "ParticleEmitter" end
    function d:IsDescendantOf(where) return where == Workspace end
    return d
end
