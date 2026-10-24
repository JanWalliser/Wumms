extends Control

# PauseMenu - In-game pause screen

@onready var resume_btn: Button = $CenterContainer/Panel/VBoxContainer/ResumeButton
@onready var abandon_btn: Button = $CenterContainer/Panel/VBoxContainer/AbandonButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	hide()
	resume_btn.pressed.connect(_on_resume_pressed)
	abandon_btn.pressed.connect(_on_abandon_pressed)

func on_shown() -> void:
	if resume_btn:
		resume_btn.grab_focus()

func _on_resume_pressed() -> void:
	AudioManager.play_sfx("coin")
	GameManager.set_state(GameManager.GameState.GAMEPLAY)

func _on_abandon_pressed() -> void:
	AudioManager.play_sfx("coin")
	if NetworkManager.is_client():
		NetworkManager.leave()
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
		return
	GameManager.end_run(false)
	GameManager.return_to_menu()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
