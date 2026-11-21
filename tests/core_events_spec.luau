local failures, count, logs = false, 0, {}
local fake = {}
function fake:Connect(fn)
    self.callback = fn
    local conn = { Connected = true }
    function conn:Disconnect() self.Connected = false end
    self.conn = conn
    return conn
end
function fake:Fire()
    if self.conn.Connected then self.callback() end
end
local conn = safeConnect(fake, function()
    count += 1
    if failures then error("falha simulada") end
end)
assert(Library._uiConnections[conn])
fake:Fire()
failures = true
for i = 1, 4 do fake:Fire() end
assert(conn.Connected)
failures = false
fake:Fire() -- recuperação zera contagem
failures = true
for i = 1, 5 do fake:Fire() end
assert(not conn.Connected)
local before = count
fake:Fire()
assert(count == before)
local other = setmetatable({}, { __index = fake })
local otherConn = safeConnect(other, function() count += 1 end)
assert(not Library._uiConnections[conn]) -- conexão terminada foi removida
Library._running = false
other:Fire()
assert(count == before and otherConn.Connected)
