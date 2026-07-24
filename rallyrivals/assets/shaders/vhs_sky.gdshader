shader_type sky;

// VHS sky (art-world-skybox). A deliberately CHUNKY, retro sky: a posterised vertical
// colour gradient (stepped bands, not a smooth ramp) and a hard low-res sun disk read from
// the scene's sun (DirectionalLight0). Deliberately CLOUDLESS — noise clouds read as mush
// against the hard bands, so overcast is expressed by the gradient + haze instead.
//
// Two authors drive it, matching the design split:
//   * WEATHER owns the look — zenith/horizon/ground band colours, sun visibility, horizon
//     haze (WeatherFX.apply writes these). A rainy sky is grey here.
//   * TIME OF DAY only tints — sky_tint (mul) + sky_energy (day<->night darken) come from
//     LightingPreset, and the sun disk inherits the sun light's colour/energy/angle. So the
//     same weather reads grey at noon and dark-grey at night, with the sun where the hour
//     puts it.
// Defaults below are a clear-day look, so a baked track shown with no conditions applied
// (e.g. F6 straight into a scene) still renders a sensible sky.

group_uniforms Gradient;
uniform vec3 zenith_color : source_color = vec3(0.20, 0.36, 0.50);
uniform vec3 horizon_color : source_color = vec3(0.78, 0.88, 0.95);
uniform vec3 ground_color : source_color = vec3(0.34, 0.36, 0.42);
uniform float bands : hint_range(2.0, 16.0) = 7.0;     // number of colour steps (chunky)
uniform float gradient_curve : hint_range(0.3, 3.0) = 0.65;  // <1 packs bands near horizon

group_uniforms Sun;
uniform float sun_visibility : hint_range(0.0, 1.0) = 1.0;  // 0 = hidden (overcast/fog)
uniform float sun_size : hint_range(0.0, 0.3) = 0.02;       // angular radius of the hard core
uniform float sun_glow : hint_range(0.0, 0.4) = 0.13;

group_uniforms TimeOfDay;
uniform vec3 sky_tint : source_color = vec3(1.0, 1.0, 1.0);  // multiply (warmth)
uniform float sky_energy : hint_range(0.0, 2.0) = 1.0;       // brightness (night darkens)
uniform float haze : hint_range(0.0, 1.0) = 0.0;            // whiten toward horizon

void sky() {
	float el = EYEDIR.y;                       // -1 (down) .. 1 (up)

	// --- posterised vertical gradient ---
	float t = pow(clamp(el, 0.0, 1.0), gradient_curve);
	float bt = round(t * (bands - 1.0)) / max(bands - 1.0, 1.0);
	vec3 sky_col = mix(horizon_color, zenith_color, bt);

	// crisp-ish horizon: sky above, flat ground colour just below
	float above = smoothstep(-0.02, 0.01, el);
	vec3 col = mix(ground_color, sky_col, above);

	// --- horizon haze (fog / overcast whiteout) ---
	float h = haze * (1.0 - smoothstep(0.0, 0.55, clamp(el, 0.0, 1.0)));
	col = mix(col, horizon_color, h * 0.7);

	// time-of-day tint + darken (weather look x hour)
	col *= sky_tint * sky_energy;

	// --- hard low-res sun disk, from the actual sun light ---
	if (LIGHT0_ENABLED && sun_visibility > 0.001) {
		float sd = dot(EYEDIR, LIGHT0_DIRECTION);    // LIGHT0_DIRECTION points toward the sun; 1 at its centre
		vec3 sun_col = LIGHT0_COLOR * clamp(LIGHT0_ENERGY, 0.2, 3.0);
		float core = step(1.0 - sun_size, sd);
		float glow = smoothstep(1.0 - sun_size - sun_glow, 1.0 - sun_size, sd);
		glow = floor(glow * 3.0) / 3.0;              // posterised glow rings
		col = mix(col, sun_col, core * sun_visibility);
		col += sun_col * glow * 0.35 * sun_visibility;
	}

	COLOR = col;
}
