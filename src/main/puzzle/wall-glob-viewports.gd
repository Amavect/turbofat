extends FrostingViewports
"""
Draws frosting smears when globs collide with the four outer walls.
"""

func _on_FrostingGlobs_hit_wall(glob: FrostingGlob, glob_alpha: float) -> void:
	add_smear(glob)
