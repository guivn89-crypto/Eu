---
name: performance-optimization
description: >
  Roblox performance optimization patterns: part count reduction, MeshParts over CSG unions,
  CollisionFidelity/RenderFidelity settings, rendering optimization (shadows, LOD, transparency),
  script optimization (reference caching, local variables, table reuse, --!native, buffer/vector),
  connection cleanup, Parallel Luau with Actors (task.desynchronize, BindToSimulationParallel),
  object pooling, content streaming (StreamingEnabled), MicroProfiler usage, device testing,
  Collections live groups, SceneAnalysisService/HeapProfilerService memory measurement.
  Use when optimizing frame rate, memory, join times, or debugging performance bottlenecks.
---

# Roblox Performance Optimization

Comprehensive patterns for optimizing Roblox experiences — from part count and rendering to script execution, parallel processing, memory management, and profiling tools.

## When to Use

- Optimizing frame rate (target: 60 FPS = 16.67ms/frame)
- Reducing memory usage and preventing leaks
- Improving join/load times
- Debugging performance bottlenecks with MicroProfiler
- Implementing object pooling for frequently created/destroyed objects
- Using Parallel Luau for CPU-intensive work
- Enabling and configuring content streaming
- Measuring scene cost with SceneAnalysisService

---

## 1. Part Count Optimization

**Core principle:** Fewer objects = fewer draw calls = higher FPS.

| Practice | Impact |
|----------|--------|
| Anchor all static parts | Unanchored parts incur physics cost every frame |
| Merge decorative geometry | Combine small parts into single MeshParts |
| Reduce mechanism complexity | Minimize constraints/joints in assemblies |
| Set `Model.LevelOfDetail = SLIM` | Distant models use simplified representation (plugin-only) |
| Cull distant objects | Spawn NPCs only when nearby; despawn out of range |

**Draw call instancing:** Identical MeshParts (same `MeshContent` + `SurfaceAppearance`/`TextureContent` + material) collapse into single draw call. Ensure duplicates share asset IDs — import once, duplicate in Studio.

```luau
-- Audit mesh duplication
for _, descendant in workspace:GetDescendants() do
    if descendant:IsA("MeshPart") then
        print(descendant.Name .. ", " .. descendant.MeshId)
    end
end
```

---

## 2. MeshParts Over UnionOperations

**Use MeshParts (from Blender/Maya) instead of CSG UnionOperations:**
- Instancing works for MeshParts, not documented for unions
- MeshParts support `SurfaceAppearance` for PBR materials
- MeshParts have configurable `CollisionFidelity` and `RenderFidelity` (set at author time)

---

## 3. CollisionFidelity & RenderFidelity Settings

| CollisionFidelity | Cost | Use Case |
|-------------------|------|----------|
| `Box` | Lowest | Small parts, non-interactable, non-collidable |
| `Hull` | Low | Small-medium convex shapes |
| `Default` | Medium | General purpose |
| `Precise` | Highest | Only when pixel-perfect collision required |

**Critical:** These properties are **plugin-only** (`PluginOrOpenCloud` capability). Game Scripts **cannot** write them — even reading `Model.LevelOfDetail` fails.

```luau
-- Command bar / plugin ONLY (needs PluginOrOpenCloud capability)
for _, part in CollectionService:GetTagged("Decorative") do
    if part:IsA("MeshPart") then
        part.CollisionFidelity = Enum.CollisionFidelity.Box
        part.CanCollide = false
        part.CanTouch = false
        part.CanQuery = false
    end
end
```

**Runtime workaround:** Use `AssetService:CreateMeshPartAsync(meshContent, { CollisionFidelity = Box, RenderFidelity = Performance })` + `part:ApplyMesh(result)` — yields, rejects large meshes (>2048 studs).

---

## 4. Rendering Optimization

### Shadows
- `BasePart.CastShadow = false` on small parts
- Disable `Light.Shadows` on lights that don't need shadow casting
- Limit light range/angle
- Disable shadows on moving objects
- Per-room lighting for indoor environments

### Level of Detail (LOD)
- `MeshPart.RenderFidelity = Automatic` or `Performance` — engine uses lower-poly at distance
- `Model.LevelOfDetail = SLIM` for distant models (plugin-only)
- `Workspace.EnableSLIMAvatars` for optimized distant avatars (Properties window, `NotScriptable`)

### Transparency Overdraw
Overlapping semi-transparent objects force multiple pixel renders — remove/reduce layered transparent parts.

