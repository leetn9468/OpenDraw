#!/bin/sh
set -eu
rm -rf dist/OpenDraw.app
swift build -c release
mkdir -p dist/OpenDraw.app/Contents/MacOS
cp .build/release/VectorFoundry dist/OpenDraw.app/Contents/MacOS/OpenDraw
cp resources/Info.plist dist/OpenDraw.app/Contents/Info.plist
codesign --force --deep --sign - --options runtime dist/OpenDraw.app
codesign --verify --deep --strict dist/OpenDraw.app
test "$(lipo -archs dist/OpenDraw.app/Contents/MacOS/OpenDraw)" = arm64
