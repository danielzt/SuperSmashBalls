extends Node2D
## Camada de efeitos: faíscas, poeira, anéis, estrelinhas e tremor de tela (via câmera).

const Art := preload("res://scripts/art.gd")

var parts: Array = []
var shake := 0.0
var cam: Camera2D


func _ready() -> void:
	add_to_group("fxlayer")
	z_index = 20
	cam = Camera2D.new()
	cam.position = Vector2(640, 360)
	add_child(cam)


func _add(p: Vector2, v: Vector2, life: float, col: Color, size: float, kind: String, g := 0.0, drag := 0.0) -> void:
	parts.append({"p": p, "v": v, "t": 0.0, "max": life, "col": col, "size": size, "kind": kind, "g": g,
		"drag": drag, "rot": randf() * TAU})


func _process(delta: float) -> void:
	for e in parts:
		e["t"] = float(e["t"]) + delta
		var v: Vector2 = e["v"]
		v.y += float(e["g"]) * delta
		v *= maxf(1.0 - float(e["drag"]) * delta, 0.0)
		e["v"] = v
		e["p"] = (e["p"] as Vector2) + v * delta
	parts = parts.filter(func(e): return float(e["t"]) < float(e["max"]))
	shake = maxf(shake - 24.0 * delta, 0.0)
	cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake if shake > 0.1 else Vector2.ZERO
	queue_redraw()


# ---------------------------------------------------------------- efeitos (chamados por call_group)

func hit_fx(pos: Vector2, col: Color, dmg: float) -> void:
	var n := 7 + int(minf(dmg, 20.0))
	for i in n:
		var a := randf() * TAU
		var sp := randf_range(160.0, 420.0 + dmg * 12.0)
		var c := Color.WHITE.lerp(col, randf() * 0.6)
		_add(pos, Vector2(cos(a), sin(a)) * sp, randf_range(0.25, 0.5), c, randf_range(5.0, 9.0), "star", 500.0, 3.0)
	_add(pos, Vector2.ZERO, 0.28, col, 34.0 + dmg * 1.6, "ring")
	_add(pos, Vector2.ZERO, 0.15, col, 24.0 + dmg * 1.1, "burst")
	var rays := 8 + int(minf(dmg, 16.0) * 0.5)
	for i in rays:
		var a := i * TAU / rays + randf() * 0.3
		_add(pos, Vector2(cos(a), sin(a)) * randf_range(300.0, 620.0), randf_range(0.14, 0.26),
			col.lerp(Color.WHITE, randf() * 0.35), randf_range(16.0, 30.0) + dmg * 0.7, "streak", 0.0, 6.0)
	_add(pos, Vector2.ZERO, 0.22, col.lightened(0.2), 40.0 + dmg * 1.2, "ring")
	shake = maxf(shake, minf(1.5 + dmg * 0.3, 7.0))


func swing_fx(pos: Vector2, dir: Vector2, col: Color, size: float) -> void:
	for i in 4:
		var v := dir * randf_range(80.0, 220.0) + Vector2(randf_range(-60.0, 60.0), randf_range(-90.0, 90.0))
		_add(pos + Vector2(randf_range(-size, size) * 0.4, randf_range(-size, size) * 0.4), v, randf_range(0.18, 0.32),
			Color.WHITE.lerp(col, 0.4), randf_range(3.0, 6.0), "star", 0.0, 5.0)


func poof_fx(pos: Vector2, col: Color) -> void:
	_add(pos, Vector2.ZERO, 0.3, col, 46.0, "ring")
	for i in 8:
		var a := randf() * TAU
		_add(pos, Vector2(cos(a), sin(a)) * randf_range(80.0, 260.0), randf_range(0.25, 0.45),
			Color.WHITE.lerp(col, 0.5), randf_range(4.0, 8.0), "star", 0.0, 4.0)


func shock_fx(pos: Vector2, col: Color, radius: float) -> void:
	_add(pos, Vector2.ZERO, 0.4, col, radius, "ring")
	_add(pos, Vector2.ZERO, 0.28, Color.WHITE, radius * 0.7, "ring")
	var n := 10 + int(radius / 20.0)
	for i in n:
		var a := i * TAU / n + randf() * 0.2
		_add(pos, Vector2(cos(a), sin(a)) * radius * 1.6, 0.3, Color.WHITE.lerp(col, 0.4), radius * 0.35, "streak", 0.0, 3.0)
	shake = maxf(shake, minf(2.0 + radius * 0.02, 6.0))


func boom_fx(pos: Vector2, col: Color, radius: float) -> void:
	shock_fx(pos, col, radius)
	_add(pos, Vector2.ZERO, 0.25, Color(1, 0.9, 0.6, 0.85), radius * 0.6, "puff")
	for i in 10:
		var a := randf() * TAU
		_add(pos, Vector2(cos(a), sin(a)) * randf_range(100.0, 380.0), randf_range(0.4, 0.8),
			Color(1.0, 0.7, 0.3).lerp(col, 0.4), randf_range(5.0, 9.0), "star", 500.0, 2.0)


