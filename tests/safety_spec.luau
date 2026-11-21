-- Executado após src/25_security.luau, com Library simulada.
local s = Library.Safety
assert(s.enabled and not s:allow("Voar", true))
assert(s:allow("Voar", false) and s:allow("Retícula", true))
local c = { state = false, calls = 0 }
function c:Get() return self.state end
function c:Set(value)
    if not s:allow("Voar", value) then return end
    self.calls += 1
    self.state = value
end
s:track("Voar", c)
c:Set(true)
assert(not c.state)
s:setEnabled(false)
c:Set(true)
assert(c.state)
local stopped = 0
s:trackStopper(function() stopped += 1 end)
s:setEnabled(true)
assert(not c.state and c.calls == 2 and stopped == 1)
c:Set(true)
assert(not c.state)
s:setEnabled(false)
c:Set(true)
assert(c.state)
s.panic = true
s:disableTracked()
assert(stopped == 2)
assert(not c.state and not s:allow("Voar", true))
assert(s:allow("Voar", false) and s:allow("Retícula", true))
s.panic = false
assert(s:allow("Voar", true))
print("safety policy OK")
local safe = { state = true }
function safe:Get() return self.state end
function safe:Set(v) self.state = v end
s:track("Retícula", safe)
s:setEnabled(true)
assert(safe.state) -- opções fora da lista não são desligadas pelo bloqueio
s:disable("Retícula")
assert(not safe.state) -- mas podem ser interrompidas em caso de erro
-- As ações também verificam a política quando são invocadas fora do menu.
local alive, flight, antiafk, ordinary = true, false, false, false
local actions = {
    ["Voar"] = function(v) flight = v end,
    ["Anti AFK"] = function(v) antiafk = v end,
    ["Retícula"] = function(v) ordinary = v end,
}
s:guardActions(actions, function() return alive end)
assert(actions["Voar"](true) == false and not flight)
assert(actions["Anti AFK"](true) == false and not antiafk)
actions["Retícula"](true); assert(ordinary)
s:setEnabled(false)
actions["Voar"](true); actions["Anti AFK"](true)
assert(flight and antiafk)
s.panic = true
assert(actions["Voar"](true) == false)
actions["Voar"](false); assert(not flight) -- restauração sempre permitida enquanto ativo
s.panic = false
alive = false
assert(actions["Anti AFK"](true) == false and antiafk)
print("action entry guards OK")
alive = true
assert(actions["Voar"]("truthy") == false and not flight)
assert(actions["Voar"](1) == false and not flight)
assert(actions["Voar"](nil) == false and not flight)
