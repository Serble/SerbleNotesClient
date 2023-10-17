extends Control

@onready var username_edit: LineEdit = $CenterContainer/VBoxContainer/Username;
@onready var password_edit: LineEdit = $CenterContainer/VBoxContainer/Password;
@onready var error_msg: Label = $CenterContainer/VBoxContainer/Error;

const AUTH_URL: String = "https://api.serble.net/api/v1/auth";
const ACCOUNT_URL: String = "https://api.serble.net/api/v1/account";

func _ready():
	# Encryption tests
	# If these fail then something is wrong with the encryption algorithm
	var my_csharp_script = load("res://encryption.cs");
	var encryption = my_csharp_script.new();
	var encr: String = encryption.Encrypt("a", "a");
	print("Result: " + encr);
	
	var decr: String = encryption.Decrypt(encr, "a");
	print("Decr: " + decr);
	
	var testDecr: String = encryption.Decrypt("e0940b55bfde9594cf96e45e2tS1pViZpotPS7pHJ3vzjm8=", "a");
	print("TEST (b): " + testDecr);
	
	# Look for saved token
	var config: ConfigFile = ConfigFile.new();
	config.load("user://login.cfg");
	var token = config.get_value("login", "access_token");
	if token == null:
		return;
	
	# Check token to see if it's valid
	Global.http_req(token_check_callback.bind(token), ACCOUNT_URL, HTTPClient.METHOD_GET, "", ["SerbleAuth: User " + token]);


func token_check_callback(result: int, response_code: int, headers: PackedStringArray, body: String, token: String):
	if response_code != 200:
		return;
	
	# Token was valid
	Global.access_token = token;
	get_tree().change_scene_to_file("res://notes.tscn");


func _on_button_pressed():
	var username: String = username_edit.text;
	var password: String = password_edit.text;
	
	var base64_compiled: String = Marshalls.utf8_to_base64(username + ":" + password);
	
	Global.http_req(login_callback, AUTH_URL, HTTPClient.METHOD_GET, "", ["Authorization: Basic " + base64_compiled]);


func login_callback(result: int, response_code: int, headers: PackedStringArray, body: String):
	if response_code != 200:
		# oh no
		printerr("login failed");
		print(body);
		var response_code_str: String = str(response_code);
		var error_msg_str: String;
		match response_code_str[0]:
			"1":
				error_msg_str = "UMMM, WHAT THE FUCK";
			"2":
				error_msg_str = "Task failed sucessfully";
			"3":
				error_msg_str = "Recived redirect from login";
			"4":
				error_msg_str = "Invalid Credentials";
			"5":
				error_msg_str = "Server Offline";
			_:
				error_msg_str = "Server is brain dead";
		error_msg.text = error_msg_str;
		return;
	var response: Dictionary = JSON.parse_string(body);
	if !response.success:
		# wtf
		printerr("waddafuck");
		return;
	if response.mfa_required:
		Global.mfa_token = response.mfa_token;
		get_tree().change_scene_to_file("res://mfa.tscn");
		return;
	Global.access_token = response.token;
	
	# Success, attempt to save token
	var config: ConfigFile = ConfigFile.new();
	config.set_value("login", "access_token", Global.access_token);
	config.save("user://login.cfg");
	
	get_tree().change_scene_to_file("res://notes.tscn");
