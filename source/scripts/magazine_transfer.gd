class_name MagazineTransfer
extends RefCounted

const ROUND_TIME := 0.9
var weapon: WeaponState
var source: Dictionary={}
var destination: Dictionary={}
var active := false
var clock := 0.0
var draw_left := 0.0
var stow_left := 0.0
var moved := 0
var planned := 0
var box_bag: BackpackState
var box_uid := -1
var source_slot := -1
var destination_slot := -1
var elapsed := 0.0
var access_duration := 1.0

static func magazine_at(w: WeaponState, slot: int) -> Dictionary:
 if slot==0:return w.packed_magazine if not w.packed_magazine.is_empty() else w.magazine
 if slot>0 and slot<=w.pouches.size():return w.pouches[slot-1]
 return {}

func begin(w: WeaponState, from_slot: int, to_slot: int) -> bool:
 if active or from_slot==to_slot or w.phase!="" or w.pending_slot>=0:return false
 var a := magazine_at(w,from_slot)
 var b := magazine_at(w,to_slot)
 if a.is_empty() or b.is_empty():return false
 planned=mini(int(a.rounds),int(w.data.capacity)-int(b.rounds))
 if planned<=0:return false
 box_bag=null
 box_uid=-1
 source_slot=from_slot
 destination_slot=to_slot
 elapsed=0
 access_duration=1.0
 weapon=w
 source=a
 destination=b
 moved=0
 clock=0
 draw_left=1.0
 stow_left=0
 active=true
 w.phase="repack"
 # A magazine in the firearm is physically removed for repacking; the chamber
 # is untouched. The retained object also participates in ammunition_total().
 if from_slot==0 or to_slot==0:
  w.packed_magazine=w.magazine
  w.magazine={}
 return true

func begin_box(w: WeaponState, bag: BackpackState, uid: int, to_slot: int) -> bool:
 if active or w.phase!="" or w.pending_slot>=0 or not bag.equipped:return false
 var entry := bag.item(uid)
 if entry.is_empty() or Equipment.ITEMS[entry.kind].get("weapon","")!=w.id:return false
 var target := magazine_at(w,to_slot)
 if target.is_empty():return false
 planned=mini(int(entry.rounds),int(w.data.capacity)-int(target.rounds))
 if planned<=0:return false
 box_bag=bag;box_uid=uid;weapon=w;source=entry;destination=target
 source_slot=-1;destination_slot=to_slot
 moved=0;clock=0;elapsed=0;stow_left=0
 access_duration=3.4;draw_left=access_duration;active=true
 w.phase="repack"
 if to_slot==0:w.packed_magazine=w.magazine;w.magazine={}
 return true

func update(delta: float) -> void:
 if not active:return
 elapsed+=delta
 if weapon.phase!="repack":cancel();return
 if draw_left>0:
  var used := minf(delta,draw_left)
  draw_left-=used
  delta-=used
 if moved>=planned:
  stow_left-=delta
  if stow_left<=0:cancel()
  return
 clock+=delta
 while clock>=ROUND_TIME and moved<planned:
  if int(source.rounds)<=0 or int(destination.rounds)>=int(weapon.data.capacity):cancel();return
  clock-=ROUND_TIME
  source.rounds-=1
  destination.rounds+=1
  moved+=1
 if moved==planned:stow_left=2.2 if box_bag!=null else 0.8

func cancel() -> void:
 if is_instance_valid(weapon) and weapon.phase=="repack":weapon.cancel()
 active=false
 if box_bag!=null and not box_bag.item(box_uid).is_empty() and int(box_bag.item(box_uid).rounds)==0:box_bag.remove(box_uid)

func progress() -> float:
 if not active:return 1
 return clampf((moved+clock/ROUND_TIME)/maxi(1,planned),0,1)
