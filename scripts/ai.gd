extends RefCounted
## IA dos lutadores: gera "entradas virtuais" (held/just) como se fosse um controle.
##
## Nível 1: lenta, erra, quase não se recupera, nunca usa escudo nem especiais.
## Nível 5: intermediária (usa especiais, escudo e golpes direcionais).
## Nível 9: reflexos rápidos, escudo, agarra quem defende, especiais, recuperação perfeita.

const Art := preload("res://scripts/art.gd")

var f: Node
var level := 5
var held: Dictionary = {}
var just: Dictionary = {}
var p: Dictionary = {}
var info: Dictionary = {}   # slot -> {reach, kind}
var ranged := false
var melee_reach := 40.0

var think_t := 0.3
var mv := 0.0               # intenção de movimento horizontal (-1, 0, 1)
var down_hold := false
var act_held: Dictionary = {}
var act_t := 0.0
var btn_name := ""
var btn_t := 0.0
var shield_t := 0.0
var sp_cd := 0.0
var grab_pick := ""
var grab_t := 0.0


func _init(fighter: Node, lvl: int) -> void:
	f = fighter
	level = clampi(lvl, 1, 9)
	var t := float(level - 1) / 8.0
	p = {
		"interval": lerpf(0.45, 0.06, t),
		"aggr": lerpf(0.30, 0.95, t),
		"special": lerpf(0.04, 0.55, t),
		"shield": 0.0 if level < 3 else lerpf(0.10, 0.85, t),
		"mistake": lerpf(0.30, 0.0, t),
		"recover": lerpf(0.20, 1.0, t),
		"t": t,
	}
	_analyze()


## Descobre o alcance e o tipo de cada golpe do personagem.
func _analyze() -> void:
	var moves: Dictionary = f.cdata["moves"]
	for slot in moves.keys():
		var m: Dictionary = moves[slot]
		if m.has("copy"):
			info[slot] = {"reach": 45.0, "melee": 45.0, "kind": "attack"}
			continue
		var reach := 0.0
		var melee := 0.0
		var kind := "util"
		for s in m["steps"]:
			match String(s["type"]):
				"hit", "grab":
					var off: Vector2 = f.hb_off(s)
					var sz: Vector2 = f.hb_size(s)
					var rr: float = absf(off.x) + sz.x / 2.0
					reach = maxf(reach, rr)
					melee = maxf(melee, rr)
					kind = "attack"
				"proj":
					var r := 520.0 if String(s.get("mode", "fly")) == "fly" else 60.0
					if s.get("sky_target", false):
						r = 450.0
					reach = maxf(reach, r)
					kind = "attack"
				"area":
					reach = maxf(reach, float(s["r"]) * 0.65)
					kind = "attack"
				"guard", "barrier":
					if kind != "attack":
						kind = "defense"
		info[slot] = {"reach": reach, "melee": melee, "kind": kind}
	var jr := maxf(float(info["jab"]["reach"]), float(info["ftilt"]["reach"]))
	ranged = jr >= 300.0
	melee_reach = maxf(maxf(float(info["jab"]["melee"]), float(info["ftilt"]["melee"])), 28.0)


func update(delta: float) -> void:
	just.clear()
	held.clear()
	think_t -= delta
	sp_cd = maxf(sp_cd - delta, 0.0)
	act_t -= delta
	btn_t -= delta
	shield_t -= delta
	if f.grab_v == null:
		grab_pick = ""
		grab_t = 0.0
	if f.eliminated or f.respawn_t > 0.0:
		return
	if f.hitstun > 0.0 or f.stun > 0.0 or f.grabbed_by != null or f.pin_t > 0.0:
		act_t = 0.0
		return
	if f.grab_v != null:
		_grab_logic(delta)
		return
	if think_t <= 0.0:
		think_t = float(p["interval"]) * randf_range(0.8, 1.25)
		_think()
		var ut: Node = f._nearest_enemy()
		if ut != null and (f.ult_cd <= 0.0 or f.power_orb) and f.cur_move.is_empty() and f.hitstun <= 0.0 \
				and f.global_position.distance_to(ut.global_position) < 340.0 \
				and randf() < 0.12 + 0.45 * float(p["t"]):
			just["ult"] = true
	if act_t > 0.0:
		for k in act_held.keys():
			held[k] = true
	else:
		if mv < 0.0:
			held["left"] = true
		elif mv > 0.0:
			held["right"] = true
		if down_hold:
			held["down"] = true
	if btn_t > 0.0:
		held[btn_name] = true
	if shield_t > 0.0:
		held["shield"] = true


func _ok(slot: String, dist: float) -> bool:
	if not info.has(slot):
		return false
	var i: Dictionary = info[slot]
	return i["kind"] == "attack" and float(i["reach"]) >= dist - 15.0 and f.mana >= f.cost_of(slot)


