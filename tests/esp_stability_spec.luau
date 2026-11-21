-- Testes dos auxiliares reais extraídos do motor: sem instâncias Roblox.
local function vec(x)
    return setmetatable({x=x}, {__sub=function(a,b) return {Magnitude=math.abs(a.x-b.x)} end})
end
local Library = {Panic=false, ESPMaster={Jogador=true}}
local pool, scans, draws, hidden = {Jogador={}}, 0, 0, 0
local models = {}
local function part(y)
    return {Size={Y=y}, Position=vec(0), Parent=true, IsA=function(_, name) return name == 'BasePart' end}
end
local function model(parts)
    return {Parent=true, FindFirstChild=function(_, name) return parts[name] end}
end
local root = part(2)
local humanoid = {HipHeight=0, Health=100, Parent=true}
local target = {model=model({Torso=part(2), Head=part(1), ['Left Leg']=part(2)}), hum=humanoid, hrp=root}
local function gather(_, out)
    scans += 1
    table.insert(out, target)
end
local function anyOn() return true end
local function newDraw() return {root={Destroy=function() end}, hl={Destroy=function() end}} end
local function hideDraw() hidden += 1 end
local function drawTarget(_, t) draws += 1; assert(t.studs >= 0) end
-- INSERT IMPLEMENTATION HERE
local above, below = characterOffsets(target)
assert(above == 2 and below == 3, 'R6 offsets should cover head and legs')
target.model = model({UpperTorso=part(2), LowerTorso=part(1), Head=part(1)})
humanoid.HipHeight=2
above, below = characterOffsets(target)
assert(above == 3.5 and below == 3, 'R15 offsets use rig sizes and hip height')
local camera = {CFrame={Position=vec(0)}}
local settings = {maxDist=100}
for i=1,60 do
    root.Position = vec(i)
    processKind('Jogador', settings, camera, {}, i % 2 == 0)
end
assert(scans == 31, 'target gathering should remain throttled')
assert(draws == 60, 'existing targets must be reprojected every frame')
Library.Panic=true
processKind('Jogador', settings, camera, {}, false)
assert(hidden > 0 and draws == 60, 'panic must hide cached targets immediately')
Library.Panic=false
processKind('Jogador', settings, camera, {}, false)
assert(scans == 32 and draws == 61, 're-enabling must gather immediately')
target.model.Parent=false
processKind('Jogador', settings, camera, {}, false)
assert(pool.Jogador[target.model] == nil, 'removed models must be destroyed')
print('ESP stable rig offsets, frame projection, throttling and cleanup OK')
-- Uma câmera inclinada não deve fazer os extremos saírem do plano da tela.
local V = {}
V.__index = V
function V.__add(a,b) return setmetatable({x=a.x+b.x,y=a.y+b.y,z=a.z+b.z}, V) end
function V.__sub(a,b) return setmetatable({x=a.x-b.x,y=a.y-b.y,z=a.z-b.z}, V) end
function V.__mul(a,b) return setmetatable({x=a.x*b,y=a.y*b,z=a.z*b}, V) end
local center = setmetatable({x=10,y=20,z=30}, V)
local up = setmetatable({x=0.3,y=0.4,z=0.5}, V)
local projections = {}
local tilted = {CFrame={UpVector=up}}
function tilted:WorldToViewportPoint(v) projections[#projections+1]=v; return v end
local top, bottom = projectBounds(tilted, center, 2, 3)
assert(math.abs(top.x - 10.6)<1e-6 and math.abs(top.z - 31)<1e-6)
assert(math.abs(bottom.x - 9.1)<1e-6 and math.abs(bottom.z - 28.5)<1e-6)
assert(#projections == 2)
print('camera aligned projection uses camera up vector')
