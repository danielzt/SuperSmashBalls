extends Node
## Áudio 100% procedural (autoload `Sfx`): efeitos e músicas sintetizados por código, sem arquivos de som.
## Tudo é gerado numa thread ao abrir o jogo; o que ainda não ficou pronto simplesmente não toca.
## Uso: Sfx.play("hit_forte"), Sfx.hit(dano, percentual), Sfx.set_music("menu" | "battle" | "final" | "stop").

const SR := 44100            # taxa dos efeitos
const MUSIC_SR := 22050      # taxa das músicas (mais leve de gerar)
const POOL := 14             # vozes simultâneas de efeitos
const MIN_GAP := 35          # ms mínimos entre duas execuções do mesmo efeito
const BATTLES := ["battle1", "battle2", "battle3", "battle4", "battle5", "battle6", "battle7", "battle8", "battle9", "battle10"]
const NO_VARY := ["menu_mover", "menu_ok", "menu_voltar", "personagem", "contagem", "vida_perdida", "vitoria",
	"derrota", "mana_vazia", "conquista", "relogio", "apito", "morte_subita", "ult_pronto", "combo",
	"eliminado", "mutador", "vento_vira"]
const SETTINGS := "user://audio.cfg"
const CACHE_DIR := "user://audio_cache"
const CACHE_VER := 2

var enabled := true
var music_lvl := 7           # 0..10
var sfx_lvl := 8             # 0..10

var _sfx: Dictionary = {}    # id -> AudioStreamWAV
var _tracks: Dictionary = {} # "menu", "battle1", "battle1_f"... -> AudioStreamWAV
var _mutex := Mutex.new()
var _thread: Thread
var _quit := false
var _buf := PackedFloat32Array()
var _naive := false          # músicas: ondas "cruas" (sem PolyBLEP), como no som original
var _cache_ok := false
var _cache_dir := ""
var _sr := SR
var _noise := PackedFloat32Array()
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last: Dictionary = {}
var _mp: Array[AudioStreamPlayer] = []
var _mi := 0
var _want := ""
var _cur := ""
var _cur_len := 1.0
var _battle := ""
var _acc := 0.0


func _ready() -> void:
	enabled = DisplayServer.get_name() != "headless"
	if not enabled:
		return
	_load_settings()
	for b in ["Music", "SFX"]:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, b)
		AudioServer.set_bus_send(i, "Master")
		if b == "SFX":
			# reverb curto em tempo real nos efeitos (a música fica seca, como no som original)
			var rv := AudioEffectReverb.new()
			rv.room_size = 0.25
			rv.damping = 0.5
			rv.spread = 1.0
			rv.hipass = 0.3
			rv.dry = 1.0
			rv.wet = 0.07
			AudioServer.add_bus_effect(i, rv)
	_apply_levels()
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = "Music"
		add_child(m)
		_mp.append(m)
	_thread = Thread.new()
	_thread.start(_generate)


func _exit_tree() -> void:
	_quit = true
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()


func _process(delta: float) -> void:
	_acc += delta
	if _acc >= 0.3:
		_acc = 0.0
		_apply_music()


# ---------------------------------------------------------------- configuração

func _load_settings() -> void:
	var c := ConfigFile.new()
	if c.load(SETTINGS) == OK:
		music_lvl = clampi(int(c.get_value("audio", "music", music_lvl)), 0, 10)
		sfx_lvl = clampi(int(c.get_value("audio", "sfx", sfx_lvl)), 0, 10)


func _save_settings() -> void:
	var c := ConfigFile.new()
	c.set_value("audio", "music", music_lvl)
	c.set_value("audio", "sfx", sfx_lvl)
	c.save(SETTINGS)


func _bus_db(lvl: int, gain: float) -> float:
	return -80.0 if lvl <= 0 else linear_to_db(float(lvl) / 10.0 * gain)


func _apply_levels() -> void:
	var mi := AudioServer.get_bus_index("Music")
	var si := AudioServer.get_bus_index("SFX")
	if mi >= 0:
		AudioServer.set_bus_volume_db(mi, _bus_db(music_lvl, 0.6))
	if si >= 0:
		AudioServer.set_bus_volume_db(si, _bus_db(sfx_lvl, 0.9))


func set_music_level(l: int) -> void:
	music_lvl = clampi(l, 0, 10)
	_apply_levels()
	_save_settings()


func set_sfx_level(l: int) -> void:
	sfx_lvl = clampi(l, 0, 10)
	_apply_levels()
	_save_settings()


# ---------------------------------------------------------------- reprodução

func play(id: String, vol := 1.0) -> void:
	if not enabled:
		return
	_mutex.lock()
	var s: AudioStreamWAV = _sfx.get(id, null)
	_mutex.unlock()
	if s == null:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last.get(id, -1000)) < MIN_GAP:
		return
	_last[id] = now
	var p: AudioStreamPlayer = null
	for q in _players:
		if not q.playing:
			p = q
			break
	if p == null:
		p = _players[_next]
		_next = (_next + 1) % POOL
	p.stream = s
	p.pitch_scale = 1.0 if NO_VARY.has(id) else randf_range(0.94, 1.06)
	p.volume_db = linear_to_db(clampf(vol, 0.05, 1.5))
	p.play()


## Escolhe o som de golpe conforme o dano (já escalado) e o percentual do alvo.
func hit(dmg: float, percent: float) -> void:
	if dmg >= 10.0 or (dmg >= 6.0 and percent > 100.0):
		play("hit_forte")
	elif dmg >= 4.5:
		play("hit_medio")
	else:
		play("hit_fraco", 0.9)


## Pedido de música: "menu", "battle" (sorteia uma das 3 na primeira vez), "final" (última vida) ou "stop".
func set_music(want: String) -> void:
	_want = want
	_apply_music()


## Troca para outra música de luta (diferente da atual). Usado a cada rodada da Partida Infinita.
func next_battle() -> void:
	var opts: Array = []
	for b in BATTLES:
		if b != _battle and _has(b):
			opts.append(b)
	if opts.is_empty():
		return
	_battle = opts[randi() % opts.size()]
	_apply_music()


func _has(key: String) -> bool:
	_mutex.lock()
	var r := _tracks.has(key)
	_mutex.unlock()
	return r


func _apply_music() -> void:
	if not enabled or _want == "":
		return
	match _want:
		"stop":
			_battle = ""
			if _cur != "":
				_stop_music()
		"menu":
			_battle = ""
			if _cur != "menu" and _has("menu"):
				_play_track("menu", 0.0)
		"battle", "final":
			if _battle == "":
				var opts: Array = []
				for b in BATTLES:
					if _has(b):
						opts.append(b)
				if opts.is_empty():
					return
				_battle = opts[randi() % opts.size()]
			var key: String = _battle
			if _want == "final" and _has(_battle + "_f"):
				key = _battle + "_f"
			if key != _cur:
				var frac := 0.0
				if _cur.begins_with(_battle) and _mp[_mi].playing:
					frac = _mp[_mi].get_playback_position() / maxf(_cur_len, 0.1)
				_play_track(key, frac)


