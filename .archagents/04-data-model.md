# 04 — Modelo de dados AS-IS

Não há banco relacional, migrations, OpenAPI, protobuf ou GraphQL no repositório. Persistência é key-value local (`SharedPreferences` / Hive / `flutter_secure_storage` no pacote de storage) e mocks em memória. Entidades vivem em `domain/entities/`; DTOs em `data/models/` (ex.: `UserModel`).

Imutabilidade: a maioria estende `Equatable` e expõe `copyWith`. `Payment` **não** é `Equatable` (`packages/micro_apps/payments/lib/src/domain/entities/payment.dart:L2-L18`).

Não há dartz/Freezed gerado nas entidades lidas (Freezed está no `pubspec` do host — `super_app/pubspec.yaml:L73-L89` — mas as entidades de domínio são manuais).

## User (auth)

Fonte: `packages/micro_apps/auth/lib/src/domain/entities/user.dart:L4-L22`

| Campo | Tipo | Notas |
|---|---|---|
| id | String | required |
| name | String | |
| email | String | |
| photoUrl | String? | |
| createdAt | DateTime | |
| lastLogin | DateTime? | |

DTO: `packages/micro_apps/auth/lib/src/data/models/user_model.dart`. Mock devolve `id: 'mock-user-id'`, `name: 'Test User'` (`auth_mock_datasource.dart:L19-L26`).

**Invariantes aparentes:** nenhuma no construtor. Senha **não** é campo da entidade.

## Account

Fonte: `packages/micro_apps/account/lib/src/domain/entities/account.dart:L4-L81`

| Campo | Tipo |
|---|---|
| id, number, agency, holderName, holderDocument | String |
| type | `AccountType` {checking, savings, salary, investment} |
| status | `AccountStatus` {active, inactive, blocked, closed} |
| openingDate | DateTime |

Derivados: `formattedNumber` = `agency / number`; `isActive` ⇔ `status == active`.

### AccountBalance

Fonte: `account_balance.dart:L4-L63`

`accountId`, `available`, `total`, `blocked`, `overdraftLimit`, `overdraftUsed`, `updatedAt`. Derivados: `availableWithOverdraft`, `isNegative`, `isUsingOverdraft`.

### AccountStatement / Transaction (account)

`AccountStatement` agrega transações. `Transaction` em `packages/micro_apps/account/lib/src/domain/entities/transaction.dart` — **não é a mesma classe** que `dashboard` `Transaction` (homônimo, outro arquivo).

## AccountSummary (dashboard)

Fonte: `packages/micro_apps/dashboard/lib/src/domain/entities/account_summary.dart:L4-L38`

`accountId`, `accountNumber`, `agency`, `balance`, `income`, `expenses`, `savings`, `investments`, `lastUpdate`.

## TransactionSummary / Transaction / MonthlyExpense (dashboard)

Fonte: `transaction_summary.dart:L4-L50`

`Transaction` do dashboard: `id`, `title`, `description`, `amount`, `date`, `category`, `type` (`TransactionType`). Agregados: `recentTransactions`, `categoryDistribution`, `monthlyExpenses`.

## QuickAction

Fonte: `quick_action.dart:L5-L22`

`id`, `title`, `description`, `icon` (`IconData` — **dependência de Flutter no domain**), `route`, `routeParams`, `isEnabled`.

Anomalia CA leve: entidade de domínio importa `package:flutter/material.dart` (`quick_action.dart:L2`).

## Card

Fonte: `packages/micro_apps/cards/lib/src/domain/entities/card.dart:L4-L108`

| Campo | Tipo | Risco |
|---|---|---|
| number | String | `maskedNumber` mascara do 5º ao 12º |
| cvv | String | **CVV em claro no modelo de domínio** |
| limit, availableLimit | double | |
| isBlocked, isVirtual, isContactless | bool | |
| status | `CardStatus` {active, inactive, blocked, expired, canceled} | |
| type, brand, holderName | String | |
| expirationDate | DateTime | `isExpired` |

Também: `CardTransaction`, `CardStatement`.

## Payment

Fonte: `packages/micro_apps/payments/lib/src/domain/entities/payment.dart:L2-L27`

`id`, `amount`, `recipient`, `description`, `date`, `status` ∈ {pending, processing, completed, failed, cancelled}. Sem `Equatable`/`copyWith`. Sem barcode/linha digitável de boleto no modelo.

