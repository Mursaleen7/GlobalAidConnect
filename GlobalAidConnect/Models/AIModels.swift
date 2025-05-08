import Foundation

// MARK: - AI Models
struct AIMessage: Codable {
    let role: String
    let content: String
}

struct ClaudeRequest: Codable {
    let model: String
    let messages: [AIMessage]
    let temperature: Double
    let maxTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }
}

struct GPTRequest: Codable {
    let model: String
    let messages: [AIMessage]
    let temperature: Double
    let maxTokens: Int
    let responseFormat: ResponseFormat?
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
        case responseFormat = "response_format"
    }
}

struct ResponseFormat: Codable {
    let type: String
}

struct AIResponse: Codable {
    let id: String
    let choices: [AIChoice]
}

struct AIChoice: Codable {
    let message: AIMessage
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case message
        case finishReason = "finish_reason"
    }
}
