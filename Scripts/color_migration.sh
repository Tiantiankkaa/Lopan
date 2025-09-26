#!/bin/bash

# Color Migration Script for Lopan iOS App
# Finds and reports hardcoded colors in Swift files

echo "🎨 Lopan Color Migration Tool"
echo "=============================="

# Set the project root
PROJECT_ROOT="/Users/bobo/Library/Mobile Documents/com~apple~CloudDocs/Desktop/桌面 - Bobo的Mac mini/Lopan"
cd "$PROJECT_ROOT"

# Find all hardcoded colors (excluding the LopanColors.swift file itself and tests)
echo "📊 Finding hardcoded colors..."

# Create output file
OUTPUT_FILE="Scripts/hardcoded_colors_report.txt"
echo "Hardcoded Colors Report - $(date)" > "$OUTPUT_FILE"
echo "=======================================" >> "$OUTPUT_FILE"

# Search patterns for hardcoded colors
PATTERNS="\.red\b|\.blue\b|\.green\b|\.orange\b|\.purple\b|\.yellow\b|\.pink\b|\.cyan\b|\.indigo\b|\.gray\b"

# Find files (excluding certain directories and files)
echo "🔍 Scanning Swift files..."
rg "$PATTERNS" --type swift \
   --exclude "LopanColors.swift" \
   --exclude "*Test*" \
   --exclude "Snapshot*" \
   --exclude "Preview*" \
   -n > "$OUTPUT_FILE.raw"

# Count total occurrences
TOTAL_COUNT=$(wc -l < "$OUTPUT_FILE.raw" 2>/dev/null || echo "0")

echo "📈 Found $TOTAL_COUNT hardcoded color instances" | tee -a "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Group by file for easier processing
echo "📁 Grouping by file:" >> "$OUTPUT_FILE"
echo "===================" >> "$OUTPUT_FILE"

if [ -f "$OUTPUT_FILE.raw" ] && [ -s "$OUTPUT_FILE.raw" ]; then
    # Sort by filename and count occurrences per file
    cat "$OUTPUT_FILE.raw" | cut -d: -f1 | sort | uniq -c | sort -nr >> "$OUTPUT_FILE"

    echo "" >> "$OUTPUT_FILE"
    echo "🔧 Detailed breakdown:" >> "$OUTPUT_FILE"
    echo "======================" >> "$OUTPUT_FILE"
    cat "$OUTPUT_FILE.raw" >> "$OUTPUT_FILE"

    echo ""
    echo "📄 Most problematic files:"
    cat "$OUTPUT_FILE.raw" | cut -d: -f1 | sort | uniq -c | sort -nr | head -10
else
    echo "✅ No hardcoded colors found!" | tee -a "$OUTPUT_FILE"
fi

# Generate migration suggestions
echo "" >> "$OUTPUT_FILE"
echo "🛠️  Suggested Replacements:" >> "$OUTPUT_FILE"
echo "============================" >> "$OUTPUT_FILE"
cat << 'EOF' >> "$OUTPUT_FILE"

Common Color Replacements:
.red → LopanColors.error
.green → LopanColors.success
.blue → LopanColors.primary
.orange → LopanColors.warning
.gray → LopanColors.secondary
.purple → LopanColors.premium
.yellow → LopanColors.warning (or create specific yellow semantic)
.pink → LopanColors.accent (or create specific semantic)
.cyan → LopanColors.info (or create specific semantic)
.indigo → LopanColors.roleWorkshopTechnician

Context-specific Replacements:
Status indicators → LopanColors.statusPending, statusCompleted, etc.
Role badges → LopanColors.roleAdministrator, roleSalesperson, etc.
Background colors → LopanColors.background, surface, surfaceElevated
Text colors → LopanColors.textPrimary, textSecondary
Border colors → Consider LopanColors.border (if needed)

EOF

# Create a priority list for manual review
echo "🎯 Priority Files (Top 10):" >> "$OUTPUT_FILE"
echo "============================" >> "$OUTPUT_FILE"

if [ -f "$OUTPUT_FILE.raw" ] && [ -s "$OUTPUT_FILE.raw" ]; then
    cat "$OUTPUT_FILE.raw" | cut -d: -f1 | sort | uniq -c | sort -nr | head -10 | while read count file; do
        echo "$count instances: $file" >> "$OUTPUT_FILE"
    done
fi

# Clean up temporary file
rm -f "$OUTPUT_FILE.raw"

echo ""
echo "✅ Color migration analysis complete!"
echo "📊 Report saved to: $OUTPUT_FILE"
echo ""
echo "Next steps:"
echo "1. Review the report file"
echo "2. Start with the highest-count files"
echo "3. Use find/replace with semantic color tokens"
echo "4. Test each change in light/dark mode"
echo "5. Run build verification after each batch"