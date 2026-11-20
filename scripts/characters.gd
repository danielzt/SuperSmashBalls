extends RefCounted
## Dados dos 16 personagens. O motor que executa os golpes está em fighter.gd.
##
## Esquema de golpes (estilo Smash):
##   A: jab | Lado+A: ftilt | Cima+A: utilt | Baixo+A: dtilt | Correndo+A: dash
##   No ar: A nair | Frente+A fair | Trás+A bair | Cima+A uair | Baixo+A dair
##   Escudo+A: agarrão (grab), com arremessos Frente/Trás/Cima/Baixo
##   B: b_neutral (Especial) | Lado+B: b_side (Especial 2) | Cima+B: b_up | Baixo+B: b_down
##
## Passos de um golpe (campo "t" = segundo em que acontecem):
##   hit, vel, proj, tele, ghost, armor, guard, barrier, heal, buff, fly,
##   area, root_area, grab, morph, stopx

static var _cache: Array = []

const SLOT_ORDER := ["jab", "ftilt", "utilt", "dtilt", "dash", "nair", "fair", "bair", "uair",
	"dair", "grab", "b_neutral", "b_side", "b_up", "b_down"]
const SLOT_NAMES := {
	"jab": "A", "ftilt": "Lado+A", "utilt": "Cima+A", "dtilt": "Baixo+A", "dash": "Correndo+A",
	"nair": "Ar A", "fair": "Ar Frente+A", "bair": "Ar Trás+A", "uair": "Ar Cima+A",
	"dair": "Ar Baixo+A", "grab": "Escudo+A", "b_neutral": "B (Especial)",
	"b_side": "Lado+B (Esp. 2)", "b_up": "Cima+B", "b_down": "Baixo+B",
}


## Custo de mana de cada golpe (a barra vai de 0 a 100 e recarrega com o tempo).
const MANA_COST := {
	"jab": 4, "ftilt": 7, "utilt": 7, "dtilt": 7, "dash": 10, "ult": 0,
	"nair": 7, "fair": 7, "bair": 7, "uair": 7, "dair": 7,
	"grab": 10, "b_neutral": 35, "b_side": 40, "b_up": 25, "b_down": 20,
}


static func all() -> Array:
	if _cache.is_empty():
		_cache = _build()
	return _cache


# ---------------------------------------------------------------- helpers

static func _h(t: float, len: float, ox: float, oy: float, w: float, h: float, dmg: float,
		base: float, sc: float, ang: float, ex: Dictionary = {}) -> Dictionary:
	var d := {"type": "hit", "t": t, "len": len, "off": Vector2(ox, oy), "size": Vector2(w, h),
		"dmg": dmg, "base": base, "scale": sc, "angle": ang}
	d.merge(ex, true)
	return d


static func _v(t: float, vx: float, vy: float, ex: Dictionary = {}) -> Dictionary:
	var d := {"type": "vel", "t": t, "vx": vx, "vy": vy}
	d.merge(ex, true)
	return d


static func _s(t: float, type: String, ex: Dictionary = {}) -> Dictionary:
	var d := {"type": type, "t": t}
	d.merge(ex, true)
	return d


static func _pr(t: float, ox: float, oy: float, vx: float, vy: float, r: float, dmg: float,
		base: float, sc: float, ang: float, ex: Dictionary = {}) -> Dictionary:
	var d := {"type": "proj", "t": t, "off": Vector2(ox, oy), "vel": Vector2(vx, vy), "r": r,
		"dmg": dmg, "base": base, "scale": sc, "angle": ang}
	d.merge(ex, true)
	return d


static func _g(t: float, len: float, ox: float, oy: float, w: float, h: float,
		ex: Dictionary = {}) -> Dictionary:
	var d := {"type": "grab", "t": t, "len": len, "off": Vector2(ox, oy), "size": Vector2(w, h)}
	d.merge(ex, true)
	return d


static func _m(label: String, dur: float, steps: Array, ex: Dictionary = {}) -> Dictionary:
	var d := {"label": label, "dur": dur, "steps": steps}
	d.merge(ex, true)
	return d


static func _copy(label: String, slot: String) -> Dictionary:
	return {"label": label, "dur": 0.3, "steps": [], "copy": slot}


static func _throw(label: String, dmg: float, base: float, sc: float, ang: float) -> Dictionary:
	return {"label": label, "dmg": dmg, "base": base, "scale": sc, "angle": ang}


static func _std_throws(p: float) -> Dictionary:
	return {
		"f": _throw("Arremesso frontal", 7 * p, 330, 3.4 * p, 38),
		"b": _throw("Arremesso traseiro", 8 * p, 340, 3.6 * p, 38),
		"u": _throw("Arremesso para cima", 6 * p, 300, 3.0 * p, 85),
		"d": _throw("Arremesso para baixo", 5 * p, 250, 2.8 * p, 70),
	}


