precision mediump float;

attribute vec4 a_position;
uniform float time;

varying vec4 v_color;

void main() {
    gl_Position = vec4(a_position.xy, 0.0, 1.0);
    vec4 color_pos = vec4(sin(time) * a_position.x, cos(time) * a_position.y, gl_Position.z, gl_Position.w);
    v_color = color_pos * 0.5 + 0.5;
}