class_name Chapters
extends RefCounted
## Campaign progression (code-meta-chapters, GDD §5/§8, CAMPAIGN.md). Four chapters = four regions; a
## two-step gate carries you through each:
##   1. Bank ≈70% of the chapter's CP  → the chapter BOSS duel unlocks.
##   2. Beat the boss                  → advance to the next chapter/region (+ pink-slip the boss car,
##                                        code-meta-pinkslip). Losing costs only the retry (lenient).
##
## Static helpers over Save.active — the one owner of `chapter` + `chapter_cp_base`. CP is never spent
## (GDD §8), so chapter progress is simply how much CP has been banked SINCE the chapter began:
## `cp - chapter_cp_base`. Advancing rebases that to the current CP, so the bar resets while lifetime CP
## keeps climbing.
##
## The CP TARGET here is a placeholder — balance-difficulty-pacing owns the real per-chapter totals
## (derived from the chapter's eight race CP pools once content-tracks-campaign authors them) and the
## exact gate %. This file owns the MECHANISM; those own the numbers. The career MAP that lists races +
## the boss tile is code-ui-career-map; awarding the won car is code-meta-pinkslip.

const COUNT := 4               ## four chapters; chapter == COUNT means the campaign is complete
const GATE := 0.7              ## fraction of the chapter CP target that unlocks the boss (placeholder)
const CP_TARGET := 100         ## PLACEHOLDER per-chapter CP total — balance-difficulty-pacing owns the real, per-chapter figure

## Current chapter (0-based), clamped to a valid roster index even when the campaign is complete.
static func current() -> int:
	if Save.active == null:
		return 0
	return clampi(Save.active.chapter, 0, COUNT - 1)

## Raw chapter counter (may equal COUNT once every chapter is done — unlike current(), not clamped).
static func raw() -> int:
	return Save.active.chapter if Save.active != null else 0

static func is_complete() -> bool:
	return raw() >= COUNT

## CP banked toward THIS chapter's boss (cp since the chapter began; never negative).
static func cp_progress() -> int:
	if Save.active == null:
		return 0
	return maxi(0, Save.active.cp - Save.active.chapter_cp_base)

## CP needed this chapter: the sum of the chapter's race CP pools (Campaign). Falls back to the flat
## placeholder only if the campaign has no pools yet. balance-difficulty-pacing owns the real figure.
static func cp_target() -> int:
	var total := Campaign.chapter_cp_total(current())
	return total if total > 0 else CP_TARGET

## CP that unlocks the boss (≈70% of the target).
static func boss_threshold() -> int:
	return roundi(GATE * float(cp_target()))

## 0..1 progress toward the boss unlock, for a gauge.
static func boss_fraction() -> float:
	var t := boss_threshold()
	return clampf(float(cp_progress()) / float(t), 0.0, 1.0) if t > 0 else 1.0

## Has the boss duel unlocked (enough CP banked, campaign not already finished)?
static func boss_unlocked() -> bool:
	return not is_complete() and cp_progress() >= boss_threshold()

## The current chapter's boss (identity + manner + pink-slip car).
static func boss() -> BossDef:
	return BossDef.for_chapter(current())

## Beating a boss (place 1 in its duel, RaceDirector). Advances ONLY when it's the CURRENT chapter's
## boss — so debug-booting another chapter's boss can't skip you ahead. Rebases CP, pink-slips the boss's
## car (code-meta-pinkslip), then persists once. `boss_chapter` is the RaceDef's 1-based chapter. Returns
## the CarDef NEWLY won (null if the win didn't count or you already owned it) so results can announce it.
static func on_boss_win(boss_chapter: int) -> CarDef:
	if Save.active == null or is_complete():
		return null
	if boss_chapter - 1 != current():
		return null                              # not this chapter's boss — no advance, no trophy
	var won := _award_pink_slip(BossDef.for_chapter(boss_chapter - 1))
	Save.active.chapter += 1
	Save.active.chapter_cp_base = Save.active.cp
	Save.write()
	return won

## Pink-slip the boss's car (code-meta-pinkslip): add it to the garage the first time it's won, so it
## shows there (Cars.owned) and never in the shop (pink_slip_only). Returns the CarDef only when it's
## NEWLY won — null if already owned or the id is bad — so the results screen announces the trophy once.
static func _award_pink_slip(boss: BossDef) -> CarDef:
	if boss == null:
		return null
	var cd := Cars.by_id(boss.car_id)
	if cd == null or cd.id in Save.active.owned_cars:
		return null
	Save.add_car(cd.id)                          # canonical garage add: dedups, persists, emits car_changed
	return cd
