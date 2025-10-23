extends Node3D

@onready var color_ray1 = $ColorRay1
@onready var color_ray2 = $ColorRay2
@onready var color_ray3 = $ColorRay3
@onready var color_ray4 = $ColorRay4
@onready var color_ray5 = $ColorRay5

@onready var axeRotation = $AxeRotation

# Max constantes
const maxAcc = 0.3 # m/s2
const maxDec = -0.3 # m/s2
const maxTurn = 150.0 # deg/s
const maxAngle = 85.0 # deg

# Speed constantes
const fullSpeed = 0.25
const midSpeed = 0.15
const slowSpeed = 0.1

# Angle constantes
const littleAngle = 2*maxAngle/5
const midAngle = 5*maxAngle/6
const bigAngle = maxAngle

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
	var angle = deg_to_rad(wheelAngle * delta * movementSpeed) 
	var pivot_global = axeRotation.global_transform.origin

	if abs(angle) > 0.0:
		var vec = global_transform.origin - pivot_global
		vec = vec.rotated(Vector3.UP, angle)
		var new_origin = pivot_global + vec
		var new_basis = global_transform.basis.rotated(Vector3.UP, angle)
		global_transform = Transform3D(new_basis, new_origin)
	
	# Move
	position.x += movementSpeed * delta * cos(deg_to_rad(rotation_degrees.y))
	position.z += movementSpeed * delta * -sin(deg_to_rad(rotation_degrees.y))
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
	# [0, 0, 1, 1, 1] -> target
	# [0, 0, 0, 1, 1] -> target
	var detection = onLine()
	
	if detection == [0, 0, 1, 1, 1]:
		wheelAngleTarget = littleAngle
		speedTarget = fullSpeed
		lastDirection = 0
	elif detection == [0, 0, 0, 1, 1]:
		wheelAngleTarget = -littleAngle
		speedTarget = fullSpeed
		lastDirection = 1
		
	elif detection == [0, 0, 0, 0, 1]:
		wheelAngleTarget = -bigAngle
		speedTarget = midSpeed
		lastDirection = 1
	elif detection == [0, 1, 1, 1, 1] || detection == [1, 1, 1, 1, 1]:
		wheelAngleTarget = bigAngle
		speedTarget = midSpeed
		lastDirection = 0
	pass
