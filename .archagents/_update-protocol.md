# Protocolo de Atualização Incremental de `.archagents/`

> Este documento define como qualquer agente deve atualizar `.archagents/` após fazer uma mudança no código. É referenciado pelo `AGENTS.md` raiz e é de cumprimento obrigatório.

## Quando atualizar

Sempre que a mudança afetar qualquer uma destas dimensões:

- **Arquitetura** (camadas, padrões, boundaries) → `02-architecture.md`
- **Módulos** (novo módulo, reorganização, nova responsabilidade) → `03-modules.md`
- **Dados** (nova entidade, migration, schema) → `04-data-model.md`
- **Integrações** (nova API, mudança de contrato externo) → `05-integrations.md`
- **Infra/DevOps** (nova pipeline, ambiente, secret) → `06-infra-devops.md`
- **Segurança/Compliance** (authN/Z, crypto, PII, LGPD, Bacen) → `07-security-compliance.md`
- **Convenções** (novo padrão adotado ou abandonado) → `08-conventions.md`
- **Domínio** (nova regra de negócio, novo termo no glossário) → `01-business-domain.md`
- **Decisão arquitetural** → criar novo ADR em `09-decisions/ADR-NNNN-*.md`

## Como atualizar

### Passo 1 — Identifique o delta

```bash
git diff --name-only HEAD~1 HEAD        # última mudança
# ou
git diff --name-only <base-ref>         # escopo explícito
```

### Passo 2 — Classifique o impacto

Para cada arquivo alterado, determine quais seções de `.archagents/` são afetadas consultando `.archagents/_meta.json` (que mapeia arquivos-fonte → seções Docs).

### Passo 3 — Atualize apenas as seções afetadas

**Regras duras:**

- Edite só as seções impactadas. **Não** "melhore" seções não afetadas.
- Atualize/adicione citações `path:Lstart-Lend` pra refletir o novo código.
- Se a mudança é arquiteturalmente significativa, crie um ADR em `09-decisions/`.
- Atualize `_meta.json` com os novos hashes SHA-1 dos arquivos-fonte tocados:

```bash
git hash-object <arquivo>
```

### Passo 4 — Verificação

Antes de considerar a atualização completa:

- [ ] Cada afirmação nova tem citação `path:Lstart-Lend`.
- [ ] As linhas citadas existem e correspondam ao que foi afirmado.
- [ ] `_meta.json` continua sendo JSON válido.
- [ ] Nenhuma seção não relacionada foi tocada.
- [ ] Se havia drift registrado nessa área, adicione entrada de reconciliação em `_drift-log.md`.

## O que **não** fazer

- **Não reescreva** arquivos `.archagents/*.md` inteiros. Use edições pontuais.
- **Não remova** citações antigas só porque você adicionou novas. Atualize-as.
- **Não duplique** informação entre seções. Cada fato vive em exatamente um lugar canônico, com referências cruzadas.
- **Não atualize** `.archagents/` para mudanças triviais (typo, rename local sem impacto público, refactor puramente interno sem mudança de comportamento).
- **Não apague** entradas antigas do `_drift-log.md`. Ele é append-only.

## Modo rápido (via skill)

Se você tem o skill `codebase-ops` disponível, invoque o estágio Update com `/ops-config docs` (consumidor: só `asis_scan` + `asis_sync`; `sync-skills.sh` não se aplica).

## Casos especiais

### Grande refactor arquitetural

Se a mudança impacta 3+ seções de `.archagents/`, pare e invoque Design antes de implementar.

### Mudança em ambiente de dev apenas

Scripts locais e IDE configs só entram em `06-infra-devops.md` se virarem convenção do time.

### Mudança de dependência (bump de versão)

Patch: geralmente não. Major de API pública: atualize `05-integrations.md` ou `03-modules.md`.
