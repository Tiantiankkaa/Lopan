#!/bin/bash

# Code Coverage Report Generator for Lopan iOS App
# Generates detailed coverage reports and validates against targets

set -e

echo "📊 Lopan iOS Code Coverage Generator"
echo "===================================="
echo "Date: $(date)"
echo ""

# Configuration
SCHEME="Lopan"
DEVICE="iPhone 17 Pro Max,OS=26.0"
COVERAGE_TARGET=85
PROJECT_NAME="Lopan"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

success() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️ $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
info() { echo -e "${BLUE}ℹ️ $1${NC}"; }

# Function to run tests with coverage
run_tests_with_coverage() {
    echo "🧪 Running tests with code coverage..."
    echo "====================================="

    # Clean previous test data
    echo "Cleaning previous test data..."
    rm -rf ~/Library/Developer/Xcode/DerivedData/Lopan-*/Logs/Test/

    # Run unit tests with coverage
    echo "Running unit tests..."
    if xcodebuild test \
        -scheme "$SCHEME" \
        -destination "platform=iOS Simulator,name=$DEVICE" \
        -enableCodeCoverage YES \
        -derivedDataPath "./DerivedData" \
        -resultBundlePath "./TestResults.xcresult" \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO; then
        success "Tests completed successfully"
        return 0
    else
        warning "Some tests failed, but continuing with coverage analysis..."
        return 1
    fi
}

# Function to find test results
find_test_results() {
    echo ""
    echo "🔍 Finding test results..."

    # Check for local results first
    if [ -f "./TestResults.xcresult" ]; then
        echo "./TestResults.xcresult"
        return 0
    fi

    # Check DerivedData
    if [ -d "./DerivedData" ]; then
        RESULT_PATH=$(find "./DerivedData" -name "*.xcresult" -type d | head -1)
        if [ -n "$RESULT_PATH" ]; then
            echo "$RESULT_PATH"
            return 0
        fi
    fi

    # Check system DerivedData
    DERIVED_DATA_PATH="$HOME/Library/Developer/Xcode/DerivedData"
    RESULT_PATH=$(find "$DERIVED_DATA_PATH" -name "*$PROJECT_NAME*" -type d | head -1)
    if [ -n "$RESULT_PATH" ]; then
        RESULT_PATH=$(find "$RESULT_PATH" -name "*.xcresult" -type d | head -1)
        if [ -n "$RESULT_PATH" ]; then
            echo "$RESULT_PATH"
            return 0
        fi
    fi

    return 1
}

# Function to generate basic coverage report
generate_basic_coverage() {
    local result_path="$1"
    echo ""
    echo "📈 Generating Basic Coverage Report..."
    echo "====================================="

    if xcrun xccov view --report "$result_path" > coverage_basic.txt 2>/dev/null; then
        success "Basic coverage report generated: coverage_basic.txt"

        # Extract overall coverage percentage
        if command -v grep &> /dev/null; then
            OVERALL_COVERAGE=$(grep -E "^\s*$PROJECT_NAME\.app" coverage_basic.txt | awk '{print $3}' | sed 's/%//' || echo "0")
            echo "Overall Coverage: ${OVERALL_COVERAGE}%"

            # Check against target
            if [ $(echo "$OVERALL_COVERAGE >= $COVERAGE_TARGET" | bc -l 2>/dev/null || echo 0) -eq 1 ]; then
                success "Coverage target met: ${OVERALL_COVERAGE}% >= ${COVERAGE_TARGET}%"
            else
                warning "Coverage below target: ${OVERALL_COVERAGE}% < ${COVERAGE_TARGET}%"
            fi
        fi

        # Show summary
        echo ""
        echo "Coverage Summary:"
        head -20 coverage_basic.txt
    else
        error "Failed to generate basic coverage report"
        return 1
    fi
}

