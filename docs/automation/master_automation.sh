#!/bin/bash

# Master Automation Script for Lopan iOS Production Pipeline
# Orchestrates all automation tasks for production deployment

set -e

echo "🚀 Lopan iOS Master Automation Pipeline"
echo "======================================"
echo "Date: $(date)"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

success() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️ $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
info() { echo -e "${BLUE}ℹ️ $1${NC}"; }
stage() { echo -e "${PURPLE}🎬 $1${NC}"; }

# Configuration
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
PROJECT_ROOT="$(pwd)"
AUTOMATION_DIR="$PROJECT_ROOT/docs/automation"

# Pipeline stages
declare -A STAGES=(
    ["performance"]="Performance Benchmark"
    ["tests"]="Test Suite Execution"
    ["coverage"]="Code Coverage Analysis"
    ["security"]="Security Audit"
    ["all"]="Complete Pipeline"
)

# Function to run performance benchmark
run_performance_benchmark() {
    stage "Running Performance Benchmark..."
    echo "=================================="

    if [ -f "$AUTOMATION_DIR/performance_benchmark.sh" ]; then
        bash "$AUTOMATION_DIR/performance_benchmark.sh"
        success "Performance benchmark completed"
        return 0
    else
        error "Performance benchmark script not found"
        return 1
    fi
}

# Function to run test suite
run_test_suite() {
    stage "Running Test Suite..."
    echo "===================="

    if [ -f "$AUTOMATION_DIR/run_tests.sh" ]; then
        bash "$AUTOMATION_DIR/run_tests.sh" --quick
        success "Test suite completed"
        return 0
    else
        error "Test runner script not found"
        return 1
    fi
}

# Function to generate coverage report
run_coverage_analysis() {
    stage "Generating Coverage Report..."
    echo "============================="

    if [ -f "$AUTOMATION_DIR/generate_coverage.sh" ]; then
        bash "$AUTOMATION_DIR/generate_coverage.sh" --quick
        success "Coverage analysis completed"
        return 0
    else
        error "Coverage generator script not found"
        return 1
    fi
}

# Function to run security audit
run_security_audit() {
    stage "Running Security Audit..."
    echo "========================="

    if [ -f "$AUTOMATION_DIR/security_audit.sh" ]; then
        bash "$AUTOMATION_DIR/security_audit.sh"
        success "Security audit completed"
        return 0
    else
        error "Security audit script not found"
        return 1
    fi
}

# Function to run complete pipeline
run_complete_pipeline() {
    stage "Starting Complete Production Pipeline..."
    echo "========================================"

    local start_time=$(date +%s)
    local stages_passed=0
    local stages_failed=0

    echo ""
    info "Pipeline Stages:"
    echo "1. Performance Benchmark"
    echo "2. Test Suite Execution"
    echo "3. Code Coverage Analysis"
    echo "4. Security Audit"
    echo ""

    # Stage 1: Performance Benchmark
    echo "📊 Stage 1/4: Performance Benchmark"
    if run_performance_benchmark; then
        stages_passed=$((stages_passed + 1))
    else
        stages_failed=$((stages_failed + 1))
        warning "Performance benchmark failed, continuing..."
    fi

    echo ""

    # Stage 2: Test Suite
    echo "🧪 Stage 2/4: Test Suite"
    if run_test_suite; then
        stages_passed=$((stages_passed + 1))
    else
        stages_failed=$((stages_failed + 1))
        warning "Test suite failed, continuing..."
    fi

    echo ""

    # Stage 3: Coverage Analysis
    echo "📈 Stage 3/4: Coverage Analysis"
    if run_coverage_analysis; then
        stages_passed=$((stages_passed + 1))
    else
        stages_failed=$((stages_failed + 1))
        warning "Coverage analysis failed, continuing..."
    fi

    echo ""

    # Stage 4: Security Audit
    echo "🔒 Stage 4/4: Security Audit"
    if run_security_audit; then
        stages_passed=$((stages_passed + 1))
    else
        stages_failed=$((stages_failed + 1))
        warning "Security audit failed, continuing..."
    fi

    # Pipeline Summary
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    echo ""
    echo "🏁 Pipeline Execution Summary"
    echo "============================"
    echo "Duration: ${duration}s"
    echo "Stages Passed: $stages_passed/4"
    echo "Stages Failed: $stages_failed/4"

    if [ $stages_failed -eq 0 ]; then
        success "🎉 All pipeline stages completed successfully!"
        echo ""
        echo "📂 Generated Artifacts:"
        ls -la coverage_* security_* 2>/dev/null || echo "  (Check individual stage outputs)"
        echo ""
        echo "✅ Production Readiness: EXCELLENT"
        echo "Ready for App Store submission!"
        return 0
    elif [ $stages_passed -gt $stages_failed ]; then
        warning "⚠️ Pipeline completed with some failures"
        echo "Most stages passed - review failed stages and retry"
        return 1
    else
        error "❌ Pipeline failed - multiple stages need attention"
        return 1
    fi
}

