-- Simulação parcial do painel; o código real buildEspPanel é inserido abaixo.
local created, controls, general = {}, {}, {}
local Enum = setmetatable({}, {__index=function(_, k) return setmetatable({}, {__index=function(_, x) return k .. '.' .. x end}) end})
local function signal() return {} end
local Instance = {}
function Instance.new(class)
    local obj = {ClassName=class, MouseButton1Click=signal()}
    table.insert(created, obj)
    return obj
end
local function pack(...) return {...} end
local UDim = {new=pack}
local UDim2 = {new=pack, fromOffset=pack, fromScale=pack}
local Vector2 = {new=pack}
local Color3 = {new=pack, fromRGB=pack}
local NumberSequence = {new=pack}
local NumberSequenceKeypoint = {new=pack}
local Library = {Fonts={Bold='bold', Regular='regular'}, Theme={Accent='accent', Stroke='stroke', Text='text', Muted='muted'}}
function Library.Bind(obj, key, value) obj[key] = Library.Theme[value] or value end
function Library.MakeIcon(parent, name, _, _, props)
    local obj = {Parent=parent, name=name}
    for k,v in pairs(props) do obj[k]=v end
    table.insert(created, obj)
    return obj
end
local Actions = {}
function Actions.connect(s, callback) s.callback=callback; return {Disconnect=function() end} end
local game = {}
function game:GetService(name)
    assert(name == 'RunService')
    return {Heartbeat=signal()}
end
local function tr(x) return x end
local function tipText(x) return x end
local function setter(registry, opts)
    registry[opts.Name] = opts
    local obj = {}
    function obj:Set(v)
        if opts.Disabled then return false end
        if opts.Callback then opts.Callback(v) end
        return true
    end
    return obj
end
local function sub(registry)
    local obj={}
    function obj:Slider(opts) return setter(registry, opts) end
    function obj:Toggle(opts) return setter(registry, opts) end
    function obj:Dropdown(opts) return setter(registry, opts) end
    function obj:ColorPicker(opts) return setter(registry, opts) end
    function obj:Label(opts) return {} end
    return obj
end
local right = sub(controls)
function right:Foldout(opts)
    opts.Build(sub(general))
    return {Set=function() end, IsOpen=function() return false end}
end
local m = {Left={}, Right=right, RightBox={}, LeftBox={}, RightScroll={}, Overlay={Visible=true}}
-- INSERT IMPLEMENTATION HERE
buildEspPanel('Jogador')(m)
local S = Library.ESP.Jogador
assert(S.highlight.color[1] == 255 and S.highlight.color[2] == 120 and S.box.style == 'Completa')
assert(S.highlight.alpha == 0.8 and S.healthbar.on and not S.health.on)
local chips = {}
for _, obj in ipairs(created) do
    if obj.ClassName == 'TextButton' and obj.Text ~= '' then chips[obj.Text] = obj end
end
assert(chips.Destaque and chips.Caixa and chips['Barra de vida'] and chips.Setas)
local painted = 0
for _, obj in ipairs(created) do
    if obj.ClassName == 'Frame' and obj.BackgroundColor3 == S.highlight.color and type(obj.BackgroundTransparency) == "number" and math.abs(obj.BackgroundTransparency - 0.2) < 0.0001 then painted += 1 end
end
assert(painted >= 10, 'person preview should have individual painted body parts')
controls.Caixa.Callback(false)
assert(not S.box.on)
chips.Caixa.MouseButton1Click.callback()
assert(S.box.on, 'chip must use the same control state')
controls.Setas.Callback(true); assert(S.arrows.on)
general['Distância da prévia'].Callback(300); assert(S.prevDist == 300)
general['Vida da prévia'].Callback(50); assert(S.prevHp == 50)
local boxSettings = sub({})
controls.Caixa.Settings(boxSettings)
assert(controls['K/D'].Disabled and controls['Denúncias'].Disabled)
for _, kind in ipairs({'NPCs','Corpo','Recipiente','Item no chão','Itens de missão'}) do
    created, controls, general = {}, {}, {}
    right = sub(controls)
    function right:Foldout(opts) opts.Build(sub(general)); return {Set=function() end, IsOpen=function() return false end} end
    m.Right = right
    buildEspPanel(kind)(m)
    assert(Library.ESP[kind] and controls['Caixa'] and controls['Destaque'] and controls['Setas'], kind)
    controls['Destaque'].Callback(false)
    assert(not Library.ESP[kind].highlight.on, kind)
end
print('All ESP previews initialize and share settings with ESP state')
