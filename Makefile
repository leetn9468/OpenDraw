.PHONY: build release test lint format sanitize dependency-check run

build:
	swift build

release:
	swift build -c release

test:
	OPENDRAW_DELTA_HISTORY=0 swift test --parallel
	OPENDRAW_DELTA_HISTORY=1 swift test --parallel

lint:
	xcrun swift-format lint --recursive --strict Sources Tests Package.swift

format:
	xcrun swift-format format --recursive --in-place Sources Tests Package.swift

sanitize:
	scripts/run-address-sanitizer-tests.sh

dependency-check:
	swift package show-dependencies
	scripts/check-module-dependencies.sh

run:
	swift run VectorFoundry
