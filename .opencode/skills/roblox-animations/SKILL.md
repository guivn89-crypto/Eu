---
name: roblox-animations
description: Use when working with Roblox animation systems — playing, stopping or blending animations on Humanoid characters or non-Humanoid models, AnimationTrack events and markers, replacing default character animations, priority/blending bugs (emotes playing at half strength), animation packs, NPC poses on AnimationConstraint rigs (CreateHumanoidModelFromDescription), authoring custom animations as data and exporting them, props held in the hand, and cutscene actors with voiced lines.
---

# Roblox Animations

## Core objects
| Object | Purpose |
|---|---|
| `Animation` | Asset reference, holds `AnimationId` |
| `Animator` | Inside Humanoid or AnimationController; loads and drives tracks |
| `AnimationController` | Replaces Humanoid for non-character rigs |
| `AnimationTrack` | Returned by `Animator:LoadAnimation`; controls playback |

## Where to run animation code
| Scenario | Script | Location |
|---|---|---|
| Local player character | `LocalScript` | `StarterCharacterScripts` (replicates from the owner) |
| NPC everyone sees | `Script` | server |
| Cutscene actors / display copies only one player sees | `LocalScript` | client, on local clones |

- Always `Animator:LoadAnimation`, never the deprecated `Humanoid:LoadAnimation`.
- An `AnimationController` needs an `Animator` child or tracks won't play.
- Animations only play if the experience owner (user or group) or Roblox owns them. Upload under the same creator as the game (Asphalt to the group).

## Playback
```lua
local track = animator:LoadAnimation(animation)
track:Play(fadeTime, weight, speed)   -- defaults 0.1, 1, 1
track:AdjustSpeed(1.5); track:AdjustWeight(0.5, 0.2)
track:Stop(0.5)
track.Stopped:Once(cleanup)
track:GetMarkerReachedSignal("Release"):Connect(function(param) ... end)
-- TimePosition (rw), Length, IsPlaying, Looped (rw), Priority (rw), WeightCurrent
```
- `track.Looped` can be overridden at runtime. A one-shot fires `Stopped` after one cycle.
- `Length` is 0 until the animation has loaded. Preload (`ContentProvider:PreloadAsync` on the Animation objects) before a scene.
- **Hold the last frame**: watch `TimePosition >= Length - 0.04` on Heartbeat, then `AdjustSpeed(0)`.
- Stop everything: `for _, t in animator:GetPlayingAnimationTracks() do t:Stop(0.1) end`.

## Priority and blending
`Idle < Movement < Action < Action2 < Action3 < Action4 < Core`. Higher wins on joints it keys; **equal priorities blend by weight**.
- **Always set `track.Priority` yourself after loading.** Roblox animation-pack tracks can ship at unexpected priorities: some packs' idle and walk are **Action**. An emote at Action over them then blends 50/50 and plays at half strength, so the character looks stiff. Nothing in code shows it; only watching does.
- A working stack: idle = `Idle`, walk = `Movement`, emotes/gestures = `Action`, custom scene moves = `Action2` (over emotes).
- No runtime joint masks: an upper-body-only move must leave lower-body joints unkeyed in the asset. A joint no key touches is left to lower tracks.
- Packs' walk cycles are made for a set speed. Scale the walk with `walk:AdjustSpeed(walkSpeed / packWalkSpeed)` or feet slide.

## Replacing default character animations
Change the `AnimationId`s under the character's `Animate` script on CharacterAdded (slots `idle`, `walk`, `run`, `jump`, `fall`, `climb`, `swim`, `swimidle`, `toolnone`, `toolslash`, `toollunge`). Default emotes: `Animate.PlayEmote` (a BindableFunction) plays Roblox's default emotes so they replicate and stop when the player moves.

## AnimationConstraint rigs (CreateHumanoidModelFromDescription)
Rigs from `Players:CreateHumanoidModelFromDescription` (and many newer avatars) join parts with **AnimationConstraint**, not Motor6D.
- There is no `Motor6D.C0` to edit. Head turns go through the neck's rig attachment (`UpperTorso.NeckRigAttachment`, the constraint's `Attachment0`), or the joint's `Transform`.
- **Static poses without an animation** (sit on the ground, lie on a towel): rotate the joint's `Attachment0` (hip / knee rig attachments). That is the C0 equivalent, and the idle keeps playing on top.
  - Turn it **about the parent part's X axis**: `CFrame.new(rest.Position) * CFrame.Angles(a, 0, 0) * rest.Rotation`. Turning about the attachment's own axes splays legs on some leg packages.
  - Save each attachment's rest CFrame and restore it on stand-up.
- Hold the body in place with a rigid `AlignPosition` + `AlignOrientation` (OneAttachment, `RigidityEnabled`) on the HumanoidRootPart plus `PlatformStand = true`. **Never anchor the root**: an anchored root stops the limbs following animations.
  - Stand up: restore the attachments, slide back, destroy the aligners, `PlatformStand = false`, `ChangeState(Running)`.
- These joints follow animations **only while the Humanoid is in a normal standing state**. For display copies (shop mannequins, avatar previews): unanchored, on a floor, with `FallingDown` / `Ragdoll` / `Jumping` disabled via `SetStateEnabled`.
- Cloning a live character copies its current joint pose. Reset every `Motor6D` / `AnimationConstraint` `Transform` to identity on the copy, or a stale neck turn sticks on joints the idle doesn't key.