# Function to generate detailed coverage report
generate_detailed_coverage() {
    local result_path="$1"
    echo ""
    echo "📋 Generating Detailed Coverage Report..."
    echo "========================================"

    # Generate detailed report
    if xcrun xccov view --file-list "$result_path" > coverage_files.txt 2>/dev/null; then
        success "File coverage list generated: coverage_files.txt"

        # Show files with low coverage
        echo ""
        echo "Files with coverage < 70%:"
        while IFS= read -r line; do
            if echo "$line" | grep -E "\s+[0-6][0-9]\.[0-9]+%" >/dev/null; then
                echo "  $line"
            fi
        done < coverage_files.txt || echo "  All files have good coverage!"

    else
        warning "Could not generate detailed file coverage"
    fi

    # Generate function-level coverage for key files
    echo ""
    echo "Analyzing key service files..."

    KEY_FILES=(
        "LopanPerformanceProfiler.swift"
        "LopanMemoryManager.swift"
        "LopanScrollOptimizer.swift"
        "AuthenticationService.swift"
        "CustomerService.swift"
    )

    for file in "${KEY_FILES[@]}"; do
        if grep -q "$file" coverage_files.txt 2>/dev/null; then
            coverage_line=$(grep "$file" coverage_files.txt)
            echo "  $coverage_line"
        fi
    done
}

