#!/bin/bash

cd "$(dirname "$0")"
cd ..

SCEHEME="Example"
WORKSPACE="Example.xcworkspace"

WATCH_SCHEME="ExampleWatch Watch App"

# run_xcodebuild <label> <xcodebuild arguments...>
function run_xcodebuild() {
	LABEL=$1
	shift
	echo "[*] $LABEL"
	xcodebuild "$@" \
		CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
		| xcbeautify --disable-logging
	EXIT_CODE=${PIPESTATUS[0]}
	echo "[*] finished with exit code $EXIT_CODE"
	if [ $EXIT_CODE -ne 0 ]; then
		echo "[!] failed: $LABEL"
		exit 1
	fi
}

function test_build() {
	DESTINATION=$1
	run_xcodebuild "test build for $DESTINATION" \
		-scheme $SCEHEME -workspace $WORKSPACE -destination "$DESTINATION"
}

# The Mac Catalyst test target is only compiled by build-for-testing; a plain
# build never touches it. Code coverage stays off: with it on, linking the
# cmark-gfm package product fails with an undefined ___llvm_profile_runtime.
function test_build_for_testing() {
	DESTINATION=$1
	run_xcodebuild "build-for-testing for $DESTINATION" \
		build-for-testing -enableCodeCoverage NO \
		-scheme $SCEHEME -workspace $WORKSPACE -destination "$DESTINATION"
}

function test_build_watch() {
	DESTINATION=$1
	run_xcodebuild "watch build for $DESTINATION" \
		-scheme "$WATCH_SCHEME" -workspace $WORKSPACE -destination "$DESTINATION"
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
test_build_for_testing "platform=macOS,variant=Mac Catalyst"
test_build_watch "generic/platform=watchOS"
test_build_watch "generic/platform=watchOS Simulator"
