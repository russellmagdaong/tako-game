extends Node
# Autoload or Static Helper: MathManager
# Manages active math session questions, parameters, grading, and misconception matching.

# Active question state
var active_template: Dictionary = {}
var active_params: Dictionary = {}
var active_expected_answer: String = ""
var last_misconception: String = ""

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
		last_misconception = ""
		return {"is_correct": true, "misconception": ""}
		
	# Incorrect: Identify misconception
	var misconception := ""
	if not active_template.is_empty():
		var player_val := AnswerValidator.parse_math_value(player_answer)
		if not is_nan(player_val) and active_template.has("match_misconception"):
			misconception = active_template["match_misconception"].call(active_params, player_val)
			
	last_misconception = misconception
	GameLogger.info("MathManager: Answer checked. Correct? %s | Misconception: %s" % [str(is_correct), misconception])
	return {"is_correct": false, "misconception": misconception}

# Generates static fallback question text and hint in case AI fails.
func get_static_fallback_question(lang: String) -> Dictionary:
	if active_template.is_empty():
		return {"question": "Solve this math problem.", "hint": "Check your calculations."}
	
	var q_id: String = active_template.get("id", "")
	var question_text := ""
	var hint_text := ""
	
	match q_id:
		"g7_arithmetic_add_negative":
			if lang == "tl":
				var opts := [
					"I-evaluate ang sum: %d + (%d) = ?",
					"Hanapin ang halaga ng: %d + (%d) = ________",
					"Hanapin ang sum: %d + (%d) = ________",
					"Kalkulahin ang expression: %d + (%d) = ?"
				]
				question_text = opts[randi() % opts.size()] % [active_params.x, active_params.y]
				hint_text = "Tandaan, ang pagdadagdag ng negatibong numero ay parang pagbabawas."
			else:
				var opts := [
					"Evaluate the sum: %d + (%d) = ?",
					"Find the value of: %d + (%d) = ________",
					"Find the sum: %d + (%d) = ________",
					"Calculate the expression: %d + (%d) = ?"
				]
				question_text = opts[randi() % opts.size()] % [active_params.x, active_params.y]
				hint_text = "Remember, adding a negative number is the same as subtracting its absolute value."
		"g7_rational_simplify":
			if lang == "tl":
				var opts := [
					"I-simplify ang fraction na %d/%d sa pinakamababang anyo.",
					"I-reduce ang fraction na %d/%d sa lowest terms.",
					"Ano ang pinakasimpleng anyo ng fraction na %d/%d?"
				]
				question_text = opts[randi() % opts.size()] % [active_params.x, active_params.y]
				hint_text = "Hatiin ang parehong numerator at denominator sa kanilang Greatest Common Divisor (GCD)."
			else:
				var opts := [
					"Simplify the fraction %d/%d to its simplest form.",
					"Reduce the fraction %d/%d to its lowest terms.",
					"What is the simplified form of the fraction %d/%d?"
				]
				question_text = opts[randi() % opts.size()] % [active_params.x, active_params.y]
				hint_text = "Divide both the numerator and the denominator by their Greatest Common Divisor (GCD)."
		"g7_decimal_to_fraction":
			if lang == "tl":
				var opts := [
					"I-convert ang decimal na %.2f sa fraction sa pinakamababang anyo.",
					"Isulat ang decimal na %.2f bilang fraction sa lowest terms.",
					"I-express ang decimal na %.2f sa anyong fraction."
				]
				question_text = opts[randi() % opts.size()] % active_params.dec
				hint_text = "Isulat ang decimal sa ibabaw ng kapangyarihan ng 10 at i-simplify (halimbawa, 0.25 ay naging 25/100)."
			else:
				var opts := [
					"Convert the decimal %.2f to a fraction in its simplest form.",
					"Write the decimal %.2f as a fraction in its lowest terms.",
					"Express the decimal %.2f as a fraction in simplest form."
				]
				question_text = opts[randi() % opts.size()] % active_params.dec
				hint_text = "Write the decimal over a power of 10 and simplify (e.g. 0.25 becomes 25/100)."
		"g7_algebra_linear_simple":
			if lang == "tl":
				var opts := [
					"Hanapin ang halaga ng x sa equation: x + %d = %d",
					"Lutasin para sa x: x + %d = %d",
					"Anong value ng x ang makapaglulutas sa equation na x + %d = %d?"
				]
				question_text = opts[randi() % opts.size()] % [active_params.a, active_params.b]
				hint_text = "Ibawas ang %d sa magkabilang panig ng equation upang maiwan ang x." % active_params.a
			else:
				var opts := [
					"Find the value of x in the equation: x + %d = %d",
					"Solve for x: x + %d = %d",
					"What value of x satisfies the equation: x + %d = %d?"
				]
				question_text = opts[randi() % opts.size()] % [active_params.a, active_params.b]
				hint_text = "Subtract %d from both sides of the equation to isolate x." % active_params.a
		"g7_geometry_perimeter_rect":
			if lang == "tl":
				var opts := [
					"Ang isang parihaba ay may haba na %d cm at lapad na %d cm. Ano ang perimeter nito?",
					"Hanapin ang perimeter ng isang parihaba na may habang %d cm at lapad na %d cm.",
					"Kalkulahin ang perimeter ng isang %d cm at %d cm na parihaba."
				]
				question_text = opts[randi() % opts.size()] % [active_params.l, active_params.w]
				hint_text = "Gamitin ang formula: Perimeter = 2 * (haba + lapad)."
			else:
				var opts := [
					"A rectangle has a length of %d cm and a width of %d cm. What is its perimeter?",
					"Find the perimeter of a rectangle with length %d cm and width %d cm.",
					"Calculate the perimeter of a %d cm by %d cm rectangle."
				]
				question_text = opts[randi() % opts.size()] % [active_params.l, active_params.w]
				hint_text = "Use the formula: Perimeter = 2 * (length + width)."
		"g8_algebra_exponent_mul":
			if lang == "tl":
				var opts := [
					"I-simplify ang expression: x^%d * x^%d. Ano ang exponent ng sagot?",
					"Hanapin ang exponent kapag pinag-multiply ang: x^%d * x^%d",
					"Tukuyin ang exponent ng sagot para sa: x^%d * x^%d"
				]
				question_text = opts[randi() % opts.size()] % [active_params.a, active_params.b]
				hint_text = "Kapag nagpaparami ng kaparehong base, ipag-add ang mga exponent."
			else:
				var opts := [
					"Simplify the expression: x^%d * x^%d. What is the exponent of the answer?",
					"Find the exponent when simplifying: x^%d * x^%d",
					"Determine the final exponent value for: x^%d * x^%d"
				]
				question_text = opts[randi() % opts.size()] % [active_params.a, active_params.b]
				hint_text = "When multiplying powers with the same base, add their exponents."
		"g8_algebra_solve_linear":
			if lang == "tl":
				var opts := [
					"Lutasin ang equation para sa x: %dx + %d = %d",
					"Hanapin ang halaga ng x sa linear equation: %dx + %d = %d",
					"Lutasin para sa variable x: %dx + %d = %d"
				]
				question_text = opts[randi() % opts.size()] % [active_params.a, active_params.b, active_params.c]
				hint_text = "Ibawas muna ang %d sa magkabilang panig, pagkatapos ay i-divide sa %d." % [active_params.b, active_params.a]
			else:
				var opts := [
					"Solve the equation for x: %dx + %d = %d",
					"Find the value of x in the linear equation: %dx + %d = %d",
					"Solve for the variable x: %dx + %d = %d"
				]
				question_text = opts[randi() % opts.size()] % [active_params.a, active_params.b, active_params.c]
				hint_text = "Subtract %d from both sides first, then divide by %d." % [active_params.b, active_params.a]
		"g8_geometry_slope":
			if lang == "tl":
				var opts := [
					"Ano ang slope ng linya na dumadaan sa mga puntos na (%d, %d) at (%d, %d)?",
					"Kalkulahin ang slope ng linya na nag-uugnay sa mga puntos na (%d, %d) at (%d, %d).",
					"Hanapin ang gradient o slope sa pagitan ng (%d, %d) at (%d, %d)."
				]
				question_text = opts[randi() % opts.size()] % [active_params.x1, active_params.y1, active_params.x2, active_params.y2]
				hint_text = "Gamitin ang formula ng slope: m = (y2 - y1) / (x2 - x1)."
			else:
				var opts := [
					"What is the slope of the line passing through points (%d, %d) and (%d, %d)?",
					"Calculate the slope of the line connecting points (%d, %d) and (%d, %d).",
					"Find the gradient or slope between the points (%d, %d) and (%d, %d)."
				]
				question_text = opts[randi() % opts.size()] % [active_params.x1, active_params.y1, active_params.x2, active_params.y2]
				hint_text = "Use the slope formula: m = (y2 - y1) / (x2 - x1)."
		"g9_algebra_discriminant":
			if lang == "tl":
				var opts := [
					"Hanapin ang discriminant ng quadratic equation na ito: x² + %dx + %d = 0",
					"Kalkulahin ang discriminant ng quadratic equation na x² + %dx + %d = 0",
					"Ano ang halaga ng discriminant para sa equation na x² + %dx + %d = 0?"
				]
				question_text = opts[randi() % opts.size()] % [active_params.b, active_params.c]
				hint_text = "Gamitin ang formula: Discriminant = b² - 4ac. Dito, a = 1, b = %d, at c = %d." % [active_params.b, active_params.c]
			else:
				var opts := [
					"Find the discriminant of the quadratic equation: x² + %dx + %d = 0",
					"Calculate the discriminant of the quadratic equation: x² + %dx + %d = 0",
					"What is the value of the discriminant for: x² + %dx + %d = 0?"
				]
				question_text = opts[randi() % opts.size()] % [active_params.b, active_params.c]
				hint_text = "Use the formula: Discriminant = b² - 4ac. Here, a = 1, b = %d, and c = %d." % [active_params.b, active_params.c]
		"g9_geometry_distance_points":
			if lang == "tl":
				var opts := [
					"Ano ang distansya sa pagitan ng mga puntos na (%d, %d) at (%d, %d)?",
					"Kalkulahin ang distansya ng dalawang puntos na (%d, %d) at (%d, %d).",
					"Hanapin ang haba ng line segment na nagkokonekta sa (%d, %d) at (%d, %d)."
				]
				question_text = opts[randi() % opts.size()] % [active_params.x1, active_params.y1, active_params.x2, active_params.y2]
				hint_text = "Gamitin ang Distance Formula: d = sqrt((x2 - x1)² + (y2 - y1)²)."
			else:
				var opts := [
					"What is the distance between points (%d, %d) and (%d, %d)?",
					"Calculate the distance between the two points (%d, %d) and (%d, %d).",
					"Find the length of the line segment connecting (%d, %d) and (%d, %d)."
				]
				question_text = opts[randi() % opts.size()] % [active_params.x1, active_params.y1, active_params.x2, active_params.y2]
				hint_text = "Use the Distance Formula: d = sqrt((x2 - x1)² + (y2 - y1)²)."
		"g9_algebra_direct_variation":
			if lang == "tl":
				var opts := [
					"Kung ang y ay direktang nagbabago kasabay ng x, at y = %d kapag x = %d, ano ang y kapag x = %d?",
					"Ang y ay direktang proporsyonal sa x. Kung y = %d kapag x = %d, hanapin ang y kapag x = %d.",
					"Lutasin para sa y kung ang y ay nagbabago direktang kasabay ng x, at y = %d kapag x = %d (hanapin para sa x = %d)."
				]
				question_text = opts[randi() % opts.size()] % [active_params.y1, active_params.x1, active_params.x2]
				hint_text = "Hanapin muna ang variation constant k = y/x, pagkatapos ay gamitin ang y = k * x."
			else:
				var opts := [
					"If y varies directly as x, and y = %d when x = %d, what is y when x = %d?",
					"The variable y is directly proportional to x. If y = %d when x = %d, find y when x = %d.",
					"Solve for y if y varies directly with x, where y = %d when x = %d (find for x = %d)."
				]
				question_text = opts[randi() % opts.size()] % [active_params.y1, active_params.x1, active_params.x2]
				hint_text = "Find the variation constant k = y/x first, then use y = k * x."
		"g10_statistics_median":
			if lang == "tl":
				var opts := [
					"Hanapin ang median ng data set na ito: %d, %d, %d, %d, %d",
					"Tukuyin ang median value ng sumusunod na set ng mga numero: %d, %d, %d, %d, %d",
					"Ano ang median ng sumusunod na naka-sort na grupo ng data: %d, %d, %d, %d, %d?"
				]
				question_text = opts[randi() % opts.size()] % [active_params.a, active_params.b, active_params.c, active_params.d, active_params.e]
				hint_text = "Ayusin ang mga numero mula sa pinakamaliit hanggang pinakamalaki at hanapin ang gitnang numero."
			else:
				var opts := [
					"Find the median of the following ordered data set: %d, %d, %d, %d, %d",
					"Determine the median value of the following numbers: %d, %d, %d, %d, %d",
					"What is the median of this data group: %d, %d, %d, %d, %d?"
				]
				question_text = opts[randi() % opts.size()] % [active_params.a, active_params.b, active_params.c, active_params.d, active_params.e]
				hint_text = "Identify the middle value in the sorted list of numbers."
		"g10_geometry_circumference":
			if lang == "tl":
				var opts := [
					"Ano ang circumference ng isang bilog na may radius na %d cm? (pi = 22/7)",
					"Kalkulahin ang circumference ng bilog na may radius na %d cm. (Gamitin ang pi = 22/7)",
					"Hanapin ang circumference ng bilog na may radius na %d cm gamit ang pi = 22/7."
				]
				question_text = opts[randi() % opts.size()] % active_params.r
				hint_text = "Gamitin ang formula: Circumference = 2 * pi * r."
			else:
				var opts := [
					"What is the circumference of a circle with radius %d cm? (Use pi = 22/7)",
					"Calculate the circumference of a circle whose radius is %d cm. (Use pi = 22/7)",
					"Find the circumference of a circle with radius %d cm using pi = 22/7."
				]
				question_text = opts[randi() % opts.size()] % active_params.r
				hint_text = "Use the formula: Circumference = 2 * pi * r."
		"g10_probability_bag":
			if lang == "tl":
				var opts := [
					"Ang isang bag ay naglalaman ng %d pulang bola at %d asul na bola. Ano ang probability na makakuha ng asul na bola sa random na bunot?",
					"May %d pulang bola at %d asul na bola sa isang bag. Ano ang probability na makabunot ng asul na bola?",
					"Kalkulahin ang probability na makakuha ng asul na bola mula sa bag na may %d pulang bola at %d asul na bola."
				]
				question_text = opts[randi() % opts.size()] % [active_params.r, active_params.b]
				hint_text = "Probability = (bilang ng asul na bola) / (kabuuang bilang ng mga bola)."
			else:
				var opts := [
					"A bag contains %d red balls and %d blue balls. What is the probability of drawing a blue ball at random?",
					"There are %d red balls and %d blue balls in a bag. What is the probability of drawing a blue ball?",
					"Calculate the probability of drawing a blue ball from a bag containing %d red and %d blue balls."
				]
				question_text = opts[randi() % opts.size()] % [active_params.r, active_params.b]
				hint_text = "Probability = (number of blue balls) / (total number of balls)."
		_:
			if lang == "tl":
				question_text = "Lutasin ang math problem na ito."
				hint_text = "Suriin ang iyong kalkulasyon."
			else:
				question_text = "Solve this math problem."
				hint_text = "Double check your operations."
				
	return {"question": question_text, "hint": hint_text}

