extends Node2D
## Menus (título, configuração, conexão, seleção), Versus (com CPUs), Treino e Tutoriais.

const Chars := preload("res://scripts/characters.gd")
const FighterScript := preload("res://scripts/fighter.gd")
const TutorialScript := preload("res://scripts/tutorial.gd")
const Art := preload("res://scripts/art.gd")
const BackdropScript := preload("res://scripts/backdrop.gd")
const FxScript := preload("res://scripts/fxlayer.gd")
const StageScript := preload("res://scripts/stage.gd")
const ItemsScript := preload("res://scripts/items.gd")
const Stages := preload("res://scripts/stages.gd")
const Ach := preload("res://scripts/achievements.gd")
const MAX_PLAYERS := 6
const COLORS := [Color("e74c3c"), Color("3498db"), Color("2ecc71"), Color("f1c40f"), Color("b46bd6"), Color("ff8a3d")]
## Extras: frases (Splash Text) sorteadas no título, no lugar de "arena de luta".
const SPLASHES := [
	"Arena de luta!", "Agora com 100% mais bolas!", "Não é um jogo de bilhar!", "Redondo, mas perigoso!",
	"Feito com carinho e _draw()!", "Zero sprites, 100% código!", "Cuidado com a lava!", "Sai da frente, cara!",
	"Quem cair, perdeu!", "Smash em formato bola!", "Pule duas vezes, viva uma!", "O escudo é seu amigo!",
	"Tem Orbe de Poder por aí!", "Mana não cai do céu!", "Aperte Y e reze!", "Seus amigos vão te trair!",
	"A CPU nível 9 não perdoa!", "Quase um clássico!", "Feito em Godot!", "Também funciona no navegador!",
	"Rolando para a vitória!", "Foi só um empurrãozinho!", "Fora do mapa, fora do jogo!", "39 mapas de pura loucura!",
	"16 bolas, uma só vencedora!", "Trapaça não vale conquista!", "Ninguém sobrevive ao Caos!", "Treine antes de chorar!",
	"Só mais uma partida...", "Pause e respire fundo!"]
const TITLE_OPTS := ["VERSUS", "TREINO", "TUTORIAL BÁSICO", "TUTORIAL AVANÇADO", "CONQUISTAS"]
const GRID_ORIGIN := Vector2(50, 120)
const CELL := Vector2(150, 100)
const RANDOM_ID := 16                          # "personagem" especial: sorteia um dos 16
const RANDOM_RECT := Rect2(54, 524, 592, 38)
const SG_ORIGIN := Vector2(40, 80)            # tela de mapas: grade 8 x 5
const SG_CELL := Vector2(150, 86)
const SG_COLS := 8

enum S { TITLE, CONFIG, CONNECT, SELECT, FIGHT, OVER, STAGE, ACH }

## Tela de conquistas: grade 3 colunas, 7 linhas visíveis, rolagem por linha.
const ACH_COLS := 3
const ACH_ROWS := 7
const ACH_CARD := Vector2(392, 62)
const ACH_ORIGIN := Vector2(40, 104)
const ACH_GAP := Vector2(12, 8)

## Modos de jogo do Versus (escolhidos na configuração) e mutadores.
const GAME_MODES := ["Clássico", "Frenético", "Mutadores", "Morte Súbita", "Caos", "Caça aos KOs"]
const RULES := ["classic", "frantic", "mutators", "sudden", "chaos", "hunt"]
const MODE_DESC := [
	"Todos contra todos, 3 vidas. Vence o último de pé.",
	"Tudo mais rápido: corrida, golpes, dano, respawn, itens e perigos. Sem tempo para respirar!",
	"Um mutador aleatório (de 10) muda as regras da partida.",
	"1 vida só e todo mundo começa com 100% de dano.",
	"A cada 15 segundos um novo mutador aleatório muda tudo.",
	"90 segundos, vidas infinitas: quem fizer mais KOs vence.",
]
const WIND_F := 600.0        # força do mutador Vento
const WIND_PERIOD := 6.0
## Trapaças do menu de pausa. toggle = fica ligada até o fim da partida; senão acontece na hora.
const CHEATS := [
	{"id": "items", "text": "FAZER APARECER ITENS", "toggle": false},
	{"id": "dmg999", "text": "999% DE DANO PARA TODOS", "toggle": false},
	{"id": "dmg0", "text": "ZERAR O DANO DE TODOS", "toggle": false},
	{"id": "life", "text": "+1 VIDA PARA TODOS", "toggle": false},
	{"id": "ko_cpu", "text": "NOCAUTEAR AS CPUs", "toggle": false},
	{"id": "mana", "text": "MANA INFINITA", "toggle": true},
	{"id": "ult", "text": "Y SEMPRE PRONTO", "toggle": true},
	{"id": "god", "text": "JOGADORES INVENCÍVEIS", "toggle": true},
	{"id": "jump", "text": "SUPER PULO", "toggle": true},
	{"id": "slow", "text": "CÂMERA LENTA", "toggle": true},
	{"id": "grav", "text": "GRAVIDADE DA LUA", "toggle": true},
]
const MUTATORS := [
	{"id": "lowgrav", "name": "GRAVIDADE BAIXA", "desc": "Tudo flutua"},
	{"id": "dmg2", "name": "DANO DOBRADO", "desc": "Todo golpe machuca o dobro"},
	{"id": "slip", "name": "CHÃO ESCORREGADIO", "desc": "O chão virou gelo"},
	{"id": "push", "name": "EMPURRA-EMPURRA", "desc": "Todo golpe vira um empurrão"},
	{"id": "wind", "name": "VENTO", "desc": "O vento muda de lado de tempos em tempos"},
	{"id": "mana", "name": "MUITA MANA", "desc": "250 de mana para todos"},
	{"id": "invis", "name": "INVISÍVEL", "desc": "Parado, você some"},
	{"id": "run", "name": "CORRIDA", "desc": "Todo mundo anda o dobro"},
	{"id": "gameboy", "name": "GAMEBOY", "desc": "Tudo fica pixelado"},
	{"id": "swap", "name": "CONTROLES TROCADOS", "desc": "Analógico e botões trocaram de função"},
]
const GB_SHADER := "shader_type canvas_item;
uniform sampler2D scr : hint_screen_texture, filter_nearest;
void fragment() {
	vec2 res = vec2(320.0, 180.0);
	vec2 uv = (floor(SCREEN_UV * res) + 0.5) / res;
	vec3 c = texture(scr, uv).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	float k = clamp(floor(l * 4.0), 0.0, 3.0);
	vec3 p0 = vec3(0.059, 0.220, 0.059);
	vec3 p1 = vec3(0.188, 0.384, 0.188);
	vec3 p2 = vec3(0.545, 0.675, 0.059);
	vec3 p3 = vec3(0.608, 0.737, 0.059);
	COLOR = vec4(k < 0.5 ? p0 : (k < 1.5 ? p1 : (k < 2.5 ? p2 : p3)), 1.0);
}
"

var st := S.TITLE
var mode := "versus"       # versus | training | tutorial1 | tutorial2
var title_sel := 0
var cfg_row := 0
var cfg_humans := 1
var cfg_cpus := 1
var cfg_level := 5
var train_ai := 0          # treino: 0 = boneco parado, 1..9 = CPU
var n_players := 1         # jogadores humanos a conectar
var slots: Array = []      # dispositivos conectados, na ordem de entrada
var entries: Array = []    # seleção: {kind, prefix, label, color, cursor, locked, level}
var focus := 0
var connect_t := 0.0
var fighters: Array = []
var tut = null
var feed: Array = []       # registro de golpes: {text, color, t}
var hud_labels: Array[Label] = []
var hud_panel: Node2D
var btn_layer: Node2D
var msg: Label
var hint: Label
var anim_t := 0.0
var splash := ""
var _draw_acc := 0.0
var _hud_cache: Array = ["", "", "", "", "", ""]   # evita reescrever Labels (e refazer layout) todo quadro
var _hud_col: Array = [-1, -1, -1, -1, -1, -1]
var _hud_n := 0   # quantos painéis o HUD está mostrando (reposiciona os textos)
var backdrop: Node2D
var mouse := Vector2(-999, -999)   # posição do mouse (para destacar botões)
var hover_cell := -1               # seleção: personagem sob o mouse
var btn_focus := 0                 # controle: botão em foco (configuração / fim da partida)
var sel_btn := -1                  # controle: botão em foco na seleção de personagem (-1 = nenhum)
var stage: Node2D
var items: Node2D
var stage_sel := 1                 # tela de mapas: 0 = aleatório, 1.. = mapa (índice + 1)
var stage_id := 0                  # mapa da partida atual
var pal_id := 0                    # paleta da partida atual
var _aud_want := ""                # última música pedida ao Sfx
var cfg_mode := 0                  # configuração: índice em GAME_MODES
var rule := "classic"              # regra da partida atual (RULES)
var cfg_inf := false                  # opção: Partida Infinita (rodadas seguidas)
var inf_run := false               # a partida atual é infinita
var wins: Dictionary = {}          # Partida Infinita: índice do lutador -> vitórias
var round_over := false
var round_t := 0.0
var mut_cur := -1                  # mutador ativo (índice em MUTATORS) ou -1
var chaos_t := 0.0
var wind_t := 0.0
var wind_dir := 1.0
var wind_cur := 0.0                # força atual do vento (vira devagar)
var wind_warned := false
var wind_parts: Array = []         # partículas do vento: {p, v, l}
var hunt_t := 90.0
var banner := ""
var banner_t := 0.0
var gb_rect: ColorRect
var paused := false              # menu de pausa aberto (Start/Options ou Esc durante a luta)
var pause_sel := 0
var pause_page := 0               # 0 = menu de pausa, 1 = trapaças
var cheats: Dictionary = {}        # trapaças ligadas nesta partida (id -> true)
var cheats_used := false           # usou trapaça: a partida não conta para as conquistas
var ach_row := 0                   # conquistas: primeira linha visível (alvo da rolagem)
var ach_scroll := 0.0              # rolagem suavizada, em linhas
var _ach_prev: Dictionary = {}     # conquistas: foto dos contadores de cada lutador humano
var _ach_acc := 0.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Ach.flush()


func _ready() -> void:
	Ach.setup(Stages.count())
	process_mode = Node.PROCESS_MODE_ALWAYS      # o menu de pausa continua funcionando com o jogo pausado
	Sfx.process_mode = Node.PROCESS_MODE_ALWAYS  # a música não para na pausa
	Art.pal = Stages.palette(0)
	backdrop = BackdropScript.new()
	add_child(backdrop)
	stage = StageScript.new()
	add_child(stage)
	items = ItemsScript.new()
	items.feed_cb = _on_move_used
	add_child(items)
	var fxl := FxScript.new()
	add_child(fxl)
	for n in [backdrop, stage, items, fxl]:
		n.process_mode = Node.PROCESS_MODE_PAUSABLE
	_build_hud()
	_go_title()


# ---------------------------------------------------------------- construção

func _label(pos: Vector2, size: Vector2, font: int, center: bool) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = size
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", Art.font())
	l.add_theme_font_size_override("font_size", font)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.2))
	l.add_theme_constant_override("outline_size", 6)
	return l


func _build_hud() -> void:
	# Painéis de mana num nó com z alto: ficam sempre à frente dos lutadores.
	var gl := CanvasLayer.new()   # filtro Gameboy (mutador): por cima de tudo
	gl.layer = 5
	add_child(gl)
	gb_rect = ColorRect.new()
	gb_rect.size = Vector2(1280, 720)
	gb_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = GB_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	gb_rect.material = mat
	gb_rect.visible = false
	gl.add_child(gb_rect)
	hud_panel = Node2D.new()
	hud_panel.z_index = 100
	hud_panel.draw.connect(_draw_mana_bars)
	add_child(hud_panel)
	# Botões acima de tudo (inclusive lutadores).
	btn_layer = Node2D.new()
	btn_layer.z_index = 200
	btn_layer.draw.connect(_draw_buttons)
	add_child(btn_layer)
	var hud := CanvasLayer.new()
	add_child(hud)
	for i in MAX_PLAYERS:
		var l := _label(Vector2(44 + i * 310, 592), Vector2(270, 64), 22, false)
		hud.add_child(l)
		hud_labels.append(l)
	msg = _label(Vector2(0, 60), Vector2(1280, 300), 30, true)
	hud.add_child(msg)
	hint = _label(Vector2(0, 694), Vector2(1280, 26), 17, true)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	hud.add_child(hint)


# ---------------------------------------------------------------- fluxo

func _in_match() -> bool:
	return st == S.FIGHT or st == S.OVER


func _is_tutorial() -> bool:
	return mode.begins_with("tutorial")


func _on_move_used(f: Node, text: String) -> void:
	var who := "P%d" % f.pid
	if f.ai != null:
		who = "CPU %d" % f.pid
	elif f.prefix == "":
		who = "BONECO"
	feed.append({"text": "%s %s" % [who, text], "color": f.color, "t": 0.0})
	if feed.size() > 9:
		feed.pop_front()


