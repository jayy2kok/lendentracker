# LenDen Tracker UI/UX specification

Design review draft, 17 October 2026. Flutter is approved. This document describes interface behavior, not implemented functionality. All names, amounts, and dates in the mockups are fictional.

Revision 2 includes 18 new/revised Stitch screens: 12 light screens and 6 dark examples. The gallery places these first and retains 13 earlier flow references separately. Theme rules apply throughout the eventual app; not every route has a separately rendered dark mockup. The previous 21-screen manifest is preserved in design/stitch-screens-v1.json.

Stitch project: https://stitch.withgoogle.com/projects/4889254299419652146

Stitch design system: Quiet Ledger, asset `4bebad38dffe482eb4b0ef27c793403d`. The design includes primary screens, selected-state interest variants, and empty/error examples. `design/stitch-screens.json` records the latest selected screen revisions and their image/HTML URLs. `design/index.html` is a browsable reference gallery, not an implemented app; its preview images are served by Stitch and require internet access.

## Product structure

Three root destinations: Home, Loans, Settings. Loan details push onto the Loans navigation stack. Add loan is a four-step full-screen flow: Basics > Interest > Repayment > Review. Record payment is a focused form reached from a loan. Backup, restore, and export live under Settings, with backup also accessible from Home.

No account setup, server sync, payment initiation, or shared ledger. First launch offers Create private ledger and Restore backup. Borrowers and lenders must be selected from phone contacts with a usable phone number. Contact selection is requested just in time, not at launch. The optional app lock uses system authentication rather than a custom password recovery flow. User-initiated WhatsApp image reminders are supported; sending occurs in WhatsApp.

## Visual direction: Quiet Ledger

Warm, calm, and legible. Avoid decorative charts or alarming language about family debts.

Brand v2: full name **LenDen Tracker**, paired with a rounded-square **LDT** monogram. Tracker must remain readable in wordmarks, welcome screens, and share cards. Use the LDT mark alone for the app icon or compact spaces, with the accessible name LenDen Tracker. Do not imitate LenDenClub branding or suggest affiliation. Older Stitch revisions remain historical; v2 designs take precedence.

| Token | Value |
| --- | --- |
| Canvas | #F7F6F2 |
| Card/input surface | #FFFFFF |
| Primary action | #146356 with white text |
| Main text | #182B29 |
| Secondary text | #5E706B |
| Border | #E5E3DC |
| Caution | #9A5B18, always accompanied by text/icon |
| Error | #B42318, always accompanied by a specific message |
| Typography | Inter, bundled locally; tabular money figures |
| Body / supporting text | 16 / 14 logical pixels; allow text scaling |
| Heading / balance | 24 / 28-32 logical pixels |
| Spacing | 4/8-based scale; 16px screen gutters; 24px section gaps |
| Corners | 16px cards, 12px controls |
| Interactive target | At least 48 by 48 logical pixels |

The explicit tokens above take precedence over automatically inferred Stitch theme colors. Phone layouts use safe areas and vertical scrolling. A long Stitch render represents scrolling content, not one oversized physical viewport. Footer actions never cover content or the keyboard. Large text can stack paired balance cards. No horizontal scrolling for essential controls.

### Light, Dark, and System appearance

Offer System (default), Light, and Dark in Settings > Appearance. Persist the selection locally. System follows OS changes; an explicit selection overrides them. Apply the theme to every route, bottom sheet, dialog, keyboard style where supported, empty/error state, and system-bar icon contrast. Never clear unsaved form data when appearance changes.

| Semantic token | Light | Dark |
| --- | --- | --- |
| Canvas | #F7F6F2 | #101917 |
| Surface | #FFFFFF | #192622 |
| Raised surface | #F0F2EE | #22342E |
| Primary/action fill | #146356 | #8DD4BE |
| Text on action | #FFFFFF | #10271E |
| Main text | #182B29 | #EDF5EF |
| Secondary text | #5E706B | #B5C8BF |
| Border | #E5E3DC | #40594E |
| Caution text | #9A5B18 | #F0C078 |
| Error text | #B42318 | #FFB4AB |

Use semantic Flutter ThemeData/ColorScheme tokens instead of individual hard-coded screen colors. Verify WCAG AA text contrast and non-text control contrast in both modes. The exported reminder card uses a predictable light background for readability in recipient chats, regardless of the sender's app theme; show that exact image in the preview.

