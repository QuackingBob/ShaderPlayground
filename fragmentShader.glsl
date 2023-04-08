precision mediump float;

varying vec4 v_color;

void main() {
    gl_FragColor = vec4(fract(v_color.rgb), 1);
}