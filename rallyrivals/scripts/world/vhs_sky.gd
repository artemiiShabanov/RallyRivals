class_name VhsSky
extends RefCounted
## The one place that builds the custom VHS sky (assets/shaders/vhs_sky.gdshader). The baker
## bakes it into a track's WorldEnvironment; LightingPreset and WeatherFX both call ensure()
## before writing their uniforms, so a scene converges on a single shared ShaderMaterial no
## matter which applies first. Weather owns the gradient uniforms, time-of-day owns the tint
## uniforms — see the shader header for the split.

const SHADER: Shader = preload("res://assets/shaders/vhs_sky.gdshader")

## Return `env`'s sky ShaderMaterial, creating the Sky + material if the env has no sky or an
## older ProceduralSkyMaterial. Idempotent.
static func ensure(env: Environment) -> ShaderMaterial:
	if env == null:
		return null
	var mat := env.sky.sky_material as ShaderMaterial if env.sky != null else null
	if mat != null and mat.shader == SHADER:
		return mat
	mat = ShaderMaterial.new()
	mat.shader = SHADER
	if env.sky == null:
		env.sky = Sky.new()
	env.sky.sky_material = mat
	env.background_mode = Environment.BG_SKY
	return mat
