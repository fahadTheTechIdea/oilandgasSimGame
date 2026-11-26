class_name PortSpec
extends Resource
## Pipeline ports for one structure: which sides accept a pipe and how many runs
## it is designed to serve.
##
## Sides are 4-neighbour bits: East=1, North=2, West=4, South=8. Exported as
## flags so the Inspector shows a checkbox grid instead of a raw integer.

const SIDE_E := 1
const SIDE_N := 2
const SIDE_W := 4
const SIDE_S := 8
const ALL_SIDES := SIDE_E | SIDE_N | SIDE_W | SIDE_S

@export_flags("East:1", "North:2", "West:4", "South:8") var in_sides: int = 0
@export_flags("East:1", "North:2", "West:4", "South:8") var out_sides: int = 0
@export_range(0, 4) var links: int = 0


func mask() -> int:
	return in_sides | out_sides


func accepts(side: int) -> bool:
	return (mask() & side) != 0


static func sides_text(bits: int) -> String:
	var out: Array[String] = []
	if bits & SIDE_E:
		out.append("E")
	if bits & SIDE_N:
		out.append("N")
	if bits & SIDE_W:
		out.append("W")
	if bits & SIDE_S:
		out.append("S")
	return " ".join(out) if not out.is_empty() else "none"
