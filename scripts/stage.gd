extends Node2D
## Palco da luta: chão, plataformas (fixas, móveis ou que desmoronam) e os perigos de cada mapa.
## Os dados dos mapas ficam em stages.gd; as cores vêm da paleta atual (Art.pal).

const Art := preload("res://scripts/art.gd")
const Stages := preload("res://scripts/stages.gd")

const YELLOW := Color("f0c24a")
const DARK := Color("1d1a24")

var id := 0
var data: Dictionary = {}
var running := false      # os perigos só funcionam durante a luta
var t := 0.0
var solids: Array = []    # StaticBody2D do chão
var plats: Array = []     # plataformas em jogo (ver load_stage)
var hz: Array = []        # perigos (cópia dos dados, com estado)
var objs: Array = []      # meteoros, balas, estalactites, explosões
var pending: Array = []
var cds: Dictionary = {}  # recarga de dano por perigo + lutador
var rng := RandomNumberGenerator.new()
var gr_all: Array = []    # retângulos do chão (todos, mesmo os que sumiram)
var gr_on: Array = []     # true = bloco de chão presente (Tabuleiro Instável)
var _sn: Dictionary = {}  # estado dos sons dos perigos (disparo por borda / recarga)


func _ready() -> void:
	z_index = -5
	if data.is_empty():
		load_stage(0)


func _shape(size: Vector2, one_way: bool) -> CollisionShape2D:
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = size
	cs.shape = rs
	cs.one_way_collision = one_way
	return cs


func load_stage(i: int) -> void:
	for b in solids:
		(b as Node).queue_free()
	for pl in plats:
		(pl["body"] as Node).queue_free()
	solids.clear()
	plats.clear()
	objs.clear()
	pending.clear()
	cds.clear()
	_sn.clear()
	id = i
	data = Stages.get_stage(i)
	t = 0.0
	rng.randomize()
	var gl: Array = []
	for g in data["ground"]:
		var r := Rect2(float(g[0]), float(g[2]), float(g[1]) - float(g[0]), float(g[3]))
		var b := StaticBody2D.new()
		b.collision_layer = 1
		b.collision_mask = 0
		b.position = r.get_center()
		b.add_child(_shape(r.size, false))
		add_child(b)
		solids.append(b)
		gl.append(r)
	gr_all = gl.duplicate()
	gr_on = []
	for _g in gl:
		gr_on.append(true)
	Art.grounds = gl
	for pd in data["plats"]:
		var half: float = pd["half"]
		var base := Vector2(float(pd["x"]), float(pd["y"]))
		var b := AnimatableBody2D.new()
		b.collision_layer = 4
		b.collision_mask = 0
		b.sync_to_physics = true
		b.position = base
		var cs := _shape(Vector2(half * 2.0, 12.0), true)
		b.add_child(cs)
		add_child(b)
		plats.append({"base": base, "p": base, "half": half, "mx": float(pd["mx"]), "my": float(pd["my"]),
			"sp": float(pd["sp"]), "ph": float(pd["ph"]), "crumble": bool(pd["crumble"]), "circ": bool(pd.get("circ", false)),
			"state": 0, "st": 0.0, "off": 0.0, "fv": 0.0, "body": b, "cs": cs})
	Art.respawn = data["respawn"]
	Art.lava_danger = -1.0
	Art.grav = 1.0
	Art.fric = 1.0
	hz.clear()
	for h in data["hz"]:
		hz.append((h as Dictionary).duplicate(true))
		if String(h["type"]) == "ice":
			Art.fric = float(h["fric"])
	_update_plats(0.0)
	_sync_art()
	queue_redraw()


# ---------------------------------------------------------------- atualização

var rate := 1.0   # velocidade dos perigos e plataformas (modo Frenético > 1)


func _physics_process(delta: float) -> void:
	if running:
		t += delta * rate
		for k in cds.keys():
			cds[k] = float(cds[k]) - delta * rate
	_update_plats(delta)
	if running:
		_update_hazards(delta * rate)
	_sync_art()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _update_plats(delta: float) -> void:
	for pl in plats:
		var w := t * float(pl["sp"]) + float(pl["ph"])
		# "circ": gira em círculo (roda gigante); senão vai e volta
		var p: Vector2 = (pl["base"] as Vector2) + Vector2(float(pl["mx"]) * (cos(w) if pl["circ"] else sin(w)),
			float(pl["my"]) * sin(w))
		pl["p"] = p
		if pl["crumble"] and running:
			_crumble(pl, delta)
		(pl["body"] as Node2D).position = p + Vector2(0.0, float(pl["off"]))


func _crumble(pl: Dictionary, delta: float) -> void:
	match int(pl["state"]):
		0:
			for f in _alive():
				if _standing_on(f, pl):
					pl["state"] = 1
					pl["st"] = 1.0
					break
		1:
			pl["st"] = float(pl["st"]) - delta
			if float(pl["st"]) <= 0.0:
				pl["state"] = 2
				pl["st"] = 3.0
				pl["fv"] = 0.0
				(pl["cs"] as CollisionShape2D).set_deferred("disabled", true)
				get_tree().call_group("fxlayer", "dust_fx", pl["p"], 8)
		2:
			pl["fv"] = float(pl["fv"]) + 900.0 * delta
			pl["off"] = minf(float(pl["off"]) + float(pl["fv"]) * delta, 900.0)
			pl["st"] = float(pl["st"]) - delta
			if float(pl["st"]) <= 0.0:
				pl["state"] = 3
				pl["st"] = 0.8
				pl["off"] = 0.0
		3:
			pl["st"] = float(pl["st"]) - delta
			if float(pl["st"]) <= 0.0:
				pl["state"] = 0
				(pl["cs"] as CollisionShape2D).set_deferred("disabled", false)


func _standing_on(f: Node, pl: Dictionary) -> bool:
	if not f.is_on_floor():
		return false
	var p: Vector2 = pl["p"]
	var feet := _feet(f)
	return absf(f.global_position.x - p.x) < float(pl["half"]) + float(f.body.x) * 0.5 \
		and absf(feet - (p.y - 6.0)) < 6.0


func _sync_art() -> void:
	var arr: Array = []
	for pl in plats:
		arr.append({"p": (pl["p"] as Vector2) + Vector2(0.0, float(pl["off"])), "half": pl["half"],
			"on": int(pl["state"]) <= 1})
	Art.plats = arr


func _alive() -> Array:
	var out: Array = []
	for f in get_tree().get_nodes_in_group("fighters"):
		if not f.eliminated and f.respawn_t <= 0.0 and f.visible:
			out.append(f)
	return out


func _feet(f: Node) -> float:
	return f.global_position.y + float(f.body.y) / 2.0


func _away(f: Node, x: float) -> int:
	return 1 if f.global_position.x >= x else -1


func _cyc(h: Dictionary) -> float:
	return fposmod(t + float(h.get("ph", 0.0)), float(h["period"]))


func _cnum(h: Dictionary) -> int:
	return int(floor((t + float(h.get("ph", 0.0))) / float(h["period"])))


func _rect_hit(f: Node, r: Rect2) -> bool:
	var br: Rect2 = f.body_rect()
	return br.intersects(r)


func _circ_hit(f: Node, c: Vector2, r: float) -> bool:
	var br: Rect2 = f.body_rect()
	var q := Vector2(clampf(c.x, br.position.x, br.end.x), clampf(c.y, br.position.y, br.end.y))
	return q.distance_to(c) < r


## Dano de perigo (não pode ser bloqueado pelo escudo). Cada perigo tem recarga por lutador.
func _hurt(f: Node, key: String, dmg: float, base: float, sc: float, ang: float, dir_x: int, cd := 0.6, snd := "") -> void:
	var k := "%s#%d" % [key, f.get_instance_id()]
	if float(cds.get(k, 0.0)) > 0.0:
		return
	if f.take_hit({"dmg": dmg, "base": base, "scale": sc, "angle": ang, "ub": true}, dir_x, null):
		cds[k] = cd
		if snd != "":
			Sfx.play(snd, 0.8)


## Empurra um lutador (vento, esteira, buraco negro).
func _push(f: Node, dx: float, dy := 0.0) -> void:
	if f.grabbed_by != null or f.pin_t > 0.0:
		return
	f.global_position += Vector2(dx, dy)


## Toca o som uma vez quando a condição passa de falsa para verdadeira.
func _edge(k: String, on: bool, snd: String, vol := 1.0) -> void:
	if on and not bool(_sn.get(k, false)):
		Sfx.play(snd, vol)
	_sn[k] = on


## Toca o som repetidamente, no máximo a cada `every` segundos.
func _pulse(k: String, every: float, snd: String, vol := 1.0) -> void:
	if t - float(_sn.get(k, -99.0)) >= every:
		_sn[k] = t
		Sfx.play(snd, vol)


