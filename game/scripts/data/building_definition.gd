class_name BuildingDefinition
extends Resource
## One buildable structure: cost, footprint, model, upkeep, pipeline ports and
## capacity. This is the data asset the game reads; tune it in the Inspector.

@export var id: String = ""
@export var display_name: String = ""
@export var cost: float = 0.0
@export_range(1, 4) var footprint: int = 1
@export var model_id: String = ""
@export var upkeep: float = 0.0

## Menu/UI data — the build menu and hotkeys are generated from these, so a new
## structure needs no code changes.
@export var hotkey: String = ""
@export var category: String = ""     # build-menu section, grouped in catalogue order
@export var order: int = 0
@export var icon_index: int = -1
@export var icon_path: String = ""
@export var description: String = ""
@export var minimap_color: Color = Color(0.80, 0.80, 0.75)

## Placement rules as data.
@export var requires_deposit: bool = false
@export var spacing_role: String = ""
@export_range(0, 4) var spacing_cells: int = 0
@export var logistics: float = 0.0   # load this site puts on its road network
@export var network_boost: float = 0.0  # extra logistics a depot adds to its network
@export var unit_job: String = ""       # logistics | seismic | prep | hauler
@export var forward_deg: float = 0.0    # model forward offset; kit vehicles face +Z
@export var buildable: bool = true      # false = pre-placed / hidden in the build menu

## producer | buffer | consumer | booster | survey | transport | access
@export_enum("producer", "buffer", "consumer", "booster", "processor", "meter", "survey", "transport", "access", "unit", "base")
var role: String = "producer"

@export var ports: PortSpec
@export var capacity: CapacitySpec


func port_mask() -> int:
	return ports.mask() if ports != null else 0


func links() -> int:
	return ports.links if ports != null else 0