# Function to show pipeline status
show_status() {
    echo "📋 Lopan iOS Automation Status"
    echo "============================="
    echo ""

    echo "Available Scripts:"
    for script in performance_benchmark.sh run_tests.sh generate_coverage.sh security_audit.sh; do
        if [ -f "$AUTOMATION_DIR/$script" ]; then
            success "$script"
        else
            error "$script (missing)"
        fi
    done

    echo ""
    echo "Recent Artifacts:"
    find . -name "coverage_*" -o -name "security_*" -o -name "TestResults.xcresult" 2>/dev/null | head -5 || echo "  No recent artifacts found"

    echo ""
    echo "Project Stats:"
    if [ -d "Lopan" ]; then
        swift_files=$(find Lopan -name "*.swift" | wc -l | tr -d ' ')
        echo "  Swift Files: $swift_files"

        total_lines=$(find Lopan -name "*.swift" -exec wc -l {} + | tail -1 | awk '{print $1}')
        echo "  Lines of Code: $total_lines"

        test_files=$(find . -name "*Tests.swift" | wc -l | tr -d ' ')
        echo "  Test Files: $test_files"
    fi
}

# Function to clean artifacts
clean_artifacts() {
    echo "🧹 Cleaning Previous Artifacts..."
    echo "==============================="

    artifacts_to_clean=(
        "coverage_*"
        "security_*"
        "TestResults.xcresult"
        "DerivedData"
        "*.xcresult"
    )

    for pattern in "${artifacts_to_clean[@]}"; do
        if ls $pattern 1> /dev/null 2>&1; then
            rm -rf $pattern
            echo "Removed: $pattern"
        fi
    done

    success "Artifact cleanup completed"
}

# Help function
show_help() {
    echo "Usage: $0 [stage] [options]"
    echo ""
    echo "Stages:"
    for stage in "${!STAGES[@]}"; do
        echo "  $stage     ${STAGES[$stage]}"
    done
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -s, --status   Show pipeline status"
    echo "  -c, --clean    Clean previous artifacts"
    echo "  -v, --verbose  Verbose output"
    echo ""
    echo "Examples:"
    echo "  $0 all              # Run complete pipeline"
    echo "  $0 performance      # Run only performance benchmark"
    echo "  $0 security         # Run only security audit"
    echo "  $0 --status         # Show current status"
    echo "  $0 --clean          # Clean artifacts"
    echo ""
    echo "Pipeline Stages:"
    echo "1. Performance: Benchmarks app metrics against targets"
    echo "2. Tests: Runs unit and performance tests"
    echo "3. Coverage: Generates code coverage reports"
    echo "4. Security: Performs comprehensive security audit"
}

# Validate environment
validate_environment() {
    echo "🔍 Validating Environment..."
    echo "=========================="

    # Check if we're in the right directory
    if [ ! -d "Lopan" ]; then
        error "Not in Lopan project root directory"
        exit 1
    fi

    # Check if automation scripts exist
    if [ ! -d "$AUTOMATION_DIR" ]; then
        error "Automation directory not found: $AUTOMATION_DIR"
        exit 1
    fi

    # Check Xcode availability
    if ! command -v xcodebuild &> /dev/null; then
        error "Xcode command line tools not found"
        exit 1
    fi

    success "Environment validation passed"
}

# Main execution logic
main() {
    case "${1:-all}" in
        "performance")
            validate_environment
            run_performance_benchmark
            ;;
        "tests")
            validate_environment
            run_test_suite
            ;;
        "coverage")
            validate_environment
            run_coverage_analysis
            ;;
        "security")
            validate_environment
            run_security_audit
            ;;
        "all")
            validate_environment
            run_complete_pipeline
            ;;
        "-s"|"--status")
            show_status
            ;;
        "-c"|"--clean")
            clean_artifacts
            ;;
        "-h"|"--help")
            show_help
            ;;
        *)
            error "Unknown stage or option: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"