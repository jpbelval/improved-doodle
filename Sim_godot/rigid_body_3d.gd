extends Node3D

var movementSpeed
var wheelAngleDeg

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	movementSpeed = 0.25
	wheelAngleDeg = -45.0
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	lineFollower()
	move(delta)
	pass
	
func move(delta: float) -> void:
	var angle = wheelAngleDeg * delta * movementSpeed
	rotate_y(deg_to_rad(angle))
	position.x += movementSpeed * delta * cos(deg_to_rad(rotation_degrees.y))
	position.z += movementSpeed * delta * -sin(deg_to_rad(rotation_degrees.y))
	pass
	
func lineFollower() -> void:
	if rotation_degrees.y > 45:
		wheelAngleDeg = -80
	else:
		wheelAngleDeg = 80
	pass
