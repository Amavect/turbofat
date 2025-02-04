extends "res://addons/gut/test.gd"
"""
Tests settings for levels.
"""

var settings: LevelSettings

func before_each() -> void:
	settings = LevelSettings.new()


func load_level(filename: String) -> void:
	var json_text := FileUtils.get_file_as_text("res://assets/test/puzzle/levels/%s.json" % [filename])
	var json_dict: Dictionary = parse_json(json_text)
	settings.from_json_dict("test_5952", json_dict)


func test_load_1922_data() -> void:
	load_level("level-1922")
	
	assert_eq(settings.speed_ups.size(), 3)
	assert_eq(settings.speed_ups[0].get_meta("speed"), "2")
	assert_eq(settings.speed_ups[1].get_meta("speed"), "3")
	assert_eq(settings.speed_ups[2].get_meta("speed"), "4")


func test_load_19c5_data() -> void:
	load_level("level-19c5")
	
	var blocks_start := settings.tiles.blocks_start()
	assert_eq(Vector2(1, 10) in blocks_start.block_tiles, true, "start.block_tiles[(1, 10)]")
	assert_eq(blocks_start.block_tiles.get(Vector2(1, 10)), 1, "start.block_tiles[(1, 10)]")
	assert_eq(blocks_start.block_autotile_coords.get(Vector2(1, 10)), Vector2(14, 1), "start.autotile_coords[(1, 10)]")


func test_load_tiles() -> void:
	load_level("level-tiles")
	
	var blocks_start := settings.tiles.blocks_start()
	assert_eq(Vector2(1, 16) in blocks_start.block_tiles, true, "start.block_tiles[(1, 16)]")
	assert_eq(blocks_start.block_tiles.get(Vector2(1, 16)), 2, "start.block_tiles[(1, 16)]")
	assert_eq(blocks_start.block_autotile_coords.get(Vector2(1, 16)), Vector2(9, 1), "start.autotile_coords[(1, 16)]")
	
	var blocks_0 := settings.tiles.get_tiles("0")
	assert_eq(Vector2(3, 2) in blocks_0.block_tiles, true, "0.block_tiles[(3, 2)]")
	assert_eq(blocks_0.block_tiles.get(Vector2(3, 2)), 2, "0.block_tiles[(3, 2)]")
	assert_eq(blocks_0.block_autotile_coords.get(Vector2(3, 2)), Vector2(6, 3), "0.block_autotile_coords[(3, 2)]")
	assert_eq(Vector2(4, 2) in blocks_0.pickups, true, "0.pickups[(4, 2)]")
	assert_eq(blocks_0.pickups.get(Vector2(4, 2)), 4, "0.pickups[(4, 2)]")


func test_path_from_level_key() -> void:
	assert_eq(LevelSettings.path_from_level_key("boatricia1"),
			"res://assets/main/puzzle/levels/boatricia1.json")
	assert_eq(LevelSettings.path_from_level_key("marsh/goodbye_bones"),
			"res://assets/main/puzzle/levels/marsh/goodbye-bones.json")


func test_level_key_from_path_resources() -> void:
	assert_eq(LevelSettings.level_key_from_path("res://assets/main/puzzle/levels/boatricia1.json"),
			"boatricia1")
	assert_eq(LevelSettings.level_key_from_path("res://assets/main/puzzle/levels/marsh/goodbye_bones.json"),
			"marsh/goodbye_bones")


func test_level_key_from_path_files() -> void:
	assert_eq(LevelSettings.level_key_from_path("d:/level_894.json"),
			"level_894")
	assert_eq(LevelSettings.level_key_from_path("/usr/local/bin/level_894.json"),
			"level_894")
	assert_eq(LevelSettings.level_key_from_path("~/.local/share/godot/level_894.json"),
			"level_894")


func _convert_to_json_and_back() -> void:
	var json_dict := settings.to_json_dict()
	settings = LevelSettings.new()
	settings.from_json_dict("id_873", json_dict)


