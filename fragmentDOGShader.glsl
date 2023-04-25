precision mediump float;

varying highp vec2 vTextureCoord;

const int maxKernelSize = 200;
const int NMAX = 10;
const int RGB_MAX = 3 * NMAX;

uniform sampler2D uSampler;
uniform vec2 uResolution;
uniform int uKernelSize;
uniform float uRadius;
uniform float uSigma;
uniform float uTau;
uniform float uK;
uniform float uPhi;
uniform float uEpsilon;
uniform int uN;
uniform int rgb_vals[RGB_MAX];
uniform int uMode;

float gaussian(float x, float sigma) {
    return 1.0 / (sigma * sqrt(6.28318530718)) * exp(-0.5 * pow(x / sigma, 2.0));
}

float luminance(vec4 color) {
    return 0.2126 * color.x + 0.7152 * color.y + 0.0722 * color.z;
}

vec4 gray_scale(vec4 color) {
    float luminance = luminance(color);
    return vec4(luminance, luminance, luminance, luminance);
}

float tanh(float x) {
  return (exp(x) - exp(-x)) / (exp(x) + exp(-x));
}

float logistic(float x, float a, float b, float c, float d) {
    return a / (b + exp(-c * (x - d)));
}

vec4 rgb(int r, int g, int b) {
    return vec4(float(r)/255.0, float(g)/255.0, float(b)/255.0, 1.0);
}

vec4 gaussian_blur(sampler2D image, vec2 uv, vec2 resolution, float sigma) {
    vec4 color = vec4(0.0);
    vec2 texelSize = 1.0 / resolution;
    int kernelSize = uKernelSize;

    // horizontal blur pass
    float weightSum = 0.0;
    for (int i = 0; i < maxKernelSize; i++) {
        int j = i - kernelSize;
        if (j >= kernelSize) break;
        float weight = gaussian(float(j), sigma);
        color += gray_scale(texture2D(image, uv + texelSize * vec2(float(j), 0.0))) * weight;
        weightSum += weight;
    }

    color /= weightSum;

    // vertical blur pass
    weightSum = 0.0;
    for (int i = 0; i < maxKernelSize; i++) {
        int j = i - kernelSize;
        if (j >= kernelSize) break;
        float weight = gaussian(float(j), sigma);
        color += gray_scale(texture2D(image, uv + texelSize * vec2(0.0, float(j)))) * weight;
        weightSum += weight;
    }
    
    color /= weightSum;

    return color;
}

vec4 threshold(vec4 color, float phi, float epsilon) {
    float luminance = 0.2126 * color.x + 0.7152 * color.y + 0.0722 * color.z;
    vec4 gray_rgb;
    if (luminance >= epsilon) {
        gray_rgb += vec4(1.0, 1.0, 1.0, 1.0);
    }
    else {
        float scale = 1.0 + tanh(phi * (luminance - epsilon));
        gray_rgb += vec4(scale, scale, scale, scale);
    }
    // gray_rgb = 1.0 - gray_rgb;
    return gray_rgb;
}

vec4 threetonethreshold(vec4 color) {
    float luminance = luminance(color);
    vec4 out_color;
    if (luminance < 0.3333) {
        out_color = vec4(luminance*luminance);
        out_color.y = 0.0;
        out_color.z = 0.0;
    }
    else if (luminance < 0.75) {
        out_color = vec4(logistic(luminance, 2.8, 1.3, 3.3, 1.8) - logistic(0.3333, 2.8, 1.3, 3.3, 1.8) + luminance*luminance);
        out_color.x = 0.0;
        out_color.z = 0.0;
    }
    else {
        out_color = vec4(logistic(luminance, 1.0, 1.0, 4.0, 1.0) - logistic(0.75, 1.0, 1.0, 4.0, 1.0) + logistic(0.75, 2.8, 1.3, 3.3, 1.8));
        out_color.x = 0.0;
        out_color.y = 0.0;
    }
    return out_color * 2.5;
}

