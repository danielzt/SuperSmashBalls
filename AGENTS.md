# AGENTS.md — Super Smash Balls (pasta `ArtFight`)

Guia para agentes (e pessoas) que vão mexer neste projeto.

## O que é

**Super Smash Balls** é um jogo de luta de plataforma estilo *Super Smash Bros.*, feito em **Godot 4.7 (GDScript, renderer GL Compatibility)**. Interface e textos estão em **português (BR)**. Todo o visual é desenhado por código (`_draw()`), sem imagens ou assets externos.

- Resolução base 1280×720, `stretch mode = canvas_items`, aspecto mantido.
- Cena principal: `main.tscn` (um `Node2D` com `scripts/main.gd`).
- Autoloads: `Inputs` → `scripts/inputs.gd`, `Sfx` → `scripts/sfx.gd` (música e efeitos sonoros procedurais).
- Sem repositório git neste diretório.

## Como rodar

- Jogar: `Jogar Super Smash Balls.bat` · Editor: `Editar Super Smash Balls.bat`.
- Ambos usam `C:\Users\danza\Godot\Godot_v4.7.2-stable_win64.exe` (caminho fixo; ajuste se o Godot estiver em outro lugar).
- Linha de comando: `Godot --path .` (jogo) ou `Godot --path . res://tests/<cena>.tscn` (testes).

## Funcionalidades

- **Menus**: título, configuração, conexão de dispositivos, seleção de personagem, seleção de mapa, fim de partida.
- **Modos** (`main.mode`): `versus` (até 6 lutadores, `MAX_PLAYERS`: humanos + CPUs, 3 vidas), `training` (vidas infinitas, boneco parado ou CPU nível 1–9), `tutorial1` (básico) e `tutorial2` (avançado).
- **Modos de jogo do Versus** (linha "Modo de jogo" na configuração, `main.rule`): Clássico, Frenético (tudo mais rápido: flags de ritmo em `fighter.gd`, `items.rate`, `stage.rate`), Mutadores (1 de 10 por partida: `MUTATORS` em main.gd), Morte Súbita, Caos (mutador novo a cada 15 s) e Caça aos KOs (90 s, vence quem tiver mais KOs). Os efeitos dos mutadores ficam em flags de `fighter.gd` (`dmg_taken`, `push_only`, `swap_ctl`, `invis_mode`, `wind_force`, `run_mult`, `max_mana`) e em `Art.grav/fric`; o filtro Gameboy é um shader em `main.gd`.
- **Partida Infinita** é uma opção à parte (linha na configuração, `cfg_inf`/`inf_run`) que vale para qualquer modo: ao fim de cada rodada o vencedor aparece e a próxima começa com outro mapa, outras cores e outra música.
- **Pausa**: na luta, Start/Options (ou Esc/Select) pausa o jogo (`get_tree().paused`; `main` roda sempre, lutadores/mapa/itens/projéteis são PAUSABLE, a música continua) e abre o menu: voltar, volumes, zerar (treino), pular passo (tutorial), TRAPAÇAS (`CHEATS`, `_cheat`, `_cheat_tick`; partida com trapaça não conta para conquistas) e sair (`_pause_items`, `_draw_pause`).
- **Botão Y**: especial único de cada personagem (`moves["ult"]`, com recarga, sem mana).
- **16 personagens** + opção "Aleatório" (`RANDOM_ID = 16`): Equilibrado, Velocista, Tanque, Grappler, Zoner, Espadachim, Ninja, Aéreo, Mago, Tecnológico, Capoeirista, Trapper, Suporte, Mímico, Assassino, Duelista.
- **39 mapas** com perigos próprios (serras, lava, lasers, meteoros, vento, trem, prensas, eletricidade, ruínas, pêndulos, gêiseres, canhões, buraco negro, espinhos, minas, tornado, avalanche, raios, maré, bumpers, gelo, gravidade baixa, chão que some, farol giratório, paredes, portais, molas, elevadores, pé gigante, ácido, órbitas, ventiladores, lava com bolas de fogo, onda gigante, teias e aranhas…) e **paletas de cores** do cenário. O último (`Procedural`) é gerado do zero a cada partida (`Stages._gen()`: layout de chão, plataformas e 2–3 perigos sorteados). Mapa escolhido na tela de mapas (grade 8×5, com opção "Aleatório").
- **Combate estilo Smash**: dano em porcentagem, knockback, hitstun, escudo, agarrão/arremesso, pulo duplo, queda rápida, plataformas atravessáveis, blast zone, respawn, vidas (stocks) e **barra de mana** (golpes custam mana, regenera com o tempo).
- **IA** com 9 níveis de dificuldade.
- **Controles por dispositivo**: `kb1`, `kb2` (teclados) e `j0..j7` (controles Xbox/PlayStation). Cada jogador entra apertando ATAQUE no seu dispositivo.

