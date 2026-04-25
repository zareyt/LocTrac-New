#!/bin/zsh
#
# pre-commit-test.sh
# LocTrac
#
# Runs unit tests before allowing a commit.
# Usage:
#   ./scripts/pre-commit-test.sh          (run unit tests only)
#   ./scripts/pre-commit-test.sh --all    (run unit + UI tests)
#
# To install as a git pre-commit hook:
#   ln -sf ../../scripts/pre-commit-test.sh .git/hooks/pre-commit
#

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="LocTrac"
TEST_PLAN="LocTrac"
DESTINATION="platform=iOS Simulator,name=iPhone 16"

RUN_UI_TESTS=false
if [[ "${1:-}" == "--all" ]]; then
    RUN_UI_TESTS=true
fi

echo "=== LocTrac Pre-Commit Tests ==="
echo "Project: $PROJECT_DIR"
echo "Scheme: $SCHEME"
echo ""

if [[ "$RUN_UI_TESTS" == "true" ]]; then
    echo "Running ALL tests (unit + UI)..."
    TEST_TARGET_FLAG=""
else
    echo "Running unit tests only..."
    TEST_TARGET_FLAG="-only-testing LocTracTests"
fi

cd "$PROJECT_DIR"

BUILD_OUTPUT=$(xcodebuild test \
    -scheme "$SCHEME" \
    -testPlan "$TEST_PLAN" \
    -destination "$DESTINATION" \
    $TEST_TARGET_FLAG \
    -quiet \
    2>&1) || {
    echo ""
    echo "TESTS FAILED"
    echo ""
    echo "$BUILD_OUTPUT" | tail -30
    echo ""
    echo "Fix failing tests before committing."
    exit 1
}

PASS_COUNT=$(echo "$BUILD_OUTPUT" | grep -c "Test Case.*passed" 2>/dev/null || echo "0")
FAIL_COUNT=$(echo "$BUILD_OUTPUT" | grep -c "Test Case.*failed" 2>/dev/null || echo "0")

echo ""
echo "All tests passed ($PASS_COUNT passed, $FAIL_COUNT failed)"
echo "=== Pre-Commit Check Complete ==="
exit 0
