shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float severity = 0.0;
uniform float clock = 0.0;
void fragment() {
 vec2 offset = vec2(0.0018 + sin(clock * 0.7) * 0.0006, 0.0008) * severity;
 vec3 center = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
 vec3 ghost = textureLod(screen_texture, SCREEN_UV + offset, 0.0).rgb;
 vec3 soft = textureLod(screen_texture, SCREEN_UV - offset, 0.0).rgb;
 vec3 color = mix(center, (center + ghost + soft) / 3.0, severity * 0.85);
 float grey = dot(color, vec3(0.299, 0.587, 0.114));
 COLOR = vec4(mix(color, vec3(grey), severity * 0.45), 1.0);
}
