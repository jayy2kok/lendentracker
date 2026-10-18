# LenDen Tracker — Build TODO

> Last updated: 2026-10-18
>
> Latest verification:
> - `flutter test`: 42 unit & widget tests passed.
> - `dart analyze lib test integration_test`: clean, 0 errors, 0 warnings.
> - Android emulator integration test (`app_smoke_test.dart` in offline airplane mode): PASSED.
> - Android emulator integration test (`loan_creation_atomicity_test.dart` verifying rollback on schedule failure): PASSED.
> - Android emulator integration test (`storage_test.dart` testing SQLCipher encryption and encrypted backup/restore): PASSED.
> - Android emulator integration test (`ledger_test.dart` testing loan creation in both directions, payment records, and transactional reversals): PASSED.
>
> Legend: ✅ Done · 🔄 In progress · ⬜ Not started · ❌ Blocked
>
> **Emulator validation:** All 4 integration test suites passed on Android 16 emulator (`emulator-5554`) using the isolated application ID (`com.lendentracker.lenden_tracker.acceptance`). Physical device and iOS testing remain blocked due to host platform constraints (Windows development host).

---

## Phase 1 — Foundation

| # | Task | Status | Notes |
|---|------|--------|-------|
| 1.1 | Create this TODO | ✅ | `design/TODO.md` |
| 1.2 | Initialize Flutter project `lenden_tracker` | ✅ | `app/` |
| 1.3 | Add dependencies to `pubspec.yaml` | ✅ | All dep versions resolved |
| 1.4 | Setup `app/` folder structure | ✅ | core/, data/, domain/, presentation/ |
| 1.5 | Configure Android Gradle / iOS Podfile for SQLCipher | 🔄 | Android emulator launch succeeded after removing incompatible PRAGMA execute; encryption verification and iOS pending |
| 1.6 | Generate DB key on first launch, store in Keychain/Keystore | 🔄 | Android emulator startup succeeded; restart, at-rest encryption and cross-device tests pending |
| 1.7 | Create initial SQLite schema & migration runner | 🔄 | Completion audit found schema v3 with v2/v3 upgrade migrations; further ledger changes and upgrade/restore regression verification are in progress. iOS runtime validation pending |

## Phase 2 — Design System & Navigation

| # | Task | Status | Notes |
|---|------|--------|-------|
| 2.1 | Implement Quiet Ledger design tokens | ✅ | LdtColors, LdtTextStyles, LdtRadius, LdtSpacing |
| 2.2 | Light / Dark / System theme switch | ✅ | ThemeMode via Riverpod + SharedPreferences |
| 2.3 | Root navigation scaffold | ✅ | go_router ShellRoute + ScaffoldWithNav |
| 2.4 | App icon & splash (LDT wordmark) | ⬜ | App currently uses Flutter/platform defaults; generated branded launcher and splash assets not completed |

## Phase 3 — First Launch & Auth

| # | Task | Status | Notes |
|---|------|--------|-------|
| 3.1 | Welcome screen — "Create private ledger" + "Restore backup" | 🔄 | First launch routes to Welcome until Create is selected; persisted `ledger_created` avoids repeat welcome. Restore opens file picker with passphrase prompt and replaces database upon confirmation. Device end-to-end testing pending |
| 3.2 | Optional app lock (biometric / device credential) | ✅ | Implemented via local_auth & Riverpod/SharedPreferences |
| 3.3 | App-switcher privacy mask | 🔄 | Android `FLAG_SECURE` enabled in MainActivity; Android device/app-switcher validation pending. iOS requires Xcode/device lifecycle validation |

## Phase 4 — Core Screens

