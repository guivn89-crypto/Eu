-- Sem bloqueio preventivo: só o pânico impede reativação e cancela ações.
local s = Library.Safety
assert(s.enabled == nil and s.setEnabled == nil)
assert(s:allow("Voar", true) and s:allow("Anti AFK", true) and s:allow("Retícula", true))
for name in pairs(s.blocked) do assert(s:allow(name, true), name .. " was blocked outside panic") end
local c = {state = false, calls = 0}
function c:Get() return self.state end
function c:Set(value)
    if not s:allow("Voar", value) then return false end
    self.calls += 1; self.state = value
end
s:track("Voar", c)
c:Set(true); assert(c.state)
local stopped = 0
s:trackStopper(function() stopped += 1 end)
s.panic = true; s:disableTracked()
assert(stopped == 1 and not c.state)
assert(not s:allow("Voar", true) and s:allow("Voar", false))
assert(s:allow("Retícula", true))
s.panic = false
c:Set(true); assert(c.state)
s:disable("Voar"); assert(not c.state)
local alive, flight, ordinary = true, false, false
local actions = {
    ["Voar"] = function(v) flight = v end,
    ["Retícula"] = function(v) ordinary = v end,
}
s:guardActions(actions, function() return alive end)
actions.Voar(true); actions["Retícula"](true); assert(flight and ordinary)
s.panic = true
assert(actions.Voar(true) == false)
actions.Voar(false); assert(not flight)
s.panic = false
alive = false
assert(actions.Voar(true) == false and not flight)
alive = true
assert(actions.Voar("truthy") == false and not flight)
print("panic and lifecycle guards without preventive policy OK")