func _update_hazards(delta: float) -> void:
	var alive := _alive()
	for i in hz.size():
		var h: Dictionary = hz[i]
		var key := "h%d" % i
		match String(h["type"]):
			"saw":
				var pos := _saw_pos(h)
				for f in alive:
					if f.global_position.distance_to(pos) < 320.0:
						_pulse(key, 1.0, "serra", 0.5)
					if _circ_hit(f, pos, float(h["r"])):
						_hurt(f, key, 10.0, 380.0, 2.6, 55.0, _away(f, pos.x))
			"lava":
				var lv: float = _lava(h)[0]
				var lc := _cyc(h)
				var lp: float = h["period"]
				_edge(key, lc >= lp * 0.5 and lc < lp * 0.5 + 4.5, "lava", 0.8)
				# perigo para a IA: do aviso até a lava baixar de novo
				Art.lava_danger = float(h["high"]) if lc >= lp * 0.5 and lc < lp * 0.5 + 7.5 else lv
				for f in alive:
					if _feet(f) > lv + 6.0:
						# lava é morte imediata (perde uma vida, mesmo invencível)
						get_tree().call_group("fxlayer", "dust_fx", Vector2(f.global_position.x, lv), 12)
						f._ko()
			"laser":
				_edge(key, _laser_state(h) == 2, "laser", 0.7)
				if _laser_state(h) == 2:
					var r := Rect2(float(h["x0"]), float(h["y"]) - 8.0, float(h["x1"]) - float(h["x0"]), 16.0)
					for f in alive:
						if _rect_hit(f, r):
							_hurt(f, key, 12.0, 420.0, 2.6, 50.0, _away(f, 640.0))
			"meteor", "stalactite":
				h["acc"] = float(h["acc"]) + delta
				if float(h["acc"]) >= float(h["every"]):
					h["acc"] = 0.0
					_spawn_falling(h)
			"wind":
				var w := _wind(h)
				var s: float = w[1]
				_edge(key, s > 0.0, "vento", 0.6)
				if s > 0.0:
					for f in alive:
						_push(f, float(w[0]) * s * (1.0 if f.is_on_floor() else 1.5) * delta)
			"train":
				var tr := _train(h)
				_edge(key, int(tr["s"]) == 1, "trem", 0.8)
				if int(tr["s"]) == 2:
					for f in alive:
						if _rect_hit(f, tr["r"]):
							_hurt(f, key, 22.0, 650.0, 3.4, 40.0, int(tr["dir"]), 1.0)
			"crusher":
				var cr := _crusher(h)
				var ph: int = cr[1]
				_edge(key, ph == 2, "prensa", 0.8)
				if ph == 2 or (ph == 3 and _cyc(h) / float(h["period"]) < 0.76):
					for f in alive:
						if _rect_hit(f, _crusher_rect(h, float(cr[0]))):
							_hurt(f, key, 18.0, 430.0, 3.2, 30.0, _away(f, float(h["x"])), 0.8)
			"conveyor":
				for f in alive:
					var fx: float = f.global_position.x
					if f.is_on_floor() and absf(_feet(f) - float(h["y"])) < 6.0 and fx > float(h["x0"]) \
							and fx < float(h["x1"]):
						_push(f, float(h["v"]) * delta)
						_pulse(key, 0.55, "p_esteira", 0.25)
			"electric":
				var n := _cnum(h)
				var segs: Array = h["segs"]
				if int(h.get("n", -999)) != n:
					h["n"] = n
					var cur: Array = [rng.randi() % segs.size()]
					if rng.randf() < 0.35:
						cur.append((int(cur[0]) + 1 + rng.randi() % (segs.size() - 1)) % segs.size())
					h["cur"] = cur
				var c := _cyc(h)
				_edge(key, c >= float(h["warn"]) and c < float(h["warn"]) + float(h["on"]), "eletricidade", 0.7)
				if c >= float(h["warn"]) and c < float(h["warn"]) + float(h["on"]):
					for f in alive:
						if not f.is_on_floor() or absf(_feet(f) - float(h["y"])) > 8.0:
							continue
						for si in h["cur"]:
							var sg: Array = segs[si]
							if f.global_position.x > float(sg[0]) - 10.0 and f.global_position.x < float(sg[1]) + 10.0:
								_hurt(f, key, 9.0, 430.0, 2.2, 80.0, _away(f, (float(sg[0]) + float(sg[1])) / 2.0), 0.5)
			"pendulum":
				var pe := _pendulum(h)
				for f in alive:
					if f.global_position.distance_to(pe[0]) < 300.0:
						_pulse(key + "s", 1.3, "p_pendulo", 0.35)
					if _circ_hit(f, pe[0], float(h["r"])):
						_hurt(f, key, 15.0, 480.0, 3.0, 40.0, int(pe[1]), 0.8)
			"geyser":
				var gr := _geyser_rect(h)
				_edge(key, gr.size.y > 0.0, "geiser", 0.6)
				if gr.size.y > 0.0:
					for f in alive:
						if _rect_hit(f, gr):
							_hurt(f, key, 7.0, 780.0, 1.2, 88.0, _away(f, float(h["x"])), 0.35)
			"cannon":
				var n2 := _cnum(h)
				if not h.has("n"):
					h["n"] = int(floor(float(h["ph"]) / float(h["period"])))
				if n2 != int(h["n"]):
					h["n"] = n2
					var dir: int = h["dir"]
					objs.append({"kind": "ball", "p": (h["pos"] as Vector2) + Vector2(dir * 50.0, 0.0),
						"v": Vector2(dir * float(h["speed"]), 0.0), "r": 15.0})
					h["flash"] = 0.25
					Sfx.play("canhao", 0.8)
				h["flash"] = maxf(float(h.get("flash", 0.0)) - delta, 0.0)
			"vortex":
				var c2 := _cyc(h)
				_edge(key, c2 >= float(h["warn"]) and c2 < float(h["warn"]) + float(h["on"]), "buraco_negro", 0.7)
				if c2 >= float(h["warn"]) and c2 < float(h["warn"]) + float(h["on"]):
					var pos2: Vector2 = h["pos"]
					var R: float = h["r"]
					for f in alive:
						var d: Vector2 = pos2 - f.global_position
						var dist := d.length()
						if dist < float(h["core"]):
							_hurt(f, key, 10.0, 560.0, 2.4, 70.0, -1 if rng.randf() < 0.5 else 1, 1.0)
						elif dist < R and f.hitstun <= 0.0:
							var v := d / dist * float(h["pull"]) * (0.35 + 0.65 * (1.0 - dist / R)) * delta
							_push(f, v.x, 0.0 if f.is_on_floor() else v.y)
			"spikes":
				for f in alive:
					var ft := _feet(f)
					var fx2: float = f.global_position.x
					if ft > float(h["y"]) - 16.0 and ft < float(h["y"]) + 6.0 and fx2 > float(h["x0"]) \
							and fx2 < float(h["x1"]):
						_hurt(f, key, 10.0, 620.0, 1.8, 85.0, _away(f, (float(h["x0"]) + float(h["x1"])) / 2.0), 0.5, "p_espinhos")
			"hub":
				var hp: Vector2 = h["pos"]
				for f in alive:
					if _circ_hit(f, hp, float(h["r"])):
						_hurt(f, key, 10.0, 450.0, 2.4, 50.0, _away(f, hp.x), 0.6)
			"mines":
				h["acc"] = float(h["acc"]) + delta
				if float(h["acc"]) >= float(h["every"]) and _count("mine") < 5:
					h["acc"] = 0.0
					var mx := rng.randf_range(float(h["x0"]), float(h["x1"]))
					var my := Art.surface_below(mx, -100.0)
					if my >= 0.0:
						objs.append({"kind": "mine", "p": Vector2(mx, my), "arm": 0.7, "fuse": 3.0})
						Sfx.play("p_mina_campo", 0.5)
			"tornado":
				var tw := _tornado(h)
				_edge(key, int(tw[1]) == 2, "vento", 0.8)
				if int(tw[1]) == 2:
					var tx: float = tw[0]
					var tr2 := Rect2(tx - 45.0, -100.0, 90.0, float(h["y"]) + 100.0)
					for f in alive:
						if _rect_hit(f, tr2):
							_push(f, (tx - f.global_position.x) * 2.0 * delta)
							_hurt(f, key, 5.0, 560.0, 1.6, 86.0, 1 if rng.randf() < 0.5 else -1, 0.7)
			"snowball":
				h["acc"] = float(h["acc"]) + delta
				if float(h["acc"]) >= float(h["every"]):
					h["acc"] = 0.0
					var sd := 1 if rng.randf() < 0.5 else -1
					objs.append({"kind": "snow", "dir": sd, "warn": 1.0, "x": float(h["x0"]) if sd > 0 else float(h["x1"]),
						"y": float(h["y"]), "vy": 0.0, "r": 16.0, "sp": float(h["speed"])})
					Sfx.play("p_bola_neve", 0.5)
			"lightning":
				h["acc"] = float(h["acc"]) + delta
				if float(h["acc"]) >= float(h["every"]):
					h["acc"] = 0.0
					var lx := rng.randf_range(float(h["x0"]), float(h["x1"]))
					if not alive.is_empty() and rng.randf() < 0.7:
						lx = float(alive[rng.randi() % alive.size()].global_position.x) + rng.randf_range(-40.0, 40.0)
					var ly := Art.surface_below(lx, -100.0)
					objs.append({"kind": "bolt", "x": lx, "y": ly if ly >= 0.0 else 760.0, "warn": 1.1, "on": 0.25})
					Sfx.play("p_raio_aviso", 0.6)
			"tide":
				var lv2 := _tide(h)
				var cur_dir := 1.0 if _cnum(h) % 2 == 0 else -1.0
				if int(_sn.get(key, -1)) != _cnum(h):
					_sn[key] = _cnum(h)
					Sfx.play("p_mare", 0.5)
				for f in alive:
					_edge("w%d" % f.get_instance_id(), _feet(f) > lv2 + 10.0, "p_agua", 0.7)
					if _feet(f) > lv2 + 10.0:
						# na água: boia para cima e a correnteza leva para o lado
						var fv: Vector2 = f.velocity
						fv.y = move_toward(fv.y, -260.0, 2400.0 * delta)
						f.velocity = fv
						_push(f, cur_dir * float(h["current"]) * delta)
			"bumper":
				var bp := _bumper_pos(h)
				for f in alive:
					if _circ_hit(f, bp, float(h["r"])):
						var d: Vector2 = (f.global_position - bp).normalized()
						var ang := rad_to_deg(atan2(-d.y, absf(d.x)))
						_hurt(f, key, 4.0, float(h.get("pow", 700.0)), 1.4, ang, 1 if d.x >= 0.0 else -1, 0.35)
						h["flash"] = 0.25
						_pulse(key, 0.2, "p_bumper", 0.7)
				h["flash"] = maxf(float(h.get("flash", 0.0)) - delta, 0.0)
			"ice":
				for f in alive:
					if f.is_on_floor() and absf(f.velocity.x) > 260.0:
						_pulse(key + "#%d" % f.get_instance_id(), 0.7, "p_gelo", 0.22)
			"gravity":
				var gc := _cyc(h)
				var low: bool = gc >= float(h["warn"]) and gc < float(h["warn"]) + float(h["dur"])
				Art.grav = lerpf(Art.grav, float(h["mult"]) if low else 1.0, minf(6.0 * delta, 1.0))
				if bool(_sn.get(key, false)) and not low:
					Sfx.play("p_gravidade_fim", 0.5)
				_edge(key, low, "p_gravidade", 0.6)
			"vanish":
				_vanish(h)
			"sweeper":
				var sa := t * float(h["speed"]) + float(h["ph"])
				var sdir := Vector2(cos(sa), sin(sa))
				var spos: Vector2 = h["pos"]
				_pulse(key, 1.2, "p_varredor", 0.3)
				for f in alive:
					var sd: Vector2 = f.global_position - spos
					var along := sd.dot(sdir)
					if along > 24.0 and along < float(h["len"]) and absf(sd.cross(sdir)) < 24.0:
						_hurt(f, key, 14.0, 440.0, 2.8, 60.0, _away(f, spos.x), 0.7)
			"walls":
				var wd := _wall_depth(h)
				var dep: float = wd[0]
				if int(wd[1]) >= 2 and dep > 4.0:
					var wl := Rect2(float(h["lx"]) - 80.0, 60.0, 80.0 + dep, 700.0)
					var wr := Rect2(float(h["rx"]) - dep, 60.0, 80.0 + dep, 700.0)
					for f in alive:
						if _rect_hit(f, wl):
							_hurt(f, key + "l", 16.0, 480.0, 3.0, 50.0, 1, 0.8)
						elif _rect_hit(f, wr):
							_hurt(f, key + "r", 16.0, 480.0, 3.0, 50.0, -1, 0.8)
				_edge(key + "a", int(wd[1]) == 1, "p_aviso", 0.6)
				_edge(key, int(wd[1]) == 2, "p_paredes", 0.8)
			"portal":
				var pa: Vector2 = h["a"]
				var pb: Vector2 = h["b"]
				var prr: float = h["r"]
				for f in alive:
					var kp := "portal#%d" % f.get_instance_id()
					if float(cds.get(kp, 0.0)) > 0.0:
						continue
					var fp: Vector2 = f.global_position
					var dest := Vector2.ZERO
					var go := false
					if absf(fp.x - pa.x) < 26.0 and absf(fp.y - pa.y) < prr:
						dest = pb + Vector2(0.0, fp.y - pa.y)
						go = true
					elif absf(fp.x - pb.x) < 26.0 and absf(fp.y - pb.y) < prr:
						dest = pa + Vector2(0.0, fp.y - pb.y)
						go = true
					if go:
						cds[kp] = 1.0
						get_tree().call_group("fxlayer", "dust_fx", fp, 8)
						f.global_position = dest
						get_tree().call_group("fxlayer", "dust_fx", dest, 8)
						Sfx.play("p_portal", 0.6)
			"spring":
				var spx: float = h["x"]
				var spy: float = h["y"]
				var spw: float = h["w"]
				h["anim"] = maxf(float(h.get("anim", 0.0)) - delta, 0.0)
				for f in alive:
					var sft := _feet(f)
					if absf(f.global_position.x - spx) < spw * 0.5 + 8.0 and sft > spy - 10.0 and sft < spy + 12.0 \
							and f.velocity.y > -50.0:
						var ks := "spr#%d" % f.get_instance_id()
						if float(cds.get(ks, 0.0)) <= 0.0:
							cds[ks] = 0.25
							f.velocity.y = -float(h["power"])
							h["anim"] = 0.3
							Sfx.play("p_mola", 0.6)
							get_tree().call_group("fxlayer", "dust_fx", Vector2(spx, spy), 6)
			"acid":
				var amid := (float(h["x0"]) + float(h["x1"])) / 2.0
				for f in alive:
					var afx: float = f.global_position.x
					if afx > float(h["x0"]) and afx < float(h["x1"]) and _feet(f) > float(h["y"]) - 2.0:
						_hurt(f, key, 6.0, 600.0, 1.0, 88.0, -1 if afx < amid else 1, 0.4, "p_acido")
			"stomp":
				h["acc"] = float(h["acc"]) + delta
				if float(h["acc"]) >= float(h["every"]):
					h["acc"] = 0.0
					var fx4 := rng.randf_range(float(h["x0"]), float(h["x1"]))
					if not alive.is_empty() and rng.randf() < 0.6:
						fx4 = clampf(float(alive[rng.randi() % alive.size()].global_position.x), float(h["x0"]), float(h["x1"]))
					var fy4 := Art.surface_below(fx4, -100.0)
					objs.append({"kind": "foot", "x": fx4, "y": fy4 if fy4 >= 0.0 else 780.0, "warn": 1.2, "p": -160.0,
						"v": 0.0, "had": fy4 >= 0.0})
					Sfx.play("p_pisao_aviso", 0.6)
			"orbiter":
				var op := _orbiter_pos(h)
				for f in alive:
					if f.global_position.distance_to(op) < 260.0:
						_pulse(key + "s", 1.5, "p_orbe", 0.3)
					if _circ_hit(f, op, float(h["r"])):
						_hurt(f, key, 12.0, 430.0, 2.8, 50.0, _away(f, op.x), 0.6)
			"fan":
				var fnx: float = h["x"]
				var fnw: float = h["w"]
				for f in alive:
					var fnt := _feet(f)
					if absf(f.global_position.x - fnx) < fnw * 0.5 and fnt < float(h["y"]) + 8.0 \
							and fnt > float(h["y"]) - float(h["h"]):
						if f.velocity.y > -float(h["lift"]):
							f.velocity.y = move_toward(f.velocity.y, -float(h["lift"]), 3400.0 * delta)
						_pulse(key + "s", 1.0, "vento", 0.2)
			"lavapit":
				for f in alive:
					if _feet(f) > float(h["y"]) + 4.0:
						# lava é morte imediata (perde uma vida)
						get_tree().call_group("fxlayer", "dust_fx", Vector2(f.global_position.x, float(h["y"])), 12)
						Sfx.play("lava", 0.7)
						f._ko()
			"fireball":
				h["acc"] = float(h["acc"]) + delta
				if float(h["acc"]) >= float(h["every"]):
					h["acc"] = 0.0
					var fbx := rng.randf_range(float(h["x0"]), float(h["x1"]))
					objs.append({"kind": "fire", "p": Vector2(fbx, float(h["y"])), "warn": 0.7, "y0": float(h["y"]),
						"v": Vector2(rng.randf_range(-140.0, 140.0), -rng.randf_range(700.0, 900.0))})
			"bigwave":
				var bw := _bigwave(h)
				_edge(key, int(bw["s"]) == 1, "p_mare", 0.8)
				if int(bw["s"]) == 2:
					for f in alive:
						if _rect_hit(f, bw["r"]):
							_hurt(f, key, 16.0, 560.0, 3.0, 35.0, int(bw["dir"]), 1.0)
			"spider":
				var spp := _spider_pos(h)
				for f in alive:
					if _circ_hit(f, spp, float(h["r"])):
						_hurt(f, key, 10.0, 420.0, 2.2, 70.0, _away(f, spp.x), 0.7)
			"web":
				var wzr := Rect2(float(h["x0"]), float(h["y0"]), float(h["x1"]) - float(h["x0"]), float(h["y1"]) - float(h["y0"]))
				for f in alive:
					if _rect_hit(f, wzr):
						f.slow_t = maxf(f.slow_t, 0.25)
	# objetos soltos
	var keep: Array = []
	for o in objs:
		if _obj_step(o, delta, alive):
			keep.append(o)
	objs = keep + pending
	pending = []


func _spawn_falling(h: Dictionary) -> void:
	var x := rng.randf_range(float(h["x0"]), float(h["x1"]))
	var ty := Art.surface_below(x, -100.0)
	if ty < 0.0:
		ty = 780.0
	if h["type"] == "meteor":
		Sfx.play("meteoro", 0.7)
		var start := Vector2(x - 180.0, -80.0)
		objs.append({"kind": "meteor", "p": start, "target": Vector2(x, ty), "warn": 1.0,
			"v": (Vector2(x, ty) - start).normalized() * 900.0})
	else:
		var ln := rng.randf_range(34.0, 54.0)
		Sfx.play("p_estalactite_aviso", 0.6)
		objs.append({"kind": "stal", "p": Vector2(x, ln + 6.0), "len": ln, "target": Vector2(x, ty), "warn": 1.0,
			"v": Vector2.ZERO})


func _boom(p: Vector2, radius: float, alive: Array, key: String, dmg: float) -> void:
	Sfx.play("explosao", 0.6)
	for f in alive:
		if _circ_hit(f, p, radius):
			_hurt(f, key, dmg, 430.0, 3.0, 65.0, _away(f, p.x), 0.4)
	pending.append({"kind": "boom", "p": p, "t": 0.35, "r": radius})
	get_tree().call_group("fxlayer", "dust_fx", p, 8)


