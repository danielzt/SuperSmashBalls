extends Node2D
## Projétil / mina / armadilha / espinho. Criado pelo fighter.gd.

const Art := preload("res://scripts/art.gd")

var owner_f: Node = null
var vel := Vector2.ZERO
var r := 12.0
var data: Dictionary = {}
var life := 2.0
var pierce := false
var grav := 0.0
var homing := 0.0
var mode := "fly"  # fly | mine | spike | trap
var arm := 0.0
var aoe := 0.0
var col := Color.WHITE
var hit_set: Array = []
var cd: Dictionary = {}
var boom_t := 0.0
var age := 0.0


func _ready() -> void:
	add_to_group("projectiles")
	process_mode = Node.PROCESS_MODE_PAUSABLE   # para no menu de pausa


func _owner_ok() -> bool:
	return owner_f != null and is_instance_valid(owner_f)


func _physics_process(delta: float) -> void:
	age += delta
	queue_redraw()
	if boom_t > 0.0:
		boom_t -= delta
		if boom_t <= 0.0:
			queue_free()
		return
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	arm = maxf(arm - delta, 0.0)
	for k in cd.keys():
		cd[k] = float(cd[k]) - delta
	if mode == "fly":
		if fmod(age, 0.04) < delta:
			get_tree().call_group("fxlayer", "trail_fx", global_position, col)
		if homing > 0.0:
			_home(delta)
		vel.y += grav * delta
		position += vel * delta
		if not Rect2(-350, -700, 1980, 1700).has_point(position):
			queue_free()
			return
		var sy := Art.surface_below(position.x, position.y - 20.0)
		if aoe > 0.0 and sy >= 0.0 and position.y >= sy:
			_explode()
			return
	if arm > 0.0:
		return
	for f in get_tree().get_nodes_in_group("fighters"):
		if f == owner_f or f.eliminated or f.respawn_t > 0.0:
			continue
		if not f.body_rect().grow(r).has_point(position):
			continue
		if mode == "spike":
			if float(cd.get(f.get_instance_id(), 0.0)) > 0.0:
				continue
		elif hit_set.has(f):
			continue
		if aoe > 0.0:
			_explode()
			return
		var dirx := 1 if f.global_position.x >= position.x else -1
		if mode == "fly" and absf(vel.x) > 1.0:
			dirx = 1 if vel.x > 0.0 else -1
		var atk: Node = owner_f if _owner_ok() else null
		if f.take_hit(data, dirx, atk):
			hit_set.append(f)
			if mode == "spike":
				cd[f.get_instance_id()] = 0.8
			elif not pierce:
				queue_free()
				return


func _home(delta: float) -> void:
	var best: Node = null
	var bd := 1e9
	for f in get_tree().get_nodes_in_group("fighters"):
		if f == owner_f or f.eliminated or f.respawn_t > 0.0:
			continue
		var d := position.distance_to(f.global_position)
		if d < bd:
			bd = d
			best = f
	if best == null:
		return
	var target_pos: Vector2 = best.global_position
	var want: float = (target_pos - position).angle()
	var diff: float = wrapf(want - vel.angle(), -PI, PI)
	var step: float = deg_to_rad(homing) * delta
	vel = vel.rotated(clampf(diff, -step, step))


func _explode() -> void:
	boom_t = 0.18
	Sfx.play("explosao", 0.8)
	get_tree().call_group("fxlayer", "boom_fx", global_position, col, maxf(aoe, 40.0))
	var atk: Node = owner_f if _owner_ok() else null
	for f in get_tree().get_nodes_in_group("fighters"):
		if f == owner_f or f.eliminated or f.respawn_t > 0.0:
			continue
		if f.body_rect().grow(aoe).has_point(position):
			var dirx := 1 if f.global_position.x >= position.x else -1
			f.take_hit(data, dirx, atk)
	vel = Vector2.ZERO


