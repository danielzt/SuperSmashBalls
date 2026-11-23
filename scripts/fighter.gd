extends CharacterBody2D
## Lutador estilo Smash. Executa os golpes descritos em characters.gd.

const Chars := preload("res://scripts/characters.gd")
const ProjScript := preload("res://scripts/projectile.gd")
const AIScript := preload("res://scripts/ai.gd")
const ItemsScript := preload("res://scripts/items.gd")
const Art := preload("res://scripts/art.gd")

## Multiplicador global do dano em % (menor = porcentagem sobe mais devagar)
const DMG_SCALE := 0.6
const GRAVITY := 1800.0
const FALL_MAX := 800.0
const FAST_FALL := 1300.0
const RUN_SPEED := 380.0
const AIR_SPEED := 340.0
const GROUND_ACCEL := 3200.0
const AIR_ACCEL := 1800.0
const GROUND_FRICTION := 2800.0
const AIR_DRAG := 350.0
const JUMP_VEL := -640.0
const DJUMP_VEL := -580.0
const BLAST := Rect2(-250, -300, 1780, 1300)
const SPAWN := Vector2(640, 100)
const START_STOCKS := 3
const HB := 0.65  # escala das caixas de golpe (o corpo é um cubo de metade da altura original)
const MAX_MANA := 100.0
const MANA_REGEN := 14.0  # por segundo (metade enquanto está golpeando)

signal move_used(fighter: Node, text: String)

var pid := 1
var prefix := ""          # dispositivo ("kb1", "j0"...). "" = boneco sem controle
var char_id := 0
var color := Color.WHITE  # cor do jogador
var cdata: Dictionary = {}
var body := Vector2(40, 64)
var infinite := false     # treino: vidas infinitas

var percent := 0.0
var stocks := START_STOCKS
var eliminated := false

var facing := 1
var jumps_left := 2
var was_on_floor := false
var up_b_used := false

# temporizadores / estados
var hitstun := 0.0
var stun := 0.0
var lag_t := 0.0
var invincible := 0.0
var hit_flash := 0.0
var drop_t := 0.0
var respawn_t := 0.0
var slow_t := 0.0
var root_t := 0.0
var ghost_t := 0.0
var ghost_alpha := 0.35
var armor_t := 0.0
var guard_t := 0.0
var guard_mult := 1.0
var guard_kb := 1.0
var guard_counter: Dictionary = {}
var barrier_t := 0.0
var barrier_hp := 0.0
var fly_t := 0.0
var buff_dmg_t := 0.0
var buff_dmg_v := 1.0
var buff_spd_t := 0.0
var buff_spd_v := 1.0
var morph_t := 0.0
var morph_char := -1
var pin_t := 0.0
var pin_owner: Node = null
var shield_hp := 100.0
var shielding := false

# golpe atual
var cur_move: Dictionary = {}
var cur_slot := ""
var attack_t := 0.0
var attack_btn := "attack"
var fired: Array = []
var active_hits: Array = []
var hit_connected := false
var charge_t := 0.0
var charge_done := false

# agarrão
var grab_v: Node = null
var grab_step: Dictionary = {}
var grab_t := 0.0
var pummel_t := 0.0
var grabbed_by: Node = null

# treino
var last_hit_dmg := 0.0
var combo_hits := 0
var combo_dmg := 0.0
var combo_timer := 0.0

var fx: Array = []

# animação (só visual)
var anim_t := 0.0
var squash := 0.0
var squash_v := 0.0
var spin := 0.0
var hands: Array = [Vector2(20, 0), Vector2(-20, 0)]
var hand_sc: Array = [1.0, 1.0]
var hand_punch: Array = [false, false]
var hand_hist: Array = [[], []]
var dust_t := 0.0
var floor_vis := false

# IA e contadores (usados pela IA e pelos tutoriais)
var ai = null             # controlador de IA (ai.gd) ou null
var used_slots: Dictionary = {}
var jumps_used := 0
var air_jumps := 0
var plat_drops := 0
var fast_falling := false
var ff_snd := false       # som de queda rápida já tocado nesta queda
var step_t := 0.0         # tempo até o próximo som de passo
var throw_count := 0
var counter_count := 0
var ko_count := 0
var max_charge := 0.0
var hits_landed := 0       # conquistas: golpes que acertou em rivais
var dmg_dealt := 0.0
var sd_count := 0          # quedas sem ninguém ter acertado antes (sozinho)

# mana
var mana := MAX_MANA
var no_mana_t := 0.0
var no_mana_cd := 0.0
var ult_cd := 0.0          # recarga do especial único (botão Y)
var ult_max := 8.0
var pose := 0               # 0 normal, 1 vencedor (feliz), 2 derrotado (triste)
var gaze := Vector2.ZERO    # para onde os olhos olham (rival mais próximo)
var hop_cd := 0.0
var lean := 0.0             # inclinação do corpo (mola)
var lean_v := 0.0
var trail: Array = []       # rastro de posições quando está muito rápido
var trail_t := 0.0
var spawn_pop := 0.0        # "pop" elástico ao voltar do KO
var land_t := 0.0           # mãos abrem ao pousar
var teeter := false         # parado na beirada, se equilibrando

var expr := 0               # expressão do momento (humor desenhado no rosto)
var expr_t := 0.0
var flip_t := 0.0           # cambalhota do pulo duplo
var turn_t := 0.0           # "virada" ao trocar de lado
var last_facing := 1
var fall_flag := false

## Cada acontecimento sorteia 1 de até 3 expressões (ids de humor de Art.blob):
## 1 machucado, 2 grito, 3 tonto, 4 feliz, 5 decidido, 6 triste, 7 assustado,
## 8 surpreso, 9 convencido, 10 empolgado, 11 bravo.
const EXPRS := {
	"hit": [1, 8, 7],
	"attack": [2, 11, 10],
	"ult": [11, 10, 9],
	"block": [5, 9, 8],
	"ko": [4, 9, 10],
	"respawn": [8, 4, 9],
	"fall": [7, 8, 1],
	"win": [4, 10, 9],
	"lose": [6, 3, 7],
}


## Chance de NÃO mudar de cara em cada acontecimento (a vitória/derrota sempre mudam).
const NO_EXPR := {"hit": 0.25, "attack": 0.45, "ult": 0.1, "block": 0.3, "ko": 0.1, "respawn": 0.3, "fall": 0.15}


var atk_lock := false   # segurando o golpe: mantém a mesma expressão até soltar


func _express(ev: String, dur: float) -> void:
	if ev == "attack":
		if atk_lock:   # golpes em sequência segurando o botão: não sorteia de novo
			if expr_t > 0.0:
				expr_t = maxf(expr_t, dur)
			return
		atk_lock = true
	var opts: Array = EXPRS.get(ev, [])
	if opts.is_empty():
		return
	if randf() < float(NO_EXPR.get(ev, 0.0)):
		expr_t = 0.0
		return   # desta vez, cara normal
	expr = int(opts[randi() % opts.size()])
	expr_t = dur
var jump_mult := 1.0
var kb_taken := 1.0         # multiplicador do empurrão que recebe
var atk_speed := 1.0        # velocidade dos golpes
var respawn_time := 1.5
var respawn_inv := 2.5
var regen_mult := 1.0       # regeneração de mana
var ult_rate := 1.0         # velocidade de recarga do Y

# --- modos de jogo / mutadores (ligados pelo main.gd)
var max_mana := MAX_MANA
var dmg_taken := 1.0        # Dano Dobrado
var push_only := false      # Empurra-Empurra: todo golpe vira empurrão
var swap_ctl := false       # Controles Trocados: direções <-> botões
var invis_mode := false     # Invisível: parado = invisível
var still_t := 0.0
var wind_force := 0.0       # Vento (aceleração horizontal)
var run_mult := 1.0         # Corrida
var kos := 0                # Caça aos KOs: pontos
var last_attacker: Node = null
var last_attacker_t := 99.0
var held_item := ""        # item agarrável na mão (items.gd)
var power_orb := false     # Orbe de Poder usado: aura + próximo Y é o golpe supremo
var atk_block := false     # após pegar/usar item, segurar ataque não golpeia


func setup(p_pid: int, p_prefix: String, p_char: int, p_color: Color) -> void:
	pid = p_pid
	prefix = p_prefix
	char_id = p_char
	color = p_color
	cdata = Chars.all()[p_char]
	var side: float = (cdata["size"] as Vector2).y * 0.5  # cubo, metade da altura original
	body = Vector2(side, side)
	jumps_left = int(cdata["jumps"])


## Posição e tamanho de uma caixa de golpe, já na escala do corpo menor.
func hb_off(s: Dictionary) -> Vector2:
	return (s["off"] as Vector2) * (1.0 if s.get("noscale", false) else HB)


func hb_size(s: Dictionary) -> Vector2:
	return (s["size"] as Vector2) * (1.0 if s.get("noscale", false) else HB)


func cost_of(slot: String) -> float:
	var m: Dictionary = _moves().get(slot, {})
	return float(m.get("cost", Chars.MANA_COST.get(slot, 10)))


func _announce(m: Dictionary, label_suffix := "") -> void:
	var verb := "usou"
	for s in m["steps"]:
		var t := String(s["type"])
		if t == "hit" or t == "proj" or t == "area" or t == "grab":
			verb = "deu"
			break
	move_used.emit(self, "%s %s%s" % [verb, String(m["label"]).split(" (")[0], label_suffix])


func _ready() -> void:
	add_to_group("fighters")
	process_mode = Node.PROCESS_MODE_PAUSABLE   # para no menu de pausa
	collision_layer = 2     # camada 2: lutadores
	collision_mask = 1 | 4  # colide com o chão (1) e plataformas (3)
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = body
	cs.shape = rs
	add_child(cs)
	invincible = 1.2


# ---------------------------------------------------------------- utilidades

func body_rect() -> Rect2:
	return Rect2(global_position - body / 2.0, body)


