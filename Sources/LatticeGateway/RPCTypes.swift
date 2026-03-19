import Foundation

struct RPCRequest: Codable, Sendable {
    let jsonrpc: String
    let method: String
    let params: [RPCParam]?
    let id: Int
}

enum RPCParam: Codable, Sendable {
    case string(String)
    case int(Int)
    case bool(Bool)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let i = try? container.decode(Int.self) {
            self = .int(i)
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported param type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .int(let i): try container.encode(i)
        case .bool(let b): try container.encode(b)
        }
    }

    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }
}

struct RPCResponse<T: Codable & Sendable>: Codable, Sendable {
    let jsonrpc: String
    let result: T?
    let error: RPCError?
    let id: Int
}

struct RPCError: Codable, Sendable {
    let code: Int
    let message: String
}

struct EmptyResult: Codable, Sendable {}
