extends RefCounted
## Conquistas: 60 metas persistentes (user://conquistas.json).
## Cada conquista olha UM contador (`stat`) e libera quando ele chega em `goal`.
## Contadores: Ach.add (soma), Ach.set_max (maior valor) e Ach.mark (conjuntos: o contador é o tamanho do conjunto).

const SAVE_PATH := "user://conquistas.json"
const PLATINUM := "platina"
const ALL_STAGES := -1     # `goal` especial: todos os mapas (Stages.count())

## id, nome, descrição, contador e meta.
const LIST := [
	# --- Vitórias
	{"id": "win1", "name": "Estreia Vitoriosa", "desc": "Vença uma partida Versus.", "stat": "wins", "goal": 1},
	{"id": "win5", "name": "Pegando o Jeito", "desc": "Vença 5 partidas.", "stat": "wins", "goal": 5},
	{"id": "win25", "name": "Veterano de Guerra", "desc": "Vença 25 partidas.", "stat": "wins", "goal": 25},
	{"id": "win100", "name": "Lenda da Arena", "desc": "Vença 100 partidas.", "stat": "wins", "goal": 100},
	{"id": "mat10", "name": "Frequentador", "desc": "Jogue 10 partidas Versus até o fim.", "stat": "matches", "goal": 10},
	{"id": "mat50", "name": "Viciado em Luta", "desc": "Jogue 50 partidas Versus até o fim.", "stat": "matches", "goal": 50},
	# --- KOs
	{"id": "ko1", "name": "Primeira Queda", "desc": "Nocauteie um rival.", "stat": "kos_total", "goal": 1},
	{"id": "ko25", "name": "Caçador", "desc": "Faça 25 KOs.", "stat": "kos_total", "goal": 25},
	{"id": "ko100", "name": "Exterminador", "desc": "Faça 100 KOs.", "stat": "kos_total", "goal": 100},
	{"id": "ko500", "name": "Ceifador", "desc": "Faça 500 KOs.", "stat": "kos_total", "goal": 500},
	{"id": "kom5", "name": "Massacre", "desc": "Faça 5 KOs numa única partida.", "stat": "ko_match", "goal": 5},
	{"id": "kom10", "name": "Chacina Total", "desc": "Faça 10 KOs numa única partida.", "stat": "ko_match", "goal": 10},
	{"id": "proc", "name": "Mundo Novo", "desc": "Lute no mapa Procedural.", "stat": "proc", "goal": 1},
	{"id": "sd1", "name": "A Gravidade Venceu", "desc": "Caia da arena sozinho.", "stat": "sd_total", "goal": 1},
	# --- Combate
	{"id": "hit100", "name": "Cem Socos", "desc": "Acerte 100 golpes.", "stat": "hits_total", "goal": 100},
	{"id": "hit1k", "name": "Mil Golpes", "desc": "Acerte 1.000 golpes.", "stat": "hits_total", "goal": 1000},
	{"id": "hit10k", "name": "Chuva de Golpes", "desc": "Acerte 10.000 golpes.", "stat": "hits_total", "goal": 10000},
	{"id": "dmg1k", "name": "Pancadaria", "desc": "Cause 1.000% de dano no total.", "stat": "dmg_total", "goal": 1000},
	{"id": "dmg10k", "name": "Moedor de Carne", "desc": "Cause 10.000% de dano no total.", "stat": "dmg_total", "goal": 10000},
	{"id": "cmb5", "name": "Combo!", "desc": "Acerte um combo de 5 golpes.", "stat": "combo_max", "goal": 5},
	{"id": "cmb10", "name": "Combo Monstro", "desc": "Acerte um combo de 10 golpes.", "stat": "combo_max", "goal": 10},
	{"id": "cmb20", "name": "Sem Piedade", "desc": "Acerte um combo de 20 golpes.", "stat": "combo_max", "goal": 20},
	{"id": "dur200", "name": "Durão", "desc": "Aguente 200% de dano sem ser nocauteado.", "stat": "survive_pct", "goal": 200},
	{"id": "dur300", "name": "Cascudo Imortal", "desc": "Aguente 300% de dano sem ser nocauteado.", "stat": "survive_pct", "goal": 300},
	{"id": "cnt1", "name": "Na Hora H", "desc": "Faça um contra-ataque.", "stat": "counters", "goal": 1},
	{"id": "cnt10", "name": "Mestre do Contra-Ataque", "desc": "Faça 10 contra-ataques.", "stat": "counters", "goal": 10},
	{"id": "thr10", "name": "Arremessador", "desc": "Arremesse 10 rivais.", "stat": "throws", "goal": 10},
	{"id": "ult1", "name": "Especial Único", "desc": "Use o especial do botão Y.", "stat": "ult_total", "goal": 1},
	{"id": "ult50", "name": "Show de Especiais", "desc": "Use o especial do botão Y 50 vezes.", "stat": "ult_total", "goal": 50},
	{"id": "mana0", "name": "Sem Fôlego", "desc": "Tente golpear sem ter mana.", "stat": "nomana", "goal": 1},
	# --- Movimento e itens
	{"id": "air200", "name": "Pés de Pluma", "desc": "Dê 200 pulos no ar.", "stat": "air_total", "goal": 200},
	{"id": "drop50", "name": "Elevador Humano", "desc": "Atravesse plataformas para baixo 50 vezes.", "stat": "drops", "goal": 50},
	{"id": "ff100", "name": "Gravidade Pura", "desc": "Faça 100 quedas rápidas.", "stat": "fastfall", "goal": 100},
	{"id": "time1h", "name": "Hora de Jogo", "desc": "Passe 1 hora em combate.", "stat": "playtime", "goal": 3600},
	{"id": "item15", "name": "Colecionador de Itens", "desc": "Pegue 15 itens do cenário.", "stat": "items", "goal": 15},
	# --- Vitórias especiais
	{"id": "flaw", "name": "Invicto", "desc": "Vença sem perder nenhuma vida.", "stat": "win_flawless", "goal": 1},
	{"id": "last", "name": "Por um Fio", "desc": "Vença com apenas 1 vida sobrando.", "stat": "win_last", "goal": 1},
	{"id": "hurt", "name": "Sobrevivente", "desc": "Vença terminando com 150% ou mais de dano.", "stat": "win_hurt", "goal": 1},
	{"id": "rand", "name": "Confia no Destino", "desc": "Vença com um personagem sorteado.", "stat": "win_random", "goal": 1},
	{"id": "cpu5", "name": "Acima da Média", "desc": "Vença uma CPU de nível 5 ou mais.", "stat": "beat_cpu", "goal": 5},
	{"id": "cpu9", "name": "Desafiante Supremo", "desc": "Vença uma CPU de nível 9.", "stat": "beat_cpu", "goal": 9},
	{"id": "six", "name": "Um Contra Todos", "desc": "Vença uma partida com 6 lutadores.", "stat": "win_six", "goal": 1},
	{"id": "brig6", "name": "Briga de Seis", "desc": "Comece uma partida com 6 lutadores.", "stat": "fighters_max", "goal": 6},
	{"id": "mp1", "name": "Amizade Testada", "desc": "Jogue uma partida com 2 ou mais humanos.", "stat": "mp_matches", "goal": 1},
	{"id": "plat", "name": "Platina", "desc": "Desbloqueie todas as outras conquistas.", "stat": "others", "goal": 59},
	# --- Modos de jogo
	{"id": "sudden", "name": "Tudo ou Nada", "desc": "Vença uma Morte Súbita.", "stat": "win_sudden", "goal": 1},
	{"id": "mutw", "name": "Mutante", "desc": "Vença uma partida de Mutadores.", "stat": "win_mutators", "goal": 1},
	{"id": "chaos", "name": "Caos Absoluto", "desc": "Vença uma partida do modo Caos.", "stat": "win_chaos", "goal": 1},
	{"id": "hunt", "name": "Caçador de Recompensas", "desc": "Vença uma Caça aos KOs.", "stat": "win_hunt", "goal": 1},
	{"id": "hunt8", "name": "Safári de KOs", "desc": "Faça 8 KOs numa Caça aos KOs.", "stat": "hunt_best", "goal": 8},
	{"id": "inf3", "name": "Maratonista", "desc": "Vença 3 rodadas da Partida Infinita.", "stat": "inf_rounds", "goal": 3},
	{"id": "mut10", "name": "Colecionador de Mutadores", "desc": "Jogue com os 10 mutadores diferentes.", "stat": "muts", "goal": 10},
	{"id": "train", "name": "Rato de Treino", "desc": "Passe 10 minutos no Treino.", "stat": "train_time", "goal": 600},
	{"id": "tut1", "name": "Aluno Aplicado", "desc": "Conclua o tutorial básico.", "stat": "tut1", "goal": 1},
	{"id": "tut2", "name": "Mestre dos Tutoriais", "desc": "Conclua o tutorial avançado.", "stat": "tut2", "goal": 1},
	# --- Explorar
	{"id": "ch8", "name": "Curioso", "desc": "Lute com 8 personagens diferentes.", "stat": "chars", "goal": 8},
	{"id": "ch16", "name": "Elenco Completo", "desc": "Lute com os 16 personagens.", "stat": "chars", "goal": 16},
	{"id": "wch16", "name": "Campeão Absoluto", "desc": "Vença com os 16 personagens.", "stat": "win_chars", "goal": 16},
	{"id": "stg10", "name": "Turista", "desc": "Lute em 10 mapas diferentes.", "stat": "stages", "goal": 10},
	{"id": "stgall", "name": "Cartógrafo", "desc": "Lute em todos os mapas.", "stat": "stages", "goal": ALL_STAGES},
]