func dmg_mult() -> float:
	return buff_dmg_v if buff_dmg_t > 0.0 else 1.0


func speed_mult() -> float:
	var s := float(cdata["speed"]) * run_mult
	if buff_spd_t > 0.0:
		s *= buff_spd_v
	if slow_t > 0.0:
		s *= 0.5
	return s


func setup_ai(level: int) -> void:
	ai = AIScript.new(self, level)


var input_locked := false   # partida acabou: sem controle
var mute_until := 0          # ignora o controle até este quadro (ex.: logo depois de sair da pausa)
var god_mode := false       # trapaça "jogadores invencíveis": golpes não pegam

## Controles Trocados: direções do analógico <-> botões da direita (esq=ataque, dir=especial, cima=Y, baixo=pulo).
const SWAP_MAP := {"left": "attack", "attack": "left", "right": "special", "special": "right",
	"up": "ult", "ult": "up", "down": "jump", "jump": "down"}


func _rm(a: String) -> String:
	return SWAP_MAP.get(a, a) if swap_ctl else a


func _held(a: String) -> bool:
	if input_locked or Engine.get_physics_frames() < mute_until:
		return false
	if ai != null:
		return ai.held.get(a, false)
	return prefix != "" and Input.is_action_pressed(prefix + "_" + _rm(a))


func _just(a: String) -> bool:
	if input_locked or Engine.get_physics_frames() < mute_until:
		return false
	if ai != null:
		return ai.just.get(a, false)
	return prefix != "" and Input.is_action_just_pressed(prefix + "_" + _rm(a))


func _axis_x() -> float:
	if input_locked or Engine.get_physics_frames() < mute_until:
		return 0.0
	if ai != null:
		return (1.0 if ai.held.get("right", false) else 0.0) - (1.0 if ai.held.get("left", false) else 0.0)
	if prefix == "":
		return 0.0
	return Input.get_axis(prefix + "_" + _rm("left"), prefix + "_" + _rm("right"))


func _moves() -> Dictionary:
	if morph_t > 0.0 and morph_char >= 0:
		return Chars.all()[morph_char]["moves"]
	return cdata["moves"]


func _nearest_enemy(max_d := 1e9) -> Node:
	var best: Node = null
	var bd := max_d
	for f in get_tree().get_nodes_in_group("fighters"):
		if f == self or f.eliminated or f.respawn_t > 0.0:
			continue
		var d := global_position.distance_to(f.global_position)
		if d < bd:
			bd = d
			best = f
	return best


func _resolve(slot: String) -> Dictionary:
	var m: Dictionary = _moves().get(slot, {})
	if m.has("copy"):
		var e := _nearest_enemy()
		if e != null:
			var em: Dictionary = e._moves().get(m["copy"], {})
			if not em.is_empty() and not em.has("copy"):
				return em
		var fb: Dictionary = Chars.all()[0]["moves"].get(m["copy"], {})
		return fb
	return m


func _dir_to(f: Node) -> int:
	if f.global_position.x > global_position.x + 3.0:
		return 1
	if f.global_position.x < global_position.x - 3.0:
		return -1
	return facing


func reset_state() -> void:
	percent = 0.0
	hitstun = 0.0
	stun = 0.0
	lag_t = 0.0
	slow_t = 0.0
	root_t = 0.0
	ghost_t = 0.0
	armor_t = 0.0
	guard_t = 0.0
	barrier_t = 0.0
	fly_t = 0.0
	buff_dmg_t = 0.0
	buff_spd_t = 0.0
	morph_t = 0.0
	held_item = ""
	power_orb = false
	pin_t = 0.0
	shield_hp = 100.0
	mana = max_mana
	combo_hits = 0
	combo_dmg = 0.0
	last_hit_dmg = 0.0
	_cancel_attack()
	velocity = Vector2.ZERO


# ---------------------------------------------------------------- física

func _tick_timers(delta: float) -> void:
	invincible = maxf(invincible - delta, 0.0)
	hit_flash = maxf(hit_flash - delta, 0.0)
	hitstun = maxf(hitstun - delta, 0.0)
	stun = maxf(stun - delta, 0.0)
	lag_t = maxf(lag_t - delta, 0.0)
	drop_t = maxf(drop_t - delta, 0.0)
	slow_t = maxf(slow_t - delta, 0.0)
	root_t = maxf(root_t - delta, 0.0)
	ghost_t = maxf(ghost_t - delta, 0.0)
	armor_t = maxf(armor_t - delta, 0.0)
	guard_t = maxf(guard_t - delta, 0.0)
	barrier_t = maxf(barrier_t - delta, 0.0)
	fly_t = maxf(fly_t - delta, 0.0)
	buff_dmg_t = maxf(buff_dmg_t - delta, 0.0)
	buff_spd_t = maxf(buff_spd_t - delta, 0.0)
	morph_t = maxf(morph_t - delta, 0.0)
	pin_t = maxf(pin_t - delta, 0.0)
	no_mana_t = maxf(no_mana_t - delta, 0.0)
	no_mana_cd = maxf(no_mana_cd - delta, 0.0)
	var ult_was := ult_cd
	ult_cd = maxf(ult_cd - delta * ult_rate, 0.0)
	if ult_was > 0.0 and ult_cd <= 0.0 and ai == null and prefix != "":
		Sfx.play("ult_pronto", 0.7)   # especial Y disponível de novo (só para humanos)
	last_attacker_t += delta
	var regen := MANA_REGEN * regen_mult * (2.0 if infinite else 1.0) * (0.5 if not cur_move.is_empty() else 1.0)
	mana = minf(mana + regen * delta, max_mana)
	combo_timer = maxf(combo_timer - delta, 0.0)
	if combo_timer <= 0.0:
		combo_hits = 0
		combo_dmg = 0.0
	if guard_t <= 0.0:
		guard_counter = {}
	for e in fx:
		e["t"] = float(e["t"]) + delta
	fx = fx.filter(func(e): return float(e["t"]) < float(e["max"]))


func _physics_process(delta: float) -> void:
	if eliminated:
		return
	if respawn_t > 0.0:
		respawn_t -= delta
		if respawn_t <= 0.0:
			_respawn()
		return

	_tick_timers(delta)
	if ai != null:
		ai.update(delta)

	# Preso num agarrão: o agarrador move este lutador.
	if grabbed_by != null:
		if not is_instance_valid(grabbed_by) or grabbed_by.grab_v != self:
			grabbed_by = null
		else:
			velocity = Vector2.ZERO
			return
	# Preso por um combo: segue o atacante.
	if pin_t > 0.0 and pin_owner != null and is_instance_valid(pin_owner):
		var o: Node = pin_owner
		var tgt: Vector2 = o.global_position + Vector2(o.facing * (o.body.x / 2.0 + body.x / 2.0 + 6.0), 0.0)
		global_position = global_position.lerp(tgt, 0.55)
		velocity = Vector2.ZERO
		return

	set_collision_mask_value(3, drop_t <= 0.0)

	var on_floor := is_on_floor()
	var jumps_total := int(cdata["jumps"])
	if on_floor:
		jumps_left = jumps_total
		up_b_used = false
	elif was_on_floor:
		jumps_left = mini(jumps_left, jumps_total - 1)
	was_on_floor = on_floor
	fast_falling = false

	var can_act := hitstun <= 0.0 and stun <= 0.0 and lag_t <= 0.0 and grab_v == null
	var dir := 0.0
	var want_down := false
	var want_up := false
	if can_act and root_t <= 0.0:
		dir = _axis_x()
	if can_act:
		want_down = _held("down")
		want_up = _held("up")

	var attacking := not cur_move.is_empty()

	# Escudo
	var was_shielding := shielding
	shielding = can_act and on_floor and not attacking and shield_hp > 0.0 and _held("shield")
	if shielding and not was_shielding:
		Sfx.play("escudo_on", 0.8)
	if shielding:
		shield_hp = maxf(shield_hp - 22.0 * delta, 0.0)
		if shield_hp <= 0.0:
			_break_shield()
	else:
		shield_hp = minf(shield_hp + 14.0 * delta, 100.0)

	# Golpes leves podem ser repetidos em sequência rápida (apertar ataque várias vezes)
	if not _held("attack"):
		atk_block = false
	if can_act and attacking and grab_v == null and not atk_block and (_just("attack") or _held("attack")) and _can_rapid_cancel():
		_cancel_attack()
		_begin_slot(_pick_attack_slot(on_floor, dir, want_up, want_down))
		attacking = not cur_move.is_empty()

	# Entradas de ação
	if can_act and not attacking:
		if _try_item():
			atk_block = true
		elif _just("attack") or (_held("attack") and not atk_block):
			_begin_slot(_pick_attack_slot(on_floor, dir, want_up, want_down))
		elif _just("ult") and (ult_cd <= 0.0 or power_orb):
			_begin_slot("super" if power_orb else "ult")
		elif _just("special"):
			_begin_slot(_pick_special_slot(dir, want_up, want_down))
		elif not shielding and _just("jump") and jumps_left > 0 and root_t <= 0.0:
			velocity.y = (JUMP_VEL if on_floor else DJUMP_VEL) * float(cdata["jump"]) * jump_mult
			jumps_left -= 1
			jumps_used += 1
			Sfx.play("pulo" if on_floor else "pulo_duplo", 0.8)
			squash = -0.3
			squash_v = 0.0
			_fx_dust(5 if on_floor else 3)
			if not on_floor:
				flip_t = 0.4   # cambalhota no pulo duplo
			if not on_floor:
				air_jumps += 1
		if on_floor and _just("down") and not shielding:
			drop_t = 0.22  # atravessa plataforma por baixo
			if global_position.y < 450.0:
				plat_drops += 1
	attacking = not cur_move.is_empty()

	# Voo (Aéreo): controla o corpo livremente
	if fly_t > 0.0 and hitstun <= 0.0:
		var vy := 0.0
		if want_up:
			vy = -1.0
		elif want_down:
			vy = 1.0
		velocity = velocity.lerp(Vector2(dir, vy) * 330.0, minf(8.0 * delta, 1.0))
		if dir != 0.0 and not attacking:
			facing = 1 if dir > 0.0 else -1
	else:
		# Gravidade e queda rápida
		if not on_floor:
			fast_falling = want_down and velocity.y > 0.0
			if fast_falling and not ff_snd:
				Sfx.play("queda", 0.6)
			ff_snd = fast_falling
			var cap := FAST_FALL if fast_falling else FALL_MAX * float(cdata["fall"])
			if velocity.y < cap:
				velocity.y = minf(velocity.y + GRAVITY * Art.grav * float(cdata["fall"]) * delta, cap)
		# Movimento horizontal
		var spd := speed_mult()
		if hitstun > 0.0:
			if on_floor:
				velocity.x = move_toward(velocity.x, 0.0, GROUND_FRICTION * Art.fric * 0.5 * delta)
		elif stun > 0.0 or shielding or lag_t > 0.0 or (attacking and on_floor):
			var f := GROUND_FRICTION * Art.fric * (0.35 if attacking else 1.0) if on_floor else AIR_DRAG
			velocity.x = move_toward(velocity.x, 0.0, f * delta)
		elif grab_v != null:
			velocity.x = 0.0
		else:
			var target := dir * (RUN_SPEED if on_floor else AIR_SPEED) * spd
			var accel := AIR_ACCEL if not on_floor else GROUND_ACCEL * Art.fric
			if dir == 0.0:
				accel = GROUND_FRICTION * Art.fric if on_floor else AIR_DRAG
			velocity.x = move_toward(velocity.x, target, accel * delta)
			if dir != 0.0 and not attacking:
				facing = 1 if dir > 0.0 else -1

	if grab_v != null:
		velocity = Vector2.ZERO

	var vy_before := velocity.y
	if wind_force != 0.0 and grab_v == null and grabbed_by == null:
		velocity.x += wind_force * delta
		if is_on_floor():
			move_and_collide(Vector2(wind_force * 0.12 * delta, 0.0))   # empurra também quem está parado no chão
	if invis_mode:
		still_t = still_t + delta if (absf(velocity.x) < 25.0 and cur_move.is_empty() and hitstun <= 0.0) else 0.0
	move_and_slide()
	on_floor = is_on_floor()
	if on_floor and not floor_vis and vy_before > 250.0:
		squash = clampf(vy_before / 2200.0, 0.12, 0.35)
		land_t = 0.18
		squash_v = 0.0
		ff_snd = false
		Sfx.play("pouso", clampf(vy_before / 1500.0, 0.3, 1.0))
		_fx_dust(6)
	floor_vis = on_floor
	# passos ao correr no chão
	if on_floor and absf(velocity.x) > 220.0 and cur_move.is_empty() and hitstun <= 0.0:
		step_t -= delta
		if step_t <= 0.0:
			step_t = 0.26
			Sfx.play("passo", 0.18)
	else:
		step_t = 0.0

	if not cur_move.is_empty():
		_update_attack(delta, on_floor)

	if not BLAST.has_point(global_position):
		_ko()


