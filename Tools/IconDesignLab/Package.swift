// swift-tools-version: 6.0
import PackageDescription

// Standalone preview sandbox for the menu bar bar icon. Open this folder (not the repo root) in Xcode.
// StackedBarsIconRenderer.swift is a symlink to the app's real file, so edits land in the app directly.
let package = Package(
    name: "IconDesignLab",
    platforms: [.macOS(.v15)],
    products: [.library(name: "IconDesignLab", targets: ["IconDesignLab"])],
    targets: [.target(name: "IconDesignLab")],
    swiftLanguageModes: [.v5])
