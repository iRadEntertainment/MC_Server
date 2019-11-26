#============================#
#         server.gd
#============================#

extends Node

const SERVER_VERSION = "0.2"
const PORT           = 5000
var   max_users      = 200

#timer
var auto_shut_down = 120   setget _set_auto_shut_down_time
var fl_auto_shut   = false setget _set_auto_shut_down

#stats
var num_user = 0 setget _user_num_changed
var max_users_connected = 0

#vars
const config_path  = "res://server_config.cfg"
const data_path    = "res://data.mcd"
var log_max_size = 1000
var server_log = []

var users_existing = {} # {"username":code, "username":code, ... }
var users_auth     = {} # {"username":[id1,id2,...], "username2":[...]}
var user_stats     = {}



#=========== INIT
var one_time_update = false
func _ready():
	#on time update function to operate on data resorting and savings THEN quit
	if one_time_update:
		print("One time update ON, server will NOT be initialized")
		one_time_update()
		#prevent all the other init operations (quitting at the end of the func anyway)
		return
	
	load_config()
	load_datas()
	setup_server()
	start_server()

func one_time_update():
	#the content is adjusted any time a new update need to happen
	
	get_tree().quit()

func setup_server():
	get_tree().multiplayer.connect("network_peer_packet",self,"_on_packets_received")
	get_tree().connect("network_peer_connected", self, "_user_connected")
	get_tree().connect("network_peer_disconnected", self, "_user_disconnected")
	
	#timers
	if fl_auto_shut:
		$tmr.wait_time = auto_shut_down
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
func add_user(id, username, code):
	log_print("Added new user: %s"%username)
	users_existing[username] = code
	save_datas()

func _user_connected(id):
	self.num_user = get_tree().multiplayer.get_network_connected_peers().size()
	log_print(str("Connected - Tot user: ",num_user),id)
	max_users_connected = max(max_users_connected,num_user)
	#---associate user
	var user_name = remote_func.ask_user_name(id)
	associate_user(user_name,id)

func _user_disconnected(id):
	self.num_user = get_tree().multiplayer.get_network_connected_peers().size()
	log_print(str("Disconnected - Tot user: ",num_user),id)
	#---dissociate user
	dissociate_user(id)

func _user_num_changed(val):
	num_user = val
#	log_print(str("Total users: " , num_user) )

func associate_user(username,id): #associate the name in the dictionary with the user id
	if username == null: return
	
	if users_auth.has(username):
		users_auth[username].append(id)
	else:
		log_print(str("ERROR: impossible to associate ",username," (id ",id,") to any registered user"))

func dissociate_user(id): #dissociate the name in the dictionary
	for key in users_auth.keys():
		if id in users_auth[key]:
			users_auth[key].erase(id)
			break

#============== USER AUTHORIZATION
func auth_request(id,username,pw):
	if not username in users_existing.keys():
		
		return false

func id2username(id):
	var username = "Unknown(%s)"%id
	if id==1:
		username = "Server"
	elif id == 0:
		username = "All"
	else:
		for key in users_auth.keys():
			if id in users_auth[key][1]:
				username = key
				break
	return username

#============= SERVER FUNC
remote func shut_server():
	log_print("quitting")
	#---send "server disconnetting" to all clients
	
	#---disconnect all clients
	
	#---remove peer network
	get_tree().set_network_peer(null)
	#---save config_file
	save_config()
	#---quit server application
	yield(get_tree(),"idle_frame")
	yield(get_tree(),"idle_frame")
	get_tree().quit()

func manual_shut_down(id):
	log_print("%s: manual shut down",id )
	shut_server()

func manual_restart(id):
	log_print("%s: manual restart",id )
	OS.execute("./restart_MC_server.sh",[],false)
	pass

func log_print(string,id=1):
	var time_unix = OS.get_unix_time()
	var dic = OS.get_datetime()
	var time = [dic["month"],dic["day"],dic["hour"],dic["minute"],dic["second"]]
	var log_entry = [time_unix,id,string]
	server_log.push_back(log_entry)
	while server_log.size() > log_max_size:
		server_log.pop_front()
	
	#print sdtout
	var time_str   = "%s/%s [%s:%s:%s]"%time
	var format_str = str(time_str," ",id2username(id),": ",string)
	print(format_str)
	
	#sending last log entry to all clients
	remote_func.send_last_server_entry(log_entry)

#============= SAVE AND LOAD FUNC
func save_config(val = 0):
	var config_file = ConfigFile.new()
	if Directory.new().file_exists(config_path): config_file.load(config_path)
	if val in [0]: config_file.set_value("logs","server_log",server_log)
	if val in [0]: config_file.set_value("logs","max_users_connected",max_users_connected)
	config_file.save(config_path)

func load_config():
	if not Directory.new().file_exists(config_path):
		log_print("Creating default config_file.cfg")
		save_config()
		return
	var config_file = ConfigFile.new()
	config_file.load(config_path)
	server_log          = config_file.get_value("logs","server_log",[])
	max_users_connected = config_file.get_value("logs","max_users_connected",0)

func save_datas(val = 0):
	var data_file = ConfigFile.new()
	if Directory.new().file_exists(data_path): data_file.load(data_path)
	if val in [0,1]: data_file.set_value("users","users_existing",users_existing)
	
	data_file.save(data_path)

func load_datas():
	if not Directory.new().file_exists(data_path):
		log_print("Creating default data.mcd")
		save_datas()
		return
	
	var data_file = ConfigFile.new()
	data_file.load(data_path)
	users_existing = data_file.get_value("users","users_existing",{})


#============= TIMERS
func _on_tmr_timeout(): shut_server()

func _set_auto_shut_down(val):
	fl_auto_shut = val
	if fl_auto_shut: $tmr.start(0)

func _set_auto_shut_down_time(val):
	auto_shut_down = val
	$tmr.wait_time = auto_shut_down
	if fl_auto_shut: $tmr.start(0)
