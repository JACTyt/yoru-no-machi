extends RefCounted
## Combat feedback: hit sparks, flashes, dust, hit-stop, slow motion and post-process cues.

const TimeScale := preload("res://scripts/combat/time_scale.gd")


static func hit_spark(parent: Node, pos: Vector3, color: Color, big: bool) -> void:
	var spark_mat := StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	spark_mat.albedo_color = color.lightened(0.4)
	var streak := BoxMesh.new()
	streak.size = Vector3(0.025, 0.45 if big else 0.28, 0.025)
	streak.material = spark_mat

	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(1, 0))

	var p := CPUParticles3D.new()
	p.mesh = streak
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 20 if big else 10
	p.lifetime = 0.3
	p.particle_flag_align_y = true
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 16.0 if big else 10.0
	p.damping_min = 10.0
	p.damping_max = 16.0
	p.gravity = Vector3(0, -6, 0)
	p.scale_amount_curve = shrink
	p.position = pos
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)

	_flash(parent, pos, color, 3.2 if big else 2.0, 0.14)


static func dust(parent: Node, pos: Vector3) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	var puff := QuadMesh.new()
	puff.size = Vector2(0.5, 0.5)
	puff.material = mat
	var fade := Gradient.new()
	fade.set_color(0, Color(0.85, 0.82, 0.95, 0.5))
	fade.set_color(1, Color(0.85, 0.82, 0.95, 0.0))

	var p := CPUParticles3D.new()
	p.mesh = puff
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 8
	p.lifetime = 0.45
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.5
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.color_ramp = fade
	p.position = pos + Vector3.UP * 0.1
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


static func _flash(parent: Node, pos: Vector3, color: Color, size: float, time: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(color.lightened(0.6), 1.0)
	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	var flash := MeshInstance3D.new()
	flash.mesh = sphere
	flash.material_override = mat
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.position = pos
	parent.add_child(flash)
	var tw := flash.create_tween().set_parallel()
	tw.tween_property(flash, "scale", Vector3.ONE * size, time).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, time)
	tw.chain().tween_callback(flash.queue_free)


## Freezes the action for a few frames so hits feel heavy.
static func hit_stop(tree: SceneTree, duration: float) -> void:
	TimeScale.request(tree, "hit_stop", 0.03, duration)


static func slow_motion(tree: SceneTree, scale: float, duration: float) -> void:
	TimeScale.request(tree, "slow_motion", scale, duration)


## Flat ring racing outward along the ground (strong attack release).
static func shockwave(parent: Node, pos: Vector3, color: Color) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.92
	torus.outer_radius = 1.0
	torus.rings = 48
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = color
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ring)
	ring.global_position = pos
	ring.scale = Vector3(0.3, 0.6, 0.3)
	var tw := ring.create_tween().set_parallel()
	tw.tween_property(ring, "scale", Vector3(5.0, 1.5, 5.0), 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tw.chain().tween_callback(ring.queue_free)


## Stylised two-tone "impact frame" flashed over the whole screen.
static func impact_frame(tree: SceneTree, duration: float) -> void:
	set_post(tree, "impact", 1.0)
	tree.create_timer(duration, true, false, true).timeout.connect(func(): set_post(tree, "impact", 0.0))


static func set_post(tree: SceneTree, param: String, value: float) -> void:
	for node in tree.get_nodes_in_group("anime_post"):
		((node as CanvasItem).material as ShaderMaterial).set_shader_parameter(param, value)
