extends Node2D
## Cenário de fundo: céu, lua (ou sol), estrelas, colinas, nuvens, ilhas flutuantes e vagalumes.
## As cores vêm da paleta atual (Art.pal), sorteada a cada partida.

const Art := preload("res://scripts/art.gd")

var t := 0.0
var _acc := 0.0   # tempo acumulado desde o último redesenho
var stars: Array = []
var clouds: Array = []
var motes: Array = []
var minis: Array = []


func _ready() -> void:
	z_index = -10
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 80:
		stars.append({"p": Vector2(rng.randf() * 1280.0, rng.randf() * 360.0), "s": rng.randf_range(1.2, 3.6),
			"ph": rng.randf() * TAU})
	for i in 7:
		clouds.append({"x": rng.randf() * 1500.0 - 110.0, "y": 60.0 + rng.randf() * 240.0,
			"s": rng.randf_range(0.6, 1.4), "v": rng.randf_range(6.0, 18.0)})
	for i in 40:
		motes.append({"x": rng.randf() * 1280.0, "y": rng.randf() * 720.0, "v": rng.randf_range(10.0, 30.0),
			"ph": rng.randf() * TAU, "r": rng.randf_range(2.0, 4.5), "h": rng.randf()})
	for d in [[130.0, 250.0, 150.0, 0.0], [1150.0, 205.0, 120.0, 1.7], [1120.0, 440.0, 110.0, 3.1],
			[170.0, 470.0, 100.0, 4.4]]:
		minis.append({"x": d[0], "y": d[1], "w": d[2], "ph": d[3]})


func _process(delta: float) -> void:
	t += delta
	_acc += delta
	for c in clouds:
		c["x"] = float(c["x"]) + float(c["v"]) * delta
		if float(c["x"]) > 1400.0:
			c["x"] = -140.0
	for m in motes:
		m["y"] = float(m["y"]) - float(m["v"]) * delta
		if float(m["y"]) < -10.0:
			m["y"] = 730.0
	if _acc >= 1.0 / 30.0:   # cenário lento: 30 Hz bastam
		_acc = 0.0
		queue_redraw()


func _draw() -> void:
	var P := Art.pal
	_sky(P)
	_moon(P)
	var sa: float = P["star_a"]
	if sa > 0.0:
		for s in stars:
			var a := 0.45 + 0.55 * sin(t * 2.0 + float(s["ph"]))
			var sz := float(s["s"])
			if sz > 2.6:
				Art.sparkle(self, s["p"], sz * 2.2 * (0.7 + 0.3 * a), Color(1, 1, 0.9, (0.35 + 0.6 * a) * sa))
			else:
				Art.circ(self, s["p"], sz * 0.7, Color(1, 1, 0.95, (0.3 + 0.6 * a) * sa))
	_aurora(P)
	for c in clouds:
		_cloud(Vector2(float(c["x"]), float(c["y"])), float(c["s"]), P["cloud"])
	_hills(480.0, 120.0, 0.006, 0.4, P["hill1"])
	_hills(545.0, 90.0, 0.008, 2.1, P["hill2"])
	for m in minis:
		_mini_island(m, P)
	_hills(630.0, 70.0, 0.011, 4.0, P["hill3"])
	_motes(P)


func _sky(P: Dictionary) -> void:
	var top: Color = P["sky_top"]
	var mid: Color = P["sky_mid"]
	var low: Color = P["sky_low"]
	Art.grad_quad(self, PackedVector2Array([Vector2(-20, -20), Vector2(1300, -20), Vector2(1300, 300), Vector2(-20, 300)]),
		PackedColorArray([top, top, mid, mid]))
	Art.grad_quad(self, PackedVector2Array([Vector2(-20, 300), Vector2(1300, 300), Vector2(1300, 740), Vector2(-20, 740)]),
		PackedColorArray([mid, mid, low, low]))


