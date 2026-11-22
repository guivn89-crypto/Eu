---
name: roblox-studio-workflow
description: Use when developing, editing, or testing a Roblox (Luau) game — the disk + Rojo + selene + Studio-MCP dev loop, the sync cycle (solo_playtest, eval_server_runtime / eval_client_runtime, get_runtime_logs), checking Rojo really synced, multi-place universes (lobby + game) with shared modules, a project CLAUDE.md as the system index, StreamingEnabled remote pitfalls, parallel Claude sessions sharing one Studio, who publishes, and the engine gotchas that waste hours (200-local ceiling, stale-code syncs, duplicate-instance drift). Load at the start of any Roblox coding/testing task.
---

# Roblox Studio dev workflow (Rojo + selene + Studio MCP)

Author code on disk, sync with Rojo, test through the Studio MCP (`mcp__robloxstudio__*`).

Sibling skills:
- **roblox-studio-mcp**: tool menu and MCP gotchas.
- **roblox-studio-verification**: screenshots, recording motion, device checks, profiling.
- **roblox-cross-device-ui**: phone / tablet / pad / PC GUI.
- **roblox-game-architecture**: system design, admin panel, lobby + game places, funnels.
- **roblox-game-audio**: music, SFX, voice.
- **roblox-generated-art**: icons, textures, meshes from scripts.
- **roblox-low-end-performance**: what costs frames on phones and how to measure it.
- **roblox-release-safety** / **roblox-live-ops**: publishing, and running the live experience.

## Golden rules
- **Author all Luau on disk** (`src/`), never in Studio. Rojo is the single source of truth. Editing a synced script in Studio creates **duplicate instances** on the next sync. The one exception is fixing a dropped patch (below).
- **Rojo manages scripts only.** Keep Workspace (builds, models) and StarterGui (all GUI) **out of the Rojo tree**. They are built by hand in Studio or Blender and saved in the place file. Scripts find existing objects and drive them; they never build maps or GUI. This is the user's standing preference: ask before deviating.
- **Assets go through Asphalt** (`roblox-assets-asphalt`): files on disk, `asphalt sync`, then `Assets.<folder>.<name>` in code. No hand-pasted `rbxassetid://` literals. If a project has no `asphalt.toml`, set it up first.
- **`--!strict` + tabs** (match house style). When an Edit `old_string` fails on whitespace, copy the exact leading tabs.
- **Lint after every change**: `selene src` (or `~/.rokit/bin/selene src`), 0 errors / 0 warnings. Toolchain pinned in `rokit.toml` (`rokit install`). selene misses the runtime traps below.

## Keep a project CLAUDE.md as the system index
The most valuable file in a big Roblox project: **one bullet per system**, each saying:
- where it lives (`server/X`, `client/Y`, the Studio GUI path),
- its API (`X.add(player, n)`, attributes it sets, remotes),
- its tuning (`Config.X`) and its **test hooks** (`X.spawnNow()`, `failSaves`, admin buttons),
- the rule other code must follow ("anything that hurts players calls `Life.damage`", "new menus call `Panels.open`").

Update the bullet in the same change that alters the system. Then a fresh session (or a parallel one) finds the owner of a concern in seconds instead of re-reading 50 modules, and doesn't build a second copy of something. Also keep project facts there: place ids, universe id, Rojo ports, the MCP `instance_id`s.

