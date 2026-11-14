extends Node3D
## A lost item lying on the sidewalk: bobbing, glowing, labelled. The world picks it up when the
## heroine walks over it.

const Toon := preload("res://scripts/toon.gd")

var item := "item"
var owner_npc ## Civilian waiting for it.

var _gem: MeshInstance3D
var _t := 0.0


func _ready() -> void:
	add_to_group("pickups")
	_gem = Toon.add_mesh(self, Toon.box(Vector3(0.22, 0.12, 0.3)), Color(1.0, 0.85, 0.35), Vector3(0, 0.35, 0), true, 0.01)
	(_gem.material_override as ShaderMaterial).set_shader_parameter("emission", Color(1.0, 0.75, 0.2) * 0.8)
	var ring := Toon.add_mesh(self, Toon.cylinder(0.55, 0.02), Color(1.0, 0.85, 0.35), Vector3(0, 0.02, 0), false)
	(ring.material_override as ShaderMaterial).set_shader_parameter("emission", Color(1.0, 0.75, 0.2) * 0.5)
	var label := Label3D.new()
	label.text = item.capitalize()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.pixel_size = 0.004
	label.outline_size = 10
	label.outline_modulate = Color(0.1, 0.05, 0.02)
	label.modulate = Color(1.0, 0.9, 0.6)
	label.position.y = 0.85
	add_child(label)


func _process(delta: float) -> void:
	_t += delta
	_gem.position.y = 0.35 + sin(_t * 3.0) * 0.08
	_gem.rotation.y += delta * 2.0
