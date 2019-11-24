extends Node

onready var server = get_tree().get_root().get_node("server")


#=========== SERVER COMMANDS ==============
remote func shut_down_server():
	server.log_print(str(multiplayer.get_rpc_sender_id()))
	server.shut_server()

remote func restart_server():
	server.log_print(str(multiplayer.get_rpc_sender_id()))
	OS.execute("./restart_MC_server.sh",[],false)
	server.shut_server()

#=========== SERVER LOGS ==============
remote func send_server_log(id):
	rpc_id(id,"receive_server_log",server.server_log)

remote func send_last_server_entry(entry,id = null):
	var connected = get_tree().has_network_peer()
	if not connected: return
	if id:
		rpc_id(id,"receive_last_server_entry",entry)
	else:
		rpc("receive_last_server_entry",entry)

func ask_user_name(id):
	var user_name = rpc_id(id,"return_user_name")
	return user_name

#================ FILE MANAGEMENT ======================
remote func send_file_content(which):
	var sender_id = multiplayer.get_rpc_sender_id()
	server.log_print( str( sender_id ) + " requested file %s"%which )
	
	var allowed = ["remote_func","server"]
	if not which in allowed:
		return false
	var path
	match which:
		"remote_func": path = "res://remote_func.gd"
		"server":      path = "res://server.gd"
	
	var file = File.new()
	file.open(path, File.READ)
	var content = file.get_as_text()
	file.close()
	rpc_id(sender_id,"receive_file_content",content)

remote func override_file(which, content):
	var sender_id = multiplayer.get_rpc_sender_id()
	server.log_print( str( sender_id ) + " overriding file %s"%which )
	
	var allowed = ["remote_func","server"]
	if not which in allowed:
		return false
	var path
	match which:
		"remote_func": path = "res://remote_func.gd"
		"server":      path = "res://server.gd"
	
	var file = File.new()
	file.open(path, File.WRITE)
	file.store_string(content)
	file.close()


#================ TESTS ======================
remote func test():
	server.log_print("TEST: successful")
	return true
