extends SceneTree

# Max constantes
const maxAngle = 45.0 # deg
const maxSpeed = 38 # %/s
const moveAcc = 30 # %/s2 line follower acceleration
const accAcc = 55 # %/s3 
const dodgeAcc = 65 # dodging acceleration (start stop only)
const maxWheelSpeed = 138.0 # deg/s

# Speed constantes
const fullSpeed = maxSpeed
const midSpeed = 7.0*maxSpeed/8.0
const midSlowSpeed = 6.5*maxSpeed/8.0
const slowSpeed = 6.0*maxSpeed/8.0

# Angle constantes
const reverseAngle = 3.75*maxAngle/45.0
const littleAngle = 3.0*maxAngle/45.0
const midAngle = 10.0*maxAngle/45.0
const mediumLargeAngle = 25.0*maxAngle/45.0
const mediumLukaAngle = 27.0*maxAngle/45.0
const bigAngle = 30.0*maxAngle/45.0
const panicAngle = 45.0*maxAngle/45.0

# reference for the line module
const reference = [65.5, 64.0, 55.0, 76.5, 66.0]

# Obstacle avoidance constants
const obstacleDetectionDistance = 20 # cm - trigger avoidance if obstacle within this distance
const obstacleStartDistance = 30 # cm -  distance at which the car stops reversing

# Avoidance constants
const avoidance_direction = 1  # 1 = left, 0 = right - which way to dodge

# Movement Variables
var movementSpeed
var wheelAngleTarget
var speedTarget
var wheelAngle
var accelerationTarget
var lastDirection # 1 : Left, 0 : Right
var movement
var acceleration = moveAcc
var wasTurning
var turnAvg
var amount

# state variable
var state
var nextState
var delay
var timer

# Avoidance variable
var correction_timer

# picar connection and data
var picar_data
var ws
var connected
var lineValue

var globalTimer

func _init():
	print("Connecting…")
	ws = WebSocketPeer.new()
	ws.connect_to_url("ws://127.0.0.1:8765")  # Adresse du PiCar
	
	# Private
	movementSpeed = 0.0 # m/s
	state = -2
	
	# Public
	wheelAngleTarget = 0.0 # deg
	wheelAngle = 0.0
	speedTarget = 0.0 # m/s
	correction_timer = 0.0
	timer = 0.0
	movement = 0.0
	connected = false
	lineValue = 0
	accelerationTarget = 0.0
	acceleration = 0.0
	
	wasTurning = 0.0
	turnAvg = 0.0
	amount = 0
	
	globalTimer = 0.0

func _process(delta):
	globalTimer += delta
	# Receve PiCar communication
	ws.poll()
	readPiCar()
	# setTurnExitSpeed(delta)
	# logic
	fastStateMachine(delta)
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
	
func digitalToInt(rawData: Array) -> int:
	return rawData[0] << 4 | rawData[1] << 3 | rawData[2] << 2 | rawData[3] << 1 | rawData[4]

