# Take3

This repository contains the Swift/SpriteKit implementation of **Orbit Flip Frenzy**, an iOS arcade title generated entirely from code. The goal of this README is to track follow-up tasks by discipline after reviewing the shipped code.

## Task Tracker

### Monetization

**Current implementation**

- StoreKit-backed `PurchaseManager` now consults remote config overrides for production product identifiers, handles purchase flows, verifies transactions, and exposes an iOS 15 restore UI that reconciles entitlements without duplicating consumables.
- `AdManager` tracks reward-ad load state, retries on failure, and either shows a production adapter (Google Mobile Ads when present) or a simulated rewarded video with cancellation/error analytics.
- Game over flow supports spending gems to continue, keeps the ad button stateful, and renders the player’s gem balance alongside revive options.
- The main menu renders live pricing fed by StoreKit/remote config, a Starter Pack banner driven by configurable cooldowns, hero-product/badge merchandising, gem totals, cosmetic purchases, and a restore button that surfaces the native flow.
- Analytics events are queued offline with disk-backed persistence, authenticated upload headers, configurable batch sizes, and enrichment for purchase, ad, gem, restore, and error events.

**Follow-up work**

1. Replace the simulated rewarded adapter with a real network SDK integration (e.g. AdMob/AppLovin), including dependency management, consent prompts, and mediation failover handling.
2. Stand up the real remote-config/telemetry backend, add auth rotation + exponential backoff, and expose tooling to edit hero products and merchandising copy.
3. Expand the cosmetic shop with previews, additional unlock types, and gem sinks tied to new content beyond the shield purchase path.
4. Implement integration testing around StoreKit restore flows, refund handling, and server-side entitlement reconciliation.
5. Build analytics dashboards that join purchase/ad/gem data for retention modeling and alert on upload failures surfaced by the reliable uploader.

**Risks & considerations**

- Ensure rewarded ads pause gameplay audio/haptics, gracefully handle dismissals, and avoid duplicate reward grants on failure retries.
- Verify receipt handling, entitlement persistence, and edge cases like refund/restoration across devices for StoreKit purchases.
- Localize storefront copy, gem pricing, and merch messaging and consider server-driven overrides before shipping internationally.