vec4 ntonethresh(vec4 color) {
    float luminance = luminance(color);

    float a = 0.2;
    float k = 85.0;
    float x1 = 0.18;

    float threshold_val;
    float scale_val;
    vec4 out_color = vec4(1.0);
    for (int i = 0; i < NMAX; i++) {
        if (i >= uN) break;
        threshold_val += logistic(luminance, a, 1.0, k, float(i + 1) * x1);
    }

    int color_index = int(floor(threshold_val / a));
    scale_val = (threshold_val - float(color_index+1) * a) / a;
    for (int i = 0; i < RGB_MAX; i++) {
        if (i >= 3 * uN) break;
        if (i == color_index * 3) out_color.x = float(rgb_vals[i]) / 255.0;
        if (i == color_index * 3 + 1) out_color.y = float(rgb_vals[i]) / 255.0;
        if (i == color_index * 3 + 2) out_color.z = float(rgb_vals[i]) / 255.0;
    }
    // out_color = rgb(rgb_vals[3*color_index], rgb_vals[3*color_index + 1], rgb_vals[3*color_index + 2]);

    // out_color.xyz *= threshold_val;
    // out_color.xyz *= scale_val;

    // out_color.xyz = 1.0 - out_color.xyz;

    return out_color;
}

// helper function to convolve kernel and pixel region
float convolve(mat3 kernel, mat3 val) {
    float accumulator = 0;
    for (int i = 0; i < 3; i++) {
        for (int j = 0; j < 3; j++) {
            accumulator += kernel[i][j] * val[i][j];
        }
    }
    return accumulator;
}

// Compute image gradients Ix and Iy using Sobel operator
vec2 sobel(sampler2D image, vec2 uv, vec2 resolution) {
    vec2 texel = 1.0 / resolution;

    mat3 region = mat3(1);
    for (int i = 0; i < 3; i++) {
        for (int j = 0; j < 3; j++) {
            region[i][j] = luminance(texture2D(image, uv + vec2(float(i - 1) * texel.x, float(j - 1) * texel.y)));
        }
    }

    const mat3 Gx = mat3(1, 0, -1, 2, 0, -2, 1, 0, -1);
    float grad_x = convolve(Gx, region);

    const mat3 Gy = mat3(1, 2, 1, 0, 0, 0, -1, -2, -1);
    float grad_y = convolve(Gy, region);

    return vec2(grad_x, grad_y);
}

// get smoothed structure tensor
mat2 sst(sampler2D image, vec2 uv, vec2 resolution, float sigma) {
    vec2 grad = sobel(image, uv, resolution);

    float Ix = grad.x;
    float Iy = grad.y;

    float s_xx = gaussian(Ix * Ix, sigma);
    float s_xy = gaussian(Ix * Iy, sigma);
    float s_yy = gaussian(Iy * Iy, sigma);

    return mat2(s_xx, s_xy, s_xy, s_yy);
}

vec2 findeigenvec(float t, mat2 S) {
    // A v = t v
    /*
        |a b|        |x|    |a b||x|    |x|
    A = |c d|    v = |y|    |c d||y| = t|y|

    ax + by = tx
    cx + dy = ty

    (a - t)x +       by = 0
          cx + (d - t)y = 0

    c = a - t
    b = d - t
    */
    vec2 eigen_vec;
    if (S[0][1] != 0) {
        eigen_vec = vec2(S[0][1], t - S[0][0]);
    }
    else {
        eigen_vec = vec2(1.0, - (a - t) / c);
    }

    // normalize the eigen vectors
    eigen_vec /= length(eigen_vec);

    return eigen_vec;
}

// eigen-analysis of sst (principal component analysis) first row is major, second row is minor eigenvector
mat2 geteigenvec(sampler2D image, vec2 uv, vec2 resolution, float sigma) {
    mat2 S = sst(image, uv, resolution, sigma);

    // coefficients of polynomial (a = 1) ax^2 + bx + c
    float b = -(S[0][0] + S[1][1]);
    float c = (S[0][0] * S[0][1] - S[1][0] * S[1][1]);

    // discriminant of quadratic formula (should be greater than 0)
    float D = b*b - 4 * c;

    // find lambda 1 & 2
    float t1 = (b + sqrt(D)) / 2.0;
    float t2 = (b - sqrt(D)) / 2.0;

    vec2 evec1, evec2;
    evec1 = findeigenvec(t1, S);
    evec2 = findeigenvec(t2, S);

    mat2 output;
    if (t1 >= t2) {
        output = mat2(evec1.x, evec1.y, evec2.x, evec2.y);
    }
    else {
        output = mat2(evec2.x, evec2.y, evec1.x, evec1.y);
    }

    return output;
}


void main() {
    vec4 color = (1.0 + uTau) * gaussian_blur(uSampler, vTextureCoord, uResolution, uSigma) - uTau * gaussian_blur(uSampler, vTextureCoord, uResolution, uK * uSigma);
    if (uMode == 1) {
        gl_FragColor = ntonethresh(color);
    }
    else {
        gl_FragColor = threshold(color, uPhi, uEpsilon);
    }
    // gl_FragColor = gaussian_blur(uSampler, vTextureCoord, uResolution, uSigma);
}