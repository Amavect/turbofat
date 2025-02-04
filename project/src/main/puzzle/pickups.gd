extends Control
"""
Creates pickups on the playfield for certain levels.

These pickups react to the player's piece, changing their appearance and spawning food.
"""

# emitted when a food item should be spawned because the player collects a pickup
signal food_spawned(cell, remaining_food, food_type)

# sound effect volume when the piece overlaps a pickup, temporarily turning it into a food
const OVERLAP_VOLUME_DB := -6.0

const PICKUP_DEFAULT: int = BlocksDuringRules.PickupType.DEFAULT
const PICKUP_FLOAT: int = BlocksDuringRules.PickupType.FLOAT
const PICKUP_FLOAT_REGEN: int = BlocksDuringRules.PickupType.FLOAT_REGEN

export (NodePath) var _puzzle_tile_map_path: NodePath
export (PackedScene) var PickupScene: PackedScene

# key: Vector2 playfield cell positions
# value: Pickup node contained within that cell
var _pickups_by_cell: Dictionary

# the next pickup sound effect to play
var _pickup_sfx_index := 0

# how many more pickup sounds should play after the current one
var _remaining_pickup_sfx := 0

onready var _puzzle_tile_map: PuzzleTileMap = get_node(_puzzle_tile_map_path)

# parent node for the pickup graphics
onready var _visuals := $Visuals

# timer which triggers playing consecutive pickup sounds. we don't want to play them all simultaneously
onready var _pickup_sfx_timer := $CollectSfxTimer

# array of AudioStreamPlayer instances which play pickup sounds
onready var _pickup_sfx_players := [$PickupSfx0, $PickupSfx1, $PickupSfx2, $PickupSfx3, $PickupSfx4, $PickupSfx5]

func _ready() -> void:
	PuzzleState.connect("before_piece_written", self, "_on_PuzzleState_before_piece_written")
	PuzzleState.connect("game_prepared", self, "_on_PuzzleState_game_prepared")
	PuzzleState.connect("after_piece_written", self, "_on_PuzzleState_after_piece_written")
	CurrentLevel.connect("settings_changed", self, "_on_Level_settings_changed")
	Pauser.connect("paused_changed", self, "_on_Pauser_paused_changed")
	_prepare_pickups_for_level()


"""
Adds or replaces a pickup in a playfield cell.
"""
func set_pickup(cell: Vector2, box_type: int) -> void:
	remove_pickup(cell)
	
	if box_type != -1:
		var pickup: Pickup = PickupScene.instance()
		pickup.food_type = _food_type_for_box_type(box_type, cell)

		pickup.position = _puzzle_tile_map.map_to_world(cell + Vector2(0, -3))
		pickup.position += _puzzle_tile_map.cell_size * Vector2(0.5, 0.5)
		pickup.position *= _puzzle_tile_map.scale
		pickup.scale = _puzzle_tile_map.scale
		pickup.z_index = 4 # in front of the active piece
		
		_pickups_by_cell[cell] = pickup
		_visuals.add_child(pickup)


"""
Removes a pickup from a playfield cell.
"""
func remove_pickup(cell: Vector2) -> void:
	if not _pickups_by_cell.has(cell):
		return
	
	_pickups_by_cell[cell].queue_free()
	_pickups_by_cell.erase(cell)


"""
Removes all pickups from all playfield cells.
"""
func clear() -> void:
	for pickup in _visuals.get_children():
		pickup.queue_free()
	_pickups_by_cell.clear()


