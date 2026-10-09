# Image assets

## Questreihen Tracker logo

- Master: `assets/questreihentracker-logo.png` (1254 × 1254, RGBA PNG).
- Runtime texture: `addon/QuestreihenTracker/Media/QuestreihenTrackerLogo.tga` (128 × 128, uncompressed type 2 true-color TGA, 32-bit RGBA).
- WoW texture path: `Interface\\AddOns\\QuestreihenTracker\\Media\\QuestreihenTrackerLogo`.
- Created with the built-in `image_gen.imagegen` tool in native tool mode on 2026-10-08, with `transparent_background=true` and no reference images. The prompt requested a 1024 × 1024 canvas; the tool returned a 1254 × 1254 PNG, preserved as the master.
- The design is an original gold quest marker and linked route ending in a green completion check, inside a dark teal circular medallion. It represents questline progress rather than an Earthen unlock.
- Pillow performed only a Lanczos downscale and a format export for the runtime texture. No generated image content was repainted. The exported TGA was reopened and checked for identical RGBA pixels, type 2 encoding, 128 × 128 dimensions, 32-bit depth, and preserved transparency.
- Master SHA-256: `3123a04dccb2484c285bd8d814d25491448f9d3f7270d9a8abf3008f8afc6e75`.
- Runtime SHA-256: `a564220dd17018d5d6e307c47585315cb9bdcb551b682f58749d6ed1e3366e45`.

The runtime logo is now displayed as a 20-pixel inset inside a 32-pixel native launcher. The visible ring and hover highlight use Blizzard's own minimap assets, with provenance links in TECHNICAL_NOTES.md. Dragging and actual alignment still require a client check; the master/runtime image files are unchanged.

### Final generation prompt

```text
Use case: logo-brand
Asset type: Original raster logo for a native World of Warcraft addon minimap button, QuestreihenTracker; it helps players efficiently finish questlines rather than unlock a race.
Primary request: A clean compact fantasy quest route and completion emblem, suitable for a very small circular button.
Scene/backdrop: A centered circular midnight teal medallion with a broad simple warm gold rim. Everything outside the circle must be genuinely transparent.
Subject: One bold warm gold quest exclamation marker linked by a single broad curved route to three large round route nodes; the final node carries a clear green check mark to communicate completion. Make the main gold quest marker visually dominant and integrate the route naturally into one balanced simple symbol.
Style/medium: Original polished flat graphic with subtle restrained fantasy UI shading; broad silhouettes, high contrast, smooth clean edges, generous negative space. No intricate illustration.
Composition/framing: Square 1024x1024 canvas, exactly centered, the circular medallion nearly fills the image with a small transparent outer margin. Readable as a 20–24 pixel minimap icon, with very few shapes.
Color palette: Midnight teal / charcoal interior, warm gold main marker and rim, small emerald green completion accent.
Text: None.
Constraints: Brand-new original artwork. No lettering, no words, no watermark, no characters, no race emblems, no decorative flourishes, no fine lines, no tiny details. Do not use Blizzard, World of Warcraft, Wowhead, or any other existing brand logo. Preserve actual alpha transparency outside the medallion.
```

### Client verification

The generated master was visually inspected, and the runtime file encoding was checked offline. Rendering at the native minimap button size and texture loading in the WoW client still require an actual client test.
