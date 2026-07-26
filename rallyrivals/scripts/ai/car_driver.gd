class_name CarDriver
extends RefCounted
## Base for a non-human driver plugged into `VehicleController.driver`. The controller PULLS controls
## from `poll()` once per physics frame and feeds them through the same throttle/brake/steer/handbrake
## path a human uses — so an AI drives the real body and physics, never a parallel sim.
##
## Return a Dictionary of intents (all optional, sensible defaults if absent):
##   throttle : 0..1   accelerate
##   reverse  : 0..1   brake while rolling forward, reverse once nearly stopped (controller decides)
##   steer    : -1..1  +1 = full steer toward the controller's steer_left, -1 toward steer_right
##   handbrake: bool   instant drift
func poll(_car, _delta: float) -> Dictionary:
	return {}
