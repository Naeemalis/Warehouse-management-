# NaeemSoft WMS

Offline-first Android Warehouse Management System using Flutter and SQLite.

## Confirmed scope
- Scalable product gallery for 100+ products.
- User-defined units per product: carton, pack, piece, litre, kilogram, gram, and custom units.
- Nested packaging and supplier-specific packaging snapshots per receipt.
- Mixed-unit issue lines for the same product in one document.
- Receipt cashier: select supplier, choose products, enter carton/pack/piece structure and purchase prices.
- Issue cashier: select customer/recipient, choose product, choose unit first, enter quantity on a numeric keypad, add to basket.
- Draft and pending documents do not affect stock. Authorized approval posts stock movements.
- Physical delivery confirmation is separate from approval.
- Arabic, English, and French interface; printable receipts and issue documents.
- Product add/edit from receiving workflow, with historical snapshots and audit trail.
- Local SQLite database; normal warehouse operations work offline.

## Current status
This is the first foundation commit. It adds a Flutter application entry point, SQLite schema, approval/stock-ledger methods, and workflow documentation. It is not a complete or production-ready application and has not yet been built or tested on an Android device. Product editor, supplier/customer screens, complete cashiers, role administration, printing, backup/restore, and Android packaging remain for subsequent milestones.

## Safety
Do not use for live inventory until the complete workflows, permissions, backup/restore, migrations, printing, and acceptance tests have been completed and verified.