## Conjunto padrão de golpes: p = poder, s = duração (menor = mais rápido), r = alcance.
static func _std(p: float, s: float, r: float) -> Dictionary:
	var m := {}
	m["jab"] = _m("Golpe rápido", 0.26 * s, [_h(0.05 * s, 0.07, 34 * r, 0, 44 * r, 34, 3 * p, 110, 1.0 * p, 25)])
	m["ftilt"] = _m("Golpe frontal", 0.40 * s, [_h(0.12 * s, 0.09, 42 * r, 0, 56 * r, 40, 8 * p, 250, 3.2 * p, 38)])
	m["utilt"] = _m("Golpe para cima", 0.38 * s, [_h(0.10 * s, 0.10, 0, -52 * r, 64 * r, 46, 7 * p, 260, 3.0 * p, 88)])
	m["dtilt"] = _m("Golpe baixo", 0.34 * s, [_h(0.08 * s, 0.08, 40 * r, 22, 64 * r, 22, 6 * p, 200, 2.6 * p, 30)])
	m["dash"] = _m("Ataque correndo", 0.55 * s, [_v(0.0, 520, 0, {"keep_y": true}),
		_h(0.05 * s, 0.28, 34 * r, 0, 52 * r, 44, 9 * p, 300, 3.2 * p, 40)])
	m["nair"] = _m("Golpe aéreo", 0.42 * s, [_h(0.06 * s, 0.20, 0, 0, 76 * r, 64, 7 * p, 230, 2.8 * p, 45)], {"air": true})
	m["fair"] = _m("Golpe aéreo frontal", 0.45 * s, [_h(0.12 * s, 0.10, 40 * r, 0, 56 * r, 50, 9 * p, 290, 3.4 * p, 40)], {"air": true})
	m["bair"] = _m("Golpe aéreo traseiro", 0.45 * s, [_h(0.10 * s, 0.10, -40 * r, 0, 56 * r, 50, 10 * p, 310, 3.6 * p, 40)], {"air": true})
	m["uair"] = _m("Golpe aéreo para cima", 0.40 * s, [_h(0.08 * s, 0.10, 0, -50 * r, 64 * r, 46, 8 * p, 260, 3.0 * p, 88)], {"air": true})
	m["dair"] = _m("Golpe aéreo para baixo", 0.50 * s, [_h(0.14 * s, 0.12, 0, 48 * r, 44 * r, 50, 8 * p, 220, 3.0 * p, -70)], {"air": true})
	m["grab"] = _m("Agarrar", 0.40, [_g(0.10, 0.12, 34 * r, 0, 46 * r, 52, {"hold": 1.2, "mode": "choose"})])
	m["b_up"] = _m("Impulso", 0.7, [_v(0.05, 80, -700), _h(0.05, 0.30, 0, -20, 60, 70, 6 * p, 250, 2.6 * p, 80)])
	m["b_down"] = _m("Giro", 0.5, [_h(0.06, 0.20, 0, 0, 90, 60, 6 * p, 240, 2.8 * p, 50)])
	m["b_neutral"] = _m("Especial", 0.5, [_h(0.15, 0.10, 44, 0, 60, 46, 10 * p, 300, 3.6 * p, 40)])
	m["b_side"] = _m("Especial 2", 0.5, [_h(0.15, 0.10, 44, 0, 60, 46, 10 * p, 300, 3.6 * p, 40)])
	return m


static func _c(name: String, desc: String, weight: float, speed: float, jump: float, jumps: int,
		fall: float, size: Vector2, moves: Dictionary, throws: Dictionary = {}) -> Dictionary:
	return {"name": name, "desc": desc, "weight": weight, "speed": speed, "jump": jump,
		"jumps": jumps, "fall": fall, "size": size, "moves": moves,
		"throws": throws if not throws.is_empty() else _std_throws(1.0)}


static func _build() -> Array:
	var list: Array = [
		_equilibrado(), _velocista(), _tanque(), _grappler(),
		_zoner(), _espadachim(), _ninja(), _aereo(),
		_mago(), _tecnologico(), _capoeirista(), _trapper(),
		_suporte(), _mimico(), _assassino(), _duelista(),
	]
	for i in list.size():
		list[i]["id"] = i
		list[i]["moves"]["ult"] = _sig(i)
		list[i]["color"] = Color.from_hsv(float(i) / 16.0, 0.55, 0.92)
	return list


# ---------------------------------------------------------------- personagens

static func _equilibrado() -> Dictionary:
	var m := _std(1.0, 1.0, 1.0)
	m["jab"] = _m("Soco leve", 0.28, [_h(0.05, 0.07, 36, 0, 46, 36, 3, 110, 1.0, 25)])
	m["ftilt"] = _m("Soco forte", 0.42, [_h(0.14, 0.09, 44, 0, 58, 42, 9, 270, 3.4, 38)])
	m["dtilt"] = _m("Chute baixo", 0.36, [_h(0.09, 0.09, 42, 24, 64, 22, 6, 210, 2.6, 28)])
	m["utilt"] = _m("Chute alto", 0.40, [_h(0.10, 0.10, 10, -52, 70, 50, 8, 270, 3.0, 85)])
	m["fair"] = _m("Pulo duplo + chute", 0.46, [_h(0.10, 0.12, 42, 0, 60, 46, 10, 300, 3.4, 38)], {"air": true})
	m["b_up"] = _m("Pulo + chute", 0.70, [_v(0.04, 70, -690), _h(0.06, 0.34, 20, -14, 60, 84, 7, 270, 2.8, 80)])
	m["b_down"] = _m("Defesa + contra-ataque", 0.75, [_s(0.0, "guard", {"len": 0.5, "mult": 0.0, "kb": 0.0,
		"counter": _m("Contra-ataque", 0.4, [_h(0.04, 0.10, 44, 0, 62, 48, 12, 320, 4.0, 40)])})])
	m["b_neutral"] = _m("Combo de 3 hits", 0.85, [
		_h(0.08, 0.07, 40, 0, 50, 40, 4, 60, 0.4, 20, {"pin": true}),
		_h(0.26, 0.07, 42, 0, 52, 40, 4, 70, 0.4, 20, {"pin": true, "if_hit": true}),
		_h(0.44, 0.10, 46, 0, 58, 44, 8, 330, 3.6, 40, {"if_hit": true})])
	m["b_side"] = _m("Soco carregado que empurra (segure B)", 0.85,
		[_h(0.10, 0.12, 50, 0, 66, 46, 10, 320, 4.2, 15, {"charged": true})],
		{"charge": {"at": 0.08, "max": 0.8}})
	return _c("Equilibrado", "Golpes versáteis, bom em tudo.", 1.0, 1.0, 1.0, 2, 1.0, Vector2(40, 64), m)