func _process(delta: float) -> void:
	anim_t += delta
	Ach.tick(delta)
	ach_scroll = move_toward(ach_scroll, float(ach_row), delta * (6.0 + absf(ach_scroll - ach_row) * 6.0))
	stage.visible = _in_match()
	stage.running = st == S.FIGHT
	items.running = st == S.FIGHT and not _is_tutorial()
	for e in feed:
		e["t"] = float(e["t"]) + delta
	feed = feed.filter(func(e): return float(e["t"]) < 3.2)
	if st == S.FIGHT:
		if paused:
			_pause_menu()
			btn_layer.queue_redraw()
			msg.visible = false
			hint.visible = false
			for hl in hud_labels:
				hl.visible = false
			return
		if Input.is_action_just_pressed("start") or Input.is_action_just_pressed("menu_back"):
			_open_pause()
			return
	if Input.is_action_just_pressed("menu_back") and st != S.TITLE and st != S.FIGHT:
		Sfx.play("menu_voltar")
		_go_title()
	if st != S.FIGHT and (Inputs.any_just("up") != "" or Inputs.any_just("down") != "" \
			or Inputs.any_just("left") != "" or Inputs.any_just("right") != ""):
		Sfx.play("menu_mover")
	match st:
		S.TITLE:
			_title()
		S.CONFIG:
			_config()
		S.CONNECT:
			_connect(delta)
		S.SELECT:
			_select()
		S.STAGE:
			_stage_select()
		S.FIGHT:
			_fight(delta)
			_cheat_tick()
			_ach_tick(delta)
		S.OVER:
			_over()
		S.ACH:
			_ach_screen()
	_update_audio()
	_update_hud()
	# Em partida o HUD só precisa de ~60 Hz; menus redesenham todo quadro (animações e mouse).
	_draw_acc += delta
	if (st != S.FIGHT and st != S.OVER) or _draw_acc >= 1.0 / 60.0 - 0.0005:
		_draw_acc = 0.0
		queue_redraw()
		hud_panel.queue_redraw()
		btn_layer.queue_redraw()


## Escolhe a música do momento: menu, luta (sorteia 1 de 3 por partida), última vida ou silêncio (fim).
func _update_audio() -> void:
	var want := "menu"
	match st:
		S.FIGHT:
			if not _is_tutorial():
				want = "battle"
				if mode == "versus":
					for f in fighters:
						if not f.eliminated and f.stocks <= 1:
							want = "final"
		S.OVER:
			want = "stop"
	if want != _aud_want:
		_aud_want = want
		Sfx.set_music(want)


func _confirm_pressed() -> bool:
	return Inputs.any_just("attack") != "" or Inputs.any_just("jump") != "" \
		or Input.is_action_just_pressed("start")


func _go_title() -> void:
	for hl in hud_labels:
		hl.visible = true
	_reset_cheats()
	msg.visible = true
	hint.visible = true
	paused = false
	get_tree().paused = false
	Ach.flush()
	_clear_fighters()
	rule = "classic"
	inf_run = false
	_clear_mut()
	items.rate = 1.0
	stage.rate = 1.0
	Art.pal = Stages.palette(0)
	st = S.TITLE
	splash = SPLASHES[randi() % SPLASHES.size()]
	slots.clear()
	tut = null
	msg.text = ""
	hint.text = ""


func _title() -> void:
	if Inputs.any_just("up") != "":
		title_sel = (title_sel + TITLE_OPTS.size() - 1) % TITLE_OPTS.size()
	if Inputs.any_just("down") != "":
		title_sel = (title_sel + 1) % TITLE_OPTS.size()
	if _confirm_pressed():
		_title_confirm()


func _title_confirm() -> void:
	Sfx.play("menu_ok")
	cfg_row = 0
	slots.clear()
	connect_t = 0.0
	match title_sel:
		0:
			mode = "versus"
			st = S.CONFIG
		1:
			mode = "training"
			st = S.CONFIG
		2:
			mode = "tutorial1"
			n_players = 1
			st = S.CONNECT
		3:
			mode = "tutorial2"
			n_players = 1
			st = S.CONNECT
		4:
			ach_row = 0
			ach_scroll = 0.0
			st = S.ACH


func _over() -> void:
	var bl := _buttons()
	if Inputs.any_just("up") != "" or Inputs.any_just("down") != "":
		btn_focus = (btn_focus + 1) % bl.size()
	if Input.is_action_just_pressed("start"):
		_start_select()
	elif Inputs.any_just("attack") != "" or Inputs.any_just("jump") != "":
		_press(String(bl[btn_focus]["id"]))


## Índice do botão em foco pelo controle/teclado (-1 = nenhum), para desenhar o destaque.
func _focused_index() -> int:
	match st:
		S.CONFIG:
			return btn_focus if cfg_row >= _cfg_row_count() else -1
		S.SELECT:
			return sel_btn
		S.OVER:
			return btn_focus
	return -1


func _config() -> void:
	# a última "linha" é a barra de botões (CONTINUAR / VOLTAR), alcançada descendo
	var rows := _cfg_row_count() + 1
	if Inputs.any_just("up") != "":
		cfg_row = (cfg_row + rows - 1) % rows
		btn_focus = 0
	if Inputs.any_just("down") != "":
		cfg_row = (cfg_row + 1) % rows
		btn_focus = 0
	if cfg_row == rows - 1:
		var bl := _buttons()
		if Inputs.any_just("left") != "":
			btn_focus = (btn_focus + bl.size() - 1) % bl.size()
		if Inputs.any_just("right") != "":
			btn_focus = (btn_focus + 1) % bl.size()
		if Input.is_action_just_pressed("start"):
			_cfg_confirm()
		elif _confirm_pressed():
			_press(String(bl[btn_focus]["id"]))
		return
	var dl := 0
	if Inputs.any_just("left") != "":
		dl = -1
	elif Inputs.any_just("right") != "":
		dl = 1
	if dl != 0:
		_cfg_adjust(dl)
	if _confirm_pressed():
		_cfg_confirm()


func _cfg_adjust(dl: int) -> void:
	var ar := _cfg_audio_row()
	if cfg_row == ar:
		Sfx.set_music_level(Sfx.music_lvl + dl)
		return
	if cfg_row == ar + 1:
		Sfx.set_sfx_level(Sfx.sfx_lvl + dl)
		Sfx.play("hit_medio")
		return
	if mode == "versus":
		match cfg_row:
			0:
				cfg_humans = clampi(cfg_humans + dl, 1, MAX_PLAYERS)
				if cfg_humans + cfg_cpus > MAX_PLAYERS:
					cfg_cpus = MAX_PLAYERS - cfg_humans
				if cfg_humans + cfg_cpus < 2:
					cfg_cpus = 2 - cfg_humans
			1:
				cfg_cpus = clampi(cfg_cpus + dl, 0, MAX_PLAYERS - 1)
				if cfg_humans + cfg_cpus > MAX_PLAYERS:
					cfg_humans = MAX_PLAYERS - cfg_cpus
				if cfg_humans + cfg_cpus < 2:
					cfg_humans = 2 - cfg_cpus
			2:
				cfg_level = clampi(cfg_level + dl, 1, 9)
			3:
				cfg_mode = wrapi(cfg_mode + dl, 0, GAME_MODES.size())
			4:
				cfg_inf = not cfg_inf
	else:
		train_ai = clampi(train_ai + dl, 0, 9)


func _cfg_confirm() -> void:
	Sfx.play("menu_ok")
	n_players = cfg_humans if mode == "versus" else 1
	slots.clear()
	connect_t = 0.0
	st = S.CONNECT


func _join(pf: String) -> void:
	if not slots.has(pf) and slots.size() < n_players:
		slots.append(pf)
		Sfx.play("menu_ok")


func _connect(delta: float) -> void:
	if Inputs.any_just("special") != "":
		Sfx.play("menu_voltar")
		_go_title()   # B / Bolinha / G: voltar
		return
	for pf in Inputs.prefixes:
		if Inputs.just(pf, "attack") or Inputs.just(pf, "jump"):
			_join(pf)
	if slots.size() >= n_players:
		connect_t += delta
		if connect_t > 0.9:
			if _is_tutorial():
				_start_tutorial()
			else:
				_start_select()


func _start_select() -> void:
	_clear_fighters()
	_clear_mut()
	Art.pal = Stages.palette(0)
	entries.clear()
	for i in slots.size():
		entries.append({"kind": "human", "prefix": slots[i], "label": "P%d" % (i + 1),
			"color": COLORS[i], "cursor": i * 3, "locked": false, "level": 0})
	if mode == "versus":
		for j in cfg_cpus:
			entries.append({"kind": "cpu", "prefix": slots[0], "label": "CPU %d (Nv %d)" % [j + 1, cfg_level],
				"color": COLORS[(slots.size() + j) % COLORS.size()], "cursor": randi() % 16, "locked": false,
				"level": cfg_level})
	else:
		entries.append({"kind": "dummy", "prefix": slots[0],
			"label": "BONECO" if train_ai == 0 else "CPU (Nv %d)" % train_ai,
			"color": Color("9aa5b8"), "cursor": 0, "locked": false, "level": train_ai})
	focus = 0
	sel_btn = -1
	msg.text = ""
	hint.text = ""
	st = S.SELECT


## Controle: o foco está na barra de botões (MENU / DESFAZER / LUTAR!) da seleção.
func _select_buttons() -> void:
	var bl := _buttons()
	sel_btn = clampi(sel_btn, 0, bl.size() - 1)
	if Input.is_action_just_pressed("start") and _all_locked():
		sel_btn = -1
		_go_stage()
		return
	if Inputs.any_just("left") != "":
		sel_btn = (sel_btn + bl.size() - 1) % bl.size()
	if Inputs.any_just("right") != "":
		sel_btn = (sel_btn + 1) % bl.size()
	if Inputs.any_just("up") != "" or Inputs.any_just("special") != "":
		sel_btn = -1
		return
	if Inputs.any_just("attack") != "" or Inputs.any_just("jump") != "":
		var id := String(bl[sel_btn]["id"])
		sel_btn = -1
		_press(id)


func _select() -> void:
	if sel_btn >= 0:
		_select_buttons()
		return
	var humans := 0
	for e in entries:
		if e["kind"] == "human":
			humans += 1
	var humans_locked := true
	for i in humans:
		if not entries[i]["locked"]:
			humans_locked = false
	# Humanos escolhem ao mesmo tempo; CPUs/boneco são escolhidos pelo P1, um de cada vez.
	var active := humans
	if humans_locked:
		for i in range(humans, entries.size()):
			active = i + 1
			if not entries[i]["locked"]:
				break
	for i in active:
		var e: Dictionary = entries[i]
		if e["locked"]:
			continue
		var pf: String = e["prefix"]
		var c: int = e["cursor"]
		var moved := false
		var up: bool = Inputs.just(pf, "up")
		var down: bool = Inputs.just(pf, "down")
		if c == RANDOM_ID:
			# da linha "ALEATÓRIO": cima volta para a última linha, baixo vai para a primeira
			var lc: int = int(e.get("lastcol", 0))
			if up:
				c = 12 + lc
				moved = true
			elif down:
				sel_btn = _buttons().size() - 1   # desce para a barra de botões
		else:
			var col := c % 4
			var row := c / 4
			if Inputs.just(pf, "left"):
				col = (col + 3) % 4
				moved = true
			if Inputs.just(pf, "right"):
				col = (col + 1) % 4
				moved = true
			e["lastcol"] = col
			if up:
				moved = true
				if row == 0:
					row = -1
				else:
					row -= 1
			elif down:
				moved = true
				if row == 3:
					row = -1
				else:
					row += 1
			c = RANDOM_ID if row == -1 else row * 4 + col
		if moved:
			e["cursor"] = c
			focus = i
		if Inputs.just(pf, "attack") or Inputs.just(pf, "jump"):
			_lock_entry(i)
	# Cancelar
	for i in entries.size():
		var e: Dictionary = entries[i]
		if e["kind"] != "human" or not e["locked"]:
			continue
		if Inputs.just(e["prefix"], "special") or Inputs.just(e["prefix"], "shield"):
			if i == 0:
				var last := -1
				for j in range(humans, entries.size()):
					if entries[j]["locked"]:
						last = j
				if last >= 0:
					entries[last]["locked"] = false
					continue
			e["locked"] = false
	var all_locked := true
	for e in entries:
		if not e["locked"]:
			all_locked = false
	if all_locked and Input.is_action_just_pressed("start"):
		_go_stage()
	elif all_locked and not entries.is_empty() and Inputs.just(entries[0]["prefix"], "down"):
		sel_btn = _buttons().size() - 1   # tudo travado: baixo foca a barra de botões


# ---------------------------------------------------------------- escolha do mapa

func _go_stage() -> void:
	st = S.STAGE
	hover_cell = -1


func _stage_select() -> void:
	var n := Stages.count() + 1
	var c := stage_sel
	if Inputs.any_just("left") != "":
		c = (c + n - 1) % n
	if Inputs.any_just("right") != "":
		c = (c + 1) % n
	if Inputs.any_just("up") != "" and c >= SG_COLS:
		c -= SG_COLS
	if Inputs.any_just("down") != "" and c + SG_COLS < n:
		c += SG_COLS
	stage_sel = c
	if _confirm_pressed():
		_start_match()
	elif Inputs.any_just("special") != "" or Inputs.any_just("shield") != "":
		Sfx.play("menu_voltar")
		st = S.SELECT


func _stage_cell_rect(i: int) -> Rect2:
	return Rect2(SG_ORIGIN + Vector2((i % SG_COLS) * SG_CELL.x, (i / SG_COLS) * SG_CELL.y) + Vector2(5, 5),
		SG_CELL - Vector2(10, 10))


func _stage_cell_at(p: Vector2) -> int:
	for i in Stages.count() + 1:
		if _stage_cell_rect(i).has_point(p):
			return i
	return -1


