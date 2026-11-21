assert(Actions.alive and type(Actions.player) == "table" and type(Actions.world) == "table")
assert(type(Actions.paintTerrain) == "function" and type(Actions.applyLighting) == "function")
assert(type(buildProfile) == "function" and type(Actions.stopRiskyWork) == "function")
print("actions initializer startup OK")
