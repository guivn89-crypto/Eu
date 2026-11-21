Actions.stopRiskyWork()
for _, v in pairs(MV) do assert(v == false) end
assert(preFallHealth == nil and not swapOn and not autoLoot)
assert(Actions.swapToken == 3 and Actions.lootToken == 4)
for _, v in pairs(COMBAT) do assert(v == false) end
assert(not WORLD.grama and not WORLD.minas and not WORLD.jogadores)
assert(calls.restoreWalk == 1 and calls.restoreSwim == 1 and calls.stopOffset == 1)
assert(calls.aim == 1 and calls.antiAim == 1 and calls.under == 1 and calls.peek == 1 and calls.throw == 1)
assert(calls.grass == 1 and calls.mines == 1 and calls.effects == 1) -- continua após erro em stopFly
print("emergency stop OK")