func trail_fx(pos: Vector2, col: Color) -> void:
	_add(pos, Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0)), randf_range(0.2, 0.4),
		Color.WHITE.lerp(col, 0.5), randf_range(3.0, 6.0), "star", 0.0, 3.0)


func block_fx(pos: Vector2) -> void:
	_add(pos, Vector2.ZERO, 0.25, Color(0.5, 0.8, 1.0), 40.0, "ring")
	for i in 5:
		var a := randf() * TAU
		_add(pos, Vector2(cos(a), sin(a)) * 220.0, 0.3, Color(0.7, 0.9, 1.0), 5.0, "star", 0.0, 4.0)


func dust_fx(pos: Vector2, n: int) -> void:
	for i in n:
		var dir := -1.0 if i % 2 == 0 else 1.0
		_add(pos + Vector2(randf_range(-6.0, 6.0), 0.0), Vector2(dir * randf_range(30.0, 110.0), randf_range(-60.0, -15.0)),
			randf_range(0.25, 0.45), Color(1, 1, 1, 0.55), randf_range(3.5, 6.5), "puff", 0.0, 3.0)


func ko_fx(pos: Vector2, col: Color) -> void:
	var p := Vector2(clampf(pos.x, 24.0, 1256.0), clampf(pos.y, 24.0, 696.0))
	for i in 34:
		var a := randf() * TAU
		var sp := randf_range(150.0, 650.0)
		var c := Color.WHITE.lerp(col, randf())
		_add(p, Vector2(cos(a), sin(a)) * sp, randf_range(0.5, 1.0), c, randf_range(7.0, 15.0), "star", 0.0, 1.8)
	_add(p, Vector2.ZERO, 0.6, col, 150.0, "ring")
	_add(p, Vector2.ZERO, 0.45, Color.WHITE, 90.0, "ring")
	shake = maxf(shake, 9.0)


func respawn_fx(pos: Vector2, col: Color) -> void:
	for i in 16:
		var a := randf() * TAU
		_add(pos, Vector2(cos(a), sin(a)) * randf_range(60.0, 240.0), randf_range(0.4, 0.8),
			Color.WHITE.lerp(col, 0.5), randf_range(5.0, 10.0), "star", -120.0, 2.5)
	_add(pos, Vector2.ZERO, 0.5, col, 70.0, "ring")


# ---------------------------------------------------------------- desenho

func _draw() -> void:
	for e in parts:
		var f := float(e["t"]) / float(e["max"])
		var col: Color = e["col"]
		var p: Vector2 = e["p"]
		var s := float(e["size"])
		match String(e["kind"]):
			"star":
				Art.sparkle(self, p, s * (1.0 - f * 0.7), Color(col, col.a * (1.0 - f * f)), float(e["rot"]) + f * 3.0)
			"burst":
				var gr := s * (0.5 + 0.9 * (1.0 - pow(1.0 - f, 2.0)))
				var al := 1.0 - f * f
				var spk := 9
				for pass_i in 3:
					var rr := gr * (1.1 if pass_i == 0 else (1.0 if pass_i == 1 else 0.55))
					var cc := Art.INK if pass_i == 0 else (Color.WHITE if pass_i == 1 else col)
					cc = Color(cc, al)
					var ir := rr * 0.38
					for k in spk:
						var a := float(e["rot"]) + k * TAU / spk
						var h := PI / spk
						var tri := PackedVector2Array([p + Vector2(cos(a - h), sin(a - h)) * ir,
							p + Vector2(cos(a), sin(a)) * rr, p + Vector2(cos(a + h), sin(a + h)) * ir])
						draw_primitive(tri, PackedColorArray([cc, cc, cc]), PackedVector2Array())
						draw_primitive(PackedVector2Array([p, tri[0], tri[2]]), PackedColorArray([cc, cc, cc]), PackedVector2Array())
			"streak":
				var vv: Vector2 = e["v"]
				var d := vv.normalized() if vv.length() > 1.0 else Vector2.RIGHT
				var l := s * (1.0 - f)
				var seg := PackedVector2Array([p - d * l, p + d * l * 0.3])
				Art.polyline(self, seg, Color(Art.INK, 0.7 * (1.0 - f)), maxf(7.0 * (1.0 - f), 2.0))
				Art.polyline(self, seg, Color(col, col.a * (1.0 - f)),
					maxf(4.0 * (1.0 - f), 1.0))
			"ring":
				var rr := s * (1.0 - pow(1.0 - f, 3.0))
				Art.arc(self, p, maxf(rr, 1.0), 0.0, TAU, 40, Color(col, col.a * (1.0 - f)), maxf(7.0 * (1.0 - f), 1.0), true)
			_:
				Art.circ(self, p, s * (1.0 + f * 0.8), Color(col, col.a * (1.0 - f)))
