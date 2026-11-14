extends RefCounted
## Vector pictograms drawn straight onto any CanvasItem: places, shop items, cars, phone apps.
## `draw(ci, id, center, half_size, tint)`; most icons use `tint`, food and drinks keep their colors.

const INK := Color(0.07, 0.05, 0.12)


static func draw(ci: CanvasItem, id: String, c: Vector2, s: float, tint := Color.WHITE) -> void:
	match id:
		"home":
			_poly(ci, [c + Vector2(0, -s), c + Vector2(s, -0.05 * s), c + Vector2(-s, -0.05 * s)], tint)
			ci.draw_rect(Rect2(c + Vector2(-0.7, -0.1) * s, Vector2(1.4, 1.0) * s), tint)
			ci.draw_rect(Rect2(c + Vector2(-0.18, 0.35) * s, Vector2(0.36, 0.55) * s), INK)
		"konbini", "bag":
			ci.draw_rect(Rect2(c + Vector2(-0.75, -0.35) * s, Vector2(1.5, 1.25) * s), tint)
			ci.draw_arc(c + Vector2(0, -0.35) * s, 0.4 * s, PI, TAU, 16, tint, 0.14 * s, true)
			if id == "konbini":
				ci.draw_rect(Rect2(c + Vector2(-0.75, 0.05) * s, Vector2(1.5, 0.18) * s), INK)
		"pharmacy", "medkit":
			if id == "medkit":
				ci.draw_rect(Rect2(c + Vector2(-0.9, -0.65) * s, Vector2(1.8, 1.4) * s), tint)
				ci.draw_rect(Rect2(c + Vector2(-0.3, -0.85) * s, Vector2(0.6, 0.25) * s), tint)
				tint = Color(0.9, 0.15, 0.2)
				s *= 0.65
			ci.draw_rect(Rect2(c + Vector2(-0.28, -0.9) * s, Vector2(0.56, 1.8) * s), tint)
			ci.draw_rect(Rect2(c + Vector2(-0.9, -0.28) * s, Vector2(1.8, 0.56) * s), tint)
		"car_rental", "car", "car_sedan":
			_car(ci, c, s, tint, [Vector2(-1, 0.3), Vector2(-0.95, -0.05), Vector2(-0.45, -0.15), Vector2(-0.2, -0.55), Vector2(0.4, -0.55), Vector2(0.65, -0.15), Vector2(1, -0.05), Vector2(1, 0.3)])
		"car_compact":
			_car(ci, c, s, tint, [Vector2(-0.85, 0.3), Vector2(-0.85, -0.1), Vector2(-0.55, -0.6), Vector2(0.3, -0.6), Vector2(0.6, -0.15), Vector2(0.85, -0.05), Vector2(0.85, 0.3)])
		"car_coupe":
			_car(ci, c, s, tint, [Vector2(-1, 0.3), Vector2(-1, 0.0), Vector2(-0.3, -0.12), Vector2(0.0, -0.45), Vector2(0.45, -0.42), Vector2(0.85, -0.05), Vector2(1, 0.05), Vector2(1, 0.3)])
		"car_van":
			_car(ci, c, s, tint, [Vector2(-1, 0.3), Vector2(-1, -0.7), Vector2(0.55, -0.7), Vector2(0.95, -0.15), Vector2(1, 0.3)])
		"school":
			ci.draw_rect(Rect2(c + Vector2(-0.95, -0.3) * s, Vector2(1.9, 1.2) * s), tint)
			_poly(ci, [c + Vector2(-0.35, -0.3) * s, c + Vector2(0, -0.9) * s, c + Vector2(0.35, -0.3) * s], tint)
			ci.draw_circle(c + Vector2(0, -0.32) * s, 0.22 * s, INK)
			for x in [-0.65, -0.3, 0.3, 0.65]:
				ci.draw_rect(Rect2(c + Vector2(x - 0.1, 0.15) * s, Vector2(0.2, 0.25) * s), INK)
		"university":
			_poly(ci, [c + Vector2(-1, -0.45) * s, c + Vector2(0, -0.95) * s, c + Vector2(1, -0.45) * s], tint)
			for x in [-0.7, -0.23, 0.23, 0.7]:
				ci.draw_rect(Rect2(c + Vector2(x - 0.12, -0.35) * s, Vector2(0.24, 0.95) * s), tint)
			ci.draw_rect(Rect2(c + Vector2(-1, 0.65) * s, Vector2(2, 0.25) * s), tint)
		"gas":
			ci.draw_rect(Rect2(c + Vector2(-0.7, -0.85) * s, Vector2(1.0, 1.75) * s), tint)
			ci.draw_rect(Rect2(c + Vector2(-0.55, -0.65) * s, Vector2(0.7, 0.45) * s), INK)
			ci.draw_polyline(PackedVector2Array([c + Vector2(0.3, -0.4) * s, c + Vector2(0.75, -0.2) * s, c + Vector2(0.75, 0.55) * s, c + Vector2(0.55, 0.6) * s]), tint, 0.14 * s, true)
		"ev", "energy":
			if id == "energy":
				ci.draw_rect(Rect2(c + Vector2(-0.5, -0.9) * s, Vector2(1.0, 1.8) * s), Color(0.15, 0.6, 0.95))
				tint = Color(1.0, 0.9, 0.2)
				s *= 0.7
			_poly(ci, [c + Vector2(0.15, -1) * s, c + Vector2(-0.6, 0.15) * s, c + Vector2(-0.05, 0.15) * s, c + Vector2(-0.2, 1) * s, c + Vector2(0.6, -0.2) * s, c + Vector2(0.05, -0.2) * s], tint)
		"bus":
			var r := Rect2(c + Vector2(-0.8, -0.95) * s, Vector2(1.6, 1.7) * s)
			ci.draw_rect(r, tint)
			ci.draw_rect(Rect2(c + Vector2(-0.62, -0.75) * s, Vector2(1.24, 0.7) * s), INK)
			ci.draw_circle(c + Vector2(-0.45, 0.45) * s, 0.14 * s, INK)
			ci.draw_circle(c + Vector2(0.45, 0.45) * s, 0.14 * s, INK)
			ci.draw_rect(Rect2(c + Vector2(-0.65, 0.75) * s, Vector2(0.3, 0.2) * s), tint)
			ci.draw_rect(Rect2(c + Vector2(0.35, 0.75) * s, Vector2(0.3, 0.2) * s), tint)
		"bench":
			ci.draw_rect(Rect2(c + Vector2(-0.95, -0.45) * s, Vector2(1.9, 0.25) * s), tint)
			ci.draw_rect(Rect2(c + Vector2(-0.95, 0.0) * s, Vector2(1.9, 0.25) * s), tint)
			ci.draw_rect(Rect2(c + Vector2(-0.8, 0.25) * s, Vector2(0.18, 0.65) * s), tint)
			ci.draw_rect(Rect2(c + Vector2(0.62, 0.25) * s, Vector2(0.18, 0.65) * s), tint)
		"vending":
			ci.draw_rect(Rect2(c + Vector2(-0.6, -0.95) * s, Vector2(1.2, 1.9) * s), tint)
			for row in 3:
				for col in 3:
					ci.draw_rect(Rect2(c + Vector2(-0.45 + col * 0.3, -0.8 + row * 0.35) * s, Vector2(0.2, 0.25) * s), INK)
			ci.draw_rect(Rect2(c + Vector2(-0.45, 0.45) * s, Vector2(0.9, 0.25) * s), INK)
		"message":
			ci.draw_rect(Rect2(c + Vector2(-0.95, -0.75) * s, Vector2(1.9, 1.3) * s), tint)
			_poly(ci, [c + Vector2(-0.5, 0.5) * s, c + Vector2(-0.6, 0.95) * s, c + Vector2(0.0, 0.5) * s], tint)
			for x in [-0.45, 0.0, 0.45]:
				ci.draw_circle(c + Vector2(x, -0.1) * s, 0.12 * s, INK)
		"globe":
			ci.draw_circle(c, 0.9 * s, tint)
			ci.draw_arc(c, 0.9 * s, 0, TAU, 32, INK, 0.08 * s, true)
			ci.draw_line(c + Vector2(-0.9, 0) * s, c + Vector2(0.9, 0) * s, INK, 0.08 * s, true)
			ci.draw_line(c + Vector2(0, -0.9) * s, c + Vector2(0, 0.9) * s, INK, 0.08 * s, true)
			ci.draw_arc(c, 0.9 * s, -PI * 0.5, PI * 0.5, 16, INK, 0.08 * s, true)
			draw_set_ellipse(ci, c, Vector2(0.45, 0.9) * s, INK, 0.08 * s)
		"map":
			_poly(ci, [c + Vector2(-0.95, -0.7) * s, c + Vector2(-0.3, -0.9) * s, c + Vector2(0.3, -0.7) * s, c + Vector2(0.95, -0.9) * s,
				c + Vector2(0.95, 0.7) * s, c + Vector2(0.3, 0.9) * s, c + Vector2(-0.3, 0.7) * s, c + Vector2(-0.95, 0.9) * s], tint)
			ci.draw_line(c + Vector2(-0.3, -0.9) * s, c + Vector2(-0.3, 0.7) * s, INK, 0.08 * s)
			ci.draw_line(c + Vector2(0.3, -0.7) * s, c + Vector2(0.3, 0.9) * s, INK, 0.08 * s)
			ci.draw_circle(c + Vector2(0.62, -0.15) * s, 0.16 * s, Color(1.0, 0.35, 0.55))
		"onigiri":
			_poly(ci, [c + Vector2(0, -0.9) * s, c + Vector2(0.9, 0.7) * s, c + Vector2(-0.9, 0.7) * s], Color(0.98, 0.97, 0.94))
			ci.draw_rect(Rect2(c + Vector2(-0.4, 0.15) * s, Vector2(0.8, 0.55) * s), Color(0.12, 0.2, 0.15))
		"melonpan":
			ci.draw_circle(c, 0.85 * s, Color(0.98, 0.82, 0.4))
			for k in [-0.4, 0.0, 0.4]:
				ci.draw_line(c + Vector2(k - 0.4, -0.7) * s, c + Vector2(k + 0.4, 0.7) * s, Color(0.85, 0.6, 0.25), 0.07 * s)
				ci.draw_line(c + Vector2(k + 0.4, -0.7) * s, c + Vector2(k - 0.4, 0.7) * s, Color(0.85, 0.6, 0.25), 0.07 * s)
		"coffee":
			_poly(ci, [c + Vector2(-0.6, -0.5) * s, c + Vector2(0.6, -0.5) * s, c + Vector2(0.45, 0.9) * s, c + Vector2(-0.45, 0.9) * s], Color(0.95, 0.95, 0.97))
			ci.draw_rect(Rect2(c + Vector2(-0.68, -0.72) * s, Vector2(1.36, 0.25) * s), Color(0.45, 0.3, 0.22))
			ci.draw_rect(Rect2(c + Vector2(-0.5, 0.05) * s, Vector2(1.0, 0.35) * s), Color(0.55, 0.36, 0.25))
		"bento":
			ci.draw_rect(Rect2(c + Vector2(-0.95, -0.65) * s, Vector2(1.9, 1.3) * s), Color(0.2, 0.18, 0.25))
			ci.draw_rect(Rect2(c + Vector2(-0.82, -0.52) * s, Vector2(0.9, 1.04) * s), Color(0.98, 0.97, 0.94))
			ci.draw_rect(Rect2(c + Vector2(0.15, -0.52) * s, Vector2(0.67, 0.48) * s), Color(0.95, 0.5, 0.35))
			ci.draw_rect(Rect2(c + Vector2(0.15, 0.04) * s, Vector2(0.67, 0.48) * s), Color(0.5, 0.8, 0.4))
			ci.draw_circle(c + Vector2(-0.37, 0.0) * s, 0.15 * s, Color(0.9, 0.2, 0.3))
		"drink":
			ci.draw_rect(Rect2(c + Vector2(-0.45, -0.9) * s, Vector2(0.9, 1.8) * s), tint)
			ci.draw_rect(Rect2(c + Vector2(-0.45, -0.25) * s, Vector2(0.9, 0.5) * s), Color.WHITE)
		"bandage":
			var t := Transform2D(-0.6, c)
			ci.draw_set_transform_matrix(t)
			ci.draw_rect(Rect2(Vector2(-1.0, -0.35) * s, Vector2(2.0, 0.7) * s), Color(0.98, 0.85, 0.72))
			ci.draw_rect(Rect2(Vector2(-0.35, -0.35) * s, Vector2(0.7, 0.7) * s), Color(0.95, 0.72, 0.6))
			ci.draw_set_transform_matrix(Transform2D())
		"pills":
			var t := Transform2D(0.7, c)
			ci.draw_set_transform_matrix(t)
			ci.draw_circle(Vector2(-0.45, 0) * s, 0.42 * s, Color(0.95, 0.3, 0.4))
			ci.draw_circle(Vector2(0.45, 0) * s, 0.42 * s, Color.WHITE)
			ci.draw_rect(Rect2(Vector2(-0.45, -0.42) * s, Vector2(0.45, 0.84) * s), Color(0.95, 0.3, 0.4))
			ci.draw_rect(Rect2(Vector2(0.0, -0.42) * s, Vector2(0.45, 0.84) * s), Color.WHITE)
			ci.draw_set_transform_matrix(Transform2D())
		"manga":
			ci.draw_rect(Rect2(c + Vector2(-0.7, -0.9) * s, Vector2(1.4, 1.8) * s), tint)
			ci.draw_rect(Rect2(c + Vector2(-0.5, -0.65) * s, Vector2(1.0, 0.8) * s), Color.WHITE)
			ci.draw_circle(c + Vector2(0, -0.3) * s, 0.25 * s, INK)
		"gear":
			ci.draw_circle(c, 0.62 * s, tint)
			for k in 8:
				var a := TAU * k / 8.0
				var d := Vector2.from_angle(a)
				var side := Vector2(-d.y, d.x)
				_poly(ci, [c + d * 0.55 * s + side * 0.16 * s, c + d * 0.95 * s + side * 0.12 * s, c + d * 0.95 * s - side * 0.12 * s, c + d * 0.55 * s - side * 0.16 * s], tint)
			ci.draw_circle(c, 0.25 * s, INK)
		"boutique", "dress":
			# Hanger hook, shoulders and a flared dress.
			ci.draw_arc(c + Vector2(0, -0.78) * s, 0.13 * s, PI, TAU * 1.1, 10, tint if id == "dress" else INK, 0.08 * s, true)
			_poly(ci, [c + Vector2(-0.32, -0.62) * s, c + Vector2(0.32, -0.62) * s, c + Vector2(0.42, -0.2) * s, c + Vector2(0.22, -0.05) * s,
				c + Vector2(0.75, 0.9) * s, c + Vector2(-0.75, 0.9) * s, c + Vector2(-0.22, -0.05) * s, c + Vector2(-0.42, -0.2) * s], tint)
			ci.draw_rect(Rect2(c + Vector2(-0.24, -0.08) * s, Vector2(0.48, 0.1) * s), INK if id == "dress" else tint.darkened(0.4))
		"phone":
			ci.draw_rect(Rect2(c + Vector2(-0.55, -0.95) * s, Vector2(1.1, 1.9) * s), tint)
			ci.draw_rect(Rect2(c + Vector2(-0.42, -0.75) * s, Vector2(0.84, 1.35) * s), INK)
		_:
			ci.draw_circle(c, 0.8 * s, tint)


static func _poly(ci: CanvasItem, pts: Array, color: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array(pts), color)


static func _car(ci: CanvasItem, c: Vector2, s: float, tint: Color, outline: Array) -> void:
	var pts := PackedVector2Array()
	for p in outline:
		pts.append(c + p * s)
	ci.draw_colored_polygon(pts, tint)
	for x in [-0.55, 0.55]:
		ci.draw_circle(c + Vector2(x, 0.32) * s, 0.27 * s, INK)
		ci.draw_circle(c + Vector2(x, 0.32) * s, 0.11 * s, Color(0.8, 0.82, 0.88))


static func draw_set_ellipse(ci: CanvasItem, c: Vector2, radii: Vector2, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		pts.append(c + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	ci.draw_polyline(pts, color, width, true)