## Authoring custom animations as data
When the Animation Editor isn't an option (Claude can't drag gizmos), write poses as data in a Luau file that builds `KeyframeSequence`s. Full pattern and builder: `references/animations-as-data.md`.
- A table per animation: `length`, `looped`, `markers = { Release = 0.38 }`, `keys = { { t, pose = { RightUpperArm = { pitch, yaw, roll, lift? } } } }`, in degrees per R15 joint.
- Write down the sign convention at the top of the file once you've checked it on a rig (which way positive pitch swings an arm, etc.).
- The builder nests `Pose`s along the R15 parent chain, adds every joint any key uses to every keyframe, gives the root `Weight = 0`, and sets `seq.Priority`.
- **Markers only exist on keyframes**: put a key at each marker's time.
- Run it in Studio **edit mode** (`execute_luau`): it fills `ServerStorage.<Folder>` with KeyframeSequences. To preview in a playtest client, `KeyframeSequenceProvider:RegisterKeyframeSequence(seq)` gives a temporary id.
- Ship: export each sequence to `assets/.../anims/<name>.rbxm`, `asphalt sync` (see roblox-assets-asphalt), then use `Assets.anims.<name>`. To change a pose: edit the data, rebuild, export, sync.

## Timing props and effects with markers
- Name marker events by what happens: `Release` (item leaves the hand), `Dig`, `Ball`, `Give`, `Take`, `Pay`, `Hit`.
- Always add a timed fallback, so a scene doesn't stall when an animation fails to load:
```lua
local function onMarker(track: AnimationTrack?, name: string, at: number, fn: () -> ())
	local done = false
	local function run() if not done then done = true; fn() end end
	if track then track:GetMarkerReachedSignal(name):Once(run) end
	task.delay(at + 0.15, run)
end
```

## Holding items like a tool
- Put held props on the hand's grip attachment every frame: `RightHand.RightGripAttachment.WorldCFrame * offset`, bound with `BindToRenderStep` just before the camera.
- Author holding poses for the **right fist**, as Roblox tools are.
- Keep a small offset per item kind (a cube in the palm, a tub by its rim, a cone upright).
- Hand-overs: lerp the prop from where it is to the receiver's grip over ~0.3 s with a small arc, then attach it.

## Cutscene actors
- **One actor helper** that loads walk + idle with priorities set, starts the idle, and on `MoveToFinished` settles back into the idle. Wait a frame before settling: a multi-point walk starts its next point a frame later, or it stutters at every point.
- Use Roblox's own animation packs and emotes for characters, never the default animations, which read as placeholder.
- **Gestures replace each other**: stop the previous emote (0.15 s fade) before playing the next. On a camera cut, stop it at once so a move doesn't carry into the new shot.
- **Pin actors working a machine** to their spot every frame (set root CFrame, zero velocity in a RenderStep). Otherwise the Humanoid turns them back to their last walk direction.
- Writing a character's root CFrame every frame cancels `Humanoid:MoveTo`. Pin only while not walking.
- A track stops when its rig leaves the world. When an actor is re-parented into a scene, play the idle again or it stands in the rest pose.
- **Teams**: cast clones of every teammate. `role(i) = cast[(i - 1) % #cast + 1]` hands each shot's part to the next one, so everyone appears.
- **Framing**: a person at a wall-mounted machine shows only their back from behind. Stand them at an angle to it and put the camera beside the machine, looking back at their face. Keep lamp posts and walls out of the lens; keep speech-bubble anchors in front of the subject.

## Voiced lines driving captions and gestures
- Generate lines with TTS, then align words with Whisper and write per-line **word start times** into a generated module (`Voice[key] = { duration, words = { t1, t2, ... } }`).
- Captions reveal word by word on those times. With no recording, fall back to the typewriter timing.
- Body language as cues: `{ at = "NOW", move = "Point" }` starts the gesture when the first word beginning with `at` is said, a small lead (~0.2 s) early so the big part lands on the word. Drop cues once the next line starts.
- Keep the caption text and the recorded text identical; regenerate the take when a line changes.

## Watch it move
Motion bugs (half-strength emotes, clipping, wrong facing, a pose that pops) don't show in code or single screenshots. Record the playtest window in a fast loop and review frame sheets after every take: see **roblox-studio-verification**. To check an emote's timing without recording, scrub `TimePosition` on a local copy and sample hand heights against the head.

## Common mistakes
| Mistake | Fix |
|---|---|
| Emote plays weak / stiff over a pack idle | Set priorities on load (idle Idle, walk Movement, emote Action) |
| Player animation played from a server `Script` | `LocalScript` in `StarterCharacterScripts` |
| Two animations fight on the same joints | Different `Priority` values |
| `GetMarkerReachedSignal` never fires | Marker name wrong, not on a keyframe, asset not re-exported, or animation didn't load: add a timed fallback |
| NPC limbs frozen | Root anchored, or Humanoid not in a standing state |
| Pose splays legs | Rotate the rig attachment about the parent part's X axis |
| Cloned character has a twisted neck | Reset joint `Transform`s on the copy |
| Animation doesn't play in a group game | Upload it under the group |
