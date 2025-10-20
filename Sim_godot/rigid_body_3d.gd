extends Node3D

var movementSpeed = 0.3

var angle = 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	angle = rotation_degrees.y
	position.x += movementSpeed * delta * cos(deg_to_rad(angle))
	position.z += movementSpeed * delta * -sin(deg_to_rad(angle))
	rotate_y(deg_to_rad(0.4))
	pass


func lineFolower() -> void:
	var i = 0
	pass
