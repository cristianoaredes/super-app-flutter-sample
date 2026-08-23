# Riscos Consolidados

> Agrupamento dos findings critical/high por área de negócio. Assessment 2026-08-12. Sem `critical` (sample sem backend real; rubric: na dúvida, menor).

## Risco 1 — Autenticação do sample não fecha o ciclo — high

**Findings componentes:** FND-0004, FND-0003

**Cenário concreto:** Usuário faz login com as credenciais do README, o AuthBloc autentica a UI, mas o splash e qualquer volta a `/` leem `AuthService.isAuthenticated` (sempre false). Deep link `/dashboard` ou `/pix` abre a feature sem guarda.

**Probabilidade:** alta (reproduzível em todo `flutter run`)
**Impacto:** o artefato de referência não demonstra o fluxo que o README descreve; forks herdam AuthZ ausente.
**Mitigação sugerida (em alto nível):** unificar sessão (AuthBloc → AuthService ou splash lê o repositório) e redirect de rotas autenticadas.

---

## Risco 2 — Credenciais e tokens em log — high

**Findings componentes:** FND-0001, FND-0002, FND-0010

**Cenário concreto:** Dev liga `mock_data: false` ou captura logcat; senha do mock e headers Dio (Bearer) saem no console.

**Probabilidade:** média (hoje mock; sobe se ligarem API)
**Impacto:** vazamento de senha/token em dispositivo compartilhado; ensino de anti-padrão.
**Mitigação sugerida (em alto nível):** redigir logs; nunca printar senha; interceptor sem body/Authorization.

---

## Risco 4 — Pagamentos no web não inicializa — high

**Findings componentes:** FND-0012

**Cenário concreto:** Usuário autenticado toca Pagamentos no Chrome. `PaymentsCubit` (HydratedCubit) constrói sem `HydratedBloc.storage`; o redirect cai em `#/error`.

**Probabilidade:** alta (reproduzível em todo `flutter run -d chrome`)
**Impacto:** feature de pagamentos ausente no único target que sobe neste ambiente (iOS sim bloqueado por ML Kit).
**Mitigação sugerida (em alto nível):** bootstrap oficial de `HydratedStorage` no host (web + IO) e ensure idempotente no micro-app.

---

## Risco 3 — Gate de qualidade do repositório morto — high

**Findings componentes:** FND-0008, FND-0009, FND-0011

**Cenário concreto:** PR contra `master` não dispara o workflow; mesmo em `main`, Flutter 3.19.x pode recusar o host `>=3.29.2`. Testes de PIX não pegam use case sem regra.

**Probabilidade:** alta (branch default atual = master)
**Impacto:** regressões entram no sample sem analyze/test; a referência perde credibilidade.
**Mitigação sugerida (em alto nível):** alinhar triggers do workflow à branch default e o pin de Flutter ao `pubspec` do host.

---

## Riscos medium (não agregados como “área crítica”)

- Superfície de segurança documentada mas não ligada (`core_security`) — FND-0006, FND-0007.
- PIX/pagamentos sem invariante — FND-0005 (sobe se houver PSP).
