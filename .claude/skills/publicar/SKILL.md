---
name: publicar
description: Publica o Super Smash Balls no GitHub Pages (https://danielzt.github.io/SuperSmashBalls/). Use quando o usuário pedir para publicar, subir o jogo, atualizar o site ou fazer deploy.
---

# Publicar no GitHub Pages

O site é servido pela branch `main`, pasta `/docs` (repositório `danielzt/SuperSmashBalls`). Publicar = reexportar o build web para `docs/`, commitar e dar push em `main`. O pedido "publicar" já autoriza commit e push em `main`; não precisa perguntar de novo.

## Passos

1. **Estado**: `git status --short` e `git branch --show-current`. Ignore `shots*/` (capturas de tela, nunca commitar).
2. **Testes rápidos** (se houve mudança em golpes, IA, mapas ou física): `Godot --headless --path . res://tests/test.tscn` e `res://tests/test_stages.tscn`. Se falharem, pare e avise.
3. **Exportar** o build web (preset "Web", já configurado em `export_presets.cfg`, saída `docs/index.html`):
   ```powershell
   & "C:\Users\danza\Godot\Godot_v4.7.2-stable_win64.exe" --headless --path . --export-release Web docs/index.html
   ```
   Confirme que terminou com `DONE` e que `docs/index.pck` e `docs/index.wasm` mudaram/existem. Não altere o caminho do Godot.
4. **Commitar** o código e o `docs/` (inclua `.uid` novos de scripts, exclua `shots*/`). Mensagem em português, terminando com a linha de coautoria exigida no ambiente.
5. **Levar para `main`**:
   - Se já está em `main`: `git push origin main`.
   - Se está em outra branch: faça push da branch, depois `git checkout main`, `git merge --no-ff <branch>` (em conflito em `docs/`, reexporte e resolva com o build novo), `git push origin main`, e volte à branch original.
   - Nunca use `--force`.
6. **Verificar**: o Pages leva ~1–2 min para atualizar. Abra https://danielzt.github.io/SuperSmashBalls/ no navegador embutido, confirme que carrega o menu e sem erros no console (o aviso "Service worker already exists" é inofensivo). Se o usuário estiver testando áudio, lembre que a música só aparece depois da geração (~1 min na primeira visita) e que o Chrome pode precisar de um clique na página.
7. Informe o link e o hash do commit publicado.

## Observações

- `project.godot` tem `audio/general/default_playback_type.web=0` (modo Stream): necessário para o som procedural funcionar no navegador. Não remova.
- O export usa threads (`thread_support=true`): o service worker `docs/index.service.worker.js` libera o isolamento cross-origin no Pages; na 1ª visita o Chrome recarrega a página uma vez.
- Se `gh`/credenciais de push falharem, avise o usuário em vez de tentar contornar.
