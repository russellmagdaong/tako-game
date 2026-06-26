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
@export var gemini_model: String = "gemini-2.5-flash"
@export var gemini_nano_plugin_name: String = "GodotGeminiNano"
@export var ollama_model: String = "gemma3"

var _http: HTTPRequest
var _queue: Array[Dictionary] = []
var _busy: bool = false
var _current_tag: String = ""
var _current_prompt: String = ""
var _nano_plugin: Object = null

# Gemini API key pool with automatic failover. When a key hits its daily quota
# (HTTP 429 / 403), the client rotates to the next key and retries the same
# request. Only when ALL keys are exhausted does it fall back to static templates.
var _gemini_keys: PackedStringArray = []
var _key_index: int = 0
var _rotations_this_request: int = 0

func _ready() -> void:
	_load_ai_config()
	_http = HTTPRequest.new()
	_http.process_mode = Node.PROCESS_MODE_ALWAYS
	_http.timeout = 20.0 # fall back to templates if the AI call stalls
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	
	# Detect and initialize the Android Gemini Nano JNI plugin
	if Engine.has_singleton(gemini_nano_plugin_name):
		_nano_plugin = Engine.get_singleton(gemini_nano_plugin_name)
		if _nano_plugin.has_signal("content_generated"):
			_nano_plugin.connect("content_generated", _on_nano_content_generated)
		if _nano_plugin.has_signal("generation_failed"):
			_nano_plugin.connect("generation_failed", _on_nano_generation_failed)
		active_provider = AiProvider.GEMINI_NANO
		GameLogger.info("ApiClient: Gemini Nano Android plugin singleton detected and connected. Switched provider to GEMINI_NANO.")
		
	GameLogger.info("AiClient ready — active provider: %s" % AiProvider.keys()[active_provider])

func _load_ai_config() -> void:
	# Project settings take priority because they are bundled into exported
	# Android/desktop builds; res://.env is only a developer-machine fallback.
	var model := str(ProjectSettings.get_setting("tako/gemini/model", "")).strip_edges()
	if not model.is_empty():
		gemini_model = model

	# Build the Gemini API key pool from all available sources (deduped).
	_gemini_keys = _load_gemini_keys()
	_key_index = 0
	if not _gemini_keys.is_empty():
		gemini_api_key = _gemini_keys[0]
		# Prefer the on-device Nano plugin when present; otherwise use Flash REST.
		if not Engine.has_singleton(gemini_nano_plugin_name):
			active_provider = AiProvider.GEMINI_1_5_FLASH
		GameLogger.info("ApiClient: Loaded %d Gemini key(s) for failover." % _gemini_keys.size())

# Collects Gemini keys from every source, in priority order, deduped:
#   1. project setting (tako/gemini/api_key)
#   2. res://scripts/core/secrets.gd  (GEMINI_API_KEYS array preferred, else GEMINI_API_KEY)
#   3. res://.env  (GEMINI_API_KEY)
func _load_gemini_keys() -> PackedStringArray:
	var raw: PackedStringArray = []
	var ps := str(ProjectSettings.get_setting("tako/gemini/api_key", "")).strip_edges()
	if not ps.is_empty():
		raw.append(ps)
	raw.append_array(_read_secret_keys())
	var env_key := _read_env_gemini_key()
	if not env_key.is_empty():
		raw.append(env_key)

	var seen := {}
	var out: PackedStringArray = []
	for k in raw:
		var key := str(k).strip_edges()
		if key.is_empty() or key.begins_with("PASTE"):
			continue
		if seen.has(key):
			continue
		seen[key] = true
		out.append(key)
	return out

func _read_secret_keys() -> PackedStringArray:
	var out: PackedStringArray = []
	var path := "res://scripts/core/secrets.gd"
	if not ResourceLoader.exists(path):
		return out
	var s = load(path)
	if not (s is GDScript):
		return out
	var consts: Dictionary = s.get_script_constant_map()
	if consts.has("GEMINI_API_KEYS"):
		for k in consts["GEMINI_API_KEYS"]:
			out.append(str(k))
	elif consts.has("GEMINI_API_KEY"):
		out.append(str(consts["GEMINI_API_KEY"]))
	return out

func _read_env_gemini_key() -> String:
	var path := "res://.env"
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.begins_with("GEMINI_API_KEY"):
			var parts := line.split("=", true, 1)
			if parts.size() > 1:
				var value := parts[1].strip_edges()
				if (value.begins_with('"') and value.ends_with('"')) or (value.begins_with("'") and value.ends_with("'")):
					value = value.substr(1, value.length() - 2)
				return value
	return ""

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
		"You are a creative, friendly math companion.\n"
		+ "Your task is to transform the mathematical base specifications below into a fun, uniquely structured math question. Do NOT repeat the same sentence patterns. Mix up the phrasings extensively: sometimes use direct questions (e.g. 'Solve this:', 'Evaluate the expression:', 'Find the sum of:', 'What is the value of:', etc.), sometimes write story-driven word problems, and sometimes write a short dialogue with a character asking the player. Avoid rigid formats.\n"
		+ "Base specifications:\n"
		+ "%s\n" % prompt_instructions
		+ lang_instruction + "\n"
		+ "Return ONLY valid JSON with exactly these two fields:\n"
		+ "{\"question\": \"your creative, uniquely phrased and structured math question\", \"hint\": \"a helpful hint to guide them\"}"
	)
	_enqueue(prompt, "question_generate")

