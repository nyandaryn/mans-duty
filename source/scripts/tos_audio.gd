class_name TosAudio
extends RefCounted

# Sounds of the TOS-1A. A recording of the vehicle itself is used where
# there is one under assets/audio/tos (see AUDIO-CREDITS); otherwise the
# BM-21's recorded launch stands in, played lower (TosVehicle.play_launch):
# the MO.1.01.04M is a 220 mm rocket with a heavier, shorter-burning motor.
static var cache: Dictionary={}

static func clip(id: String) -> AudioStream:
 if cache.has(id):return cache[id]
 var path:="res://assets/audio/tos/%s.wav" % id
 var stream: AudioStream=load(path) if ResourceLoader.exists(path) else GradAudio.clip(id)
 cache[id]=stream
 return stream
