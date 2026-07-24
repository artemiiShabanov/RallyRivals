class_name WeatherPreset
extends Resource
## One weather look (GDD 7: clear / rain / snow / thunder / fog — fixed per race, stacks with
## time-of-day). VISUALS ONLY here; grip_multiplier ships dormant and is consumed by
## code-track-weather-grip when it lands. Applied by WeatherFX: it OWNS the sky look (the VHS
## sky gradient + clouds + sun visibility + haze), plus camera-following cube precipitation,
## environment fog, and thunder flashes. Time-of-day only tints the sky on top (LightingPreset).
## Fog/haze stay moderate — low visibility must remain fair (telegraph corners).

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
@export_group("Sky")
@export var sky_zenith := Color(0.20, 0.36, 0.50)   ## top band of the VHS sky gradient
@export var sky_horizon := Color(0.78, 0.88, 0.95)  ## bottom band (meets the ground)
@export var sky_ground := Color(0.34, 0.36, 0.42)   ## flat colour below the horizon line
@export var cloud_cover := 0.0          ## 0..1 sky-cover intensity (0 = cloudless)
@export var cloud_color := Color(1, 1, 1)
@export var sun_visibility := 1.0       ## 0 hides the sun disk (overcast/fog), 1 = clear
@export var haze := 0.0                 ## 0..1 horizon whiteout (fog/heavy overcast)
@export_group("")
@export var thunder := false            ## random double-pulse sun flashes
@export var grip_multiplier := 1.0      ## folded into wheel grip (surface x car x weather)
@export var wetness := 0.0              ## 0..1 — darkens/glosses terrain via rr_wetness global

@export_group("Sound")
@export var ambient: AmbientDef         ## looping weather bed, crossfaded on the "weather" layer
@export var thunder_sfx: SfxDef         ## one-shot crack, delayed after each flash (see WeatherFX)
