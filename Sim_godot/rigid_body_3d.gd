extends Node3D

var movementSpeed
var wheelAngleDeg

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	movementSpeed = 0.5
	wheelAngleDeg = -10.0
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	move(delta)
	pass
	
func move(delta: float) -> void:
	var angle = wheelAngleDeg * delta * movementSpeed
	rotate_y(deg_to_rad(angle))
	position.x += movementSpeed * delta * cos(deg_to_rad(rotation_degrees.y))
	position.z += movementSpeed * delta * -sin(deg_to_rad(rotation_degrees.y))
	pass

func turn() -> void:
	pass
	
