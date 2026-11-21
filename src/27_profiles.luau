-- Validação de perfis não confiáveis antes de chamar callbacks do menu.
-- Não protege contra um executor ou cliente comprometido.
Library.ProfileGuard = { MAX_BYTES = 256 * 1024, MAX_NODES = 20000, MAX_DEPTH = 8, MAX_STRING = 4096 }

function Library.ProfileGuard:validateTree(root)
    local seen, nodes = {}, 0
    local function walk(value, depth)
        nodes += 1
        if nodes > self.MAX_NODES or depth > self.MAX_DEPTH then return false end
        local kind = type(value)
        if kind == "boolean" then return true end
        if kind == "number" then return value == value and value ~= math.huge and value ~= -math.huge end
        if kind == "string" then return #value <= self.MAX_STRING end
        if kind ~= "table" or seen[value] then return false end
        seen[value] = true
        for key, item in pairs(value) do
            local kt = type(key)
            if kt ~= "string" and kt ~= "number" then return false end
            if kt == "string" and #key > 512 then return false end
            if kt == "number" and (key ~= key or key == math.huge or key == -math.huge) then return false end
            if not walk(item, depth + 1) then return false end
        end
        seen[value] = nil
        return true
    end
    return type(root) == "table" and walk(root, 0)
end

function Library.ProfileGuard:prepare(decoded, registry, blocked)
    if not self:validateTree(decoded) then return nil, "perfil inválido ou excede os limites" end
    local data = decoded
    if decoded.v ~= nil then
        if (decoded.v ~= 1 and decoded.v ~= 2) or type(decoded.data) ~= "table" then return nil, "versão de perfil não suportada" end
        data = decoded.data
    end
    local operations, skipped, unknown = {}, 0, 0
    for key, value in pairs(data) do
        if type(key) ~= "string" then return nil, "chave de perfil inválida" end
        local entry = registry[key]
        if entry then
            -- O contorno do ESP era booleano em perfis anteriores e agora é
            -- slider. Migra somente as seis chaves conhecidas, sem alterar o arquivo.
            if type(value) == "boolean" and string.match(key, "^VISUAIS/ESP/[^/]+/painel/sub2/Contorno$") then
                local kind = string.match(key, "^VISUAIS/ESP/([^/]+)/")
                local espKinds = { Jogador = true, NPCs = true, Corpo = true, Recipiente = true, ["Item no chão"] = true, ["Itens de missão"] = true }
                if espKinds[kind] then value = value and 1.5 or 0 end
            end
            local ok, current = pcall(entry.get)
            if not ok then return nil, "não foi possível ler uma opção" end
            if entry.validate then
                local valid, result = pcall(entry.validate, value)
                if not valid or result ~= true then return nil, "valor inválido: " .. key end
            elseif current ~= nil and type(value) ~= type(current) then
                return nil, "tipo inválido: " .. key
            elseif current == nil and type(value) ~= "string" and type(value) ~= "table" then
                return nil, "tipo inválido: " .. key
            end
            local name = entry.name and string.gsub(entry.name, "#ativo$", "")
            if value == true and name and blocked[name] then
                skipped += 1
            else
                operations[#operations + 1] = { key = key, entry = entry, value = value, old = current }
            end
        else
            unknown += 1
        end
    end
    -- Ausência de atalhos/fixos no perfil remove esses registros como antes.
    for key, entry in pairs(registry) do
        if data[key] == nil and (string.sub(key, -6) == "#tecla" or string.sub(key, -7) == "#fixado") then
            local ok, old = pcall(entry.get)
            if not ok then return nil, "não foi possível ler um atalho" end
            operations[#operations + 1] = { key = key, entry = entry, old = old }
        end
    end
    table.sort(operations, function(a, b) return a.key < b.key end)
    return operations, nil, skipped, unknown
end

function Library.ProfileGuard:apply(operations)
    local applied = {}
    for _, operation in ipairs(operations) do
        local ok, result = pcall(operation.entry.set, operation.value)
        if not ok or result == false then
            -- Melhor esforço: callbacks podem ter efeitos irreversíveis no servidor.
            pcall(operation.entry.set, operation.old)
            for i = #applied, 1, -1 do pcall(applied[i].entry.set, applied[i].old) end
            return false, operation.key
        end
        applied[#applied + 1] = operation
    end
    return true
end
