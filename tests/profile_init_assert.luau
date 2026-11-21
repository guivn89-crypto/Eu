assert(type(buildProfile) == "function")
assert(type(callbacks[added]) == "function" and type(callbacks[playerAdded]) == "function")
assert(type(callbacks[render]) == "function" and #Library._themeListeners == 1)
-- Os callbacks permanecem válidos depois que initializeProfile retorna.
local hum = { Health = 100, HealthChanged = health, Died = died }
local char = {}
function char:WaitForChild(name) assert(name == "Humanoid"); return hum end
LP.Character = char
callbacks[added](char)
assert(type(callbacks[health]) == "function" and type(callbacks[died]) == "function")
callbacks[health](75)
callbacks[died]()
callbacks[render]()
Library._themeListeners[1]()
print("profile initialization closures OK")
