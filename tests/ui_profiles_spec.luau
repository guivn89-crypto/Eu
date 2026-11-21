local current = false
Library.Registry.flag = { name = "flag", get = function() return current end, set = function(v) current = v end }
local win = setmetatable({ _ready = true, _cfgName = "default" }, { __index = Window })
local initial = win:_snapshot()
win._lastState = stable(initial)
current = true
writeFails = true
win:_autoSaveNow()
assert(writeAttempts == 1 and win._lastState == stable(initial))
writeFails = false
win:_autoSaveNow()
assert(writeAttempts == 2 and win._lastState == stable(win:_snapshot()))
mockDecoded = { v = 2, data = { flag = false } }
rawFile = "old-valid"
current = false
win:_autoSaveNow()
assert(writes["BBC_HUB/configs/default.json.bak"] == "old-valid")
assert(writes["BBC_HUB/configs/default.json"] == "json")
local savedAttempts = writeAttempts
writeFails = true
current = true
win:_autoSaveNow()
assert(writeAttempts == savedAttempts + 1) -- falha no backup impede escrever o arquivo principal
assert(win._lastState ~= stable(win:_snapshot()))
writeFails = false
savedAttempts = writeAttempts
mockDecoded = { v = 99, data = {} } -- árvore válida é preservada mesmo se a versão for desconhecida
rawFile = string.rep("x", Library.ProfileGuard.MAX_BYTES + 1)
current = true
win:_autoSaveNow()
assert(writeAttempts == savedAttempts) -- não sobrescreve arquivo inválido
win._autoSaveBlocked = true
win:_autoSaveNow()
assert(writeAttempts == savedAttempts)
win._autoSaveBlocked = false
local count = decodeAttempts
assert(not win:ImportConfig(string.rep("x", Library.ProfileGuard.MAX_BYTES + 1)))
assert(decodeAttempts == count) -- texto longo é recusado antes do parser
mockDecoded = { v = 2, data = { flag = "wrong" } }
assert(not win:ImportConfig("profile") and current)
mockDecoded = { v = 2, data = { flag = false } }
assert(win:ImportConfig("profile") and not current)
rawFile = string.rep("x", Library.ProfileGuard.MAX_BYTES + 1)
count = decodeAttempts
assert(not win:LoadConfig("default", true) and decodeAttempts == count)
print("UI profile integration OK")
