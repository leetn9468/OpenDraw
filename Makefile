.PHONY: build release test lint format sanitize dependency-check run

build:
	swift build

release:
	swift build -c release

test:
	swift test --parallel

lint:
	xcrun swift-format lint --recursive --strict Sources Tests Package.swift

format:
	xcrun swift-format format --recursive --in-place Sources Tests Package.swift

sanitize:
	swift test --sanitize=address

dependency-check:
	swift package show-dependencies
	scripts/check-module-dependencies.sh

run:
	swift run VectorFoundry
