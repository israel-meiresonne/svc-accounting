# svc-accounting

A Rails JSON API for a personal accounting app. It manages accounts, transactions, CSV import, and cross-currency statistics, with no server-rendered views. The `svc-accounting-ui` frontend is its only client.

## Quick start

You'll need Ruby 3.4.7 and PostgreSQL. This repo pins its Ruby version via [mise](https://mise.jdx.dev/) in `.ruby-version`, so run `mise install` from this directory first. If your shell hasn't activated mise, prefix Rails and Bundler commands with `mise exec --`, for example `mise exec -- bundle exec rspec`.

Install dependencies and set up the database:

```bash
bundle install
bin/rails db:create db:migrate
```

`config/credentials.yml.enc` already provides `secret_key_base`, and the app reuses it as the JWT signing secret (`lib/json_web_tokens/configurations/base.rb`), so no separate secret needs configuring for auth to work locally.

Start the server:

```bash
bin/rails server
```

The API now listens on `http://localhost:3000`. Interactive docs are served at `/api-docs` once the OpenAPI file is generated (see "Testing and linting" below).

Currency conversion needs a working API key for at least one of the two rate providers listed under "Environment variables" below. Without one, the app still runs, but any request that triggers a currency conversion fails.

## Environment variables

For local development, set these in a `.env` file at the repo root. `dotenv-rails` loads it into `ENV` on boot, and it's already gitignored, so it never gets committed.

| Variable | Used by | Required |
|---|---|---|
| `CURRENCYLAYER_API_KEY` | `Integrations::Currencylayer::Services::FetchRate` | One of the two providers needs a working key |
| `FREECURRENCYAPI_API_KEY` | `Integrations::Freecurrencyapi::Services::FetchRate` | Same |
| `DATABASE_URL` | Rails' database config | Production only |
| `RAILS_MAX_THREADS` | Database connection pool size | No, defaults to 5 |

## Testing and linting

```bash
bundle exec rspec                          # full test suite
bundle exec rubocop                        # style and lint, rubocop-rails-omakase base config
bundle exec rake rswag:specs:swaggerize    # regenerate openapi/v1/swagger.yaml from the rswag request specs
```

`brakeman` and `bundler-audit` are also available in the `development, test` group for security scanning.

## Architecture

Business logic lives outside `app/models` and `app/controllers`, in `app/domain/<domain>/`, as small single-purpose interactors:

```
app/domain/
├── accounts/       # Create, Update, Delete, SumAll, ResolveBalanceAtCreation, ...
├── currencies/     # Convert, FetchRate, Money (a value object, never a raw float or decimal)
├── integrations/   # One directory per external provider (currencylayer, freecurrencyapi),
│                     each with its own configurations/ and services/ subdirectory
├── transactions/   # Create, Update, CalculateStats, Search, Csv::Import::*, Bulk::*, Pdf::Report::*, Statistics::Aggregate
└── users/          # Create, Update, Authenticate, ResolveCounterparty, SearchCounterparties
```

Every interactor includes `Interactor::Initializer` directly, from the `interactor-initializer` gem rather than the `interactor` gem, so there's no `context` or `fail!` anywhere in this codebase. Each one takes either positional arguments (`initialize_with`) or keyword arguments (`initialize_with_keyword_params`), depending on its parameter shape, and every call site reads `SomeDomain::Action.for(...)`, or `.run` for a zero-argument interactor.

Controllers stay thin. Each one lives at `app/controllers/<domain>/api/v1/<name>_controller.rb`, resolves any `code`-based identifier, calls one interactor, and renders its result. `app/serializers/` shapes every JSON response. Domain-specific exceptions live in `app/errors/<domain>/errors/<name>_error.rb`, each subclassing `BaseError` (`lib/errors/base_error.rb`) with its own `CODE` and `HTTP_STATUS`. `ApplicationController` has exactly one `rescue_from BaseError`, which renders `{ code, message, details }` for all of them.

### Money and currency

Every monetary column is `decimal`, never a float or integer cents. `Currencies::Money` wraps an amount and a currency and is the only representation domain code passes around, so arithmetic between mismatched currencies raises instead of silently converting.

Currency codes stay lowercase everywhere, with one exception: currencylayer and freecurrencyapi both require uppercase ISO codes at their request and response boundary. The frontend's final display formatting is the only other place a code gets uppercased.

Cross-currency conversion always routes through a pivot currency, `CurrencyRate::CENTRAL_CURRENCY` (`"usd"`), via `Currencies::Convert`, the only class that reads `CurrencyRate` rows directly. When `Currencies::FetchRate` tries each provider in turn and every one fails, it leaves the existing rate untouched rather than blanking it, since a stale rate beats no rate at all.

### Identifiers

Every externally visible `account`, `user`, and `transaction` record carries a `code`, a prefixed ULID such as `acc_...`, `usr_...`, or `txn_...`, assigned once in a `before_validation` callback on create. No route, request body, or response ever exposes a numeric `id` instead. An unowned or unknown `code` resolves as a `404`, never a `403`, so the response never confirms or denies that a record exists for someone else.

### Soft deletion

`Account` and `Transaction` both include `SoftDeletable` (`app/models/concerns/soft_deletable.rb`): a `deleted_at` timestamp, an `active` scope that every balance, listing, and statistics query goes through, and a fixed retention period after which a scheduled task purges old soft-deleted rows.

## API surface

All routes sit under `/api/v1`, defined in `config/routes.rb`. For the full request and response contract, see `openapi/v1/swagger.yaml` or `/api-docs` once the server is running.

| Resource | Routes |
|---|---|
| Auth and users | `POST /users/create`, `POST /users/login`, `GET /users/me`, `PATCH /users/me`, `GET /users/counterparties` |
| Accounts | `GET/POST /accounts`, `PATCH/DELETE /accounts/:code` |
| Transactions | `POST/PATCH /transactions`, `GET /transactions`, `GET /transactions/stats`, `POST /transactions/import/preview`, `POST /transactions/import/commit` |
| Bulk transaction actions | `PATCH/DELETE /transactions/bulk`, `POST /transactions/bulk/move`, `POST /transactions/bulk/export_csv`, `POST /transactions/bulk/generate_report` |
| Statistics | `GET /statistics` |

Authentication is a bearer JWT, sent as `Authorization: Bearer <token>` and issued by `/users/login` and `/users/create`. The `Authenticatable` controller concern checks it on every action except those two.
