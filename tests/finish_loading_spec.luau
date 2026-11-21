local function window()
    local w = setmetatable({_introActive = false, _pendingPrebuild = 2}, {__index = Window})
    function w:CaptureDefaults() self.captured = true end
    function w:GetAutoload() return nil end
    function w:StartAutoSave() self.autosave = true end
    return w
end
local w = window()
onWait = function() w._pendingPrebuild = 0 end
w:FinishLoading()
assert(w._loaded and w.captured and w._ready and w.autosave)
local failed = window(); failed._pendingPrebuild = 0; failed._prebuildFailed = true
failed:FinishLoading()
assert(not failed._loaded and failed._autoSaveBlocked and not failed.captured and not failed.autosave)
local slow = window(); onWait = function() end; now = 0
slow:FinishLoading()
assert(not slow._loaded and slow._autoSaveBlocked and not slow.captured and not slow.autosave)
local closed = window(); onWait = function() closed._destroyed = true end; now = 0
closed:FinishLoading()
assert(not closed._loaded and not closed.captured and not closed.autosave)
print("prebuild completion and autoload guard OK")
