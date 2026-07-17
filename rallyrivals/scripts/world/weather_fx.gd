class_name WeatherFX
extends Node3D
## Applies a WeatherPreset to the scene: cube precipitation (ADR-003 — every particle is a
## cube) in a camera-following emitter box, exponential fog on the scene's WorldEnvironment,
## and thunder as randomized double-pulse flashes of the scene's sun. One node per scene;
## the debug menu (and later code-track-conditions) calls apply().

const BOX_EXTENTS := Vector3(18.0, 6.0, 18.0)
const EMITTER_AHEAD := 8.0    # metres ahead of the camera (fills the view, not the mirror)
const EMITTER_UP := 9.0

var _preset: WeatherPreset
var _particles: GPUParticles3D
var _env: Environment
var _sun: DirectionalLight3D
var _flash_elapsed := -1.0
var _next_flash := 0.0
var _flash_base := 1.0

# One shared cloud panorama for all presets (seamless fractal noise, gradient-thresholded
# into clumps); per-weather look comes from sky_cover_modulate colour + alpha.
static var _cloud_tex: NoiseTexture2D

## The active weather's grip multiplier (GDD 7: weather grip stacks on surface grip).
## VehicleController folds this into every wheel's grip product. Resets with the effect.
static var current_grip_multiplier := 1.0

func apply(preset: WeatherPreset) -> void:
	_preset = preset
	_find_scene_nodes()
	_setup_fog()
	_setup_clouds()
	_setup_particles()
	_flash_elapsed = -1.0
	_next_flash = randf_range(2.0, 5.0)
	current_grip_multiplier = preset.grip_multiplier

func _exit_tree() -> void:
	current_grip_multiplier = 1.0   # weather never leaks into the next scene

func _find_scene_nodes() -> void:
	var tree := get_tree()
	if tree == null:
		return   # not in the tree yet — apply() again once it is
	var base: Node = tree.current_scene
	if base == null:
		base = tree.root
	var envs := base.find_children("*", "WorldEnvironment", true, false)
	_env = (envs[0] as WorldEnvironment).environment if not envs.is_empty() else null
	var suns := base.find_children("*", "DirectionalLight3D", true, false)
	_sun = suns[0] as DirectionalLight3D if not suns.is_empty() else null

func _setup_fog() -> void:
	if _env == null:
		return
	_env.fog_enabled = _preset.fog_enabled
	if _preset.fog_enabled:
		_env.fog_light_color = _preset.fog_color
		_env.fog_density = _preset.fog_density
		_env.fog_sky_affect = 0.5

func _setup_clouds() -> void:
	if _env == null or _env.sky == null:
		return
	var sky_mat := _env.sky.sky_material as ProceduralSkyMaterial
	if sky_mat == null:
		return
	if _preset.cloud_cover <= 0.0:
		sky_mat.sky_cover = null
		return
	if _cloud_tex == null:
		var noise := FastNoiseLite.new()
		noise.seed = 7
		noise.frequency = 0.012
		noise.fractal_octaves = 4
		var grad := Gradient.new()
		grad.offsets = PackedFloat32Array([0.5, 0.72])
		grad.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1)])
		var tex := NoiseTexture2D.new()
		tex.width = 512
		tex.height = 256
		tex.seamless = true
		tex.noise = noise
		tex.color_ramp = grad
		_cloud_tex = tex
	sky_mat.sky_cover = _cloud_tex
	sky_mat.sky_cover_modulate = Color(_preset.cloud_color.r, _preset.cloud_color.g, _preset.cloud_color.b, _preset.cloud_cover)

func _setup_particles() -> void:
	if _particles == null:
		_particles = GPUParticles3D.new()
		_particles.name = "Precipitation"
		add_child(_particles)
	if _preset.precipitation == "none" or _preset.amount <= 0:
		_particles.emitting = false
		_particles.visible = false
		return
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3.DOWN
	mat.spread = 0.0
	mat.initial_velocity_min = _preset.fall_speed * 0.85
	mat.initial_velocity_max = _preset.fall_speed
	mat.gravity = _preset.wind   # fall comes from velocity; gravity carries only the drift
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = BOX_EXTENTS
	if _preset.turbulence > 0.0:
		mat.turbulence_enabled = true
		mat.turbulence_influence_min = _preset.turbulence * 0.5
		mat.turbulence_influence_max = _preset.turbulence
	_particles.process_material = mat
	var box := BoxMesh.new()
	box.size = _preset.particle_size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = _preset.particle_color
	box.material = m
	_particles.draw_pass_1 = box
	_particles.amount = _preset.amount
	_particles.lifetime = maxf(1.0, (BOX_EXTENTS.y + EMITTER_UP + 6.0) / _preset.fall_speed * 1.2)
	_particles.preprocess = _particles.lifetime
	_particles.local_coords = false
	_particles.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))
	_particles.visible = true
	_particles.emitting = true

func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam != null and _particles != null:
		var fwd := -cam.global_transform.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
		_particles.global_position = cam.global_position + fwd * EMITTER_AHEAD + Vector3.UP * EMITTER_UP
	_thunder(delta)

# Randomized double-pulse: bright flash, beat, dimmer echo. Base energy is sampled when each
# flash starts, so lighting-preset changes between storms stay honest.
func _thunder(delta: float) -> void:
	if _preset == null or not _preset.thunder or _sun == null:
		return
	if _flash_elapsed < 0.0:
		_next_flash -= delta
		if _next_flash <= 0.0:
			_flash_elapsed = 0.0
			_flash_base = _sun.light_energy
		return
	_flash_elapsed += delta
	if _flash_elapsed < 0.08:
		_sun.light_energy = _flash_base * 4.0
	elif _flash_elapsed < 0.13:
		_sun.light_energy = _flash_base
	elif _flash_elapsed < 0.2:
		_sun.light_energy = _flash_base * 2.5
	else:
		_sun.light_energy = _flash_base
		_flash_elapsed = -1.0
		_next_flash = randf_range(4.0, 9.0)
