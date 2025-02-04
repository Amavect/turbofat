class_name PieceQueue
extends Node
"""
Queue of upcoming randomized pieces.

This queue stores the upcoming pieces so they can be displayed, and randomizes them according to some complex rules.
"""

# minimum number of next pieces in the queue, before we add more
const MIN_SIZE := 50

const UNLIMITED_PIECES := 999999

# queue of upcoming NextPiece instances
var pieces := []

# default pieces to pull from if none are provided by the level
var _default_piece_types := PieceTypes.all_types

var _remaining_piece_count := UNLIMITED_PIECES

func _ready() -> void:
	CurrentLevel.connect("settings_changed", self, "_on_Level_settings_changed")
	PuzzleState.connect("game_prepared", self, "_on_PuzzleState_game_prepared")
	_fill()


"""
Clears the pieces and refills the piece queues.
"""
func clear() -> void:
	if CurrentLevel.settings.finish_condition.type == Milestone.PIECES:
		_remaining_piece_count = CurrentLevel.settings.finish_condition.value
	else:
		_remaining_piece_count = UNLIMITED_PIECES
	pieces.clear()
	_fill()


"""
Pops the next piece off the queue.
"""
func pop_next_piece() -> NextPiece:
	var next_piece_type: NextPiece = pieces.pop_front()
	if _remaining_piece_count != UNLIMITED_PIECES:
		_remaining_piece_count -= 1
	_fill()
	return next_piece_type


"""
Returns a specific piece in the queue.
"""
func get_next_piece(index: int) -> NextPiece:
	return pieces[index]


func _apply_piece_limit() -> void:
	if _remaining_piece_count < pieces.size():
		for i in range(_remaining_piece_count, pieces.size()):
			pieces[i] = _new_next_piece(PieceTypes.piece_null)


"""
Fills the queue with randomized pieces.

The first pieces have some constraints to limit players from having especially lucky or unlucky starts. Later pieces
have fewer constraints, but still use a bagging algorithm to ensure fairness.
"""
func _fill() -> void:
	if pieces.empty():
		_fill_initial_pieces()
	_fill_remaining_pieces()
	_apply_piece_limit()


"""
Initializes an empty queue with a set of starting pieces.
"""
func _fill_initial_pieces() -> void:
	if CurrentLevel.settings.piece_types.types.empty() and CurrentLevel.settings.piece_types.start_types.empty():
		"""
		Default starting pieces:
		1. Append three same-size pieces which can't build a cake box; lot, jot, jlt or pqu
		2. Append a piece which can't build a snack box or a cake box
		3. Append a piece which can build a snack box, but not a cake box
		4. Append the remaining three pieces
		5. Insert an extra piece in the last 3 positions
		
		These are called 'bad starts' since they avoid giving player ideal openings of 'lojpqvut' or 'lqpjutov' where
		each piece fits with the previous piece.
		"""
		var all_bad_starts := [
			[PieceTypes.piece_l, PieceTypes.piece_o, PieceTypes.piece_t, PieceTypes.piece_p, PieceTypes.piece_q],
			[PieceTypes.piece_l, PieceTypes.piece_o, PieceTypes.piece_t, PieceTypes.piece_p, PieceTypes.piece_v],
			[PieceTypes.piece_l, PieceTypes.piece_o, PieceTypes.piece_t, PieceTypes.piece_p, PieceTypes.piece_u],
			
			[PieceTypes.piece_j, PieceTypes.piece_o, PieceTypes.piece_t, PieceTypes.piece_q, PieceTypes.piece_p],
			[PieceTypes.piece_j, PieceTypes.piece_o, PieceTypes.piece_t, PieceTypes.piece_q, PieceTypes.piece_v],
			[PieceTypes.piece_j, PieceTypes.piece_o, PieceTypes.piece_t, PieceTypes.piece_q, PieceTypes.piece_u],
			
			[PieceTypes.piece_j, PieceTypes.piece_l, PieceTypes.piece_t, PieceTypes.piece_v, PieceTypes.piece_p],
			[PieceTypes.piece_j, PieceTypes.piece_l, PieceTypes.piece_t, PieceTypes.piece_v, PieceTypes.piece_q],
			[PieceTypes.piece_j, PieceTypes.piece_l, PieceTypes.piece_t, PieceTypes.piece_v, PieceTypes.piece_u],
			
			[PieceTypes.piece_p, PieceTypes.piece_q, PieceTypes.piece_u, PieceTypes.piece_o, PieceTypes.piece_j],
			[PieceTypes.piece_p, PieceTypes.piece_q, PieceTypes.piece_u, PieceTypes.piece_o, PieceTypes.piece_l],
			[PieceTypes.piece_p, PieceTypes.piece_q, PieceTypes.piece_u, PieceTypes.piece_o, PieceTypes.piece_t],
		]
		var bad_start: Array = Utils.rand_value(all_bad_starts)
		for piece_type in bad_start:
			pieces.append(_new_next_piece(piece_type))
		pieces.shuffle()
		
		var _other_piece_types := shuffled_piece_types()
		for piece_type in _other_piece_types:
			var duplicate_piece := false
			for piece in pieces:
				if piece.type == piece_type:
					duplicate_piece = true
					break
			if not duplicate_piece:
				pieces.push_back(_new_next_piece(piece_type))
		
		_insert_annoying_piece(3)
	elif CurrentLevel.settings.piece_types.start_types and CurrentLevel.settings.piece_types.ordered_start:
		# Fixed starting pieces: Append all of the start pieces in order.
		for piece_type in CurrentLevel.settings.piece_types.start_types:
			pieces.append(_new_next_piece(piece_type))
	else:
		# Shuffled starting pieces: Append all of the start pieces in a random order, skipping duplicates.
		var pieces_tmp: Array = CurrentLevel.settings.piece_types.start_types.duplicate()
		pieces_tmp.shuffle()
		for piece_type in pieces_tmp:
			if pieces.empty() or pieces[0].type != piece_type:
				# avoid prepending duplicate pieces
				pieces.push_front(_new_next_piece(piece_type))


