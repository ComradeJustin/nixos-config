#version 440

// Draws a picture in two colours. The picture's brightness at each dot is
// compared against an ordered (Bayer) pattern of thresholds: brighter than
// the threshold gives the light colour, darker gives the dark one. Bright
// areas come out mostly light, dark areas mostly dark, and everything in
// between as a regular scatter of dots, like a newspaper photograph.
//
// This is the source. Qt loads the compiled dither-image.frag.qsb beside it.
// After editing, rebuild it with:
//   nix shell nixpkgs#kdePackages.qtshadertools -c qsb --glsl "100 es,120,150" -o dither-image.frag.qsb dither-image.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    // Size of one dither dot, in pixels.
    float dotSize;
    // The picture's size on screen, in pixels.
    vec2 size;
    // The two colours.
    vec4 dark;
    vec4 light;
};

layout(binding = 1) uniform sampler2D source;

// The 2x2 Bayer pattern (0, 1/2, 3/4, 1/4) from a dot's coordinates.
float bayer2(vec2 dot) {
    dot = floor(dot);
    return fract(dot.x / 2.0 + dot.y * dot.y * 0.75);
}

// The 4x4 Bayer pattern: sixteen thresholds from 0 to 15/16.
float bayer4(vec2 dot) {
    return bayer2(0.5 * dot) * 0.25 + bayer2(dot);
}

void main() {
    vec2 cell = floor(qt_TexCoord0 * size / dotSize);
    // Sample the picture once per dot, at the dot's centre, so each dot is
    // one flat colour.
    vec2 cellCentre = (cell + 0.5) * dotSize / size;
    vec4 picture = texture(source, cellCentre);
    // How bright the picture is there, the way the eye weighs the colours.
    float brightness = dot(picture.rgb, vec3(0.299, 0.587, 0.114));
    float isLight = step(bayer4(cell) + 1.0 / 32.0, brightness);
    fragColor = mix(dark, light, isLight) * picture.a * qt_Opacity;
}
