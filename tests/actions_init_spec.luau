-- Ambiente estritamente simulado; não substitui Roblox nem executor.
local function signal() return {} end
local LP = {UserId = 123, Character = nil, CharacterAdded = signal(), CharacterRemoving = signal(), ChildAdded = signal()}
local Players = {LocalPlayer = LP, PlayerAdded = signal(), PlayerRemoving = signal()}
function Players:GetPlayers() return {} end
local Terrain = {}
function Terrain:GetChildren() return {} end
local Workspace = {Terrain = Terrain}
local RunService = {Heartbeat = signal(), RenderStepped = signal()}
local UserInputService = {InputBegan = signal(), InputEnded = signal(), InputChanged = signal()}
local HttpService, StatsService, Lighting, StarterGui, SoundService = {}, {}, {}, {}, {}
local services = {Players = Players, Workspace = Workspace, RunService = RunService,
    UserInputService = UserInputService, HttpService = HttpService, Stats = StatsService,
    Lighting = Lighting, StarterGui = StarterGui, SoundService = SoundService, VirtualUser = {}}
local game = {}
function game:GetService(name) assert(services[name], 'serviço não simulado: ' .. name); return services[name] end
local Config = {}
local Library = {_themeListeners = {}, Guards = {}, Safety = {}, Panic = false}
function Library.Guards.connect(_, _, _, _) return {Connected = true, Disconnect = function(self) self.Connected = false end} end
function Library.Safety:trackStopper(_) end
function Library.Safety:guardActions(_, _) end
local task = {spawn = function() end, defer = function() end, wait = function() end}
local Color3 = {fromRGB = function(...) return {...} end, new = function(...) return {...} end}
local materials = setmetatable({Grass="Grass", Sand="Sand", Rock="Rock", Ground="Ground"}, {
    __index = function(_, key) error("material inexistente: " .. tostring(key)) end,
})
local Enum = {Material = materials}
local Instance = {}
function Instance.new(class)
    local obj = {ClassName = class}
    function obj:Destroy() self.destroyed = true end
    return obj
end
local onLanguageChanged = {}
local function tr(s) return s end
local function warn(...) end
-- O runner injeta a inicialização completa das ações aqui.
