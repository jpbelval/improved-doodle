extends Node3D

@onready var color_ray1 = $ColorRay1
@onready var color_ray2 = $ColorRay2
@onready var color_ray3 = $ColorRay3
@onready var color_ray4 = $ColorRay4
@onready var color_ray5 = $ColorRay5
@onready var distance_sensor = $DistanceSensor

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

# Obstacle avoidance constants
const obstacleDetectionDistance = 0.3 # meters - trigger avoidance if obstacle within this distance

# Variables
var movementSpeed
var wheelAngle

var wheelAngleTarget
var speedTarget

var state # State Machine
var lastDirection # 0 : Left, 1 : Right

var reverse

# Avoidance state variables
var avoidance_timer = 0.0
var avoidance_direction = 0  # 0 = left, 1 = right - which way to dodge

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Private
	movementSpeed = 0.0 # m/s
	wheelAngle = 0.0 # deg
	state = 0
	reverse = false
	
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
	var wheel_direction = -1 if reverse else 1	
	
	translate(Vector3(wheel_direction, 0, 0) * movementSpeed * cos(deg_to_rad(wheelAngle)) * delta)
	pass
	
func stateMachine(delta: float) -> void:
	match state:
		0: # Follow Line
			lineFollower()
			if distance_sensor.is_colliding():
				var distance = global_position.distance_to(distance_sensor.get_collision_point())
				if distance < obstacleDetectionDistance:
					state = 2 
					avoidance_timer = 0.0
					if wheelAngle > 0:
						avoidance_direction = 0
					else:
						avoidance_direction = 1
		2: # Avoiding maneuver
			avoidance_timer += delta
			speedTarget = midSpeed

			if avoidance_direction == 0:
				wheelAngleTarget = bigAngle
			else:
				wheelAngleTarget = -bigAngle
			

			if avoidance_timer > 2.0: 
				state = 3
				avoidance_timer = 0.0

		3: # Dodge obstacle
			avoidance_timer += delta
			wheelAngleTarget = 0
			speedTarget = maxSpeed
			
			if avoidance_timer > 3.0:
				state = 4
				avoidance_timer = 0.0
		4: # Find line again
			avoidance_timer += delta
			speedTarget = midSpeed
			# Turn back toward line (opposite direction from avoidance)
			if avoidance_direction == 0:
				wheelAngleTarget = -bigAngle 
			else:
				wheelAngleTarget = bigAngle

			var detection = onLine()
			if detection != [0, 0, 0, 0, 0]:
				state = 0
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