# ---------------------------------------------------------------- golpes

func _pick_attack_slot(on_floor: bool, dir: float, up: bool, down: bool) -> String:
	var side := absf(dir) > 0.5
	if on_floor:
		if _held("shield"):
			return "grab"
		if side and (1 if dir > 0.0 else -1) == facing and absf(velocity.x) > RUN_SPEED * speed_mult() * 0.85:
			return "dash"
		if up:
			return "utilt"
		if down:
			return "dtilt"
		if side:
			facing = 1 if dir > 0.0 else -1
			return "ftilt"
		return "jab"
	if up:
		return "uair"
	if down:
		return "dair"
	if side:
		return "fair" if (1 if dir > 0.0 else -1) == facing else "bair"
	return "nair"


func _pick_special_slot(dir: float, up: bool, down: bool) -> String:
	if up:
		return "b_up"
	if down:
		return "b_down"
	if absf(dir) > 0.5:
		facing = 1 if dir > 0.0 else -1
		return "b_side"
	return "b_neutral"


func _begin_slot(slot: String) -> void:
	var m := ItemsScript.super_move() if slot == "super" else _resolve(slot)
	if push_only:
		m = Chars._m("Empurrão", 0.28, [Chars._h(0.05, 0.10, 34, 0, 76, 58, 1.5, 300, 3.2, 20)])
	if m.is_empty():
		return
	var cost := 0.0 if (push_only or slot == "super") else cost_of(slot)
	if mana < cost:
		no_mana_t = 0.5
		if no_mana_cd <= 0.0:
			no_mana_cd = 0.9
			move_used.emit(self, "sem mana!")
			if prefix != "":
				Sfx.play("mana_vazia")
		return
	if slot == "b_up" and not is_on_floor():
		if up_b_used:
			return
		up_b_used = true
	mana -= cost
	if slot == "ult":
		ult_max = float(m.get("cd", 8.0))
		ult_cd = ult_max
	if slot == "super":
		power_orb = false
		fx.append({"pos": global_position, "r": 260.0, "t": 0.0, "max": 0.7, "col": Color("8fdcff")})
	_start(m, slot)
	if slot == "dash":
		Sfx.play("dash", 0.7)
	used_slots[slot] = int(used_slots.get(slot, 0)) + 1
	_announce(m, " (copiado)" if (_moves().get(slot, {}) as Dictionary).has("copy") else "")


func _start(m: Dictionary, slot: String) -> void:
	cur_move = m
	cur_slot = slot
	attack_t = 0.0
	_express("ult" if slot in ["ult", "super"] else "attack", 0.6)
	fired.clear()
	for i in (m["steps"] as Array).size():
		fired.append(false)
	active_hits.clear()
	hit_connected = false
	charge_t = 0.0
	charge_done = false
	attack_btn = "special" if slot.begins_with("b_") else ("ult" if slot in ["ult", "super"] else "attack")
	# som do golpe saindo (o impacto tem som próprio em take_hit)
	if slot == "ult" or slot == "super":
		Sfx.play("ult")
	elif slot.begins_with("b_"):
		Sfx.play("especial", 0.55)
	elif slot == "jab" or slot == "nair":
		Sfx.play("golpe_ar", 0.5)
	elif slot != "" and slot != "grab" and slot != "dash":
		Sfx.play("golpe_ar_forte", 0.5)


const RAPID_SLOTS := ["jab", "ftilt", "utilt", "dtilt", "nair", "fair", "bair", "uair", "dair"]


# Golpe leve que já "saiu" (primeiro hit disparado) pode ser cancelado por outro ataque.
func _can_rapid_cancel() -> bool:
	if not RAPID_SLOTS.has(cur_slot) or cur_move.has("charge"):
		return false
	var first_hit := INF
	for s in (cur_move["steps"] as Array):
		if String(s["type"]) in ["hit", "proj"]:
			first_hit = minf(first_hit, float(s["t"]))
	if first_hit == INF:
		return false
	return attack_t >= first_hit + 0.02


func _cancel_attack() -> void:
	cur_move = {}
	active_hits.clear()
	_release_grab()


func _end_move(lag := 0.0) -> void:
	cur_move = {}
	active_hits.clear()
	lag_t = lag


func _update_attack(delta: float, on_floor: bool) -> void:
	var m := cur_move
	if grab_v != null:
		_update_grab(delta)
		return
	if m.has("charge") and not charge_done:
		var c: Dictionary = m["charge"]
		if attack_t >= float(c["at"]):
			if _held(attack_btn) and charge_t < float(c["max"]):
				charge_t += delta
				max_charge = maxf(max_charge, charge_t)
				return
			charge_done = true
	attack_t += delta * atk_speed
	var steps: Array = m["steps"]
	for i in steps.size():
		if fired[i] or attack_t < float(steps[i]["t"]):
			continue
		fired[i] = true
		_fire(steps[i])
		if cur_move.is_empty():
			return
	_run_active()
	if cur_move.is_empty():
		return
	if grab_v != null:
		return
	if attack_t >= float(m["dur"]):
		_end_move()
	elif m.get("air", false) and on_floor and attack_t > 0.06:
		_end_move(0.1)
	elif m.get("land_end", false) and on_floor and attack_t > 0.3:
		_end_move(0.15)


func _fire(s: Dictionary) -> void:
	match String(s["type"]):
		"hit", "grab":
			if s.get("if_hit", false) and not hit_connected:
				attack_t = maxf(attack_t, float(cur_move["dur"]) - 0.12)
				return
			active_hits.append({"s": s, "end": float(s["t"]) + float(s["len"]), "done": []})
			if String(s["type"]) == "hit":
				var hp := global_position + Vector2(hb_off(s).x * facing, hb_off(s).y)
				get_tree().call_group("fxlayer", "swing_fx", hp, Vector2(facing, 0.0), cdata["color"],
					maxf(hb_size(s).x, hb_size(s).y))
		"vel":
			var vx := float(s["vx"]) * facing
			if s.get("keep_y", false):
				velocity.x = vx
			elif s.get("keep_x", false):
				velocity.y = float(s["vy"])
			else:
				velocity = Vector2(vx, float(s["vy"]))
		"stopx":
			velocity.x = 0.0
		"proj":
			_spawn_proj(s)
		"tele":
			_do_tele(s)
		"ghost":
			ghost_t = float(s["len"])
			ghost_alpha = float(s.get("alpha", 0.35))
		"armor":
			armor_t = float(s["len"])
		"guard":
			guard_t = float(s["len"])
			guard_mult = float(s.get("mult", 0.0))
			guard_kb = float(s.get("kb", 0.5))
			guard_counter = s.get("counter", {})
		"barrier":
			barrier_t = float(s["len"])
			barrier_hp = float(s["hp"])
		"heal":
			percent = maxf(percent - float(s["amount"]), 0.0)
			Sfx.play("cura")
		"area_heal":
			Sfx.play("cura")
			# Sem times no modo todos-contra-todos: só cura quem for do mesmo jogador (você).
			fx.append({"pos": global_position, "r": float(s.get("ring", 100)), "t": 0.0, "max": 0.4,
				"col": Color(0.4, 1.0, 0.5)})
		"buff":
			Sfx.play("buff")
			if s.has("dmg"):
				buff_dmg_t = float(s["len"])
				buff_dmg_v = float(s["dmg"])
			if s.has("speed"):
				buff_spd_t = float(s["len"])
				buff_spd_v = float(s["speed"])
		"fly":
			fly_t = float(s["len"])
			velocity.y = minf(velocity.y, -150.0)
		"area":
			_do_area(s)
		"root_area":
			for f in get_tree().get_nodes_in_group("fighters"):
				if f != self and not f.eliminated and f.respawn_t <= 0.0 \
						and f.global_position.distance_to(global_position) <= float(s["r"]):
					f.root_t = float(s["len"])
			fx.append({"pos": global_position, "r": float(s.get("ring", 200)), "t": 0.0, "max": 0.4,
				"col": Color(0.8, 0.6, 0.3)})
		"morph":
			var e := _nearest_enemy(float(s.get("range", 600)))
			if e != null:
				morph_char = e.char_id
				morph_t = float(s["len"])


