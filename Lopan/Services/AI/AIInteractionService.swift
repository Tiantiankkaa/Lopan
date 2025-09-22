//
//  AIInteractionService.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/19.
//  iOS 26 Apple Intelligence Integration Service
//

import Foundation
import AVFoundation
import Speech
import NaturalLanguage

/// Apple Intelligence integration service for voice commands and smart suggestions
@available(iOS 26.0, *)
@MainActor
public final class AIInteractionService: NSObject, ObservableObject, Sendable {

    // MARK: - Published Properties
    @Published public var isListening: Bool = false
    @Published public var isProcessing: Bool = false
    @Published public var lastCommand: String = ""
    @Published public var suggestions: [SmartSuggestion] = []

    // MARK: - Private Properties
    private nonisolated(unsafe) var speechRecognizer: SFSpeechRecognizer?
    private nonisolated(unsafe) var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private nonisolated(unsafe) var recognitionTask: SFSpeechRecognitionTask?
    private nonisolated(unsafe) let audioEngine = AVAudioEngine()
    private nonisolated(unsafe) let nlProcessor = NLLanguageRecognizer()
    private nonisolated(unsafe) var hasConfiguredSpeech = false

    // MARK: - Dependencies
    private nonisolated(unsafe) weak var repositoryFactory: RepositoryFactory?
    private nonisolated(unsafe) weak var serviceFactory: ServiceFactory?

    // MARK: - Initialization
    public init(repositoryFactory: RepositoryFactory? = nil, serviceFactory: ServiceFactory? = nil) {
        super.init()
        self.repositoryFactory = repositoryFactory
        self.serviceFactory = serviceFactory
    }

    // MARK: - Voice Command Processing

    /// Start listening for voice commands
    public func startListening() async {
        guard await requestPermissions() else {
            print("❌ AI: Speech recognition permissions denied")
            return
        }

        configureSpeechRecognitionIfNeeded()

        do {
            try await startSpeechRecognition()
            isListening = true
            print("🎤 AI: Started listening for voice commands")
        } catch {
            print("❌ AI: Failed to start speech recognition: \(error)")
        }
    }