# Function to generate HTML coverage report
generate_html_coverage() {
    local result_path="$1"
    echo ""
    echo "🌐 Generating HTML Coverage Report..."
    echo "===================================="

    # Check if we can generate HTML report
    if command -v xcov &> /dev/null; then
        echo "Using xcov for HTML report generation..."
        if xcov --xcresult_path "$result_path" --output_directory "./coverage_html" --minimum_coverage_percentage $COVERAGE_TARGET; then
            success "HTML coverage report generated in ./coverage_html/"
            echo "Open ./coverage_html/index.html in your browser to view detailed coverage"
        else
            warning "xcov failed, trying alternative method..."
        fi
    else
        warning "xcov not installed. Install with: gem install xcov"
        echo "Generating basic HTML with xccov..."

        # Create a simple HTML report
        cat > coverage_report.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Lopan iOS Code Coverage Report</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 40px; }
        .header { background: #f5f5f5; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
        .metric { display: inline-block; margin: 10px 20px 10px 0; }
        .high { color: #28a745; }
        .medium { color: #ffc107; }
        .low { color: #dc3545; }
        pre { background: #f8f9fa; padding: 15px; border-radius: 4px; overflow-x: auto; }
    </style>
</head>
<body>
    <div class="header">
        <h1>📊 Lopan iOS Code Coverage Report</h1>
        <p>Generated: $(date)</p>
        <p>Target Coverage: ${COVERAGE_TARGET}%</p>
    </div>

    <h2>Overall Coverage</h2>
    <div class="metric">
        <strong>Project Coverage:</strong> <span class="high">See detailed report below</span>
    </div>

    <h2>Detailed Coverage Data</h2>
    <pre>
$(cat coverage_basic.txt 2>/dev/null || echo "Coverage data not available")
    </pre>

    <h2>File Coverage</h2>
    <pre>
$(cat coverage_files.txt 2>/dev/null || echo "File coverage data not available")
    </pre>

    <h2>Recommendations</h2>
    <ul>
        <li>Focus on files with coverage below 70%</li>
        <li>Add unit tests for business logic in Services/</li>
        <li>Test error handling and edge cases</li>
        <li>Consider integration tests for workflows</li>
    </ul>
</body>
</html>
EOF

        success "Basic HTML report generated: coverage_report.html"
    fi
}

# Function to analyze coverage trends
analyze_coverage_trends() {
    echo ""
    echo "📈 Coverage Analysis & Recommendations..."
    echo "========================================"

    # Count test files
    unit_tests=$(find . -name "*Tests.swift" -not -path "./DerivedData/*" | wc -l | tr -d ' ')
    total_swift_files=$(find Lopan -name "*.swift" | wc -l | tr -d ' ')

    echo "Test Infrastructure:"
    echo "  Unit Test Files: $unit_tests"
    echo "  Total Swift Files: $total_swift_files"
    echo "  Test Coverage Ratio: $(echo "scale=1; $unit_tests * 100 / $total_swift_files" | bc -l 2>/dev/null || echo "N/A")%"

    # Analyze key directories
    echo ""
    echo "Key Areas for Testing:"

    DIRS_TO_ANALYZE=("Lopan/Services" "Lopan/Models" "Lopan/Repository")
    for dir in "${DIRS_TO_ANALYZE[@]}"; do
        if [ -d "$dir" ]; then
            file_count=$(find "$dir" -name "*.swift" | wc -l | tr -d ' ')
            echo "  $dir: $file_count files"
        fi
    done

    # Recommendations
    echo ""
    echo "📋 Recommendations for Improving Coverage:"
    echo "1. Add unit tests for Services/ directory (business logic)"
    echo "2. Test Repository layer with mock data"
    echo "3. Add integration tests for critical workflows"
    echo "4. Test error handling and edge cases"
    echo "5. Consider UI tests for user flows"
}

# Function to validate against Phase 4 targets
validate_phase4_targets() {
    echo ""
    echo "🎯 Phase 4 Coverage Validation..."
    echo "================================"

    # Read coverage from basic report if available
    if [ -f "coverage_basic.txt" ]; then
        ACTUAL_COVERAGE=$(grep -E "^\s*$PROJECT_NAME\.app" coverage_basic.txt | awk '{print $3}' | sed 's/%//' 2>/dev/null || echo "0")

        echo "Phase 4 Coverage Targets:"
        echo "  Target: ${COVERAGE_TARGET}%"
        echo "  Actual: ${ACTUAL_COVERAGE}%"

        if [ $(echo "$ACTUAL_COVERAGE >= $COVERAGE_TARGET" | bc -l 2>/dev/null || echo 0) -eq 1 ]; then
            success "✅ Phase 4 coverage target achieved!"
        elif [ $(echo "$ACTUAL_COVERAGE >= $((COVERAGE_TARGET - 10))" | bc -l 2>/dev/null || echo 0) -eq 1 ]; then
            warning "⚠️ Close to Phase 4 target (within 10%)"
        else
            error "❌ Phase 4 coverage target not met"
        fi
    else
        warning "Could not validate coverage against Phase 4 targets"
    fi
}

# Main execution
main() {
    echo "Starting coverage report generation..."

    # Run tests with coverage
    run_tests_with_coverage

    # Find test results
    echo ""
    RESULT_PATH=$(find_test_results)
    if [ $? -eq 0 ] && [ -n "$RESULT_PATH" ]; then
        success "Found test results: $RESULT_PATH"

        # Generate reports
        generate_basic_coverage "$RESULT_PATH"
        generate_detailed_coverage "$RESULT_PATH"
        generate_html_coverage "$RESULT_PATH"
        analyze_coverage_trends
        validate_phase4_targets

        echo ""
        success "Coverage report generation completed!"
        echo ""
        echo "📂 Generated Files:"
        ls -la coverage_* 2>/dev/null || echo "  (No coverage files found)"

    else
        error "Could not find test results"
        echo "Run this script after running tests, or run with --generate-only"
        exit 1
    fi
}

# Help function
show_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -g, --generate-only Generate reports from existing test results"
    echo "  -t, --target NUM    Set coverage target percentage (default: $COVERAGE_TARGET)"
    echo "  -q, --quick         Quick coverage check without HTML generation"
    echo ""
    echo "Examples:"
    echo "  $0                  # Run tests and generate full coverage report"
    echo "  $0 --generate-only  # Generate reports from existing results"
    echo "  $0 --target 90      # Set 90% coverage target"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -g|--generate-only)
            RESULT_PATH=$(find_test_results)
            if [ $? -eq 0 ] && [ -n "$RESULT_PATH" ]; then
                generate_basic_coverage "$RESULT_PATH"
                generate_detailed_coverage "$RESULT_PATH"
                generate_html_coverage "$RESULT_PATH"
                analyze_coverage_trends
                validate_phase4_targets
                exit 0
            else
                error "No existing test results found"
                exit 1
            fi
            ;;
        -t|--target)
            COVERAGE_TARGET="$2"
            shift 2
            ;;
        -q|--quick)
            RESULT_PATH=$(find_test_results)
            if [ $? -eq 0 ] && [ -n "$RESULT_PATH" ]; then
                generate_basic_coverage "$RESULT_PATH"
                validate_phase4_targets
                exit 0
            else
                error "No existing test results found"
                exit 1
            fi
            ;;
        *)
            error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Run main function if no arguments
main