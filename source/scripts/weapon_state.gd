class_name WeaponState
extends RefCounted

# A magazine is its own object. A chambered cartridge is NOT part of it.
const DATA = {
	"svd": {"name": "СВД / ПСО-1", "caliber": "7.62 × 54R", "capacity": 10, "damage": 68.0, "interval": 0.16, "modes": ["ОДИН"], "recoil": 0.044, "reload": 3.2, "hold_open": true},
	"ak74": {"name": "АК-74М", "caliber": "5.45 × 39", "capacity": 30, "damage": 36.0, "interval": 60.0 / 600.0, "modes": ["АВТО", "ОДИН"], "recoil": 0.021, "reload": 2.5, "hold_open": false},
	"m16": {"name": "M16A2", "caliber": "5.56 × 45", "capacity": 30, "damage": 38.0, "interval": 60.0 / 800.0, "modes": ["ОДИН", "3 ПОСТРІЛИ"], "recoil": 0.017, "reload": 2.3, "hold_open": true},
	"pm": {"name": "ПМ", "caliber": "9 × 18", "capacity": 8, "damage": 29.0, "interval": 0.12, "modes": ["ОДИН"], "recoil": 0.035, "reload": 1.9, "hold_open": true},
	"m9": {"name": "M9", "caliber": "9 × 19", "capacity": 15, "damage": 31.0, "interval": 0.10, "modes": ["ОДИН"], "recoil": 0.029, "reload": 1.9, "hold_open": true},
	# PKM: belt of 100 in a box under the receiver, 650 rounds/min, automatic
	# only, fires from an open bolt: at the end of the belt the bolt runs
	# home on an empty chamber, a new belt needs the cover lifted, the belt
	# laid on the feed tray, the cover shut and the handle pulled (V).
	"pkm": {"name": "ПКМ", "caliber": "7.62 × 54R", "capacity": 100, "damage": 68.0, "interval": 60.0 / 650.0, "modes": ["АВТО"], "recoil": 0.032, "reload": 7.5, "hold_open": false}
}
var id: String
var data: Dictionary
var magazine: Dictionary = {}
var packed_magazine: Dictionary = {}
var pouches: Array[Dictionary] = []
var held_old: Dictionary = {}
var held_new: Dictionary = {}
var pending_slot := -1
var inspection_slot := -1
var inspection_departure := 0.0
var prepared_reload := false
var inspected_loaded_reload := false
var chambered := false
# Bots chamber a round after a magazine change by drill. The player racks the
# bolt himself (V), knowing or not whether a round is already chambered.
var auto_rack := true
var bolt_open := false
# The PKM fires from an open bolt: `cocked` is its carrier held back on the
# sear, `chambered` there means the next round of the belt lies on the tray
# ready. At the end of a belt the carrier runs home; a new belt then needs
# the handle pulled back and pushed forward by hand (V). Changing the belt
# with the carrier still back needs no cocking.
var cocked := false
var mode_index := 0
var phase := ""
var clock := 0.0
var magazine_serial := 1
var discarded_rounds := 0
var live_ejections := 0
var shots_fired := 0
var debug_infinite := false
# The PSO-1's drum (SVD), or the setting of the iron sight, in metres: the
# range at which the round comes down onto the line of sight.
var scope_zero := 100
# Iron sights set by PgUp / PgDn: the AK-74's tangent sight 1–10 (its «П» is
# the setting 4), the M16A2's elevation knob 300–800 m, the PKM's frame 1–15.
const SIGHT_RANGES := {"ak74":[100,1000],"m16":[300,800],"pkm":[100,1500]}
var scope_windage := 0 # Half-milliradian clicks, positive = right correction.
var scope_illuminated := false

func _init(weapon_id: String="ak74") -> void:
	id=weapon_id
	data=DATA[id]
	magazine={"serial":1,"rounds":int(data.capacity)}
	# Spare boxes of 100 for the machine gun: two on the gunner.
	for i in range(2 if id in ["pm","m9","pkm"] else 3):pouches.append({"serial":i+2,"rounds":int(data.capacity)})
	# Carried on the direct-fire setting (Ballistics.PROFILES zero).
	if id in SIGHT_RANGES:scope_zero=int(Ballistics.PROFILES[id].zero)
	if id=="pkm":cocked=true
	chamber()

func rounds() -> int:return int(magazine.get("rounds",0))

# The iron sight's setting as marked: hundreds of metres, the AK-74's 4 as «П».
func sight_label() -> String:
	if id=="ak74" and scope_zero==400:return "П"
	return str(scope_zero/100)

# PgUp / PgDn on an iron sight: a hundred metres a notch, within its scale.
func step_sight(up: bool) -> bool:
	if not SIGHT_RANGES.has(id):return false
	var limits: Array=SIGHT_RANGES[id]
	var next:=clampi(scope_zero+(100 if up else -100),int(limits[0]),int(limits[1]))
	if next==scope_zero:return false
	scope_zero=next
	return true
func mode() -> String:return data.modes[mode_index]
func cycle_mode() -> void:mode_index=(mode_index+1)%data.modes.size()

