// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BtoFolderLoop",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "BtoFolderLoop", targets: ["BtoFolderLoopApp"])],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.6")],
    targets: [
        .target(name: "BtoFolderLoopCore"),
        .systemLibrary(name: "CSQLite", pkgConfig: "sqlite3"),
        .target(name: "BtoFolderLoopStorage", dependencies: ["BtoFolderLoopCore", "CSQLite"], resources: [.process("Resources")]),
        .target(name: "BtoFolderLoopMac", dependencies: ["BtoFolderLoopCore"]),
        .executableTarget(name: "BtoFolderLoopApp", dependencies: ["BtoFolderLoopCore", "BtoFolderLoopStorage", "BtoFolderLoopMac", .product(name: "Sparkle", package: "Sparkle")], resources: [.process("Resources")], linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
        .testTarget(name: "BtoFolderLoopTests", dependencies: ["BtoFolderLoopCore", "BtoFolderLoopStorage", "BtoFolderLoopMac", "BtoFolderLoopApp", "CSQLite"])
    ]
)
