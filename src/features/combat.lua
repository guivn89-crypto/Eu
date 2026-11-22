--[[
    BBC HUB - Feature: Combat
    Aba COMBATE: mira, alvos, espia, corpo a corpo, arma, efeitos, anti-aim, granadas.
]]

local Features = BBC.Features or {}
BBC.Features = Features

local Controls = BBC.UI.Controls
local T = Controls.T
local S = Controls.S

function Features.buildCombat(window)
    local combate = window:Tab({ Name = "COMBATE", Icon = "crosshair" })
    local g = combate:Groupbox({ Name = "MIRA", Icon = "crosshair", Side = "Left", Checkbox = true, Default = true, Callback = function(v) end })
    g:Segmented({ Name = "Modo", Options = { "Silencioso", "Fixar", "Agressivo" }, Icons = { "crosshair", "lock", "flame" }, Default = "Fixar", Callback = function(v) end })
    g:Dropdown({ Name = "Ativação", Options = { "Ao mirar", "Sempre" }, Default = "Ao mirar", Callback = function(v) end })
    T(g, "Alvo fixo"); T(g, "Previsão")
    S(g, "Suavização", 0, 300, 80, "ms")
    T(g, "Pausa inteligente"); T(g, "Notificar", true)
    g = combate:Groupbox({ Name = "ALVOS", Icon = "target", Side = "Left" })
    S(g, "Raio da mira", 10, 500, 70)
    T(g, "FOV dinâmico", true)
    g:Dropdown({ Name = "Ponto de mira", Options = { "Partes selecionadas", "Mais próximo" }, Default = "Partes selecionadas", Callback = function(v) end })
    g:Dropdown({ Name = "Partes do corpo", Options = { "Cabeça", "Corpo", "Braços", "Pernas" }, Default = { "Cabeça" }, Multi = true, Callback = function(v) end })
    T(g, "Alternativa visível", true); T(g, "Mirar em NPCs", true); T(g, "Tiro por paredes", true)
    g:Keybind({ Name = "Adicionar amigo", Default = "MB3", Callback = function() end })
    S(g, "Limite de verificações", 1, 20, 7)
    g = combate:Groupbox({ Name = "ESPIADA", Icon = "eye", Side = "Left" })
    T(g, "Espiada subterrânea")
    g = combate:Groupbox({ Name = "CORPO A CORPO", Icon = "swords", Side = "Left" })
    T(g, "Aura letal", true)
    g = combate:Groupbox({ Name = "ARMA", Icon = "target", Side = "Right" })
    T(g, "Recarga automática", true); T(g, "Abastecer cargadores", true)
    g:Button({ Name = "Manuseio da arma", Arrow = true, Callback = function() BBC.notify("Manuseio da arma") end })
    T(g, "Mira falsa", true)
    g = combate:Groupbox({ Name = "EFEITOS DE COMBATE", Icon = "sparkles", Side = "Right" })
    T(g, "Retícula"); T(g, "Círculo da mira", true); T(g, "Rastro personalizado", true)
    T(g, "Rastros do jogo", true); T(g, "Marca de acerto", true); T(g, "Números de dano", true)
    T(g, "Efeitos de acerto", true); T(g, "Efeitos de eliminação"); T(g, "Dados do alvo", true)
    T(g, "Só acertos confirmados", true)
    g = combate:Groupbox({ Name = "ANTI AIM", Icon = "shield", Side = "Right" })
    T(g, "Anti aim"); T(g, "Sob o chão"); T(g, "Fantasma", true)
    g = combate:Groupbox({ Name = "GRANADAS", Icon = "bomb", Side = "Right" })
    T(g, "Trajetória do arremesso", true); T(g, "Sem tremor", true)

    return combate
end

return { buildCombat = Features.buildCombat }