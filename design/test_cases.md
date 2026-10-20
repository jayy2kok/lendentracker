# LenDen Tracker — Functional Test Matrix

**Document Reference:** `design/test_cases.md`  
**Application:** LenDen Tracker (LDT) — Android Version 1  
**Specifications:** `design/PLAN.md` and `design/UI_UX.md`  
**Evidence recorded:** 2026-10-20; assessed base revision `dc4950b` (individual historical observations identified below)  

---

## 1. Overview & Classification

This document preserves 62 proposed cases and attaches conservative execution evidence. Planned Type does not assert execution. See [evidence provenance](evidence/provenance.md). The matrix defines acceptance criteria, pre-conditions, step-by-step verification flows, expected outcomes, test types, and priority rankings for all capabilities specified in the project build plan.

### Priority Levels
- **P0 (Critical / Blocker):** Core ledger, financial calculations, database encryption, backup/restore integrity, and crash-free navigation. Must pass for any release.
- **P1 (High):** Contact selection, WhatsApp reminder rendering, payment reversals, app lock, and theme handling.
- **P2 (Medium / Low):** Edge-case format validations, empty states, search/filter combinations, and non-blocking visual feedback.

### Execution Types
- **Unit (U):** Isolated Dart tests (`app/test/*`) for calculation algorithms, entities, and data models.
- **Widget (W):** Flutter widget tests for screen presentation, forms, dialogs, and validation feedback.
- **Integration (I):** On-device/emulator integration tests (`app/integration_test/*`) verifying SQLCipher storage, database transactions, and OS plugins.
- **Manual / E2E (M):** Device/emulator end-to-end verification involving external systems (e.g., WhatsApp app handoff, biometric prompt, OS file picker).

---

## 2. Test Execution Matrix

### 2.1 First Launch, Onboarding & Database Initialization (ONB)

| Test ID | Area | Scenario / Description | Pre-conditions | Test Steps | Expected Result | Type (planned) | Priority | Execution status | Evidence | Method | Device / package | Assessed commit | Execution date | Limitations |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-ONB-01** | First Launch | Fresh install initial screen display | App installed, no prior data | 1. Launch app for the first time. | Welcome screen is shown with LDT logo, LenDen Tracker wordmark, and options: "Create private ledger" and "Restore backup". | W / M | P0 | Passed | E1 | device | V2515 Android 16; com.lendentracker.lenden_tracker.acceptance | historical (exact SHA unavailable) | 2026-10-20 | Complete welcome screen observed; historical revision. |
| **TC-ONB-02** | First Launch | Create private ledger flow | Fresh install state | 1. Tap "Create private ledger". | 1. Random encryption key generated in secure storage.<br>2. SQLCipher encrypted database initialized.<br>3. User routed to Home screen. | I / M | P0 | Partial | E1/E3 | device/integration | V2515 Android 16; com.lendentracker.lenden_tracker.acceptance | historical (exact SHA unavailable) | 2026-10-20 | UI and encrypted restart observed; random-key generation not independently audited. |
| **TC-ONB-03** | First Launch | Offline initialization | Airplane mode active | 1. Enable Airplane mode.<br>2. Launch app.<br>3. Tap "Create private ledger". | Ledger creates successfully without network connectivity or error dialogs. | I / M | P0 | Not run | — | — | — | — | — | No case-specific execution evidence available; proposed criterion only. |
| **TC-ONB-04** | Security | Database encryption verification | App initialized and populated | 1. Extract database file via adb/root or inspect raw bytes.<br>2. Attempt opening via standard SQLite CLI. | File is encrypted with SQLCipher; raw SQLite CLI reports "file is not a database" or invalid header. | I | P0 | Not run | — | — | — | — | — | No case-specific execution evidence available; proposed criterion only. |
| **TC-ONB-05** | Security | Encryption key exclusion from backup | Device OS backup enabled | 1. Inspect Android manifest and platform backup rules. | Database file and secure storage are excluded from Android cloud/auto backup. | I / M | P0 | Not run | — | — | — | — | — | No case-specific execution evidence available; proposed criterion only. |

---

### 2.2 Navigation & Application Shell (NAV)