## Avança um objeto; devolve false quando ele deve sumir.
func _obj_step(o: Dictionary, delta: float, alive: Array) -> bool:
	match String(o["kind"]):
		"boom":
			o["t"] = float(o["t"]) - delta
			return float(o["t"]) > 0.0
		"meteor":
			if float(o["warn"]) > 0.0:
				o["warn"] = float(o["warn"]) - delta
				return true
			o["p"] = (o["p"] as Vector2) + (o["v"] as Vector2) * delta
			var p: Vector2 = o["p"]
			for f in alive:
				if _circ_hit(f, p, 22.0):
					_boom(p, 75.0, alive, "met", 13.0)
					return false
			if p.y >= (o["target"] as Vector2).y:
				_boom(Vector2(p.x, (o["target"] as Vector2).y), 75.0, alive, "met", 13.0)
				return false
			return p.y < 800.0
		"ball":
			o["p"] = (o["p"] as Vector2) + (o["v"] as Vector2) * delta
			var bp: Vector2 = o["p"]
			for f in alive:
				if _circ_hit(f, bp, float(o["r"])):
					_hurt(f, "ball", 12.0, 430.0, 2.8, 35.0, 1 if (o["v"] as Vector2).x > 0.0 else -1, 0.3, "p_bala")
					pending.append({"kind": "boom", "p": bp, "t": 0.25, "r": 30.0})
					return false
			return bp.x > -120.0 and bp.x < 1400.0
		"stal":
			if float(o["warn"]) > 0.0:
				o["warn"] = float(o["warn"]) - delta
				return true
			o["v"] = (o["v"] as Vector2) + Vector2(0.0, 1400.0 * delta)
			o["p"] = (o["p"] as Vector2) + (o["v"] as Vector2) * delta
			var sp: Vector2 = o["p"]
			var ln: float = o["len"]
			var r := Rect2(sp.x - 11.0, sp.y - ln, 22.0, ln)
			for f in alive:
				if _rect_hit(f, r):
					_hurt(f, "stal", 12.0, 400.0, 2.8, 70.0, _away(f, sp.x), 0.4, "p_estalactite")
					pending.append({"kind": "boom", "p": sp, "t": 0.3, "r": 34.0})
					return false
			if sp.y >= (o["target"] as Vector2).y:
				pending.append({"kind": "boom", "p": Vector2(sp.x, (o["target"] as Vector2).y), "t": 0.3, "r": 34.0})
				Sfx.play("p_estalactite", 0.7)
				get_tree().call_group("fxlayer", "dust_fx", Vector2(sp.x, (o["target"] as Vector2).y), 6)
				return false
			return sp.y < 800.0
		"mine":
			if float(o["arm"]) > 0.0:
				o["arm"] = float(o["arm"]) - delta
				return true
			o["fuse"] = float(o["fuse"]) - delta
			var mp: Vector2 = (o["p"] as Vector2) + Vector2(0.0, -8.0)
			var touched := false
			for f in alive:
				if _circ_hit(f, mp, 16.0):
					touched = true
			if touched or float(o["fuse"]) <= 0.0:
				_boom(mp, 85.0, alive, "mine", 14.0)
				return false
			return true
		"snow":
			if float(o["warn"]) > 0.0:
				o["warn"] = float(o["warn"]) - delta
				return true
			var dir: int = o["dir"]
			o["x"] = float(o["x"]) + dir * float(o["sp"]) * delta
			o["r"] = minf(float(o["r"]) + 14.0 * delta, 42.0)
			# sem chão embaixo: cai
			if Art.surface_below(float(o["x"]), float(o["y"]) - 2.0) < 0.0 or float(o["vy"]) > 0.0:
				o["vy"] = float(o["vy"]) + 1400.0 * delta
				o["y"] = float(o["y"]) + float(o["vy"]) * delta
			var c := Vector2(float(o["x"]), float(o["y"]) - float(o["r"]))
			for f in alive:
				if _circ_hit(f, c, float(o["r"])):
					_hurt(f, "snow", 14.0, 450.0, 2.8, 35.0, dir, 0.6, "p_neve_impacto")
					pending.append({"kind": "boom", "p": c, "t": 0.3, "r": float(o["r"]) + 10.0})
					get_tree().call_group("fxlayer", "dust_fx", c, 10)
					return false
			return float(o["y"]) < 800.0 and float(o["x"]) > -100.0 and float(o["x"]) < 1380.0
		"bolt":
			if float(o["warn"]) > 0.0:
				o["warn"] = float(o["warn"]) - delta
				if float(o["warn"]) <= 0.0:
					Sfx.play("p_raio", 0.9)
					get_tree().call_group("fxlayer", "dust_fx", Vector2(float(o["x"]), float(o["y"])), 8)
				return true
			o["on"] = float(o["on"]) - delta
			var br := Rect2(float(o["x"]) - 22.0, -100.0, 44.0, float(o["y"]) + 100.0)
			for f in alive:
				if _rect_hit(f, br):
					_hurt(f, "bolt", 14.0, 450.0, 2.6, 80.0, _away(f, float(o["x"])), 0.5)
			return float(o["on"]) > 0.0
		"foot":
			if float(o["warn"]) > 0.0:
				o["warn"] = float(o["warn"]) - delta
				return true
			o["v"] = float(o["v"]) + 2600.0 * delta
			o["p"] = float(o["p"]) + float(o["v"]) * delta
			var fty: float = o["y"]
			if float(o["p"]) >= fty:
				var ffx: float = o["x"]
				for f in alive:
					if _rect_hit(f, Rect2(ffx - 70.0, fty - 100.0, 140.0, 110.0)):
						_hurt(f, "foot", 20.0, 520.0, 3.4, 70.0, _away(f, ffx), 0.6)
				Sfx.play("p_pisao", 0.9)
				get_tree().call_group("fxlayer", "dust_fx", Vector2(ffx, fty), 12)
				if bool(o["had"]):
					Sfx.play("p_onda", 0.5)
					for dd in [-1, 1]:
						pending.append({"kind": "wave", "x": ffx + dd * 80.0, "y": fty, "dir": dd, "life": 1.0})
				return false
			return true
		"wave":
			o["life"] = float(o["life"]) - delta
			o["x"] = float(o["x"]) + int(o["dir"]) * 430.0 * delta
			if Art.surface_below(float(o["x"]), float(o["y"]) - 2.0) < 0.0:
				return false
			var wrc := Rect2(float(o["x"]) - 22.0, float(o["y"]) - 36.0, 44.0, 36.0)
			for f in alive:
				if _rect_hit(f, wrc):
					_hurt(f, "wave", 8.0, 380.0, 2.0, 60.0, int(o["dir"]), 0.8)
			return float(o["life"]) > 0.0
		"fire":
			if float(o["warn"]) > 0.0:
				o["warn"] = float(o["warn"]) - delta
				return true
			var fbv: Vector2 = o["v"]
			fbv.y += 1500.0 * delta
			o["v"] = fbv
			var fbp: Vector2 = (o["p"] as Vector2) + fbv * delta
			o["p"] = fbp
			for f in alive:
				if _circ_hit(f, fbp, 15.0):
					_hurt(f, "fire", 12.0, 450.0, 2.8, 60.0, _away(f, fbp.x), 0.4)
					return false
			return not (fbp.y > float(o["y0"]) + 20.0 and fbv.y > 0.0)
	return false


func _count(kind: String) -> int:
	var n := 0
	for o in objs:
		if o["kind"] == kind:
			n += 1
	return n


# ---------------------------------------------------------------- estado dos perigos (também usado no desenho)

func _saw_pos(h: Dictionary) -> Vector2:
	var k := 0.5 - 0.5 * cos(t * TAU / float(h["period"]) + float(h["ph"]))
	return (h["a"] as Vector2).lerp(h["b"], k)


## [nível da lava, avisando?]
func _lava(h: Dictionary) -> Array:
	var P: float = h["period"]
	var c := _cyc(h)
	var L: float = h["low"]
	var H: float = h["high"]
	var w0 := P * 0.5
	var r0 := w0 + 2.5
	var r1 := r0 + 2.0
	var f0 := r1 + 2.5
	if c < r0:
		return [L, c >= w0]
	if c < r1:
		return [lerpf(L, H, smoothstep(0.0, 1.0, (c - r0) / 2.0)), false]
	if c < f0:
		return [H, false]
	return [lerpf(H, L, smoothstep(0.0, 1.0, (c - f0) / (P - f0))), false]


## 0 desligado, 1 aviso, 2 disparando
func _laser_state(h: Dictionary) -> int:
	var c := _cyc(h)
	if c < float(h["warn"]):
		return 1
	if c < float(h["warn"]) + float(h["on"]):
		return 2
	return 0


## [direção, força atual (0 = parado), avisando?]
func _wind(h: Dictionary) -> Array:
	var c := _cyc(h)
	var dir := 1.0 if _cnum(h) % 2 == 0 else -1.0
	var wn: float = h["warn"]
	var du: float = h["dur"]
	if c < wn:
		return [dir, 0.0, true]
	if c < wn + du:
		var e := minf(minf((c - wn) / 0.4, (wn + du - c) / 0.4), 1.0)
		return [dir, float(h["force"]) * e, false]
	return [dir, 0.0, false]


## {s: 0 nada | 1 aviso | 2 passando, dir, r}
func _train(h: Dictionary) -> Dictionary:
	var c := _cyc(h)
	var dir := 1 if _cnum(h) % 2 == 0 else -1
	var wn: float = h["warn"]
	if c < wn:
		return {"s": 1, "dir": dir}
	var front := (c - wn) * float(h["speed"])
	var L: float = h["len"]
	var x0 := -200.0 + front - L if dir > 0 else 1480.0 - front
	if (dir > 0 and x0 > 1400.0) or (dir < 0 and x0 + L < -120.0):
		return {"s": 0, "dir": dir}
	return {"s": 2, "dir": dir, "r": Rect2(x0, float(h["y"]) - float(h["h"]), L, float(h["h"]))}


## [base do bloco, fase: 0 parado, 1 tremendo, 2 descendo, 3 embaixo, 4 subindo]
func _crusher(h: Dictionary) -> Array:
	var c := _cyc(h) / float(h["period"])
	var rest: float = h["rest"]
	var gy: float = h["y"]
	if c < 0.52:
		return [rest, 0]
	if c < 0.68:
		return [rest, 1]
	if c < 0.716:
		return [lerpf(rest, gy, (c - 0.68) / 0.036), 2]
	if c < 0.84:
		return [gy, 3]
	return [lerpf(gy, rest, (c - 0.84) / 0.16), 4]


func _crusher_rect(h: Dictionary, bottom: float) -> Rect2:
	var w: float = h["w"]
	return Rect2(float(h["x"]) - w / 2.0, bottom - 90.0, w, 90.0)


## [posição da bola, direção do movimento]
func _pendulum(h: Dictionary) -> Array:
	var w := t * TAU / float(h["period"]) + float(h["ph"])
	var a := float(h["amp"]) * sin(w)
	var pos: Vector2 = (h["pivot"] as Vector2) + Vector2(sin(a), cos(a)) * float(h["len"])
	return [pos, 1 if cos(w) >= 0.0 else -1]


func _geyser_rect(h: Dictionary) -> Rect2:
	var c := _cyc(h)
	var wn: float = h["warn"]
	var on: float = h["on"]
	if c < wn or c >= wn + on:
		return Rect2()
	var k := minf((c - wn) / 0.2, 1.0) * minf((wn + on - c) / 0.25, 1.0)
	var hh := float(h["h"]) * k
	var w: float = h["w"]
	return Rect2(float(h["x"]) - w / 2.0, float(h["y"]) - hh, w, hh)


# ---------------------------------------------------------------- desenho

## Liga/desliga um bloco de chão (colisão + desenho).
func _set_ground(i: int, on: bool) -> void:
	if bool(gr_on[i]) == on:
		return
	gr_on[i] = on
	var cs := (solids[i] as Node).get_child(0) as CollisionShape2D
	cs.set_deferred("disabled", not on)
	var gl: Array = []
	for j in gr_all.size():
		if gr_on[j]:
			gl.append(gr_all[j])
	Art.grounds = gl


## Tabuleiro Instável: a cada ciclo 1-2 blocos piscam (aviso) e somem por um tempo.
func _vanish(h: Dictionary) -> void:
	var tiles := gr_all.size()
	if tiles < 2:
		return
	var n := _cnum(h)
	if int(h.get("n", -999)) != n:
		h["n"] = n
		var cur: Array = []
		var k1 := rng.randi() % tiles
		cur.append(k1)
		if tiles > 3 and rng.randf() < 0.5:
			cur.append((k1 + 2 + rng.randi() % (tiles - 3)) % tiles)
		h["cur"] = cur
	var c := _cyc(h)
	var off := c >= float(h["warn"]) and c < float(h["warn"]) + float(h["off"])
	var cur2: Array = h["cur"]
	for i in tiles:
		_set_ground(i, not (off and cur2.has(i)))
	if bool(_sn.get("vanish", false)) and not off:
		Sfx.play("p_volta", 0.5)
	_edge("vanish", off, "p_some", 0.6)


## [profundidade das paredes, fase: 0 parado | 1 aviso | 2 fechando | 3 fechada | 4 abrindo]
func _wall_depth(h: Dictionary) -> Array:
	var P: float = h["period"]
	var c := _cyc(h)
	var w0 := P - 4.5
	var md: float = h["depth"]
	if c < w0:
		return [0.0, 0]
	if c < w0 + 1.2:
		return [0.0, 1]
	if c < w0 + 1.7:
		return [md * smoothstep(0.0, 1.0, (c - w0 - 1.2) / 0.5), 2]
	if c < w0 + 2.9:
		return [md, 3]
	return [md * (1.0 - smoothstep(0.0, 1.0, (c - w0 - 2.9) / 1.6)), 4]


## Onda gigante: {s: 0 nada | 1 aviso | 2 passando, dir, r}
func _bigwave(h: Dictionary) -> Dictionary:
	var c := _cyc(h)
	var dir := 1 if _cnum(h) % 2 == 0 else -1
	var wn: float = h["warn"]
	if c < wn:
		return {"s": 1, "dir": dir}
	var L := 280.0
	var front := (c - wn) * float(h["speed"])
	var x0 := -200.0 + front - L if dir > 0 else 1480.0 - front
	if (dir > 0 and x0 > 1400.0) or (dir < 0 and x0 + L < -120.0):
		return {"s": 0, "dir": dir}
	return {"s": 2, "dir": dir, "r": Rect2(x0, float(h["y"]) - float(h["h"]), L, float(h["h"]))}


func _spider_pos(h: Dictionary) -> Vector2:
	var k := 0.5 - 0.5 * cos(t * TAU / float(h["period"]) + float(h["ph"]))
	return Vector2(float(h["x"]), lerpf(float(h["top"]), float(h["reach"]), smoothstep(0.0, 1.0, k)))


func _orbiter_pos(h: Dictionary) -> Vector2:
	var a := t * float(h["speed"]) + float(h["ph"])
	return (h["pos"] as Vector2) + Vector2(cos(a), sin(a)) * float(h["orbit"])


## [posição x do tornado, estado: 0 ausente | 1 aviso | 2 ativo]
func _tornado(h: Dictionary) -> Array:
	var c := _cyc(h)
	var wn: float = h["warn"]
	var du: float = h["dur"]
	if c < wn:
		return [h["x0"], 1]
	if c < wn + du:
		var k := 0.5 - 0.5 * cos((c - wn) / du * TAU)
		return [lerpf(float(h["x0"]), float(h["x1"]), k), 2]
	return [h["x0"], 0]


