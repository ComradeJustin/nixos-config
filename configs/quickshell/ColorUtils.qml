pragma Singleton
import QtQuick

QtObject {
    // Mix two colors by a factor (0 = color1, 1 = color2)
    function mix(c1, c2, factor) {
        let f = Math.max(0, Math.min(1, factor));
        return Qt.rgba(
            c1.r + (c2.r - c1.r) * f,
            c1.g + (c2.g - c1.g) * f,
            c1.b + (c2.b - c1.b) * f,
            c1.a + (c2.a - c1.a) * f
        );
    }

    // Set alpha on an existing color
    function withAlpha(c, alpha) {
        return Qt.rgba(c.r, c.g, c.b, Math.max(0, Math.min(1, alpha)));
    }

    // Lighten a color by mixing with white
    function lighten(c, amount) {
        return mix(c, Qt.rgba(1, 1, 1, c.a), amount);
    }

    // Darken a color by mixing with black
    function darken(c, amount) {
        return mix(c, Qt.rgba(0, 0, 0, c.a), amount);
    }

    // Compute perceived luminance (0-1)
    function luminance(c) {
        return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
    }

    // Returns true if color is dark
    function isDark(c) {
        return luminance(c) < 0.5;
    }

    // Compute the result of overlaying a semi-transparent color on a base
    function overlay(base, top) {
        let a = top.a;
        return Qt.rgba(
            base.r * (1 - a) + top.r * a,
            base.g * (1 - a) + top.g * a,
            base.b * (1 - a) + top.b * a,
            1
        );
    }

    // Create a hover variant: base color with subtle accent tint
    function hover(base, accent, intensity) {
        let i = intensity !== undefined ? intensity : 0.08;
        return overlay(base, withAlpha(accent, i));
    }

    // Create an active/pressed variant: stronger accent tint
    function active(base, accent, intensity) {
        let i = intensity !== undefined ? intensity : 0.15;
        return overlay(base, withAlpha(accent, i));
    }
}
