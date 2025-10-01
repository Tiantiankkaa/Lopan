#!/bin/bash
# setup-fastlane.sh
# Fastlane Setup Script for Lopan iOS App Deployment
# Phase 6: Production Deployment & App Store Launch

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project configuration
PROJECT_NAME="Lopan"
BUNDLE_ID="com.lopanng.Lopan"
SCHEME_NAME="Lopan"
WORKSPACE_NAME="Lopan.xcworkspace"
PROJECT_PATH="/Users/bobo/Library/Mobile Documents/com~apple~CloudDocs/Desktop/桌面 - Bobo的Mac mini/Lopan"

echo -e "${BLUE}🚀 Setting up Fastlane for Lopan deployment...${NC}"
echo "Project: $PROJECT_NAME"
echo "Bundle ID: $BUNDLE_ID"
echo "Path: $PROJECT_PATH"
echo ""

# Check prerequisites
echo -e "${YELLOW}📋 Checking prerequisites...${NC}"

# Check if we're in the right directory
if [ ! -f "Lopan.xcodeproj/project.pbxproj" ]; then
    echo -e "${RED}❌ Error: Not in Lopan project directory${NC}"
    echo "Please run this script from the Lopan project root directory"
    exit 1
fi

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}❌ Error: Xcode not found${NC}"
    echo "Please install Xcode from the App Store"
    exit 1
fi

# Check Ruby version
if ! command -v ruby &> /dev/null; then
    echo -e "${RED}❌ Error: Ruby not found${NC}"
    echo "Please install Ruby (recommended: rbenv or rvm)"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites check passed${NC}"
echo ""

# Install fastlane
echo -e "${YELLOW}💎 Installing Fastlane...${NC}"

if ! command -v fastlane &> /dev/null; then
    # Check if bundler is available for gem management
    if command -v bundle &> /dev/null && [ -f "Gemfile" ]; then
        echo "Installing fastlane via Bundler..."
        bundle install
    else
        echo "Installing fastlane via gem..."
        sudo gem install fastlane
    fi
else
    echo "Fastlane already installed: $(fastlane --version | head -n 1)"
fi

echo -e "${GREEN}✅ Fastlane installation complete${NC}"
echo ""

# Initialize Fastlane (if not already initialized)
echo -e "${YELLOW}🔧 Configuring Fastlane...${NC}"

if [ ! -d "fastlane" ]; then
    echo "Initializing Fastlane..."
    fastlane init
else
    echo "Fastlane directory already exists"
fi

# Create Fastfile with Lopan-specific configuration
echo "Creating Fastfile for Lopan deployment..."

cat > fastlane/Fastfile << 'EOF'
# Fastfile for Lopan iOS App
# Phase 6: Production Deployment & App Store Launch

default_platform(:ios)

