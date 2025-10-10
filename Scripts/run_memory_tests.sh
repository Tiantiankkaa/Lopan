#!/bin/bash

#
# run_memory_tests.sh
# Convenience script for running Ephemeral Context Memory Tests
#
# These tests must be run from command line to avoid Xcode View Debugger
# timeout issues when serializing 112K SwiftData objects.
#
# Usage:
#   ./scripts/run_memory_tests.sh                    # Run all memory tests
#   ./scripts/run_memory_tests.sh testName           # Run specific test
#   ./scripts/run_memory_tests.sh --help             # Show help
#

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
SCHEME="Lopan"
SDK="iphonesimulator"
DESTINATION="platform=iOS Simulator,name=iPhone 17 Pro Max"
TEST_SUITE="LopanTests/EphemeralContextMemoryTests"
LOG_DIR="/tmp"

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to show help
show_help() {
    cat << EOF
${GREEN}Ephemeral Context Memory Tests Runner${NC}

${BLUE}Usage:${NC}
  $(basename "$0") [test_name]

${BLUE}Examples:${NC}
  $(basename "$0")                                           # Run all memory tests
  $(basename "$0") testFetchDashboardMetrics_MemoryRelease   # Run specific test
  $(basename "$0") --list                                    # List available tests

${BLUE}Available Tests:${NC}
  - testCountByStatusInBatches_MemoryRelease
  - testFetchDashboardMetrics_MemoryRelease
  - testFetchDeliveryStatistics_MemoryRelease
  - testMemoryComparison_EphemeralVsReused
  - testEphemeralContextLogging

${YELLOW}Note:${NC} These tests must be run from command line (not Xcode UI) to avoid
      View Debugger timeout issues with 112K SwiftData objects.

${BLUE}Memory Targets:${NC}
  - Individual operations: < 80MB peak memory growth
  - Comparison test: > 50% memory improvement vs. reused context

${BLUE}Log Location:${NC}
  Results saved to: ${LOG_DIR}/memory_tests_<timestamp>.log
EOF
}

# Function to list available tests
list_tests() {
    print_info "Available memory tests:"
    echo "  1. testCountByStatusInBatches_MemoryRelease"
    echo "  2. testFetchDashboardMetrics_MemoryRelease"
    echo "  3. testFetchDeliveryStatistics_MemoryRelease"
    echo "  4. testMemoryComparison_EphemeralVsReused"
    echo "  5. testEphemeralContextLogging"
}

# Parse command line arguments
TEST_NAME=""
if [[ $# -gt 0 ]]; then
    case "$1" in
        --help|-h)
            show_help
            exit 0
            ;;
        --list|-l)
            list_tests
            exit 0
            ;;
        *)
            TEST_NAME="/$1"
            ;;
    esac
fi

# Generate timestamp for log file
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${LOG_DIR}/memory_tests_${TIMESTAMP}.log"

# Print header
echo ""
print_info "═══════════════════════════════════════════════════════════"
print_info "  Ephemeral Context Memory Tests"
print_info "═══════════════════════════════════════════════════════════"
echo ""

if [[ -n "$TEST_NAME" ]]; then
    print_info "Running specific test: ${TEST_NAME#/}"
else
    print_info "Running all memory tests"
fi

print_info "Simulator: iPhone 17 Pro Max (iOS 26.0)"
print_info "Log file: $LOG_FILE"
echo ""

# Build the xcodebuild command
CMD="xcodebuild test \
    -scheme \"$SCHEME\" \
    -sdk \"$SDK\" \
    -destination \"$DESTINATION\" \
    -only-testing:${TEST_SUITE}${TEST_NAME} \
    -allowProvisioningUpdates"

# Run the tests
print_info "Executing: xcodebuild test..."
echo ""

if eval "$CMD 2>&1 | tee \"$LOG_FILE\""; then
    echo ""
    print_success "Tests completed successfully!"
    print_info "Log saved to: $LOG_FILE"

    # Extract test results summary
    if grep -q "Test Suite 'EphemeralContextMemoryTests' passed" "$LOG_FILE"; then
        print_success "All tests PASSED"
    elif grep -q "Test Suite 'EphemeralContextMemoryTests' failed" "$LOG_FILE"; then
        print_warning "Some tests FAILED - check log for details"
    fi

    echo ""
    print_info "To view memory measurements:"
    echo "  grep -E '📏|Memory|TEST [0-9]' $LOG_FILE"

    exit 0
else
    echo ""
    print_error "Tests failed!"
    print_info "Log saved to: $LOG_FILE"
    print_info "Check log for error details"
    exit 1
fi