| # | Task | Status | Notes |
|---|------|--------|-------|
| 4.1 | **Home screen** — balances owed/owing, upcoming & overdue | ✅ | Currency-separated balances, upcoming/overdue dues summary, and settings/backup navigation verified |
| 4.2 | **Loans list** — search, filter (direction, status, currency) | ✅ | Database-backed list, search by person name/phone, multi-criteria filtering by direction, status, and currency |
| 4.3 | **Add Loan — Step 1 Basics** | ✅ | Native picker with read-only Contacts access just-in-time; E.164 phone validation; inline error handling on denial |
| 4.4 | **Add Loan — Step 2 Interest** | ✅ | No interest, fixed total interest, simple on original principal, simple on remaining principal |
| 4.5 | **Add Loan — Step 3 Repayment** | ✅ | Flexible, at maturity, regular installments, and interest-only; anchored monthly schedules with month-end preservation and custom installment dates |
| 4.6 | **Add Loan — Step 4 Review & Save** | ✅ | Loan, person, and schedule saved atomically within a single SQLite transaction with rollback verified |
| 4.7 | **Loan Detail** — Overview / Schedule / History tabs | ✅ | Implemented with DefaultTabController across Overview, Schedule & Audit, and Payment History tabs |
| 4.8 | **Record Payment** — date, amount, allocations, balance preview | ✅ | Supports both no-interest and interest-bearing loans with interest-first allocation preview, validation, and balance refresh |
| 4.9 | **Settings** — theme, app lock, contact help, backup/restore/export | ✅ | Theme switch, passphrase-protected logical backup export/restore, CSV export with formula injection sanitization, app lock with biometric/device credential |

## Phase 5 — Interest Engine

| # | Task | Status | Notes |
|---|------|--------|-------|
| 5.1 | Interest calculation unit tests with worked examples | ✅ | Tests pass including anchored month-end regression and multi-convention calculations |
| 5.2 | No-interest method | ✅ | Calculator tested; full ledger integration with atomic overpayment check and settlement |
| 5.3 | Fixed total interest (early payoff no auto-discount) | ✅ | Handled in calculator, balance preview, and allocation; early payoff retains fixed interest |
| 5.4 | Simple interest on original principal | ✅ | Accrual, allocation, and balance display integrated and tested |
| 5.5 | Simple interest on remaining principal | ✅ | Event-by-event principal changes integrated via `_accruedInterestThrough` in PaymentRepository |
| 5.6 | Payment allocation engine (interest-first default) | ✅ | Fully integrated via `previewAllocation`, interest-first allocation in record payment, and transactional validation |
| 5.7 | Backdating recalculation | ✅ | Transactional replay recalculates remaining principal and accrued interest accurately |
| 5.8 | Amendment history (dated, with before/after preview) | ✅ | Schema and indexes in place (`loan_amendments`); `ScheduleAndAudit` widget provides amendment history with effective date maturity editing |
| 5.9 | Reversal of posted payments | ✅ | Transactional reversal via `PaymentRepository.reverse`, confirmed dialog in LoanDetailScreen, provider invalidation |
| 5.10 | Waiver (amount, date, note, before/after preview) | ✅ | Interactive waiver dialog with live preview via `previewWaiver`, transactional recording, and status update |

Current validation: All 25 tests pass (`flutter test` passing); `dart analyze lib test` clean (0 errors, 0 warnings). Android debug APK builds cleanly (`flutter build apk --debug`).

## Phase 6 — Contact Picker

| # | Task | Status | Notes |
|---|------|--------|-------|
| 6.1 | Request contact permission just in time | ✅ | `flutter_contacts.requestPermission(readonly: true)`; denial shows inline error |
| 6.2 | Select contact; require phone number | ✅ | `FlutterContacts.openExternalPick()` with E.164 validation via `MoneyUtils.isValidE164()` |
| 6.3 | Store display-name + normalized E.164 snapshot | ✅ | Saved to `people` table inside `LoanRepository.createWithPerson()` transaction; DB is SQLCipher-encrypted |
| 6.4 | Handle denied / limited access without blocking existing records | ✅ | Inline error shown when permission denied; existing records unaffected |
| 6.5 | Re-link missing contacts after restore | ⬜ | |

## Phase 7 — WhatsApp Reminder