platform :ios do
  # Environment setup
  before_all do
    ensure_git_status_clean
    git_pull

    # Verify Phase 4 components are present
    verify_phase4_components
  end

  # Private lanes
  private_lane :verify_phase4_components do
    UI.message "🔍 Verifying Phase 4 performance components..."

    required_components = [
      "Lopan/Services/LopanPerformanceProfiler.swift",
      "Lopan/Services/LopanMemoryManager.swift",
      "Lopan/Services/LopanScrollOptimizer.swift",
      "Lopan/Services/LopanProductionMonitoring.swift",
      "LopanTests/LopanTestingFramework.swift",
      "LopanTests/PerformanceTests.swift"
    ]

    missing_components = []
    required_components.each do |component|
      unless File.exist?(component)
        missing_components << component
      end
    end

    unless missing_components.empty?
      UI.user_error!("❌ Missing Phase 4 components:\n#{missing_components.join("\n")}")
    end

    UI.success "✅ All Phase 4 components verified"
  end

  private_lane :validate_build_performance do
    UI.message "⚡ Validating build performance..."

    # Run performance tests to ensure Phase 4 targets are met
    scan(
      scheme: "Lopan",
      testplan: "PerformanceTests",
      output_style: "basic",
      suppress_xcode_output: true
    )

    UI.success "✅ Performance validation passed"
  end

  private_lane :increment_version_safely do
    # Increment build number
    increment_build_number(
      build_number: latest_testflight_build_number + 1
    )

    # Get current version info
    version_number = get_version_number
    build_number = get_build_number

    UI.message "📊 Version: #{version_number} (#{build_number})"

    # Commit version changes
    commit_version_bump(
      message: "Version bump to #{version_number} (#{build_number})",
      xcodeproj: "Lopan.xcodeproj"
    )
  end

  private_lane :build_app_with_validation do
    # Clean build directory
    clear_derived_data

    # Build the app with release configuration
    gym(
      scheme: "Lopan",
      configuration: "Release",
      export_method: "app-store",
      export_options: {
        method: "app-store",
        provisioningProfiles: {
          "com.lopanng.Lopan" => "Lopan Distribution"
        },
        signingStyle: "manual",
        stripSwiftSymbols: true,
        uploadBitcode: false,
        uploadSymbols: true,
        compileBitcode: false
      },
      output_directory: "./build",
      output_name: "Lopan.ipa"
    )

    UI.success "✅ Build completed successfully"
  end

  # Public lanes

  desc "🧪 Run tests with Phase 4 performance validation"
  lane :test do
    # Run unit tests
    scan(
      scheme: "Lopan",
      clean: true,
      output_style: "basic"
    )

    # Validate Phase 4 performance targets
    validate_build_performance

    UI.success "🎉 All tests passed with performance validation"
  end

  desc "🚀 Deploy to TestFlight"
  lane :beta do
    # Verify Phase 4 components
    verify_phase4_components

    # Version management
    increment_version_safely

    # Run tests before deployment
    test

    # Build the app
    build_app_with_validation

    # Upload to TestFlight
    pilot(
      skip_waiting_for_build_processing: false,
      changelog: "Latest improvements based on Phase 4 performance optimization:\n• 60fps scrolling with large datasets\n• <150MB memory usage\n• Enhanced user experience with micro-interactions\n• Production-ready monitoring and analytics",
      distribute_external: false,  # Internal testing first
      groups: ["Internal Testing"]
    )

    # Tag the release
    add_git_tag(
      tag: "testflight-#{get_version_number}-#{get_build_number}"
    )

    push_git_tags

    # Notify team
    slack(
      message: "🎉 Lopan v#{get_version_number} (#{get_build_number}) successfully deployed to TestFlight!\n• Phase 4 performance targets maintained\n• All tests passing\n• Ready for internal testing",
      channel: "#ios-deployment",
      success: true
    ) if ENV["SLACK_URL"]

    UI.success "🚀 Successfully deployed to TestFlight!"
  end

  desc "📱 Deploy to App Store"
  lane :release do
    # Comprehensive pre-release validation
    verify_phase4_components

    # Capture screenshots for App Store
    capture_screenshots(
      scheme: "Lopan",
      output_directory: "./screenshots"
    )

    # Version management for release
    increment_version_number(bump_type: "patch")
    increment_version_safely

    # Full test suite
    test

    # Build for App Store
    build_app_with_validation

    # Upload to App Store Connect
    deliver(
      submit_for_review: true,
      automatic_release: false,
      force: true,
      metadata_path: "./fastlane/metadata",
      screenshots_path: "./screenshots",
      skip_binary_upload: false,
      skip_screenshots: false,
      skip_metadata: false,
      submission_information: {
        add_id_info_uses_idfa: false,
        add_id_info_serves_ads: false,
        add_id_info_tracks_install: false,
        add_id_info_tracks_action: false,
        export_compliance_platform: "ios",
        export_compliance_uses_encryption: true,
        export_compliance_encryption_updated: false,
        export_compliance_compliance_required: false,
        export_compliance_contains_third_party_cryptography: false,
        export_compliance_contains_proprietary_cryptography: false,
        export_compliance_available_on_french_store: true
      }
    )

    # Tag the release
    add_git_tag(
      tag: "release-v#{get_version_number}"
    )

    push_git_tags

    # Notify team
    slack(
      message: "🚀 Lopan v#{get_version_number} submitted to App Store!\n• Phase 4 performance excellence delivered\n• All quality gates passed\n• Ready for review",
      channel: "#ios-releases",
      success: true
    ) if ENV["SLACK_URL"]

    UI.success "🎉 Successfully submitted to App Store!"
  end

  desc "📸 Generate screenshots for App Store"
  lane :screenshots do
    capture_screenshots(
      scheme: "Lopan",
      output_directory: "./screenshots",
      clear_previous_screenshots: true,
      override_status_bar: true,
      localize_simulator: true
    )

    UI.success "📸 Screenshots generated successfully"
  end

  desc "🔧 Setup code signing"
  lane :certificates do
    match(
      type: "development",
      readonly: false,
      force_for_new_devices: true
    )

    match(
      type: "appstore",
      readonly: false
    )

    UI.success "🔧 Code signing setup complete"
  end

  desc "🧹 Clean build environment"
  lane :clean do
    clear_derived_data
    reset_git_repo(force: true, skip_clean: true)

    UI.success "🧹 Build environment cleaned"
  end

  # Error handling
  error do |lane, exception|
    slack(
      message: "❌ Lopan deployment failed in lane '#{lane}': #{exception.message}",
      channel: "#ios-deployment",
      success: false
    ) if ENV["SLACK_URL"]

    UI.error "Deployment failed: #{exception.message}"
  end