## Altura da superfície da água (maré).
func _tide(h: Dictionary) -> float:
	var k := 0.5 - 0.5 * cos(t * TAU / float(h["period"]) + float(h.get("ph", 0.0)))
	return lerpf(float(h["low"]), float(h["high"]), smoothstep(0.0, 1.0, k))


func _bumper_pos(h: Dictionary) -> Vector2:
	var w := t * TAU / float(h["period"]) + float(h.get("ph", 0.0))
	return (h["pos"] as Vector2) + (h["amp"] as Vector2) * sin(w)


func _draw() -> void:
	var P := Art.pal
	if P.is_empty():
		return
	_draw_back(P)
	var style := String(data.get("style", "grass"))
	if style == "island":
		_island(P)
	else:
		for g in Art.grounds:
			match style:
				"metal":
					_ground_metal(g, P)
				"stone":
					_ground_stone(g, P)
				_:
					_ground_grass(g, P)
	var ps := String(data.get("pstyle", "wood"))
	for pl in plats:
		_plat(pl, ps, P)
	_draw_front(P)


func _bang(p: Vector2, a := 1.0) -> void:
	var pts := PackedVector2Array([p + Vector2(0, -22), p + Vector2(20, 13), p + Vector2(-20, 13)])
	Art.poly(self, pts, Color(1.0, 0.82, 0.15, a))
	pts.append(pts[0])
	Art.polyline(self, pts, Color(0.25, 0.1, 0.0, a), 2.5, true)
	draw_string(Art.font(), p + Vector2(-20, 11), "!", HORIZONTAL_ALIGNMENT_CENTER, 40.0, 22, Color(0.2, 0.06, 0.0, a))


func _blink(speed := 12.0) -> float:
	return 0.5 + 0.5 * sin(t * speed)


# --- terreno

func _under_rock(r: Rect2, P: Dictionary) -> void:
	var x0 := r.position.x
	var x1 := r.end.x
	var w := r.size.x
	var top := r.position.y
	var bot := r.end.y
	var cx := x0 + w / 2.0
	var depth := clampf(w * 0.3, 50.0, 190.0)
	var rock := PackedVector2Array([Vector2(x0, top + 10.0), Vector2(x1, top + 10.0), Vector2(x1 - w * 0.06, bot + depth * 0.35),
		Vector2(x1 - w * 0.25, bot + depth * 0.75), Vector2(cx, bot + depth), Vector2(x0 + w * 0.25, bot + depth * 0.75),
		Vector2(x0 + w * 0.06, bot + depth * 0.35)])
	Art.poly(self, rock, P["rock1"])
	var inner := PackedVector2Array()
	for q in rock:
		inner.append(Vector2(cx, top + 10.0).lerp(q, 0.78))
	Art.poly(self, inner, P["rock2"])


func _ground_grass(r: Rect2, P: Dictionary) -> void:
	_under_rock(r, P)
	var x0 := r.position.x
	var w := r.size.x
	var top := r.position.y
	var n := int(w / 70.0)
	for i in n:
		var dx := x0 + 30.0 + i * (w - 60.0) / maxf(n - 1, 1)
		var dl := 14.0 + 10.0 * sin(dx * 0.13)
		Art.rrect(self, Rect2(dx - 5.0, top + r.size.y - 4.0, 10.0, dl + 10.0), 5.0, P["moss"])
	Art.rrect(self, Rect2(x0, top, w, r.size.y + 4.0), 16.0, P["dirt"], P["dirt_dark"], 2.0, 10)
	Art.rrect(self, Rect2(x0 - 6.0, top - 6.0, w + 12.0, 28.0), 14.0, P["grass1"])
	Art.rrect(self, Rect2(x0 - 6.0, top - 8.0, w + 12.0, 20.0), 10.0, P["grass2"])
	Art.rrect(self, Rect2(x0 + 4.0, top - 6.0, w - 8.0, 5.0), 3.0, Color(1, 1, 1, 0.3))
	var nb := int((w - 20.0) / 14.0)
	for i in nb:
		var gx := x0 + 10.0 + i * 14.0
		var hh := 7.0 + 4.0 * sin(i * 0.9)
		var sw := sin(t * 2.2 + i * 0.35) * 2.5 + sin(Time.get_ticks_msec() * 0.002 + i * 0.35) * 1.5
		Art.poly(self, PackedVector2Array([Vector2(gx - 4, top - 4), Vector2(gx + 4, top - 4),
			Vector2(gx + sw, top - 4 - hh)]), P["grass3"])


func _ground_stone(r: Rect2, P: Dictionary) -> void:
	_under_rock(r, P)
	var x0 := r.position.x
	var w := r.size.x
	var top := r.position.y
	Art.rrect(self, Rect2(x0, top, w, r.size.y), 8.0, P["rock2"], P["rock1"], 2.0, 8)
	var line: Color = Color(P["rock1"], 0.9)
	var row := 0
	var y := top + 12.0
	while y < r.end.y - 6.0:
		draw_line(Vector2(x0 + 4.0, y), Vector2(r.end.x - 4.0, y), line, 2.0)
		var y2 := minf(y + 18.0, r.end.y - 4.0)
		var bx := x0 + (24.0 if row % 2 == 0 else 48.0)
		while bx < r.end.x - 8.0:
			draw_line(Vector2(bx, y), Vector2(bx, y2), line, 2.0)
			bx += 48.0
		y += 18.0
		row += 1
	Art.rrect(self, Rect2(x0 - 4.0, top - 4.0, w + 8.0, 14.0), 6.0, P["rock3"])
	Art.rrect(self, Rect2(x0, top - 3.0, w, 4.0), 2.0, Color(1, 1, 1, 0.22))


func _ground_metal(r: Rect2, P: Dictionary) -> void:
	var x0 := r.position.x
	var w := r.size.x
	var top := r.position.y
	# vigas de sustentação
	for k in 3:
		var sx := x0 + w * (0.2 + 0.3 * k)
		Art.rrect(self, Rect2(sx - 12.0, r.end.y - 4.0, 24.0, 760.0 - r.end.y), 4.0, P["metal2"])
		draw_line(Vector2(sx - 12.0, r.end.y + 10.0), Vector2(sx + 12.0, r.end.y + 60.0), Color(P["metal1"], 0.6), 3.0)
	Art.rrect(self, Rect2(x0, top, w, r.size.y), 6.0, P["metal1"], P["metal2"], 3.0, 8)
	# faixa zebrada
	var sy := top + 16.0
	var sx2 := x0 + 8.0
	while sx2 < r.end.x - 22.0:
		Art.poly(self, PackedVector2Array([Vector2(sx2, sy + 12.0), Vector2(sx2 + 8.0, sy), Vector2(sx2 + 18.0, sy),
			Vector2(sx2 + 10.0, sy + 12.0)]), YELLOW)
		sx2 += 22.0
	draw_line(Vector2(x0 + 6.0, sy), Vector2(r.end.x - 6.0, sy), Color(0, 0, 0, 0.3), 1.5)
	draw_line(Vector2(x0 + 6.0, sy + 12.0), Vector2(r.end.x - 6.0, sy + 12.0), Color(0, 0, 0, 0.3), 1.5)
	Art.rrect(self, Rect2(x0 - 3.0, top - 3.0, w + 6.0, 10.0), 4.0, P["metal3"])
	var rx := x0 + 14.0
	while rx < r.end.x - 10.0:
		Art.circ(self, Vector2(rx, top + 2.0), 2.0, P["metal2"])
		rx += 40.0


# --- plataformas

func _plat(pl: Dictionary, style: String, P: Dictionary) -> void:
	var st: int = pl["state"]
	var p: Vector2 = (pl["p"] as Vector2) + Vector2(0.0, float(pl["off"]))
	var half: float = pl["half"]
	var a := 1.0
	if st == 1:
		p += Vector2(sin(t * 70.0) * 2.5, cos(t * 55.0) * 1.5)
	elif st == 2:
		a = clampf(1.0 - float(pl["off"]) / 400.0, 0.0, 1.0)
	elif st == 3:
		a = 1.0 - float(pl["st"]) / 0.8
	if a <= 0.01:
		return
	match style:
		"metal":
			_plat_metal(p, half, P)
		"stone":
			_plat_stone(p, half, P, a, bool(pl["crumble"]), st)
		"rock":
			_plat_rock(p, half, P)
		_:
			_plat_wood(p, half, P)


func _plat_wood(p: Vector2, half: float, P: Dictionary) -> void:
	var r := Rect2(p.x - half, p.y - 6.0, half * 2.0, 12.0)
	Art.ellipse(self, Vector2(p.x, p.y + 20.0), half * 0.92, 14.0, Color(0.7, 0.85, 1.0, 0.1))
	for f in [-0.72, -0.24, 0.38, 0.8]:
		var vx: float = f * half
		var vl := 18.0 + 10.0 * sin(vx * 0.3 + p.x)
		var sw := sin(t * 1.6 + vx) * 3.0
		var a := Vector2(p.x + vx, p.y + 4.0)
		var b := Vector2(p.x + vx + sw, p.y + 4.0 + vl)
		draw_line(a, b, P["moss"], 3.0, true)
		Art.circ(self, b, 4.5, P["grass2"])
		Art.circ(self, a.lerp(b, 0.5) + Vector2(4, 0), 3.5, P["grass3"])
	Art.rrect(self, r, 6.0, P["plank"], P["plank_dark"], 2.0, 6)
	Art.rrect(self, Rect2(r.position + Vector2(5, 1.5), Vector2(r.size.x - 10.0, 3.5)), 2.0, P["plank_light"])
	var lx := -half + 50.0
	while lx < half - 20.0:
		draw_line(Vector2(p.x + lx, r.position.y + 4.0), Vector2(p.x + lx, r.end.y - 1.0), Color(P["plank_dark"], 0.6), 1.5, true)
		lx += 50.0
	var cr: Color = P["crystal1"]
	for ex in [-half + 8.0, half - 8.0]:
		var pulse := 0.5 + 0.5 * sin(t * 2.4 + ex)
		Art.circ(self, Vector2(p.x + ex, p.y - 12.0), 12.0, Color(cr, 0.1 + 0.1 * pulse))
		Art.poly(self, PackedVector2Array([Vector2(p.x + ex - 5, p.y - 6), Vector2(p.x + ex + 5, p.y - 6),
			Vector2(p.x + ex, p.y - 20)]), cr)


func _plat_metal(p: Vector2, half: float, P: Dictionary) -> void:
	var r := Rect2(p.x - half, p.y - 6.0, half * 2.0, 14.0)
	draw_line(Vector2(p.x - half * 0.6, p.y + 8.0), Vector2(p.x - half * 0.3, p.y + 26.0), P["metal2"], 4.0)
	draw_line(Vector2(p.x + half * 0.6, p.y + 8.0), Vector2(p.x + half * 0.3, p.y + 26.0), P["metal2"], 4.0)
	Art.rrect(self, r, 4.0, P["metal1"], P["metal2"], 2.0, 6)
	Art.rrect(self, Rect2(r.position + Vector2(4, 1.5), Vector2(r.size.x - 8.0, 3.0)), 2.0, P["metal3"])
	for ex in [-half + 8.0, half - 8.0]:
		Art.circ(self, Vector2(p.x + ex, p.y + 2.0), 2.5, P["metal2"])
	var cr: Color = P["crystal1"]
	var blink := 0.5 + 0.5 * sin(t * 3.0 + p.x)
	Art.circ(self, Vector2(p.x, p.y + 2.0), 3.5, Color(cr, 0.5 + 0.5 * blink))


func _plat_stone(p: Vector2, half: float, P: Dictionary, a: float, crumble: bool, st: int) -> void:
	var r := Rect2(p.x - half, p.y - 6.0, half * 2.0, 16.0)
	var under := PackedVector2Array([Vector2(p.x - half + 6.0, p.y + 8.0), Vector2(p.x + half - 6.0, p.y + 8.0),
		Vector2(p.x + half * 0.4, p.y + 26.0), Vector2(p.x - half * 0.3, p.y + 30.0)])
	Art.poly(self, under, Color(P["rock1"], a))
	Art.rrect(self, r, 5.0, Color(P["rock2"], a), Color(P["rock1"], a), 2.0)
	Art.rrect(self, Rect2(r.position + Vector2(3, 1), Vector2(r.size.x - 6.0, 4.0)), 2.0, Color(P["rock3"], a))
	if crumble:
		var cc := Color(P["rock1"], a)
		Art.polyline(self, PackedVector2Array([Vector2(p.x - half * 0.5, p.y - 5.0), Vector2(p.x - half * 0.42, p.y + 2.0),
			Vector2(p.x - half * 0.5, p.y + 9.0)]), cc, 1.5, true)
		Art.polyline(self, PackedVector2Array([Vector2(p.x + half * 0.3, p.y - 5.0), Vector2(p.x + half * 0.38, p.y + 3.0),
			Vector2(p.x + half * 0.28, p.y + 9.0)]), cc, 1.5, true)
		if st == 1:
			Art.rrect(self, r, 5.0, Color(1.0, 0.3, 0.2, 0.25 + 0.25 * _blink(30.0)))


func _plat_rock(p: Vector2, half: float, P: Dictionary) -> void:
	var rock := PackedVector2Array([Vector2(p.x - half, p.y), Vector2(p.x + half, p.y), Vector2(p.x + half * 0.6, p.y + half * 0.28),
		Vector2(p.x + half * 0.15, p.y + half * 0.5), Vector2(p.x - half * 0.2, p.y + half * 0.4), Vector2(p.x - half * 0.65, p.y + half * 0.25)])
	Art.poly(self, rock, P["rock1"])
	var inner := PackedVector2Array()
	for q in rock:
		inner.append(Vector2(p.x, p.y).lerp(q, 0.7))
	Art.poly(self, inner, P["rock2"])
	var cr: Color = P["crystal2"]
	var tip := Vector2(p.x + half * 0.1, p.y + half * 0.5)
	Art.circ(self, tip + Vector2(0, 12), 10.0, Color(cr, 0.15 + 0.1 * sin(t * 2.0 + p.x)))
	Art.poly(self, PackedVector2Array([tip + Vector2(-6, -4), tip + Vector2(6, -4), tip + Vector2(0, 18)]), cr)
	Art.rrect(self, Rect2(p.x - half - 4.0, p.y - 8.0, half * 2.0 + 8.0, 18.0), 9.0, P["grass1"])
	Art.rrect(self, Rect2(p.x - half - 4.0, p.y - 9.0, half * 2.0 + 8.0, 12.0), 6.0, P["grass2"])
	Art.rrect(self, Rect2(p.x - half + 4.0, p.y - 8.0, half * 2.0 - 8.0, 3.0), 2.0, Color(1, 1, 1, 0.3))


# --- ilha original (mapa 0)

