extends RefCounted
## Runtime region reskin (code-track-regions). Given a freshly-instanced baked track and a RegionDef,
## restyles the track to the region's biome IN PLACE — no rebake — so one baked track reads as any
## region ("same track, new place", CAMPAIGN.md). Called at track-load (RaceDirector._build,
## track_demo) right after the .tscn is instanced, alongside the per-race conditions (lighting/weather).
##
## NO class_name — preloaded BY PATH by the boot-critical race harness, so it never depends on the
## global class registry. Region is passed as a plain Resource (a RegionDef) and read by duck-typing.
##
## Stage 1 (here): props — recolour each baked placeholder prop to the region's tint, via the
## `prop_type` meta the baker stamps on every prop. Stage 2 will add the off-road ground (grip + colour)
## and Stage 3 the scenery dressing. Each layer is a no-op when the region doesn't specify it, and the
## whole thing is a safe no-op when region or track is null (test races / F6 without a region).

## Reskin `track` to `region` (a RegionDef Resource). Null region or track -> no-op (neutral track).
static func apply(track: Node, region: Resource) -> void:
	if track == null or region == null:
		return
	_reskin_ground(track, region)   # Stage 2: off-road grip + ground colour
	_reskin_props(track, region)    # Stage 1: prop tints
	_add_dressing(track, region)    # Stage 3: placeholder scenery backdrop

# Recolour every baked prop whose type the region tints. Reads the `prop_type` meta (TrackBaker sets it
# on each prop body); leaves collision + transform untouched — a region changes only how props LOOK.
static func _reskin_props(track: Node, region: Resource) -> void:
	var props := track.get_node_or_null("Props")
	if props == null or region.prop_tints.is_empty():
		return
	for prop in props.get_children():
		var t := String(prop.get_meta("prop_type", ""))
		if not region.prop_tints.has(t):
			continue                                  # infrastructure / untinted types keep their look
		var col: Color = region.prop_tints[t]
		for child in prop.get_children():
			if child is MeshInstance3D:
				var mesh_inst := child as MeshInstance3D
				# Each baked prop owns its StandardMaterial3D (per-instance), so tint it directly; dup
				# defensively in case a future baker shares one, so we never mutate a shared resource.
				var mat := mesh_inst.material_override
				if mat is StandardMaterial3D:
					var m := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
					m.albedo_color = col
					mesh_inst.material_override = m

# Stage 2 — off-road GROUND: swap grip (the SurfaceMap's off_road SurfaceType) and the ground COLOUR
# (the off-road slot of the shared terrain palette uniform). Both the SurfaceMap and the terrain
# material are DUPLICATED first so the reskin can't bleed into the .tscn's cached shared resources
# (which would leak this region's ground into the next race). Classification stays anchored to the
# baked off_road_key, so swapping to grass/snow can't make off-road pixels read as a road surface.
static func _reskin_ground(track: Node, region: Resource) -> void:
	var s: SurfaceType = region.off_road_surface
	if s == null:
		return
	var ground := track.get_node_or_null("Ground")
	if ground == null or not ground.has_meta("surface_map"):
		return
	var smap = ground.get_meta("surface_map").duplicate()   # grip
	var offroad_idx: int = smap.surfaces.size()             # off_road is appended last in the palette
	smap.off_road = s
	ground.set_meta("surface_map", smap)
	var mat := _terrain_mat(ground)                          # colour
	if mat == null:
		return
	var dup := mat.duplicate() as ShaderMaterial
	var pal = dup.get_shader_parameter("palette")
	if pal is PackedVector3Array and offroad_idx < pal.size():
		pal[offroad_idx] = Vector3(s.color.r, s.color.g, s.color.b)
		dup.set_shader_parameter("palette", pal)
	_set_float_slot(dup, "variation", offroad_idx, s.tint_variation)
	_set_float_slot(dup, "rough", offroad_idx, s.roughness)
	_set_float_slot(dup, "chunk", offroad_idx, s.chunkiness)
	for mi in ground.get_children():
		if mi is MeshInstance3D and (mi as MeshInstance3D).material_override is ShaderMaterial:
			(mi as MeshInstance3D).material_override = dup

# Stage 3 — placeholder DRESSING: a seeded ring of tinted prisms at the horizon (mountains / treeline /
# water band, per the region's vibe) so each biome reads as a distinct place. Gray-box until
# art-voxel-environment; region.dressing_tint/density drive it. Parented under a "Dressing" node.
static func _add_dressing(track: Node, region: Resource) -> void:
	if float(region.dressing_density) <= 0.0:
		return
	var ground := track.get_node_or_null("Ground")
	var aabb := _ground_aabb(ground)
	if aabb.size == Vector3.ZERO:
		return
	var center := aabb.get_center()
	var radius: float = maxf(aabb.size.x, aabb.size.z) * 0.5
	if radius <= 1.0:
		return
	var dress := Node3D.new(); dress.name = "Dressing"
	track.add_child(dress)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(region.id)) if String(region.id) != "" else 20260801
	var mat := StandardMaterial3D.new()
	mat.albedo_color = region.dressing_tint
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.roughness = 1.0
	var count := int(48.0 * clampf(float(region.dressing_density), 0.1, 2.0))
	var ring_r := radius * 1.25
	var base_y := aabb.position.y
	for i in count:
		var ang := TAU * float(i) / float(count) + rng.randf_range(-0.03, 0.03)
		var h := rng.randf_range(radius * 0.10, radius * 0.38)
		var w := rng.randf_range(radius * 0.06, radius * 0.15)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = Vector3(w, h, w)
		mi.mesh = bm
		mi.material_override = mat
		mi.position = center + Vector3(cos(ang) * ring_r, base_y + h * 0.5 - center.y, sin(ang) * ring_r)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dress.add_child(mi)

# The shared terrain ShaderMaterial (every Ground/Mesh_* carries the same one as material_override).
static func _terrain_mat(ground: Node) -> ShaderMaterial:
	for mi in ground.get_children():
		if mi is MeshInstance3D and (mi as MeshInstance3D).material_override is ShaderMaterial:
			return (mi as MeshInstance3D).material_override
	return null

static func _set_float_slot(mat: ShaderMaterial, param: String, idx: int, value: float) -> void:
	var arr = mat.get_shader_parameter(param)
	if arr is PackedFloat32Array and idx < arr.size():
		arr[idx] = value
		mat.set_shader_parameter(param, arr)

# Combined world AABB of the ground's meshes (baker builds world-space verts, Ground at origin).
static func _ground_aabb(ground: Node) -> AABB:
	var out := AABB()
	if ground == null:
		return out
	var first := true
	for mi in ground.get_children():
		if mi is MeshInstance3D and (mi as MeshInstance3D).mesh != null:
			var a: AABB = (mi as MeshInstance3D).get_aabb()
			out = a if first else out.merge(a)
			first = false
	return out