Token contrast spot checks: light secondary text on white 5.24:1, light primary-button text 7.12:1, dark secondary text on surface 8.93:1, dark primary-button text 9.24:1, and dark error text on surface 9.22:1. These pass normal-text AA; generated screens and actual Flutter control boundaries still need individual verification.

## Screen and interaction specification

### First launch and empty Home

Explain: Your ledger stays on this phone. No account needed. Buttons Create private ledger and Restore backup. Mention that keeping a backup is the user's responsibility. After creation, empty Home shows zero balances, 'Your first loan starts here', and Add loan. Do not insert demo records into a real ledger.

### Home

Currency selector scopes all totals. Present Owed to you and You owe separately, explicitly labeled Outstanding principal. Show due amounts with their type: interest, principal, or installment. A due row opens the corresponding loan; no payment is automatically recorded. Active loan rows and View all lead to Loans. Backup reminder appears when there is no backup or the latest backup is stale; it does not block use.

Use an internally consistent fictional portfolio: Amit lent INR 50,000, Riya lent INR 25,000, Neha borrowed INR 20,000. Portfolio totals are INR 75,000 owed to you and INR 20,000 you owe. Screens showing Amit's payment are snapshots as of 17 November 2026; after that payment his principal is INR 45,000.

### Loans and people selection

Search by person; direction filters All/Lent/Borrowed; status Active/Settled; currency filter. A loan row shows person, direction, remaining principal, concise terms, and next due date where applicable. No-results state offers Clear filters; the empty ledger state offers Add loan.

Every new borrower/lender must be chosen from phone contacts. Prefer the OS contact picker/limited-contact grant so the app receives only selected contact data. If a platform integration requires contacts permission, explain it immediately before selection; never upload or bulk-copy the address book. Save the selected display name, chosen normalized phone number, and local contact reference in the encrypted ledger.

When a contact has multiple numbers, require the user to select one. Parse using country-aware phone metadata and normalize to E.164; country code is independent of loan currency. Reject missing, malformed, extension-only, and known non-message-capable number types; allow mobile/fixed-line-or-mobile classifications without falsely certifying reachability. A name alone is insufficient. Contacts with no usable number offer 'Edit in Contacts' and 'Choose another contact'. Return from the OS editor and revalidate; do not silently edit device contacts. Permission denial offers OS Settings or Try again, with existing ledger access unaffected. An empty address book offers Open Contacts to add a person.

Offline validation proves format only, not ownership, SMS reachability, active service, or WhatsApp registration. Use 'Phone format checked', never 'Verified WhatsApp contact'. The user confirms the chosen number is the person's messaging number. No OTP, lookup service, SMS permission, or automatic test message is introduced. Actual delivery depends on the external messaging service.

Keep historical contact snapshots when a device contact is renamed/deleted or a backup is restored. Re-link unavailable contacts before a new share, and explicitly confirm number changes before replacing a loan's messaging destination. Never silently redirect reminders to another number. Restoring a ledger does not recreate phone contacts or invalidate historical financial records. All mockup phone numbers use fictional reserved examples such as +44 7700 900123; no real address-book data is used in Stitch.

### Add loan: Basics

Required: I lent/I borrowed, phone contact with selected valid-format messaging number, positive amount, currency, loan date. Optional note. Show name and chosen number with Change contact; the review screen repeats both. Direction changes labels throughout the flow, including Payment received versus Payment paid. Amount input uses a decimal numeric keyboard and currency precision. Start dates represent actual disbursement; planned future loans are outside version 1. Back retains fields; cancel with changes opens Discard draft?/Keep editing.

### Add loan: Interest

Four radio cards with explanations: No interest; Fixed total interest; On original amount; On remaining amount. Fixed total shows an amount field, no rate period. Percentage methods show rate and monthly/annual period. No interest hides all rate fields. Preview uses concrete amounts without implying a guaranteed total for variable balances. Explain monthly rate is not annual rate; do not silently convert entered values.

Calculation details disclose the approved day-count and partial-period rules in PLAN.md: actual-days/365 annually, anniversary-period monthly prorating with the original month-end anchor, and currency-aware half-up rounding. Stop accrual at maturity by default and on full principal settlement; continuation beyond maturity requires an explicit agreement setting. Fixed total interest has no automatic early-payoff discount. Implementation still requires worked-example verification. No compounding or late-fee controls in version 1.

### Add loan: Repayment

Payment arrangements are independent of the calculation method: Flexible, All at maturity, Regular installments, Interest only. Disable Interest only for no-interest agreements with helper text; all other compatible combinations remain available. Fixed-total interest may be paid in agreed portions; it never repeats as a newly charged fixed amount each month.

