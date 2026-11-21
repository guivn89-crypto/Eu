-- Ambiente simulado para verificar as closures após a inicialização da Home.
local callbacks = {}
local function signal() return {} end
local added, playerAdded, render = signal(), signal(), signal()
local health, died = signal(), signal()
local Actions = { alive = true }
function Actions.connect(event, fn)
    callbacks[event] = fn
    return { Disconnect = function() callbacks[event] = nil end }
end
function Actions.trackConn(conn) return conn end
local LP = { UserId = 123, CharacterAdded = added }
local Players = { PlayerAdded = playerAdded }
function Players:GetPlayers() return {} end
local RunService = { RenderStepped = render }
local Library = { _themeListeners = {}, Panic = false }
local MV = { respawn = false }
local task = { spawn = function(fn) fn() end }
local buildProfile
-- O runner injeta a implementação aqui.
