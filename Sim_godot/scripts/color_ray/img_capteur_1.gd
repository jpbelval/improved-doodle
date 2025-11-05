extends TextureRect


# Called when the node enters the scene tree for the first time.
func _ready():
	var raycast_node = get_node("/root/Main/voiture/ColorRay1")
	raycast_node.target_detected.connect(_on_target_detected)

func _on_target_detected(hit: bool):
	if hit == true:
		texture = load("res://assets/img/red-circle.png")
	else:
		texture = load("res://assets/img/gray-circle.png")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
