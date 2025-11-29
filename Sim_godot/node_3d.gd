extends Node

# Max constantes
const maxAngle = 45.0 # deg
const maxSpeed = 25 # %/s
const maxAcc = 45 # %/s2
const maxWheelSpeed = 120.0 # deg/s

# Speed constantes
const fullSpeed = 8.0*maxSpeed/8.0
const midSpeed = 7.0*maxSpeed/8.0
const slowSpeed = 6.0*maxSpeed/8.0

# Angle constantes
const reverseAngle = 3.75*maxAngle/45.0
const littleAngle = 3.0*maxAngle/45.0
const midAngle = 10.0*maxAngle/45.0
const mediumLargeAngle = 23.0*maxAngle/45.0
const bigAngle = 30.0*maxAngle/45.0
const panicAngle = 45.0*maxAngle/45.0

# reference for the line module
const reference = [66.5, 67.0, 56.5, 79.0, 66.0]

# Obstacle avoidance constants
const obstacleDetectionDistance = 20 # cm - trigger avoidance if obstacle within this distance

# Movement Variables
var movementSpeed
var wheelAngleTarget
var speedTarget
var lastDirection # 0 : Left, 1 : Right

# state variable
var state

# Avoidance state variables
var avoidance_timer
var avoidance_direction  # 0 = left, 1 = right - which way to dodge

# picar connection and data
var picar_data
var ws
var connected

func _ready():
	print("Connecting…")
	ws.connect_to_url("ws://10.29.203.165:8765")  # Adresse du PiCar
	
	# Private
	movementSpeed = 0.0 # m/s
	state = -2
	ws = WebSocketPeer.new()
	
	# protected
	connected = false
	
	# Public
	wheelAngleTarget = 0.0 # deg
	speedTarget = 0.2 # m/s
	avoidance_timer = 0.0
	avoidance_direction = 0

func _process(delta):
	# PiCar communication
	ws.poll()
	readPiCar()
	
	# logic
	stateMachine(delta)
	move(delta)
	
	# Picar Communication
	sendPiCar({0:movementSpeed, 1:-wheelAngleTarget+100})

# Transform raw data from the PiCar to digital data
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

func fastStateMachine():
	match state:
		-2: # Connection state
			if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
				connected = true
				print("CONNECTED to server!")
				state = -1
			speedTarget = 0.0
			wheelAngleTarget = 0.0
		-1: # Start state
			var i = 0
		0: # Line follower state
			var i = 0

