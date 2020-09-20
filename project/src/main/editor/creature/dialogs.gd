extends Control
"""
Shows popup dialogs for the creature editor.
"""

export (NodePath) var creature_editor_path: NodePath

onready var _creature_editor: CreatureEditor = get_node(creature_editor_path)

func _show_import_export_not_supported_error() -> void:
	$Error.dialog_text = "Import/export isn't supported over the web. Sorry!"
	$Error.popup_centered()


func _on_ImportButton_pressed() -> void:
	if OS.has_feature("web"):
		_show_import_export_not_supported_error()
		return
	
	$Import.popup_centered()


"""
Imports the specified creature into the editor.
"""
func _on_ImportDialog_file_selected(path: String) -> void:
	var loaded_def := CreatureLoader.load_creature_def(path)
	if loaded_def:
		_creature_editor.set_center_creature_def(loaded_def)
		_creature_editor.mutate_all_creatures()
	else:
		$Error.dialog_text = "Error importing creature."
		$Error.popup_centered()


func _on_ExportJsonButton_pressed() -> void:
	if OS.has_feature("web"):
		_show_import_export_not_supported_error()
		return
	
	var exported_creature: Creature = _creature_editor.center_creature
	var sanitized_creature_name := StringUtils.sanitize_file_root(exported_creature.creature_short_name)
	$ExportJson.current_file = "%s.json" % sanitized_creature_name
	$ExportJson.popup_centered()


func _on_ExportPngButton_pressed() -> void:
	if OS.has_feature("web"):
		_show_import_export_not_supported_error()
		return
	
	var exported_creature: Creature = _creature_editor.center_creature
	var sanitized_creature_name := StringUtils.sanitize_file_root(exported_creature.creature_short_name)
	$ExportPng.current_file = "%s.png" % sanitized_creature_name
	$ExportPng.popup_centered()


"""
Exports the currently edited creature to a file.
"""
func _on_ExportJsonDialog_file_selected(path: String) -> void:
	var exported_creature: Creature = _creature_editor.center_creature
	var exported_json := exported_creature.creature_def.to_json_dict()
	FileUtils.write_file(path, Utils.print_json(exported_json))


func _on_ExportPngDialog_file_selected(path: String) -> void:
	print("68: file selected: %s" % path)
	var texture_rect: TextureRect = _creature_editor.center_creature.get_node("CreatureOutline/TextureRect")
	print("70: texture_rect=%s" % texture_rect) 
#	var image := texture_rect.texture.get_data()
	var image := get_viewport().get_texture().get_data()
	image.convert(Image.FORMAT_RGBA8)
	image.flip_y()
	image.save_png(path)


func _on_SaveButton_pressed() -> void:
	$SaveConfirmation.popup_centered()


"""
Updates the player character and writes it to their save file.
"""
func _on_SaveConfirmation_confirmed() -> void:
	PlayerData.creature_library.player_def = _creature_editor.center_creature.creature_def
	PlayerSave.save_player_data()
