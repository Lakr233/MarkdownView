#!/bin/bash

cd "$(dirname "$0")"
cd ..

SCEHEME="Example"
WORKSPACE="Example.xcworkspace"

function test_build() {
	DESTINATION=$1
	echo "[*] test build for $DESTINATION"
	xcodebuild -scheme $SCEHEME -workspace $WORKSPACE -destination "$DESTINATION" \
		CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
		| xcbeautify --disable-logging
	EXIT_CODE=${PIPESTATUS[0]}
	echo "[*] finished with exit code $EXIT_CODE"
	if [ $EXIT_CODE -ne 0 ]; then
		echo "[!] failed to build for $DESTINATION"
		exit 1
	fi
}

# to reset all cache
# rm -rf "$(getconf DARWIN_USER_CACHE_DIR)/org.llvm.clang/ModuleCache"
# rm -rf "$(getconf DARWIN_USER_CACHE_DIR)/org.llvm.clang.$(whoami)/ModuleCache"
# rm -rf ~/Library/Developer/Xcode/DerivedData/*
# rm -rf ~/Library/Caches/com.apple.dt.Xcode/*
# rm -rf ~/Library/Caches/org.swift.swiftpm
# rm -rf ~/Library/org.swift.swiftpm

test_build "generic/platform=macOS"
test_build "generic/platform=macOS,variant=Mac Catalyst"
test_build "generic/platform=iOS"
test_build "generic/platform=iOS Simulator"
test_build "generic/platform=xrOS"
test_build "generic/platform=xrOS Simulator"
