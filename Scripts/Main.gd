extends Node2D

class_name Main

var scene_manager: SceneManager = SceneManager.new(self)

var online_game = false
var player_name = ""
var network_data = {}
var loaded_scene_history = []
var game_modes = []
var stored_IP = ""

var peer = null
const SERVER_PORT = 9658
const MAX_PLAYERS = 2
const LOCAL_HOST = "127.0.0.1"
# Dictionary mapping player names ("host", "guest") to network ids
var players = {}

remotesync func load_level(scene_str, world_str, game_modes):
	var scene = scene_manager._load_scene(scene_str)
	scene._root = self
	scene.game_modes = game_modes
	scene.world_str = world_str
	scene_manager._replace_scene(scene)

func _ready():
	# The event that triggers when a player connects to this instance of the game
	get_tree().connect("network_peer_connected", self, "_player_connected")
	
	var scene = scene_manager._load_scene("UI/Local Online")
	scene_manager._replace_scene(scene)

# Callback from SceneTree.
func _player_connected(id):
	# Registering the new player that connected
	rpc_id(id, "register_player", player_name, get_tree().get_network_unique_id())

# Register a player to a dictionary that contains player names and player ids
remote func register_player(player_name, id):	
	players[player_name] = id
	notify_player_connection(player_name)

func notify_player_connection(connecting_player_name):
	var notification = Label.new()
	notification.text = connecting_player_name + " has connected"
	notification.add_font_override("font", load("res://Assets/Fonts/Font_50.tres"))
	get_children()[0].add_child(notification)
	
	# Remove the back button for the host once the guest has connected
	get_children()[0].get_node("TextureButton").visible = false

# Create a server and set the network peer to the peer you created
func host():
	peer = NetworkedMultiplayerENet.new()
	peer.create_server(SERVER_PORT, MAX_PLAYERS)
	print(get_tree())
	get_tree().network_peer = peer
	
	# Adding yourself to the list of players
	if online_game:
		register_player(player_name, get_tree().get_network_unique_id())

func guest(server_IP):
	# Default of 127.0.0.1
	if not server_IP:
		server_IP = LOCAL_HOST
	# Create a client and set the network peer to the peer you created
	peer = NetworkedMultiplayerENet.new()
	peer.create_client(server_IP, SERVER_PORT)
	get_tree().network_peer = peer
	
	# Adding yourself to the list of players 
	register_player(player_name, get_tree().get_network_unique_id())
	print(server_IP)

func load_save(save_dict):
	# Setting up the game
	game_modes = save_dict["game_modes"]
	rpc("load_level", "Levels/Level Main", save_dict["map"],  game_modes)
	
	# Setting up curr_player and curr_player_index
	var main = get_children()[0]
	main.curr_player = main.players[save_dict["curr_player_color"]]
	# Finding the current player index
	var players_colors = []
	for player in main.players.values():
		players_colors.append(player.color)
	main.curr_player_index = players_colors.find(save_dict["curr_player_color"])
	
	# Assigning all countries their saved properties
	for country_dict in save_dict["countries"]:
		var country = main.all_countries[country_dict["name"]]
		country.set_max_troops(country_dict["max_troops"])
		country.set_num_troops(country_dict["troops"])
		for status in country_dict["status"]:
			country.set_statused(status, country_dict["status"][status])
	
	# Assigning ownership of countries to players
	for player_dict in save_dict["players"]:
		var player = main.players[player_dict["color"]]
		player.reset()
		for country_name in player_dict["owned_countries"]:
			main.all_countries[country_name].change_ownership_to(player)
	
	main.update_labels()
	main.Phase.update_player_status()