| Test ID | Area | Scenario / Description | Pre-conditions | Test Steps | Expected Result | Type (planned) | Priority | Execution status | Evidence | Method | Device / package | Assessed commit | Execution date | Limitations |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-NAV-01** | Navigation | Root tabs switching | Ledger initialized | 1. Tap "Home" tab.<br>2. Tap "Loans" tab.<br>3. Tap "Settings" tab. | Active tab switches promptly with clear focus and selection indicator; state persists between tabs. | W / M | P0 | Partial | E1 | device | V2515 Android 16; com.lendentracker.lenden_tracker.acceptance | historical (exact SHA unavailable) | 2026-10-20 | Tabs switched; state persistence between tabs not separately established. |
| **TC-NAV-02** | Navigation | Back stack preservation | In Loan Detail | 1. From Loans list, tap a loan to view Detail.<br>2. Press Android system back button or AppBar back button. | Returns to Loans list with previous scroll position and active filter preserved. | W / M | P1 | Not run | — | — | — | — | — | No case-specific execution evidence available; proposed criterion only. |
| **TC-NAV-03** | Shell | LenDen Tracker branding | Any screen | 1. Observe top AppBar and splash/welcome views. | Correct LenDen Tracker wordmark and LDT logo displayed. | W | P2 | Passed | E1 | device | V2515 Android 16; com.lendentracker.lenden_tracker.acceptance | historical (exact SHA unavailable) | 2026-10-20 | Branding observed on welcome and navigation; historical revision. |
| **TC-NAV-04** | Shell | Empty state presentation | Fresh ledger (0 loans) | 1. Open Home tab.<br>2. Open Loans tab. | Displays informative empty state with clear calls to action to add the first loan. | W | P1 | Passed | E1 | device | V2515 Android 16; com.lendentracker.lenden_tracker.acceptance | historical (exact SHA unavailable) | 2026-10-20 | Empty Home and Loans call-to-action observed; historical revision. |

---

### 2.3 Contacts Integration & Permission Management (CON)

| Test ID | Area | Scenario / Description | Pre-conditions | Test Steps | Expected Result | Type (planned) | Priority | Execution status | Evidence | Method | Device / package | Assessed commit | Execution date | Limitations |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-CON-01** | Contacts | Just-in-time permission request | Add Loan flow; contact permission not yet granted | 1. In Add Loan Step 1, tap "Select contact". | Permission dialog is requested at this moment (never at app launch). | W / M | P0 | Passed | E1 | device | V2515 Android 16; com.lendentracker.lenden_tracker.acceptance | historical (exact SHA unavailable) | 2026-10-20 | Permission prompted on Choose contact, not launch; historical revision. |
| **TC-CON-02** | Contacts | Permission granted & contact selected | Permission dialog open | 1. Grant contact permission.<br>2. Select contact with 1 phone number. | Contact name and normalized E.164 number auto-populate borrower/lender field. | W / M | P0 | Partial | E1 | device | V2515 Android 16; com.lendentracker.lenden_tracker.acceptance | historical (exact SHA unavailable) | 2026-10-20 | Single-number synthetic contact populated; E.164 normalization not independently validated. |
| **TC-CON-03** | Contacts | Contact with multiple phone numbers | Contact has work and mobile numbers | 1. Select contact with multiple numbers. | A dialog prompts user to explicitly pick which phone number to use for messaging. | W / M | P1 | Not run | — | — | — | — | — | No case-specific execution evidence available; proposed criterion only. |
| **TC-CON-04** | Contacts | Permission permanently denied | Permission previously denied | 1. Tap "Select contact". | User is shown an informative non-blocking message explaining permission is needed, with fallback manual entry or Settings link. | W / M | P1 | Not run | — | — | — | — | — | No case-specific execution evidence available; proposed criterion only. |
| **TC-CON-05** | Privacy | Address book privacy | App running | 1. Inspect database tables. | Only the selected contact record is persisted; full address book is never copied or scanned. | I | P0 | Not run | — | — | — | — | — | No case-specific execution evidence available; proposed criterion only. |

---

### 2.4 Loan Creation Wizard (LNC)

