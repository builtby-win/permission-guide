// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PermissionGuide",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "PermissionGuide", targets: ["PermissionGuide"]),
        .library(name: "CPermissionGuide", targets: ["CPermissionGuide"]),
    ],
    targets: [
        .target(name: "PermissionGuide"),
        // C ABI: @_cdecl exports; header lives in include/ for C/Rust/Go consumers.
        .target(name: "CPermissionGuide", dependencies: ["PermissionGuide"],
                exclude: ["include"]),
        .executableTarget(name: "PermissionGuideExample", dependencies: ["PermissionGuide"],
                          path: "Example/PermissionGuideExample"),
    ]
)
