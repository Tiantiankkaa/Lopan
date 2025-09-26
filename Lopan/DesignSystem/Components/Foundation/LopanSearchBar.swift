//
//  LopanSearchBar.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//  Enhanced by Claude Code for Product Management Redesign
//

import SwiftUI
import Speech
import AVFoundation

struct LopanSearchBar: View {
    @Binding var searchText: String
    let placeholder: String
    let suggestions: [String]
    let style: SearchBarStyle
    let showVoiceSearch: Bool
    let onClear: (() -> Void)?
    let onSearch: ((String) -> Void)?
    
    @State private var isEditing = false
    @State private var isFocused = false
    @State private var showingSuggestions = false
    @State private var isVoiceSearching = false
    @State private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()
    @State private var showingVoiceUnavailableAlert = false
    
    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    private var canUseVoiceSearch: Bool {
        !isSimulator && showVoiceSearch && speechRecognizer?.isAvailable == true
    }
    
    enum SearchBarStyle {
        case standard
        case prominent
        case compact
    }
    
    init(
        searchText: Binding<String>,
        placeholder: String = "搜索...",
        suggestions: [String] = [],
        style: SearchBarStyle = .standard,
        showVoiceSearch: Bool = false,
        onClear: (() -> Void)? = nil,
        onSearch: ((String) -> Void)? = nil
    ) {
        self._searchText = searchText
        self.placeholder = placeholder
        self.suggestions = suggestions
        self.style = style
        self.showVoiceSearch = showVoiceSearch
        self.onClear = onClear
        self.onSearch = onSearch
    }
    
