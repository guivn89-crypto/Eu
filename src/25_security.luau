-- Bloqueio preventivo baseado em uma lista explícita, NÃO detecção de anticheat.
-- O bloqueio também vale para atalhos e perfis importados via controles :Set().
Library.Safety = {
    enabled = true,
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
    if self.panic and self.blocked[name] then return false end
    return not self.enabled or not self.blocked[name]
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
function Library.Safety:setEnabled(value)
    self.enabled = value == true
    if self.enabled then self:disableTracked() end
end

-- Segunda checagem na entrada das ações, além da validação do menu.
-- A lista continua sendo uma política local, não um detector de anticheat.
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
