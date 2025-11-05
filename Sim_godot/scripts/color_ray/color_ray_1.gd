extends RayCast3D

signal target_detected(hit: bool)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	emit_signal("target_detected", is_colliding() && get_collider().name == "parcoursBody")
	pass
