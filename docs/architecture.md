# NaeemSoft WMS — implementation baseline

## Agreed deployment boundary
- Android application, initially hosted and operated locally on one Android device.
- SQLite database stored on-device; core workflows work offline.
- One warehouse in this local edition. No branch/warehouse switching or internet backend is required for the first release.
- Keep the data model migration-ready; do not add cloud services or PostgreSQL to this phase.

## Implementation sequence
1. Database schema, constraints, indexes, and migration versioning.
2. Repository/data-access layer and transaction-safe posting services.
3. Arabic-first Android screens and navigation.
4. Validation with realistic receiving, issue, return, and stock-count scenarios.
5. Build and verify an installable APK.

## Inventory invariants
- Draft or pending documents never change available stock.
- Stock changes only in the same database transaction that approves a document and writes its stock ledger entries.
- Receiving approval creates a traceable batch for every receiving line.
- Issues consume available stock and must never create a negative batch balance.
- Supplier returns refer to the original receiving line and its original batch; cumulative returns cannot exceed the received quantity less previous returns.
- Starting an inventory count freezes stock movements until approval/cancellation closes the count. Other non-stock screens remain usable.
- Stock quantities are stored in each product's base unit. Package/unit conversions are captured on document lines as a snapshot.
- Unit conversion and sale/issue pricing are separate concerns; no automatic price derivation from conversion factors.
- Approved source documents are immutable. Corrections are made through controlled reversal/adjustment documents and audit records.

## Important implementation note
The SQL file establishes the relational foundation and core database guards. Approval workflows, batch allocation, weighted/FEFO consumption policy, balance calculations, and all-or-nothing transaction orchestration must be implemented in the application data layer and covered by tests before the APK is considered production-ready.
