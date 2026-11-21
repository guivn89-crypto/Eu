-- Testa eventos sem Roblox: falhas, recuperação, limite e fim de vida.
local signal = {}
function signal:Connect(fn)
    self.callback = fn
    local conn = { Connected = true }
    function conn:Disconnect() self.Connected = false end
    self.conn = conn
    return conn
end
function signal:Fire(...)
    if self.conn.Connected then self.callback(...) end
end
local alive, failures, calls, reports = true, false, 0, {}
local conn = Library.Guards.connect(signal, function(v)
    calls += v
    if failures then error("falha simulada") end
end, function() return alive end, function(stage) table.insert(reports, stage) end, 3)
signal:Fire(1)
failures = true
signal:Fire(1); signal:Fire(1)
assert(conn.Connected and #reports == 1 and reports[1] == "erro")
failures = false
signal:Fire(1) -- sucesso zera as falhas consecutivas
failures = true
signal:Fire(1); signal:Fire(1)
assert(conn.Connected and #reports == 2)
signal:Fire(1)
assert(not conn.Connected and reports[3] == "interrompido")
local before = calls
signal:Fire(1)
assert(calls == before)
local signal2 = setmetatable({}, { __index = signal })
local conn2 = Library.Guards.connect(signal2, function() error("não deve chamar") end,
    function() return alive end, function() error("não deve avisar") end)
alive = false
signal2:Fire()
assert(conn2.Connected)
print("guarded events OK")
local state, notices = {}, {}
local function report(stage) table.insert(notices, stage) end
assert(Library.Guards.step(state, function() error("x") end, report, 2))
assert(not state.stopped and notices[1] == "erro")
assert(Library.Guards.step(state, function() end, report, 2))
assert(state.failures == 0)
assert(Library.Guards.step(state, function() error("x") end, report, 2))
assert(not Library.Guards.step(state, function() error("x") end, report, 2))
assert(state.stopped and notices[#notices] == "interrompido")
assert(not Library.Guards.step(state, function() error("não executa") end, report, 2))