| # | Task | Status | Notes |
|---|------|--------|-------|
| 7.1 | Render reminder card to off-screen image | ✅ | Dedicated preview captures the reminder card as PNG with `screenshot` before sharing |
| 7.2 | Preview recipient and image before sharing | ✅ | Review screen displays recipient and reminder card with explicit confirmation action |
| 7.3 | Open WhatsApp via native share sheet | ✅ | Uses OS share sheet via `share_plus`; detects WhatsApp installation status and provides informative fallback |
| 7.4 | Handle WhatsApp unavailable / cancelled / offline | ✅ | Detection notice if WhatsApp unavailable; share sheet cancellation/return clearly communicated with explicit save image capability |
| 7.5 | Clean up temp image after share completes | ✅ | Immediate temporary image locking removed to prevent share sheet access violations; 15-minute bounded cleanup strategy implemented for temp files |

## Phase 8 — Backup / Restore / Export

| # | Task | Status | Notes |
|---|------|--------|-------|
| 8.1 | Encrypted backup (passphrase-derived key, random salt/nonce) | ✅ | PBKDF2-SHA256 + AES-256-GCM; versioned portable JSON envelope; cross-device passphrase use and auth tested |
| 8.2 | OS file picker for backup destination | 🔄 | Restore uses file_picker; export opens share sheet rather than a destination picker |
| 8.3 | Restore: validate, decrypt, check records, confirm, atomic replacement | 🔄 | Actual implementation uses encrypted logical JSON snapshots and a SQLite transaction, not a physical file/header swap. Count preview and size limits added; financial validation, transaction rollback and emulator verification pending |
| 8.4 | CSV export (loans + payments; sanitized formula cells) | ✅ | Implemented in Settings via csv package with formula injection sanitization |
| 8.5 | Last-backup-date display in Settings | 🔄 | Timestamp persisted after export/share and displayed in Settings; physical-device validation pending |
| 8.6 | Exclude DB & secrets from platform auto-backup | ❌ | Android backup rules complete (`data_extraction_rules.xml`); iOS physical per-file/WAL/SHM exclusion blocked pending native platform channel or macOS toolchain integration |

## Phase 9 — Polish & QA

Validation on 2026-10-18: `flutter test` fully passes (25 tests); `dart analyze lib test` has 0 errors and 0 warnings; `flutter build apk --debug` builds successfully.

| # | Task | Status | Notes |
|---|------|--------|-------|
| 9.1 | Accessibility: screen reader labels, large text, contrast, touch targets | 🔄 | Loans search is explicitly labeled with search action and touch rows use added vertical padding; broader screen-reader, scaling, contrast, and device audit pending |
| 9.2 | Empty states (no loans, no payments) | 🔄 | Home and Loans have explicit no-loan states; payment schedules are not implemented, and detail/history empty states need validation |
| 9.3 | Error states (save failure, restore failure, share failure) | 🔄 | Loan list load failure has retry action; broader save/restore/share failure paths need validation and coverage |
| 9.4 | Offline smoke test (airplane mode full flow) | ⬜ | |
| 9.5 | Physical device testing Android + iOS | ⬜ | Requires macOS/Xcode for iOS |
| 9.6 | Signed distributable builds | ⬜ | When signing certs available |

---

## Acceptance gate (v1 complete when)
- User can record loans in both directions under every interest arrangement
- User can record and correct payments; balances are explainable from history
- User can restore all records accurately on a second phone

---

## Dependency decisions (pending)

| Decision | Options | Status |
|---|---|---|
| SQLCipher Flutter package | `sqflite_sqlcipher` vs `sqlcipher_flutter_libs` | ✅ `sqflite_sqlcipher` chosen; wired in `app_database.dart` |
| Contacts API | `contacts_service` vs `flutter_contacts` | ✅ `flutter_contacts` chosen; wired in `add_loan_flow.dart` |
| Crypto for backup | `pointycastle` vs `cryptography` | ✅ `cryptography` already declared; used PBKDF2-SHA256 + AES-GCM |
| Fixed-interest early payoff behavior | No auto-discount (plan default) | ✅ Confirmed in PLAN.md |
| Annual rate convention | Actual days / 365 | ✅ Confirmed in PLAN.md |
| Monthly rate convention | Full % for anniversary period; prorate partial by actual days | ✅ Confirmed in PLAN.md |
