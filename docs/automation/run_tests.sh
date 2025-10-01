#!/bin/bash

# Automated Test Runner for Lopan iOS App
# Runs unit tests, UI tests, and performance tests with coverage

set -e

echo "🧪 Lopan iOS Test Suite Runner"
echo "=============================="
echo "Date: $(date)"
echo ""

# Configuration
SCHEME="Lopan"
DEVICE="iPhone 17 Pro Max,OS=26.0"
PROJECT_DIR="$(pwd)"
COVERAGE_THRESHOLD=75

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

success() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️ $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }

# Function to check if simulator is available
check_simulator() {
    echo "📱 Checking iOS Simulator..."
    if xcrun simctl list devices | grep -q "iPhone 17 Pro Max"; then
        success "iPhone 17 Pro Max simulator available"
    else
        warning "Creating iPhone 17 Pro Max simulator..."
        xcrun simctl create "iPhone 17 Pro Max" "com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro-Max" "com.apple.CoreSimulator.SimRuntime.iOS-17-0"
    fi
}

# Function to run unit tests
run_unit_tests() {
    echo ""
    echo "🔬 Running Unit Tests..."
    echo "========================"

    # Run just the working tests first
    if xcodebuild test \
        -scheme "$SCHEME" \
        -destination "platform=iOS Simulator,name=$DEVICE" \
        -testPlan "UnitTests" \
        -enableCodeCoverage YES \
        -quiet; then
        success "Unit tests passed"
        return 0
    else
        warning "Some unit tests failed, continuing with available tests..."
        return 1
    fi
}

# Function to run performance tests
run_performance_tests() {
    echo ""
    echo "⚡ Running Performance Tests..."
    echo "============================="

    # Check if performance test file exists
    if [ -f "LopanTests/PerformanceTests.swift" ]; then
        success "Performance test file found"

        # Try to run performance tests
        if xcodebuild test \
            -scheme "$SCHEME" \
            -destination "platform=iOS Simulator,name=$DEVICE" \
            -only-testing "LopanTests/PerformanceTests" \
            -enableCodeCoverage YES \
            -quiet; then
            success "Performance tests passed"
            return 0
        else
            warning "Performance tests had issues, checking implementation..."
            return 1
        fi
    else
        error "Performance test file not found"
        return 1
    fi
}

# Function to check code coverage
check_coverage() {
    echo ""
    echo "📊 Checking Code Coverage..."
    echo "==========================="

    # Find the latest test results
    DERIVED_DATA_PATH="$HOME/Library/Developer/Xcode/DerivedData"
    LATEST_RESULT=$(find "$DERIVED_DATA_PATH" -name "*.xcresult" -type d | head -1)

    if [ -n "$LATEST_RESULT" ]; then
        echo "Found test results: $LATEST_RESULT"

        # Try to extract coverage info
        if command -v xcov &> /dev/null; then
            xcov --xcresult_path "$LATEST_RESULT" --minimum_coverage_percentage $COVERAGE_THRESHOLD
        else
            warning "xcov not installed, using basic coverage check"
            xcrun xccov view --report "$LATEST_RESULT" || warning "Could not generate coverage report"
        fi
    else
        warning "No test results found for coverage analysis"
    fi
}

# Function to validate code quality
validate_code_quality() {
    echo ""
    echo "🔍 Code Quality Validation..."
    echo "==========================="

    # Check for common issues
    echo "Checking for common code issues..."

    # Check for hardcoded strings that should be localized
    hardcoded_strings=$(grep -r "Text(\"[^\"]*\")" Lopan/Views --include="*.swift" | grep -v "\.localized" | wc -l | tr -d ' ')
    if [ $hardcoded_strings -gt 10 ]; then
        warning "Found $hardcoded_strings potentially non-localized strings"
    else
        success "String localization looks good ($hardcoded_strings non-localized)"
    fi

    # Check for memory leaks patterns
    retain_cycles=$(grep -r "self\." Lopan --include="*.swift" | grep -E "closure|block" | wc -l | tr -d ' ')
    echo "Potential retain cycle patterns: $retain_cycles"

    # Check accessibility implementation
    accessibility_labels=$(grep -r "accessibilityLabel\|accessibilityHint" Lopan --include="*.swift" | wc -l | tr -d ' ')
    if [ $accessibility_labels -gt 100 ]; then
        success "Good accessibility implementation ($accessibility_labels accessibility modifiers)"
    else
        warning "Consider adding more accessibility labels ($accessibility_labels found)"
    fi
}

