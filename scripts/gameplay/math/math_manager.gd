extends Node
# Autoload or Static Helper: MathManager
# Manages active math session questions, parameters, grading, and misconception matching.

# Active question state
var active_template: Dictionary = {}
var active_params: Dictionary = {}
var active_expected_answer: String = ""

# Generates new math parameters and returns the prompt instructions for the AI.
func setup_new_question(skill_type: String, preferred_lang: String = "en") -> String:
	active_template = QuestionTemplates.get_template_for_skill(skill_type)
	if active_template.is_empty():
		GameLogger.error("MathManager: No template found for skill type: %s" % skill_type)
		return ""
		
	# Randomize parameters in the template
	active_params = active_template["generate_params"].call()
	active_expected_answer = active_template["compute_answer"].call(active_params)
	
	# Fetch AI prompt instructions
	var ai_prompt: String = active_template["get_ai_prompt"].call(active_params, preferred_lang)
	GameLogger.info("MathManager: Prepared new question template %s with params %s" % [active_template.id, str(active_params)])
	
	return ai_prompt

# Verifies player's answer, runs deterministic grading, and detects misconceptions.
func verify_player_answer(player_answer: String) -> Dictionary:
	var is_correct := AnswerValidator.validate(player_answer, active_expected_answer)
	if is_correct:
		return {"is_correct": true, "misconception": ""}
		
	# Incorrect: Identify misconception
	var misconception := ""
	if not active_template.is_empty():
		var player_val := AnswerValidator.parse_math_value(player_answer)
		if not is_nan(player_val) and active_template.has("match_misconception"):
			misconception = active_template["match_misconception"].call(active_params, player_val)
			
	GameLogger.info("MathManager: Answer checked. Correct? %s | Misconception: %s" % [str(is_correct), misconception])
	return {"is_correct": false, "misconception": misconception}
