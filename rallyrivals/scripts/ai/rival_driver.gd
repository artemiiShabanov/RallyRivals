class_name RivalDriver
extends CarDriver
## An AI rival that drives the baked racing line (code-ai-rival). Two independent controllers:
##   STEER — pure pursuit: aim at a look-ahead point on the AiLine (the look-ahead grows with speed,
##           so it's twitchy-tight when slow and smooth when fast) and steer by the heading error.
##   SPEED — a local backward pass over the corners in the braking horizon ahead: each corner has a
##           safe speed sqrt(corner_grip · radius); the target now is the fastest speed from which the
##           car can still shed down to each upcoming corner in time (v² = v_corner² + 2·decel·dist).
##           Throttle/brake track the error to that target.
## Plus a small stuck-recovery reverse so a wall-wedged rival backs off instead of grinding.
##
## The car's grip/top-speed still come from its CarDef + the surface under its wheels — this only
## decides intent. All feel knobs are plain vars so code-ai-difficulty can scale pace per opponent
## (lower corner_grip / brake_decel = a slower, safer rival) without touching the driving code.
## Boss manners (blocking, drift) layer on top in code-ai-boss.

var path: Path3D          ## the AiLine node (gives the curve + its world transform)
var loop: bool            ## does the track loop (wrap arc offsets) or run point-to-point (clamp)

# --- pace / feel (code-ai-difficulty scales these) ---
var corner_grip := 8.5        ## m/s² lateral budget: corner speed = sqrt(corner_grip · radius) — conservative so the base rival doesn't run hairpins wide; code-ai-difficulty raises it for faster opponents
var brake_decel := 12.0       ## m/s² assumed braking power for the look-ahead speed profile
var lookahead_base := 5.0     ## m of steering look-ahead at a standstill
var lookahead_per_speed := 0.9 ## + this many metres of look-ahead per m/s of speed
var steer_ref := 0.5          ## heading error (rad) that commands full steering lock
var throttle_gain := 1.0      ## throttle per m/s under the speed target
var brake_gain := 0.45        ## brake per m/s over the speed target
var steer_sign := 1.0         ## maps heading error to the controller's left/right convention (verified in the drive test)

const PROBE := 4.0            # m between curvature samples along the horizon
const MIN_BRAKE_SPEED := 3.0  # below this, coast rather than command reverse (which would back up)
const STRAIGHT_R := 100000.0  # radius reported for a near-collinear sample (no corner)

# stuck recovery
const STUCK_SPEED := 1.5
const STUCK_TIME := 1.2
const RECOVER_TIME := 0.9
var _stuck := 0.0
var _recover := 0.0

# telemetry (read by the test bed / probes)
var last_cross_track := 0.0   ## metres from the racing line this frame
var last_offset := 0.0        ## arc-length position along the line this frame

func _init(ai_path: Path3D, is_loop := true) -> void:
	path = ai_path
	loop = is_loop

func poll(car, delta: float) -> Dictionary:
	var curve: Curve3D = path.curve if path != null else null
	if curve == null or curve.point_count < 2:
		return {}
	var length := curve.get_baked_length()
	var speed: float = car.linear_velocity.length()   # car is duck-typed, so annotate to keep types
	var top_speed: float = car.max_speed   # INF when the car has no CarDef -> corners still cap it

	var pos: Vector3 = car.global_position
	var off := curve.get_closest_offset(path.to_local(pos))
	last_offset = off
	last_cross_track = pos.distance_to(_point(curve, off, length))

	# --- STEER: pure pursuit toward a speed-scaled look-ahead point ---
	var la := lookahead_base + speed * lookahead_per_speed
	var target := _point(curve, off + la, length)
	var local: Vector3 = car.to_local(target)
	var ang := atan2(local.x, local.z)                       # +x = target is to the car's right
	var steer := steer_sign * clampf(ang / steer_ref, -1.0, 1.0)

	# --- SPEED: fastest speed that still brakes down to every corner in the horizon ---
	var horizon := maxf(la, speed * speed / (2.0 * brake_decel) + PROBE * 2.0)
	var target_speed := top_speed
	var s := PROBE
	while s <= horizon:
		var v_corner := sqrt(corner_grip * _radius(curve, off + s, length))
		target_speed = minf(target_speed, sqrt(v_corner * v_corner + 2.0 * brake_decel * s))
		s += PROBE

	# --- throttle / brake from the speed error ---
	var err := target_speed - speed
	var throttle := 0.0
	var reverse := 0.0
	if err > 0.0:
		throttle = clampf(err * throttle_gain, 0.0, 1.0)
	elif speed > MIN_BRAKE_SPEED:
		reverse = clampf(-err * brake_gain, 0.0, 1.0)        # controller reads reverse>0 at speed as braking

	# --- stuck recovery: near-stopped too long -> back up briefly, counter-steering to unwind ---
	if _recover > 0.0:
		_recover -= delta
		return {throttle = 0.0, reverse = 1.0, steer = -steer, handbrake = false}
	if speed < STUCK_SPEED:
		_stuck += delta
		if _stuck > STUCK_TIME:
			_stuck = 0.0
			_recover = RECOVER_TIME
	else:
		_stuck = 0.0

	return {throttle = throttle, reverse = reverse, steer = steer, handbrake = false}

# World-space point at arc-length `off` on the line (wraps on a loop, clamps point-to-point).
func _point(curve: Curve3D, off: float, length: float) -> Vector3:
	var o := fposmod(off, length) if loop else clampf(off, 0.0, length)
	return path.to_global(curve.sample_baked(o, true))

# Corner radius (m) at arc-length `off`, from three samples in the XZ plane (elevation ignored).
func _radius(curve: Curve3D, off: float, length: float) -> float:
	var a := _point(curve, off - PROBE, length)
	var b := _point(curve, off, length)
	var c := _point(curve, off + PROBE, length)
	var a2 := Vector2(a.x, a.z); var b2 := Vector2(b.x, b.z); var c2 := Vector2(c.x, c.z)
	var area2 := absf((b2.x - a2.x) * (c2.y - a2.y) - (c2.x - a2.x) * (b2.y - a2.y))  # = 2 · triangle area
	if area2 < 0.0001:
		return STRAIGHT_R
	return (a2.distance_to(b2) * b2.distance_to(c2) * c2.distance_to(a2)) / (2.0 * area2)