func _clear_fighters() -> void:
	for f in fighters:
		if is_instance_valid(f):
			f.queue_free()
	fighters.clear()
	items.clear()
	for p in get_tree().get_nodes_in_group("projectiles"):
		p.queue_free()


## Posição do centro do lutador para ficar em pé sobre um ponto de nascimento (pé).
func _spawn_pos(f: Node, feet: Vector2) -> Vector2:
	var sy := Art.surface_below(feet.x, feet.y - 10.0)   # encaixa no topo real (plataformas têm 6 px acima do centro)
	if sy < 0.0:
		sy = feet.y
	return Vector2(feet.x, sy - f.body.y / 2.0 - 1.0)


## Pontos de nascimento da partida atual (treino e tutorial usam os dois do meio).
func _spawns(n: int) -> Array:
	if mode != "versus":
		var sp: Array = Stages.get_stage(stage_id)["spawns"]
		return [sp[1], sp[3]]
	return Stages.spawn_points(stage_id, n)


func _load_stage(id: int, pal: int) -> void:
	stage_id = id
	pal_id = pal
	Art.pal = Stages.palette(pal)
	if Stages.is_proc(id):
		Stages.regenerate()   # mapa procedural: novo layout a cada partida
	stage.load_stage(id)


func _start_match(next_round := false) -> void:
	Sfx.play("menu_ok")
	_clear_fighters()
	if not next_round:
		rule = RULES[cfg_mode] if mode == "versus" else "classic"
		wins.clear()
		_reset_cheats()
		inf_run = cfg_inf and mode == "versus"
	var sid := randi() % Stages.count() if stage_sel == 0 else stage_sel - 1
	if next_round:   # Partida Infinita: cada rodada muda de mapa, de cores e de música
		Sfx.next_battle()
		while Stages.count() > 1 and sid == stage_id:
			sid = randi() % Stages.count()
	_load_stage(sid, Stages.random_palette())
	var n := entries.size()
	var sp := _spawns(n)
	for i in n:
		var e: Dictionary = entries[i]
		var f = FighterScript.new()
		var pf := ""
		if e["kind"] == "human":
			pf = e["prefix"]
		f.setup(i + 1, pf, e["cursor"], e["color"])
		if e["kind"] == "cpu" or (e["kind"] == "dummy" and int(e["level"]) > 0):
			f.setup_ai(int(e["level"]))
		f.infinite = mode == "training"
		f.position = _spawn_pos(f, sp[i])
		f.facing = 1 if f.position.x < 640.0 else -1
		f.move_used.connect(_on_move_used)
		add_child(f)
		fighters.append(f)
	_setup_rule()
	_ach_start()
	feed.clear()
	if mode == "versus" and rule != "classic":
		feed.append({"text": "Modo: %s" % GAME_MODES[RULES.find(rule)], "color": GOLD, "t": -2.0})
	var sd := Stages.get_stage(stage_id)
	feed.append({"text": "Mapa: %s" % sd["name"], "color": GOLD, "t": -2.0})
	if bool(sd.get("proc", false)):
		feed.append({"text": "Agora: %s" % String(sd["hz_text"]).split("Agora: ")[1].trim_suffix("."), "color": GOLD, "t": -2.0})
	feed.append({"text": "Cores: %s" % Art.pal["name"], "color": GOLD, "t": -2.0})
	st = S.FIGHT
	msg.text = ""
	hint.text = ""


func _start_tutorial() -> void:
	_clear_fighters()
	_load_stage(0, 0)
	var sp := _spawns(2)
	var pl = FighterScript.new()
	pl.setup(1, slots[0], 0, COLORS[0])
	var du = FighterScript.new()
	du.setup(2, "", 0, Color("9aa5b8"))
	for i in 2:
		var f = [pl, du][i]
		f.infinite = true
		f.position = _spawn_pos(f, sp[i])
		f.facing = 1 if i == 0 else -1
		f.move_used.connect(_on_move_used)
		add_child(f)
		fighters.append(f)
	feed.clear()
	tut = TutorialScript.new()
	tut.setup(pl, du, 1 if mode == "tutorial1" else 2, Inputs.hints(slots[0]))
	st = S.FIGHT


func _fight(delta: float) -> void:
	if _is_tutorial():
		if Input.is_action_just_pressed("start"):
			if tut.done:
				_go_title()
				return
			tut.skip()
		tut.update(delta)
		if tut.done:
			Ach.set_max("tut%d" % tut.kind, 1.0)
		msg.add_theme_font_size_override("font_size", 24)
		msg.position.y = 8.0
		msg.add_theme_color_override("font_color", Color("2ecc71") if (tut.flash > 0.0 or tut.done) else Color.WHITE)
		if tut.flash > 0.0:
			msg.text = tut.title() + "\nPasso concluído!"
		else:
			msg.text = tut.title() + "\n" + tut.text()
		hint.text = "START/OPTIONS ou ESC: pausa (pular passo, configurações, sair)"
		return
	msg.add_theme_color_override("font_color", Color.WHITE)
	if mode == "training":
		if Input.is_action_just_pressed("start"):
			_training_reset()
		var d = fighters[1]
		msg.text = "TREINO  |  START/OPTIONS ou ESC: pausa (zerar, configurações, sair)\n" \
			+ "Último golpe: %.1f%%   Combo: %d hits / %.1f%%" % [d.last_hit_dmg, d.combo_hits, d.combo_dmg]
		msg.position.y = 12.0
		msg.add_theme_font_size_override("font_size", 22)
		return
	var alive: Array = []
	var humans_alive := 0
	var humans_total := 0
	for f in fighters:
		if f.ai == null:
			humans_total += 1
		if not f.eliminated:
			alive.append(f)
			if f.ai == null:
				humans_alive += 1
	# Sem humanos vivos = derrota (só vale se havia algum humano na partida)
	var humans_out := false  # a partida só termina quando sobra 1 lutador
	_rules_tick(delta)
	if round_over:   # Partida Infinita: espera um pouco e começa a próxima rodada
		round_t -= delta
		hint.text = "Próxima rodada em %d...   |   ESC/SELECT: menu" % ceili(maxf(round_t, 0.0))
		if round_t <= 0.0:
			_start_match(true)
		return
	if rule == "hunt":
		if hunt_t <= 0.0:
			_end_hunt()
		return
	if alive.size() <= 1 and inf_run:
		if alive.is_empty():
			_round_end(null, "EMPATE!")
		else:
			_round_end(alive[0], "%s VENCEU!" % _who(alive[0]))
		return
	if alive.size() <= 1:
		st = S.OVER
		btn_focus = 0
		for f2 in fighters:
			f2.input_locked = true
		_set_poses(alive[0] if not alive.is_empty() else null)
		if not alive.is_empty():
			_ach_win(alive[0])
		_ach_match_end()
		Sfx.play("derrota" if (humans_out or alive.is_empty()) else "vitoria")
		var text := "Ninguém venceu"
		if humans_out and not alive.is_empty():
			text = "DERROTA — %s venceu" % _who(alive[0])
		elif not alive.is_empty():
			text = "%s VENCEU!" % _who(alive[0])
		msg.position.y = 90.0
		msg.add_theme_font_size_override("font_size", 40)
		msg.text = text + "\n\nENTER/START: escolher personagens   |   ESC/SELECT: menu"


# ---------------------------------------------------------------- modos de jogo e mutadores

## Prepara a regra do modo escolhido logo depois de criar os lutadores.
func _setup_rule() -> void:
	round_over = false
	round_t = 0.0
	hunt_t = 90.0
	chaos_t = 8.0
	banner = ""
	banner_t = 0.0
	_clear_mut()
	items.rate = 1.0
	stage.rate = 1.0
	match rule:
		"frantic":
			for f in fighters:
				f.run_mult = 1.25
				f.jump_mult = 1.1
				f.dmg_taken = 1.4
				f.kb_taken = 1.15
				f.atk_speed = 1.2
				f.respawn_time = 0.8
				f.respawn_inv = 1.5
				f.regen_mult = 1.7
				f.ult_rate = 1.6
				if f.ai != null:
					f.ai.p["interval"] = float(f.ai.p["interval"]) * 0.7
					f.ai.p["aggr"] = minf(float(f.ai.p["aggr"]) * 1.2, 1.0)
			items.rate = 2.5
			stage.rate = 1.3
			_banner("FRENÉTICO", "Tudo mais rápido, mais itens, mais perigo!")
		"sudden":
			for f in fighters:
				f.stocks = 1
				f.percent = 100.0
			_banner("MORTE SÚBITA", "1 vida e 100% de dano!")
			Sfx.play("morte_subita")
		"mutators":
			_apply_mut(randi() % MUTATORS.size())
		"hunt":
			for f in fighters:
				f.infinite = true
			_banner("CAÇA AOS KOs", "90 segundos: quem nocautear mais vence!")
		"chaos":
			_banner("CAOS", "A cada 15 segundos, um mutador novo!")
	if inf_run and rule == "classic":
		_banner("PARTIDA INFINITA", "Ganhou a rodada? Mapa, cores e música mudam!")


func _banner(title: String, sub: String) -> void:
	banner = "%s\n%s" % [title, sub]
	banner_t = 3.0


## Desliga qualquer mutador (volta a gravidade, atrito, filtro e flags dos lutadores ao normal).
func _clear_mut() -> void:
	mut_cur = -1
	wind_cur = 0.0
	wind_parts.clear()
	Art.grav = 1.0
	Art.fric = 1.0
	if gb_rect != null:
		gb_rect.visible = false
	for f in fighters:
		f.dmg_taken = 1.0
		f.push_only = false
		f.swap_ctl = false
		f.invis_mode = false
		f.wind_force = 0.0
		f.run_mult = 1.0
		f.max_mana = f.MAX_MANA
		f.mana = minf(f.mana, f.max_mana)


func _apply_mut(i: int) -> void:
	_clear_mut()
	mut_cur = i
	var m: Dictionary = MUTATORS[i]
	Ach.mark("muts", m["id"])
	match String(m["id"]):
		"lowgrav":
			Art.grav = 0.42
		"dmg2":
			for f in fighters:
				f.dmg_taken = 2.0
		"slip":
			Art.fric = 0.12
		"push":
			for f in fighters:
				f.push_only = true
		"wind":
			wind_t = WIND_PERIOD
			wind_dir = 1.0 if randf() < 0.5 else -1.0
			wind_cur = wind_dir * WIND_F
			wind_warned = false
			wind_parts.clear()
			for f in fighters:
				f.wind_force = wind_cur
		"mana":
			for f in fighters:
				f.max_mana = 250.0
				f.mana = 250.0
		"invis":
			for f in fighters:
				f.invis_mode = true
		"run":
			for f in fighters:
				f.run_mult = 2.0
		"gameboy":
			gb_rect.visible = true
		"swap":
			for f in fighters:
				f.swap_ctl = true
	_banner("MUTADOR: %s" % m["name"], String(m["desc"]))
	Sfx.play("mutador")


## Relógio dos modos: vento, caos e a contagem da Caça aos KOs.
func _rules_tick(delta: float) -> void:
	if banner_t > 0.0 and not round_over:
		banner_t -= delta
		msg.position.y = 90.0
		msg.add_theme_font_size_override("font_size", 38)
		msg.text = banner if banner_t > 0.0 else ""
	if mut_cur >= 0 and String(MUTATORS[mut_cur]["id"]) == "wind":
		wind_t -= delta
		if wind_t < 2.0 and not wind_warned:   # aviso antes de virar
			wind_warned = true
			feed.append({"text": "Atenção: o vento vai mudar!", "color": Color("ff9a3d"), "t": 0.0})
			Sfx.play("vento_vira", 0.8)
		if wind_t <= 0.0:
			wind_t = WIND_PERIOD
			wind_dir = -wind_dir
			wind_warned = false
			feed.append({"text": "Vento para %s" % ("a direita >>" if wind_dir > 0.0 else "<< a esquerda"),
				"color": GOLD, "t": 0.0})
		wind_cur = move_toward(wind_cur, wind_dir * WIND_F, WIND_F * 0.9 * delta)   # vira devagar (~1,5 s)
		for f in fighters:
			f.wind_force = wind_cur
		_wind_particles(delta)
	if rule == "chaos":
		chaos_t -= delta
		if chaos_t <= 0.0:
			chaos_t = 15.0
			var nxt := randi() % MUTATORS.size()
			while nxt == mut_cur:
				nxt = randi() % MUTATORS.size()
			_apply_mut(nxt)
	if rule == "hunt":
		var sec_before := ceili(hunt_t)
		hunt_t = maxf(hunt_t - delta, 0.0)
		# tique-taque nos últimos 10 segundos (mais forte nos 3 finais) e apito no fim
		if ceili(hunt_t) < sec_before and not round_over:
			if hunt_t <= 0.0:
				Sfx.play("apito")
			elif sec_before <= 10:
				Sfx.play("relogio", 1.0 if sec_before <= 3 else 0.6)


## Partículas do vento: riscos brancos que cruzam a tela na direção (e força) do vento.
func _wind_particles(delta: float) -> void:
	var k := absf(wind_cur) / WIND_F
	if k > 0.05 and randf() < delta * 70.0 * k:
		var dir := signf(wind_cur)
		wind_parts.append({"p": Vector2(-40.0 if dir > 0.0 else 1320.0, randf_range(30.0, 570.0)),
			"v": dir * randf_range(650.0, 1100.0) * (0.5 + k * 0.5), "l": randf_range(30.0, 90.0)})
	for w in wind_parts.duplicate():
		w["p"] = (w["p"] as Vector2) + Vector2(float(w["v"]) * delta, sin(anim_t * 3.0 + float(w["l"])) * 14.0 * delta)
		if (w["p"] as Vector2).x < -120.0 or (w["p"] as Vector2).x > 1400.0:
			wind_parts.erase(w)


