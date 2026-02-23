import Foundation

// MARK: - OpenAI Chat Completions Request

struct OpenAIRequest: Encodable {
    let model: String
    let messages: [OpenAIMessage]
    let max_tokens: Int
}

struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

// MARK: - OpenAI Chat Completions Response

struct OpenAIResponse: Decodable {
    let id: String
    let choices: [Choice]
    let usage: OpenAIUsage?
}

struct Choice: Decodable {
    let message: OpenAIMessage
    let finish_reason: String?
}

struct OpenAIUsage: Decodable {
    let prompt_tokens: Int
    let completion_tokens: Int
    let total_tokens: Int
}
