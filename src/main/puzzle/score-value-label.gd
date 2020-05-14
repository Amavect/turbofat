extends Label
"""
Displays the player's score.
"""

func _ready() -> void:
	PuzzleScore.connect("score_changed", self, "_on_PuzzleScore_score_changed")
	text = "0"


func _on_PuzzleScore_score_changed(new_score: int) -> void:
	text = str(new_score)
