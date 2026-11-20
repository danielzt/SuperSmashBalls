extends Node2D
## Itens agarráveis: aparecem com chance e em lugar aleatório (chão ou plataformas).
## X/Quadrado perto de um item = pega; com o item na mão, X/Quadrado = usa ou joga.

const Art := preload("res://scripts/art.gd")
const ProjScript := preload("res://scripts/projectile.gd")

const MAX_ITEMS := 2
const LIFE := 14.0
const PICK_R := 30.0

## id: [nome, cor, peso (chance relativa)]
const TYPES := {
	"spikeball": ["Bola de espinhos", Color("8e9aa8"), 3.0],
	"bomb": ["Bomba", Color("e8743b"), 2.5],
	"mine": ["Mina", Color("b86bff"), 1.5],
	"heal": ["Maçã", Color("e84a5f"), 2.5],
	"star": ["Estrela", Color("ffd23f"), 1.0],
	"speed": ["Botas rápidas", Color("3fd0ff"), 2.0],
	"power": ["Punho de força", Color("ff6b35"), 2.0],
	"mana": ["Cristal de mana", Color("4d7cff"), 2.0],
	"bubble": ["Bolha protetora", Color("7af0c8"), 1.5],
}

var running := false
var items: Array = []   # {id, x, y, vy, t, age}
var timer := 5.0
var rate := 1.0   # frequência de itens (modo Frenético > 1)
var feed_cb: Callable = Callable()   # opcional: texto de aviso (f, texto)


func _ready() -> void:
	add_to_group("items")


func _someone_near(c: Vector2) -> bool:
	for f in get_tree().get_nodes_in_group("fighters"):
		if f.eliminated or f.respawn_t > 0.0 or f.held_item != "":
			continue
		if f.body_rect().grow(22.0).has_point(c):
			return true
	return false


func clear() -> void:
	items.clear()
	timer = randf_range(4.0, 8.0)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not running:
		if not items.is_empty():
			clear()
		return
	timer -= delta * rate
	if timer <= 0.0:
		timer = randf_range(5.0, 11.0)
		# só aparece com chance (não toda vez)
		if items.size() < MAX_ITEMS and randf() < 0.7:
			_spawn()
	for it in items.duplicate():
		it["age"] += delta
		if it["age"] > LIFE:
			items.erase(it)
			Sfx.play("i_some", 0.6)
			continue
		# cai até a superfície (acompanha plataformas móveis/desmoronáveis)
		var sy := Art.surface_below(it["x"], it["y"] - 14.0)
		if sy >= 0.0 and it["y"] >= sy - 0.5 and it["vy"] >= 0.0:
			it["y"] = sy
			it["vy"] = 0.0
		else:
			it["vy"] += 1500.0 * delta
			it["y"] += it["vy"] * delta
			if sy >= 0.0 and it["y"] > sy:
				it["y"] = sy
				it["vy"] = 0.0
		if it["y"] > 900.0:
			items.erase(it)
			continue
	queue_redraw()


func _spawn() -> void:
	var spots: Array = []   # [x, y]
	for g in Art.grounds:
		var r: Rect2 = g
		spots.append([randf_range(r.position.x + 30.0, r.end.x - 30.0), r.position.y, r.size.x])
	for pl in Art.plats:
		if not pl["on"]:
			continue
		var p: Vector2 = pl["p"]
		var h: float = float(pl["half"])
		spots.append([p.x + randf_range(-h + 20.0, h - 20.0), p.y - 6.0, h * 2.0])
	if spots.is_empty():
		return
	# sorteia o lugar ponderado pelo tamanho da superfície
	var total := 0.0
	for s in spots:
		total += float(s[2])
	var pick := randf() * total
	var chosen: Array = spots[0]
	for s in spots:
		pick -= float(s[2])
		if pick <= 0.0:
			chosen = s
			break
	# sorteia o tipo ponderado
	var wt := 0.0
	for k in TYPES:
		wt += float(TYPES[k][2])
	var r2 := randf() * wt
	var id := "heal"
	for k in TYPES:
		r2 -= float(TYPES[k][2])
		if r2 <= 0.0:
			id = k
			break
	items.append({"id": id, "x": chosen[0], "y": float(chosen[1]) - 140.0, "vy": 0.0, "age": 0.0})
	Sfx.play("i_aparece", 0.6)


