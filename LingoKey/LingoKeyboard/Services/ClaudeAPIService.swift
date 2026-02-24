import Foundation

final class LLMAPIService {
    var apiKey: String = ""

    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let model = "gpt-4.1-nano"
    private let maxTokens = 512
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public

    func correct(text: String, mode: KeyboardMode) async -> [Suggestion] {
        let systemPrompt = systemPrompt(for: mode)
        return await callAPI(system: systemPrompt, userMessage: text, originalText: text)
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
        Translate the ENTIRE text as a whole — do NOT omit or skip any sentences. \
        Return a JSON array of 1-3 natural \(targetLanguage) translations suitable for casual chat. \
        Each translation must cover the full input text, not just part of it. \
        Only return the JSON array, no explanation. Example: ["How are you?", "How's it going?"]
        """

        return await callAPI(system: system, userMessage: text, originalText: text)
            .map { Suggestion(text: $0.text, originalText: $0.originalText, kind: .translation) }
    }

    // MARK: - Private

    private func callAPI(system: String, userMessage: String, originalText: String) async -> [Suggestion] {
        guard !apiKey.isEmpty else { return [] }

        let request = OpenAIRequest(
            model: model,
            messages: [
                OpenAIMessage(role: "system", content: system),
                OpenAIMessage(role: "user", content: userMessage)
            ],
            max_tokens: maxTokens
        )

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
            let (data, response) = try await session.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return []
            }

            let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            return parseSuggestions(from: openAIResponse, originalText: originalText)
        } catch {
            return []
        }
    }

    private func callConvertAndTranslateAPI(system: String, hiragana: String) async -> [Suggestion] {
        guard !apiKey.isEmpty else { return [] }

        let request = OpenAIRequest(
            model: model,
            messages: [
                OpenAIMessage(role: "system", content: system),
                OpenAIMessage(role: "user", content: hiragana)
            ],
            max_tokens: maxTokens
        )

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
            let (data, response) = try await session.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return []
            }

            let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            return parseConvertAndTranslate(from: openAIResponse, originalText: hiragana)
        } catch {
            return []
        }
    }

    private func parseConvertAndTranslate(from response: OpenAIResponse, originalText: String) -> [Suggestion] {
        guard let text = response.choices.first?.message.content else {
            return []
        }

        let cleaned = extractJSON(from: text)

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

    private func parseSuggestions(from response: OpenAIResponse, originalText: String) -> [Suggestion] {
        guard let text = response.choices.first?.message.content else {
            return []
        }

        let cleaned = extractJSON(from: text)

        if let data = cleaned.data(using: .utf8),
           let array = try? JSONDecoder().decode([String].self, from: data) {
            return array.map { Suggestion(text: $0, originalText: originalText) }
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return [Suggestion(text: trimmed, originalText: originalText)]
    }

    private func extractJSON(from text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if s.hasPrefix("```") {
            if let firstNewline = s.firstIndex(of: "\n") {
                s = String(s[s.index(after: firstNewline)...])
            }
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
