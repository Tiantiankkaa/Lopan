//
//  String+Pinyin.swift
//  Lopan
//
//  Created by Claude Code on 2025/10/02.
//

import Foundation

extension String {
    /// Converts a Chinese string to its pinyin representation and returns the first letter
    /// Uses CFStringTransform for accurate Chinese character to pinyin conversion
    ///
    /// Examples:
    /// - "张三" → "Z" (from Zhāng Sān)
    /// - "李明" → "L" (from Lǐ Míng)
    /// - "王芳" → "W" (from Wáng Fāng)
    /// - "Alice" → "A" (English names pass through)
    /// - "123客户" → "#" (numbers/symbols)
    ///
    /// - Returns: A single uppercase letter (A-Z) or "#" for non-letter characters
    func pinyinInitial() -> String {
        // Handle empty strings
        guard !self.isEmpty else { return "#" }

        // Create mutable string for transformation
        let mutableString = NSMutableString(string: self)

        // Step 1: Transform Chinese characters to Latin (pinyin with tone marks)
        // "张三" → "zhāng sān"
        CFStringTransform(mutableString, nil, kCFStringTransformToLatin, false)

        // Step 2: Strip diacritics (tone marks) to get clean pinyin
        // "zhāng sān" → "zhang san"
        CFStringTransform(mutableString, nil, kCFStringTransformStripDiacritics, false)

        // Get the converted pinyin string
        let pinyin = String(mutableString)

        // Extract first character and validate it's a letter
        if let firstChar = pinyin.uppercased().first, firstChar.isLetter, firstChar.isASCII {
            return String(firstChar)
        }

        // Fallback for numbers, symbols, or empty results
        return "#"
    }

    /// Full pinyin conversion for display purposes
    /// Converts Chinese characters to their full pinyin representation
    ///
    /// Example: "张三" → "zhang san"
    ///
    /// - Returns: Full pinyin string
    func toPinyin() -> String {
        let mutableString = NSMutableString(string: self)
        CFStringTransform(mutableString, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutableString, nil, kCFStringTransformStripDiacritics, false)
        return String(mutableString)
    }

    /// Checks if the first character is a Chinese character
    var startsWithChineseCharacter: Bool {
        guard let firstChar = self.first else { return false }
        let scalar = firstChar.unicodeScalars.first!
        // CJK Unified Ideographs range
        return (0x4E00...0x9FFF).contains(scalar.value)
    }
}

// MARK: - Previews & Tests

#if DEBUG
extension String {
    /// Test cases for pinyin conversion
    static let pinyinTestCases: [(input: String, expected: String)] = [
        // Chinese surnames (common)
        ("张三", "Z"),
        ("李明", "L"),
        ("王芳", "W"),
        ("刘德华", "L"),
        ("陈冠希", "C"),
        ("黄晓明", "H"),
        ("赵薇", "Z"),
        ("孙悟空", "S"),
        ("周杰伦", "Z"),
        ("吴京", "W"),

        // English names
        ("Alice", "A"),
        ("Bob", "B"),
        ("Charlie", "C"),

        // Mixed
        ("Alice Wang", "A"),
        ("张 Alice", "Z"),

        // Edge cases
        ("123", "#"),
        ("@#$%", "#"),
        ("", "#"),
        ("   ", "#"),

        // Multiple Chinese characters
        ("北京市朝阳区", "B"),
        ("上海浦东新区", "S"),
    ]

    /// Run test validation
    static func validatePinyinConversion() {
        print("🧪 Running Pinyin Conversion Tests...")
        var passed = 0
        var failed = 0

        for test in pinyinTestCases {
            let result = test.input.pinyinInitial()
            if result == test.expected {
                passed += 1
                print("✅ '\(test.input)' → '\(result)' (expected '\(test.expected)')")
            } else {
                failed += 1
                print("❌ '\(test.input)' → '\(result)' (expected '\(test.expected)')")
            }
        }

        print("\n📊 Test Results: \(passed) passed, \(failed) failed")
    }
}
#endif
