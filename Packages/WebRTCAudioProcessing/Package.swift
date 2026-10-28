// swift-tools-version: 6.0
import PackageDescription

// WebRTC's audio processing module (AEC3 is its echo canceller), built from source.
// The sources under `Sources/WebRTCAudioProcessing/webrtc` are the trimmed copy of WebRTC
// that the webrtc-audio-processing project publishes, pinned to one revision: see README.md.
// `EchoCanceller.cpp` is the thin C wrapper that exposes the module to Swift.
let defines = [
    "WEBRTC_MAC",
    "WEBRTC_POSIX",
    "WEBRTC_ARCH_ARM64",
    "WEBRTC_HAS_NEON",
    "WEBRTC_LIBRARY_IMPL",
    "WEBRTC_ENABLE_SYMBOL_EXPORT",
    "WEBRTC_APM_DEBUG_DUMP=0",
    "NDEBUG",
]

let package = Package(
    name: "WebRTCAudioProcessing",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "WebRTCAudioProcessing", targets: ["WebRTCAudioProcessing"])
    ],
    dependencies: [
        // WebRTC needs Abseil. This release builds as C++17, like the sources of the pinned WebRTC revision (the 20240722 one builds as C++14, and its classes then differ from the ones WebRTC sees).
        .package(url: "https://github.com/firebase/abseil-cpp-SwiftPM.git", exact: "0.20250127.1")
    ],
    targets: [
        .target(
            name: "WebRTCAudioProcessing",
            dependencies: [.product(name: "abseil", package: "abseil-cpp-SwiftPM")],
            path: "Sources/WebRTCAudioProcessing",
            publicHeadersPath: "include",
            cSettings: [.headerSearchPath("webrtc"), .define("_GNU_SOURCE")] + defines.map { .define($0) },
            cxxSettings: [.headerSearchPath("webrtc")] + defines.map { .define($0) }
        )
    ],
    cLanguageStandard: .c11,
    cxxLanguageStandard: .cxx17
)
