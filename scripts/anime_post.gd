extends RefCounted
## Attaches the anime look to a camera: 3D ink-line overlay + full-screen 2D color grade.
## Returns {"lines": MeshInstance3D, "grade": ColorRect}. The grade rect is in group "anime_post".

const LINES_SHADER := preload("res://shaders/anime_post.gdshader")
const GRADE_SHADER := preload("res://shaders/anime_grade.gdshader")


static func attach(camera: Camera3D) -> Dictionary:
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	quad.flip_faces = true
	var lines_mat := ShaderMaterial.new()
	lines_mat.shader = LINES_SHADER
	lines_mat.render_priority = 127
	var lines := MeshInstance3D.new()
	lines.name = "InkLines"
	lines.mesh = quad
	lines.material_override = lines_mat
	lines.extra_cull_margin = 16384.0
	lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera.add_child(lines)

	# Below gameplay HUD layers (default 1), above the 3D view.
	var layer := CanvasLayer.new()
	layer.name = "AnimeGrade"
	layer.layer = -1
	camera.add_child(layer)
	var grade_mat := ShaderMaterial.new()
	grade_mat.shader = GRADE_SHADER
	var grade := ColorRect.new()
	grade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grade.material = grade_mat
	grade.add_to_group("anime_post")
	layer.add_child(grade)
	return {"lines": lines, "grade": grade}
