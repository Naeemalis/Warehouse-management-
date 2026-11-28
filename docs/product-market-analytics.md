# Product Performance & Market Intelligence

## Purpose

Add a decision-support module to NaeemSoft WMS that combines the institution's verified operational history with separately captured market intelligence. The module must help management understand product performance, unmet demand, competitor positioning, geographic coverage, market share, and profitable growth/import opportunities.

This is an offline-first SQLite feature. It does not introduce a backend, cloud database, or a second inventory ledger.

## Existing WMS data to reuse

The current application database already contains:

- `products` and `product_units`: product identity and unit conversion snapshots.
- `documents` and `document_lines`: receipt, issue, sales, and return documents.
- `stock_movements`, `stock_batches`, and `stock_movement_allocations`: approved stock movement and batch traceability.
- `suppliers`, `customers`, `supplier_payments`, and `customer_payments`.
- `permissions`, `role_permissions`, and `user_permissions`.

Do not duplicate these operational facts in market tables. Market analytics must query the existing approved records.

### Operational classification rules

| Existing document data | Analytics treatment |
|---|---|
| Approved receipt | Supply inflow and purchase-cost history |
| Approved sale (`kind='issue'`, `document_type='sale'`) | Commercial sales and revenue |
| Approved standard issue | Non-sales consumption/distribution; never revenue |
| Approved customer return (`kind='return_in'`) | Reduce net sales and restore stock |
| Approved supplier return (`kind='return_out'`) | Reduce net received quantity/cost as appropriate |
| Draft, pending, rejected, cancelled | Exclude from realized performance |

The implementation must follow the actual return-line references and approved status. It must not infer sales from all outgoing stock movements.

## Module structure

1. Product performance — sales, issues, receipts, returns, current stock, turnover, expiry exposure, costs and margin.
2. Market demand — estimated demand by product, period, area and customer segment; lost/unfulfilled requests.
3. Competitors — competitor profiles, branches, matched products, dated price observations and availability observations.
4. Geographic coverage — demand, our fulfilled quantity, service gaps and presence by area.
5. Market share — volume share and value share, with an explicit market-size source and confidence level.
6. Growth opportunities — scored product/area opportunities and management decisions.
7. Procurement/import planning — supplier lead time, minimum order quantity, landed-cost assumptions and demand coverage.

## New relational entities

The companion SQL migration file defines these tables:

- `market_areas`: country/city/district/neighborhood hierarchy.
- `market_segments`: customer/market segments.
- `market_data_sources`: source, collection method and reliability.
- `product_market_profiles`: brand, manufacturer, country of origin, customs code and storage profile.
- `supplier_product_terms`: supplier-specific lead time, MOQ and quoted procurement terms.
- `competitors`, `competitor_branches`: competitor identity and geographic footprint.
- `competitor_products`: competitor catalogue item, optionally matched to an internal product.
- `competitor_price_observations`: dated, sourced, unit-normalized competitor price records.
- `competitor_availability_observations`: dated availability observations.
- `market_demand_observations`: demand estimates/observations by product, area, segment and period.
- `unfulfilled_demand`: real customer requests that the institution could not fulfil.
- `market_size_estimates`: sourced estimates of total market volume and value.
- `growth_opportunities`, `market_decisions`: opportunities and management decisions.

Do not store calculated market share as an independently editable fact. Calculate it from approved internal sales and a dated market-size estimate; an optional future cache must be rebuildable.

## Metric definitions

All quantity comparisons must first normalize to the internal product's base unit. Comparisons must use the same product, geographic area, and time period.

- Net sold quantity = approved sale line quantities minus approved customer-return quantities linked to those sale lines.
- Net sales value = approved sale line value minus the value of approved customer returns, using the original line price snapshot.
- Volume market share (%) = net sold base quantity / estimated total market sold base quantity × 100.
- Value market share (%) = net sales value / estimated total market sales value × 100, only when currencies and tax treatment are comparable.
- Demand fulfilment (%) = our net fulfilled demand quantity / estimated total demand quantity × 100. Display the numerator and denominator; do not silently cap values above 100%.
- Recorded unmet requests = sum of verified unfulfilled customer requests. This is distinct from estimated total market demand minus our sales.
- Competitive price index = our comparable selling price / competitor comparable selling price × 100. Compare only equivalent product specifications and normalized units.
- Stock cover days = available non-expired stock / average daily net demand. If the demand window has no activity, show “insufficient history”, not infinity or zero-demand certainty.
- Reorder point = average daily demand × supplier lead time days + safety stock. Lead time and safety stock must be visible assumptions.

## Data quality and governance

- Every external observation must record its source, observation date, collection method and confidence/reliability.
- Competitor price and availability observations are time-stamped history; never overwrite old observations.
- Keep observed, surveyed and estimated demand distinguishable.
- Never compare different pack sizes without a verified conversion factor.
- Keep currencies and tax inclusion explicit for price/value comparisons.
- A market-size estimate is not a fact unless its source and estimation method are recorded.
- No market recommendation should trigger a purchase automatically.
- Import decisions must consider expected demand, supplier lead time, MOQ, landed cost, gross margin, expiry risk, cash requirements and current stock.
- Competitor confidential data must use the existing explicit `competitor_confidential_view` permission. Admin/Super Admin must not receive this permission implicitly. Do not expose confidential fields until authenticated permission enforcement is active.

## Implementation sequence

1. Add the schema as a versioned SQLite migration; preserve existing WMS data.
2. Add repository methods for market master data and observations.
3. Add analytics queries over approved WMS documents and market estimates.
4. Add explicit permission checks for market and confidential competitor access.
5. Add Arabic, English and French screens.
6. Add unit tests for return-aware sales, stock/issue separation, unit normalization, market share, coverage, price comparisons and permission denial.
7. Run Flutter analyze/tests and Android release build; inspect the generated APK and test on a physical Android device.

## Current implementation status

Implemented on `feature/product-market-analytics`:

- Version 11 SQLite migration creates the market intelligence tables on new installs and upgrades existing version 10 databases.
- Repository methods capture competitor catalog/price/availability, demand observations, unmet requests, market-size estimates, supplier lead-time/MOQ terms, product origin/manufacturer metadata, opportunities and decisions.
- Product performance queries reuse approved WMS documents and distinguish sales from standard issues; customer returns linked to original sales reduce net sales.
- Market analytics repository methods require explicit `market.analytics.view`, `market.demand.manage`, `market.competitors.manage`, or `market.decisions.manage` permissions. Confidential competitor records additionally require the existing `competitor_confidential_view` permission.
- Pure metric functions and unit tests cover market share, demand coverage, comparable price index, stock cover, reorder point and gross margin.

Still outstanding: the interactive Arabic/English/French screens, a real authenticated session wired to the permission checks, competitor branch/product capture UI, full automated SQLite migration/integration tests, and Android CI/device verification. The current app's demo actor is not an authenticated user, so the market screen must not be exposed until session identity is wired into these checks. No APK or production readiness is claimed at this stage.
