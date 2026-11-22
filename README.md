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
Authentication and real role-based authorization are not implemented; current development UI uses a temporary demo actor identifier. Full delivery evidence/signature capture, product archive and full unit editing, opening balances, inventory counts, transfers, returns, complete reports, PDF/thermal printing, backups/restores, database migration tests, and physical Android device testing remain outstanding. Do not use this branch to control live stock until these are implemented and verified.


Latest development note: unit-conversion validation and automated tests are included in the current branch. Android build status must be checked in the Actions tab for the latest branch commit.
