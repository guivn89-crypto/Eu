local state, calls = false, 0
Library.Registry.flag = {name = "Voar", get = function() return state end, set = function(v) calls += 1; state = v end}
Library.Safety = {panic = false, blocked = {Voar = true}}
files["BBC_HUB/configs/demo.json"] = "valid-backup"
local w = setmetatable({}, {__index = Window})
Library.Safety.enabled = true -- campo antigo não pode reintroduzir bloqueio preventivo
local report = assert(w:StageConfigPreview("demo"))
assert(calls == 0 and #report.changes == 1 and report.unknown == 1 and report.skipped == 0)
state = true
assert(not w:ConfirmConfigPreview("demo") and calls == 0) -- mudou depois da prévia
state = false
assert(w:StageConfigPreview("demo"))
files["BBC_HUB/configs/demo.json"] = "invalid"
assert(not w:ConfirmConfigPreview("demo") and calls == 0)
files["BBC_HUB/configs/demo.json"] = "valid-backup"
assert(w:StageConfigPreview("demo"))
Library.Safety.panic = true
assert(not w:ConfirmConfigPreview("demo") and calls == 0) -- política mudou
report = assert(w:StageConfigPreview("demo"))
assert(report.skipped == 1 and #report.changes == 0)
assert(w:ConfirmConfigPreview("demo") and calls == 0 and not state)
Library.Safety.panic = false
assert(w:StageConfigPreview("demo"))
w._configPreview.expires = -1
assert(not w:ConfirmConfigPreview("demo") and calls == 0)
assert(w:StageConfigPreview("demo"))
assert(w:ConfirmConfigPreview("demo") and calls == 1 and state)
assert(not w:ConfirmConfigPreview("demo")) -- confirmação é de uso único
print("profile preview and confirmation OK")
