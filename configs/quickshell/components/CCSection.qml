import QtQuick
import ".." as Root

// CCSection — the single "strip card" primitive for the Control Center.
//
// Every visible block in the CC (quick toggles, sliders, cards area, tab
// bar pill…) wraps its children in this component so they all share the
// same rounded background, border, radius and inner padding. That
// uniformity is what makes the panel feel like a coherent column of
// related controls rather than a bag of unrelated widgets.
//
// Inspired by Noctalia's NBox primitive. The insight is that visual
// consistency comes from *repetition of chrome*, not from special-casing
// individual sections. One primitive means one place to tweak colors,
// radii or padding — and consumers only need to drop their content
// inside. Example:
//
//     CCSection {
//         Layout.fillWidth: true
//         Row { anchors.fill: parent; /* toggles */ }
//     }
//
// Children are parented to the inner content Item (`content` default
// alias), so they don't have to worry about the background Rectangle
// or the padding math.
Item {
    id: section

    // Vertical padding inside the section. Horizontal padding is the
    // same value applied as leftMargin/rightMargin on the inner Item so
    // callers can still use anchors.fill against `content`.
    property int padding: 10

    // Accessor so children can be declared as default children of the
    // section (goes into the inner padded Item, not the background).
    default property alias content: inner.data

    // implicitHeight follows inner.childrenRect.height + padding on both
    // sides. This works for layout-flow children (Column, Row without
    // anchor centering, etc.). For anchor-centered children or other
    // tricky cases, callers should set implicitHeight explicitly on the
    // CCSection instance — QML's property-override semantics will replace
    // this binding cleanly. That's the Noctalia pattern: every card has
    // an explicit height, auto-sizing is just a convenience fallback.
    //
    // NOTE: a plain Item's implicitHeight does NOT auto-follow children,
    // so we must use childrenRect explicitly. Empty sections size to 0 +
    // padding*2, which is the sensible baseline.
    // No implicitWidth binding — CCSection is always used with
    // Layout.fillWidth, and binding implicitWidth to childrenRect creates
    // a feedback loop with anchor-centered children (their x depends on
    // the section's width, and their width contributes to childrenRect).
    implicitHeight: inner.childrenRect.height + padding * 2

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Root.Theme.ccSectionRadius
        color: Root.Theme.ccSectionBg
        border.width: Root.Theme.borderWidth
        border.color: Root.Theme.borderColor
    }

    Item {
        id: inner
        anchors.fill: parent
        anchors.margins: section.padding
    }
}
