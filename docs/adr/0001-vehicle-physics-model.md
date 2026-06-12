# 0001 — Vehicle physics model

- **Status:** accepted
- **Date:** 2026-06-06

## Context
M1's vehicle controller (GDD §4) needs a physics foundation. The pillars demand arcade,
feel-first handling — buttery, weighty, responsive, **never hitching** — on shifting rally
surfaces, with player-only slipstream and mild damage effects. Performance-first is a hard
rule. We must pick the model before writing the M1 controller.

Three candidates (GDD §4 open):
- **A — `VehicleBody3D`** (built-in Jolt/Godot vehicle): wheels, suspension, friction out of
  the box. Fastest to stand up; less direct control over arcade feel.
- **B — Custom raycast car** (kinematic/rigid body + raycast "wheels", hand-rolled forces):
  full control over feel; more code; the common arcade-racer approach.
- **C — Pure kinematic** (`CharacterBody3D`-style, scripted motion, no rigidbody): cheapest,
  most predictable; least emergent physicality (jumps/landings/collisions feel hand-made).

## Spike findings
> Drive each spike, jot raw impressions here. Prompts: responsiveness, weight, grip/slide,
> suspension, arcade-fit, tuning reach.

### Spike A — `VehicleBody3D` (`prototypes/physics_vehiclebody/spike.tscn`)
- **Verdict: superior.** Weighty, planted suspension and believable contact "for free"; felt
  the most like a real car with the least code. Tuning the engine/steer/grip exports reached a
  good feel quickly. This is the base.
- Caveats surfaced (see findings): grip needs a custom front/rear layer to drift; surface
  `PhysicsMaterial` is ignored.

### Spike B — custom raycast car (`prototypes/physics_raycast/spike.tscn`)
- More direct control over grip (front/rear slip is just a number), but cost real effort to get
  basics right: forward-axis confusion, and it **rolled over** until an active "keep-upright"
  torque was added. Suspension/contact had to be hand-built and felt less planted than A.
- Useful as a reference for the grip model, but not worth re-implementing what A gives for free.

## Findings (validated in the spikes)
1. **`VehicleBody3D` drives toward +Z** (local +Z is forward), opposite the usual `-Z`
   convention — confirmed by probe. Affects camera, steering-wheel placement, brake logic.
2. **Surface `PhysicsMaterial.friction` does NOT affect wheel grip** in Godot Physics —
   a 50× friction change (1.0 → 0.02) produced *identical* lateral-slide decay. So surface grip
   **must** be applied via `wheel_friction_slip`, per wheel, from a surface tag (we used a
   `grip_slip` node meta read through `VehicleWheel3D.get_contact_body()`). *(Jolt backend may
   differ — untested; not switching backends just for this.)*
3. **Drift needs an asymmetric (front/rear) grip model.** A single `wheel_friction_slip`
   governs both drive and lateral grip, so a uniform drop = understeer + bog ("slow-mo"), never
   drift. Keeping front grip while dropping the rear (and slashing rear grip on handbrake)
   produces the arcade oversteer the **Arcade Rally Flow** pillar wants.

## Decision
Use **`VehicleBody3D` as the base, plus a thin custom handling layer** on top:
- Per-wheel surface grip via `wheel_friction_slip`, driven by a surface tag (not `PhysicsMaterial`).
- Front/rear grip split + handbrake rear-grip cut for drift.
- Likely later: speed-dependent grip, throttle-on-oversteer, steering-assist shaping.

We keep `VehicleBody3D`'s suspension, wheel raycasts, and collision for free, and only hand-roll
the *grip/handling feel* — far less code than the full raycast car (Spike B), which would have us
rebuild suspension and uprighting ourselves.

## Alternatives considered
- **B — custom raycast car:** rejected. Maximum control, but we'd re-implement suspension,
  contact, and anti-rollover that A provides; the only thing it bought (grip control) we can layer
  onto A anyway.
- **C — pure kinematic:** rejected. Cheapest/most predictable, but too far from the simulated
  weight, jumps, and collision feel the rally pillars want; everything physical becomes hand-authored.

## Consequences
- M1's vehicle controller starts from the Spike A script (`prototypes/physics_vehiclebody/`) —
  promote it from prototype to `scripts/` and grow the handling layer there.
- Surfaces (M2) need a **`SurfaceType`** representation carrying grip + FX + audio tags; the
  `grip_slip` meta is the throwaway stand-in. Define it as a small `Resource` when building M2.
- Locked to **Godot Physics** for now (surface-friction finding assumes it). Revisit only if a
  concrete need pushes us to Jolt.
- The handling layer (front/rear split, handbrake) is now the main feel surface to tune at the
  M1 checkpoint — that's where "buttery" gets dialed in.
