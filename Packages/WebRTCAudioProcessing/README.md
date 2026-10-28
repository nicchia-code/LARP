# WebRTCAudioProcessing

WebRTC's audio processing module, used by LARP only for its echo canceller (AEC3), built from
source as a Swift Package Manager C++ target.

- `Sources/WebRTCAudioProcessing/webrtc/` is the trimmed copy of WebRTC published by the
  [webrtc-audio-processing](https://gitlab.freedesktop.org/pulseaudio/webrtc-audio-processing)
  project, **tag `v2.1`, commit `846fe90a289f58b7c9303a635142aa2c7caa93e5`**. It holds the
  sources that project builds for Apple silicon (its `meson.build` lists, without the x86, MIPS
  and 32-bit ARM files), every header of its `webrtc/` folder and the licences (`LICENSE`,
  `PATENTS`, the third-party `LICENSE`/`COPYING` files). Nothing else of WebRTC is included.
  The files are not edited.
- `Sources/WebRTCAudioProcessing/EchoCanceller.cpp` and `include/WebRTCAudioProcessing.h` are the
  thin C wrapper that exposes the module to Swift: one echo canceller, 16 kHz mono, 10 ms frames,
  with only the echo canceller enabled.
- Abseil, which WebRTC needs, comes from `firebase/abseil-cpp-SwiftPM`, pinned in `Package.swift`
  to a release that builds as C++17, like the WebRTC sources: the release of Abseil 20240722, which
  the pinned WebRTC revision names, builds as C++14 under Xcode and then its classes differ from the
  ones WebRTC sees (link error on `absl::string_view`).

To move to another revision, replace the `webrtc/` folder with the one of the new revision (the
same selection of files), update the revision above and the Abseil pin if the new revision needs
another one.
