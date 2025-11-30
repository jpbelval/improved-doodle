extends Node

# Max constantes
const maxAngle = 45.0 # deg
const maxSpeed = 35 # %/s
const maxAcc = 35 # %/s2
const maxWheelSpeed = 140.0 # deg/s

# Speed constantes
const fullSpeed = maxSpeed
const midSpeed = 7.0*maxSpeed/8.0
const slowSpeed = 6.0*maxSpeed/8.0

# Angle constantes
const reverseAngle = 3.75*maxAngle/45.0
const littleAngle = 3.0*maxAngle/45.0
const midAngle = 10.0*maxAngle/45.0
const mediumLargeAngle = 25.0*maxAngle/45.0
const bigAngle = 30.0*maxAngle/45.0
const panicAngle = 45.0*maxAngle/45.0

# reference for the line module
const reference = [66.5, 67.0, 56.5, 79.0, 66.0]

# Obstacle avoidance constants
const obstacleDetectionDistance = 20 # cm - trigger avoidance if obstacle within this distance

# Avoidance constants
const avoidance_direction = 1  # 1 = left, 0 = right - which way to dodge

# Movement Variables
var movementSpeed
var wheelAngleTarget
var speedTarget
var wheelAngle
var lastDirection # 1 : Left, 0 : Right
var movement

# state variable
var state
var nextState
var delay
var timer

# Avoidance variable
var avoidance_timer

# picar connection and data
var picar_data
var ws
var connected

func _ready():
	print("Connecting…")
	ws = WebSocketPeer.new()
	ws.connect_to_url("ws://10.0.0.175:8765")  # Adresse du PiCar
	
	# Private
	movementSpeed = 0.0 # m/s
	state = -2
	
	# Public
	wheelAngleTarget = 0.0 # deg
	wheelAngle = 0.0
	speedTarget = 0.2 # m/s
	avoidance_timer = 0.0
	timer = 0.0
	movement = 0.0
	connected = false

func _process(delta):
	# Receve PiCar communication
	ws.poll()
	readPiCar()
	
	# logic
	fastStateMachine(delta)
	setSpeed()
	move(delta)
	
	# Send Picar Communication
	sendPiCar({0:movementSpeed, 1:-wheelAngle+100})

# Transform raw data from the PiCar to digital data
func rawToDigital(rawData: Array) -> Array:
	var returns = [0, 0, 0, 0, 0]
	for i in range(5):
		if (int(rawData[2 * i]) << 8) | int(rawData[2 * i + 1]) < reference[i]:
			returns[i] = 1
		else:
			returns[i] = 0
	return returns

# Set movementSpeed with acceleration
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
	
	# Angle update
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

# Refactor of stateMachine with optimization 
func fastStateMachine(delta: float) -> void:
	match state:
		-5: # debug
			setWheelAngle(avoidance_direction, bigAngle)
			speedTarget = 30
		-4: # Complete stop
			speedTarget = 0.0
			wheelAngleTarget = 0.0
			
		-3: # Wait for next state
			timer += delta
			if timer > delay:
				state = nextState
				timer = 0.0

		-2: # Connection state
			if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
				if not connected:
					print("CONNECTED to server!")
					connected = true
				readPiCar()
				if picar_data != null:
					state = -1
			speedTarget = 0.0
			wheelAngleTarget = 0.0
			
		-1: # Start state
			if picar_data["Raw"] == [1, 1, 1, 1, 1]:
				speedTarget = maxSpeed
			if speedTarget != 0 && picar_data["Raw"][0] + picar_data["Raw"][1] + picar_data["Raw"][2] + picar_data["Raw"][3] + picar_data["Raw"][4] < 3:
				state = 0
				
		0: # Line follower state
			timer += delta
			if picar_data["UltraValue"] != null && picar_data["UltraValue"] < obstacleDetectionDistance:
				state = 1
				timer = 0.0
			elif picar_data["Raw"] == [1, 1, 1, 1, 1]:
				state = -4
				timer = 0.0
			elif picar_data["Raw"] == [0, 0, 0, 0, 0] && timer > 1:
				state = -3 # figurer quel state mettre
				timer = 0.0
				if wheelAngleTarget > 0:
					lastDirection = 1
				else:
					lastDirection = 0
				delay = 0.25
				nextState = 10
			else:
				lineFollower()
				speedTarget = maxSpeed
				if(picar_data["Raw"] != [0, 0, 0, 0, 0]):
					timer = 0.0

		1: # Reverse until 30 cm
			timer = 0.0
			
			if timer > 1:
				lineFollower(-1)
			else:
				speedTarget = 0
				
			if picar_data["UltraValue"] > 23:
				state = -3
				nextState = 2
				timer = 0.0
				delay = 1
			elif timer > 15:
				state = 0 # find back step
				timer = 0.0
				wheelAngleTarget = 0.0
			
		2: # leave line
			timer += delta
			movement += movementSpeed * timer
			if movement > 10:
				state = -4
				timer = 0.0

		10: # retour sur la ligne
			timer += delta
			speedTarget = -midSpeed
			setWheelAngle(lastDirection, -mediumLargeAngle)
			if picar_data["Raw"] != [0, 0, 0, 0, 0]:
				state = 0
				timer = 0.0

# To Be Deleted
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
			var detection = picar_data["Raw"]
			if avoidance_timer > 2 && detection == [0, 0, 0, 0, 0]:
				state = 8
				avoidance_timer = 0.0
			
		2: # Reverse maneuver
			avoidance_timer += delta
			if avoidance_timer > 1:
				lineFollower(-1)
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

# Set wheelAngle to follow the line
func lineFollower(reverse: int = 1) -> void:
	if picar_data["Raw"] == [0, 0, 1, 0, 0]:
		wheelAngleTarget = 0.0
	elif picar_data["Raw"] == [0, 1, 1, 0, 0] || picar_data["Raw"]  == [0, 0, 1, 1, 0]:
		setWheelAngle(picar_data["Raw"][1], reverse*littleAngle)
	elif picar_data["Raw"] == [0, 1, 0, 0, 0] || picar_data["Raw"]  == [0, 0, 0, 1, 0]:
		setWheelAngle(picar_data["Raw"][1], reverse*midAngle)
	elif picar_data["Raw"] == [1, 1, 0, 0, 0] || picar_data["Raw"]  == [0, 0, 0, 1, 1]:
		setWheelAngle(picar_data["Raw"][1], reverse*bigAngle)
	elif picar_data["Raw"] == [1, 0, 0, 0, 0] || picar_data["Raw"]  == [0, 0, 0, 0, 1]:
		setWheelAngle(picar_data["Raw"][0], reverse*panicAngle)

# Transform relative angle and direction to real angle
# direction is only 1 or 0 : 1 -> left, 0 -> right
func setWheelAngle(direction: int, angle: float)->void:
	wheelAngleTarget = direction*angle + (direction-1)*angle

# Transform the speed depending on the wheels angle
func setSpeed() -> void:
	speedTarget = (-0.011 * abs(wheelAngleTarget) + 1) * maxSpeed

# Get data from PiCar
func readPiCar(printData: bool = false) -> void:
	while ws.get_available_packet_count() > 0:
		picar_data = JSON.parse_string(ws.get_packet().get_string_from_utf8())
		picar_data["Raw"] = rawToDigital(picar_data["Raw"])
	if printData:
		print(picar_data)

# Send data to PiCar
func sendPiCar(data: Dictionary, printData: bool = false) -> void:
	ws.send_text(JSON.stringify(data, "\t"))
	if printData:
		print(JSON.stringify(data, "\t"))
