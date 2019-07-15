extends Node

onready var server = get_tree().get_root().get_node("server")


#=========== SERVER COMMANDS ==============
remote func shut_down_server():
	server.shut_server()

remote func restart_server():
	OS.execute("./restart_MC_server.sh",[],false)
	server.shut_server()

#=========== SERVER LOGS ==============
remote func send_server_log(id):
	rpc_id(id,"receive_server_log",server.server_log)

remote func send_last_server_entry(entry,id = null):
	if id:
		rpc_id(id,"receive_last_server_entry",entry)
	else:
		rpc("receive_last_server_entry",entry)

func ask_user_name(id):
	var user_name = null
	user_name = rpc_id(id,"return_user_name")
	return user_name