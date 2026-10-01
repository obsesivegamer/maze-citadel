extends RefCounted
## Base for unit tests. The runner calls every `test_*` method and reports the
## messages collected in `failures`.

var failures: PackedStringArray = []


func check(condition: bool, message := "check failed") -> void:
	if not condition:
		failures.append(message)


func check_eq(actual: Variant, expected: Variant, message := "") -> void:
	if actual != expected:
		failures.append("%s expected %s, got %s" % [message, expected, actual])


func check_near(actual: float, expected: float, eps := 1e-4, message := "") -> void:
	if abs(actual - expected) > eps:
		failures.append("%s expected %.5f, got %.5f" % [message, expected, actual])
