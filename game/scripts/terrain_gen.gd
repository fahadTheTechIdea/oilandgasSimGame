## Deterministic terrain generator, built on Godot's FastNoiseLite.
##
## The lease is a coastal plain: a flat central basin (where the player base
## plots sit), a gently rolling grassland, an irregular sea coast to the north,
## a smooth mountain belt along the southern edge and a river draining east.
## Landforms are explicit; noise only adds natural variation, so the map reads
## as a landscape rather than a random noise field.
##
## The result is an OilTerrain resource, so the mesh, collision and the gameplay
## height queries all read the same data.
class_name OilTerrainGen
extends RefCounted

const TERRAIN_SHADER := "res://shaders/terrain.gdshader"


## Build one seamless byte noise field (0..1) with a single C++ call.
static func _field(seed_value: int, n: int, freq_scale: float, octaves: int) -> PackedByteArray:
	var f := FastNoiseLite.new()
	f.seed = seed_value
	f.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	f.fractal_type = FastNoiseLite.FRACTAL_FBM
	f.fractal_octaves = octaves
	f.frequency = freq_scale / float(n)
	return f.get_image(n, n, false, false, true).get_data()


## Bilinear sample of a byte noise field at float grid coordinates.
static func _sample_field(field: PackedByteArray, n: int, fx: float, fz: float) -> float:
	var x := clampf(fx, 0.0, float(n - 1))
	var z := clampf(fz, 0.0, float(n - 1))
	var x0 := int(x)
	var z0 := int(z)
	var x1 := mini(x0 + 1, n - 1)
	var z1 := mini(z0 + 1, n - 1)
	var tx := x - float(x0)
	var tz := z - float(z0)
	var r0 := z0 * n
	var r1 := z1 * n
	var a := lerpf(float(field[r0 + x0]), float(field[r0 + x1]), tx)
	var b := lerpf(float(field[r1 + x0]), float(field[r1 + x1]), tx)
	return lerpf(a, b, tz) / 255.0


static func generate(seed_value: int, resolution: int, cell: float) -> OilTerrain:
	var data := OilTerrain.new()
	var n: int = maxi(64, resolution)
	var cs: float = maxf(0.5, cell)
	data.resolution = n
	data.cell_size = cs
	data.max_height = 96.0
	var count: int = n * n

	# Broad fields. They vary the explicit landforms, never define them.
	var coast_warp := _field(seed_value + 101, n, 2.2, 2)
	var ridge_line := _field(seed_value + 303, n, 3.0, 2)
	var river_line := _field(seed_value + 505, n, 3.0, 2)
	var hills := _field(seed_value + 707, n, 6.0, 3)
	var hills2 := _field(seed_value + 808, n, 13.0, 2)
	var detail := _field(seed_value + 909, n, 24.0, 2)
	var climate := _field(seed_value + 7919, n, 2.0, 2)

	data.heights.resize(count)
	data.mats.resize(count)
	data.biomes.resize(count)
	data.biome_overlay.resize(count)
	data.biome_blend.resize(count)

	var sea: float = data.sea_level
	var raw := PackedFloat32Array()
	raw.resize(count)
	var humid := PackedFloat32Array()
	humid.resize(count)
	var river_d := PackedFloat32Array()
	river_d.resize(count)
	var mount := PackedFloat32Array()
	mount.resize(count)

	# Pass 1: coast, plain, mountain belt, river and hills.
	for gz in n:
		var wz: float = (float(gz) - float(n) * 0.5) * cs
		for gx in n:
			var i: int = gz * n + gx
			var wx: float = (float(gx) - float(n) * 0.5) * cs
			var d: float = sqrt(wx * wx + wz * wz)

			# coast: sea to the north, land rising south into the plain
			var coast_off: float = (_sample_field(coast_warp, n, float(gx), float(gz)) - 0.5) * 70.0
			var coast: float = smoothstep(-250.0, -120.0, wz + coast_off)
			var h: float = lerpf(-6.0, 20.0, coast)

			# one smooth mountain belt along the southern edge
			var crest: float = 265.0 + sin(wx * 0.008) * 22.0 \
				+ (_sample_field(ridge_line, n, float(gx), 4.0) - 0.5) * 30.0
			var mass: float = exp(-pow((wz - crest) / 58.0, 2.0))
			h += mass * 42.0
			h += exp(-pow((wz - crest) / 120.0, 2.0)) * 6.0   # foothills

			# rolling relief: gentle in the basin, stronger toward the edges
			var plain: float = 1.0 - smoothstep(150.0, 240.0, d)
			var hill_n: float = _sample_field(hills, n, float(gx), float(gz))
			var hill2_n: float = _sample_field(hills2, n, float(gx), float(gz))
			h += (hill_n - 0.5) * lerpf(8.0, 5.0, plain)
			h += (hill2_n - 0.5) * 2.5
			h += (_sample_field(detail, n, float(gx), float(gz)) - 0.5) * 1.2

			# the basin stays low and rolling, so the pads are easy to level
			h = lerpf(h, 20.0, plain * 0.22)

			# river from the hills to the sea, east of the base plots. The bed
			# drops below sea level so the sea plane actually fills it.
			var rx: float = 200.0 + sin(wz * 0.010) * 24.0 \
				+ (_sample_field(river_line, n, 4.0, float(gz)) - 0.5) * 24.0
			var rd: float = absf(wx - rx)
			var channel: float = exp(-pow(rd / 14.0, 2.0))
			var valley: float = exp(-pow(rd / 36.0, 2.0))
			var river: float = channel
			h -= channel * 9.0 + valley * 3.0

			raw[i] = h
			river_d[i] = rd
			mount[i] = mass

			# moisture: broad climate, wetter near the river and the coast
			var m: float = 0.46 + (_sample_field(climate, n, float(gx), float(gz)) - 0.5) * 0.50
			m += river * 0.15
			m += (1.0 - smoothstep(sea + 1.0, sea + 10.0, h)) * 0.15
			m -= mass * 0.12
			humid[i] = clampf(m, 0.0, 1.0)

	# Pass 2: gentle erosion smoothing and landform-driven biomes.
	for gz in n:
		var wz: float = (float(gz) - float(n) * 0.5) * cs
		for gx in n:
			var i: int = gz * n + gx
			var wx: float = (float(gx) - float(n) * 0.5) * cs
			var d: float = sqrt(wx * wx + wz * wz)

			var h: float = raw[i]
			var sum: float = raw[i] * 4.0
			var weight: float = 4.0
			for dz in range(-1, 2):
				var nz: int = clampi(gz + dz, 0, n - 1)
				for dx in range(-1, 2):
					if dx == 0 and dz == 0:
						continue
					var w: float = 2.0 if (dx == 0 or dz == 0) else 1.0
					sum += raw[nz * n + clampi(gx + dx, 0, n - 1)] * w
					weight += w
			h = lerpf(h, sum / weight, 0.30)
			h = clampf(h, 0.5, 92.0)

			var mass: float = mount[i]
			var m: float = humid[i]

			# Soft weights instead of hard classification: the grass base fades
			# into sand/mud over a wide band, so no grid-line texture seams.
			var sand_w: float = 0.0
			if h < sea + 3.5:
				sand_w = smoothstep(sea + 3.5, sea + 0.3, h)
			# dry climate creates desert, but never on the central base plain
			sand_w = maxf(sand_w, smoothstep(0.52, 0.74, 1.0 - m) * 0.9
				* smoothstep(120.0, 220.0, d))

			var mud_w: float = 0.0
			if river_d[i] < 44.0:
				mud_w = smoothstep(44.0, 6.0, river_d[i]) * smoothstep(sea + 22.0, sea + 2.0, h)

			# faint dry-grass mottling so the grassland is not one flat colour
			var var_n: float = _sample_field(hills2, n, float(gx) * 0.6, float(gz) * 0.6)
			sand_w = maxf(sand_w, smoothstep(0.58, 0.82, var_n) * 0.16 * (1.0 - mass))

			var base_id := OilTerrain.BIOME_GRASS
			var overlay_id := OilTerrain.BIOME_SAND
			var blend: float = sand_w
			if mud_w > sand_w:
				overlay_id = OilTerrain.BIOME_MUD
				blend = mud_w

			# only the high crests turn to bare rock; foothills stay grassy
			if mass > 0.52:
				overlay_id = OilTerrain.BIOME_ROCK
				blend = smoothstep(0.52, 0.74, mass)
				if mass > 0.74:
					base_id = OilTerrain.BIOME_ROCK
					overlay_id = OilTerrain.BIOME_GRASS
					blend = 0.2
			blend = clampf(blend, 0.0, 1.0)

			data.heights[i] = h
			data.biomes[i] = base_id
			data.biome_overlay[i] = overlay_id
			data.biome_blend[i] = blend
			if base_id == OilTerrain.BIOME_ROCK:
				data.mats[i] = OilTerrain.MAT_ROCK
			elif base_id == OilTerrain.BIOME_SAND or base_id == OilTerrain.BIOME_MUD:
				data.mats[i] = OilTerrain.MAT_DRY
			else:
				data.mats[i] = OilTerrain.MAT_GRASS
	return data


