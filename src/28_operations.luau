-- Limites locais para reduzir chamadas repetidas. Não são regras do jogo e
-- não garantem aceitação, segurança ou ausência de detecção no servidor.
Library.OperationGuard = { limits = {
    loot = { interval = 2, window = 60, max = 10 },
    reload = { interval = 5, window = 60, max = 6 },
}, history = {} }

function Library.OperationGuard:take(kind, now)
    local rule = self.limits[kind]
    if not rule or type(now) ~= "number" or now ~= now or now == math.huge or now == -math.huge then return false end
    local times = self.history[kind] or {}
    self.history[kind] = times
    -- Um relógio inesperadamente regressivo não deve abrir a trava.
    if #times > 0 and now < times[#times] then return false end
    while #times > 0 and now - times[1] >= rule.window do table.remove(times, 1) end
    if #times >= rule.max or (#times > 0 and now - times[#times] < rule.interval) then return false end
    times[#times + 1] = now
    return true
end

function Library.OperationGuard:validPath(path)
    if type(path) ~= "table" or #path < 1 or #path > 8 then return false end
    local count = 0
    for key, value in pairs(path) do
        if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > #path then return false end
        if type(value) ~= "string" or #value < 1 or #value > 80 then return false end
        count += 1
    end
    return count == #path
end

-- Não procura remotes por palavras-chave; o caminho deve ser informado pelo
-- usuário, relativo à ferramenta equipada. Duplicatas tornam o alvo ambíguo.
function Library.OperationGuard:resolveRemote(tool, path)
    if not tool or not self:validPath(path) then return nil end
    local ok, remote = pcall(function()
        local node = tool
        for _, name in ipairs(path) do
            local match = nil
            for _, child in ipairs(node:GetChildren()) do
                if child.Name == name then
                    if match then return nil end
                    match = child
                end
            end
            if not match then return nil end
            node = match
        end
        if not node:IsA("RemoteEvent") or not node:IsDescendantOf(tool) then return nil end
        return node
    end)
    return ok and remote or nil
end

-- Listas de caminhos explícitos, relativas ao Workspace e vinculadas ao PlaceId.
-- As informações locais não comprovam autorização no servidor.
function Library.OperationGuard:validLootConfig(placeId, paths, actualPlaceId)
    if type(placeId) ~= "number" or placeId ~= actualPlaceId or placeId <= 0 or placeId % 1 ~= 0 then return false end
    if type(paths) ~= "table" or #paths < 1 or #paths > 20 then return false end
    local count = 0
    for k, path in pairs(paths) do
        if type(k) ~= "number" or k % 1 ~= 0 or k < 1 or k > #paths or not self:validPath(path) then return false end
        count += 1
    end
    return count == #paths
end

function Library.OperationGuard:resolvePrompt(root, path)
    if not root or not self:validPath(path) then return nil end
    local ok, result = pcall(function()
        local node = root
        for _, name in ipairs(path) do
            local found
            for _, child in ipairs(node:GetChildren()) do
                if child.Name == name then
                    if found then return nil end
                    found = child
                end
            end
            if not found then return nil end
            node = found
        end
        if not node:IsA("ProximityPrompt") or not node:IsDescendantOf(root) then return nil end
        return node
    end)
    return ok and result or nil
end
