extends KinematicBody2D
"""
Something which blocks the player on the overworld, such as a tree or bush.

These objects can also be inspected (talked to) if the chat_path is set.
"""

# the size of the shadow cast by this object
export (float) var shadow_scale: float = 1.0 setget set_shadow_scale

# The path of the json chat resource for this object. If set, the object will have a thought bubble and the player will
# be able to inspect it.
export (String) var chat_path: String  setget set_chat_path

func _init() -> void:
	add_to_group("shadow_casters")


"""
When the shadow scale is set, we update the node's metadata so the shadow will be rendered correctly.
"""
func set_shadow_scale(new_shadow_scale: float) -> void:
	shadow_scale = new_shadow_scale
	set_meta("shadow_scale", shadow_scale)


"""
When the chat path is set, we update the node's groups and metadata to integrate the node into the chat framework.
"""
func set_chat_path(new_chat_path: String) -> void:
	chat_path = new_chat_path
	if new_chat_path:
		add_to_group("chattables")
		set_meta("chat_path", new_chat_path)
		set_meta("chat_bubble_type", ChatIcon.THOUGHT)
	else:
		if is_in_group("chattables"):
			remove_from_group("chattables")
		set_meta("chat_path", null)
		set_meta("chat_bubble_type", null)