func _moon(P: Dictionary) -> void:
	var p := Vector2(1010.0, 150.0 + sin(t * 0.5) * 4.0)
	for i in 5:
		Art.circ(self, p, 54.0 + i * 22.0, P["moon_glow"])
	Art.circ(self, p, 54.0, P["moon"])
	Art.circ(self, p + Vector2(-14, -10), 12.0, P["moon_spot"])
	Art.circ(self, p + Vector2(16, 14), 8.0, P["moon_spot"])
	Art.circ(self, p + Vector2(10, -22), 6.0, P["moon_spot"])


func _aurora(P: Dictionary) -> void:
	for k in 2:
		var col: Color = P["aurora1"] if k == 0 else P["aurora2"]
		if col.a <= 0.0:
			continue
		var pts := PackedVector2Array()
		for i in 28:
			var x := -20.0 + i * 50.0
			pts.append(Vector2(x, 120.0 + k * 60.0 + sin(x * 0.01 + t * 0.4 + k * 2.0) * 38.0))
		Art.polyline(self, pts, col, 70.0, true)


func _cloud(p: Vector2, s: float, col: Color) -> void:
	Art.rrect(self, Rect2(p + Vector2(-52.0, 4.0) * s, Vector2(104.0, 22.0) * s), 11.0 * s, col)
	for d in [[-34.0, 6.0, 18.0], [-12.0, -8.0, 26.0], [18.0, -3.0, 22.0], [40.0, 8.0, 16.0]]:
		Art.circ(self, p + Vector2(d[0], d[1]) * s, d[2] * s, col)


func _hills(base: float, amp: float, f: float, ph: float, col: Color) -> void:
	var pts := PackedVector2Array()
	pts.append(Vector2(-20, 740))
	for i in 34:
		var x := -20.0 + i * 40.0
		pts.append(Vector2(x, base - amp * (0.5 + 0.5 * sin(x * f * 6.0 + ph)) - amp * 0.35 * sin(x * f * 14.0 + ph * 1.7)))
	pts.append(Vector2(1300, 740))
	Art.poly(self, pts, col)


func _motes(P: Dictionary) -> void:
	var h0: float = P["mote_h"]
	var sat: float = P["mote_s"]
	for m in motes:
		var x := float(m["x"]) + sin(t * 0.8 + float(m["ph"])) * 18.0
		var y := float(m["y"])
		var c := Color.from_hsv(fposmod(h0 + float(m["h"]) * 0.08, 1.0), sat, 1.0)
		var r := float(m["r"]) * (0.8 + 0.2 * sin(t * 3.0 + float(m["ph"])))
		Art.circ(self, Vector2(x, y), r * 3.2, Color(c, 0.1))
		Art.circ(self, Vector2(x, y), r, Color(c, 0.85))


func _mini_island(m: Dictionary, P: Dictionary) -> void:
	var w := float(m["w"])
	var x := float(m["x"])
	var y := float(m["y"]) + sin(t * 0.9 + float(m["ph"])) * 8.0
	var rock := PackedVector2Array([Vector2(x - w / 2.0, y), Vector2(x + w / 2.0, y), Vector2(x + w * 0.32, y + w * 0.3),
		Vector2(x + w * 0.1, y + w * 0.58), Vector2(x - w * 0.12, y + w * 0.44), Vector2(x - w * 0.34, y + w * 0.28)])
	Art.poly(self, rock, P["mini_rock"])
	var cr: Color = P["crystal1"]
	Art.circ(self, Vector2(x - w * 0.1, y + w * 0.62), 4.0, Color(cr, 0.5 + 0.4 * sin(t * 2.0 + x)))
	Art.rrect(self, Rect2(x - w / 2.0 - 3.0, y - 9.0, w + 6.0, 16.0), 8.0, P["mini_grass"])
	# arvorezinha
	Art.rrect(self, Rect2(x + w * 0.12, y - 34.0, 5.0, 28.0), 2.0, P["trunk"])
	Art.circ(self, Vector2(x + w * 0.12 + 2.5, y - 42.0), 16.0, P["leaf1"])
	Art.circ(self, Vector2(x + w * 0.12 + 14.0, y - 34.0), 11.0, P["leaf2"])
	Art.circ(self, Vector2(x + w * 0.12 - 10.0, y - 34.0), 11.0, P["leaf2"])