func _play_track(key: String, frac: float) -> void:
	_mutex.lock()
	var w: AudioStreamWAV = _tracks[key]
	_mutex.unlock()
	var tlen := float(w.loop_end) / float(w.mix_rate)
	var old := _mp[_mi]
	_mi = 1 - _mi
	var nw := _mp[_mi]
	nw.stream = w
	nw.volume_db = -40.0
	nw.play(fposmod(frac * tlen, tlen))
	create_tween().tween_property(nw, "volume_db", 0.0, 0.35)
	_fade_out(old)
	_cur = key
	_cur_len = tlen


func _fade_out(p: AudioStreamPlayer) -> void:
	if not p.playing:
		return
	var tw := create_tween()
	tw.tween_property(p, "volume_db", -60.0, 0.4)
	tw.tween_callback(p.stop)


func _stop_music() -> void:
	_fade_out(_mp[_mi])
	_cur = ""


# ---------------------------------------------------------------- geração (thread)

func _generate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_noise.resize(88200)
	for i in _noise.size():
		_noise[i] = rng.randf() * 2.0 - 1.0
	_cache_prepare()
	var defs := _sfx_defs()
	var tracks := _track_defs()
	# ordem: cliques de menu → música do menu → demais efeitos → cada música de luta seguida da sua versão
	# "última vida" (em ordem aleatória), para a 1ª partida já ter música e final sem esperar todas
	for id in ["menu_mover", "menu_ok", "menu_voltar", "personagem"]:
		if _quit or not _gen_sfx(defs, id):
			return
	if not _gen_track(tracks, "menu"):
		return
	for id in defs:
		if not _gen_sfx(defs, id):
			return
	var bl: Array = BATTLES.duplicate()
	bl.shuffle()
	for b in bl:
		if not _gen_track(tracks, b) or not _gen_track(tracks, b + "_f"):
			return


## Gera (ou lê do cache) um efeito. Devolve false se o jogo está fechando.
func _gen_sfx(defs: Dictionary, id: String) -> bool:
	if _quit:
		return false
	_mutex.lock()
	var done := _sfx.has(id)
	_mutex.unlock()
	if done:
		return true
	var w := _cache_load("s_" + id)
	if w == null:
		_sr = SR
		w = _render(defs[id] as Array, false)
		_cache_save("s_" + id, w)
	_mutex.lock()
	_sfx[id] = w
	_mutex.unlock()
	return true


## Gera (ou lê do cache) uma música; chaves terminadas em "_f" são a versão "última vida".
func _gen_track(tracks: Dictionary, key: String) -> bool:
	if _quit:
		return false
	var w := _cache_load("m_" + key)
	if w == null:
		var tr: Dictionary = tracks[key.trim_suffix("_f")]
		if key.ends_with("_f"):
			tr = _final_of(tr)
		_sr = MUSIC_SR
		w = _render_music(tr)
		if w == null or _quit:
			return false
		_cache_save("m_" + key, w)
	_mutex.lock()
	_tracks[key] = w
	_mutex.unlock()
	return true


func _t(type: String, f: float, f2: float, dur: float, vol: float, at := 0.0, a := 0.003, lp := 0.0) -> Dictionary:
	return {"k": 0, "w": type, "f": f, "f2": f2, "d": dur, "v": vol, "at": at, "a": a, "q": lp}


func _n(kind: String, f: float, f2: float, dur: float, vol: float, at := 0.0, a := 0.002, q := 1.0) -> Dictionary:
	return {"k": 1, "w": kind, "f": f, "f2": f2, "d": dur, "v": vol, "at": at, "a": a, "q": q}


## Acrescenta parâmetros extras a uma voz: "p" pan (-1..1, só nas músicas), "s" envio para eco/reverb,
## "vb" vibrato (fração da frequência), "sus" nível de sustentação (0 = decai direto, estilo pluck).
func _x(v: Dictionary, extra: Dictionary) -> Dictionary:
	v.merge(extra, true)
	return v


