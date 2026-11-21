local refreshed = {}
function Actions.refreshAdjustment(key) refreshed[#refreshed + 1] = key end
assert(Actions.setAdjustment("speed", 900) and Actions.getAdjustment("speed") == 4)
assert(Actions.setAdjustment("speed", -5) and Actions.getAdjustment("speed") == 1)
assert(not Actions.setAdjustment("speed", 0/0))
assert(not Actions.setAdjustment("speed", math.huge))
assert(not Actions.setAdjustment("notReal", 2))
assert(Actions.setAdjustment("hotbarSlots", 2.9) and Actions.getAdjustment("hotbarSlots") == 2)
local ui = {sliders = {}, labels = {}}
function ui:Slider(opts) self.sliders[#self.sliders + 1] = opts end
function ui:Label(opts) self.labels[#self.labels + 1] = opts end
for name, descriptors in pairs(SETTINGS) do
    assert(GEARS[name], name)
    table.clear(ui.sliders)
    buildSettings(name)(ui)
    assert(#ui.sliders == #descriptors, name)
    for i, spec in ipairs(descriptors) do
        local slider = ui.sliders[i]
        local entry = Actions.adjustments[spec[1]]
        assert(entry and slider.Min == entry[2] and slider.Max == entry[3] and slider.Default >= entry[2] and slider.Default <= entry[3], name)
        slider.Callback(slider.Min)
        assert(Actions.getAdjustment(spec[1]) == slider.Min, name)
        slider.Callback(slider.Max)
        assert(Actions.getAdjustment(spec[1]) == slider.Max, name)
    end
end
buildSettings("Mochila personalizada")(ui)
assert(#ui.labels > 0)
table.clear(ui.sliders)
buildSettings("Disparo")(ui)
ui.sliders[1].Callback(35)
assert(soundName == "Disparo" and soundValue == 35)
assert(#refreshed > 20)
print("settings integration OK")