"""
Spawns any pickups necessary for starting the current level.
"""
func _prepare_pickups_for_level() -> void:
	var src_pickups := CurrentLevel.settings.tiles.blocks_start().pickups
	
	var pickups_to_add := []
	var pickups_to_remove := []
	
	# calculate pickups to add/replace
	for src_pickup_cell in src_pickups:
		if not _pickups_by_cell.has(src_pickup_cell):
			# pickup doesn't exist. need to add it
			pickups_to_add.append(src_pickup_cell)
		elif _pickups_by_cell[src_pickup_cell].food_type \
				!= _food_type_for_box_type(src_pickups[src_pickup_cell], src_pickup_cell):
			# pickup is the wrong type. need to replace it
			pickups_to_add.append(src_pickup_cell)
	
	# calculate pickups to remove
	for dest_pickup_cell in _pickups_by_cell:
		if not src_pickups.has(dest_pickup_cell):
			# pickup shouldn't exist. need to remove it
			pickups_to_remove.append(dest_pickup_cell)
	
	# remove/replace/add pickups
	for cell in pickups_to_remove:
		remove_pickup(cell)
	for cell in pickups_to_add:
		set_pickup(cell, src_pickups[cell])
	for cell in _pickups_by_cell:
		_pickups_by_cell[cell].food_shown = false


"""
Return the food type which belongs in the specified cell.

The food type corresponds to the box type, although we alternate identical snack box pickups in a checkerboard pattern.
"""
func _food_type_for_box_type(box_type: int, cell: Vector2) -> int:
	var food_types: Array = Foods.FOOD_TYPES_BY_BOX_TYPES[box_type]
	return food_types[(int(cell.x + cell.y) % food_types.size())]


"""
Updates the overlapped pickups as the player moves their piece.
"""
func _refresh_pickup_state(piece: ActivePiece) -> void:
	var play_overlap_sfx := false
	
	for pickup_cell in _pickups_by_cell:
		var pickup: Pickup = _pickups_by_cell[pickup_cell]
		var piece_overlaps_pickup := false
		for pos_arr_item_obj in piece.get_pos_arr():
			if pickup_cell == pos_arr_item_obj + piece.pos:
				piece_overlaps_pickup = true
				break
		
		if piece_overlaps_pickup and not pickup.food_shown:
			play_overlap_sfx = true
		if piece_overlaps_pickup != pickup.food_shown:
			pickup.food_shown = piece_overlaps_pickup
	
	if play_overlap_sfx:
		for player_obj in _pickup_sfx_players:
			var player: AudioStreamPlayer = player_obj
			if not player.playing:
				player.volume_db = OVERLAP_VOLUME_DB
				player.play()
				break


"""
Removes all pickups from a playfield row.
"""
func _erase_row(y: int) -> void:
	for x in range(PuzzleTileMap.COL_COUNT):
		remove_pickup(Vector2(x, y))


"""
Shifts a group of pickups up or down.

Parameters:
	'bottom_row': The lowest row to shift. All pickups at or above this row will be shifted.
	
	'direction': The direction to shift the pickups, such as Vector2.UP or Vector2.DOWN.
"""
func _shift_rows(bottom_row: int, direction: Vector2) -> void:
	# First, erase and store all the old pickups which are shifting
	var shifted := {}
	for cell in _pickups_by_cell.keys():
		if cell.y > bottom_row:
			# pickups below the specified bottom row are left alone
			continue
		# pickups above the specified bottom row are shifted
		_pickups_by_cell[cell].position += direction * _puzzle_tile_map.cell_size * _puzzle_tile_map.scale
		if cell.y == PuzzleTileMap.FIRST_VISIBLE_ROW - 1:
			_pickups_by_cell[cell].visible = true
		shifted[cell + direction] = _pickups_by_cell[cell]
		_pickups_by_cell.erase(cell)
	
	# Next, write the old pickups in their new locations
	for cell in shifted.keys():
		_pickups_by_cell[cell] = shifted[cell]


"""
Plays a single sound effect for the next collected pickup.

Also schedules a followup sound effect if more pickup sounds need to be played.
"""
func _play_collect_sfx() -> void:
	if _pickup_sfx_index < _pickup_sfx_players.size():
		_pickup_sfx_players[_pickup_sfx_index].stop()
		_pickup_sfx_players[_pickup_sfx_index].volume_db = 0
		_pickup_sfx_players[_pickup_sfx_index].play()
	_remaining_pickup_sfx -= 1
	_pickup_sfx_index += 1
	if _remaining_pickup_sfx > 0:
		_pickup_sfx_timer.start()


func _pickup_type() -> int:
	return CurrentLevel.settings.blocks_during.pickup_type


