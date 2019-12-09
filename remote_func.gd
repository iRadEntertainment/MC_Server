#============================#
#       remote_func.gd
#============================#

extends Node

onready var server = get_tree().get_root().get_node("server")


#=========== SERVER COMMANDS ==============
remote func shut_down_server():
	server.manual_shut_down(multiplayer.get_rpc_sender_id())

remote func restart_server():
	server.maunal_restart(multiplayer.get_rpc_sender_id())


#=========== USER MANAGEMENT ==============
remote func send_existing_users():
<<<<<<< HEAD
	var id = multiplayer.get_rpc_sender_id()
	var users = server.users_existing.keys()
	rpc_id(id,"receive_existing_users",users)

remote func auth_request(username, code):
	var id     = multiplayer.get_rpc_sender_id()
	var result = server.auth_request( multiplayer.get_rpc_sender_id() , username, code )
	rpc_id(id,"auth_request_result",result)
=======
	var sender_id = multiplayer.get_rpc_sender_id()
	var existing_users = server.users_existing.keys()
	glb.rset_id(sender_id,"existing_users",existing_users)

remote func auth_request(username, code):
	var sender_id = multiplayer.get_rpc_sender_id()
	var server_auth = server.auth_request( multiplayer.get_rpc_sender_id() , username, code )
	glb.rset_id(sender_id,"server_auth",server_auth)
>>>>>>> 33c638d778cfbb07d50c57a156673e1f5fe00259

remote func add_user(username,code):
	server.add_user( multiplayer.get_rpc_sender_id() , username, code)


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
	server.log_print( "requested file %s"%which, sender_id )
	
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
