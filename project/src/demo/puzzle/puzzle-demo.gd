extends Node
"""
Shows off the visual effects for the puzzle.

Keys:
	[Q,W,E]: Build a box at different locations in the playfield
	[T,Y]: Insert a line at different locations in the playfield
	[A,S,D,F,G]: Change the box color to brown, pink, bread, white, cake
	[H]: Change the cake box variation used to make cake boxes
	[U,I,O]: Clear a line at different locations in the playfield
	[P]: Add pickups
	[J]: Generate a food item
	[K]: Cycle to the next food item
	[L]: Level up
"""

var _line_clear_count := 1
var _box_type := 0
var _food_item_index := 0
var _cake_box_type: int = Foods.BoxType.CAKE_JJO

# a local path to a json level resource to demo
export (String, FILE, "*.json") var level_path: String

func _ready() -> void:
	var settings: LevelSettings = LevelSettings.new()
	if level_path:
		var json_text := FileUtils.get_file_as_text(level_path)
		var json_dict: Dictionary = parse_json(json_text)
		settings.from_json_dict("test_5952", json_dict)
	CurrentLevel.start_level(settings)


func _input(event: InputEvent) -> void:
	match Utils.key_scancode(event):
		KEY_Q: _build_box(3)
		KEY_W: _build_box(9)
		KEY_E: _build_box(15)
		
		KEY_T: _insert_line("", PuzzleTileMap.ROW_COUNT - 1)
		KEY_Y: _insert_line("", PuzzleTileMap.ROW_COUNT - 2)
		
		KEY_A: _box_type = Foods.BoxType.BROWN
		KEY_S: _box_type = Foods.BoxType.PINK
		KEY_D: _box_type = Foods.BoxType.BREAD
		KEY_F: _box_type = Foods.BoxType.WHITE
		
		KEY_G: _box_type = _cake_box_type
		KEY_H:
			_cake_box_type = wrapi(_cake_box_type + 1,
					Foods.BoxType.CAKE_JJO, Foods.BoxType.CAKE_QUV)
			_box_type = _cake_box_type
		
		KEY_U: _clear_line(3)
		KEY_I: _clear_line(9)
		KEY_O: _clear_line(15)
		
		KEY_P: _add_pickups()
		
		KEY_J: $Puzzle/FoodItems.add_food_item(Vector2(1, 4), _food_item_index)
		KEY_K:
			_food_item_index = (_food_item_index + 1) % 16
			$Puzzle/FoodItems.add_food_item(Vector2(1, 4), _food_item_index)
		
		KEY_L:
			PuzzleState.set_speed_index((PuzzleState.speed_index + 1) % CurrentLevel.settings.speed_ups.size())


func _build_box(y: int) -> void:
	$Puzzle/Playfield/BoxBuilder.build_box(Rect2(6, y, 3, 3), _box_type)


func _insert_line(tiles_key: String, y: int) -> void:
	CurrentLevel.puzzle.get_playfield().line_inserter.insert_line(tiles_key, y)


func _clear_line(cleared_line: int) -> void:
	$Puzzle/Playfield/LineClearer.lines_being_cleared = range(cleared_line, cleared_line + _line_clear_count)
	$Puzzle/Playfield/LineClearer.clear_line(cleared_line, 1, 0)


func _add_pickups() -> void:
	var cells := []
	for y in range(PuzzleTileMap.ROW_COUNT - 5, PuzzleTileMap.ROW_COUNT):
		for x in range(PuzzleTileMap.COL_COUNT):
			cells.append(Vector2(x, y))
	
	for cell in cells:
		var box_type: int = [
			Foods.BoxType.BROWN,
			Foods.BoxType.PINK,
			Foods.BoxType.BREAD,
			Foods.BoxType.WHITE,
			Foods.BoxType.CAKE_JLO,
		][int(cell.y) % 5]
		if $Puzzle/Playfield.tile_map.is_cell_empty(cell):
			$Puzzle/Pickups.set_pickup(cell, box_type)
