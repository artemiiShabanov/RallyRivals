class_name CarClass
extends RefCounted
## The S–D class system (code-meta-classes): the single source of truth for what the five car classes
## are and how they order, so "class" means one thing everywhere — catalog sort, shop/garage display,
## the AI field's class band, and the Grand-Prix class gate all rank through here.
##
## Strength order is D < C < B < A < S. `rank()` returns 0..4 (D=0 … S=4); higher = stronger. The
## SHOP/garage show the reverse (S first) via display_order(). An empty/unknown class ranks -1 — it is
## never "at least" anything and is outside every band, so bad data fails closed rather than sneaking
## a car past a gate.
##
## Gating policy (which race demands which class) lives on RaceDef, which calls the predicates here.

const ALL := ["D", "C", "B", "A", "S"]   ## ascending strength; index IS the rank

static func is_valid(cls: String) -> bool:
	return cls in ALL

## 0 (D) … 4 (S); -1 for an unknown or empty class.
static func rank(cls: String) -> int:
	return ALL.find(cls)

## Comparator: >0 when `a` is the stronger class, <0 when weaker, 0 when equal.
static func compare(a: String, b: String) -> int:
	return rank(a) - rank(b)

## Is `cls` at least `min_class` in strength? An empty `min_class` means no requirement (always true);
## an empty/unknown `cls` never clears a real requirement.
static func at_least(cls: String, min_class: String) -> bool:
	if min_class == "":
		return true
	var r := rank(cls)
	return r >= 0 and r >= rank(min_class)

## Is `cls` inside the inclusive band [low..high]? Either bound may be "" to leave that side open.
## Used by the open-race field draw (field-matching spec) to pick rival classes.
static func in_band(cls: String, low: String, high: String) -> bool:
	var r := rank(cls)
	if r < 0:
		return false
	if low != "" and r < rank(low):
		return false
	if high != "" and r > rank(high):
		return false
	return true

## The classes strongest-first (S → D) — catalog / shop / garage display order.
static func display_order() -> Array:
	var out := ALL.duplicate()
	out.reverse()
	return out
