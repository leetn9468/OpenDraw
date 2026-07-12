// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "VectorFoundry",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "VectorFoundry", targets: ["VectorFoundryApp"]),
        .executable(name: "RenderBenchmark", targets: ["RenderBenchmark"]),
        .library(name: "EditorCore", targets: ["EditorCore"]),
        .library(name: "Geometry", targets: ["Geometry"]),
        .library(name: "DocumentModel", targets: ["DocumentModel"]),
        .library(name: "EditorCommands", targets: ["EditorCommands"]),
        .library(name: "CanvasRender", targets: ["CanvasRender"]),
    ],
    targets: [
        .target(name: "EditorCore"),
        .target(name: "Geometry", dependencies: ["EditorCore"]),
        .target(name: "DocumentModel", dependencies: ["EditorCore", "Geometry"]),
        .target(name: "EditorCommands", dependencies: ["EditorCore", "DocumentModel"]),
        .target(name: "CanvasRender", dependencies: ["DocumentModel", "Geometry", "TextEngine"]),
        .target(name: "TextEngine", dependencies: ["EditorCore", "Geometry"]),
        .target(name: "EditorTools", dependencies: ["EditorCore", "Geometry", "DocumentModel", "EditorCommands"]),
        .target(name: "DocumentFormats", dependencies: ["EditorCore", "Geometry", "DocumentModel"]),
        .target(name: "MacPlatform", dependencies: ["EditorCore"]),
        .executableTarget(
            name: "VectorFoundryApp",
            dependencies: [
                "DocumentModel", "EditorCommands", "CanvasRender", "TextEngine", "EditorTools", "DocumentFormats",
                "MacPlatform",
            ]
        ),
        .executableTarget(
            name: "RenderBenchmark",
            dependencies: ["CanvasRender", "DocumentModel", "EditorCore", "Geometry"]),
        .testTarget(name: "GeometryTests", dependencies: ["Geometry"]),
        .testTarget(
            name: "DocumentModelTests", dependencies: ["EditorCore", "DocumentModel", "EditorCommands", "Geometry"]),
        .testTarget(name: "CanvasRenderTests", dependencies: ["CanvasRender", "DocumentModel", "Geometry"]),
        .testTarget(name: "TextEngineTests", dependencies: ["TextEngine"]),
        .testTarget(
            name: "DocumentFormatsTests", dependencies: ["EditorCore", "DocumentFormats", "DocumentModel", "Geometry"],
            resources: [.copy("Fixtures")]),
        .testTarget(name: "EditorToolsTests", dependencies: ["EditorTools", "DocumentModel"]),
    ]
)
