# 01 — Domínio de negócio AS-IS

Produto no código e nos assets: **Premium Bank**, um **banco digital de demonstração** (super-app). `README.md:L20-L26` declara explicitamente: sample / reference architecture, não app de produção.

## Glossário (ubiquitous language extraída do código)

| Termo | Significado no código | Fonte |
|---|---|---|
| Super App / Micro App | Host fino + módulo de feature isolado | `MicroApp`, `BaseMicroApp` |
| Premium Bank | Nome de marca na UI | `main.dart:L325` |
| User | Titular autenticado (id, name, email) | `user.dart` |
| Account | Conta corrente/poupança/salário/investimento | `AccountType` em `account.dart:L68-L73` |
| Agency / number | Agência e número da conta | `Account.formattedNumber` |
| holderDocument | Documento do titular (CPF/CNPJ não tipado) | `account.dart:L9` |
| AccountBalance | Disponível, bloqueado, cheque especial | `account_balance.dart` |
| overdraft | Cheque especial (`overdraftLimit` / `overdraftUsed`) | `account_balance.dart:L9-L10` |
| Transfer | Transferência entre contas (não-PIX) | `TransferMoneyUseCase`, rota `/account/transfer` |
| Dashboard | Home com saldo, gastos, atalhos | `DashboardMicroApp` |
| QuickAction | Atalho da home (Pix, pagar, cartões…) | `quick_action.dart` |
| Card | Cartão débito/crédito, virtual, contactless | `card.dart` |
| CVV / limit / availableLimit | Dados de cartão no modelo | `card.dart:L11-L13` |
| Payment / bill payment | Pagamento de contas | `Payment`, flag `enable_bill_payments` |
| Pix | Transferência instantânea BR | micro-app `pix` |
| PixKey | Chave: CPF, CNPJ, e-mail, telefone, aleatória | `PixKeyType` `pix_key.dart:L73-L79` |
| endToEndId | Identificador E2E da transação PIX | `pix_transaction.dart:L13` |
| PixQrCode estático/dinâmico | QR com/sem valor e expiração | `pix_qr_code.dart:L14`, `L65-L69` |
| Feature flag | Toggle in-app de produto | `feature_flags_service_impl.dart:L23-L37` |

Não aparecem no código como entidades: TED, boleto (linha digitável), Open Finance, KYC, onboarding regulatório.

## Atores e perfis

| Ator | Como aparece | Evidência |
|---|---|---|
| Usuário titular (demo) | único perfil; email fixo | `AuthMockDataSource` / README credenciais |
| Usuário Google/Apple (stub) | mock sem OAuth | `login_usecase.dart:L16-L23` |
| Operador/admin | **não existe** no código | — |
| Instituição / Bacen / DICT | **não existem** como atores de sistema | — |

Sem RBAC. Sem multi-conta de usuário.

## Casos de uso principais (das rotas + use cases)

1. Abrir o app (`/` splash) → navegar para login ou dashboard.
2. Login email/senha (e stubs social).
3. Registrar usuário / resetar senha (`/register`, `/reset-password`).
4. Ver dashboard (saldo, resumo, quick actions).
5. Ver conta, detalhes, extrato; transferir (`TransferMoneyUseCase`).
6. Listar cartões, detalhe, extrato, bloquear/desbloquear.
7. Listar/pagar contas (`GetPaymentsUseCase`, `MakePaymentUseCase`, `cancelPayment` no repo).
8. Área Pix: listar/registrar/apagar chaves; enviar; receber; gerar/ler QR.

Rotas agregadas pelo host em `app_router.dart:L104-L137`.

## Regras de negócio identificadas

| Regra | Onde | Notas |
|---|---|---|
| Credencial demo aceita só um par email/senha | `auth_mock_datasource.dart:L19`; `auth_service_impl.dart:L22` | Não é política de produção |
| Senha “válida” ≥ 6 chars; “forte” ≥ 8 + A-Z + a-z + dígito + especial | `password_validator.dart:L3-L36` | Validator compartilhado; **não** visto como gate do `LoginUseCase` |
| Conta ativa ⇔ `AccountStatus.active` | `account.dart:L64` | |
| Cartão expirado se `expirationDate < now` | `card.dart:L98` | |
| PIX incoming/outgoing e status pending/completed/failed/returned | `pix_transaction.dart:L69-L83` | |
| QR dinâmico expira em `expiresAt` | `pix_qr_code.dart:L63-L66` | |
| Envio PIX **sem** checagem de saldo/limite/horario | `send_pix_usecase.dart:L13-L26` | pass-through |
| Overdraft: disponível efetivo = available + (limit − used) | `account_balance.dart:L56` | |
| Flags: investimentos/empréstimos/seguro **off**; Pix/pagamentos/cartões **on** | `feature_flags_service_impl.dart:L23-L37` | **UI não consulta** `isEnabled` (grep só acha a impl) |
| `InsufficientFundsException` / `DuplicateTransactionException` existem | `core_interfaces` exceptions | **nenhum use case as lança** |

## Feature flags de negócio (ativas no default)

Ligadas: dark mode, biometria (flag só), push (flag só), card management, pix transfers, bill payments, chat support.

Desligadas: new dashboard, investments, loans, insurance.

Analytics/crash: on fora de debug.

## Contexto setorial

Fintech / banco digital brasileiro **simulado** (PIX, CPF/CNPJ, agência/conta). Implicação: forks que trocarem mock por API real entram em superfície regulada (LGPD + normas Bacen). Hoje não há KYC, limites, consentimento, nem trilha de auditoria persistida.

## Arquivos-fonte desta seção

- `README.md`
- `super_app/lib/main.dart`
- `packages/micro_apps/*/lib/src/domain/usecases/*.dart`
- `packages/core/core_feature_flags/lib/src/feature_flags_service_impl.dart`
- `packages/shared/shared_utils/lib/src/validators/password_validator.dart`
