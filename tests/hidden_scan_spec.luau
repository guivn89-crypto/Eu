local pending, connections = {}, {}
local Workspace = {Parent = true, DescendantAdded = {}}
local LP = {Character = nil}
local Library = {Panic = false, StreamScan = {}}
local Actions = {alive = true, tracked = {}}
function Actions.connect(signal, fn)
    local c = {Connected = true, fire = fn}
    function c:Disconnect() self.Connected = false end
    connections[#connections + 1] = c
    return c
end
function Actions.trackConn(c) return c end
function Library.StreamScan.start(root, active, visit) pending[#pending + 1] = {active=active, visit=visit} end
local function obj(name)
    local d = {Name=name, Parent=Workspace}
    function d:IsA(kind) return kind == "BasePart" end
    function d:IsDescendantOf(where) return self.Parent == where end
    return d
end