static var stats: Dictionary = {}       # contador -> valor
static var sets: Dictionary = {}        # conjunto -> {chave: true}
static var unlocked: Dictionary = {}    # id -> true
static var toasts: Array = []           # avisos na tela: {"name", "t"}
static var dirty := false
static var _stage_total := 40
static var _persist := true


static func setup(stage_total: int) -> void:
	_stage_total = stage_total
	_persist = DisplayServer.get_name() != "headless"   # testes não mexem no save do jogador
	if _persist:
		load_data()


static func goal_of(a: Dictionary) -> int:
	var g := int(a["goal"])
	return _stage_total if g == ALL_STAGES else g


static func value_of(a: Dictionary) -> float:
	if String(a["stat"]) == "others":
		return float(unlocked.size() - (1 if unlocked.has(PLATINUM) else 0))
	return float(stats.get(a["stat"], 0.0))


static func count_unlocked() -> int:
	return unlocked.size()


static func add(stat: String, n: float = 1.0) -> void:
	stats[stat] = float(stats.get(stat, 0.0)) + n
	dirty = true
	_check(stat)


static func set_max(stat: String, v: float) -> void:
	if v > float(stats.get(stat, 0.0)):
		stats[stat] = v
		dirty = true
		_check(stat)


## Conjunto: o contador `set_name` vale quantas chaves diferentes já entraram.
static func mark(set_name: String, key) -> void:
	var s: Dictionary = sets.get(set_name, {})
	var k := str(key)
	if s.has(k):
		return
	s[k] = true
	sets[set_name] = s
	stats[set_name] = float(s.size())
	dirty = true
	_check(set_name)


static func _check(stat: String) -> void:
	var any := false
	for a in LIST:
		if String(a["stat"]) != stat or unlocked.has(a["id"]):
			continue
		if value_of(a) >= float(goal_of(a)):
			_unlock(a)
			any = true
	if any:
		_check("others")
		flush()


static func _unlock(a: Dictionary) -> void:
	unlocked[a["id"]] = true
	toasts.append({"name": a["name"], "t": 0.0})
	Sfx.play("conquista")


static func tick(delta: float) -> void:
	for t in toasts:
		t["t"] = float(t["t"]) + delta
	toasts = toasts.filter(func(t): return float(t["t"]) < 4.5)


# ---------------------------------------------------------------- save

static func flush() -> void:
	if not dirty or not _persist:
		return
	dirty = false
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"stats": stats, "sets": sets, "unlocked": unlocked}))


static func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return
	stats = d.get("stats", {})
	sets = d.get("sets", {})
	unlocked = d.get("unlocked", {})
