extends Control


func _on_boton_jugar_pressed():
	get_tree().change_scene_to_file("res://scenes/limbo.tscn")

func _on_boton_salir_pressed():
	get_tree().quit()