### Texture Memory
Based on pixel count, not file size. 1024×1024 = 4× memory of 512×512. Size textures for display size.

---

## 5. Script Optimization

### Cache References
```luau
-- BAD: repeated lookups every frame
RunService.Heartbeat:Connect(function()
    local character = workspace:FindFirstChild("PlayerCharacter")
    local humanoid = character and character:FindFirstChild("Humanoid")
end)

-- GOOD: cache references, update on change
local character, humanoid
player.CharacterAdded:Connect(function(c)
    character = c
    humanoid = c:WaitForChild("Humanoid")
end)
RunService.Heartbeat:Connect(function()
    if humanoid and humanoid.Health > 0 then -- cached ✅
    end
end)
```

### Hoist Lookups Outside Loops
```luau
-- BAD
for i = 1, #items do
    local dist = (items[i] - workspace.CurrentCamera.CFrame.Position).Magnitude
end

-- GOOD
local cameraPos = workspace.CurrentCamera.CFrame.Position
for i = 1, #items do
    local dist = (items[i] - cameraPos).Magnitude
end
```

### Reuse Tables (Avoid GC Pressure)
```luau
-- BAD: new table every frame
RunService.Heartbeat:Connect(function()
    local results = {}
end)

-- GOOD: reuse with table.clear()
local results: { BasePart } = {}
RunService.Heartbeat:Connect(function()
    table.clear(results)
end)
```

### Luau 0.735+ Fast Execution
- **`LOP_FASTPCALL`**: ~2× lower `pcall` overhead (call itself, not free)
- **`--!native`**: Server scripts + Android clients **only** (not Windows/Mac/iOS LocalScripts). Increases startup time, extra memory, silent compilation stop at size limit. Use `@native` on individual functions for narrower scope.
- **Buffer & Vector Types**: `buffer.create()` for binary serialization; `vector.create()` for SIMD math without GC.
- **Frozen metatables**: Metamethod lookup cache added — freeze metatables for free dispatch speedup.

### Thick Casts: `RaycastParams.Margin` (Engine 0.746)
```luau
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = ignore
params.Margin = margin -- sphere cast radius
return Workspace:Raycast(origin, direction, params)
```
- `Margin` makes Raycast behave as sphere cast of that radius
- Also grows `Spherecast`, `Blockcast`, `Shapecast`
- Result describes a sphere: `Position` on surface, `Normal` points to sphere center, `Distance` = sphere travel distance

### Avoid Expensive Operations on RunService Events
Use appropriate modern events:
| Order | Modern Event | Legacy | Runs On | Use For |
|-------|-------------|--------|---------|---------|
| 1 | `PreRender` | `RenderStepped` | Client only | Camera, UI |
| 2 | `PreAnimation` | — | Client + Server | Animation prep |
| 3 | `PreSimulation` | `Stepped` | Client + Server | Input, pre-physics |
| 4 | `PostSimulation` | `Heartbeat` | Client + Server | Post-physics, game logic |

---

## 6. Connection Cleanup (Memory Leak Prevention)

Engine **never** GCs events connected to instances + values in callbacks. Active connections keep everything alive — #1 memory leak source.

```luau
local Players = game:GetService("Players")
local playerConnections: { [Player]: { RBXScriptConnection } } = {}

Players.PlayerAdded:Connect(function(player)
    local connections: { RBXScriptConnection } = {}
    table.insert(connections, player.CharacterAdded:Connect(function(character) end))
    playerConnections[player] = connections
end)

Players.PlayerRemoving:Connect(function(player)
    local connections = playerConnections[player]
    if connections then
        for _, conn in connections do conn:Disconnect() end
    end
    playerConnections[player] = nil
end)
```

### ServerLowMemoryWarning
```luau
game.ServerLowMemoryWarning:Connect(function()
    warn("[Memory] Low memory! Flushing caches...")
    -- Evict spatial caches, flush query tables, trim buffer pools
end)
```

---

## 7. Parallel Luau with Actors

### Actor as Unit of Parallel Execution
- Scripts under **same Actor** = sequential
- Scripts under **different Actors** = true parallel (multiple CPU cores)
- Place Actors in appropriate containers or replace top-level entities (NPCs)

### Modern Parallel Callbacks (0.746+)
```luau
-- Script must be under an Actor
RunService:BindToSimulationParallel(function()
    -- Runs in PARALLEL (read DataModel, limited writes)
    -- ... expensive computation ...
end, frequency, priority)

RunService:BindToAnimationParallel(function() end)
```