func _on_PuzzleState_game_prepared() -> void:
	_prepare_pickups_for_level()


func _on_Level_settings_changed() -> void:
	_prepare_pickups_for_level()


func _on_Playfield_blocks_prepared() -> void:
	if not _puzzle_tile_map:
		# _ready() has not yet been called
		return
	_prepare_pickups_for_level()


func _on_PieceManager_piece_changed(piece: ActivePiece) -> void:
	_refresh_pickup_state(piece)


"""
When the piece is placed, we collect any overlapped pickups.
"""
func _on_PuzzleState_before_piece_written() -> void:
	# count shown pickups
	var pickup_count := 0
	for pickup_cell in _pickups_by_cell:
		var pickup: Pickup = _pickups_by_cell[pickup_cell]
		if pickup.food_shown:
			pickup_count += 1
	
	var remaining_food_for_line_clears := pickup_count
	var pickup_score := 0
	
	# Emit food_spawned signals and remove collected pickups.
	# We iterate over a copy of the key set to avoid bugs when keys are removed.
	for pickup_cell in _pickups_by_cell.keys():
		var pickup: Pickup = _pickups_by_cell[pickup_cell]
		if not pickup.food_shown:
			# pickup is not currently being collected
			continue
		
		if pickup.is_cake():
			pickup_score += CurrentLevel.settings.score.cake_pickup_points
		else:
			pickup_score += CurrentLevel.settings.score.snack_pickup_points
		
		if _pickup_type() == PICKUP_FLOAT_REGEN:
			# temporarily hide the pickup until after the piece is written
			pickup.visible = false
		else:
			remove_pickup(pickup_cell)
		
		remaining_food_for_line_clears -= 1
		emit_signal("food_spawned", pickup_cell, remaining_food_for_line_clears, pickup.food_type)
	
	if pickup_score:
		PuzzleState.add_pickup_score(pickup_score)
		_remaining_pickup_sfx = pickup_count
		_pickup_sfx_index = 0
		_play_collect_sfx()


func _on_PuzzleState_after_piece_written() -> void:
	if _pickup_type() == PICKUP_FLOAT_REGEN:
		for pickup in _visuals.get_children():
			# restore the pickup to its default uncollected state
			if not pickup.visible:
				pickup.food_shown = false
				pickup.visible = true


func _on_Playfield_line_erased(y: int, _total_lines: int, _remaining_lines: int, _box_ints: Array) -> void:
	if _pickup_type() in [PICKUP_FLOAT_REGEN]:
		# pickups are not erased
		pass
	else:
		# erase pickups; this is especially important when the player tops out
		_erase_row(y)


func _on_Playfield_lines_deleted(lines: Array) -> void:
	if _pickup_type() in [PICKUP_FLOAT, PICKUP_FLOAT_REGEN]:
		# pickups do not move
		pass
	else:
		for y in lines:
			# some levels might have rows which are deleted, but not erased. erase any pickups
			_erase_row(y)
			
			# drop all pickups above the deleted lines to fill the gap
			_shift_rows(y - 1, Vector2.DOWN)


func _on_Playfield_line_inserted(y: int, tiles_key: String, src_y: int) -> void:
	if _pickup_type() in [PICKUP_FLOAT, PICKUP_FLOAT_REGEN]:
		# pickups do not move
		pass
	else:
		# raise all pickups at or above the specified row
		_shift_rows(y, Vector2.UP)
		
		# fill in the new gaps with pickups
		var block_bunch := CurrentLevel.settings.tiles.get_tiles(tiles_key)
		for x in range(PuzzleTileMap.COL_COUNT):
			var src_pos := Vector2(x, src_y)
			if not block_bunch.pickups.has(src_pos):
				continue
			var box_type: int = block_bunch.pickups[src_pos]
			set_pickup(Vector2(x, y), box_type)


func _on_PickupSfxTimer_timeout() -> void:
	_play_collect_sfx()


"""
When the player pauses, we hide the playfield so they can't cheat.
"""
func _on_Pauser_paused_changed(value: bool) -> void:
	visible = not value