# Generates static fallback feedback text in case AI fails.
func get_static_fallback_feedback(misconception: String, lang: String) -> Dictionary:
	var msg := ""
	match misconception:
		"added_absolute_values":
			if lang == "tl":
				msg = "Mali ang sagot. Tila pinag-add mo ang absolute values nang hindi pinansin ang negatibong sign. Subukan ulit!"
			else:
				msg = "Incorrect. It looks like you added the absolute values directly, ignoring the negative sign. Try again!"
		"wrong_negative_sign":
			if lang == "tl":
				msg = "Mali ang sagot. Tandaan na ang sign ng kabuuan ay sumusunod sa numero na may mas malaking absolute value. Subukan ulit!"
			else:
				msg = "Incorrect. Remember that the sign of the sum follows the number with the larger absolute value. Try again!"
		"added_instead_of_subtracted":
			if lang == "tl":
				msg = "Mali ang sagot. Kapag inilipat mo ang constant sa kabilang panig, kailangan mong ibawas ito. Subukan ulit!"
			else:
				msg = "Incorrect. When moving a positive constant to the other side of the equation, you need to subtract it. Try again!"
		"calculated_area_instead_of_perimeter":
			if lang == "tl":
				msg = "Mali ang sagot. Kinalkula mo ang area (haba * lapad). Ang perimeter ay ang kabuuan ng lahat ng panig: 2 * (haba + lapad)."
			else:
				msg = "Incorrect. You calculated the area (length * width). The perimeter is the sum of all sides: 2 * (length + width)."
		"forgot_to_multiply_by_two":
			if lang == "tl":
				msg = "Mali ang sagot. Pinag-add mo lang ang haba at lapad. Huwag kalimutang i-multiply ito sa 2."
			else:
				msg = "Incorrect. You only added the length and width. Don't forget to multiply the sum by 2."
		"multiplied_exponents_instead_of_adding":
			if lang == "tl":
				msg = "Mali ang sagot. Kapag nagpaparami ng exponents na may parehong base, ipinagdaragdag (add) ang mga exponent, hindi pinararami (multiply)."
			else:
				msg = "Incorrect. When multiplying terms with the same base, add the exponents together. Do not multiply them."
		"added_instead_of_subtracted_constant":
			if lang == "tl":
				msg = "Mali ang sagot. Tiyaking ibabawas mo ang constant bago hatiin ang coefficient. Subukan ulit!"
			else:
				msg = "Incorrect. Make sure you subtract the constant before dividing by the coefficient. Try again!"
		"multiplied_instead_of_divided_coefficient":
			if lang == "tl":
				msg = "Mali ang sagot. Para maihiwalay ang x, kailangan mong i-divide ang magkabilang panig sa coefficient. Subukan ulit!"
			else:
				msg = "Incorrect. To isolate x, you need to divide both sides by the coefficient. Try again!"
		"inverted_slope_formula":
			if lang == "tl":
				msg = "Mali ang sagot. Tila binaligtad mo ang formula ng slope. Ito ay rise divided by run (y2 - y1) / (x2 - x1). Subukan ulit!"
			else:
				msg = "Incorrect. It looks like you inverted the slope formula. Slope is rise over run (y2 - y1) / (x2 - x1). Try again!"
		"added_instead_of_subtracted_discriminant":
			if lang == "tl":
				msg = "Mali ang sagot. Ang formula ng discriminant ay b² - 4ac. Tila ginamit mo ang + sa halip na -. Subukan ulit!"
			else:
				msg = "Incorrect. The discriminant formula is b² - 4ac. It looks like you added instead of subtracted. Try again!"
		"added_coordinates_directly":
			if lang == "tl":
				msg = "Mali ang sagot. Pinagsama mo ang mga coordinates nang direkta (Manhattan distance). Gamitin ang distance formula. Subukan ulit!"
			else:
				msg = "Incorrect. You added the coordinate differences directly (Manhattan distance). Use the distance formula: d = sqrt(dx² + dy²)."
		"solved_using_inverse_variation":
			if lang == "tl":
				msg = "Mali ang sagot. Ginamit mo ang inverse variation formula. Para sa direct variation, gamitin ang y = k * x. Subukan ulit!"
			else:
				msg = "Incorrect. You solved using inverse variation. For direct variation, use the formula y = k * x. Try again!"
		"calculated_mean_instead_of_median":
			if lang == "tl":
				msg = "Mali ang sagot. Kinalkula mo ang mean (average). Ang median ay ang gitnang numero sa naka-sort na data set. Subukan ulit!"
			else:
				msg = "Incorrect. You calculated the mean (average). The median is the middle value of the sorted data set. Try again!"
		"calculated_area_instead_of_circumference":
			if lang == "tl":
				msg = "Mali ang sagot. Kinalkula mo ang area (pi * r²). Ang circumference ay 2 * pi * r. Subukan ulit!"
			else:
				msg = "Incorrect. You calculated the area (pi * r²). The circumference formula is 2 * pi * r. Try again!"
		"calculated_ratio_instead_of_probability":
			if lang == "tl":
				msg = "Mali ang sagot. Kinalkula mo ang ratio ng asul sa pulang bola. Ang probability ay (asul) / (kabuuan). Subukan ulit!"
			else:
				msg = "Incorrect. You calculated the ratio of blue to red balls. Probability is (blue balls) / (total balls). Try again!"
		"calculated_opposite_probability":
			if lang == "tl":
				msg = "Mali ang sagot. Kinalkula mo ang probability ng pulang bola. Ang tinatanong ay para sa asul na bola. Subukan ulit!"
			else:
				msg = "Incorrect. You calculated the probability of drawing a red ball. The question asks for a blue ball. Try again!"
		_:
			# Determine skill-specific hint for general incorrect answers
			var skill = active_template.get("skill_type", "")
			match skill:
				"BasicArithmetic":
					if lang == "tl":
						msg = "Mali ang sagot. Suriin ang mga signs ng mga numero. Ang pagdadagdag ng negatibong numero ay parang pagbabawas."
					else:
						msg = "Incorrect. Check the signs of the numbers. Remember that adding a negative number is equivalent to subtraction."
				"Fractions":
					if lang == "tl":
						msg = "Mali ang sagot. Siguraduhing na-simplify mo ang fraction sa pinakamababang anyo sa pamamagitan ng paghahati sa GCD."
					else:
						msg = "Incorrect. Make sure you simplified the fraction to its lowest terms by dividing both parts by their GCD."
				"Algebra":
					if lang == "tl":
						msg = "Mali ang sagot. Subukang ihiwalay ang variable x sa pamamagitan ng paggawa ng kabaligtarang operasyon sa magkabilang panig."
					else:
						msg = "Incorrect. Try to isolate the variable x by performing the inverse operation on both sides of the equation."
				"Geometry":
					if lang == "tl":
						msg = "Mali ang sagot. Double-check ang formula na ginamit mo (perimeter, circumference, o distansya) at ang iyong kalkulasyon."
					else:
						msg = "Incorrect. Double-check the formula you used (perimeter, circumference, or distance) and your arithmetic."
				"Statistics":
					if lang == "tl":
						msg = "Mali ang sagot. Suriin ang iyong kalkulasyon at tiyaking sinunod mo ang tamang paraan para sa median o probability."
					else:
						msg = "Incorrect. Review your calculations and ensure you followed the correct steps for median or probability."
				_:
					if lang == "tl":
						msg = "Mali ang sagot. Pakisuri ang iyong solusyon at subukan ulit."
					else:
						msg = "Incorrect answer. Please check your steps and try again."
				
	return {"feedback": msg}
