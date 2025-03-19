extends Control

var item_res: PackedScene = preload("res://item.tscn");

# Text Edit Items
@onready var item_container: VBoxContainer = $"Main View Split/Nav/Scroll View/List of notes";
@onready var text_box: TextEdit = $"Main View Split/Notes/TextEdit";
@onready var save_button: Button = $"Main View Split/Notes/Save";

# Encryption Items
@onready var encryption_msg: Label = $"Main View Split/Notes/EncryptionMsg";
@onready var encryption_desc: Label = $"Main View Split/Notes/EncryptionDesc";
@onready var password: LineEdit = $"Main View Split/Notes/Password";
@onready var decrypt_button: Button = $"Main View Split/Notes/Decrypt";

const NOTES_LIST_URL: String = "https://api.serble.net/api/v1/vault/notes";
const ENCRYPTION_HEADER: String = "------BEGIN ENCRYPTED NOTE-----\n";
var serble_auth_header_list = ["SerbleAuth: User " + Global.access_token];

var current_note_id: String;

var contents: Dictionary = { };
var item_objects: Dictionary = { };
var passwords: Dictionary = { };
var encryptedness: Dictionary = { };

var config: ConfigFile;

func _ready():
	# Load saved passwords for notes
	config = ConfigFile.new();
	config.load("user://notes.cfg");
	var keys: PackedStringArray = config.get_section_keys("passwords");
	for key in keys:
		passwords[key] = config.get_value("passwords", key);
	
	Global.http_req(recieved_notes_list, NOTES_LIST_URL, HTTPClient.METHOD_GET, "", serble_auth_header_list);


func set_password(id: String, pw: String):
	passwords[id] = pw;
	config.set_value("passwords", id, pw);
	config.save("user://notes.cfg");


func recieved_notes_list(result: int, response_code: int, headers: PackedStringArray, body: String):
	if response_code != 200:
		# give up
		return;
	var note_ids: Array = JSON.parse_string(body);
	for note in note_ids:
		Global.http_req(recieved_content.bind(note, false), NOTES_LIST_URL + "/" + note, HTTPClient.METHOD_GET, "", serble_auth_header_list);


func recieved_content(result: int, response_code: int, headers: PackedStringArray, body: String, note_id: String, activate: bool):
	if response_code != 200:
		# BRUH
		return;
	
	var item = item_res.instantiate();
	item_container.add_child(item);
	
	item.pressed.connect(select_note.bind(note_id));
	item.get_node("HBoxContainer/Delete").pressed.connect(delete_note.bind(note_id));
	contents[note_id] = body;
	print("Note added to list with body: " + body);
	item_objects[note_id] = item;
	
	update_item_info(note_id);
	if activate:
		select_note(note_id);


func select_note(id: String):
	var text: String = contents[id];
	
	if passwords.has(id) && encryptedness[id]:
		# Decrypt
		var encryption_class = load("res://encryption.cs");
		var encryption = encryption_class.new();
		var pt = encryption.Decrypt(text.replace(ENCRYPTION_HEADER, ""), passwords[id]);
		if pt != null:
			text = pt;  # Valid
		else:
			# Bad password
			passwords.erase(id);
	
	text_box.text = text;
	
	set_mode_notes(!encryptedness[id] || passwords.has(id));  # Change display to encryption
	
	current_note_id = id;


func update_item_info(id: String):
	var body: String = contents[id];
	var item = item_objects[id];
	
	var is_empty = body == "";
	var is_encrypted = body.begins_with(ENCRYPTION_HEADER);
	encryptedness[id] = is_encrypted;
	
	var text = body;
	if is_encrypted && passwords.has(id):
		print("Is encrypted and has password");
		var ct: String = body.replace(ENCRYPTION_HEADER, "");
		var password: String = passwords[id];
		var encryption_class = load("res://encryption.cs");
		var encryption = encryption_class.new();
		var pt = encryption.Decrypt(ct, password);
		if pt == null:
			# It failed
			printerr("Decryption FAILED with password: " + password);
		else:
			text = pt;
	elif is_encrypted:
		# We don't have the password to decrypt it
		print("Is encrypted and we don't have password");
		text = "ENCRYPTED NOTE\nClick to decrypt.";
	else:
		print("Is not encrypted");
	
	var title;
	var desc;
	if is_empty:
		title = id;
		desc = "Empty note";
	else:
		var parts = text.split("\n", false, 1);
		title = parts[0];
		desc = text.substr(title.length(), 100);
		desc = desc.replace("\n", " ");
	
	var oldLen: int = title.length();
	title = title.substr(0, 26);
	if oldLen > title.length():
		title += "...";
		
	item.get_node("HBoxContainer/MarginContainer/VBoxContainer/Title").text = title;
	item.get_node("HBoxContainer/MarginContainer/VBoxContainer/Desc").text = desc;
	print(id + " was updated");
	print("Title: " + title);


