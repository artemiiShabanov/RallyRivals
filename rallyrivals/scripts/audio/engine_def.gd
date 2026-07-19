class_name EngineDef
extends Resource
## How a car's engine sounds (assets/audio/engine_*.tres). Three steady-RPM loops recorded from
## one engine, each valid near its own RPM; CarAudio pitches each within its band and crossfades
## between them. Splitting by RPM rather than pitching one loop matters because a real engine
## changes TIMBRE with revs — it doesn't just go up in pitch — and samples audibly stretch past
## roughly ±500 RPM from where they were recorded.
##
## The band centres are nominal: the loops we ship aren't labelled with true RPM, and for an arcade
## racer what matters is that the three sit in order and hand over smoothly, not that they match a
## real tachometer. Retune by ear.

@export_group("Bands")
@export var low: AudioStream
@export var low_rpm := 1200.0
@export var mid: AudioStream
@export var mid_rpm := 3000.0
@export var high: AudioStream
@export var high_rpm := 5500.0

@export_group("Rev range")
@export var idle_rpm := 800.0
@export var redline_rpm := 7000.0
## Speed fractions (of the car's top speed) where each gear starts. Revs climb through a gear and
## drop on the shift — the drop is what makes an engine sound driven rather than speed-tracking.
@export var gear_starts := PackedFloat32Array([0.0, 0.20, 0.40, 0.62, 0.84])

@export_group("Mix")
@export var volume_db := -14.0
@export var idle_volume_db := -22.0   ## off throttle, coasting: quieter than under load
## Pitch is clamped per band so a sample never stretches far enough to sound artificial.
@export var pitch_min := 0.85
@export var pitch_max := 1.30

@export_group("Cues")
@export var start_sfx: SfxDef
@export var off_sfx: SfxDef