### task.desynchronize() / task.synchronize()
```luau
-- Script under Actor
RunService.Heartbeat:Connect(function()
    task.desynchronize()
    -- PARALLEL: read DataModel, limited writes
    -- ... expensive computation ...
    
    task.synchronize()
    -- SERIAL: modify instances freely
    -- ... apply results ...
end)
```

**Alternative:** `signal:ConnectParallel()` starts callback already in parallel (no `desynchronize` needed).

### Thread Safety Levels
| Level | Properties | Functions |
|-------|-----------|-----------|
| Unsafe | Cannot read/write in parallel | Cannot call in parallel |
| Read Parallel | Read only in parallel | N/A |
| Local Safe | Read/write within same Actor | Call within same Actor |
| Safe | Read/write freely | Call freely |

### Master-Worker Pattern
```luau
-- Master creates workers, distributes via Actor:SendMessage()
local actor = script:GetActor()
if actor == nil then -- Master
    for i = 1, WORKER_COUNT do
        local worker = Instance.new("Actor")
        script:Clone().Parent = worker
        worker.Parent = script
    end
    task.defer(function()
        for taskIndex = 1, 100 do
            workers[rand:NextInteger(1, #workers)]:SendMessage("DoWork", taskIndex)
        end
    end)
    return
end

-- Worker
actor:BindToMessageParallel("DoWork", function(taskIndex)
    task.desynchronize()
    local result = taskIndex * taskIndex
    task.synchronize()
    print("Task", taskIndex, "result:", result)
end)
```
**Best practice:** Use more Actors than CPU cores (e.g., 64 on 4-core) for load balancing.

---

## 8. Object Pooling Pattern

Minimize instantiation/destruction cost (especially Humanoids, layered clothing).

```luau
-- ModuleScript "ObjectPool"
local ObjectPool = {}
ObjectPool.__index = ObjectPool

type PoolData<T> = {
    available: { T },
    inUse: { [T]: boolean },
    factory: () -> T,
    reset: (item: T) -> (),
}

function ObjectPool.new<T>(factory: () -> T, reset: (item: T) -> (), preWarm: number?)
    local data: PoolData<T> = { available = {}, inUse = {}, factory = factory, reset = reset }
    for _ = 1, preWarm or 0 do table.insert(data.available, factory()) end
    return setmetatable(data, ObjectPool)
end

function ObjectPool.acquire<T>(self: Pool<T>): T
    local item = table.remove(self.available) or self.factory()
    self.inUse[item] = true
    return item
end

function ObjectPool.release<T>(self: Pool<T>, item: T)
    if not self.inUse[item] then return end
    self.inUse[item] = nil
    self.reset(item)
    table.insert(self.available, item)
end

return ObjectPool
```

**NPC Pooling Usage:**
```luau
local npcPool = ObjectPool.new(function()
    return npcTemplate:Clone()
end, function(npc)
    npc.Parent = ServerStorage
    local humanoid = npc:FindFirstChildOfClass("Humanoid")
    if humanoid then humanoid.Health = humanoid.MaxHealth end
end, 10)

local npc = npcPool:acquire()
npc:PivotTo(CFrame.new(0, 5, 0))
npc.Parent = workspace
-- Return to pool instead of destroying:
npcPool:release(npc)
```

---

## 9. Content Streaming (StreamingEnabled)

Enable in Properties (Workspace → `StreamingEnabled`) — **not scriptable** (plugin-only).

**Key Properties (plugin-only):**
- `StreamingMinRadius` — min distance always streamed
- `StreamingTargetRadius` — target distance engine maintains
- `StreamingIntegrityMode` — behavior when required content missing

**Per-model modes (`Model.ModelStreamingMode`):**
- `Default` — distance-based
- `Atomic` — entire model as unit
- `Persistent` — always loaded (use sparingly)
- `PersistentPerPlayer` — always loaded for specific players

**Script considerations:** Instances may not exist — use `WaitForChild()` or `ModelStreamingMode.Atomic`. `GetChildren()` only lists streamed-in instances.

**Join time optimization:**
- Enable streaming (default for new places)
- Keep only join-essential assets in `ReplicatedStorage`; rest in `ServerStorage`
- Minimal `ReplicatedFirst` (loading screen only)
- Preload only what must not pop in; offer Skip Loading button
- Measure with stopwatch; Studio Settings → Network → Print Join Size Breakdown

---

## 10. MicroProfiler Usage

