extends Node

const SERVER_VERSION = "0.1"
const PORT           = 5000
var   max_users      = 200
const AUTO_SHUT_DOWN = 120

var fl_auto_shut = true

#stats
var num_user = 0 setget _user_num_changed
var max_users_connected = 0

#vars
const config_path  = "res://server_config.cfg"
const data_path    = "res://data.mcd"
var log_max_size = 1000
var server_log = []
var registered_users = {"Dario":[0,[]],"Monica":[0,[]],"Luis":[0,[]],
						"Antonia":[0,[]],"Blago":[0,[]],"Liisa":[0,[]],
						"Valeria":[0,[]],"Giulio":[0,[]]}

enum Save{ALL,SERVER_LOG,MAX_USER_CONNECTED,USERS_DIC}

#commands
enum Cmds{SERVER,UPDATE} #server management or update management

enum Serv_in	{SHUT_DOWN,			#simple command from MASTER client
				REBOOT,				#simple
				SEND_LOG,			#simple
				ADD_USER}			#ARG = string
enum Serv_out	{SHUTTING_DOWN,		#simple command for ALL clients
				LOG_UPDATED}		#simple command from MASTER client

enum Updt_up	{NONE}
enum Updt_req	{ALL_VARS,
				NUM_USER}

#=========== INIT
func _ready():
	load_config()
	load_datas()
	setup_server()
	start_server()

func setup_server():
	get_tree().multiplayer.connect("network_peer_packet",self,"_on_packets_received")
	get_tree().connect("network_peer_connected", self, "_user_connected")
	get_tree().connect("network_peer_disconnected", self, "_user_disconnected")
	
	#timers
	if fl_auto_shut:
		$tmr.wait_time = AUTO_SHUT_DOWN
		$tmr.start()
	

func start_server():
	log_print("Server started")
	var server = NetworkedMultiplayerENet.new()
	var res = server.create_server(PORT, max_users)
	get_tree().set_network_peer(server)
	
	if res != OK:
		log_print("Impossible to create the server")
		log_print(str("Error: ",res))
		return
	
#================ USER MANAGEMENT
func _user_connected(id):
	self.num_user = get_tree().multiplayer.get_network_connected_peers().size()
	log_print(str("Connected to server! - Tot user: ",num_user),id)
	max_users_connected = max(max_users_connected,num_user)
	#---associate user
	dissociate_user(id)

func _user_disconnected(id):
	self.num_user = get_tree().multiplayer.get_network_connected_peers().size()
	log_print(str("User disconnected from server! ID:",id," - Tot user: ",num_user))
	#---dissociate user
	dissociate_user(id)

func _user_num_changed(val):
	num_user = val
	log_print(num_user)
	var msg = [Cmds.UPDATE,Updt_req.NUM_USER, num_user]
	send_command(msg)

func associate_user(username,id): #associate the name in the dictionary with the user id
	if registered_users.has(username):
		registered_users[username].append(id)
	else:
		log_print(str("ERROR: impossible to associate ",username," (id ",id,") to any registered user"))

func dissociate_user(id): #dissociate the name in the dictionary
	for key in registered_users.keys():
		if id in registered_users[key]:
			registered_users[key].erase(id)
			break

#============== USER AUTHORIZATION
func auth_request(id,pw):
	if not id2username(id) in registered_users.keys():
		log_print(str("ERROR: Impossible auth - id(",id,") not found in registered_users"),id)
		#TODO manage error on the client -> send the error from the server
		return
	var username = id2username(id)
	if registered_users[username][0] == 0:
		first_auth(id,pw)
	else:
		auth_user(id,pw)

func first_auth(id,pw):
	var username = id2username(id)
	registered_users[username][0] = pw
	#TODO: save the sha pw in the config file

func auth_user(id,pw):
	var auth = -1
	
	return auth

func id2username(id):
	var username = "Unknown"
	if id==1:
		username = "Server"
	elif id == 0:
		username = "All"
	else:
		for key in registered_users.keys():
			if id in registered_users[key][1]:
				username = key
				break
	return username

#============= SENDING INFOS
func send_command(cmd, id=0): #id=0 send to all the peers connected
	if num_user != 0:
		get_tree().multiplayer.send_bytes(var2bytes(cmd),id)

func update_client(id,arg):
	var cmd = [Cmds.UPDATE,Updt_req.ALL_VARS,arg]
	send_command(cmd, id)
	log_print(str("Sending UPDATE-ALL_VARS to ",id))

#============= RECEIVING COMMANDS
func _on_packets_received(id,packets):
	var msg_received = bytes2var(packets)
	log_print(str("Sending packets:",msg_received),id)
	match msg_received[0]:
		Cmds.SERVER:
			match msg_received[1]: #Serv_in{SHUT_DOWN,REBOOT,SEND_LOG,ADD_USER}
				Serv_in.SHUT_DOWN: manual_shut_down(id)
				Serv_in.REBOOT:    pass
				Serv_in.SEND_LOG:  update_client(id,server_log)
				Serv_in.ADD_USER:  add_user(id,msg_received[2])
		Cmds.UPDATE:
			match msg_received[1]:
				Updt_req.ALL_VARS: update_client(id,"ciccio")
				Updt_req.NUM_USER: _user_num_changed(num_user)

#============= SERVER FORCED UPDATES
func add_user(id,val):
	log_print(str("Adding user: ",val),id)

#============= SERVER FUNC
func shut_server():
	log_print("quitting")
	#---send "server disconnetting" to all clients
	var cmd = [Cmds.SERVER,Serv_out.SHUTTING_DOWN]
	send_command(cmd)
	#---remove peer network
	get_tree().set_network_peer(null)
	#---save config_file
	save_config()
	#---quit server application
	OS.delay_msec(50)
	get_tree().quit()

func manual_shut_down(id):
	log_print("manual shut down",id)
	shut_server()

func log_print(string,id=1):
	var dic = OS.get_datetime()
	var time = [dic["month"],dic["day"],dic["hour"],dic["minute"],dic["second"]]
	var log_entry = [time,id,string]
	server_log.push_back(log_entry)
	while server_log.size() > log_max_size:
		server_log.pop_front()
	
	#print sdtout
	var time_str   = "%s/%s [%s:%s:%s]"%time
	var format_str = str(time_str," ",id2username(id),": ",string)
	print(format_str)
	
	#sending a command to update the clients who are showing server logs
	if num_user != 0:
		var cmd = [Cmds.SERVER,Serv_out.LOG_UPDATED]
		send_command(cmd)

#============= SAVE AND LOAD FUNC
func save_config(val = 0):
	var config_file = ConfigFile.new()
	if Directory.new().file_exists(config_path): config_file.load(config_path)
	if val in [0,Save.SERVER_LOG]:         config_file.set_value("logs","server_log",server_log)
	if val in [0,Save.MAX_USER_CONNECTED]: config_file.set_value("logs","max_users_connected",max_users_connected)
	if val in [0,Save.USERS_DIC]:          config_file.set_value("users","registered_users",registered_users)
	config_file.save(config_path)

func load_config():
	if not Directory.new().file_exists(config_path):
		create_default_config()
		return
	var config_file = ConfigFile.new()
	config_file.load(config_path)
	server_log          = config_file.get_value("logs","server_log",[])
	max_users_connected = config_file.get_value("logs","max_users_connected",0)
	registered_users    = config_file.get_value("users","registered_users",registered_users)

func save_datas():
	pass

func load_datas():
	pass

func create_default_config():
	log_print("Server: creating default config_file.cfg")
	save_config()

func create_default_data():
	pass

#============= TIMERS
func _on_tmr_timeout(): shut_server()


