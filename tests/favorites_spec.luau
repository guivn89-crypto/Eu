local f = Library.Favorites
local calls = 0
table.insert(f.listeners, function() calls += 1 end)
assert(f:toggle("VISUAIS/ESP/Jogador") and f:contains("VISUAIS/ESP/Jogador") and calls == 1)
local copy = f:get(); copy[1] = "alterado"; assert(f:contains("VISUAIS/ESP/Jogador"))
assert(f:toggle("VISUAIS/ESP/Jogador") and #f:get() == 0)
assert(not f:set({"x", "x"}) and not f:set({[2] = "x"}) and not f:set({string.rep("x", 513)}))
local list = {}; for i=1,12 do list[i] = "tab/" .. i end
assert(f:set(list) and not f:toggle("tab/13") and #f:get() == 12)
assert(Library.Registry["__favorites/list"].validate(list))
assert(f:toggle("tab/1") and #f:get() == 11)
print("favorites validation OK")

local r = Library.RecentNavigation
local updates = 0; table.insert(r.listeners, function() updates += 1 end)
for i=1,6 do r:add("option/" .. i) end
assert(#r:get() == 5 and r:get()[1] == "option/6" and r:get()[5] == "option/2")
r:add("option/3"); assert(r:get()[1] == "option/3" and #r:get() == 5 and updates == 7)
r:add(nil); assert(updates == 7)
