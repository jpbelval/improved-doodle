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
const reverseAngle = maxAngle/12
const littleAngle = maxAngle/8
const midAngle = 5*maxAngle/8
const bigAngle = 6*maxAngle/8

# Obstacle avoidance constants
const obstacleDetectionDistance = 0.3 # meters - trigger avoidance if obstacle within this distance

#Signal
signal target_distance(distance: float)

# Variables
var movementSpeed
var wheelAngle

var wheelAngleTarget
var speedTarget

var state # State Machine
var lastDirection # 0 : Left, 1 : Right

# Avoidance state variables
var avoidance_timer = 0.0
var avoidance_direction = 0  # 0 = left, 1 = right - which way to dodge

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Private
	movementSpeed = 0.0 # m/s
	wheelAngle = 0.0 # deg
	state = 0
	
	# Public
	wheelAngleTarget = 0.0 # deg
	speedTarget = 0.2 # m/s
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	stateMachine(delta)
	move(delta)
	
	
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
	
	
func stateMachine(delta: float) -> void:
	match state:
		0: # Follow Line
			lineFollower()
			if distance_sensor.is_colliding():
				var distance = global_position.distance_to(distance_sensor.get_collision_point())
				emit_signal("target_distance", distance)
				if distance < obstacleDetectionDistance:
					state = 2 
					avoidance_timer = 0.0
					if wheelAngle > 0:
						avoidance_direction = 0
					else:
						avoidance_direction = 1
			else:
				emit_signal("target_distance", 2)
		2: # Reverse maneuver
			reversing()
			avoidance_timer += delta

			if avoidance_timer > 6.0:
				state = 3
				avoidance_timer = 0
				speedTarget = fullSpeed
				setWheelAngle(avoidance_direction, bigAngle)


		3: # Dodge obstacle
			avoidance_timer += delta
			if distance_sensor.is_colliding():
				var distance = global_position.distance_to(distance_sensor.get_collision_point())
				emit_signal("target_distance", distance)
				if distance < obstacleDetectionDistance:
					state = 2
			
			if avoidance_timer > 1.5:
				wheelAngleTarget = 0.0 
			if avoidance_timer > 6.0:
				state = 4
				avoidance_timer = 0.0
				setInvWheelAngle(avoidance_direction, midAngle)
				
		4: # Find line again
			avoidance_timer += delta
			if distance_sensor.is_colliding():
				var distance = global_position.distance_to(distance_sensor.get_collision_point())
				emit_signal("target_distance", distance)
				if distance < obstacleDetectionDistance:
					state = 2
			var detection = onLine()
			if detection != [0, 0, 0, 0, 0]:
				state = 0
			if avoidance_timer > 1.5:
				wheelAngleTarget = 0.0 
				state = 6
				avoidance_timer = 0.0
			
		5:
			wheelAngleTarget = 0.0
			speedTarget = 0.0
		6:
			avoidance_timer += delta
			speedTarget = midSpeed
			if avoidance_timer > 2.5:
				setInvWheelAngle(avoidance_direction, midAngle)
			if distance_sensor.is_colliding():
				var distance = global_position.distance_to(distance_sensor.get_collision_point())
				emit_signal("target_distance", distance)
				if distance < obstacleDetectionDistance:
					state = 2
			var detection = onLine()
			if detection != [0, 0, 0, 0, 0]:
				state = 0

	
func onLine() -> Array:
	var detection = [0, 0, 0, 0, 0]
	if color_ray1.is_colliding():
		if color_ray1.get_collider().name == "parcoursBody" || color_ray1.get_collider().name == "parcoursBody" :
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
	
func reversing() -> void:
	var detection = onLine()
		# Basic case
	if detection == [0, 0, 1, 0, 0]:
		wheelAngleTarget = -reverseAngle
		lastDirection = 1
	elif detection == [0, 0, 0, 1, 0]:
		wheelAngleTarget = reverseAngle
		lastDirection = 0
	
	# Curves
	elif detection == [0, 0, 0, 0, 1]:
		wheelAngleTarget = reverseAngle
		lastDirection = 0
	elif detection == [0, 1, 0, 0, 0] || detection == [0, 1, 1, 0, 0]:
		wheelAngleTarget = -reverseAngle
		lastDirection = 1
		
	# Panic mode
	elif detection == [1, 0, 0, 0, 0] || detection == [1, 1, 0, 0, 0]:
		wheelAngleTarget = -reverseAngle
		lastDirection = 1
	elif detection == [1, 1, 1, 1, 1]:
		state = 5
		speedTarget = 0.0
		wheelAngleTarget = 0.0
	else:
		if lastDirection:
			wheelAngleTarget = -reverseAngle
		else:
			wheelAngleTarget = reverseAngle
		
	speedTarget = -slowSpeed
	

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
	elif detection == [1, 1, 1, 1, 1]:
		state = 5
		speedTarget = 0.0
		wheelAngleTarget = 0.0
	else:
		if lastDirection:
			wheelAngleTarget = -bigAngle
		else:
			wheelAngleTarget = bigAngle
		speedTarget = slowSpeed
		
	


func setWheelAngle(direction: int, angle: float)->void:
	if direction:
		wheelAngleTarget = -angle
	else:
		wheelAngleTarget = angle


func setInvWheelAngle(direction: int, angle: float)->void:
	if direction:
		wheelAngleTarget = angle
	else:
		wheelAngleTarget = -angle
