-- Diagnóstico local limitado; não detecta anticheat e não testa APIs do executor.
Library.Diagnostics = { recent = {}, MAX = 8 }
function Library.Diagnostics:record(context, detail)
    local message = string.sub(tostring(context or "evento"), 1, 40) .. ": " .. string.sub(tostring(detail or "erro"), 1, 120)
    self.recent[#self.recent + 1] = message
    while #self.recent > self.MAX do table.remove(self.recent, 1) end
end
function Library.Diagnostics:last()
    return self.recent[#self.recent]
end
-- Média móvel aproximada do tempo gasto no callback do motor visual; não mede GPU.
function Library.Diagnostics:sampleEngine(seconds)
    if type(seconds) ~= "number" or seconds ~= seconds or seconds < 0 or seconds == math.huge then return end
    local sample = math.min(seconds * 1000, 60000)
    local m = self.engine or { count = 0, average = 0, last = 0 }
    m.count = math.min(m.count + 1, 60)
    m.average += (sample - m.average) / m.count
    m.last = sample
    self.engine = m
end
-- Calcula a escala sem exceder os limites da tela. Valores inválidos usam padrão.
function Library.fitScale(width, height, windowWidth, windowHeight, factor)
    local function positiveFinite(n) return type(n) == "number" and n == n and n > 0 and n < math.huge end
    if not positiveFinite(width) or not positiveFinite(height) or not positiveFinite(windowWidth) or not positiveFinite(windowHeight) then return nil end
    if type(factor) ~= "number" or factor ~= factor or factor == math.huge or factor == -math.huge then factor = 1 end
    factor = math.clamp(factor, 0.7, 1.3)
    local ceiling = math.min(width * 0.96 / windowWidth, height * 0.96 / windowHeight, 1.5)
    local base = math.min(width * 0.8 / windowWidth, height * 0.92 / windowHeight, 1.3)
    return math.min(base * factor, ceiling)
end

-- Caminhada incremental: não materializa todos os descendentes num único array.
-- O chamador registra os eventos antes de iniciar e valida objetos que saíram.
Library.StreamScan = {}
function Library.StreamScan.run(root, alive, visit, yieldEvery)
    local stack, processed = { root }, 0
    yieldEvery = math.clamp(tonumber(yieldEvery) or 200, 1, 1000)
    while #stack > 0 and alive() do
        local node = table.remove(stack)
        if node ~= root then
            local ok, err = pcall(visit, node)
            if not ok and Library.Diagnostics then Library.Diagnostics:record("varredura", err) end
        end
        local ok, children = pcall(function() return node:GetChildren() end)
        if ok and type(children) == "table" then
            for i, child in ipairs(children) do
                if not alive() then return end
                stack[#stack + 1] = child
                if i % yieldEvery == 0 then task.wait() end
            end
        elseif not ok and Library.Diagnostics then
            Library.Diagnostics:record("varredura", children)
        end
        processed += 1
        if processed % yieldEvery == 0 then task.wait() end
    end
end
function Library.StreamScan.start(root, alive, visit)
    task.spawn(function() Library.StreamScan.run(root, alive, visit) end)
end
