---
name: roblox-studio-mcp
description: Use when driving or inspecting Roblox Studio through the `robloxstudio` MCP tools (mcp__robloxstudio__*) - reading or searching the datamodel and scripts, editing instances or script source, starting/stopping solo or multiplayer playtests, running Luau in edit/server/client (execute_luau, eval_server_runtime, eval_client_runtime), screenshots and device emulation, MicroProfiler / ScriptProfiler / memory / scene analysis, inserting or generating assets, or when the MCP link is dead or tools are missing. A capability menu plus the gotchas that cost hours.
---

# Roblox Studio MCP (`robloxstudio`): capability menu

The tools are deferred: load them once with ToolSearch `"+robloxstudio"` (max_results 80) before the first call. This is the toolbox reference. For the disk + Rojo + selene dev loop see `roblox-studio-workflow`; for proving a change works (screenshots, recordings, devices, profiling, honest reports) see `roblox-studio-verification`; for phone / second-player conditions see `roblox-studio-emulation`.

## Targeting: which Studio, which peer
- **Several places can be connected at once** (e.g. a lobby and a game place). Every tool takes `instance_id`; pass `instance_id = "place:<placeId>"` whenever more than one is connected, or the call may hit the wrong place. `get_connected_instances` lists places and, during a playtest, their roles (`edit`, `server`, `client-1`, `client-2`...).
- Most runtime tools take `target`: `"edit"` (default for inspect/edit tools), `"server"`, `"client-N"`, sometimes `"all"` / `"all-clients"`.
- `get_place_info` confirms place id / name before you write anything.

