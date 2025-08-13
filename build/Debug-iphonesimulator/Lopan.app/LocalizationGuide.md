# Localization Implementation Guide

## Overview
This guide explains how to implement localization in the Lopan app to support multiple languages based on the user's system language.

## Files Created

### 1. Localization Files
- `Lopan/en.lproj/Localizable.strings` - English translations
- `Lopan/zh-Hans.lproj/Localizable.strings` - Chinese translations

### 2. Helper Files
- `Lopan/Utils/LocalizationHelper.swift` - String extension for easy localization
- `Lopan/Info.plist` - App configuration with supported languages

## How to Use Localization

### 1. Basic String Localization
Replace hardcoded strings with localized versions:

```swift
// Before
Text("产品管理")

// After
Text("产品管理".localized)
```

### 2. String with Parameters
For strings with dynamic values:

```swift
// Before
Text("确定要删除选中的 \(count) 个产品吗？")

// After
Text("确定要删除选中的 %d 个产品吗？此操作不可撤销。".localized(with: count))
```

### 3. Navigation Titles
```swift
// Before
.navigationTitle("产品管理")

// After
.navigationTitle("产品管理".localized)
```

### 4. Alert Messages
```swift
// Before
.alert("确认删除", isPresented: $showingAlert) {
    Button("取消", role: .cancel) { }
    Button("删除", role: .destructive) { }
}

// After
.alert("确认删除".localized, isPresented: $showingAlert) {
    Button("取消".localized, role: .cancel) { }
    Button("删除".localized, role: .destructive) { }
}
```

### 5. TextField Placeholders
```swift
// Before
TextField("搜索产品名称", text: $searchText)

// After
TextField("搜索产品名称、颜色或尺寸".localized, text: $searchText)
```

## Files That Need to be Updated

### Priority 1 (Main Views)
1. `Lopan/Views/Salesperson/ProductManagementView.swift` ✅ (Example updated)
2. `Lopan/Views/Salesperson/CustomerManagementView.swift`
3. `Lopan/Views/Salesperson/CustomerOutOfStockListView.swift`
4. `Lopan/Views/Salesperson/SalespersonDashboardView.swift`

### Priority 2 (Detail Views)
1. `Lopan/Views/Salesperson/ProductDetailView.swift`
2. `Lopan/Views/Salesperson/CustomerDetailView.swift`
3. `Lopan/Views/Salesperson/CustomerOutOfStockDetailView.swift`
4. `Lopan/Views/Salesperson/EditProductView.swift`
5. `Lopan/Views/Salesperson/EditCustomerView.swift`
6. `Lopan/Views/Salesperson/EditCustomerOutOfStockView.swift`

### Priority 3 (Component Views)
1. `Lopan/Views/Components/AddProductView.swift`
2. `Lopan/Views/Components/AddCustomerView.swift`
3. `Lopan/Views/Components/ExcelImportView.swift`
4. `Lopan/Views/Components/ExcelExportView.swift`
5. `Lopan/Views/Components/ShareSheet.swift`

### Priority 4 (Models and Services)
1. `Lopan/Models/Product.swift` (enum values)
2. `Lopan/Models/CustomerOutOfStock.swift` (enum values)
3. `Lopan/Services/ExcelService.swift` (error messages)

## Common Patterns to Replace

### 1. Navigation Titles
```swift
// Find all instances of:
.navigationTitle("中文标题")

// Replace with:
.navigationTitle("中文标题".localized)
```

### 2. Button Labels
```swift
// Find all instances of:
Label("中文按钮", systemImage: "icon")

// Replace with:
Label("中文按钮".localized, systemImage: "icon")
```

### 3. Alert Messages
```swift
// Find all instances of:
.alert("中文标题", isPresented: $showingAlert) {
    Button("中文按钮", role: .cancel) { }
}

// Replace with:
.alert("中文标题".localized, isPresented: $showingAlert) {
    Button("中文按钮".localized, role: .cancel) { }
}
```

### 4. Text with Parameters
```swift
// Find all instances of:
Text("包含 \(variable) 的文本")

// Replace with:
Text("包含 %d 的文本".localized(with: variable))
```

## Testing Localization

### 1. Simulator Testing
1. Open iOS Simulator
2. Go to Settings > General > Language & Region
3. Change the language to English
4. Run the app to see English translations

### 2. Device Testing
1. On your device, go to Settings > General > Language & Region
2. Add English as a language
3. Set English as the primary language
4. Run the app to see English translations

## Adding New Languages

To add support for additional languages:

1. Create a new `.lproj` folder (e.g., `ja.lproj` for Japanese)
2. Create `Localizable.strings` file in the new folder
3. Add translations for all strings
4. Update `Info.plist` to include the new language code

## Best Practices

1. **Use descriptive keys**: Make string keys descriptive and meaningful
2. **Group related strings**: Use comments to group related strings in `.strings` files
3. **Test thoroughly**: Test with different languages and text lengths
4. **Consider text expansion**: Some languages have longer text than others
5. **Use proper formatting**: Use `%d`, `%@` for parameters in localized strings

## Common Issues and Solutions

### 1. Missing Localization
If a string doesn't appear localized:
- Check that the key exists in both `.strings` files
- Verify the key spelling matches exactly
- Ensure the `.localized` extension is used

### 2. Parameter Issues
If parameters don't work:
- Use `%d` for integers, `%@` for strings
- Use `.localized(with: parameter)` syntax
- Check parameter order matches the string format

### 3. Build Issues
If localization doesn't work after build:
- Clean build folder (Cmd+Shift+K)
- Rebuild the project
- Check that `.strings` files are included in the target

## Example: Complete View Update

Here's an example of how to update a complete view:

```swift
// Before
struct ProductManagementView: View {
    var body: some View {
        VStack {
            Text("产品管理")
            Button("添加产品") {
                // action
            }
            .alert("确认删除", isPresented: $showingAlert) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) { }
            }
        }
        .navigationTitle("产品管理")
    }
}

// After
struct ProductManagementView: View {
    var body: some View {
        VStack {
            Text("产品管理".localized)
            Button("添加产品".localized) {
                // action
            }
            .alert("确认删除".localized, isPresented: $showingAlert) {
                Button("取消".localized, role: .cancel) { }
                Button("删除".localized, role: .destructive) { }
            }
        }
        .navigationTitle("产品管理".localized)
    }
}
```

This approach ensures that the app will automatically display in the user's preferred language based on their system settings. 