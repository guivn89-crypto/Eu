local guard = Library.OperationGuard
assert(not guard:take("other", 0) and not guard:take("loot", 0/0))
assert(guard:take("loot", 0) and not guard:take("loot", 1.9))
assert(guard:take("loot", 2) and not guard:take("loot", 1))
for i = 2, 9 do assert(guard:take("loot", i * 2)) end
assert(not guard:take("loot", 21))
assert(guard:take("loot", 60)) -- o primeiro registro expirou
assert(guard:take("reload", 0) and not guard:take("reload", 4.99))
for i = 1, 5 do assert(guard:take("reload", i * 5)) end
assert(not guard:take("reload", 30) and guard:take("reload", 60))
assert(not guard:validPath(nil) and not guard:validPath({}) and not guard:validPath({"", "x"}))
assert(not guard:validPath({"one", [3] = "three"}))
assert(not guard:validPath({"one", malicious = "x"}))
assert(not guard:validPath({string.rep("x", 81)}))
assert(not guard:validPath({"a", "b", "c", "d", "e", "f", "g", "h", "i"}))
local function node(name, class, children)
    local result = { Name = name, class = class, children = children or {} }
    for _, c in ipairs(result.children) do c.parent = result end
    function result:GetChildren() return self.children end
    function result:IsA(c) return self.class == c end
    function result:IsDescendantOf(other)
        local current = self.parent
        while current do if current == other then return true end; current = current.parent end
        return false
    end
    return result
end
local remote = node("Reload", "RemoteEvent")
local folder = node("Events", "Folder", {remote})
local tool = node("Tool", "Tool", {folder})
assert(guard:resolveRemote(tool, {"Events", "Reload"}) == remote)
assert(not guard:resolveRemote(tool, {"Reload"}))
assert(not guard:resolveRemote(tool, {"Events"}))
folder.children[#folder.children + 1] = node("Reload", "RemoteEvent")
assert(not guard:resolveRemote(tool, {"Events", "Reload"})) -- ambíguo
folder.children[2] = nil
remote.parent = nil
assert(not guard:resolveRemote(tool, {"Events", "Reload"}))
assert(not guard:resolveRemote({GetChildren = function() error("acesso negado") end}, {"x"}))
assert(guard:validLootConfig(42, {{"Crates", "Loot"}}, 42))
assert(not guard:validLootConfig(41, {{"Crates", "Loot"}}, 42))
assert(not guard:validLootConfig(42, {}, 42))
assert(not guard:validLootConfig(42, {{"x"}, [3] = {"y"}}, 42))
assert(not guard:validLootConfig(42, {{"x"}, extra = {"y"}}, 42))
assert(not guard:validLootConfig(42, {{""}}, 42))
assert(not guard:validLootConfig(42, table.create(21, {"x"}), 42))
local prompt = node("Loot", "ProximityPrompt")
local crates = node("Crates", "Folder", {prompt})
local world = node("Workspace", "Workspace", {crates})
assert(guard:resolvePrompt(world, {"Crates", "Loot"}) == prompt)
assert(not guard:resolvePrompt(world, {"Crates"}))
crates.children[2] = node("Loot", "ProximityPrompt")
assert(not guard:resolvePrompt(world, {"Crates", "Loot"}))
crates.children[2] = nil
prompt.parent = nil
assert(not guard:resolvePrompt(world, {"Crates", "Loot"}))
assert(not guard:resolvePrompt({ GetChildren = function() error("negado") end }, {"Loot"}))
print("operation guard OK")