func _island(P: Dictionary) -> void:
	for i in 4:
		Art.circ(self, Vector2(640, 585), 300.0 + i * 70.0, Color(0.6, 0.8, 1.0, 0.03))
	for cr in [[404.0, 624.0, 36.0, 0], [466.0, 660.0, 46.0, 1], [560.0, 690.0, 32.0, 0], [724.0, 690.0, 40.0, 1],
			[816.0, 660.0, 48.0, 0], [880.0, 624.0, 34.0, 1]]:
		var cx: float = cr[0]
		var cy: float = cr[1]
		var cl: float = cr[2]
		var col: Color = P["crystal1"] if cr[3] == 0 else P["crystal2"]
		var pulse := 0.5 + 0.5 * sin(t * 2.0 + cx * 0.05 + Time.get_ticks_msec() * 0.001)
		Art.circ(self, Vector2(cx, cy + cl * 0.6), cl * 0.9, Color(col, 0.1 + 0.1 * pulse))
		Art.poly(self, PackedVector2Array([Vector2(cx - 9, cy), Vector2(cx + 9, cy), Vector2(cx + 3, cy + cl)]),
			col.lerp(Color.WHITE, 0.2 * pulse))
		Art.poly(self, PackedVector2Array([Vector2(cx - 9, cy), Vector2(cx, cy), Vector2(cx + 3, cy + cl)]),
			col.lightened(0.3))
	var rock := PackedVector2Array([Vector2(340, 534), Vector2(352, 590), Vector2(398, 636), Vector2(470, 672),
		Vector2(560, 702), Vector2(640, 738), Vector2(720, 702), Vector2(810, 672), Vector2(882, 636),
		Vector2(928, 590), Vector2(940, 534)])
	Art.poly(self, rock, P["rock1"])
	var inner := PackedVector2Array()
	for p in rock:
		inner.append(Vector2(640, 540).lerp(p, 0.9))
	Art.poly(self, inner, P["rock2"])
	var inner2 := PackedVector2Array()
	for p in rock:
		inner2.append(Vector2(640, 520).lerp(p, 0.62))
	Art.poly(self, inner2, P["rock3"])
	for dx in [370.0, 440.0, 520.0, 610.0, 700.0, 780.0, 860.0, 915.0]:
		var dl := 14.0 + 10.0 * sin(dx * 0.13)
		Art.rrect(self, Rect2(dx - 5.0, 540.0, 10.0, dl + 20.0), 5.0, P["moss"])
	Art.rrect(self, Rect2(340, 520, 600, 44), 16.0, P["dirt"], P["dirt_dark"], 2.0, 10)
	Art.rrect(self, Rect2(334, 514, 612, 28), 14.0, P["grass1"])
	Art.rrect(self, Rect2(334, 512, 612, 20), 10.0, P["grass2"])
	Art.rrect(self, Rect2(344, 514, 592, 5), 3.0, Color(1, 1, 1, 0.3))
	var tt := Time.get_ticks_msec() * 0.001
	for i in 43:
		var gx := 344.0 + i * 14.0
		var h := 7.0 + 4.0 * sin(i * 0.9)
		var sw := sin(tt * 2.2 + i * 0.35) * 2.5
		Art.poly(self, PackedVector2Array([Vector2(gx - 4, 516), Vector2(gx + 4, 516), Vector2(gx + sw, 516 - h)]),
			P["grass3"])
	var fcols := [Color("e8b04a"), Color("f3e3b0"), Color("7fb8d8"), Color("ffffff"), Color("d98a4a")]
	var k := 0
	for fx in [372.0, 410.0, 495.0, 590.0, 700.0, 790.0, 850.0, 896.0]:
		var sw := sin(tt * 2.0 + fx) * 2.0
		var top := Vector2(fx + sw, 498.0)
		draw_line(Vector2(fx, 516), top, (P["grass1"] as Color).darkened(0.2), 2.5, true)
		var fc: Color = fcols[k % fcols.size()]
		for q in 5:
			var a := q * TAU / 5.0 + tt * 0.3
			Art.circ(self, top + Vector2(cos(a), sin(a)) * 4.5, 3.4, fc)
		Art.circ(self, top, 3.0, Color("fff3a0"))
		k += 1
	var mp := Vector2(560, 513)
	Art.rrect(self, Rect2(mp.x - 3.0, mp.y - 8.0, 6.0, 10.0), 3.0, Color("fff3e0"))
	var cap := PackedVector2Array()
	for q in 13:
		var a := PI + q * PI / 12.0
		cap.append(mp + Vector2(cos(a) * 11.0, sin(a) * 9.0 - 7.0))
	Art.poly(self, cap, Color("c8553d"))
	Art.circ(self, mp + Vector2(-4, -12), 2.0, Color.WHITE)
	Art.circ(self, mp + Vector2(4, -10), 1.6, Color.WHITE)
	for lx in [368.0, 912.0]:
		Art.rrect(self, Rect2(lx - 2.5, 452.0, 5.0, 64.0), 2.0, Color("5a3d4a"))
		Art.arc(self, Vector2(lx, 452.0), 9.0, PI, TAU, 10, Color("5a3d4a"), 3.0, true)
		var pulse := 0.5 + 0.5 * sin(tt * 3.0 + lx)
		Art.circ(self, Vector2(lx, 462.0), 34.0, Color(1.0, 0.85, 0.4, 0.07 + 0.06 * pulse))
		Art.circ(self, Vector2(lx, 462.0), 20.0, Color(1.0, 0.85, 0.4, 0.16 + 0.1 * pulse))
		Art.rrect(self, Rect2(lx - 8.0, 454.0, 16.0, 20.0), 7.0, Color("ffe08a"), Color("5a3d4a"), 2.0)
		Art.circ(self, Vector2(lx, 463.0), 4.0, Color(1, 1, 1, 0.8))


# --- perigos: fundo

func _draw_back(P: Dictionary) -> void:
	for h in hz:
		match String(h["type"]):
			"saw":
				var a: Vector2 = h["a"]
				var b: Vector2 = h["b"]
				draw_line(a, b, Color(0.1, 0.08, 0.1, 0.55), 7.0, true)
				draw_line(a, b, Color(0.6, 0.6, 0.65, 0.5), 2.0, true)
				for e in [a, b]:
					Art.circ(self, e, 9.0, Color(0.15, 0.12, 0.15, 0.8))
			"laser":
				for side in [-1.0, 1.0]:
					var ex: float = h["x0"] if side < 0.0 else h["x1"]
					var y: float = h["y"]
					Art.rrect(self, Rect2(ex - 16.0, y - 18.0, 32.0, 36.0), 8.0, P["metal1"], P["metal2"], 2.0)
					var on := _laser_state(h)
					var lc := Color(1, 0.2, 0.25) if on == 2 else (Color(1, 0.6, 0.2, 0.4 + 0.6 * _blink(20.0)) if on == 1 else Color(0.4, 0.15, 0.18))
					Art.circ(self, Vector2(ex - side * 6.0, y), 7.0, lc)
			"cannon":
				var cp: Vector2 = h["pos"]
				Art.rrect(self, Rect2(cp.x - 40.0, cp.y + 16.0, 80.0, 740.0 - cp.y), 6.0, P["rock2"], P["rock1"], 2.0)
				Art.rrect(self, Rect2(cp.x - 46.0, cp.y + 12.0, 92.0, 12.0), 4.0, P["rock3"])
			"vortex":
				_vortex(h)
			"pendulum":
				var pv: Vector2 = h["pivot"]
				Art.rrect(self, Rect2(pv.x - 60.0, pv.y - 30.0, 120.0, 24.0), 6.0, P["rock2"], P["rock1"], 2.0)
			"stalactite":
				var pts := PackedVector2Array([Vector2(-20, -20), Vector2(1300, -20)])
				var x := 1300.0
				while x > -40.0:
					pts.append(Vector2(x, 14.0 + 10.0 * sin(x * 0.07)))
					pts.append(Vector2(x - 20.0, 30.0 + 14.0 * absf(sin(x * 0.13))))
					x -= 40.0
				Art.poly(self, pts, P["rock1"])
			"hub":
				if h.has("orbit"):
					Art.arc(self, h["pos"], float(h["orbit"]), 0.0, TAU, 56, Color(1, 1, 1, 0.14), 4.0, true)
					for q in 8:
						var a := q * TAU / 8.0
						draw_line(h["pos"], (h["pos"] as Vector2) + Vector2(cos(a), sin(a)) * float(h["orbit"]),
							Color(1, 1, 1, 0.08), 2.0)
			"lightning":
				# nuvens de tempestade no alto
				for q in 9:
					var cx := 40.0 + q * 150.0
					Art.circ(self, Vector2(cx, 30.0 + 8.0 * sin(t * 0.6 + q)), 70.0, Color(0.12, 0.12, 0.2, 0.9))
					Art.circ(self, Vector2(cx + 60.0, 18.0), 56.0, Color(0.18, 0.18, 0.28, 0.9))
			"sweeper":
				# torre do farol
				var tp: Vector2 = h["pos"]
				Art.poly(self, PackedVector2Array([Vector2(tp.x - 26.0, 520.0), Vector2(tp.x + 26.0, 520.0),
					Vector2(tp.x + 12.0, tp.y + 10.0), Vector2(tp.x - 12.0, tp.y + 10.0)]), P["rock2"])
				Art.poly(self, PackedVector2Array([Vector2(tp.x - 10.0, 520.0), Vector2(tp.x + 26.0, 520.0),
					Vector2(tp.x + 12.0, tp.y + 10.0), Vector2(tp.x + 4.0, tp.y + 10.0)]), P["rock1"])
				for q in 3:
					Art.rrect(self, Rect2(tp.x - 22.0 + q * 2.0, 520.0 - 40.0 - q * 40.0, 44.0 - q * 4.0, 12.0), 4.0, Color("c8553d"))
			"orbiter":
				if float(h["orbit"]) > 0.0:
					Art.arc(self, h["pos"], float(h["orbit"]), 0.0, TAU, 64, Color(1, 1, 1, 0.12), 3.0, true)
			"acid":
				pass
			"gravity":
				if Art.grav < 0.9:
					for i in 18:
						var gx := fposmod(i * 89.0 + sin(t * 0.7 + i) * 20.0, 1280.0)
						var gy := 720.0 - fposmod(i * 53.0 + t * 38.0, 720.0)
						Art.circ(self, Vector2(gx, gy), 5.0 + float(i % 4) * 2.0, Color(1, 1, 1, 0.12))
			"web":
				_web_draw(h)
			"train":
				var y2: float = h["y"]
				var sx := 248.0
				while sx < 1036.0:
					Art.rrect(self, Rect2(sx, y2 - 6.0, 16.0, 6.0), 2.0, Color(0.3, 0.2, 0.15))
					sx += 28.0


# --- perigos: frente