## Inspect (read-only, safe any time)
- Tree: `get_project_structure` (maxDepth, scriptsOnly), `get_file_tree`, `get_instance_children`, `get_descendants` (classFilter, maxDepth), `get_services`.
- Properties: `get_instance_properties` (excludeSource for scripts), `mass_get_property`, `compare_instances` (why does a duplicate differ?), `get_attributes`, `get_tags` / `get_tagged`, `get_selection`.
- Search: `search_objects` (name / class / property), `search_by_property`, `search_files` (name / type / content), `search_materials` (MaterialVariants).
- API: `get_class_info`, `get_roblox_docs` (official docs page, cached; use before guessing an API), `get_roblox_skills` (Roblox's own Assistant skills).

## Edit the datamodel (edit mode persists only after the user saves / publishes)
- `set_property`, `set_properties`, `mass_set_property`, `set_attribute`, `bulk_set_attributes`, `delete_attribute`, `add_tag` / `remove_tag`.
- `create_object`, `mass_create_objects`, `clone_object`, `smart_duplicate`, `mass_duplicate`, `delete_object`.
- Serialization: `export_rbxm` (instances -> .rbxm on disk, also from `server` at runtime), `import_rbxm` (path / url / base64, one undo step).
- Before a bulk edit, print the original values (CFrames, sizes, colours) so you can restore them by value. Re-read positions right before editing: the user may have moved things since.
- Respect the project's rules: if builds and GUIs are made by hand in Studio, don't build them from scripts.

## Scripts
- Read: `get_script_source` (line_range for big scripts; result has `numberedSource`), `grep_scripts` (literal or Lua pattern with `|`, contextLines, filesOnly).
- Write: `edit_script_lines` (exact replace, unique or anchored by line), `insert_script_lines`, `delete_script_lines`, `set_script_source`, `find_and_replace_in_scripts` (use `dryRun` first).
- **In a Rojo project, author scripts on disk**, never with these write tools: Rojo owns them and a datamodel edit drifts or duplicates. Use the write tools only for scripts that live only in the place, or to repair a stale sync (below).
- **Rojo can silently drop one file's patch** while every other edit syncs (symptom: "attempt to call a nil value" on a new function). After a sync, `grep_scripts` for a string you just added in each edited script. If one is stale, `set_script_source` on that SAME instance with the exact disk content (never create a second instance).

## Playtests and runtime evaluation
- Lifecycle: `solo_playtest` (`start` with mode `play` / `run`, `status`, `stop`), `multiplayer_playtest` (`start` numPlayers 1-8, `add_players`, `leave_client`, `status`, `end`).
- **Never batch a playtest start with evals or screenshots in the same turn.** If start fails ("already running") the evals land in someone else's playtest. Read the start result first.
- **Before every eval into a playtest, check it's yours**: `return game.Players.LocalPlayer.Name` (solo = the account name; multiplayer = Player1/2...). Parallel sessions or the user can replace a playtest mid-run. Don't reparent, inject or take the camera in a playtest that isn't yours.
- `eval_server_runtime` / `eval_client_runtime` run in the GAME's Script / LocalScript VM and share its `require` cache: you get the live module singletons (call `Module.testHook()`, read real state). Use these for testing.
- `execute_luau` runs in **plugin context, a separate VM**: the DataModel is shared but `require()` returns a fresh copy, so module state is not the game's. Good for edit-mode datamodel work and PluginSecurity APIs; wrong for poking live modules.
- **Runtime evals time out at ~40-60 s** ("Proxy request timeout"). Never `task.wait` long inside one. For long observations spawn a logger: `task.spawn(function() _G.log = {} while true do table.insert(_G.log, ...) task.wait(0.5) end end)`, then read `_G.log` in later short evals.
- Logs: `get_runtime_logs` (target, `filter`, `since` = previous `nextSince` for incremental polling, `tail`). Always read errors after a boot: silent failures (stuck WaitForChild, register limits, service errors) only show here.
- Input: `simulate_keyboard_input` (tap / press / release, or `text` into a focused TextBox) works, e.g. E for ProximityPrompts, WASD to walk. `simulate_mouse_input` clicks land, but **virtual clicks don't fire GUI `Activated`** in practice: expose the button's action as a module function and call it from `eval_client_runtime`. Its coordinates are **viewport points**, while screenshots come back at 2x on a Retina Mac: divide screenshot pixels by the scale first.
- **Is a button really tappable?** `PlayerGui:GetGuiObjectsAtPosition(x, y)` at the button's centre returns what sits on top; the first input-sinking object must be the button (or its child). Found close buttons covered by Roblox's top-bar row and a fitted-down panel's X at 35 pt this way; a sweep of every close button on an emulated phone is quick.
- Multiplayer: keep to **2 clients** unless the user OKs more (each is a Studio process); clients can't be screenshotted, so read state or record the window.
- Debugging: `breakpoints` with `log_message` (log-and-continue), then `get_runtime_logs` filter `"Breakpoint"`, then `action="clear"`. Don't set `continue_execution=false` without an OnStopped handler.
- Network: `set_network_profile` (great / good / poor / custom) on clients; `reset_simulation_state` afterwards.

## Capture and devices
- `capture_screenshot`: the live viewport (edit or the running client), native resolution. Needs "Allow Mesh / Image APIs" on and the Studio window visible; a backgrounded window gives black or throttled frames. Not available for StudioTestService multiplayer clients (use window recording, see `roblox-studio-verification`).
- **Screenshots skip `AlwaysOnTop` BillboardGuis** (they render in game). Turn AlwaysOnTop off temporarily to check one, or record the window.
- Freecam / scripted cameras can hide ScreenGuis and distant SurfaceGuis can render blank: cross-check with instance queries before calling it a game bug.
- Devices: `get_device_simulator_state` (preset list), `set_device_simulator` (deviceId, orientation, resolution; target edit / client-N / all-clients; `stopSimulation`), `capture_device_matrix` (up to 6 devices, screenshots each, restores state). Set the device on `edit` BEFORE starting a playtest: switching on a running one doesn't re-run touch-only layout reliably.

## Profiling and memory
- `capture_micro_profiler` (server or client-N, 100-5000 ms; top_groups / top_timers; `summary_output_path` + `baseline_path` for A/B against an empty baseplate).
- `capture_script_profiler` (Luau hot paths; wrap suspects in `debug.profilebegin("Area:Step")` and pass `filter`).
- `get_memory_breakdown` (per DeveloperMemoryTag, per peer), `get_scene_analysis` (instance / script memory, unparented instances, `triangle_composition` incl. a Shadows row, animation / audio memory; needs the Scene Analysis beta).

## Assets and generation
- Creator Store: `search_assets`, `get_asset_details`, `get_asset_thumbnail`, `preview_asset` (scans, never inserts), `insert_asset` (strips every script and PackageLink). It's the Creator Store only, not the avatar Marketplace (see `roblox-avatar-appearance`).
- `upload_asset` exists, but in a Rojo project **use Asphalt** (`roblox-assets-asphalt`) so ids live in a lockfile and a generated module, never hand-pasted.
- `generate_model` (GenerationService, lands in `ServerStorage.__MCPGeneratedModels`), `generate_build` / `create_build` / `import_build` / `import_scene` / `export_build` / `get_build` / `list_library` (part-based build library). Hand-made Blender / Studio builds beat these for shipped art.
- `manage_instance`: launch a baseplate / local file / published place / old revision, `list_place_versions`, close.

## Things the MCP can't or shouldn't do
- **Don't use `undo` / `redo` to revert your own edits.** The top of the undo stack is often the user's (they edit in parallel, and playtest-time edits never reach the stack). Fix forward by value from the originals you printed.
- **Claude can't publish.** There's no publish tool, and with two places open Studio runs two processes. Ask the user to do File > Publish to Roblox (Alt/Option+P) from that place's own window. Edit-mode changes also need the user's save.
- Teleports, MessagingService across servers, real DataStores without API access, and Robux prompts don't behave like production in Studio: say so instead of claiming they work.
- The engine may have no `PlayerScripts.PlayerModule` (native controls): `GetControls()` doesn't exist and WaitForChild on it hangs. Freeze characters by zeroing Humanoid WalkSpeed / JumpPower locally. `DevComputerMovementMode` can only be set on the server.

## Connection troubleshooting
- Studio dials OUT to the MCP. If it never connected, ToolSearch finds no `mcp__robloxstudio__*` tools or `get_connected_instances` is empty.
- Fixes, in order: make sure the MCP plugin / "Enable Studio as MCP server" is on and Studio is open on a place; toggle it off/on while the Claude session runs; restart Studio after saving the setting; reconnect via `/mcp` or start a fresh session (an open session can keep an empty tool list).
- The link can drop mid-session (Studio auto-update, crash, a second Studio process). If calls suddenly fail, check `get_connected_instances` before blaming your code.
