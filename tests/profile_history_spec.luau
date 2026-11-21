local value = false
Library.Registry.flag = {name = "flag", get = function() return value end, set = function(v) value = v end}
local w = setmetatable({}, {__index = Window})
local p = "BBC_HUB/configs/demo.json"
files[p] = "valid-backup"
local ok, why = w:RequestSaveConfig("demo")
assert(not ok and why == "confirmar" and files[p] == "valid-backup")
w._savePreview.expires = -1
ok, why = w:RequestSaveConfig("demo")
assert(not ok and why == "confirmar" and files[p] == "valid-backup")
value = true
ok, why = w:RequestSaveConfig("demo")
assert(not ok and why == "alterado" and files[p] == "valid-backup" and not files[p .. ".version1"])
value = false
failedWrite = p .. ".version1"
assert(not w:CreateConfigVersion("demo") and not files[p .. ".version1"])
failedWrite = nil
assert(not w:RequestSaveConfig("demo"))
assert(w:RequestSaveConfig("demo"))
assert(files[p] == "json" and files[p .. ".version1"] == "valid-backup" and files[p .. ".bak"] == "valid-backup")
failedWrite = "BBC_HUB/configs/demo-hist1.json"
assert(not w:RestoreConfigVersion("demo", "1") and not files[failedWrite])
failedWrite = nil
local restored, copy = w:RestoreConfigVersion("demo", "1")
assert(restored and copy == "demo-hist1" and files["BBC_HUB/configs/demo-hist1.json"] == "valid-backup")
assert(files[p] == "json" and files[p .. ".version1"] == "valid-backup" and w._cfgName == "demo")
assert(not w:RestoreConfigVersion("demo", "9"))
files[p] = "valid-backup"
assert(w:CreateConfigVersion("demo")); assert(w:CreateConfigVersion("demo"))
assert(not w:CreateConfigVersion("demo"))
assert(#w:ListConfigVersions("demo") == 3 and files[p .. ".version1"] == "valid-backup")
assert(not w:RequestSaveConfig("demo"))
files[p] = nil
local saved, reason = w:RequestSaveConfig("demo")
assert(not saved and reason == "alterado" and files[p] == nil)
files[p] = "valid-backup"
assert(not w:RequestSaveConfig("demo"))
files[p] = "invalid"
assert(not w:RequestSaveConfig("demo") and files[p] == "invalid")
print("manual overwrite confirmation and history OK")

files[p] = "valid-backup"
failedWrite = p .. ".bak"
assert(not w:SaveConfig("demo", true) and files[p] == "valid-backup")
failedWrite = p
assert(not w:SaveConfig("demo", true) and files[p] == "valid-backup")
failedWrite = nil