func _draw_front(P: Dictionary) -> void:
	for h in hz:
		match String(h["type"]):
			"saw":
				_saw(_saw_pos(h), float(h["r"]))
			"lava":
				_lava_draw(h)
			"laser":
				var st := _laser_state(h)
				var a := Vector2(float(h["x0"]) + 14.0, float(h["y"]))
				var b := Vector2(float(h["x1"]) - 14.0, float(h["y"]))
				if st == 1:
					var al := 0.25 + 0.55 * _blink(18.0)
					var x := a.x
					while x < b.x:
						draw_line(Vector2(x, a.y), Vector2(minf(x + 18.0, b.x), a.y), Color(1, 0.3, 0.3, al), 2.0)
						x += 30.0
				elif st == 2:
					draw_line(a, b, Color(1, 0.2, 0.3, 0.18), 36.0)
					draw_line(a, b, Color(1, 0.25, 0.35, 0.85), 16.0)
					draw_line(a, b, Color(1, 0.9, 0.95), 5.0)
			"wind":
				var w := _wind(h)
				var dir: float = w[0]
				if w[2]:
					var al2 := 0.4 + 0.6 * _blink(10.0)
					for q in 3:
						_chevron(Vector2(640.0 + (q - 1) * 60.0 * dir, 80.0), dir, Color(1, 1, 1, al2))
				elif float(w[1]) > 0.0:
					var s: float = float(w[1]) / float(h["force"])
					for i in 30:
						var y := fposmod(i * 37.0, 520.0) + 30.0
						var x2 := fposmod(i * 173.0 + t * 1100.0 * dir, 1500.0) - 110.0
						draw_line(Vector2(x2, y), Vector2(x2 - dir * (60.0 + 40.0 * sin(i)), y), Color(1, 1, 1, 0.35 * s), 3.0, true)
			"train":
				_train_draw(h, P)
			"crusher":
				_crusher_draw(h, P)
			"conveyor":
				var y3: float = h["y"]
				var x0: float = h["x0"]
				var x1: float = h["x1"]
				Art.rrect(self, Rect2(x0, y3 - 5.0, x1 - x0, 8.0), 4.0, Color(0.12, 0.12, 0.15))
				var v: float = h["v"]
				var span := x1 - x0
				for q in int(span / 40.0):
					var cx := x0 + fposmod(q * 40.0 + t * v, span)
					_chevron_small(Vector2(cx, y3 - 1.0), signf(v))
			"electric":
				_electric_draw(h)
			"pendulum":
				var pe := _pendulum(h)
				var pv: Vector2 = h["pivot"]
				var bp: Vector2 = pe[0]
				draw_line(pv, bp, Color("6a5040"), 5.0, true)
				draw_line(pv, bp, Color("a08060"), 2.0, true)
				Art.circ(self, pv, 9.0, YELLOW)
				_spiked_ball(bp, float(h["r"]))
			"geyser":
				_geyser_draw(h)
			"cannon":
				_cannon_draw(h)
			"spikes":
				var sx0: float = h["x0"]
				var sx1: float = h["x1"]
				var y4: float = h["y"]
				var n := int((sx1 - sx0) / 20.0)
				for q in n:
					var bx0 := sx0 + q * 20.0
					Art.poly(self, PackedVector2Array([Vector2(bx0, y4 + 1.0), Vector2(bx0 + 20.0, y4 + 1.0),
						Vector2(bx0 + 10.0, y4 - 18.0)]), Color("c9d3df"))
					Art.poly(self, PackedVector2Array([Vector2(bx0 + 10.0, y4 + 1.0), Vector2(bx0 + 20.0, y4 + 1.0),
						Vector2(bx0 + 10.0, y4 - 18.0)]), Color("8e99a8"))
					Art.circ(self, Vector2(bx0 + 10.0, y4 - 16.0), 2.0, Color(0.9, 0.2, 0.2))
			"hub":
				var hp: Vector2 = h["pos"]
				var hr: float = h["r"]
				Art.circ(self, hp, hr + 14.0, Color(1, 0.4, 0.3, 0.12))
				for k in 6:
					var a := t * 3.0 + k * TAU / 6.0
					var d := Vector2(cos(a), sin(a))
					Art.poly(self, PackedVector2Array([hp + d * hr * 0.7 + d.orthogonal() * 9.0,
						hp + d * hr * 0.7 - d.orthogonal() * 9.0, hp + d * (hr + 22.0)]), Color("c9d3df"))
				Art.circ(self, hp, hr, Color("4a4a58"))
				Art.circ(self, hp, hr * 0.45, Color("e74c3c"))
				Art.circ(self, hp + Vector2(-hr * 0.3, -hr * 0.35), hr * 0.25, Color(1, 1, 1, 0.3))
			"tornado":
				_tornado_draw(h)
			"tide":
				_tide_draw(h)
			"bumper":
				var bp := _bumper_pos(h)
				var br: float = h["r"]
				var fl: float = float(h.get("flash", 0.0)) / 0.25
				Art.circ(self, bp, br + 12.0 + 10.0 * fl, Color(1, 0.4, 0.8, 0.18 + 0.3 * fl))
				Art.circ(self, bp, br, Color("2a1a40"))
				Art.circ(self, bp, br - 5.0 + 4.0 * fl, Color("ff4fa8"))
				Art.circ(self, bp, br * 0.5, Color("ffd0e8"))
				Art.sparkle(self, bp, br * 0.4, Color(1, 1, 1, 0.9), t * 2.0)
			"ice":
				for g in Art.grounds:
					var gr: Rect2 = g
					Art.rrect(self, Rect2(gr.position.x + 4.0, gr.position.y + 1.0, gr.size.x - 8.0, 7.0), 3.0, Color(0.85, 0.97, 1.0, 0.55))
					for q in 6:
						Art.sparkle(self, Vector2(gr.position.x + fposmod(q * 97.0 + t * 12.0, gr.size.x), gr.position.y + 4.0),
							3.0 + 2.0 * sin(t * 3.0 + q), Color(1, 1, 1, 0.8), t + q)
			"gravity":
				var gcy := _cyc(h)
				if gcy < float(h["warn"]):
					_bang(Vector2(640, 150), 0.5 + 0.5 * _blink(10.0))
			"vanish":
				var vc := _cyc(h)
				var vcur: Array = h.get("cur", [])
				var voff: bool = vc >= float(h["warn"]) and vc < float(h["warn"]) + float(h["off"])
				for vi in vcur:
					var vr: Rect2 = gr_all[vi]
					if vc < float(h["warn"]):
						Art.rrect(self, Rect2(vr.position.x, vr.position.y - 4.0, vr.size.x, vr.size.y + 4.0), 6.0,
							Color(1, 0.2, 0.15, 0.2 + 0.4 * _blink(20.0)))
					elif voff:
						Art.rrect(self, Rect2(vr.position.x + 6.0, vr.position.y + 4.0, vr.size.x - 12.0, vr.size.y - 8.0), 6.0,
							Color(0, 0, 0, 0), Color(1, 1, 1, 0.25), 2.0)
			"sweeper":
				var sa := t * float(h["speed"]) + float(h["ph"])
				var sdir := Vector2(cos(sa), sin(sa))
				var sp0: Vector2 = h["pos"]
				var sperp := sdir.orthogonal()
				var slen: float = h["len"]
				Art.poly(self, PackedVector2Array([sp0 + sperp * 12.0, sp0 + sdir * slen + sperp * 26.0,
					sp0 + sdir * slen - sperp * 26.0, sp0 - sperp * 12.0]), Color(1, 0.9, 0.4, 0.28))
				Art.poly(self, PackedVector2Array([sp0 + sperp * 5.0, sp0 + sdir * slen + sperp * 10.0,
					sp0 + sdir * slen - sperp * 10.0, sp0 - sperp * 5.0]), Color(1, 0.97, 0.7, 0.85))
				Art.circ(self, sp0, 20.0, Color("fff3a0"))
				Art.circ(self, sp0, 11.0, Color(1, 1, 1))
			"walls":
				_walls_draw(h, P)
			"portal":
				_portal_draw(h["a"], Color("4fb8ff"), float(h["r"]))
				_portal_draw(h["b"], Color("ff9a3c"), float(h["r"]))
			"spring":
				var spx: float = h["x"]
				var spy: float = h["y"]
				var spw: float = h["w"]
				var an: float = float(h.get("anim", 0.0)) / 0.3
				var coil := 22.0 * (1.0 - 0.6 * an)
				Art.rrect(self, Rect2(spx - spw / 2.0, spy - 5.0, spw, 6.0), 3.0, Color("7a3a3a"))
				var zig := PackedVector2Array()
				for q in 7:
					zig.append(Vector2(spx + (-14.0 if q % 2 == 0 else 14.0), spy - 5.0 - coil * float(q) / 6.0))
				Art.polyline(self, zig, Color("c9d3df"), 4.0, true)
				Art.rrect(self, Rect2(spx - spw / 2.0 - 4.0, spy - 9.0 - coil, spw + 8.0, 8.0), 4.0, Color("e74c3c"), Color("7a1a1a"), 2.0)
			"acid":
				var ay: float = h["y"]
				var ax0: float = h["x0"]
				var ax1: float = h["x1"]
				var apts := PackedVector2Array()
				apts.append(Vector2(ax0, 760.0))
				var axx := ax0
				while axx <= ax1:
					apts.append(Vector2(axx, ay + sin(axx * 0.05 + t * 2.5) * 3.0))
					axx += 20.0
				apts.append(Vector2(ax1, ay))
				apts.append(Vector2(ax1, 760.0))
				Art.poly(self, apts, Color(0.45, 0.9, 0.2, 0.85))
				var atop := PackedVector2Array()
				for i in range(1, apts.size() - 2):
					atop.append(apts[i])
				Art.polyline(self, atop, Color(0.8, 1.0, 0.4), 4.0, true)
				for i in 9:
					var bx := ax0 + fposmod(i * 61.0, ax1 - ax0)
					var by := ay + 12.0 + fposmod(i * 23.0 - t * 40.0, 90.0)
					Art.circ(self, Vector2(bx, by), 3.0 + float(i % 3), Color(0.85, 1, 0.5, 0.6))
			"orbiter":
				var op := _orbiter_pos(h)
				var orr: float = h["r"]
				if float(h["orbit"]) <= 0.0:
					for q in 3:
						Art.circ(self, op, orr + 30.0 - q * 10.0, Color(1, 0.8, 0.2, 0.12))
					Art.circ(self, op, orr, Color("ffd04a"))
					Art.circ(self, op + Vector2(-orr * 0.25, -orr * 0.25), orr * 0.5, Color("fff3a0"))
				else:
					var pc := Color(String(h.get("col", "7fb8d8")))
					Art.circ(self, op, orr + 6.0, Color(pc, 0.2))
					Art.circ(self, op, orr, pc)
					Art.circ(self, op + Vector2(-orr * 0.3, -orr * 0.3), orr * 0.35, Color(1, 1, 1, 0.35))
					Art.circ(self, op + Vector2(orr * 0.3, orr * 0.3), orr * 0.45, Color(0, 0, 0, 0.18))
			"fan":
				var fnx: float = h["x"]
				var fnw: float = h["w"]
				var fny: float = h["y"]
				var fnh: float = h["h"]
				Art.rrect(self, Rect2(fnx - fnw / 2.0, fny - fnh, fnw, fnh), 0.0, Color(0.8, 0.95, 1.0, 0.07))
				for i in 9:
					var yy := fny - fposmod(i * 47.0 + t * 320.0, fnh)
					var xx := fnx + sin(t * 3.0 + i * 1.9) * fnw * 0.32
					draw_line(Vector2(xx, yy), Vector2(xx, yy + 24.0), Color(1, 1, 1, 0.5 * (1.0 - (fny - yy) / fnh)), 3.0, true)
				Art.rrect(self, Rect2(fnx - fnw / 2.0 - 6.0, fny - 10.0, fnw + 12.0, 12.0), 4.0, P["metal2"], P["metal1"], 2.0)
				for q in 5:
					Art.rrect(self, Rect2(fnx - fnw / 2.0 + 6.0 + q * (fnw - 12.0) / 5.0, fny - 8.0, 4.0, 8.0), 1.0, Color(0, 0, 0, 0.5))
				var ba := t * 14.0
				for sd in [-1.0, 1.0]:
					draw_line(Vector2(fnx, fny - 16.0), Vector2(fnx + sd * cos(ba) * fnw * 0.4, fny - 16.0 - absf(sin(ba)) * 4.0),
						Color(0.8, 0.85, 0.9, 0.7), 3.0, true)
			"lavapit":
				var lpy: float = h["y"]
				var lpts := PackedVector2Array()
				lpts.append(Vector2(-20, 760))
				var lx := -20.0
				while lx <= 1300.0:
					lpts.append(Vector2(lx, lpy + sin(lx * 0.03 + t * 3.0) * 5.0))
					lx += 40.0
				lpts.append(Vector2(1300, 760))
				Art.rrect(self, Rect2(-20.0, lpy - 50.0, 1320.0, 50.0), 0.0, Color(1, 0.4, 0.1, 0.08))
				Art.poly(self, lpts, Color("e2431c"))
				var ltop := PackedVector2Array()
				for i in range(1, lpts.size() - 1):
					ltop.append(lpts[i])
				Art.polyline(self, ltop, Color("ffb347"), 6.0, true)
				for i in 12:
					var bx := fposmod(i * 113.0 + sin(t + i) * 20.0, 1280.0)
					var by := lpy + 14.0 + fposmod(i * 29.0 - t * 30.0, 60.0)
					Art.circ(self, Vector2(bx, by), 4.0 + 2.0 * sin(t * 3.0 + i), Color("ff8a3a"))
			"bigwave":
				_wave_draw(h)
			"spider":
				_spider_draw(h)
	for o in objs:
		_obj_draw(o, P)


func _walls_draw(h: Dictionary, P: Dictionary) -> void:
	var wd := _wall_depth(h)
	var dep: float = wd[0]
	if int(wd[1]) == 1:
		dep = 6.0 + 4.0 * sin(t * 60.0)
	var lin := float(h["lx"]) + dep
	var rin := float(h["rx"]) - dep
	Art.rrect(self, Rect2(-60.0, 40.0, lin + 60.0, 720.0), 0.0, P["metal1"], P["metal2"], 3.0, 8)
	Art.rrect(self, Rect2(rin, 40.0, 1400.0 - rin, 720.0), 0.0, P["metal1"], P["metal2"], 3.0, 8)
	var y := 60.0
	while y < 740.0:
		Art.poly(self, PackedVector2Array([Vector2(lin, y), Vector2(lin + 26.0, y + 18.0), Vector2(lin, y + 36.0)]), Color("c9d3df"))
		Art.poly(self, PackedVector2Array([Vector2(rin, y), Vector2(rin - 26.0, y + 18.0), Vector2(rin, y + 36.0)]), Color("c9d3df"))
		y += 36.0
	Art.rrect(self, Rect2(lin - 30.0, 40.0, 24.0, 720.0), 0.0, Color(P["metal3"], 0.35))
	Art.rrect(self, Rect2(rin + 6.0, 40.0, 24.0, 720.0), 0.0, Color(P["metal3"], 0.35))
	if int(wd[1]) == 1:
		_bang(Vector2(lin + 70.0, 300.0), 0.5 + 0.5 * _blink(12.0))
		_bang(Vector2(rin - 70.0, 300.0), 0.5 + 0.5 * _blink(12.0))


func _portal_draw(p: Vector2, col: Color, r: float) -> void:
	for q in 4:
		Art.ellipse(self, p, 30.0 - q * 5.0, r + 8.0 - q * 8.0, Color(col, 0.18 + 0.12 * q))
	Art.ellipse(self, p, 14.0, r * 0.72, Color(0.04, 0.04, 0.1, 0.9))
	for i in 7:
		var a := t * 4.0 + i * TAU / 7.0
		Art.circ(self, p + Vector2(cos(a) * 22.0, sin(a) * (r - 4.0)), 3.0, Color(col.lightened(0.5), 0.9))


func _wave_draw(h: Dictionary) -> void:
	var bw := _bigwave(h)
	var dir: int = bw["dir"]
	var y: float = h["y"]
	var hh: float = h["h"]
	if int(bw["s"]) == 1:
		var ex := 190.0 if dir > 0 else 1090.0
		_bang(Vector2(ex, y - hh - 30.0), 0.5 + 0.5 * _blink(10.0))
		_chevron(Vector2(ex + dir * 50.0, y - hh - 30.0), float(dir), Color(0.6, 0.85, 1.0, 0.8))
		for i in 10:
			var sx := ex + dir * fposmod(i * 37.0 + t * 200.0, 120.0)
			Art.circ(self, Vector2(sx, y - 10.0 - fposmod(i * 29.0 + t * 90.0, 60.0)), 4.0, Color(0.8, 0.95, 1.0, 0.6))
		return
	if int(bw["s"]) != 2:
		return
	var r: Rect2 = bw["r"]
	var xf := r.end.x if dir > 0 else r.position.x
	var xb := r.position.x if dir > 0 else r.end.x
	var top := r.position.y
	var pts := PackedVector2Array([Vector2(xb, top + 50.0), Vector2(xf - dir * 90.0, top + 6.0),
		Vector2(xf - dir * 20.0, top), Vector2(xf + dir * 14.0, top + 26.0), Vector2(xf, top + 80.0),
		Vector2(xf + dir * 6.0, y), Vector2(xb, y)])
	Art.poly(self, pts, Color(0.18, 0.5, 0.88, 0.88))
	Art.poly(self, PackedVector2Array([Vector2(xb, top + 80.0), Vector2(xf - dir * 80.0, top + 30.0),
		Vector2(xf - dir * 10.0, top + 40.0), Vector2(xf, top + 90.0), Vector2(xf, y), Vector2(xb, y)]), Color(0.1, 0.35, 0.7, 0.5))
	for i in 9:
		Art.circ(self, Vector2(xf - dir * (6.0 + i * 15.0), top + 8.0 + 6.0 * sin(t * 8.0 + i) + i * 2.0), 7.0, Color(1, 1, 1, 0.85))
	for i in 6:
		var ly := top + 40.0 + i * 18.0
		draw_line(Vector2(xb, ly), Vector2(xf - dir * 30.0, ly), Color(1, 1, 1, 0.18), 2.0, true)


func _spider_draw(h: Dictionary) -> void:
	var sp := _spider_pos(h)
	var r: float = h["r"]
	draw_line(Vector2(sp.x, -20.0), sp, Color(1, 1, 1, 0.6), 2.0, true)
	var leg := Color(0.1, 0.05, 0.15)
	for k in 4:
		var a := 0.4 + k * 0.35
		for sd in [-1.0, 1.0]:
			var kn := sp + Vector2(sd * cos(a) * r * 1.6, -sin(a) * r * 1.1 + sin(t * 8.0 + k) * 2.0)
			var ft := sp + Vector2(sd * (r * 2.2 + k * 3.0), r * 0.7 + k * 4.0 - 4.0)
			draw_line(sp, kn, leg, 3.0, true)
			draw_line(kn, ft, leg, 3.0, true)
	Art.circ(self, sp, r, Color("2a1a3a"))
	Art.circ(self, sp + Vector2(0.0, -r * 0.7), r * 0.62, Color("3a2650"))
	Art.circ(self, sp + Vector2(-5.0, -r * 0.8), 3.5, Color(1, 0.2, 0.2))
	Art.circ(self, sp + Vector2(5.0, -r * 0.8), 3.5, Color(1, 0.2, 0.2))
	Art.circ(self, sp + Vector2(-r * 0.3, r * 0.2), r * 0.25, Color(1, 1, 1, 0.12))


