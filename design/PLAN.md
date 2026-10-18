# LenDen Tracker — draft build plan

Status: Flutter implementation exists in `app/` and completion/verification is in progress. Stitch UI/UX revision 2 incorporates LenDen Tracker/LDT branding, phone contacts, manual WhatsApp image reminders, and Light/Dark/System themes. See UI_UX.md and design/index.html. Financial conventions below are approved; implementation and acceptance evidence are tracked in design/TODO.md. Existing implementation does not by itself establish release readiness.

## Confirmed scope

- Private ledger for loans given and received.
- Android and iOS phone app.
- Core ledger fully offline; no server sync in version 1. User-initiated WhatsApp sharing uses the external app and may need connectivity for delivery.
- Encrypted local database on the phone.
- Backup, restore, and export.
- LenDen Tracker wordmark with concise LDT logo.
- Borrower/lender selected from phone contacts with a usable messaging phone number; offline format validation cannot verify SMS delivery or WhatsApp registration.
- Optional user-initiated screenshot reminder through WhatsApp, with image/recipient preview and final Send in WhatsApp.
- Light and Dark modes, with System as the default setting.
- Support no interest, fixed total interest, interest on original principal, interest on remaining principal, and interest-only payments with principal due at maturity.

## Recommended approach

Use Flutter for a single Android/iOS codebase, with SQLite encrypted using SQLCipher and an OS-protected database key stored through Keychain/Android Keystore integration. Validate maintained library compatibility, licensing, encrypted side files, and physical-device release builds before committing to specific packages. Use a small repository layer for database operations and ordinary Flutter screens; no backend or sync framework.

Alternatives: React Native is reasonable if TypeScript is the team's strongest language, but requires the same native encryption verification. Separate Swift/Kotlin apps provide native control with twice the implementation and maintenance work. Flutter is the proposed default for a new, small app.

## Proposed product defaults

- Default currency INR, selectable per loan; never combine different currencies into a single total.
- One owner and device-local data. Use the native contact picker/limited access where available; obtain permission only when needed and retain only selected contact fields.
- No automatic compounding, late fees, automated messaging, payment transfers, or shared accounts. Manual WhatsApp screenshot sharing is supported.
- Optional biometric/device-credential app lock; database encryption is always enabled.
- Hundreds of loans and thousands of payments; target normal screens opening within two seconds on representative midrange phones.
- Ledger operations and reminder-image rendering work in airplane mode. External message delivery is not guaranteed offline. A successful save means a committed local transaction.
- Maintain one codebase with pinned dependencies and periodic platform/security updates. iOS builds and release testing require macOS/Xcode and signing access.

## Loan agreement and calculation rules

Separate the interest calculation method from the payment schedule. Interest-only is a payment schedule, compatible with original-principal or remaining-principal interest.

Loan fields: direction, person, principal, currency, start date, optional maturity date, interest method, rate or fixed total, rate period (monthly/annual), accrual convention, payment schedule, first due date, and notes. Present a plain-language agreement preview before saving.

Calculation methods:

1. No interest.
2. Fixed total interest: agreed once; separately specify when it becomes due. Proposed default: early repayment does not automatically discount the agreed amount; allow an explicit waiver.
3. Simple interest on original principal: partial principal repayments do not reduce the interest base.
4. Simple interest on remaining principal: repayments reduce the interest base from their effective date.

Schedules: flexible/no scheduled installments, one payment at maturity, recurring manually agreed principal-plus-interest installments, and recurring interest-only payments with principal due at maturity. Allow monthly schedules initially, plus explicitly dated custom installments. Do not imply that a fixed installment is an automatically calculated amortization schedule.

Approved conventions: annual rates use actual days/365; monthly rates charge the stated percentage for a full anniversary period and prorate partial periods by actual days in that period. Clamp unavailable month-end dates while preserving the original schedule anchor, including across payment events. Show the convention in the agreement. Stop ordinary accrual when principal is fully settled and at maturity by default; continuation after maturity requires an explicit agreement setting. Fixed total interest remains owed on early payoff unless explicitly waived; it is due at maturity when present, otherwise explicit due dates or portions are required. Use half-up rounding to currency minor units at posted allocation/display boundaries, with exact decimal calculations. Validate these rules with worked-example tests, including partial periods, due boundaries, and early payoff.

Use integer minor units for persisted money, decimal arithmetic for rates/calculations, and an explicit currency-aware rounding policy. Use local calendar dates for financial events, not elapsed timestamp hours. Distinguish accrued interest from due interest and future scheduled interest.

Payments store effective date, total, principal allocation, interest allocation, and optional note/reference. Suggest interest-first allocation but allow explicit principal/interest allocation. Validate that allocations equal the total, principal cannot fall below zero, and unsupported overpayments are rejected with an explanation. Backdated entries recalculate affected balances and dues deterministically.

Keep a history of corrections and waivers. Reverse and replace posted payments instead of silently overwriting them. Preserve original agreement terms; store changes as dated amendments with a preview of their effect on history. Mark a loan settled only when principal and agreed outstanding interest are paid or explicitly waived.

## Screens

1. Home: amounts owed to me/by me, currency-separated balances, upcoming and overdue payments.
2. Loans: search and filter by person, direction, status, and currency.
3. Add loan: required phone contact/number and amount, interest rules, payment schedule, agreement preview.
4. Loan detail: original agreement, outstanding principal, accrued/due interest, schedule, payments, amendments, and manual WhatsApp reminder preview.
5. Record payment: date, amount, allocation, resulting balance preview.
6. Settings and data: System/Light/Dark appearance, app lock, contact-access help, encrypted backup, restore, CSV export, last backup date.