func use(id: String, f: Node) -> void:
	var col: Color = TYPES[id][1]
	f.fx.append({"pos": f.global_position, "r": 70.0, "t": 0.0, "max": 0.4, "col": col})
	match id:
		"spikeball":
			_throw(f, {"type": "proj", "dmg": 13.0, "base": 260.0, "scale": 3.2, "angle": 40.0, "spiky": true,
				"off": Vector2.ZERO}, Vector2(520.0, -170.0), 17.0, 3.2, true, 950.0, 0.0)
		"bomb":
			_throw(f, {"type": "proj", "dmg": 16.0, "base": 300.0, "scale": 3.6, "angle": 55.0, "bomb": true,
				"off": Vector2.ZERO}, Vector2(430.0, -330.0), 13.0, 3.0, false, 1100.0, 95.0)
		"mine":
			var p := ProjScript.new()
			p.owner_f = f
			p.position = Vector2(f.global_position.x, f.global_position.y + f.body.y * 0.5 - 12.0)
			p.r = 12.0
			p.mode = "mine"
			p.arm = 0.8
			p.life = 14.0
			p.aoe = 70.0
			p.col = col
			p.data = {"type": "proj", "dmg": 14.0, "base": 280.0, "scale": 3.4, "angle": 60.0}
			f.get_parent().add_child(p)
			Sfx.play("i_mina", 0.8)
		"heal":
			f.percent = maxf(f.percent - 30.0, 0.0)
			Sfx.play("i_maca")
		"star":
			f.invincible = maxf(f.invincible, 5.0)
			Sfx.play("i_estrela")
		"speed":
			f.buff_spd_t = 8.0
			f.buff_spd_v = 1.45
			Sfx.play("i_botas")
		"power":
			f.buff_dmg_t = 9.0
			f.buff_dmg_v = 1.5
			Sfx.play("i_punho")
		"mana":
			f.mana = 100.0
			Sfx.play("i_mana")
		"bubble":
			f.barrier_t = 8.0
			f.barrier_hp = 40.0
			Sfx.play("i_bolha")
	if feed_cb.is_valid():
		feed_cb.call(f, "usou " + String(TYPES[id][0]))


func _throw(f: Node, data: Dictionary, v: Vector2, r: float, life: float, pierce: bool, grav: float, aoe: float) -> void:
	var p := ProjScript.new()
	p.owner_f = f
	p.position = f.global_position + Vector2(24.0 * f.facing, -10.0)
	p.vel = Vector2(v.x * f.facing, v.y)
	p.r = r
	p.data = data
	p.life = life
	p.pierce = pierce
	p.grav = grav
	p.aoe = aoe
	p.col = Color("8e9aa8") if data.has("spiky") else Color("e8743b")
	f.get_parent().add_child(p)
	Sfx.play("i_bomba" if data.has("bomb") else "i_spikeball", 0.8)


func _draw() -> void:
	for it in items:
		var id: String = it["id"]
		var col: Color = TYPES[id][1]
		var age: float = it["age"]
		var left: float = LIFE - age
		if left < 3.0 and int(age * 8.0) % 2 == 0:
			continue   # pisca antes de sumir
		var bob := sin(age * 4.0) * 3.0
		var c := Vector2(it["x"], it["y"] - 18.0 + bob)
		Art.ellipse(self, Vector2(it["x"], it["y"]), 14.0, 4.0, Color(0, 0, 0, 0.25))
		Art.circ(self, c, 24.0 + sin(age * 5.0) * 2.0, Color(col, 0.18))
		draw_icon(self, id, c, col, age)
		if _someone_near(c):
			var by := c.y - 34.0 - absf(sin(age * 6.0)) * 4.0
			Art.circ(self, Vector2(c.x, by), 11.0, Art.INK)
			Art.circ(self, Vector2(c.x, by), 9.5, Color.WHITE)
			draw_string(Art.font(), Vector2(c.x - 5.0, by + 5.5), "X", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Art.INK)


