extends RefCounted
## Melee move data. Poses use vrm_character's character-space convention (degrees):
## pitch + swings hanging limbs forward / tilts upright bones back; yaw + turns left;
## roll + moves hanging limbs to the left / tilts upright bones to the right.
## Timings in seconds: `hit` is the active window, `cancel` is when the next input may cut in.
## Optional clip fields (used when the UAL libraries are imported): `clip`, `clip_speed`
## (sped up to fit `duration`), `clip_then` (queued recovery) and `clip_limb` (trail bone for the clip).
## The windup/strike poses remain as the procedural fallback.

const LIGHT := [
	{
		"name": "jab", "duration": 0.4, "hit": [0.12, 0.2], "cancel": 0.22,
		"clip": "ual1/Punch_Jab", "clip_speed": 2.2,
		"reach": 1.5, "radius": 0.8, "damage": 8.0, "knockback": 2.0, "lunge": 3.5,
		"limb": "LeftHand", "color": Color(0.6, 0.85, 1.0),
		"windup": {
			"Chest": Vector3(0, 12, 0),
			"LeftUpperArm": Vector3(35, 0, 0), "LeftLowerArm": Vector3(100, 0, 0),
			"RightUpperArm": Vector3(30, 0, 0), "RightLowerArm": Vector3(110, 0, 0),
		},
		"strike": {
			"Spine": Vector3(-6, 0, 0), "Chest": Vector3(0, -18, 0),
			"LeftUpperArm": Vector3(88, 10, 0), "LeftLowerArm": Vector3(5, 0, 0),
			"RightUpperArm": Vector3(35, 0, 0), "RightLowerArm": Vector3(115, 0, 0),
			"LeftUpperLeg": Vector3(20, 0, 0), "LeftLowerLeg": Vector3(-15, 0, 0), "RightUpperLeg": Vector3(-15, 0, 0),
		},
	},
	{
		"name": "cross", "duration": 0.45, "hit": [0.13, 0.21], "cancel": 0.25,
		"clip": "ual1/Punch_Cross", "clip_speed": 2.2,
		"reach": 1.6, "radius": 0.85, "damage": 10.0, "knockback": 2.5, "lunge": 4.0,
		"limb": "RightHand", "color": Color(0.7, 0.8, 1.0),
		"windup": {
			"Chest": Vector3(0, -10, 0),
			"RightUpperArm": Vector3(35, 0, 0), "RightLowerArm": Vector3(100, 0, 0),
			"LeftUpperArm": Vector3(30, 0, 0), "LeftLowerArm": Vector3(110, 0, 0),
		},
		"strike": {
			"Spine": Vector3(-8, 0, 0), "Chest": Vector3(0, 24, 0),
			"RightUpperArm": Vector3(88, -10, 0), "RightLowerArm": Vector3(5, 0, 0),
			"LeftUpperArm": Vector3(35, 0, 0), "LeftLowerArm": Vector3(115, 0, 0),
			"RightUpperLeg": Vector3(-20, 0, 0), "LeftUpperLeg": Vector3(25, 0, 0), "LeftLowerLeg": Vector3(-20, 0, 0),
		},
	},
	{
		# Finisher: hook punch with clips, front kick as the procedural fallback.
		"name": "finisher", "duration": 0.6, "hit": [0.24, 0.34], "cancel": 0.42,
		"clip": "ual2/Melee_Hook", "clip_then": "ual2/Melee_Hook_Rec", "clip_speed": 1.3, "clip_limb": "RightHand",
		"reach": 1.9, "radius": 1.0, "damage": 18.0, "knockback": 9.0, "launch": 2.5, "lunge": 5.0,
		"heavy": true, "limb": "RightFoot", "color": Color(1.0, 0.55, 0.4),
		"windup": {
			"Spine": Vector3(8, 0, 0),
			"RightUpperLeg": Vector3(70, 0, 0), "RightLowerLeg": Vector3(-100, 0, 0),
			"LeftUpperArm": Vector3(25, 0, 15), "RightUpperArm": Vector3(25, 0, -15),
		},
		"strike": {
			"Spine": Vector3(18, 0, 0), "Chest": Vector3(6, 0, 0),
			"RightUpperLeg": Vector3(100, 0, 0), "RightLowerLeg": Vector3(-5, 0, 0), "LeftUpperLeg": Vector3(-5, 0, 0),
			"LeftUpperArm": Vector3(-20, 0, 30), "RightUpperArm": Vector3(-25, 0, -30),
		},
	},
]

