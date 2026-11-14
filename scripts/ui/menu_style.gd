extends RefCounted
## Shared look of the out-of-game screens: drifting light motes, glowing serif labels,
## tapering flourishes and diamonds.

const FONT_PATH := "res://fonts/Cinzel.ttf"
const TEXT_DIM := Color(0.55, 0.6, 0.7)
const TEXT_LIT := Color(0.95, 0.97, 1.0)
const ORNAMENT := Color(0.8, 0.88, 1.0)


static func font() -> Font:
	return load(FONT_PATH) if ResourceLoader.exists(FONT_PATH) else null


static func label_settings(f: Font, size: int, color: Color, glow: float) -> LabelSettings:
	var s := LabelSettings.new()
	s.font = f
	s.font_size = size
	s.font_color = color
	s.shadow_color = Color(0.5, 0.7, 1.0, glow)
	s.shadow_size = int(size * 0.35)
	s.shadow_offset = Vector2.ZERO
	return s


static func add_motes(parent: Control, amount: int, scale_range: Vector2, alpha: float) -> void:
	var tex := GradientTexture2D.new()
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var soft := Gradient.new()
	soft.set_color(0, Color(1, 1, 1, 1))
	soft.set_color(1, Color(1, 1, 1, 0))
	tex.gradient = soft

	var life := Gradient.new()
	life.set_color(0, Color(0.75, 0.88, 1.0, 0.0))
	life.add_point(0.2, Color(0.75, 0.88, 1.0, alpha))
	life.add_point(0.8, Color(0.75, 0.88, 1.0, alpha))
	life.set_color(life.get_point_count() - 1, Color(0.75, 0.88, 1.0, 0.0))

	var motes := CPUParticles2D.new()
	motes.texture = tex
	motes.amount = amount
	motes.lifetime = 16.0
	motes.preprocess = 16.0
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	var view := parent.get_viewport_rect().size
	motes.position = view * 0.5
	motes.emission_rect_extents = view * 0.6
	motes.direction = Vector2(0.2, -1.0)
	motes.spread = 40.0
	motes.gravity = Vector2(0, -3)
	motes.initial_velocity_min = 4.0
	motes.initial_velocity_max = 18.0
	motes.scale_amount_min = scale_range.x
	motes.scale_amount_max = scale_range.y
	motes.color_ramp = life
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	motes.material = add
	parent.add_child(motes)


static func diamond(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), color)


## Line that thins and fades as it extends away from `from` in direction `dir` (±1).
static func flourish(ci: CanvasItem, from: Vector2, length: float, dir: float, color: Color) -> void:
	var steps := 12
	for s in steps:
		var t0 := float(s) / steps
		var t1 := float(s + 1) / steps
		var c := Color(color, color.a * (1.0 - t0))
		ci.draw_line(from + Vector2(dir * length * t0, 0), from + Vector2(dir * length * t1, 0), c, lerpf(2.0, 0.5, t0), true)