static func _velocista() -> Dictionary:
	var m := _std(0.85, 0.75, 0.95)
	m["jab"] = _m("Soco rápido x3", 0.5, [
		_h(0.04, 0.06, 34, 0, 44, 34, 2, 40, 0.3, 20, {"pin": true}),
		_h(0.15, 0.06, 34, 0, 44, 34, 2, 40, 0.3, 20, {"pin": true, "if_hit": true}),
		_h(0.26, 0.08, 36, 0, 46, 34, 3, 150, 1.6, 30, {"if_hit": true})])
	m["ftilt"] = _m("Chute rápido", 0.28, [_h(0.05, 0.07, 42, 0, 56, 36, 6, 240, 2.8, 38)])
	m["dash"] = _m("Corrida + soco", 0.5, [_v(0.0, 660, 0, {"keep_y": true}),
		_h(0.05, 0.30, 36, 0, 50, 40, 8, 300, 3.2, 40)])
	m["fair"] = _m("Ataque correndo (ar)", 0.45, [_v(0.02, 520, 0, {"keep_y": true}),
		_h(0.05, 0.25, 34, 0, 54, 46, 8, 280, 3.2, 40)], {"air": true})
	m["b_up"] = _m("Dash pra frente", 0.55, [_v(0.03, 720, -380),
		_h(0.05, 0.25, 20, 0, 60, 50, 6, 260, 2.8, 50)])
	m["b_down"] = _m("Dash pra trás", 0.40, [_v(0.0, -700, 0, {"keep_y": true}),
		_s(0.0, "ghost", {"len": 0.22, "alpha": 0.5})])
	m["b_neutral"] = _m("Dash fantasma (atravessa e corta)", 0.65, [
		_s(0.0, "ghost", {"len": 0.24, "alpha": 0.35}),
		_v(0.0, 760, 0, {"keep_y": true}),
		_s(0.2, "stopx"),
		_h(0.22, 0.12, 0, 0, 190, 60, 10, 330, 3.6, 40)])
	var steps: Array = []
	for i in 5:
		var last := i == 4
		steps.append(_h(0.05 + i * 0.2, 0.07, 38, 0, 52, 40, 5.0 if last else 2.2,
			350.0 if last else 50.0, 4.0 if last else 0.3, 35.0 if last else 20.0,
			{"pin": not last, "if_hit": i > 0}))
	m["b_side"] = _m("5 socos em 1 segundo", 1.15, steps)
	return _c("Velocista", "Rápido e leve. Combos de socos.", 0.85, 1.35, 1.08, 2, 1.0, Vector2(36, 60), m)


static func _tanque() -> Dictionary:
	var m := _std(1.3, 1.3, 1.15)
	m["jab"] = _m("Soco pesado", 0.55, [_h(0.16, 0.10, 44, 0, 58, 46, 10, 300, 3.6, 35)])
	m["ftilt"] = _m("Chute pesado", 0.60, [_h(0.20, 0.12, 50, 10, 64, 50, 12, 330, 4.0, 35)])
	m["dash"] = _m("Ombro (empurra)", 0.65, [_v(0.0, 480, 0, {"keep_y": true}),
		_h(0.05, 0.35, 30, 0, 60, 64, 9, 300, 3.4, 30)])
	m["dtilt"] = _m("Soco no chão", 0.50, [_h(0.18, 0.10, 46, 26, 68, 26, 9, 260, 3.0, 30)])
	m["dair"] = _m("Pisada no chão", 0.60, [_v(0.05, 0, 900, {"keep_x": true}),
		_h(0.10, 0.30, 0, 46, 60, 50, 12, 250, 3.6, -75)], {"air": true})
	m["b_down"] = _m("Bloqueio pesado", 0.95, [_s(0.0, "guard", {"len": 0.9, "mult": 0.15, "kb": 0.2})])
	m["b_neutral"] = _m("Terremoto", 1.0, [
		_v(0.0, 0, -320),
		_s(0.55, "area", {"r": 650, "grounded": true, "dmg": 12, "base": 480, "scale": 3.6,
			"angle": 88, "ring": 650})])
	m["b_side"] = _m("Fúria (invencível 2s, golpes +60%)", 0.4, [
		_s(0.0, "ghost", {"len": 2.0, "alpha": 0.9}),
		_s(0.0, "buff", {"len": 2.0, "dmg": 1.6})])
	return _c("Tanque", "Lento e pesado. Quase não voa.", 1.4, 0.75, 0.85, 2, 1.0, Vector2(52, 72), m)


static func _grappler() -> Dictionary:
	var m := _std(1.15, 1.1, 0.9)
	m["nair"] = _m("Agarrão no ar", 0.7, [_g(0.08, 0.14, 0, 0, 70, 70, {"hold": 0.5, "mode": "auto",
		"throw": {"dmg": 10, "base": 300, "scale": 3.6, "angle": -60}})], {"air": true})
	m["b_neutral"] = _m("Suplex gigante (30%)", 1.2, [_g(0.12, 0.14, 38, 0, 52, 58, {"hold": 0.8, "mode": "auto",
		"throw": {"dmg": 30, "base": 520, "scale": 4.5, "angle": 75}})])
	m["b_side"] = _m("Pega e gira 2x", 1.8, [_g(0.12, 0.14, 38, 0, 52, 58, {"hold": 1.2, "mode": "auto", "spin": 2.0,
		"throw": {"dmg": 16, "base": 480, "scale": 4.4, "angle": 40}})])
	var th := {
		"f": _throw("Arremesso pra frente", 10, 380, 4.0, 38),
		"b": _throw("Arremesso pra trás", 11, 400, 4.2, 40),
		"u": _throw("Jogada de ombro (cima)", 9, 360, 3.6, 85),
		"d": _throw("Suplex (baixo)", 12, 300, 3.6, 70),
	}
	return _c("Grappler", "Agarra e arremessa. Danos enormes de perto.", 1.25, 0.9, 0.95, 2, 1.0, Vector2(46, 66), m, th)


static func _zoner() -> Dictionary:
	var m := _std(0.8, 1.0, 1.0)
	m["jab"] = _m("Projétil leve", 0.32, [_pr(0.08, 30, 0, 620, 0, 10, 3, 120, 1.2, 20, {"life": 1.2})])
	m["ftilt"] = _m("Projétil forte", 0.50, [_pr(0.18, 30, 0, 520, 0, 16, 9, 260, 3.0, 35, {"life": 1.6})])
	m["utilt"] = _m("Projétil alto", 0.45, [_pr(0.12, 14, -30, 160, -700, 14, 6, 240, 2.8, 80, {"life": 1.0, "grav": 700})])
	m["dtilt"] = _m("Projétil baixo", 0.38, [_pr(0.10, 30, 24, 560, 0, 12, 5, 180, 2.0, 25, {"life": 1.4})])
	m["nair"] = _m("Tiro no ar", 0.40, [_pr(0.08, 30, 10, 480, 380, 12, 5, 200, 2.4, 40, {"life": 1.2})], {"air": true})
	m["b_down"] = _m("Recua + tiro", 0.55, [_v(0.0, -480, 0, {"keep_y": true}),
		_pr(0.12, 30, 0, 640, 0, 13, 6, 220, 2.6, 30, {"life": 1.4})])
	var steps: Array = []
	for i in 5:
		steps.append(_pr(i * 0.12, 70 + i * 70, -280, 0, 620, 12, 5, 220, 2.6, 60, {"life": 1.2}))
	m["b_neutral"] = _m("Chuva de 5 projéteis", 0.95, steps)
	m["b_side"] = _m("Projétil gigante (atravessa)", 0.9, [_pr(0.3, 40, 0, 380, 0, 44, 14, 380, 4.5, 35,
		{"life": 2.6, "pierce": true})])
	return _c("Zoner", "Controla o espaço com projéteis.", 0.9, 1.0, 1.0, 2, 1.0, Vector2(38, 64), m)