"""
Creates a new next piece with the specified type.
"""
func _new_next_piece(type: PieceType) -> NextPiece:
	var next_piece := NextPiece.new()
	next_piece.type = type
	if pieces:
		# if the last piece in the queue has been rotated, we match its orientation.
		next_piece.orientation = pieces.back().orientation
	return next_piece


func shuffled_piece_types() -> Array:
	var result: Array = CurrentLevel.settings.piece_types.types
	if not result:
		result = _default_piece_types
	result = result.duplicate()
	result.shuffle()
	return result


"""
Extends a non-empty queue by adding more pieces.

The algorithm puts all 8 piece types into a bag with one extra random piece. It pulls random pieces from the bag, but
avoids pulling the same piece back to back. With this algorithm you're always able to build four 3x3 boxes, but the
extra piece acts as an helpful tool for 3x4 boxes and 3x5 boxes, or an annoying deterrent for 3x3 boxes.
"""
func _fill_remaining_pieces() -> void:
	while pieces.size() < MIN_SIZE:
		# fill a bag with one of each piece and one extra; draw them out in a random order
		var new_piece_types := shuffled_piece_types()
		for piece_type in new_piece_types:
			pieces.append(_new_next_piece(piece_type))
		
		if new_piece_types.size() >= 3:
			# for levels with multiple identical pieces in the bag, we shuffle the bag so that those identical pieces
			# aren't back to back
			var min_to_index := pieces.size() - new_piece_types.size()
			var from_index := min_to_index
			while from_index < pieces.size():
				var to_index := from_index
				if pieces[from_index].type == pieces[from_index - 1].type:
					# a piece appears back-to-back; move it to a new position
					to_index = _move_duplicate_piece(from_index, min_to_index)
				if to_index <= from_index:
					# don't advance from_index if it would skip an item in the queue
					from_index += 1
		_insert_annoying_piece(new_piece_types.size())


"""
Moves a piece which appears back-to-back in the piece queue.

Parameters:
	'from_index': The index of the piece being moved
	
	'min_to_index': The earliest position in the queue the piece can be moved to

Returns:
	The position the piece was moved to, or 'from_index' if the piece did not move.
"""
func _move_duplicate_piece(from_index: int, min_to_index: int) -> int:
	# remove the piece from the queue
	var duplicate_piece: NextPiece = pieces[from_index]
	pieces.remove(from_index)
	
	# find a new position for it
	var to_index := from_index
	var piece_positions := non_adjacent_indexes(pieces, duplicate_piece.type, min_to_index)
	if piece_positions:
		to_index = Utils.rand_value(piece_positions)
	
	# move the piece to its new place in the queue
	pieces.insert(to_index, duplicate_piece)
	return to_index


"""
Returns 'true' if the specified array has the same piece back-to-back.
"""
func _has_duplicate_pieces(in_pieces: Array) -> bool:
	var result := false
	for i in range(in_pieces.size() - 1):
		if in_pieces[i].type == in_pieces[i + 1].type:
			result = true
			break
	return result


"""
Inserts an extra piece into the bag.

Turbo Fat's pieces fit together too well. We periodically add extra pieces to the bag to ensure the game isn't too
easy.

Parameters:
	'max_pieces_to_right': The maximum number of pieces to the right of the new piece. '0' guarantees the new piece
			will be appended to the end of the queue, '8' means it will be mixed in with the last eight pieces.
"""
func _insert_annoying_piece(max_pieces_to_right: int) -> void:
	var new_piece_index := int(rand_range(pieces.size() - max_pieces_to_right + 1, pieces.size() + 1))
	var extra_piece_types: Array = shuffled_piece_types()
	if extra_piece_types.size() >= 3:
		# check the neighboring pieces, and remove those from the pieces we're picking from
		Utils.remove_all(extra_piece_types, pieces[new_piece_index - 1].type)
		if new_piece_index < pieces.size():
			Utils.remove_all(extra_piece_types, pieces[new_piece_index].type)
	
	if extra_piece_types:
		if extra_piece_types[0] == PieceTypes.piece_o:
			# the o piece is awful, so it comes 10% less often
			extra_piece_types.shuffle()
		pieces.insert(new_piece_index, _new_next_piece(extra_piece_types[0]))


func _on_Level_settings_changed() -> void:
	clear()


func _on_PuzzleState_game_prepared() -> void:
	clear()


"""
Returns a list of of positions where a piece can be inserted without being adjacent to another piece of the same type.

non_adjacent_indexes(['j', 'o'], 'j')      = [2]
non_adjacent_indexes(['j', 'o', 't'], 't') = [0, 1]
non_adjacent_indexes([], 't')              = [0]
non_adjacent_indexes(['o', 'j', 'o'], 'o') = []

Parameters:
	'pieces': An array of NextPiece instances representing pieces in a queue.
	
	'piece_type': The type of the piece being inserted.
	
	'from_index': The lowest position to check in the piece queue.
"""
static func non_adjacent_indexes(in_pieces: Array, piece_type: PieceType, from_index: int = 0) -> Array:
	var result := []
	for i in range(from_index, in_pieces.size() + 1):
		if (i == 0 or piece_type != in_pieces[i - 1].type) \
				and (i >= in_pieces.size() or piece_type != in_pieces[i].type):
			result.append(i)
	return result
