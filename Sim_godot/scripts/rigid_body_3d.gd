extends Node3D

@onready var color_ray1 = $ColorRay1
@onready var color_ray2 = $ColorRay2
@onready var color_ray3 = $ColorRay3

# Max constantes
const maxAcc = 0.3 # m/s2
const maxDec = -0.3 # m/s2
const maxTurn = 150.0 # deg/s
const maxAngle = 90.0 # deg

# Speed constantes
const fullSpeed = 0.15
const slowSpeed = 0.15
const panicSpeed = 0.1

# Angle constantes
const straightAngle = 32
const curveAngle = 80
const panicAngle = maxAngle

# Variables
var movementSpeed
var wheelAngle

var wheelAngleTarget
var speedTarget

var state # State Machine
var lastDirection # 0 : Left, 1 : Right

var is_running
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Private
	movementSpeed = 0.0 # m/s
	wheelAngle = 0.0 # deg
	state = 0
	is_running = false
	
	# Public
	wheelAngleTarget = 0.0 # deg
	speedTarget = 0.2 # m/s
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_pressed("Start_engine"):
		is_running = true
		
	if is_running:
		lineFollower(delta)
		move(delta)
	
	
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
	#position.x += movementSpeed * delta * cos(deg_to_rad(rotation_degrees.y))
	#position.z += movementSpeed * delta * -sin(deg_to_rad(rotation_degrees.y))
	var forward = Vector3(1, 0, 0)  # En Godot, l’axe Z négatif est l’avant
	var local_movement = forward * movementSpeed * delta

	# Déplacer le véhicule selon sa direction actuelle
	translate(local_movement)
	pass
	
func lineFollower(delta: float) -> void:
	match state:
		0: # Follow Line
			var detection = onLine()
			print(detection)
			# The line as to be on the right side of the car
			# [1, 1, 1] -> Go little left and full speed
			if detection[0] && detection[1] && detection[2]:
				wheelAngleTarget = -straightAngle
				speedTarget = fullSpeed
				lastDirection = 0
			# [0, 0, 0] -> Depend on last direction and slow down
			elif !detection[0] && !detection[1] && !detection[2]:
				speedTarget = panicSpeed
			# [0, 0, 1] -> Go right and slow down
			elif !detection[0] && !detection[1] && detection[2]:
				wheelAngleTarget = -curveAngle
				speedTarget = slowSpeed
				lastDirection = 1
			# [0, 1, 0] -> Go little left and full speed
			elif !detection[0] && detection[1] && !detection[2]:
				wheelAngleTarget = straightAngle
				speedTarget = fullSpeed
				lastDirection = 0
			# [0, 1, 1] -> Go little right and full speed
			elif !detection[0] && detection[1] && detection[2]:
				wheelAngleTarget = -straightAngle
				speedTarget = fullSpeed
				lastDirection = 1
			# [1, 0, 0] -> Go left and slow down
			elif detection[0] && !detection[1] && !detection[2]:
				wheelAngleTarget = curveAngle
				speedTarget = slowSpeed
				lastDirection = 0
			# [1, 1, 0] -> Go little left and full speed
			elif detection[0] && detection[1] && !detection[2]:
				wheelAngleTarget = straightAngle
				speedTarget = fullSpeed
				lastDirection = 0
		
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
	var detection = [0, 0, 0]
	if color_ray1.is_colliding():
		if color_ray1.get_collider().name == "parcoursBody":
			detection[0] = 1
	if color_ray2.is_colliding():
		if color_ray2.get_collider().name == "parcoursBody":
			detection[1] = 1
	if color_ray3.is_colliding():
		if color_ray3.get_collider().name == "parcoursBody":
			detection[2] = 1
	return detection