func chamber() -> void:
	if not chambered and rounds()>0 and (id!="pkm" or cocked):
		magazine.rounds-=1
		chambered=true
		bolt_open=false

func fire() -> bool:
	if phase!="" or not chambered:return false
	shots_fired+=1
	chambered=false
	chamber()
	if not chambered:
		bolt_open=bool(data.hold_open)
		# The belt's last round gone, the carrier runs home on an empty chamber.
		if id=="pkm":cocked=false
	return true

func best_pouch() -> int:
	var best := -1
	for i in range(pouches.size()):
		if best<0 or int(pouches[i].get("rounds",0))>int(pouches[best].get("rounds",0)):best=i
	return best

func inspection_in_hand() -> bool:
	return phase in ["inspect_mag","inspect_pouch"] and clock>=0.48 and clock<1.65

func reload(slot: int=-1) -> bool:
	if phase in ["inspect_mag","inspect_pouch"]:
		if not inspection_in_hand():return false
		inspection_departure=clock
		if phase=="inspect_pouch":
			if slot>=0 and slot!=inspection_slot:return false
			pending_slot=inspection_slot
			held_new=pouches[pending_slot]
			pouches[pending_slot]={}
			if debug_infinite:held_new.rounds=int(data.capacity)
			prepared_reload=true
			phase="ready_remove"
		else:
			if slot<0:slot=best_pouch()
			if slot<0 or slot>=pouches.size():return false
			pending_slot=slot
			belt_off()
			held_old=magazine
			magazine={}
			inspected_loaded_reload=true
			phase="stow"
		clock=0
		return true
	if phase!="":return false
	if pending_slot>=0:
		if prepared_reload:
			phase="ready_remove" if not magazine.is_empty() else ("ready_stow" if not held_old.is_empty() else "ready_insert")
			clock=0
			return true
		phase="remove" if not magazine.is_empty() else ("stow" if not held_old.is_empty() else "draw")
		clock=0
		return true
	if slot<0:slot=best_pouch()
	if slot<0 or slot>=pouches.size():return false
	# Explicit swaps are allowed even when both magazines are full.
	pending_slot=slot
	phase="remove" if not magazine.is_empty() else "stow"
	clock=0
	return true

func rack() -> bool:
	if phase!="" or pending_slot>=0:return false
	phase="rack"
	clock=0
	return true

func inspect_chamber() -> bool:
	if phase!="" or pending_slot>=0:return false
	phase="inspect_chamber"
	clock=0
	return true

func inspect_magazine(slot: int=-1) -> bool:
	if phase!="" or pending_slot>=0 or slot>=pouches.size():return false
	if slot<0 and magazine.is_empty():return false
	inspection_slot=slot
	phase="inspect_mag" if slot<0 else "inspect_pouch"
	clock=0
	return true

func inspected_rounds() -> int:
	return rounds() if inspection_slot<0 else int(pouches[inspection_slot].rounds)

func inspection_estimate() -> String:
	if not inspection_in_hand() or clock<0.85:return ""
	var mag: Dictionary=magazine if inspection_slot<0 else pouches[inspection_slot]
	if mag.is_empty():return ""
	var count := int(mag.rounds)
	if count==0:return "Порожній — набоїв зверху не видно"
	# Stable error for this physical magazine at this fill level; reopening the
	# inspection cannot reroll a series of estimates to recover the exact count.
	var seed_value := absi(hash(id+":"+str(mag.serial)+":"+str(count)))
	var uncertainty := float(seed_value%1001)/1000.0*0.30-0.15
	var fraction := clampf(float(count)/float(data.capacity)+uncertainty,0.01,1)
	if fraction<0.2:return "На вагу: лишилося небагато"
	if fraction<0.4:return "На вагу: менше половини"
	if fraction<0.65:return "На вагу: приблизно половина"
	if fraction<0.85:return "На вагу: більше половини"
	return "На вагу: майже повний"

func cancel() -> void:
	if not packed_magazine.is_empty():
		magazine=packed_magazine
		packed_magazine={}
	# Transfer checkpoints survive interruption. A retained magazine never vanishes
	# and no ammunition is regenerated by switching weapons or receiving a wound.
	phase=""
	clock=0

# The universal cancel (Operator.cancel_action). Nothing is lost and nothing
# is made: a magazine (or the PKM's box) not yet off the weapon stays on it;
# one taken from a pouch for a prepared reload goes back into it; one already
# in the hand stays there and R carries the reload on from that point. A bolt
# pulled past the round lets go and chambers the next; the PKM's handle,
# once back past the sear, leaves the carrier cocked, before that it rides
# forward with it. An inspection just stops.
func interrupt() -> bool:
	match phase:
		"","repack":return false
		"remove":
			pending_slot=-1
			prepared_reload=false
			inspected_loaded_reload=false
		"ready_remove":
			pouches[pending_slot]=held_new
			held_new={}
			pending_slot=-1
			prepared_reload=false
		"rack":
			if id=="pkm":
				if clock>=phase_duration()*0.5:
					cocked=true
					chamber()
			elif not chambered and clock>=0.35:
				bolt_open=false
				chamber()
	phase=""
	clock=0
	return true

