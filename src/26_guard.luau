-- Proteção de eventos locais: erros consecutivos interrompem só a conexão
-- defeituosa. O chamador controla a vida útil e o aviso ao usuário.
Library.Guards = {}
function Library.Guards.connect(signal, callback, alive, report, limit)
    assert(type(callback) == "function", "callback inválido")
    limit = math.max(1, math.min(tonumber(limit) or 5, 20))
    local failures, connection = 0, nil
    connection = signal:Connect(function(...)
        if not alive() then return end
        local ok, err = pcall(callback, ...)
        if ok then failures = 0; return end
        failures += 1
        if failures == 1 then pcall(report, "erro", tostring(err)) end
        if failures >= limit then
            if connection then pcall(function() connection:Disconnect() end) end
            pcall(report, "interrompido", tostring(err))
        end
    end)
    return connection
end

-- Passo de laço periódico. Um sucesso zera a contagem de falhas consecutivas.
function Library.Guards.step(state, callback, report, limit)
    if state.stopped then return false end
    limit = math.max(1, math.min(tonumber(limit) or 5, 20))
    local ok, err = pcall(callback)
    if ok then state.failures = 0; return true end
    state.failures = (state.failures or 0) + 1
    if state.failures == 1 then pcall(report, "erro", tostring(err)) end
    if state.failures >= limit then
        state.stopped = true
        pcall(report, "interrompido", tostring(err))
        return false
    end
    return true
end