static func draw_icon(ci: CanvasItem, id: String, c: Vector2, col: Color, age: float) -> void:
	var ink := Art.INK
	match id:
		"spikeball":
			for k in 10:
				var a := k * TAU / 10.0 + age * 1.5
				var d := Vector2(cos(a), sin(a))
				Art.poly(ci, PackedVector2Array([c + d.rotated(0.2) * 9.0, c + d * 19.0, c + d.rotated(-0.2) * 9.0]), ink)
			Art.circ(ci, c, 11.0, ink)
			Art.circ(ci, c, 9.5, col)
			Art.circ(ci, c + Vector2(-3, -3), 3.0, Color(1, 1, 1, 0.7))
		"bomb":
			Art.circ(ci, c + Vector2(0, 2), 13.0, ink)
			Art.circ(ci, c + Vector2(0, 2), 11.5, Color("39363f"))
			Art.circ(ci, c + Vector2(-4, -2), 3.0, Color(1, 1, 1, 0.5))
			ci.draw_line(c + Vector2(4, -9), c + Vector2(9, -16), ink, 3.0)
			Art.circ(ci, c + Vector2(9, -16), 3.0 + sin(age * 20.0), Color("ffd23f"))
		"mine":
			for k in 8:
				var a := k * TAU / 8.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * 9.0, c + Vector2(cos(a), sin(a)) * 15.0, ink, 3.0)
			Art.circ(ci, c, 11.0, ink)
			Art.circ(ci, c, 9.5, col)
			Art.circ(ci, c, 4.0, Color(1.0, 0.25, 0.3) if int(age * 4.0) % 2 == 0 else Color(0.2, 0.1, 0.2))
		"heal":
			Art.circ(ci, c + Vector2(0, 2), 13.0, ink)
			Art.circ(ci, c + Vector2(0, 2), 11.5, col)
			Art.circ(ci, c + Vector2(-4, -2), 3.0, Color(1, 1, 1, 0.5))
			ci.draw_line(c + Vector2(0, -9), c + Vector2(3, -17), ink, 3.0)
			Art.ellipse(ci, c + Vector2(7, -13), 6.0, 3.0, Color("49c46a"))
		"star":
			var pts := PackedVector2Array()
			for q in 10:
				var an := -PI / 2.0 + q * PI / 5.0 + sin(age * 3.0) * 0.15
				pts.append(c + Vector2(cos(an), sin(an)) * (17.0 if q % 2 == 0 else 7.5))
			Art.poly(ci, pts, ink)
			var pts2 := PackedVector2Array()
			for q in 10:
				var an2 := -PI / 2.0 + q * PI / 5.0 + sin(age * 3.0) * 0.15
				pts2.append(c + Vector2(cos(an2), sin(an2)) * (14.0 if q % 2 == 0 else 6.0))
			Art.poly(ci, pts2, col)
		"speed":
			Art.poly(ci, PackedVector2Array([c + Vector2(-4, -16), c + Vector2(-14, 4), c + Vector2(-2, 2),
				c + Vector2(-8, 17), c + Vector2(14, -5), c + Vector2(2, -3), c + Vector2(8, -16)]), ink)
			Art.poly(ci, PackedVector2Array([c + Vector2(-3, -13), c + Vector2(-10, 3), c + Vector2(1, 1),
				c + Vector2(-5, 13), c + Vector2(10, -4), c + Vector2(0, -5), c + Vector2(5, -13)]), col)
		"power":
			Art.circ(ci, c, 15.0, ink)
			Art.circ(ci, c, 13.5, col)
			for k in 3:
				Art.circ(ci, c + Vector2(-6 + k * 6, -5), 4.0, col.lightened(0.3))
			ci.draw_line(c + Vector2(-8, 6), c + Vector2(8, 6), ink, 2.0)
		"mana":
			var d := PackedVector2Array([c + Vector2(0, -18), c + Vector2(12, 0), c + Vector2(0, 18), c + Vector2(-12, 0)])
			Art.poly(ci, d, ink)
			Art.poly(ci, PackedVector2Array([c + Vector2(0, -14), c + Vector2(9, 0), c + Vector2(0, 14), c + Vector2(-9, 0)]), col)
			Art.poly(ci, PackedVector2Array([c + Vector2(0, -14), c + Vector2(-9, 0), c + Vector2(0, 0)]), col.lightened(0.4))
		"bubble":
			Art.circ(ci, c, 17.0, ink)
			Art.circ(ci, c, 15.5, Color(col, 0.55))
			Art.circ(ci, c + Vector2(-6, -6), 4.0, Color(1, 1, 1, 0.8))


## Item no chão ao alcance do lutador (ou -1).
func near_index(f: Node) -> int:
	var best := -1
	var bd := 1e9
	var r: Rect2 = f.body_rect().grow(22.0)
	for i in items.size():
		var c := Vector2(items[i]["x"], items[i]["y"] - 16.0)
		if r.has_point(c):
			var d := c.distance_to(f.global_position)
			if d < bd:
				bd = d
				best = i
	return best


## Tenta pegar o item mais próximo. Devolve true se pegou.
func pickup(f: Node) -> bool:
	var i := near_index(f)
	if i < 0:
		return false
	f.held_item = String(items[i]["id"])
	items.remove_at(i)
	Sfx.play("i_pega", 0.8)
	f.fx.append({"pos": f.global_position, "r": 50.0, "t": 0.0, "max": 0.3, "col": TYPES[f.held_item][1]})
	if feed_cb.is_valid():
		feed_cb.call(f, "pegou " + String(TYPES[f.held_item][0]))
	queue_redraw()
	return true
