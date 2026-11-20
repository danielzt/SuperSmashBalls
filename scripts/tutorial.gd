extends RefCounted
## Tutoriais guiados (básico e avançado). Usam o personagem Equilibrado.
## Cada passo tem uma condição que é verificada a cada frame.

const AIScript := preload("res://scripts/ai.gd")

const BASIC := [
	{"id": "move", "text": "Mova-se pelo palco: {mov}."},
	{"id": "jump", "text": "Pule: {jump}."},
	{"id": "djump", "text": "Pulo duplo: pule de novo enquanto estiver no ar ({jump})."},
	{"id": "attack", "text": "Ataque o boneco: chegue perto e aperte ATAQUE ({atk}).\nCada golpe gasta MANA (barra azul embaixo). Sem mana o golpe não sai; ela recarrega com o tempo."},
	{"id": "dir", "text": "Golpes direcionais: segure uma direção e aperte ATAQUE ({atk}).\nFaça os 3: LADO + ataque, {up} + ataque e {down} + ataque."},
	{"id": "special", "text": "Especiais: aperte ESPECIAL ({spc}) sozinho e depois com uma direção LATERAL + especial."},
	{"id": "shield", "text": "Escudo: segure ESCUDO ({shd}) por 1 segundo no chão. Ele protege dos golpes, mas gasta."},
	{"id": "grab", "text": "Agarrão: segure ESCUDO ({shd}) e aperte ATAQUE ({atk}) perto do boneco.\nDepois segure uma direção (frente, trás, cima ou baixo) para arremessar."},
	{"id": "ko", "text": "Porcentagem e KO: cada golpe aumenta o % do rival, e quanto maior, mais longe ele voa.\nO boneco está com 110%. Mande-o para fora da tela!"},
	{"id": "end", "text": "Tutorial básico concluído!\nAgora tente o AVANÇADO ou jogue no TREINO e no VERSUS."},
]

const ADVANCED := [
	{"id": "air", "text": "Golpes aéreos: no ar, use ATAQUE ({atk}) sem direção, para frente, para trás, para cima e para baixo.\nFaça pelo menos 4 diferentes."},
	{"id": "dash", "text": "Ataque correndo: corra ({mov}) e aperte ATAQUE ({atk}) sem parar de correr."},
	{"id": "fastfall", "text": "Queda rápida: pule e, no ar, segure BAIXO ({down}) enquanto cai."},
	{"id": "drop", "text": "Atravessar plataformas: suba numa plataforma flutuante e aperte BAIXO ({down}) para descer por ela."},
	{"id": "counter", "text": "Contra-ataque: o boneco agora ataca. Use BAIXO ({down}) + ESPECIAL ({spc}) na hora do golpe dele\n(Defesa + contra-ataque do Equilibrado)."},
	{"id": "charge", "text": "Golpe carregado: segure LADO + ESPECIAL ({spc}) e mantenha apertado por meio segundo antes de soltar.\n(Soco carregado: quanto mais segura, mais forte e mais empurra.)"},
	{"id": "combo", "text": "Combo: aperte ESPECIAL ({spc}) sozinho perto do boneco e acerte os 3 golpes seguidos."},
	{"id": "recover", "text": "Recuperação: você foi lançado para fora do palco!\nUse PULO ({jump}) e depois CIMA + ESPECIAL ({up} + {spc}) para voltar. Não caia!"},
	{"id": "end", "text": "Tutorial avançado concluído!\nExperimente os 16 personagens no TREINO e desafie a CPU no VERSUS."},
]

var f: Node
var d: Node
var kind := 1
var idx := 0
var flash := 0.0
var done := false
var snap: Dictionary = {}
var hints: Dictionary = {}
var moved := 0.0
var last_x := 0.0
var shield_t := 0.0
var setup_t := 0.0
var steps: Array = []


func setup(player: Node, dummy: Node, tutorial_kind: int, device_hints: Dictionary) -> void:
	f = player
	d = dummy
	kind = tutorial_kind
	hints = device_hints
	steps = BASIC if kind == 1 else ADVANCED
	last_x = f.global_position.x
	_begin()


func title() -> String:
	return "TUTORIAL %s  —  Passo %d/%d" % ["BÁSICO" if kind == 1 else "AVANÇADO", idx + 1, steps.size()]


func text() -> String:
	return String(steps[idx]["text"]).format(hints)


func skip() -> void:
	if not done and flash <= 0.0:
		flash = 0.01


func _begin() -> void:
	snap = {
		"used": f.used_slots.duplicate(), "jumps": f.jumps_used, "air": f.air_jumps,
		"dp": d.percent, "dko": d.ko_count, "ko": f.ko_count, "throws": f.throw_count,
		"counters": f.counter_count, "drops": f.plat_drops, "moved": moved,
	}
	shield_t = 0.0
	setup_t = 0.0
	f.max_charge = 0.0
	d.ai = null
	var id := String(steps[idx]["id"])
	match id:
		"ko":
			d.percent = 110.0
		"counter":
			d.ai = AIScript.new(d, 3)
		"combo":
			d.percent = 0.0
			d.combo_hits = 0
		"recover":
			_place_off_stage()
		"end":
			done = true


func _place_off_stage() -> void:
	f.global_position = Vector2(1040.0, 380.0)
	f.velocity = Vector2.ZERO
	f.jumps_left = 2
	f.was_on_floor = false
	f.up_b_used = false
	setup_t = 0.0


func _used_since(slot: String) -> bool:
	return int(f.used_slots.get(slot, 0)) > int((snap["used"] as Dictionary).get(slot, 0))


func update(delta: float) -> void:
	if done:
		return
	moved += absf(f.global_position.x - last_x)
	last_x = f.global_position.x
	if flash > 0.0:
		flash -= delta
		if flash <= 0.0:
			idx += 1
			_begin()
		return
	if _check(String(steps[idx]["id"]), delta):
		flash = 1.3


func _check(id: String, delta: float) -> bool:
	match id:
		"move":
			return moved - float(snap["moved"]) >= 300.0
		"jump":
			return f.jumps_used > int(snap["jumps"])
		"djump":
			return f.air_jumps > int(snap["air"])
		"attack":
			return d.percent > float(snap["dp"]) + 0.5
		"dir":
			return _used_since("ftilt") and _used_since("utilt") and _used_since("dtilt")
		"special":
			return _used_since("b_neutral") and _used_since("b_side")
		"shield":
			if f.shielding:
				shield_t += delta
			return shield_t >= 1.0
		"grab":
			return f.throw_count > int(snap["throws"])
		"ko":
			if d.percent < 100.0 and d.ko_count == int(snap["dko"]):
				d.percent = 110.0
			return d.ko_count > int(snap["dko"])
		"air":
			var n := 0
			for s in ["nair", "fair", "bair", "uair", "dair"]:
				if _used_since(s):
					n += 1
			return n >= 4
		"dash":
			return _used_since("dash")
		"fastfall":
			return f.fast_falling and f.velocity.y > 950.0
		"drop":
			return f.plat_drops > int(snap["drops"])
		"counter":
			return f.counter_count > int(snap["counters"])
		"charge":
			return f.max_charge >= 0.5
		"combo":
			return d.combo_hits >= 3
		"recover":
			setup_t += delta
			if f.ko_count > int(snap["ko"]):
				snap["ko"] = f.ko_count
				setup_t = -1.5
				_place_off_stage()
				return false
			return setup_t > 0.6 and f.is_on_floor() and f.global_position.x > 345.0 \
				and f.global_position.x < 935.0
	return false
