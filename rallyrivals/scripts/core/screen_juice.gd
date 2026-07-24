class_name ScreenJuice
extends RefCounted
## Screen juice (art-vfx-juice): the view's physical reaction to violence — a decaying shake from
## impacts, a suspension dip on landing, and a faint tremor at speed — plus a matching spike of the
## VHS filter's glitch, so a big hit makes the tape stutter as well as knocking the camera.
##
## Statics, following the VHSFilter / WeatherFX convention: the car holds no reference to the camera,
## so events are pushed from wherever they happen and ChaseCamera drains them each frame. NOTHING
## here touches physics — every value is view-space only, so juice can never change how the car
## drives (the same rule the terrain shader follows about collision).
##
## `scale` is the accessibility dial (Settings -> SCREEN SHAKE; GDD §9, and the "Glance to Read"
## pillar): 0 stops all camera motion. The glitch spike is deliberately NOT scaled by it — it
## carries no motion, so players who turn shake off still get the hit feedback.

## User setting; 0 = no camera motion at all. Mirrors the role of VHSFilter.intensity.
static var scale := 1.0

const TRAUMA_DECAY := 2.2       ## trauma/s — a full hit rings for a bit under half a second
const DIP_RECOVER := 7.0        ## spring rate the landing dip eases back at
const GLITCH_DECAY := 5.0       ## the tape recovers fast; a lingering tear reads as breakage
const MAX_OFFSET := 0.34        ## metres of camera translation at full trauma
const MAX_ROLL := 0.055         ## radians of view roll at full trauma
const MAX_DIP := 0.42           ## metres the view drops on the hardest landing
const RUMBLE_AMP := 0.16        ## trauma-equivalent amplitude of a flat-out speed tremor

## Contact impulse that counts as a full-strength hit. VehicleController.impacted reports the
## strongest contact impulse of the frame; a ~1200 kg car hitting something at speed lands in the
## low thousands, so this saturates on a real crash but not on scraping a wall.
const IMPACT_FULL := 4200.0

static var _trauma := 0.0
static var _dip := 0.0
static var _rumble := 0.0
static var _glitch := 0.0
static var _t := 0.0

## A collision. `impulse` comes straight from VehicleController.impacted.
static func impact(impulse: float) -> void:
	var s := clampf(impulse / IMPACT_FULL, 0.0, 1.0)
	_trauma = minf(1.0, _trauma + s)
	_glitch = minf(1.0, _glitch + s * 0.9)

## A touchdown after air. `strength` is 0..1 — how hard the car came down.
static func landing(strength: float) -> void:
	var s := clampf(strength, 0.0, 1.0)
	_dip = minf(1.0, _dip + s)
	_trauma = minf(1.0, _trauma + s * 0.55)
	_glitch = minf(1.0, _glitch + s * 0.5)

## Continuous 0..1 tremor, pushed every frame by whatever is watching speed.
static func set_rumble(v: float) -> void:
	_rumble = clampf(v, 0.0, 1.0)

## Decay everything. ChaseCamera calls this once per frame, before reading the offsets.
static func advance(delta: float) -> void:
	_t += delta
	_trauma = maxf(0.0, _trauma - TRAUMA_DECAY * delta)
	_glitch = maxf(0.0, _glitch - GLITCH_DECAY * delta)
	_dip = lerpf(_dip, 0.0, 1.0 - exp(-DIP_RECOVER * delta))   # frame-rate independent

## Clear it all — scene change or respawn, so a hit never rings on into the next scene.
static func reset() -> void:
	_trauma = 0.0
	_dip = 0.0
	_rumble = 0.0
	_glitch = 0.0

## Camera translation for this frame, in VIEW space (x sideways, y vertical). Three unrelated
## frequencies so the motion never settles into a clean, readable oscillation.
static func offset() -> Vector3:
	var amp := _amp()
	var x := sin(_t * 37.0) * amp * MAX_OFFSET
	var y := sin(_t * 43.0 + 1.7) * amp * MAX_OFFSET - _dip * MAX_DIP
	return Vector3(x, y, 0.0) * scale

## View roll for this frame, radians.
static func roll() -> float:
	return sin(_t * 31.0 + 3.1) * _amp() * MAX_ROLL * scale

## Additive glitch for the VHS filter. NOT scaled by `scale` on purpose — see the header.
static func glitch_boost() -> float:
	return _glitch

# Trauma is squared so the shake falls off perceptually rather than linearly (a half-strength hit
# should feel much gentler than half). The speed tremor is a floor under it, not an addition, so
# driving fast never amplifies a crash.
static func _amp() -> float:
	return maxf(_trauma * _trauma, _rumble * RUMBLE_AMP)
