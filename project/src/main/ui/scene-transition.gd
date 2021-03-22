extends Node
"""
Emits scene transition signals and keeps track of the currently active scene transition.
"""

const SCREEN_FADE_OUT_DURATION := 0.3
const SCREEN_FADE_IN_DURATION := 0.6

# A scene transition emits these four signals in order as the screen fades out and fades back in
signal fade_out_started
signal fade_in_started

# Set to 'true' when the scene transition starts fading out, and 'false' when it finishes fading back in
var fading: bool

# The color to fade to during scene transitions.
var fade_color: Color = ProjectSettings.get_setting("rendering/environment/default_clear_color")

# The method and parameters to call on the Breadcrumb node after fading out.
var breadcrumb_method: String
var breadcrumb_arg_array: Array

"""
Navigates forward one level, appending the new path to the breadcrumb trail after a scene transition.

Parameters:
	'path': The path to append to the breadcrumb trail. This is usually a scene path such as 'res://MyScene.tscn', but
		it can also include a '::foo' suffix for navigation paths which do not result in a scene change.

	'skip_transition': If 'true', the scene changes immediately without fading.
"""
func push_trail(path: String, skip_transition: bool = false) -> void:
	if skip_transition or not get_tree().get_nodes_in_group("scene_transition_covers"):
		Breadcrumb.push_trail(path)
	else:
		_fade_out("push_trail", [path])


"""
Navigates back one level in the breadcrumb trail after a scene transition.

Parameters:
	'skip_transition': If 'true', the scene changes immediately without fading.
"""
func pop_trail(skip_transition: bool = false) -> void:
	if skip_transition or not get_tree().get_nodes_in_group("scene_transition_covers"):
		Breadcrumb.pop_trail()
	else:
		_fade_out("pop_trail")


"""
Stays at the current level in the breadcrumb trail, but replaces the current navigation path after a scene transition.

Parameters:
	'path': The path to append to the breadcrumb trail. This is usually a scene path such as 'res://MyScene.tscn', but
		it can also include a '::foo' suffix for navigation paths which do not result in a scene change.

	'skip_transition': If 'true', the scene changes immediately without fading.
"""
func replace_trail(path: String, skip_transition: bool = false) -> void:
	if skip_transition or not get_tree().get_nodes_in_group("scene_transition_covers"):
		Breadcrumb.replace_trail(path)
	else:
		_fade_out("replace_trail", [path])


"""
Called when the 'fade out' visual transition ends, triggering a scene transition.
"""
func end_fade_out() -> void:
	if breadcrumb_method:
		Breadcrumb.callv(breadcrumb_method, breadcrumb_arg_array)


"""
Launches the 'fade in' visual transition.
"""
func fade_in() -> void:
	emit_signal("fade_in_started")


"""
Called when the 'fade in' visual transition ends, toggling a state variable.
"""
func end_fade_in() -> void:
	fading = false


"""
Launches the 'fade out' visual transition.
"""
func _fade_out(new_breadcrumb_method: String, new_breadcrumb_arg_array: Array = []) -> void:
	breadcrumb_method = new_breadcrumb_method
	breadcrumb_arg_array = new_breadcrumb_arg_array
	fading = true
	emit_signal("fade_out_started")
