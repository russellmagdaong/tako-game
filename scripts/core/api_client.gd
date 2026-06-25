extends Node
# Autoload: ApiClient
#
# Coordinates AI requests for math question phrasing and encouraging feedback.
# Supports Ollama (local test-only), Google Gemini 1.5 Flash (online REST API),
# and Google Gemini Nano (offline on-device Android AICore).
#
# NOTE: The Ollama mode is strictly for local desktop testing and developer validation.
# It is completely bypassed in exported Android SDK builds in favor of Gemini Nano/Flash.

enum AiProvider {
	OLLAMA,
	GEMINI_1_5_FLASH,
	GEMINI_NANO
}

signal question_generated(data: Dictionary)
signal feedback_generated(data: Dictionary)
signal request_failed(tag: String, http_code: int)

const OLLAMA_URL := "http://localhost:11434"

@export var active_provider: AiProvider = AiProvider.OLLAMA
@export var gemini_api_key: String = ""
@export var gemini_nano_plugin_name: String = "GodotGeminiNano"
@export var ollama_model: String = "gemma3"

var _http: HTTPRequest
var _queue: Array[Dictionary] = []
var _busy: bool = false
var _current_tag: String = ""
var _nano_plugin: Object = null

func _ready() -> void:
	_load_env_file()
	_http = HTTPRequest.new()
	_http.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	
	# Detect and initialize the Android Gemini Nano JNI plugin
	if Engine.has_singleton(gemini_nano_plugin_name):
		_nano_plugin = Engine.get_singleton(gemini_nano_plugin_name)
		if _nano_plugin.has_signal("content_generated"):
			_nano_plugin.connect("content_generated", _on_nano_content_generated)
		if _nano_plugin.has_signal("generation_failed"):
			_nano_plugin.connect("generation_failed", _on_nano_generation_failed)
		GameLogger.info("ApiClient: Gemini Nano Android plugin singleton detected and connected.")
		
	GameLogger.info("AiClient ready — active provider: %s" % AiProvider.keys()[active_provider])

func _load_env_file() -> void:
	var path := "res://.env"
	if not FileAccess.file_exists(path):
		return
		
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
		
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.begins_with("GEMINI_API_KEY"):
			var parts := line.split("=", true, 1)
			if parts.size() > 1:
				var value := parts[1].strip_edges()
				# Remove potential outer quotes
				if (value.begins_with('"') and value.ends_with('"')) or (value.begins_with("'") and value.ends_with("'")):
					value = value.substr(1, value.length() - 2)
				gemini_api_key = value
				break

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func generate_question(skill_type: String, lang: String = "en") -> void:
	var prompt_instructions := MathManager.setup_new_question(skill_type, lang)
	if prompt_instructions.is_empty():
		GameLogger.error("ApiClient: Failed to set up math question.")
		return
		
	var lang_instruction := "Write the question and hint strictly in English."
	if lang == "tl":
		lang_instruction = "Write the question and hint strictly in Tagalog (Filipino)."
		
	var prompt := (
		"You are a friendly, in-character math companion.\n"
		+ "Based on these parameters, construct a short, fun math question:\n"
		+ "%s\n" % prompt_instructions
		+ lang_instruction + "\n"
		+ "Return ONLY valid JSON with exactly these two fields:\n"
		+ "{\"question\": \"the creative question text\", \"hint\": \"a helpful hint to guide them\"}"
	)
	_enqueue(prompt, "question_generate")

func generate_feedback(question: String, expected: String, player_answer: String, misconception: String = "", lang: String = "en") -> void:
	var lang_instruction := "Write the feedback strictly in English."
	if lang == "tl":
		lang_instruction = "Write the feedback strictly in Tagalog (Filipino)."
		
	var misconception_hint := ""
	if not misconception.is_empty():
		misconception_hint = "The student made a specific mistake categorized as: %s.\n" % misconception
		
	var prompt := (
		"A student answered a math question incorrectly in a game.\n"
		+ "Question: %s\n" % question
		+ "Correct answer: %s\n" % expected
		+ "Student's answer: %s\n" % player_answer
		+ misconception_hint
		+ "Write a short, encouraging message (1-2 sentences) explaining their mistake and guiding them to the correct method.\n"
		+ lang_instruction + "\n"
		+ "Return ONLY valid JSON: {\"feedback\": \"your message here\"}"
	)
	_enqueue(prompt, "feedback_generate")

# ---------------------------------------------------------------------------
# Queue
# ---------------------------------------------------------------------------

func _enqueue(prompt: String, tag: String) -> void:
	_queue.append({"prompt": prompt, "tag": tag})
	if not _busy:
		_flush()

