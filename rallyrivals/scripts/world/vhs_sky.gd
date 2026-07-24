class_name VhsSky
extends RefCounted
## The one place that builds the custom VHS sky (assets/shaders/vhs_sky.gdshader). The baker
## bakes it into a track's WorldEnvironment; LightingPreset and WeatherFX both call ensure()
## before writing their uniforms, so a scene converges on a single shared ShaderMaterial no
## matter which applies first. Weather owns the gradient/clouds uniforms, time-of-day owns the
## tint uniforms — see the shader header for the split.

const SHADER: Shader = preload("res://assets/shaders/vhs_sky.gdshader")

# One shared cloud panorama (seamless fractal noise) for every sky; per-weather look is the
# cloud_amount / cloud_color uniforms, not the texture.
static var _cloud_tex: NoiseTexture2D

## Return `env`'s sky ShaderMaterial, creating the Sky + material (and wiring the cloud noise)
## if the env has no sky or an older ProceduralSkyMaterial. Idempotent.
static func ensure(env: Environment) -> ShaderMaterial:
	if env == null:
		return null
	var mat := env.sky.sky_material as ShaderMaterial if env.sky != null else null
	if mat != null and mat.shader == SHADER:
		return mat
	mat = ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("cloud_noise", _clouds())
	if env.sky == null:
		env.sky = Sky.new()
	env.sky.sky_material = mat
	env.background_mode = Environment.BG_SKY
	return mat

static func _clouds() -> NoiseTexture2D:
	if _cloud_tex != null:
		return _cloud_tex
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	_cloud_tex = tex
	return tex
