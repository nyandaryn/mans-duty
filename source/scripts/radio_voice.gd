class_name RadioVoice
extends Node

# The commander's orders on the squad radio net: recorded lines (Piper TTS
# through a field-radio chain, tools/radio_voice.py) heard in the headset —
# the click of the press-to-talk switch and the squelch first, the voice
# narrow and a little driven, the squelch tail at the end. One transmission
# at a time: orders given together are heard one after another. Each line
# is shown at the top of the screen while it plays.
const LINES := {
	"hold":"Увага всім! Стоїмо на місці, чекаємо роботу «Градів».",
	"grad_fire":"«Гради», вогонь!",
	"mount_up":"По машинах!",
	"column":"Колона — вперед!",
	"dismount":"Десант, до машини!",
	"file":"За БМП, колоною по одному!",
	"assault":"Відділення — на штурм! Розсипом, вперед!",
	"mount":"По місцях!",
	"strongpoint":"Опорний пункт знищено! Вперед, до наступного!",
	"cleared":"Село зачищено! Закріпитися!",
}
const PATH := "res://assets/audio/radio_voice/%s.ogg"
const GAP := 0.35
var game: Node3D
var output: AudioStreamPlayer
var caption: Label
var queue: Array[String]=[]
var current := ""
var current_left := 0.0
var gap_left := 0.0
var caption_left := 0.0
# Every line started in this match, in order (the tests read it).
var heard: Array[String]=[]

func setup(owner_game: Node3D, parent: Control) -> void:
	game=owner_game
	name="RadioVoice"
	output=AudioStreamPlayer.new()
	output.bus=game.hearing.bus_name
	add_child(output)
	caption=game.label("",17,Color("cfe3c1"))
	caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_constant_override("outline_size",5)
	caption.add_theme_color_override("font_outline_color",Color(0.02,0.03,0.02,0.85))
	game.place(caption,parent,0.25,0.243,0.75,0.298)
	caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
	caption.hide()

func reset() -> void:
	queue.clear();heard.clear();current="";current_left=0.0;gap_left=0.0;caption_left=0.0
	if is_instance_valid(output):output.stop()
	if is_instance_valid(caption):caption.hide()

# The orders reach the player's own squad: the rifleman, the sniper and the
# mortarman in the great assault, the BMP driver who leads his squad anywhere.
func listening() -> bool:
	return game.player_class=="bmp" or (game.battle.active and game.player_class in PlayerClass.INFANTRY+["mortarman"])

func say(id: String) -> void:
	if not LINES.has(id) or not listening():return
	# The same order already waiting is not repeated.
	if id in queue or id==current:return
	queue.append(id)

func speaking() -> bool:return current!="" or not queue.is_empty()

# Timed by the length of each line, not by the player's signal: the order
# goes on with the sound off too. A line begun before the end of the match
# («Село зачищено!») is heard over the results.
func _process(delta: float) -> void:
	if game==null or not is_instance_valid(output):return
	output.stream_paused=game.paused
	if game.paused:return
	if caption_left>0.0:
		caption_left-=delta
		if caption_left<=0.0:caption.hide()
	if current!="":
		current_left-=delta
		if current_left>0.0:return
		current="";gap_left=GAP
	gap_left-=delta
	if gap_left>0.0 or queue.is_empty():return
	current=queue.pop_front()
	heard.append(current)
	output.stream=load(PATH % current)
	output.volume_db=linear_to_db(maxf(game.volume,0.0001))+1.0
	output.play()
	current_left=output.stream.get_length() if output.stream!=null else 2.0
	caption.text="РАЦІЯ · КОМАНДИР: %s" % LINES[current]
	caption.show()
	caption_left=current_left+1.2