func _flush() -> void:
	if _queue.is_empty():
		_busy = false
		return
	_busy = true
	var req: Dictionary = _queue.pop_front()
	_current_tag = req.tag
	var prompt: String = req.prompt
	
	match active_provider:
		AiProvider.OLLAMA:
			var payload := {
				"model": ollama_model,
				"prompt": prompt,
				"stream": false,
				"format": "json"
			}
			var body := JSON.stringify(payload)
			var headers: PackedStringArray = ["Content-Type: application/json"]
			var err := _http.request(OLLAMA_URL + "/api/generate", headers, HTTPClient.METHOD_POST, body)
			if err != OK:
				_handle_request_error(err)
				
		AiProvider.GEMINI_1_5_FLASH:
			if gemini_api_key.is_empty():
				GameLogger.error("AiClient: Gemini API Key is missing!")
				_handle_request_error(ERR_UNCONFIGURED)
				return
				
			var url := "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=" + gemini_api_key
			var payload := {
				"contents": [{
					"parts": [{"text": prompt}]
				}],
				"generationConfig": {
					"responseMimeType": "application/json"
				}
			}
			var body := JSON.stringify(payload)
			var headers: PackedStringArray = ["Content-Type: application/json"]
			var err := _http.request(url, headers, HTTPClient.METHOD_POST, body)
			if err != OK:
				_handle_request_error(err)
				
		AiProvider.GEMINI_NANO:
			if _nano_plugin == null:
				GameLogger.error("AiClient: Gemini Nano plugin is not available on this platform!")
				_handle_request_error(ERR_UNAVAILABLE)
				return
				
			# Trigger the native Android AICore JNI generator asynchronously
			_nano_plugin.call("generate_content", prompt)

func _handle_request_error(err: int) -> void:
	GameLogger.error("AiClient: request error %d for [%s]" % [err, _current_tag])
	request_failed.emit(_current_tag, err)
	_busy = false
	_flush()

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var tag := _current_tag
	_current_tag = ""
	_busy = false

	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		GameLogger.error("AiClient: HTTP result=%d code=%d tag=%s" % [result, response_code, tag])
		request_failed.emit(tag, response_code)
		_flush()
		return

	var text := body.get_string_from_utf8()
	var outer := JSON.new()
	if outer.parse(text) != OK or not outer.data is Dictionary:
		GameLogger.error("AiClient: outer JSON parse failed for tag=%s" % tag)
		request_failed.emit(tag, -1)
		_flush()
		return

	var outer_dict: Dictionary = outer.data
	var response_text := ""
	
	match active_provider:
		AiProvider.OLLAMA:
			response_text = outer_dict.get("response", "")
		AiProvider.GEMINI_1_5_FLASH:
			var candidates = outer_dict.get("candidates", [])
			if not candidates.is_empty() and candidates[0] is Dictionary:
				var content = candidates[0].get("content", {})
				if content is Dictionary:
					var parts = content.get("parts", [])
					if not parts.is_empty() and parts[0] is Dictionary:
						response_text = parts[0].get("text", "")

	var inner := JSON.new()
	var data: Dictionary = {}
	if inner.parse(response_text) == OK and inner.data is Dictionary:
		data = inner.data
	else:
		GameLogger.error("AiClient: inner JSON parse failed for tag=%s. Raw text: %s" % [tag, response_text])
		request_failed.emit(tag, -1)
		_flush()
		return

	GameLogger.info("AiClient: response tag=%s" % tag)
	match tag:
		"question_generate":
			question_generated.emit(data)
		"feedback_generate":
			feedback_generated.emit(data)

	_flush()

# ---------------------------------------------------------------------------
# Android Native Gemini Nano JNI Callbacks
# ---------------------------------------------------------------------------

func _on_nano_content_generated(response_text: String) -> void:
	var tag := _current_tag
	_current_tag = ""
	_busy = false
	
	var inner := JSON.new()
	var data: Dictionary = {}
	if inner.parse(response_text) == OK and inner.data is Dictionary:
		data = inner.data
	else:
		GameLogger.error("AiClient (Nano): inner JSON parse failed for tag=%s. Raw: %s" % [tag, response_text])
		request_failed.emit(tag, -1)
		_flush()
		return
		
	GameLogger.info("AiClient (Nano): response tag=%s" % tag)
	match tag:
		"question_generate":
			question_generated.emit(data)
		"feedback_generate":
			feedback_generated.emit(data)
			
	_flush()

func _on_nano_generation_failed(error_message: String) -> void:
	var tag := _current_tag
	_current_tag = ""
	_busy = false
	GameLogger.error("AiClient (Nano) Error: %s for tag=%s" % [error_message, tag])
	request_failed.emit(tag, -2)
	_flush()
