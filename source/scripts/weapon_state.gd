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
var mode_index := 0
var phase := ""
var clock := 0.0
var magazine_serial := 1
var discarded_rounds := 0
var live_ejections := 0
var shots_fired := 0
var debug_infinite := false
var scope_zero := 100
var scope_windage := 0 # Half-milliradian clicks, positive = right correction.
var scope_illuminated := false

func _init(weapon_id: String="ak74") -> void:
	id=weapon_id
	data=DATA[id]
	magazine={"serial":1,"rounds":int(data.capacity)}
	# Spare boxes of 100 for the machine gun: two on the gunner.
	for i in range(2 if id in ["pm","m9","pkm"] else 3):pouches.append({"serial":i+2,"rounds":int(data.capacity)})
	if id=="pkm":scope_zero=300
	chamber()

func rounds() -> int:return int(magazine.get("rounds",0))
func mode() -> String:return data.modes[mode_index]
func cycle_mode() -> void:mode_index=(mode_index+1)%data.modes.size()

func chamber() -> void:
	if not chambered and rounds()>0:
		magazine.rounds-=1
		chambered=true
		bolt_open=false

func fire() -> bool:
	if phase!="" or not chambered:return false
	shots_fired+=1
	chambered=false
	chamber()
	if not chambered:bolt_open=bool(data.hold_open)
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

func phase_duration() -> float:
	match phase:
		# The PKM: the feed cover lifted and the old belt out of the tray; the
		# new belt laid on it and the cover shut (with the box: about 7 s).
		"remove":return 1.5 if id=="pkm" else 0.7
		"stow":return 0.65 if inspected_loaded_reload else 0.9
		"ready_remove":return 0.55
		"ready_stow":return 0.55
		"ready_insert":return 0.65
		"draw":return 0.7
		"insert":return 2.2 if id=="pkm" else 0.9
		"rack":return 0.85
		"inspect_chamber":return 1.8
		"inspect_mag","inspect_pouch":return 2.1
	return 1.0

func update(delta: float) -> String:
	var event := ""
	if phase=="" or phase=="repack":return event
	clock+=delta
	if phase=="rack" and clock>=0.35 and chambered:
		chambered=false
		bolt_open=true
		discarded_rounds+=1
		live_ejections+=1
	while phase!="" and clock>=phase_duration():
		clock-=phase_duration()
		match phase:
			"ready_remove":
				held_old=magazine
				magazine={}
				phase="ready_stow"
			"ready_stow":
				pouches[pending_slot]=held_old
				held_old={}
				phase="ready_insert"
			"remove":
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
				phase="rack" if auto_rack and not chambered and rounds()>0 else ""
				event="inserted"
			"rack":
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
	match phase:
		"remove","ready_remove":return "ВИЙМАННЯ МАГАЗИНА"
		"stow","ready_stow":return "ПОВЕРНЕННЯ У ПІДСУМОК"
		"draw":return "МАГАЗИН ІЗ ПІДСУМКА"
		"insert","ready_insert":return "ВСТАВЛЕННЯ МАГАЗИНА"
		"rack":return "ЗАТВОР"
		"inspect_chamber":return "ОГЛЯД ПАТРОННИКА"
		"inspect_mag","inspect_pouch":return "ОГЛЯД МАГАЗИНА · R ПЕРЕЗАРЯДИТИ" if inspection_in_hand() else "ОГЛЯД МАГАЗИНА"
	return mode()

func ammunition_total() -> int:
	var total := int(chambered)+rounds()+int(packed_magazine.get("rounds",0))+int(held_old.get("rounds",0))+int(held_new.get("rounds",0))
	for mag in pouches:total+=int(mag.get("rounds",0))
	return total
