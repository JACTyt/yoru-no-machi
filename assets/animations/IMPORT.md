# Animation libraries

Quaternius **Universal Animation Library 1 & 2** (Standard), CC0. Licenses in `ual1/` and `ual2/`.
We use the in-place files (`UAL1_Standard.glb`, `UAL2_Standard.glb`), not the `_RM` root-motion ones.

## One-time import setup (per .glb)

The clips must be retargeted to Godot's humanoid profile so they play on the VRM's `%GeneralSkeleton`.

1. In the FileSystem dock, double-click `ual1/UAL1_Standard.glb` → **Advanced Import Settings**.
2. In the scene tree on the left, select **Skeleton3D**.
3. Right panel → **Retarget → Bone Map** → `<empty>` → **New BoneMap**.
4. Click the new BoneMap → **Profile** → `<empty>` → **New SkeletonProfileHumanoid**.
   Bones auto-map from the Unreal mannequin names; all entries should turn green.
5. **Reimport** (bottom right).
6. Repeat for `ual2/UAL2_Standard.glb`.

If this is skipped, the game logs a warning and falls back to procedural animation.

## Clips in use

| Use | Clip |
|---|---|
| Idle / walk / jog / sprint / air | `ual1/Idle`, `Walk`, `Jog_Fwd`, `Sprint`, `Jump` (Godot strips the `_Loop` suffix on import and marks them looping) |
| Light combo | `ual1/Punch_Jab`, `ual1/Punch_Cross`, `ual2/Melee_Hook` (+ `Melee_Hook_Rec`) |
| Dash | `ual1/Roll` |
| Hurt / knockback / death | `ual1/Hit_Chest`, `ual2/Hit_Knockback`, `ual1/Death01` |

Browse everything at https://quaternius.com/animviewer.html
