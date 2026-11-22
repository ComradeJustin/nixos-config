#version 440

// A 1-bit dither fade for a whole item. Every pixel is either kept or
// dropped; nothing is ever half transparent. How much of the item should
// show is compared, pixel by pixel, against an ordered (Bayer) pattern of
// thresholds, so the item thins out into a regular scatter of dots and then
// to nothing, like a printed halftone.
//
// This is the source. Qt loads the compiled dither-fade.frag.qsb beside it.
// After editing, rebuild it with:
//   nix shell nixpkgs#kdePackages.qtshadertools -c qsb --glsl "100 es,120,150" -o dither-fade.frag.qsb dither-fade.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    // 0 = gone, 1 = fully shown.
    float amount;
    // Size of one dither dot, in pixels.
    float dotSize;
    // Width of the dithered front as a share of the item's width. The front
    // runs left to right. With a very large value the whole item fades at once.
    float spread;
    // The item's size in pixels.
    vec2 size;
};

layout(binding = 1) uniform sampler2D source;

// The 2x2 Bayer pattern (0, 1/2, 3/4, 1/4) from a dot's coordinates.
float bayer2(vec2 dot) {
    dot = floor(dot);
    return fract(dot.x / 2.0 + dot.y * dot.y * 0.75);
}

// The 4x4 Bayer pattern: sixteen thresholds from 0 to 15/16, arranged so
// that neighbouring dots differ as much as possible.
float bayer4(vec2 dot) {
    return bayer2(0.5 * dot) * 0.25 + bayer2(dot);
}

void main() {
    vec2 dot = floor(qt_TexCoord0 * size / dotSize);
    // How much of the item shows at this pixel, from 0 to 1.
    float shown = clamp((amount * (1.0 + spread) - qt_TexCoord0.x) / spread, 0.0, 1.0);
    // Keep the pixel if that beats this dot's threshold. The half step keeps
    // 0 fully gone and 1 fully shown.
    float keep = step(bayer4(dot) + 1.0 / 32.0, shown);
    fragColor = texture(source, qt_TexCoord0) * keep * qt_Opacity;
}
