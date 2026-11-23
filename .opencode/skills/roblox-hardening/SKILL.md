---
name: roblox-hardening
description: Regras de segurança de cliente e APIs atualizadas para Luau/Roblox — never-trust-the-client, validação de remotos, sanitização de entradas, APIs obsoletas vs substitutas, device trust, anti-cheat defensivo. Sem servidor (ServerScriptService/DataStoreService/MarketplaceService) nem Roblox Studio.
---

# Roblox Hardening — Segurança de Cliente e APIs Atualizadas

Regras de segurança para código cliente em Luau/Roblox executado via executor (Delta/UNC) ou em ambiente local. Foco em **never-trust-the-client**, validação de entradas, APIs substituídas e device trust.

**Escopo:** apenas cliente. Não inclui servidor (`ServerScriptService`, `ServerStorage`, `DataStoreService`, `MarketplaceService`, `BadgeService`, etc.) nem Roblox Studio.

---

## 1. Never Trust the Client (Princípio Fundamental)

Um jogador com executor tem **controle total** sobre seu estado local e tráfego de rede. Ele pode:
- Decompilar qualquer `LocalScript`/`ModuleScript` replicado, mesmo que nunca rode no cliente.
- Assumir network ownership do próprio personagem e partes não ancoradas.
- Disparar eventos (`Touched`, `ProximityPrompt`) a qualquer alcance/frequência.
- Modificar posição, física ou interações com o mundo.
- Firear `RemoteEvent`/`RemoteFunction` com argumentos arbitrários.
- Alterar qualquer coisa no DataModel local sem disparar eventos esperados.

**Toda lógica crítica deve ser validada pelo servidor ou rodar exclusivamente nele.** No cliente, valide o que puder mas nunca confie cegamente em dados locais.

---

## 2. Validação de Remotos (Cliente → Servidor)

Todo argumento recebido do cliente deve passar por múltiplas camadas de validação.

### 2.1 Type checking com `typeof()`
```lua
if typeof(itemName) ~= "string" then return end
if typeof(quantity) ~= "number" then return end
-- typeof(item) ~= "Instance" captura payloads de tabela que se passam por instância
```

### 2.2 NaN e Infinito
`NaN` é do tipo `"number"` mas falha todas as comparações. `NaN < 0` é falso, `NaN > 1000000` é falso.
```lua
local function isFiniteNumber(n)
    return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end
```

### 2.3 Validação de instância
Exploiters podem enviar tabelas que imitam instâncias. Sempre use `typeof()` e verifique ancestralidade.
```lua
if typeof(item) ~= "Instance" then return false end
if not item:IsDescendantOf(pastaEsperada) then return false end
```

### 2.4 Sanitização de strings
Strings para uso local devem ser UTF-8 válidas e com tamanho limitado.
```lua
local MAX_LEN = 200
local function sanitizeString(s)
    if type(s) ~= "string" then return nil end
    if #s > MAX_LEN then return nil end
    return s
end
```

### 2.5 Rate limiting no servidor
Sempre implemente cooldowns server-side para ações exploráveis:
```lua
local COOLDOWN = 0.5
local lastActionTime = {}
remote.OnServerEvent:Connect(function(player, action)
    local now = os.clock()
    local last = lastActionTime[player] or 0
    if now - last < COOLDOWN then return end
    lastActionTime[player] = now
    -- processar ação legítima
end)
Players.PlayerRemoving:Connect(function(player) lastActionTime[player] = nil end)
```

---

## 3. Sanitização de Entrada (Input Sanitization)

- Nunca aceite um `Player` vindo do cliente; o primeiro argumento de `OnServerEvent` é o jogador que fireou (engine-injected, não spoofável).
- Valide ranges numéricos (mín/máx, inteiro quando necessário).
- Valide que o alvo está dentro do alcance permitido (`MAX_FIRE_RANGE`, distância do jogador até a origem do tiro).
- Raycast server-side para detecção de hit autoritativa; nunca confie no dano enviado pelo cliente.
- Não use `OnClientInvoke` para operações sensíveis: cliente pode lançar erro, desconectar ou nunca retornar, travando o servidor. Use `RemoteEvent:FireClient()`.

---

## 4. APIs Obsoletas vs Substitutas

Use as substitutas atuais; nunca escreva código novo com membros deprecados.

| Deprecado | Use em vez |
|-----------|------------|
| `wait()` / `spawn()` / `delay()` | `task.wait()` / `task.spawn()` / `task.delay()` |
| `getfenv` / `setfenv` | nada (desabilita otimizações) |
| `table.getn`, `table.foreach` | `#t`, `for k, v in t do` |
| `Ray.new` + `FindPartOnRay*` | `workspace:Raycast(origin, direction, RaycastParams)` |
| `Instance:Remove()` | `Instance:Destroy()` ou `Parent = nil` |
| `GuiObject:TweenPosition` etc. | `TweenService:Create()` |
| `Mouse.KeyDown/KeyUp` | `UserInputService` / Input Action System |
| `Humanoid:LoadAnimation()` | `Animator:LoadAnimation()` |
| `Model:SetPrimaryPartCFrame()` | `Model:PivotTo()` |
| `BasePart.Velocity` / `RotVelocity` | `AssemblyLinearVelocity` / `AssemblyAngularVelocity` |
| `BodyVelocity`, `BodyGyro`, etc. | `LinearVelocity`, `AlignOrientation`, `VectorForce`, `AngularVelocity` |
| `TeleportService:Teleport` / `ReserveServer` | `TeleportService:TeleportAsync()` + `TeleportOptions.ReservedServerId = HttpService:GenerateGUID(false)` |
| `MarketplaceService:GetProductInfo()` | `GetProductInfoAsync()` |
| `BadgeService:AwardBadge()` | `AwardBadgeAsync()` |
| `Chat` service / `Chat:FilterStringForPlayerAsync` | `TextChatService` + `TextService:FilterStringAsync` |
| `PhysicsService:CreateCollisionGroup` | `workspace:RegisterCollisionGroup` |
| `UserInputService.ModalEnabled` | `GuiService.TouchControlsEnabled` |