func _draw_wind(c: Node2D) -> void:
	for w in wind_parts:
		var p: Vector2 = w["p"]
		var s := signf(float(w["v"]))
		var l := float(w["l"])
		c.draw_line(p, p - Vector2(s * l, 0.0), Color(1, 1, 1, 0.22), 4.0, true)
		c.draw_line(p, p - Vector2(s * l * 0.7, 0.0), Color(1, 1, 1, 0.5), 2.0, true)


## Partida Infinita: fim de uma rodada (mostra o vencedor; a próxima começa sozinha).
func _round_end(winner: Node, text: String) -> void:
	round_over = true
	round_t = 3.5
	for f in fighters:
		f.input_locked = true
	_set_poses(winner)
	if winner != null:
		var wi := fighters.find(winner)
		wins[wi] = int(wins.get(wi, 0)) + 1
		_ach_win(winner)
		if _is_human(winner):
			Ach.add("inf_rounds")
	Sfx.play("vitoria")
	msg.position.y = 90.0
	msg.add_theme_font_size_override("font_size", 46)
	msg.text = text


func _end_hunt() -> void:
	var best := -1
	var tie := false
	for f in fighters:
		if f.kos > best:
			best = f.kos
			tie = false
		elif f.kos == best:
			tie = true
	var text := "EMPATE com %d KOs!" % best
	var champ: Node = null
	if not tie:
		for f in fighters:
			if f.kos == best:
				text = "%s VENCEU com %d KOs!" % [_who(f), best]
				champ = f
	if inf_run:
		_round_end(champ, text)
		return
	st = S.OVER
	btn_focus = 0
	for f2 in fighters:
		f2.input_locked = true
	_set_poses(champ)
	if champ != null:
		_ach_win(champ)
	_ach_match_end()
	Sfx.play("vitoria")
	msg.position.y = 90.0
	msg.add_theme_font_size_override("font_size", 40)
	msg.text = text + "\n\nENTER/START: escolher personagens   |   ESC/SELECT: menu"


func _who(f: Node) -> String:
	var who := "P%d" % f.pid
	if f.ai != null:
		who = "CPU Nv%d" % f.ai.level
	elif f.prefix == "":
		who = "BONECO"
	return "%s (%s)" % [who, f.cdata["name"]]


func _training_reset() -> void:
	var sp := _spawns(fighters.size())
	for i in fighters.size():
		var f = fighters[i]
		f.reset_state()
		f.global_position = _spawn_pos(f, sp[mini(i, sp.size() - 1)])
		f.visible = true
		f.respawn_t = 0.0


# ---------------------------------------------------------------- mouse

func _title_rect(i: int) -> Rect2:
	return Rect2(350, 306.0 + i * 58.0 - 26.0, 580, 52)


## Primeira das duas linhas de áudio (música, efeitos), depois das linhas da partida.
func _cfg_audio_row() -> int:
	return 5 if mode == "versus" else 1


func _cfg_row_count() -> int:
	return _cfg_audio_row() + 2


func _cfg_row_y(i: int) -> float:
	return (214.0 + i * 52.0) if mode == "versus" else (290.0 + i * 66.0)


func _cfg_row_rect(i: int) -> Rect2:
	return Rect2(300, _cfg_row_y(i) - 40.0, 680, 50 if mode == "versus" else 62)


func _cell_at(p: Vector2) -> int:
	if RANDOM_RECT.has_point(p):
		return RANDOM_ID
	var q := p - GRID_ORIGIN
	if q.x < 0.0 or q.y < 0.0 or q.x >= CELL.x * 4.0 or q.y >= CELL.y * 4.0:
		return -1
	return int(q.y / CELL.y) * 4 + int(q.x / CELL.x)


func _all_locked() -> bool:
	for e in entries:
		if not e["locked"]:
			return false
	return not entries.is_empty()


## Quantas entradas da seleção estão ativas agora (humanos juntos; CPUs/boneco depois, um por vez).
func _active_entries() -> int:
	var humans := 0
	for e in entries:
		if e["kind"] == "human":
			humans += 1
	var humans_locked := true
	for i in humans:
		if not entries[i]["locked"]:
			humans_locked = false
	var active := humans
	if humans_locked:
		for i in range(humans, entries.size()):
			active = i + 1
			if not entries[i]["locked"]:
				break
	return active


func _select_click(c: int) -> void:
	var act := _active_entries()
	for i in act:
		var e: Dictionary = entries[i]
		if not e["locked"]:
			e["cursor"] = c
			_lock_entry(i)
			return


## Confirma a escolha de uma entrada. Se o cursor está em "ALEATÓRIO", sorteia o personagem agora.
func _lock_entry(i: int) -> void:
	var e: Dictionary = entries[i]
	e["rand"] = int(e["cursor"]) == RANDOM_ID
	if e["rand"]:
		e["cursor"] = randi() % 16
	e["locked"] = true
	focus = i
	Sfx.play("personagem")
	if i + 1 < entries.size() and entries[i + 1]["kind"] != "human":
		entries[i + 1]["cursor"] = e["cursor"]


func _select_back() -> void:
	for i in range(entries.size() - 1, -1, -1):
		if entries[i]["locked"]:
			entries[i]["locked"] = false
			focus = i
			return


## Botões clicáveis da tela atual (também desenhados por _draw_buttons).
func _buttons() -> Array:
	var b: Array = []
	match st:
		S.CONFIG:
			b.append({"id": "cfg_ok", "rect": Rect2(500, 600, 280, 54), "text": "CONTINUAR", "hint": "A", "main": true})
			b.append({"id": "back", "rect": Rect2(40, 628, 200, 48), "text": "VOLTAR", "hint": "Esc/Select"})
		S.CONNECT:
			b.append({"id": "back", "rect": Rect2(40, 628, 200, 48), "text": "VOLTAR", "hint": "B"})
		S.SELECT:
			b.append({"id": "back", "rect": Rect2(684, 632, 172, 48), "text": "MENU", "hint": "Esc/Select"})
			b.append({"id": "undo", "rect": Rect2(866, 632, 160, 48), "text": "DESFAZER", "hint": "B"})
			if _all_locked():
				b.append({"id": "fight", "rect": Rect2(1036, 626, 218, 58), "text": "MAPA", "hint": "Start", "main": true})
		S.STAGE:
			b.append({"id": "to_select", "rect": Rect2(40, 632, 220, 48), "text": "PERSONAGENS", "hint": "B"})
			b.append({"id": "fight_stage", "rect": Rect2(1036, 626, 218, 58), "text": "LUTAR!", "hint": "A", "main": true})
		S.ACH:
			b.append({"id": "back", "rect": Rect2(40, 628, 200, 48), "text": "VOLTAR", "hint": "Esc/Select"})
		S.FIGHT:
			if paused:
				return b
			b.append({"id": "pause", "rect": Rect2(1050, 90, 210, 40), "text": "PAUSA", "hint": "Start"})
			if _is_tutorial() and tut != null:
				b.append({"id": "skip", "rect": Rect2(1050, 136, 210, 40), "text": "FIM" if tut.done else "PULAR PASSO", "hint": "mouse"})
			elif mode == "training":
				b.append({"id": "reset", "rect": Rect2(1050, 136, 210, 40), "text": "ZERAR", "hint": "mouse"})
		S.OVER:
			b.append({"id": "again", "rect": Rect2(400, 400, 480, 60), "text": "ESCOLHER PERSONAGENS", "hint": "Start", "main": true})
			b.append({"id": "back", "rect": Rect2(400, 480, 480, 60), "text": "MENU", "hint": "Esc/Select"})
	return b


func _press(id: String) -> void:
	if id in ["back", "undo", "to_select"]:
		Sfx.play("menu_voltar")
	elif id != "cfg_ok" and id != "fight_stage":
		Sfx.play("menu_ok")
	match id:
		"pause":
			_open_pause()
		"back":
			_go_title()
		"cfg_ok":
			_cfg_confirm()
		"undo":
			_select_back()
		"fight":
			if _all_locked():
				_go_stage()
		"to_select":
			st = S.SELECT
		"fight_stage":
			_start_match()
		"again":
			_start_select()
		"skip":
			if tut != null:
				if tut.done:
					_go_title()
				else:
					tut.skip()
		"reset":
			_training_reset()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse = get_local_mouse_position()
		hover_cell = _cell_at(mouse) if st == S.SELECT else -1
		if paused and st == S.FIGHT:
			for i in _pause_items().size():
				if _pause_rect(i).has_point(mouse):
					pause_sel = i
		match st:
			S.TITLE:
				for i in TITLE_OPTS.size():
					if _title_rect(i).has_point(mouse):
						title_sel = i
			S.CONFIG:
				for i in _cfg_row_count():
					if _cfg_row_rect(i).has_point(mouse):
						cfg_row = i
			S.STAGE:
				var c := _stage_cell_at(mouse)
				if c >= 0:
					stage_sel = c
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			mouse = get_local_mouse_position()
			_click(mouse, mb.button_index)


func _click(pos: Vector2, btn: int) -> void:
	if paused and st == S.FIGHT:
		_pause_click(pos, btn)
		return
	if btn == MOUSE_BUTTON_WHEEL_UP or btn == MOUSE_BUTTON_WHEEL_DOWN:
		if st == S.ACH:
			ach_row = clampi(ach_row + (-1 if btn == MOUSE_BUTTON_WHEEL_UP else 1), 0, _ach_max_row())
		if st == S.CONFIG:
			for i in _cfg_row_count():
				if _cfg_row_rect(i).has_point(pos):
					cfg_row = i
					_cfg_adjust(1 if btn == MOUSE_BUTTON_WHEEL_UP else -1)
		return
	if btn == MOUSE_BUTTON_RIGHT:
		if st == S.SELECT:
			_select_back()
		elif st == S.STAGE:
			st = S.SELECT
		return
	if btn != MOUSE_BUTTON_LEFT:
		return
	for b in _buttons():
		if (b["rect"] as Rect2).has_point(pos):
			_press(String(b["id"]))
			return
	match st:
		S.TITLE:
			for i in TITLE_OPTS.size():
				if _title_rect(i).has_point(pos):
					title_sel = i
					_title_confirm()
					return
		S.CONFIG:
			for i in _cfg_row_count():
				if _cfg_row_rect(i).has_point(pos):
					cfg_row = i
					if pos.x >= 690.0 and pos.x < 780.0:
						_cfg_adjust(-1)
					elif pos.x >= 900.0 and pos.x < 990.0:
						_cfg_adjust(1)
					return
		S.CONNECT:
			# clicar num cartão livre conecta o teclado (Teclado 1, depois Teclado 2)
			var n := n_players
			var w := minf(260.0, (1200.0 - 20.0 * (n - 1)) / n)
			var x0 := 640.0 - (n * w + (n - 1) * 20.0) / 2.0
			for i in n:
				if i >= slots.size() and Rect2(x0 + i * (w + 20.0), 260, w, 230).has_point(pos):
					for pf in ["kb1", "kb2"]:
						if not slots.has(pf):
							_join(pf)
							break
					return
		S.SELECT:
			var c := _cell_at(pos)
			if c >= 0:
				_select_click(c)
		S.STAGE:
			var c2 := _stage_cell_at(pos)
			if c2 >= 0:
				stage_sel = c2
				_start_match()


func _draw_buttons() -> void:
	if paused and st == S.FIGHT:
		_draw_pause(btn_layer)
		return
	var list := _buttons()
	var foc := _focused_index()
	for i in list.size():
		var b: Dictionary = list[i]
		var r: Rect2 = b["rect"]
		var focused := i == foc
		var hot := r.has_point(mouse) or focused
		var primary: bool = b.get("main", false)
		var gold := primary or hot
		var fill := GOLD if gold else Color(0.06, 0.12, 0.25, 0.88)
		var txt := Color("14233f") if gold else Color.WHITE
		Art.rrect(btn_layer, r, r.size.y / 2.0, fill, Color.WHITE if hot else Color(1, 1, 1, 0.5),
			4.0 if focused else (3.0 if hot else 2.0), 10)
		var label := String(b["text"])
		var hint_txt := String(b.get("hint", ""))
		var size := 22 if r.size.y > 50.0 else 17
		if hint_txt != "":
			label += "  [%s]" % hint_txt
			size = 19 if r.size.y > 50.0 else 15
		var tp := Vector2(r.position.x, r.position.y + r.size.y / 2.0 + 7.0)
		btn_layer.draw_string_outline(Art.font(), tp, label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, size, maxi(size / 5, 3), Color(0.04, 0.07, 0.14, 0.9))
		btn_layer.draw_string(Art.font(), tp, label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, size, txt)
		if focused:
			var wob := sin(anim_t * 6.0) * 4.0
			Art.hand(btn_layer, Vector2(r.position.x - 18.0 + wob, r.position.y + r.size.y / 2.0), 11.0, GOLD, Color("14233f"))
	_draw_toasts()


