import AppKit
import SwiftUI

// Edit StackedBarsIconRenderer.swift (Metrics, barWidth, trackAlpha, drawBar) and watch the canvas update.

/// Loads the app's real provider SVGs straight from the repo, sized and templated like ProviderBrandIcon.
enum LabIcons {
    private static let resources = URL(fileURLWithPath: #filePath)
        .resolvingSymlinksInPath()
        .deletingLastPathComponent() // IconDesignLab
        .deletingLastPathComponent() // Sources
        .deletingLastPathComponent() // IconDesignLab package
        .deletingLastPathComponent() // Tools
        .deletingLastPathComponent() // repo root
        .appendingPathComponent("Sources/CodexBar/Resources")

    static func image(_ name: String) -> NSImage? {
        guard let image = NSImage(contentsOf: self.resources.appendingPathComponent("\(name).svg")) else {
            return nil
        }
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        return image
    }

    static let claude = Self.image("ProviderIcon-claude")
    static let codex = Self.image("ProviderIcon-codex")
}

struct LabScenario: Identifiable {
    let id = UUID()
    let title: String
    let rows: [StackedBarsIconRenderer.Row]
    let icons: [NSImage?]

    static let all: [LabScenario] = {
        let icons3 = [LabIcons.claude, LabIcons.codex, LabIcons.codex]
        return [
            LabScenario(
                title: "2 rows",
                rows: [.init(percent: 72, stale: false), .init(percent: 35, stale: false)],
                icons: Array(icons3.prefix(2))),
            LabScenario(
                title: "3 rows",
                rows: [
                    .init(percent: 90, stale: false),
                    .init(percent: 45, stale: false),
                    .init(percent: 10, stale: false),
                ],
                icons: icons3),
            LabScenario(
                title: "2 rows, no icons",
                rows: [.init(percent: 72, stale: false), .init(percent: 35, stale: false)],
                icons: []),
            LabScenario(
                title: "3 rows, no icons",
                rows: [
                    .init(percent: 90, stale: false),
                    .init(percent: 45, stale: false),
                    .init(percent: 10, stale: false),
                ],
                icons: []),
            LabScenario(
                title: "Stale / no data / 0 / 100",
                rows: [
                    .init(percent: 60, stale: true),
                    .init(percent: nil, stale: true),
                    .init(percent: 0, stale: false),
                ],
                icons: icons3),
            LabScenario(
                title: "Full",
                rows: [.init(percent: 100, stale: false), .init(percent: 100, stale: false)],
                icons: Array(icons3.prefix(2))),
        ]
    }()
}

/// Fake 24 pt menu bar strip; the template image takes the strip's foreground colour like the real menu bar.
struct MenuBarStrip: View {
    let image: NSImage
    let zoom: CGFloat
    let dark: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi")
            Image(nsImage: self.image)
                .resizable()
                .renderingMode(.template)
                .interpolation(self.zoom > 1 ? .none : .high)
                .frame(width: self.image.size.width * self.zoom, height: self.image.size.height * self.zoom)
            Text("Sat 11 Oct 13:20").font(.system(size: 13))
        }
        .padding(.horizontal, 10)
        .frame(height: max(24, self.image.size.height * self.zoom + 6))
        .foregroundStyle(self.dark ? Color.white : Color.black.opacity(0.85))
        .background(self.dark ? Color(white: 0.16) : Color(white: 0.93))
        .environment(\.colorScheme, self.dark ? .dark : .light)
    }
}

struct IconDesignLabView: View {
    var zoom: CGFloat = 1
    @State private var top: Double = 72
    @State private var middle: Double = 35
    @State private var bottom: Double = 10
    @State private var rowCount = 2
    @State private var showsIcons = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                self.playground
                Divider()
                ForEach(LabScenario.all) { scenario in
                    self.section(
                        scenario.title,
                        image: StackedBarsIconRenderer.makeImage(rows: scenario.rows, icons: scenario.icons))
                }
            }
            .padding(16)
        }
        .frame(minWidth: 420, minHeight: 600)
    }

    private var playground: some View {
        let percents = [self.top, self.middle, self.bottom].prefix(self.rowCount)
        let icons = [LabIcons.claude, LabIcons.codex, LabIcons.codex].prefix(self.rowCount)
        let image = StackedBarsIconRenderer.makeImage(
            rows: percents.map { StackedBarsIconRenderer.Row(percent: $0, stale: false) },
            icons: self.showsIcons ? Array(icons) : [])
        return VStack(alignment: .leading, spacing: 8) {
            self.section("Playground (use live preview)", image: image)
            Picker("Rows", selection: self.$rowCount) {
                Text("2").tag(2)
                Text("3").tag(3)
            }
            .pickerStyle(.segmented)
            .frame(width: 160)
            Toggle("Provider icons", isOn: self.$showsIcons)
            Slider(value: self.$top, in: 0...100) { Text("Row 1") }
            Slider(value: self.$middle, in: 0...100) { Text("Row 2") }
            if self.rowCount == 3 {
                Slider(value: self.$bottom, in: 0...100) { Text("Row 3") }
            }
        }
    }

    private func section(_ title: String, image: NSImage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(title) — \(Int(image.size.width))×\(Int(image.size.height)) pt")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                MenuBarStrip(image: image, zoom: self.zoom, dark: false)
                MenuBarStrip(image: image, zoom: self.zoom, dark: true)
            }
        }
    }
}

#Preview("Actual size") {
    IconDesignLabView(zoom: 1)
}

#Preview("4× zoom") {
    IconDesignLabView(zoom: 4)
}
