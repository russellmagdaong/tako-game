extends Object
# AnswerValidator
# Safely compares mathematical answers (integers, decimals, fractions).
# Resolves equivalence: e.g., "1/2" is equivalent to "0.5", "2/4", etc.

class_name AnswerValidator

# Core equivalence check
static func validate(player_answer: String, expected_answer: String) -> bool:
	var player_clean := player_answer.strip_edges().to_lower().replace(" ", "")
	var expected_clean := expected_answer.strip_edges().to_lower().replace(" ", "")
	
	if player_clean == expected_clean:
		return true
		
	var player_val := parse_math_value(player_clean)
	var expected_val := parse_math_value(expected_clean)
	
	# If both are valid numbers (not NaN), compare with tolerance
	if not is_nan(player_val) and not is_nan(expected_val):
		return absf(player_val - expected_val) < 0.0001
		
	return false

# Converts a string like "3.5", "1/2", or "5" to a float. Returns NAN on failure.
static func parse_math_value(s: String) -> float:
	if s.is_empty():
		return NAN
		
	if "/" in s:
		var parts := s.split("/")
		if parts.size() == 2:
			var num_str := parts[0].strip_edges()
			var den_str := parts[1].strip_edges()
			if num_str.is_valid_float() and den_str.is_valid_float():
				var den := den_str.to_float()
				if den != 0.0:
					return num_str.to_float() / den
		return NAN
		
	if s.is_valid_float():
		return s.to_float()
		
	return NAN