**Keep it an index, not the history.** One project's `CLAUDE.md` grew to ~410 KB in three weeks (every bullet kept
every tuning change, date, measurement and "verified on" note), and it loads into every session's context. Rules
that keep it useful:
- Each system bullet: 3-6 lines (where, API, tuning key, test hooks, the rule for other code), plus a link to
  `docs/systems/<system>.md` for the long story (why each number is what it is, verification notes, before / after
  measurements, rejected options with the user's reasons).
- Dated decisions and "the user said" go in the system doc; the bullet keeps only the current rule
  ("don't add a tutorial step before the first sale").
- History of numbers lives in `analytics/CHANGES.md`, not here.
- When a bullet passes ~10 lines, move the detail out in the same change.

## The sync cycle (get this wrong and you test stale code)
**Rojo only applies patches in EDIT mode, not during a playtest.** Edits made while playing land when it stops.
1. `solo_playtest` `action: "stop"` (check `action: "status"` first: the playtest may not be yours, see parallel sessions).
2. Wait ~10 s for Rojo to flush.
3. **Check the sync really landed**: `grep_scripts` for a string you just added (or `get_script_source`) in each edited script.
4. `solo_playtest` `action: "start", mode: "play"`. Read the result before doing anything else. If start failed ("already running"), any eval you send lands in someone else's playtest.
5. `get_runtime_logs` (`filter`, `tail`, `since`) to confirm a clean boot before testing.

**Rojo can silently drop one file's patch.** Every other edit syncs, one script stays stale, and the playtest fails with "attempt to call a nil value". If step 3 shows a script without the new string, set **that same instance's** Source to the exact disk content (`set_script_source` on its path). Don't create a new instance. If the plugin shows `[Rojo-Warn] Disconnected`, nothing syncs until the user reconnects it.

Duplicate instances: Rojo plugin → Disconnect → delete the synced roots (`ReplicatedStorage.Shared`, `ServerScriptService.Server`, `StarterPlayerScripts.Client`) → Connect once.

**Quick successive edits to one file can be dropped** even with a healthy connection: after three Edits to one script within seconds, Studio kept the second-to-last version. Compare `#Source` in Studio with `wc -c` on disk after a burst of edits; `touch` doesn't help (same content), a real change and back does.

### Rojo connection gotchas
- **Ports are not reserved.** Another project's `rojo serve` may hold the port a Studio panel defaults to, and a
  Studio connected to it gets the other game's scripts. Before connecting: `pgrep -fl "rojo serve"`, the process cwd
  (`lsof -a -p <pid> -d cwd`) and `curl -s localhost:<port>/api/rojo` (its `projectName`). Never kill another
  project's server without the user's OK; use free ports and tell the user.
- **Proof of sync**: MCP `get_connected_instances` shows `dataModelName` = the Rojo project name once synced; a
  throwaway comment + `grep_scripts` proves patches flow.
- **Connect does nothing**: the first sync waits for Accept in the Rojo panel when it has more than ~5 changes; a
  hidden panel stalls silently (Plugins tab > Rojo shows it).
- **Panel ignores clicks**: Rojo's update check to api.github.com hung 60-120 s at a time; set
  `Rojo_checkForUpdates` false in `~/Documents/Roblox/<userId>/InstalledPlugins/0/settings.json` with Studio closed.
- **Rojo missing**: Studio log (`~/Library/Logs/Roblox/*_Studio_*_last.log`) shows `loadPlugin` but no `Running plugin`
  = disabled in Manage Plugins (remembered by file name: copying the .rbxm under a new name re-enables it). A
  Creator Store copy beside the local one clashes ("Failed Already Added").
- A `*.project.json` that was briefly empty / invalid stops that server pushing changes while the panel still says
  connected: restart the server and reconnect.
- Studio ignores SIGTERM; `kill -9`, then reopen with
  `open "roblox-studio:1+launchmode:edit+task:EditPlace+placeId:<id>+universeId:<id>"`.

## Testing a running game
- **`eval_server_runtime` / `eval_client_runtime`** run in the game's own Script / LocalScript VM and **share its require cache**: `require(ServerScriptService.Server.Run).something` returns the live module. Use these to call module test hooks and read live state. `eval_client_runtime` takes `target: "client-N"`.
- **`execute_luau`** runs in plugin context (`target: "edit"` default, or `server` / `client-N`): modules required there are fresh copies. Use it for edit-mode work (building, running a tool script, reading the place), not for game state.
- Give every system **test hooks** (`spawnNow()`, `addBlocks(n, player)`, `point(x, y, hold)`, `failSaves = true`) and an **admin panel** (see roblox-game-architecture). Testing then means calling them, not scripting fake input.
- MCP virtual mouse clicks don't fire GUI `Activated`. Expose each button's action as a module function and call it from `eval_client_runtime`. Keyboard input (E for prompts) does work.
- Evals time out around 40–60 s: never `task.wait` long inside one. For long observations, `task.spawn` a logger that appends to `_G.log`, then read it in later short evals.
- Verify through side effects (a label's `.Text`, an attribute, a part's position), then **look at it** (screenshots / recording: roblox-studio-verification).
- Several places can be open at once: pass `instance_id` (e.g. `"place:<placeId>"`) on every call.
- `multiplayer_playtest` for 2+ clients (`start` with `numPlayers`, `add_players`, `end`).
- Pace side-effectful loops to real server cooldowns, or rejections read as failures.

## Multi-place universes (lobby + game)
- One experience can hold several places (lobby = start place, game = second place). DataStores, OrderedDataStores, passes and products are **per universe**, so they are shared.
- **One Rojo project per place** (`default.project.json`, `lobby.project.json`), each served on **its own port** to its own Studio window.
- **Share modules by mapping them into both trees** in project.json, never by copying:
```json
"Shared": { "$path": "src/shared",
  "LobbyConfig": { "$path": "lobby/src/shared/LobbyConfig.luau" },
  "RobuxPrice":  { "$path": "lobby/src/shared/RobuxPrice.luau" } }
```
  Good candidates: the product list, the generated `Assets` module, analytics step names, input / guide helpers.
- Lint each tree (`selene src`, `selene lobby/src`).
- Teleports (`TeleportService:TeleportAsync` into a reserved server) fail in Studio (HTTP 403). They only work once both places are published into the same experience. Design for the failure (reset the pad, toast).
- Retired standalone places: write down "don't publish to X" in CLAUDE.md.

## Publishing (the user does it)
- The Studio MCP has no publish tool. With two places open, Studio runs as two processes and desktop automation may only reach one. **Ask the user** to publish from that place's own window (File > Publish to Roblox), and say which place.
- Never publish whichever window happens to be in front.
- Remind them to save/publish after hand-built Workspace / StarterGui changes, which exist only in the place file.
- When GUI wording changes in code, also update the Studio-saved default text: edit mode shows the saved text.

## Parallel sessions sharing one Studio
Users often run several Claude sessions on one project. They share `src/`, the open place and the playtest.
- **Re-read a file right before editing it** and make small, exact edits. No whole-file rewrites of shared modules.
- Before evals, check the playtest is yours: `solo_playtest status`, and `game.Players.LocalPlayer.Name` in the client. A running playtest you didn't start belongs to someone else: don't inject, reparent or retune things in it. Wait, or ask its owner.
- Never batch a playtest start with evals in one turn.
- **Don't use the MCP `undo`** to roll back your own edits: the top of the undo stack may be the user's work. Record original values before bulk edits and fix forward by value.
- Multiplayer playtests: 2 clients unless the user OKs more (each client is a Studio process; 4 + server bogged down
  a MacBook). Stand one other player in for many by lowering budgets / thresholds at runtime.
- Before an eval, `return game.Players.LocalPlayer.Name`: another session may have replaced your playtest.

### Git with parallel sessions
Sessions share one working tree AND one index.
- Never `git commit -a`, and never a bare `git commit` after `git add`: another session's staged files ride along.
- `git commit -m "..." -- <my paths>` commits only those paths, but **the whole working-tree file**, including
  another session's unstaged hunks in it. For a shared file (Config, CLAUDE.md, CHANGES.md) holding someone else's
  edits: stage only your hunks (`git diff -U0 <file>` filtered, `git apply --cached --unidiff-zero`), check
  `git diff --cached --stat`, then `git commit -m` with no pathspec. Check `git show --stat HEAD` after.
- **Don't keep the repo in an iCloud-synced folder** (`~/Documents` / Desktop with "Optimize Mac Storage"): iCloud
  made 614 files in `.git` cloud-only, git reads timed out, a commit left `refs/heads/main.lock` and `main` showed
  "No commits yet". New projects go outside iCloud (e.g. `~/Dev/<game>`). For an existing one: move the git dir to
  `.git.nosync` (iCloud skips `.nosync`), leave a one-line `.git` file `gitdir: .git.nosync`, add `.git.nosync/` to
  `info/exclude`, push to GitHub often (iCloud no longer backs it up). Diagnose with
  `find .git -flags +dataless | wc -l`.

## Engine / language gotchas (selene misses these)
- **StreamingEnabled + remotes**: a part the server creates and passes in a RemoteEvent in the same frame often arrives as `nil` (the remote outruns streaming). For effects on new objects, send data (kind, CFrame, size, target) and let each client spawn its own copy. Pass Instances only when they already exist on the client. Anything a client must always find goes in ReplicatedStorage or uses `ModelStreamingMode = Persistent`.
- **StreamingEnabled + client lookups**: on a slow join or a short streaming radius, `workspace.Lobby.PlayPads` isn't there yet; indexing it directly in a loop threw hundreds of times an hour and killed that client system for the whole visit. Look streamed parts up nil-safe every time (`lobbyPart(name)`), set up late arrivals with `ChildAdded`, make small must-have models Persistent, and for a far model used on demand make it `Atomic` and `player:RequestStreamAroundAsync(pos)` before entering. A client start that waits on a far streamed part never finishes on a short radius.
- **Characters and collisions**: put players in a collision group that doesn't collide with itself (nobody blocks a pad, a door or a teammate), and for wide avatars put every part except the HumanoidRootPart in a group that collides with nothing (bundles got stuck in 4-stud doors). Default-group raycasts then hit only a player's root: filter on the character when you need the body. Re-apply on every spawn.
- **Void / water safety**: one-life games rescue players who fall below a Y or stand in terrain water too long (put them back where they last stood on land), plus invisible player-only walls at sea edges. Run each check under its own pcall so one can't stop the other.
- **200-local ceiling** in a big main chunk: "Out of local registers: exceeded limit 200" at runtime, and boot silently fails. Bundle state into one table local, hang module refs on a table, wrap groups in `do … end`. Function-body locals don't count.
- **selene + new classes**: `Instance.new("NewClass")` can fail selene's stdlib check. If the service auto-creates the instance, `FindFirstChildOfClass` it instead.
- **No `PlayerModule`** in some engine versions (engine-native controls): `WaitForChild("PlayerModule")` yields forever. Freeze a character by zeroing WalkSpeed / JumpPower locally. `DevComputerMovementMode` can only be set by the server.
- After `LoadCharacter` without a PlayerModule, the camera stays on the old body. Set `CameraSubject` yourself.
- A child named like a property (`Name`) needs `FindFirstChild("Name")`.
- UI traps (font glyphs, `UIListLayout` order, click-outside-close, visibility bugs): **roblox-ui-hud** and **roblox-cross-device-ui**.

## PlayerData persistence checklist
For every saved field confirm: **type · default · serialize · load · reset**. A field saved but not loaded resets on rejoin, and the next autosave writes the reset value back: permanent loss. Prefer looping over a saved sub-table so new keys load automatically. Never write a profile whose load failed. Purchase fields: **roblox-monetization**. Store design: **roblox-data**.
