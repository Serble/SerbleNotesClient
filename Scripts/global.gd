extends Node

var access_token: String;
var mfa_token: String;

# recieved params: result: int, response_code: int, headers: PackedStringArray, body: String
func http_req(recieved: Callable, url: String, method: HTTPClient.Method, request_data: String = "", headers: PackedStringArray = PackedStringArray(), is_string: bool = true):
	var req: HTTPRequest = HTTPRequest.new();
	req.request_completed.connect(func req_process(result: int, response_code: int, out_headers: PackedStringArray, body: PackedByteArray):
		var body_formatted;
		if is_string:
			body_formatted = body.get_string_from_utf8();
		
		recieved.call(result, response_code, out_headers, body_formatted);
		req.queue_free();
	)
	
	# If content-type isnt defined, default to json
	var add_type := true;
	for header in headers:
		if header.begins_with("Content-Type:"):
			add_type = false;
			break;
	
	if add_type:
		headers.append("Content-Type:application/json");
	
	add_child(req);
	req.request(url, headers, method, request_data);

func recieve_ignore(result: int, response_code: int, headers: PackedStringArray, body: String):
	pass;