| Test ID | Area | Scenario / Description | Pre-conditions | Test Steps | Expected Result | Type (planned) | Priority | Execution status | Evidence | Method | Device / package | Assessed commit | Execution date | Limitations |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-LNC-01** | Loan Creation | Step 1: Direction selection | Add Loan opened | 1. Select "Loan Given" (I lent money).<br>2. Toggle to "Loan Received" (I borrowed money). | UI correctly updates directional labels and visual indicators without relying solely on color. | W | P0 | Partial | E1 | device | V2515 Android 16; com.lendentracker.lenden_tracker.acceptance | historical (exact SHA unavailable) | 2026-10-20 | Direction selected; all directional label states not checked. |
| **TC-LNC-02** | Loan Creation | Step 1: Principal & Currency | Step 1 active | 1. Input principal amount `50,000`.<br>2. Select currency `INR` (or USD/EUR/GBP). | Form formats input in currency minor units; rejects non-numeric or negative values. | U / W | P0 | Partial | E1 | device | V2515 Android 16; com.lendentracker.lenden_tracker.acceptance | historical (exact SHA unavailable) | 2026-10-20 | Synthetic contact selected; alternate manual path not checked. |
| **TC-LNC-03** | Loan Creation | Step 2: No Interest option | Step 1 completed | 1. Select "No Interest".<br>2. Proceed to next step. | Repayment schedule options adjust accordingly; interest rate inputs hidden. | W | P0 | Not run | — | — | — | — | — | No case-specific execution evidence available; proposed criterion only. |
| **TC-LNC-04** | Loan Creation | Step 2: Fixed Total Interest | Step 1 completed | 1. Select "Fixed Total Interest".<br>2. Input fixed amount `5,000`. | Fixed interest is captured; separate options for due at maturity vs custom schedule shown. | U / W | P0 | Partial | E1 | device | V2515 Android 16; com.lendentracker.lenden_tracker.acceptance | historical (exact SHA unavailable) | 2026-10-20 | Fixed interest entered; all validations not checked. |
| **TC-LNC-05** | Loan Creation | Step 2: Simple interest on original principal | Step 1 completed | 1. Select "Interest on original principal".<br>2. Input rate `12%` annual.<br>3. Select Actual/365 convention. | Accrual rules established where partial repayments do not reduce the interest base. | U / W | P0 | Not run | — | — | — | — | — | No case-specific execution evidence available; proposed criterion only. |
| **TC-LNC-06** | Loan Creation | Step 2: Simple interest on remaining principal | Step 1 completed | 1. Select "Interest on remaining principal".<br>2. Input rate `1.5%` monthly. | Accrual rules established where repayments reduce the interest base from effective date. | U / W | P0 | Not run | — | — | — | — | — | No case-specific execution evidence available; proposed criterion only. |
| **TC-LNC-07** | Loan Creation | Step 3: Flexible schedule | Step 2 completed | 1. Select "Flexible / No fixed installments". | Due date is optional; maturity date can be set or left open. | W | P1 | Partial | E1 | device | V2515 Android 16; com.lendentracker.lenden_tracker.acceptance | historical (exact SHA unavailable) | 2026-10-20 | Flexible schedule entered; complete rules not checked. |
| **TC-LNC-08** | Loan Creation | Step 3: One payment at maturity | Step 2 completed | 1. Select "One payment at maturity".<br>2. Set maturity date 6 months ahead. | Total expected payout calculated and scheduled for that date. | U / W | P0 | Not run | — | — | — | — | — | No case-specific execution evidence available; proposed criterion only. |
| **TC-LNC-09** | Loan Creation | Step 3: Monthly recurring installments | Step 2 completed | 1. Select "Monthly installments".<br>2. Set start anchor date Jan 31. | Schedule clamps unavailable month-end dates (Jan 31 -> Feb 28/29 -> Mar 31). | U / W | P0 | Not run | — | — | — | — | — | No case-specific execution evidence available; proposed criterion only. |
| **TC-LNC-10** | Loan Creation | Step 4: Plain-language agreement preview | Steps 1-3 completed | 1. Review Agreement Preview screen. | Plain-language text clearly summarizes lender, borrower, principal, interest method, rate period, and schedule. | W | P0 | Partial | E1 | device | V2515 Android 16; com.lendentracker.lenden_tracker.acceptance | historical (exact SHA unavailable) | 2026-10-20 | Review and save observed; all summary fields not independently checked. |
| **TC-LNC-11** | Loan Creation | Atomic commitment on Save | Review screen | 1. Tap "Confirm & Save". | Loan, initial scheduled dues, and person reference committed atomically in single DB transaction. | I | P0 | Partial | E1/E3 | device/integration | V2515 Android 16; com.lendentracker.lenden_tracker.acceptance | historical (exact SHA unavailable) | 2026-10-20 | Save and same-package restart observed; full atomicity not proved. |

