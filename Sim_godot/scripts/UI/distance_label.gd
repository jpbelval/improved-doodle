extends Label


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var car_node = get_node("/root/Main/voiture")
	car_node.target_distance.connect(_on_target_distance)
	pass # Replace with function body.

func _on_target_distance(distance: float):
	if distance <= 1:
		text = "Distance: " + str(int(distance * 1.875 * 100)) + " mm"
	else:
		text = "Distance: NA"

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
