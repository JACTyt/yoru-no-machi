extends RefCounted
## Session-wide settings shared across scenes (static vars survive scene changes): the chosen
## heroine and her customised look, persisted in user://profile.json.

const PLACEHOLDER_PATH := "res://characters/placeholder/Godette_vrm_v4.vrm"
const PROFILE_PATH := "user://profile.json"
const HEROINES := {
	"hana": {"name": "Hana Kurose", "path": "res://characters/heroine/Hana.vrm"},
	"saki": {"name": "Saki Tachibana", "path": "res://characters/heroine/Saki.vrm"},
}
## Customisable parts: id → [label, material-name tags]. Preset 0 ("Natural") keeps the original look.
## One-piece outfits (bodysuits, dresses) count as the bottom.
const PARTS := {
	"hair": ["Hair", ["_HAIR"]],
	"tops": ["Top", ["_Tops_"]],
	"bottoms": ["Bottom", ["_Bottoms_", "_Onepiece_"]],
	"shoes": ["Shoes", ["_Shoes_"]],
	"eyes": ["Eyes", ["_EyeIris_"]],
}
const PRESETS := [
	["Natural", ""], ["Midnight", "#2a2f45"], ["Ash silver", "#c9ced6"], ["Sakura", "#f2a7c3"],
	["Crimson", "#c21e3a"], ["Mint", "#7fd6c4"], ["Honey", "#e8b65a"], ["Violet", "#8f6ad8"],
	["Ocean", "#3b7bd4"], ["Ivory", "#f3eee2"],
]

static var heroine := "saki"
## heroine id → {part: preset index}
static var looks := {}
## heroine id → chosen outfit file name ("" = the default model).
static var outfits := {}
static var _loaded := false
static var _gray_cache := {}


static func heroine_name() -> String:
	return HEROINES[heroine]["name"]


## The selected heroine's VRM (in her chosen outfit), falling back to any available one, then the
## placeholder.
static func heroine_path() -> String:
	var path: String = HEROINES[heroine]["path"]
	var chosen: String = outfits.get(heroine, "")
	if not chosen.is_empty() and ResourceLoader.exists(path.get_base_dir().path_join(chosen)):
		return path.get_base_dir().path_join(chosen)
	if ResourceLoader.exists(path):
		return path
	for key in HEROINES:
		if ResourceLoader.exists(HEROINES[key]["path"]):
			return HEROINES[key]["path"]
	return PLACEHOLDER_PATH


## Outfit variants: every "<Name>_<Outfit>.vrm" next to the heroine's model, e.g. Saki_Casual.vrm.
## Returns [[label, file name]], the default model first with file name "".
static func outfit_list(id := "") -> Array:
	if id.is_empty():
		id = heroine
	var path: String = HEROINES[id]["path"]
	var stem := path.get_file().get_basename()
	var list := [["Default", ""]]
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		return list
	for f in dir.get_files():
		# Exported games only list the .import / .remap stubs.
		var file: String = f.trim_suffix(".import").trim_suffix(".remap")
		if file.begins_with(stem + "_") and file.get_extension().to_lower() == "vrm" and not list.any(func(o): return o[1] == file):
			list.append([file.get_basename().trim_prefix(stem + "_").capitalize(), file])
	return list


static func outfit_index() -> int:
	var list := outfit_list()
	for i in list.size():
		if list[i][1] == outfits.get(heroine, ""):
			return i
	return 0


static func cycle_outfit(step := 1) -> void:
	var list := outfit_list()
	outfits[heroine] = list[posmod(outfit_index() + step, list.size())][1]


static func cycle_heroine(step := 1) -> void:
	var keys := HEROINES.keys()
	heroine = keys[posmod(keys.find(heroine) + step, keys.size())]


static func look() -> Dictionary:
	if not looks.has(heroine):
		looks[heroine] = {}
	return looks[heroine]


static func load_profile() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(PROFILE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
	if data is Dictionary:
		if HEROINES.has(data.get("heroine", "")):
			heroine = data["heroine"]
		if data.get("looks") is Dictionary:
			looks = data["looks"]
		if data.get("outfits") is Dictionary:
			outfits = data["outfits"]


static func save_profile() -> void:
	var f := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"heroine": heroine, "looks": looks, "outfits": outfits}, "\t"))


## Recolours the VRM under `root` with the current heroine's look. Tinted parts use a grayscale,
## brightness-normalised copy of their texture so even black hair takes the new colour while
## keeping its strand shading.
static func apply_look(root: Node) -> void:
	var colors := {}
	for part in PARTS:
		var preset := int(look().get(part, 0))
		colors[part] = Color(PRESETS[preset][1]) if preset > 0 and preset < PRESETS.size() else null
	tint(root, colors)


## Recolours any VRoid model: `colors` maps a PARTS id to a Color, or null for the original look.
## Parts not listed are left alone (pedestrian variety uses this too).
static func tint(root: Node, colors: Dictionary) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i) as ShaderMaterial
			if mat == null:
				continue
			for part in colors:
				if not PARTS[part][1].any(func(tag): return mat.resource_name.contains(tag)):
					continue
				if colors[part] == null:
					if mi.get_surface_override_material(i) != null:
						mi.set_surface_override_material(i, null)
					continue
				var tint: Color = colors[part]
				var m := mat.duplicate() as ShaderMaterial
				var tex = mat.get_shader_parameter("_MainTex")
				if tex is Texture2D:
					var gray := _grayscale(tex)
					m.set_shader_parameter("_MainTex", gray)
					m.set_shader_parameter("_ShadeTexture", gray)
				var alpha: float = (mat.get_shader_parameter("_Color") as Color).a if mat.get_shader_parameter("_Color") is Color else 1.0
				m.set_shader_parameter("_Color", Color(tint, alpha))
				m.set_shader_parameter("_ShadeColor", tint.darkened(0.35).lerp(Color(0.45, 0.4, 0.65), 0.25))
				mi.set_surface_override_material(i, m)


static func _grayscale(tex: Texture2D) -> Texture2D:
	var key := tex.get_rid()
	if _gray_cache.has(key):
		return _gray_cache[key]
	var img := tex.get_image()
	if img == null:
		return tex
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.clear_mipmaps()
	var probe := img.duplicate() as Image
	probe.resize(1, 1, Image.INTERPOLATE_BILINEAR)
	var avg := maxf(probe.get_pixel(0, 0).get_luminance(), 0.02)
	img.adjust_bcs(clampf(0.8 / avg, 1.0, 8.0), 1.0, 0.0)
	img.generate_mipmaps()
	var out := ImageTexture.create_from_image(img)
	_gray_cache[key] = out
	return out
