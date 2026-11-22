--[[
    BBC HUB - Feature: Visuals
    Aba VISUAIS: ESP, interface do jogo e efeitos locais.
]]

local Features = BBC.Features or {}
BBC.Features = Features

local Controls = BBC.UI.Controls
local T = Controls.T

function Features.buildVisuals(window)
    local visuals = window:Tab({ Name = "VISUAIS", Icon = "eye" })

    local group = visuals:Groupbox({ Name = "ESP", Icon = "scan-eye", Side = "Left" })
    for _, name in ipairs({ "Jogador", "NPCs", "Corpo", "Recipiente", "Item no chão", "Itens de missão" }) do
        T(group, name, name == "Jogador" or name == "NPCs" or name == "Corpo")
    end

    group = visuals:Groupbox({ Name = "INTERFACE DO JOGO", Icon = "layout-dashboard", Side = "Right" })
    T(group, "Mochila personalizada")
    T(group, "Mochila")
    T(group, "Barra rápida", true)

    group = visuals:Groupbox({
        Name = "LOCAL",
        Icon = "map-pin",
        Side = "Right",
        Checkbox = true,
        Default = true,
        Callback = function() end,
    })
    for _, name in ipairs({ "Aura", "Círculo de salto", "Auréola", "Rastro estelar" }) do
        T(group, name)
    end

    return visuals
end

return Features.buildVisuals
