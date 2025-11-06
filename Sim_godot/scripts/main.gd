extends Node3D

# Variables
var NetworkIPAddrRegex = RegEx.new()

# Engine functions
# Called when the node enters the scene tree for the first time.
func _ready():
	NetworkIPAddrRegex.compile(r'^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)(\.(?!$)|$)){4}$')
	#get_node("NetworkFSM").current_state = $NetworkFSM/NetworkInitState
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

# Signals functions
func _on_quit_pressed():
	$NetworkFSM.current_state = $NetworkFSM/NetworkClosingConnectionState
	get_tree().quit()

func _on_connect_pressed():
	# IP address REGEX before starting connection
	if get_node("GridContainer/btn_Connect").text == "Disconnect":
		$NetworkFSM.current_state = $NetworkFSM/NetworkClosingConnectionState
	else:
		var RegexResult = NetworkIPAddrRegex.search_all(get_node("GridContainer/le_IpAdress").text)
		if RegexResult.size() > 0:
			# Disable button before having a connection
			get_node("GridContainer/btn_Connect").disabled = true
			get_node("GridContainer/lb_ConnectionStatusPackets").text = "Connecting"
			get_node("NetworkFSM").current_state = $NetworkFSM/NetworkInitState
		else:
			get_node("AspectRatioContainer/GridContainer/lb_ConnectionStatusPackets").text = "Wrong IP Address!"


func _on_check_box_toggled(toggled_on):
	if toggled_on:
		$GridContainer/le_IpAdress.text = "127.0.0.1"
		get_node("NetworkFSM").current_state = $NetworkFSM/NetworkInitState


func _on_item_list_item_selected(index: int) -> void:
	var selected_text = $ItemList.get_item_text(index)
	$PickedParcours.text = selected_text
	if (selected_text == "Alternatif"):
		$Bille.position = Vector3(-11.542, 0.099, -0.446)
		$voiture.position = Vector3(-11.619, 0.011, -0.45)
		$voiture.rotation = Vector3(0.0, 0.0, 0.0)
		$voiture._ready()
	else:
		$Bille.position = Vector3(-11.542, 0.099, -1.477)
		$voiture.position = Vector3(-11.619, 0.011, -1.486)
		$voiture.rotation = Vector3(0.0, 0.0, 0.0)
		$voiture._ready()
