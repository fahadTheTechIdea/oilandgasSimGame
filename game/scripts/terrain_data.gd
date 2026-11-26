## Generated terrain data: heights in metres, material bands, world<->grid helpers.
## Mirrors BeepWings' MapData: the generator produces it, the game consumes it.
class_name OilTerrain
extends Resource

const MAT_GRASS := 0
const MAT_DRY := 1
const MAT_ROCK := 2

## Biome / texture ids used by the Terrain3D control map.
const BIOME_GRASS := 0
const BIOME_ROCK := 1
const BIOME_SAND := 2
const BIOME_MUD := 3

@export var resolution := 0
@export var cell_size := 1.0
@export var heights := PackedFloat32Array()
@export var mats := PackedByteArray()
@export var biomes := PackedByteArray()
@export var biome_overlay := PackedByteArray()
@export var biome_blend := PackedFloat32Array()
@export var sea_level := 10.0
@export var max_height := 40.0


func world_size() -> float:
	return float(resolution) * cell_size


## Bilinear height sample in metres, clamped to the map edge.
func height_at(x: float, z: float) -> float:
	if resolution <= 0:
		return 0.0
	var fx := clampf(x / cell_size + float(resolution) * 0.5, 0.0, float(resolution) - 1.001)
	var fz := clampf(z / cell_size + float(resolution) * 0.5, 0.0, float(resolution) - 1.001)
	var x0 := int(fx)
	var z0 := int(fz)
	var tx := fx - float(x0)
	var tz := fz - float(z0)
	var n := resolution
	var h00 := heights[z0 * n + x0]
	var h10 := heights[z0 * n + x0 + 1]
	var h01 := heights[(z0 + 1) * n + x0]
	var h11 := heights[(z0 + 1) * n + x0 + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


func material_at(x: float, z: float) -> int:
	var gx := clampi(int(x / cell_size + float(resolution) * 0.5), 0, resolution - 1)
	var gz := clampi(int(z / cell_size + float(resolution) * 0.5), 0, resolution - 1)
	return int(mats[gz * resolution + gx])


func grid_to_world(gx: int, gz: int) -> Vector2:
	return Vector2(
		(float(gx) - float(resolution) * 0.5) * cell_size,
		(float(gz) - float(resolution) * 0.5) * cell_size
	)
