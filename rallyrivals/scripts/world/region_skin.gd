extends RefCounted
const EnvCatalog := preload("res://scripts/world/env_catalog.gd")   # scenery models (art-voxel-environment)
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
	var corner: float = Vector2(aabb.size.x, aabb.size.z).length() * 0.5   # to the square footprint's corner
	if corner <= 1.0:
		return
	var base_y := aabb.position.y                                          # ground floor (footprint low point)
	var density := clampf(float(region.dressing_density), 0.1, 2.0)
	var dress := Node3D.new(); dress.name = "Dressing"
	track.add_child(dress)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(region.id)) if String(region.id) != "" else 20260801

	# Water plane at the far horizon (Island) — a big flat tinted sheet just under the ground floor.
	if bool(region.dressing_water):
		var water := MeshInstance3D.new()
		var pm := PlaneMesh.new(); pm.size = Vector2(corner * 8.0, corner * 8.0)
		water.mesh = pm
		var wmat := StandardMaterial3D.new()
		wmat.albedo_color = Color(0.16, 0.34, 0.55); wmat.roughness = 0.25; wmat.metallic = 0.1
		water.material_override = wmat
		water.position = Vector3(center.x, base_y - corner * 0.05, center.z)
		dress.add_child(water)

	# Backdrop: tile the region's silhouette model around the horizon ring, facing centre. Per-region
	# tuning: backdrop_scale (size), backdrop_dist (ring radius), backdrop_count (how many segments).
	var bid := String(region.dressing_backdrop)
	if EnvCatalog.has(bid):
		var ring_r := corner * 1.2 * float(region.backdrop_dist)
		var target_h := corner * 0.22 * float(region.backdrop_scale)
		var scl := maxf(target_h / maxf(EnvCatalog.size(bid).y, 0.1), 1.0)
		var base_count := TAU * ring_r / maxf(EnvCatalog.size(bid).x * scl * 0.85, 1.0)
		var count := int(clampf(base_count * float(region.backdrop_count), 3.0, 44.0))
		for i in count:
			var ang := TAU * float(i) / float(count) + rng.randf_range(-0.05, 0.05)
			var s := scl * rng.randf_range(0.8, 1.3)
			var node := _env_node(bid, region, false)
			node.scale = Vector3(s, s, s)
			node.position = center + Vector3(cos(ang) * ring_r, base_y - center.y, sin(ang) * ring_r)
			node.rotation.y = atan2(center.x - node.position.x, center.z - node.position.z)   # wide face to centre
			dress.add_child(node)

	# Buildings: ringed OUTSIDE the track footprint (closer than the backdrop), scaled up, as scenery
	# (non-collidable) sitting on the base plane — a village around the track, not track obstacles.
	var bldgs: Array = region.dressing_buildings
	if not bldgs.is_empty():
		var b_ring := corner * 1.12                          # just beyond the square, inside the backdrop
		var bscale: float = maxf(float(region.building_scale), 0.5)
		var b_count := int(clampf(6.0 * density, 3.0, 12.0))
		for i in b_count:
			var mid := String(bldgs[i % bldgs.size()])
			if not EnvCatalog.has(mid):
				continue
			var ang := TAU * (float(i) + rng.randf_range(0.15, 0.85)) / float(b_count)
			var rr := b_ring * rng.randf_range(0.95, 1.08)
			var node := _env_node(mid, region, false)        # scenery outside the track
			node.scale = Vector3(bscale, bscale, bscale)
			node.position = center + Vector3(cos(ang) * rr, base_y - center.y, sin(ang) * rr)
			node.rotation.y = rng.randf() * TAU
			dress.add_child(node)

# One scenery node: the imported .obj mesh (base at y=0) or, until it's imported, a tinted box fallback
# the model's size. Solid models are wrapped in a StaticBody (box collider, layer 1 the car hits).
static func _env_node(id: String, region: Resource, solid: bool) -> Node3D:
	var mesh := EnvCatalog.mesh(id)
	var sz := EnvCatalog.size(id)
	var mi := MeshInstance3D.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if mesh != null:
		mi.mesh = mesh
	else:
		var bm := BoxMesh.new(); bm.size = sz
		mi.mesh = bm
		mi.position.y = sz.y * 0.5                                        # box centred -> base at y=0
		var mat := StandardMaterial3D.new(); mat.albedo_color = region.dressing_tint; mat.roughness = 1.0
		mi.material_override = mat
	if not solid:
		return mi
	var body := StaticBody3D.new()
	body.collision_layer = 1; body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new(); shape.size = sz
	cs.shape = shape; cs.position = Vector3(0.0, sz.y * 0.5, 0.0)
	body.add_child(cs)
	body.add_child(mi)
	return body

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