end
EOF

echo -e "${GREEN}✅ Fastfile created${NC}"

# Create Appfile
echo "Creating Appfile..."

cat > fastlane/Appfile << EOF
# Appfile for Lopan iOS App

app_identifier("$BUNDLE_ID")
apple_id(ENV["APPLE_ID"])
team_id(ENV["TEAM_ID"])

# Uncomment if you need specific iTunes Connect team
# itc_team_id(ENV["ITC_TEAM_ID"])

# Uncomment if you need specific Developer Portal team
# team_name("Your Team Name")
EOF

echo -e "${GREEN}✅ Appfile created${NC}"

# Create Matchfile for certificate management
echo "Creating Matchfile..."

cat > fastlane/Matchfile << EOF
# Matchfile for Lopan iOS App Certificate Management

git_url(ENV["MATCH_GIT_URL"])
storage_mode("git")
type("development")

app_identifier(["$BUNDLE_ID"])
username(ENV["APPLE_ID"])
team_id(ENV["TEAM_ID"])

# Uncomment if using a different storage location
# git_branch("master")
# git_full_name("Your Name")
# git_user_email("your.email@example.com")
EOF

echo -e "${GREEN}✅ Matchfile created${NC}"

# Create environment template
echo "Creating environment configuration template..."

cat > fastlane/.env.template << EOF
# Environment Configuration for Lopan Deployment
# Copy this file to .env and fill in your values
# DO NOT commit .env to version control

# Apple Developer Account
APPLE_ID="your-apple-id@example.com"
TEAM_ID="YOUR_TEAM_ID"
ITC_TEAM_ID="YOUR_ITC_TEAM_ID"

# Certificate Management (Match)
MATCH_GIT_URL="https://github.com/your-org/certificates.git"
MATCH_PASSWORD="your-match-password"

# App Store Connect API (Optional)
APP_STORE_CONNECT_API_KEY_ID="YOUR_API_KEY_ID"
APP_STORE_CONNECT_ISSUER_ID="YOUR_ISSUER_ID"
APP_STORE_CONNECT_API_KEY_PATH="./AuthKey_YOUR_API_KEY_ID.p8"

# Slack Integration (Optional)
SLACK_URL="https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"

# CI/CD Configuration
FASTLANE_USER="your-apple-id@example.com"
FASTLANE_PASSWORD="app-specific-password"
FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD="app-specific-password"
FASTLANE_SESSION="your-session-token"

# Build Configuration
GYM_SCHEME="Lopan"
GYM_CONFIGURATION="Release"
SCAN_SCHEME="Lopan"
EOF

echo -e "${GREEN}✅ Environment template created${NC}"

# Create GitHub Actions integration
echo "Creating GitHub Actions integration..."

mkdir -p .github/workflows

cat > .github/workflows/ios-deployment.yml << 'EOF'
name: iOS Deployment Pipeline
# Lopan Phase 6: Production Deployment

on:
  push:
    branches: [ main ]
    tags: [ 'v*' ]
  pull_request:
    branches: [ main ]

env:
  DEVELOPER_DIR: /Applications/Xcode.app/Contents/Developer

