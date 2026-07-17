class_name WeatherPreset
extends Resource
## One weather look (GDD 7: clear / rain / snow / thunder / fog — fixed per race, stacks with
## time-of-day). VISUALS ONLY here; grip_multiplier ships dormant and is consumed by
## code-track-weather-grip when it lands. Applied by WeatherFX (camera-following cube
## precipitation + environment fog + thunder flashes). Fog stays moderate — low visibility
## must remain fair (telegraph corners).

@export var id := ""
@export_enum("none", "rain", "snow") var precipitation := "none"
@export var amount := 0                 ## particle count (0 = no precipitation)
@export var fall_speed := 20.0          ## m/s straight down (rain fast, snow slow)
@export var wind := Vector3.ZERO        ## sideways drift added to gravity
@export var turbulence := 0.0           ## snow flutter (ParticleProcessMaterial influence)
@export var particle_size := Vector3(0.05, 0.05, 0.05)
@export var particle_color := Color(0.9, 0.94, 1.0, 0.7)
@export var fog_enabled := false
@export var fog_density := 0.0
@export var fog_color := Color(0.69, 0.75, 0.85)
@export var thunder := false            ## random double-pulse sun flashes
@export var grip_multiplier := 1.0      ## dormant until code-track-weather-grip
