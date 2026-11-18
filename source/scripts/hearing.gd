class_name CombatHearing
extends Node

var exposure := 0.0
var intensity := 0.0
var injury_floor := 0.0
var bus_name: String
var filter := AudioEffectLowPassFilter.new()
var ring := AudioStreamPlayer.new()

func _ready() -> void:
	bus_name="Combat_%d" % get_instance_id()
	AudioServer.add_bus()
	var bus := AudioServer.bus_count-1
	AudioServer.set_bus_name(bus,bus_name)
	AudioServer.add_bus_effect(bus,filter)
	var bytes := PackedByteArray()
	bytes.resize(44100*2)
	for i in range(44100):
		var t := float(i)/44100.0
		bytes.encode_s16(i*2,int((sin(TAU*3600*t)*0.65+sin(TAU*4400*t)*0.25)*8000))
	var wav := AudioStreamWAV.new()
	wav.format=AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate=44100
	wav.data=bytes
	wav.loop_mode=AudioStreamWAV.LOOP_FORWARD
	wav.loop_end=44100
	ring.stream=wav
	ring.volume_db=-80
	add_child(ring)

func shot(distance: float, own: bool=false) -> void:
	exposure=minf(1.6,exposure+(0.105 if own else 0.075/pow(maxf(distance/3.0,1),1.5)))

func update(delta: float, active: bool, volume: float) -> void:
	if active:
		exposure=move_toward(exposure,0,delta*0.065)
		intensity=move_toward(intensity,maxf(injury_floor,clampf((exposure-0.30)/0.85,0,1)),delta*1.8)
	var bus := AudioServer.get_bus_index(bus_name)
	filter.cutoff_hz=lerpf(20000,1900,intensity)
	AudioServer.set_bus_volume_db(bus,-intensity*8)
	if active and volume>0 and intensity>=0.01 and not ring.playing:ring.play()
	if intensity<0.01:ring.stop()
	ring.stream_paused=not active or volume<=0
	ring.volume_db=-80 if intensity<0.01 or volume<=0 else -24+linear_to_db(intensity*volume)

func reset() -> void:
	injury_floor=0
	exposure=0
	intensity=0
	update(0,false,0)

func _exit_tree() -> void:
	ring.stop()
	ring.stream=null
	var bus := AudioServer.get_bus_index(bus_name)
	if bus>0:AudioServer.remove_bus(bus)
