class_name GradAudio
extends RefCounted

# Recorded sounds of the BM-21 (see AUDIO-CREDITS): launches filmed by DVIDS
# (public domain) and by Operational Command West of the Armed Forces of
# Ukraine (CC BY 4.0); the engine is a BM-21-1 on the Ural-4320 chassis laying
# its package (Ministry of Defence of the Russian Federation, CC BY 4.0).
static var cache: Dictionary={}

static func clip(id: String) -> AudioStream:
 if not cache.has(id):cache[id]=load("res://assets/audio/grad/%s.wav" % id)
 return cache[id]

static func engine() -> AudioStreamWAV:return looped("engine_loop","res://assets/audio/grad/engine_idle.wav")

# A recorded engine as an endless loop (the files are cut to loop cleanly).
static func looped(key: String, path: String) -> AudioStreamWAV:
 if cache.has(key):return cache[key]
 var source: AudioStreamWAV=load(path)
 var sample: AudioStreamWAV=source.duplicate()
 sample.loop_mode=AudioStreamWAV.LOOP_FORWARD
 sample.loop_begin=0
 sample.loop_end=int(sample.get_length()*sample.mix_rate)-1
 cache[key]=sample
 return sample

# Short synthesised cab noises: the starter, the gear clash, the air valve,
# the far thump of a 122-mm burst.
static func synth(kind: String) -> AudioStreamWAV:
 if cache.has(kind):return cache[kind]
 var rate:=22050
 var length: float={"starter":1.0,"grind":0.45,"air":0.7,"thump":2.4}[kind]
 var count:=int(rate*length)
 var bytes:=PackedByteArray();bytes.resize(count*2)
 var rng:=RandomNumberGenerator.new();rng.seed=3711+kind.length()
 var low:=0.0;var phase:=0.0
 for i in range(count):
  var t:=float(i)/rate
  var noise:=rng.randf_range(-1,1)
  low=lerpf(low,noise,0.06)
  var sample:=0.0
  if kind=="starter":
   phase+=TAU*(38.0+sin(t*TAU*7.0)*6.0)/rate
   sample=(sin(phase)*0.5+sin(phase*3.0)*0.2+noise*0.12)*0.8
  elif kind=="grind":sample=(noise*0.6+sin(TAU*1900*t)*0.25*rng.randf())*exp(-t*3.0)
  elif kind=="air":sample=noise*0.5*exp(-t*4.0)*smoothstep(0.0,0.03,t)
  else:sample=low*3.2*exp(-t*1.6)+sin(TAU*31*t)*0.35*exp(-t*2.2)
  bytes.encode_s16(i*2,int(clampf(sample,-0.95,0.95)*28000))
 var audio:=AudioStreamWAV.new();audio.format=AudioStreamWAV.FORMAT_16_BITS;audio.mix_rate=rate;audio.data=bytes
 if kind=="starter":
  audio.loop_mode=AudioStreamWAV.LOOP_FORWARD;audio.loop_end=count-1
 cache[kind]=audio
 return audio