func _think() -> void:
	var tgt: Node = f._nearest_enemy()
	if tgt == null:
		mv = 0.0
		return
	var pos: Vector2 = f.global_position
	var tp: Vector2 = tgt.global_position
	var dx := tp.x - pos.x
	var dy := tp.y - pos.y
	var dist := absf(dx)
	var toward := 1.0 if dx >= 0.0 else -1.0
	var on_floor: bool = f.is_on_floor()
	var attacking: bool = not f.cur_move.is_empty()
	down_hold = false

	# Fora do palco: recuperação
	var feet: float = pos.y + f.body.y / 2.0
	if not on_floor and Art.surface_below(pos.x, feet) < 0.0:
		_recover(pos)
		return
	# Lava subindo (ou já alta): corre para o terreno alto do meio
	if Art.lava_danger > 0.0 and level >= 3 and feet > Art.lava_danger - 6.0:
		var sx := Art.respawn.x
		mv = 0.0 if absf(pos.x - sx) < 30.0 else (1.0 if sx > pos.x else -1.0)
		act_t = 0.0
		# pula só na beirada (buraco à frente) ou quando há um degrau mais alto logo adiante
		var step := Art.surface_below(pos.x + mv * 40.0, feet - 60.0)
		if on_floor and mv != 0.0 and (step < 0.0 or step < feet - 8.0):
			just["jump"] = true
		return
	if attacking:
		return
	# Erros (níveis baixos): anda sem rumo
	if randf() < float(p["mistake"]):
		mv = [-1.0, 0.0, 0.0, 1.0].pick_random()
		return

	# Defesa: segura escudo quando o rival ataca perto
	if on_floor and not tgt.cur_move.is_empty() and dist < 100.0 and absf(dy) < 70.0 \
			and randf() < float(p["shield"]):
		shield_t = 0.35 + randf() * 0.25
		mv = 0.0
		return
	# Contra escudo: agarra
	if on_floor and tgt.shielding and dist < 45.0 and level >= 5 and randf() < 0.7:
		if f.facing == int(toward):
			_do("grab", toward)
			return
	# Defesa especial (contra-ataque, escudo mágico...)
	if level >= 5 and not tgt.cur_move.is_empty() and dist < 120.0 and info.has("b_down") \
			and info["b_down"]["kind"] == "defense" and randf() < 0.35 and sp_cd <= 0.0 \
			and f.mana >= f.cost_of("b_down"):
		_do("b_down", toward)
		sp_cd = 1.2
		return

	# Movimento
	var want_dist := clampf(melee_reach * 0.7, 20.0, 60.0)
	if ranged and level >= 4:
		want_dist = 280.0
	if dist > want_dist + 12.0:
		mv = toward
	elif ranged and level >= 4 and dist < want_dist - 60.0:
		mv = -toward
	else:
		mv = 0.0
	# Não cai da beirada de propósito (a partir do nível 3)
	if level >= 3 and on_floor and mv != 0.0:
		var ahead := Art.surface_below(pos.x + mv * 40.0, feet - 2.0)
		if ahead < 0.0 or ahead > feet + 160.0:
			# buraco à frente: pula por cima se houver chão do outro lado e o rival estiver lá
			var far := Art.surface_below(pos.x + mv * 170.0, feet - 140.0)
			if far >= 0.0 and mv == toward and dist > 90.0 and level >= 4:
				just["jump"] = true
			else:
				mv = 0.0
	# Plataformas
	if dy < -90.0 and dist < 170.0:
		if on_floor and randf() < 0.5 + 0.4 * float(p["t"]):
			just["jump"] = true
		elif not on_floor and f.jumps_left > 0 and f.velocity.y > 0.0 and randf() < 0.5:
			just["jump"] = true
	elif dy > 90.0 and dist < 120.0 and on_floor and level >= 3 \
			and Art.surface_below(pos.x, feet + 12.0) >= 0.0:
		down_hold = true
		just["down"] = true
	# Fica de frente para o rival antes de atacar
	if dist > 20.0 and f.facing != int(toward) and on_floor:
		mv = toward
		return

	# Ataques
	var near := dist < 80.0 and absf(dy) < 80.0
	var in_y := absf(dy) < 55.0
	var cands: Array = []
	if randf() < float(p["aggr"]):
		if on_floor:
			if in_y and _ok("jab", dist):
				cands.append(["jab", 3.0])
			if in_y and _ok("ftilt", dist):
				cands.append(["ftilt", 3.0])
			if level >= 4 and dy < -35.0 and dist < 60.0 and _ok("utilt", dist):
				cands.append(["utilt", 4.0])
			if level >= 4 and in_y and _ok("dtilt", dist):
				cands.append(["dtilt", 1.5])
		else:
			if near and _ok("nair", dist):
				cands.append(["nair", 2.0])
			if near and toward == float(f.facing) and _ok("fair", dist):
				cands.append(["fair", 3.0])
			if near and level >= 4 and toward != float(f.facing) and _ok("bair", dist):
				cands.append(["bair", 3.0])
			if near and dy < -45.0 and _ok("uair", dist):
				cands.append(["uair", 3.0])
			if level >= 4 and dy > 35.0 and dist < 45.0 and _ok("dair", dist):
				cands.append(["dair", 3.0])
	# Especiais
	if level >= 2 and sp_cd <= 0.0 and randf() < float(p["special"]) and dist < 600.0:
		for sl in ["b_neutral", "b_side"]:
			if _ok(sl, dist):
				cands.append([sl, 2.5])
	if cands.is_empty():
		# Especiais de suporte (cura, buff) quando longe do rival
		if level >= 4 and dist > 250.0 and sp_cd <= 0.0 and f.percent > 25.0 and randf() < 0.2 \
				and info.has("b_neutral") and info["b_neutral"]["kind"] == "util" \
				and f.mana >= f.cost_of("b_neutral"):
			_do("b_neutral", toward)
			sp_cd = 4.0
		return
	var total := 0.0
	for c in cands:
		total += float(c[1])
	var roll := randf() * total
	var pick: String = cands[0][0]
	for c in cands:
		roll -= float(c[1])
		if roll <= 0.0:
			pick = c[0]
			break
	_do(pick, toward)
	if pick.begins_with("b_"):
		sp_cd = lerpf(3.5, 1.0, float(p["t"]))


