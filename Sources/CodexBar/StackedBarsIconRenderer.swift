import AppKit

/// Draws two or three providers as stacked rows: brand icon on the left, a flat meter on the right.
/// The image is a template so AppKit applies the menu bar's active/inactive tinting.
enum StackedBarsIconRenderer {
    struct Row: Equatable {
        /// Fill percent (0...100) in the user's remaining/used direction; nil draws an empty track.
        let percent: Double?
        let stale: Bool
    }

    struct Metrics: Equatable {
        let rowHeight: CGFloat
        let iconSize: CGFloat
        let barHeight: CGFloat
        let barX: CGFloat
        let size: NSSize

        /// Two rows use 9 pt each (18 pt tall), three rows 6 pt each (18 pt), matching the standard icon height.
        init(rowCount: Int, barWidth: CGFloat = StackedBarsIconRenderer.barWidth) {
            let rows = max(1, rowCount)
            self.rowHeight = rows >= 3 ? 6 : 9
            self.iconSize = self.rowHeight - 1
            self.barHeight = rows >= 3 ? 4 : 6
            self.barX = self.iconSize + 4
            self.size = NSSize(width: self.barX + barWidth, height: self.rowHeight * CGFloat(rows))
        }
    }

    static let maxRows = 3
    static let barWidth: CGFloat = 28
    static let trackAlpha: CGFloat = 0.38

    static func fillWidth(percent: Double?, barWidth: CGFloat) -> CGFloat {
        guard let percent, percent.isFinite else { return 0 }
        let clamped = max(0, min(percent, 100)) / 100
        return (barWidth * CGFloat(clamped) * 2).rounded() / 2
    }

    static func makeImage(rows: [Row], icons: [NSImage?], scale: CGFloat = 2) -> NSImage {
        let rows = Array(rows.prefix(self.maxRows))
        let metrics = Metrics(rowCount: rows.count)
        let image = NSImage(size: metrics.size)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int((metrics.size.width * scale).rounded(.up)),
            pixelsHigh: Int((metrics.size.height * scale).rounded(.up)),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0)
        else {
            image.isTemplate = true
            return image
        }
        rep.size = metrics.size
        image.addRepresentation(rep)

        NSGraphicsContext.saveGraphicsState()
        if let context = NSGraphicsContext(bitmapImageRep: rep) {
            NSGraphicsContext.current = context
            for (index, row) in rows.enumerated() {
                // AppKit's origin is bottom-left; row 0 is the top row.
                let rowBottom = metrics.size.height - CGFloat(index + 1) * metrics.rowHeight
                let alpha: CGFloat = row.stale ? 0.55 : 1
                if let icon = icons.indices.contains(index) ? icons[index] : nil {
                    icon.draw(
                        in: NSRect(
                            x: 0,
                            y: rowBottom + (metrics.rowHeight - metrics.iconSize) / 2,
                            width: metrics.iconSize,
                            height: metrics.iconSize),
                        from: .zero,
                        operation: .sourceOver,
                        fraction: alpha)
                }
                self.drawBar(
                    in: NSRect(
                        x: metrics.barX,
                        y: rowBottom + (metrics.rowHeight - metrics.barHeight) / 2,
                        width: self.barWidth,
                        height: metrics.barHeight),
                    percent: row.percent,
                    alpha: alpha)
            }
        }
        NSGraphicsContext.restoreGraphicsState()
        image.isTemplate = true
        return image
    }

    private static func drawBar(in rect: NSRect, percent: Double?, alpha: CGFloat) {
        let radius = rect.height / 2
        let track = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        NSColor.black.withAlphaComponent(self.trackAlpha * alpha).setFill()
        track.fill()

        let fill = self.fillWidth(percent: percent, barWidth: rect.width)
        guard fill > 0 else { return }
        NSGraphicsContext.saveGraphicsState()
        track.addClip()
        NSColor.black.withAlphaComponent(alpha).setFill()
        NSBezierPath(rect: NSRect(x: rect.minX, y: rect.minY, width: fill, height: rect.height)).fill()
        NSGraphicsContext.restoreGraphicsState()
    }
}
