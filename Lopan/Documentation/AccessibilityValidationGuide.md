# 可访问性验证指南

本指南提供了全面的可访问性测试和验证方法，确保Lopan应用符合Apple可访问性指南和WCAG标准。

## 快速检查清单

### ✅ 基础合规性检查

- [ ] **触摸目标**: 所有交互元素最小44x44pt
- [ ] **VoiceOver标签**: 所有UI元素有意义的标签
- [ ] **颜色对比度**: 文本与背景对比度≥4.5:1 (WCAG AA)
- [ ] **Dynamic Type**: 支持所有系统字体大小
- [ ] **深色模式**: 所有颜色在深色模式下正确显示

### ✅ 高级功能检查

- [ ] **Switch Control**: 所有功能可通过Switch Control访问
- [ ] **Voice Control**: 语音控制可识别所有元素
- [ ] **减动画**: 尊重系统减动画设置
- [ ] **高对比度**: 支持增强对比度模式

## 详细测试步骤

### 1. VoiceOver测试

#### 启用VoiceOver
```
设置 > 辅助功能 > VoiceOver > 开启
或使用三指三击快捷方式
```

#### 测试要点
1. **导航测试**
   - 左右轻扫可正确导航所有元素
   - 双指向上/向下轻扫切换转子设置
   - 转子包含"标题"、"按钮"、"文本字段"等选项

2. **标签准确性**
   - 每个元素有描述性标签
   - 避免重复或无意义的标签
   - 状态信息清晰传达

3. **操作可用性**
   - 所有按钮可通过双击激活
   - 表单控件可正确操作
   - 手势操作有语音替代方案

#### VoiceOver测试脚本
```swift
// 开发期间的VoiceOver测试辅助
#if DEBUG
extension View {
    func voiceOverTest(_ identifier: String) -> some View {
        self.accessibilityIdentifier(identifier)
            .accessibilityHint("测试元素: \(identifier)")
    }
}
#endif
```

### 2. Dynamic Type测试

#### 测试步骤
1. 打开 设置 > 显示与亮度 > 文字大小
2. 拖动滑块到最大
3. 启用"更大字体" > 选择最大尺寸
4. 返回应用验证布局

#### 验证要点
- 文本不被截断
- 界面布局适应大字体
- 滚动内容保持可访问
- 按钮文本完全显示

### 3. 颜色和对比度测试

#### 对比度要求
- **正常文本**: 4.5:1 对比度 (WCAG AA)
- **大文本**: 3:1 对比度 (≥18pt或14pt粗体)
- **图标和按钮**: 3:1 对比度

#### 测试工具
使用Xcode的Accessibility Inspector或在线工具：
- WebAIM对比度检查器
- Colour Contrast Analyser

#### 深色模式测试
```swift
// 测试深色模式颜色
struct ColorContrastTest: View {
    var body: some View {
        VStack {
            Text("正常文本").foregroundColor(.primary)
            Text("次要文本").foregroundColor(.secondary)
            Text("错误状态").foregroundColor(.red)
            Text("成功状态").foregroundColor(.green)
        }
        .background(LopanColors.background)
    }
}
```

### 4. 触摸目标测试

#### 验证方法
1. 使用Accessibility Inspector
2. 选择"Audit"标签
3. 运行"Touch Target Size"审计

#### 常见问题修复
```swift
// ❌ 触摸目标太小
Button("×") {
    // action
}
.font(.caption)

// ✅ 符合HIG的触摸目标
Button("×") {
    // action
}
.frame(minWidth: 44, minHeight: 44)
.font(.caption)
```

### 5. Switch Control测试

#### 启用Switch Control
```
设置 > 辅助功能 > Switch Control > 开启
```

#### 测试重点
- 所有交互元素可通过switch访问
- 焦点顺序逻辑合理
- 没有焦点陷阱

### 6. Voice Control测试

#### 启用Voice Control
```
设置 > 辅助功能 > Voice Control > 开启
```

#### 测试命令
- "显示数字" - 验证所有元素有数字标签
- "显示名称" - 验证元素有语音识别名称
- "点击 [元素名称]" - 验证语音命令有效

## 自动化测试

### Xcode Accessibility Inspector

#### 启动Inspector
```
Xcode > Open Developer Tool > Accessibility Inspector
```

