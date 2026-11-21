local value = false
Library.Registry.flag = {name = "flag", get = function() return value end, set = function(v) value = v end}
local win = setmetatable({ _ready = true }, {__index = Window})
local source = "BBC_HUB/configs/demo.json"
files[source] = "corrupt-original"
files[source .. ".bak"] = "valid-backup"
files["BBC_HUB/configs/demo-rec1.json"] = "existing"
local ok, name = win:RestoreConfigBackup("../demo")
assert(ok and name == "demo-rec2" and value == true)
assert(files[source] == "corrupt-original" and files[source .. ".bak"] == "valid-backup")
assert(files["BBC_HUB/configs/demo-rec1.json"] == "existing")
assert(files["BBC_HUB/configs/demo-rec2.json"] == "valid-backup")
assert(win._cfgName == name)
assert(not win:RestoreConfigBackup("missing"))
files["BBC_HUB/configs/bad.json.bak"] = "invalid"
assert(not win:RestoreConfigBackup("bad"))
assert(files["BBC_HUB/configs/bad-rec1.json"] == nil)
files["BBC_HUB/configs/fail.json.bak"] = "valid-backup"
failWrite = true
assert(not win:RestoreConfigBackup("fail"))
assert(files["BBC_HUB/configs/fail.json.bak"] == "valid-backup")
failWrite = false
assert(not win:SetAutoload("none"))
assert(win:SetAutoload("demo-rec2") and files["BBC_HUB/autoload.txt"] == "demo-rec2")
local _, _, skipped, unknown = Library.ProfileGuard:prepare({v = 2, data = {flag = true, oldOption = 12}}, Library.Registry, {})
assert(skipped == 0 and unknown == 1)
print("non-destructive recovery and legacy diagnostics OK")
