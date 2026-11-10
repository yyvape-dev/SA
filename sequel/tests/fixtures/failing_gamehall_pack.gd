extends "res://scripts/district.gd"
# Simulate only the external pack boundary; exercise the real transition/UI code.
var requests := 0
func ensure(id: String) -> bool:
    if id == "gh1":
        requests += 1
        last_error = "gh1 0 503"
        return false
    return await super.ensure(id)
