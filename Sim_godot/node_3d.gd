extends Node

var ws := WebSocketPeer.new()
var connected := false

# Max constantes
const maxAngle = 45.0 # deg
const maxSpeed = 35 # %/s
const maxAcc = 45 # %/s2
const maxWheelSpeed = 120.0 # deg/s

# Speed constantes
const fullSpeed = maxSpeed
const midSpeed = maxSpeed
const slowSpeed = maxSpeed
#const midSpeed = 6*maxSpeed/8
#const slowSpeed = 5*maxSpeed/8

# Angle constantes
const reverseAngle = maxAngle/12
const littleAngle = 3
const midAngle = 10
const bigAngle = 30
const panicAngle = maxAngle

# Obstacle avoidance constants
const obstacleDetectionDistance = 10 # meters - trigger avoidance if obstacle within this distance

#Signal
signal target_distance(distance: float)

# Variables
var movementSpeed
var wheelAngle

var wheelAngleTarget
var speedTarget

var state # State Machine
var lastDirection # 0 : Left, 1 : Right
var lastDetection = [0, 0, 0, 0, 0]

# Avoidance state variables
var avoidance_timer = 0.0
var avoidance_direction = 0  # 0 = left, 1 = right - which way to dodge

var picar_data
var reference = [65, 55, 47, 85, 75]

func _ready():
	print("Connecting…")
	ws.connect_to_url("ws://172.20.10.10:8765")  # Adresse du PiCar
	
	# Private
	movementSpeed = 0.0 # m/s
	wheelAngle = 0.0 # deg
	state = 0
	
	# Public
	wheelAngleTarget = 0.0 # deg
	speedTarget = 0.2 # m/s

func _process(delta):
	ws.poll()

	var stateWB = ws.get_ready_state()

	if stateWB == WebSocketPeer.STATE_OPEN and not connected:
		connected = true
		print("CONNECTED to server!")
	elif stateWB == WebSocketPeer.STATE_CLOSED:
		if connected:
			print("Connection closed.")
		connected = false
		
		# Lire les messages
	while ws.get_available_packet_count() > 0:
		picar_data = (ws.get_packet().get_string_from_utf8())
		picar_data = JSON.parse_string(picar_data)
		#print("Received: %s" % picar_data)
		picar_data["Raw"] = rawToDigital(picar_data["Raw"])
		#print("Received: %s" % picar_data)
	
	# update
	if connected and picar_data != null:
		stateMachine(delta)
		move(delta)

		#var data = {0:0.0, 1:100};
		var data = {0:movementSpeed, 1:-wheelAngleTarget+90};
		#print(state)
		#print(picar_data["Raw"])
		#print(JSON.stringify(data, "\t"))
		ws.send_text(JSON.stringify(data, "\t"))
		
	#await get_tree().create_timer(0.0005).timeout 

func rawToDigital(rawData: Array) -> Array:
	var returns = [0, 0, 0, 0, 0]

	for i in range(5):
		var high = int(rawData[2 * i])
		var low  = int(rawData[2 * i + 1])
		var value = (high << 8) | low
		
		if value < reference[i]:
			returns[i] = 1
		else:
			returns[i] = 0

	return returns

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

func stateMachine(delta: float) -> void:
	match state:
		0: # Follow Line
			lineFollower()
			
			if picar_data["UltraValue"] != null:
				if picar_data["UltraValue"] < obstacleDetectionDistance:
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
			if picar_data["UltraValue"] != null:
				if picar_data["UltraValue"] < obstacleDetectionDistance:
					state = 2
			
			if avoidance_timer > 1.5:
				wheelAngleTarget = 0.0 
			if avoidance_timer > 6.0:
				state = 4
				avoidance_timer = 0.0
				setWheelAngle(avoidance_direction, -midAngle)
				
		4: # Find line again
			avoidance_timer += delta
			if picar_data["UltraValue"] != null:
				if picar_data["UltraValue"] < obstacleDetectionDistance:
					state = 2
			var detection = picar_data["Raw"]
			if detection != [0, 0, 0, 0, 0]:
				state = 0
			if avoidance_timer > 1.25:
				wheelAngleTarget = 0.0 
				state = 6
				avoidance_timer = 0.0
			
		5:
			wheelAngleTarget = 0.0
			speedTarget = 0.0
		6:
			avoidance_timer += delta
			speedTarget = midSpeed
			if avoidance_timer > 5:
				setWheelAngle(avoidance_direction, -midAngle)
			if picar_data["UltraValue"] != null:
				if picar_data["UltraValue"] < obstacleDetectionDistance:
					state = 2
			var detection = picar_data["Raw"]
			if detection != [0, 0, 0, 0, 0]:
				state = 0

	
func reversing() -> void:
	var detection = picar_data["Raw"]
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
	var detection = picar_data["Raw"]
	speedTarget = maxSpeed

	if detection == [0, 0, 1, 0, 0]:
		wheelAngleTarget = 0.0
	elif detection == [0, 1, 1, 0, 0] || detection  == [0, 0, 1, 1, 0]:
		if detection[1]:
			wheelAngleTarget = littleAngle
		else:
			wheelAngleTarget = -littleAngle
	elif detection == [0, 1, 0, 0, 0] || detection  == [0, 0, 0, 1, 0]:
		if detection[1]:
			wheelAngleTarget = midAngle
		else:
			wheelAngleTarget = -midAngle
	elif detection == [1, 1, 0, 0, 0] || detection  == [0, 0, 0, 1, 1]:
		if detection[1]:
			wheelAngleTarget = bigAngle
		else:
			wheelAngleTarget = -bigAngle
	elif detection == [1, 0, 0, 0, 0] || detection  == [0, 0, 0, 0, 1]:
		if detection[0]:
			wheelAngle = panicAngle
		else:
			wheelAngle = -panicAngle
	else:
		setWheelAngle(lastDirection, -panicAngle)

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
