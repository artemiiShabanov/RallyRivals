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
	_reskin_props(track, region)

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