func _mtof(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


# ---------------------------------------------------------------- cache em disco
# A 1ª abertura gera tudo (~25 s, em segundo plano); as próximas só leem os arquivos prontos.
# A chave muda sozinha quando este arquivo muda (hash do código) ou quando CACHE_VER sobe.

## Cada versão do cache fica numa pasta com o nome da chave: um arquivo de versão antiga nunca é lido
## por engano. Pastas e arquivos de versões anteriores são apagados.
func _cache_prepare() -> void:
	var key := "%d_%d" % [CACHE_VER, FileAccess.get_file_as_string("res://scripts/sfx.gd").hash()]
	_cache_dir = CACHE_DIR + "/" + key
	DirAccess.make_dir_recursive_absolute(_cache_dir)
	_cache_ok = DirAccess.dir_exists_absolute(_cache_dir)
	var root := DirAccess.open(CACHE_DIR)
	if root == null:
		return
	for f in root.get_files():
		DirAccess.remove_absolute(CACHE_DIR + "/" + f)
	for sub in root.get_directories():
		if sub == key:
			continue
		var old := CACHE_DIR + "/" + sub
		var od := DirAccess.open(old)
		if od != null:
			for f in od.get_files():
				DirAccess.remove_absolute(old + "/" + f)
		DirAccess.remove_absolute(old)


func _cache_load(name: String) -> AudioStreamWAV:
	if not _cache_ok:
		return null
	var path := "%s/%s.snd" % [_cache_dir, name]
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return null
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = f.get_32()
	w.stereo = f.get_8() == 1
	var loop := f.get_8() == 1
	var le := f.get_32()
	var sz := f.get_32()
	w.data = f.get_buffer(sz)
	f.close()
	if w.data.size() != sz or sz == 0:
		return null
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = le
	return w


func _cache_save(name: String, w: AudioStreamWAV) -> void:
	if not _cache_ok or w == null:
		return
	var f := FileAccess.open_compressed("%s/%s.snd" % [_cache_dir, name], FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return
	f.store_32(w.mix_rate)
	f.store_8(1 if w.stereo else 0)
	f.store_8(1 if w.loop_mode == AudioStreamWAV.LOOP_FORWARD else 0)
	f.store_32(w.loop_end)
	f.store_32(w.data.size())
	f.store_buffer(w.data)
	f.close()


# ---------------------------------------------------------------- síntese

## Renderiza uma lista de vozes num AudioStreamWAV mono (efeitos; o reverb é em tempo real no barramento SFX).
func _render(voices: Array, loop: bool, length := 0.0) -> AudioStreamWAV:
	var total := length
	if total <= 0.0:
		for v in voices:
			total = maxf(total, float(v["at"]) + float(v["d"]))
		total += 0.04
	_buf = PackedFloat32Array()
	_buf.resize(int(total * _sr))
	for v in voices:
		if int(v["k"]) == 0:
			_tone(v)
		else:
			_noise_voice(v)
	return _to_wav(loop)


func _to_wav(loop: bool) -> AudioStreamWAV:
	var n := _buf.size()
	var d := PackedByteArray()
	d.resize(n * 2)
	for i in n:
		d.encode_s16(i * 2, int(clampf(tanh(_buf[i] * 0.9), -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = _sr
	w.stereo = false
	w.data = d
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = n
	return w


func _tone(v: Dictionary) -> void:
	var sr := _sr
	var sz := _buf.size()
	var i0 := int(float(v["at"]) * sr)
	var n := int(float(v["d"]) * sr)
	if n < 2:
		return
	var vol: float = v["v"]
	var na := maxi(int(float(v["a"]) * sr), 1)
	var k := pow(0.0001 / vol, 1.0 / float(maxi(n - na, 1)))
	# modo sustentado: ataque, decai até vol*sus e solta no fim (notas longas, pads)
	var sus: float = float(v.get("sus", 0.0))
	var target := vol * sus
	var kd := exp(-1.0 / (0.12 * sr))
	var nr := maxi(int(n * 0.82), na + 1)
	var kr := pow(0.001, 1.0 / float(maxi(n - nr, 1)))
	var f: float = v["f"]
	var f2: float = v["f2"]
	var fr := 1.0
	if f2 > 0.0:
		fr = pow(f2 / f, 1.0 / float(n))
	var wt := 3
	match String(v["w"]):
		"sine":
			wt = 0
		"square":
			wt = 1
		"saw":
			wt = 2
	var lp: float = v["q"]
	var alpha := 1.0
	if lp > 0.0:
		alpha = 1.0 - exp(-TAU * lp / sr)
	var vb: float = float(v.get("vb", 0.0))
	var vinc := TAU * 5.5 / sr
	var vph := 0.0
	var vstart := int(0.14 * sr)
	var blep := not _naive
	var y := 0.0
	var ph := 0.0
	var dphi := f / sr
	var env := 0.0
	for j in n:
		if j < na:
			env = vol * float(j) / float(na)
		elif sus > 0.0:
			if j < nr:
				env = target + (env - target) * kd
			else:
				env *= kr
		elif j == na:
			env = vol
		else:
			env *= k
		var x: float
		if wt == 0:
			x = sin(TAU * ph)
		elif wt == 1:
			# quadrada com PolyBLEP (sem o chiado de aliasing)
			x = 1.0 if ph < 0.5 else -1.0
			if not blep:
				pass
			elif ph < dphi:
				var u := ph / dphi
				x += u + u - u * u - 1.0
			elif ph > 1.0 - dphi:
				var u := (ph - 1.0) / dphi
				x += u * u + u + u + 1.0
			var p2 := ph - 0.5 if ph >= 0.5 else ph + 0.5
			if not blep:
				pass
			elif p2 < dphi:
				var u := p2 / dphi
				x -= u + u - u * u - 1.0
			elif p2 > 1.0 - dphi:
				var u := (p2 - 1.0) / dphi
				x -= u * u + u + u + 1.0
		elif wt == 2:
			# dente de serra com PolyBLEP
			x = 2.0 * ph - 1.0
			if not blep:
				pass
			elif ph < dphi:
				var u := ph / dphi
				x -= u + u - u * u - 1.0
			elif ph > 1.0 - dphi:
				var u := (ph - 1.0) / dphi
				x -= u * u + u + u + 1.0
		else:
			x = 4.0 * absf(ph - 0.5) - 1.0
		if lp > 0.0:
			y += alpha * (x - y)
			x = y
		_buf[(i0 + j) % sz] += x * env
		var inc := dphi
		if vb > 0.0 and j > vstart:
			inc *= 1.0 + vb * sin(vph)
			vph += vinc
		ph += inc
		if ph >= 1.0:
			ph -= 1.0
		dphi *= fr


func _noise_voice(v: Dictionary) -> void:
	var sr := _sr
	var sz := _buf.size()
	var i0 := int(float(v["at"]) * sr)
	var n := int(float(v["d"]) * sr)
	if n < 2:
		return
	var vol: float = v["v"]
	var na := maxi(int(float(v["a"]) * sr), 1)
	var k := pow(0.0001 / vol, 1.0 / float(maxi(n - na, 1)))
	var fc: float = v["f"]
	var f2: float = v["f2"]
	var fr := 1.0
	if f2 > 0.0:
		fr = pow(f2 / fc, 1.0 / float(n))
	var kind := 0
	match String(v["w"]):
		"high":
			kind = 1
		"band":
			kind = 2
	var qd := 1.0 / maxf(float(v["q"]), 0.3)
	var low := 0.0
	var band := 0.0
	var ff := 0.0
	var env := 0.0
	var nl := _noise.size()
	var off := randi() % nl
	var fmax := sr / 7.0
	for j in n:
		if j < na:
			env = vol * float(j) / float(na)
		elif j == na:
			env = vol
		else:
			env *= k
		if (j & 15) == 0:
			ff = 2.0 * sin(PI * minf(fc, fmax) / sr)
		var x := _noise[(off + j) % nl]
		low += ff * band
		var high := x - low - qd * band
		band += ff * high
		var o := low
		if kind == 1:
			o = high
		elif kind == 2:
			o = band * qd
		_buf[(i0 + j) % sz] += o * env
		fc *= fr


# ---------------------------------------------------------------- efeitos

func _arp(notes: Array, gap: float, type: String, vol: float, dur: float) -> Array:
	var a: Array = []
	for i in notes.size():
		a.append(_t(type, float(notes[i]), 0.0, dur, vol, i * gap))
	return a


func _sfx_defs() -> Dictionary:
	var d: Dictionary = {}
	# golpes em camadas: estalo (ataque), corpo (tom grave que cai) e chiado (textura)
	d["hit_fraco"] = [_n("band", 2400, 0, .06, .45, 0, .002, .8), _t("sine", 260, 110, .08, .35),
		_n("high", 6000, 0, .015, .3), _t("triangle", 520, 200, .05, .12)]
	d["hit_medio"] = [_t("sine", 190, 55, .16, .6), _n("low", 3500, 450, .14, .5), _t("saw", 230, 80, .1, .2, 0, .003, 2200),
		_n("high", 5000, 0, .02, .35)]
	d["hit_forte"] = [_t("sine", 140, 32, .5, .95), _n("low", 3200, 140, .38, .75), _t("saw", 110, 38, .32, .28, 0, .003, 1600),
		_n("high", 4500, 0, .05, .5), _t("square", 1100, 180, .06, .14), _n("band", 900, 200, .25, .3, .03, .002, 1.2)]
	var ko: Array = [_t("saw", 900, 50, 1.0, .32, 0, .003, 3000), _n("low", 4000, 100, 1.1, .7), _t("sine", 80, 25, .9, .9),
		_n("high", 6000, 1500, .45, .22)]
	for i in 6:
		ko.append(_t("sine", 1500 + i * 300, 0, .25, .08, .2 + i * .07))
	d["ko"] = ko
	d["pulo"] = [_t("triangle", 300, 720, .1, .26), _t("sine", 600, 1440, .08, .08), _n("band", 1500, 3500, .06, .08, 0, .002, 1.5)]
	d["pulo_duplo"] = [_t("triangle", 340, 820, .09, .24), _t("triangle", 520, 1250, .1, .2, .06), _t("sine", 1800, 2600, .12, .05, .08)]
	d["pouso"] = [_n("low", 600, 0, .07, .42), _t("sine", 110, 55, .1, .35), _n("band", 1200, 0, .03, .12)]
	d["dash"] = [_n("band", 900, 4500, .18, .35, 0, .01, .9), _n("high", 3000, 7000, .12, .12)]
	d["queda"] = [_t("triangle", 700, 140, .2, .2), _n("high", 2500, 800, .18, .2)]
	d["escudo_on"] = [_t("triangle", 280, 620, .22, .3), _t("sine", 560, 1240, .22, .1), _t("sine", 1120, 2480, .2, .04)]
	d["escudo_bloqueio"] = [_t("square", 1300, 1000, .1, .2), _t("square", 1950, 0, .14, .1), _n("band", 4000, 0, .05, .3)]
	var eq: Array = [_n("low", 6000, 300, .5, .7), _t("saw", 700, 60, .5, .3)]
	for i in 4:
		eq.append(_t("square", 2000 + i * 430, 0, .15, .07, i * .05))
	d["escudo_quebra"] = eq
	d["agarrao"] = [_t("square", 500, 0, .04, .25), _t("square", 700, 0, .05, .25, .05), _n("band", 1500, 0, .08, .2, .05)]
	d["arremesso"] = [_n("band", 600, 3000, .25, .35, 0, .002, 1.5), _t("sine", 200, 500, .2, .25)]
	d["projetil"] = [_t("square", 1100, 300, .16, .22), _t("sine", 2200, 600, .12, .08)]
	d["explosao"] = [_n("low", 2500, 60, .8, .9), _t("sine", 110, 30, .6, .9)]
	d["mina"] = [_t("square", 880, 0, .06, .2), _t("square", 880, 0, .06, .2, .12)]
	d["cura"] = _arp([523, 659, 784, 1047], .08, "triangle", .25, .16)
	var bf: Array = [_t("saw", 200, 800, .3, .18, 0, .003, 2500)]
	for i in 4:
		bf.append(_t("sine", 1200 + i * 250, 0, .18, .08, .15 + i * .06))
	d["buff"] = bf
	var rs: Array = _arp([330, 440, 554, 660, 880], .07, "square", .15, .14)
	for i in 5:
		rs.append(_t("sine", 1800 + i * 220, 0, .3, .06, .35 + i * .05))
	d["respawn"] = rs
	d["mana_vazia"] = [_t("square", 150, 0, .08, .22), _t("square", 140, 0, .1, .22, .1)]
	# --- itens agarráveis ---
	d["i_aparece"] = [_t("sine", 1400, 500, .3, .15), _t("triangle", 988, 0, .08, .14, .28), _t("triangle", 1319, 0, .14, .14, .34)]
	d["i_pega"] = [_t("square", 784, 0, .05, .2), _t("square", 1175, 0, .09, .2, .05), _n("high", 5000, 0, .04, .12)]
	var isome: Array = []
	for i in 5:
		isome.append(_t("sine", 900.0 - i * 90.0, 0, .05, .1, i * .07))
	d["i_some"] = isome
	var isp: Array = [_n("band", 700, 2600, .3, .3, 0, .002, 1.6), _t("sine", 220, 420, .22, .2)]
	for i in 6:
		isp.append(_t("square", 1700.0 + (i % 2) * 500.0, 0, .025, .1, i * .045))
	d["i_spikeball"] = isp
	var ibm: Array = [_n("high", 4500, 7000, .35, .18), _t("sine", 180, 420, .2, .28, .3), _n("band", 600, 2200, .2, .3, .3)]
	for i in 5:
		ibm.append(_n("high", 6000, 0, .02, .18, i * .06))
	d["i_bomba"] = ibm
	d["i_mina"] = [_t("sine", 160, 70, .1, .4), _n("low", 500, 0, .05, .25), _t("square", 880, 0, .05, .2, .14),
		_t("square", 880, 0, .05, .2, .3), _t("square", 1320, 0, .08, .18, .46)]
	var imc: Array = [_n("band", 2500, 0, .05, .5, 0, .002, 2.0), _n("band", 2000, 0, .05, .4, .09, .002, 2.0), _t("sine", 130, 80, .05, .3)]
	for i in 5:
		imc.append(_t("sine", [523, 659, 784, 1047, 1319][i], 0, .22, .22, .22 + i * .07))
	d["i_maca"] = imc
	var ies: Array = []
	for i in 7:
		ies.append(_t("square", [1047, 1319, 1568, 2093, 1568, 2093, 2637][i], 0, .09, .11, i * .055))
	ies.append(_t("sine", 2637, 0, .7, .12, .4, .02))
	for i in 8:
		ies.append(_t("sine", 3000.0 + randf() * 3000.0, 0, .12, .05, .2 + i * .06))
	d["i_estrela"] = ies
	var ibt: Array = [_n("high", 800, 6000, .35, .4, 0, .01), _t("saw", 300, 1400, .28, .14, 0, .003, 3000)]
	for i in 3:
		ibt.append(_t("triangle", 900.0 + i * 300.0, 0, .07, .14, .2 + i * .05))
	d["i_botas"] = ibt
	d["i_punho"] = [_t("sine", 150, 40, .3, .75), _n("low", 1500, 200, .12, .6), _t("saw", 110, 220, .35, .2, .08, .003, 1500),
		_t("square", 440, 0, .18, .1, .2), _t("square", 660, 0, .25, .1, .28)]
	var imn: Array = [_t("triangle", 440, 880, .35, .12, 0, .003, 1800)]
	for i in 4:
		var fq: float = [1319, 1760, 2349, 2960][i]
		imn.append(_t("sine", fq, 0, .5, .14, i * .06, .004))
		imn.append(_t("sine", fq * 2.01, 0, .3, .05, i * .06))
	d["i_mana"] = imn
	d["i_bolha"] = [_t("sine", 300, 900, .18, .22), _t("sine", 500, 1400, .15, .12, .05), _n("band", 3000, 0, .1, .1, .12, .002, 3.0)]
	d["i_bolha_quebra"] = [_t("sine", 1800, 300, .07, .3), _n("high", 3500, 0, .12, .4), _t("sine", 700, 200, .15, .12, .04)]
	# --- novos perigos ---
	d["p_espinhos"] = [_n("high", 3500, 0, .06, .45), _t("square", 1800, 600, .05, .2), _t("sine", 120, 70, .1, .3)]
	d["p_pendulo"] = [_n("band", 300, 900, .6, .3, 0, .25, .9), _t("sine", 90, 60, .5, .18, 0, .2)]
	d["p_orbe"] = [_t("saw", 260, 380, .35, .12, 0, .12, 1400), _t("sine", 520, 760, .35, .1, 0, .12)]
	var pea: Array = []
	for i in 3:
		pea.append(_n("band", 2500.0 + i * 400.0, 0, .04, .35, i * .12, .002, 3.0))
		pea.append(_t("triangle", 1800.0 + i * 200.0, 0, .03, .1, i * .12))
	d["p_estalactite_aviso"] = pea
	d["p_estalactite"] = [_t("sine", 1600, 300, .18, .12), _n("high", 2500, 0, .2, .55, .12), _t("sine", 130, 60, .15, .45, .12)]
	d["p_aviso"] = [_t("square", 1000, 0, .07, .18), _t("square", 1000, 0, .07, .18, .11)]
	var pmc: Array = []
	for t in [0.0, .2, .38, .52]:
		pmc.append(_t("square", 1200, 0, .04, .16, t))
	d["p_mina_campo"] = pmc
	var pbn: Array = [_t("sine", 70, 55, .65, .25, 0, .1)]
	for i in 9:
		pbn.append(_n("low", 500.0 + randf() * 300.0, 0, .09, .28, i * .07))
	d["p_bola_neve"] = pbn
	d["p_neve_impacto"] = [_n("low", 1500, 300, .25, .5), _t("sine", 110, 55, .2, .45)]
	d["p_raio_aviso"] = [_t("saw", 300, 1800, .9, .1, 0, .5, 3000), _n("high", 4000, 7000, .9, .12, 0, .6)]
	var prl: Array = [_n("high", 2000, 0, .04, .8), _n("low", 1800, 90, .9, .7, .04), _t("sine", 70, 28, .9, .7, .05)]
	for i in 6:
		prl.append(_n("high", 4000, 0, .03, .35, i * .03))
	d["p_raio"] = prl
	d["p_mare"] = [_n("low", 400, 1200, 1.1, .35, 0, .5), _n("low", 1200, 300, 1.1, .3, 1.0, .1)]
	var pag: Array = [_n("band", 1500, 500, .3, .5, 0, .002, .8), _t("sine", 500, 150, .15, .3)]
	for i in 4:
		pag.append(_t("sine", 700.0 + randf() * 500.0, 300, .08, .12, .08 + i * .06))
	d["p_agua"] = pag
	d["p_bumper"] = [_t("square", 300, 900, .09, .2), _t("sine", 600, 1500, .12, .2), _t("triangle", 1200, 0, .06, .12, .07)]
	d["p_mola"] = [_t("sine", 180, 520, .07, .3), _t("triangle", 400, 1500, .28, .2, .05), _t("sine", 1800, 900, .14, .08, .2)]
	var pgv: Array = [_t("sine", 500, 180, .9, .2, 0, .15), _t("sine", 752, 270, .9, .08, 0, .15)]
	for i in 4:
		pgv.append(_t("triangle", 900.0 - i * 120.0, 0, .2, .06, .2 + i * .15))
	d["p_gravidade"] = pgv
	d["p_gravidade_fim"] = [_t("sine", 180, 500, .25, .18), _t("sine", 90, 50, .2, .4, .2)]
	var psm: Array = [_n("low", 2500, 400, .25, .2, 0, .05)]
	for i in 5:
		psm.append(_t("triangle", 1400.0 - i * 180.0, 0, .08, .12, i * .05))
	d["p_some"] = psm
	var pvl: Array = [_t("sine", 100, 0, .08, .3, .22)]
	for i in 4:
		pvl.append(_t("triangle", 600.0 + i * 180.0, 0, .08, .12, i * .05))
	d["p_volta"] = pvl
	d["p_varredor"] = [_t("saw", 140, 200, .7, .12, 0, .2, 1200), _t("sine", 1800, 1300, .7, .06, 0, .2)]
	d["p_paredes"] = [_n("low", 200, 120, 1.0, .3, 0, .4), _t("saw", 55, 45, 1.0, .25, 0, .3, 300),
		_t("sine", 70, 30, .3, .7, .95), _n("low", 900, 0, .25, .5, .95)]
	d["p_portal"] = [_t("sine", 200, 1600, .18, .22), _t("sine", 1600, 300, .2, .22, .16), _t("triangle", 1000, 2000, .3, .1, .1)]
	var pac: Array = [_t("sine", 200, 120, .25, .15)]
	for i in 7:
		pac.append(_n("high", 4000.0 + randf() * 3000.0, 0, .06, .25, i * .05 + randf() * .03))
	d["p_acido"] = pac
	d["p_pisao_aviso"] = [_t("sine", 800, 300, .6, .12, 0, .35), _t("triangle", 400, 200, .6, .1, 0, .35)]
	d["p_pisao"] = [_t("sine", 120, 28, .5, .95), _n("low", 1800, 100, .35, .8), _n("high", 3000, 0, .15, .5),
		_t("sine", 65, 35, .35, .5, .12)]
	d["p_onda"] = [_n("low", 900, 200, .5, .35), _t("sine", 90, 50, .4, .4)]
	var pes: Array = []
	for i in 6:
		pes.append(_t("square", 110, 100, .06, .12, i * .08, .003, 500))
		pes.append(_n("band", 1200, 0, .03, .12, i * .08))
	d["p_esteira"] = pes
	d["p_gelo"] = [_n("high", 5000, 9000, .3, .25), _t("sine", 2600, 3400, .25, .06, 0, .05)]
	d["p_bala"] = [_t("sine", 140, 60, .18, .5), _n("low", 1800, 300, .15, .5)]
	d["serra"] = [_t("saw", 180, 260, .6, .18, 0, .003, 3000), _t("saw", 187, 270, .6, .18, 0, .003, 3000),
		_n("high", 3000, 0, .6, .15)]
	d["laser"] = [_t("saw", 2400, 200, .3, .22, 0, .003, 4000), _t("square", 1200, 100, .3, .12)]
	var lv: Array = []
	for i in 6:
		var t := i * .11 + randf() * .05
		lv.append(_n("low", 300, 0, .08, .35, t))
		lv.append(_t("sine", 150.0 + randf() * 100.0, 350, .09, .25, t))
	d["lava"] = lv
	d["trem"] = [_t("square", 233, 0, .8, .22, 0, .05, 1800), _t("square", 294, 0, .8, .16, 0, .05, 1800)]
	d["vento"] = [_n("band", 300, 900, .7, .4, 0, .3, .7), _n("band", 900, 300, .7, .4, .6, .1, .7)]
	d["meteoro"] = [_n("low", 1500, 200, .9, .5, 0, .5), _n("low", 2200, 60, .7, .8, .9), _t("sine", 100, 30, .6, .8, .9)]
	var el: Array = [_t("saw", 60, 0, .5, .15, 0, .003, 300)]
	for i in 12:
		el.append(_n("high", 3000.0 + randf() * 3000.0, 0, .03, .3, i * .035 + randf() * .02))
	d["eletricidade"] = el
	d["buraco_negro"] = [_t("sine", 400, 40, 1.4, .3, 0, .2), _n("low", 1200, 60, 1.4, .3, 0, .3)]
	d["prensa"] = [_t("sine", 180, 40, .3, .7), _n("low", 800, 0, .2, .5)]
	d["geiser"] = [_n("band", 500, 1800, .7, .35, 0, .2)]
	d["canhao"] = [_n("low", 2000, 100, .4, .7), _t("sine", 160, 45, .35, .8)]
	# menus: timbres de "sininho" (triângulo + harmônico senoidal) em vez de quadrada crua
	d["menu_mover"] = [_t("triangle", 1320, 0, .05, .14), _t("sine", 2640, 0, .035, .05)]
	d["menu_ok"] = [_t("triangle", 880, 0, .07, .18), _t("sine", 1760, 0, .06, .05), _t("triangle", 1320, 0, .12, .18, .06),
		_t("sine", 2640, 0, .1, .05, .06)]
	d["menu_voltar"] = [_t("triangle", 880, 587, .12, .18), _t("sine", 1760, 1174, .1, .04)]
	var pc: Array = [_t("sine", 2093, 0, .3, .05, .05)]
	for s in [0, 4, 7]:
		pc.append(_t("saw", _mtof(60 + s), 0, .3, .12, 0, .003, 2200))
		pc.append(_t("triangle", _mtof(72 + s), 0, .25, .06, .02))
	d["personagem"] = pc
	var ct: Array = []
	for tt in [0.0, .6, 1.2]:
		ct.append(_t("square", 660, 0, .15, .22, tt))
	ct.append(_t("square", 990, 0, .45, .25, 1.8))
	ct.append(_t("square", 1320, 0, .45, .15, 1.8))
	d["contagem"] = ct
	d["vida_perdida"] = _arp([392, 330, 262, 196], .14, "triangle", .22, .28)
	d["vida_perdida"].append(_t("sine", 98, 0, .6, .2, .42, .01))
	# vitória: fanfarra subindo + acorde maior sustentado com vibrato e brilho
	var vt: Array = []
	var vi := 0
	for f in [523, 659, 784, 1047]:
		var ta: float = [0.0, .13, .26, .39][vi]
		vt.append(_t("square", f, 0, .18, .14, ta, .003, 3000))
		vt.append(_t("triangle", f * .5, 0, .18, .14, ta))
		vi += 1
	for f in [523, 659, 784]:
		vt.append(_x(_t("triangle", f, 0, 1.2, .14, .62, .01), {"sus": .6}))
	vt.append(_x(_t("square", 1047, 0, 1.1, .1, .62, .01, 3500), {"sus": .5, "vb": .006}))
	vt.append(_t("sine", 131, 0, 1.0, .25, .62, .01))
	for i in 6:
		vt.append(_t("sine", 2093.0 + i * 330.0, 0, .2, .04, .7 + i * .06))
	d["vitoria"] = vt
	d["derrota"] = [_t("triangle", 392, 0, .3, .26), _t("triangle", 370, 0, .3, .26, .25), _t("triangle", 349, 0, .3, .26, .5),
		_x(_t("triangle", 330, 0, 1.2, .26, .75, .01), {"sus": .5, "vb": .004}), _x(_t("saw", 165, 0, 1.2, .08, .75, .05, 900), {"sus": .6}),
		_x(_t("saw", 196, 0, 1.2, .06, .75, .05, 900), {"sus": .6}), _t("sine", 82, 0, 1.1, .2, .75, .02)]
	_new_sfx(d)
	return d


## Sons novos: golpes no ar, especiais, Y, modos, conquistas, torcida, passos…
func _new_sfx(d: Dictionary) -> void:
	d["golpe_ar"] = [_n("band", 700, 2600, .12, .28, 0, .01, 1.3)]
	d["golpe_ar_forte"] = [_n("band", 450, 1900, .2, .38, 0, .02, 1.1), _t("sine", 160, 90, .15, .12)]
	var es: Array = [_t("sine", 600, 1250, .2, .14), _t("triangle", 1200, 2500, .16, .07, .02), _n("band", 3000, 6000, .18, .08, 0, .01, 2.0)]
	for i in 3:
		es.append(_t("sine", 2000.0 + i * 600.0, 0, .1, .04, .05 + i * .04))
	d["especial"] = es
	# especial Y: carrega (serra subindo) e explode (grave + ruído) com brilho no fim
	var ul: Array = [_t("saw", 110, 880, .5, .16, 0, .35, 2400), _n("band", 400, 3000, .5, .2, 0, .4, 1.0),
		_t("sine", 95, 30, .6, .85, .48), _n("low", 3200, 180, .55, .65, .48), _t("square", 880, 0, .35, .07, .5, .003, 3000),
		_t("square", 1320, 0, .4, .05, .5, .003, 3000)]
	for i in 5:
		ul.append(_t("sine", 2500.0 + i * 400.0, 0, .18, .05, .55 + i * .05))
	d["ult"] = ul
	d["ult_pronto"] = [_t("sine", 1568, 0, .5, .13, 0, .004), _t("sine", 2349, 0, .4, .07, .05), _t("triangle", 784, 0, .35, .1)]
	d["teleporte"] = [_t("sine", 300, 2200, .12, .2), _t("sine", 2200, 500, .14, .16, .1), _n("high", 5000, 0, .08, .12, .08)]
	d["contra"] = [_n("high", 5000, 0, .03, .35), _t("square", 1800, 0, .04, .15), _t("sine", 2700, 0, .45, .16),
		_t("sine", 3600, 0, .35, .07, .02)]
	d["combo"] = [_t("triangle", 1047, 0, .07, .14), _t("triangle", 1568, 0, .12, .14, .06), _t("sine", 3136, 0, .1, .04, .06)]
	var el: Array = [_t("saw", 420, 55, .9, .16, 0, .003, 1500), _t("sine", 75, 28, .8, .6), _n("low", 1500, 80, .9, .4)]
	var en := 0
	for f in [392, 311, 262, 196]:
		el.append(_t("triangle", f, 0, .3, .2, .5 + en * .16))
		en += 1
	d["eliminado"] = el
	# torcida: dezenas de "vozes" (ruído em banda estreita) começando em momentos aleatórios + assobios
	var tc: Array = [_n("band", 1100, 0, 1.5, .16, 0, .35, .8)]
	for i in 28:
		tc.append(_n("band", randf_range(700.0, 2200.0), 0, randf_range(.25, .6), .05, randf() * 1.1, .08, 4.0))
	for i in 3:
		var tw := randf() * .8
		tc.append(_t("sine", 1800, 2500, .3, .03, tw, .02))
	d["torcida"] = tc
	var cq: Array = [_x(_t("sine", 2093, 0, .7, .09, .3, .005), {"sus": .4})]
	var cn := 0
	for f in [784, 988, 1175, 1568]:
		cq.append(_t("triangle", f, 0, .2, .16, cn * .07))
		cn += 1
	for i in 4:
		cq.append(_t("sine", 2600.0 + i * 500.0, 0, .12, .04, .35 + i * .05))
	d["conquista"] = cq
	d["mutador"] = [_n("band", 300, 3200, .45, .3, 0, .25, 1.0), _t("square", 659, 0, .3, .08, .4, .003, 3000),
		_t("square", 831, 0, .3, .08, .4, .003, 3000), _t("square", 988, 0, .3, .08, .4, .003, 3000), _t("sine", 1976, 0, .3, .05, .4)]
	d["vento_vira"] = [_n("band", 400, 1600, .9, .35, 0, .45, .8), _t("triangle", 988, 0, .1, .14), _t("triangle", 740, 0, .14, .14, .14)]
	var ms: Array = [_t("sine", 70, 35, .6, .6, .64), _n("low", 2000, 100, .5, .45, .64)]
	for i in 4:
		ms.append(_t("saw", 880 if i % 2 == 0 else 660, 0, .15, .12, i * .16, .003, 2600))
	d["morte_subita"] = ms
	d["relogio"] = [_t("square", 1500, 0, .03, .13, 0, .001, 4000), _t("sine", 3000, 0, .02, .05)]
	d["apito"] = [_x(_t("square", 440, 0, .9, .14, 0, .01, 2200), {"sus": .8}), _x(_t("square", 444, 0, .9, .14, 0, .01, 2200), {"sus": .8}),
		_x(_t("saw", 220, 0, .9, .08, 0, .01, 1200), {"sus": .8})]
	d["passo"] = [_n("low", 900, 0, .035, .22), _t("sine", 150, 90, .04, .12)]


# ---------------------------------------------------------------- músicas

func _track_defs() -> Dictionary:
	var drum_menu := {"k": "x.......x.....x.", "s": "....x.......x...", "h": "..x...x...x...x."}
	var drum_b1 := {"k": "x.....x.x.x...x.", "s": "....x.......x...", "h": "x.x.x.x.x.x.x.x."}
	var drum_b2 := {"k": "x..x..x...x..x..", "s": "....x.......x...", "h": "x.x.x.x.x.x.x.xx"}
	var drum_b3 := {"k": "x...x...x...x...", "s": "....x.......x...", "h": "..x...x...x...x."}
	var lead_menu := [
		[[0, 76, 4], [6, 74, 2], [8, 72, 6]], [[0, 77, 4], [6, 76, 2], [8, 72, 6]],
		[[0, 79, 4], [6, 76, 2], [8, 72, 4], [12, 76, 2]], [[0, 74, 6], [8, 71, 4], [12, 74, 4]]]
	var lead_b1 := [
		[[0, 76, 3], [4, 74, 1], [5, 71, 1], [6, 74, 2], [8, 71, 4], [12, 67, 2], [14, 71, 2]],
		[[0, 72, 3], [4, 71, 1], [5, 67, 1], [6, 71, 2], [8, 67, 4], [12, 64, 2], [14, 67, 2]],
		[[0, 74, 3], [4, 71, 1], [5, 67, 1], [6, 71, 2], [8, 74, 4], [12, 79, 2], [14, 76, 2]],
		[[0, 74, 2], [2, 69, 2], [4, 74, 2], [6, 78, 2], [8, 76, 2], [10, 74, 2], [12, 71, 2], [14, 69, 2]]]
	var lead_b2 := [
		[[0, 74, 2], [2, 77, 2], [4, 81, 3], [8, 79, 2], [10, 77, 2], [12, 74, 4]],
		[[0, 74, 2], [2, 77, 2], [4, 82, 3], [8, 81, 2], [10, 77, 2], [12, 74, 4]],
		[[0, 77, 2], [2, 81, 2], [4, 84, 3], [8, 81, 2], [10, 79, 2], [12, 77, 4]],
		[[0, 79, 2], [2, 76, 2], [4, 72, 2], [6, 76, 2], [8, 79, 4], [12, 76, 2], [14, 72, 2]]]
	var lead_b3 := [
		[[0, 81, 2], [2, 76, 2], [4, 81, 2], [6, 84, 2], [8, 83, 4], [12, 81, 2], [14, 76, 2]],
		[[0, 77, 2], [2, 81, 2], [4, 84, 2], [6, 81, 2], [8, 77, 4], [12, 81, 4]],
		[[0, 79, 2], [2, 84, 2], [4, 88, 2], [6, 84, 2], [8, 79, 4], [12, 84, 2], [14, 79, 2]],
		[[0, 83, 2], [2, 79, 2], [4, 74, 2], [6, 79, 2], [8, 83, 4], [12, 86, 2], [14, 83, 2]]]
	var lead_b4 := [   # Vulcão (Dó menor)
		[[0, 72, 2], [2, 75, 2], [4, 79, 4], [8, 77, 2], [10, 75, 2], [12, 72, 4]],
		[[0, 72, 2], [2, 75, 2], [4, 80, 4], [8, 79, 2], [10, 75, 2], [12, 72, 4]],
		[[0, 75, 2], [2, 79, 2], [4, 82, 4], [8, 79, 2], [10, 75, 2], [12, 79, 4]],
		[[0, 74, 2], [2, 77, 2], [4, 82, 2], [6, 77, 2], [8, 74, 4], [12, 77, 2], [14, 74, 2]]]
	var lead_b5 := [   # Cristal (Fá# menor)
		[[0, 78, 3], [4, 81, 3], [8, 85, 4], [12, 81, 2], [14, 78, 2]],
		[[0, 74, 3], [4, 78, 3], [8, 81, 4], [12, 78, 2], [14, 74, 2]],
		[[0, 81, 3], [4, 85, 3], [8, 88, 4], [12, 85, 2], [14, 81, 2]],
		[[0, 76, 3], [4, 80, 3], [8, 83, 4], [12, 80, 2], [14, 76, 2]]]
	var lead_b6 := [   # Turbo (Si menor, chiptune)
		[[0, 78, 1], [1, 81, 1], [2, 83, 2], [4, 78, 1], [5, 81, 1], [6, 83, 2], [8, 86, 4], [12, 83, 2], [14, 81, 2]],
		[[0, 79, 1], [1, 83, 1], [2, 86, 2], [4, 79, 1], [5, 83, 1], [6, 86, 2], [8, 86, 4], [12, 83, 2], [14, 79, 2]],
		[[0, 78, 1], [1, 81, 1], [2, 86, 2], [4, 78, 1], [5, 81, 1], [6, 86, 2], [8, 86, 4], [12, 81, 2], [14, 78, 2]],
		[[0, 81, 1], [1, 85, 1], [2, 88, 2], [4, 81, 1], [5, 85, 1], [6, 88, 2], [8, 85, 4], [12, 81, 2], [14, 76, 2]]]
	var lead_b7 := [   # Sombra (Sol menor, pesada)
		[[0, 67, 4], [4, 70, 2], [6, 74, 2], [8, 72, 4], [12, 70, 2], [14, 67, 2]],
		[[0, 67, 2], [2, 70, 2], [4, 74, 4], [8, 77, 4], [12, 75, 2], [14, 74, 2]],
		[[0, 70, 4], [4, 74, 2], [6, 77, 2], [8, 74, 4], [12, 70, 4]],
		[[0, 72, 4], [4, 69, 2], [6, 72, 2], [8, 77, 4], [12, 74, 2], [14, 72, 2]]]
	var lead_b8 := [   # Festival (Ré maior, alegre)
		[[0, 78, 2], [2, 81, 2], [4, 78, 2], [6, 74, 2], [8, 78, 2], [10, 81, 2], [12, 86, 4]],
		[[0, 76, 2], [2, 81, 2], [4, 85, 2], [6, 81, 2], [8, 85, 4], [12, 81, 2], [14, 76, 2]],
		[[0, 74, 2], [2, 78, 2], [4, 83, 4], [8, 81, 2], [10, 78, 2], [12, 74, 4]],
		[[0, 79, 2], [2, 83, 2], [4, 86, 2], [6, 83, 2], [8, 79, 4], [12, 83, 2], [14, 79, 2]]]
	var lead_b9 := [   # Deserto (Lá menor, árabe)
		[[0, 81, 2], [2, 82, 2], [4, 81, 2], [6, 76, 2], [8, 81, 4], [12, 84, 2], [14, 82, 2]],
		[[0, 82, 2], [2, 86, 2], [4, 82, 2], [6, 77, 2], [8, 82, 4], [12, 86, 2], [14, 84, 2]],
		[[0, 81, 2], [2, 84, 2], [4, 77, 2], [6, 81, 2], [8, 84, 4], [12, 81, 2], [14, 77, 2]],
		[[0, 79, 2], [2, 83, 2], [4, 86, 2], [6, 83, 2], [8, 79, 4], [12, 83, 2], [14, 81, 2]]]
	var lead_b10 := [   # Cosmos (Mi menor, épica)
		[[0, 76, 3], [4, 79, 3], [8, 83, 4], [12, 79, 2], [14, 76, 2]],
		[[0, 76, 3], [4, 79, 3], [8, 84, 4], [12, 79, 2], [14, 76, 2]],
		[[0, 79, 3], [4, 83, 3], [8, 86, 4], [12, 83, 2], [14, 79, 2]],
		[[0, 78, 2], [2, 83, 2], [4, 87, 4], [8, 86, 2], [10, 83, 2], [12, 78, 4]]]
	var q := ["m", "M", "M", "M"]
	return {
		"menu": {"bpm": 96, "roots": [57, 53, 60, 55], "q": q, "trans": 0, "lead": lead_menu, "wave": "triangle",
			"lvol": .2, "bass": "long", "arp": "slow", "drums": drum_menu, "dbl": false},
		"battle1": {"bpm": 150, "roots": [52, 48, 55, 50], "q": q, "trans": 0, "lead": lead_b1, "wave": "square",
			"lvol": .17, "bass": "eighth", "arp": "8", "drums": drum_b1, "dbl": true},
		"battle2": {"bpm": 132, "roots": [50, 46, 53, 48], "q": q, "trans": 0, "lead": lead_b2, "wave": "saw",
			"lvol": .13, "bass": "eighth", "arp": "8", "drums": drum_b2, "dbl": true},
		"battle3": {"bpm": 164, "roots": [57, 53, 60, 55], "q": q, "trans": 0, "lead": lead_b3, "wave": "square",
			"lvol": .16, "bass": "eighth", "arp": "16", "drums": drum_b3, "dbl": true},
		"battle4": {"bpm": 140, "roots": [48, 44, 51, 46], "q": q, "trans": 0, "lead": lead_b4, "wave": "saw",
			"lvol": .13, "bass": "eighth", "arp": "8", "dbl": true,
			"drums": {"k": "x..x..x.x..x..x.", "s": "....x.......x...", "h": "x.x.x.x.x.x.x.x."}},
		"battle5": {"bpm": 118, "roots": [54, 50, 57, 52], "q": q, "trans": 0, "lead": lead_b5, "wave": "triangle",
			"lvol": .2, "bass": "eighth", "arp": "8", "dbl": true,
			"drums": {"k": "x.......x..x....", "s": "....x.......x...", "h": "x.x.x.x.x.x.x.xx"}},
		"battle6": {"bpm": 176, "roots": [47, 43, 50, 45], "q": q, "trans": 0, "lead": lead_b6, "wave": "square",
			"lvol": .15, "bass": "eighth", "arp": "16", "dbl": true,
			"drums": {"k": "x...x...x...x...", "s": "....x.......x...", "h": "xxxxxxxxxxxxxxxx"}},
		"battle7": {"bpm": 112, "roots": [55, 55, 58, 53], "q": ["m", "m", "M", "M"], "trans": 0, "lead": lead_b7,
			"wave": "saw", "lvol": .14, "bass": "eighth", "arp": "8", "dbl": true,
			"drums": {"k": "x.....x...x.....", "s": "....x.......x...", "h": "x.x.x.x.x.x.x.x."}},
		"battle8": {"bpm": 146, "roots": [50, 45, 47, 43], "q": ["M", "M", "m", "M"], "trans": 0, "lead": lead_b8,
			"wave": "square", "lvol": .15, "bass": "eighth", "arp": "8", "dbl": true,
			"drums": {"k": "x..x..x..x..x...", "s": "....x.......x...", "h": "x.xxx.xxx.xxx.xx"}},
		"battle9": {"bpm": 128, "roots": [57, 58, 53, 55], "q": q, "trans": 0, "lead": lead_b9, "wave": "square",
			"lvol": .15, "bass": "eighth", "arp": "8", "dbl": true,
			"drums": {"k": "x.x...x.x.x...x.", "s": "....x.......x...", "h": "x.x.x.x.x.x.x.x."}},
		"battle10": {"bpm": 124, "roots": [52, 60, 55, 59], "q": q, "trans": 0, "lead": lead_b10, "wave": "saw",
			"lvol": .12, "bass": "eighth", "arp": "16", "dbl": true,
			"drums": {"k": "x.......x..x....", "s": "....x.......x...", "h": "..x...x...x...x."}},
	}


## Versão "última vida": ~15% mais rápida, meio tom acima, bateria mais intensa.
func _final_of(b: Dictionary) -> Dictionary:
	var f := b.duplicate()
	f["bpm"] = int(round(float(b["bpm"]) * 1.15))
	f["trans"] = int(b["trans"]) + 2
	f["wave"] = "saw"
	f["lvol"] = .15
	f["arp"] = "16"
	f["drums"] = {"k": "x...x...x...x...", "s": "....x.......x..x", "h": "xxxxxxxxxxxxxxxx"}
	f["dbl"] = true
	return f


## Música: mesmo arranjo e timbre do som original (mono, ondas cruas, sem pad/eco/reverb).
func _render_music(tr: Dictionary) -> AudioStreamWAV:
	var sd := 60.0 / float(tr["bpm"]) / 4.0
	var steps := 128
	var voices: Array = []
	for step in steps:
		_music_step(voices, step, step * sd, sd, tr)
	_naive = true
	var w := _render(voices, true, steps * sd)
	_naive = false
	return w


func _music_step(vs: Array, step: int, at: float, sd: float, tr: Dictionary) -> void:
	var bar := (step >> 4) % 8
	var sec := bar % 4
	var s := step % 16
	var trans := int(tr["trans"])
	var root := int((tr["roots"] as Array)[sec]) + trans
	var third := 3 if String((tr["q"] as Array)[sec]) == "m" else 4
	var p: Dictionary = tr["drums"]
	var arp := String(tr["arp"])
	if String(p["k"])[s] == "x":
		vs.append(_t("sine", 150, 45, .14, .75, at))
	if String(p["s"])[s] == "x" or (bar == 7 and s >= 12 and arp != "slow"):
		vs.append(_n("band", 1800, 0, .13, .4, at, .002, .7))
		vs.append(_t("triangle", 210, 150, .09, .25, at))
	if String(p["h"])[s] == "x":
		var open := s == 14 and arp != "slow"
		vs.append(_n("high", 7000, 0, .16 if open else .04, .13, at))
	if String(tr["bass"]) == "eighth":
		if s % 2 == 0:
			vs.append(_t("saw", _mtof(root - 12 + (12 if (s == 6 or s == 14) else 0)), 0, sd * 1.7, .22, at, .003, 900))
	elif s == 0 or s == 8:
		vs.append(_t("triangle", _mtof(root - 12), 0, sd * 7.0, .32, at, .02))
	var iv := [0, third, 7, 12]
	if arp == "8" and s % 2 == 0:
		vs.append(_t("square", _mtof(root + 12 + iv[(s >> 1) % 4]), 0, sd * 1.4, .05, at, .003, 3000))
	elif arp == "16":
		vs.append(_t("square", _mtof(root + 12 + iv[s % 4]), 0, sd * 1.1, .045, at, .003, 3500))
	elif arp == "slow" and s % 2 == 0:
		var sl := [0, 7, 12, third + 12, 12, 7, third + 12, 7]
		vs.append(_t("triangle", _mtof(root + 12 + sl[(s >> 1) % 8]), 0, sd * 2.4, .11, at))
	for e in (tr["lead"] as Array)[sec]:
		if int(e[0]) != s:
			continue
		var n := float(int(e[1]) + trans)
		var nlen: float = float(e[2])
		vs.append(_t(String(tr["wave"]), _mtof(n), 0, sd * nlen * .95, float(tr["lvol"]), at, .003, 4500))
		if bool(tr["dbl"]) and bar >= 4:
			vs.append(_t("square", _mtof(n + 12), 0, sd * nlen * .8, float(tr["lvol"]) * .45, at, .003, 5000))
