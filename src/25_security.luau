-- Controles rastreados apenas para interrupção por pânico, erro ou respawn.
-- Não há bloqueio preventivo automático nem detecção de anticheat.
Library.Safety = {
    blocked = {
        ["MIRA"] = true, ["Hack de velocidade"] = true, ["Sprint automático"] = true,
        ["Pulos seguidos"] = true, ["Controle no ar"] = true, ["Voar"] = true,
        ["Sem dano de queda"] = true, ["Sempre no chão"] = true, ["Jesus"] = true,
        ["Aranha"] = true, ["Não se afogar"] = true, ["Renascer automático"] = true, ["Anti AFK"] = true,
        ["Saque automático"] = true, ["Atravessar porta"] = true,
        ["Deslocamento"] = true, ["Troca rápida"] = true, ["Carregar jogadores"] = true,
        ["Desativar minas"] = true, ["Sem grama"] = true, ["Remover efeitos"] = true,
        ["Aura letal"] = true, ["Espiada subterrânea"] = true, ["Anti aim"] = true,
        ["Sob o chão"] = true, ["Recarga automática"] = true, ["Abastecer cargadores"] = true,
        ["Trajetória do arremesso"] = true,
    },
    controls = {},
    stoppers = {},
}
function Library.Safety:allow(name, value)
    if value ~= true then return true end
    return not (self.panic and self.blocked[name])
end
function Library.Safety:track(name, control)
    self.controls[#self.controls + 1] = { name = name, control = control }
end
function Library.Safety:disable(name)
    for _, item in ipairs(self.controls) do
        if item.name == name then
            pcall(function() if item.control:Get() then item.control:Set(false) end end)
        end
    end
end
function Library.Safety:trackStopper(callback)
    assert(type(callback) == "function", "stopper inválido")
    self.stoppers[#self.stoppers + 1] = callback
end
function Library.Safety:disableTracked()
    for _, item in ipairs(self.controls) do
        if self.blocked[item.name] then
            pcall(function() if item.control:Get() then item.control:Set(false) end end)
        end
    end
    for _, stop in ipairs(self.stoppers) do pcall(stop) end
end
-- Impede reativação durante pânico e chamadas após encerramento. Não bloqueia
-- ações durante uso normal; dados por jogo continuam sujeitos à validação.
function Library.Safety:guardActions(actions, isAlive)
    for name, callback in pairs(actions) do
        if self.blocked[name] and type(callback) == "function" then
            actions[name] = function(value, ...)
                if type(value) ~= "boolean" or not isAlive() or not self:allow(name, value) then return false end
                return callback(value, ...)
            end
        end
    end
end