## Aviso "conquista desbloqueada" no topo da tela (aparece em qualquer tela, inclusive durante a luta).
func _draw_toasts() -> void:
	var y := 12.0
	for t in Ach.toasts.slice(0, 3):
		var age := float(t["t"])
		var a := clampf(minf(age / 0.25, (4.5 - age) / 0.5), 0.0, 1.0)
		var r := Rect2(440.0, y - (1.0 - a) * 30.0, 400, 56)
		Art.rrect(btn_layer, r, 28.0, Color(0.18, 0.13, 0.03, 0.95 * a), Color(GOLD, a), 3.0, 8)
		Art.sparkle(btn_layer, r.position + Vector2(32, 28), 13.0, Color(GOLD, a), age * 2.0)
		var f := Art.font()
		var p := r.position
		btn_layer.draw_string(f, p + Vector2(60, 24), "CONQUISTA DESBLOQUEADA!", HORIZONTAL_ALIGNMENT_LEFT, 320.0, 14, Color(GOLD, a))
		btn_layer.draw_string_outline(f, p + Vector2(60, 46), String(t["name"]), HORIZONTAL_ALIGNMENT_LEFT, 320.0, 22, 4, Color(0.04, 0.07, 0.14, 0.9 * a))
		btn_layer.draw_string(f, p + Vector2(60, 46), String(t["name"]), HORIZONTAL_ALIGNMENT_LEFT, 320.0, 22, Color(1, 1, 1, a))
		y += 62.0


# ---------------------------------------------------------------- conquistas

func _ach_max_row() -> int:
	return maxi(ceili(float(Ach.LIST.size()) / ACH_COLS) - ACH_ROWS, 0)


func _ach_screen() -> void:
	var mx := _ach_max_row()
	if Inputs.any_just("down") != "":
		ach_row = mini(ach_row + 1, mx)
	if Inputs.any_just("up") != "":
		ach_row = maxi(ach_row - 1, 0)
	if Inputs.any_just("right") != "":
		ach_row = mini(ach_row + ACH_ROWS, mx)
	if Inputs.any_just("left") != "":
		ach_row = maxi(ach_row - ACH_ROWS, 0)


func _draw_ach() -> void:
	var n := Ach.LIST.size()
	var bottom := ACH_ORIGIN.y + ACH_ROWS * (ACH_CARD.y + ACH_GAP.y)
	for i in n:
		var y := ACH_ORIGIN.y + (float(i / ACH_COLS) - ach_scroll) * (ACH_CARD.y + ACH_GAP.y)
		if y < ACH_ORIGIN.y - ACH_CARD.y or y > bottom:
			continue
		_draw_ach_card(i, Vector2(ACH_ORIGIN.x + (i % ACH_COLS) * (ACH_CARD.x + ACH_GAP.x), y))
	# faixas de cima e de baixo escondem os cartões que rolam para fora
	draw_rect(Rect2(0, 0, 1280, ACH_ORIGIN.y - 6.0), Color(0.04, 0.08, 0.16, 1.0))
	draw_rect(Rect2(0, bottom - 2.0, 1280, 720.0 - bottom + 2.0), Color(0.04, 0.08, 0.16, 1.0))
	var got := Ach.count_unlocked()
	_tc("CONQUISTAS", 50, 40, GOLD)
	Art.rrect(self, Rect2(440, 66, 400, 16), 8.0, Color(0, 0, 0, 0.55), Color(1, 1, 1, 0.35), 1.5)
	var fw := 392.0 * got / float(n)
	if fw > 2.0:
		Art.rrect(self, Rect2(444, 70, fw, 8), 4.0, GOLD)
	_tc("%d / %d  (%d%%)" % [got, n, roundi(100.0 * got / n)], 96, 17, Color(1, 1, 1, 0.85))
	# barra de rolagem
	var track := Rect2(1264, ACH_ORIGIN.y, 6, bottom - ACH_ORIGIN.y - 10.0)
	Art.rrect(self, track, 3.0, Color(1, 1, 1, 0.12))
	var mx := _ach_max_row()
	if mx > 0:
		var th := track.size.y * ACH_ROWS / float(ACH_ROWS + mx)
		var ty := track.position.y + (track.size.y - th) * clampf(ach_scroll / mx, 0.0, 1.0)
		Art.rrect(self, Rect2(track.position.x, ty, 6, th), 3.0, GOLD)
	_tc("Cima/Baixo ou roda do mouse: rolar   |   Esq/Dir: página   |   Esc/Select: voltar", 700, 17, Color(1, 1, 1, 0.75))


func _draw_ach_card(i: int, pos: Vector2) -> void:
	var a: Dictionary = Ach.LIST[i]
	var done: bool = Ach.unlocked.has(a["id"])
	var r := Rect2(pos, ACH_CARD)
	Art.rrect(self, r, 16.0, Color(0.2, 0.15, 0.04, 0.94) if done else Color(0.06, 0.1, 0.2, 0.88),
		GOLD if done else Color(1, 1, 1, 0.16), 2.5 if done else 2.0)
	var mc := pos + Vector2(32, 31)
	draw_circle(mc, 21.0, GOLD if done else Color(0.22, 0.27, 0.38))
	draw_circle(mc, 16.0, Color(1.0, 0.93, 0.55) if done else Color(0.12, 0.16, 0.26))
	if done:
		Art.sparkle(self, mc, 12.0, Color("14233f"), 0.0)
	else:
		var gc := Color(0.5, 0.56, 0.68)
		draw_arc(mc + Vector2(0, -3), 5.0, PI, TAU, 10, gc, 2.5)
		draw_rect(Rect2(mc.x - 7.0, mc.y - 3.0, 14.0, 11.0), gc)
	var goal := Ach.goal_of(a)
	var val := Ach.value_of(a)
	_to(String(a["name"]), pos + Vector2(66, 24), 19, GOLD if done else Color(1, 1, 1, 0.85),
		HORIZONTAL_ALIGNMENT_LEFT, 250.0 if goal > 1 and not done else 316.0)
	_t(String(a["desc"]), pos + Vector2(66, 43), 14, Color(1, 1, 1, 0.9 if done else 0.6), HORIZONTAL_ALIGNMENT_LEFT, 316.0)
	if goal > 1 and not done:
		var frac := clampf(val / goal, 0.0, 1.0)
		_t("%d/%d" % [int(minf(val, goal)), goal], pos + Vector2(ACH_CARD.x - 84, 22), 14, Color(1, 1, 1, 0.7),
			HORIZONTAL_ALIGNMENT_RIGHT, 72.0)
		Art.rrect(self, Rect2(pos.x + 66, pos.y + 50, 316, 7), 3.5, Color(0, 0, 0, 0.5))
		if frac > 0.02:
			Art.rrect(self, Rect2(pos.x + 66, pos.y + 50, 316.0 * frac, 7), 3.5, Color("e8884a"))


## Acompanha os contadores dos humanos a cada quadro (diferenças desde o quadro anterior).
func _ach_tick(delta: float) -> void:
	if cheats_used:
		return   # partida com trapaça não conta para as conquistas
	if _is_tutorial() or fighters.is_empty():
		return
	_ach_acc += delta
	if _ach_acc >= 1.0:
		Ach.add("playtime", _ach_acc)
		if mode == "training":
			Ach.add("train_time", _ach_acc)
		_ach_acc = 0.0
	var versus := mode == "versus"
	for v in fighters:
		if not is_instance_valid(v):
			continue
		var la = v.last_attacker
		if la != null and is_instance_valid(la) and _is_human(la):
			Ach.set_max("combo_max", float(v.combo_hits))
		if not _is_human(v):
			continue
		var cur := {
			"hits": v.hits_landed, "dmg": v.dmg_dealt, "kos": v.kos, "sd": v.sd_count,
			"throws": v.throw_count, "counters": v.counter_count, "air": v.air_jumps,
			"drops": v.plat_drops, "item": v.held_item != "", "ff": v.fast_falling,
			"nm": v.no_mana_t > 0.0, "ult": v.ult_cd,
		}
		var p: Dictionary = _ach_prev.get(v.get_instance_id(), cur)
		_ach_prev[v.get_instance_id()] = cur
		if int(cur["hits"]) > int(p["hits"]):
			Ach.add("hits_total", int(cur["hits"]) - int(p["hits"]))
			Ach.add("dmg_total", float(cur["dmg"]) - float(p["dmg"]))
		if versus:
			if int(cur["kos"]) > int(p["kos"]):
				Ach.add("kos_total", int(cur["kos"]) - int(p["kos"]))
			if int(cur["sd"]) > int(p["sd"]):
				Ach.add("sd_total", int(cur["sd"]) - int(p["sd"]))
			Ach.set_max("ko_match" if rule != "hunt" else "hunt_best", float(v.kos))
			if not v.eliminated and v.respawn_t <= 0.0:
				Ach.set_max("survive_pct", v.percent)
		if int(cur["throws"]) > int(p["throws"]):
			Ach.add("throws", int(cur["throws"]) - int(p["throws"]))
		if int(cur["counters"]) > int(p["counters"]):
			Ach.add("counters", int(cur["counters"]) - int(p["counters"]))
		if int(cur["air"]) > int(p["air"]):
			Ach.add("air_total", int(cur["air"]) - int(p["air"]))
		if int(cur["drops"]) > int(p["drops"]):
			Ach.add("drops", int(cur["drops"]) - int(p["drops"]))
		if bool(cur["item"]) and not bool(p["item"]):
			Ach.add("items")
		if bool(cur["ff"]) and not bool(p["ff"]):
			Ach.add("fastfall")
		if bool(cur["nm"]) and not bool(p["nm"]):
			Ach.add("nomana")
		if float(cur["ult"]) > float(p["ult"]) + 0.5:
			Ach.add("ult_total")


func _is_human(f: Node) -> bool:
	return f.ai == null and f.prefix != ""


## Chamado ao começar a partida (Versus ou Treino): registra personagens, mapa e tamanho da briga.
func _ach_start() -> void:
	_ach_prev.clear()
	_ach_acc = 0.0
	Ach.mark("stages", stage_id)
	if Stages.is_proc(stage_id):
		Ach.add("proc")
	if mode == "versus":
		Ach.set_max("fighters_max", float(fighters.size()))
	for f in fighters:
		if _is_human(f):
			Ach.mark("chars", f.char_id)


func _ach_win(w: Node) -> void:
	if cheats_used:
		return   # partida com trapaça não conta para as conquistas
	if mode != "versus" or not _is_human(w):
		return
	Ach.add("wins")
	Ach.mark("win_chars", w.char_id)
	Ach.add("win_" + rule)
	var idx := fighters.find(w)
	if idx >= 0 and idx < entries.size() and bool(entries[idx].get("rand", false)):
		Ach.add("win_random")
	if rule != "sudden" and rule != "hunt":
		if w.stocks >= FighterScript.START_STOCKS:
			Ach.add("win_flawless")
		elif w.stocks == 1:
			Ach.add("win_last")
	if w.percent >= 150.0:
		Ach.add("win_hurt")
	var best := 0
	for f in fighters:
		if f.ai != null:
			best = maxi(best, int(f.ai.level))
	if best > 0:
		Ach.set_max("beat_cpu", float(best))
	if fighters.size() >= 6:
		Ach.add("win_six")


func _ach_match_end() -> void:
	if cheats_used:
		return   # partida com trapaça não conta para as conquistas
	if mode != "versus":
		return
	Ach.add("matches")
	var humans := 0
	for f in fighters:
		if _is_human(f):
			humans += 1
	if humans >= 2:
		Ach.add("mp_matches")
	Ach.flush()


# ---------------------------------------------------------------- HUD

## Retângulo do painel do jogador i quando há n lutadores (4 ou menos: painéis largos; 5-6: mais estreitos).
func _hud_slot(i: int, n: int) -> Rect2:
	n = maxi(n, 1)
	var gap := 20.0 if n <= 4 else 8.0
	var pw := minf(290.0, (1240.0 - gap * (n - 1)) / n)
	var x0 := (1280.0 - (n * pw + (n - 1) * gap)) / 2.0
	return Rect2(x0 + i * (pw + gap), 586.0, pw, 106.0)


func _update_hud() -> void:
	var n_now := fighters.size() if _in_match() else 0
	if n_now != _hud_n:
		_hud_n = n_now
		for k in MAX_PLAYERS:
			var sl := _hud_slot(k, maxi(n_now, 1))
			hud_labels[k].position = Vector2(sl.position.x + 10.0, 592.0)
			hud_labels[k].size = Vector2(sl.size.x - 20.0, 64.0)
			hud_labels[k].add_theme_font_size_override("font_size", 22 if n_now <= 4 else 16)
			_hud_cache[k] = "x"   # força reescrever o texto
	for i in MAX_PLAYERS:
		var l := hud_labels[i]
		if not _in_match() or i >= fighters.size():
			if _hud_cache[i] != "":
				_hud_cache[i] = ""
				l.text = ""
			continue
		var f = fighters[i]
		var pct := int(f.percent)
		if int(_hud_col[i]) != pct:   # a cor só muda quando o dano muda
			_hud_col[i] = pct
			l.add_theme_color_override("font_color",
				Color.WHITE.lerp(Color("ff3030"), clampf(f.percent / 150.0, 0.0, 1.0)))
		var who := "P%d" % f.pid
		if f.ai != null:
			who = "CPU Nv%d" % f.ai.level
		elif f.prefix == "":
			who = "BONECO"
		elif mode != "versus":
			who = "VOCÊ"
		var txt: String
		if f.eliminated:
			txt = "%s %s\nELIMINADO" % [who, f.cdata["name"]]
		elif mode == "versus":
			var vit := "  Vit: %d" % int(wins.get(i, 0)) if inf_run else ""
			if rule == "hunt":
				txt = "%s %s\n%d%%   KOs: %d%s" % [who, f.cdata["name"], pct, f.kos, vit]
			else:
				txt = "%s %s\n%d%%  Vidas: %d%s" % [who, f.cdata["name"], pct, f.stocks, vit]
		else:
			txt = "%s %s\n%d%%" % [who, f.cdata["name"], pct]
		if txt != _hud_cache[i]:
			_hud_cache[i] = txt
			l.text = txt