func _run_active() -> void:
	var fighters := get_tree().get_nodes_in_group("fighters")
	for a in active_hits.duplicate():
		if attack_t > float(a["end"]):
			active_hits.erase(a)
			continue
		var s: Dictionary = a["s"]
		var off: Vector2 = hb_off(s)
		var size: Vector2 = hb_size(s)
		var rect := Rect2(global_position + Vector2(off.x * facing, off.y) - size / 2.0, size)
		for f in fighters:
			if f == self or (a["done"] as Array).has(f):
				continue
			if not rect.intersects(f.body_rect()):
				continue
			if s["type"] == "grab":
				if f.can_be_grabbed():
					_begin_grab(f, s)
					active_hits.clear()
					return
				continue
			var hd: Dictionary = s.duplicate()
			if s.get("charged", false) and cur_move.has("charge"):
				var cm := 1.0 + 1.5 * charge_t / float(cur_move["charge"]["max"])
				hd["dmg"] = float(hd["dmg"]) * cm
				hd["base"] = float(hd["base"]) * cm
			if f.take_hit(hd, _dir_to(f), self):
				(a["done"] as Array).append(f)
				hit_connected = true


func _spawn_proj(s: Dictionary) -> void:
	var p := ProjScript.new()
	p.owner_f = self
	var po: Vector2 = hb_off(s)
	var pos := global_position + Vector2(po.x * facing, po.y)
	var v: Vector2 = s["vel"]
	var vel := Vector2(v.x * facing, v.y)
	if s.get("sky_target", false):
		var e := _nearest_enemy()
		pos = Vector2(e.global_position.x if e != null else global_position.x + 200.0 * facing, -60.0)
		vel = Vector2(0.0, v.y)
	p.position = pos
	p.vel = vel
	p.r = maxf(float(s.get("r", 12)) * HB, 5.0)
	p.data = s
	p.life = float(s.get("life", 2.0))
	p.pierce = bool(s.get("pierce", false))
	p.grav = float(s.get("grav", 0.0))
	p.homing = float(s.get("homing", 0.0))
	p.mode = String(s.get("mode", "fly"))
	p.arm = float(s.get("arm", 0.0))
	p.aoe = float(s.get("aoe", 0.0)) * HB
	p.col = cdata["color"].lightened(0.15)
	get_parent().add_child(p)
	Sfx.play("mina" if p.mode in ["mine", "trap", "spike"] else "projetil", 0.8)


func _do_tele(s: Dictionary) -> void:
	Sfx.play("teleporte", 0.8)
	var target := global_position
	if s.get("behind", false):
		var e := _nearest_enemy(float(s.get("range", 360)))
		if e != null:
			target = e.global_position + Vector2(-e.facing * (e.body.x / 2.0 + body.x / 2.0 + 8.0), 0.0)
			facing = e.facing
		else:
			target = global_position + Vector2(150.0 * facing, 0.0)
	else:
		target = global_position + Vector2(float(s.get("dx", 0)) * facing, float(s.get("dy", 0)))
	fx.append({"pos": global_position, "r": 30.0, "t": 0.0, "max": 0.25, "col": Color(1, 1, 1)})
	get_tree().call_group("fxlayer", "poof_fx", global_position, cdata["color"])
	global_position = Vector2(clampf(target.x, BLAST.position.x + 40.0, BLAST.end.x - 40.0),
		clampf(target.y, BLAST.position.y + 40.0, BLAST.end.y - 40.0))
	velocity = Vector2(velocity.x * 0.3, minf(velocity.y, 0.0) * 0.3)
	fx.append({"pos": global_position, "r": 30.0, "t": 0.0, "max": 0.25, "col": Color(1, 1, 1)})


func _do_area(s: Dictionary) -> void:
	get_tree().call_group("fxlayer", "shock_fx", global_position, cdata["color"], float(s.get("ring", s["r"])))
	fx.append({"pos": global_position, "r": float(s.get("ring", s["r"])), "t": 0.0, "max": 0.35,
		"col": cdata["color"]})
	for f in get_tree().get_nodes_in_group("fighters"):
		if f == self or f.eliminated or f.respawn_t > 0.0:
			continue
		if s.get("grounded", false) and not f.is_on_floor():
			continue
		if f.global_position.distance_to(global_position) > float(s["r"]):
			continue
		f.take_hit(s, _dir_to(f), self)


# ---------------------------------------------------------------- agarrão

func can_be_grabbed() -> bool:
	return not eliminated and respawn_t <= 0.0 and invincible <= 0.0 and ghost_t <= 0.0 \
		and grabbed_by == null and barrier_t <= 0.0


func _begin_grab(f: Node, s: Dictionary) -> void:
	grab_v = f
	Sfx.play("agarrao")
	grab_step = s
	grab_t = 0.0
	pummel_t = 0.0
	f.grabbed_by = self
	f._cancel_attack()
	f.shielding = false
	hit_connected = true


func _release_grab() -> void:
	if grab_v != null and is_instance_valid(grab_v) and grab_v.grabbed_by == self:
		grab_v.grabbed_by = null
	grab_v = null


func _update_grab(delta: float) -> void:
	var v: Node = grab_v
	if not is_instance_valid(v) or v.eliminated or v.respawn_t > 0.0 or v.grabbed_by != self:
		_release_grab()
		return
	var s := grab_step
	grab_t += delta
	pummel_t = maxf(pummel_t - delta, 0.0)
	velocity = Vector2.ZERO
	var hold := float(s.get("hold", 0.5))
	var spin := float(s.get("spin", 0.0))
	if spin > 0.0:
		var ang := (0.0 if facing > 0 else PI) + TAU * spin * clampf(grab_t / hold, 0.0, 1.0) * facing
		v.global_position = global_position + Vector2(cos(ang), sin(ang)) * 46.0
	else:
		v.global_position = global_position + Vector2(facing * (body.x / 2.0 + v.body.x / 2.0 + 2.0), -4.0)
	v.velocity = Vector2.ZERO

	var key := ""
	if s.get("mode", "auto") == "choose":
		if _just("attack") and pummel_t <= 0.0:
			pummel_t = 0.3
			v.percent += 1.5 * DMG_SCALE * dmg_mult()
			v.hit_flash = 0.06
			v.last_hit_dmg = 1.5
		var dx := _axis_x()
		if grab_t > 0.15:
			if _held("up"):
				key = "u"
			elif _held("down"):
				key = "d"
			elif absf(dx) > 0.5:
				key = "f" if (1 if dx > 0.0 else -1) == facing else "b"
		if key == "" and grab_t >= hold:
			key = "f"
	elif grab_t >= hold:
		key = "t"
	if key == "":
		return
	var data: Dictionary
	var dir := facing
	if key == "t":
		data = (s["throw"] as Dictionary).duplicate()
	else:
		data = (cdata["throws"][key] as Dictionary).duplicate()
		if key == "b":
			dir = -facing
	data["ub"] = true
	v.grabbed_by = null
	grab_v = null
	throw_count += 1
	Sfx.play("arremesso")
	move_used.emit(self, "deu %s" % String(data.get("label", cur_move.get("label", "Arremesso"))).split(" (")[0])
	v.take_hit(data, dir, self)
	hit_connected = true


# ---------------------------------------------------------------- dano

