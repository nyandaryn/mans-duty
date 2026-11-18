class_name BackpackState
extends RefCounted

const WIDTH := 6
const HEIGHT := 4
const MAX_PAYLOAD := 18.0
var equipped := false
var items: Array[Dictionary]=[]
var serial := 0

func item(uid: int) -> Dictionary:
 for entry in items:
  if int(entry.uid)==uid:return entry
 return {}

func can_place(kind: String, at: Vector2i, except_uid: int=-1) -> bool:
 if not equipped or not Equipment.ITEMS.has(kind):return false
 var footprint: Vector2i=Equipment.ITEMS[kind].size
 if at.x<0 or at.y<0 or at.x+footprint.x>WIDTH or at.y+footprint.y>HEIGHT:return false
 var area := Rect2i(at,footprint)
 for other in items:
  if int(other.uid)==except_uid:continue
  if area.intersects(Rect2i(Vector2i(other.x,other.y),Equipment.ITEMS[other.kind].size)):return false
 return true

func add(kind: String, at: Vector2i=Vector2i(-1,-1)) -> int:
 if not equipped or not Equipment.ITEMS.has(kind):return -1
 var definition: Dictionary=Equipment.ITEMS[kind]
 var extra := float(definition.mass)+int(definition.get("rounds",0))*float(Equipment.ROUND_MASS.get(definition.get("weapon",""),0))
 if mass()-Equipment.PACK_MASS+extra>MAX_PAYLOAD:return -1
 if at.x<0:
  for y in range(HEIGHT):
   for x in range(WIDTH):
    if can_place(kind,Vector2i(x,y)):at=Vector2i(x,y);break
   if at.x>=0:break
 if not can_place(kind,at):return -1
 serial+=1
 items.append({"uid":serial,"kind":kind,"x":at.x,"y":at.y,"rounds":int(definition.get("rounds",0))})
 if kind=="recon_drone":items[-1].merge({"battery":1.0,"condition":1.0})
 return serial

func move_item(uid: int, at: Vector2i) -> bool:
 var entry := item(uid)
 if entry.is_empty() or not can_place(entry.kind,at,uid):return false
 entry.x=at.x;entry.y=at.y
 return true

func remove(uid: int) -> void:
 var entry := item(uid)
 if not entry.is_empty():items.erase(entry)

func count(kind: String) -> int:
 var total := 0
 for entry in items:
  if entry.kind==kind:total+=1
 return total

func first(kind: String) -> int:
 for entry in items:
  if entry.kind==kind:return int(entry.uid)
 return -1

func used_slots() -> int:
 var total := 0
 for entry in items:
  var s: Vector2i=Equipment.ITEMS[entry.kind].size
  total+=s.x*s.y
 return total

func mass() -> float:
 if not equipped:return 0
 var total := Equipment.PACK_MASS
 for entry in items:
  var definition: Dictionary=Equipment.ITEMS[entry.kind]
  total+=float(definition.mass)+int(entry.rounds)*float(Equipment.ROUND_MASS.get(definition.get("weapon",""),0))
 return total

func serialize() -> Dictionary:
 return {"equipped":equipped,"items":items.duplicate(true)}

static func restore(data: Variant) -> BackpackState:
 var bag := BackpackState.new()
 if not data is Dictionary:return bag
 bag.equipped=data.get("equipped",false)==true
 var entries: Variant=data.get("items",[])
 if not entries is Array:return bag
 for entry in entries.slice(0,24):
  if not entry is Dictionary:continue
  var kind := str(entry.get("kind",""))
  if not Equipment.ITEMS.has(kind):continue
  var x: Variant=entry.get("x",-1)
  var y: Variant=entry.get("y",-1)
  if not (x is float or x is int) or not (y is float or y is int):continue
  if not bag.can_place(kind,Vector2i(int(x),int(y))):continue
  var uid := bag.add(kind,Vector2i(int(x),int(y)))
  if uid<0:continue
  var rounds: Variant=entry.get("rounds",Equipment.ITEMS[kind].get("rounds",0))
  if rounds is float or rounds is int:bag.item(uid).rounds=clampi(int(rounds),0,int(Equipment.ITEMS[kind].get("rounds",0)))
  if kind=="recon_drone":
   for property in ["battery","condition"]:
    var value: Variant=entry.get(property,1.0)
    if (value is float or value is int) and is_finite(float(value)):bag.item(uid)[property]=clampf(float(value),0,1)
 return bag