Support screen readers, large text, clear focus/labels, adequate contrast, and usable touch targets. Never encode loan direction or overdue status using color alone.

## Local data and privacy

Tables: people, loans, dated agreement amendments, scheduled dues, payments/reversals, and interest waivers. Derive balances from agreements and financial events; avoid competing editable balance fields. Use foreign keys, transactional writes, schema migrations, and trust-boundary validation on all imported files.

People store selected phone-contact references plus display-name and normalized E.164 phone snapshots, encrypted with the ledger. Use maintained country-aware number validation; do not infer country from currency. Require selection among multiple numbers and handle denied/limited access without blocking existing records. Do not import the entire address book. Contact changes and backup restores preserve history; re-link missing contacts and confirm changed numbers before sharing.

WhatsApp sharing renders only the chosen loan reminder card to an app-private temporary image, previews recipient and image, and opens supported native sharing. Direct contact targeting with an image must be proven separately on Android/iOS; fall back to WhatsApp's recipient picker when unsupported. Do not assume a WhatsApp text deep link supports attachments. Never send automatically or report delivery from a share-sheet callback. Validate WhatsApp unavailable, offline, canceled, and failed-share states. No SMS permission or OTP verification service is added.

Generate a random database encryption key on first launch. Store it using platform secure storage; never hard-code it or place it beside the database. Confirm secure-storage accessibility survives ordinary OS upgrades and app restarts. Exclude the database and secrets from automatic platform backup to avoid accidental cloud copies or restoring ciphertext without its key. Mask sensitive app-switcher previews and keep financial data out of logs. No analytics or network service is required.

## Backup, restore, and export

- Backup: a versioned portable snapshot encrypted with authenticated encryption, using a passphrase-derived key and random salt/nonce through maintained cryptographic libraries. It must restore on another Android or iOS phone without the old phone's database key. Passphrases are not stored in backup files and cannot be recovered by the app.
- Use an OS file picker/share sheet so the user selects the destination. The app performs no server sync; an OS destination may be a user-selected cloud provider. Recommend a copy outside the phone for loss recovery.
- Restore: validate file size/format/version, authenticate/decrypt, validate records and relationships, show record counts, and require confirmation before replacing the ledger. Version 1 replaces rather than merges. Retain the existing database until the restored database is validated and the switch succeeds; recover safely after interruption.
- Export: human-readable CSV files for loans and payments, including currency and interest terms. Sanitize spreadsheet formula cells and quote/escape fields correctly. State that CSV is unencrypted and cannot serve as a full-fidelity restore backup. Clean up temporary files after sharing when safe.
- Show last successful backup date and offer an in-app reminder. Avoid background scheduled backup complexity in version 1.

## Build sequence and acceptance gates

1. Finalize agreement examples and basic screen wireframes. Approve interest conventions, fixed-interest early-payoff behavior, allocation defaults, and maturity handling.
2. Validate Flutter + encrypted SQLite + secure storage on both platforms. Confirm database/side files are encrypted and keys are excluded from exports and logs. Establish application structure and migrations.
3. Build contact selection/phone validation, loans given/received, lists, detail, and transactional persistence. Verify all core flows offline, including restart persistence and contact permission denial/changes.
4. Implement deterministic interest and schedule calculations, payment allocation, corrections, waivers, and amendments. Test known financial examples, leap years, month-end dates, partial payments, backdating, rounding, and full settlement.
5. Build encrypted backup/restore and CSV export. Test cross-platform round trips, wrong passphrases, tampered/truncated files, unsupported versions, and interruption without data loss.
6. Add manual WhatsApp image preview/handoff and verify platform targeting/fallback behavior on real phones. No automatic sends or false delivered status.
7. Add System/Light/Dark theme support, app lock, privacy details, accessibility, and empty/error states. Test physical Android/iOS devices, upgrades/migrations, and complete airplane-mode ledger workflows. Prepare signed distributable builds when signing access is available.

Version 1 is complete when a user can record either loan direction under every supported arrangement, record/correct repayments, explain displayed balances from the history, and restore all records accurately on a second phone.

## Decision log

| Decision | Status | Reason / alternatives |
| --- | --- | --- |
| Private, offline ledger without server sync | Confirmed | User preference; shared/cloud accounts excluded |
| Android and iOS phones | Confirmed | User preference; desktop/web excluded |
| Encrypted local database | Confirmed | User preference; plain SQLite insufficient |
| All listed interest arrangements | Confirmed | User preference; calculation and schedule modeled separately |
| Backup and export | Confirmed | User preference; restore included to make backup useful |
| Flutter | Confirmed | User approved one Android/iOS codebase |
| LenDen Tracker + LDT identity | Confirmed | User requested clearer distinction from similarly named products |
| Required phone contact and messaging number | Confirmed | User request; offline validation covers format, not delivery capability |
| Manual WhatsApp screenshot reminder | Confirmed | User request; review then external app handoff, no server or automated send |
| Light/Dark/System appearance | Confirmed | User requested both modes; System default proposed |
| SQLCipher-backed SQLite | Proposed | Meets encrypted local storage requirement; verify platform integration |
| Portable encrypted backup + CSV export | Proposed | Recovery and readable reporting have different requirements |
| Simple interest, no automatic compounding/fees | Proposed | Keeps informal agreement behavior explicit |

## Next discussion

Review the detailed Stitch UI/UX, then review worked interest examples before finalizing the implementation specification.
