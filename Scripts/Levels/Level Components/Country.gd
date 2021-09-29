extends Area2D

var num_troops: int = 0
var belongs_to = null
var connected_countries = []
var country_name = null
var Game_Manager = null

# This is so during reinforcement the label can show up as
# {num_troops} + {num_reinforcements}
var num_reinforcements: int = 0

var flashing = false
var time_since_last_flash = 0
const flashing_period = 0.5
var mask_sprites = {}

# List of locations to move to to complete the attack animation.
const destination_movement_duration = 0.2
const origin_movement_duration = 0.4

func save():
	var save_dict = {}
	save_dict["name"] = country_name
	save_dict["troops"] = num_troops
	save_dict["x"] = position[0]
	save_dict["y"] = position[1]
	save_dict["connections"] = []
	for country in connected_countries:
		save_dict["connections"].append(country.country_name)
	return save_dict

var colors = {"blue": load("res://Assets/blue-square.svg"), 
				"red": load("res://Assets/red-pentagon.svg"),
				"gray": load("res://Assets/neutral-circle.svg")}

func change_color_to(color):
	get_node("Sprite").texture = colors[color]
	get_node("Reinforcements/Sprite").texture = colors[color]
	create_mask_sprite("color_mask")

# Called when the node enters the scene tree for the first time.
func _ready():
	Game_Manager = get_parent()
	change_color_to(belongs_to.color)

func change_ownership_to(player):
	# Transfer of Ownership
	belongs_to.owned_countries.erase(self)
	belongs_to = player
	player.owned_countries.append(self)
	
	# Visual Update
	if Game_Manager:
		Game_Manager.update_labels()
	change_color_to(player.color)

func update_labels():
	get_node("Units").text = str(num_troops)
	if num_reinforcements > 0:
		get_node("Reinforcements").visible = true
		get_node("Reinforcements/Label").text = "+" + str(num_reinforcements)
	else:
		get_node("Reinforcements").visible = false
	if Game_Manager:
		Game_Manager.update_labels()

func flash_attackable_neighbours(player_color):
	# Creation of a mask sprite to do the flashing
	for country in connected_countries:
		if not ('flash_mask' in country.mask_sprites):
			print(str(country.create_mask_sprite("flash_mask")) + "ms")
	
	# Flash all countries that are not owned by the provided player
	for country in connected_countries:
		if country.belongs_to.color != player_color:
			country.flashing = true

func draw_line_to_country(selected_country):
	var new_line = Line2D.new()
	add_child(new_line)
	new_line.add_point(Vector2(20,20))
	new_line.add_point(selected_country.position - position + Vector2(20,20))

func get_attackable_countries():
	var attackable_countries = []
	for country in connected_countries:
		if country.num_troops < num_troops and country.belongs_to != belongs_to:
			attackable_countries.append(country)
	return attackable_countries

func _input_event(viewport, event, shape_idx):
	if get_tree().get_current_scene().get_name() == "Level Creator":
		if event.is_pressed():
			self.on_click(event)

func move_to_location_with_duration(location, duration):
	get_node("Tween").interpolate_property(self, "position", position, location, duration)

# Moving to a country and back
func move_to_country(destination_country):
	move_to_location_with_duration(destination_country.position, destination_movement_duration)
	get_node("Tween").interpolate_callback(self, destination_movement_duration, "move_to_location_with_duration", position, origin_movement_duration)
	get_node("Tween").start()