Flexible: optional target repayment date. Maturity: required date. Regular: frequency, first due date, agreed installment amount, and payoff/maturity treatment. Interest only: interest due dates and required principal maturity date. Monthly and explicit custom dates cover the initial scope. When fixed interest is split, show each portion and ensure the sum equals the agreed total. Validate date ordering and do not assume that a manually entered installment automatically amortizes the loan.

### Add loan: Review and save

Plain-language agreement plus editable Basics, Interest, and Repayment sections. State 'This records your agreement. No money is transferred.' Save once in a transaction; disable duplicate submission while saving. On success open Loan detail with 'Loan saved on this phone'. On failure retain entries and offer Retry. Never show success until the transaction is committed.

### Loan detail, schedule, and history

Header: person, direction, status. Main balance is outstanding principal; interest due and accrued-but-not-due are distinct where applicable, with an as-of date. Tabs Overview/Schedule/History retain state. Schedule groups overdue, upcoming, and paid entries; flexible loans show 'No scheduled payments'. Future interest is labeled estimated when principal changes could affect it.

History includes origination, payments with allocations, amendments, waivers, and corrections. A reversed payment remains labeled Reversed and excluded from balances. Overflow actions include Edit agreement, Waive interest, Export loan. No destructive deletion of posted history. Settled loans show completion and history; no overdue reminders. A waiver requires amount, date, optional note, and a before/after preview; it cannot exceed eligible interest.

### WhatsApp screenshot reminder

For an active lent loan with a due amount, offer Remind via WhatsApp. Borrowed loans may offer Share loan summary with neutral wording, rather than telling the lender to pay. The user initiates every share; there is no background sender or WhatsApp Business integration.

1. Open an in-app preview showing the linked contact name and selected phone number.
2. Render a screenshot of a dedicated reminder card containing only this loan: LDT / LenDen Tracker, recipient name, loan reference, as-of date, amount currently due with principal/interest breakdown, due date, and outstanding principal separately labeled. Do not include portfolio totals, other contacts, private notes, device chrome, or the recipient phone number in the image.
3. Let the user review the exact image and optional caption, then tap Share to WhatsApp. Explain 'Choose or confirm this contact in WhatsApp. Tap Send there.'
4. Hand the image to WhatsApp through supported native sharing. Target the saved contact only when the platform's supported API actually permits image-plus-recipient handoff. Otherwise, use the WhatsApp recipient picker and prominently retain the intended name/number in the pre-share screen. A text chat deep link cannot be assumed to attach an image. No brittle private intents or undocumented WhatsApp APIs.
5. Returning to the app does not imply Sent or Delivered. Use 'Opened sharing' if recorded; cancellation has no financial effect. SMS transmission is outside this request.

No WhatsApp app: explain installation is needed for that action and allow Cancel or Save reminder image explicitly. Offline: the ledger and preview work; WhatsApp may require connectivity or queue the message. Do not promise delivery. Image-generation/sharing failure retains the preview and offers Retry. Use app-private temporary storage with platform content-URI/file sharing permissions, no photo-library permission by default, and clean temporary images after the receiving app has had time to consume them. No automated recipient selection or final Send operation is performed by LenDen Tracker.

### Record payment

Date, total, principal/interest split, optional reference and note. Suggest allocation but let the owner match the actual agreement. Show preview before saving. Example: INR 5,500 received = INR 500 interest + INR 5,000 principal; principal goes from INR 50,000 to INR 45,000; interest due becomes zero.

Reject zero/negative totals, allocation mismatch, negative components, future actual-payment dates, payment before origination, and principal overpayment. An allocation mismatch keeps entered values and shows the exact difference. Backdated payments warn that later balances will recalculate and show the revised outcome before confirmation. Corrections reverse and replace the existing record with a reason; they do not silently rewrite history.

### Settings and app lock

Security section: database protection status in plain language ('Encrypted on this phone'), optional app lock with OS authentication, and clear fallback if biometrics are unavailable. No fabricated custom PIN recovery. Mask the app-switcher preview. Default currency, data actions, and app version follow. All required assets, fonts, and icons ship locally for offline operation.

Appearance provides System/Light/Dark with immediate preview. Contacts explains selected-contact access and links to OS settings only when needed. Privacy wording must distinguish local storage from deliberate exports/shares: 'Your ledger stays on this phone. Share a reminder only when you choose.'

