# NaeemSoft WMS

Offline-first Android Warehouse Management System built with Flutter and SQLite.

## Product and unit model
- Product gallery designed for 100+ items and scalable growth.
- Each product has a user-selected stock base unit and user-defined transaction units.
- Supports cartons, packs, pieces, litres, kilograms, grams, and custom units.
- Unit conversion factors are configurable by the user.
- Receiving lines can override the conversion factor for supplier-specific packaging and store the actual packaging description as a historical snapshot.

## Receiving and issue workflow
- Receiving: select supplier, product, unit, actual package conversion, quantity and purchase price; add to basket and submit for approval.
- Issue: select customer/department, product, choose unit before quantity, add mixed-unit lines to basket and submit for approval.
- Documents are created as drafts and submitted to the approval queue.
- Draft and pending documents do not change stock.
- Approval posts stock movements atomically; issue approval checks aggregated requested quantities per product against available stock.
- Physical delivery is a separate confirmation step in the data layer.
- Product gallery, add-product dialog, receiving/issue basket and approval queue are implemented as an initial usable milestone.

## Languages
Arabic (RTL), English (LTR), and French (LTR) are supported in the application shell and the currently implemented product/transaction/approval flows. Remaining screens and printed documents still need complete translation and verification.

## Data and architecture
- Flutter Android application.
- Local SQLite database; normal operation does not require internet.
- Immutable stock movement ledger for approved receipt/issue documents.
- Document and line snapshots preserve names, units, factors, prices, and packaging notes.
- Database and workflow documentation are in lib/data/wms_database.dart and docs/WORKFLOWS.md.

## Build
GitHub Actions workflow .github/workflows/android.yml generates Android platform files, runs flutter pub get, flutter analyze, flutter test, builds a release APK, and uploads it as a workflow artifact.

## Current status and limitations
This is an active development build, not yet production-ready. Authentication and role-based authorization, delivery-confirmation screen, supplier/customer management screens, complete reports, inventory count, transfer and return workflows, PDF/thermal printing, backup/restore, migration tests, and physical-device acceptance tests remain outstanding. Do not use for live stock control until these controls and tests are completed.
