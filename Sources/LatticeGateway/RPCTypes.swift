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

    var intValue: Int? {
        if case .int(let i) = self { return i }
        return nil
    }
}

struct RPCResponse: Codable, Sendable {
    let jsonrpc: String
    let result: AnyCodable?
    let error: RPCError?
    let id: Int

    static func success(_ result: some Codable & Sendable, id: Int) -> RPCResponse {
        RPCResponse(jsonrpc: "2.0", result: AnyCodable(result), error: nil, id: id)
    }

    static func error(code: Int, message: String, id: Int) -> RPCResponse {
        RPCResponse(jsonrpc: "2.0", result: nil, error: RPCError(code: code, message: message), id: id)
    }
}

struct RPCError: Codable, Sendable {
    let code: Int
    let message: String
}

struct AnyCodable: Codable, Sendable {
    private let _encode: @Sendable (Encoder) throws -> Void

    init(_ value: some Codable & Sendable) {
        self._encode = { encoder in try value.encode(to: encoder) }
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) {
            self = AnyCodable(s)
        } else if let i = try? container.decode(Int.self) {
            self = AnyCodable(i)
        } else if let b = try? container.decode(Bool.self) {
            self = AnyCodable(b)
        } else {
            self = AnyCodable("null")
        }
    }
}
