import Foundation

final class ClaudeAPIService {
    var apiKey: String = ""

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model = "claude-sonnet-4-5"
    private let maxTokens = 256
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public

    func correct(text: String, mode: KeyboardMode) async -> [Suggestion] {
        let systemPrompt = systemPrompt(for: mode)
        let userMessage = text
        return await callAPI(system: systemPrompt, userMessage: userMessage, originalText: text)
    }

    func translate(text: String, mode: KeyboardMode) async -> [Suggestion] {
        let systemPrompt = systemPrompt(for: mode)
        return await callAPI(system: systemPrompt, userMessage: text, originalText: text)
    }

    func convertAndTranslate(hiragana: String, mode: KeyboardMode) async -> [Suggestion] {
        let system = convertAndTranslatePrompt(for: mode)
        return await callConvertAndTranslateAPI(system: system, hiragana: hiragana)
    }

    /// Translation only (no conversion) — used when local kana-kanji handles conversion.
    func translateOnly(text: String, mode: KeyboardMode) async -> [Suggestion] {
        let targetLanguage: String
        switch mode {
        case .jpToEn: targetLanguage = "English"
        case .jpToKr: targetLanguage = "Korean"
        default: return []
        }

        let system = """
        You are a Japanese-to-\(targetLanguage) translator for a chat keyboard. \
        The user will send Japanese text (may contain hiragana, kanji, katakana, or a mix). \
        Return a JSON array of 1-3 natural \(targetLanguage) translations suitable for casual chat. \
        Only return the JSON array, no explanation. Example: ["How are you?", "How's it going?"]
        """

        return await callAPI(system: system, userMessage: text, originalText: text)
            .map { Suggestion(text: $0.text, originalText: $0.originalText, kind: .translation) }
    }

    // MARK: - Private

    private func callAPI(system: String, userMessage: String, originalText: String) async -> [Suggestion] {
        guard !apiKey.isEmpty else { return [] }

        let request = ClaudeRequest(
            model: model,
            max_tokens: maxTokens,
            system: system,
            messages: [ClaudeMessage(role: "user", content: userMessage)]
        )

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
            let (data, response) = try await session.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return []
            }

            let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)
            return parseSuggestions(from: claudeResponse, originalText: originalText)
        } catch {
            return []
        }
    }

    private func callConvertAndTranslateAPI(system: String, hiragana: String) async -> [Suggestion] {
        guard !apiKey.isEmpty else { return [] }

        let request = ClaudeRequest(
            model: model,
            max_tokens: maxTokens,
            system: system,
            messages: [ClaudeMessage(role: "user", content: hiragana)]
        )

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
            let (data, response) = try await session.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return []
            }

            let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)
            return parseConvertAndTranslate(from: claudeResponse, originalText: hiragana)
        } catch {
            return []
        }
    }

    private func parseConvertAndTranslate(from response: ClaudeResponse, originalText: String) -> [Suggestion] {
        guard let textBlock = response.content.first(where: { $0.type == "text" }),
              let text = textBlock.text else {
            return []
        }

        let cleaned = extractJSON(from: text)

        // Try to parse as {"conversions":[...], "translations":[...]}
        if let data = cleaned.data(using: .utf8),
           let json = try? JSONDecoder().decode(ConvertAndTranslateResponse.self, from: data) {
            var results: [Suggestion] = []
            for c in json.conversions {
                results.append(Suggestion(text: c, originalText: originalText, kind: .conversion))
            }
            for t in json.translations {
                results.append(Suggestion(text: t, originalText: originalText, kind: .translation))
            }
            return results
        }

        // Fallback: treat as single translation
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return [Suggestion(text: trimmed, originalText: originalText, kind: .translation)]
    }

    private struct ConvertAndTranslateResponse: Decodable {
        let conversions: [String]
        let translations: [String]
    }

    private func convertAndTranslatePrompt(for mode: KeyboardMode) -> String {
        let targetLanguage: String
        let targetExample: String
        switch mode {
        case .jpToEn:
            targetLanguage = "English"
            targetExample = "\"translations\":[\"How are you?\",\"How's it going?\"]"
        case .jpToKr:
            targetLanguage = "Korean"
            targetExample = "\"translations\":[\"잘 지내?\",\"어떻게 지내?\"]"
        default:
            targetLanguage = "English"
            targetExample = "\"translations\":[\"How are you?\"]"
        }

        return """
        You are a Japanese input assistant for a chat keyboard. \
        The user will send Japanese text that may contain hiragana, kanji, katakana, or a mix. \
        Return a JSON object with two arrays: \
        1. "conversions": 1-3 natural kanji/katakana conversion candidates for the entire input text. \
        If the input already contains kanji/katakana, refine or offer alternative phrasings. \
        If only part of the text is hiragana, convert that part while keeping existing kanji/katakana. \
        2. "translations": 1-3 natural \(targetLanguage) translations suitable for casual chat. \
        Only return the JSON object, no explanation. \
        Example: {"conversions":["元気ですか","元気？","お元気ですか"],\(targetExample)}
        """
    }

    private func parseSuggestions(from response: ClaudeResponse, originalText: String) -> [Suggestion] {
        guard let textBlock = response.content.first(where: { $0.type == "text" }),
              let text = textBlock.text else {
            return []
        }

        let cleaned = extractJSON(from: text)

        // Try to parse as JSON array
        if let data = cleaned.data(using: .utf8),
           let array = try? JSONDecoder().decode([String].self, from: data) {
            return array.map { Suggestion(text: $0, originalText: originalText) }
        }

        // Fallback: treat the whole response as a single suggestion
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return [Suggestion(text: trimmed, originalText: originalText)]
    }

    /// Strips markdown code fences and extracts the JSON content from Claude's response.
    private func extractJSON(from text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip ```json ... ``` or ``` ... ```
        if s.hasPrefix("```") {
            // Remove opening fence (```json or ```)
            if let firstNewline = s.firstIndex(of: "\n") {
                s = String(s[s.index(after: firstNewline)...])
            }
            // Remove closing fence
            if s.hasSuffix("```") {
                s = String(s.dropLast(3))
            }
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return s
    }

    private func systemPrompt(for mode: KeyboardMode) -> String {
        switch mode {
        case .enCorrection:
            return """
            You are an English writing assistant for a chat keyboard. \
            The user will send a sentence they typed. \
            Return a JSON array of 1-3 corrected/improved versions. \
            Fix grammar, spelling, and make it natural for casual chat. \
            Only return the JSON array, no explanation. Example: ["Hi, how are you?", "Hey, how's it going?"]
            """
        case .krCorrection:
            return """
            You are a Korean writing assistant for a chat keyboard. \
            The user will send a Korean sentence they typed. \
            Return a JSON array of 1-3 corrected/improved versions. \
            Fix grammar, spelling, and make it natural for casual Korean chat. \
            Only return the JSON array, no explanation. Example: ["안녕하세요!", "안녕!"]
            """
        case .jpToEn:
            return """
            You are a Japanese-to-English translator for a chat keyboard. \
            The user will send a Japanese sentence in hiragana. \
            Return a JSON array of 1-3 natural English translations suitable for casual chat. \
            Only return the JSON array, no explanation. Example: ["How are you?", "How's it going?"]
            """
        case .jpToKr:
            return """
            You are a Japanese-to-Korean translator for a chat keyboard. \
            The user will send a Japanese sentence in hiragana. \
            Return a JSON array of 1-3 natural Korean translations suitable for casual chat. \
            Only return the JSON array, no explanation. Example: ["잘 지내?", "어떻게 지내?"]
            """
        }
    }
}
