#!/bin/bash

# iOS 26 UI/UX Navigation Migration Script
# Migrates remaining NavigationView instances to NavigationStack

set -e

PROJECT_ROOT="/Users/bobo/Library/Mobile Documents/com~apple~CloudDocs/Desktop/桌面 - Bobo的Mac mini/Lopan"
VIEWS_DIR="$PROJECT_ROOT/Lopan/Views"

echo "🚀 Starting iOS 26 Navigation Migration..."
echo "📁 Project Root: $PROJECT_ROOT"

# Count NavigationView instances before migration
echo "📊 Counting NavigationView instances before migration..."
BEFORE_COUNT=$(find "$VIEWS_DIR" -name "*.swift" -exec grep -l "NavigationView" {} \; | wc -l)
echo "📋 Found $BEFORE_COUNT files with NavigationView"

# High-priority files to migrate first
HIGH_PRIORITY_FILES=(
    "$VIEWS_DIR/Administrator/UserManagementView.swift"
    "$VIEWS_DIR/Administrator/SystemConfigurationView.swift"
    "$VIEWS_DIR/Administrator/PermissionManagementView.swift"
    "$VIEWS_DIR/Salesperson/CustomerManagementView.swift"
    "$VIEWS_DIR/Salesperson/ProductManagementView.swift"
    "$VIEWS_DIR/Salesperson/CustomerDetailView.swift"
)

echo "🔧 Migrating high-priority files..."
for file in "${HIGH_PRIORITY_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        echo "  ⏳ Migrating: $(basename "$file")"
        # Replace NavigationView with NavigationStack
        sed -i '' 's/NavigationView {/NavigationStack {/g' "$file"
        echo "  ✅ Completed: $(basename "$file")"
    else
        echo "  ⚠️  File not found: $(basename "$file")"
    fi
done

# Migrate remaining files in batch
echo "🔄 Migrating remaining files..."
find "$VIEWS_DIR" -name "*.swift" -exec grep -l "NavigationView" {} \; | while read -r file; do
    echo "  ⏳ Migrating: $(basename "$file")"
    sed -i '' 's/NavigationView {/NavigationStack {/g' "$file"
    echo "  ✅ Completed: $(basename "$file")"
done

# Count NavigationView instances after migration
echo "📊 Counting NavigationView instances after migration..."
AFTER_COUNT=$(find "$VIEWS_DIR" -name "*.swift" -exec grep -l "NavigationView" {} \; | wc -l)
echo "📋 Remaining files with NavigationView: $AFTER_COUNT"

# Verify NavigationStack adoption
STACK_COUNT=$(find "$VIEWS_DIR" -name "*.swift" -exec grep -l "NavigationStack" {} \; | wc -l)
echo "📈 Files now using NavigationStack: $STACK_COUNT"

echo ""
echo "📋 Migration Summary:"
echo "  - Files migrated: $((BEFORE_COUNT - AFTER_COUNT))"
echo "  - Remaining NavigationView files: $AFTER_COUNT"
echo "  - Total NavigationStack adoptions: $STACK_COUNT"

if [[ $AFTER_COUNT -eq 0 ]]; then
    echo "🎉 Migration complete! All NavigationView instances have been migrated to NavigationStack."
else
    echo "⚠️  Migration incomplete. $AFTER_COUNT files still contain NavigationView."
    echo "📋 Remaining files:"
    find "$VIEWS_DIR" -name "*.swift" -exec grep -l "NavigationView" {} \;
fi

echo ""
echo "🔍 Next steps:"
echo "  1. Run build test: xcodebuild -scheme Lopan build"
echo "  2. Test key user flows manually"
echo "  3. Update Phase 1 audit documentation"
echo "  4. Commit changes with conventional commit message"

echo "✨ Navigation migration script completed!"