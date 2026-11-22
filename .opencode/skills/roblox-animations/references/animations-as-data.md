# Authoring animations as data (KeyframeSequence builder)

Use when you need a custom R15 animation and can't use the Animation Editor by hand. Poses are tables in a Luau file; the script builds KeyframeSequences in Studio edit mode; you export them as .rbxm and upload through Asphalt.

## Workflow
1. Write `tools/anims/<set>.luau` (pattern below). Keep it out of the Rojo tree: it's a tool, not game code.
2. Run it in Studio **edit mode** (MCP `execute_luau`, paste the file's source). It fills `ServerStorage.<Folder>` with one KeyframeSequence per animation.
3. Quick look without uploading: in a playtest client, `KeyframeSequenceProvider:RegisterKeyframeSequence(seq)` returns a temporary id to load on a local rig. (The script puts the folder in the Camera when run in a playtest client.)
4. Export each sequence to `assets/<...>/anims/<name>.rbxm` (MCP `export_rbxm`, or right-click > Save to File).
5. `asphalt sync` → `Assets.anims.<name>` (see roblox-assets-asphalt). Upload under the game's owner (group), or it won't play.
6. Record it playing in the scene and look at the frames (roblox-studio-verification). Adjust numbers, repeat.

## Conventions to write at the top of the file
- Angles are degrees per R15 joint, named by the part the joint moves (Part1): `{ pitch (X), yaw (Y), roll (Z), lift? }`. The 4th number lifts the LowerTorso in studs (knee dips).
- Check the signs on a rig once and write them down, e.g.: pitch > 0 swings an arm / leg / forearm forward and leans UpperTorso / Head back; yaw > 0 turns left; roll > 0 swings a right arm outward (a left arm inward).
- A joint left out of a key is neutral in that key. Joints no key uses aren't animated at all, so the idle under it keeps them.
- Helpers like `merge(base, over)` and `dip(amount, pose)` keep poses short. A loop starts and ends on the same pose.

## Data shape
```lua
type Angles = { number } -- { pitch, yaw, roll, lift? }
type Key = { t: number, pose: { [string]: Angles } }
type Anim = { length: number, looped: boolean, markers: { [string]: number }?, keys: { Key } }

local A: { [string]: Anim } = {}
local carry = { RightUpperArm = { 40, 0, -8 }, RightLowerArm = { 45, 0, 0 }, Head = { -8, 0, 0 } }
A.toss = {
	length = 0.85,
	looped = false,
	markers = { Release = 0.38 }, -- needs a key at exactly 0.38
	keys = {
		{ t = 0, pose = carry },
		{ t = 0.22, pose = { UpperTorso = { 5, 12, 0 }, RightUpperArm = { 155, 0, 12 }, RightLowerArm = { 70, 0, 0 } } },
		{ t = 0.38, pose = { UpperTorso = { -12, -10, 0 }, RightUpperArm = { 92, 0, -6 }, RightLowerArm = { 8, 0, 0 } } },
		{ t = 0.85, pose = carry },
	},
}
```

## Builder
```lua

local PARENT = {
	LowerTorso = "HumanoidRootPart",
	UpperTorso = "LowerTorso",
	Head = "UpperTorso",
	RightUpperArm = "UpperTorso",
	RightLowerArm = "RightUpperArm",
	RightHand = "RightLowerArm",
	LeftUpperArm = "UpperTorso",
	LeftLowerArm = "LeftUpperArm",
	LeftHand = "LeftLowerArm",
	RightUpperLeg = "LowerTorso",
	RightLowerLeg = "RightUpperLeg",
	RightFoot = "RightLowerLeg",
	LeftUpperLeg = "LowerTorso",
	LeftLowerLeg = "LeftUpperLeg",
	LeftFoot = "LeftLowerLeg",
}

-- Build ---------------------------------------------------------------------------------------------

local function angles(a: Angles?): CFrame
	if not a then
		return CFrame.identity
	end
	return CFrame.new(0, a[4] or 0, 0) * CFrame.Angles(math.rad(a[1] or 0), math.rad(a[2] or 0), math.rad(a[3] or 0))
end

local function build(name: string, anim: Anim): KeyframeSequence
	local seq = Instance.new("KeyframeSequence")
	seq.Name = name
	seq.Loop = anim.looped
	seq.Priority = Enum.AnimationPriority.Action2
	-- every joint any key moves, plus the parents that hold it in the pose tree
	local used: { [string]: boolean } = {}
	for _, key in anim.keys do
		for joint in key.pose do
			local at: string? = joint
			while at and at ~= "HumanoidRootPart" do
				used[at] = true
				at = PARENT[at]
			end
		end
	end
	for _, key in anim.keys do
		local frame = Instance.new("Keyframe")
		frame.Time = key.t
		local poses: { [string]: Pose } = {}
		local root = Instance.new("Pose")
		root.Name = "HumanoidRootPart"
		root.Weight = 0
		root.Parent = frame
		poses.HumanoidRootPart = root
		local function poseFor(joint: string): Pose
			local made = poses[joint]
			if made then
				return made
			end
			local pose = Instance.new("Pose")
			pose.Name = joint
			pose.CFrame = angles(key.pose[joint])
			pose.EasingStyle = Enum.PoseEasingStyle.Cubic
			pose.EasingDirection = Enum.PoseEasingDirection.InOut
			pose.Parent = poseFor(PARENT[joint])
			poses[joint] = pose
			return pose
		end
		for joint in used do
			poseFor(joint)
		end
		for marker, at in anim.markers or {} do
			if math.abs(at - key.t) < 1e-4 then
				local m = Instance.new("KeyframeMarker")
				m.Name = marker
				frame:AddMarker(m)
			end
		end
		frame.Parent = seq
	end
	return seq
end

-- in a playtest client (previewing: KeyframeSequenceProvider:RegisterKeyframeSequence) it goes in the Camera
local RunService = game:GetService("RunService")
local home: Instance = if RunService:IsRunning() and RunService:IsClient() then workspace.CurrentCamera else game:GetService("ServerStorage")
local folder = home:FindFirstChild("BuiltAnims") or Instance.new("Folder")
folder.Name = "BuiltAnims"
folder.Parent = home
folder:ClearAllChildren()
for name, anim in A do
	build(name, anim).Parent = folder
end
return folder
```

## Gotchas
- **Markers are only added on keyframes**: a marker time with no key at that time is silently dropped.
- Every keyframe holds every used joint (and its parents in the tree), so a joint missing from a key eases back to neutral there instead of holding. Repeat a pose if it should hold.
- `seq.Priority` is saved into the asset, but still set `track.Priority` after loading in code.
- Easing per pose: Cubic InOut reads natural. Linear looks robotic.
- Items are held in the right fist (RightGripAttachment), so reach poses use the right arm.
