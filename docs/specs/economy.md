# Spec — Banked-best reward economy

- **Status:** draft
- **Date:** 2026-06-13
- **Task:** `design-spec-economy`

## Intent
Replaying a race you've already done well at gives almost nothing; *improving* your result
always pays out the difference — so you chase better finishes, never grind the same race.

## Serves
GDD §5 (race rewards economy) and §8 (two currencies). Pillar 3 — *Old-School Campaign*
("lenient, never hard-walled": even a poor finish earns something; grinding is pointless, so
the game never pushes you to do it).

## Model
Each race defines, for **each currency** (money and campaign points / CP), a **per-place full
value** table — the *total* reward associated with finishing at that place, descending:

```
place_full[1] >= place_full[2] >= ... >= place_full[N] > 0
```

- `place_full[1]` (1st) is the whole pool — reaching 1st means you've eventually collected it all.
- Even last place pays the bottom slice (`place_full[N] > 0`) — lenient.

Per race **per save**, persist one number per currency: `banked` = the full value of your
**best-ever finish** in that race so far (starts at 0).

## Payout algorithm (per currency, on finishing a race at `place`)
```
new_full = place_full[place]
if new_full > banked:          # improved your best
    payout  = new_full - banked
    banked  = new_full
else:                          # matched or finished below your best
    payout  = ROUND(0.10 * new_full)   # small farm trickle, 10% of THIS finish
    # banked unchanged
grant(payout); save(banked)
```
Money and CP run this independently, each with its own `place_full[]` table and `banked` value.

## Acceptance criteria
- [ ] First time reaching a *new best* place pays `place_full[place] - banked` (the top-up).
- [ ] Matching or finishing below your banked best pays `10%` of the place you just got, and
      does **not** change `banked`.
- [ ] Once you've reached 1st, the sum of all top-ups paid equals `place_full[1]` exactly
      (no double-dipping, no overpay).
- [ ] `banked` never decreases; it persists across sessions (save/load).
- [ ] Money and CP are computed by the same function, independent tables/banks.
- [ ] Worked example (CP table 1st=10, 2nd=8, 3rd=3), starting banked=0:
  - finish 2nd → **+8**, banked=8
  - finish 2nd again → **+0.8**, banked=8
  - finish 3rd → **+0.3**, banked=8 (below best → 10% of 3rd)
  - finish 1st → **+2**, banked=10 (tops 8 → 10)
  - finish 1st again → **+1.0**, banked=10 (10% of 1st)

## Feel criteria
- [ ] Improving a result *always* feels worth the run (you see a real payout).
- [ ] Re-running a maxed race feels pointless-but-not-punishing — a trickle, never zero-grind bait.
- [ ] No "grind this race 20×" incentive ever emerges.

## Out of scope
- The **numeric tables** themselves (`balance-economy-tables`) — this spec defines the *rule*,
  not the values.
- Spending money (shop `code-meta-shop`), CP→chapter gating (`code-meta-chapters`), pink-slips.
- Any money source other than race payouts (GDD §8: race payouts are the sole source).
- Rounding policy for fractional money/CP — flagged below.

## Notes
- **Rounding:** the 10% trickle and any fractional `place_full` need a rounding rule. Default:
  round to nearest integer, floor at 1 so a trickle is never 0. Confirm when building
  `code-meta-economy`.
- **Where place_full comes from:** authored per race (or derived from a base pool × place
  weights). The representation is a `code-meta-economy` decision; this spec only requires a
  descending positive table per currency.
- Implements into `code-meta-economy` (blocked task); `code-meta-currencies` provides the wallets.