# ---------------------------------------------------------------- desenho

const PANEL := Color(0.05, 0.09, 0.18, 0.82)
const GOLD := Color("f0c24a")


func _t(text: String, pos: Vector2, size := 24, col := Color.WHITE,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string(Art.font(), pos, text, align, width, size, col)


func _tc(text: String, y: float, size := 24, col := Color.WHITE) -> void:
	_to(text, Vector2(0, y), size, col, HORIZONTAL_ALIGNMENT_CENTER, 1280.0)


## Texto com contorno escuro (bom para ler sobre o cenário).
func _to(text: String, pos: Vector2, size := 24, col := Color.WHITE,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string_outline(Art.font(), pos, text, align, width, size, maxi(size / 5, 3), Color(0.04, 0.07, 0.14, 0.9))
	draw_string(Art.font(), pos, text, align, width, size, col)


func _draw() -> void:
	match st:
		S.TITLE:
			_draw_title()
		S.CONFIG:
			_draw_config()
		S.CONNECT:
			_draw_connect()
		S.SELECT:
			_draw_select()
		S.STAGE:
			_draw_stage_select()
		S.ACH:
			_draw_ach()
		_:
			_draw_feed()


## Painel de cada jogador: nome, dano, vidas e medidor de MANA.
func _draw_mana_bars() -> void:
	var c: Node2D = hud_panel
	if not wind_parts.is_empty() and st == S.FIGHT:
		_draw_wind(c)
	var in_fight := st != S.TITLE and st != S.CONFIG and st != S.CONNECT \
		and st != S.SELECT and st != S.STAGE and st != S.ACH
	if not in_fight:
		return
	for i in fighters.size():
		var f = fighters[i]
		var slot := _hud_slot(i, fighters.size())
		var x := slot.position.x
		var pw := slot.size.x
		Art.rrect(c, Rect2(x, 586, pw, 106), 22.0, Color(0.04, 0.08, 0.16, 0.82), Color(f.color, 0.95), 3.0, 8)
		if f.eliminated:
			continue
		var bx := x + 12.0
		var bw := pw - 24.0
		var by := 660.0
		var low: bool = f.no_mana_t > 0.0
		var col := Color(1.0, 0.3, 0.35) if low else Color(0.35, 0.72, 1.0)
		Art.rrect(c, Rect2(bx, by, bw, 20), 10.0, Color(0, 0, 0, 0.55))
		var mw: float = bw * f.mana / f.max_mana
		if mw > 2.0:
			Art.rrect(c, Rect2(bx, by, mw, 20), 10.0, col)
			Art.rrect(c, Rect2(bx + 4.0, by + 3.0, maxf(mw - 8.0, 0.0), 4.0), 2.0, Color(1, 1, 1, 0.35))
		Art.rrect(c, Rect2(bx, by, bw, 20), 10.0, Color(0, 0, 0, 0), Color(1, 1, 1, 0.5), 1.5)
		# Especial único (botão Y): barra de recarga
		var uy := by - 20.0
		var ready: bool = f.ult_cd <= 0.0 or f.power_orb
		var ucol := Color(0.35, 0.75, 1.0) if f.power_orb else (Color(1.0, 0.85, 0.2) if ready else Color(0.6, 0.55, 0.3))
		Art.rrect(c, Rect2(bx, uy, bw, 14), 7.0, Color(0, 0, 0, 0.55))
		var uw: float = bw if f.power_orb else bw * (1.0 - f.ult_cd / maxf(f.ult_max, 0.1))
		if uw > 2.0:
			Art.rrect(c, Rect2(bx, uy, uw, 14), 7.0, ucol)
		Art.rrect(c, Rect2(bx, uy, bw, 14), 7.0, Color(0, 0, 0, 0), Color(1, 1, 1, 0.5), 1.5)
		var utxt := "Y  SUPREMO!" if f.power_orb else ("Y  PRONTO!" if ready else "Y  %.1fs" % f.ult_cd)
		c.draw_string_outline(Art.font(), Vector2(bx, uy + 12), utxt, HORIZONTAL_ALIGNMENT_CENTER, bw, 12, 3, Color(0.04, 0.07, 0.14, 0.9))
		c.draw_string(Art.font(), Vector2(bx, uy + 12), utxt, HORIZONTAL_ALIGNMENT_CENTER, bw, 12, Color.WHITE)
		var txt := "MANA  %d / %d" % [int(f.mana), int(f.max_mana)]
		var tp := Vector2(bx, by + 16)
		c.draw_string_outline(Art.font(), tp, txt, HORIZONTAL_ALIGNMENT_CENTER, bw, 14, 3, Color(0.04, 0.07, 0.14, 0.9))
		c.draw_string(Art.font(), tp, txt, HORIZONTAL_ALIGNMENT_CENTER, bw, 14, Color.WHITE)


## Registro dos golpes: "P1 deu Soco leve". Fica na lateral esquerda e some sozinho.
func _draw_feed() -> void:
	if st == S.FIGHT and mode == "versus":
		if rule == "hunt":
			var tl := int(ceil(hunt_t))
			_tc("CAÇA AOS KOs   %d:%02d" % [tl / 60, tl % 60], 44, 28, GOLD)
		elif mut_cur >= 0 and String(MUTATORS[mut_cur]["id"]) == "wind":
			var arrows := ">>>" if wind_cur > 30.0 else ("<<<" if wind_cur < -30.0 else "...")
			if wind_t < 2.0 and int(anim_t * 5.0) % 2 == 0:
				_tc("ATENÇÃO: O VENTO VAI MUDAR!", 44, 28, Color("ff9a3d"))
			else:
				_tc("MUTADOR: VENTO   %s" % arrows, 44, 26, GOLD)
		elif mut_cur >= 0:
			_tc("MUTADOR: %s" % MUTATORS[mut_cur]["name"], 44, 26, GOLD)
	var y := 150.0
	for e in feed:
		var a := 1.0 - clampf((float(e["t"]) - 2.4) / 0.8, 0.0, 1.0)
		var col: Color = e["color"]
		var w := minf(Art.font().get_string_size(e["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 22.0, 340.0)
		Art.rrect(self, Rect2(10, y - 19, w, 26), 13.0, Color(0.04, 0.08, 0.16, 0.6 * a), Color(col, 0.8 * a), 2.0)
		draw_string(Art.font(), Vector2(21, y), e["text"], HORIZONTAL_ALIGNMENT_LEFT, 320.0, 17, Color(1, 1, 1, a))
		y += 31.0


func _draw_title() -> void:
	_title_word("SUPER", 60, 128.0, 0.0)
	_title_word("SMASH BALLS", 96, 224.0, 1.3)
	# Splash Text: amarelo, inclinado e pulsando
	if splash == "":
		splash = SPLASHES[randi() % SPLASHES.size()]
	var ps := 1.0 + 0.06 * sin(anim_t * 5.0)
	draw_set_transform(Vector2(640.0, 262.0), -0.05, Vector2(ps, ps))
	var sw := 1100.0
	draw_string_outline(Art.font(), Vector2(-sw * 0.5, 0), splash, HORIZONTAL_ALIGNMENT_CENTER, sw, 26, 5, Color(0.04, 0.07, 0.14, 0.9))
	draw_string(Art.font(), Vector2(-sw * 0.5, 0), splash, HORIZONTAL_ALIGNMENT_CENTER, sw, 26, GOLD)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# mãos gigantes flutuando dos dois lados do título
	var hc := [Color("e8884a"), Color("5aa9d6"), Color("6cc59a"), Color("e8c04a")]
	for k in 2:
		var s := -1.0 if k == 0 else 1.0
		var cx := 640.0 + s * 520.0
		Art.hand(self, Vector2(cx + s * 10.0, 150.0 + sin(anim_t * 1.8 + k) * 10.0), 38.0, hc[k], hc[k].darkened(0.55))
		Art.hand(self, Vector2(cx - s * 60.0, 235.0 + sin(anim_t * 2.2 + k * 2.0) * 10.0), 27.0, hc[k + 2], hc[k + 2].darkened(0.55))
	for k in 10:
		var sp := Vector2(120.0 + k * 118.0 + sin(k * 7.0) * 30.0, 70.0 + fposmod(k * 53.0, 190.0))
		Art.sparkle(self, sp, 7.0 + 5.0 * sin(anim_t * 3.0 + k), Color(1, 1, 0.8, 0.5 + 0.4 * sin(anim_t * 2.5 + k * 1.3)),
			anim_t * 0.5 + k)
	# opções
	for i in TITLE_OPTS.size():
		var sel := i == title_sel
		var label: String = TITLE_OPTS[i]
		if i == 0:
			label += " (jogadores e CPUs)"
		elif i == 4:
			label += "  %d/%d" % [Ach.count_unlocked(), Ach.LIST.size()]
		var cy := 306.0 + i * 58.0
		var sc := 1.0 + (0.035 * sin(anim_t * 6.0) if sel else 0.0)
		draw_set_transform(Vector2(640.0, cy), 0.0, Vector2(sc, sc))
		if sel:
			Art.rrect(self, Rect2(-290, -27, 580, 54), 27.0, GOLD, Color.WHITE, 3.0, 12, Color(1, 0.8, 0.3, 0.35), Vector2(0, 0))
			Art.rrect(self, Rect2(-280, -22, 560, 14), 7.0, Color(1, 1, 1, 0.35))
			_t(label, Vector2(-640, 13), 34, Color("14233f"), HORIZONTAL_ALIGNMENT_CENTER, 1280.0)
		else:
			Art.rrect(self, Rect2(-290, -27, 580, 54), 27.0, Color(0.06, 0.12, 0.25, 0.5), Color(1, 1, 1, 0.18), 2.0)
			_t(label, Vector2(-640, 12), 30, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER, 1280.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if sel:
			var wob := sin(anim_t * 5.0) * 6.0
			Art.hand(self, Vector2(330.0 + wob, cy), 15.0, GOLD, Color("14233f"))
			Art.hand(self, Vector2(950.0 - wob, cy), 15.0, GOLD, Color("14233f"))
	# desfile dos 16 personagens
	var chars := Chars.all()
	for i in 16:
		var cd: Dictionary = chars[i]
		var col: Color = cd["color"]
		Art.mascot(self, Vector2(40.0 + i * 80.0, 612.0), 34.0, col, col.darkened(0.55), anim_t, i * 0.55,
			1.0 if i % 2 == 0 else -1.0, 0, 6.0)
	_tc("Mouse: clique numa opção   |   Cima/Baixo + Ataque / A / Xis / Enter: confirmar   |   Esc/Select: voltar", 692, 18,
		Color(1, 1, 1, 0.8))


func _row(y: float, label: String, value: String, sel: bool) -> void:
	var rh := 50.0 if mode == "versus" else 62.0
	var r := Rect2(300, y - 40, 680, rh)
	if sel:
		Art.rrect(self, r, 31.0, GOLD, Color.WHITE, 3.0, 10)
		Art.rrect(self, Rect2(316, y - 36, 648, 12), 6.0, Color(1, 1, 1, 0.35))
		_t(label, Vector2(332, y), 28, Color("14233f"))
		_t(value, Vector2(740, y), 30, Color("1f4f8a"), HORIZONTAL_ALIGNMENT_CENTER, 200.0)
		var lhot := Rect2(690, y - 40.0, 90, rh).has_point(mouse)
		var rhot := Rect2(900, y - 40.0, 90, rh).has_point(mouse)
		_t("<", Vector2(716, y + 2.0), 40 if lhot else 34, Color("14233f") if lhot else Color("1f4f8a"))
		_t(">", Vector2(950, y + 2.0), 40 if rhot else 34, Color("14233f") if rhot else Color("1f4f8a"))
		var wob := sin(anim_t * 5.0) * 5.0
		Art.hand(self, Vector2(274.0 + wob, y - 15.0 + (rh - 50.0) * 0.5), 15.0, GOLD, Color("14233f"))
		Art.hand(self, Vector2(1006.0 - wob, y - 15.0 + (rh - 50.0) * 0.5), 15.0, GOLD, Color("14233f"))
	else:
		Art.rrect(self, r, 31.0, PANEL, Color(1, 1, 1, 0.15), 2.0)
		_t(label, Vector2(332, y), 28, Color(1, 1, 1, 0.65))
		_t(value, Vector2(740, y), 30, Color(1, 1, 1, 0.65), HORIZONTAL_ALIGNMENT_CENTER, 200.0)


func _draw_config() -> void:
	if mode == "versus":
		_tc("CONFIGURAR PARTIDA", 150, 56)
		_row(_cfg_row_y(0), "Jogadores humanos", str(cfg_humans), cfg_row == 0)
		_row(_cfg_row_y(1), "CPUs", str(cfg_cpus), cfg_row == 1)
		_row(_cfg_row_y(2), "Nível das CPUs (1 a 9)", str(cfg_level), cfg_row == 2)
		_row(_cfg_row_y(3), "Modo de jogo", GAME_MODES[cfg_mode], cfg_row == 3)
		_row(_cfg_row_y(4), "Partida Infinita", "Ligada" if cfg_inf else "Desligada", cfg_row == 4)
		_tc("Quem vence a rodada: mapa, cores e música mudam e todos lutam de novo." if cfg_row == 4 else MODE_DESC[cfg_mode], 566, 21, GOLD)
		_tc("Total: %d jogadores   |   CPUs: nível 1 = iniciante, 9 = muito difícil" % (cfg_humans + cfg_cpus), 590, 19,
			Color("8affb0"))
	else:
		_tc("TREINO", 150, 56)
		_row(_cfg_row_y(0), "Boneco", "Parado" if train_ai == 0 else "CPU nível %d" % train_ai, cfg_row == 0)
		_tc("O boneco pode ficar parado ou lutar de volta como CPU.", 520, 22, Color(1, 1, 1, 0.85))
	var ar := _cfg_audio_row()
	_row(_cfg_row_y(ar), "Música", "%d%%" % (Sfx.music_lvl * 10), cfg_row == ar)
	_row(_cfg_row_y(ar + 1), "Efeitos sonoros", "%d%%" % (Sfx.sfx_lvl * 10), cfg_row == ar + 1)
	var chars := Chars.all()
	for k in 2:
		var cd: Dictionary = chars[(k * 5 + 1) % 16]
		var col: Color = cd["color"]
		Art.mascot(self, Vector2(130.0 + k * 1020.0, 520.0), 70.0, col, col.darkened(0.55), anim_t, k * 2.0,
			1.0 if k == 0 else -1.0, 0, 14.0)
	_tc("Cima/Baixo: linha (desça até os botões)   |   Esquerda/Direita: valor   |   A/Xis/Enter: confirmar   |   Mouse: clique", 692, 17,
		Color(1, 1, 1, 0.8))


func _draw_connect() -> void:
	_tc("CONECTE OS JOGADORES" if n_players > 1 else "CONECTE SEU CONTROLE", 130, 56)
	_tc("Aperte ATAQUE no controle ou teclado (F = Teclado 1)   |   ou clique num cartão para usar o teclado", 190, 20,
		Color(1, 1, 1, 0.9))
	var n := n_players
	var w := minf(260.0, (1200.0 - 20.0 * (n - 1)) / n)
	var x0 := 640.0 - (n * w + (n - 1) * 20.0) / 2.0
	var chars := Chars.all()
	for i in n:
		var x := x0 + i * (w + 20.0)
		var ok := i < slots.size()
		Art.rrect(self, Rect2(x, 260, w, 230), 32.0, PANEL, COLORS[i] if ok else Color(1, 1, 1, 0.25), 5.0, 10)
		var lab := "P%d" % (i + 1) if n > 1 else "VOCÊ"
		_to(lab, Vector2(x, 316), 44, COLORS[i], HORIZONTAL_ALIGNMENT_CENTER, w)
		if ok:
			var col: Color = chars[(i * 4 + 2) % 16]["color"]
			Art.mascot(self, Vector2(x + w / 2.0, 385.0), 54.0, col, COLORS[i], anim_t, i, 1.0, 0, 12.0)
			_t(Inputs.name_of(slots[i]), Vector2(x, 450), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, w)
			_t("CONECTADO", Vector2(x, 478), 20, Color("8affb0"), HORIZONTAL_ALIGNMENT_CENTER, w)
		else:
			var wv := sin(anim_t * 4.0 + i)
			Art.hand(self, Vector2(x + w / 2.0, 385.0 + wv * 8.0), 26.0, COLORS[i], COLORS[i].darkened(0.55), 0.6)
			_t("Aperte ATAQUE", Vector2(x, 460), 24, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER, w)
	_tc("Conectados: %d / %d" % [slots.size(), n], 560, 30)
	if slots.size() >= n:
		_tc("Tudo pronto!", 610, 26, Color("8affb0"))
	_tc("Esc/Select: voltar", 690, 18, Color(1, 1, 1, 0.7))


func _draw_select() -> void:
	var chars := Chars.all()
	_tc("ESCOLHA SEU PERSONAGEM", 60, 40)
	var hovered: Array = []
	for e in entries:
		hovered.append(e["cursor"])
	for i in 16:
		var pos := GRID_ORIGIN + Vector2((i % 4) * CELL.x, (i / 4) * CELL.y)
		var cd: Dictionary = chars[i]
		var cc: Color = cd["color"]
		var hot := hovered.has(i) or i == hover_cell
		Art.rrect(self, Rect2(pos + Vector2(4, 4), CELL - Vector2(8, 8)), 22.0, Color(cc.darkened(0.6), 0.92),
			Color(cc, 0.9 if hot else 0.45), 2.0, 6)
		Art.mascot(self, pos + Vector2(CELL.x / 2.0, 54.0), 38.0, cc, cc.darkened(0.55), anim_t * (1.6 if hot else 0.4),
			i * 0.7, 1.0, 0, 9.0 if hot else 2.0, false)
		_t(cd["name"], pos + Vector2(0, 88), 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, CELL.x)
		_t(str(i + 1), pos + Vector2(14, 28), 14, Color(1, 1, 1, 0.45))
	# opção ALEATÓRIO
	var rhot := hovered.has(RANDOM_ID) or hover_cell == RANDOM_ID
	Art.rrect(self, RANDOM_RECT, 19.0, Color(0.16, 0.1, 0.28, 0.92), Color(GOLD, 0.95 if rhot else 0.5), 2.0, 6)
	_t("ALEATÓRIO  -  sorteia qualquer personagem", Vector2(RANDOM_RECT.position.x, RANDOM_RECT.position.y + 26.0),
		20, GOLD if rhot else Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER, RANDOM_RECT.size.x)
	for k in 3:
		Art.sparkle(self, RANDOM_RECT.position + Vector2(40.0 + k * 22.0, 19.0), 6.0 + 3.0 * sin(anim_t * 4.0 + k),
			Color(1, 0.9, 0.5, 0.9), anim_t + k)
	var humans := 0
	for e in entries:
		if e["kind"] == "human":
			humans += 1
	var humans_locked := true
	for i in humans:
		if not entries[i]["locked"]:
			humans_locked = false
	var active := humans
	if humans_locked:
		for i in range(humans, entries.size()):
			active = i + 1
			if not entries[i]["locked"]:
				break
	for i in active:
		var e: Dictionary = entries[i]
		var c: int = e["cursor"]
		var pos := GRID_ORIGIN + Vector2((c % 4) * CELL.x, (c / 4) * CELL.y)
		var inset := 2.0 + i * 4.0
		var crect := Rect2(pos + Vector2(inset, inset), CELL - Vector2(inset * 2, inset * 2))
		var tag_pos := pos + Vector2(0, 22 + i * 16)
		var tag_w := CELL.x - 12.0
		if c == RANDOM_ID:
			crect = RANDOM_RECT.grow(-inset * 0.6)
			tag_pos = RANDOM_RECT.position + Vector2(0, 24)
			tag_w = RANDOM_RECT.size.x - 14.0 - i * 60.0
		Art.rrect(self, crect, 22.0 if c != RANDOM_ID else 16.0,
			Color(e["color"], 0.12 if not e["locked"] else 0.3), e["color"], 4.0)
		_t(String(e["label"]).split(" ")[0] + (" OK" if e["locked"] else ""), tag_pos, 14,
			e["color"], HORIZONTAL_ALIGNMENT_RIGHT, tag_w)
	# painel de informações
	var fe: Dictionary = entries[clampi(focus, 0, entries.size() - 1)]
	var previewing := hover_cell >= 0
	var shown: int = hover_cell if previewing else int(fe["cursor"])
	var show_random := shown == RANDOM_ID
	var cd2: Dictionary = {"name": "Aleatório", "desc": "Sorteia qualquer um dos 16 personagens ao confirmar.",
		"color": GOLD, "weight": 0.0, "speed": 0.0, "jumps": 0, "moves": {}, "throws": {}}
	if not show_random:
		cd2 = chars[shown]
	var px := 690.0
	Art.rrect(self, Rect2(px - 10, 100, 590, 520), 30.0, Color(0.04, 0.08, 0.16, 0.9), Color(fe["color"], 0.7), 3.0, 10)
	var pc: Color = cd2["color"]
	Art.mascot(self, Vector2(px + 505.0, 142.0), 54.0, pc, fe["color"], anim_t, 0.0, 1.0, 0, 10.0)
	_t(("Prévia — %s" if previewing else "%s — %s") % ([cd2["name"]] if previewing else [fe["label"], cd2["name"]]),
		Vector2(px, 140), 30, Color.WHITE if previewing else fe["color"])
	_t(cd2["desc"], Vector2(px, 170), 19, Color(1, 1, 1, 0.85))
	if not show_random:
		_t("MANA", Vector2(px + 505, 222), 14, Color(0.5, 0.75, 1.0))
		_t("Peso %.2f   Velocidade %.2f   Pulos %d" % [cd2["weight"], cd2["speed"], cd2["jumps"]],
			Vector2(px, 196), 17, Color(1, 1, 1, 0.65))
	var y := 228.0
	var mv: Dictionary = cd2["moves"]
	for slot in Chars.SLOT_ORDER:
		var m: Dictionary = mv.get(slot, {})
		if m.is_empty():
			continue
		var label: String = m["label"]
		if slot == "grab":
			label = "Agarrar + direção = arremessos"
		_t("%s:" % Chars.SLOT_NAMES[slot], Vector2(px, y), 16, Color(1, 1, 0.6))
		_t(label, Vector2(px + 180, y), 16, Color.WHITE)
		_t("%d" % int(m.get("cost", Chars.MANA_COST.get(slot, 10))), Vector2(px + 520, y), 16,
			Color(0.5, 0.75, 1.0), HORIZONTAL_ALIGNMENT_RIGHT, 50.0)
		y += 24.0
	# status inferior
	var by := 596.0
	for i in entries.size():
		var e: Dictionary = entries[i]
		var nm: String = "Aleatório" if int(e["cursor"]) == RANDOM_ID else chars[e["cursor"]]["name"]
		var st_txt := "confirmado" if e["locked"] else "escolhendo..."
		if e["locked"] and e.get("rand", false):
			st_txt = "sorteado!"
		if i >= active and not e["locked"]:
			st_txt = "aguardando"
		_to("%s: %s (%s)" % [e["label"], nm, st_txt], Vector2(50, by + i * 26), 20, e["color"])
	var all_locked := true
	for e in entries:
		if not e["locked"]:
			all_locked = false
	if all_locked:
		_to("ENTER / START ou clique em MAPA para escolher o cenário", Vector2(50, 700), 22, Color("8affb0"))
	else:
		var extra := "CPUs/boneco são escolhidos depois   |   " if entries.size() > humans else ""
		_to(extra + "Controle: direcional + A/Xis (desça da última linha p/ os botões)   |   Mouse: clique",
			Vector2(50, 705), 15, Color(1, 1, 1, 0.8))


func _draw_stage_select() -> void:
	_tc("ESCOLHA O MAPA", 62, 40)
	var n := Stages.count() + 1
	for i in n:
		var r := _stage_cell_rect(i)
		var sel := i == stage_sel
		var hot := r.has_point(mouse)
		Art.rrect(self, r, 14.0, Color(0.04, 0.08, 0.16, 0.9), GOLD if sel else Color(1, 1, 1, 0.6 if hot else 0.2),
			4.0 if sel else 2.0, 8)
		var pr := Rect2(r.position + Vector2(6, 5), Vector2(r.size.x - 12.0, 50.0))
		var name := "ALEATÓRIO"
		var is_proc := i > 0 and Stages.is_proc(i - 1)
		if i == 0 or is_proc:
			var tint := Color(0.1, 0.16, 0.32) if i == 0 else Color(0.2, 0.1, 0.34)
			Art.rrect(self, pr, 8.0, tint)
			for k in 4:
				Art.sparkle(self, pr.position + Vector2(18.0 + k * 32.0, 14.0 + 30.0 * fposmod(k * 0.37, 1.0)),
					5.0 + 2.0 * sin(anim_t * 3.0 + k), Color(1, 1, 0.8, 0.6), anim_t + k)
			_t("?", Vector2(pr.position.x, pr.position.y + 42.0), 42, GOLD if i == 0 else Color("d9a8ff"),
				HORIZONTAL_ALIGNMENT_CENTER, pr.size.x)
			if is_proc:
				name = "Procedural"
		else:
			Stages.preview(self, pr, i - 1, anim_t if sel else 0.0)
			name = Stages.get_stage(i - 1)["name"]
		var fs := 13
		while fs > 9 and Art.font().get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > r.size.x - 6.0:
			fs -= 1
		_t(name, Vector2(r.position.x, r.position.y + 69.0), fs, GOLD if sel else Color.WHITE,
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		if i > 1:
			_t("!", Vector2(r.position.x + r.size.x - 18.0, r.position.y + 21.0), 15, Color(1, 0.4, 0.3))
	# painel de informações
	var ip := Rect2(280, 528, 740, 156)
	Art.rrect(self, ip, 22.0, PANEL, Color(1, 1, 1, 0.2), 2.0)
	if stage_sel == 0:
		_t("ALEATÓRIO", Vector2(ip.position.x + 22, ip.position.y + 38), 26, GOLD)
		_t("Um dos %d mapas é sorteado quando a luta começa." % Stages.count(),
			Vector2(ip.position.x + 22, ip.position.y + 70), 18, Color.WHITE)
	else:
		var sd := Stages.get_stage(stage_sel - 1)
		_t(String(sd["name"]), Vector2(ip.position.x + 22, ip.position.y + 38), 26, GOLD)
		var info := String(sd["hz_text"])
		if bool(sd.get("proc", false)):
			info = "Um mapa novo é gerado do zero a cada partida: chão, plataformas e perigos sorteados."
		draw_multiline_string(Art.font(), Vector2(ip.position.x + 22, ip.position.y + 66), info,
			HORIZONTAL_ALIGNMENT_LEFT, ip.size.x - 44.0, 17, 2, Color.WHITE)
	_t("As cores do cenário são sorteadas a cada partida (às vezes vêm as originais).",
		Vector2(ip.position.x + 22, ip.position.y + 106), 15, Color(1, 1, 1, 0.65))
	_t("Direcional: escolher   |   A / Enter: lutar   |   B: voltar   |   Mouse: clique",
		Vector2(ip.position.x + 22, ip.position.y + 136), 15, Color(1, 1, 1, 0.65))


## Palavra do título: cada letra balança e gira de leve.
func _title_word(word: String, fs: int, base_y: float, phase: float) -> void:
	var font := Art.font()
	var widths: Array = []
	var total := 0.0
	for ch in word:
		var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 2.0
		widths.append(w)
		total += w
	var x := 640.0 - total / 2.0
	for i in word.length():
		var half: float = float(widths[i]) / 2.0
		if word[i] != " ":
			var pos := Vector2(x + half, base_y + sin(anim_t * 2.6 + i * 0.55 + phase) * 10.0)
			var col := Color.from_hsv(0.11 - i * 0.006, 0.72 - i * 0.02, 1.0)
			draw_set_transform(pos, sin(anim_t * 2.0 + i * 0.8 + phase) * 0.06, Vector2.ONE)
			draw_string(font, Vector2(-half + 4.0, 8.0), word[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.02, 0.05, 0.12, 0.45))
			draw_string_outline(font, Vector2(-half, 0.0), word[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 16, Color("101a33"))
			draw_string(font, Vector2(-half, 0.0), word[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
			draw_string(font, Vector2(-half, -3.0), word[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.18))
		x += float(widths[i])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Fim de partida/rodada: o vencedor comemora (pula, feliz) e os outros ficam tristes.
func _set_poses(winner: Node) -> void:
	for f in fighters:
		f.pose = 1 if f == winner else (2 if winner != null else 0)
		if f.pose == 1:
			f._express("win", 999.0)
		elif f.pose == 2:
			f._express("lose", 999.0)


# ---------------------------------------------------------------- pausa

## Itens do menu de pausa (o que aparece depende do modo).
func _pause_items() -> Array:
	if pause_page == 1:
		return _cheat_items()
	var l: Array = [{"id": "resume", "text": "VOLTAR AO JOGO"},
		{"id": "music", "text": "MÚSICA"}, {"id": "sfx", "text": "EFEITOS SONOROS"}]
	if mode == "training":
		l.append({"id": "reset", "text": "ZERAR DANO E POSIÇÕES"})
	elif _is_tutorial() and tut != null and not tut.done:
		l.append({"id": "skip", "text": "PULAR PASSO"})
	if not _is_tutorial():
		l.append({"id": "cheats", "text": "TRAPAÇAS"})
	l.append({"id": "quit", "text": "SAIR DO JOGO"})
	return l


## Página de trapaças: ações (acontecem na hora) e opções que ficam ligadas até o fim da partida.
func _cheat_items() -> Array:
	var l: Array = []
	for c in CHEATS:
		var txt := String(c["text"])
		if bool(c["toggle"]):
			txt += "   [%s]" % ("LIGADO" if cheats.get(c["id"], false) else "desligado")
		l.append({"id": "c_" + String(c["id"]), "text": txt})
	l.append({"id": "back_page", "text": "VOLTAR"})
	return l


func _pause_rect(i: int) -> Rect2:
	var n := _pause_items().size()
	var stp := 62.0 if pause_page == 0 else 44.0
	var y0 := 360.0 - n * stp * 0.5 + (40.0 if pause_page == 0 else 30.0)
	return Rect2(400 if pause_page == 0 else 380, y0 + i * stp, 480 if pause_page == 0 else 520, 52.0 if pause_page == 0 else 38.0)


func _open_pause() -> void:
	pause_page = 0
	paused = true
	pause_sel = 0
	get_tree().paused = true
	Sfx.play("menu_ok")


func _close_pause() -> void:
	for hl in hud_labels:
		hl.visible = true
	msg.visible = true
	hint.visible = true
	paused = false
	get_tree().paused = false
	# o botão que fechou a pausa não vira golpe/pulo no mesmo instante
	for f in fighters:
		f.mute_until = Engine.get_physics_frames() + 3


func _pause_menu() -> void:
	var items_l := _pause_items()
	pause_sel = clampi(pause_sel, 0, items_l.size() - 1)
	if pause_page == 1 and Inputs.any_just("special") != "":
		Sfx.play("menu_voltar")   # B nas trapaças volta para a pausa
		pause_page = 0
		pause_sel = _pause_items().size() - 2
		return
	if Input.is_action_just_pressed("start") or Input.is_action_just_pressed("menu_back") \
			or Inputs.any_just("special") != "":
		Sfx.play("menu_voltar")
		_close_pause()
		return
	if Inputs.any_just("up") != "":
		pause_sel = (pause_sel + items_l.size() - 1) % items_l.size()
		Sfx.play("menu_mover")
	if Inputs.any_just("down") != "":
		pause_sel = (pause_sel + 1) % items_l.size()
		Sfx.play("menu_mover")
	var dl := 0
	if Inputs.any_just("left") != "":
		dl = -1
	elif Inputs.any_just("right") != "":
		dl = 1
	if dl != 0:
		_pause_adjust(String(items_l[pause_sel]["id"]), dl)
	if Inputs.any_just("attack") != "" or Inputs.any_just("jump") != "":
		_pause_press(String(items_l[pause_sel]["id"]))


func _pause_adjust(id: String, dl: int) -> void:
	if id == "music":
		Sfx.set_music_level(Sfx.music_lvl + dl)
	elif id == "sfx":
		Sfx.set_sfx_level(Sfx.sfx_lvl + dl)
		Sfx.play("hit_medio")


func _pause_press(id: String) -> void:
	if id.begins_with("c_"):
		_cheat(id.substr(2))
		return
	if id == "cheats":
		Sfx.play("menu_ok")
		pause_page = 1
		pause_sel = 0
		return
	if id == "back_page":
		Sfx.play("menu_voltar")
		pause_page = 0
		pause_sel = _pause_items().size() - 2
		return
	match id:
		"resume":
			Sfx.play("menu_ok")
			_close_pause()
		"music", "sfx":
			_pause_adjust(id, 1)   # apertar no volume aumenta
		"reset":
			Sfx.play("menu_ok")
			_close_pause()
			_training_reset()
		"skip":
			Sfx.play("menu_ok")
			_close_pause()
			tut.skip()
		"quit":
			Sfx.play("menu_voltar")
			_close_pause()
			_go_title()


func _draw_pause(c: CanvasItem) -> void:
	c.draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.04, 0.1, 0.62))
	var items_l := _pause_items()
	var cheat_pg := pause_page == 1
	var first := _pause_rect(0)
	var last := _pause_rect(items_l.size() - 1)
	var head := 100.0 if not cheat_pg else 84.0
	var panel := Rect2(first.position.x - 30.0, first.position.y - head, first.size.x + 60.0, last.end.y - first.position.y + head + 40.0)
	Art.rrect(c, panel, 34.0, Color(0.05, 0.09, 0.18, 0.95), Color(GOLD, 0.8) if not cheat_pg else Color("ff6bd5"), 3.0, 12)
	var title := "PAUSA" if not cheat_pg else "TRAPAÇAS"
	var tcol := GOLD if not cheat_pg else Color("ff8fe0")
	var tsz := 54 if not cheat_pg else 40
	var ty := first.position.y - (40.0 if not cheat_pg else 30.0)
	c.draw_string_outline(Art.font(), Vector2(panel.position.x, ty), title, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, tsz, 10,
		Color(0.04, 0.07, 0.14))
	c.draw_string(Art.font(), Vector2(panel.position.x, ty), title, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, tsz, tcol)
	var fsz := 26 if not cheat_pg else 19
	for i in items_l.size():
		var it: Dictionary = items_l[i]
		var r := _pause_rect(i)
		var sel := i == pause_sel
		var id := String(it["id"])
		var txt := String(it["text"])
		if id == "music":
			txt = "MÚSICA:  < %d%% >" % (Sfx.music_lvl * 10)
		elif id == "sfx":
			txt = "EFEITOS:  < %d%% >" % (Sfx.sfx_lvl * 10)
		var on := id.begins_with("c_") and bool(cheats.get(id.substr(2), false))
		var fill := GOLD if sel else Color(0.1, 0.16, 0.3, 0.95)
		if not sel and (id == "quit"):
			fill = Color(0.35, 0.1, 0.14, 0.95)
		elif not sel and id == "cheats":
			fill = Color(0.32, 0.12, 0.34, 0.95)
		elif not sel and on:
			fill = Color(0.16, 0.38, 0.22, 0.95)   # trapaça ligada: verde
		Art.rrect(c, r, r.size.y * 0.5, fill, Color.WHITE if sel else Color(1, 1, 1, 0.2), 2.0)
		c.draw_string(Art.font(), r.position + Vector2(0, r.size.y * 0.5 + fsz * 0.36), txt, HORIZONTAL_ALIGNMENT_CENTER,
			r.size.x, fsz, Color("14233f") if sel else Color.WHITE)
		if sel:
			var wob := sin(anim_t * 6.0) * 4.0
			Art.hand(c, Vector2(r.position.x - 22.0 + wob, r.get_center().y), 12.0, GOLD, Color("14233f"))
	var help := "Esq/Dir: volume   |   Start, B ou Esc: voltar ao jogo"
	if cheat_pg:
		help = "A/Xis: usar ou ligar   |   B: voltar   |   Trapaça não conta para conquistas"
	c.draw_string(Art.font(), Vector2(panel.position.x, last.end.y + 26.0), help, HORIZONTAL_ALIGNMENT_CENTER,
		panel.size.x, 15, Color(1, 1, 1, 0.75))


func _pause_click(pos: Vector2, btn: int) -> void:
	if btn == MOUSE_BUTTON_RIGHT:
		Sfx.play("menu_voltar")
		if pause_page == 1:
			pause_page = 0
			pause_sel = _pause_items().size() - 2
		else:
			_close_pause()
		return
	var items_l := _pause_items()
	for i in items_l.size():
		var r := _pause_rect(i)
		if not r.has_point(pos):
			continue
		pause_sel = i
		var id := String(items_l[i]["id"])
		if id == "music" or id == "sfx":
			if btn == MOUSE_BUTTON_WHEEL_UP:
				_pause_adjust(id, 1)
			elif btn == MOUSE_BUTTON_WHEEL_DOWN:
				_pause_adjust(id, -1)
			elif btn == MOUSE_BUTTON_LEFT:
				_pause_adjust(id, -1 if pos.x < r.get_center().x else 1)   # metade esquerda diminui, direita aumenta
		elif btn == MOUSE_BUTTON_LEFT:
			_pause_press(id)
		return


# ---------------------------------------------------------------- trapaças

func _reset_cheats() -> void:
	cheats.clear()
	cheats_used = false
	Engine.time_scale = 1.0


func _cheat(id: String) -> void:
	cheats_used = true
	var cd: Dictionary = {}
	for c in CHEATS:
		if String(c["id"]) == id:
			cd = c
	if cd.is_empty():
		return
	Sfx.play("buff")
	if bool(cd["toggle"]):
		cheats[id] = not bool(cheats.get(id, false))
		var on: bool = cheats[id]
		match id:
			"slow":
				Engine.time_scale = 0.5 if on else 1.0
			"jump":
				for f in fighters:
					f.jump_mult = (1.7 if on else (1.1 if rule == "frantic" else 1.0))
			"grav":
				if not on:
					Art.grav = 0.42 if (mut_cur >= 0 and String(MUTATORS[mut_cur]["id"]) == "lowgrav") else 1.0
			"god":
				if not on:
					for f in fighters:
						f.god_mode = false
		feed.append({"text": "Trapaça: %s %s" % [String(cd["text"]).to_lower(), "ligada" if on else "desligada"],
			"color": Color("ff6bd5"), "t": 0.0})
		return
	match id:
		"items":
			for k in 3:
				items._spawn()
		"dmg999":
			for f in fighters:
				if not f.eliminated:
					f.percent = 999.0
		"dmg0":
			for f in fighters:
				f.percent = 0.0
		"life":
			for f in fighters:
				if not f.eliminated:
					f.stocks += 1
		"ko_cpu":
			for f in fighters:
				if f.ai != null and not f.eliminated and f.respawn_t <= 0.0:
					f._ko()
	feed.append({"text": "Trapaça: %s" % String(cd["text"]).to_lower(), "color": Color("ff6bd5"), "t": 0.0})


## Trapaças que ficam ligadas: reaplicadas a cada quadro da luta.
func _cheat_tick() -> void:
	if cheats.is_empty():
		return
	for f in fighters:
		if cheats.get("mana", false):
			f.mana = f.max_mana
		if cheats.get("ult", false):
			f.ult_cd = 0.0
		if cheats.get("god", false):
			f.god_mode = f.ai == null and f.prefix != ""
	if cheats.get("grav", false):
		Art.grav = 0.45
