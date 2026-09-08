# Contrato Operacional — thin-client (codebase-ops)

Projeto **consumidor enxuto** (TCK-2821 fase 1): NÃO há cópia do motor neste
repo. O runtime vive em UM artefato — `.orqo/engine.pyz` — e os stubs em
`scripts/hooks/` apenas o resolvem e delegam.

## Resolução do motor (única fonte: `.orqo/resolve-engine.py`)

1. `.orqo/engine.pyz` LOCAL, procurado daqui para cima (semântica git);
2. `$CODEBASE_OPS_ENGINE_DIR` (override explícito);
3. `~/.orqo/engine.pyz` (instalação global / air-gap);
4. nada → **erro instruído, rc 3**: construa com `build-engine.sh` no repo do
   framework e copie `dist/engine.pyz`, ou instale em `~/.orqo/engine.pyz`.

## Como operar

    bash scripts/hooks/engine-doctor          # saúde do encadeamento (CI/clone fresco)
    bash scripts/hooks/cbops cbctl --help     # qualquer módulo, dentro do motor

Estado do ciclo em `.archagents/` (texto puro, rastreável por ID:
TCK/DES/ADR/RUN/VER/FND…). Piso SAFETY: inegociável em qualquer nível de
autonomia — secret/prod/git-destrutivo param SEMPRE. O piso mecânico completo
(regex/gitleaks no pre-commit) acompanha a conversão da frota (fases 3–4);
hoje o pre-commit thin falha fechado se o motor não resolver.

## Atualização do engine

Pin e checksum vivem em `.archagents/_meta.json`. Para trocar a versão,
substitua `.orqo/engine.pyz` e regrave o sha256 no `_meta.json`.
