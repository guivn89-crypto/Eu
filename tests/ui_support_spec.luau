local ui = Library.UISupport
assert(ui.normalize("ПРИВЕТ ЁЖ") == "привет ёж")
assert(ui.normalize("ÁREA DO MENU") == "área do menu")
assert(ui.normalize("简体中文 ESP") == "简体中文 esp")
assert(ui.normalize(string.char(255)) == string.char(255))
local white, black = {R=1,G=1,B=1}, {R=0,G=0,B=0}
assert(math.abs(ui.contrast(white, black) - 21) < 0.00001)
assert(ui.contrast(white, white) == 1)
assert(ui.contrast({R=0/0,G=0,B=0}, white) == nil)
assert(ui.compact(390, 844, true) and not ui.compact(1000, 600, true))
assert(not ui.compact(390, 844, false) and not ui.compact(0, 844, true))
print("unicode search, contrast and compact layout OK")
