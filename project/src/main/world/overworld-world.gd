extends Node
"""
Populates/unpopulates the creatures and obstacles on the overworld.
"""

export (NodePath) var creature_shadows_path: NodePath
export (NodePath) var chat_icons_path: NodePath
export (NodePath) var overworld_ui_path: NodePath
export (NodePath) var player_path: NodePath
export (PackedScene) var CreaturePackedScene: PackedScene

onready var _creature_shadows: CreatureShadows = get_node(creature_shadows_path)
onready var _chat_icons: ChatIcons = get_node(chat_icons_path)
onready var _overworld_ui: OverworldUi = get_node(overworld_ui_path)
onready var _player: Creature = get_node(player_path)

func _ready() -> void:
	var creature_scene := load("res://src/main/world/creature/Creature.tscn")
	if not ResourceCache.richie:
		print("22: initializing richie")
		ResourceCache.richie = creature_scene.instance()
		ResourceCache.richie.name = "Richie"
		ResourceCache.richie.creature_id = "richie"
		ResourceCache.richie.position = Vector2(113, 444)
		ResourceCache.richie.orientation = Creature.SOUTHWEST
		ResourceCache.richie.add_to_group("chattables")
	else:
		print("31: richie already initialized")
	$Obstacles.add_child(ResourceCache.richie)
	
	if not ResourceCache.skins:
		print("22: initializing skins")
		ResourceCache.skins = creature_scene.instance()
		ResourceCache.skins.name = "Skins"
		ResourceCache.skins.creature_id = "skins"
		ResourceCache.skins.position = Vector2(-86, 444)
		ResourceCache.skins.orientation = Creature.SOUTHWEST
		ResourceCache.skins.add_to_group("chattables")
	else:
		print("31: skins already initialized")
	$Obstacles.add_child(ResourceCache.skins)
	
	if not ResourceCache.bones:
		print("22: initializing bones")
		ResourceCache.bones = creature_scene.instance()
		ResourceCache.bones.name = "Bones"
		ResourceCache.bones.creature_id = "bones"
		ResourceCache.bones.position = Vector2(-176, 484)
		ResourceCache.bones.orientation = Creature.SOUTHEAST
		ResourceCache.bones.add_to_group("chattables")
	else:
		print("31: bones already initialized")
	$Obstacles.add_child(ResourceCache.bones)
	
	if not ResourceCache.shirts:
		print("22: initializing shirts")
		ResourceCache.shirts = creature_scene.instance()
		ResourceCache.shirts.name = "Shirts"
		ResourceCache.shirts.creature_id = "shirts"
		ResourceCache.shirts.position = Vector2(-56, 594)
		ResourceCache.shirts.orientation = Creature.SOUTHEAST
		ResourceCache.shirts.add_to_group("chattables")
	else:
		print("31: shirts already initialized")
	$Obstacles.add_child(ResourceCache.shirts)
	
	if Level.launched_level_id:
		_overworld_ui.cutscene = true
		
		# remove all of the creatures from the overworld
		for child in [$Obstacles/Bort, $Obstacles/Ebe, $Obstacles/Boatricia]:
			child.queue_free()
		
		# add the cutscene creatures
		var creature: Creature = CreaturePackedScene.instance()
		creature.creature_id = Level.launched_creature_id
		creature.add_to_group("chattables")
		$Obstacles.add_child(creature)
		_chat_icons.create_icon(creature)
		_creature_shadows.create_shadow(creature)
		
		# reposition the cutscene creatures, ensuring fat creatures have enough space
		creature.position = _player.position
		creature.position += Vector2(creature.chat_extents.x, 0)
		creature.position += Vector2(_player.chat_extents.x, 0)
		creature.position += Vector2(60, 0)
		
		_schedule_chat(creature)
	
	ChattableManager.refresh_creatures()
	get_tree().get_root().connect("size_changed", self, "_on_Viewport_size_changed")
	_refresh_goop_control_size()


func _exit_tree() -> void:
	Global.benchmark_start("remove-creatures")
	for creature in [ResourceCache.richie, ResourceCache.skins, ResourceCache.bones, ResourceCache.shirts]:
		if creature:
			print("99: remove %s" % [creature.name])
			$Obstacles.remove_child(creature)
	Global.benchmark_end("remove-creatures")


func _process(_delta: float) -> void:
	# scroll the goop and ground textures as the camera scrolls
	var transform: Transform2D = $Ground.get_canvas_transform()
	var new_offset := transform.get_origin() / (get_viewport().get_visible_rect().size * transform.get_scale())
	$Ground/GoopViewport/GoopTextureRect.material.set_shader_param("offset", new_offset)
	$Ground/ScrewportTexrect.material.set_shader_param("red_texture_offset", Vector2(1, -1) * new_offset)


func _schedule_chat(creature: Creature) -> void:
	yield(get_tree(), "idle_frame")
	var chat_tree := ChatLibrary.load_chat_events_for_creature(creature, Level.launched_level_num)
	_overworld_ui.start_chat(chat_tree, creature)


"""
Scales the goop texture based on the viewport size.
"""
func _refresh_goop_control_size() -> void:
	var new_size: Vector2 = $Ground/ScrewportTexrect.get_viewport_rect().size / $Ground/ScrewportTexrect.rect_scale
	$Ground/GoopViewport/GoopTextureRect.material.set_shader_param("squash_factor",
			Vector2(new_size.x * 0.5 / new_size.y, 1.0))
	$Ground/ScrewportTexrect.material.set_shader_param("green_texture_scale",
			new_size / $Ground/GoopViewport.size)


func _on_Viewport_size_changed() -> void:
	_refresh_goop_control_size()