## Estrutura

```
main.tscn / project.godot
scripts/
  main.gd         Máquina de estados do jogo (enum S: TITLE, CONFIG, CONNECT, SELECT, FIGHT, OVER, STAGE),
                  menus, HUD, criação de lutadores, feed de golpes, mouse e controle nos menus.
  fighter.gd      CharacterBody2D: física, movimento, estados (hitstun, escudo, invencibilidade…),
                  motor que executa os golpes (passos com tempo), take_hit(), KO/respawn, desenho.
  characters.gd   DADOS dos 16 personagens (peso, velocidade, pulo, caixas de golpe, passos). Cache estático.
  ai.gd           IA: gera entradas virtuais (held/just) como se fosse um controle. Nível 1–9.
  inputs.gd       Autoload: registra ações no InputMap por dispositivo (`kb1_left`, `j0_attack`…),
                  ações globais `start` e `menu_back`, textos de dicas de botões.
  projectile.gd   Projéteis/minas/armadilhas (modos fly | mine | spike | trap), homing, explosão.
  stage.gd        Mapa em jogo: colisões (StaticBody2D), plataformas móveis/desmoronáveis,
                  perigos (serra, lava, laser, vento, trem, prensa, pêndulo, gêiser, minas, tornado, raio, maré, bumper, gelo/gravidade via Art.fric/Art.grav, farol, paredes, portal, mola, ácido, pé gigante, órbitas…) e desenho do cenário.
  stages.gd       DADOS dos 39 mapas e das paletas (chão, plataformas, spawns, perigos) + gerador do mapa procedural (_gen, regenerate).
  backdrop.gd     Fundo animado (céu, estrelas, lua, aurora, nuvens, colinas, ilhas distantes).
  fxlayer.gd      Partículas e screen shake (hit, bloqueio, poeira, KO, respawn).
  tutorial.gd     Passos dos tutoriais básico/avançado; verifica ações do jogador.
  sfx.gd          Autoload `Sfx`: áudio 100% procedural (99 efeitos, incluindo itens `i_*`, perigos `p_*`, golpes no ar, especial Y,
                  torcida, passos, conquistas, modos; + 21 faixas: menu e 10 lutas, cada uma com versão "última vida").
                  Efeitos: ondas com PolyBLEP e reverb curto em tempo real no barramento SFX. Músicas: som original (mono,
                  ondas cruas, sem reverb). Gerado numa thread na 1ª abertura (~25 s) e salvo em user://audio_cache/<chave>/ (<1 s depois;
                  a chave muda sozinha quando sfx.gd muda, ou suba CACHE_VER). Volumes em user://audio.cfg.
                  API: Sfx.play(id), Sfx.hit(dano, %), Sfx.set_music("menu"|"battle"|"final"|"stop"), Sfx.next_battle().
                  Desligado em --headless (testes não tocam som).
  achievements.gd 60 conquistas (`LIST`), contadores (`Ach.add/set_max/mark`) e save em user://conquistas.json (desligado em --headless).
                  Tela `S.ACH` em main.gd (menu título > CONQUISTAS); `_ach_tick` acompanha os humanos na luta; `_ach_win` registra vitórias.
  art.gd          Helpers de desenho (formas arredondadas, rostos, mãos, fonte) e estado estático
                  do mapa atual (`grounds`, `plats`, `respawn`, `pal`) lido por outros scripts.
tests/            Cenas de teste/ferramentas (ver abaixo).
tests_pad.gd/.tscn  Teste de controle (fora da pasta tests/).
```