jobs:
  test:
    name: Test & Validate
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.0
          bundler-cache: true

      - name: Install dependencies
        run: bundle install

      - name: Run tests with Phase 4 validation
        run: bundle exec fastlane test

      - name: Upload test results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: test-results
          path: fastlane/test_output/

  deploy_testflight:
    name: Deploy to TestFlight
    runs-on: macos-14
    needs: test
    if: github.ref == 'refs/heads/main'

    steps:
      - uses: actions/checkout@v4

      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.0
          bundler-cache: true

      - name: Install dependencies
        run: bundle install

      - name: Setup certificates
        run: bundle exec fastlane certificates
        env:
          MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
          MATCH_GIT_URL: ${{ secrets.MATCH_GIT_URL }}
          APPLE_ID: ${{ secrets.APPLE_ID }}
          TEAM_ID: ${{ secrets.TEAM_ID }}

      - name: Deploy to TestFlight
        run: bundle exec fastlane beta
        env:
          APPLE_ID: ${{ secrets.APPLE_ID }}
          TEAM_ID: ${{ secrets.TEAM_ID }}
          FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD: ${{ secrets.FASTLANE_PASSWORD }}
          SLACK_URL: ${{ secrets.SLACK_URL }}

  deploy_app_store:
    name: Deploy to App Store
    runs-on: macos-14
    needs: test
    if: startsWith(github.ref, 'refs/tags/v')

    steps:
      - uses: actions/checkout@v4

      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.0
          bundler-cache: true

      - name: Install dependencies
        run: bundle install

      - name: Setup certificates
        run: bundle exec fastlane certificates
        env:
          MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
          MATCH_GIT_URL: ${{ secrets.MATCH_GIT_URL }}
          APPLE_ID: ${{ secrets.APPLE_ID }}
          TEAM_ID: ${{ secrets.TEAM_ID }}

      - name: Deploy to App Store
        run: bundle exec fastlane release
        env:
          APPLE_ID: ${{ secrets.APPLE_ID }}
          TEAM_ID: ${{ secrets.TEAM_ID }}
          FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD: ${{ secrets.FASTLANE_PASSWORD }}
          SLACK_URL: ${{ secrets.SLACK_URL }}
EOF

echo -e "${GREEN}✅ GitHub Actions workflow created${NC}"

# Create Gemfile for dependency management
echo "Creating Gemfile..."

cat > Gemfile << EOF
source "https://rubygems.org"

gem "fastlane"
gem "cocoapods", "~> 1.12"

plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')
eval_gemfile(plugins_path) if File.exist?(plugins_path)
EOF

echo -e "${GREEN}✅ Gemfile created${NC}"

# Create gitignore entries for fastlane
echo "Updating .gitignore for fastlane..."

cat >> .gitignore << EOF

# Fastlane
fastlane/report.xml
fastlane/Preview.html
fastlane/screenshots/**/*.png
fastlane/test_output
fastlane/.env
fastlane/.env.*

# Certificates
*.p12
*.mobileprovision
AuthKey_*.p8
EOF

echo -e "${GREEN}✅ .gitignore updated${NC}"

# Validate setup
echo -e "${YELLOW}🔍 Validating fastlane setup...${NC}"

if bundle exec fastlane --version &> /dev/null; then
    echo -e "${GREEN}✅ Fastlane setup validation passed${NC}"
else
    echo -e "${RED}❌ Fastlane setup validation failed${NC}"
    exit 1
fi

# Final instructions
echo ""
echo -e "${BLUE}🎉 Fastlane setup complete for Lopan!${NC}"
echo ""
echo -e "${YELLOW}📋 Next steps:${NC}"
echo "1. Copy fastlane/.env.template to fastlane/.env and fill in your values"
echo "2. Set up your certificate repository for Match"
echo "3. Configure GitHub Actions secrets for CI/CD"
echo "4. Run 'bundle exec fastlane certificates' to set up code signing"
echo "5. Test with 'bundle exec fastlane test' to validate Phase 4 components"
echo ""
echo -e "${YELLOW}🚀 Available lanes:${NC}"
echo "• fastlane test - Run tests with Phase 4 performance validation"
echo "• fastlane beta - Deploy to TestFlight"
echo "• fastlane release - Deploy to App Store"
echo "• fastlane screenshots - Generate App Store screenshots"
echo "• fastlane certificates - Set up code signing"
echo ""
echo -e "${GREEN}✅ Ready for Phase 6 deployment! 🚀${NC}"