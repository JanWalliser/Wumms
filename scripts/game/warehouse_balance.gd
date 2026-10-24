extends RefCounted

# Project tuning for the single-map local-coop release, not original server values.
const DENSITY = [1.0,1.5,2.0,2.5]
const NORMAL_HP = [1.0,1.2,1.4,1.6]
const SPECIAL_HP = [1.0,1.45,1.9,2.35]
const BOSS_HP = [1.0,1.65,2.3,2.95]
const NORMAL_LIMIT := 550
const SPECIAL_RESERVE := 48
const TRIAL_RESERVE := 40

static func density(players: int) -> float:
	return DENSITY[clampi(players-1,0,3)]

static func hp(players: int, id: String) -> float:
	var values: Array = BOSS_HP if id.begins_with("boss_") else (SPECIAL_HP if id in ["mini_boss","elite_variant"] else NORMAL_HP)
	return values[clampi(players-1,0,3)]

static func reksai_attack(difficulty: String, phase_two: bool) -> Dictionary:
	var base: float = {"story":1.4,"hard":1.3,"extreme":1.2}.get(difficulty,1.4)
	# Keep the late-phase dodge possible after the requested ten-percent walk reduction.
	return {"radius":72.0,"warmup":base+0.1-(0.2 if phase_two else 0.0),"recovery":3.8 if not phase_two else 2.6}