## Retorna true se o golpe foi "consumido" (acertou, bloqueou ou foi absorvido).
func take_hit(d: Dictionary, dir_x: int, attacker: Node = null) -> bool:
	if god_mode:
		return false
	var ub: bool = d.get("ub", false)
	if invincible > 0.0 or eliminated or respawn_t > 0.0:
		return false
	if ghost_t > 0.0 and not ub:
		return false
	var dmg := float(d["dmg"]) * DMG_SCALE * dmg_taken
	var base := float(d["base"])
	var has_atk := attacker != null and is_instance_valid(attacker)
	if has_atk:
		dmg *= attacker.dmg_mult()
		if d.has("back_mult") and facing == dir_x:
			dmg *= float(d["back_mult"])
			base *= float(d["back_mult"])
	var kbm := 1.0
	if not ub:
		if barrier_t > 0.0 and barrier_hp > 0.0:
			barrier_hp -= dmg
			if barrier_hp <= 0.0:
				barrier_t = 0.0
				Sfx.play("i_bolha_quebra")
			hit_flash = 0.05
			Sfx.play("escudo_bloqueio")
			_express("block", 0.6)
			return true
		if guard_t > 0.0:
			if not guard_counter.is_empty() and has_atk:
				var c := guard_counter
				guard_t = 0.0
				guard_counter = {}
				counter_count += 1
				ghost_t = 0.25
				ghost_alpha = 1.0
				facing = 1 if attacker.global_position.x > global_position.x else -1
				_cancel_attack()
				Sfx.play("contra")
				_start(c, "")
				_announce(c)
				return true
			dmg *= guard_mult
			kbm = guard_kb
		elif shielding:
			shield_hp = maxf(shield_hp - dmg * 2.5, 0.0)
			velocity.x = dir_x * 160.0
			hit_flash = 0.05
			Sfx.play("escudo_bloqueio")
			_express("block", 0.6)
			get_tree().call_group("fxlayer", "block_fx", global_position + Vector2(-dir_x * body.x * 0.5, 0.0))
			if shield_hp <= 0.0:
				_break_shield()
			return true
	percent += dmg
	Sfx.hit(dmg, percent)
	get_tree().call_group("fxlayer", "hit_fx", global_position, color, dmg)
	last_hit_dmg = dmg
	if has_atk and attacker != self:
		last_attacker = attacker
		last_attacker_t = 0.0
		attacker.hits_landed += 1
		attacker.dmg_dealt += dmg
	combo_hits += 1
	if combo_hits == 5 or combo_hits == 10:
		Sfx.play("combo", 0.8)
	combo_dmg += dmg
	combo_timer = 1.2
	hit_flash = 0.1
	_express("hit", 0.7)
	squash = 0.3   # amassa com a pancada
	squash_v = 0.0
	if armor_t > 0.0:
		return true
	var kb := (base + float(d["scale"]) * percent) / float(cdata["weight"]) * kbm  * kb_taken
	if d.get("pin", false) and has_atk:
		velocity = Vector2.ZERO
		hitstun = 0.28
		pin_t = 0.28
		pin_owner = attacker
	else:
		var ang := deg_to_rad(float(d["angle"]))
		velocity = Vector2(cos(ang) * dir_x, -sin(ang)) * kb
		hitstun = clampf(kb / 1700.0, 0.12, 0.7)
		pin_t = 0.0
	if d.has("slow"):
		slow_t = maxf(slow_t, float(d["slow"]))
	if d.has("root"):
		root_t = maxf(root_t, float(d["root"]))
	fly_t = 0.0
	shielding = false
	_cancel_attack()
	return true


func _break_shield() -> void:
	Sfx.play("escudo_quebra")
	shielding = false
	stun = 1.6
	shield_hp = 50.0
	velocity = Vector2(0.0, -350.0)


func _ko() -> void:
	ko_count += 1
	if last_attacker != null and is_instance_valid(last_attacker) and last_attacker_t < 6.0:
		last_attacker.kos += 1
		last_attacker._express("ko", 1.6)
		Sfx.play("torcida", 0.5)
	else:
		sd_count += 1
	last_attacker = null
	if not infinite:
		stocks -= 1
	_cancel_attack()
	shielding = false
	velocity = Vector2.ZERO
	hitstun = 0.0
	stun = 0.0
	pin_t = 0.0
	fly_t = 0.0
	get_tree().call_group("fxlayer", "ko_fx", global_position, color)
	Sfx.play("ko")
	if ai == null and prefix != "" and not infinite:
		var lost := "eliminado" if stocks <= 0 else "vida_perdida"
		get_tree().create_timer(0.6).timeout.connect(func(): Sfx.play(lost))
	visible = false
	if stocks <= 0:
		eliminated = true
	else:
		respawn_t = respawn_time


func _respawn() -> void:
	_express("respawn", 1.0)
	spawn_pop = 0.45
	trail.clear()
	global_position = Art.respawn
	velocity = Vector2.ZERO
	reset_state()
	invincible = respawn_inv
	jumps_left = int(cdata["jumps"])
	was_on_floor = false
	visible = true
	get_tree().call_group("fxlayer", "respawn_fx", global_position, color)
	Sfx.play("respawn", 0.8)


# ---------------------------------------------------------------- desenho

func _fx_dust(n: int) -> void:
	get_tree().call_group("fxlayer", "dust_fx", global_position + Vector2(0.0, body.y / 2.0), n)


func _process(delta: float) -> void:
	anim_t += delta
	if ghost_t > 0.0:
		modulate.a = ghost_alpha
	elif invincible > 0.0 and int(Time.get_ticks_msec() / 90.0) % 2 == 0:
		modulate.a = 0.4
	else:
		modulate.a = 1.0
	if invis_mode and still_t > 0.45:
		modulate.a = minf(modulate.a, 0.05)
	# mola de "amassa e estica"
	squash_v += (-squash * 380.0 - squash_v * 16.0) * delta
	squash += squash_v * delta
	if hitstun > 0.0:
		spin += clampf(velocity.x / 300.0, -1.5, 1.5) * 9.0 * delta
	else:
		spin = lerp_angle(wrapf(spin, -PI, PI), 0.0, 1.0 - exp(-14.0 * delta))
	# inclinação com mola (balança e assenta, em vez de virar seco)
	var lt := clampf(velocity.x / 420.0, -1.0, 1.0) * 0.16
	if not cur_move.is_empty() and hitstun <= 0.0:
		lt += _atk_lean()
	lean_v += ((lt - lean) * 170.0 - lean_v * 13.0) * delta
	lean += lean_v * delta
	land_t = maxf(land_t - delta, 0.0)
	spawn_pop = maxf(spawn_pop - delta, 0.0)
	# parado na beirada: se equilibra
	teeter = false
	if is_on_floor() and absf(velocity.x) < 30.0 and cur_move.is_empty() and hitstun <= 0.0 and not shielding:
		var feet := global_position.y + body.y * 0.5
		var l_air := Art.surface_below(global_position.x - body.x * 0.55, feet - 4.0) < 0.0 or Art.surface_below(global_position.x - body.x * 0.55, feet - 4.0) > feet + 12.0
		var r_air := Art.surface_below(global_position.x + body.x * 0.55, feet - 4.0) < 0.0 or Art.surface_below(global_position.x + body.x * 0.55, feet - 4.0) > feet + 12.0
		teeter = l_air != r_air
	# rastro quando está muito rápido (arremessado, dash, mergulho)
	trail_t -= delta
	var fast := visible and (velocity.length() > 620.0 or (ghost_t > 0.0 and velocity.length() > 300.0))
	if fast and trail_t <= 0.0:
		trail_t = 0.025
		trail.push_front(global_position)
		if trail.size() > 6:
			trail.pop_back()
	elif not fast and not trail.is_empty() and trail_t <= 0.0:
		trail_t = 0.03
		trail.pop_back()
	# poeirinha ao correr
	dust_t -= delta
	if visible and not eliminated and is_on_floor() and absf(velocity.x) > 250.0 and dust_t <= 0.0:
		dust_t = 0.13
		_fx_dust(1)
	# expressões, cambalhota e "virada" de lado
	expr_t = maxf(expr_t - delta, 0.0)
	if atk_lock and not _held("attack"):
		atk_lock = false   # soltou o botão de golpe: o próximo golpe sorteia outra expressão
	flip_t = maxf(flip_t - delta, 0.0)
	turn_t = maxf(turn_t - delta, 0.0)
	if facing != last_facing:
		last_facing = facing
		turn_t = 0.14
	if not is_on_floor() and Art.surface_below(global_position.x, global_position.y) < 0.0 \
			and velocity.y > 200.0 and hitstun <= 0.0 and visible:
		if not fall_flag:
			fall_flag = true
			_express("fall", 1.4)   # caindo para fora do palco
	else:
		fall_flag = false
	# olhar: os olhos seguem o rival mais próximo
	var en := _nearest_enemy()
	var gt := Vector2.ZERO
	if en != null:
		var gd: Vector2 = en.global_position - global_position
		gt = Vector2(clampf(gd.x / 220.0, -1.0, 1.0), clampf(gd.y / 160.0, -1.0, 1.0))
	gaze = gaze.lerp(gt, 1.0 - exp(-9.0 * delta))
	# vencedor pula de alegria
	if pose == 1 and not eliminated:
		hop_cd -= delta
		if hop_cd <= 0.0 and is_on_floor():
			velocity.y = -380.0
			squash = -0.25
			squash_v = 0.0
			hop_cd = 0.75
	_update_hands(delta)
	queue_redraw()


