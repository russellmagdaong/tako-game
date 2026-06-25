extends Object
# QuestionTemplates
# Contains DepEd curriculum mathematical templates for Grades 7-10.
# Handles parameter randomization, hardcoded answer computation, AI instructions, and misconception rules.

class_name QuestionTemplates

static func get_template_for_skill(skill_type: String) -> Dictionary:
	var list := get_all_templates()
	var matches: Array[Dictionary] = []
	for t in list:
		if t["skill_type"] == skill_type:
			matches.append(t)
			
	if matches.is_empty():
		return list[0]
	return matches[randi() % matches.size()]

static func get_all_templates() -> Array[Dictionary]:
	return [
		# ===========================================================================
		# GRADE 7 MATHEMATICS TEMPLATES
		# ===========================================================================
		{
			"id": "g7_arithmetic_add_negative",
			"skill_type": "BasicArithmetic",
			"grade": 7,
			"generate_params": (func() -> Dictionary:
				var x := randi_range(10, 30)
				var y := randi_range(-20, -2) # Negative integer
				return {"x": x, "y": y}),
			"compute_answer": (func(params: Dictionary) -> String:
				return str(params.x + params.y)),
			"get_ai_prompt": (func(params: Dictionary, lang: String) -> String:
				if lang == "tl":
					return "Gumawa ng maikling math question tungkol sa pag-evaluate ng sum ng positibo at negatibong numero: %d + (%d). " % [params.x, params.y] + \
						"Maaari mo itong gawing word problem tungkol sa temperatura na bumababa, utang, o billiard points score. Huwag ibigay ang sagot."
				else:
					return "Write a short math question about evaluating the sum of a positive and a negative integer: %d + (%d). " % [params.x, params.y] + \
						"You can frame it as a word problem about temperature drops, scoring points, or money. Do not reveal the answer."),
			"match_misconception": (func(params: Dictionary, player_answer: float) -> String:
				var x: float = params.x
				var y: float = params.y
				# Misconception 1: added absolute values: x + |y|
				if player_answer == (x - y):
					return "added_absolute_values"
				# Misconception 2: subtracted absolute values incorrectly (wrong sign): -(x + |y|)
				if player_answer == -(x - y):
					return "wrong_negative_sign"
				return "")
		},
		{
			"id": "g7_rational_simplify",
			"skill_type": "Fractions",
			"grade": 7,
			"generate_params": (func() -> Dictionary:
				var factors := [2, 3, 4, 5, 6]
				var f = factors[randi() % factors.size()]
				# a and b coprime
				var a := randi_range(2, 5)
				var b := randi_range(a + 1, 7)
				while _gcd(a, b) > 1:
					b = randi_range(a + 1, 7)
				return {"x": a * f, "y": b * f, "a": a, "b": b}),
			"compute_answer": (func(params: Dictionary) -> String:
				return "%d/%d" % [params.a, params.b]),
			"get_ai_prompt": (func(params: Dictionary, lang: String) -> String:
				if lang == "tl":
					return "Gumawa ng maikling math question kung saan kailangang i-simplify ang fraction na %d/%d sa pinakamababang anyo (simplest form). " % [params.x, params.y] + \
						"Sabihin sa user na ibigay ang sagot bilang fraction tulad ng '3/5'."
				else:
					return "Write a short math question asking the player to simplify the fraction %d/%d into its simplest form. " % [params.x, params.y] + \
						"Instruct the user to enter the answer in fraction format (e.g. '3/5')."),
			"match_misconception": (func(params: Dictionary, player_answer: float) -> String:
				# Misconception: divided numerator but not denominator, or vice versa
				return "")
		},
		{
			"id": "g7_decimal_to_fraction",
			"skill_type": "Fractions",
			"grade": 7,
			"generate_params": (func() -> Dictionary:
				# Common decimals and their simplest fractions
				var options := [
					{"dec": 0.2, "ans": "1/5"},
					{"dec": 0.4, "ans": "2/5"},
					{"dec": 0.6, "ans": "3/5"},
					{"dec": 0.8, "ans": "4/5"},
					{"dec": 0.25, "ans": "1/4"},
					{"dec": 0.75, "ans": "3/4"},
					{"dec": 0.5, "ans": "1/2"}
				]
				return options[randi() % options.size()]),
			"compute_answer": (func(params: Dictionary) -> String:
				return params.ans),
			"get_ai_prompt": (func(params: Dictionary, lang: String) -> String:
				if lang == "tl":
					return "Gumawa ng math question kung saan iko-convert ang decimal na %.2f papuntang fraction sa simplest form." % params.dec
				else:
					return "Write a math question asking to convert the decimal %.2f into a fraction in its simplest form." % params.dec),
			"match_misconception": (func(params: Dictionary, player_answer: float) -> String:
				return "")
		},
		{
			"id": "g7_algebra_linear_simple",
			"skill_type": "Algebra",
			"grade": 7,
			"generate_params": (func() -> Dictionary:
				var a := randi_range(5, 20)
				var x := randi_range(5, 25)
				var b := x + a
				return {"a": a, "b": b, "x": x}),
			"compute_answer": (func(params: Dictionary) -> String:
				return str(params.x)),
			"get_ai_prompt": (func(params: Dictionary, lang: String) -> String:
				if lang == "tl":
					return "Gumawa ng algebra word problem sa Tagalog kung saan ang equation ay: x + %d = %d. Hanapin ang halaga ng x." % [params.a, params.b]
				else:
					return "Write an algebra word problem in English that models the linear equation: x + %d = %d. Solve for x." % [params.a, params.b]),
			"match_misconception": (func(params: Dictionary, player_answer: float) -> String:
				var a: float = params.a
				var b: float = params.b
				# Misconception: Added constant instead of subtracting: x = b + a
				if player_answer == (b + a):
					return "added_instead_of_subtracted"
				return "")
		},
		{
			"id": "g7_geometry_perimeter_rect",
			"skill_type": "Geometry",
			"grade": 7,
			"generate_params": (func() -> Dictionary:
				var length := randi_range(8, 20)
				var width := randi_range(3, length - 2)
				return {"l": length, "w": width}),
			"compute_answer": (func(params: Dictionary) -> String:
				return str(2 * (params.l + params.w))),
			"get_ai_prompt": (func(params: Dictionary, lang: String) -> String:
				if lang == "tl":
					return "Gumawa ng word problem tungkol sa isang parihaba (rectangle) na may haba (length) na %d cm at lapad (width) na %d cm. Hanapin ang perimeter nito." % [params.l, params.w]
				else:
					return "Write a word problem in English about a rectangle with a length of %d cm and a width of %d cm. Find its perimeter." % [params.l, params.w]),
			"match_misconception": (func(params: Dictionary, player_answer: float) -> String:
				var l: float = params.l
				var w: float = params.w
				# Misconception 1: calculated area instead: l * w
				if player_answer == (l * w):
					return "calculated_area_instead_of_perimeter"
				# Misconception 2: forgot to double: l + w
				if player_answer == (l + w):
					return "forgot_to_multiply_by_two"
				return "")
		},

		# ===========================================================================
		# GRADE 8 MATHEMATICS TEMPLATES
		# ===========================================================================
		{
			"id": "g8_algebra_exponent_mul",
			"skill_type": "Algebra",
			"grade": 8,
			"generate_params": (func() -> Dictionary:
				var a := randi_range(2, 6)
				var b := randi_range(2, 6)
				return {"a": a, "b": b}),
			"compute_answer": (func(params: Dictionary) -> String:
				return str(params.a + params.b)),
			"get_ai_prompt": (func(params: Dictionary, lang: String) -> String:
				if lang == "tl":
					return "Gumawa ng algebra question tungkol sa pagpaparami ng exponents: x^%d * x^%d. I-simplify ito at itanong kung ano ang magiging exponent ng sagot." % [params.a, params.b]
				else:
					return "Write an algebra question in English asking the student to simplify: x^%d * x^%d. Ask specifically for the final exponent value." % [params.a, params.b]),
			"match_misconception": (func(params: Dictionary, player_answer: float) -> String:
				var a: float = params.a
				var b: float = params.b
				# Misconception: multiplied exponents instead of adding: a * b
				if player_answer == (a * b):
					return "multiplied_exponents_instead_of_adding"
				return "")
		},
		{
			"id": "g8_algebra_solve_linear",
			"skill_type": "Algebra",
			"grade": 8,
			"generate_params": (func() -> Dictionary:
				var a := randi_range(2, 6)
				var x := randi_range(2, 8)
				var b := randi_range(1, 10)
				var c := (a * x) + b
				return {"a": a, "b": b, "c": c}),
			"compute_answer": (func(params: Dictionary) -> String:
				var a: int = params.a
				var b: int = params.b
				var c: int = params.c
				return str((c - b) / a)),
			"get_ai_prompt": (func(params: Dictionary, lang: String) -> String:
				if lang == "tl":
					return "Gumawa ng algebra word problem sa Tagalog kung saan ang equation ay: %dx + %d = %d. Lutasin para sa x." % [params.a, params.b, params.c]
				else:
					return "Write a short algebra word problem in English that models the equation: %dx + %d = %d. Solve for x." % [params.a, params.b, params.c]),
			"match_misconception": (func(params: Dictionary, player_answer: float) -> String:
				var a: float = params.a
				var b: float = params.b
				var c: float = params.c
				if abs(player_answer - ((c + b) / a)) < 0.001:
					return "added_instead_of_subtracted_constant"
				if abs(player_answer - ((c - b) * a)) < 0.001:
					return "multiplied_instead_of_divided_coefficient"
				return "")
		},
		{
			"id": "g8_geometry_slope",
			"skill_type": "Geometry",
			"grade": 8,
			"generate_params": (func() -> Dictionary:
				var x1 := randi_range(1, 4)
				var y1 := randi_range(1, 4)
				var slope := randi_range(1, 3)
				var dx := randi_range(1, 3)
				var x2 := x1 + dx
				var y2 := y1 + slope * dx
				return {"x1": x1, "y1": y1, "x2": x2, "y2": y2, "slope": slope}),
			"compute_answer": (func(params: Dictionary) -> String:
				return str(params.slope)),
			"get_ai_prompt": (func(params: Dictionary, lang: String) -> String:
				if lang == "tl":
					return "Gumawa ng word problem sa Tagalog na nagpapasolve ng slope ng line na dumadaan sa dalawang points: (%d, %d) at (%d, %d)." % [params.x1, params.y1, params.x2, params.y2]
				else:
					return "Write a math problem in English to find the slope of the line passing through the points: (%d, %d) and (%d, %d)." % [params.x1, params.y1, params.x2, params.y2]),
			"match_misconception": (func(params: Dictionary, player_answer: float) -> String:
				var dy: float = params.y2 - params.y1
				var dx: float = params.x2 - params.x1
				# Misconception: run over rise (dx / dy)
				if abs(player_answer - (dx / dy)) < 0.001:
					return "inverted_slope_formula"
				return "")
		},

		# ===========================================================================
		# GRADE 9 MATHEMATICS TEMPLATES
		# ===========================================================================
		{
			"id": "g9_algebra_discriminant",
			"skill_type": "Algebra",
			"grade": 9,
			"generate_params": (func() -> Dictionary:
				# Equation: x^2 + bx + c = 0
				var b := randi_range(2, 8) * 2 # Even number for ease
				var c := randi_range(1, 12)
				return {"b": b, "c": c}),
			"compute_answer": (func(params: Dictionary) -> String:
				var b: int = params.b
				var c: int = params.c
				return str(b * b - 4 * c)),
			"get_ai_prompt": (func(params: Dictionary, lang: String) -> String:
				if lang == "tl":
					return "Gumawa ng quadratic equation word problem sa Tagalog na nagpapahanap ng discriminant ng equation: x² + %dx + %d = 0." % [params.b, params.c]
				else:
					return "Write a quadratic equation math problem in English to find the value of the discriminant of: x² + %dx + %d = 0." % [params.b, params.c]),
			"match_misconception": (func(params: Dictionary, player_answer: float) -> String:
				var b: float = params.b
				var c: float = params.c
				# Misconception: b^2 + 4ac instead of b^2 - 4ac
				if player_answer == (b * b + 4 * c):
					return "added_instead_of_subtracted_discriminant"
				return "")
		},
		{
			"id": "g9_geometry_distance_points",
			"skill_type": "Geometry",
			"grade": 9,
			"generate_params": (func() -> Dictionary:
				# Pythagorean distances
				var x1 := randi_range(1, 5)
				var y1 := randi_range(1, 5)
				var pairs := [
					{"dx": 3, "dy": 4, "dist": 5},
					{"dx": 5, "dy": 12, "dist": 13},
					{"dx": 6, "dy": 8, "dist": 10}
				]
				var selected = pairs[randi() % pairs.size()]
				return {
					"x1": x1,
					"y1": y1,
					"x2": x1 + selected.dx,
					"y2": y1 + selected.dy,
					"dist": selected.dist,
					"dx": selected.dx,
					"dy": selected.dy
				}),
			"compute_answer": (func(params: Dictionary) -> String:
				return str(params.dist)),
			"get_ai_prompt": (func(params: Dictionary, lang: String) -> String:
				if lang == "tl":
					return "Gumawa ng Tagalog word problem na nagpapahanap ng distansya (distance) sa pagitan ng dalawang points: (%d, %d) at (%d, %d)." % [params.x1, params.y1, params.x2, params.y2]
				else:
					return "Write a word problem in English to find the distance between the two coordinates: (%d, %d) and (%d, %d)." % [params.x1, params.y1, params.x2, params.y2]),
			"match_misconception": (func(params: Dictionary, player_answer: float) -> String:
				var dx: float = params.dx
				var dy: float = params.dy
				# Misconception: Manhattan distance (dx + dy)
				if player_answer == (dx + dy):
					return "added_coordinates_directly"
				return "")
		},
		{
			"id": "g9_algebra_direct_variation",
			"skill_type": "Algebra",
			"grade": 9,
			"generate_params": (func() -> Dictionary:
				var k := randi_range(2, 6) # variation constant
				var x1 := randi_range(3, 8)
				var y1 := k * x1
				var x2 := randi_range(x1 + 1, x1 + 5)
				return {"x1": x1, "y1": y1, "x2": x2, "k": k}),
			"compute_answer": (func(params: Dictionary) -> String:
				return str(params.k * params.x2)),
			"get_ai_prompt": (func(params: Dictionary, lang: String) -> String:
				if lang == "tl":
					return "Gumawa ng direct variation word problem sa Tagalog: 'Kung ang y ay direct na nagbabago kasabay ng x, at ang y = %d kapag ang x = %d, ano ang y kapag ang x = %d?'" % [params.y1, params.x1, params.x2]
				else:
					return "Write a direct variation word problem in English: 'If y varies directly as x, and y = %d when x = %d, what is y when x = %d?'" % [params.y1, params.x1, params.x2]),
			"match_misconception": (func(params: Dictionary, player_answer: float) -> String:
				var y1: float = params.y1
				var x1: float = params.x1
				var x2: float = params.x2
				# Misconception: Inverse variation format instead: y = (y1 * x1) / x2
				if abs(player_answer - ((y1 * x1) / x2)) < 0.001:
					return "solved_using_inverse_variation"
				return "")
		},

		# ===========================================================================
		# GRADE 10 MATHEMATICS TEMPLATES
		# ===========================================================================
		{
			"id": "g10_statistics_median",
			"skill_type": "Statistics",
			"grade": 10,
			"generate_params": (func() -> Dictionary:
				# Generate 5 sorted numbers
				var nums: Array[int] = []
				var current := randi_range(2, 6)
				for i in range(5):
					current += randi_range(1, 4)
					nums.append(current)
				return {"a": nums[0], "b": nums[1], "c": nums[2], "d": nums[3], "e": nums[4]}),
			"compute_answer": (func(params: Dictionary) -> String:
				return str(params.c)),
			"get_ai_prompt": (func(params: Dictionary, lang: String) -> String:
				if lang == "tl":
					return "Gumawa ng maikling Tagalog word problem na nagpapanap ng median ng sumusunod na data set: %d, %d, %d, %d, %d." % [params.a, params.b, params.c, params.d, params.e]
				else:
					return "Write a short word problem in English to find the median of the following ordered data set: %d, %d, %d, %d, %d." % [params.a, params.b, params.c, params.d, params.e]),
			"match_misconception": (func(params: Dictionary, player_answer: float) -> String:
				var a: float = params.a
				var b: float = params.b
				var c: float = params.c
				var d: float = params.d
				var e: float = params.e
				# Misconception: calculated Mean instead of Median: (a+b+c+d+e)/5
				var sum = a + b + c + d + e
				if abs(player_answer - (sum / 5.0)) < 0.001:
					return "calculated_mean_instead_of_median"
				return "")
		},
		{
			"id": "g10_geometry_circumference",
			"skill_type": "Geometry",
			"grade": 10,
			"generate_params": (func() -> Dictionary:
				var mults := [1, 2, 3, 4]
				var r: int = 7 * mults[randi() % mults.size()]
				return {"r": r}),
			"compute_answer": (func(params: Dictionary) -> String:
				# C = 2 * pi * r. Using pi = 22/7, C = 2 * 22/7 * r = 44 * (r/7)
				return str(44 * (params.r / 7))),
			"get_ai_prompt": (func(params: Dictionary, lang: String) -> String:
				if lang == "tl":
					return "Gumawa ng word problem sa Tagalog para hanapin ang circumference ng isang bilog (circle) na may radius na %d cm. Sabihin na gumamit ng pi = 22/7." % params.r
				else:
					return "Write a word problem in English to find the circumference of a circle with a radius of %d cm. Instruct to use pi = 22/7." % params.r),
			"match_misconception": (func(params: Dictionary, player_answer: float) -> String:
				var r: float = params.r
				# Misconception: calculated area instead: pi * r^2 = 22/7 * r * r
				var area := (22.0 / 7.0) * r * r
				if abs(player_answer - area) < 0.001:
					return "calculated_area_instead_of_circumference"
				return "")
		},
		{
			"id": "g10_probability_bag",
			"skill_type": "Statistics",
			"grade": 10,
			"generate_params": (func() -> Dictionary:
				var b := randi_range(2, 6) # Blue balls
				var r := randi_range(3, 8) # Red balls
				return {"b": b, "r": r}),
			"compute_answer": (func(params: Dictionary) -> String:
				return "%d/%d" % [params.b, params.b + params.r]),
			"get_ai_prompt": (func(params: Dictionary, lang: String) -> String:
				if lang == "tl":
					return "Gumawa ng probability word problem sa Tagalog: 'Ang isang bag ay naglalaman ng %d na pulang bola (red balls) at %d na asul na bola (blue balls). Ano ang probability na makakuha ng asul na bola sa random na bunot?' Ibigay ang sagot bilang simpleng fraction." % [params.r, params.b]
				else:
					return "Write a probability word problem in English: 'A bag contains %d red balls and %d blue balls. What is the probability of drawing a blue ball at random?' Request the answer as a simplified fraction." % [params.r, params.b]),
			"match_misconception": (func(params: Dictionary, player_answer: float) -> String:
				var b: float = params.b
				var r: float = params.r
				# Misconception 1: ratio of blue to red (b/r)
				if abs(player_answer - (b / r)) < 0.001:
					return "calculated_ratio_instead_of_probability"
				# Misconception 2: probability of red ball instead of blue: r / (b+r)
				if abs(player_answer - (r / (b + r))) < 0.001:
					return "calculated_opposite_probability"
				return "")
		}
	]

static func _gcd(a: int, b: int) -> int:
	while b != 0:
		var temp = b
		b = a % b
		a = temp
	return a