Anomalia: o mock usa status string `'paid'`, que **não** é valor de `PaymentStatus`; o mapper cai em `pending` (`payment_model` + `payment_mock_datasource`).

Contrato do repositório: `getPayments`, `getPaymentById`, `makePayment`, `cancelPayment` (`payment_repository.dart:L4-L16`).

## PIX

### PixKey

Fonte: `packages/micro_apps/pix/lib/src/domain/entities/pix_key.dart:L3-L79`

`id`, `value`, `type` ∈ {cpf, cnpj, email, phone, random}, `name?`, `createdAt`, `isActive`. Formatters de CPF/CNPJ/telefone no próprio entity.

### PixTransaction + PixParticipant

Fonte: `pix_transaction.dart:L6-L139`

Transação: `id`, `description`, `amount`, `date`, `type` {incoming, outgoing}, `status` {pending, completed, failed, returned}, `endToEndId?`, `sender`, `receiver`.

Participante: `name`, `document`, `bank`, `agency?`, `account?`, `pixKey?`.

**Sem invariante de amount > 0** no construtor.

### PixQrCode

Fonte: `pix_qr_code.dart:L6-L70`

`id`, `payload`, `pixKey`, `amount?`, `description?`, `createdAt`, `expiresAt?`, `isStatic`. `isExpired` compara `expiresAt` com `DateTime.now()`.

## Config / flags (não são entidades de domínio, mas estado persistido em memória)

`AppConfig` (`packages/core/core_interfaces/lib/src/config/app_config.dart:L2-L28`): `apiBaseUrl`, `appName`, `appVersion`, `buildNumber`, `environment` {development, staging, production}, `additionalConfig`.

Flags default (`feature_flags_service_impl.dart:L23-L37`):

| Key | Default |
|---|---|
| enable_dark_mode | true |
| enable_biometrics | true |
| enable_push_notifications | true |
| enable_analytics | `!kDebugMode` |
| enable_crash_reporting | `!kDebugMode` |
| enable_new_dashboard | false |
| enable_card_management | true |
| enable_pix_transfers | true |
| enable_bill_payments | true |
| enable_investments | false |
| enable_loans | false |
| enable_insurance | false |
| enable_chat_support | true |

`synchronize()` não busca remoto — `Future.delayed(500ms)` (`feature_flags_service_impl.dart:L91-L94`).

## Storage keys

- Auth local: JSON do user em SharedPreferences chave `user`; token pretendido em secure storage chave `access_token` (`auth_local_datasource.dart`). O mock de login **salva o user** e **não** grava token — `AuthRepository.isAuthenticated` checa token ≠ null.
- Auth host **não** persiste nada (`auth_service_impl.dart:L3-L6`).
- Payments: HydratedBloc em `Directory.systemTemp` (`payments_micro_app.dart` onInitialize).

## Identidades de mock (sample)

- Login: `user@example.com` / `password` → `mock-user-id` / “Test User”
- Conta: João da Silva, CPF `123.456.789-00`, agência `0001`, conta `12345-6` (`account_mock_datasource`)
- Cartões: CVV `'123'|'456'|'789'` no mock (`cards_mock_datasource`)

## Arquivos-fonte desta seção

- `packages/micro_apps/auth/lib/src/domain/entities/user.dart`
- `packages/micro_apps/account/lib/src/domain/entities/account.dart`
- `packages/micro_apps/account/lib/src/domain/entities/account_balance.dart`
- `packages/micro_apps/dashboard/lib/src/domain/entities/account_summary.dart`
- `packages/micro_apps/dashboard/lib/src/domain/entities/transaction_summary.dart`
- `packages/micro_apps/dashboard/lib/src/domain/entities/quick_action.dart`
- `packages/micro_apps/cards/lib/src/domain/entities/card.dart`
- `packages/micro_apps/payments/lib/src/domain/entities/payment.dart`
- `packages/micro_apps/pix/lib/src/domain/entities/pix_key.dart`
- `packages/micro_apps/pix/lib/src/domain/entities/pix_transaction.dart`
- `packages/micro_apps/pix/lib/src/domain/entities/pix_qr_code.dart`
- `packages/core/core_feature_flags/lib/src/feature_flags_service_impl.dart`
- `packages/core/core_interfaces/lib/src/config/app_config.dart`