func _on_save_pressed():
	var text: String = text_box.text;
	if encryptedness[current_note_id]:
		# Encrypt the text
		print("Saving encrypted note");
		var encryption_class = load("res://encryption.cs");
		var encryption = encryption_class.new();
		text = ENCRYPTION_HEADER + encryption.Encrypt(text, passwords[current_note_id]);
	else:
		print("Saving plaintext note");
	var singleArray: String = JSON.stringify([text]);
	var jsonBody: String = singleArray.substr(1, singleArray.length() - 2);
	print("Writing text to note: " + text);
	Global.http_req(Global.recieve_ignore, NOTES_LIST_URL + "/" + current_note_id, HTTPClient.METHOD_PUT, jsonBody, serble_auth_header_list);
	contents[current_note_id] = text;
	update_item_info(current_note_id);


func delete_note(id: String):
	Global.http_req(Global.recieve_ignore, NOTES_LIST_URL + "/" + id, HTTPClient.METHOD_DELETE, "", serble_auth_header_list);
	item_objects[id].queue_free();
	item_objects.erase(id);


func create_note(encrypted: bool):
	# First off just create any note
	Global.http_req(note_created.bind(encrypted), NOTES_LIST_URL, HTTPClient.METHOD_POST, "{}", serble_auth_header_list);


func note_created(result: int, response_code: int, headers: PackedStringArray, body: String, encrypted: bool):
	if response_code != 200:
		printerr("Failed to create note");
		printerr(response_code);
		print(body);
		return;
	var responseJson: Dictionary = JSON.parse_string(body);
	var note_id: String = responseJson.note_id;
	
	if encrypted:
		var singleArray: String = JSON.stringify([ENCRYPTION_HEADER]);
		var jsonBody: String = singleArray.substr(1, singleArray.length() - 2);
		Global.http_req(encryption_header_added.bind(note_id), NOTES_LIST_URL + "/" + note_id, HTTPClient.METHOD_PUT, jsonBody, serble_auth_header_list);
		return;
	
	encryption_header_added(0, 0, [], "", note_id);


func encryption_header_added(result: int, response_code: int, headers: PackedStringArray, body: String, note_id: String):
	Global.http_req(recieved_content.bind(note_id, true), NOTES_LIST_URL + "/" + note_id, HTTPClient.METHOD_GET, "", serble_auth_header_list);


func _on_new_encrypted_note_pressed():
	create_note(true);


func _on_new_note_pressed():
	create_note(false);


func set_mode_notes(mode: bool):
	# Notes
	text_box.visible = mode;
	save_button.visible = mode;
	
	# Encryption
	encryption_msg.visible = !mode;
	encryption_desc.visible = !mode;
	password.visible = !mode;
	decrypt_button.visible = !mode;


func _on_decrypt_pressed():
	var id: String = current_note_id;
	var is_setup: bool = contents[id] == ENCRYPTION_HEADER; # True means its setup
	set_password(id, password.text);
	if is_setup:
		text_box.text = "Welcome to your encrypted note!";
		_on_save_pressed();  # Trigger a save on the dummy text
		select_note(id);
		return;
	# Note needs to be decrypted
	# Reload it because the password has been set
	update_item_info(id);
	select_note(id);


func _on_logout_pressed():
	var config: ConfigFile = ConfigFile.new();
	config.load("user://login.cfg");
	config.erase_section_key("login", "access_token");
	config.save("user://login.cfg");
	get_tree().change_scene_to_file("res://login.tscn");
