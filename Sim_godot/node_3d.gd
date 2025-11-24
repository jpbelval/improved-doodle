extends Node

var ws := WebSocketPeer.new()
var connected := false

func _ready():
	print("Connecting…")
	ws.connect_to_url("ws://192.168.1.114:8765")  # Adresse du PiCar

func _process(delta):
	ws.poll()

	var state = ws.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN and not connected:
		connected = true
		print("CONNECTED to server!")
		ws.send_text("hello from Godot!")

	elif state == WebSocketPeer.STATE_CLOSED:
		print("Connection closed. Reason: %s" % ws.get_close_reason())

	# Lire les messages
	while ws.get_available_packet_count() > 0:
		var pkt = ws.get_packet().get_string_from_utf8()
		print("Received: %s" % pkt)
