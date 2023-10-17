extends Control

@onready var password_edit: LineEdit = $CenterContainer/VBoxContainer/Password;
@onready var error_msg: Label = $CenterContainer/VBoxContainer/Error;

const MFA_SUBMIT_URL: String = "https://api.serble.net/api/v1/account/mfa"


# Submit code
func _on_button_pressed():
	var body = {
		login_token = Global.mfa_token,
		totp_code = password_edit.text
	};
	Global.http_req(mfa_callback, MFA_SUBMIT_URL, HTTPClient.METHOD_POST, JSON.stringify(body), []);


func mfa_callback(result: int, response_code: int, headers: PackedStringArray, body: String):
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
				error_msg_str = "Invalid Code";
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
	Global.access_token = response.token;
	
	# Success, attempt to save token
	var config: ConfigFile = ConfigFile.new();
	config.set_value("login", "access_token", Global.access_token);
	config.save("user://login.cfg");
	
	get_tree().change_scene_to_file("res://notes.tscn");
