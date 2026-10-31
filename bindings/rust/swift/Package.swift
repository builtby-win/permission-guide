// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PermissionGuide",
    platforms: [.macOS(.v13)],
    products: [
        // Swift API.
        .library(name: "PermissionGuide", targets: ["PermissionGuide"]),
        // C ABI (pg_status/pg_present/pg_dismiss); header in Sources/CPermissionGuide/include.
        .library(name: "CPermissionGuide", targets: ["CPermissionGuide"]),
    ],
    targets: [
        .target(name: "PermissionGuide"),
        // C ABI: @_cdecl exports; header lives in include/ for C/Rust/Go consumers.
        .target(name: "CPermissionGuide", dependencies: ["PermissionGuide"],
                exclude: ["include"]),
    ]
)
