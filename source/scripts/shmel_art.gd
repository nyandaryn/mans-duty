class_name ShmelArt
extends RefCounted

# RPO-A public identification data; see SHMEL-REFERENCES.md. No warhead model.
const MASS_KG := 11.0
const LENGTH_M := 0.920
const CALIBER_MM := 93
const INITIAL_SPEED := 125.0
const SIGHT_X := -0.083
const SIGHT_Y := 0.125
const REAR_SIGHT_Z := 0.10

static func build() -> Node3D:
 var root := Node3D.new();root.name="RPO_A_Shmel"
 # Fibreglass launch container, protective collars, grips, sling and open sights.
 Models.tube(root,Vector3(0,0,-0.10),0.060,0.88,"#596143",Vector3.FORWARD)
 for z in [-0.55,-0.51,0.31,0.35]:
  Models.tube(root,Vector3(0,0,z),0.069,0.025,"#2d352b",Vector3.FORWARD)
  Models.tube(root,Vector3(0,0,z-0.014),0.071,0.006,"#85856a",Vector3.FORWARD)
 for z in [-0.567,0.368]:
  Models.tube(root,Vector3(0,0,z),0.053,0.004,"#111910",Vector3.FORWARD)
  for i in range(10):
   var angle := i*TAU/10
   Models.bevel(root,Vector3(cos(angle)*0.065,sin(angle)*0.065,z+0.002),Vector3(0.009,0.008,0.012),"#3e4939",0.002)
 for z in [-0.19,0.15]:
  var grip := Models.bevel(root,Vector3(-0.035,-0.105,z),Vector3(0.036,0.11,0.048),"#242c22",0.007)
  grip.rotation.x=-0.15
  for y in [-0.07,-0.09,-0.11,-0.13]:Models.bevel(root,Vector3(-0.056,y,z),Vector3(0.004,0.004,0.041),"#4b5142",0.001)
 Models.bevel(root,Vector3(-0.047,-0.065,0.09),Vector3(0.025,0.033,0.12),"#293326",0.004)
 for z in [-0.40,REAR_SIGHT_Z]:
  Models.bevel(root,Vector3(SIGHT_X,0.055,z),Vector3(0.012,0.10,0.010),"#293326",0.002)
  for x in [-0.021,0.021]:Models.limb(root,Vector3(SIGHT_X+x,0.10,z),Vector3(SIGHT_X+x,0.151,z),0.003,"#252e25")
  Models.limb(root,Vector3(SIGHT_X-0.021,0.151,z),Vector3(SIGHT_X+0.021,0.151,z),0.003,"#252e25")
 # A real opening between rear notch sides; nothing fills the sight line.
 for x in [-0.012,0.012]:Models.bevel(root,Vector3(SIGHT_X+x,SIGHT_Y,REAR_SIGHT_Z),Vector3(0.014,0.008,0.006),"#87917f",0.001)
 Models.bevel(root,Vector3(SIGHT_X,SIGHT_Y-0.009,REAR_SIGHT_Z),Vector3(0.038,0.010,0.006),"#293326",0.001)
 Models.bevel(root,Vector3(SIGHT_X,SIGHT_Y-0.009,-0.40),Vector3(0.003,0.018,0.006),"#969b88",0.001)
 Models.bevel(root,Vector3(-0.061,0.015,-0.02),Vector3(0.002,0.065,0.17),"#c7c6ad",0.001)
 for z in [-0.07,-0.045,-0.02,0.005,0.03]:Models.bevel(root,Vector3(-0.063,0.015,z),Vector3(0.001,0.032,0.003),"#565d47",0.0003)
 for z in [-0.35,0.25]:Models.bevel(root,Vector3(0.064,0,z),Vector3(0.012,0.024,0.028),"#626b52",0.003)
 Models.limb(root,Vector3(0.074,0,-0.35),Vector3(0.095,-0.035,-0.05),0.009,"gear_#5e654a")
 Models.limb(root,Vector3(0.095,-0.035,-0.05),Vector3(0.074,0,0.25),0.009,"gear_#5e654a")
 var muzzle := Marker3D.new();muzzle.name="Muzzle";muzzle.position=Vector3(0,0,-0.59);root.add_child(muzzle)
 Models.merge_rigid(root)
 return root

static func sound(blast: bool) -> AudioStreamWAV:
 # Original synthesised effects, not a claimed recording of this weapon.
 var rate := 22050;var count := int(rate*(1.6 if blast else 0.55))
 var bytes := PackedByteArray();bytes.resize(count*2)
 var rng := RandomNumberGenerator.new();rng.seed=81311 if blast else 81312
 var low := 0.0
 for i in range(count):
  var t := float(i)/rate
  var noise := rng.randf_range(-1,1)
  low=lerpf(low,noise,0.10)
  var sample := (noise*0.32*exp(-t*24)+low*2.4*exp(-t*3)+sin(TAU*54*t)*0.16*exp(-t*5)) if blast else noise*exp(-t*12)*0.65+low*exp(-t*6)
  bytes.encode_s16(i*2,int(clampf(sample,-0.9,0.9)*28000))
 var audio := AudioStreamWAV.new();audio.format=AudioStreamWAV.FORMAT_16_BITS;audio.mix_rate=rate;audio.data=bytes
 return audio
