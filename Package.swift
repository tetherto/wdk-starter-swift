// swift-tools-version: 5.9
import PackageDescription

// Test the Foundation-only argument encoder without the native wallet dependencies.
let package = Package(
    name: "WalletArguments",
    targets: [
        .target(name: "WalletArguments", path: "WdkStarterApp/Support"),
        .testTarget(
            name: "WalletArgumentsTests",
            dependencies: ["WalletArguments"],
            path: "Tests/WalletArgumentsTests"
        )
    ]
)
