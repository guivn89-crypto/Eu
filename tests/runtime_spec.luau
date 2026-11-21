local diag = Library.Diagnostics
for i = 1, 12 do diag:record("teste", tostring(i)) end
assert(#diag.recent == 8 and diag:last() == "teste: 12" and diag.recent[1] == "teste: 5")
diag:record(string.rep("x", 90), string.rep("y", 200))
assert(#diag:last() <= 162)
local fit = Library.fitScale
assert(math.abs(fit(640, 400, 640, 388, 1) - 0.8) < 0.0001)
assert(fit(640, 400, 640, 388, 1.3) <= 0.96)
assert(math.abs(fit(640, 400, 640, 388, 0/0) - 0.8) < 0.0001)
assert(not fit(0, 100, 640, 388, 1) and not fit(math.huge, 100, 640, 388, 1))
assert(not fit(0/0, 100, 640, 388, 1))
local function node(name, children)
    local n = {name = name, children = children or {}}
    function n:GetChildren() return self.children end
    return n
end
local tree = node("root", {node("a", {node("leaf")}), node("b")})
local visits, waits, alive = {}, 0, true
task.wait = function() waits += 1 end
Library.StreamScan.run(tree, function() return alive end, function(n) visits[n.name] = (visits[n.name] or 0) + 1 end, 2)
assert(visits.a == 1 and visits.b == 1 and visits.leaf == 1 and visits.root == nil and waits > 0)
local n = 0
Library.StreamScan.run(tree, function() return alive end, function() n += 1; alive = false end, 2)
assert(n == 1)
alive = true
Library.StreamScan.run(tree, function() return alive end, function(item) if item.name == "b" then error("falha simulada") end end, 2)
assert(string.find(diag:last(), "varredura", 1, true))
print("runtime diagnostics, scaling and incremental scanning OK")

diag:sampleEngine(0.001); diag:sampleEngine(0.003)
assert(diag.engine.count == 2 and math.abs(diag.engine.average - 2) < 0.00001)
diag:sampleEngine(0/0); assert(diag.engine.count == 2)
for _ = 1, 100 do diag:sampleEngine(0.002) end
assert(diag.engine.count == 60 and math.abs(diag.engine.average - 2) < 0.00001)