## As mãos flutuam soltas ao lado do corpo e vão até onde o golpe acontece.
func _update_hands(delta: float) -> void:
	var f := float(facing)
	var rx := body.x * 0.5 + 15.0
	var bob := sin(anim_t * 3.4) * 4.0
	var bob2 := sin(anim_t * 3.4 + 1.7) * 4.0
	var lag := Vector2(clampf(-velocity.x * 0.025, -14.0, 14.0), clampf(-velocity.y * 0.02, -12.0, 12.0))
	var tf := Vector2(f * rx, 4.0 + bob) + lag
	var tb := Vector2(-f * rx, 4.0 + bob2) + lag
	var punch := [false, false]
	var k := 12.0
	if grabbed_by != null:
		tf = Vector2(f * rx, -body.y * 0.5 - 8.0)
		tb = Vector2(-f * rx, -body.y * 0.5 - 8.0)
	elif hitstun > 0.0:
		var w := sin(anim_t * 28.0) * 5.0
		tf = Vector2(f * (rx + 6.0) + w, -body.y * 0.42)
		tb = Vector2(-f * (rx + 6.0) - w, -body.y * 0.42)
	elif stun > 0.0:
		tf = Vector2(f * (rx - 4.0), body.y * 0.38)
		tb = Vector2(-f * (rx - 4.0), body.y * 0.38)
	elif grab_v != null:
		tf = Vector2(f * (body.x * 0.5 + 16.0), -6.0)
		tb = Vector2(f * (body.x * 0.5 + 16.0), 8.0)
		punch = [true, true]
	elif not cur_move.is_empty():
		var si := _strike()
		if not si.is_empty():
			# golpe em 3 tempos: prepara (puxa a mão para trás), dispara (mão vai seca até o alvo), volta
			var d: Vector2 = si["d"]
			var at: Vector2 = (si["at"] as Vector2).limit_length(body.x * 0.5 + 80.0)
			var lead := 0 if d.x * f >= -0.2 else 1
			var hl := Vector2.ZERO   # mão que golpeia
			var ho := Vector2.ZERO   # a outra mão
			match int(si["ph"]):
				1:
					var kw := float(si["k"])
					hl = -d * rx * (0.3 + 0.35 * kw) + Vector2(0.0, -4.0)
					ho = d * rx * 0.45 + Vector2(0.0, 6.0)   # guarda na frente
					k = 30.0
				2:
					hl = at
					ho = -d * rx * 0.55 + Vector2(0.0, 4.0)  # puxa a outra para trás (equilíbrio)
					punch[lead] = true
					k = 75.0
				_:
					hl = at.lerp(Vector2(f * rx, 4.0), float(si["k"]))
					ho = Vector2(-f * rx, 4.0)
					k = 14.0
			if lead == 0:
				tf = hl
				tb = ho
			else:
				tb = hl
				tf = ho
		else:
			var cast := true
			for s in cur_move["steps"]:
				var ty := String(s["type"])
				if ty == "hit" or ty == "grab" or ty == "proj":
					cast = false
			if cast:
				# magia/buff: mãos sobem tremendo
				var up := -body.y * 0.5 - 22.0 + sin(anim_t * 18.0) * 3.0
				tf = Vector2(f * 14.0, up)
				tb = Vector2(-f * 14.0, up)
				k = 16.0
			else:
				tf = Vector2(-f * (rx - 4.0), 2.0)  # preparando o golpe
				k = 18.0
		if cur_move.has("charge") and not charge_done:
			tf = Vector2(-f * (rx - 2.0) + randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))
	elif shielding or guard_t > 0.0 or barrier_t > 0.0:
		tf = Vector2(f * body.x * 0.62, -8.0)
		tb = Vector2(f * body.x * 0.62, 10.0)
	elif fly_t > 0.0:
		var fl := sin(anim_t * 16.0) * 9.0
		tf = Vector2(f * (rx + 10.0), -10.0 + fl)
		tb = Vector2(-f * (rx + 10.0), -10.0 - fl)
	else:
		var spd := absf(velocity.x)
		if not is_on_floor():
			if velocity.y < -80.0:
				# subindo: braços para cima
				tf = Vector2(f * (rx - 2.0), -body.y * 0.38) + lag * 0.5
				tb = Vector2(-f * (rx - 2.0), -body.y * 0.3) + lag * 0.5
			else:
				# caindo: braços se agitando no alto
				var fl := sin(anim_t * 22.0) * 5.0
				tf = Vector2(f * (rx + 4.0), -body.y * 0.42 + fl)
				tb = Vector2(-f * (rx + 4.0), -body.y * 0.42 - fl)
			k = 14.0
		elif teeter:
			# na beirada: gira os braços tentando se equilibrar
			var wa := anim_t * 13.0
			tf = Vector2(f * rx, -6.0) + Vector2(cos(wa), sin(wa)) * 9.0
			tb = Vector2(-f * rx, -6.0) + Vector2(cos(wa + PI), sin(wa + PI)) * 9.0
			k = 20.0
		elif spd > 40.0:
			# correndo: braços alternam para frente e para trás no ritmo dos passos
			var ph := anim_t * (8.0 + spd / 55.0) * 0.5 + pid
			var sw := cos(ph) * 11.0
			tf = Vector2(f * (rx - 4.0) + f * sw, 4.0 - absf(sin(ph)) * 6.0) + lag * 0.4
			tb = Vector2(-f * (rx - 4.0) + f * sw * -1.0, 4.0 - absf(cos(ph)) * 6.0) + lag * 0.4
			k = 18.0
		if land_t > 0.0:
			# acabou de pousar: mãos abrem para os lados e para baixo
			tf = Vector2(f * (rx + 8.0), body.y * 0.28)
			tb = Vector2(-f * (rx + 8.0), body.y * 0.28)
			k = 26.0
	var tg := [tf, tb]
	for i in 2:
		hands[i] = (hands[i] as Vector2).lerp(tg[i], 1.0 - exp(-k * delta))
		hand_sc[i] = lerpf(float(hand_sc[i]), 1.4 if punch[i] else 1.0, 1.0 - exp(-30.0 * delta))
		hand_punch[i] = punch[i]
		var h: Array = hand_hist[i]
		h.push_front(hands[i])
		if h.size() > 6:
			h.pop_back()


func _draw_hand(i: int, fill: Color) -> void:
	var r := clampf(body.x * 0.3, 9.0, 14.0) * float(hand_sc[i])
	if hand_punch[i]:
		# rastro do soco: faixa afinando atrás da mão, na direção em que ela veio
		var h: Array = hand_hist[i]
		if h.size() > 4:
			var a: Vector2 = h[4]
			var b: Vector2 = hands[i]
			var dv := b - a
			if dv.length() > 6.0:
				var n := dv.normalized().orthogonal()
				var w0 := r * 0.25
				var w1 := r * 0.95
				var pts := PackedVector2Array([a + n * w0, b + n * w1, b - n * w1, a - n * w0])
				Art.poly(self, pts, Color(fill.lerp(Color.WHITE, 0.6), 0.45))
				Art.poly(self, PackedVector2Array([a.lerp(b, 0.3) + n * w0 * 0.6, b + n * w1 * 0.45,
					b - n * w1 * 0.45, a.lerp(b, 0.3) - n * w0 * 0.6]), Color(1, 1, 1, 0.6))
	Art.hand(self, hands[i], r, fill, color)