#### 运行审计
1. 选择设备和应用
2. 点击"Audit"标签
3. 运行全面审计
4. 修复发现的问题

### UI测试中的可访问性

```swift
class AccessibilityUITests: XCTestCase {
    
    func testVoiceOverLabels() {
        let app = XCUIApplication()
        app.launch()
        
        // 验证关键元素有正确的accessibility标签
        XCTAssertTrue(app.buttons["添加记录"].exists)
        XCTAssertTrue(app.searchFields["搜索缺货记录"].exists)
        
        // 验证状态信息可访问
        XCTAssertTrue(app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS '状态'")
        ).firstMatch.exists)
    }
    
    func testDynamicType() {
        let app = XCUIApplication()
        app.launchArguments += ["-UIPreferredContentSizeCategory", "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"]
        app.launch()
        
        // 验证大字体下界面仍然可用
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.isHittable)
        XCTAssertTrue(searchField.frame.height >= 44)
    }
}
```

## 常见问题和解决方案

### 问题1: 装饰性图标被VoiceOver朗读

```swift
// ❌ 装饰图标没有隐藏
Image(systemName: "magnifyingglass")
    .foregroundColor(.secondary)

// ✅ 隐藏装饰图标
Image(systemName: "magnifyingglass")
    .foregroundColor(.secondary)
    .accessibilityHidden(true)
```

### 问题2: 复合视图缺少整体标签

```swift
// ❌ VoiceOver分别朗读每个子元素
HStack {
    Text("客户名称")
    Text("张三")
}

// ✅ 组合为单一可访问元素
HStack {
    Text("客户名称")
    Text("张三")
}
.accessibilityElement(children: .combine)
.accessibilityLabel("客户名称: 张三")
```

### 问题3: 状态变化没有语音反馈

```swift
// ❌ 状态变化无反馈
@State private var isLoading = false

Button("加载") {
    isLoading = true
    // load data
}

// ✅ 提供状态变化反馈
@State private var isLoading = false

Button("加载") {
    isLoading = true
    // load data
}
.accessibilityLabel(isLoading ? "正在加载" : "加载")
.accessibilityAddTraits(isLoading ? .updatesFrequently : [])
```

## 持续改进流程

### 1. 开发阶段
- 使用Accessibility Inspector实时检查
- 编写可访问性测试用例
- 定期进行VoiceOver测试

### 2. 代码审查
- 检查accessibility标签和提示
- 验证触摸目标大小
- 确认颜色对比度

### 3. 用户测试
- 邀请有视觉障碍的用户参与测试
- 收集真实使用反馈
- 持续优化用户体验

### 4. 版本发布前
- 运行完整的可访问性审计
- 测试所有主要功能流程
- 验证新功能的可访问性

## 性能影响考虑

### 最小化性能影响
```swift
// ✅ 合理使用accessibility修饰符
Text("重要信息")
    .accessibilityLabel("重要信息") // 必要时使用

// ❌ 过度使用accessibility修饰符
Text("普通文本") // 系统会自动处理，无需额外标签
    .accessibilityLabel("普通文本") // 不必要
```

### 条件性accessibility支持
```swift
// 根据需要动态添加accessibility支持
struct AccessibilityOptimizedView: View {
    @Environment(\.accessibilityEnabled) private var accessibilityEnabled
    
    var body: some View {
        Text("内容")
            .if(accessibilityEnabled) { text in
                text.accessibilityHint("详细的提示信息")
            }
    }
}
```

## 资源和工具

### Apple官方资源
- [Human Interface Guidelines - Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [Accessibility Programming Guide](https://developer.apple.com/accessibility/ios/)

### 第三方工具
- [Accessibility Scanner (Android)](https://play.google.com/store/apps/details?id=com.google.android.apps.accessibility.auditor)
- [axe DevTools](https://www.deque.com/axe/devtools/)
- [Colour Contrast Analyser](https://www.tpgi.com/color-contrast-checker/)

### 测试社区
- [AppleVis Community](https://www.applevis.com/) - 盲人和低视力用户社区
- [WebAIM](https://webaim.org/) - Web可访问性资源

这份指南应该成为开发团队的标准参考，确保每个功能都符合可访问性标准。