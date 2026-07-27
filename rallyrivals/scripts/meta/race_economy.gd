class_name RaceEconomy
extends RefCounted
## Banked-best top-up payout (code-meta-economy, GDD §7). Turns a finishing place into money + CP.
##
## A race's `money_pool` / `cp_pool` is the 1ST-PLACE (maximum) reward; lower places earn a fraction of
## it (place_fraction), down to a bottom slice so even last pays something. The game BANKS your best-
## ever place per race (SaveProfile.bests):
##   • IMPROVING on your banked place pays the DIFFERENCE — reward(new) − reward(old) — and re-banks.
##     Across successive improvements the total collected can never exceed the pool (reaching 1st
##     collects it whole), so there's no double-dipping.
##   • MATCHING or finishing BELOW your best pays a 10% trickle of THIS run's place — a small farm,
##     never the full slice — and the bank is unchanged.
##   • Money and CP use the identical rule.
##
## `settle()` is pure math (unit-tested); `apply()` is the one place that reads/writes Save. The exact
## place→reward curve here is a DEFAULT — balance-economy-tables authors the shipping numbers; keep the
## shape swappable (only place_fraction + the two constants below).

const TRICKLE := 0.10        ## fraction paid when matching/below the banked best
const BOTTOM_SLICE := 0.15   ## last place earns this fraction of the pool (default; balance owns it)

## Fraction of the pool a finish at `place` (1-based) earns in a field of `field_size`. 1.0 at 1st,
## linearly down to BOTTOM_SLICE at last. A one-entry field (solo skeleton / time trial gold) is all
## 1st, so it returns 1.0. DEFAULT curve — balance-economy-tables replaces the shape.
static func place_fraction(place: int, field_size: int) -> float:
	if field_size <= 1:
		return 1.0
	var t := float(clampi(place, 1, field_size) - 1) / float(field_size - 1)
	return lerpf(1.0, BOTTOM_SLICE, t)

## Whole-currency reward for finishing `place` of `field_size` from a `pool` (the 1st-place maximum).
static func reward_at(pool: int, place: int, field_size: int) -> int:
	return roundi(pool * place_fraction(place, field_size))

## Compute the payout for one finish WITHOUT touching Save. `prev_best` is the banked place before this
## run (<=0 = never placed here). Returns {money, cp, new_best, improved}.
static func settle(place: int, field_size: int, money_pool: int, cp_pool: int, prev_best: int) -> Dictionary:
	var improved := prev_best <= 0 or place < prev_best
	return {
		"improved": improved,
		"new_best": place if improved else prev_best,
		"money": _pay(money_pool, place, field_size, prev_best, improved),
		"cp": _pay(cp_pool, place, field_size, prev_best, improved),
	}

# One currency's payout: the top-up (reward(new) − reward(old)) when improving, else the 10% trickle.
static func _pay(pool: int, place: int, field_size: int, prev_best: int, improved: bool) -> int:
	var r_new := reward_at(pool, place, field_size)
	if not improved:
		return roundi(TRICKLE * r_new)
	var r_old := 0 if prev_best <= 0 else reward_at(pool, prev_best, field_size)
	return maxi(0, r_new - r_old)

## Settle a finished race and commit it: credit the wallet, re-bank the best place, persist, and write
## the breakdown back onto `res` for the results screen. Idempotent per race because the RaceDirector
## fires it once at finish. No active save (F6 / debug) → fills a zero breakdown and banks nothing.
static func apply(res: RaceResult, race: RaceDef) -> void:
	if res == null or race == null:
		return
	var prev := int(Save.active.bests.get(res.race_id, 0)) if Save.active != null else 0
	var b := settle(res.place, res.field_size, race.money_pool, race.cp_pool, prev)
	res.prev_best = prev
	res.banked_place = int(b["new_best"])
	res.improved = bool(b["improved"])
	res.money_earned = int(b["money"])
	res.cp_earned = int(b["cp"])
	if Save.active == null:
		return
	if res.money_earned > 0:
		Save.earn(res.money_earned)
	if res.cp_earned > 0:
		Save.earn_cp(res.cp_earned)
	Save.active.bests[res.race_id] = res.banked_place
	Save.write()
