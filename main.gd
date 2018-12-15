extends Control

const PORT        = 5000
const ADDRESS     = "81.4.107.146"#"127.0.0.1"#"81.4.107.146"

#-------- commands
enum Cmds{
	SERVER,UPDATE}
enum Serv{
	SHUT_DOWN,REBOOT,SEND_LOG,LOG_UPDATED}
enum Updt{
	ALL_VARS,NUM_USER}

#-------- flags
var fl_connected = false
var master_id = -1

#----- vars
const config_path  = "user://client_config.cfg"
var server_log = []
var registered_users = {}


#=========== INIT

func _ready():
	setup_client()
	

func setup_client():
	get_tree().multiplayer.connect("network_peer_packet",self,"_on_packets_received")
	get_tree().multiplayer.connect("connected_to_server",self,"_on_connection_succeeded")
	get_tree().multiplayer.connect("connection_failed",self,"_on_connection_failed")

func connect_to_server():
	if !fl_connected:
		print("Joining network")
		$scr/bg/lb_print.text = str($scr/bg/lb_print.text,"\n","Joining network")
		var host = NetworkedMultiplayerENet.new()
		var res = host.create_client(ADDRESS,PORT)
		
		if res != OK:
			print("Impossible to create client")
			prints("Error:",res)
			$scr/bg/lb_print.text = str($scr/bg/lb_print.text,"\n","Impossible to create client - ","Error: ",res)
			return
		
		get_tree().set_network_peer(host)
		master_id = get_tree().multiplayer.get_network_unique_id()
	else:
		get_tree().set_network_peer(null)
		fl_connected = false
	
	if fl_connected: $btn_bg/btn.text = "disconnect"
	else:            $btn_bg/btn.text = "connect"

func _on_connection_failed():
	$scr/bg/lb_print.text = str($scr/bg/lb_print.text,"\n","Connection failed - ","Error: ")
	get_tree().set_network_peer(null)
	fl_connected = false
	
func _on_connection_succeeded():
	$scr/bg/lb_print.text = str($scr/bg/lb_print.text,"\n","Connection succeded - ")
	fl_connected = true
	$btn_bg/btn.text = "disconnect"

func _on_btn_send_pressed():
	if $message.text == "": return
	if !fl_connected:
		$scr/bg/lb_print.text = str($scr/bg/lb_print.text,"\n","Not connected to server")
		$message.text = ""
		return
	
	var text_to_send = $message.text
	match text_to_send:
		"1": text_to_send = 1
		"2": text_to_send = 2
	$scr/bg/lb_print.text = str($scr/bg/lb_print.text,"\n","Sending data to server:",text_to_send)
	get_tree().multiplayer.send_bytes(var2bytes(text_to_send))
	$message.text = ""

#=========== server requests


#=========== server commands

func shut_down_server():
	var cmd = null
	send_command(cmd)

#=========== communications
func send_command(cmd, id=1): #id=0 all the peers
	get_tree().multiplayer.send_bytes(var2bytes(cmd),id)

func _on_packets_received(id,packet):
	if id == 1: id = "Server: "
	$scr/bg/lb_print.text = str($scr/bg/lb_print.text,"\n", id , str( bytes2var(packet) ) )