    /// Stop listening for voice commands
    public func stopListening() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        isListening = false
        print("🔇 AI: Stopped listening for voice commands")
    }

    /// Process a voice command
    public func processVoiceCommand(_ text: String) async {
        isProcessing = true
        lastCommand = text

        let intent = await extractIntent(from: text)
        _ = await executeIntent(intent)
        await generateSuggestions(for: intent)

        print("🤖 AI: Processed command '\(text)' with intent: \(intent.type)")

        isProcessing = false
    }

    // MARK: - Smart Suggestions

    /// Generate contextual suggestions
    public func generateSuggestions(for context: AIIntent) async {
        let newSuggestions = await generateContextualSuggestions(for: context)

        await MainActor.run {
            self.suggestions = newSuggestions
        }
    }

    /// Clear all suggestions
    public func clearSuggestions() {
        suggestions.removeAll()
    }

    // MARK: - Private Methods

    private func setupSpeechRecognition() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
        speechRecognizer?.delegate = self
    }

    private func configureSpeechRecognitionIfNeeded() {
        guard !hasConfiguredSpeech else { return }
        setupSpeechRecognition()
        hasConfiguredSpeech = true
    }

    private func requestPermissions() async -> Bool {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        let audioGranted = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }

        return speechStatus == .authorized && audioGranted
    }

    private func startSpeechRecognition() async throws {
        recognitionTask?.cancel()
        recognitionTask = nil

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw AIError.speechRecognitionUnavailable
        }

        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                if let result = result {
                    let text = result.bestTranscription.formattedString
                    await self?.processVoiceCommand(text)
                }

                if error != nil || result?.isFinal == true {
                    self?.stopListening()
                }
            }
        }
    }

    private func extractIntent(from text: String) async -> AIIntent {
        // Use NLLanguageRecognizer for intent classification
        nlProcessor.processString(text)

        // Simplified intent extraction - in production, use more sophisticated NLP
        if text.localizedCaseInsensitiveContains("客户") || text.localizedCaseInsensitiveContains("customer") {
            return AIIntent(type: .customerManagement, parameters: [:], confidence: 0.8)
        } else if text.localizedCaseInsensitiveContains("生产") || text.localizedCaseInsensitiveContains("production") {
            return AIIntent(type: .productionControl, parameters: [:], confidence: 0.8)
        } else if text.localizedCaseInsensitiveContains("库存") || text.localizedCaseInsensitiveContains("inventory") {
            return AIIntent(type: .inventoryManagement, parameters: [:], confidence: 0.8)
        } else {
            return AIIntent(type: .general, parameters: [:], confidence: 0.3)
        }
    }

    private func executeIntent(_ intent: AIIntent) async -> AIResponse {
        switch intent.type {
        case .customerManagement:
            return await handleCustomerManagement(intent)
        case .productionControl:
            return await handleProductionControl(intent)
        case .inventoryManagement:
            return await handleInventoryManagement(intent)
        case .general:
            return AIResponse(success: true, message: "收到您的指令", data: nil)
        }
    }

    private func handleCustomerManagement(_ intent: AIIntent) async -> AIResponse {
        // Integrate with customer service
        guard serviceFactory?.customerService != nil else {
            return AIResponse(success: false, message: "客户服务不可用", data: nil)
        }

        // Example: Get customer count
        do {
            let customers = try await repositoryFactory?.customerRepository.fetchCustomers() ?? []
            let message = "当前有 \(customers.count) 个客户"
            return AIResponse(success: true, message: message, data: customers.count)
        } catch {
            return AIResponse(success: false, message: "获取客户信息失败", data: nil)
        }
    }

    private func handleProductionControl(_ intent: AIIntent) async -> AIResponse {
        // Integrate with production service
        return AIResponse(success: true, message: "生产控制功能正在开发中", data: nil)
    }

    private func handleInventoryManagement(_ intent: AIIntent) async -> AIResponse {
        // Integrate with inventory service
        return AIResponse(success: true, message: "库存管理功能正在开发中", data: nil)
    }

    private func generateContextualSuggestions(for intent: AIIntent) async -> [SmartSuggestion] {
        switch intent.type {
        case .customerManagement:
            return [
                SmartSuggestion(
                    id: UUID().uuidString,
                    text: "查看客户列表",
                    action: .navigation(destination: "CustomerList"),
                    confidence: 0.9
                ),
                SmartSuggestion(
                    id: UUID().uuidString,
                    text: "添加新客户",
                    action: .action(name: "addCustomer"),
                    confidence: 0.8
                )
            ]
        case .productionControl:
            return [
                SmartSuggestion(
                    id: UUID().uuidString,
                    text: "查看生产状态",
                    action: .navigation(destination: "ProductionDashboard"),
                    confidence: 0.9
                )
            ]
        case .inventoryManagement:
            return [
                SmartSuggestion(
                    id: UUID().uuidString,
                    text: "检查库存水平",
                    action: .navigation(destination: "InventoryDashboard"),
                    confidence: 0.9
                )
            ]
        case .general:
            return []
        }
    }
}

// MARK: - Supporting Types

@available(iOS 26.0, *)
public struct AIIntent {
    public let type: IntentType
    public let parameters: [String: Any]
    public let confidence: Double

    public enum IntentType: String {
        case customerManagement = "customer_management"
        case productionControl = "production_control"
        case inventoryManagement = "inventory_management"
        case general = "general"
    }
}

@available(iOS 26.0, *)
public struct AIResponse {
    public let success: Bool
    public let message: String
    public let data: Any?
}

@available(iOS 26.0, *)
public struct SmartSuggestion: Identifiable {
    public let id: String
    public let text: String
    public let action: SuggestionAction
    public let confidence: Double

    public enum SuggestionAction {
        case navigation(destination: String)
        case action(name: String)
        case search(query: String)
    }
}

// MARK: - Errors

@available(iOS 26.0, *)
public enum AIError: Error {
    case speechRecognitionUnavailable
    case permissionDenied
    case processingFailed
    case serviceUnavailable
}

// MARK: - Speech Recognizer Delegate

@available(iOS 26.0, *)
@MainActor
extension AIInteractionService: SFSpeechRecognizerDelegate {
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if !available {
            stopListening()
        }
    }
}