`.godot/` é cache do editor — não editar nem versionar.

## Convenções e arquitetura

- **Dados × motor**: personagens e mapas são dicionários puros (`characters.gd`, `stages.gd`); a lógica fica em `fighter.gd` e `stage.gd`. Para criar/ajustar um golpe ou mapa, edite os dados.
- **Esquema de golpes** (`characters.gd`): slots `jab, ftilt, utilt, dtilt, dash, nair, fair, bair, uair, dair, grab, b_neutral, b_side, b_up, b_down` (ver `SLOT_ORDER`, `SLOT_NAMES`, `MANA_COST`). Cada golpe é uma lista de **passos** com campo `t` (segundo em que ocorre): `hit, vel, proj, tele, ghost, armor, guard, barrier, heal, buff, fly, area, root_area, grab, morph, stopx`. Use os helpers `_h` (hit), `_v` (vel), `_s` (passo genérico).
- **Mapa**: `name`, `hz_text`, `style` do chão (`island|grass|stone|metal`), `pstyle` das plataformas (`wood|metal|stone|rock`), `ground [x0,x1,topo,espessura]`, `plats`, 5 `spawns`, `respawn`, `hz` (perigos). Perigos só funcionam com `stage.running = true` (durante a luta).
- **Entradas**: tanto humanos quanto IA são acessados pelo prefixo de dispositivo; a IA imita o contrato `held`/`just`. Ações: `left right up down jump attack special shield`.
- **Visual 100% procedural**: nada de sprites; use `Art` para desenhar e `Art.INK` para contornos. Cores do cenário vêm de `Art.pal`.
- GDScript tipado onde possível; `preload` de scripts como `const X := preload(...)`; comentários e strings em português.
- Código de jogo usa `_physics_process` para lógica; constantes de física no topo de `fighter.gd` (GRAVITY, RUN_SPEED, JUMP_VEL, BLAST, SPAWN, START_STOCKS, HB, MAX_MANA…).

## Testes

Cenas em `tests/` (rodar com `Godot --path . res://tests/<nome>.tscn`; as marcadas "headless" podem usar `--headless`):

| Cena | Uso |
| --- | --- |
| `test.tscn` | Testa tutoriais e IA sem depender de teclas (headless, `time_scale` 6×) |
| `test_stages.tscn` | Percorre os mapas (o procedural roda 8 vezes, com layouts diferentes) |
| `test_ach.tscn` | Valida as 60 conquistas, o desbloqueio e abre a tela (headless) |
| `test_mouse.tscn` | Interação do mouse nos menus |
| `bench.tscn` | Benchmark de FPS por mapa (precisa de janela): `-- mapa1,mapa2` |
| `capture.tscn` | Captura de telas |
| `../tests_pad.tscn` | Teste de controle/gamepad |

Após mudanças em golpes, IA, mapas ou física, rode ao menos `test.tscn` e `test_stages.tscn`.

## Dicas para agentes

- Os arquivos grandes são `fighter.gd`, `main.gd` e `stage.gd` (~1.2k linhas cada); leia só o trecho necessário (use `grep` pelos nomes de função).
- Ao adicionar personagem: nova função em `characters.gd` + incluir em `_build()`; atualize `RANDOM_ID`, a grade de seleção (`GRID_ORIGIN`, `CELL`, `RANDOM_RECT`) em `main.gd` se mudar a contagem.
- Ao adicionar mapa: novo `S.append({...})` em `stages.gd` (antes do mapa procedural, que deve continuar sendo o último), lógica do perigo em `stage.gd` (`_update_hazards` + desenho + `preview` em `stages.gd`) e ajuste a grade de mapas (`SG_COLS`, `SG_CELL`) se necessário (hoje 8 colunas × 5 linhas = 40 casas, todas usadas: Aleatório + 39 mapas, com o Procedural no canto inferior direito; para passar de 39 mapas, aumente a grade ou pagine).
- Mantenha textos de UI em português e não introduza assets externos.
- Os `.bat` contêm o caminho absoluto do Godot do usuário; não o altere sem pedir.
