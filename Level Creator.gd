extends Node2D
var phase = "add countries"
var Country = load("res://Country.tscn")
var all_countries = {}
var selected_country = null

var change_curr_troops_button = null
var add_countries_button = null
var export_level_button = null
var connect_countries_button = null
var information_label = null

# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():	
	OS.set_window_size(Vector2(1920, 1080))
	
	# Button to change curr troops
	change_curr_troops_button = Button.new()
	change_curr_troops_button.text = "Change Curr Troops"
	change_curr_troops_button.connect("pressed", self, "change_to_change_curr_troops")
	add_child(change_curr_troops_button)
	change_curr_troops_button.set_position(Vector2(0, 20))
	
	# Button to add countries
	add_countries_button = Button.new()
	add_countries_button.text = "Add Countries"
	add_countries_button.connect("pressed", self, "change_to_add_countries")
	add_child(add_countries_button)
	add_countries_button.set_position(Vector2(0, 40))
	
	# Button to export level to text
	export_level_button = Button.new()
	export_level_button.text = "Export Level to Text"
	export_level_button.connect("pressed", self, "export_level")
	add_child(export_level_button)
	export_level_button.set_position(Vector2(0, 60))
	
	# Button to connect countries
	connect_countries_button = Button.new()
	connect_countries_button.text = "Connect Countries"
	connect_countries_button.connect("pressed", self, "connect_countries")
	add_child(connect_countries_button)
	connect_countries_button.set_position(Vector2(0, 80))
	
	# Label showing phase
	information_label = Label.new()
	add_child(information_label)
	information_label.set_position(Vector2(200, 0))
	update_labels()
	
	var save_game = File.new()
	if save_game.file_exists("res://savegame.save"):
		import_level()

func update_labels():
	match phase:
		"add countries":
			information_label.text = "Click anywhere to add a country"
		"change curr troops":
			information_label.text = "Left click on any country to increase it's current number of troops\n" + \
				"Right click on any country to decrease it's current number of troops\n"
		"connect countries":
			information_label.text = "Select any two countries to connect them"

func export_level():
	var save_game = File.new()
	save_game.open("res://savegame.save", File.WRITE)
	for country in all_countries.values():
		save_game.store_line(to_json(country.save()))
	save_game.close()

func import_level():	
	# Instantiating countries
	var save_game = File.new()
	save_game.open("res://savegame.save", File.READ)
	while save_game.get_position() < save_game.get_len():
		var node_data = parse_json(save_game.get_line())
		var new_country = Country.instance().init(node_data["x"], node_data["y"], node_data["name"])
		add_country_to_level(new_country)
		add_child(new_country)
	
	# Adding connections
	save_game.open("res://savegame.save", File.READ)
	while save_game.get_position() < save_game.get_len():
		var node_data = parse_json(save_game.get_line())
		add_connections(node_data["name"], node_data["connections"])
		for neighbour in all_countries[node_data["name"]].connected_countries:
			all_countries[node_data["name"]].draw_line_to_country(neighbour)

func add_connections(source_country_name, destination_country_names):
	for destination_country_name in destination_country_names:
		all_countries[source_country_name].add_connection(all_countries[destination_country_name])

func add_country_to_level(country):
	all_countries[country.country_name] = country

func connect_countries():
	phase = "connect countries"
	update_labels()

func change_to_change_curr_troops():
	phase = "change curr troops"
	update_labels()

func change_to_add_countries():
	phase = "add countries"
	update_labels()

func _input(event):
	if phase == "add countries":
		if event.is_pressed() and event.button_index == BUTTON_LEFT:
			var coordinate = get_global_mouse_position()
			# Dead zone for buttons
			if coordinate[0] < 150 and coordinate[1] < 100:
				return
			var new_country = Country.instance().init(coordinate[0], coordinate[1], hash(OS.get_system_time_msecs()))
			all_countries[new_country.country_name] =  new_country
			add_child(new_country)

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