# Set movementSpeed with acceleration
func move(delta: float) -> void:
	# acceleration update
	if acceleration < accelerationTarget:
		if acceleration + accAcc * delta > accelerationTarget:
			acceleration = accelerationTarget
		else:
			acceleration += accAcc * delta
	elif acceleration > accelerationTarget:
		if acceleration - accAcc * delta < accelerationTarget:
			acceleration = accelerationTarget
		else:
			acceleration -= accAcc * delta
	
	# Speed update
	if movementSpeed < speedTarget:
		if movementSpeed + acceleration * delta > speedTarget:
			movementSpeed = speedTarget
		else:
			movementSpeed += acceleration * delta
	elif movementSpeed > speedTarget:
		if movementSpeed - acceleration * delta < speedTarget:
			movementSpeed = speedTarget
		else:
			movementSpeed -= acceleration * delta
	
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
			if lineValue == 31:
				speedTarget = maxSpeed
				accelerationTarget = moveAcc
			if speedTarget != 0 && lineValue != 31:
				state = 0
				
		0: # Line follower state
			timer += delta
			if picar_data["UltraValue"] != null && picar_data["UltraValue"] < obstacleDetectionDistance:
				state = -3
				timer = 0.0
				accelerationTarget = dodgeAcc
				speedTarget = 0.0
				nextState = 1
				delay = 3
			elif lineValue == 31:
				state = -4
				accelerationTarget = dodgeAcc
				acceleration = accelerationTarget
				timer = 0.0
			elif !lineValue && timer > 1.3:
				state = -3 # figurer quel state mettre
				timer = 0.0
				if wheelAngleTarget > 0:
					lastDirection = 1
				else:
					lastDirection = 0
				delay = 0.25
				speedTarget = 0.0
				nextState = 10
			else:
				lineFollower()
				if lineValue:
					timer = 0.0

		1: # Reverse until 30 cm
			timer += delta
			
			lineFollower(-1)
			if picar_data["UltraValue"] > obstacleStartDistance:
				state = -3
				nextState = 2
				speedTarget = 0.0
				timer = 0.0
				delay = 1
				accelerationTarget = moveAcc
			elif timer > 10:
				state = 0 # find back step
				timer = 0.0
				wheelAngleTarget = 0.0
				accelerationTarget = moveAcc
			
		2: # leave line
			timer += delta
			state = -3
			nextState = 3
			setWheelAngle(avoidance_direction, mediumLargeAngle)
			speedTarget = midSpeed
			delay = 2.20
		
		3: # parall elize peopele
			timer += delta
			state = -3
			nextState = 4
			setWheelAngle(avoidance_direction, -mediumLargeAngle)
			delay = 1.75
		
		4: # fine the laine (not hutson) (gsp voice)
			if lineValue == 2 || lineValue == 4 || lineValue == 6  :
				setWheelAngle(avoidance_direction, mediumLukaAngle)
				state = 0
				timer = 0.0
			
		10: # retour sur la ligne
			timer += delta
			speedTarget = -midSlowSpeed
			setWheelAngle(lastDirection, -mediumLargeAngle)
			if lineValue:
				state = -3
				nextState = 0
				delay = 0.25
				timer = 0.0
				speedTarget = 0.0
		11: # post turn line follower
			pass

# Set wheelAngle to follow the line
func lineFollower(reverse: int = 1) -> void:
	if lineValue == 4:
		wheelAngleTarget = 0.0
	elif lineValue == 12 || lineValue  == 6:
		setWheelAngle(lineValue >> 3, reverse*littleAngle)
	elif lineValue == 8 || lineValue  == 2:
		setWheelAngle(lineValue >> 3, reverse*midAngle)
	elif lineValue == 24 || lineValue  == 3:
		setWheelAngle(lineValue >> 3, reverse*bigAngle)
	elif lineValue == 16 || lineValue  == 1:
		setWheelAngle(lineValue >> 4, reverse*panicAngle)
	setSpeed(reverse)

# Transform relative angle and direction to real angle
# direction is only 1 or 0 : 1 -> left, 0 -> right
func setWheelAngle(direction: int, angle: float)->void:
	wheelAngleTarget = direction*angle + (direction-1)*angle

# Transform the speed depending on the wheels angle
func setSpeed(reverse: int = 1) -> void:
	speedTarget = (-1.0/400.0 * abs(wheelAngleTarget) + 1) * maxSpeed * reverse

# Get data from PiCar
func readPiCar(printData: bool = false) -> void:
	if ws.get_available_packet_count() > 0:
		var pkt
		while ws.get_available_packet_count() > 0:
			pkt = ws.get_packet()
		picar_data = JSON.parse_string(pkt.get_string_from_utf8())
		lineValue = digitalToInt(rawToDigital(picar_data["Raw"]))
		if printData:
			print(picar_data)

# Send data to PiCar
func sendPiCar(data: Dictionary, printData: bool = false) -> void:
	if globalTimer > 0.033:
		globalTimer -= 0.033
		ws.send_text(JSON.stringify(data, "\t"))
	if printData:
		print(JSON.stringify(data, "\t"))