# A reload broken off with a magazine in the hand (interrupt, a wound, the
# other weapon): R takes it up again.
func reload_interrupted() -> bool:return phase=="" and pending_slot>=0

func phase_duration() -> float:
	match phase:
		# The PKM: the feed cover lifted, the belt off the tray, the box
		# unlatched; the new box latched on, the belt laid on the tray, the
		# cover shut (with the pouch: about 7 s).
		"remove","ready_remove":return 2.4 if id=="pkm" else (0.7 if phase=="remove" else 0.55)
		"stow":return 0.65 if inspected_loaded_reload else 0.9
		"ready_stow":return 0.55
		"ready_insert":return 2.6 if id=="pkm" else 0.65
		"draw":return 0.7
		"insert":return 2.6 if id=="pkm" else 0.9
		# The PKM's handle back by hand and forward again by hand.
		"rack":return 1.6 if id=="pkm" else 0.85
		"inspect_chamber":return 1.8
		"inspect_mag","inspect_pouch":return 2.1
	return 1.0

func update(delta: float) -> String:
	var event := ""
	if phase=="" or phase=="repack":return event
	clock+=delta
	if phase=="rack" and clock>=0.35 and chambered and id!="pkm":
		chambered=false
		bolt_open=true
		discarded_rounds+=1
		live_ejections+=1
	while phase!="" and clock>=phase_duration():
		clock-=phase_duration()
		match phase:
			"ready_remove":
				belt_off()
				held_old=magazine
				magazine={}
				phase="ready_stow"
			"ready_stow":
				pouches[pending_slot]=held_old
				held_old={}
				phase="ready_insert"
			"remove":
				belt_off()
				held_old=magazine
				magazine={}
				phase="stow"
				event="removed"
			"stow":
				held_new=pouches[pending_slot]
				pouches[pending_slot]=held_old
				held_old={}
				if debug_infinite:held_new.rounds=int(data.capacity)
				phase="draw"
				event="stowed"
			"draw":phase="insert"
			"insert","ready_insert":
				magazine=held_new
				held_new={}
				pending_slot=-1
				prepared_reload=false
				inspected_loaded_reload=false
				# A PKM with its carrier still back is ready again at once.
				if id=="pkm":chamber()
				phase="rack" if auto_rack and not chambered and rounds()>0 else ""
				event="inserted"
			"rack":
				# The PKM's open bolt: nothing in the chamber to throw out, the
				# carrier now held back on the sear.
				if id=="pkm":cocked=true
				else:
					if chambered:
						discarded_rounds+=1
						live_ejections+=1
					chambered=false
				chamber()
				phase=""
				event="racked"
			_:phase=""
	if phase=="":clock=0
	return event

func status() -> String:
	if reload_interrupted():return ("КОРОБКА" if id=="pkm" else "МАГАЗИН")+" У РУЦІ · R — ПРОДОВЖИТИ ПЕРЕЗАРЯДЖАННЯ"
	if id=="pkm":
		var p := clampf(clock/phase_duration(),0,1)
		match phase:
			"remove","ready_remove":return "КРИШКА ВГОРУ" if p<0.3 else ("СТРІЧКА З ПРИЙМАЧА" if p<0.55 else "КОРОБКА ГЕТЬ")
			"stow","ready_stow":return "КОРОБКА В ПІДСУМОК"
			"draw":return "НОВА КОРОБКА"
			"insert","ready_insert":return "КОРОБКА НА МІСЦЕ" if p<0.4 else ("СТРІЧКА НА ПРИЙМАЧ" if p<0.7 else "КРИШКУ ЗАКРИТИ")
			"rack":return "ЗАТВОР: РУКОЯТКУ НАЗАД" if p<0.5 else "РУКОЯТКУ ВПЕРЕД"
	match phase:
		"remove","ready_remove":return "ВИЙМАННЯ МАГАЗИНА"
		"stow","ready_stow":return "ПОВЕРНЕННЯ У ПІДСУМОК"
		"draw":return "МАГАЗИН ІЗ ПІДСУМКА"
		"insert","ready_insert":return "ВСТАВЛЕННЯ МАГАЗИНА"
		"rack":return "ЗАТВОР"
		"inspect_chamber":return "ОГЛЯД ПАТРОННИКА"
		"inspect_mag","inspect_pouch":return "ОГЛЯД МАГАЗИНА · R ПЕРЕЗАРЯДИТИ" if inspection_in_hand() else "ОГЛЯД МАГАЗИНА"
	return mode()

# The PKM's round on the feed tray goes back into the belt when the belt is
# lifted off; the carrier stays where it was.
func belt_off() -> void:
	if id=="pkm" and chambered and not magazine.is_empty():
		magazine.rounds=int(magazine.rounds)+1
		chambered=false

func ammunition_total() -> int:
	var total := int(chambered)+rounds()+int(packed_magazine.get("rounds",0))+int(held_old.get("rounds",0))+int(held_new.get("rounds",0))
	for mag in pouches:total+=int(mag.get("rounds",0))
	return total
