local guard = Library.ProfileGuard
local state, calls = { toggle = false, number = 10, choice = "A", shortcut = "K" }, 0
local registry = {
    toggle = { name = "Voar", get = function() return state.toggle end, set = function(v) calls += 1; state.toggle = v end },
    number = { get = function() return state.number end, set = function(v) calls += 1; state.number = v end },
    choice = { get = function() return state.choice end, set = function(v) calls += 1; state.choice = v end,
        validate = function(v) return v == "A" or v == "B" end },
    ["x#tecla"] = { get = function() return state.shortcut end, set = function(v) calls += 1; state.shortcut = v end,
        validate = function(v) return v == "K" or v == "L" end },
}
local ops, err, skipped = guard:prepare({v = 2, data = { toggle = true, number = 20, choice = "B", ["x#tecla"] = "L" }}, registry, {Voar = true})
assert(ops and not err and skipped == 1 and guard:apply(ops))
assert(not state.toggle and state.number == 20 and state.choice == "B" and state.shortcut == "L")
local before = calls
assert(not guard:prepare({number = "wrong", choice = "A"}, registry, {}))
assert(not guard:prepare({number = 0/0}, registry, {}))
assert(not guard:prepare({number = math.huge}, registry, {}))
assert(not guard:prepare({choice = "C"}, registry, {}))
assert(not guard:prepare({v = 3, data = {}}, registry, {}))
assert(not guard:prepare({v = 2, data = false}, registry, {}))
assert(not guard:prepare({[1] = true}, registry, {}))
assert(not guard:prepare({other = string.rep("x", guard.MAX_STRING + 1)}, registry, {}))
local cycle = {}; cycle.child = cycle
assert(not guard:prepare(cycle, registry, {}))
local deep = {}; local node = deep
for i = 1, guard.MAX_DEPTH + 1 do node.x = {}; node = node.x end
assert(not guard:prepare(deep, registry, {}))
local many = {}; for i = 1, guard.MAX_NODES + 1 do many[tostring(i)] = true end
assert(not guard:prepare(many, registry, {}))
assert(calls == before) -- validação não executa setters
ops = assert(guard:prepare({v = 1, data = { number = 30 }}, registry, {}))
assert(guard:apply(ops) and state.number == 30 and state.shortcut == nil)
ops = assert(guard:prepare({toggle = true}, registry, {}))
assert(guard:apply(ops) and state.toggle) -- política desligada
local first, second = 1, 2
local failRegistry = {
    a = {get = function() return first end, set = function(v) first = v end},
    b = {get = function() return second end, set = function(v) if v == 99 then error("erro") end; second = v end},
}
ops = assert(guard:prepare({a = 20, b = 99}, failRegistry, {}))
assert(not guard:apply(ops) and first == 1 and second == 2)
print("profile validation OK")
