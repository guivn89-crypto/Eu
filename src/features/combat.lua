--[[
    BBC HUB - Feature: Combat
    Aba COMBATE: mira, alvos, espada, arma, efeitos, anti-aim e granadas.
]]

local Features = BBC.Features or {}
BBC.Features = Features

local Controls = BBC.UI.Controls
local T = Controls.T
local S = Controls.S

local function notify(text)
    BBC.Utils.notifyText(text)
end

function Features.buildCombat(window)
    local combat = window:Tab({ Name = "COMBATE", Icon = "crosshair" })

    local group = combat:Groupbox({
        Name = "MIRA",
        Icon = "crosshair",
        Side = "Left",
        Checkbox = true,
        Default = true,
        Callback = function() end,
    })
    group:Segmented({
        Name = "Modo",
        Options = { "Silencioso", "Fixar", "Agressivo" },
        Icons = { "crosshair", "lock", "flame" },
        Default = "Fixar",
        Callback = function() end,
    })
    group:Dropdown({
        Name = "Ativação",
        Options = { "Ao mirar", "Sempre" },
        Default = "Ao mirar",
        Callback = function() end,
    })
    T(group, "Alvo fixo")
    T(group, "Previsão")
    S(group, "Suavização", 0, 300, 80, "ms")
    T(group, "Pausa inteligente")
    T(group, "Notificar", true)

    group = combat:Groupbox({ Name = "ALVOS", Icon = "target", Side = "Left" })
    S(group, "Raio da mira", 10, 500, 70)
    T(group, "FOV dinâmico", true)
    group:Dropdown({
        Name = "Ponto de mira",
        Options = { "Partes selecionadas", "Mais próximo" },
        Default = "Partes selecionadas",
        Callback = function() end,
    })
    group:Dropdown({
        Name = "Partes do corpo",
        Options = { "Cabeça", "Corpo", "Braços", "Pernas" },
        Default = { "Cabeça" },
        Multi = true,
        Callback = function() end,
    })
    T(group, "Alternativa visível", true)
    T(group, "Mirar em NPCs", true)
    T(group, "Tiro por paredes", true)
    group:Keybind({ Name = "Adicionar amigo", Default = "MB3", Callback = function() end })
    S(group, "Limite de verificações", 1, 20, 7)

    group = combat:Groupbox({ Name = "ESPIADA", Icon = "eye", Side = "Left" })
    T(group, "Espiada subterrânea")

    group = combat:Groupbox({ Name = "CORPO A CORPO", Icon = "swords", Side = "Left" })
    T(group, "Aura letal", true)

    group = combat:Groupbox({ Name = "ARMA", Icon = "target", Side = "Right" })
    T(group, "Recarga automática", true)
    T(group, "Abastecer cargadores", true)
    group:Button({
        Name = "Manuseio da arma",
        Arrow = true,
        Callback = function()
            notify("Manuseio da arma")
        end,
    })
    T(group, "Mira falsa", true)

    group = combat:Groupbox({ Name = "EFEITOS DE COMBATE", Icon = "sparkles", Side = "Right" })
    T(group, "Retícula")
    T(group, "Círculo da mira", true)
    T(group, "Rastro personalizado", true)
    T(group, "Rastros do jogo", true)
    T(group, "Marca de acerto", true)
    T(group, "Números de dano", true)
    T(group, "Efeitos de acerto", true)
    T(group, "Efeitos de eliminação")
    T(group, "Dados do alvo", true)
    T(group, "Só acertos confirmados", true)

    group = combat:Groupbox({ Name = "ANTI AIM", Icon = "shield", Side = "Right" })
    T(group, "Anti aim")
    T(group, "Sob o chão")
    T(group, "Fantasma", true)

    group = combat:Groupbox({ Name = "GRANADAS", Icon = "bomb", Side = "Right" })
    T(group, "Trajetória do arremesso", true)
    T(group, "Sem tremor", true)

    return combat
end

return Features.buildCombat
