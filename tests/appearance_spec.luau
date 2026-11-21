local A = Library.Appearance
assert(A.theme == "Orange" and not A.motion and not A.skipIntro)
assert(not A:setColor({0, 0/0, 1}, true))
assert(not A:setColor({0, 2, 1}, true))
assert(not Library:SetTheme("unknown", true))
local observed
table.insert(A.colorListeners, function(c) observed = c[2] end)
assert(A:setColor({0.2, 0.4, 0.6}, true) and observed == 0.4)
assert(Library:SetTheme("Custom", true))
assert(Library.Theme.Accent.R == 0.2)
assert(A:setFlag("contrast", true, true) and Library.Theme.Text.R == 1)
assert(A:setFlag("motion", true, true) and Library.ReduceMotion)
assert(A:setFlag("skipIntro", true, true) and A.skipIntro)
assert(not A:setFlag("unsafe", true, true))
assert(Library.Registry["__appearance/theme"].validate("Custom"))
assert(not Library.Registry["__appearance/theme"].validate("other"))
assert(A:save() and files["BBC_HUB/appearance.json"] == "encoded")
local valid = {v = 1, theme = "Orange", color = {1, 0.5, 0}, contrast = false, motion = false, skipIntro = false}
decoded = valid
files["BBC_HUB/appearance.json"] = "prior"
assert(A:load() and A.theme == "Orange" and A.color[2] == 0.5 and not A.motion)
assert(A:save() and files["BBC_HUB/appearance.json.bak"] == "prior")
files["BBC_HUB/appearance.json"] = "corrupt"
decoded = nil
assert(not A:load() and not A.writable)
assert(not A:save() and files["BBC_HUB/appearance.json"] == "corrupt")
print("appearance validation and backup OK")
