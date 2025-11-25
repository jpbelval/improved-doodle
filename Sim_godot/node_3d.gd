extends Node

var ws := WebSocketPeer.new()
var connected := false

# Max constantes
const maxAngle = 40.0 # deg
const maxSpeed = 30 # %/s
const maxAcc = 45 # %/s2
const maxWheelSpeed = 90.0 # deg/s

# Speed constantes
const fullSpeed = maxSpeed
const midSpeed = 6*maxSpeed/8
const slowSpeed = 5*maxSpeed/8

# Angle constantes
const reverseAngle = maxAngle/12
#const littleAngle = maxAngle/8
const littleAngle = 2*maxAngle/8
const midAngle = 5*maxAngle/8
const bigAngle = 7*maxAngle/8

# Obstacle avoidance constants
const obstacleDetectionDistance = 30 # meters - trigger avoidance if obstacle within this distance

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

var picar_data
var picar_data_parsed

func _ready():
	print("Connecting…")
	ws.connect_to_url("ws://172.20.10.7:8765")  # Adresse du PiCar
	
	# Private
	movementSpeed = 0.0 # m/s
	wheelAngle = 0.0 # deg
	state = 0
	
	# Public
	wheelAngleTarget = 0.0 # deg
	speedTarget = 0.2 # m/s

func _process(delta):
	ws.poll()

	var state = ws.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN and not connected:
		connected = true
		print("CONNECTED to server!")
		# ws.send_text("hello from Godot!")
	elif state == WebSocketPeer.STATE_CLOSED:
		if connected:
			print("Connection closed.")
		connected = false
		
		# Lire les messages
	while ws.get_available_packet_count() > 0:
		picar_data = (ws.get_packet().get_string_from_utf8()) #JSON.parse_string
		picar_data = picar_data.replace("'", "\"")
		picar_data = JSON.parse_string(picar_data)
		picar_data_parsed = []
		
		for d in picar_data["LineValue"]:
			picar_data_parsed.append(int(d))
			
		picar_data["LineValue"] = picar_data_parsed
			
		#print("Received: %s" % picar_data)
	
	# update
	if connected and picar_data != null:
		stateMachine(delta)
		move(delta)

		#var data = {0:0.0, 1:70};
		var data = {0:movementSpeed, 1:-wheelAngleTarget+90};
		print(JSON.stringify(data, "\t"))
		ws.send_text(JSON.stringify(data, "\t"))

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
				setInvWheelAngle(avoidance_direction, midAngle)
				
		4: # Find line again
			avoidance_timer += delta
			if picar_data["UltraValue"] != null:
				if picar_data["UltraValue"] < obstacleDetectionDistance:
					state = 2
			var detection = picar_data["LineValue"]
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
				setInvWheelAngle(avoidance_direction, midAngle)
			if picar_data["UltraValue"] != null:
				if picar_data["UltraValue"] < obstacleDetectionDistance:
					state = 2
			var detection = picar_data["LineValue"]
			if detection != [0, 0, 0, 0, 0]:
				state = 0

	
func reversing() -> void:
	var detection = picar_data["LineValue"]
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
	var detection = picar_data["LineValue"]
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
