# Pocket Ledger

A **local-first** personal finance tracker for Android and iOS. All your data lives
on-device in an SQLite database — no accounts, no servers, no network required. It
starts instantly, works fully offline, and is private by default.

Built with Flutter. The codebase is designed from day one so that optional cloud sync
can be added later as an additive feature, without a schema rewrite.

---

## Features

- **Transactions** — expenses, income, transfers between accounts, and adjustments.
- **People & debts** — lend, borrow, and settle up. Each person has their own ledger
  with a running net balance.
- **Split expenses** — split a bill across people; the split fans out into individual
  lend/expense rows automatically.
- **Accounts** — cash, bank, wallet, savings, credit card, and more, each with a live
  balance recomputed from its history.
- **Categories** — separate expense and income categories with custom icons and colors.
- **Budgets** — an overall monthly budget plus per-category budgets, with sensible
  defaults and the ability to override any individual month.
- **Customizable dashboard** — a grid of widgets you can add, remove, and rearrange.
- **Reports** — monthly summaries and charts.
- **Home-screen widget** — see this month's budget at a glance and jump straight into
  adding a transaction.
- **JSON backup** — export a full copy of your data to share or archive.
- **Balance verification** — recompute every account from its transaction history to
  confirm everything reconciles.
- **Light / dark / system themes.**
- **In-app updater** — checks GitHub Releases on launch and offers to install newer
  builds directly (Android).

## Tech stack

| Concern        | Choice |
|----------------|--------|
| Framework      | Flutter (Dart 3) |
| Local database | [Drift](https://drift.simonbinder.eu/) (SQLite) — type-safe, reactive queries |
| State          | [Riverpod](https://riverpod.dev/) |
| Routing        | [go_router](https://pub.dev/packages/go_router) |
| Charts         | [fl_chart](https://pub.dev/packages/fl_chart) |
| Money          | Stored as integer minor units (cents); `Decimal` only at the input/display boundary |
| IDs            | UUID v4 strings (sync-safe across devices) |

### Local-first by design

Every record uses UUID primary keys, soft deletes, timestamps, and a change journal.
None of this is needed for the on-device app today — it exists so that adding cloud
sync later is purely additive, not a migration project.

## Getting started

You'll need the [Flutter SDK](https://docs.flutter.dev/get-started/install)
(Dart `^3.12.1`) and an Android or iOS toolchain.

```bash
git clone <repo-url>
cd pocket_ledger_app

flutter pub get

# Generate Drift database code (and other generated sources)
dart run build_runner build --delete-conflicting-outputs

flutter run
```

### Common commands

```bash
flutter analyze                 # static analysis
flutter test                    # run the test suite
flutter build apk --release     # Android release build
flutter build ios --release     # iOS release build
```

> After changing anything under `lib/core/db/`, regenerate the Drift code with
> `dart run build_runner build --delete-conflicting-outputs`.

## Project layout

```
lib/
  core/        # database, router, theme, update, home-widget, shared utils
  data/        # repositories (accounts, transactions, people, budgets, …)
  domain/      # financial logic — ledger, splits, dashboard & report summaries
  features/    # UI: dashboard, add_transaction, transactions, people, more
  providers/   # Riverpod providers wiring data into the UI
  app.dart     # root widget
  main.dart    # entry point
test/          # unit & widget tests (heaviest coverage on the financial logic)
```

The financial logic in `lib/domain/` is the highest-risk area and carries the heaviest
test coverage — balance updates, settlements, splits, and net-balance math.

## Contributing

Contributions are welcome. Please:

1. Run `flutter analyze` and `flutter test` before opening a PR.
2. Keep new financial logic in `lib/domain/` covered by tests.
3. Match the style and conventions of the surrounding code.
