class_name SKEntityManager
extends Node
## Manages entities in the game.

## The instance of the entity manager.
static var instance: SKEntityManager

var entities: Dictionary = {}
var disk_assets: Dictionary = {}  # TODO: Figure out an alternative that isn't so memory heavy
var regex: RegEx
@export var config:SKConfig


func _init() -> void:
	instance = self


func _ready():
	regex = RegEx.new()
	regex.compile("([^\\/\n\\r]+)\\.t?res")
	_cache_entities(ProjectSettings.get_setting("skelerealms/entities_path"))
	SkeleRealmsGlobal.entity_manager_loaded.emit()
	config.compile()
	for se:StatusEffect in config.status_effects:
		SkeleRealmsGlobal.register_effect(se.name, se)


## Gets an entity in the game. [br]
## This system follows a cascading pattern, and attempts to get entities by following the following steps. It will execute each step, and if it fails to get an entity, it will move onto the next one. [br]
## 1. Tries to get the entity from its internal hash table of entities. [br]
## 2. Scans its children entities to see if it missed any (this step may be removed in the future) [br]
## 3. Attempts to load the entity from disk. [br]
## Failing all of these, it will return [code]none[/code].
func get_entity(id: StringName) -> SKEntity:
	# stage 1: attempt find in cache
	if entities.has(id):
		(entities[id] as SKEntity).reset_stale_timer()  # FIXME: If another entity is carrying a reference to this entity, then we might break stuff by cleaning it up in this way?
		return entities[id]
	# stage 2: Check in save file
	var potential_data = SaveSystem.entity_in_save(id)  # chedk the save system
	if potential_data.some():  # if found:
		add_entity(ResourceLoader.load(disk_assets[id], "InstanceData"))  # load default from disk
		entities[id].load_data(potential_data.unwrap())  # and then load using the data blob we got from the save file
		(entities[id] as SKEntity).reset_stale_timer()
		return entities[id]
	# stage 3: check on disk
	if disk_assets.has(id):
		add_entity(load(disk_assets[id]))
		(entities[id] as SKEntity).reset_stale_timer()
		return entities[id]  # we added the entity in #add_entity

	# Other than that, we've failed. Attempt to find the entity in the child count as a failsave, then return none.
	return get_node_or_null(id as String)


func get_disk_data_for_entity(id: StringName) -> InstanceData:
	if disk_assets.has(id):
		return load(disk_assets[id])
	else:
		return null


func _cache_entities(path: String):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():  # if is directory, cache subdirectory
				_cache_entities("%s/%s" % [path, file_name])
			else:  # if filename, cache filename
				if ".remap" in file_name:
					file_name = file_name.trim_suffix(".remap")
				var result = regex.search(file_name)
				if result:
					disk_assets[result.get_string(1)] = "%s/%s" % [path, file_name]  # TODO: Check if it's actually an InstanceData
			file_name = dir.get_next()
		dir.list_dir_end()

	else:
		print("An error occurred when trying to access the path.")


## add a new entity.
func add_entity(res: InstanceData) -> SKEntity:
	var new_entity = SKEntity.new(res)  # make a new entity
	# add new entity to self, and the dictionary
	entities[res.ref_id] = new_entity
	add_child(new_entity)
	return new_entity


func _add_entity_raw(e: SKEntity) -> SKEntity:
	entities[e.name] = e
	add_child(e)
	return e


## ONLY call after save!!!
func _cleanup_stale_entities():
	# Get all children
	for c in get_children():
		if (
			(c as SKEntity).stale_timer
			>= ProjectSettings.get_setting("skelerealms/entity_cleanup_timer")
		):  # If stale timer is beyond threshold
			remove_entity(c.name)  # remove


## Remove entity from the game.
func remove_entity(rid: StringName) -> void:
	if entities.has(rid):
		entities[rid].queue_free()
		entities.erase(rid)
