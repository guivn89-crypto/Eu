-- Inicializador real de ações e política de pânico injetados pelo runner.
assert(type(Actions.player['Hack de velocidade']) == 'function')
assert(type(Actions.world['Sem grama']) == 'function')
assert(type(Actions.extra['Barra rápida']) == 'function')
assert(type(Actions.combat['Previsão']) == 'function')
Actions.combat['Previsão'](true); assert(Actions.COMBAT.predict == true)
Actions.combat['Previsão'](false); assert(Actions.COMBAT.predict == false)
Actions.combat['Alvo fixo'](true); assert(Actions.COMBAT.lock == true)
Actions.combat['Ignorar obstáculos na mira'](false); assert(Actions.COMBAT.throughWalls == false)
assert(Library.Safety:allow('Hack de velocidade', true))
assert(pcall(Actions.player['Hack de velocidade'], true))
assert(pcall(Actions.player['Hack de velocidade'], false))
Library.Safety.panic = true
assert(Actions.player['Hack de velocidade'](true) == false)
Library.Safety.panic = false
assert(pcall(Actions.player['Hack de velocidade'], true))
assert(pcall(Actions.player['Hack de velocidade'], false))
print('existing action mappings and normal activation remain available')