static func build_mesh(data: OilTerrain, uv_per_metre: float = 0.12) -> ArrayMesh:
	var n := data.resolution
	if n < 2:
		return ArrayMesh.new()
	var cs := data.cell_size
	var half := float(n) * cs * 0.5

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	verts.resize(n * n)
	normals.resize(n * n)
	colors.resize(n * n)
	uvs.resize(n * n)

	for gz in n:
		for gx in n:
			var i := gz * n + gx
			var h := data.heights[i]
			verts[i] = Vector3(float(gx) * cs - half, h, float(gz) * cs - half)
			var hl := data.heights[gz * n + maxi(gx - 1, 0)]
			var hr := data.heights[gz * n + mini(gx + 1, n - 1)]
			var hd := data.heights[maxi(gz - 1, 0) * n + gx]
			var hu := data.heights[mini(gz + 1, n - 1) * n + gx]
			normals[i] = Vector3(hl - hr, 2.0 * cs, hd - hu).normalized()
			var m := int(data.mats[i])
			var tint := Color(0.92, 0.96, 0.88)
			if m == OilTerrain.MAT_DRY:
				tint = Color(0.98, 0.95, 0.84)
			elif m == OilTerrain.MAT_ROCK:
				tint = Color(0.78, 0.76, 0.70)
			colors[i] = tint
			uvs[i] = Vector2(verts[i].x, verts[i].z) * uv_per_metre

	var faces := (n - 1) * (n - 1) * 6
	indices.resize(faces)
	var w := 0
	for gz in n - 1:
		for gx in n - 1:
			var a := gz * n + gx
			var b := a + 1
			var c := a + n
			var d := c + 1
			indices[w] = a
			indices[w + 1] = c
			indices[w + 2] = b
			indices[w + 3] = b
			indices[w + 4] = c
			indices[w + 5] = d
			w += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func build_body(data: OilTerrain) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	var shape := HeightMapShape3D.new()
	shape.map_width = data.resolution
	shape.map_depth = data.resolution
	shape.map_data = data.heights
	var cs := CollisionShape3D.new()
	cs.shape = shape
	# HeightMapShape3D samples are 1 m apart; scale to the terrain cell size
	cs.scale = Vector3(data.cell_size, 1.0, data.cell_size)
	body.add_child(cs)
	return body
