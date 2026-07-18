class_name AmbientDef
extends Resource
## One looping ambience bed (assets/audio/ambient/*.tres): the stream, its resting level and how
## long it takes to fade in/out when a layer swaps. Played by AmbientBed, never positionally —
## ambience surrounds the listener, so it stays non-spatial and only its level moves.
## The stream itself must loop (AudioStreamWAV.loop_mode, or "Loop" in an .ogg's import tab).

@export var id := ""
@export var stream: AudioStream
@export var volume_db := -12.0
@export var fade_time := 1.5      ## seconds for a full crossfade when this layer changes
@export var bus := "SFX"