static func _espadachim() -> Dictionary:
	var m := _std(1.1, 1.0, 1.35)
	m["jab"] = _m("Corte leve", 0.3, [_h(0.07, 0.08, 48, -4, 76, 34, 4, 150, 1.6, 30)])
	m["ftilt"] = _m("Corte forte", 0.5, [_h(0.20, 0.10, 56, 0, 86, 44, 11, 300, 3.8, 38)])
	m["utilt"] = _m("Corte pra cima", 0.45, [_h(0.12, 0.10, 18, -58, 84, 60, 8, 270, 3.0, 88)])
	m["dtilt"] = _m("Corte pra baixo", 0.42, [_h(0.10, 0.10, 50, 26, 86, 24, 8, 240, 3.0, 28)])
	m["dash"] = _m("Estocada (alcance longo)", 0.6, [_v(0.0, 420, 0, {"keep_y": true}),
		_h(0.10, 0.14, 68, -2, 110, 24, 10, 320, 3.6, 35)])
	m["b_down"] = _m("Defesa com espada", 0.7, [_s(0.0, "guard", {"len": 0.6, "mult": 0.2, "kb": 0.3})])
	m["b_neutral"] = _m("Corte em X (25%)", 0.85, [
		_h(0.20, 0.10, 50, -10, 80, 60, 12.5, 350, 3.8, 50),
		_h(0.38, 0.10, 50, 10, 80, 60, 12.5, 380, 4.0, 40)])
	m["b_side"] = _m("3 cortes seguidos", 0.9, [
		_h(0.12, 0.08, 52, 0, 84, 44, 5, 60, 0.4, 20, {"pin": true}),
		_h(0.32, 0.08, 52, 0, 84, 44, 5, 60, 0.4, 20, {"pin": true, "if_hit": true}),
		_h(0.52, 0.10, 56, 0, 90, 48, 7, 340, 3.8, 40, {"if_hit": true})])
	return _c("Espadachim", "Alcance longo com a espada.", 1.0, 1.0, 1.0, 2, 1.0, Vector2(40, 66), m)


static func _ninja() -> Dictionary:
	var m := _std(0.85, 0.8, 1.0)
	m["jab"] = _m("Soco rápido", 0.3, [
		_h(0.04, 0.06, 34, 0, 44, 34, 2, 50, 0.3, 20, {"pin": true}),
		_h(0.14, 0.07, 36, 0, 46, 34, 3, 140, 1.4, 30, {"if_hit": true})])
	m["ftilt"] = _m("Kunai", 0.36, [_pr(0.08, 30, -2, 820, 0, 8, 4, 150, 1.6, 25, {"life": 1.0})])
	m["fair"] = _m("Kunai no ar", 0.36, [_pr(0.06, 30, 6, 680, 360, 8, 4, 160, 1.8, 35, {"life": 1.0})], {"air": true})
	m["utilt"] = _m("Ataque pelas costas", 0.65, [
		_s(0.05, "tele", {"behind": true, "range": 280}),
		_h(0.15, 0.10, 40, 0, 50, 42, 8, 260, 3.0, 38, {"back_mult": 1.8})])
	m["b_up"] = _m("Teleporte pra frente", 0.45, [
		_s(0.0, "ghost", {"len": 0.2, "alpha": 0.3}),
		_s(0.1, "tele", {"dx": 190, "dy": -60})])
	m["b_down"] = _m("Teleporte pra trás", 0.45, [
		_s(0.0, "ghost", {"len": 0.2, "alpha": 0.3}),
		_s(0.1, "tele", {"dx": -190, "dy": 0})])
	m["b_neutral"] = _m("Some 1s e aparece atrás", 1.5, [
		_s(0.0, "ghost", {"len": 1.0, "alpha": 0.12}),
		_s(1.0, "tele", {"behind": true, "range": 700}),
		_h(1.08, 0.10, 40, 0, 52, 44, 11, 320, 3.6, 38, {"back_mult": 1.5})])
	var steps: Array = []
	for i in 5:
		steps.append(_pr(i * 0.08, 24, -10, 600 + i * 40, -180 + i * 90, 8, 4, 150, 1.8, 35, {"life": 1.1}))
	m["b_side"] = _m("Chuva de 5 kunais", 0.8, steps)
	return _c("Ninja", "Teleportes e ataques pelas costas.", 0.85, 1.2, 1.1, 2, 1.0, Vector2(36, 60), m)


static func _aereo() -> Dictionary:
	var m := _std(0.9, 0.85, 1.0)
	m["nair"] = _m("Giro no ar", 0.5, [_h(0.05, 0.30, 0, 0, 84, 70, 7, 230, 2.8, 45)], {"air": true})
	m["fair"] = _m("Chute aéreo", 0.45, [_h(0.10, 0.12, 42, 0, 62, 46, 9, 290, 3.4, 40)], {"air": true})
	m["uair"] = _m("Soco aéreo", 0.38, [_h(0.07, 0.10, 0, -50, 62, 46, 8, 270, 3.0, 88)], {"air": true})
	m["dair"] = _m("Mergulho leve", 0.55, [_v(0.04, 160, 700), _h(0.06, 0.35, 20, 40, 50, 56, 7, 230, 3.0, -55)],
		{"air": true})
	m["b_up"] = _m("Pulo + chute", 0.65, [_v(0.04, 60, -720), _h(0.06, 0.34, 22, -10, 62, 84, 7, 270, 2.8, 80)])
	m["b_neutral"] = _m("Mergulho do céu", 1.4, [
		_v(0.0, 0, -820),
		_v(0.45, 520, 1000),
		_h(0.45, 0.9, 24, 30, 58, 64, 15, 420, 4.4, -35)], {"land_end": true})
	m["b_side"] = _m("Voar por 3s", 0.25, [_s(0.0, "fly", {"len": 3.0})])
	return _c("Aéreo", "Pulo triplo e combate no ar.", 0.8, 1.0, 1.15, 3, 0.8, Vector2(38, 62), m)