func generate_feedback(question: String, expected: String, player_answer: String, misconception: String = "", lang: String = "en", attempt: int = 1) -> void:
	var lang_instruction := "Write the feedback strictly in English."
	if lang == "tl":
		lang_instruction = "Write the feedback strictly in Tagalog (Filipino)."

	var misconception_hint := ""
	if not misconception.is_empty():
		var desc_dict = MathManager.get_static_fallback_feedback(misconception, lang)
		var desc = desc_dict.get("feedback", "")
		misconception_hint = "Likely misconception: \"%s\".\n" % desc

	# Escalate guidance with each failed attempt so feedback feels responsive,
	# not repetitive, and reacts to the player's actual answer.
	var attempt_instruction := ""
	if attempt <= 1:
		attempt_instruction = "This is their first attempt. Briefly point out, based on their specific answer, where their reasoning likely went wrong and nudge them toward the right approach.\n"
	elif attempt == 2:
		attempt_instruction = "This is their SECOND attempt and they are still stuck. Do not repeat generic advice — analyse what their answer of '%s' shows about their thinking and walk them through the FIRST concrete step of the correct method.\n" % player_answer
	else:
		attempt_instruction = "This is attempt #%d and they keep struggling. Be very concrete: react to their answer '%s', name the specific operation or step they should do next, and strongly encourage them. Still do NOT state the final answer.\n" % [attempt, player_answer]

	var prompt := (
		"A student answered a math question incorrectly in a game.\n"
		+ "Question: %s\n" % question
		+ "Correct answer (do NOT reveal it): %s\n" % expected
		+ "Student's answer: %s\n" % player_answer
		+ misconception_hint
		+ attempt_instruction
		+ "Write a short, warm, specific message (1-2 sentences) that clearly reacts to THIS student's answer. Vary your wording each time.\n"
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
	_current_prompt = req.prompt
	_rotations_this_request = 0
	_dispatch()

# Sends the current request (_current_prompt / _current_tag) to the active
# provider. Called both for fresh requests and for key-rotation retries.
func _dispatch() -> void:
	var prompt := _current_prompt

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
			if _gemini_keys.is_empty():
				GameLogger.error("AiClient: No Gemini API key configured!")
				_handle_request_error(ERR_UNCONFIGURED)
				return

			gemini_api_key = _gemini_keys[_key_index]
			var url := "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=%s" % [gemini_model, gemini_api_key]
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
	GameLogger.warning("AiClient: Request error %d for [%s]. Attempting local fallback..." % [err, _current_tag])
	if _generate_local_fallback(_current_tag):
		_current_tag = ""
		_busy = false
		_flush()
		return

	GameLogger.error("AiClient: request error %d for [%s]" % [err, _current_tag])
	request_failed.emit(_current_tag, err)
	_busy = false
	_flush()

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var tag := _current_tag
	_current_tag = ""
	_busy = false

	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		# Quota / rate-limit hit: rotate to the next Gemini key and retry the same
		# request before giving up. 429 = quota exceeded, 403 = often RESOURCE_EXHAUSTED.
		if active_provider == AiProvider.GEMINI_1_5_FLASH \
				and (response_code == 429 or response_code == 403) \
				and _gemini_keys.size() > 1 \
				and _rotations_this_request < _gemini_keys.size() - 1:
			_key_index = (_key_index + 1) % _gemini_keys.size()
			_rotations_this_request += 1
			GameLogger.warning("AiClient: Gemini key quota hit (code %d). Rotating to key #%d/%d and retrying." % [response_code, _key_index + 1, _gemini_keys.size()])
			_current_tag = tag
			_busy = true
			_dispatch()
			return

		GameLogger.warning("AiClient: HTTP result=%d code=%d tag=%s. Attempting local fallback..." % [result, response_code, tag])
		if _generate_local_fallback(tag):
			_flush()
			return
		GameLogger.error("AiClient: HTTP result=%d code=%d tag=%s" % [result, response_code, tag])
		request_failed.emit(tag, response_code)
		_flush()
		return

	var text := body.get_string_from_utf8()
	var outer := JSON.new()
	if outer.parse(text) != OK or not outer.data is Dictionary:
		GameLogger.warning("AiClient: outer JSON parse failed for tag=%s. Attempting local fallback..." % tag)
		if _generate_local_fallback(tag):
			_flush()
			return
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
		GameLogger.warning("AiClient: inner JSON parse failed for tag=%s. Attempting local fallback... Raw: %s" % [tag, response_text])
		if _generate_local_fallback(tag):
			_flush()
			return
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
		GameLogger.warning("AiClient (Nano): inner JSON parse failed for tag=%s. Attempting local fallback... Raw: %s" % [tag, response_text])
		if _generate_local_fallback(tag):
			_flush()
			return
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
	GameLogger.warning("AiClient (Nano) Error: %s for tag=%s. Attempting local fallback..." % [error_message, tag])
	if _generate_local_fallback(tag):
		_flush()
		return
	GameLogger.error("AiClient (Nano) Error: %s for tag=%s" % [error_message, tag])
	request_failed.emit(tag, -2)
	_flush()

# Generates static fallback content in GDScript.
func _generate_local_fallback(tag: String) -> bool:
	match tag:
		"question_generate":
			var data = MathManager.get_static_fallback_question(Globals.preferred_language)
			GameLogger.info("ApiClient: Generated local fallback question successfully.")
			question_generated.emit(data)
			return true
		"feedback_generate":
			var data = MathManager.get_static_fallback_feedback(MathManager.last_misconception, Globals.preferred_language)
			GameLogger.info("ApiClient: Generated local fallback feedback successfully.")
			feedback_generated.emit(data)
			return true
	return false
