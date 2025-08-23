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
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
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
                Color(.systemGray6)
            case .prominent:
                Color.white
            case .compact:
                Color(.systemGray6)
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
            return Color.black.opacity(0.05)
        case .prominent:
            return isFocused ? LopanColors.primary.opacity(0.15) : Color.black.opacity(0.08)
        case .compact:
            return Color.clear
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
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
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
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
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
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
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

#Preview {
    @Previewable @State var searchText = ""
    
    let sampleSuggestions = ["iPhone 15 Pro", "iPhone 15", "Samsung Galaxy S24", "华为 Mate 60", "小米 14 Pro"]
    
    return VStack(spacing: 24) {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prominent Style with Voice Search")
                .font(.headline)
                .foregroundColor(.primary)
            
            LopanSearchBar(
                searchText: $searchText,
                placeholder: "搜索产品名称、颜色或尺寸...",
                suggestions: sampleSuggestions,
                style: .prominent,
                showVoiceSearch: true
            )
        }
        
        VStack(alignment: .leading, spacing: 8) {
            Text("Standard Style")
                .font(.headline)
                .foregroundColor(.primary)
            
            LopanSearchBar(
                searchText: .constant(""),
                placeholder: "标准搜索样式",
                suggestions: sampleSuggestions,
                style: .standard
            )
        }
        
        VStack(alignment: .leading, spacing: 8) {
            Text("Compact Style")
                .font(.headline)
                .foregroundColor(.primary)
            
            LopanSearchBar(
                searchText: .constant(""),
                placeholder: "紧凑搜索样式",
                suggestions: [],
                style: .compact
            )
        }
        
        Spacer()
    }
    .padding()
    .background(Color(.systemGray6))
}