func on_click(event):	
	# Level Creator Behaviour
	if get_tree().get_current_scene().get_name() == "Level Creator":
		match Game_Manager.phase:
			"change curr troops":
				match event.button_index:
					BUTTON_LEFT:
						num_troops += 1
					BUTTON_RIGHT:
						num_troops -=1
			
			"add countries":
				# Country deletion
				if event.button_index == BUTTON_RIGHT:
					Game_Manager.all_countries.erase(country_name)
					for country in connected_countries:
						print(country.name)
						country.connected_countries.erase(self)
					queue_free()
			
			"connect countries":
				if Game_Manager.selected_country == null:
					Game_Manager.selected_country = self
				elif Game_Manager.selected_country != self:
					connected_countries.append(Game_Manager.selected_country)
					Game_Manager.selected_country.connected_countries.append(self)
					if Game_Manager.lines_drawn:
						draw_line_to_country(Game_Manager.selected_country)
					Game_Manager.selected_country = null
			
			"move countries":
				Game_Manager.selected_country = self
			
			"add color to country":
				var color = str(Game_Manager.get_color_in_mask())
				for country in connected_countries:
					for i in len(country.connected_countries):
						if str(country.connected_countries[i].country_name) == str(country_name):
							country.connected_countries[i].country_name = color
				country_name = color
		
		update_labels()
		return
	
	# In Game Behaviour
	
	# Don't do anything in multiplayer mode if the player of this game instance isn't the curr player
	if Game_Manager._root.online_game:
		print(Game_Manager.curr_player.network_id)
		print(Game_Manager._root.players[Game_Manager._root.player_name])
		if Game_Manager.curr_player.network_id != Game_Manager._root.players[Game_Manager._root.player_name]:
			return
	
	Game_Manager.stop_flashing()
	
	# Do nothing if the game hasn't started
	if not Game_Manager.game_started:
		return
	
	# Deselecting behaviour
	if Game_Manager.selected_country == self:
		Game_Manager.selected_country = null
		return
	
	match Game_Manager.phase:
		"attack":
			if belongs_to != Game_Manager.curr_player:
				# Checking if there was a previous country selection
				if Game_Manager.selected_country != null:
					# And if it is a neighbour and the attacker has sufficient troops, then attack
					var attacker = Game_Manager.selected_country
					var defender = belongs_to
					if (attacker in connected_countries) and (attacker.num_troops > num_troops):
						# Attack logic that changes troops and updates labels
						num_troops = attacker.num_troops - num_troops
						attacker.num_troops = 1
						update_labels()
						attacker.update_labels()
						change_ownership_to(attacker.belongs_to)
						Game_Manager.selected_country = null
						
						# Movement animation
						Game_Manager.move_country_across_network(attacker.country_name, country_name)
						
						# Phase change
						if Game_Manager.is_attack_over():
							Game_Manager.change_to_reinforcement()
						# Check if the opponent has any troops left
						if Game_Manager.get_next_player().get_num_troops() == 0:
							Game_Manager.end_game(defender.color)
			else:
				print("flashing")
				Game_Manager.selected_country = self
				Game_Manager.flash_across_network(Game_Manager.curr_player.color, country_name)

		"reinforcement":
			if belongs_to == Game_Manager.curr_player:
				# Add a reinforcement
				if event.button_index == BUTTON_LEFT:
					# Check that the player has reinforcements available to allocate
					if Game_Manager.curr_player.num_reinforcements > 0:
						Game_Manager.curr_player.num_reinforcements -= 1
						num_reinforcements += 1
				# Remove a reinforcement
				if event.button_index == BUTTON_RIGHT:
					# Check that a reinforcement has been previously added to this country
					if num_reinforcements > 0:
						num_reinforcements -= 1
						Game_Manager.curr_player.num_reinforcements += 1
				
				update_labels()
				Game_Manager.update_labels()
			pass
		
		"game over":
			pass

func add_connection(country):
	connected_countries.append(country)

# Randomise num_troops
func randomise_troops():
	# Distribution 1: 0.5, 2: 0.3, 3: 0.1, 4: 0.1
	# TODO, HAVE A STATIC GLOBAL rng
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var rand_num = rng.randf_range(0,10)
	if rand_num < 5:
		num_troops = 1
	elif rand_num < 8:
		num_troops = 2
	elif rand_num < 9:
		num_troops = 3
	elif rand_num < 10:
		num_troops = 4
	update_labels()

func init(_x, _y, _country_name, player):
	self.belongs_to = player
	position = Vector2(_x, _y)
	self.country_name = _country_name
	randomise_troops()
	update_labels()
	return self

func stop_flashing():
	if 'flash_mask' in mask_sprites:
		mask_sprites['flash_mask'].visible = false
	get_node("Sprite").modulate = Color(1,1,1)
	time_since_last_flash = 0
	self.flashing = false

# Synchronise the country over network
func synchronise(_num_troops, _num_reinforcements, _belongs_to):
	num_troops = _num_troops
	num_reinforcements = _num_reinforcements
	if belongs_to != _belongs_to:
		change_ownership_to(_belongs_to)
	update_labels()

func create_mask_sprite(type):
	# Measuring performance
	var time_start = OS.get_ticks_msec()
	
	# Creating a sprite that contains the world's mask texture and add it to level
	var mask_sprite = Sprite.new()
	mask_sprite.centered = false
	var tex = ImageTexture.new()
	tex.create_from_image(Game_Manager.world_mask)
	mask_sprite.texture = tex
	Game_Manager.add_child(mask_sprite)

	# Changing the select country to white and everything else to transparent
	var flash_shader = Game_Manager.flash_shader.duplicate()
	flash_shader.set_shader_param("u_color_key", Color(country_name))
	match type:
		"flash_mask":
			flash_shader.set_shader_param("u_highlight_color", Color8(255,255,255,255))
			mask_sprite.visible = false
			mask_sprite.z_index = 4
		"color_mask":
			mask_sprite.z_index = 3
			match belongs_to.color:
				"blue":
					flash_shader.set_shader_param("u_highlight_color", Color8(70,70,185,255))
				"red":
					flash_shader.set_shader_param("u_highlight_color", Color8(195,60,60,255))
				"gray":
					flash_shader.set_shader_param("u_highlight_color", Color8(165,165,165,255))
	flash_shader.set_shader_param("u_background_color", Color8(0,0,0,0))
	mask_sprite.set_material(flash_shader)
	
	# Scale after the shader has run to avoid AA issues
	mask_sprite.set_scale(Vector2(1/Game_Manager.scale_ratio,1/Game_Manager.scale_ratio))
	mask_sprites[type] = mask_sprite
	
	# Measuring performance
	var time_taken = OS.get_ticks_msec() - time_start
	return time_taken

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if flashing:
		time_since_last_flash += delta
		if time_since_last_flash > flashing_period:
			if "flash_mask" in mask_sprites:
				mask_sprites['flash_mask'].visible = !mask_sprites['flash_mask'].visible
			
			#Flashing the country sprite
			if get_node("Sprite").modulate == Color(1,1,1):
				get_node("Sprite").modulate = Color(0.5,0.5,0.5)
			else:
				get_node("Sprite").modulate = Color(1,1,1)
			time_since_last_flash = 0
