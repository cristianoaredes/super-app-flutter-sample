# Drift Log

> Registro append-only de divergências detectadas entre `.archagents/` e o código-fonte, que ainda não foram reconciliadas.
>
> **Não edite entradas antigas.** Adicione novas entradas no final. Quando uma entrada é reconciliada, adicione uma nova entrada marcando-a como resolvida, mas não remova a original.

## Formato

Cada entrada segue o template:

```
## DRIFT-YYYYMMDD-NN — <título curto>

- **Detectado em:** YYYY-MM-DD HH:MM:SS
- **Detectado por:** <agente | comando | humano>
- **Seção Docs afetada:** <.archagents/NN-xxx.md §Seção>
- **Arquivo-fonte divergente:** <path:Lstart-Lend>
- **Descrição:** <1-3 frases sobre a divergência>
- **Impacto estimado:** baixo | médio | alto
- **Status:** aberto | reconciliado em DRIFT-YYYYMMDD-NN

### Detalhes

<texto livre, opcional>
```

## Reconciliação

Quando reconciliar um drift:

1. Execute o estágio Update (`update/UPDATE.md` do skill) pra atualizar a seção Docs afetada.
2. Adicione uma nova entrada no drift-log marcando a original como resolvida:

```
## DRIFT-YYYYMMDD-NN — RESOLVE DRIFT-YYYYMMDD-MM

- **Resolvido em:** YYYY-MM-DD HH:MM:SS
- **Resolvido por:** <agente | comando | humano>
- **Seção Docs atualizada:** <path>
- **Commit:** <sha se aplicável>
```

## Entradas

<!-- Novas entradas abaixo desta linha, em ordem cronológica. -->

## DRIFT-20260812-01 — docs/security descreve secure storage ligado; host não usa

- **Detectado em:** 2026-08-12
- **Detectado por:** codebase-ops-bootstrap
- **Seção Docs afetada:** `.archagents/07-security-compliance.md` (já registra o AS-IS do código)
- **Arquivo-fonte divergente:** `docs/security/SECURITY.md:L41-L79` vs `super_app/lib/core/di/injection_container.dart:L76-L78`
- **Descrição:** Guia de segurança ensina `FlutterSecureStorage` como prática do app; o host registra `StorageServiceImpl`/`WebStorageService` e não depende de `core_security`.
- **Impacto estimado:** médio
- **Status:** aberto — código é a verdade; `docs/security/` é prescritivo legado

## DRIFT-20260812-02 — README lista core_security na arquitetura do host

- **Detectado em:** 2026-08-12
- **Detectado por:** codebase-ops-bootstrap
- **Seção Docs afetada:** `.archagents/03-modules.md`
- **Arquivo-fonte divergente:** `README.md:L47` vs `super_app/pubspec.yaml` (sem `core_security`)
- **Descrição:** Diagrama de pastas do README inclui `core_security` como se fizesse parte do runtime orquestrado.
- **Impacto estimado:** baixo
- **Status:** aberto

## DRIFT-20260812-03 — CI escuta main/develop; default git é master

- **Detectado em:** 2026-08-12
- **Detectado por:** codebase-ops-bootstrap
- **Seção Docs afetada:** `.archagents/06-infra-devops.md`
- **Arquivo-fonte divergente:** `.github/workflows/ci_cd.yaml:L3-L8` vs branch `master`
- **Descrição:** Workflow não dispara no branch default atual.
- **Impacto estimado:** alto (CI morto no fluxo principal)
- **Status:** aberto

## DRIFT-20260812-05 — ApplicationHub e feature flags documentados como capacidades; runtime não usa

- **Detectado em:** 2026-08-12
- **Detectado por:** codebase-ops-explorer (pós-bootstrap)
- **Seção Docs afetada:** `.archagents/02-architecture.md`, `05-integrations.md`
- **Arquivo-fonte divergente:** `README.md:L122-L123` vs grep `publish(`/`isEnabled(` só nas impls
- **Descrição:** README lista event bus e feature flags como demonstrados; nenhum micro-app publica eventos nem lê flags.
- **Impacto estimado:** médio
- **Status:** aberto

## DRIFT-20260812-06 — Login do AuthBloc não autentica o AuthService do host

- **Detectado em:** 2026-08-12
- **Detectado por:** codebase-ops-explorer
- **Seção Docs afetada:** `.archagents/02-architecture.md`, `07-security-compliance.md`
- **Arquivo-fonte divergente:** `splash_page.dart:L28-L34` vs `auth_bloc.dart` (login não chama `AuthService.login`); `_onCheckAuthStatus` sempre `UnauthenticatedState`
- **Descrição:** Restart/splash sempre manda para `/login` mesmo após login bem-sucedido na sessão anterior da UI.
- **Impacto estimado:** alto no fluxo de sample (sessão quebrada)
- **Status:** aberto

## DRIFT-20260812-04 — Flutter 3.29 no host/README vs 3.19.x no CI

- **Detectado em:** 2026-08-12
- **Detectado por:** codebase-ops-bootstrap
- **Seção Docs afetada:** `.archagents/06-infra-devops.md`
- **Arquivo-fonte divergente:** `super_app/pubspec.yaml:L6-L8`, `README.md:L8` vs `ci_cd.yaml:L16-L18`
- **Descrição:** Pins de SDK divergentes.
- **Impacto estimado:** médio
- **Status:** aberto