---

## 5. Device Trust (IntegrityService, engine 0.745+)

O engine avalia o **device** de cada jogador ao entrar. `Player.DeviceTrustLevel` é um de:
`Pending` (ainda verificando; todo mundo começa aqui), `Unknown` (plataforma não suportada ou erro), `None` (falhou), `Standard` (algumas checagens passaram), `Full` (todas passaram).

Regras:
- **Nunca compare níveis como números** (`level.Value > None.Value` exclui Windows, Mac, iOS, Xbox, PlayStation que reportam `Unknown`). Use uma lista explícita de níveis permitidos.
- Trate `Pending` como não confiável.
- Decida no servidor, nunca no cliente (o cliente pode ser contornado).
- O nível muda **uma vez**, após `PlayerAdded`, e pode ficar `Pending` toda a sessão.
- Roblox não verifica devices em Studio; não teste a política de confiança lá.
- A device trust avalia o **dispositivo**, não o jogador: validação server-side continua sendo o que impede exploits.

---

## 6. Anti-Cheat Defensivo (Design Over Detection)

Projete sistemas onde trapacear seja impossível ou não traga vantagem, em vez de detectar depois.

| Cenário | Reativo (menos efetivo) | Defensivo (mais efetivo) |
|---------|-------------------------|--------------------------|
| Obby: teleport para o final | Detectar tempo impossível | Checkpoints sequenciais validados pelo servidor |
| Combate: dano impossível | Filtrar dano impossível | Servidor calcula todo dano com stats server-side |
| Economia: duplicação rápida | Detectar padrões duplicados | Cooldowns server-side + validar inventário |
| Shooter: bot de kills | Código complexo de bot detection | Remover ganhos de kills em personagens recém-spawnados |

Heurísticas server-side de movimento:
- Distância-tempo para checagem de velocidade (projetar no plano XZ para movimento no chão).
- Acumulador tipo leaky-bucket para tolerância a burst com detecção de violação sustentada.
- Contabilizar latência de rede média nas atualizações de posição.
- Sistema de isenção para teleportes legítimos.

**Rubber-banding:** quando o servidor detecta posição inválida, teleporte o personagem de volta à última posição válida server-side.

---

## 7. Proteção contra Decompilação

Qualquer `LocalScript`, `Script` em contexto cliente ou `ModuleScript` replicado **pode ser decompilado**, mesmo desabilitado ou nunca requerido.
- Nunca coloque senhas, chaves de API, webhooks do Discord ou lógica de negócio server-side em módulos compartilhados.
- `ReplicatedStorage` replica para todo cliente; nada secreto lá.
- Inspecione assets de terceiros antes de usar; eles podem conter backdoors.
- Não confie em `Sandboxed = true` sozinho; o sistema de capacidades é experimental e off por padrão.

---

## 8. Ciclo de Vida e Limpeza (Cliente)

- Desconecte **todas** as conexões (`:Disconnect()`) ao desligar ou no `Unload`.
- Capture referências antes de `CharacterRemoving`/`Destroying` (onde `Parent` já pode ser `nil`).
- Mantenha uma tabela global de cleanup e itere-a ao destruir, sem deixar conexões órfãs.
- `Highlight` tem limite de renderização simultânea (~31); não crie um por alvo sem limitar.
- Nunca use `task.wait` dentro de loops `RenderStepped`/`Heartbeat`.

---

## 9. Inputs Híbridos (PC + Mobile)

- Use `Activated` para cliques simples (cobre mouse e touch).
- Para arraste de sliders/janelas, use `InputBegan`/`InputChanged` tratando `MouseButton1` e `Touch`.
- Suporta *Keybinds* no PC via `UserInputService.InputBegan`, ignorando `gameProcessedEvent`.
- Nunca dependa de teclado no Mobile: todo atalho de teclado precisa de equivalente em botão na tela.

---

## 10. Checklist Obrigatório (Cliente)

- [ ] Nenhuma checagem por nome de executor (`if syn then`, `if KRNL_LOADED then`). Use detecção de capacidades (`Caps`) com fallback.
- [ ] Toda chamada de API de executor envolta em `pcall` com fallback nativo.
- [ ] Nenhum segredo (senha, cookie `.ROBLOSECURITY`, webhook) no código cliente.
- [ ] Nenhum `loadstring` de URL de terceiros.
- [ ] APIs substituídas não aparecem em código novo.
- [ ] Validação de tipo, range e NaN em toda entrada remota.
- [ ] Device trust decidido no servidor, com lista explícita de níveis permitidos.
- [ ] Limpeza de conexões e objetos visuais no `Unload`.