func _draw() -> void:
	if boom_t > 0.0:
		var f := 1.0 - boom_t / 0.18
		var rr := aoe * (0.55 + 0.45 * f)
		Art.circ(self, Vector2.ZERO, rr, Color(col, 0.35 * (1.0 - f)))
		Art.arc(self, Vector2.ZERO, rr, 0.0, TAU, 40, Color(1, 1, 1, 1.0 - f), 4.0, true)
		for k in 6:
			var a := k * TAU / 6.0 + 0.4
			var sp := Vector2(cos(a), sin(a)) * rr
			var pts := PackedVector2Array()
			for q in 8:
				var an := q * PI / 4.0
				pts.append(sp + Vector2(cos(an), sin(an)) * (9.0 if q % 2 == 0 else 3.0) * (1.0 - f))
			Art.poly(self, pts, Color(1, 1, 0.9, 1.0 - f))
		return
	match mode:
		"mine":
			var armed := arm <= 0.0
			var pulse := 0.5 + 0.5 * sin(age * 6.0)
			Art.circ(self, Vector2.ZERO, r * (1.6 + 0.3 * pulse), Color(col, 0.12 if armed else 0.05))
			for k in 8:
				var a := k * TAU / 8.0
				draw_line(Vector2(cos(a), sin(a)) * r * 0.9, Vector2(cos(a), sin(a)) * r * 1.35, Color(0.2, 0.15, 0.3), 3.0, true)
			Art.circ(self, Vector2.ZERO, r + 1.5, Color(0.2, 0.15, 0.3))
			Art.circ(self, Vector2.ZERO, r, Color(col, 0.95) if armed else Color(col, 0.4))
			Art.circ(self, Vector2.ZERO, r * 0.42, Color(1.0, 0.25, 0.3) if int(age * 6.0) % 2 == 0 else Color(0.2, 0.1, 0.2))
		"spike":
			var tri := PackedVector2Array([Vector2(-r, 10), Vector2(0, -r * 1.4), Vector2(r, 10)])
			Art.poly(self, tri, col.darkened(0.3))
			Art.poly(self, PackedVector2Array([Vector2(-r * 0.6, 10), Vector2(0, -r * 1.1), Vector2(r * 0.2, 10)]), col.lightened(0.25))
		"trap":
			var pulse2 := 0.5 + 0.5 * sin(age * 4.0)
			Art.arc(self, Vector2.ZERO, r * (1.0 + 0.1 * pulse2), 0.0, TAU, 24, col, 4.0, true)
			Art.arc(self, Vector2.ZERO, r * 0.55, age * 2.0, age * 2.0 + PI * 1.4, 12, Color(col, 0.7), 3.0, true)
			draw_line(Vector2(-r, 0), Vector2(r, 0), Color(col, 0.6), 2.0, true)
		_ when bool(data.get("super", false)):
			# onda de energia azul do golpe supremo
			var dir2 := Vector2(signf(vel.x) if absf(vel.x) > 1.0 else 1.0, 0.0)
			for i in range(7, 0, -1):   # rastro
				var a2 := 0.16 * (1.0 - i / 8.0)
				Art.circ(self, -dir2 * r * 0.55 * i, r * (1.0 - i * 0.09), Color(0.2, 0.5, 1.0, a2 + 0.05))
			Art.circ(self, Vector2.ZERO, r * 1.35, Color(0.15, 0.4, 1.0, 0.18))
			Art.circ(self, Vector2.ZERO, r * 1.05, Color(0.2, 0.5, 1.0, 0.75))
			Art.circ(self, Vector2.ZERO, r * 0.72, Color(0.55, 0.82, 1.0, 0.9))
			Art.circ(self, Vector2.ZERO, r * 0.4, Color(0.97, 1.0, 1.0))
			Art.arc(self, dir2 * r * 0.2, r * 1.15, -PI * 0.5 - 0.9 * dir2.x, -PI * 0.5 + 0.9 * dir2.x + PI * (1.0 - dir2.x) * 0.0, 16, Color(0.9, 0.98, 1.0, 0.9), 4.0, true)
			for q in 8:
				var an := age * 14.0 + q * TAU / 8.0
				Art.sparkle(self, Vector2(cos(an), sin(an)) * r * 1.25, 7.0, Color(0.85, 0.97, 1.0), an)
		_ when bool(data.get("spiky", false)):
			for k in 10:
				var a := k * TAU / 10.0 + age * 9.0
				var d := Vector2(cos(a), sin(a))
				Art.poly(self, PackedVector2Array([d.rotated(0.22) * r * 0.7, d * r * 1.5, d.rotated(-0.22) * r * 0.7]), Art.INK)
			Art.circ(self, Vector2.ZERO, r * 0.95, Art.INK)
			Art.circ(self, Vector2.ZERO, r * 0.8, Color("8e9aa8"))
			Art.circ(self, Vector2(-r * 0.25, -r * 0.25), r * 0.22, Color(1, 1, 1, 0.7))
		_:
			var dir := -vel.normalized() if vel.length() > 1.0 else Vector2.ZERO
			for i in range(4, 0, -1):
				Art.circ(self, dir * r * 0.85 * i, r * (1.0 - i * 0.17), Color(col, 0.34 * (1.0 - i * 0.2)))
			Art.circ(self, Vector2.ZERO, r * 2.0, Color(col, 0.14))
			Art.circ(self, Vector2.ZERO, r + 1.5, Color(col.darkened(0.4), 0.9))
			Art.circ(self, Vector2.ZERO, r, col)
			Art.circ(self, Vector2.ZERO, r * 0.55, Color.WHITE)
