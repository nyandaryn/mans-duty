class_name GroundSupport
extends RefCounted

# Fit a support plane to the actual collision surface, including small ridges
# and steps. A ray at the centre alone misses the ground under the extremities.
static func sample(space: PhysicsDirectSpaceState3D, origin: Vector3, heading: Basis, half_width: float, front: float, rear: float, exclude: Array[RID]) -> Dictionary:
 var points: Array[Vector3]=[]
 var middle := (front+rear)*0.5
 for x in [-half_width,0.0,half_width]:
  for z in [front,middle,rear]:
   var at := origin+heading*Vector3(x,0,z)
   # Search below knee level first, so a tabletop/low roof is not mistaken
   # for the ground beneath a prone soldier. Extend upward only uphill.
   var ray := PhysicsRayQueryParameters3D.create(at+Vector3.UP*0.28,at+Vector3.DOWN*1.3,1,exclude)
   var hit := space.intersect_ray(ray)
   if hit.is_empty():
    ray.from=at+Vector3.UP*1.3
    hit=space.intersect_ray(ray)
   if hit.is_empty() or Vector3(hit.normal).y<0.5:return {}
   points.append(Vector3(x,Vector3(hit.position).y-origin.y,z))
 var average := Vector3.ZERO
 for point in points:average+=point/points.size()
 var xx := 0.0;var zz := 0.0;var xy := 0.0;var zy := 0.0
 for point in points:
  var d := point-average
  xx+=d.x*d.x;zz+=d.z*d.z;xy+=d.x*d.y;zy+=d.z*d.y
 var slope_x := xy/xx
 var slope_z := zy/zz
 var normal := (heading*Vector3(-slope_x,1,-slope_z)).normalized()
 if normal.y<0.57:return {}
 var intercept := average.y-slope_x*average.x-slope_z*average.z
 var lift := 0.0
 for point in points:lift=maxf(lift,point.y-(intercept+slope_x*point.x+slope_z*point.z))
 # Larger discontinuities are real obstacles, not uneven soil.
 if lift>0.28:return {}
 var back := (heading.z-normal*heading.z.dot(normal)).normalized()
 var basis := Basis(normal.cross(back).normalized(),normal,back)
 return {"frame":Transform3D(basis,origin+Vector3.UP*(intercept+lift)),"roughness":lift}
