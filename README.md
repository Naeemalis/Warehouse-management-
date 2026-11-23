# NaeemSoft WMS

Offline-first Android Warehouse Management System built with Flutter and SQLite.

## Implemented in the development branch
- Product gallery using a responsive grid, with product creation and long-press editing for name and prices.
- User-defined base unit and additional units/conversion factors; examples include carton, pack, piece, kg, gram, litre and custom units.
- Supplier/customer management screens.
- Receiving flow: supplier, product, unit, quantity, purchase price, supplier-specific conversion override and packaging note; lines are collected in a basket and submitted for approval.
- Issue flow: customer/recipient, product, choose unit before quantity, collect mixed-unit lines in a basket and submit for approval.
- Pending approval queue with approve/reject actions and rejection reason.
- Draft/pending documents do not affect stock. Approval posts stock movements atomically; issue approval aggregates all lines for the same product before checking available stock.
- Separate delivery confirmation screen for approved issue documents, recording recipient and delivery note.
- Invoice register for receipt and issue documents with line-level detail and calculated totals.
- Dedicated issue register (outgoing stock documents) with drill-down to invoice lines.
- Customer account statement combining approved issue invoices, recorded customer payments, and approved customer returns when return documents exist; includes a running balance and debit/credit status.
- Supplier account statement combining approved receipt invoices, recorded supplier payments, and approved supplier returns when return documents exist; includes a running balance and debit/credit status.
- Customer and supplier payment entry with payment date, method, reference and notes; payments reduce the corresponding party balance.
- Arabic PDF generation, system print, and share/export actions for receipt/issue documents and customer/supplier statements; the bundled Almarai font is used for Arabic output.
- Supplier/customer name and phone editing; archive actions hide records from active selectors while preserving linked history.
- Product name and price editing, plus safe archive from the product gallery; historical invoice snapshots remain unchanged.
- Issue cashier now accepts an issue price per transaction unit so approved issues can contribute to customer balances.
- Arabic, English and French translations for the current gallery, transaction and approval workflows; RTL for Arabic and LTR for English/French.
- SQLite ledger, document line snapshots, approval history and audit entries for product edits.

## Build pipeline
GitHub Actions workflow at .github/workflows/android.yml generates Android platform files, installs Flutter dependencies, runs static analysis and tests, builds a release APK, and uploads it as an artifact. Check the Actions tab for an actual run; a workflow file alone is not proof of a successful build.

## Architecture
- Flutter Android application with local SQLite database; normal warehouse operation is designed to work offline.
- Stock is derived from approved ledger movements only.
- Each document line stores the product name, unit name, conversion factor, entered quantity, base quantity, price and packaging description snapshots.
- Supplier-specific package conversion overrides are stored on the receipt line so later product-unit edits do not rewrite history.

## Not production-ready yet
Authentication and real role-based authorization are not implemented; current development UI uses a temporary demo actor identifier. Role-based authorization and user accounts, full unit editing, opening balances, inventory counts, transfers, full return-document creation/approval with original invoice and batch traceability, payment allocation to individual invoices, date-filtered financial reports, thermal-printer integration, backups/restores, dedicated database migration tests, and physical Android device testing remain outstanding. Customer and supplier payments currently reduce the overall party balance; they are not allocated to specific invoices. Return-aware statement calculations do not mean the return transaction workflow is implemented. Do not use this branch to control live stock until these are implemented and verified.


Latest development note: unit-conversion validation and automated tests are included in the current branch. Android build status must be checked in the Actions tab for the latest branch commit.

CI dependency alignment: intl is pinned to the version required by the current Flutter localization SDK; the Android workflow generates platform files without resolving packages prematurely.

Analyzer adjustment: CI treats warnings as failures while allowing informational SDK deprecation notices.
