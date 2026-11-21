local shots, childrenCalls, disabled = 0, 0, 0
local tool = {}
local remote = { Name = "Reload" }
function tool:GetChildren() childrenCalls += 1; return {remote} end
function tool:FindFirstChildOfClass(name) return tool end
function remote:IsA(name) return name == "RemoteEvent" end
function remote:IsDescendantOf(other) return other == tool end
function remote:FireServer() shots += 1 end
LP.Character = tool
COMBAT.reload = true
assert(not doReload() and shots == 0 and childrenCalls == 0) -- política ligada
enabled = false
assert(not doReload() and shots == 0 and childrenCalls == 0) -- sem caminho explícito
BBC_CONFIG.ReloadRemotePath = {"Reload"}
assert(doReload() and shots == 1)
now = 2; assert(not doReload() and shots == 1) -- cooldown
now = 5; assert(doReload() and shots == 2)
now = 10
function remote:FireServer() error("blocked") end
function Library.Safety:disable(name) disabled += 1 end
assert(not doReload() and not COMBAT.reload and disabled == 1)
print("reload integration OK")