func _recover(pos: Vector2) -> void:
	var s := Art.nearest_surface(pos)
	if s.is_empty():
		mv = 1.0 if pos.x < 640.0 else -1.0
		return
	var x0: float = s["x0"]
	var x1: float = s["x1"]
	var sy: float = s["y"]
	var tx := clampf(pos.x, x0 + 30.0, x1 - 30.0)
	if pos.y > sy + 10.0 and pos.x > x0 - 15.0 and pos.x < x1 + 15.0:
		# por baixo da superfície: vai para a borda mais próxima
		tx = x0 - 40.0 if pos.x - x0 < x1 - pos.x else x1 + 40.0
	mv = 0.0 if absf(tx - pos.x) < 8.0 else (1.0 if tx > pos.x else -1.0)
	if randf() > float(p["recover"]):
		return
	if f.jumps_left > 0 and f.velocity.y > -100.0 and pos.y > sy - 140.0:
		just["jump"] = true
	elif f.jumps_left <= 0 and not f.up_b_used and pos.y > sy - 120.0 and f.cdata["moves"].has("b_up") \
			and f.mana >= f.cost_of("b_up"):
		_do("b_up", mv)


## Traduz um golpe em entradas (direção + botão).
func _do(slot: String, toward: float) -> void:
	act_held = {}
	var dir_toward := "right" if toward >= 0.0 else "left"
	var dir_away := "left" if toward >= 0.0 else "right"
	match slot:
		"jab", "nair":
			just["attack"] = true
		"ftilt", "fair", "dash":
			act_held[dir_toward] = true
			just["attack"] = true
		"bair":
			act_held[dir_away] = true
			just["attack"] = true
		"utilt", "uair":
			act_held["up"] = true
			just["attack"] = true
		"dtilt", "dair":
			act_held["down"] = true
			just["attack"] = true
		"grab":
			act_held["shield"] = true
			just["attack"] = true
		"b_neutral":
			just["special"] = true
		"b_side":
			act_held[dir_toward] = true
			just["special"] = true
		"b_up":
			act_held["up"] = true
			if toward != 0.0:
				act_held[dir_toward] = true
			just["special"] = true
		"b_down":
			act_held["down"] = true
			just["special"] = true
	act_t = 0.15
	var m: Dictionary = f._moves().get(slot, {})
	if m.has("charge"):
		btn_name = "special"
		btn_t = float((m["charge"] as Dictionary)["max"]) * 0.9
	if act_held.has("down"):
		down_hold = false


func _grab_logic(delta: float) -> void:
	grab_t += delta
	var v: Node = f.grab_v
	if grab_pick == "":
		var r := randf()
		if level >= 5 and v != null and v.percent > 70.0:
			grab_pick = "f" if r < 0.5 else "b"
		elif r < 0.4:
			grab_pick = "f"
		elif r < 0.6:
			grab_pick = "b"
		elif r < 0.8:
			grab_pick = "u"
		else:
			grab_pick = "d"
	if grab_t < 0.25 + (1.0 - float(level) / 9.0) * 0.5:
		return
	var right_is_front: bool = f.facing == 1
	match grab_pick:
		"u":
			held["up"] = true
		"d":
			held["down"] = true
		"f":
			held["right" if right_is_front else "left"] = true
		"b":
			held["left" if right_is_front else "right"] = true
