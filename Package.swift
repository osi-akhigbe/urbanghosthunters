// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "urbanghosthunters",
    platforms: [
        .iOS(.v15), .macOS(.v12) // Supabase needs modern versions
    ],
    dependencies: [
        // This tells Swift WHERE to get the code
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "urbanghosthunters",
            dependencies: [
                // This tells your specific folder to USE the code
                .product(name: "Supabase", package: "supabase-swift")
            ]
        )
    ]
)