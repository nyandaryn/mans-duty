class_name ConcussionState
extends RefCounted

# Persistent mission injury, separate from short-lived acoustic stunning and
# treatable wounds. Severity/timings are game states, not clinical predictions.
var severity := 0.0
var acute_left := 0.0
var blackout_left := 0.0
var elapsed := 0.0
var events := 0

func apply(amount: float) -> void:
 if amount<0.18:return
 events+=1
 severity=clampf(maxf(severity,amount)+minf(severity,amount)*0.25,0,1)
 acute_left=maxf(acute_left,12+severity*65)
 if severity>=0.7:blackout_left=maxf(blackout_left,5+severity*13)
 elapsed=0

func tick(delta: float) -> void:
 elapsed+=delta
 acute_left=maxf(0,acute_left-delta)
 blackout_left=maxf(0,blackout_left-delta)
 # No passive recovery to combat fitness during an operation, and no medkit reset.

func active() -> bool:return severity>0
func incapacitated() -> bool:return severity>=0.70
func can_aim() -> bool:return severity<0.35 and acute_left<=0
func can_fire() -> bool:return severity<0.55 and acute_left<=0
func movement_multiplier() -> float:
 if incapacitated() or blackout_left>0:return 0
 return (0.25 if acute_left>0 else 1.0)*(1-severity*0.55)

func view_sway(clock: float) -> Vector3:
 return Vector3(sin(clock*1.13)*0.016,sin(clock*0.73)*0.010,sin(clock*0.91)*0.020)*severity

func darkness(clock: float) -> float:
 if blackout_left>0:return 0.98
 return severity*(0.20+(0.18 if acute_left>0 else 0.04)+sin(clock*0.8)*0.025)