func _draw() -> void:
	var base_col: Color = cdata["color"]
	if morph_t > 0.0 and morph_char >= 0:
		base_col = base_col.lerp(Chars.all()[morph_char]["color"], 0.6)
	var c := base_col
	if hit_flash > 0.0:
		c = base_col.lerp(Color.WHITE, 0.85)
	elif stun > 0.0:
		c = base_col.darkened(0.45)
	elif slow_t > 0.0:
		c = c.lerp(Color(0.5, 0.8, 1.0), 0.5)
	var f := float(facing)

	# sombra no chão
	var sy := Art.surface_below(global_position.x, global_position.y + body.y / 2.0)
	if sy > 0.0:
		var dist := sy - (global_position.y + body.y / 2.0)
		var k := clampf(1.0 - dist / 320.0, 0.0, 1.0)
		if k > 0.02:
			Art.ellipse(self, Vector2(0.0, sy - global_position.y + 1.0), body.x * (0.35 + 0.35 * k), body.x * 0.1 * (0.5 + 0.5 * k),
				Color(0, 0, 0, 0.32 * k))
	if power_orb:
		_draw_power_aura()
	elif cur_slot == "super" and not cur_move.is_empty():
		_draw_power_aura(1.0 + 0.9 * clampf(attack_t / 0.4, 0.0, 1.0))
		_draw_power_aura()
	if held_item != "":
		var hp := Vector2(0.0, -body.y / 2.0 - 24.0 + sin(anim_t * 5.0) * 2.0)
		draw_set_transform(hp, 0.0, Vector2(0.75, 0.75))
		ItemsScript.draw_icon(self, held_item, Vector2.ZERO, ItemsScript.TYPES[held_item][1], anim_t)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# rastro quando está muito rápido
	for i in trail.size():
		var tp: Vector2 = (trail[i] as Vector2) - global_position
		Art.rrect(self, Rect2(tp - body / 2.0, body), minf(body.x, body.y) * 0.46, Color(c, 0.3 * (1.0 - float(i) / 6.0)))
	# mão de trás (fica atrás do corpo)
	_draw_hand(1, c)

	# corpo arredondado com amassa/estica
	var sx := 1.0 + squash
	var syy := 1.0 - squash
	var bob := 0.0
	var xoff := 0.0
	var on_fl := is_on_floor()
	var attacking_now := not cur_move.is_empty()
	if not on_fl:
		# no ar: estica na direção do movimento (mais na queda rápida)
		var st := clampf(absf(velocity.y) / 2000.0, 0.0, 0.22)
		syy += st
		sx -= st * 0.6
	elif hitstun <= 0.0 and stun <= 0.0:
		var spd := absf(velocity.x)
		if spd > 40.0 and not attacking_now:
			# correndo: pulinhos no ritmo dos passos (mais rápido = mais rápido)
			var h := absf(sin(anim_t * (8.0 + spd / 55.0) + pid))
			syy += (h - 0.5) * 0.14
			sx -= (h - 0.5) * 0.09
			bob = h * 5.0
		elif not attacking_now:
			var br := sin(anim_t * 2.4 + pid * 1.3) * 0.035   # respirando parado
			syy += br
			sx -= br * 0.6
		if shielding:
			syy -= 0.08
			sx += 0.08
	var atk_rot := 0.0
	if attacking_now and hitstun <= 0.0:
		# o corpo acompanha os 3 tempos do golpe: recua no preparo, avança seco no golpe, assenta na volta
		var sh := _atk_shape()
		sx += sh.y
		syy += sh.z
		atk_rot = sh.x * 0.5
		var si := _strike()
		if not si.is_empty():
			var am := _strike_amt(si)
			var dd: Vector2 = si["d"]
			xoff = dd.x * (8.0 * maxf(am, 0.0) + 4.0 * minf(am, 0.0))
			bob += -dd.y * 6.0 * maxf(am, 0.0)
	if pose == 2:
		syy -= 0.07   # derrotado: encolhido
		sx += 0.04
	if turn_t > 0.0:
		sx *= 1.0 - 0.28 * sin(PI * (1.0 - turn_t / 0.14))   # achata ao virar de lado
	if spawn_pop > 0.0:
		# voltou do KO: aparece crescendo com um "boing"
		var pp := 1.0 - spawn_pop / 0.45
		var el := sin(pp * TAU * 1.5) * (1.0 - pp) * 0.4
		var grow := minf(pp * 3.0, 1.0)
		sx *= grow * (1.0 + el)
		syy *= grow * (1.0 - el)
	if hit_flash > 0.0:
		xoff += randf_range(-3.0, 3.0)   # tremida ao apanhar
	var nair_spin := attacking_now and cur_slot == "nair" and hitstun <= 0.0
	var spinning := hitstun > 0.0 or fly_t > 0.0 or flip_t > 0.0 or nair_spin
	var pivot := Vector2.ZERO if spinning else Vector2(0.0, body.y / 2.0)
	var rot := spin if hitstun > 0.0 else lean + atk_rot
	if nair_spin:
		rot += clampf(attack_t / maxf(float(cur_move.get("dur", 0.3)), 0.05), 0.0, 1.0) * TAU * f   # giro do golpe aéreo
	if teeter:
		rot += sin(anim_t * 9.0) * 0.14   # se equilibrando na beirada
	if pose == 1:
		rot = sin(anim_t * 9.0) * 0.12   # vencedor balança feliz
	if flip_t > 0.0:
		rot += (1.0 - flip_t / 0.4) * TAU * f   # cambalhota no pulo duplo
	draw_set_transform(pivot, rot, Vector2(sx, syy))
	var mood := 0
	if pose != 0:
		mood = expr                      # comemorando / derrotado (sorteado ao fim da partida)
	elif stun > 0.0:
		mood = 3                         # tonto
	elif expr_t > 0.0:
		mood = expr                      # reação a um acontecimento (sorteada entre até 3)
	elif hitstun > 0.0:
		mood = 1
	elif teeter:
		mood = 7   # na beirada: medo de cair
	elif shielding or (percent >= 110.0 and not attacking_now):
		mood = 5   # decidido / apertado
	elif attacking_now:
		mood = 2
	elif ult_cd <= 0.0 and mana >= max_mana * 0.9 and on_fl and absf(velocity.x) < 40.0 and int(anim_t * 0.5 + pid) % 4 == 0:
		mood = 4   # confiante: Y pronto e mana cheia
	var blink := fmod(anim_t + pid * 0.7, 3.4) > 3.28
	Art.blob(self, -pivot + Vector2(xoff, -bob), body, c, color, f, mood, blink, gaze)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# mão da frente
	_draw_hand(0, c)

	# etiqueta com o nome
	var tag := "P%d" % pid
	if ai != null:
		tag = "CPU Nv%d" % ai.level
	elif prefix == "":
		tag = "BONECO"
	var ty := -body.y / 2.0 - 27.0
	Art.rrect(self, Rect2(-31.0, ty, 62.0, 19.0), 9.0, Color(color.darkened(0.45), 0.85), Color(color, 0.9), 1.5)
	draw_string(Art.font(), Vector2(-31.0, ty + 14.0), tag, HORIZONTAL_ALIGNMENT_CENTER, 62.0, 12, Color.WHITE)
	# barra de mana
	var bw := maxf(body.x + 8.0, 40.0)
	var by := -body.y / 2.0 - 38.0
	Art.rrect(self, Rect2(-bw / 2.0, by, bw, 6.0), 3.0, Color(0, 0, 0, 0.55))
	var mw := bw * mana / max_mana
	if mw > 1.0:
		Art.rrect(self, Rect2(-bw / 2.0, by, mw, 6.0), 3.0,
			Color(1.0, 0.3, 0.3) if no_mana_t > 0.0 else Color(0.35, 0.75, 1.0))

	# status
	if shielding:
		var a := 0.12 + 0.3 * shield_hp / 100.0
		Art.circ(self, Vector2.ZERO, body.y * 0.78, Color(0.4, 0.75, 1.0, a))
		Art.arc(self, Vector2.ZERO, body.y * 0.78, 0.0, TAU, 32, Color(0.8, 0.95, 1.0, 0.7), 2.5, true)
		Art.arc(self, Vector2.ZERO, body.y * 0.6, -2.5, -1.4, 8, Color(1, 1, 1, 0.8), 3.0, true)
	if guard_t > 0.0:
		Art.arc(self, Vector2.ZERO, body.y * 0.72, 0.0, TAU, 32, Color(1.0, 0.95, 0.5), 4.0, true)
	if barrier_t > 0.0 and barrier_hp > 0.0:
		Art.circ(self, Vector2.ZERO, body.y * 0.82, Color(0.7, 0.4, 1.0, 0.2 + 0.25 * barrier_hp / 30.0))
		Art.arc(self, Vector2.ZERO, body.y * 0.82, 0.0, TAU, 32, Color(0.9, 0.7, 1.0, 0.8), 2.5, true)
	if root_t > 0.0:
		for q in 4:
			var vx := -body.x * 0.5 + q * body.x / 3.0
			draw_line(Vector2(vx, body.y / 2.0), Vector2(vx + 3.0, body.y / 2.0 - 9.0), Color(0.45, 0.8, 0.35), 3.5, true)
		draw_line(Vector2(-body.x / 2.0 - 4.0, body.y / 2.0), Vector2(body.x / 2.0 + 4.0, body.y / 2.0), Color(0.7, 0.5, 0.2), 5.0, true)
	if buff_dmg_t > 0.0:
		var p := 0.6 + 0.4 * sin(anim_t * 10.0)
		Art.arc(self, Vector2.ZERO, body.y * 0.62, 0.0, TAU, 28, Color(1.0, 0.55, 0.2, p), 3.5, true)
		Art.sparkle(self, Vector2(sin(anim_t * 4.0) * body.x * 0.6, -body.y * 0.5 - 4.0 + cos(anim_t * 6.0) * 4.0), 6.0, Color(1.0, 0.8, 0.3))
	if buff_spd_t > 0.0:
		Art.arc(self, Vector2.ZERO, body.y * 0.58, 0.0, TAU, 28, Color(0.5, 1.0, 0.7, 0.55), 2.5, true)
	if not cur_move.is_empty():
		_draw_attack()
	for e in fx:
		var fr := float(e["t"]) / float(e["max"])
		Art.arc(self, to_local(e["pos"]), float(e["r"]) * (0.3 + 0.7 * fr), 0.0, TAU, 48,
			Color(e["col"], 1.0 - fr), 5.0 * (1.0 - fr) + 1.0, true)


func _draw_attack() -> void:
	var col: Color = cdata["color"]
	var light := col.lerp(Color.WHITE, 0.55)
	for s in cur_move["steps"]:
		if s["type"] != "hit" and s["type"] != "grab":
			continue
		var st := float(s["t"])
		var ln := maxf(float(s["len"]), 0.05)
		var off: Vector2 = hb_off(s)
		var size: Vector2 = hb_size(s)
		var c := Vector2(off.x * facing, off.y)
		var r := Rect2(c - size / 2.0, size)
		var rad := minf(size.x, size.y) * 0.5
		if attack_t < st or attack_t > st + ln:
			continue
		var p := clampf((attack_t - st) / ln, 0.0, 1.0)
		var fade := 1.0 - pow(p, 2.5)
		if cur_slot == "super" and s["type"] == "hit":
			_draw_super_burst(c, size, p, fade)
			continue
		if s["type"] == "grab":
			Art.rrect(self, r, rad, Color(1, 0.85, 0.35, 0.18 * fade), Color(1, 0.9, 0.5, 0.7 * fade), 2.0)
			Art.sparkle(self, c, 8.0 + 6.0 * sin(anim_t * 20.0), Color(1, 0.95, 0.6, fade), anim_t * 6.0)
			continue
		var dist := c.length()
		var ext := maxf(size.x, size.y) * 0.5
		if dist < 14.0:
			var rr := maxf(size.x, size.y) * (0.35 + 0.65 * p)
			Art.arc(self, c, rr, 0.0, TAU, 32, Color(col, 0.35 * fade), 12.0)
			Art.arc(self, c, rr, 0.0, TAU, 32, Color(light, 0.85 * fade), 4.0)
			for k in 6:
				var an := k * TAU / 6.0 + anim_t * 8.0
				Art.sparkle(self, c + Vector2(cos(an), sin(an)) * rr, 6.0, Color(1, 1, 1, fade), an)
			continue
		if ext < 24.0:
			# golpe curto (soco/chute): a mão com rastro já mostra o golpe; aqui só um estalo no ponto do impacto
			if p < 0.5:
				Art.sparkle(self, c, 8.0 + 10.0 * (1.0 - p * 2.0), Color(1, 1, 1, fade), anim_t * 10.0)
			continue
		# corte em arco: varre da ponta de trás até a da frente
		var base := c.angle()
		var span := clampf(ext / dist, 0.45, 1.25)
		var sg := float(facing)
		var a_start := base - sg * span
		var e := 1.0 - pow(1.0 - p, 2.5)
		var lead := a_start + sg * 2.0 * span * e
		var tail := lead - sg * 2.0 * span * (0.35 + 0.65 * e)
		if (tail - a_start) * sg < 0.0:
			tail = a_start
		var rad_arc := dist + ext * 0.15
		var a0 := minf(tail, lead)
		var a1 := maxf(tail, lead)
		if a1 - a0 > 0.02:
			var wdt := minf(ext * 0.6 + 16.0, 44.0)
			_crescent(a0, a1, rad_arc, wdt + 7.0, sg, Color(Art.INK, 0.8 * fade))
			_crescent(a0, a1, rad_arc, wdt, sg, Color(col.lightened(0.1), 0.95 * fade))
			_crescent(a0, a1, rad_arc, wdt * 0.5, sg, Color(1, 1, 1, fade))
		var tip := Vector2(cos(lead), sin(lead)) * rad_arc
		Art.sparkle(self, tip, 10.0 + ext * 0.35, Color(1, 1, 1, fade), anim_t * 10.0)
		for k in 3:
			var la := lead - sg * (0.35 + 0.22 * k)
			var d0 := Vector2(cos(la), sin(la))
			Art.polyline(self, PackedVector2Array([d0 * (rad_arc - ext * 0.5), d0 * (rad_arc + ext * 0.7)]),
				Color(light, 0.5 * fade), 2.0)
	if cur_move.has("charge") and not charge_done:
		var cr := 20.0 + 30.0 * charge_t
		Art.arc(self, Vector2.ZERO, cr, 0.0, TAU, 32, Color(1, 0.9, 0.3), 3.0, true)
		Art.sparkle(self, Vector2(cos(anim_t * 9.0), sin(anim_t * 9.0)) * cr, 6.0, Color(1, 0.95, 0.5), anim_t * 4.0)


