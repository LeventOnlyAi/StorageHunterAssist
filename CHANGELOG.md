# Changelog

## 0.3.0 — quality routing and collectibles, 2026-10-27

- Per-rarity group checkboxes with item counts and individual item selection.
- Configurable quality route: Common sells by default; other known rarities go to a separately chosen owned warehouse.
- Separate sale region and warehouse destination for mixed batches.
- Collectibles grouped below qualities by native collector name; current outstanding weekly requests marked with a star.
- Collectibles held by default, optionally warehoused; never sold through the quality route. Unknown metadata held.
- Optional automatic quality routing (including sale); off at startup, stopped by rule/target/source changes and transaction failures.
- Open list refreshes while automation is off, preserves selections, and avoids rebuilding unchanged rows.
- A failed item-name read or invalid nearby item no longer aborts the rest of the scan.
- Confirmed transaction latches expire when native actor pooling resets ownership/storage state, so reused actors are not permanently hidden.
- Unverified sale candidates are held and labeled; manual sale requires normal game verification, avoiding zero-price unverified removal. No automatic verification.
- Recheck eligibility and quality after the native sale widget's asynchronous construction.
- Mixed-batch warehouse capacity preflight; stop before selling if deposit fails.
- Updated Turkish Steam guide and English guide.

## 0.2.0 — first public release, 2026-10-26

- Turkish F8 panel with truck / nearby item selection.
- Remote quick sale with a choice of five pawn shops.
- Transfer to a selected owned shop's warehouse using the game's normal inventory operation.
- Optional automatic warehouse transfer; off at startup.
- Configurable time steps, F6 advance and F7 selection, with an end-of-day boundary.
- Bundled MIT-licensed ue4ss-ModMenu v1.4.0.
- Detailed Steam installation instructions, configuration examples and removal steps.

This publishes the working 0.2.0 runtime without changing its gameplay code. Earlier private shelf-stocking experiments are not part of this release.
