extends Control

@onready var profile_label: Label = $Center/Panel/Margin/VBox/ProfileLabel
@onready var player_label: Label = $Center/Panel/Margin/VBox/PlayerLabel
@onready var prompt_label: Label = $Center/Panel/Margin/VBox/PromptLabel
@onready var progress_label: Label = $Center/Panel/Margin/VBox/ProgressLabel
@onready var progress_bar: ProgressBar = $Center/Panel/Margin/VBox/ProgressBar
@onready var feedback_label: Label = $Center/Panel/Margin/VBox/FeedbackLabel
@onready var hint_label: Label = $Center/Panel/Margin/VBox/HintLabel

const DIRECTIONS := ["up", "down", "left", "right"]

var feedback_time := 0.0

func _ready() -> void:
	if Communicator.has_signal("config_prompt"):
		Communicator.config_prompt.connect(_on_config_prompt)
	if Communicator.has_signal("config_captured"):
		Communicator.config_captured.connect(_on_config_captured)
	if Communicator.has_signal("config_done"):
		Communicator.config_done.connect(_on_config_done)
	feedback_label.text = ""
	hint_label.text = "Tap a button or push a direction to set it      •      Hold a button to skip      •      Hold two buttons to cancel"

func _process(delta: float) -> void:
	if feedback_time > 0.0:
		feedback_time -= delta
		if feedback_time <= 0.0:
			feedback_label.text = ""

func _on_config_prompt(data: Dictionary) -> void:
	profile_label.text = "Configuring: " + String(data.get("profileName", "Controller"))

	var player := int(data.get("player", 1))
	var total_players := int(data.get("totalPlayers", 1))
	var joypad := String(data.get("joypadName", ""))
	var player_text := "Player %d of %d" % [player, total_players]
	if joypad != "":
		player_text += "   —   " + joypad
	player_label.text = player_text

	var input := String(data.get("input", ""))
	var label := String(data.get("label", input)).to_upper()
	if input in DIRECTIONS:
		prompt_label.text = "Push the joystick\n" + label
	else:
		prompt_label.text = "Press\n" + label

	var index := int(data.get("index", 0))
	var total := int(data.get("total", 1))
	progress_label.text = "%d / %d" % [index + 1, total]
	progress_bar.max_value = total
	progress_bar.value = index

func _on_config_captured(data: Dictionary) -> void:
	if bool(data.get("skipped", false)):
		feedback_label.modulate = Color(0.7, 0.7, 0.7, 1)
		feedback_label.text = "Skipped"
	else:
		feedback_label.modulate = Color(0.35, 1.0, 0.45, 1)
		var btn := String(data.get("btn", "nul"))
		var axis := String(data.get("axis", "nul"))
		var detail := ("button %s" % btn) if btn != "nul" else ("axis %s" % axis)
		feedback_label.text = "Mapped to " + detail
	feedback_time = 1.2

func _on_config_done(data: Dictionary) -> void:
	if bool(data.get("cancelled", false)):
		prompt_label.text = "Cancelled"
	elif data.get("error", null) != null:
		prompt_label.text = "Error"
		feedback_label.modulate = Color(1.0, 0.4, 0.4, 1)
		feedback_label.text = String(data.get("error", ""))
		feedback_time = 3.0
	else:
		prompt_label.text = "All done!"
	player_label.text = ""
	progress_label.text = ""
	hint_label.text = ""

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			Communicator.config_skip()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			Communicator.config_cancel()
			get_viewport().set_input_as_handled()