static func _mago() -> Dictionary:
	var m := _std(1.0, 1.1, 1.0)
	m["jab"] = _m("Bola de fogo", 0.40, [_pr(0.10, 30, 0, 500, 0, 14, 5, 180, 2.0, 30, {"life": 1.5})])
	m["ftilt"] = _m("Raio", 0.55, [_h(0.18, 0.10, 190, 0, 340, 22, 8, 260, 3.0, 30)])
	m["utilt"] = _m("Gelo (deixa lento)", 0.45, [_pr(0.10, 30, 0, 430, 0, 16, 4, 120, 1.2, 25,
		{"life": 1.5, "slow": 2.5})])
	m["dtilt"] = _m("Magia no chão", 0.55, [_h(0.20, 0.25, 92, 22, 70, 70, 7, 260, 3.0, 85)])
	m["b_up"] = _m("Teleporte curto", 0.45, [_s(0.0, "ghost", {"len": 0.2, "alpha": 0.3}),
		_s(0.1, "tele", {"dx": 130, "dy": -110})])
	m["b_down"] = _m("Escudo de magia", 0.9, [_s(0.0, "barrier", {"len": 1.2, "hp": 25})])
	m["b_neutral"] = _m("Meteoro", 1.3, [_pr(0.5, 0, -80, 0, 700, 34, 16, 450, 4.8, 55,
		{"aoe": 95, "life": 3.0, "sky_target": true})])
	m["b_side"] = _m("Explosão em volta", 0.8, [_s(0.35, "area", {"r": 170, "dmg": 12, "base": 380,
		"scale": 4.0, "angle": 45, "radial": true, "ring": 170})])
	return _c("Mago", "Magias à distância e controle.", 0.85, 0.95, 1.0, 2, 1.0, Vector2(38, 64), m)


static func _tecnologico() -> Dictionary:
	var m := _std(1.05, 1.1, 1.0)
	m["jab"] = _m("Soco de ferro", 0.30, [_h(0.08, 0.08, 38, 0, 48, 38, 5, 200, 2.2, 30)])
	m["ftilt"] = _m("Chute de ferro", 0.45, [_h(0.14, 0.10, 46, 10, 56, 40, 9, 280, 3.4, 38)])
	m["utilt"] = _m("Laser pequeno", 0.45, [_h(0.12, 0.10, 170, -4, 300, 18, 6, 220, 2.6, 30)])
	m["fair"] = _m("Laser no ar", 0.45, [_h(0.10, 0.10, 160, 10, 300, 18, 5, 210, 2.4, 30)], {"air": true})
	m["dash"] = _m("Dash com propulsor", 0.5, [_v(0.0, 820, 0, {"keep_y": true}),
		_h(0.04, 0.30, 30, 0, 56, 46, 8, 300, 3.4, 38)])
	m["b_down"] = _m("Bloqueio de metal", 0.8, [_s(0.0, "guard", {"len": 0.8, "mult": 0.3, "kb": 0.3})])
	m["b_neutral"] = _m("Laser grande (atravessa a fase)", 1.1, [_h(0.5, 0.35, 1400, 0, 2800, 60, 16, 420, 4.5, 25, {"noscale": true})])
	m["b_side"] = _m("Míssil teleguiado", 0.7, [_pr(0.2, 30, -10, 380, -60, 14, 12, 340, 4.0, 40,
		{"life": 3.5, "homing": 170, "aoe": 50})])
	return _c("Tecnológico", "Lasers e mísseis teleguiados.", 1.15, 0.95, 0.95, 2, 1.0, Vector2(44, 66), m)


static func _capoeirista() -> Dictionary:
	var m := _std(1.0, 0.95, 1.1)
	m["jab"] = _m("Chute giratório", 0.35, [_h(0.06, 0.12, 0, 0, 86, 40, 4, 120, 1.2, 30)])
	m["ftilt"] = _m("Chute baixo girando", 0.45, [_h(0.12, 0.10, 48, 14, 66, 30, 8, 250, 3.0, 35)])
	m["utilt"] = _m("Chute alto girando", 0.45, [_h(0.12, 0.10, 14, -48, 74, 50, 8, 260, 3.0, 85)])
	m["dtilt"] = _m("Rasteira", 0.42, [_h(0.10, 0.10, 46, 26, 82, 20, 6, 170, 1.8, 70)])
	m["dash"] = _m("Giro + chute", 0.55, [_v(0.0, 520, 0, {"keep_y": true}),
		_h(0.05, 0.30, 34, 0, 64, 50, 9, 300, 3.2, 40)])
	m["b_down"] = _m("Esquiva girando", 0.5, [_s(0.0, "ghost", {"len": 0.35, "alpha": 0.5}),
		_v(0.0, 420, 0, {"keep_y": true}), _h(0.25, 0.1, 40, 0, 56, 44, 5, 220, 2.4, 40)])
	var steps: Array = []
	for i in 5:
		var last := i == 4
		steps.append(_h(0.1 + i * 0.2, 0.10, 0, 0, 100, 60, 5.0 if last else 3.0, 340.0 if last else 50.0,
			3.8 if last else 0.3, 40.0 if last else 20.0, {"pin": not last, "if_hit": i > 0}))
	m["b_neutral"] = _m("Furacão de chutes (5x)", 1.35, steps)
	m["b_side"] = _m("Chute giratório gigante", 0.9, [_h(0.30, 0.25, 56, 0, 112, 92, 16, 420, 4.6, 35)])
	return _c("Capoeirista", "Chutes giratórios e esquivas.", 0.95, 1.15, 1.05, 2, 1.0, Vector2(38, 62), m)


