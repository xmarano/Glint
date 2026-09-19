# Glint identity

An asymmetric amber glint with a rising diagonal, on an obsidian macOS tile.

- `Glint-icon.png`: original generated raster artwork with alpha, for reuse and icon packaging.
- `../Glint.icns`: full macOS icon family, 16–1024 pixels; bundled by both build routes.
- `Glint-mark.svg`: editable flat companion silhouette.
- [GlintBrand.swift](../../Sources/UI/GlintBrand.swift): matching native vector used by the menu bar, input panel and Settings. The menu bar image is a monochrome template, so macOS handles light/dark appearances.

Rebuild the ICNS from the PNG with `bash scripts/build-icon.sh`, then rebuild the app. The original PNG is retained without visual edits; Apple's `sips` and `iconutil` handle size/format conversion.

The app icon is AI-generated artwork. The small-size vector companion is drawn in code. The source PNG retains its provenance metadata; conversion to the application icon uses the build script above. The assets are included under the project's [MIT License](../../LICENSE).

## Generation prompt

Create a finished production macOS application icon for Glint, a quiet, fast inline AI assistant. Use case: logo-brand. Deliver ONE square 1024x1024 icon image, not a presentation board or mockup. Background outside the icon must be truly transparent. Center a dark obsidian rounded-square macOS tile occupying about 88% of the canvas, generous smooth continuous corners, subtle bevel and very restrained dimensional depth. On the tile, place one bold, memorable, asymmetric four-point glint symbol: a large elongated upper-right ray, a medium lower-left ray, shorter upper-left and lower-right rays, concave flowing sides, thick enough to remain crisp at small sizes. Symbol roughly 58% of tile width, precisely centered. Glint is luminous warm amber/orange with a delicate ivory highlight on its upper-left face, subtle folded-metal dimensional quality, not glitter. Sophisticated, minimal, professional native Mac utility. Palette: charcoal #17191E, amber #FFAE45, warm orange #FF7A32, pale gold #FFE4A2. No text, no letters, no border text, no surrounding objects, no extra stars, no lens flare, no noisy texture, no environment, no drop shadow outside the icon tile, no watermark. Exact square frontal orthographic composition, not perspective. The silhouette of the four-point symbol must be simple and ownable, suitable to recreate as a monochrome menu-bar vector.