---

### 2.5 Loan Details & Ledger Tracking (DET)

| Test ID | Area | Scenario / Description | Pre-conditions | Test Steps | Expected Result | Type (planned) | Priority | Execution status | Evidence | Method | Device / package | Assessed commit | Execution date | Limitations |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-DET-01** | Loan Detail | Summary metrics display | Active loan with payments | 1. Open Loan Detail screen. | Accurately displays: Outstanding Principal, Accrued Interest, Due Interest, and Future Interest. | W / I | P0 | Partial | E2 | device | V2515 Android 16; com.lendentracker.lenden_tracker.acceptance | dc4950b46f41815e997f7cab4b146c6b89db8c5b | 2026-10-20 | Due and future interest separated in corrected scenario; all metrics not audited. |
| **TC-DET-02** | Loan Detail | Multi-currency balance isolation | Loans in INR and USD exist | 1. View Home and Loans summary. | Currencies are displayed in distinct separate totals; never summed together into a single total. | U / W | P0 | Not run | — | — | — | — | — | No case-specific execution evidence available; proposed criterion only. |
| **TC-DET-03** | Loan Detail | Search and Filter | Multiple loans exist | 1. Filter by "Given" vs "Received".<br>2. Filter by "Active" vs "Settled".<br>3. Search by person name. | List updates instantly and accurately matches selected filters and query string. | W | P1 | Not run | — | — | — | — | — | No case-specific execution evidence available; proposed criterion only. |
| **TC-DET-04** | Loan Detail | Payment history timeline | Loan with 2+ payments | 1. Scroll to Payment History section. | Displays chronological payments with effective date, total, principal allocation, and interest allocation. | W | P0 | Partial | E1/E2 | device | V2515 Android 16; com.lendentracker.lenden_tracker.acceptance | historical (exact SHA unavailable) | 2026-10-20 | Reversal history observed; 2+ payment chronology/all allocations not checked. |
| **TC-DET-05** | Loan Detail | Reversal of posted payment | Posted payment exists | 1. Tap payment entry.<br>2. Select "Reverse payment".<br>3. Provide reversal reason. | Payment is marked reversed (audit trail retained); ledger recalculates balances instantly. | I | P0 | Partial | E2/E3 | device/widget/integration | V2515 Android 16; com.lendentracker.lenden_tracker.acceptance | dc4950b46f41815e997f7cab4b146c6b89db8c5b | 2026-10-20 | Reason prompt/persistence and reversal checked; full audit/balance scenarios not exhausted. |
| **TC-DET-06** | Loan Detail | Agreement Amendment | Active loan | 1. Tap "Amend agreement".<br>2. Change interest rate or maturity date. | Stored as dated amendment with preview of effect on history; original agreement preserved. | I / W | P1 | Not run | — | — | — | — | — | No case-specific execution evidence available; proposed criterion only. |
| **TC-DET-07** | Loan Detail | Full settlement transition | Principal and interest reach 0 | 1. Record final payment settling all dues. | Loan status automatically transitions to "Settled" with settlement date recorded. | U / I | P0 | Partial | E2 | device | V2515 Android 16; com.lendentracker.lenden_tracker.acceptance | dc4950b46f41815e997f7cab4b146c6b89db8c5b | 2026-10-20 | Non-settlement while future interest unpaid observed; final settlement transition not run. |

---

### 2.6 Recording Payments (PAY)

