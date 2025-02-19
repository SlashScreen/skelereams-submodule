class_name SKEntityComponent 
extends Node
## A component that is within an [SKEntity].
## Extend these to add functionality to an entity.
## When inheriting, make sure to call super._ready() if overriding.


## Parent entity of this component.
@onready var parent_entity:SKEntity = get_parent() as SKEntity
## Whether this component should be saved.
var dirty:bool = false

# Called when the node enters the scene tree for the first time.
func _ready():
	parent_entity = get_parent() as SKEntity
	if not parent_entity.left_scene.is_connected(_on_exit_scene.bind()):
		parent_entity.left_scene.connect(_on_exit_scene.bind())
	if not parent_entity.entered_scene.is_connected(_on_enter_scene.bind()):
		parent_entity.entered_scene.connect(_on_enter_scene.bind())


func _entity_ready() -> void:
	pass


## Called when the parent entity enters a scene. See [signal SKEntity.entered_scene].
func _on_enter_scene():
	pass


## Called when the parent entity exits a scene. See [signal SKEntity.left_scene].
func _on_exit_scene():
	pass


func _try_dialogue_command(command:String, args:Array) -> void:
	pass


func save() -> Dictionary:
	return {}


func load_data(data:Dictionary):
	pass


func gather_debug_info() -> String:
	return ""


## Prints a rich text message to the console prepended with the entity name. Used for easier debugging. 
func printe(text:String) -> void:
	parent_entity.printe(text)