## Spinning side kick: the body spins a full turn plus a quarter so the right leg meets the target.
const HEAVY := {
	"name": "spin_kick", "duration": 0.8, "hit": [0.32, 0.42], "cancel": 0.55,
	"reach": 2.1, "radius": 1.2, "damage": 26.0, "knockback": 13.0, "launch": 4.0, "lunge": 4.5,
	"heavy": true, "spin": true, "limb": "RightFoot", "color": Color(1.0, 0.3, 0.5),
	"windup": {
		"Spine": Vector3(0, 0, -10),
		"RightUpperLeg": Vector3(40, 0, -30), "RightLowerLeg": Vector3(-90, 0, 0),
		"LeftUpperArm": Vector3(40, 0, 20), "RightUpperArm": Vector3(40, 0, -20),
		"LeftLowerArm": Vector3(90, 0, 0), "RightLowerArm": Vector3(90, 0, 0),
	},
	"strike": {
		"Spine": Vector3(0, 0, -25), "Chest": Vector3(0, 0, -10), "Head": Vector3(0, 0, 15),
		"RightUpperLeg": Vector3(10, 0, -95), "RightLowerLeg": Vector3(0, 0, 0),
		"LeftUpperArm": Vector3(0, 0, 60), "RightUpperArm": Vector3(0, 0, -40),
	},
}

const DASH_POSE := {
	"Spine": Vector3(-22, 0, 0), "Chest": Vector3(-8, 0, 0),
	"LeftUpperArm": Vector3(-40, 0, 10), "RightUpperArm": Vector3(-40, 0, -10),
	"LeftUpperLeg": Vector3(30, 0, 0), "LeftLowerLeg": Vector3(-60, 0, 0),
	"RightUpperLeg": Vector3(-20, 0, 0), "RightLowerLeg": Vector3(-30, 0, 0),
}

const HURT_POSE := {
	"Spine": Vector3(18, 0, 0), "Chest": Vector3(10, 0, 0), "Head": Vector3(15, 0, 0),
	"LeftUpperArm": Vector3(30, 0, 20), "RightUpperArm": Vector3(30, 0, -20),
}

const DOWN_POSE := {
	"Spine": Vector3(-35, 0, 0), "Head": Vector3(-20, 0, 0),
	"LeftUpperLeg": Vector3(90, 0, 0), "LeftLowerLeg": Vector3(-120, 0, 0),
	"RightUpperLeg": Vector3(30, 0, 0), "RightLowerLeg": Vector3(-130, 0, 0),
	"LeftUpperArm": Vector3(20, 0, 0), "RightUpperArm": Vector3(20, 0, 0),
}


static func lerp_pose(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := {}
	for k in a:
		out[k] = (a[k] as Vector3).lerp(b.get(k, Vector3.ZERO), t)
	for k in b:
		if not out.has(k):
			out[k] = Vector3.ZERO.lerp(b[k], t)
	return out


## Strong attack (E): a brief power-up (`charge`), then a bursting hook that launches everything in a
## wide arc. Costs stamina; `charge_clip` plays while gathering, `clip` on release.
const STRONG := {
	"name": "crescent_breaker", "duration": 1.15, "charge": 0.42, "hit": [0.55, 0.7], "cancel": 0.95,
	"charge_clip": "ual1/Spell_Simple_Enter", "clip": "ual2/Melee_Hook", "clip_then": "ual2/Melee_Hook_Rec",
	"clip_speed": 1.5, "clip_limb": "RightHand",
	"reach": 2.4, "radius": 1.9, "damage": 48.0, "knockback": 18.0, "launch": 6.0, "lunge": 11.0,
	"heavy": true, "strong": true, "limb": "RightHand", "color": Color(1.0, 0.78, 0.3),
	"windup": {
		"Spine": Vector3(10, 0, 0), "Chest": Vector3(0, -25, 0),
		"RightUpperArm": Vector3(20, 0, -40), "RightLowerArm": Vector3(110, 0, 0),
		"LeftUpperArm": Vector3(40, 0, 20), "LeftLowerArm": Vector3(90, 0, 0),
		"LeftUpperLeg": Vector3(30, 0, 0), "LeftLowerLeg": Vector3(-40, 0, 0),
	},
	"strike": {
		"Spine": Vector3(-12, 0, 0), "Chest": Vector3(0, 35, 0),
		"RightUpperArm": Vector3(95, -15, 0), "RightLowerArm": Vector3(5, 0, 0),
		"LeftUpperArm": Vector3(-20, 0, 35), "RightUpperLeg": Vector3(-25, 0, 0),
		"LeftUpperLeg": Vector3(35, 0, 0), "LeftLowerLeg": Vector3(-25, 0, 0),
	},
}