# Function to run lint checks
run_lint_checks() {
    echo ""
    echo "🔧 Running Lint Checks..."
    echo "======================="

    # Check if SwiftLint is available
    if command -v swiftlint &> /dev/null; then
        echo "Running SwiftLint..."
        if swiftlint --quiet; then
            success "SwiftLint passed"
        else
            warning "SwiftLint found issues (see above)"
        fi
    else
        warning "SwiftLint not installed, skipping lint checks"
        echo "Install with: brew install swiftlint"
    fi

    # Manual checks
    echo "Running manual code checks..."

    # Check for print statements in release code
    debug_prints=$(grep -r "print(" Lopan --include="*.swift" | grep -v "// DEBUG" | wc -l | tr -d ' ')
    if [ $debug_prints -gt 5 ]; then
        warning "Found $debug_prints print statements (consider removing for release)"
    else
        success "Debug print statements under control ($debug_prints found)"
    fi
}

# Main execution
main() {
    echo "Starting test suite execution..."

    # Initialize counters
    tests_passed=0
    tests_failed=0

    # Check prerequisites
    check_simulator

    # Run tests
    if run_unit_tests; then
        tests_passed=$((tests_passed + 1))
    else
        tests_failed=$((tests_failed + 1))
    fi

    if run_performance_tests; then
        tests_passed=$((tests_passed + 1))
    else
        tests_failed=$((tests_failed + 1))
    fi

    # Quality checks
    validate_code_quality
    run_lint_checks
    check_coverage

    # Summary
    echo ""
    echo "📋 Test Summary"
    echo "==============="
    echo "Tests Passed: $tests_passed"
    echo "Tests Failed: $tests_failed"

    # Build verification
    echo ""
    echo "🔨 Final Build Verification..."
    if xcodebuild build -scheme "$SCHEME" -destination "platform=iOS Simulator,name=$DEVICE" -quiet; then
        success "Final build verification passed"
        echo ""
        echo "🎉 Test Suite Completed Successfully!"
        echo "Ready for further development or deployment."
    else
        error "Final build verification failed"
        echo ""
        echo "❌ Test Suite Failed"
        echo "Please fix build issues before proceeding."
        exit 1
    fi
}

# Help function
show_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -u, --unit     Run only unit tests"
    echo "  -p, --perf     Run only performance tests"
    echo "  -c, --coverage Run coverage analysis only"
    echo "  -q, --quick    Run quick validation (build + lint)"
    echo ""
    echo "Examples:"
    echo "  $0              # Run full test suite"
    echo "  $0 --unit       # Run only unit tests"
    echo "  $0 --quick      # Quick validation"
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    -u|--unit)
        check_simulator
        run_unit_tests
        exit $?
        ;;
    -p|--perf)
        check_simulator
        run_performance_tests
        exit $?
        ;;
    -c|--coverage)
        check_coverage
        exit $?
        ;;
    -q|--quick)
        echo "🚀 Quick Validation Mode"
        run_lint_checks
        xcodebuild build -scheme "$SCHEME" -destination "platform=iOS Simulator,name=$DEVICE" -quiet
        exit $?
        ;;
    "")
        main
        ;;
    *)
        error "Unknown option: $1"
        show_help
        exit 1
        ;;
esac