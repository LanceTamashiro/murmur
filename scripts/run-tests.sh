#!/bin/bash
# run-tests.sh — Runs all Murmur tests (MurmurCore + MurmurTests)
#
# Runs MurmurTests suites individually to work around macOS 26 beta
# BSBlockSentinel:FBSWorkspaceScenesClient crash. The crash can delete
# the xctest bundle, so we rebuild before each suite. Build cache makes
# this fast (~2s per rebuild).
#
# The crash can also cause xcodebuild to report TEST EXECUTE FAILED even
# when all tests passed, so this script checks the actual Swift Testing
# output (✔/✗ lines) rather than relying on the exit code.
#
# When adding a new @Suite struct to MurmurTests, add its struct name
# to the SUITES array below.

set -uo pipefail

cd "$(dirname "$0")/.."
PROJECT_ROOT="$(pwd)"

FAILED=0
PASSED=0
RESULTS=()

DESTINATION='platform=macOS'

# MurmurTests suite struct names (used with -only-testing:)
SUITES=(
    "DictationViewModelRaceTests"
    "EarlyInjectionTests"
    "AppDelegateSetupTests"
    "MockSpeechEngineRaceTests"
    "TextInjectionTests"
    "SessionRecoveryTests"
    "TriggerKeyTests"
    "ToggleMaxDurationTests"
    "KeychainServiceTests"
    "AIPipelineIntegrationTests"
    "MenuBarPopoverTests"
    "NoteExporterTests"
    "KeychainEdgeCaseTests"
)

record_result() {
    local name="$1" code="$2"
    if [ "$code" -eq 0 ]; then
        RESULTS+=("  ✓ $name")
        PASSED=$((PASSED + 1))
    else
        RESULTS+=("  ✗ $name")
        FAILED=$((FAILED + 1))
    fi
}

# Check actual Swift Testing results in xcodebuild output.
# Returns 0 if the suite passed, 1 if any test failed or no results found.
check_suite_output() {
    local output="$1"
    local suite_name="$2"

    # Check for actual test failures (✗ Test ... failed)
    if echo "$output" | grep -q '✗ Test .* failed'; then
        return 1
    fi
    # Check for suite pass
    if echo "$output" | grep -qF "✔ Suite"; then
        return 0
    fi
    if echo "$output" | grep -qF "✔ Test run with"; then
        return 0
    fi
    # No Swift Testing output found — suite didn't run
    return 1
}

# --- MurmurCore SPM Tests ---
echo "=== MurmurCore SPM Tests ==="
cd "$PROJECT_ROOT/Packages/MurmurCore"
if swift test 2>&1; then
    record_result "MurmurCore (SPM)" 0
else
    record_result "MurmurCore (SPM)" 1
fi

# --- Run each MurmurTests suite separately ---
echo ""
echo "=== MurmurTests (per-suite) ==="
cd "$PROJECT_ROOT"
for suite in "${SUITES[@]}"; do
    echo "--- $suite ---"

    # Kill any zombie Murmur instances relaunched by macOS after a test host exit.
    # These aren't test hosts (parentProc=launchd, no XCTest env), so our guards
    # don't fire and they crash in SwiftData, producing annoying dialogs.
    pkill -9 -f 'Murmur.app/Contents/MacOS/Murmur' 2>/dev/null || true
    sleep 0.2

    # Build (or rebuild) to ensure xctest bundle exists.
    # The beta crash can delete it, but build cache makes this fast.
    xcodebuild build-for-testing \
        -scheme Murmur \
        -destination "$DESTINATION" \
        2>&1 > /dev/null

    OUTPUT=$(xcodebuild test-without-building \
        -scheme Murmur \
        -destination "$DESTINATION" \
        -only-testing:"MurmurTests/$suite" \
        2>&1) || true

    # Show relevant Swift Testing output
    echo "$OUTPUT" | grep -E '^(✔|✗|◇)' || true

    if check_suite_output "$OUTPUT" "$suite"; then
        record_result "$suite" 0
    else
        # Show tail on real failure for debugging
        echo "  FAILED — details:"
        echo "$OUTPUT" | tail -15
        record_result "$suite" 1
    fi
    echo ""
done

# --- Summary ---
echo ""
echo "=== Summary ==="
for r in "${RESULTS[@]}"; do
    echo "$r"
done
echo ""
echo "Passed: $PASSED  Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
