-- Exercita drawTarget real com câmera e GUIs simuladas, sem Roblox.
local V = {}; V.__index=V
function V.__add(a,b) return setmetatable({x=a.x+b.x,y=a.y+b.y,z=a.z+b.z}, V) end
function V.__sub(a,b) return setmetatable({x=a.x-b.x,y=a.y-b.y,z=a.z-b.z}, V) end
function V.__mul(a,b) return setmetatable({x=a.x*b,y=a.y*b,z=a.z*b}, V) end
local function v(x,y,z) return setmetatable({x=x,y=y,z=z}, V) end
local Color3 = {new=function(...) return {...} end, fromRGB=function(...) return {...} end}
local UDim2 = {fromOffset=function(x,y) return {x=x,y=y} end, fromScale=function(x,y) return {x=x,y=y} end}
local Vector2 = {new=function(x,y) return {x=x,y=y} end}
local Enum = {TextXAlignment={Right='right', Left='left'}}
local R6, R15 = {}, {}
local function mk() return {} end
local function lineF(f) f.Visible = true end
local function hpColor(S) return S.healthbar.color end
-- INSERT IMPLEMENTATION HERE
local function part(size) return {Size={Y=size}, IsA=function(_,x) return x == 'BasePart' end} end
local hrp = part(2); hrp.Position=v(0,0,10)
local torso, head, leg = part(2), part(1), part(2)
local model = {FindFirstChild=function(_,name) return ({Torso=torso,Head=head,['Left Leg']=leg})[name] end}
local hum = {Health=75, MaxHealth=100, HipHeight=0}
local t = {model=model, hrp=hrp, hum=hum, name='Player', m=10, studs=35}
local S = {nearest={on=false,color='near'}, box={on=true, color='box',style='Completa',thick=1,corner=14},
    highlight={on=true,color='orange',outlineColor='dark',outline=1,alpha=0.8},
    healthbar={on=true,auto=false,color='green',width=4,side='Esquerda'}, health={on=true,color='green'},
    name={on=true,color='white'},distance={on=true,color='white',unit='m'},tracers={on=false,color='white',thick=1},
    arrows={on=true,color='red',size=18},skeleton={on=false}, lod={on=true,near=150},textSize=11}
local d = {skel={}, skelOn=false, root={}, boxFull={}, boxStroke={}, corners={}, hbBg={},hbFill={},name={},hp={},dist={},tracer={},dot={},hl={},arrow={}}
for i=1,8 do d.corners[i]={} end
local cam = {CFrame={UpVector=v(0,1,0)}}
function cam:WorldToViewportPoint(p) return {X=400+p.x*10,Y=300-p.y*10,Z=p.z} end
local vp = {X=800,Y=600}
drawTarget(d,t,S,cam,vp,false)
assert(d.boxFull.Visible and d.hl.Enabled and d.name.Visible and d.hp.Visible and d.hbBg.Visible)
assert(d.boxFull.Position.x == 386.25 and d.boxFull.Position.y == 280)
assert(d.boxFull.Size.y == 50 and d.hp.TextXAlignment == 'right')
S.healthbar.side='Direita'
drawTarget(d,t,S,cam,vp,false)
assert(d.hp.TextXAlignment == 'left' and d.hp.AnchorPoint.x == 0)
assert(d.hp.Position.x > d.boxFull.Position.x + d.boxFull.Size.x)
hrp.Position=v(100,0,10)
drawTarget(d,t,S,cam,vp,false)
assert(d.arrow.Visible and not d.hl.Enabled and not d.boxFull.Visible)
hrp.Position=v(0,0,10); t.m=200
S.tracers.on=true
drawTarget(d,t,S,cam,vp,false)
assert(d.dot.Visible and d.dist.Visible and d.tracer.Visible and not d.boxFull.Visible)
print('ESP draw projection, health side, offscreen arrow and LOD OK')
