# Developer setup

## Requirements

- macOS 15 or newer.
- Swift 6.0+ toolchain. Full current Xcode is recommended for application debugging,
  accessibility inspection, XCUITest, and arm64 archive work.
- `swift-format` available through `xcrun` (included in current Xcode/Swift toolchains).
- `rg` for the dependency guard.

## Commands

```sh
swift --version
make build
make test
make lint
scripts/check-module-dependencies.sh
make release
make run
```

AddressSanitizer is available through `make sanitize`. Run it separately from normal
tests because macOS system-framework behavior and startup cost differ under ASan.

The package has debug/release configurations without generated files or network
dependencies. A clean checkout should reproduce the build. The executable opens an
original foundation window containing the sample cubic path; it is not yet an editor.

Do not place `AI10.c`, derived notes, proprietary screenshots, or copied assets in
this repository. Review the Phase 1 clean-room policy before implementation.
