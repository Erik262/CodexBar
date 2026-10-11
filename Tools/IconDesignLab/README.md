# IconDesignLab

Xcode preview sandbox for the stacked-bars menu bar icon, without loading the whole app.

1. In Xcode: File → Open… → select this `Tools/IconDesignLab` folder.
2. Open `Sources/IconDesignLab/IconDesignLabPreviews.swift`; the canvas shows the icon on light and dark menu bars ("Actual size" and "4× zoom").
3. Edit `StackedBarsIconRenderer.swift`. It is a symlink to `Sources/CodexBar/StackedBarsIconRenderer.swift`, so your changes are the app's changes.
4. Share them with `git diff` (or commit and push).

Tunable spots in the renderer: `Metrics.init` (row height, icon size, bar height, icon gap), `barWidth`, `trackAlpha`, the stale alpha in `makeImage`, and `drawBar` (corner radius, fill style).
