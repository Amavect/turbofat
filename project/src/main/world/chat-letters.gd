extends Node
"""
Emits letters when creatures talk.

This helps the player tell which creature is currently talking, especially for creatures with unconventional mouths.
"""

const VOICE_POSITIONS_BY_ORIENTATION := {
	Creatures.SOUTHEAST: Vector2(36, -15),
	Creatures.SOUTHWEST: Vector2(-36, -15),
	Creatures.NORTHWEST: Vector2(-36, -21),
	Creatures.NORTHEAST: Vector2(36, -21),
}

const LETTER_ANGLES_BY_ORIENTATION := {
	Creatures.SOUTHEAST: 0.16667 * PI,
	Creatures.SOUTHWEST: 0.83333 * PI,
	Creatures.NORTHWEST: -0.83333 * PI,
	Creatures.NORTHEAST: -0.16667 * PI,
}

onready var overworld_ui: OverworldUi = Global.get_overworld_ui()

onready var _letter_shooter: LetterShooter = $LetterShooter

# the creature currently emitting letters
var _chatter: Creature

func _ready() -> void:
	overworld_ui.connect("chatter_talked", self, "_on_OverworldUi_chatter_talked")


func _physics_process(_delta: float) -> void:
	if _chatter and not _letter_shooter.is_stopped():
		_letter_shooter.letter_position = _chatter.position \
				+ _chatter.get_node("ChatIconHook").position \
				+ VOICE_POSITIONS_BY_ORIENTATION[_chatter.orientation] * _chatter.creature_visuals.scale.y
		
		_letter_shooter.letter_angle = LETTER_ANGLES_BY_ORIENTATION[_chatter.orientation]


func _on_OverworldUi_chatter_talked(new_chatter: Creature) -> void:
	# disconnect signal from old chatter
	if _chatter:
		_chatter.disconnect("talking_changed", self, "_on_Creature_talking_changed")
	_chatter = new_chatter
	
	# connect signal to new chatter
	_chatter.connect("talking_changed", self, "_on_Creature_talking_changed")
	
	# start emitting letters
	_letter_shooter.start()


func _on_Creature_talking_changed() -> void:
	if _chatter.is_talking():
		$LetterShooter.start()
	else:
		$LetterShooter.stop()