| Test ID | Area | Scenario / Description | Pre-conditions | Test Steps | Expected Result | Type (planned) | Priority | Execution status | Evidence | Method | Device / package | Assessed commit | Execution date | Limitations |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-PAY-01** | Payments | Standard payment recording | Active loan with accrued interest | 1. Tap "Record Payment".<br>2. Input payment amount. | Form defaults to interest-first allocation; shows remaining balance preview before saving. | W | P0 | Partial | E1/E3 | device/integration | V2515 Android 16; com.lendentracker.lenden_tracker.acceptance | historical (exact SHA unavailable) | 2026-10-20 | Full principal payment observed; allocation/validation breadth not established. |
| **TC-PAY-02** | Payments | Custom allocation override | Record Payment opened | 1. Manually adjust Principal and Interest allocations.<br>2. Ensure sum equals Total Amount. | Form validates allocations equal total payment amount; permits custom allocation. | W / U | P0 | Not run | — | — | — | — | — | No case-specific execution evidence available; proposed criterion only. |
| **TC-PAY-03** | Payments | Allocation sum mismatch validation | Record Payment opened | 1. Set total `5,000`.<br>2. Set principal `3,000` and interest `1,500`. | Save button disabled or validation error: "Allocations must equal total payment". | W | P0 | Not run | — | — | — | — | — | No case-specific execution evidence available; proposed criterion only. |
| **TC-PAY-04** | Payments | Overpayment prevention | Outstanding principal `10,000` | 1. Attempt principal allocation of `12,000`. | Input rejected with explanation: "Principal repayment cannot exceed outstanding balance". | U / W | P0 | Not run | — | — | — | — | — | No case-specific execution evidence available; proposed criterion only. |
| **TC-PAY-05** | Payments | Backdated payment entry | Loan has subsequent payments | 1. Record payment with effective date 30 days in the past. | Database saves payment and recalculates subsequent interest accruals and balances deterministically. | U / I | P0 | Not run | — | — | — | — | — | No case-specific execution evidence available; proposed criterion only. |

---

### 2.7 WhatsApp Reminder Sharing (WHT)

| Test ID | Area | Scenario / Description | Pre-conditions | Test Steps | Expected Result | Type (planned) | Priority | Execution status | Evidence | Method | Device / package | Assessed commit | Execution date | Limitations |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-WHT-01** | WhatsApp Share | Reminder card rendering | Active loan with balance | 1. In Loan Detail, tap "Share Reminder". | An app-private temporary image card is rendered with loan balance, due date, and LDT branding. | W / I | P1 | Partial | E1/E2 | device | V2515 Android 16; com.lendentracker.lenden_tracker.acceptance | historical (exact SHA unavailable) | 2026-10-20 | Rendered card preview observed; private temp location not audited. |
| **TC-WHT-02** | WhatsApp Share | Preview before handoff | Card rendered | 1. Inspect Reminder Preview screen. | Shows image preview, recipient contact name, and messaging phone number. | W | P1 | Partial | E1/E2 | device | V2515 Android 16; com.lendentracker.lenden_tracker.acceptance | historical (exact SHA unavailable) | 2026-10-20 | Recipient and masked phone preview observed; full content not audited. |
| **TC-WHT-03** | WhatsApp Share | Native share handoff | WhatsApp installed | 1. Tap "Send via WhatsApp". | Invokes native share intent directed to WhatsApp with image attached; actual send occurs in WhatsApp. | M | P1 | Partial | E2 | device | V2515 Android 16; com.lendentracker.lenden_tracker.acceptance | dc4950b46f41815e997f7cab4b146c6b89db8c5b | 2026-10-20 | WhatsApp recipient picker opened with image share; no recipient selected or message sent; direct targeting not proven. |
| **TC-WHT-04** | WhatsApp Share | Fallback when WhatsApp unavailable | WhatsApp not installed | 1. Tap "Send via WhatsApp". | Gracefully falls back to system generic share sheet or informs user WhatsApp is not installed. | W / M | P1 | Not run | — | — | — | — | — | No case-specific execution evidence available; proposed criterion only. |
| **TC-WHT-05** | Privacy | Temporary file cleanup | Reminder shared or canceled | 1. Complete or cancel share flow.<br>2. Check app temp directory. | Rendered temporary image files are safely removed; no sensitive artifacts leaked. | I | P1 | Not run | — | — | — | — | — | No case-specific execution evidence available; proposed criterion only. |

---

### 2.8 Security, App Lock & Biometrics (SEC)