    var body: some View {
        VStack(spacing: 0) {
            searchBarBody
            
            if showingSuggestions && !suggestions.isEmpty && isFocused {
                suggestionsView
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showingSuggestions)
        .alert("语音输入不可用", isPresented: $showingVoiceUnavailableAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(isSimulator ? 
                "语音输入功能在模拟器中不可用，请在真机上使用此功能。" : 
                "语音输入功能当前不可用，请检查麦克风权限设置。")
        }
    }
    
    private var searchBarBody: some View {
        HStack(spacing: 12) {
            searchIconView
            searchTextField
            actionButtonsView
        }
        .padding(.horizontal, searchBarPadding)
        .padding(.vertical, verticalPadding)
        .background(searchBarBackground)
        .overlay(searchBarBorder)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowOffsetY)
        .scaleEffect(isFocused ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
    
    private var searchIconView: some View {
        Image(systemName: "magnifyingglass")
            .font(.system(size: iconSize, weight: .medium))
            .foregroundColor(iconColor)
            .scaleEffect(isFocused ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
    
    private var searchTextField: some View {
        TextField(placeholder, text: $searchText)
            .font(textFont)
            .foregroundColor(LopanColors.textPrimary)
            .disableAutocorrection(true)
            .onSubmit {
                performSearch()
            }
            .onChange(of: searchText) { _, newValue in
                withAnimation(.easeInOut(duration: 0.15)) {
                    showingSuggestions = !newValue.isEmpty && isFocused && !suggestions.isEmpty
                }
                onSearch?(newValue)
            }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isFocused = true
                    showingSuggestions = !searchText.isEmpty && !suggestions.isEmpty
                }
            }
    }
    
    private var actionButtonsView: some View {
        HStack(spacing: 8) {
            if !searchText.isEmpty {
                clearButton
            }
            
            if showVoiceSearch {
                voiceSearchButton
            }
        }
    }
    
    private var clearButton: some View {
        Button(action: clearSearch) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(LopanColors.textSecondary)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("清除搜索")
        .transition(.scale.combined(with: .opacity))
    }
    
    private var voiceSearchButton: some View {
        Button(action: handleVoiceButtonTap) {
            Image(systemName: isVoiceSearching ? "mic.fill" : "mic")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(canUseVoiceSearch ? 
                    (isVoiceSearching ? LopanColors.primary : LopanColors.textSecondary) : 
                    LopanColors.textTertiary)
                .scaleEffect(isVoiceSearching ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isVoiceSearching)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!canUseVoiceSearch)
        .accessibilityLabel(isVoiceSearching ? "停止语音搜索" : 
            (canUseVoiceSearch ? "开始语音搜索" : "语音搜索不可用"))
    }
    
    private var suggestionsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(suggestions.prefix(5), id: \.self) { suggestion in
                suggestionRow(suggestion)
                
                if suggestion != suggestions.prefix(5).last {
                    Divider()
                        .foregroundColor(LopanColors.border)
                }
            }
        }
        .background(LopanColors.backgroundSecondary)
        .cornerRadius(12)
        .shadow(color: LopanColors.shadow.opacity(2), radius: 4, x: 0, y: 2)
        .padding(.horizontal, searchBarPadding)
        .padding(.top, 4)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    private func suggestionRow(_ suggestion: String) -> some View {
        Button(action: {
            selectSuggestion(suggestion)
        }) {
            HStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(LopanColors.textSecondary)
                
                Text(suggestion)
                    .font(.body)
                    .foregroundColor(LopanColors.textPrimary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Image(systemName: "arrow.up.left")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(LopanColors.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Style Properties
    
    private var searchBarPadding: CGFloat {
        switch style {
        case .standard: return 16
        case .prominent: return 18
        case .compact: return 12
        }
    }
    
    private var verticalPadding: CGFloat {
        switch style {
        case .standard: return 12
        case .prominent: return 16
        case .compact: return 8
        }
    }
    
    private var cornerRadius: CGFloat {
        switch style {
        case .standard: return 12
        case .prominent: return 16
        case .compact: return 8
        }
    }
    
    private var iconSize: CGFloat {
        switch style {
        case .standard: return 16
        case .prominent: return 18
        case .compact: return 14
        }
    }
    
    private var textFont: Font {
        switch style {
        case .standard: return .body
        case .prominent: return .body
        case .compact: return .callout
        }
    }
    
    private var iconColor: Color {
        isFocused ? LopanColors.primary : LopanColors.textSecondary
    }
    
    private var searchBarBackground: some View {
        Group {
            switch style {
            case .standard:
                LopanColors.backgroundTertiary
            case .prominent:
                LopanColors.backgroundSecondary
            case .compact:
                LopanColors.backgroundTertiary
            }
        }
    }
    
    private var searchBarBorder: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(
                isFocused ? LopanColors.primary.opacity(0.3) : LopanColors.border,
                lineWidth: isFocused ? 2 : 0.5
            )
    }
    
    private var shadowColor: Color {
        switch style {
        case .standard:
            return LopanColors.shadow
        case .prominent:
            return isFocused ? LopanColors.primary.opacity(0.15) : LopanColors.shadow.opacity(1.6)
        case .compact:
            return LopanColors.clear
        }
    }
    
    private var shadowRadius: CGFloat {
        switch style {
        case .standard: return 2
        case .prominent: return isFocused ? 8 : 4
        case .compact: return 0
        }
    }
    
    private var shadowOffsetY: CGFloat {
        switch style {
        case .standard: return 1
        case .prominent: return isFocused ? 4 : 2
        case .compact: return 0
        }
    }
    
    // MARK: - Actions
    
    private func clearSearch() {
        LopanHapticEngine.shared.light()
        
        withAnimation(.easeInOut(duration: 0.2)) {
            searchText = ""
            showingSuggestions = false
        }
        onClear?()
    }
    
    private func performSearch() {
        isFocused = false
        showingSuggestions = false
        onSearch?(searchText)
        
        // Hide keyboard
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func selectSuggestion(_ suggestion: String) {
        LopanHapticEngine.shared.light()
        
        withAnimation(.easeInOut(duration: 0.2)) {
            searchText = suggestion
            showingSuggestions = false
            isFocused = false
        }
        
        onSearch?(suggestion)
        
        // Hide keyboard
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func handleVoiceButtonTap() {
        if !canUseVoiceSearch {
            showingVoiceUnavailableAlert = true
            return
        }
        
        if isVoiceSearching {
            stopVoiceSearch()
        } else {
            startVoiceSearch()
        }
    }
    
    private func startVoiceSearch() {
        guard canUseVoiceSearch else { 
            showingVoiceUnavailableAlert = true
            return 
        }
        
        // Check audio input availability
        let audioSession = AVAudioSession.sharedInstance()
        guard audioSession.availableInputs?.contains(where: { $0.portType == .builtInMic }) == true else {
            showingVoiceUnavailableAlert = true
            return
        }
        
        LopanHapticEngine.shared.medium()
        
        isVoiceSearching = true
        
        // Request authorization if needed
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                if authStatus == .authorized {
                    self.performVoiceSearch()
                } else {
                    self.isVoiceSearching = false
                    self.showingVoiceUnavailableAlert = true
                }
            }
        }
    }
    
    private func stopVoiceSearch() {
        isVoiceSearching = false
        recognitionRequest?.endAudio()
        audioEngine.stop()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
    }
    
    private func performVoiceSearch() {
        // Early check for simulator or unavailable hardware
        guard !isSimulator else {
            DispatchQueue.main.async {
                self.isVoiceSearching = false
                self.showingVoiceUnavailableAlert = true
            }
            return
        }
        
        do {
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else { 
                DispatchQueue.main.async {
                    self.stopVoiceSearch()
                }
                return 
            }
            
            recognitionRequest.shouldReportPartialResults = true
            
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
                if let result = result {
                    DispatchQueue.main.async {
                        self.searchText = result.bestTranscription.formattedString
                    }
                }
                
                if error != nil || result?.isFinal == true {
                    DispatchQueue.main.async {
                        self.stopVoiceSearch()
                    }
                }
            }
            
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            // Safe access to input node with additional error handling
            guard audioEngine.inputNode != nil else {
                throw NSError(domain: "AudioEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "Audio input not available"])
            }
            
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                self.recognitionRequest?.append(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
        } catch {
            DispatchQueue.main.async {
                self.stopVoiceSearch()
                self.showingVoiceUnavailableAlert = true
            }
        }
    }
}

// MARK: - Dynamic Type Previews

#Preview("Default Size") {
    @Previewable @State var searchText = ""

    let sampleSuggestions = ["生产订单", "客户管理", "产品验收", "质量检查", "库存管理"]

    return ScrollView {
        VStack(spacing: 24) {
            Text("Search Bar Variants")
                .font(.headline)
                .padding(.bottom)

            VStack(alignment: .leading, spacing: 8) {
                Text("Prominent Style with Voice Search")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                LopanSearchBar(
                    searchText: $searchText,
                    placeholder: "搜索产品名称、客户信息...",
                    suggestions: sampleSuggestions,
                    style: .prominent,
                    showVoiceSearch: true
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Standard Style with Suggestions")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                LopanSearchBar(
                    searchText: .constant(""),
                    placeholder: "标准搜索样式",
                    suggestions: sampleSuggestions,
                    style: .standard
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Compact Style")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                LopanSearchBar(
                    searchText: .constant(""),
                    placeholder: "紧凑搜索样式",
                    suggestions: [],
                    style: .compact
                )
            }
        }
        .padding()
    }
    .environment(\.dynamicTypeSize, .large)
}

#Preview("Extra Large") {
    @Previewable @State var searchText = "生产"

    let sampleSuggestions = [
        "Production Manufacturing Orders for Quality Control",
        "Customer Information Database Management",
        "Product Quality Inspection and Validation",
        "Manufacturing Process Quality Assurance",
        "Inventory Stock Management System"
    ]

    return ScrollView {
        VStack(spacing: 28) {
            Text("Search Bar Preview at Extra Large Size")
                .font(.title2)
                .padding(.bottom)

            VStack(alignment: .leading, spacing: 12) {
                Text("Prominent Style for Manufacturing Search")
                    .font(.headline)
                    .foregroundColor(.primary)

                LopanSearchBar(
                    searchText: $searchText,
                    placeholder: "Search manufacturing orders, customer information, and quality reports...",
                    suggestions: sampleSuggestions,
                    style: .prominent,
                    showVoiceSearch: true
                )
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Standard Style for Production Database")
                    .font(.headline)
                    .foregroundColor(.primary)

                LopanSearchBar(
                    searchText: .constant(""),
                    placeholder: "Search production database for orders and specifications",
                    suggestions: sampleSuggestions,
                    style: .standard
                )
            }
        }
        .padding()
    }
    .environment(\.dynamicTypeSize, .xLarge)
}

#Preview("Accessibility 3") {
    @Previewable @State var searchText = "质量检查"

    let sampleSuggestions = [
        "Quality Control Dashboard for Manufacturing Excellence",
        "Production Order Management System with Batch Tracking",
        "Customer Information Database for Manufacturing Orders",
        "Product Quality Inspection Reports and Validation Systems",
        "Manufacturing Process Monitoring and Control Interface"
    ]

    return ScrollView {
        VStack(spacing: 32) {
            Text("Search Bar Preview at AX3 Size")
                .font(.title2)
                .padding(.bottom)

            VStack(alignment: .leading, spacing: 16) {
                Text("Prominent Manufacturing Search with Voice Input Support")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                LopanSearchBar(
                    searchText: $searchText,
                    placeholder: "Search comprehensive manufacturing database including customer orders, product specifications, and quality control reports...",
                    suggestions: sampleSuggestions,
                    style: .prominent,
                    showVoiceSearch: true
                )
            }

            VStack(alignment: .leading, spacing: 16) {
                Text("Standard Production Database Search Interface")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                LopanSearchBar(
                    searchText: .constant(""),
                    placeholder: "Standard search interface for production database with intelligent suggestions",
                    suggestions: sampleSuggestions,
                    style: .standard
                )
            }
        }
        .padding()
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Accessibility 5 (Maximum)") {
    @Previewable @State var searchText = ""

    let sampleSuggestions = [
        "Search Database",
        "Customer Orders",
        "Quality Reports",
        "Production Data"
    ]

    return ScrollView {
        VStack(spacing: 36) {
            Text("Maximum Accessibility Size")
                .font(.largeTitle)
                .padding(.bottom)

            VStack(alignment: .leading, spacing: 20) {
                Text("Search System")
                    .font(.title)
                    .fontWeight(.semibold)

                LopanSearchBar(
                    searchText: $searchText,
                    placeholder: "Search everything...",
                    suggestions: sampleSuggestions,
                    style: .prominent,
                    showVoiceSearch: true
                )
            }

            VStack(alignment: .leading, spacing: 20) {
                Text("Simple Search")
                    .font(.title)
                    .fontWeight(.semibold)

                LopanSearchBar(
                    searchText: .constant(""),
                    placeholder: "Find items...",
                    suggestions: [],
                    style: .compact
                )
            }
        }
        .padding()
    }
    .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Dark Mode - AX3") {
    @Previewable @State var searchText = "夜班生产"

    let sampleSuggestions = [
        "Night Shift Production Orders and Quality Control Systems",
        "After-Hours Manufacturing Process Management Dashboard",
        "Night Operations Customer Service and Order Processing",
        "Dark Mode Quality Inspection and Validation Interface",
        "Night Shift Manufacturing Equipment Monitoring System"
    ]

    return ScrollView {
        VStack(spacing: 32) {
            Text("Dark Mode Search Bar Preview")
                .font(.title2)
                .padding(.bottom)

            VStack(alignment: .leading, spacing: 16) {
                Text("Night Shift Manufacturing Search with Voice Input")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                LopanSearchBar(
                    searchText: $searchText,
                    placeholder: "Search night shift production data, after-hours quality reports, and manufacturing status...",
                    suggestions: sampleSuggestions,
                    style: .prominent,
                    showVoiceSearch: true
                )
            }

            VStack(alignment: .leading, spacing: 16) {
                Text("Standard Dark Mode Production Search")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                LopanSearchBar(
                    searchText: .constant(""),
                    placeholder: "Search dark mode production interface with intelligent filtering",
                    suggestions: sampleSuggestions,
                    style: .standard
                )
            }
        }
        .padding()
    }
    .preferredColorScheme(.dark)
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Interactive States") {
    @Previewable @State var searchText1 = ""
    @Previewable @State var searchText2 = "生产订单"

    let sampleSuggestions = ["生产订单", "客户管理", "质量检查", "库存管理"]

    return ScrollView {
        VStack(spacing: 24) {
            Text("Search Bar Interactive States")
                .font(.headline)
                .padding(.bottom)

            VStack(alignment: .leading, spacing: 12) {
                Text("Empty State with Voice Search")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                LopanSearchBar(
                    searchText: $searchText1,
                    placeholder: "搭载语音搜索的空状态",
                    suggestions: sampleSuggestions,
                    style: .prominent,
                    showVoiceSearch: true
                )
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Filled State with Clear Button")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                LopanSearchBar(
                    searchText: $searchText2,
                    placeholder: "搜索...",
                    suggestions: sampleSuggestions,
                    style: .standard
                )
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Compact Style - No Suggestions")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                LopanSearchBar(
                    searchText: .constant("紧凑搜索"),
                    placeholder: "紧凑模式",
                    suggestions: [],
                    style: .compact
                )
            }
        }
        .padding()
    }
    .environment(\.dynamicTypeSize, .xLarge)
}