func _web_draw(h: Dictionary) -> void:
	var x0: float = h["x0"]
	var x1: float = h["x1"]
	var y0: float = h["y0"]
	var y1: float = h["y1"]
	var c := Vector2((x0 + x1) / 2.0, (y0 + y1) / 2.0)
	var hw := (x1 - x0) / 2.0
	var hh := (y1 - y0) / 2.0
	Art.rrect(self, Rect2(x0, y0, x1 - x0, y1 - y0), 8.0, Color(1, 1, 1, 0.05))
	for k in 8:
		var a := k * TAU / 8.0
		draw_line(c, c + Vector2(cos(a) * hw, sin(a) * hh), Color(1, 1, 1, 0.45), 1.5, true)
	for ring in [0.3, 0.6, 0.95]:
		var pts := PackedVector2Array()
		for k in 9:
			var a := k * TAU / 8.0
			pts.append(c + Vector2(cos(a) * hw * ring, sin(a) * hh * ring) * (1.0 + 0.02 * sin(t * 2.0 + k)))
		Art.polyline(self, pts, Color(1, 1, 1, 0.4), 1.5, true)


func _tornado_draw(h: Dictionary) -> void:
	var tw := _tornado(h)
	var x: float = tw[0]
	var y: float = h["y"]
	var st: int = tw[1]
	if st == 0:
		return
	if st == 1:
		_bang(Vector2(x, y - 70.0), 0.5 + 0.5 * _blink(10.0))
		for i in 8:
			Art.circ(self, Vector2(x + sin(t * 9.0 + i * 1.7) * (10.0 + i * 3.0), y - 4.0 - fposmod(t * 70.0 + i * 11.0, 40.0)),
				3.0, Color(0.85, 0.8, 0.7, 0.6))
		return
	for i in 16:
		var yy := y - i * 36.0
		var w := 16.0 + i * 6.5
		var wob := sin(t * 5.0 + i * 0.7) * (6.0 + i * 1.2)
		Art.ellipse(self, Vector2(x + wob, yy), w, 10.0, Color(0.78, 0.82, 0.88, 0.32))
		Art.ellipse(self, Vector2(x + wob, yy), w * 0.6, 6.0, Color(0.95, 0.97, 1.0, 0.35))
	for i in 14:
		var a := t * 6.0 + i * 1.9
		var yy2 := y - fposmod(i * 41.0 + t * 120.0, 560.0)
		Art.circ(self, Vector2(x + cos(a) * (20.0 + (y - yy2) * 0.11), yy2), 3.0, Color(0.5, 0.4, 0.3, 0.7))


func _tide_draw(h: Dictionary) -> void:
	var lv := _tide(h)
	var pts := PackedVector2Array()
	pts.append(Vector2(-20, 760))
	var x := -20.0
	while x <= 1300.0:
		pts.append(Vector2(x, lv + sin(x * 0.02 + t * 2.0) * 5.0))
		x += 30.0
	pts.append(Vector2(1300, 760))
	Art.poly(self, pts, Color(0.15, 0.5, 0.85, 0.55))
	var top := PackedVector2Array()
	for i in range(1, pts.size() - 1):
		top.append(pts[i])
	Art.polyline(self, top, Color(0.85, 0.97, 1.0, 0.9), 4.0, true)
	var dir := 1.0 if _cnum(h) % 2 == 0 else -1.0
	for i in 10:
		var bx := fposmod(i * 131.0 + t * 90.0 * dir, 1300.0)
		_chevron_small(Vector2(bx, lv + 26.0 + 14.0 * sin(i)), dir)
	for i in 8:
		Art.circ(self, Vector2(fposmod(i * 157.0, 1280.0), lv + 20.0 + fposmod(i * 37.0 - t * 40.0, 80.0)), 3.0, Color(1, 1, 1, 0.4))


func _chevron(p: Vector2, dir: float, col: Color) -> void:
	var pts := PackedVector2Array([p + Vector2(-dir * 14.0, -20.0), p + Vector2(dir * 10.0, 0.0), p + Vector2(-dir * 14.0, 20.0),
		p + Vector2(-dir * 2.0, 20.0), p + Vector2(dir * 22.0, 0.0), p + Vector2(-dir * 2.0, -20.0)])
	Art.poly(self, pts, col)


func _chevron_small(p: Vector2, dir: float) -> void:
	Art.polyline(self, PackedVector2Array([p + Vector2(-dir * 4.0, -3.0), p + Vector2(dir * 2.0, 0.0), p + Vector2(-dir * 4.0, 3.0)]),
		YELLOW, 2.0, true)