| Test ID | Area | Scenario / Description | Pre-conditions | Test Steps | Expected Result | Type (planned) | Priority | Execution status | Evidence | Method | Device / package | Assessed commit | Execution date | Limitations |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-SEC-01** | App Lock | Enable device credential lock | Settings screen | 1. Toggle "Enable App Lock".<br>2. Authenticate with device PIN/Biometrics. | App lock is enabled; status reflected in Settings. | W / M | P0 | Not run | — | — | — | — | — | No case-specific execution evidence available; proposed criterion only. |
| **TC-SEC-02** | App Lock | App backgrounding and resume | App lock enabled | 1. Send app to background.<br>2. Re-open app. | Lock screen overlay is displayed requiring biometric / device PIN before granting access. | W / M | P0 | Not run | — | — | — | — | — | No case-specific execution evidence available; proposed criterion only. |
| **TC-SEC-03** | App Lock | Recent apps switcher privacy | App running | 1. Open Android Recent Apps view. | App window thumbnail is obscured/masked to prevent financial information leakage in task switcher. | M | P1 | Not run | — | — | — | — | — | No case-specific execution evidence available; proposed criterion only. |
| **TC-SEC-04** | Security | Log sanitization | App running in debug/release | 1. Inspect logcat during calculations, logins, and backups. | No passwords, passphrases, contact phonebooks, or financial amounts printed to system logs. | I | P0 | Not run | — | — | — | — | — | No case-specific execution evidence available; proposed criterion only. |

---

### 2.9 Backup, Restore & CSV Export (BKP)

| Test ID | Area | Scenario / Description | Pre-conditions | Test Steps | Expected Result | Type (planned) | Priority | Execution status | Evidence | Method | Device / package | Assessed commit | Execution date | Limitations |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-BKP-01** | Backup | Create encrypted backup | Ledger with records | 1. Go to Settings > Backup.<br>2. Input passphrase.<br>3. Confirm passphrase.<br>4. Select export destination via file picker. | Encrypted file created using authenticated encryption (AES-GCM / PBKDF2/Argon2); last backup date updated. | U / I / M | P0 | Partial | E1 | device | V2515 Android 16; com.lendentracker.lenden_tracker.acceptance | historical (exact SHA unavailable) | 2026-10-20 | Encrypted backup share sheet observed only; destination, cryptography and last-backup date not verified. |
| **TC-BKP-02** | Backup | Restore with correct passphrase | Backup file created | 1. Tap "Restore backup".<br>2. Select backup file.<br>3. Input correct passphrase. | Confirmation dialog displays record counts (loans, payments). Upon confirm, ledger is fully restored. | U / I / M | P0 | Not run | — | — | — | — | — | No case-specific execution evidence available; proposed criterion only. |
| **TC-BKP-03** | Backup | Restore with invalid passphrase | Backup file selected | 1. Input incorrect passphrase.<br>2. Attempt restore. | Decryption fails; error displayed: "Incorrect passphrase or corrupted backup"; existing database untouched. | U / I | P0 | Not run | — | — | — | — | — | No case-specific execution evidence available; proposed criterion only. |
| **TC-BKP-04** | Backup | Restore corrupted/tampered file | Tampered file | 1. Select truncated or modified file. | Integrity/auth check fails; error displayed; existing database safely preserved without data loss. | U / I | P0 | Not run | — | — | — | — | — | No case-specific execution evidence available; proposed criterion only. |
| **TC-BKP-05** | Export | CSV export generation | Ledger with loans & payments | 1. Go to Settings > Export CSV. | Generates clean CSV files for loans and payments with proper escaping and formula injection sanitization (`=`, `+`, `-`, `@`). | U / I | P1 | Partial | E1 | device | V2515 Android 16; com.lendentracker.lenden_tracker.acceptance | historical (exact SHA unavailable) | 2026-10-20 | CSV share sheet observed only; escaping/formula sanitization not audited. |

---

### 2.10 Appearance & Accessibility (THEME)

