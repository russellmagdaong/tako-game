extends Node
# Autoload: ApiClient
#
# Communicates with a local Ollama instance to generate math questions and feedback.
# Requires Ollama running at http://localhost:11434 with a compatible model installed.
# Change `model` to whichever model you have (e.g. "llama3.2", "phi3", "gemma3").

signal question_generated(data: Dictionary)
signal feedback_generated(data: Dictionary)
signal request_failed(tag: String, http_code: int)

const OLLAMA_URL := "http://localhost:11434"
var model: String = "gemma3"

var _http: HTTPRequest
var _queue: Array[Dictionary] = []
var _busy: bool = false
var _current_tag: String = ""

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	GameLogger.info("AiClient ready — model: %s  url: %s" % [model, OLLAMA_URL])

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
	_enqueue({"model": model, "prompt": prompt, "stream": false, "format": "json"}, "question_generate")

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
	_enqueue({"model": model, "prompt": prompt, "stream": false, "format": "json"}, "feedback_generate")

# ---------------------------------------------------------------------------
# Queue
# ---------------------------------------------------------------------------

func _enqueue(payload: Dictionary, tag: String) -> void:
	_queue.append({"payload": payload, "tag": tag})
	if not _busy:
		_flush()

func _flush() -> void:
	if _queue.is_empty():
		_busy = false
		return
	_busy = true
	var req: Dictionary = _queue.pop_front()
	_current_tag = req.tag
	var body := JSON.stringify(req.payload)
	var headers: PackedStringArray = ["Content-Type: application/json"]
	var err := _http.request(OLLAMA_URL + "/api/generate", headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		GameLogger.error("AiClient: request error %d for [%s]" % [err, req.tag])
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

	# Ollama wraps the model output as a string in the "response" field.
	var response_text: String = (outer.data as Dictionary).get("response", "")
	var inner := JSON.new()
	var data: Dictionary = {}
	if inner.parse(response_text) == OK and inner.data is Dictionary:
		data = inner.data

	GameLogger.info("AiClient: response tag=%s" % tag)
	match tag:
		"question_generate":
			question_generated.emit(data)
		"feedback_generate":
			feedback_generated.emit(data)

	_flush()
