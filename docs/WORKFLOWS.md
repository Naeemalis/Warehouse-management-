# Warehouse workflows

## Product units and packaging
Each product has one stock base unit and any number of user-defined transaction units. Each unit stores a positive conversion factor to the base unit. Examples: oil piece=1 bottle, pack=6 bottles, carton=12 bottles; rice gram=1 and kilogram=1,000 grams; liquid millilitre=1 and litre=1,000 millilitres. Packaging can differ by supplier or receipt, so each document line stores the actual unit name, conversion factor, entered quantity, base quantity, product name, and packaging note as historical snapshots.

## Issue cashier
1. Start Issue from the product gallery.
2. Select customer or receiving department.
3. Select a product, then select its unit before entering quantity.
4. Enter quantity on the numeric keypad and add the line to the basket.
5. The same product may appear on multiple lines using different units.
6. Submit for approval; stock is unchanged while pending.
7. An authorized approver approves or rejects.
8. Approval posts an OUT movement atomically after checking available stock.
9. Confirm physical delivery separately and record recipient details.
10. Print the approved issue document.

## Receiving cashier
1. Start Receive Goods from the product gallery and select supplier.
2. Select products and choose carton, pack, piece, kg, gram, litre, or another configured unit.
3. For nested packaging enter cartons, packs per carton, and pieces per pack; when there are no packs enter pieces per carton.
4. Enter actual purchase price and add to the receiving basket.
5. A new product can be added from the receiving workflow.
6. Submit for approval; pending quantities do not increase stock.
7. An authorized approver reviews supplier, quantities, packaging, and prices.
8. Approval posts an IN movement atomically and the receipt can be printed.

## Ledger and approval invariants
- Draft, pending, rejected, and cancelled documents do not affect stock.
- Only approved documents post stock movements.
- Each document line can post only once.
- Approval and ledger posting occur in one SQLite transaction.
- Issue approval is rejected when requested base quantity exceeds available stock.
- Approval and physical delivery are separate states.
- Posted documents are corrected with traceable reversal/correction documents, never by silently editing historical lines.

## Remaining milestones
The first foundation adds the Flutter entry point, SQLite schema, and core approval/ledger methods. Product editor, supplier/customer selection, full receipt and issue baskets, role administration, printing, backup/restore, migrations, Android platform packaging, and device acceptance tests remain to be implemented.