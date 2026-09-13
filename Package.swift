// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BtoFolderLoop",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "BtoFolderLoop", targets: ["BtoFolderLoopApp"])],
    targets: [
        .target(name: "BtoFolderLoopCore"),
        .systemLibrary(name: "CSQLite", pkgConfig: "sqlite3"),
        .target(name: "BtoFolderLoopStorage", dependencies: ["BtoFolderLoopCore", "CSQLite"], resources: [.process("Resources")]),
        .target(name: "BtoFolderLoopMac", dependencies: ["BtoFolderLoopCore"]),
        .executableTarget(name: "BtoFolderLoopApp", dependencies: ["BtoFolderLoopCore", "BtoFolderLoopStorage", "BtoFolderLoopMac"]),
        .testTarget(name: "BtoFolderLoopTests", dependencies: ["BtoFolderLoopCore", "BtoFolderLoopStorage", "BtoFolderLoopMac"])
    ]
)