func test_to_json_basic_properties() -> void:
	settings.title = "title 215"
	settings.description = "description 356"
	settings.difficulty = "FD"
	_convert_to_json_and_back()
	
	assert_eq(settings.title, "title 215")
	assert_eq(settings.description, "description 356")
	assert_eq(settings.difficulty, "FD")


func test_to_json_speed_ups() -> void:
	settings.set_start_speed("FC")
	settings.add_speed_up(Milestone.LINES, 10, "FD")
	settings.add_speed_up(Milestone.LINES, 20, "FE")
	settings.speed_ups[2].set_meta("meta_719", "value_719")
	_convert_to_json_and_back()
	
	assert_eq(settings.speed_ups.size(), 3)
	assert_eq(settings.speed_ups[0].type, Milestone.LINES)
	assert_eq(settings.speed_ups[0].value, 0)
	assert_eq(settings.speed_ups[0].get_meta("speed"), "FC")
	assert_eq(settings.speed_ups[1].type, Milestone.LINES)
	assert_eq(settings.speed_ups[1].value, 10)
	assert_eq(settings.speed_ups[1].get_meta("speed"), "FD")
	assert_eq(settings.speed_ups[2].type, Milestone.LINES)
	assert_eq(settings.speed_ups[2].value, 20)
	assert_eq(settings.speed_ups[2].get_meta("speed"), "FE")
	assert_eq(settings.speed_ups[2].get_meta("meta_719"), "value_719")


func test_to_json_milestones_and_tiles() -> void:
	settings.finish_condition.set_milestone(Milestone.TIME_OVER, 180)
	settings.success_condition.set_milestone(Milestone.LINES, 100)
	settings.tiles.bunches["start"] = LevelTiles.BlockBunch.new()
	settings.tiles.bunches["start"].set_block(Vector2(1, 2), 3, Vector2(4, 5))
	_convert_to_json_and_back()
	
	assert_eq(settings.finish_condition.type, Milestone.TIME_OVER)
	assert_eq(settings.finish_condition.value, 180)
	assert_eq(settings.success_condition.type, Milestone.LINES)
	assert_eq(settings.success_condition.value, 100)
	assert_eq(settings.tiles.bunches.keys(), ["start"])
	assert_eq(settings.tiles.bunches["start"].block_tiles[Vector2(1, 2)], 3)
	assert_eq(settings.tiles.bunches["start"].block_autotile_coords[Vector2(1, 2)], Vector2(4, 5))


func test_to_json_rules() -> void:
	settings.blocks_during.clear_on_top_out = true
	settings.combo_break.pieces = 3
	settings.input_replay.action_timings = {"25 +rotate_cw": true, "33 -rotate_cw": true}
	settings.lose_condition.finish_on_lose = true
	settings.other.after_tutorial = true
	settings.piece_types.start_types = [PieceTypes.piece_j, PieceTypes.piece_l]
	settings.rank.box_factor = 2.0
	settings.score.cake_points = 30
	settings.timers.timers = [{"interval": 5}]
	settings.triggers.from_json_array(
			[{"phases": ["after_line_cleared y=0-5"], "effect": "insert_line tiles_key=0"}])
	_convert_to_json_and_back()
	
	assert_eq(settings.blocks_during.clear_on_top_out, true)
	assert_eq(settings.combo_break.pieces, 3)
	assert_eq(settings.input_replay.action_timings.keys(), ["25 +rotate_cw", "33 -rotate_cw"])
	assert_eq(settings.lose_condition.finish_on_lose, true)
	assert_eq(settings.other.after_tutorial, true)
	assert_eq(settings.piece_types.start_types, [PieceTypes.piece_j, PieceTypes.piece_l])
	assert_eq(settings.rank.box_factor, 2.0)
	assert_eq(settings.score.cake_points, 30)
	assert_eq_deep(settings.timers.timers, [{"interval": 5}])
	assert_eq(settings.triggers.triggers.keys(), [LevelTrigger.AFTER_LINE_CLEARED])