static func _trapper() -> Dictionary:
	var m := _std(0.9, 1.0, 1.0)
	m["jab"] = _m("Soco leve", 0.28, [_h(0.05, 0.07, 36, 0, 46, 36, 3, 110, 1.0, 25)])
	m["ftilt"] = _m("Bomba pequena", 0.5, [_pr(0.14, 28, -6, 380, -260, 14, 8, 260, 3.0, 50,
		{"grav": 900, "aoe": 62, "life": 2.5})])
	m["dtilt"] = _m("Espinho no chão", 0.5, [_pr(0.12, 72, 26, 0, 0, 18, 7, 220, 2.4, 80,
		{"mode": "spike", "life": 4.0})])
	m["utilt"] = _m("Armadilha de corda", 0.5, [_pr(0.12, 62, 26, 0, 0, 20, 2, 60, 0.2, 80,
		{"mode": "trap", "arm": 0.5, "life": 12.0, "root": 1.5})])
	m["b_up"] = _m("Recua + mina", 0.7, [_v(0.0, -260, -640),
		_pr(0.1, 0, 26, 0, 0, 16, 9, 300, 3.4, 80, {"mode": "mine", "arm": 0.6, "aoe": 70, "life": 25.0})])
	m["b_down"] = _m("Mina no chão", 0.5, [_pr(0.12, 40, 26, 0, 0, 16, 9, 300, 3.4, 80,
		{"mode": "mine", "arm": 0.6, "aoe": 70, "life": 25.0})])
	m["b_neutral"] = _m("Prisão (rival não anda 2s)", 0.8, [_s(0.2, "root_area", {"r": 460, "len": 2.0, "ring": 460})])
	var steps: Array = []
	for i in 3:
		steps.append(_pr(0.1 + i * 0.1, 40 + i * 70, 26, 0, 0, 16, 9, 300, 3.4, 80,
			{"mode": "mine", "arm": 0.6, "aoe": 70, "life": 25.0}))
	m["b_side"] = _m("3 minas de uma vez", 0.7, steps)
	return _c("Trapper", "Espalha minas e armadilhas.", 1.0, 1.0, 1.0, 2, 1.0, Vector2(40, 64), m)


static func _suporte() -> Dictionary:
	var m := _std(0.7, 1.0, 1.0)
	m["jab"] = _m("Soco leve", 0.28, [_h(0.05, 0.07, 36, 0, 46, 36, 3, 110, 1.0, 25)])
	m["ftilt"] = _m("Chute leve", 0.34, [_h(0.08, 0.08, 40, 8, 54, 34, 5, 190, 2.0, 35)])
	m["utilt"] = _m("Empurrão", 0.40, [_h(0.10, 0.10, 40, 0, 62, 54, 1, 360, 1.0, 15)])
	m["dtilt"] = _m("Buff: corre mais rápido", 0.45, [_s(0.1, "buff", {"len": 4.0, "speed": 1.4})])
	m["b_up"] = _m("Cura pequena", 0.7, [_v(0.0, 40, -640), _s(0.1, "heal", {"amount": 6})])
	m["b_down"] = _m("Escudo pequeno", 0.8, [_s(0.0, "barrier", {"len": 2.5, "hp": 15})])
	m["b_neutral"] = _m("Cura 20% + escudo", 1.0, [_s(0.2, "heal", {"amount": 20}),
		_s(0.2, "barrier", {"len": 3.0, "hp": 30})])
	m["b_side"] = _m("Cura em área (time)", 1.0, [_s(0.2, "heal", {"amount": 25}),
		_s(0.2, "buff", {"len": 3.0, "speed": 1.2}), _s(0.2, "area_heal", {"r": 420, "amount": 25, "ring": 420})])
	return _c("Suporte", "Cura, escudos e buffs.", 0.9, 1.05, 1.0, 2, 1.0, Vector2(38, 64), m)


static func _mimico() -> Dictionary:
	var m := _std(1.0, 1.0, 1.0)
	m["jab"] = _copy("Copia soco (A do rival)", "jab")
	m["ftilt"] = _copy("Copia chute (Lado+A do rival)", "ftilt")
	m["utilt"] = _copy("Copia golpe de cima", "utilt")
	m["dtilt"] = _copy("Copia golpe baixo", "dtilt")
	m["dash"] = _copy("Copia dash", "dash")
	m["nair"] = _copy("Copia golpe aéreo", "nair")
	m["fair"] = _copy("Copia pulo + ataque", "fair")
	m["bair"] = _copy("Copia golpe traseiro", "bair")
	m["uair"] = _copy("Copia golpe aéreo de cima", "uair")
	m["dair"] = _copy("Copia golpe aéreo de baixo", "dair")
	m["b_down"] = _copy("Copia defesa/habilidade", "b_down")
	m["b_up"] = _copy("Copia recuperação", "b_up")
	m["b_neutral"] = _copy("Rouba o especial do rival", "b_neutral")
	m["b_side"] = _m("Vira o rival por 5s", 0.6, [_s(0.2, "morph", {"len": 5.0, "range": 600})])
	return _c("Mímico", "Copia os golpes do rival mais próximo.", 1.0, 1.0, 1.0, 2, 1.0, Vector2(40, 64), m)


