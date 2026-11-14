# Heroine — VRoid Studio recipe

**Hana Kurose**, 17. Quiet transfer student with a polite smile, the class's "perfect girl".
Off the clock she knows the city's back alleys far too well. Sweet on the surface, dangerous underneath:
the look should read *soft* at a glance and *sharp* on a second look.

Original design for this project. Japanese school-uniform anime style.
Slider names differ slightly between VRoid versions; follow the intent where a name doesn't match.

## Palette

| Part | Hex |
|---|---|
| Hair base | `#1B1D2E` (blue-black) |
| Hair highlight / shade | `#4A5280` / `#0E0F1A` |
| Eyes (iris) | `#9E1B3B` (dark crimson), lighter ring `#E0566F` |
| Skin | VRoid default light, slightly cooler |
| Sailor top | `#20253F` (navy), trim `#F2F2F5` |
| Neck scarf / ribbon | `#C21E3A` |
| Skirt | `#20253F` |
| Cardigan (optional) | `#8C8F9E` (warm grey) |
| Thigh-highs | `#141418` |
| Loafers | `#3B2A22` |
| Hair ribbon | `#C21E3A` |

## 1. Face tab
1. Start from the default female face preset with the **largest, roundest eyes**.
2. **Eyes:** size up slightly; outer corners a touch *down* (gentle look). Iris size a bit bigger than default.
   Iris color as above. Make the highlight one big top-left highlight plus one small lower one.
3. **Eyelashes:** thicker upper lash line, short lower lashes.
4. **Eyebrows:** thin, soft, slightly raised: innocent.
5. **Mouth:** small. Leave the default expressions intact (we use happy / angry / sad / relaxed / surprised / blink).
6. **Face shape:** slightly narrower chin, small nose.

## 2. Hairstyle tab
1. **Bangs:** straight, blunt-cut (hime-style) to eyebrow length, with **two long side locks** framing the face down to the chest.
2. **Back hair:** long, straight to mid-back.
3. **Add a high side ponytail** on her right side (hair-group → new guide on the back of the head),
   falling past the shoulder. Tie it with a **red ribbon** (Accessory tab, or a small hair group colored `#C21E3A`).
4. **One "ahoge" strand** on top: a single small curved strand, which helps her read as anime from far away.
5. **Hair material:** base and shade colors as above. Turn **highlight on**, soft anisotropic band, color `#4A5280`.
6. Make sure the ponytail and side locks have **hair physics/bones** enabled. godot-vrm turns these into spring bones (the swing during combat).

## 3. Body tab
- Height ~160 cm, slim build, default proportions. Head size slightly larger than default (anime).
- Don't push extreme proportions: it breaks animation retargeting.

## 4. Outfit tab
1. **Tops:** sailor uniform (seifuku) preset. Navy body, white collar trim lines, red neck scarf.
2. **Bottoms:** pleated skirt, knee-length minus a bit. Navy.
3. **Optional:** grey cardigan, sleeves slightly long (half covers hands). Very "class rep" with a secret.
4. **Socks:** black thigh-highs. **Shoes:** brown loafers.
5. Skirt and scarf: enable physics/bones if offered.

## 5. Look / Rendering
- **Outline:** on, width ~**0.5 of max**, color dark navy `#1A1426` (not pure black).
- **Rim light:** subtle, cool.
- **Shade:** two-tone, shade toward lavender (`#B6A9D6` on skin feels right with our post-processing).

## 6. Export
1. **Export → VRM**, choose **VRM 1.0**.
2. Polygon reduction: off (or light). Texture atlas: 2048. Material reduction: allowed.
3. **Don't** reduce bones; keep hair/skirt bones.
4. Metadata: author = you; allowed uses as you like.
5. Save as `characters/heroine/heroine.vrm` in this project.
6. In Godot, wait for import, then run `scenes/test_character.tscn` (F6). She replaces the placeholder automatically.

## Checklist when testing
- Press **E** through all expressions; each one should change her face.
- Orbit to the back: ponytail and skirt should sway (spring bones).
- **L** through lighting: hair highlight readable at night, eyes still red in shade.