func _saw(p: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	var rot := t * 14.0 + Time.get_ticks_msec() * 0.002
	for k in 32:
		var a := rot + k * TAU / 32.0
		var rr := r if k % 2 == 0 else r * 0.78
		pts.append(p + Vector2(cos(a), sin(a)) * rr)
	Art.circ(self, p, r + 6.0, Color(1, 0.4, 0.3, 0.12))
	Art.poly(self, pts, Color("d5dde6"))
	Art.circ(self, p, r * 0.62, Color("aeb8c4"))
	Art.circ(self, p, r * 0.25, Color("4a4f5a"))
	for k in 3:
		var a := rot * 0.5 + k * TAU / 3.0
		Art.circ(self, p + Vector2(cos(a), sin(a)) * r * 0.42, 2.5, Color("6a7280"))


func _spiked_ball(p: Vector2, r: float) -> void:
	for k in 10:
		var a := k * TAU / 10.0 + t * 0.5
		var d := Vector2(cos(a), sin(a))
		Art.poly(self, PackedVector2Array([p + d * r * 0.8 + d.orthogonal() * 7.0, p + d * r * 0.8 - d.orthogonal() * 7.0,
			p + d * (r + 14.0)]), Color("8e99a8"))
	Art.circ(self, p, r, Color("4a4a58"))
	Art.circ(self, p + Vector2(-r * 0.3, -r * 0.35), r * 0.3, Color(1, 1, 1, 0.25))


func _lava_draw(h: Dictionary) -> void:
	var lv_info := _lava(h)
	var lv: float = lv_info[0]
	var pts := PackedVector2Array()
	pts.append(Vector2(-20, 760))
	var x := -20.0
	while x <= 1300.0:
		pts.append(Vector2(x, lv + sin(x * 0.03 + t * 3.0) * 5.0))
		x += 40.0
	pts.append(Vector2(1300, 760))
	draw_rect(Rect2(-20, lv - 40.0, 1320, 40), Color(1, 0.4, 0.1, 0.08))
	Art.poly(self, pts, Color("e2431c"))
	var top := PackedVector2Array()
	for i in range(1, pts.size() - 1):
		top.append(pts[i])
	Art.polyline(self, top, Color("ffb347"), 6.0, true)
	for i in 12:
		var bx := fposmod(i * 113.0 + sin(t + i) * 20.0, 1280.0)
		var by := lv + 14.0 + fposmod(i * 29.0 - t * 30.0, 60.0)
		Art.circ(self, Vector2(bx, by), 4.0 + 2.0 * sin(t * 3.0 + i), Color("ff8a3a"))
	if lv_info[1]:
		var a := _blink(10.0)
		for bx2 in [200.0, 640.0, 1080.0]:
			_bang(Vector2(bx2, minf(lv - 50.0, 560.0)), 0.5 + 0.5 * a)
		for i in 10:
			Art.circ(self, Vector2(fposmod(i * 131.0, 1280.0), lv - 4.0 - fposmod(t * 60.0 + i * 13.0, 40.0)), 5.0,
				Color(1, 0.6, 0.2, 0.6))


func _train_draw(h: Dictionary, P: Dictionary) -> void:
	var tr := _train(h)
	var dir: int = tr["dir"]
	var y: float = h["y"]
	draw_line(Vector2(240, y - 2.0), Vector2(1040, y - 2.0), Color(0.55, 0.55, 0.6), 3.0)
	# semáforos nas pontas
	for sx in [228.0, 1052.0]:
		Art.rrect(self, Rect2(sx - 3.0, y - 110.0, 6.0, 110.0), 2.0, Color(0.2, 0.2, 0.25))
		Art.rrect(self, Rect2(sx - 12.0, y - 130.0, 24.0, 34.0), 6.0, DARK)
		var on := int(tr["s"]) == 1
		var lit := Color(1, 0.2, 0.2, 0.4 + 0.6 * _blink(14.0)) if on else Color(0.35, 0.1, 0.1)
		Art.circ(self, Vector2(sx, y - 113.0), 8.0, lit)
		if on:
			Art.circ(self, Vector2(sx, y - 113.0), 20.0, Color(1, 0.2, 0.2, 0.2 * _blink(14.0)))
	if int(tr["s"]) == 1:
		var a := 0.5 + 0.5 * _blink(10.0)
		var ex := 200.0 if dir > 0 else 1080.0
		_bang(Vector2(ex, y - 170.0), a)
		_chevron(Vector2(ex + dir * 50.0, y - 170.0), float(dir), Color(1, 0.3, 0.25, a))
		return
	if int(tr["s"]) != 2:
		return
	var r: Rect2 = tr["r"]
	var car := 150.0
	var n := int(r.size.x / car)
	for i in n:
		var cx0 := r.position.x + i * car
		var is_loco := (dir > 0 and i == n - 1) or (dir < 0 and i == 0)
		var body := Rect2(cx0 + 4.0, r.position.y + (0.0 if is_loco else 12.0), car - 8.0, r.size.y - (16.0 if is_loco else 28.0))
		var col := Color("c8553d") if is_loco else Color("3d6fa8")
		Art.rrect(self, body, 10.0, col, col.darkened(0.45), 3.0, 6)
		if is_loco:
			var wx := body.position.x + (body.size.x - 44.0 if dir > 0 else 14.0)
			Art.rrect(self, Rect2(wx, body.position.y + 10.0, 30.0, 22.0), 5.0, Color("bfe6f8"))
			var lx := body.end.x if dir > 0 else body.position.x
			Art.circ(self, Vector2(lx, body.end.y - 18.0), 7.0, Color("fff3a0"))
			Art.circ(self, Vector2(lx + dir * 30.0, body.end.y - 18.0), 26.0, Color(1, 0.95, 0.6, 0.18))
		else:
			for q in 3:
				Art.rrect(self, Rect2(body.position.x + 12.0 + q * 42.0, body.position.y + 8.0, 28.0, 16.0), 4.0, Color("bfe6f8"))
		for wx2 in [body.position.x + 26.0, body.end.x - 26.0]:
			Art.circ(self, Vector2(wx2, y - 10.0), 11.0, Color("2a2a34"))
			Art.circ(self, Vector2(wx2, y - 10.0), 4.0, Color("8e99a8"))
	# vento do trem
	for i in 6:
		var sx2 := r.position.x - dir * (30.0 + i * 25.0) if dir > 0 else r.end.x - dir * (30.0 + i * 25.0)
		draw_line(Vector2(sx2, r.position.y + 10.0 + i * 10.0), Vector2(sx2 - dir * 50.0, r.position.y + 10.0 + i * 10.0),
			Color(1, 1, 1, 0.3), 2.0)


func _crusher_draw(h: Dictionary, P: Dictionary) -> void:
	var cr := _crusher(h)
	var bottom: float = cr[0]
	var ph: int = cr[1]
	var x: float = h["x"]
	var w: float = h["w"]
	var gy: float = h["y"]
	if ph == 1:
		var a := 0.25 + 0.35 * _blink(18.0)
		draw_rect(Rect2(x - w / 2.0, gy - 6.0, w, 6.0), Color(1, 0.2, 0.15, a + 0.3))
		draw_rect(Rect2(x - w / 2.0, bottom, w, gy - bottom), Color(1, 0.2, 0.15, a * 0.25))
		_bang(Vector2(x, gy - 50.0), 0.6 + 0.4 * _blink(10.0))
	var jit := Vector2(sin(t * 80.0) * 3.0, 0.0) if ph == 1 else Vector2.ZERO
	var r := _crusher_rect(h, bottom)
	r.position += jit
	Art.rrect(self, Rect2(x - 13.0 + jit.x, -20.0, 26.0, r.position.y + 24.0), 4.0, P["metal2"])
	draw_line(Vector2(x - 5.0 + jit.x, -20.0), Vector2(x - 5.0 + jit.x, r.position.y), Color(P["metal3"], 0.6), 3.0)
	Art.rrect(self, r, 8.0, P["metal1"], P["metal2"], 3.0, 8)
	var sx := r.position.x + 6.0
	while sx < r.end.x - 18.0:
		Art.poly(self, PackedVector2Array([Vector2(sx, r.end.y - 4.0), Vector2(sx + 8.0, r.end.y - 18.0),
			Vector2(sx + 18.0, r.end.y - 18.0), Vector2(sx + 10.0, r.end.y - 4.0)]), YELLOW)
		sx += 22.0
	for q in 2:
		Art.circ(self, Vector2(r.position.x + 14.0 + q * (w - 28.0), r.position.y + 14.0), 4.0, P["metal2"])


func _electric_draw(h: Dictionary) -> void:
	var y: float = h["y"]
	var segs: Array = h["segs"]
	for sg in segs:
		Art.rrect(self, Rect2(float(sg[0]), y - 4.0, float(sg[1]) - float(sg[0]), 6.0), 3.0, Color(0.15, 0.3, 0.45),
			Color(0.4, 0.8, 1.0, 0.4), 1.5)
	var c := _cyc(h)
	var wn: float = h["warn"]
	var on: float = h["on"]
	var cur: Array = h.get("cur", [])
	for si in cur:
		var sg: Array = segs[si]
		var x0: float = sg[0]
		var x1: float = sg[1]
		if c < wn:
			var a := 0.3 + 0.7 * _blink(16.0)
			Art.rrect(self, Rect2(x0, y - 5.0, x1 - x0, 8.0), 4.0, Color(1, 0.9, 0.2, 0.35 * a), Color(1, 0.9, 0.3, a), 2.0)
			for q in 4:
				var sx := x0 + fposmod(q * 53.0 + t * 200.0, x1 - x0)
				Art.sparkle(self, Vector2(sx, y - 8.0), 6.0 * a, Color(1, 1, 0.6, a))
			_bang(Vector2((x0 + x1) / 2.0, y - 70.0), a)
		elif c < wn + on:
			Art.rrect(self, Rect2(x0, y - 70.0, x1 - x0, 70.0), 6.0, Color(0.4, 0.8, 1.0, 0.12))
			var x := x0 + 10.0
			while x < x1:
				var pts := PackedVector2Array()
				for k in 6:
					pts.append(Vector2(x + sin(t * 47.0 + x + k * 2.1) * 8.0, y - k * 12.0))
				Art.polyline(self, pts, Color(0.5, 0.9, 1.0, 0.35), 7.0, true)
				Art.polyline(self, pts, Color(0.9, 1.0, 1.0), 2.5, true)
				x += 32.0


func _geyser_draw(h: Dictionary) -> void:
	var x: float = h["x"]
	var y: float = h["y"]
	var w: float = h["w"]
	Art.ellipse(self, Vector2(x, y - 2.0), w * 0.6, 7.0, Color(0.1, 0.12, 0.18))
	for s in [-1.0, 1.0]:
		Art.circ(self, Vector2(x + s * w * 0.6, y - 4.0), 9.0, Color(0.35, 0.32, 0.36))
	var c := _cyc(h)
	var wn: float = h["warn"]
	if c < wn:
		var a := c / wn
		for i in 6:
			var by := y - 10.0 - fposmod(t * 80.0 + i * 17.0, 60.0 * a + 10.0)
			Art.circ(self, Vector2(x + sin(t * 5.0 + i) * w * 0.3, by), 4.0 + 3.0 * a, Color(0.85, 0.95, 1.0, 0.6))
		_bang(Vector2(x, y - 90.0), 0.4 + 0.6 * _blink(12.0))
	var r := _geyser_rect(h)
	if r.size.y > 0.0:
		Art.rrect(self, Rect2(r.position.x - 6.0, r.position.y, r.size.x + 12.0, r.size.y), 20.0, Color(0.6, 0.85, 1.0, 0.35))
		Art.rrect(self, r, 18.0, Color(0.7, 0.9, 1.0, 0.8))
		Art.rrect(self, Rect2(x - w * 0.18, r.position.y + 8.0, w * 0.36, r.size.y - 8.0), 8.0, Color(1, 1, 1, 0.7))
		for i in 5:
			var a2 := i * TAU / 5.0 + t * 4.0
			Art.circ(self, Vector2(x + cos(a2) * w * 0.5, r.position.y + sin(a2) * 8.0), 14.0, Color(1, 1, 1, 0.8))


func _cannon_draw(h: Dictionary) -> void:
	var cp: Vector2 = h["pos"]
	var dir: int = h["dir"]
	var c := _cyc(h)
	var P: float = h["period"]
	var body := Rect2(cp.x - 30.0 if dir > 0 else cp.x - 30.0, cp.y - 15.0, 60.0, 30.0)
	Art.rrect(self, Rect2(cp.x + (0.0 if dir > 0 else -58.0), cp.y - 13.0, 58.0, 26.0), 8.0, Color("2a2a34"), Color("14141a"), 2.0)
	Art.rrect(self, body, 14.0, Color("3a3a46"), Color("14141a"), 2.0)
	var muzzle := cp + Vector2(dir * 58.0, 0.0)
	Art.rrect(self, Rect2(muzzle.x - 5.0, cp.y - 17.0, 10.0, 34.0), 4.0, Color("1a1a20"))
	Art.circ(self, cp + Vector2(-dir * 8.0, 14.0), 13.0, Color("5a3d2a"))
	Art.circ(self, cp + Vector2(-dir * 8.0, 14.0), 4.0, Color("a08060"))
	if c > P - 0.8:
		var a := (c - (P - 0.8)) / 0.8
		Art.circ(self, muzzle, 10.0 + 12.0 * a, Color(1, 0.6, 0.2, 0.25 + 0.4 * a * _blink(20.0)))
	var fl: float = h.get("flash", 0.0)
	if fl > 0.0:
		Art.circ(self, muzzle + Vector2(dir * 14.0, 0.0), 30.0 * fl / 0.25, Color(1, 0.85, 0.3, 0.8))


func _vortex(h: Dictionary) -> void:
	var pos: Vector2 = h["pos"]
	var c := _cyc(h)
	var wn: float = h["warn"]
	var on: float = h["on"]
	var k := 0.0
	if c < wn:
		k = c / wn * 0.35
	elif c < wn + on:
		k = minf(1.0, 0.35 + (c - wn) / 0.4)
		k *= minf(1.0, (wn + on - c) / 0.5)
	if k <= 0.0:
		return
	var core: float = h["core"]
	for i in 5:
		Art.circ(self, pos, (core + 30.0 + i * 34.0) * k, Color(0.55, 0.25, 0.95, 0.07))
	for arm in 4:
		var pts := PackedVector2Array()
		for q in 24:
			var rr := (core + q * 9.0) * k
			var a := arm * TAU / 4.0 - t * 3.0 + q * 0.22
			pts.append(pos + Vector2(cos(a), sin(a)) * rr)
		Art.polyline(self, pts, Color(0.75, 0.5, 1.0, 0.5), 4.0, true)
	if c >= wn:
		for i in 26:
			var rr2 := fposmod(-t * 160.0 + i * 37.0, 320.0) * k + core
			var a2 := i * 2.4 + t * (2.0 + 300.0 / rr2)
			Art.circ(self, pos + Vector2(cos(a2), sin(a2)) * rr2, 2.5, Color(0.9, 0.8, 1.0, 0.8))
	Art.circ(self, pos, core * k + 6.0, Color(0.85, 0.6, 1.0, 0.7))
	Art.circ(self, pos, core * k, Color(0.03, 0.0, 0.06))
	if c < wn:
		_bang(pos + Vector2(0, 80), 0.5 + 0.5 * _blink(10.0))


func _obj_draw(o: Dictionary, P: Dictionary) -> void:
	match String(o["kind"]):
		"mine":
			var mp: Vector2 = o["p"]
			var a := 0.5 if float(o["arm"]) > 0.0 else 1.0
			var blink := _blink(6.0 if float(o["fuse"]) > 1.2 else 26.0)
			Art.ellipse(self, mp + Vector2(0, 1), 14.0, 4.0, Color(0, 0, 0, 0.3 * a))
			Art.circ(self, mp + Vector2(0, -8), 12.0, Color(0.16, 0.16, 0.2, a))
			Art.rrect(self, Rect2(mp.x - 14.0, mp.y - 8.0, 28.0, 8.0), 4.0, Color(0.22, 0.22, 0.28, a))
			Art.circ(self, mp + Vector2(0, -15), 4.0, Color(1, 0.2, 0.2, a * (0.4 + 0.6 * blink)))
			if float(o["arm"]) <= 0.0:
				Art.circ(self, mp + Vector2(0, -15), 12.0, Color(1, 0.2, 0.2, 0.15 * blink))
		"snow":
			var r: float = o["r"]
			var dir2: int = o["dir"]
			if float(o["warn"]) > 0.0:
				var ex := 300.0 if dir2 > 0 else 980.0
				_bang(Vector2(ex, float(o["y"]) - 70.0), 0.5 + 0.5 * _blink(12.0))
				_chevron(Vector2(ex + dir2 * 46.0, float(o["y"]) - 70.0), float(dir2), Color(1, 1, 1, 0.8))
				return
			var c := Vector2(float(o["x"]), float(o["y"]) - r)
			Art.circ(self, c, r, Color("dfe9f2"))
			Art.circ(self, c + Vector2(-r * 0.25, -r * 0.25), r * 0.6, Color("f6fbff"))
			Art.circ(self, c + Vector2(r * 0.3, r * 0.3), r * 0.3, Color("b6c8da"))
			var ang := float(o["x"]) / r * float(dir2)
			Art.circ(self, c + Vector2(cos(ang), sin(ang)) * r * 0.55, 4.0, Color("9fb4c8"))
			for i in 4:
				Art.circ(self, c - Vector2(dir2 * (r + 8.0 + i * 12.0), -r * 0.7 + i * 3.0), 6.0 - i, Color(1, 1, 1, 0.35 - i * 0.07))
		"bolt":
			var bx: float = o["x"]
			var by: float = o["y"]
			if float(o["warn"]) > 0.0:
				var al := 0.25 + 0.5 * _blink(16.0)
				Art.ellipse(self, Vector2(bx, by), 28.0, 7.0, Color(1, 0.9, 0.2, al))
				var yy := 40.0
				while yy < by:
					draw_line(Vector2(bx, yy), Vector2(bx, minf(yy + 10.0, by)), Color(1, 0.9, 0.3, al * 0.6), 2.0)
					yy += 22.0
				_bang(Vector2(bx, minf(by, 560.0) - 60.0), al + 0.3)
				return
			var pts := PackedVector2Array()
			var y2 := 0.0
			while y2 < by:
				pts.append(Vector2(bx + (sin(y2 * 0.9 + float(o["on"]) * 90.0) * 16.0 if y2 > 0.0 else 0.0), y2))
				y2 += 30.0
			pts.append(Vector2(bx, by))
			Art.polyline(self, pts, Color(1, 0.95, 0.4, 0.35), 34.0, true)
			Art.polyline(self, pts, Color(1, 0.95, 0.6, 0.9), 12.0, true)
			Art.polyline(self, pts, Color(1, 1, 1), 4.0, true)
			Art.circ(self, Vector2(bx, by), 30.0, Color(1, 1, 0.6, 0.45))
		"foot":
			var fx: float = o["x"]
			var fy: float = o["y"]
			if float(o["warn"]) > 0.0:
				Art.ellipse(self, Vector2(fx, fy), 70.0, 10.0, Color(1, 0.15, 0.1, 0.2 + 0.35 * _blink(14.0)))
				_bang(Vector2(fx, minf(fy, 560.0) - 120.0), 0.5 + 0.5 * _blink(12.0))
				return
			var fp: float = o["p"]
			Art.rrect(self, Rect2(fx - 28.0, -300.0, 56.0, fp - 60.0 + 300.0), 14.0, Color("b07a4a"), Color("5a3a22"), 3.0)
			Art.rrect(self, Rect2(fx - 66.0, fp - 70.0, 132.0, 70.0), 28.0, Color("d49a62"), Color("5a3a22"), 4.0, 8)
			for q in 4:
				Art.circ(self, Vector2(fx - 45.0 + q * 30.0, fp - 12.0), 10.0, Color("e8b886"))
		"wave":
			var wx: float = o["x"]
			var wy: float = o["y"]
			var wdir: int = o["dir"]
			var wa := clampf(float(o["life"]), 0.0, 1.0)
			Art.poly(self, PackedVector2Array([Vector2(wx - wdir * 40.0, wy), Vector2(wx + wdir * 16.0, wy),
				Vector2(wx + wdir * 4.0, wy - 38.0)]), Color(0.85, 0.78, 0.65, 0.7 * wa))
			Art.ellipse(self, Vector2(wx - wdir * 20.0, wy - 4.0), 30.0, 8.0, Color(0.9, 0.85, 0.75, 0.4 * wa))
		"fire":
			var fp0: Vector2 = o["p"]
			if float(o["warn"]) > 0.0:
				for q in 4:
					Art.circ(self, Vector2(fp0.x + sin(t * 9.0 + q * 1.7) * 14.0, fp0.y - fposmod(t * 60.0 + q * 11.0, 24.0)),
						4.0 + float(q % 2) * 2.0, Color(1, 0.55, 0.2, 0.5 + 0.4 * _blink(14.0)))
				return
			var fvv: Vector2 = o["v"]
			draw_line(fp0 - fvv.normalized() * 36.0, fp0, Color(1, 0.5, 0.15, 0.35), 20.0, true)
			Art.circ(self, fp0, 22.0, Color(1, 0.5, 0.15, 0.3))
			Art.circ(self, fp0, 15.0, Color("ff8a2a"))
			Art.circ(self, fp0, 9.0, Color("ffd04a"))
		"boom":
			var f := 1.0 - float(o["t"]) / 0.35
			var r: float = o["r"]
			Art.circ(self, o["p"], r * (0.4 + 0.6 * f), Color(1, 0.6, 0.2, 0.5 * (1.0 - f)))
			Art.arc(self, o["p"], r * (0.5 + 0.7 * f), 0.0, TAU, 24, Color(1, 0.9, 0.6, 1.0 - f), 4.0, true)
		"meteor":
			var tg: Vector2 = o["target"]
			var w: float = o["warn"]
			var g := clampf(1.0 - w, 0.0, 1.0)
			if tg.y < 760.0:
				Art.ellipse(self, tg, 20.0 + 30.0 * g, 6.0 + 4.0 * g, Color(1, 0.15, 0.1, 0.25 + 0.4 * _blink(16.0)))
			if w > 0.0:
				_bang(Vector2(tg.x, minf(tg.y, 560.0) - 50.0), 0.5 + 0.5 * _blink(14.0))
				return
			var p: Vector2 = o["p"]
			var d: Vector2 = (o["v"] as Vector2).normalized()
			draw_line(p - d * 110.0, p, Color(1, 0.5, 0.15, 0.35), 26.0, true)
			draw_line(p - d * 70.0, p, Color(1, 0.8, 0.3, 0.6), 12.0, true)
			Art.circ(self, p, 26.0, Color(1, 0.5, 0.15, 0.3))
			Art.circ(self, p, 20.0, Color("6a4a3a"))
			Art.circ(self, p + Vector2(-5, -5), 7.0, Color("8a6a50"))
			Art.circ(self, p + Vector2(7, 4), 4.0, Color("4a3428"))
		"ball":
			var bp: Vector2 = o["p"]
			var v: Vector2 = o["v"]
			for i in 4:
				Art.circ(self, bp - v.normalized() * (18.0 + i * 14.0), 8.0 - i * 1.5, Color(0.8, 0.8, 0.85, 0.3 - i * 0.06))
			Art.circ(self, bp, float(o["r"]), Color("1e1e26"))
			Art.circ(self, bp + Vector2(-4, -5), 4.0, Color(1, 1, 1, 0.35))
		"stal":
			var sp: Vector2 = o["p"]
			var ln: float = o["len"]
			if float(o["warn"]) > 0.0:
				sp.x += sin(t * 70.0) * 2.0
			var tri := PackedVector2Array([sp + Vector2(-12, -ln), sp + Vector2(12, -ln), sp])
			Art.poly(self, tri, P["rock3"])
			Art.poly(self, PackedVector2Array([sp + Vector2(0, -ln), sp + Vector2(12, -ln), sp]), P["rock1"])
			if float(o["warn"]) > 0.0:
				var tg2: Vector2 = o["target"]
				if tg2.y < 760.0:
					Art.ellipse(self, tg2, 22.0, 6.0, Color(1, 0.15, 0.1, 0.2 + 0.3 * _blink(16.0)))
