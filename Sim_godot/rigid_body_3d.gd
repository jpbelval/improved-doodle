extends Node3D

@onready var color_ray1 = $ColorRay1
@onready var color_ray2 = $ColorRay2
@onready var color_ray3 = $ColorRay3
@onready var color_ray4 = $ColorRay4
@onready var color_ray5 = $ColorRay5

@onready var axeRotation = $AxeRotation

# Max constantes
const maxAngle = 38.0 # deg
const maxSpeed = 0.07 # m/s
const maxAcc = 0.12 # m/s2
const maxWheelSpeed = 70.0 # deg/s

# Speed constantes
const fullSpeed = maxSpeed
const midSpeed = 6*maxSpeed/8
const slowSpeed = 5*maxSpeed/8

# Angle constantes
const littleAngle = maxAngle/8
const midAngle = 5*maxAngle/8
const bigAngle = 6*maxAngle/8

# Variables
var movementSpeed
var wheelAngle

var wheelAngleTarget
var speedTarget

var state # State Machine
var lastDirection # 0 : Left, 1 : Right

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Private
	movementSpeed = 0.0 # m/s
	wheelAngle = 0.0 # deg
	state = 0

	# Public
	wheelAngleTarget = 0.0 # deg
	speedTarget = 0.2 # m/s
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	stateMachine(delta)
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
		if movementSpeed - maxAcc * delta < speedTarget:
			movementSpeed = speedTarget
		else:
			movementSpeed -= maxAcc * delta
	
	# Wheel angle update
	if wheelAngle < wheelAngleTarget:
		if wheelAngle + maxWheelSpeed * delta > wheelAngleTarget:
			wheelAngle = wheelAngleTarget
		else:
			wheelAngle += maxWheelSpeed * delta
	elif wheelAngle > wheelAngleTarget:
		if wheelAngle - maxWheelSpeed * delta < wheelAngleTarget:
			wheelAngle = wheelAngleTarget
		else:
			wheelAngle -= maxWheelSpeed * delta
	
	var L = global_position.distance_to(axeRotation.global_position)
	var rotationAngle = (movementSpeed * delta) * tan(deg_to_rad(wheelAngle)) / L
	var pivot_global = axeRotation.global_transform.origin

	var vec = global_transform.origin - pivot_global
	vec = vec.rotated(Vector3.UP, rotationAngle)
	global_transform = Transform3D(global_transform.basis.rotated(Vector3.UP, rotationAngle), pivot_global + vec)

	translate(Vector3(1, 0, 0) * movementSpeed * cos(deg_to_rad(wheelAngle)) * delta)
	pass
	
func stateMachine(delta: float) -> void:
	match state:
		0: # Follow Line
			lineFollower()
		2: # Obstacle detected
			var i = 0
		3: # Go arround
			var i = 0
		4: # Find line
			var i = 0
		5: # Allign
			var i = 0
	pass
	
func onLine() -> Array:
	var detection = [0, 0, 0, 0, 0]
	if color_ray1.is_colliding():
		if color_ray1.get_collider().name == "parcoursBody":
			detection[0] = 1
	if color_ray2.is_colliding():
		if color_ray2.get_collider().name == "parcoursBody":
			detection[1] = 1
	if color_ray3.is_colliding():
		if color_ray3.get_collider().name == "parcoursBody":
			detection[2] = 1
	if color_ray4.is_colliding():
		if color_ray4.get_collider().name == "parcoursBody":
			detection[3] = 1
	if color_ray5.is_colliding():
		if color_ray5.get_collider().name == "parcoursBody":
			detection[4] = 1
	return detection
	
func lineFollower() -> void:
	# [0, 0, 1, 0, 0] -> target
	# [0, 0, 0, 1, 0] -> target
	var detection = onLine()
	
	# Basic case
	if detection == [0, 0, 1, 0, 0]:
		wheelAngleTarget = littleAngle
		speedTarget = fullSpeed
		lastDirection = 0
	elif detection == [0, 0, 0, 1, 0]:
		wheelAngleTarget = -littleAngle
		speedTarget = fullSpeed
		lastDirection = 1
	
	# Curves
	elif detection == [0, 0, 0, 0, 1]:
		wheelAngleTarget = -bigAngle
		speedTarget = midSpeed
		lastDirection = 1
	elif detection == [0, 1, 0, 0, 0] || detection == [0, 1, 1, 0, 0]:
		wheelAngleTarget = bigAngle
		speedTarget = midSpeed
		lastDirection = 0
		
	# Panic mode
	elif detection == [1, 0, 0, 0, 0] || detection == [1, 1, 0, 0, 0]:
		wheelAngleTarget = bigAngle
		speedTarget = slowSpeed
		lastDirection = 0
	else:
		if lastDirection:
			wheelAngleTarget = -bigAngle
		else:
			wheelAngleTarget = bigAngle
		speedTarget = slowSpeed
	pass