### Encrypted backup

Show last successful backup date or Never backed up. Create backup asks for passphrase and confirmation, with reveal controls and paste allowed. Explain: 'You will need this passphrase to restore. It cannot be recovered.' Continue opens the OS destination picker. Success appears only after the file is actually written, not merely after encryption or share-sheet opening. Canceling the picker leaves the last-backup date unchanged. Show failed write/storage-full messages with Retry; preserve records.

The user can select a cloud-backed OS destination, but LenDen Tracker itself does not sync. Use wording 'Saved to your chosen location' instead of claiming the file is outside the device without evidence.

### Restore

Choose backup > enter passphrase > validate > preview > confirm replacement > restore > result. Preview shows filename, backup date, supported format version, currency-separated totals, people/loan/payment counts, and comparison with current record counts. Explicit warning: 'Restoring replaces the ledger currently on this phone. It does not merge records.' Offer Back up current ledger and Cancel alongside Restore and replace.

Wrong passphrase/tampered file: 'We could not unlock this backup. Check the passphrase or choose another file.' Unsupported version, invalid records, insufficient space, and interrupted operation have actionable messages. Never replace current data before validation completes. Retain a rollback copy until the new database opens successfully. A successful restore may optionally prompt to enable app lock; never import old device secrets.

### CSV export

Choose all loans or selected loan, Loans/Payments or both, currency/filter scope, and date range for payments. Use concise copy: 'CSV files are not encrypted. Anyone with the file can read your records. Use an encrypted backup to restore your ledger.' Explicit Export CSV button opens OS sharing/saving. Cancellation is not success. Export includes currency, unambiguous dates, direction, and payment allocation; no encryption keys or backup passphrase.

## Accessibility and platform behavior

- Semantic labels for icon buttons; screen readers announce direction and currency with amounts.
- Logical reading order, visible input labels, and focus moved to the first invalid field after submission.
- Status communicated with words and symbols, never color alone.
- Body text and essential actions support 200% scaling without clipping.
- Respect reduced motion; avoid animated balance counters.
- Android back and iOS back gestures preserve form state and protect unsaved changes.
- OS-native date/file/share/authentication surfaces; do not imitate OS permission screens inside the app.
- Currency entry preserves precision; display Indian grouping for INR and locale-appropriate formatting otherwise.

## Review checklist before Flutter implementation

Verify generated screens against this specification; static generated controls are not a functioning prototype. Check amount consistency, 390px logical layout, keyboard behavior, 48px targets, contrast, and text scaling in both themes. Approve exact interest conventions separately. Test empty, populated, settled, invalid-input, backup failure, restore failure, denied/limited contacts, multiple/invalid numbers, changed/deleted contacts, WhatsApp absent, sharing cancellation, and offline handoff. Confirm no cloud sync, automatic messaging, payment transfer, bulk contact import, or shared ownership. Verify image-plus-recipient sharing on physical Android and iOS before promising direct-contact handoff.

## Design decisions and review notes

- Approved by user: Flutter, private ledger, both phone platforms, offline operation, encrypted local DB, backup/export, all listed interest arrangements.
- Proposed design choice: three root destinations and a four-step loan form, to keep interest calculation separate from payment timing. A single long form was rejected for readability.
- Proposed visual choice: warm ivory and forest teal with simple typography; no decorative financial charts.
- Review correction: removed a generated net-balance banner so amounts owed in opposite directions remain distinct.
- Earlier review removed unsolicited reminder drafts, receipts, custom draft management, and unrelated implementation jargon. User subsequently approved manual WhatsApp screenshot reminders; automatic drafts/sending remain excluded.
- Review correction: changed maturity wording to remaining principal and made repayment dates editable rather than inferred from the interest rate period.
- Illustrated recovery protection: backup passphrase guidance, explicit replace-not-merge confirmation, and a failed-unlock state that preserves the current ledger.
- Still subject to implementation verification: actual encryption, financial calculations, native authentication, cross-platform restore, accessible contrast/semantics, dynamic text, keyboard avoidance, and error recovery. Mockups alone do not verify these behaviors.
- User-approved v2 changes: LenDen Tracker branding with LDT mark, mandatory phone-contact borrowers/lenders, user-triggered WhatsApp screenshot reminders, and Light/Dark modes with System default.
- Platform limitation: offline number format checks cannot verify messaging capability; image-plus-recipient WhatsApp targeting is platform-dependent and must fall back to user recipient selection when unsupported.
