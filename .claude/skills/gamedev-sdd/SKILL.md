---
name: gamedev-sdd
description: >-
  Lightweight spec-driven workflow for building gameplay features in the RallyRivals
  Godot project. Use this whenever starting work on a new game feature, system, or
  mechanic — e.g. the vehicle controller, AI rivals, drift physics, lap/stage timing,
  HUD, menus, save system, or any new scene/script that adds player-facing behavior.
  Trigger it even when the user just says "let's build X", "add Y", "implement Z" or
  starts coding a mechanic without mentioning specs — write the short spec first,
  then build. Skip it only for trivial tweaks, bug fixes, and pure refactors.
---

# Gamedev SDD (spec-driven development)

A featherweight spec step that keeps a solo, ship-focused Godot project honest:
catch scope creep before writing code, and make "is it done?" answerable —
including the part that matters most in games, **how it feels**.

The cost is ~5 minutes and half a page. The payoff is not building the wrong thing,
and having an objective + subjective bar to test against. Don't turn this into
ceremony — if you're spending more time on the spec than it saves, you're overdoing it.

## When to run

Run this when starting any feature that adds player-facing behavior or a new system:
vehicle controller, AI, timing, HUD, menus, save/settings, a new mechanic, etc.

Skip it for: bug fixes, refactors, tuning numbers on an existing system, or
one-line tweaks. Those don't need a spec — just do them.

## The loop

### 1. Spec (before code)

Create `docs/specs/NNNN-short-name.md` from `assets/spec-template.md` (next number,
zero-padded). Fill it in fast. The five things that matter:

- **Intent** — one or two lines, in player terms ("the car should slide when you
  yank the handbrake mid-corner"), not implementation terms.
- **Serves** — which design pillar or [GDD](../../../docs/GDD.md) section this advances.
  If you can't name one, that's a signal to cut or defer the feature, not a formality.
- **Acceptance criteria** — objective, checkable ("AI completes a lap without leaving
  the track", "timer pauses on pause menu").
- **Feel criteria** — the subjective bar you'll judge by playing ("drift is
  controllable, not slippery-ice; recovering feels skillful"). Games live or die here,
  so name it explicitly even though it's not automatable.
- **Out of scope** — what this pass deliberately does *not* do. This is the main
  scope-creep defense; be concrete.

### 2. Escalate only if architectural

If the feature locks in a hard-to-reverse technical direction (physics model, save
format, networking, data architecture), write a one-page ADR in `docs/adr/` first
using `docs/adr/0000-template.md`, and link it from the spec. This is the *only* time
this lightweight flow grows a second document — don't reach for it otherwise.

### 3. Build

Implement against the spec in small, runnable increments. Prefer something you can
drive/see in the editor early over a big-bang implementation. If the spec turns out
wrong once code meets reality, update the spec — it's a living note, not a contract.

### 4. Verify & close

- Check every **acceptance criterion** (run it, ideally headless-import clean too).
- Play it and judge it against the **feel criteria**. If feel is off, that's not done —
  iterate or log it in [PLAYTESTS.md](../../../docs/PLAYTESTS.md).
- Tick the matching [ROADMAP](../../../docs/ROADMAP.md) checkbox.
- If you pulled in any third-party asset, add it to [CREDITS.md](../../../CREDITS.md)
  (license compliance is non-negotiable for shipping).
- Set the spec's **Status** to `done`.

## Spec status values

`draft` → `building` → `done` (or `cut` / `deferred`). One word at the top of the spec
so a glance at `docs/specs/` shows what's live.
