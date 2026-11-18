shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D view : source_color, filter_linear;
uniform vec2 pupil = vec2(0.0);
uniform float relief_error = 0.0;
uniform float active = 0.0;
uniform float blocked = 0.0;
void fragment() {
 vec2 p = UV * 2.0 - 1.0;
 if (length(p) > 1.0) discard;
 vec3 glass = vec3(0.015,0.022,0.020);
 float field = 1.0-smoothstep(0.88,1.0,length(p));
 float eye = 1.0-smoothstep(0.72,1.0,length(p-pupil*0.58)+relief_error*0.62);
 float light = field*eye*(1.0-blocked)*active;
 vec3 scene = texture(view,UV).rgb;
 ALBEDO = mix(glass,scene*vec3(0.96,0.97,0.91),light);
}
