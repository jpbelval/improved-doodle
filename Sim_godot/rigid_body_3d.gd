extends Node3D

const maxAcc = 0.2 # m/s2
const maxDec = -0.2 # m/s2
const maxTurn = 45.0 # deg/s

var movementSpeed
var wheelAngle

var wheelAngleTarget
var speedTarget

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Private
	movementSpeed = 0.0 # m/s
	wheelAngle = 0.0 # deg

	# Public
	wheelAngleTarget = 0.0 # deg
	speedTarget = 0.1 # m/s
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	lineFollower()
	move(delta)
	pass
	
func move(delta: float) -> void:
	# Speed update
	if movementSpeed < speedTarget:
		if movementSpeed + maxAcc * delta > speedTarget:
			movementSpeed = speedTarget
		else:
			movementSpeed += maxAcc * delta
	elif movementSpeed > speedTarget:
		if movementSpeed + maxDec * delta < speedTarget:
			movementSpeed = speedTarget
		else:
			movementSpeed += maxDec * delta
	
	# Wheel angle update
	if wheelAngle < wheelAngleTarget:
		if wheelAngle + maxTurn * delta > wheelAngleTarget:
			wheelAngle = wheelAngleTarget
		else:
			wheelAngle += maxTurn * delta
	elif wheelAngle > wheelAngleTarget:
		if wheelAngle - maxTurn * delta < wheelAngleTarget:
			wheelAngle = wheelAngleTarget
		else:
			wheelAngle -= maxTurn * delta
	
	# Turn
	rotate_y(deg_to_rad(wheelAngle * delta * movementSpeed))
	
	# Move
	position.x += movementSpeed * delta * cos(deg_to_rad(rotation_degrees.y))
	position.z += movementSpeed * delta * -sin(deg_to_rad(rotation_degrees.y))
	pass
	
func lineFollower() -> void:
	print('movement')
	print([movementSpeed, speedTarget])
	print('turnAngle')
	print([wheelAngle, wheelAngleTarget])
	if movementSpeed != speedTarget:
		wheelAngleTarget = 150
		speedTarget = 0.34
	else:
		wheelAngleTarget = 0
	pass