**Open:** `Ctrl+F6` / `⌘+F6` — primary bottleneck identification tool.

**Key Scopes:**
| Scope | Meaning |
|-------|---------|
| `RunService.PreRender` | PreRender event code |
| `RunService.PreSimulation` | Stepped event code |
| `RunService.PostSimulation` | Heartbeat event code |
| `physicsStepped` | Overall physics |
| `worldStep` | Discrete physics steps/frame |
| `Prepare and Perform` | Overall rendering |
| `ShadowMapSystem` | Shadow mapping cost |
| `updateInvalidatedFastClusters` | Avatar instantiation/modification |
| `ProcessPackets` | Network packet processing |

**Custom Profiling:**
```luau
debug.profilebegin("MyExpensiveOperation")
-- ... work ...
debug.profileend()
```

**LibMP ALL-SCOPES.md:** `https://raw.githubusercontent.com/Roblox/libmp/main/docs/ALL-SCOPES.md`

---

## 11. Device Testing

- **Mobile/low-end:** Significantly less memory/CPU — test with Device Emulator + physical devices
- **Target 60 FPS** (16.67ms/frame)
- **Developer Console (F9):** `LuaHeap`, `InstanceCount`, `PlaceScriptMemory`
- **Render Stats (Shift+F2):** Draw calls, frame timing in-client
- Test with lower graphics quality
- MCP: `skill("rbx-device-simulator-lua")` for device switching, `skill("rbx-network-simulator")` for latency/loss

---

## 12. Collections: Live Instance Groups

`CollectionService:CreateCollection(query, root?)` — tracks matching descendants, auto-attaches callbacks on join/leave. Full release (was beta).

```luau
local killBricks = CollectionService:CreateCollection("BasePart.KillBrick")

function killBricks.OnAdded(brick: BasePart)
    brick.Material = Enum.Material.Neon
end

function killBricks.OnTouched(brick, other)
    local humanoid = other.Parent and other.Parent:FindFirstChildOfClass("Humanoid")
    if humanoid then humanoid.Health = 0 end
end
```
- `OnAdded` runs for existing members too; `OnRemoved` on tag removal, `Enabled=false`, `Destroy()`
- Each callback assigned once; bad queries fail at creation
- `OnHeartbeat`/`ForEach` cannot yield; `OnAdded` can yield
- Queries support `:in-radius(studs, selector)` — evaluated post-simulation

---

## 13. Measuring Memory & Scene Cost

### SceneAnalysisService (game Script accessible)
```luau
-- Each returns { Name, Children, Size } nested tables
SceneAnalysisService:GetInstanceCompositionAsync()
SceneAnalysisService:GetScriptMemoryAsync()
SceneAnalysisService:GetUnparentedInstancesAsync()
SceneAnalysisService:GetAnimationMemoryAsync()
SceneAnalysisService:GetAudioMemoryAsync()
SceneAnalysisService:GetTriangleCompositionAsync() -- camera-dependent, includes Triangles/Drawcalls
```
- `GetCollisionGeometryMemoryAsync` still fails ("not enabled")

### HeapProfilerService (plugin-only)
```luau
-- Via execute_luau in Server datamodel during playtest
HeapProfilerService:ServerRequestDataAsync() -- returns 1.6 MB JSON with Report/Refs
```
- In `Edit` datamodel: hangs until timeout
- For leaks: snapshot before/after action, compare

---

## 14. Legacy Patterns to Migrate

| Legacy | Modern |
|--------|--------|
| `spawn()` / `wait()` | `task.spawn()` / `task.delay()` / `task.wait()` |
| `BodyVelocity` | `LinearVelocity` |
| `BodyPosition` | `AlignPosition` |
| `BodyGyro` | `AlignOrientation` |
| `BodyForce` | `VectorForce` |
| `BodyAngularVelocity` | `AngularVelocity` |
| `BodyThrust` | `VectorForce` |
| `RocketPropulsion` | `LineForce` |
| Manual character destroy | `Workspace.PlayerCharacterDestroyBehavior = Enabled` (Properties) |
| Single Heartbeat game loop | Appropriate events + `task.wait()` |
| Fixed 240Hz physics | `Workspace.PhysicsSteppingMethod = Adaptive` (Properties) |

---

## Related Skills
- `roblox-dev-skill` — Parent skill with full Roblox/Luau reference
- `ui-systems` — UI performance (CanvasGroup, TextScaled, object pooling)
- `luau-performance` — Pure Luau language performance (tables, iteration, compiler behavior)