| Test ID | Area | Scenario / Description | Pre-conditions | Test Steps | Expected Result | Type (planned) | Priority | Execution status | Evidence | Method | Device / package | Assessed commit | Execution date | Limitations |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-THM-01** | Theme | System default appearance | Fresh install | 1. Check default theme setting. | Defaults to "System"; matches Android system light/dark mode automatically. | W | P1 | Partial | E1 | device | V2515 Android 16; com.lendentracker.lenden_tracker.acceptance | historical (exact SHA unavailable) | 2026-10-20 | Immediate theme switch observed; persistence/system mode not checked. |
| **TC-THM-02** | Theme | Explicit Light mode | Settings screen | 1. Select "Light mode". | Entire UI switches to Quiet Ledger light theme immediately and persists across restarts. | W | P1 | Partial | E1 | device | V2515 Android 16; com.lendentracker.lenden_tracker.acceptance | historical (exact SHA unavailable) | 2026-10-20 | Light and dark observed; complete contrast audit not done. |
| **TC-THM-03** | Theme | Explicit Dark mode | Settings screen | 1. Select "Dark mode". | Entire UI switches to Quiet Ledger dark theme immediately and persists across restarts. | W | P1 | Not run | — | — | — | — | — | No case-specific execution evidence available; proposed criterion only. |
| **TC-THM-04** | Accessibility | Contrast and touch targets | Any screen | 1. Measure interactive buttons and text contrast. | All touch targets meet minimum 48x48 dp standard; text meets WCAG AA contrast ratio. | W / M | P1 | Not run | — | — | — | — | — | No case-specific execution evidence available; proposed criterion only. |
| **TC-THM-05** | Accessibility | Screen reader compatibility | TalkBack enabled | 1. Navigate Home and Loan Detail with TalkBack. | All icons and custom buttons have meaningful semantic labels; balances read correctly. | M | P1 | Not run | — | — | — | — | — | No case-specific execution evidence available; proposed criterion only. |

---

### 2.11 Financial Engine & Calculation Rules (FIN)

| Test ID | Area | Scenario / Description | Pre-conditions | Test Steps | Expected Result | Type (planned) | Priority | Execution status | Evidence | Method | Device / package | Assessed commit | Execution date | Limitations |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-FIN-01** | Financial Engine | Actual/365 annual simple interest | Principal `100,000`, 10% annual | 1. Accrue for 73 days: `100,000 * 0.10 * (73 / 365)`. | Accrued interest is exactly `2,000.00`; minor units rounded half-up. | U | P0 | Not run | — | — | — | — | — | No case-specific execution evidence available; proposed criterion only. |
| **TC-FIN-02** | Financial Engine | Monthly interest proration | Rate 2% monthly; Jan 1 to Feb 15 | 1. Calculate 1 full month + 15 partial days in Feb (28-day month). | Accrual accurately prorates partial period by actual days in calendar month. | U | P0 | Not run | — | — | — | — | — | No case-specific execution evidence available; proposed criterion only. |
| **TC-FIN-03** | Financial Engine | Fixed total interest early payoff | Fixed interest `10,000` | 1. Repay entire principal early. | Fixed interest remains owed unless an explicit waiver transaction is entered. | U / I | P0 | Partial | E2 | device/widget | V2515 Android 16; com.lendentracker.lenden_tracker.acceptance | dc4950b46f41815e997f7cab4b146c6b89db8c5b | 2026-10-20 | Fixed future interest remained unpaid after principal payoff; explicit waiver branch not exercised on device. |
| **TC-FIN-04** | Financial Engine | Remaining principal reduction | Principal `50,000`, 12% annual | 1. Repay `20,000` principal on Day 30.<br>2. Calculate accrual for next 30 days. | Accrual for subsequent period is calculated strictly on reduced base of `30,000`. | U | P0 | Not run | — | — | — | — | — | No case-specific execution evidence available; proposed criterion only. |
| **TC-FIN-05** | Financial Engine | Interest accrual cessation at maturity | Loan reaches maturity date | 1. Date advances past maturity date without agreement setting. | Ordinary accrual stops at maturity unless continuation is explicitly configured in loan agreement. | U | P0 | Not run | — | — | — | — | — | No case-specific execution evidence available; proposed criterion only. |
| **TC-FIN-06** | Financial Engine | Half-up currency rounding | Fractional calculation | 1. Perform calculation resulting in `.005` minor units. | Rounding follows half-up standard (e.g. `10.5` rounds to `11`). | U | P0 | Not run | — | — | — | — | — | No case-specific execution evidence available; proposed criterion only. |

---

## 3. Execution status summary

Run `python design/evidence/validate_matrix.py` to compute current per-ID and per-area counts. Do not sum overlapping unit/widget/integration/manual test types or infer phone execution from the 47/47 source suite. The validator enforces the fixed 62-ID baseline and status vocabulary. Additional cases require separately numbered IDs and an intentional validator baseline update. This document contains no release certification or complete coverage claim.
