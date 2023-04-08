attribute vec4 a_position;
attribute vec2 aTextureCoord;
varying highp vec2 vTextureCoord;

void main(void) {
    gl_Position = a_position;
    vTextureCoord = aTextureCoord;
}