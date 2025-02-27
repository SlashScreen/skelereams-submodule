class_name SKEntity
extends Node
## An entity for the pseudo-ecs. Contains [SKEntityComponent]s.
## These allow constructs such as NPCs and Items to persist even when not in the scene.


## The world this entity is in.
@export var world: String
## Position within the world it's in.
@export var position:Vector3
## Rotation of this Enitiy.
@export var rotation:Quaternion = Quaternion.IDENTITY
## An internal timer of how long this entity has gone without being modified or referenced.
## One it's beyond a certain point, the [SKEntityManager] will mark it for cleanup after a save.
var stale_timer:float
## This is used to prevent items from spawning, even if they are supposed to be in scene.
## For example, items in invcentories should not spawn despite technically being "in the scene".
var supress_spawning:bool
## FLag telling if this was created dynamically (eg. [class SpawnPoint]).
var generated:bool
## Whether this entity is in the scene or not.
var in_scene: bool:
	get:
		return in_scene
	set(val):
		if in_scene && !val: # if was in scene and now not
			left_scene.emit()
		if !in_scene && val: # if was not in scene and now is
			entered_scene.emit()
		in_scene = val


## Emitted when an entity enters a scene.
signal left_scene
## Emitted when an entity leaves a scene.
signal entered_scene
## This signal is emitted when all components have been added once [SKEntityManager.add_entity] is called.
## Await this when you want to connect with other nodes.
signal instantiated


func _init(res:InstanceData = null) -> void:
	if not res:
		return

	var new_nodes = res.get_archetype_components() # Get the entity components
	for c in get_children(): # if this entity already exists, get rid of the components. FIXME: This is inefficient.
		c.queue_free()

	name = res.ref_id # set its name to the instance refID
	world = res.world
	position = res.position
	if not res.get("rotation") == null:
		rotation = res.rotation

	for n in new_nodes: # add all components to entity
		add_child(n)
		n.owner = self
		(n as SKEntityComponent).parent_entity = self

	# call entity ready
	instantiated.emit()
	for c in get_children():
		c._entity_ready()


func _ready():
	add_to_group("savegame_entity")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	_should_be_in_scene()
	# If we aren't in the scene, start counting up. Otherwise, we are still in the scene with the player and shouldn't depsawn.
	if not in_scene:
		stale_timer += delta
	else:
		stale_timer = 0


## Determine that this entity should be in scene
func _should_be_in_scene():
	if supress_spawning:
		in_scene = false
		return
	# if not in correct world
	if GameInfo.world != world:
		in_scene = false
		return
	# if we are outside of actor fade distance
	if position.distance_squared_to(GameInfo.world_origin.global_position) > ProjectSettings.get_setting("skelerealms/actor_fade_distance") ** 2:
		in_scene = false
		return
	in_scene = true


func _on_set_position(p:Vector3):
	position = p


func _on_set_rotation(q:Quaternion) -> void:
	rotation = q


## Gets a component by the string name.
## Example: [codeblock]
## (e.get_component("NPCComponent") as NPCComponent).kill()
## [/codeblock]
func get_component(type:String) -> SKEntityComponent:
	var n = get_node_or_null(type)
	return n


## Whether it has a component type or not. Useful for checking the capabilities of an entity.
func has_component(type:String) -> bool:
	var x = get_component(type)
	return not x == null


func add_component(c:SKEntityComponent) -> void:
	add_child(c)


func save() -> Dictionary: # TODO: Determine if instance is saved to disk. If not, save that as well. This will Theoretically allow for dynamic instances.
	var data:Dictionary = {
		"entity_data": {
			"world" = world,
			"position" = position,
			"generated" = generated
		}
	}
	for c in get_children().filter(func(x:SKEntityComponent): return x.dirty): # filter to get dirty acomponents
		data["components"][c.name] = ((c as SKEntityComponent).save())
	return data


func load_data(data:Dictionary) -> void:
	world = data["entity_data"]["world"]
	position = JSON.parse_string(data["entity_data"]["position"])
	generated = JSON.parse_string(data["entity_data"]["generated"])

	# loop through all saved components and call load
	for d in data["components"]:
		(get_node(d) as SKEntityComponent).load_data(data[d])
	pass


func reset_data() -> void:
	# TODO: Figure out how to reset entities that are generated at runtime. oh boy that's gonna be fun.
	var i = SKEntityManager.instance.get_disk_data_for_entity(name)
	if i:
		_init(i)


func reset_stale_timer() -> void:
	stale_timer = 0


func broadcast_message(msg:String, args:Array = []) -> void:
	for c in get_children():
		if c.has_method(msg):
			c.call(msg, args)


func dialogue_command(command:String, args:Array) -> void:
	for c in get_children():
		c._try_dialogue_command(command, args)


func gather_debug_info() -> Array[String]:
	var info: Array[String] = []
	info.push_back("""
[b]SKEntity[/b]
	SKEntity RefID: %s
	World: %s
	Position: x%s y%s z%s
	Rotation: x%s y%s z%s w%s
	In scene: %s
""" % [
	name,
	world,
	position.x,
	position.y,
	position.z,
	rotation.x,
	rotation.y,
	rotation.z,
	rotation.w,
	in_scene
])
	
	for c in get_children():
		var i:String = (c as SKEntityComponent).gather_debug_info()
		if not i.is_empty():
			info.push_back(i)
	
	return info


## Prints a rich text message to the console prepended with the entity name. Used for easier debugging. 
func printe(text:String) -> void:
	print_rich("[b]%s[/b]: %s" % [name, text])
