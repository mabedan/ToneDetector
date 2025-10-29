import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum ToneClassifier {
    struct LLMUnavailableError: LocalizedError { var errorDescription: String? { "On-device language model is unavailable on this device." } }

    /// Classifies text based on a question. Returns a short reason when the answer is no.
    static func classify(text: String, question: String) async throws -> (yes: Bool, reason: String?) {
        #if canImport(FoundationModels)
        // Check availability
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            break
        case .unavailable(let reason):
            let message: String
            switch reason {
            case .deviceNotEligible:
                message = "Device not eligible for Apple Intelligence."
            case .appleIntelligenceNotEnabled:
                message = "Apple Intelligence not enabled in Settings."
            case .modelNotReady:
                message = "AI model not ready. Please try again later."
            @unknown default:
                message = "Unknown availability issue."
            }
            throw NSError(domain: "ToneClassifier", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        @unknown default:
            throw LLMUnavailableError()
        }

        // Build a strict prompt
        let prompt = """
        You are a concise classifier. Respond in one of two formats only:
        1) Yes
        2) No — <one short sentence explaining why>
        Question: \(question)
        Text: \(text)
        Answer:
        """

        // Create a session and generate a response
        let session = LanguageModelSession(transcript: Transcript(entries: []))
        let options = GenerationOptions(temperature: 0.0, maximumResponseTokens: 48)
        let response = try await session.respond(to: prompt, options: options)
        let reply = response.content.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        // Parse formats
        let lower = reply.lowercased()
        if lower == "yes" || lower.hasPrefix("yes\n") { return (true, nil) }
        if lower.hasPrefix("no") {
            let separators: [Character] = ["—", "-", ":"]
            if let idx = reply.firstIndex(where: { separators.contains($0) }) {
                let reasonStart = reply.index(after: idx)
                let reason = reply[reasonStart...].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                return (false, reason.isEmpty ? nil : reason)
            }
            let stripped = reply.dropFirst(2).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            return (false, stripped.isEmpty ? nil : stripped)
        }

        // Unexpected format
        throw LLMUnavailableError()
        #else
        // Framework not available
        throw LLMUnavailableError()
        #endif
    }
}

