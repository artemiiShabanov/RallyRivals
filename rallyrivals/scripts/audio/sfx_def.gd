class_name SfxDef
extends Resource
## One sound event (assets/audio/sfx/*.tres): candidate streams (random pick per play),
## gain, pitch jitter and bus routing. Played through the Sfx autoload; max_distance only
## applies to positional play_at().

@export var streams: Array[AudioStream] = []
@export var volume_db := 0.0
@export var pitch_min := 0.95
@export var pitch_max := 1.05
@export var bus := "SFX"          ## "SFX" | "UI" | "Music"
@export var max_distance := 40.0
