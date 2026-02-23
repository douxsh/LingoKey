import Foundation

// MARK: - Request

struct ClaudeRequest: Encodable {
    let model: String
    let max_tokens: Int
    let system: String
    let messages: [ClaudeMessage]
}

struct ClaudeMessage: Codable {
    let role: String
    let content: String
}

// MARK: - Response

struct ClaudeResponse: Decodable {
    let id: String
    let content: [ContentBlock]
    let stop_reason: String?
    let usage: Usage?
}

struct ContentBlock: Decodable {
    let type: String
    let text: String?
}

struct Usage: Decodable {
    let input_tokens: Int
    let output_tokens: Int
}
