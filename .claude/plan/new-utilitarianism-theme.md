# Implementation Plan: New Utilitarianism Theme System

## Task Type
- [x] Frontend (UI/QuickShell theming)
- [x] Backend (NixOS/Stylix configuration)
- [x] Fullstack (Complete theme standardization)

---

## Design Philosophy: New Utilitarianism

Based on research from [Zarma Type](https://zarmatype.com/a-guide-to-utilitarian-design-and-style/), [AESDES](https://www.aesdes.org/2025/01/22/utilitarian-design-aesthetic/), and [AIGA](https://www.aiga.org/eye-on-design/five-fonts-that-prove-bauhaus-typography-is-alive-and-well/):

### Core Principles
1. **Form Follows Function** - Every visual element must justify its existence through utility
2. **Information Hierarchy** - Typography weight/size indicates importance, not decoration
3. **Restrained Color** - Neutrals dominate; accents guide attention to actionable items
4. **Industrial Minimalism** - Clean geometric forms, no gradients/shadows unless functional
5. **Accessibility First** - Sufficient contrast ratios (WCAG AA minimum)
6. **Grid-Based Consistency** - 4px/8px base unit system for all spacing

---

## Technical Solution

### 1. Color Scheme Selection

**Recommended Schemes** (utilitarian-appropriate from base16-schemes):

| Scheme | Character | Rationale |
|--------|-----------|-----------|
| `standardized-dark.yaml` | Neutral, accessible | Designed for WCAG compliance, industrial feel |
| `measured-dark.yaml` | Scientific, precise | Calibrated colors, utilitarian naming |
| `grayscale-dark.yaml` | Pure function | Ultimate minimalism, accent-only color |
| `gruvbox-material-dark-hard.yaml` (current) | Warm neutral | Acceptable, slightly decorative warmth |
| `nord.yaml` | Cool neutral | Clean, technical aesthetic |
| `selenized-dark.yaml` | Lab-designed | Scientific approach to color selection |

**Recommendation**: `standardized-dark.yaml` or `selenized-dark.yaml` for true utilitarianism

### 2. Typography Stack

**Available in nixpkgs** (verified):
- `pkgs.inter` - Highly legible, geometric sans-serif (UI primary)
- `pkgs.dm-sans` - Clean geometric, slightly warmer
- `pkgs.ibm-plex` - IBM Plex family (sans, mono, serif)
- `pkgs.jetbrains-mono` - Technical monospace
- `pkgs.fira-code` - Monospace with ligatures

**Recommended Stack**:
```nix
stylix.fonts = {
  serif = {
    package = pkgs.ibm-plex;
    name = "IBM Plex Serif";
  };
  sansSerif = {
    package = pkgs.inter;
    name = "Inter";
  };
  monospace = {
    package = pkgs.jetbrains-mono;
    name = "JetBrains Mono";
  };
  emoji = {
    package = pkgs.noto-fonts-color-emoji;
    name = "Noto Color Emoji";
  };
};
```

**Rationale**:
- **Inter**: Designed specifically for UI, extensive testing for screen legibility
- **IBM Plex Serif**: Industrial heritage (IBM), clean and readable
- **JetBrains Mono**: Dense, functional, excellent for data/code display

### 3. QuickShell Theme Refinement

**Current Issues**:
- Font family set to generic "monospace" instead of specific font
- Some semantic aliases could be clearer
- Layout constants not on 8px grid

**Proposed Theme.qml Changes**:

```qml
// Typography - use specific fonts
readonly property string fontFamily: "Inter"
readonly property string fontMono: "JetBrains Mono"
readonly property int fontSize: 13    // 13px for body
readonly property int fontSizeSmall: 11
readonly property int fontSizeLarge: 15
readonly property int iconSize: 16    // 16px icons (aligned to grid)

// 8px Grid System
readonly property int unit: 8
readonly property int barHeight: 32    // 4 units
readonly property int barPadding: 8    // 1 unit (was 12)
readonly property int barSpacing: 16   // 2 units

// OSD - grid aligned
readonly property int osdWidth: 256    // 32 units
readonly property int osdHeight: 64    // 8 units
readonly property int osdRadius: 8     // 1 unit (was 16)
readonly property int osdIconSize: 24  // 3 units (was 28)

// Notifications - grid aligned
readonly property int notifWidth: 360  // 45 units (OK)
readonly property int notifRadius: 8   // 1 unit (was 12)
readonly property int notifPadding: 16 // 2 units (was 14)

// Control Center - grid aligned
readonly property int ccWidth: 384     // 48 units (was 380)
readonly property int ccPadding: 16    // 2 units (was 14)
readonly property int ccSectionRadius: 8 // 1 unit (was 12)
```

### 4. Application Theming (Stylix Targets)

#### 4.1 Spicetify (Spotify)
```nix
# modules/programs/spicetify.nix
programs.spicetify = {
  enable = true;
  # Use Stylix-generated theme instead of external
  # Stylix auto-generates spicetify theme when enabled
};
```

Note: Stylix has native Spicetify support via `stylix.targets.spicetify.enable = true`

#### 4.2 Nixcord (Discord/Vesktop)
```nix
# modules/programs/nixcord.nix
programs.nixcord = {
  enable = true;
  discord.vencord.enable = true;
  vesktop.enable = true;
  config = {
    # Vencord CSS theming - use Stylix colors
    # Note: May need custom CSS using Stylix variables
  };
};
```

#### 4.3 Additional Stylix Targets to Enable

Add to `modules/theming/stylix.nix`:
```nix
stylix.targets = {
  # Terminal
  ghostty.enable = true;

  # GTK/Qt
  gtk.enable = true;

  # Editors
  vscode.enable = true;

  # Shells
  fish.enable = true;
  nushell.enable = true;

  # Browsers (if supported)
  firefox.enable = true;

  # Other
  bat.enable = true;
  fzf.enable = true;
  btop.enable = true;
};
```

---

## Implementation Steps

### Step 1: Update fonts.nix - Add Utilitarian Fonts
- **File**: `modules/core/fonts.nix`
- **Operation**: Add `pkgs.inter`, `pkgs.ibm-plex` to system fonts
- **Expected**: Inter and IBM Plex available system-wide

### Step 2: Update stylix.nix - New Font Stack
- **File**: `modules/theming/stylix.nix`
- **Operation**: Replace Bodoni Moda/Jost/CommitMono with Inter/IBM Plex/JetBrains Mono
- **Expected**: All Stylix-aware applications use new fonts

### Step 3: Update stylix.nix - Enable Additional Targets
- **File**: `modules/theming/stylix.nix`
- **Operation**: Add `stylix.targets` configuration
- **Expected**: Ghostty, VSCode, fish, btop, etc. themed automatically

### Step 4: Update spicetify.nix - Enable Stylix Theming
- **File**: `modules/programs/spicetify.nix`
- **Operation**: Remove commented theme lines, enable Stylix target
- **Expected**: Spotify themed with Stylix colors

### Step 5: Update nixcord.nix - Add Theme Config
- **File**: `modules/programs/nixcord.nix`
- **Operation**: Configure Vencord/Vesktop theming
- **Expected**: Discord clients themed consistently

### Step 6: Update Theme.qml - Grid Alignment & Font Specificity
- **File**: `configs/quickshell/Theme.qml`
- **Operation**:
  - Change `fontFamily` to "Inter"
  - Add `fontMono` property for data displays
  - Align all dimensions to 8px grid
  - Reduce border radii (16→8) for industrial aesthetic
- **Expected**: Tighter, more geometric UI appearance

### Step 7: Update Bar/Control Center Components
- **Files**: `configs/quickshell/modules/Bar.qml`, `ControlCenter.qml`, etc.
- **Operation**: Apply grid-aligned spacing, use `fontMono` for data (CPU%, time, etc.)
- **Expected**: Consistent utilitarian visual language

### Step 8: (Optional) Switch Color Scheme
- **File**: `modules/theming/stylix.nix`
- **Operation**: Change to `standardized-dark.yaml` or `selenized-dark.yaml`
- **Expected**: More neutral, industrial color palette

---

## Key Files

| File | Operation | Description |
|------|-----------|-------------|
| `modules/core/fonts.nix` | Modify | Add Inter, IBM Plex fonts |
| `modules/theming/stylix.nix` | Modify | New font stack, enable targets |
| `modules/programs/spicetify.nix` | Modify | Enable Stylix theme integration |
| `modules/programs/nixcord.nix` | Modify | Add theme configuration |
| `configs/quickshell/Theme.qml` | Modify | Grid alignment, font specificity |
| `configs/quickshell/modules/Bar.qml` | Modify | Apply theme changes |
| `configs/quickshell/modules/ControlCenter.qml` | Modify | Apply theme changes |

---

## Risks and Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Font rendering issues (hinting) | Medium | Medium | Test Inter at various sizes, enable FreeType hinting |
| Stylix target conflicts | Low | Medium | Test one target at a time |
| QuickShell component breakage | Low | High | Test each component after changes |
| Spicetify theme not applying | Medium | Low | May need manual `spicetify apply` or rebuild |
| Discord/Vesktop CSS conflicts | Medium | Low | Custom CSS may override Stylix |
| Color scheme too desaturated | Low | Low | User preference; keep Gruvbox as fallback |

---

## Verification Steps

1. `sudo nixos-rebuild switch` - Rebuild with new configuration
2. Verify font rendering in terminal (Inter for UI, JetBrains Mono for code)
3. Check Stylix targets:
   - Open VSCode → verify colors applied
   - Open Ghostty → verify terminal colors
   - Check btop → verify themed
4. Verify QuickShell:
   - Bar renders with new spacing
   - Control Center grid-aligned
   - OSD appears correctly
5. Check Spotify (restart if needed)
6. Check Discord/Vesktop

---

## Optional Enhancements

### A. Custom Base16 Scheme
Create a custom "Utilitarian" scheme at `~/.config/base16/utilitarian.yaml`:
```yaml
scheme: "Utilitarian"
author: "Justin"
base00: "1a1a1a"  # Pure dark background
base01: "262626"  # Lighter background
base02: "404040"  # Selection
base03: "666666"  # Comments
base04: "999999"  # Dark foreground
base05: "d4d4d4"  # Default foreground
base06: "e8e8e8"  # Light foreground
base07: "ffffff"  # Lightest
base08: "f44747"  # Red - Errors
base09: "d7ba7d"  # Orange - Constants
base0A: "dcdcaa"  # Yellow - Classes
base0B: "6a9955"  # Green - Strings
base0C: "4ec9b0"  # Cyan - Support
base0D: "569cd6"  # Blue - Functions (PRIMARY ACCENT)
base0E: "c586c0"  # Purple - Keywords
base0F: "ce9178"  # Brown - Deprecated
```

### B. Bento Grid for Control Center
Implement a true Bento Grid layout in ControlCenter.qml:
- 2-column grid with varying cell sizes
- Large cells for media player
- Small cells for toggles
- Medium cells for sliders

---

## SESSION_ID (for /ccg:execute use)
- CODEX_SESSION: N/A (wrapper not available)
- GEMINI_SESSION: N/A (wrapper not available)

---

## Summary

This plan transforms the current Gruvbox-themed setup into a cohesive "New Utilitarianism" design system:

1. **Typography**: Switch from decorative (Bodoni Moda, Jost) to functional (Inter, IBM Plex, JetBrains Mono)
2. **Layout**: Align all dimensions to 8px grid for consistency
3. **Styling**: Reduce decorative elements (smaller radii, consistent padding)
4. **Integration**: Enable Stylix for all supported applications
5. **Color** (optional): Switch to more neutral scheme like `standardized-dark` or `selenized-dark`

The implementation is incremental and reversible - each step can be tested independently.