## X/Quadrado: com item na mão, usa/joga; perto de um item no chão, pega. Senão, ataque normal.
func _try_item() -> bool:
	if not _just("attack"):
		return false
	var mgr := get_tree().get_first_node_in_group("items")
	if mgr == null:
		return false
	if held_item != "":
		var id := held_item
		held_item = ""
		mgr.use(id, self)
		return true
	return mgr.pickup(self)


## Meia-lua preenchida (corte de espada): fina na cauda, larga na ponta de ataque.
func _crescent(a0: float, a1: float, rad: float, w: float, sg: float, col: Color) -> void:
	var n := 18
	var prev_o := Vector2.ZERO
	var prev_i := Vector2.ZERO
	var cols := PackedColorArray([col, col, col, col])
	for k in n + 1:
		var u := float(k) / float(n)
		var ang := lerpf(a0, a1, u)
		var lead_u := u if sg > 0.0 else 1.0 - u
		var th := w * sin(PI * pow(lead_u, 0.55)) * 0.5
		var d := Vector2(cos(ang), sin(ang))
		var po := d * (rad + th)
		var pi_ := d * (rad - th)
		if k > 0:
			draw_primitive(PackedVector2Array([prev_o, po, pi_, prev_i]), cols, PackedVector2Array())
		prev_o = po
		prev_i = pi_


## Em que tempo do golpe o lutador está: ph 1 = preparo, 2 = golpe, 3 = volta (vazio = nenhum).
## d = direção do golpe (unitária), at = onde o golpe acontece (relativo ao corpo), k = 0..1 dentro do tempo.
func _strike() -> Dictionary:
	var res := {}
	if cur_move.is_empty():
		return res
	for s in cur_move["steps"]:
		var ty := String(s["type"])
		if ty != "hit" and ty != "grab" and ty != "proj":
			continue
		var st := float(s["t"])
		var ln := 0.1 if ty == "proj" else maxf(float(s["len"]), 0.04)
		var off: Vector2 = hb_off(s)
		var at := Vector2(off.x * facing, off.y)
		if ty == "proj":
			at = Vector2(facing * (body.x * 0.5 + 26.0), off.y)
		var d := at.normalized() if at.length() > 6.0 else Vector2(facing, 0.0)
		var pre := 0.11
		if attack_t >= st - pre and attack_t < st:
			return {"ph": 1, "d": d, "at": at, "k": (attack_t - (st - pre)) / pre}
		if attack_t >= st and attack_t <= st + ln:
			return {"ph": 2, "d": d, "at": at, "k": (attack_t - st) / ln}
		if attack_t > st + ln and attack_t <= st + ln + 0.14:
			res = {"ph": 3, "d": d, "at": at, "k": (attack_t - st - ln) / 0.14}
	return res


## Quanto o corpo "vai junto" com o golpe: negativo no preparo, 1 no golpe, voltando a 0 depois.
func _strike_amt(si: Dictionary) -> float:
	var k := clampf(float(si["k"]), 0.0, 1.0)
	match int(si["ph"]):
		1:
			return -0.55 * (1.0 - (1.0 - k) * (1.0 - k))
		2:
			return 1.0
		3:
			return 1.0 - k * k * (3.0 - 2.0 * k)
	return 0.0


## Pose do corpo no golpe: x = inclinação, y = estica na largura, z = estica na altura.
## Segue a direção do golpe: para frente inclina e estica, para cima estica para cima, para baixo afunda.
func _atk_shape() -> Vector3:
	var si := _strike()
	if si.is_empty():
		return Vector3.ZERO
	var d: Vector2 = si["d"]
	var am := _strike_amt(si)
	var lean_a := d.x * 0.34 * am
	var sxa := 0.2 * am * absf(d.x)
	var sya := -0.1 * am * absf(d.x)
	if d.y < 0.0:
		sya += 0.26 * am * -d.y
		sxa -= 0.13 * am * -d.y
	else:
		sya -= 0.2 * am * d.y
		sxa += 0.16 * am * d.y
	return Vector3(lean_a, sxa, sya)


func _atk_lean() -> float:
	return _atk_shape().x * 0.5


## Aura de poder (Orbe de Poder): coluna de chamas azuis, brilho pulsante, raios subindo e faíscas.
## k = intensidade (1 normal; maior durante a carga do golpe supremo).
func _draw_power_aura(k := 1.0) -> void:
	var t := anim_t
	var u := maxf(body.y, 30.0)
	var pulse := 0.5 + 0.5 * sin(t * 9.0)
	var foot := body.y * 0.5
	# brilho de fundo (coluna de luz)
	Art.circ(self, Vector2(0, -u * 0.3), u * (1.9 + 0.15 * pulse) * k, Color(0.15, 0.4, 1.0, 0.14))
	Art.circ(self, Vector2(0, -u * 0.2), u * (1.3 + 0.1 * pulse) * k, Color(0.35, 0.7, 1.0, 0.2))
	Art.ellipse(self, Vector2(0, foot), u * 1.4 * k, u * 0.22, Color(0.3, 0.65, 1.0, 0.35 + 0.2 * pulse))
	# línguas de fogo azul (3 camadas: azul profundo, azul claro, núcleo branco)
	var n := 11
	for i in n:
		var side := (float(i) / (n - 1) - 0.5) * 2.0   # -1..1
		var ph := t * 7.0 + i * 2.3
		var bx := side * u * 0.75 * k
		var by := foot - absf(side) * u * 0.12
		var fh := u * (1.5 + 0.5 * sin(ph)) * (1.15 - 0.45 * absf(side)) * k
		var w := u * (0.34 - 0.12 * absf(side)) * k
		var sway := sin(ph * 0.7) * u * 0.18
		var tip := Vector2(bx + sway, by - fh)
		var mid := Vector2(bx + sway * 0.4, by - fh * 0.5)
		Art.poly(self, PackedVector2Array([Vector2(bx - w, by), mid + Vector2(-w * 0.8, 0), tip, mid + Vector2(w * 0.8, 0), Vector2(bx + w, by)]),
			Color(0.1, 0.32, 1.0, 0.62))
		Art.poly(self, PackedVector2Array([Vector2(bx - w * 0.6, by), mid + Vector2(-w * 0.4, 0), tip * 0.5 + Vector2(bx + sway, by) * 0.5 + Vector2(0, -fh * 0.28), mid + Vector2(w * 0.4, 0), Vector2(bx + w * 0.6, by)]),
			Color(0.45, 0.78, 1.0, 0.7))
		Art.poly(self, PackedVector2Array([Vector2(bx - w * 0.28, by), Vector2(bx + sway * 0.3, by - fh * 0.42), Vector2(bx + w * 0.28, by)]),
			Color(0.9, 0.98, 1.0, 0.85))
	# anéis de energia subindo
	for r in 3:
		var f := fmod(t * 1.3 + r / 3.0, 1.0)
		Art.ellipse(self, Vector2(0, foot - f * u * 2.0), u * (1.2 - 0.5 * f) * k, u * 0.2 * (1.0 - f), Color(0.6, 0.9, 1.0, 0.7 * (1.0 - f)))
	Art.arc(self, Vector2.ZERO, u * 0.72, 0.0, TAU, 32, Color(0.75, 0.94, 1.0, 0.55 + 0.4 * pulse), 3.0, true)
	for q in 5:
		var a := t * 3.0 + q * TAU / 5.0
		Art.sparkle(self, Vector2(cos(a) * u * 0.9, foot - fmod(t * 60.0 + q * 37.0, u * 2.2)), 6.0, Color(0.75, 0.96, 1.0), a)


## Explosão azul do golpe supremo (centrada na caixa do golpe).
func _draw_super_burst(c: Vector2, size: Vector2, p: float, fade: float) -> void:
	var e := 1.0 - pow(1.0 - p, 3.0)
	var rr := size.x * 0.5 * (0.25 + 0.75 * e)
	Art.circ(self, c, rr, Color(0.1, 0.35, 1.0, 0.35 * fade))
	Art.circ(self, c, rr * 0.7, Color(0.4, 0.75, 1.0, 0.45 * fade))
	Art.circ(self, c, rr * 0.38, Color(0.95, 0.99, 1.0, 0.9 * fade))
	Art.arc(self, c, rr, 0.0, TAU, 48, Color(0.8, 0.95, 1.0, fade), 6.0, true)
	Art.arc(self, c, rr * 0.72, 0.0, TAU, 40, Color(0.3, 0.6, 1.0, 0.8 * fade), 4.0, true)
	for i in 14:   # raios de luz
		var an := i * TAU / 14.0 + 0.3
		var d := Vector2(cos(an), sin(an))
		var len := rr * (1.1 + 0.5 * float(i % 3) / 2.0)
		var w := 7.0 * (1.0 - p)
		Art.poly(self, PackedVector2Array([c + d * rr * 0.3 + d.orthogonal() * w, c + d * len, c + d * rr * 0.3 - d.orthogonal() * w]),
			Color(0.8, 0.95, 1.0, 0.8 * fade))