func stateMachine(delta: float) -> void:
	match state:
		-1:
			if picar_data["Raw"] == [1, 1, 1, 1, 1]:
				speedTarget = maxSpeed
			var sum = picar_data["Raw"][0] + picar_data["Raw"][1] + picar_data["Raw"][2] + picar_data["Raw"][3] + picar_data["Raw"][4]
			if sum < 3:
				state = 0
			
		0: # Follow Line
			lineFollower()
			avoidance_timer += delta
			if picar_data["UltraValue"] != null:
				if picar_data["UltraValue"] < obstacleDetectionDistance:
					state = 2 
					avoidance_timer = 0.0
					if wheelAngleTarget > 0:
						avoidance_direction = 0
					else:
						avoidance_direction = 1
			var detection = picar_data["Raw"]
			if avoidance_timer > 2 && detection == [0, 0, 0, 0, 0]:
				state = 8
				avoidance_timer = 0.0
				if wheelAngleTarget > 0:
					avoidance_direction = 0
				else:
					avoidance_direction = 1
			
		2: # Reverse maneuver
			avoidance_timer += delta
			if avoidance_timer > 1:
				reversing()
			else:
				speedTarget = 0
			
			if avoidance_timer > 20.0 || picar_data["UltraValue"] > 23:
				state = 5
				avoidance_timer = 0
				wheelAngleTarget = 0.0
				
		3: # Dodge obstacle
			speedTarget = maxSpeed
			avoidance_timer += delta
			if avoidance_timer > 1:
				state = 4
				avoidance_timer = 0.0
			if picar_data["UltraValue"] != null:
				if picar_data["UltraValue"] < obstacleDetectionDistance:
					state = 2
				
		4: # dodge obstacle
			avoidance_timer += delta
			if picar_data["UltraValue"] != null && avoidance_timer > 5.0:
				if picar_data["UltraValue"] < obstacleDetectionDistance:
					state = 2
			
			var detection = picar_data["Raw"]
			if detection == [0, 0, 0, 0, 0] && avoidance_timer > 0.9 && avoidance_timer < 1.5 :
				wheelAngleTarget = 0.0
			elif detection == [0, 0, 0, 0, 0] && avoidance_timer > 1.75 && avoidance_timer < 2.5:
				setWheelAngle(avoidance_direction, panicAngle)
				if detection != [0, 0, 0, 0, 0]:
					lineFollower()
					state = 0
					avoidance_timer = 0.0
			elif detection == [0, 0, 0, 0, 0] && avoidance_timer > 3:
				setWheelAngle(avoidance_direction, mediumLargeAngle)
				state = 6
				avoidance_timer = 0.0
			
		5:
			avoidance_timer += delta
			if avoidance_timer < 1:
				wheelAngleTarget = 0.0
				speedTarget = 0.0
			elif avoidance_timer > 1 && avoidance_timer < 1.5:
				setWheelAngle(avoidance_direction, -mediumLargeAngle)
			elif avoidance_timer > 1.5:
				state = 3
				avoidance_timer = 0.0
			
		6:
			if picar_data["UltraValue"] != null:
				if picar_data["UltraValue"] < obstacleDetectionDistance:
					state = 2
			var detection = picar_data["Raw"]
			if detection != [0, 0, 0, 0, 0]:
				state = 0
		7:
			speedTarget = 0.0
			wheelAngleTarget = 0.0
		8: 
			speedTarget = -slowSpeed
			setWheelAngle(avoidance_direction, -panicAngle)
			var detection = picar_data["Raw"]
			if detection != [0, 0, 0, 0, 0]:
				state = 0
				avoidance_timer = 0.0

	
func reversing() -> void:
	var detection = picar_data["Raw"]
		# Basic case
	if detection == [0, 0, 1, 0, 0]:
		wheelAngleTarget = 0.0
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
		if detection[1] == 1:
			wheelAngleTarget = littleAngle
		else:
			wheelAngleTarget = -littleAngle
	elif detection == [0, 1, 0, 0, 0] || detection  == [0, 0, 0, 1, 0]:
		if detection[1] == 1:
			wheelAngleTarget = midAngle
		else:
			wheelAngleTarget = -midAngle
	elif detection == [1, 1, 0, 0, 0] || detection  == [0, 0, 0, 1, 1]:
		if detection[1] == 1:
			wheelAngleTarget = bigAngle
		else:
			wheelAngleTarget = -bigAngle
	elif detection == [1, 0, 0, 0, 0] || detection  == [0, 0, 0, 0, 1]:
		if detection[0] == 1:
			wheelAngleTarget = panicAngle
		else:
			wheelAngleTarget = -panicAngle
	elif detection == [1, 1, 1, 1, 1]:
		wheelAngleTarget = 0.0
		state = 7
		speedTarget = 0.0	

func setWheelAngle(direction: int, angle: float)->void:
	if direction:
		wheelAngleTarget = -angle
	else:
		wheelAngleTarget = angle
		
func readPiCar(printData: bool = false) -> void:
	while ws.get_available_packet_count() > 0:
		picar_data = (ws.get_packet().get_string_from_utf8())
		picar_data = JSON.parse_string(picar_data)
		picar_data["Raw"] = rawToDigital(picar_data["Raw"])
	if printData:
		print(picar_data)
		
func sendPiCar(data: Dictionary, printData: bool = false) -> void:
	ws.send_text(JSON.stringify(data, "\t"))
	if printData:
		print(JSON.stringify(data, "\t"))