static func _assassino() -> Dictionary:
	var m := _std(1.0, 0.8, 0.85)
	m["jab"] = _m("Facada rápida", 0.26, [_h(0.05, 0.06, 34, 0, 44, 30, 4, 140, 1.6, 30)])
	m["ftilt"] = _m("Facada pelas costas", 0.38, [_h(0.10, 0.08, 38, 0, 48, 34, 6, 200, 2.4, 30, {"back_mult": 2.2})])
	m["utilt"] = _m("Soco silencioso", 0.36, [_h(0.10, 0.08, 0, -50, 54, 44, 5, 230, 2.6, 88)])
	m["dash"] = _m("Dash silencioso", 0.5, [_v(0.0, 720, 0, {"keep_y": true}),
		_h(0.05, 0.25, 30, 0, 50, 40, 7, 260, 3.0, 35, {"back_mult": 1.5})])
	m["fair"] = _m("Pulo + facada", 0.42, [_h(0.08, 0.12, 40, 0, 50, 40, 8, 270, 3.3, 40, {"back_mult": 1.4})], {"air": true})
	m["nair"] = _m("Ataque no ar", 0.40, [_h(0.06, 0.18, 0, 0, 70, 60, 6, 220, 2.6, 45)], {"air": true})
	m["b_neutral"] = _m("Golpe crítico (costas!)", 0.9, [_h(0.35, 0.12, 44, 0, 56, 44, 18, 420, 4.6, 35, {"back_mult": 2.4})])
	m["b_side"] = _m("Some 2s e dá 3 facadas", 2.0, [
		_s(0.0, "ghost", {"len": 1.2, "alpha": 0.12}),
		_s(1.2, "tele", {"behind": true, "range": 700}),
		_h(1.30, 0.08, 40, 0, 50, 40, 5, 50, 0.3, 20, {"pin": true}),
		_h(1.45, 0.08, 40, 0, 50, 40, 5, 50, 0.3, 20, {"pin": true, "if_hit": true}),
		_h(1.60, 0.10, 42, 0, 52, 42, 7, 340, 3.8, 38, {"if_hit": true})])
	return _c("Assassino", "Mortal pelas costas.", 0.85, 1.25, 1.1, 2, 1.0, Vector2(36, 62), m)


static func _duelista() -> Dictionary:
	var m := _std(1.0, 0.9, 1.0)
	m["jab"] = _m("Soco leve", 0.26, [_h(0.05, 0.07, 36, 0, 46, 36, 3, 110, 1.0, 25)])
	m["ftilt"] = _m("Soco médio", 0.36, [_h(0.09, 0.08, 40, 0, 52, 38, 6, 220, 2.6, 35)])
	m["dtilt"] = _m("Chute leve", 0.30, [_h(0.06, 0.07, 40, 18, 56, 28, 4, 150, 1.6, 30)])
	m["utilt"] = _m("Chute médio", 0.40, [_h(0.10, 0.09, 8, -50, 66, 48, 7, 250, 2.8, 85)])
	m["fair"] = _m("Combo soco + chute", 0.5, [
		_h(0.06, 0.07, 40, 0, 52, 40, 4, 60, 0.3, 20, {"pin": true}),
		_h(0.20, 0.09, 44, 4, 58, 44, 6, 280, 3.2, 40, {"if_hit": true})], {"air": true})
	m["bair"] = _m("Combo chute + soco", 0.5, [
		_h(0.06, 0.07, -40, 0, 52, 40, 4, 60, 0.3, 20, {"pin": true}),
		_h(0.20, 0.09, -44, 0, 58, 44, 6, 280, 3.2, 40, {"if_hit": true})], {"air": true})
	m["b_down"] = _m("Esquiva + soco", 0.6, [_s(0.0, "ghost", {"len": 0.25, "alpha": 0.5}),
		_v(0.0, -420, 0, {"keep_y": true}), _v(0.25, 560, 0, {"keep_y": true}),
		_h(0.28, 0.10, 40, 0, 54, 42, 8, 280, 3.2, 40)])
	var s6: Array = []
	for i in 6:
		var last := i == 5
		s6.append(_h(0.08 + i * 0.13, 0.07, 42, 0, 56, 42, 5.0 if last else 2.0,
			360.0 if last else 50.0, 4.0 if last else 0.3, 40.0 if last else 20.0,
			{"pin": not last, "if_hit": i > 0}))
	m["b_neutral"] = _m("Combo de 6 hits", 1.0, s6)
	var inf: Array = []
	for i in 10:
		var last := i == 9
		inf.append(_h(0.06 + i * 0.1, 0.07, 44, 0, 58, 44, 8.0 if last else 1.6,
			380.0 if last else 40.0, 4.0 if last else 0.2, 40.0 if last else 20.0,
			{"pin": not last, "if_hit": i > 0}))
	m["b_side"] = _m("Combo infinito (não deixa fugir)", 1.3, inf)
	return _c("Duelista", "Combos longos que prendem o rival.", 1.0, 1.1, 1.0, 2, 1.0, Vector2(40, 64), m)


# ---------------------------------------------------------------- especial único (botão Y)
## Cada personagem tem um golpe assinatura no botão Y: não gasta mana, mas tem recarga ("cd").

static func _u(label: String, dur: float, steps: Array, cd := 7.0, ex: Dictionary = {}) -> Dictionary:
	var d := {"label": label, "dur": dur, "steps": steps, "cost": 0, "cd": cd}
	d.merge(ex, true)
	return d


static func _sig(id: int) -> Dictionary:
	match id:
		0:  # Equilibrado
			return _u("COMBO FURIOSO", 1.1, [_v(0.0, 260, 0, {"keep_y": true}),
				_h(0.10, 0.08, 44, 0, 60, 46, 4, 120, 1.0, 30), _h(0.25, 0.08, 46, 0, 62, 46, 4, 130, 1.0, 30),
				_h(0.40, 0.08, 48, 0, 64, 46, 5, 150, 1.2, 35), _h(0.55, 0.08, 48, 0, 64, 46, 5, 160, 1.4, 40),
				_h(0.75, 0.12, 52, -4, 80, 56, 14, 380, 4.0, 40)])
		1:  # Velocista
			return _u("TORNADO VELOZ", 1.0, [_s(0.0, "ghost", {"len": 0.9, "alpha": 0.35}),
				_v(0.05, 800, 0, {"keep_y": true}), _h(0.05, 0.2, 40, 0, 90, 50, 6, 200, 2.0, 40),
				_v(0.30, -800, 0, {"keep_y": true}), _h(0.30, 0.2, 40, 0, 90, 50, 6, 200, 2.0, 140),
				_v(0.55, 800, 0, {"keep_y": true}), _h(0.55, 0.2, 40, 0, 90, 50, 10, 330, 3.4, 40),
				_s(0.80, "stopx")])
		2:  # Tanque
			return _u("ESMAGÃO", 1.0, [_v(0.0, 0, -420), _s(0.0, "armor", {"len": 0.9}),
				_s(0.55, "area", {"r": 360, "grounded": true, "dmg": 18, "base": 520, "scale": 4.2,
					"angle": 85, "ring": 360})], 9.0)
		3:  # Grappler
			return _u("SUPER AGARRÃO", 0.7, [_v(0.0, 520, 0, {"keep_y": true}),
				_g(0.05, 0.3, 40, 0, 90, 60, {"hold": 1.4, "mode": "choose"})], 8.0)
		4:  # Zoner
			return _u("CHUVA DE TIROS", 0.9, [
				_pr(0.10, 30, 0, 640, -160, 12, 5, 160, 1.6, 30, {"life": 1.3}),
				_pr(0.20, 30, 0, 640, -60, 12, 5, 160, 1.6, 30, {"life": 1.3}),
				_pr(0.30, 30, 0, 640, 0, 12, 5, 160, 1.6, 30, {"life": 1.3}),
				_pr(0.40, 30, 0, 640, 60, 12, 5, 160, 1.6, 30, {"life": 1.3}),
				_pr(0.50, 30, 0, 640, 160, 12, 5, 160, 1.6, 30, {"life": 1.3}),
				_pr(0.60, 30, 0, 700, 0, 22, 12, 340, 3.6, 35, {"life": 1.6})], 8.0)
		5:  # Espadachim
			return _u("CORTE GIRATÓRIO", 1.0, [_h(0.10, 0.10, 0, 0, 150, 70, 5, 160, 1.4, 45, {"radial": true}),
				_h(0.30, 0.10, 0, 0, 150, 70, 5, 170, 1.5, 45, {"radial": true}),
				_h(0.50, 0.10, 0, 0, 150, 70, 5, 180, 1.6, 45, {"radial": true}),
				_h(0.70, 0.14, 0, 0, 170, 80, 12, 380, 4.0, 50, {"radial": true})])
		6:  # Ninja
			return _u("SOMBRA LETAL", 1.1, [_s(0.0, "ghost", {"len": 0.35, "alpha": 0.15}),
				_s(0.25, "tele", {"behind": true, "range": 600}),
				_h(0.35, 0.08, 40, 0, 60, 46, 5, 150, 1.2, 30), _h(0.48, 0.08, 40, 0, 60, 46, 5, 160, 1.3, 30),
				_h(0.62, 0.12, 44, 0, 70, 50, 14, 400, 4.2, 38)], 8.0)
		7:  # Aéreo
			return _u("MERGULHO", 0.9, [_s(0.0, "armor", {"len": 0.7}), _v(0.0, 0, -480),
				_v(0.25, 260, 1000), _h(0.25, 0.35, 30, 30, 120, 110, 14, 400, 4.0, -70)], 8.0)
		8:  # Mago
			return _u("EXPLOSÃO ARCANA", 1.1, [_s(0.0, "barrier", {"len": 1.0, "hp": 20}),
				_s(0.45, "area", {"r": 300, "dmg": 14, "base": 420, "scale": 4.4, "angle": 50,
					"radial": true, "ring": 300}),
				_pr(0.55, 30, 0, 600, -200, 16, 8, 260, 3.0, 40, {"life": 1.4}),
				_pr(0.55, 30, 0, 600, 200, 16, 8, 260, 3.0, 40, {"life": 1.4})], 9.0)
		9:  # Tecnológico
			return _u("LASER TOTAL", 1.0, [_s(0.0, "armor", {"len": 0.8}),
				_pr(0.20, 30, 0, 1100, 0, 18, 6, 180, 1.4, 20, {"life": 1.0}),
				_pr(0.30, 30, 0, 1100, 0, 18, 6, 180, 1.4, 20, {"life": 1.0}),
				_pr(0.40, 30, 0, 1100, 0, 18, 6, 180, 1.4, 20, {"life": 1.0}),
				_pr(0.50, 30, 0, 1100, 0, 18, 6, 180, 1.4, 20, {"life": 1.0}),
				_pr(0.60, 30, 0, 1200, 0, 28, 14, 380, 4.0, 30, {"life": 1.0})], 8.0)
		10:  # Capoeirista
			return _u("GINGA INFERNAL", 1.1, [_h(0.10, 0.10, 55, 10, 150, 50, 4, 140, 1.2, 30),
				_h(0.25, 0.10, -55, 10, 150, 50, 4, 140, 1.2, 150), _h(0.40, 0.10, 55, 10, 150, 50, 4, 150, 1.3, 30),
				_h(0.55, 0.10, -55, 10, 150, 50, 4, 150, 1.3, 150),
				_h(0.72, 0.14, 0, -10, 240, 90, 13, 380, 4.0, 70)])
		11:  # Trapper
			return _u("PRISÃO TOTAL", 0.9, [_s(0.2, "root_area", {"r": 700, "len": 3.0, "ring": 700}),
				_s(0.2, "buff", {"len": 3.0, "speed": 1.3})], 10.0)
		12:  # Suporte
			return _u("BÊNÇÃO", 1.0, [_s(0.2, "heal", {"amount": 30}),
				_s(0.2, "barrier", {"len": 4.0, "hp": 40}), _s(0.2, "buff", {"len": 4.0, "speed": 1.3, "dmg": 1.4}),
				_s(0.2, "area_heal", {"r": 420, "amount": 0, "ring": 420})], 10.0)
		13:  # Mímico
			return _copy("COPIA O Y DO RIVAL", "ult")
		14:  # Assassino
			return _u("EXECUÇÃO", 1.2, [_s(0.0, "ghost", {"len": 0.5, "alpha": 0.12}),
				_s(0.4, "tele", {"behind": true, "range": 700}),
				_h(0.5, 0.08, 40, 0, 56, 46, 7, 200, 2.0, 35), _h(0.62, 0.08, 40, 0, 56, 46, 7, 200, 2.0, 35),
				_h(0.76, 0.12, 44, 0, 70, 50, 16, 420, 4.5, 38)], 9.0)
		15:  # Duelista
			return _u("ESTOCADA", 0.8, [_s(0.0, "armor", {"len": 0.5}), _v(0.12, 1000, 0, {"keep_y": true}),
				_h(0.12, 0.25, 50, 0, 90, 40, 15, 420, 4.4, 30), _s(0.40, "stopx")], 7.0)
	return {}
